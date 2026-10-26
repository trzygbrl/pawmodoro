; =============================================================================
; Pawmodoro - v3 Terminal Widget Library (src/widgets.asm)
;
; Purpose: Reusable rectangle-based terminal UI widgets adhering to PRD_V3
;          and Milestone G6 specifications.
; Requirements:
;   - Strict bounding rectangle clipping.
;   - Theme-slot usage (24 slots, no hardcoded colors).
;   - Both UTF-8 and strict 7-bit ASCII fallback support.
;   - Non-color visual state differentiation (focus, pressed, checked, etc.).
;   - Buffer-safe, zero dynamic memory allocation, single sys_write flush.
; Register Discipline: PRD §6.2 (all procedures preserve all general registers
;                      and EFLAGS unless explicitly documented).
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES
; =============================================================================

;=============================================================================
; Procedure: wdg_clip_text
; Purpose:   Positions cursor at (row, col) in absolute terminal coordinates,
;            applies foreground and background theme slots, and emits text
;            clipped to max_w columns. Guarantees no writing past terminal
;            or widget rectangle boundaries.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Maximum column budget
;            ESI = Pointer to NUL-terminated text string
;            DL  = Foreground theme slot (0xFF = skip)
;            DH  = Background theme slot (0xFF = skip)
; OUT:       Appends color escapes and text to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_clip_text:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate row and column against terminal bounds
    test ecx, ecx
    jle .clip_exit
    test esi, esi
    jz .clip_exit
    cmp eax, 1
    jl .clip_exit
    cmp eax, [term_rows]
    jg .clip_exit
    cmp ebx, 1
    jl .clip_exit
    cmp ebx, [term_cols]
    jg .clip_exit

    ; Clip max_w if col + max_w - 1 exceeds term_cols
    mov edi, [term_cols]
    sub edi, ebx
    inc edi                     ; EDI = available columns to right of terminal
    cmp ecx, edi
    jle .clip_col_ok
    mov ecx, edi
.clip_col_ok:
    test ecx, ecx
    jle .clip_exit

    ; Position cursor at (row, col)
    call buf_goto

    ; Apply background color if DH != 0xFF
    cmp dh, 0xFF
    je .clip_check_fg
    push eax
    mov al, dh
    call gfx_set_bg
    pop eax

.clip_check_fg:
    ; Apply foreground color if DL != 0xFF
    cmp dl, 0xFF
    je .clip_emit_loop
    push eax
    mov al, dl
    call gfx_set_fg
    pop eax

.clip_emit_loop:
    ; Loop emitting characters up to ECX bytes or NUL
    ; If string is longer than ECX, emit UI_CLIP_MARKER '~' on last cell
.clip_char:
    movzx eax, byte [esi]
    test al, al
    jz .clip_exit               ; End of string

    cmp ecx, 1
    jne .emit_normal
    ; On the last allowed column, check if there are more characters left in string
    cmp byte [esi + 1], 0
    je .emit_normal
    mov al, UI_CLIP_MARKER      ; '~' clipping indicator

.emit_normal:
    ; Strict ASCII check if setting_charset == 1
    cmp byte [setting_charset], 1
    jne .do_buf_char
    cmp al, 0x80
    jb .do_buf_char
    mov al, CHAR_QUESTION       ; '?' replacement for unexpected high bytes in ASCII mode

.do_buf_char:
    call buf_char
    inc esi
    dec ecx
    jnz .clip_char

.clip_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_panel
; Purpose:   Draws a reusable panel with rounded borders, surface background
;            fill, optional title tab, focus styling, and optional shadow.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Rectangle width in cells
;            EDX = Rectangle height in rows
;            ESI = Pointer to title tab string (or 0 if none)
;            EDI = Flags bitmask (WDG_PANEL_FLAG_TAB, FOCUS, SHADOW)
; OUT:       Appends panel drawing to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_panel:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs into dedicated BSS working variables
    mov [wdg_p_row], eax
    mov [wdg_p_col], ebx
    mov [wdg_p_w], ecx
    mov [wdg_p_h], edx
    mov [wdg_p_title], esi
    mov [wdg_p_flags], edi

    ; Sanity check dimensions
    cmp ecx, 2
    jl .panel_exit
    cmp edx, 2
    jl .panel_exit

    ; Determine border slot: focused -> SLOT_BORDER_FOCUS, normal -> SLOT_BORDER
    mov dword [wdg_p_border], SLOT_BORDER
    test edi, WDG_PANEL_FLAG_FOCUS
    jz .border_slot_ok
    mov dword [wdg_p_border], SLOT_BORDER_FOCUS
.border_slot_ok:

    ; -------------------------------------------------------------------------
    ; 1. Draw Top Border: ╭────────────╮ (or +------------+)
    ; -------------------------------------------------------------------------
    mov eax, [wdg_p_row]
    mov ebx, [wdg_p_col]
    call buf_goto

    ; Set border color and background
    mov eax, [wdg_p_border]
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg

    ; Top-left corner
    cmp byte [setting_charset], 1
    je .top_l_ascii
    mov esi, glyph_utf8_corner_tl ; ╭
    call buf_str
    jmp .top_mid
.top_l_ascii:
    mov al, CHAR_PLUS           ; +
    call buf_char

.top_mid:
    mov ecx, [wdg_p_w]
    mov esi, [wdg_p_title]
    test dword [wdg_p_flags], WDG_PANEL_FLAG_TAB
    jz .top_dashes_plain
    test esi, esi
    jz .top_dashes_plain
    cmp ecx, 8                  ; Need at least 8 cells for title tab
    jl .top_dashes_plain

    ; --- Title Tab Mode ---
    ; Calculate max allowable title length: width - 6
    mov edx, ecx
    sub edx, 6
    jle .top_dashes_plain

    ; Count actual title length until null or clamped at edx
    xor ecx, ecx
.title_len_loop:
    cmp byte [esi + ecx], 0
    jz .title_len_done
    inc ecx
    cmp ecx, edx
    jb .title_len_loop
