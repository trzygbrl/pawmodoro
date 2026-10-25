; =============================================================================
; Pawmodoro - Settings Screen & Color Editor UI (src/settings_ui.asm)
;
; Purpose: Adaptive terminal UI rendering and keyboard event loop for:
;          1. Main Settings list (Theme, Customize, Anim, Sound/Vol, Charset, Notify, Reset).
;          2. Dedicated 256-color palette editor with 16x16 grid preview and slot list.
;          3. Reset-to-defaults confirmation prompt with y/n gating.
; Reference: PRD_V2 §4 (Themes & slots), §5 (settings.dat), §6 (Keyboard & state 5)
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: settings_mutate_and_save
; Purpose:   Persists current in-memory settings to settings.dat via settings_save
;            and updates settings_status_msg and settings_status_style.
; IN:        None
; OUT:       None (settings persisted; status message updated)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_mutate_and_save:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    call settings_save
    cmp byte [settings_save_err], 0
    jne .save_failed

    ; Save succeeded
    mov dword [settings_status_msg], settings_msg_saved
    mov dword [settings_status_style], STATUS_OK
    jmp .save_done

.save_failed:
    ; Save failed
    mov dword [settings_status_msg], settings_msg_could_not_save
    mov dword [settings_status_style], STATUS_ERR

.save_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_draw
; Purpose:   Renders the Main Settings screen:
;            - Header with title "SETTINGS"
;            - 7 selectable setting rows with active values and live preview swatches
;            - Sample line demonstrating the active theme
;            - Status feedback ("Saved" / "Could not save")
;            - Footer key help
; IN:        None
; OUT:       Appends complete Settings frame to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_draw:
    save_regs
    push eax

    ; 1. Terminal size check and layout computation
    call ui_size_gate
    call ui_layout_update

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Geometry (Rows 1..22)
    ; -------------------------------------------------------------------------
    ; Row 1: Top border
    mov eax, 1
    call ui_frame_hline

    ; Row 2: Title row
    mov eax, 2
    call ui_frame_row

    ; Row 3: Separator below title
    mov eax, 3
    call ui_frame_hline

    ; Rows 4..18: Settings rows and spacing
    mov ecx, 4
