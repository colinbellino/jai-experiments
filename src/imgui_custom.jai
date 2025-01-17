Reflection :: #import "Reflection";

imgui_inspect :: (name: *u8, t : *$T) {
    ImGui.Begin(name, *show_inspector);
    imgui_inspect(name, t, type_info(T), true);
    ImGui.End();
}

imgui_inspect :: (name: *u8, data: *void, info:*Type_Info, expanded := false) {
    default_size: ImGui.ImVec2;

    if #complete info.type == {
        case .INTEGER; {
            info_int := cast(*Type_Info_Integer) info;
            ImGui.InputInt(name, data); // @@ Add support for unsigned, and larger int types.
        }
        case .FLOAT; {
            if info.runtime_size == {
                case 4; {
                    //ImGui.DragFloat(name, data, display_format="%.3f");
                    ImGui.InputFloat(name, data, 0.01, 1.0);
                }
                case 8; {
                    x : float = xx <<cast(*float64) data;
                    if ImGui.InputFloat(name, *x, 0.01, 1.0) { <<cast(*float64) data = x; };
                }
            }
        }
        case .BOOL; {
            //ImGui.Checkbox(name, data);
            index : s32 = xx <<cast(*bool)data;
            if ImGui.Combo(name, *index, "false\0true\0\0") {
                <<cast(*bool)data = xx index;
            }
        }
        case .STRING; {
            s := << cast(*string) data;  // For now we assume non-relative strings only.
            if s.count {
                ImGui.InputText(name, s.data, xx s.count, ImGui.InputTextFlags.ReadOnly);    // @@ We could allow editing of strings too.
            } else {
                ImGui.InputText(name, "(null)", 6, ImGui.InputTextFlags.ReadOnly);
            }
        }
        case .POINTER; {
            // @@ Open in new window?
            ImGui.Text("pointer");
        }
        case .PROCEDURE; {
            ImGui.Text("procedure");
        }
        case .VOID; {
            ImGui.Text("void");
        }
        case .CODE; {
            ImGui.Text("Code");
        }
        case .STRUCT; {
            info_struct := cast(*Type_Info_Struct) info;
            if ImGui.TreeNodeEx(temp_c_string(tprint("%: %", to_string(name), info_struct.name)), ifx expanded then .DefaultOpen else .None) {
                for member: info_struct.members {
                    imgui_inspect(temp_c_string(member.name), data + member.offset_in_bytes, member.type);
                }
                ImGui.TreePop();
            }
        }
        case .ARRAY; {
            info_array := cast(*Type_Info_Array) info;
            array_count, array_data := Reflection.get_array_count_and_data(data, info_array);
            array_name := to_string(name);
            element_size := info_array.element_type.runtime_size;
            if ImGui.TreeNode(name, "% (count = %)", array_name, array_count) {
                for 0..array_count-1 {
                    item_name := temp_c_string(tprint("%[%]", array_name, it));
                    imgui_inspect(item_name, array_data + it * element_size, info_array.element_type);
                }
                ImGui.TreePop();
            }
        }
        case .ANY; {
            // @@ Display type and inspect value.
            ImGui.Text("Any!");
        }
        case .ENUM; {
            info_enum := cast(*Type_Info_Enum) info;

            if info_enum.enum_type_flags & .FLAGS {
                // @@ How to handle flags?
            } else {
                value := Reflection.get_enum_value(data, info_enum);
                value_name := "";
                for info_enum.names {
                    if value == info_enum.values[it_index] {
                        value_name = it;
                    }
                }

                if ImGui.BeginCombo(name, temp_c_string(value_name)) {
                    for info_enum.names {
                        is_selected := value == info_enum.values[it_index];
                        if ImGui.Selectable(temp_c_string(it), is_selected, size=*default_size) {
                            Reflection.set_enum_value(data, info_enum, info_enum.values[it_index]);
                        }
                        if is_selected ImGui.SetItemDefaultFocus();
                    }

                    ImGui.EndCombo();
                }
            }
        }
        case .POLYMORPHIC_VARIABLE; {
            // @@ ??
        }
        case .TYPE; {
            // @@
        }
        case .OVERLOAD_SET; {
            // @@
        }
        case .VARIANT; {
            // @Incomplete: Can do something better here.
            tiv := cast(*Type_Info_Variant) info;
            imgui_inspect(name, data, tiv.variant_of);
        }
    }
}

Input_Text_Callback_User_Data :: struct {
    str:                        *string;
    chain_callback:             ImGui.InputTextCallback;
    chain_call_back_user_data:  *void;
}

input_text :: (label: string, str: *string, flags: ImGui.InputTextFlags = 0) -> bool {
    flags |= .CallbackResize;
    flags |= .CallbackEdit;

    cbUserData: *Input_Text_Callback_User_Data = talloc(size_of(Input_Text_Callback_User_Data));
    cbUserData.str = str;

    cStr: *u8 = talloc(str.count + 1);
    memset(cStr, 0, str.count + 1);
    memcpy(cStr, str.data, str.count);
    return ImGui.InputText(temp_c_string(label), cStr, cast(u64)(str.count + 1), flags, input_text_callback, cbUserData);
}

input_text_callback :: (data: *ImGui.InputTextCallbackData) -> s32 #c_call {
    new_context: Context;
    push_context new_context {
        cbUserData := cast(*Input_Text_Callback_User_Data) data.UserData;

        if data.EventFlag == .CallbackResize {
            array_resize(cast(*[]u8)cbUserData.str, data.BufTextLen);

            cStr: *u8 = talloc(cbUserData.str.count + 1);
            memset(cStr, 0, cbUserData.str.count + 1);
            memcpy(cStr, cbUserData.str.data, cbUserData.str.count);
            data.Buf = cStr;
        } else if data.EventFlag == .CallbackEdit {
            cbUserData.str.count = 0;
            cbUserData.str.* = copy_string(to_string(data.Buf));
        } else {
            print("Other callback\n");
        }
    }

    return 0;
}