.title_len_done:
    ; ecx is title length to print (<= width - 6)
    push ecx                    ; [esp] = title length

    ; 1 dash before tab
    cmp byte [setting_charset], 1
    je .tab_dash_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x80                ; ─
    call buf_char
    jmp .tab_bracket_start
.tab_dash_ascii:
    mov al, CHAR_MINUS
    call buf_char

.tab_bracket_start:
    ; Emit tab open
    cmp byte [setting_charset], 1
    je .tab_open_ascii
    mov esi, glyph_utf8_tee_right ; ┤
    call buf_str
    jmp .tab_title_text
.tab_open_ascii:
    mov al, CHAR_LBRACKET       ; [
    call buf_char

.tab_title_text:
    ; Emit title text
    mov al, SLOT_TITLE
    call gfx_set_fg
    mov esi, [wdg_p_title]
    mov ecx, [esp]              ; chars to print
    test ecx, ecx
    jz .tab_title_printed
.title_print_loop:
    lodsb
    call buf_char
    dec ecx
    jnz .title_print_loop
.tab_title_printed:

    ; Emit tab close
    mov eax, [wdg_p_border]
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .tab_close_ascii
    mov esi, glyph_utf8_tee_left ; ├
    call buf_str
    jmp .tab_calc_rem
.tab_close_ascii:
    mov al, CHAR_RBRACKET       ; ]
    call buf_char

.tab_calc_rem:
    ; Pop title length
    pop ecx                     ; ecx = title length printed
    ; Columns printed so far: 1 (corner) + 1 (dash) + 1 (open) + ecx (title) + 1 (close) = ecx + 4.
    ; Top-right corner will take 1 column.
    ; Remaining dashes = wdg_p_w - (ecx + 4) - 1 = wdg_p_w - ecx - 5.
    mov eax, [wdg_p_w]
    sub eax, ecx
    sub eax, 5
    cmp eax, 0
    jle .top_right_corner
    mov ecx, eax
    jmp .top_emit_rem_dashes

.top_dashes_plain:
    sub ecx, 2                  ; inner width
    jbe .top_right_corner

.top_emit_rem_dashes:
    cmp byte [setting_charset], 1
    je .top_dashes_ascii
.top_dashes_utf8:
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x80                ; ─
    call buf_char
    dec ecx
    jnz .top_dashes_utf8
    jmp .top_right_corner

.top_dashes_ascii:
    mov al, CHAR_MINUS
    call buf_repeat

.top_right_corner:
    cmp byte [setting_charset], 1
    je .top_r_ascii
    mov esi, glyph_utf8_corner_tr ; ╮
    call buf_str
    jmp .top_done
.top_r_ascii:
    mov al, CHAR_PLUS
    call buf_char

.top_done:

    ; -------------------------------------------------------------------------
    ; 2. Draw Middle Rows: │ <surface spaces> │
    ; -------------------------------------------------------------------------
    mov eax, [wdg_p_row]
    mov edx, [wdg_p_h]
    dec edx
    dec edx
    jle .mid_done

.mid_row_loop:
    inc eax                     ; advance row
    push eax
    push edx

    mov ebx, [wdg_p_col]
    call buf_goto

    ; Left border
    mov eax, [wdg_p_border]
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg
    cmp byte [setting_charset], 1
    je .mid_l_ascii
    mov esi, glyph_utf8_vline   ; │
    call buf_str
    jmp .mid_fill
.mid_l_ascii:
    mov al, CHAR_PIPE           ; |
    call buf_char

.mid_fill:
    ; Surface fill
    mov al, CHAR_SPACE
    mov ecx, [wdg_p_w]
    sub ecx, 2
    jle .mid_r_border
    call buf_repeat
.mid_r_border:

    ; Right border
    mov eax, [wdg_p_border]
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .mid_r_ascii
    mov esi, glyph_utf8_vline   ; │
    call buf_str
    jmp .mid_row_next
.mid_r_ascii:
    mov al, CHAR_PIPE
    call buf_char

.mid_row_next:
    pop edx
    pop eax
    dec edx
    jnz .mid_row_loop

.mid_done:

    ; -------------------------------------------------------------------------
    ; 3. Draw Bottom Border: ╰────────────╯ (or +------------+)
    ; -------------------------------------------------------------------------
    mov eax, [wdg_p_row]
    add eax, [wdg_p_h]
    dec eax                     ; Bottom row = row + h - 1
    mov ebx, [wdg_p_col]
    call buf_goto

    mov eax, [wdg_p_border]
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg

    ; Bottom-left corner
    cmp byte [setting_charset], 1
    je .bot_l_ascii
    mov esi, glyph_utf8_corner_bl ; ╰
    call buf_str
    jmp .bot_mid
.bot_l_ascii:
    mov al, CHAR_PLUS
    call buf_char

.bot_mid:
    mov ecx, [wdg_p_w]
    sub ecx, 2
    jle .bot_r_corner
    cmp byte [setting_charset], 1
    je .bot_dashes_ascii
.bot_dashes_utf8:
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x80                ; ─
    call buf_char
    dec ecx
    jnz .bot_dashes_utf8
    jmp .bot_r_corner
.bot_dashes_ascii:
    mov al, CHAR_MINUS
    call buf_repeat

.bot_r_corner:
    cmp byte [setting_charset], 1
    je .bot_r_ascii
    mov esi, glyph_utf8_corner_br ; ╯
    call buf_str
    jmp .bot_done
.bot_r_ascii:
    mov al, CHAR_PLUS
    call buf_char

.bot_done:

    ; -------------------------------------------------------------------------
    ; 4. Optional Subtle Drop Shadow (WDG_PANEL_FLAG_SHADOW)
    ; -------------------------------------------------------------------------
    test dword [wdg_p_flags], WDG_PANEL_FLAG_SHADOW
    jz .panel_exit

    ; Right shadow column: col = col + w
    mov esi, [wdg_p_col]
    add esi, [wdg_p_w]
    cmp esi, [term_cols]
    ja .panel_exit              ; Off terminal: skip shadow

    mov al, SLOT_BG
    call gfx_set_fg
    call gfx_set_bg

    mov eax, [wdg_p_row]
    inc eax                     ; Start at row + 1
    mov edx, [wdg_p_h]
    dec edx                     ; Height rows
