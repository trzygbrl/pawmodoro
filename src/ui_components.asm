; =============================================================================
; Pawmodoro - Shared GUI-like Reusable UI Components (src/ui_components.asm)
;
; Purpose: Reusable visual components, shared application shell helpers,
;          character-set aware glyph dispatch, status markers, and layout
;          primitives conforming to PRD §3.2, §5, §6.2, §6.4 and PRD_V2 §2, §3, §4.
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES
; =============================================================================

;=============================================================================
; Procedure: ui_glyph_str
; Purpose:   Returns a pointer in ESI to the appropriate glyph string based
;            on the current character set (setting_charset: 0=UTF-8, 1=ASCII).
; IN:        EAX = Glyph ID (GLYPH_CORNER_TL .. GLYPH_BAR_EMPTY)
; OUT:       ESI = Pointer to NUL-terminated glyph string
; CLOBBERS:  ESI
;=============================================================================
ui_glyph_str:
    push ebx
    push ecx
    push edx
    push edi
    push eax

    cmp eax, GLYPH_COUNT
    jae .glyph_fallback

    cmp byte [setting_charset], 1
    je .glyph_ascii

    ; UTF-8 glyph table lookup
    mov esi, [glyph_utf8_table + eax*4]
    jmp .glyph_done

.glyph_ascii:
    mov esi, [glyph_ascii_table + eax*4]
    jmp .glyph_done

.glyph_fallback:
    mov esi, glyph_ascii_corner_tl  ; Fallback to "+"

.glyph_done:
    pop eax
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: ui_shell_begin
; Purpose:   Initializes the shared application shell for a screen frame:
;            1. Checks minimum terminal size gate (80x24) via ui_size_gate.
;            2. Updates adaptive layout geometry via ui_layout_update.
;            3. Positions cursor at home (1,1) via ui_goto.
;            4. Draws rounded top border (╭───╮ in UTF-8, +---+ in ASCII).
;            5. Emits Pawmodoro branding, sparkle accent, and section badge.
; IN:        ESI = Pointer to section title string (e.g. "DASHBOARD", "FOCUS TIMER")
;            EDI = Pointer to subtitle string (or 0 if none)
; OUT:       None (appends top border and brand header to out_buf)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
ui_shell_begin:
    call ui_size_gate
    call ui_layout_update
    save_regs
    push eax
    push ebx
    push esi
    push edi

    ; 1. Frame begins with cursor home via ui_goto(1, 1)
    mov eax, 1
    mov ebx, 1
    call ui_goto

    ; 2. Draw Top Border Line
    mov eax, 1
    call ui_frame_hline_top

    ; 3. Header Row (Row 2): Left brand and Right section badge
    ; Clear Row 2
    mov eax, 2
    call ui_frame_row

    ; Left: "PAWMODORO" with sparkle accent
    mov eax, 2
    mov ebx, 4
    call ui_goto

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, menu_title_compact ; "PAWMODORO"
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Emit sparkle accent " ✦ " or " * "
    mov al, ' '
    call buf_char
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str
    mov al, ' '
    call buf_char
    mov esi, ansi_reset
    call buf_str

    ; Emit section title in SLOT_TITLE
    mov esi, [esp + 4]          ; Retrieve ESI (section title)
    test esi, esi
    jz .shell_header_right

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, [esp + 4]
    call buf_str
    mov esi, ansi_reset
    call buf_str

.shell_header_right:
    ; Subtitle on Row 3 if provided
    mov edi, [esp]              ; Retrieve EDI (subtitle)
    test edi, edi
    jz .shell_begin_done

    mov eax, 3
    call ui_frame_row

    mov eax, 3
    mov ebx, 4
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov esi, edi
    call buf_str
    mov esi, ansi_reset
    call buf_str