.frame_rows_loop:
    mov eax, ecx
    call ui_frame_row
    inc ecx
    cmp ecx, 19
    jbe .frame_rows_loop

    ; Row 19: Separator above footer
    mov eax, 19
    call ui_frame_hline

    ; Row 20: Status feedback row
    mov eax, 20
    call ui_frame_row

    ; Row 21: Key help row
    mov eax, 21
    call ui_frame_row

    ; Row 22: Bottom border
    mov eax, 22
    call ui_frame_hline

    ; Row 23: Erase to bottom of screen (ESC[J)
    mov eax, 23
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content
    ; -------------------------------------------------------------------------
    ; Screen Title at (Row 2, Col 4): "SETTINGS"
    mov eax, 2
    mov ebx, 4
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, title_settings
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; Row 0: Theme (Screen Row 4)
    ; -------------------------------------------------------------------------
    mov eax, 4
    mov edx, SETTINGS_ROW_THEME
    mov esi, settings_lbl_theme
    call settings_draw_row_label

    ; Value: < Theme Name >
    mov eax, 4
    mov ebx, 26
    call ui_goto
    mov al, CHAR_ESC
    call buf_char
    mov al, '['
    call buf_char
    mov al, '1'
    call buf_char
    mov al, 'm'
    call buf_char
    mov al, '<'
    call buf_char
    mov al, ' '
    call buf_char

    ; Look up theme name string pointer
    movzx eax, byte [setting_theme]
    cmp eax, THEME_MAX_INDEX
    jbe .theme_name_valid
    xor eax, eax
.theme_name_valid:
    mov esi, [theme_names + eax*4]
    call buf_str

    mov al, ' '
    call buf_char
    mov al, '>'
    call buf_char
    mov esi, ansi_reset
    call buf_str

    ; Live Swatch Strip at (Screen Row 5, Col 26)
    mov eax, 5
    mov ebx, 26
    call ui_goto

    xor ecx, ecx
.swatch_loop:
    push ecx
    mov al, cl
    call ui_bgcolor             ; Set bg to slot color
    mov al, CHAR_SPACE
    call buf_char
    call buf_char               ; 2 spaces per slot swatch
    mov esi, ansi_reset
    call buf_str
    pop ecx
    inc ecx
    cmp ecx, NUM_SLOTS          ; 12 slots
    jb .swatch_loop

    ; Sample Line at (Screen Row 6, Col 26)
    mov eax, 6
    mov ebx, 26
    call ui_goto

    mov esi, settings_sample_lbl
    call buf_str

    mov al, SLOT_TITLE
    call ui_color
    mov esi, settings_sample_title
    call buf_str

    mov al, SLOT_TEXT
    call ui_color
    mov esi, settings_sample_text
    call buf_str

    mov al, SLOT_ACCENT
    call ui_color
    mov esi, settings_sample_accent
    call buf_str

    mov al, SLOT_OK
    call ui_color
    mov esi, settings_sample_ok
    call buf_str

    mov al, SLOT_WARN
    call ui_color
    mov esi, settings_sample_warn
    call buf_str

    mov al, SLOT_ERR
    call ui_color
    mov esi, settings_sample_err
    call buf_str

    mov esi, ansi_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; Row 1: Customize colors (Screen Row 8)
    ; -------------------------------------------------------------------------
    mov eax, 8
    mov edx, SETTINGS_ROW_CUSTOMIZE
    mov esi, settings_lbl_customize
    call settings_draw_row_label

    mov eax, 8
    mov ebx, 26
    call ui_goto
    mov esi, settings_hint_customize
    call buf_str

    ; -------------------------------------------------------------------------
    ; Row 2: Animations (Screen Row 10)
    ; -------------------------------------------------------------------------
    mov eax, 10
    mov edx, SETTINGS_ROW_ANIM
    mov esi, settings_lbl_anim
    call settings_draw_row_label

    mov eax, 10
    mov ebx, 26
    call ui_goto
    mov al, '<'
    call buf_char
    mov al, ' '
    call buf_char

    cmp byte [setting_anim], 1
    je .anim_is_on
    mov esi, settings_val_reduce_motion
    jmp .anim_emit
.anim_is_on:
    mov esi, settings_val_on
.anim_emit:
    call buf_str
    mov al, ' '
    call buf_char
    mov al, '>'
    call buf_char

    ; -------------------------------------------------------------------------
    ; Row 3: Sound & Volume (Screen Row 12)
    ; -------------------------------------------------------------------------
    mov eax, 12
    mov edx, SETTINGS_ROW_SOUND
    mov esi, settings_lbl_sound
    call settings_draw_row_label

    mov eax, 12
    mov ebx, 26
    call ui_goto

    mov esi, settings_lbl_sound_prefix  ; "Sound: "
    call buf_str
    mov al, '<'
    call buf_char
    mov al, ' '
    call buf_char

    cmp byte [setting_sound], 1
    je .snd_is_on
    mov esi, settings_val_off
    jmp .snd_emit
.snd_is_on:
    mov esi, settings_val_on
.snd_emit:
    call buf_str
    mov al, ' '
    call buf_char
    mov al, '>'
    call buf_char

    ; Volume portion
    mov esi, settings_lbl_vol_prefix    ; "   Vol: < "
    call buf_str
    movzx eax, byte [setting_volume]
    call buf_u32
    mov esi, settings_lbl_vol_suffix    ; " > (0-3)"
    call buf_str

    ; -------------------------------------------------------------------------
    ; Row 4: Charset (Screen Row 14)
    ; -------------------------------------------------------------------------
    mov eax, 14
    mov edx, SETTINGS_ROW_CHARSET
    mov esi, settings_lbl_charset
    call settings_draw_row_label

    mov eax, 14
    mov ebx, 26
    call ui_goto
    mov al, '<'
    call buf_char
    mov al, ' '
    call buf_char

    cmp byte [setting_charset], 1
    je .charset_is_ascii
    mov esi, settings_val_utf8
    jmp .charset_emit
.charset_is_ascii:
    mov esi, settings_val_ascii
.charset_emit:
    call buf_str
    mov al, ' '
    call buf_char
    mov al, '>'
    call buf_char

    ; -------------------------------------------------------------------------
    ; Row 5: Terminal integration (Screen Row 16)
    ; -------------------------------------------------------------------------
    mov eax, 16
    mov edx, SETTINGS_ROW_NOTIFY
    mov esi, settings_lbl_notify
    call settings_draw_row_label

    mov eax, 16
    mov ebx, 26
    call ui_goto
    mov al, '<'
    call buf_char
    mov al, ' '
    call buf_char

    cmp byte [setting_notify], 1
    je .notify_is_on
    mov esi, settings_val_off
    jmp .notify_emit
.notify_is_on:
    mov esi, settings_val_on
.notify_emit:
    call buf_str
    mov al, ' '
    call buf_char
    mov al, '>'
    call buf_char

    ; Render 5 individual notification layer indicators: 1:Bel 2:Flsh 3:Titl 4:Prog 5:Toast
    ; Active layer bit: SLOT_OK (green). Inactive layer bit: SLOT_DIM (gray).
    test byte [setting_notify_layers], NOTIFY_LAYER_BELL
    jz .layer1_dim
    mov al, SLOT_OK
    jmp .layer1_draw
.layer1_dim:
    mov al, SLOT_DIM
.layer1_draw:
    call ui_color
    mov esi, settings_lbl_layer_1
    call buf_str

    test byte [setting_notify_layers], NOTIFY_LAYER_FLASH
    jz .layer2_dim
    mov al, SLOT_OK
    jmp .layer2_draw
.layer2_dim:
    mov al, SLOT_DIM
.layer2_draw:
    call ui_color
    mov esi, settings_lbl_layer_2
    call buf_str

    test byte [setting_notify_layers], NOTIFY_LAYER_TITLE
    jz .layer3_dim
    mov al, SLOT_OK
    jmp .layer3_draw
.layer3_dim:
    mov al, SLOT_DIM
.layer3_draw:
    call ui_color
    mov esi, settings_lbl_layer_3
    call buf_str

    test byte [setting_notify_layers], NOTIFY_LAYER_PROGRESS
    jz .layer4_dim
    mov al, SLOT_OK
    jmp .layer4_draw
.layer4_dim:
    mov al, SLOT_DIM
.layer4_draw:
    call ui_color
    mov esi, settings_lbl_layer_4
    call buf_str

    test byte [setting_notify_layers], NOTIFY_LAYER_TOAST
    jz .layer5_dim
    mov al, SLOT_OK
    jmp .layer5_draw
.layer5_dim:
    mov al, SLOT_DIM
.layer5_draw:
    call ui_color
    mov esi, settings_lbl_layer_5
    call buf_str

    mov esi, ansi_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; Row 6: Reset to defaults (Screen Row 18)
    ; -------------------------------------------------------------------------
    mov eax, 18
    mov edx, SETTINGS_ROW_RESET
    mov esi, settings_lbl_reset
    call settings_draw_row_label

    mov eax, 18
    mov ebx, 26
    call ui_goto
    mov esi, settings_hint_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; Row 20: Status Message (Saved / Could not save)
    ; -------------------------------------------------------------------------
    mov eax, 20
    mov ebx, [settings_status_style]
    mov esi, [settings_status_msg]
    call ui_draw_status

    ; -------------------------------------------------------------------------
    ; Row 21: Key Help Footer (Context-sensitive when on Terminal integration row)
    ; -------------------------------------------------------------------------
    mov eax, 21
    mov ebx, 4
    mov esi, settings_help_main
    cmp dword [settings_sel_row], SETTINGS_ROW_NOTIFY
    jne .emit_footer_help
    mov esi, settings_help_notify
.emit_footer_help:
    call ui_text_at

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: settings_draw_row_label
; Purpose:   Draws row selection marker '>' and row label at specified row.
;            Highlights selected row with bold and SLOT_ACCENT.
; IN:        EAX = Screen row coordinate (1-based)
;            EDX = Setting row index (0..6)
;            ESI = Pointer to row label string
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
settings_draw_row_label:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    push eax                    ; Save screen row
    push esi                    ; Save label string

    ; Position cursor at (row, 2) for selection marker
    mov ebx, 2
    call ui_goto

    cmp edx, [settings_sel_row]
    jne .not_selected

    ; Selected: Emit '>' marker in bold SLOT_ACCENT
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov al, '>'
    call buf_char
    mov al, ' '
    call buf_char

    ; Move to (row, 4) for label
    pop edi                     ; Restore label string into EDI
    pop eax                     ; Restore screen row
    mov ebx, 4
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, edi                ; Load label string after ui_color
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .label_done

.not_selected:
    ; Unselected: Emit space marker
    mov al, ' '
    call buf_char
    mov al, ' '
    call buf_char

    ; Move to (row, 4) for label
    pop edi                     ; Restore label string into EDI
    pop eax                     ; Restore screen row
    mov ebx, 4
    call ui_goto
    mov al, SLOT_TEXT
    call ui_color
    mov esi, edi                ; Load label string after ui_color
    call buf_str
    mov esi, ansi_reset
    call buf_str

.label_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_handle_key
; Purpose:   Processes keystrokes on the Main Settings screen:
;            - Up/Down/Home/End navigate the 7 selectable rows (0..6)
;            - Left/Right adjust/cycle setting values
;            - Enter activates color editor, toggles settings, or opens reset
;            - B/Esc returns to Main Menu
; IN:        EAX = Key code (ASCII or KEY_*)
; OUT:       None (updates state, redraw requested)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_handle_key:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Navigation: Up Arrow / 'K'
    cmp eax, KEY_UP
    je .nav_up
    cmp eax, 'K'
    je .nav_up

    ; Navigation: Down Arrow / 'J'
    cmp eax, KEY_DOWN
    je .nav_down
    cmp eax, 'J'
    je .nav_down

    ; Navigation: Home
    cmp eax, KEY_HOME
    je .nav_home

    ; Navigation: End
    cmp eax, KEY_END
    je .nav_end

    ; Value Adjustment: Left Arrow / 'H'
    cmp eax, KEY_LEFT
    je .adjust_left
    cmp eax, 'H'
    je .adjust_left

    ; Value Adjustment: Right Arrow / 'L'
    cmp eax, KEY_RIGHT
    je .adjust_right
    cmp eax, 'L'
    je .adjust_right

    ; Activate / Toggle: Enter / Space
    cmp eax, KEY_ENTER
    je .activate
    cmp eax, KEY_SPACE
    je .activate

    ; Exit / Return: 'B' or Esc
    cmp eax, KEY_B
    je .return_menu
    cmp eax, KEY_ESC
    je .return_menu

    ; Individual layer toggle keys '1'..'5' when on Terminal integration row
    cmp dword [settings_sel_row], SETTINGS_ROW_NOTIFY
    jne .key_done
    cmp eax, '1'
    je .toggle_layer_1
    cmp eax, '2'
    je .toggle_layer_2
    cmp eax, '3'
    je .toggle_layer_3
    cmp eax, '4'
    je .toggle_layer_4
    cmp eax, '5'
    je .toggle_layer_5

    jmp .key_done

.nav_up:
    mov edx, [settings_sel_row]
    test edx, edx
    jz .wrap_to_bottom
    dec dword [settings_sel_row]
    jmp .key_done
.wrap_to_bottom:
    mov dword [settings_sel_row], (SETTINGS_ROW_COUNT - 1)
    jmp .key_done

.nav_down:
    mov edx, [settings_sel_row]
    cmp edx, (SETTINGS_ROW_COUNT - 1)
    jae .wrap_to_top
    inc dword [settings_sel_row]
    jmp .key_done
.wrap_to_top:
    mov dword [settings_sel_row], 0
    jmp .key_done

.nav_home:
    mov dword [settings_sel_row], 0
    jmp .key_done

.nav_end:
    mov dword [settings_sel_row], (SETTINGS_ROW_COUNT - 1)
    jmp .key_done

.adjust_left:
    mov edx, [settings_sel_row]

    ; Row 0: Theme (cycle backward)
    cmp edx, SETTINGS_ROW_THEME
    je .theme_prev

    ; Row 2: Animations (toggle)
    cmp edx, SETTINGS_ROW_ANIM
    je .toggle_anim

    ; Row 3: Sound & Volume (decrease volume)
    cmp edx, SETTINGS_ROW_SOUND
    je .vol_down

    ; Row 4: Charset (toggle)
    cmp edx, SETTINGS_ROW_CHARSET
    je .toggle_charset

    ; Row 5: Terminal integration (toggle)
    cmp edx, SETTINGS_ROW_NOTIFY
    je .toggle_notify

    jmp .key_done

.adjust_right:
    mov edx, [settings_sel_row]

    ; Row 0: Theme (cycle forward)
    cmp edx, SETTINGS_ROW_THEME
    je .theme_next

    ; Row 1: Customize colors (open editor)
    cmp edx, SETTINGS_ROW_CUSTOMIZE
    je .open_colors

    ; Row 2: Animations (toggle)
    cmp edx, SETTINGS_ROW_ANIM
    je .toggle_anim

    ; Row 3: Sound & Volume (increase volume)
    cmp edx, SETTINGS_ROW_SOUND
    je .vol_up

    ; Row 4: Charset (toggle)
    cmp edx, SETTINGS_ROW_CHARSET
    je .toggle_charset

    ; Row 5: Terminal integration (toggle)
    cmp edx, SETTINGS_ROW_NOTIFY
    je .toggle_notify

    jmp .key_done

.activate:
    mov edx, [settings_sel_row]

    cmp edx, SETTINGS_ROW_THEME
    je .theme_next

    cmp edx, SETTINGS_ROW_CUSTOMIZE
    je .open_colors

    cmp edx, SETTINGS_ROW_ANIM
    je .toggle_anim

    cmp edx, SETTINGS_ROW_SOUND
    je .toggle_sound

    cmp edx, SETTINGS_ROW_CHARSET
    je .toggle_charset

    cmp edx, SETTINGS_ROW_NOTIFY
    je .toggle_notify

    cmp edx, SETTINGS_ROW_RESET
    je .open_confirm

    jmp .key_done

.theme_prev:
    movzx eax, byte [setting_theme]
    test eax, eax
    jz .theme_wrap_max
    dec al
    jmp .apply_theme_change
.theme_wrap_max:
    mov al, THEME_MAX_INDEX
    jmp .apply_theme_change

.theme_next:
    movzx eax, byte [setting_theme]
    cmp al, THEME_MAX_INDEX
    jae .theme_wrap_zero
    inc al
    jmp .apply_theme_change
.theme_wrap_zero:
    xor al, al

.apply_theme_change:
    mov [setting_theme], al
    call settings_apply_palette
    call settings_mutate_and_save
    jmp .key_done

.open_colors:
    mov dword [settings_view_mode], SETTINGS_MODE_COLORS
    mov dword [settings_color_slot], 0
    jmp .key_done

.toggle_anim:
    xor byte [setting_anim], 1
    call settings_mutate_and_save
    jmp .key_done

.toggle_sound:
    xor byte [setting_sound], 1
    call settings_mutate_and_save
    jmp .key_done

.vol_down:
    cmp byte [setting_volume], 0
    jbe .key_done
    dec byte [setting_volume]
    call settings_mutate_and_save
    jmp .key_done

.vol_up:
    cmp byte [setting_volume], MAX_VOLUME
    jae .key_done
    inc byte [setting_volume]
    call settings_mutate_and_save
    jmp .key_done

.toggle_charset:
    xor byte [setting_charset], 1
    call settings_mutate_and_save
    jmp .key_done

.toggle_notify:
    xor byte [setting_notify], 1
    call settings_mutate_and_save
    jmp .key_done

.toggle_layer_1:
    xor byte [setting_notify_layers], NOTIFY_LAYER_BELL
    call settings_mutate_and_save
    jmp .key_done

.toggle_layer_2:
    xor byte [setting_notify_layers], NOTIFY_LAYER_FLASH
    call settings_mutate_and_save
    jmp .key_done

.toggle_layer_3:
    xor byte [setting_notify_layers], NOTIFY_LAYER_TITLE
    call settings_mutate_and_save
    jmp .key_done

.toggle_layer_4:
    xor byte [setting_notify_layers], NOTIFY_LAYER_PROGRESS
    call settings_mutate_and_save
    jmp .key_done

.toggle_layer_5:
    xor byte [setting_notify_layers], NOTIFY_LAYER_TOAST
    call settings_mutate_and_save
    jmp .key_done

.open_confirm:
    mov dword [settings_view_mode], SETTINGS_MODE_CONFIRM
    jmp .key_done

.return_menu:
    mov dword [state], STATE_MENU

.key_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_colors_draw
; Purpose:   Renders the Dedicated 256-Color Customization Screen:
;            - Left side: 12 named slots (BORDER..HIGHLIGHT), current color index,
;              selection marker, and live slot color swatch
;            - Right side: 16x16 grid preview of all 256 terminal colors,
;              with the selected slot's color marked by "[]"
;            - Bottom: Illustrative sample of the selected slot in actual UI use
;            - Status feedback and key help footer
; IN:        None
; OUT:       Appends complete Color Editor frame to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_colors_draw:
    save_regs
    push eax

    call ui_size_gate
    call ui_layout_update

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Geometry (Rows 1..23)
    ; -------------------------------------------------------------------------
    mov eax, 1
    call ui_frame_hline
    mov eax, 2
    call ui_frame_row
    mov eax, 3
    call ui_frame_hline

    mov ecx, 4
.c_frame_loop:
    mov eax, ecx
    call ui_frame_row
    inc ecx
    cmp ecx, 21
    jbe .c_frame_loop

    mov eax, 21
    call ui_frame_hline
    mov eax, 22
    call ui_frame_row
    mov eax, 23
    call ui_frame_hline

    ; Row 24: Erase below frame (ESC[J)
    mov eax, 24
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content
    ; -------------------------------------------------------------------------
    ; Screen Title: "SETTINGS - CUSTOMIZE COLORS"
    mov eax, 2
    mov ebx, 4
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, title_settings_colors
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; Left Column: 12 Named Slots (Screen Rows 4..15)
    ; -------------------------------------------------------------------------
    xor ecx, ecx                ; ECX = slot index (0..11)
.slot_row_loop:
    push ecx

    mov eax, 4
    add eax, ecx                ; EAX = screen row (4 + slot)

    ; Position at (row, 4)
    mov ebx, 4
    call ui_goto

    ; Selection marker
    cmp ecx, [settings_color_slot]
    jne .slot_not_sel

    ; Selected slot marker '>' in bold SLOT_ACCENT
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov al, '>'
    call buf_char
    mov al, ' '
    call buf_char

    ; Slot Name in bold SLOT_ACCENT
    mov esi, [slot_names + ecx*4]
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .slot_color_val

.slot_not_sel:
    mov al, ' '
    call buf_char
    mov al, ' '
    call buf_char

    ; Slot Name in standard SLOT_TEXT
    mov al, SLOT_TEXT
    call ui_color
    mov esi, [slot_names + ecx*4]
    call buf_str
    mov esi, ansi_reset
    call buf_str

.slot_color_val:
    ; Decimal color index in parentheses: "(211)"
    mov al, ' '
    call buf_char
    mov al, '('
    call buf_char

    movzx eax, byte [active_palette + ecx]
    call buf_u32

    mov al, ')'
    call buf_char
    mov al, ' '
    call buf_char

    ; 2-character color swatch in slot's color
    mov al, cl
    call ui_bgcolor
    mov al, CHAR_SPACE
    call buf_char
    call buf_char
    mov esi, ansi_reset
    call buf_str

    pop ecx
    inc ecx
    cmp ecx, NUM_SLOTS          ; 12
    jb .slot_row_loop

    ; -------------------------------------------------------------------------
    ; Right Column: 16x16 Color Palette Grid (Screen Rows 4..19, Col 34)
    ; -------------------------------------------------------------------------
    ; Fetch currently selected slot's color index (0..255)
    mov edx, [settings_color_slot]
    movzx edx, byte [active_palette + edx]  ; EDX = selected color (0..255)

    xor ecx, ecx                ; ECX = grid row (0..15)
.grid_row_loop:
    push ecx
    push edx

    mov eax, 4
    add eax, ecx                ; EAX = screen row (4 + r)
    mov ebx, 34                 ; EBX = start column 34
    call ui_goto

    xor esi, esi                ; ESI = grid col (0..15)
.grid_col_loop:
    push esi
    push ecx
    push edx

    ; Calculate 256-color index N = row * 16 + col
    mov eax, ecx
    shl eax, 4                  ; row * 16
    add eax, esi                ; N = row * 16 + col (0..255)
    push eax                    ; [esp] = N

    ; Check if N == selected color in EDX
    cmp eax, edx
    jne .normal_grid_cell

    ; -------------------------------------------------------------------------
    ; Marked Cell: This cell matches the selected slot's color!
    ; Emit background color N, followed by bold "[]"
    ; -------------------------------------------------------------------------
    ; ESC[48;5;Nm
    mov esi, ansi_bg_256_prefix
    call buf_str
    pop eax                     ; Restore N
    push eax
    call buf_u32
    mov al, CHAR_LOWER_M
    call buf_char

    ; Marker text: bold white or black "[]"
    mov esi, ansi_bold
    call buf_str
    mov al, '['
    call buf_char
    mov al, ']'
    call buf_char
    mov esi, ansi_reset
    call buf_str
    jmp .grid_cell_done

.normal_grid_cell:
    ; -------------------------------------------------------------------------
    ; Normal Cell: Emit background color N, followed by two spaces "  "
    ; -------------------------------------------------------------------------
    mov esi, ansi_bg_256_prefix
    call buf_str
    pop eax                     ; Restore N
    push eax
    call buf_u32
    mov al, CHAR_LOWER_M
    call buf_char

    mov al, CHAR_SPACE
    call buf_char
    call buf_char
    mov esi, ansi_reset
    call buf_str

.grid_cell_done:
    pop eax                     ; Clean stack N
    pop edx
    pop ecx
    pop esi

    inc esi
    cmp esi, COLOR_GRID_COLS    ; 16
    jb .grid_col_loop

    pop edx
    pop ecx
    inc ecx
    cmp ecx, COLOR_GRID_ROWS    ; 16
    jb .grid_row_loop

    ; -------------------------------------------------------------------------
    ; Row 20: Illustrative Sample of Selected Slot in Actual Use
    ; -------------------------------------------------------------------------
    mov eax, 20
    mov ebx, 4
    call ui_goto

    mov esi, settings_sample_lbl  ; "Sample: "
    call buf_str

    mov edx, [settings_color_slot]
    cmp edx, SLOT_BORDER
    je .sample_border
    cmp edx, SLOT_TITLE
    je .sample_title
    cmp edx, SLOT_ACCENT
    je .sample_accent
    cmp edx, SLOT_TEXT
    je .sample_text
    cmp edx, SLOT_DIM
    je .sample_dim
    cmp edx, SLOT_OK
    je .sample_ok
    cmp edx, SLOT_WARN
    je .sample_warn
    cmp edx, SLOT_ERR
    je .sample_err
    cmp edx, SLOT_CAT
    je .sample_cat
    cmp edx, SLOT_BAR_FULL
    je .sample_bar_full
    cmp edx, SLOT_BAR_EMPTY
    je .sample_bar_empty
    cmp edx, SLOT_HIGHLIGHT
    je .sample_highlight

    jmp .sample_done

.sample_border:
    mov al, SLOT_BORDER
    call ui_color
    mov al, '+'
    call buf_char
    mov al, '-'
    mov ecx, 24
    call buf_repeat
    mov al, '+'
    call buf_char
    jmp .sample_done

.sample_title:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, title_settings
    call buf_str
    jmp .sample_done

.sample_accent:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, settings_sample_accent
    call buf_str
    jmp .sample_done

.sample_text:
    mov al, SLOT_TEXT
    call ui_color
    mov esi, settings_sample_text
    call buf_str
    jmp .sample_done

.sample_dim:
    mov al, SLOT_DIM
    call ui_color
    mov esi, habit_msg_empty
    call buf_str
    jmp .sample_done

.sample_ok:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_OK
    call ui_color
    mov esi, settings_sample_ok
    call buf_str
    jmp .sample_done

.sample_warn:
    mov al, SLOT_WARN
    call ui_color
    mov esi, settings_sample_warn
    call buf_str
    jmp .sample_done

.sample_err:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ERR
    call ui_color
    mov esi, settings_sample_err
    call buf_str
    jmp .sample_done

.sample_cat:
    mov al, SLOT_CAT
    call ui_color
    mov esi, cat_p0_l1
    call buf_str
    mov al, ' '
    call buf_char
    mov esi, cat_p0_l2
    call buf_str
    jmp .sample_done

.sample_bar_full:
    mov al, '['
    call buf_char
    mov al, SLOT_BAR_FULL
    call ui_color
    mov al, '#'
    mov ecx, 15
    call buf_repeat
    mov esi, ansi_reset
    call buf_str
    mov al, '-'
    mov ecx, 15
    call buf_repeat
    mov al, ']'
    call buf_char
    jmp .sample_done

.sample_bar_empty:
    mov al, '['
    call buf_char
    mov al, '#'
    mov ecx, 15
    call buf_repeat
    mov al, SLOT_BAR_EMPTY
    call ui_color
    mov al, '-'
    mov ecx, 15
    call buf_repeat
    mov esi, ansi_reset
    call buf_str
    mov al, ']'
    call buf_char
    jmp .sample_done

.sample_highlight:
    mov al, SLOT_HIGHLIGHT
    call ui_bgcolor
    mov esi, ansi_reverse
    call buf_str
    mov al, ' '
    call buf_char
    mov esi, title_journal
    call buf_str
    mov al, ' '
    call buf_char
    mov esi, ansi_reset
    call buf_str

.sample_done:
    mov esi, ansi_reset
    call buf_str

    ; Status Message at Row 21 (Col 4)
    mov eax, 21
    mov ebx, [settings_status_style]
    mov esi, [settings_status_msg]
    call ui_draw_status

    ; Key Help Footer at Row 22 (Col 4)
    mov eax, 22
    mov ebx, 4
    mov esi, settings_help_colors
    call ui_text_at

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: settings_colors_handle_key
; Purpose:   Processes keystrokes in the Dedicated Color Editor:
;            - Up/Down/Home/End selects the color slot (0..11)
;            - Left/Right increments/decrements color index by 1 (clamped 0..255)
;            - PgUp/PgDn increments/decrements color index by 16 (clamped 0..255)
;            - B/Esc returns to Main Settings
;            Automatically switches theme to Custom (theme 7) on mutation.
; IN:        EAX = Key code (ASCII or KEY_*)
; OUT:       None (updates custom/active palette and persists via settings_save)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_colors_handle_key:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Slot Navigation: Up Arrow / 'K'
    cmp eax, KEY_UP
    je .c_nav_up
    cmp eax, 'K'
    je .c_nav_up

    ; Slot Navigation: Down Arrow / 'J'
    cmp eax, KEY_DOWN
    je .c_nav_down
    cmp eax, 'J'
    je .c_nav_down

    ; Slot Navigation: Home
    cmp eax, KEY_HOME
    je .c_nav_home

    ; Slot Navigation: End
    cmp eax, KEY_END
    je .c_nav_end

    ; Color Adjustment: Left Arrow / 'H' (-1)
    cmp eax, KEY_LEFT
    je .c_color_dec1
    cmp eax, 'H'
    je .c_color_dec1

    ; Color Adjustment: Right Arrow / 'L' (+1)
    cmp eax, KEY_RIGHT
    je .c_color_inc1
    cmp eax, 'L'
    je .c_color_inc1

    ; Color Adjustment: PgUp (+16)
    cmp eax, KEY_PGUP
    je .c_color_inc16

    ; Color Adjustment: PgDn (-16)
    cmp eax, KEY_PGDN
    je .c_color_dec16

    ; Return: 'B' or Esc
    cmp eax, KEY_B
    je .c_return_settings
    cmp eax, KEY_ESC
    je .c_return_settings

    jmp .c_key_done

.c_nav_up:
    mov edx, [settings_color_slot]
    test edx, edx
    jz .c_wrap_to_bottom
    dec dword [settings_color_slot]
    jmp .c_key_done
.c_wrap_to_bottom:
    mov dword [settings_color_slot], (NUM_SLOTS - 1)
    jmp .c_key_done

.c_nav_down:
    mov edx, [settings_color_slot]
    cmp edx, (NUM_SLOTS - 1)
    jae .c_wrap_to_top
    inc dword [settings_color_slot]
    jmp .c_key_done
.c_wrap_to_top:
    mov dword [settings_color_slot], 0
    jmp .c_key_done

.c_nav_home:
    mov dword [settings_color_slot], 0
    jmp .c_key_done

.c_nav_end:
    mov dword [settings_color_slot], (NUM_SLOTS - 1)
    jmp .c_key_done

.c_color_dec1:
    mov edx, [settings_color_slot]
    movzx eax, byte [active_palette + edx]
    test eax, eax
    jz .c_key_done              ; Clamped at 0
    dec al
    call settings_apply_slot_color
    jmp .c_key_done

.c_color_inc1:
    mov edx, [settings_color_slot]
    movzx eax, byte [active_palette + edx]
    cmp eax, COLOR_256_MAX      ; 255
    jae .c_key_done             ; Clamped at 255
    inc al
    call settings_apply_slot_color
    jmp .c_key_done

.c_color_inc16:
    mov edx, [settings_color_slot]
    movzx eax, byte [active_palette + edx]
    add eax, COLOR_STEP_PG      ; +16
    cmp eax, COLOR_256_MAX
    jbe .apply_inc16
    mov al, COLOR_256_MAX       ; Clamp to 255
.apply_inc16:
    call settings_apply_slot_color
    jmp .c_key_done

.c_color_dec16:
    mov edx, [settings_color_slot]
    movzx eax, byte [active_palette + edx]
    sub eax, COLOR_STEP_PG      ; -16
    jns .apply_dec16
    xor al, al                  ; Clamp to 0
.apply_dec16:
    call settings_apply_slot_color
    jmp .c_key_done

.c_return_settings:
    mov dword [settings_view_mode], SETTINGS_MODE_MAIN

.c_key_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_apply_slot_color
; Purpose:   Applies new 256-color byte AL to the currently selected slot.
;            If the current theme is built-in (0..6), copies active_palette
;            into custom_palette first and sets theme to Custom (7).
;            Persists change to disk immediately via settings_mutate_and_save.
; IN:        AL = New 256-color index (0..255)
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
settings_apply_slot_color:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov bl, al                  ; BL = new color byte

    ; Check if current theme is Custom (7)
    cmp byte [setting_theme], THEME_CUSTOM_INDEX
    je .already_custom

    ; Transitioning from built-in to custom:
    ; Copy current active_palette into custom_palette first
    mov esi, active_palette
    mov edi, custom_palette
    mov ecx, 3                  ; 3 dwords = 12 bytes
    rep movsd

    ; Set theme to Custom (7)
    mov byte [setting_theme], THEME_CUSTOM_INDEX

.already_custom:
    ; Update both custom_palette and active_palette at slot index
    mov edx, [settings_color_slot]
    mov [custom_palette + edx], bl
    mov [active_palette + edx], bl

    ; Persist to disk immediately
    call settings_mutate_and_save

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_confirm_draw
; Purpose:   Renders the Reset-to-Defaults Confirmation Modal Dialog.
; IN:        None
; OUT:       Appends confirmation prompt to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_confirm_draw:
    save_regs
    push eax

    ; Draw standard settings background
    call settings_draw

    ; Overlay Confirmation Dialog at (Screen Row 20, Col 4)
    mov eax, 20
    mov ebx, 4
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_WARN
    call ui_color
    mov esi, settings_confirm_prompt
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Overlay Confirmation Key Help at (Screen Row 21, Col 4)
    mov eax, 21
    mov ebx, 4
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, settings_help_confirm
    call buf_str
    mov esi, ansi_reset
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: settings_confirm_handle_key
; Purpose:   Processes keystrokes for the Reset Confirmation prompt:
;            - 'Y' / 'y' confirms reset: calls settings_set_defaults and saves
;            - 'N' / 'n' / Esc / B / any other key cancels without reset
; IN:        EAX = Key code
; OUT:       None (view mode returned to SETTINGS_MODE_MAIN)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_confirm_handle_key:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    cmp eax, 'Y'
    je .confirm_yes
    cmp eax, 'y'
    je .confirm_yes

    ; Any other key cancels
    mov dword [settings_view_mode], SETTINGS_MODE_MAIN
    jmp .confirm_done

.confirm_yes:
    ; Restore exact PRD_V2 defaults
    call settings_set_defaults

    ; Persist to disk immediately
    call settings_mutate_and_save

    ; Return to main view
    mov dword [settings_view_mode], SETTINGS_MODE_MAIN

.confirm_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_run
; Purpose:   Master lifecycle and runner loop for STATE_SETTINGS.
;            Handles redrawing, non-blocking 50 ms polling, terminal dimension
;            checks, sub-view dispatching (Main, Color Editor, Confirm),
;            and clean exit paths.
; IN:        None
; OUT:       None (returns when exiting to STATE_MENU or sets STATE_QUIT)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_run:
    save_regs

    ; Set application state to STATE_SETTINGS
    mov dword [state], STATE_SETTINGS

    ; Initialize state on entry
    mov dword [settings_sel_row], 0
    mov dword [settings_view_mode], SETTINGS_MODE_MAIN
    mov dword [settings_color_slot], 0
    mov dword [settings_status_msg], 0
    mov dword [settings_status_style], STATUS_OK
    mov dword [need_redraw], 1

.settings_loop:
    ; Redraw if needed
    cmp dword [need_redraw], 0
    je .settings_wait_key

    ; Dispatch view renderer
    mov eax, [settings_view_mode]
    cmp eax, SETTINGS_MODE_COLORS
    je .draw_colors
    cmp eax, SETTINGS_MODE_CONFIRM
    je .draw_confirm

    ; Default: Main Settings View
    call settings_draw
    jmp .flush_frame

.draw_colors:
    call settings_colors_draw
    jmp .flush_frame

.draw_confirm:
    call settings_confirm_draw

.flush_frame:
    ; Flush complete frame with a single sys_write
    call buf_flush
    mov dword [need_redraw], 0

.settings_wait_key:
    ; Low-CPU sleep loop (50 ms) checking terminal size and polling input
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_50MS
    syscall SYS_NANOSLEEP, timespec, 0

    ; Check terminal size
    call term_size_ok
    test eax, eax
    jz .size_changed
    mov edx, [term_cols]
    cmp edx, [ui_seen_cols]
    jne .size_changed
    mov edx, [term_rows]
    cmp edx, [ui_seen_rows]
    jne .size_changed

    call key_poll
    cmp eax, KEY_NONE
    je .settings_wait_key
    jmp .dispatch_key

.size_changed:
    mov dword [need_redraw], 1
    jmp .settings_loop

.dispatch_key:
    ; Global exit: Ctrl+C always exits cleanly to shell
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c

    ; Dispatch key handling by current sub-view mode
    mov edx, [settings_view_mode]
    cmp edx, SETTINGS_MODE_COLORS
    je .handle_colors_key
    cmp edx, SETTINGS_MODE_CONFIRM
    je .handle_confirm_key

    ; Main Settings Key Handler
    call settings_handle_key

    ; Check if handle_key requested returning to menu
    cmp dword [state], STATE_MENU
    je .settings_exit

    mov dword [need_redraw], 1
    jmp .settings_loop

.handle_colors_key:
    call settings_colors_handle_key
    mov dword [need_redraw], 1
    jmp .settings_loop

.handle_confirm_key:
    call settings_confirm_handle_key
    mov dword [need_redraw], 1
    jmp .settings_loop

.key_ctrl_c:
    mov dword [state], STATE_QUIT

.settings_exit:
    restore_regs
    ret