.shadow_v_loop:
    cmp eax, [term_rows]
    ja .shadow_v_done
    mov ebx, esi
    call buf_goto
    mov al, CHAR_SPACE
    call buf_char
    inc eax
    dec edx
    jnz .shadow_v_loop
.shadow_v_done:

.panel_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_card
; Purpose:   Draws a smaller panel with a title and content area.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to title string
;            EDI = Surface theme slot (e.g. SLOT_SURFACE_ALT)
; OUT:       Appends card drawing to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_card:
    pushf
    push edi
    mov edi, WDG_PANEL_FLAG_TAB
    call wdg_panel
    pop edi
    popf
    ret

;=============================================================================
; Procedure: wdg_button
; Purpose:   Draws a button containing an optional icon sprite and text label.
;            Supports normal, focused (highlight fill + text inversion + visible
;            marker '>'), and pressed ('['..']' brackets) states.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Button width
;            EDX = Button height
;            ESI = Pointer to icon sprite descriptor (or 0 if none)
;            EDI = Pointer to label text string
;            EBP = Button state (WDG_STATE_NORMAL, FOCUSED, PRESSED)
; OUT:       Appends button to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_button:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs into BSS
    mov [wdg_b_row], eax
    mov [wdg_b_col], ebx
    mov [wdg_b_w], ecx
    mov [wdg_b_h], edx
    mov [wdg_b_icon], esi
    mov [wdg_b_label], edi
    mov [wdg_b_state], ebp

    ; Validate bounds
    cmp ecx, 4
    jl .btn_exit
    cmp edx, 1
    jl .btn_exit

    ; Determine colors and indicator based on state
    mov dl, SLOT_TEXT           ; Default text FG
    mov dh, SLOT_SURFACE        ; Default BG
    mov ch, SLOT_BORDER         ; Default border slot
    cmp ebp, WDG_STATE_FOCUSED
    je .btn_focused
    cmp ebp, WDG_STATE_PRESSED
    je .btn_pressed
    jmp .btn_colors_set

.btn_focused:
    mov dl, SLOT_TEXT_INV
    mov dh, SLOT_HIGHLIGHT
    mov ch, SLOT_BORDER_FOCUS
    jmp .btn_colors_set

.btn_pressed:
    mov dl, SLOT_ACCENT
    mov dh, SLOT_SURFACE
    mov ch, SLOT_ACCENT

.btn_colors_set:
    ; Check if 3-row bordered pill button (height >= 3)
    cmp dword [wdg_b_h], 3
    jge .btn_draw_3row

    ; -------------------------------------------------------------------------
    ; Single-Row Compact Button (height < 3)
    ; -------------------------------------------------------------------------
    mov eax, [wdg_b_row]
    mov ebx, [wdg_b_col]
    mov ecx, [wdg_b_w]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_repeat

    mov eax, [wdg_b_row]
    mov ebx, [wdg_b_col]
    mov ecx, [wdg_b_w]
    call buf_goto
    mov al, dl
    call gfx_set_fg
    cmp ebp, WDG_STATE_FOCUSED
    jne .b1_check_pressed
    mov al, '>'                 ; Focused marker
    call buf_char
    inc ebx
    dec ecx
    jmp .btn_draw_icon_label

.b1_check_pressed:
    cmp ebp, WDG_STATE_PRESSED
    jne .b1_normal
    mov al, CHAR_LBRACKET       ; '['
    call buf_char
    inc ebx
    dec ecx
    jmp .btn_draw_icon_label

.b1_normal:
    mov al, CHAR_SPACE
    call buf_char
    inc ebx
    dec ecx
    jmp .btn_draw_icon_label

    ; -------------------------------------------------------------------------
    ; 3-Row Bordered Pill Button (height >= 3)
    ; -------------------------------------------------------------------------
.btn_draw_3row:
    ; Row 0: Top border
    mov eax, [wdg_b_row]
    mov ebx, [wdg_b_col]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, ch                  ; Border slot
    call gfx_set_fg

    cmp byte [setting_charset], 1
    je .b3_top_ascii
    mov esi, glyph_utf8_corner_tl ; ╭
    call buf_str
    mov ecx, [wdg_b_w]
    sub ecx, 2
    jle .b3_top_r
.b3_top_dash:
    mov esi, glyph_utf8_hline  ; ─
    call buf_str
    dec ecx
    jnz .b3_top_dash
.b3_top_r:
    mov esi, glyph_utf8_corner_tr ; ╮
    call buf_str
    jmp .b3_draw_mid

.b3_top_ascii:
    mov al, CHAR_PLUS
    call buf_char
    mov ecx, [wdg_b_w]
    sub ecx, 2
    jle .b3_top_r_asc
    mov al, CHAR_MINUS
    call buf_repeat
.b3_top_r_asc:
    mov al, CHAR_PLUS
    call buf_char

.b3_draw_mid:
    ; Row 1: Middle content row
    mov eax, [wdg_b_row]
    inc eax
    mov ebx, [wdg_b_col]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, ch                  ; Border slot
    call gfx_set_fg

    cmp byte [setting_charset], 1
    je .b3_mid_l_asc
    mov esi, glyph_utf8_vline  ; │
    call buf_str
    jmp .b3_mid_content
.b3_mid_l_asc:
    mov al, CHAR_PIPE
    call buf_char

.b3_mid_content:
    ; Clear middle interior with dh background spaces
    mov eax, [wdg_b_row]
    inc eax
    mov ebx, [wdg_b_col]
    inc ebx
    call buf_goto
    mov ecx, [wdg_b_w]
    sub ecx, 2
    mov al, dh
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_repeat

    ; Right border of middle row
    mov eax, [wdg_b_row]
    inc eax
    mov ebx, [wdg_b_col]
    add ebx, [wdg_b_w]
    dec ebx
    call buf_goto
    mov al, ch                  ; Border slot
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .b3_mid_r_asc
    mov esi, glyph_utf8_vline
    call buf_str
    jmp .b3_draw_bot