.shell_begin_done:
    pop edi
    pop esi
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_shell_end
; Purpose:   Finishes the shared application shell for a screen frame:
;            1. Renders status message (if any) at status_row.
;            2. Renders footer key help prompt at help_row.
;            3. Draws rounded bottom border (╰───╯ in UTF-8, +---+ in ASCII)
;               at bottom_row.
;            4. Moves below bottom_row and wipes remainder of terminal screen (ESC[J).
; IN:        EAX = Status message row coordinate (1-based)
;            EBX = Status message style (STATUS_OK, STATUS_WARN, STATUS_ERR, STATUS_INFO)
;            ESI = Pointer to status message string (or 0 for none)
;            EDI = Pointer to footer key help string
;            EDX = Bottom border row coordinate (1-based)
; OUT:       None (appends footer, border, and erase_eos to out_buf)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
ui_shell_end:
    save_regs
    push eax                    ; [esp + 16] = status_row
    push ebx                    ; [esp + 12] = status_style
    push esi                    ; [esp + 8]  = status_msg
    push edi                    ; [esp + 4]  = footer_help
    push edx                    ; [esp]      = bottom_row

    ; 1. Status row
    mov eax, [esp + 16]         ; EAX = status_row
    test eax, eax
    jz .skip_status

    call ui_frame_row           ; Clear row with left/right borders

    mov esi, [esp + 8]          ; ESI = status_msg
    test esi, esi
    jz .skip_status

    mov eax, [esp + 16]
    mov ebx, [esp + 12]         ; EBX = status_style
    call ui_status_message

.skip_status:
    ; 2. Help / Footer row (bottom_row - 1)
    mov edx, [esp]              ; EDX = bottom_row
    dec edx                     ; EDX = help_row
    mov eax, edx
    call ui_frame_row           ; Clear help row

    mov edi, [esp + 4]          ; EDI = footer_help
    test edi, edi
    jz .draw_bottom

    mov eax, edx
    mov ebx, 4
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov esi, edi
    call buf_str
    mov esi, ansi_reset
    call buf_str

.draw_bottom:
    ; 3. Bottom border line
    mov eax, [esp]              ; EAX = bottom_row
    call ui_frame_hline_bot

    ; 4. Erase remainder of screen below frame (ESC[J)
    mov eax, [esp]
    inc eax                     ; EAX = bottom_row + 1
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    add esp, 20
    restore_regs
    ret

;=============================================================================
; Procedure: ui_panel_begin
; Purpose:   Draws the top line of a framed sub-panel:
;            ╭── [Title] ───────────────────╮ (or ASCII +-- [Title] ---+)
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ECX = Panel width in columns
;            ESI = Pointer to panel title string (or 0 for plain border)
; OUT:       None (appends panel top border to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_panel_begin:
    save_regs
    push eax
    push ebx
    push ecx
    push esi

    call ui_goto

    ; Border color
    mov al, SLOT_BORDER
    call ui_color

    ; Top-left corner
    mov eax, GLYPH_CORNER_TL
    call ui_glyph_str
    call buf_str

    ; 2 horizontal dashes
    mov eax, GLYPH_HLINE
    call ui_glyph_str
    call buf_str
    call buf_str

    pop esi                     ; Restore title pointer
    test esi, esi
    jz .panel_no_title

    ; Space before title
    mov al, CHAR_SPACE
    call buf_char

    ; Title in bold SLOT_TITLE
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    pop esi                     ; Retrieve title pointer
    push esi
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Space after title
    mov al, CHAR_SPACE
    call buf_char

    ; Color border again
    mov al, SLOT_BORDER
    call ui_color

.panel_no_title:
    ; Remaining dashes: width - 2 - (title_len + 4)
    ; Compute remaining columns
    mov ecx, [esp + 4]          ; Retrieve panel width
    sub ecx, 6                  ; Subtract corners & leading dashes
    jbe .panel_top_right

.panel_dash_loop:
    mov eax, GLYPH_HLINE
    call ui_glyph_str
    call buf_str
    dec ecx
    jnz .panel_dash_loop

.panel_top_right:
    mov eax, GLYPH_CORNER_TR
    call ui_glyph_str
    call buf_str

    mov esi, ansi_reset
    call buf_str

    pop esi
    pop ecx
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_panel_end
; Purpose:   Draws the bottom line of a framed sub-panel:
;            ╰──────────────────────────────╯ (or ASCII +----------------+)
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ECX = Panel width in columns
; OUT:       None (appends panel bottom border to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_panel_end:
    save_regs
    push eax
    push ebx
    push ecx

    call ui_goto

    mov al, SLOT_BORDER
    call ui_color

    ; Bottom-left corner
    mov eax, GLYPH_CORNER_BL
    call ui_glyph_str
    call buf_str

    ; Horizontal dashes (width - 2)
    mov ecx, [esp]              ; ECX = panel width
    sub ecx, 2
    jbe .panel_bot_right

.panel_bot_dash_loop:
    mov eax, GLYPH_HLINE
    call ui_glyph_str
    call buf_str
    dec ecx
    jnz .panel_bot_dash_loop

.panel_bot_right:
    mov eax, GLYPH_CORNER_BR
    call ui_glyph_str
    call buf_str

    mov esi, ansi_reset
    call buf_str

    pop ecx
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_section_heading
; Purpose:   Renders a consistently styled section heading:
;            "✦ HEADING" with sparkle in SLOT_ACCENT and text in bold SLOT_TITLE.
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ESI = Pointer to heading string
; OUT:       None (appends heading to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_section_heading:
    save_regs
    push eax
    push ebx
    push esi

    call ui_goto

    ; Sparkle icon in SLOT_ACCENT
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str

    mov al, CHAR_SPACE
    call buf_char

    ; Heading text in bold SLOT_TITLE
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    pop esi                     ; Retrieve heading pointer
    push esi
    call buf_str

    mov esi, ansi_reset
    call buf_str

    pop esi
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_label_value
; Purpose:   Renders aligned label and value pair:
;            "<Label>: <Value>" with label in SLOT_DIM and value in bold slot color.
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ESI = Pointer to label string
;            EDI = Pointer to value string
;            CL  = Value theme slot ID (e.g. SLOT_ACCENT, SLOT_OK)
; OUT:       None (appends label/value to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_label_value:
    save_regs
    push eax
    push ebx
    push ecx
    push esi
    push edi

    call ui_goto

    ; Label in SLOT_DIM
    mov al, SLOT_DIM
    call ui_color
    call buf_str

    ; Value in bold slot color
    mov esi, ansi_bold
    call buf_str
    mov al, [esp + 8]           ; Retrieve slot ID (CL)
    call ui_color
    mov esi, [esp]              ; Retrieve value pointer (EDI)
    call buf_str

    mov esi, ansi_reset
    call buf_str

    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_selected_row
; Purpose:   Renders a selection indicator at (Row, Col):
;            If selected (EDX = 1): emits "> " in bold SLOT_ACCENT.
;            If unselected (EDX = 0): emits "  " (2 spaces).
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            EDX = Selection flag (1 = selected, 0 = unselected)
; OUT:       None (appends marker to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_selected_row:
    save_regs
    push eax
    push ebx
    push edx

    call ui_goto

    test edx, edx
    jz .not_sel

    ; Selected: bold SLOT_ACCENT "> "
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov al, '>'
    call buf_char
    mov al, ' '
    call buf_char
    mov esi, ansi_reset
    call buf_str
    jmp .sel_done

.not_sel:
    mov al, ' '
    call buf_char
    mov al, ' '
    call buf_char

.sel_done:
    pop edx
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_badge
; Purpose:   Renders a compact framed badge: "[LABEL]" with brackets in
;            SLOT_DIM and text in bold slot color.
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ESI = Pointer to badge text string
;            CL  = Theme slot ID for text
; OUT:       None (appends badge to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_badge:
    save_regs
    push eax
    push ebx
    push ecx
    push esi

    call ui_goto

    ; Left bracket in SLOT_DIM
    mov al, SLOT_DIM
    call ui_color
    mov al, CHAR_LBRACKET
    call buf_char

    ; Text in bold slot color
    mov esi, ansi_bold
    call buf_str
    mov al, [esp + 4]           ; Retrieve slot ID (CL)
    call ui_color
    mov esi, [esp]              ; Retrieve text pointer
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Right bracket in SLOT_DIM
    mov al, SLOT_DIM
    call ui_color
    mov al, CHAR_RBRACKET
    call buf_char
    mov esi, ansi_reset
    call buf_str

    pop esi
    pop ecx
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_separator
; Purpose:   Draws a horizontal frame divider (├───┤ in UTF-8, +---+ in ASCII)
;            at Row coordinate in EAX spanning the full adaptive width ui_w.
; IN:        EAX = Row coordinate (1-based)
; OUT:       None (appends divider to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_separator:
    call ui_frame_hline_mid
    ret

;=============================================================================
; Procedure: ui_empty_state
; Purpose:   Renders concise empty state text with sparkle accent in SLOT_DIM:
;            "✦ <Message>"
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ESI = Pointer to empty state message string
; OUT:       None (appends empty state to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_empty_state:
    save_regs
    push eax
    push ebx
    push esi

    call ui_goto

    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str

    mov al, ' '
    call buf_char

    mov al, SLOT_DIM
    call ui_color
    pop esi
    push esi
    call buf_str
    mov esi, ansi_reset
    call buf_str

    pop esi
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_confirmation
; Purpose:   Renders a framed confirmation prompt line with [!] warning marker:
;            "[!] <Prompt>" in bold SLOT_WARN.
; IN:        EAX = Row coordinate (1-based)
;            EBX = Column coordinate (1-based, frame-relative)
;            ESI = Pointer to prompt string (e.g. "Delete this entry? (y/n)")
; OUT:       None (appends confirmation to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_confirmation:
    save_regs
    push eax
    push ebx
    push esi

    call ui_goto

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_WARN
    call ui_color

    mov esi, status_marker_warn ; "[!] "
    call buf_str

    pop esi
    push esi
    call buf_str

    mov esi, ansi_reset
    call buf_str

    pop esi
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_status_message
; Purpose:   Renders feedback on the status row with an explicit textual marker
;            ([OK], [!], [ERR], [i]), guaranteeing color is never the sole indicator.
; IN:        EAX = Row coordinate (1-based)
;            EBX = Status style (STATUS_OK, STATUS_WARN, STATUS_ERR, STATUS_INFO)
;            ESI = Pointer to message string (0 = none)
; OUT:       None (appends status message to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_status_message:
    save_regs
    push eax
    push ebx
    push esi

    test esi, esi
    jz .stat_msg_done

    ; Position at (row, 4)
    mov ebx, 4
    call ui_goto

    mov ebx, [esp + 4]          ; Retrieve style

    cmp ebx, STATUS_OK
    je .stat_style_ok
    cmp ebx, STATUS_ERR
    je .stat_style_err
    cmp ebx, STATUS_INFO
    je .stat_style_info

    ; Default: STATUS_WARN
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_WARN
    call ui_color
    mov esi, status_marker_warn ; "[!] "
    call buf_str
    jmp .stat_emit_body

.stat_style_ok:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_OK
    call ui_color
    mov esi, status_marker_ok   ; "[OK] "
    call buf_str
    jmp .stat_emit_body

.stat_style_err:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ERR
    call ui_color
    mov esi, status_marker_err  ; "[ERR] "
    call buf_str
    jmp .stat_emit_body

.stat_style_info:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, status_marker_info ; "[i] "
    call buf_str

.stat_emit_body:
    mov esi, [esp]              ; Retrieve message pointer
    call buf_str
    mov esi, ansi_reset
    call buf_str

.stat_msg_done:
    pop esi
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_progress_indicator
; Purpose:   Formats a segmented progress bar of width EBX columns:
;            "[" + filled + unfilled + "]  XX%"
;            In UTF-8 mode: filled is ▰, unfilled is ▱.
;            In ASCII mode: filled is #, unfilled is -.
; IN:        EAX = Elapsed time in seconds
;            ECX = Total duration in seconds
;            EBX = Width in columns (e.g. 30)
; OUT:       None (appends segmented bar to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_progress_indicator:
    save_regs
    push eax
    push ebx
    push ecx

    ; Check if total is zero (prevent division by zero)
    test ecx, ecx
    jnz .pi_check_clamp

    ; Total 0: treat as 100%
    mov edx, [esp + 4]          ; EDX = width (all filled)
    mov edi, PERCENT_SCALE      ; 100%
    jmp .pi_render

.pi_check_clamp:
    cmp eax, ecx
    jbe .pi_calc
    mov eax, ecx                ; Clamp elapsed to total

.pi_calc:
    ; filled = (elapsed * width) / total
    push ecx                    ; Preserve total
    mov edx, [esp + 8]          ; EDX = width
    mul edx                     ; EAX = elapsed * width
    pop ecx                     ; ECX = total
    xor edx, edx
    div ecx                     ; EAX = filled count
    push eax                    ; [esp] = filled count

    ; percentage = (elapsed * 100) / total
    mov eax, [esp + 8]          ; EAX = elapsed (from original push)
    mov edx, PERCENT_SCALE      ; 100
    mul edx
    xor edx, edx
    div ecx                     ; EAX = percentage
    mov edi, eax                ; EDI = percentage

    pop edx                     ; EDX = filled count

.pi_render:
    ; EDX = filled count, EDI = percentage
    push edi                    ; Preserve percentage

    ; 1. Emit '['
    mov al, CHAR_LBRACKET
    call buf_char

    ; 2. Emit filled segments in SLOT_BAR_FULL
    mov al, SLOT_BAR_FULL
    call ui_color

    mov ecx, edx                ; ECX = filled count
    test ecx, ecx
    jz .pi_empty_segments

.pi_fill_loop:
    cmp byte [setting_charset], 1
    je .pi_fill_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x96
    call buf_char
    mov al, 0xB0                ; '▰'
    call buf_char
    jmp .pi_fill_next
.pi_fill_ascii:
    mov al, CHAR_HASH           ; '#'
    call buf_char
.pi_fill_next:
    dec ecx
    jnz .pi_fill_loop

.pi_empty_segments:
    mov esi, ansi_reset
    call buf_str

    ; 3. Emit unfilled segments in SLOT_BAR_EMPTY
    mov al, SLOT_BAR_EMPTY
    call ui_color

    mov ecx, [esp + 8]          ; ECX = bar width (from stack)
    sub ecx, edx                ; ECX = unfilled count (width - filled)
    jbe .pi_close_bracket

.pi_empty_loop:
    cmp byte [setting_charset], 1
    je .pi_empty_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x96
    call buf_char
    mov al, 0xB1                ; '▱'
    call buf_char
    jmp .pi_empty_next
.pi_empty_ascii:
    mov al, CHAR_MINUS          ; '-'
    call buf_char
.pi_empty_next:
    dec ecx
    jnz .pi_empty_loop

.pi_close_bracket:
    mov esi, ansi_reset
    call buf_str

    ; 4. Emit ']'
    mov al, CHAR_RBRACKET
    call buf_char

    ; 5. Emit two spaces "  "
    mov al, CHAR_SPACE
    call buf_char
    mov al, CHAR_SPACE
    call buf_char

    ; 6. Emit percentage integer
    pop edi                     ; Restore percentage
    mov eax, edi
    call buf_u32

    ; 7. Emit '%'
    mov al, CHAR_PERCENT
    call buf_char

    pop ecx
    pop ebx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_greeting_get
; Purpose:   Returns in ESI a deterministic time-of-day greeting based on the
;            current local hour:
;            - 05:00 .. 11:59: "Good morning, ready to focus?"
;            - 12:00 .. 17:59: "Good afternoon, keep up the momentum!"
;            - 18:00 .. 04:59: "Good evening, wrap up your day peacefully."
; IN:        None
; OUT:       ESI = Pointer to greeting string
; CLOBBERS:  ESI
;=============================================================================
ui_greeting_get:
    push ebx
    push ecx
    push edx
    push edi
    push eax

    call time_local             ; EAX = local seconds
    xor edx, edx
    mov ebx, SECONDS_PER_DAY
    div ebx                     ; EDX = seconds into day (0..86399)

    mov eax, edx
    xor edx, edx
    mov ebx, SECONDS_PER_HOUR
    div ebx                     ; EAX = hour of day (0..23)

    cmp eax, 12
    jb .greet_morning
    cmp eax, 18
    jb .greet_afternoon
    mov esi, greeting_evening
    jmp .greet_done

.greet_morning:
    mov esi, greeting_morning
    jmp .greet_done

.greet_afternoon:
    mov esi, greeting_afternoon

.greet_done:
    pop eax
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: ui_tip_get
; Purpose:   Returns in ESI a deterministic daily cozy tip string based on
;            (time_today % COZY_TIPS_COUNT). Repeated redraws on the same day
;            yield the exact same tip.
; IN:        None
; OUT:       ESI = Pointer to cozy tip string
; CLOBBERS:  ESI
;=============================================================================
ui_tip_get:
    push ebx
    push ecx
    push edx
    push edi
    push eax

    call time_today             ; EAX = integer day number
    xor edx, edx
    mov ebx, COZY_TIPS_COUNT    ; 7
    div ebx                     ; EDX = day_number % 7 (0..6)

    mov esi, [cozy_tips_table + edx*4]

    pop eax
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
