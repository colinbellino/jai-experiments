#import "Basic";
#import "Compiler";
#import "Process";
#import "File";
#import "File_Utilities";
#import "String";

OUTPUT_PATH            :: "dist";
OUTPUT_EXECUTABLE_NAMES :: string.[
    "001_sdl_opengl_imgui",
    "002_allocators",
];

array_begins_with :: (array: [] $string, item: string) -> bool, s64 {
    for array {
        if begins_with(it, item) {
            return true, it_index;
        }
    }
    return false, -1;  // Not found.
}

#run {
    set_build_options_dc(.{ do_output = false });

    args_main := get_build_options(1).compile_time_command_line;
    arg_release := array_find(args_main, "-release");
    target := ifx arg_release then "RELEASE" else "DEBUG";

    args := get_build_options().compile_time_command_line;
    arg_open, arg_open_index := array_begins_with(args, "-open");
    output_target := tprint("%_%_%", OS, CPU, target);
    full_output_path := tprint("%/%", OUTPUT_PATH, output_target);
    log("Compiling for % | % | %.", OS, CPU, target);

    for output_executable_name: OUTPUT_EXECUTABLE_NAMES {
        if arg_open && contains(args[arg_open_index], output_executable_name) == false {
            continue;
        }

        workspace := compiler_create_workspace(tprint("Workspace: %", output_executable_name));

        options := get_build_options(workspace);
        copy_commonly_propagated_fields(get_build_options(), *options);
        options.os_target  = OS;
        options.cpu_target = CPU;
        options.output_path = full_output_path;
        options.output_executable_name = output_executable_name;
        if arg_release {
            options.backend = .LLVM;
            set_optimization(*options, .OPTIMIZED);
        } else {
            options.backend = .X64;
            set_optimization(*options, .DEBUG);
        }
        set_build_options(options, workspace);
        make_directory_if_it_does_not_exist(full_output_path, recursive = true);

        compiler_begin_intercept(workspace);
        add_build_file(tprint("src/%.jai", output_executable_name), workspace);
        while true {
            message := compiler_wait_for_message();
            if message.kind == {
                // case .PHASE;    { }
                case .ERROR;    { exit(1); }
                case .COMPLETE; { break; }
            }
        }
        compiler_end_intercept(workspace);

        if arg_open && contains(args[arg_open_index], output_executable_name) {
            log("------------------------------");
            log("Starting game.");
            run_command(tprint("./%/%", full_output_path, output_executable_name));
        }
    }
};