.b3_mid_r_asc:
    mov al, CHAR_PIPE
    call buf_char

.b3_draw_bot:
    ; Row 2: Bottom border
    mov eax, [wdg_b_row]
    add eax, 2
    mov ebx, [wdg_b_col]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, ch                  ; Border slot
    call gfx_set_fg

    cmp byte [setting_charset], 1
    je .b3_bot_ascii
    mov esi, glyph_utf8_corner_bl ; ╰
    call buf_str
    mov ecx, [wdg_b_w]
    sub ecx, 2
    jle .b3_bot_r
.b3_bot_dash:
    mov esi, glyph_utf8_hline  ; ─
    call buf_str
    dec ecx
    jnz .b3_bot_dash
.b3_bot_r:
    mov esi, glyph_utf8_corner_br ; ╯
    call buf_str
    jmp .b3_emit_inner

.b3_bot_ascii:
    mov al, CHAR_PLUS
    call buf_char
    mov ecx, [wdg_b_w]
    sub ecx, 2
    jle .b3_bot_r_asc
    mov al, CHAR_MINUS
    call buf_repeat
.b3_bot_r_asc:
    mov al, CHAR_PLUS
    call buf_char

.b3_emit_inner:
    ; Setup cursor on Row 1 (row + 1) at col + 1 for icon and text
    mov eax, [wdg_b_row]
    inc eax
    mov [wdg_b_row], eax        ; Advance effective row to inner content row
    mov ebx, [wdg_b_col]
    inc ebx                     ; Inside left border
    mov ecx, [wdg_b_w]
    sub ecx, 2                  ; Inside right border
    call buf_goto
    mov al, dl
    call gfx_set_fg
    cmp ebp, WDG_STATE_FOCUSED
    jne .b3_check_pressed
    mov al, '>'
    call buf_char
    inc ebx
    dec ecx
    jmp .btn_draw_icon_label

.b3_check_pressed:
    cmp ebp, WDG_STATE_PRESSED
    jne .b3_normal_inner
    mov al, CHAR_LBRACKET
    call buf_char
    inc ebx
    dec ecx
    jmp .btn_draw_icon_label

.b3_normal_inner:
    mov al, CHAR_SPACE
    call buf_char
    inc ebx
    dec ecx

.btn_draw_icon_label:
    ; Draw icon sprite if icon != 0 and width >= 10 and height >= 2
    mov esi, [wdg_b_icon]
    test esi, esi
    jz .btn_label_only
    cmp ecx, 10
    jl .btn_label_only
    cmp dword [wdg_b_h], 2
    jl .btn_label_only

    ; Calculate frame-relative col for sprite_draw: col_abs - [ui_col0]
    push ebx
    sub ebx, [ui_col0]
    push ecx
    push edx
    mov eax, [wdg_b_row]
    xor ecx, ecx                ; frame 0
    movzx edx, dh               ; fill bg slot
    call sprite_draw
    pop edx
    pop ecx
    pop ebx

    ; Advance past icon (5 cells)
    add ebx, 5
    sub ecx, 5
    cmp ecx, 2
    jl .btn_check_pressed_close

.btn_label_only:
    ; Draw label text clipped to remaining width
    mov eax, [wdg_b_row]
    mov esi, [wdg_b_label]
    call wdg_clip_text

.btn_check_pressed_close:
    ; If pressed state, emit closing ']' at right edge
    cmp dword [wdg_b_state], WDG_STATE_PRESSED
    jne .btn_exit
    mov eax, [wdg_b_row]
    mov ebx, [wdg_b_col]
    add ebx, [wdg_b_w]
    dec ebx
    call buf_goto
    mov al, SLOT_ACCENT
    call gfx_set_fg
    mov al, CHAR_RBRACKET       ; ']'
    call buf_char

.btn_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_toggle
; Purpose:   Draws a label and toggle switch (ON/OFF) state.
;            Uses sprite_widget_toggle in UTF-8, and [ OFF] / [ ON ] in ASCII.
;            Supports focus highlight when EBP == WDG_STATE_FOCUSED.
;            Both states distinguishable without color.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to label string
;            EDI = Toggle state (0 = OFF, 1 = ON)
;            EBP = Focus state (WDG_STATE_NORMAL / FOCUSED)
; OUT:       Appends toggle widget to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_toggle:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs
    mov [wdg_t_row], eax
    mov [wdg_t_col], ebx
    mov [wdg_t_w], ecx
    mov [wdg_t_h], edx
    mov [wdg_t_label], esi
    mov [wdg_t_state], edi

    ; Validate bounds
    cmp ecx, 10
    jl .tog_exit
    cmp edx, 1
    jl .tog_exit

    ; Determine colors
    mov dl, SLOT_TEXT
    mov dh, SLOT_SURFACE
    mov ch, SLOT_BORDER
    cmp ebp, WDG_STATE_FOCUSED
    jne .tog_colors_set
    mov dl, SLOT_TEXT_INV
    mov dh, SLOT_HIGHLIGHT
    mov ch, SLOT_BORDER_FOCUS

.tog_colors_set:
    ; Check if 3-row bordered card (height >= 3)
    cmp dword [wdg_t_h], 3
    jl .tog_draw_1row

    ; --- 3-Row Bordered Toggle Card ---
    ; Row 0: Top border
    mov eax, [wdg_t_row]
    mov ebx, [wdg_t_col]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, ch
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .tog3_top_asc
    mov esi, glyph_utf8_corner_tl
    call buf_str
    mov ecx, [wdg_t_w]
    sub ecx, 2
.tog3_top_dash:
    mov esi, glyph_utf8_hline
    call buf_str
    dec ecx
    jnz .tog3_top_dash
    mov esi, glyph_utf8_corner_tr
    call buf_str
    jmp .tog3_mid
