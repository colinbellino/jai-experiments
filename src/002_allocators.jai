#import "Basic"()(MEMORY_DEBUGGER=true);
#import "SDL";
#import "Math";
#import "GL";
Flat_Pool :: #import "Flat_Pool";

#load "imgui_sdl_gl.jai";
#load "imgui_custom.jai";

Byte     :: 1;
Kilobyte :: 1024 * Byte;
Megabyte :: 1024 * Kilobyte;
Gigabyte :: 1024 * Megabyte;
Terabyte :: 1024 * Gigabyte;
Petabyte :: 1024 * Terabyte;
Exabyte  :: 1024 * Petabyte;

sdl_malloc ::  (size: s64) -> *void #c_call {
    new_context: Context;
    new_context.allocator = pool_allocator;
    push_context new_context {
        // log("sdl_malloc: %", size);
        return alloc(size);
    }
}
sdl_calloc ::  (nmemb: s64, size: s64) -> *void #c_call {
    new_context: Context;
    new_context.allocator = pool_allocator;
    push_context new_context {
        // log("sdl_calloc: % %", nmemb, size);
        return alloc(size * nmemb);
    }
}
sdl_realloc :: (mem: *void, size: s64) -> *void #c_call {
    new_context: Context;
    new_context.allocator = pool_allocator;
    push_context new_context {
        // log("sdl_realloc: % %", mem, size);
        return realloc(mem, size, 0);
    }
}
sdl_free ::    (mem: *void) #c_call {
    new_context: Context;
    new_context.allocator = pool_allocator;
    push_context new_context {
        // log("sdl_free: %", mem);
        free(mem);
    }
}

pool_allocator: Allocator;
pool: Flat_Pool.Flat_Pool;

main :: () {
    defer log("Quitting...");

    memory := cast(*u8) Flat_Pool.get(*pool, 8 * Megabyte);

    pool_allocator.proc = Flat_Pool.flat_pool_allocator_proc;
    pool_allocator.data = *pool;

    context.allocator = pool_allocator;

    SDL_SetMemoryFunctions(sdl_malloc, sdl_calloc, sdl_realloc, sdl_free);

    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER);

    window := SDL_CreateWindow("Allocators", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if window == null {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        print( "Could not create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_load(*gl, SDL_GL_GetProcAddress);

    imgui_context := ImGui.CreateContext();
    ImGui_ImplSdl_Init(window);
    // ImGui.StyleColorsClassic();
    // ImGui.StyleColorsLight();

    io := ImGui.GetIO();
    clear_color := rgba(0.45, 0.55, 0.60, 1.00);

    bla := "bla";

    done := false;
    while !done {
        // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
        // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
        // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
        // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            ImGui_ImplSdl_ProcessEvent(*event);
            if event.type == SDL_QUIT {
                done = true;
            }
            if event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window) {
                done = true;
            }
        }

        ImGui_ImplSdl_NewFrame(window);
        ImGui.NewFrame();

        input_text("label", *bla);

        if ImGui.GetMouseCursor() == {
            case .Arrow;         SDL_SetCursor(cursor_arrow);
            case .TextInput;     SDL_SetCursor(cursor_text_input);
            case .Hand;          SDL_SetCursor(cursor_move);
            case .ResizeNS;      SDL_SetCursor(cursor_resize_ns);
            case .ResizeEW;      SDL_SetCursor(cursor_resize_ew);
            case .ResizeNESW;    SDL_SetCursor(cursor_resize_nesw);
            case .ResizeNWSE;    SDL_SetCursor(cursor_resize_nwse);
        }

        ImGui.Render();
        glViewport(0, 0, xx io.DisplaySize.x, xx io.DisplaySize.y);
        glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
        SDL_GL_SwapWindow(window);

        reset_temporary_storage();
        memory_visualizer_per_frame_update();
    }

    Flat_Pool.reset(*pool, overwrite_memory = true);

    // ImGui_ImplSdl_Shutdown();
    // ImGui.DestroyContext(imgui_context);
    // SDL_GL_DeleteContext(gl_context);
    // SDL_DestroyWindow(window);
    // SDL_Quit();
}