.tog3_top_asc:
    mov al, CHAR_PLUS
    call buf_char
    mov ecx, [wdg_t_w]
    sub ecx, 2
    mov al, CHAR_MINUS
    call buf_repeat
    mov al, CHAR_PLUS
    call buf_char

.tog3_mid:
    ; Row 1: Middle interior
    mov eax, [wdg_t_row]
    inc eax
    mov ebx, [wdg_t_col]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, ch
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .tog3_mid_l_asc
    mov esi, glyph_utf8_vline
    call buf_str
    jmp .tog3_mid_fill
.tog3_mid_l_asc:
    mov al, CHAR_PIPE
    call buf_char

.tog3_mid_fill:
    mov eax, [wdg_t_row]
    inc eax
    mov ebx, [wdg_t_col]
    inc ebx
    call buf_goto
    mov ecx, [wdg_t_w]
    sub ecx, 2
    mov al, dh
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_repeat

    ; Right border on mid row
    mov eax, [wdg_t_row]
    inc eax
    mov ebx, [wdg_t_col]
    add ebx, [wdg_t_w]
    dec ebx
    call buf_goto
    mov al, ch
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .tog3_mid_r_asc
    mov esi, glyph_utf8_vline
    call buf_str
    jmp .tog3_bot
.tog3_mid_r_asc:
    mov al, CHAR_PIPE
    call buf_char

.tog3_bot:
    ; Row 2: Bottom border
    mov eax, [wdg_t_row]
    add eax, 2
    mov ebx, [wdg_t_col]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, ch
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .tog3_bot_asc
    mov esi, glyph_utf8_corner_bl
    call buf_str
    mov ecx, [wdg_t_w]
    sub ecx, 2
.tog3_bot_dash:
    mov esi, glyph_utf8_hline
    call buf_str
    dec ecx
    jnz .tog3_bot_dash
    mov esi, glyph_utf8_corner_br
    call buf_str
    jmp .tog3_content
.tog3_bot_asc:
    mov al, CHAR_PLUS
    call buf_char
    mov ecx, [wdg_t_w]
    sub ecx, 2
    mov al, CHAR_MINUS
    call buf_repeat
    mov al, CHAR_PLUS
    call buf_char

.tog3_content:
    ; Advance target row to row + 1, col to col + 1, w to w - 2
    mov eax, [wdg_t_row]
    inc eax
    mov [wdg_t_row], eax
    mov ebx, [wdg_t_col]
    inc ebx
    mov [wdg_t_col], ebx
    mov ecx, [wdg_t_w]
    sub ecx, 2
    mov [wdg_t_w], ecx
    jmp .tog_render_inner

.tog_draw_1row:
    ; Single-row toggle background fill
    mov eax, [wdg_t_row]
    mov ebx, [wdg_t_col]
    mov ecx, [wdg_t_w]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_repeat

.tog_render_inner:
    ; Draw focus marker '>' if focused
    cmp ebp, WDG_STATE_FOCUSED
    jne .tog_no_focus_marker
    mov eax, [wdg_t_row]
    mov ebx, [wdg_t_col]
    call buf_goto
    mov al, dl
    call gfx_set_fg
    mov al, '>'
    call buf_char
    inc dword [wdg_t_col]
    dec dword [wdg_t_w]

.tog_no_focus_marker:
    ; 1. Draw Label text on left
    mov eax, [wdg_t_row]
    mov ebx, [wdg_t_col]
    mov ecx, [wdg_t_w]
    sub ecx, 8                  ; Reserve 8 columns for switch
    mov esi, [wdg_t_label]
    call wdg_clip_text

    ; 2. Draw Switch on right: col = col + w - 8
    mov ebx, [wdg_t_col]
    add ebx, [wdg_t_w]
    sub ebx, 8

    ; Check ASCII mode
    cmp byte [setting_charset], 1
    je .tog_ascii

    ; UTF-8 Mode: if height >= 2, render sprite_widget_toggle frame (0 or 1)
    cmp dword [wdg_t_h], 2
    jl .tog_ascii
    push ebx
    sub ebx, [ui_col0]          ; Frame-relative column
    mov eax, [wdg_t_row]
    mov esi, sprite_widget_toggle
    mov ecx, [wdg_t_state]      ; frame index = state (0 or 1)
    movzx edx, dh               ; fill bg slot
    call sprite_draw
    pop ebx
    jmp .tog_exit

.tog_ascii:
    ; ASCII representation: [ OFF] or [ ON ]
    call buf_goto
    mov al, dh
    call gfx_set_bg
    cmp dword [wdg_t_state], 0
    jne .tog_ascii_on

    ; OFF: [ OFF] in SLOT_DIM
    mov al, SLOT_DIM
    call gfx_set_fg
    mov al, CHAR_LBRACKET
    call buf_char
    mov al, CHAR_SPACE
    call buf_char
    mov al, 'O'
    call buf_char
    mov al, 'F'
    call buf_char
    mov al, 'F'
    call buf_char
    mov al, CHAR_RBRACKET
    call buf_char
    jmp .tog_exit

.tog_ascii_on:
    ; ON: [ ON ] in SLOT_OK
    mov al, SLOT_OK
    call gfx_set_fg
    mov al, CHAR_LBRACKET
    call buf_char
    mov al, CHAR_SPACE
    call buf_char
    mov al, 'O'
    call buf_char
    mov al, 'N'
    call buf_char
    mov al, CHAR_SPACE
    call buf_char
    mov al, CHAR_RBRACKET
    call buf_char

.tog_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_progress_cat
; Purpose:   Draws a progress bar with track, filled portion, cat marker
;            (sprite_habits_cat_head_compact), and n/m label above track.
;            Guarantees zero division errors when m = 0.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = n (completed value)
;            EDI = m (target total value)
; OUT:       Appends progress indicator to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_progress_cat:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs
    mov [wdg_pr_row], eax
    mov [wdg_pr_col], ebx
    mov [wdg_pr_w], ecx
    mov [wdg_pr_h], edx
    mov [wdg_pr_n], esi
    mov [wdg_pr_m], edi

    ; Validate bounds
    cmp ecx, 6
    jl .prog_exit
    cmp edx, 1
    jl .prog_exit

    ; Safe ratio calculation: clamp n >= 0, m >= 0
    cmp esi, 0
    jge .n_ok
    xor esi, esi
.n_ok:
    cmp edi, 0
    jge .m_ok
    xor edi, edi
.m_ok:

    ; Check if m == 0 (prevent division by zero)
    test edi, edi
    jz .calc_zero

    ; Clamp n <= m for display fill
    cmp esi, edi
    jbe .calc_ratio
    mov esi, edi

.calc_ratio:
    ; filled_cols = (n * (width - 2)) / m
    push ecx
    sub ecx, 2                  ; inner track width
    mov eax, esi
    xor edx, edx
    imul eax, ecx
    idiv edi                    ; EAX = filled_cols
    mov ebp, eax                ; EBP = filled_cols
    pop ecx
    jmp .draw_label

.calc_zero:
    xor ebp, ebp                ; filled_cols = 0

.draw_label:
    ; If height >= 2, draw "n/m" label on top row
    cmp dword [wdg_pr_h], 2
    jl .draw_bar

    ; Row 1: label "n/m"
    mov eax, [wdg_pr_row]
    mov ebx, [wdg_pr_col]
    call buf_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg
    ; Emit n
    mov eax, [wdg_pr_n]
    call buf_u32
    mov al, CHAR_SLASH          ; '/'
    call buf_char
    mov eax, [wdg_pr_m]
    call buf_u32

    inc dword [wdg_pr_row]      ; Advance track to next row

.draw_bar:
    ; Position cursor at track row
    mov eax, [wdg_pr_row]
    mov ebx, [wdg_pr_col]
    call buf_goto

    ; Start bracket '['
    mov al, SLOT_BORDER
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg
    mov al, CHAR_LBRACKET
    call buf_char

    ; Draw filled portion (EBP cells)
    mov ecx, ebp
    test ecx, ecx
    jz .draw_empty_track

    mov al, SLOT_BAR_FULL
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .fill_ascii_loop
.fill_utf8_loop:
    mov esi, glyph_utf8_block_full ; █
    call buf_str
    dec ecx
    jnz .fill_utf8_loop
    jmp .draw_empty_track

.fill_ascii_loop:
    mov al, '='                 ; '='
    call buf_repeat

.draw_empty_track:
    ; Empty track cells = (width - 2) - EBP
    mov ecx, [wdg_pr_w]
    sub ecx, 2
    sub ecx, ebp
    jle .close_bar

    mov al, SLOT_BAR_EMPTY
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .empty_ascii_loop
.empty_utf8_loop:
    mov esi, glyph_utf8_shade_light ; ░
    call buf_str
    dec ecx
    jnz .empty_utf8_loop
    jmp .close_bar

.empty_ascii_loop:
    mov al, CHAR_SPACE
    call buf_repeat

.close_bar:
    ; Closing bracket ']'
    mov al, SLOT_BORDER
    call gfx_set_fg
    mov al, CHAR_RBRACKET
    call buf_char

.prog_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_stat_card
; Purpose:   Draws a numeric value, caption, and mascot sprite.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Numeric value
;            EDI = Caption text pointer
; OUT:       Appends stat card to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_stat_card:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs
    mov [wdg_st_row], eax
    mov [wdg_st_col], ebx
    mov [wdg_st_w], ecx
    mov [wdg_st_h], edx
    mov [wdg_st_val], esi
    mov [wdg_st_cap], edi

    ; Draw card outline
    mov esi, 0
    mov edi, WDG_PANEL_FLAG_NONE
    call wdg_panel

    ; Value line at row + 1, col + 2
    mov eax, [wdg_st_row]
    inc eax
    mov ebx, [wdg_st_col]
    add ebx, 2
    mov ecx, [wdg_st_w]
    sub ecx, 4
    cmp ecx, 2
    jl .stat_exit

    call buf_goto
    mov al, SLOT_TITLE
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg
    mov eax, [wdg_st_val]
    call buf_u32

    ; Caption line at row + 2
    mov eax, [wdg_st_row]
    add eax, 2
    cmp eax, [term_rows]
    jg .stat_exit
    mov esi, [wdg_st_cap]
    mov dl, SLOT_DIM
    mov dh, SLOT_SURFACE
    call wdg_clip_text

    ; Draw compact tomato mascot if width >= 18 and height >= 5
    mov ecx, [wdg_st_w]
    mov edx, [wdg_st_h]
    cmp ecx, 18
    jl .stat_exit
    cmp edx, 5
    jl .stat_exit

    ; Draw sprite at row + 1, col = col + w - 8
    mov eax, [wdg_st_row]
    inc eax
    mov ebx, [wdg_st_col]
    add ebx, ecx
    sub ebx, 8
    sub ebx, [ui_col0]          ; frame-relative column
    mov esi, sprite_tomato_mascot_compact
    xor ecx, ecx                ; frame 0
    mov edx, SLOT_SURFACE
    call sprite_draw

.stat_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_tip_card
; Purpose:   Draws sparkle-style title ("✦ Daily Tip") and wrapped body text
;            using journal_wrap_segment. Bounded and memory safe.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to body text string
; OUT:       Appends tip card to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_tip_card:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs
    mov [wdg_tip_r], eax
    mov [wdg_tip_c], ebx
    mov [wdg_tip_w], ecx
    mov [wdg_tip_h], edx
    mov [wdg_tip_body], esi

    ; Draw panel outline
    mov esi, str_g6_tip_sparkle
    mov edi, WDG_PANEL_FLAG_TAB
    call wdg_panel

    ; Sparkle line at row + 1, col + 2
    mov eax, [wdg_tip_r]
    inc eax
    mov ebx, [wdg_tip_c]
    add ebx, 2
    mov ecx, [wdg_tip_w]
    sub ecx, 4
    cmp ecx, 2
    jl .tip_exit

    call buf_goto
    mov al, SLOT_ACCENT
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg
    cmp byte [setting_charset], 1
    je .tip_sparkle_ascii
    mov esi, glyph_utf8_sparkle ; ✦
    call buf_str
    jmp .tip_emit_caption
.tip_sparkle_ascii:
    mov al, CHAR_ASTERISK       ; *
    call buf_char

.tip_emit_caption:
    mov al, CHAR_SPACE
    call buf_char
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_tip_caption    ; "Tip:"
    call buf_str

.tip_draw_body:
    ; Text wrap loop starting at row + 2
    mov eax, [wdg_tip_r]
    add eax, 2
    mov esi, [wdg_tip_body]
    test esi, esi
    jz .tip_exit

    ; Compute string byte length in ECX
    xor ecx, ecx
.tip_len_loop:
    cmp byte [esi + ecx], 0
    jz .tip_len_done
    inc ecx
    jmp .tip_len_loop
.tip_len_done:
    test ecx, ecx
    jz .tip_exit

    ; Body wrap loop: rows remaining = height - 3
    mov edx, [wdg_tip_h]
    sub edx, 3
    jle .tip_exit

.tip_wrap_loop:
    ; Column budget for wrapped line
    mov edx, [wdg_tip_w]
    sub edx, 4                  ; inner budget
    cmp edx, 1
    jl .tip_exit

    push eax
    push ecx
    push edx
    push esi
    call journal_wrap_segment
    ; EAX = emitted bytes, EDX = advance bytes, EBX = display columns
    mov edi, eax                ; EDI = emitted bytes
    mov ebp, edx                ; EBP = advance bytes
    pop esi
    pop edx
    pop ecx
    pop eax

    ; Position cursor and emit EDI bytes
    mov ebx, [wdg_tip_c]
    add ebx, 2
    call buf_goto
    mov al, SLOT_TEXT
    call gfx_set_fg
    mov al, SLOT_SURFACE
    call gfx_set_bg

    push ecx
    push esi
    mov ecx, edi
    test ecx, ecx
    jz .tip_next_line
.tip_emit_chars:
    mov al, [esi]
    call buf_char
    inc esi
    dec ecx
    jnz .tip_emit_chars

.tip_next_line:
    pop esi
    pop ecx
    add esi, ebp                ; Advance text pointer
    sub ecx, ebp                ; Subtract remaining bytes
    jle .tip_exit

    inc eax                     ; Next row
    mov edx, [wdg_tip_r]
    add edx, [wdg_tip_h]
    sub edx, 2                  ; edx = max visual row allowed inside card
    cmp eax, edx
    jg .tip_exit
    jmp .tip_wrap_loop

.tip_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_list_row
; Purpose:   Draws a list item row containing icon/marker, text, and right-
;            aligned value with selected/unselected styling.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to label string
;            EDI = Pointer to right-aligned value string
;            EBP = Selected state (0 = normal, 1 = selected)
; OUT:       Appends list row to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_list_row:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs
    mov [wdg_lr_row], eax
    mov [wdg_lr_col], ebx
    mov [wdg_lr_w], ecx
    mov [wdg_lr_h], edx
    mov [wdg_lr_lbl], esi
    mov [wdg_lr_val], edi
    mov [wdg_lr_sel], ebp

    ; Validate bounds
    cmp ecx, 6
    jl .list_exit
    cmp edx, 1
    jl .list_exit

    ; Determine styling based on selected state
    mov dl, SLOT_TEXT
    mov dh, SLOT_SURFACE
    test ebp, ebp
    jz .list_bg_ok
    mov dl, SLOT_TEXT_INV
    mov dh, SLOT_HIGHLIGHT
.list_bg_ok:

    ; Fill background row
    call buf_goto
    mov al, dh
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_repeat

    ; Emit selection marker: '>' for selected, ' ' for normal
    call buf_goto
    mov al, dl
    call gfx_set_fg
    test ebp, ebp
    jz .marker_unsel
    mov al, '>'                 ; '>'
    call buf_char
    jmp .list_draw_label
.marker_unsel:
    mov al, CHAR_SPACE
    call buf_char

.list_draw_label:
    inc ebx
    dec ecx

    ; Reserve 6 columns for right-aligned value
    push ecx
    sub ecx, 6
    cmp ecx, 1
    jl .list_pop_val
    mov eax, [wdg_lr_row]
    mov esi, [wdg_lr_lbl]
    call wdg_clip_text
.list_pop_val:
    pop ecx

    ; Draw right-aligned value at col = col + w - 5
    mov esi, [wdg_lr_val]
    test esi, esi
    jz .list_exit

    mov eax, [wdg_lr_row]
    mov ebx, [wdg_lr_col]
    add ebx, [wdg_lr_w]
    sub ebx, 5
    mov ecx, 5
    mov dl, SLOT_DIM
    test ebp, ebp
    jz .list_val_emit
    mov dl, SLOT_TEXT_INV
.list_val_emit:
    call wdg_clip_text

.list_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_badge
; Purpose:   Draws a compact pill badge [ TEXT ] using supplied theme slots.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to badge label text
;            DL  = Foreground theme slot
;            DH  = Background theme slot
; OUT:       Appends badge to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_badge:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Store inputs
    mov [wdg_bd_row], eax
    mov [wdg_bd_col], ebx
    mov [wdg_bd_w], ecx
    mov [wdg_bd_h], edx
    mov [wdg_bd_lbl], esi
    movzx eax, dl
    mov [wdg_bd_fg], eax
    movzx eax, dh
    mov [wdg_bd_bg], eax

    ; Validate bounds
    cmp ecx, 3
    jl .badge_exit
    cmp edx, 1
    jl .badge_exit

    ; Draw badge opening '['
    mov eax, [wdg_bd_row]
    mov ebx, [wdg_bd_col]
    call buf_goto
    mov eax, [wdg_bd_bg]
    call gfx_set_bg
    mov eax, [wdg_bd_fg]
    call gfx_set_fg
    mov al, CHAR_LBRACKET       ; '['
    call buf_char

    ; Draw badge text
    mov eax, [wdg_bd_row]
    mov ebx, [wdg_bd_col]
    inc ebx
    mov ecx, [wdg_bd_w]
    sub ecx, 2
    cmp ecx, 1
    jl .badge_close
    mov esi, [wdg_bd_lbl]
    mov edx, [wdg_bd_fg]        ; DL = fg
    mov dh, byte [wdg_bd_bg]    ; DH = bg
    call wdg_clip_text

.badge_close:
    ; Draw badge closing ']'
    mov eax, [wdg_bd_row]
    mov ebx, [wdg_bd_col]
    add ebx, [wdg_bd_w]
    dec ebx
    call buf_goto
    mov eax, [wdg_bd_fg]
    call gfx_set_fg
    mov al, CHAR_RBRACKET      ; ']'
    call buf_char

.badge_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_keybar
; Purpose:   Draws footer key hints as small keycaps followed by descriptions.
;            Applies priority clipping to fit strictly within rectangle.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to keybar entries array ({key_ptr, desc_ptr, prio}, NULL)
; OUT:       Appends keybar to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_keybar:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Store inputs
    mov [wdg_kb_row], eax
    mov [wdg_kb_col], ebx
    mov [wdg_kb_w], ecx
    mov [wdg_kb_h], edx
    mov [wdg_kb_tbl], esi

    ; Validate bounds
    cmp ecx, 8
    jl .keybar_exit
    cmp edx, 1
    jl .keybar_exit
    test esi, esi
    jz .keybar_exit

    ; Clear line background
    call buf_goto
    mov al, SLOT_SURFACE
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_repeat

    ; Position cursor at start of keybar
    mov eax, [wdg_kb_row]
    mov ebx, [wdg_kb_col]
    call buf_goto

.keybar_entry_loop:
    mov edi, [esi + KEYBAR_ENTRY_KEY]
    test edi, edi
    jz .keybar_exit             ; End of table

    ; Check if enough columns remain for "[K] Desc " (at least 8 cols)
    cmp ecx, 8
    jl .keybar_exit

    ; Emit '['
    mov al, SLOT_BORDER
    call gfx_set_fg
    mov al, CHAR_LBRACKET
    call buf_char
    dec ecx

    ; Emit keycap string
    mov al, SLOT_ACCENT
    call gfx_set_fg
    push esi
    mov esi, edi
.key_str_loop:
    mov al, [esi]
    test al, al
    jz .key_str_done
    call buf_char
    inc esi
    dec ecx
    jnz .key_str_loop
.key_str_done:
    pop esi

    ; Emit ']'
    mov al, SLOT_BORDER
    call gfx_set_fg
    mov al, CHAR_RBRACKET
    call buf_char
    dec ecx

    ; Emit space
    mov al, CHAR_SPACE
    call buf_char
    dec ecx

    ; Emit description string in SLOT_DIM
    mov al, SLOT_DIM
    call gfx_set_fg
    push esi
    mov esi, [esi + KEYBAR_ENTRY_DESC]
    test esi, esi
    jz .desc_done
.desc_loop:
    mov al, [esi]
    test al, al
    jz .desc_done
    cmp ecx, 2
    jle .desc_done              ; Reserve space for separation
    call buf_char
    inc esi
    dec ecx
    jnz .desc_loop
.desc_done:
    pop esi

    ; Two spacing spaces
    cmp ecx, 2
    jb .keybar_exit
    mov al, CHAR_SPACE
    call buf_char
    call buf_char
    sub ecx, 2

    ; Advance to next keybar entry (12 bytes per struct)
    add esi, KEYBAR_ENTRY_SIZE
    jmp .keybar_entry_loop

.keybar_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: wdg_checkbox_row
; Purpose:   Draws a checkbox [ ] or [X] / [✓] and label.
; IN:        EAX = 1-based absolute terminal row
;            EBX = 1-based absolute terminal col
;            ECX = Width
;            EDX = Height
;            ESI = Pointer to label string
;            EDI = Checked state (0 = unchecked, 1 = checked)
; OUT:       Appends checkbox row to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
wdg_checkbox_row:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Store inputs
    mov [wdg_ck_row], eax
    mov [wdg_ck_col], ebx
    mov [wdg_ck_w], ecx
    mov [wdg_ck_h], edx
    mov [wdg_ck_lbl], esi
    mov [wdg_ck_state], edi

    ; Validate bounds
    cmp ecx, 5
    jl .chk_exit
    cmp edx, 1
    jl .chk_exit

    call buf_goto
    mov al, SLOT_SURFACE
    call gfx_set_bg
    mov al, SLOT_BORDER
    call gfx_set_fg

    ; Checkbox opening '['
    mov al, CHAR_LBRACKET
    call buf_char

    ; Checked indicator
    test edi, edi
    jz .chk_empty

    ; Checked: '✓' in UTF-8 or 'X' in ASCII
    mov al, SLOT_OK
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .chk_ascii_x
    mov esi, glyph_utf8_checkmark ; ✓
    call buf_str
    jmp .chk_close
.chk_ascii_x:
    mov al, CHAR_UPPER_X
    call buf_char
    jmp .chk_close

.chk_empty:
    mov al, CHAR_SPACE
    call buf_char

.chk_close:
    mov al, SLOT_BORDER
    call gfx_set_fg
    mov al, CHAR_RBRACKET       ; ']'
    call buf_char
    mov al, CHAR_SPACE
    call buf_char

    ; Draw label
    add ebx, 4
    sub ecx, 4
    cmp ecx, 1
    jl .chk_exit
    mov eax, [wdg_ck_row]
    mov esi, [wdg_ck_lbl]
    mov dl, SLOT_TEXT
    mov dh, SLOT_SURFACE
    call wdg_clip_text

.chk_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret
