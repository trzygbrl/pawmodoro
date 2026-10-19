; =============================================================================
; Pawmodoro - UI Rendering & Frame Helpers (src/ui.asm)
;
; Purpose: Frame drawing, absolute text positioning, ASCII cat art rendering,
;          main menu dashboard display, and stub screen rendering per PRD §4.1,
;          §5, and §6.4.
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

; -----------------------------------------------------------------------------
; ui_draw_cat: Render 3-line ASCII cat art in specified pose.
;
; Purpose:  Renders a 3-line ASCII cat (at most 11 columns wide) using absolute
;           positioning at coordinates (cat_row, cat_col). Applies a cozy warm
;           yellow color palette and always restores standard text styling.
;           Out-of-range pose numbers default to pose 0 (idle).
; IN:       EAX = Pose number:
;                 0 = Idle cat (main menu)
;                 1 = Working cat with focused eyes (timer focus)
;                 2 = Resting / sleeping cat with "zZ" (timer break)
;           Implicit inputs:
;                 dword [cat_row] = 1-based top row coordinate
;                 dword [cat_col] = 1-based left column coordinate
; OUT:      Appends cat escape sequences and text to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_draw_cat:
    save_regs
    push eax

    ; Clamp / validate pose number (default to 0 if > 2)
    cmp eax, CAT_POSE_WORKING
    je .pose_1
    cmp eax, CAT_POSE_RESTING
    je .pose_2

    ; Default: Pose 0 (Idle)
.pose_0:
    mov esi, cat_p0_l1
    mov edx, cat_p0_l2
    mov ecx, cat_p0_l3
    jmp .render_art

.pose_1:
    mov esi, cat_p1_l1
    mov edx, cat_p1_l2
    mov ecx, cat_p1_l3
    jmp .render_art

.pose_2:
    mov esi, cat_p2_l1
    mov edx, cat_p2_l2
    mov ecx, cat_p2_l3

.render_art:
    ; Apply cozy warm yellow foreground color
    push esi
    mov esi, ansi_fg_bright_yellow
    call buf_str
    pop esi

    ; Line 1: cat_row, cat_col
    mov eax, [cat_row]
    mov ebx, [cat_col]
    call buf_goto
    call buf_str

    ; Line 2: cat_row + 1, cat_col
    mov eax, [cat_row]
    inc eax
    mov ebx, [cat_col]
    call buf_goto
    mov esi, edx                ; Line 2 pointer
    call buf_str

    ; Line 3: cat_row + 2, cat_col
    mov eax, [cat_row]
    add eax, 2
    mov ebx, [cat_col]
    call buf_goto
    mov esi, ecx                ; Line 3 pointer
    call buf_str

    ; Always restore default attributes
    mov esi, ansi_reset
    call buf_str

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_frame_hline: Render a horizontal border line across the 56-column frame.
;
; Purpose:  Positions cursor at (row, 1) and appends '+' followed by 54 '-'
;           characters and a trailing '+'. Total line width is exactly 56 cols.
; IN:       EAX = Row coordinate (1-based)
; OUT:      Appends horizontal frame line to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_frame_hline:
    save_regs
    push eax

    ; Position cursor at (row, 1)
    mov ebx, UI_FRAME_COL_LEFT  ; 1
    call buf_goto

    ; Left corner '+'
    mov al, CHAR_PLUS
    call buf_char

    ; 54 horizontal border dashes '-'
    mov al, CHAR_MINUS
    mov ecx, UI_FRAME_INNER_WIDTH ; 54
    call buf_repeat

    ; Right corner '+'
    mov al, CHAR_PLUS
    call buf_char

    ; Clear remainder of line to prevent wrapped text residue on border rows (Task 9)
    mov esi, ansi_erase_eol
    call buf_str

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_frame_row: Render an empty framed row with line clearing and right border.
;
; Purpose:  Positions cursor at (row, 1), writes left border '|', erases from
;           cursor to end of line via ESC[K (obliterating any leftover text from
;           previous screens), positions cursor at absolute column 56, and writes
;           the right border '|'. Eliminates inner padding calculations.
; IN:       EAX = Row coordinate (1-based)
; OUT:      Appends cleared framed row to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_frame_row:
    save_regs
    push eax

    ; 1. Move to (row, 1)
    mov ebx, UI_FRAME_COL_LEFT  ; 1
    call buf_goto

    ; 2. Emit left border '|'
    mov al, CHAR_PIPE
    call buf_char

    ; 3. Emit ESC[K (erase to end of line)
    mov esi, ansi_erase_eol
    call buf_str

    ; 4. Move directly to absolute right border column 56
    mov eax, [esp]              ; Retrieve row
    mov ebx, UI_FRAME_COL_RIGHT ; 56
    call buf_goto

    ; 5. Emit right border '|'
    mov al, CHAR_PIPE
    call buf_char

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_text_at: Position cursor and render a NUL-terminated string.
;
; Purpose:  Helper routine that positions cursor at (row, col) and appends
;           the string at ESI to out_buf.
; IN:       EAX = Row coordinate (1-based)
;           EBX = Column coordinate (1-based)
;           ESI = Pointer to NUL-terminated string
; OUT:      Appends positioning and text to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_text_at:
    save_regs
    push eax

    call buf_goto
    call buf_str

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_draw_menu: Render the complete Main Menu dashboard frame (PRD §5).
;
; Purpose:  Draws all outer borders and clears inner rows first, wipes remaining
;           screen area below row 13 with ESC[J, then overlays cat art, bold
;           titles, daily statistics dashboard, and menu options.
; IN:       none (reads demo_mode, dash_pomodoros, dash_habits_done, dash_habits_total)
; OUT:      Appends complete menu frame to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_draw_menu:
    call ui_size_gate
    save_regs
    push eax

    ; Frame begins with cursor home via buf_goto(1, 1)
    mov eax, UI_MENU_ROW_TOP
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw All Borders and Cleared Rows First
    ; -------------------------------------------------------------------------
    ; Row 1: Top border
    mov eax, UI_MENU_ROW_TOP
    call ui_frame_hline

    ; Rows 2..4: Header section (Cat & Title area)
    mov eax, UI_MENU_ROW_TITLE
    call ui_frame_row
    mov eax, UI_MENU_ROW_TAGLINE
    call ui_frame_row
    mov eax, UI_MENU_ROW_CAT3
    call ui_frame_row

    ; Row 5: Separator border
    mov eax, UI_MENU_ROW_SEP
    call ui_frame_hline

    ; Rows 6..12: Content section (Dashboard, Spacing, Menu Items)
    mov eax, UI_MENU_ROW_DASH
    call ui_frame_row
    mov eax, UI_MENU_ROW_BLANK
    call ui_frame_row
    mov eax, UI_MENU_ROW_ITEM1
    call ui_frame_row
    mov eax, UI_MENU_ROW_ITEM2
    call ui_frame_row
    mov eax, UI_MENU_ROW_ITEM3
    call ui_frame_row
    mov eax, UI_MENU_ROW_ITEM4
    call ui_frame_row
    mov eax, UI_MENU_ROW_ITEMQ
    call ui_frame_row

    ; Row 13: Status / message row
    mov eax, UI_MENU_ROW_STATUS
    call ui_frame_row

    ; Row 14: Key help row
    mov eax, UI_MENU_ROW_HELP
    call ui_frame_row

    ; Row 15: Bottom border
    mov eax, UI_MENU_ROW_BOTTOM
    call ui_frame_hline

    ; Row 16: Move below frame and erase to end of screen (ESC[J)
    mov eax, UI_MENU_ROW_BELOW
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content (Cat Art, Titles, Dashboard, Menu Options)
    ; -------------------------------------------------------------------------
    ; 1. Cat art (Pose 0: Idle) at Row 2, Col 4
    mov dword [cat_row], UI_MENU_ROW_TITLE
    mov dword [cat_col], UI_MENU_COL_CAT
    mov eax, CAT_POSE_IDLE
    call ui_draw_cat

    ; 2. Bold title "P A W M O D O R O" at Row 2, Col 14
    mov eax, UI_MENU_ROW_TITLE
    mov ebx, UI_MENU_COL_TITLE
    call buf_goto
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, menu_title
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 3. Tagline "cozy focus - habits - notes" at Row 3, Col 14
    mov eax, UI_MENU_ROW_TAGLINE
    mov ebx, UI_MENU_COL_TITLE
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov esi, menu_tagline
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 4. Dashboard line at Row 6, Col 4: "Today: N pomodoros      Habits: D/T done"
    mov eax, UI_MENU_ROW_DASH
    mov ebx, UI_MENU_COL_CONTENT
    call buf_goto

    mov esi, dash_lbl_today
    call buf_str
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov eax, [dash_pomodoros]
    call buf_u32
    mov esi, ansi_reset
    call buf_str

    mov esi, dash_lbl_pomos
    call buf_str
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov eax, [dash_habits_done]
    call buf_u32
    mov esi, ansi_reset
    call buf_str

    mov al, CHAR_SLASH
    call buf_char

    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov eax, [dash_habits_total]
    call buf_u32
    mov esi, ansi_reset
    call buf_str

    mov esi, dash_lbl_done
    call buf_str

    ; 5. Menu options
    ; [1] Start focus session
    mov eax, UI_MENU_ROW_ITEM1
    mov ebx, UI_MENU_COL_CONTENT
    mov esi, menu_item_1
    call ui_text_at

    ; [2] Habit tracker
    mov eax, UI_MENU_ROW_ITEM2
    mov ebx, UI_MENU_COL_CONTENT
    mov esi, menu_item_2
    call ui_text_at

    ; [3] Journal
    mov eax, UI_MENU_ROW_ITEM3
    mov ebx, UI_MENU_COL_CONTENT
    mov esi, menu_item_3
    call ui_text_at

    ; [4] Demo mode: OFF / ON
    mov eax, UI_MENU_ROW_ITEM4
    mov ebx, UI_MENU_COL_CONTENT
    call buf_goto
    mov esi, menu_item_4_prefix
    call buf_str

    cmp dword [demo_mode], 0
    jne .menu_demo_active
    mov esi, ansi_fg_bright_black
    call buf_str
    mov esi, menu_demo_off
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .menu_item_quit

.menu_demo_active:
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_green
    call buf_str
    mov esi, menu_demo_on
    call buf_str
    mov esi, ansi_reset
    call buf_str

.menu_item_quit:
    ; [Q] Quit
    mov eax, UI_MENU_ROW_ITEMQ
    mov ebx, UI_MENU_COL_CONTENT
    mov esi, menu_item_q
    call ui_text_at

    ; 6. Status message at Row 13, Col 4
    mov eax, UI_MENU_ROW_STATUS
    mov ebx, [menu_msg_style]
    mov esi, [menu_msg]
    call ui_draw_status

    ; 7. Footer key help prompt at Row 14, Col 4
    mov eax, UI_MENU_ROW_HELP
    mov ebx, UI_MENU_COL_HELP
    mov esi, menu_help
    call ui_text_at

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_draw_stub: Render a framed placeholder screen with a custom title.
;
; Purpose:  Draws a framed screen for unimplemented modules (Timer, Habits,
;           Journal) with the given title and standard prompt:
;           "Coming soon — press B to go back". Wipes remaining lines below row 8.
; IN:       ESI = Pointer to NUL-terminated screen title string
; OUT:      Appends framed stub screen to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_draw_stub:
    save_regs
    push eax
    push esi                    ; Preserve title pointer across frame calls

    ; Frame begins with cursor home via buf_goto(1, 1)
    mov eax, UI_STUB_ROW_TOP
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw All Borders and Cleared Rows First
    ; -------------------------------------------------------------------------
    ; Row 1: Top border
    mov eax, UI_STUB_ROW_TOP
    call ui_frame_hline

    ; Row 2: Title row
    mov eax, UI_STUB_ROW_TITLE
    call ui_frame_row

    ; Row 3: Separator border
    mov eax, UI_STUB_ROW_SEP
    call ui_frame_hline

    ; Rows 4..7: Blank, message, and key help rows
    mov eax, UI_STUB_ROW_BLANK1
    call ui_frame_row
    mov eax, UI_STUB_ROW_MSG
    call ui_frame_row
    mov eax, UI_STUB_ROW_BLANK2
    call ui_frame_row
    mov eax, UI_STUB_ROW_KEY
    call ui_frame_row

    ; Row 8: Bottom border
    mov eax, UI_STUB_ROW_BOTTOM
    call ui_frame_hline

    ; Row 9: Move below frame and erase to end of screen (ESC[J)
    mov eax, UI_STUB_ROW_BELOW
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content (Title, Message, Key Help)
    ; -------------------------------------------------------------------------
    ; 1. Title at Row 2, Col 4
    mov eax, UI_STUB_ROW_TITLE
    mov ebx, UI_STUB_COL_TITLE
    call buf_goto
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    pop esi                     ; Restore title string pointer
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 2. "Coming soon — press B to go back" at Row 5, Col 4
    mov eax, UI_STUB_ROW_MSG
    mov ebx, UI_STUB_COL_CONTENT
    mov esi, stub_msg
    call ui_text_at

    ; 3. "[B] Back" at Row 7, Col 4
    mov eax, UI_STUB_ROW_KEY
    mov ebx, UI_STUB_COL_CONTENT
    mov esi, stub_key_help
    call ui_text_at

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_progress_bar: Append 30-character progress bar and percentage to out_buf.
;
; Purpose:  Calculates the proportion of elapsed time (EAX) against total phase
;           duration (ECX) and formats a 30-character progress bar:
;           '[' + filled '#' characters + empty '-' characters + ']' + "  " + percentage + '%'.
;           The number of filled characters is (elapsed * 30) / total.
;           The percentage is (elapsed * 100) / total.
;           Arithmetic uses unsigned MUL and DIV, with EDX explicitly zeroed
;           via 'xor edx, edx' before every DIV (never CDQ).
;           Elapsed is clamped to total. If total is 0, progress is treated as 100%.
; IN:       EAX = Elapsed time in seconds
;           ECX = Total phase duration in seconds
; OUT:      Appends progress bar text directly to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
ui_progress_bar:
    save_regs
    push eax

    ; Check if total is zero (prevent division by zero)
    test ecx, ecx
    jnz .pb_check_clamp

    ; Total is 0: treat as 100% complete
    mov ebx, PROGRESS_BAR_WIDTH ; 30 filled characters
    mov edi, PERCENT_SCALE      ; 100%
    jmp .pb_emit

.pb_check_clamp:
    ; Clamp elapsed (EAX) to total (ECX)
    cmp eax, ecx
    jbe .pb_calc_filled
    mov eax, ecx                ; Clamp elapsed to total

.pb_calc_filled:
    ; Calculate filled = (elapsed * PROGRESS_BAR_WIDTH) / total
    push eax                    ; Save clamped elapsed for percent calculation
    push ecx                    ; Save total

    mov edx, PROGRESS_BAR_WIDTH ; 30
    mul edx                     ; EDX:EAX = elapsed * 30
    xor edx, edx                ; Zero EDX before unsigned 32-bit DIV (never use CDQ)
    pop ecx                     ; Restore total into ECX
    div ecx                     ; EAX = quotient (filled), EDX = remainder
    mov ebx, eax                ; EBX = filled characters (0..30)

    ; Calculate percent = (elapsed * PERCENT_SCALE) / total
    pop eax                     ; Restore clamped elapsed
    push ebx                    ; Save filled character count
    mov edx, PERCENT_SCALE      ; 100
    mul edx                     ; EDX:EAX = elapsed * 100
    xor edx, edx                ; Zero EDX before unsigned 32-bit DIV
    div ecx                     ; EAX = quotient (percentage 0..100)
    mov edi, eax                ; EDI = percentage (0..100)
    pop ebx                     ; Restore filled character count

.pb_emit:
    ; 1. Emit '['
    mov al, CHAR_LBRACKET
    call buf_char

    ; 2. Emit filled '#' characters (EBX times)
    mov al, CHAR_HASH
    mov ecx, ebx
    call buf_repeat

    ; 3. Emit empty '-' characters (PROGRESS_BAR_WIDTH - EBX times)
    mov al, CHAR_MINUS
    mov ecx, PROGRESS_BAR_WIDTH
    sub ecx, ebx
    call buf_repeat

    ; 4. Emit ']'
    mov al, CHAR_RBRACKET
    call buf_char

    ; 5. Emit two spaces "  "
    mov al, CHAR_SPACE
    call buf_char
    mov al, CHAR_SPACE
    call buf_char

    ; 6. Emit percentage integer as decimal digits
    mov eax, edi
    call buf_u32

    ; 7. Emit '%'
    mov al, CHAR_PERCENT
    call buf_char

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_size_gate: Terminal dimension enforcement gate.
;
; Purpose:  Checks if terminal size is at least 80x24 via term_size_ok.
;           If smaller than 80x24, loops displaying an enlarge warning:
;             Row 1: "Please enlarge the terminal"
;             Row 2: "(need 80x24, now <cols>x<rows>)"
;           During loop, sleeps 100ms via time_sleep_100ms and polls for Ctrl+C.
;           If Ctrl+C is pressed, calls app_exit(EXIT_SUCCESS).
;           When dimensions recover to >= 80x24, appends ansi_clear to out_buf so
;           subsequent screen redraw paints on a pristine screen, and returns.
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only (all registers preserved)
; -----------------------------------------------------------------------------
ui_size_gate:
    save_regs
    push eax

    call term_size_ok
    test eax, eax
    jnz .gate_done              ; Size is >= 80x24 or unknown: return immediately

.gate_draw_warning:
    ; Discard any incomplete pending frame
    mov dword [out_len], 0

    ; Clear screen and move cursor home
    mov esi, ansi_clear
    call buf_str
    mov esi, ansi_home
    call buf_str

    ; Row 1: "Please enlarge the terminal"
    mov eax, 1
    mov ebx, 1
    call buf_goto
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov esi, ui_msg_enlarge
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Row 2: "(need 80x24, now <cols>x<rows>)"
    mov eax, 2
    mov ebx, 1
    call buf_goto
    mov esi, ui_msg_need_prefix
    call buf_str
    mov eax, [term_cols]
    call buf_u32
    mov esi, ui_msg_need_x
    call buf_str
    mov eax, [term_rows]
    call buf_u32
    mov esi, ui_msg_need_suffix
    call buf_str

    ; Flush warning frame to screen
    call buf_flush

    ; Record displayed dimensions in EDX:ECX for dynamic update
    mov edx, [term_cols]
    mov ecx, [term_rows]

.gate_wait_loop:
    call time_sleep_100ms
    call key_poll
    cmp eax, KEY_CTRL_C
    je .gate_ctrl_c

    call term_size_ok
    test eax, eax
    jnz .gate_recovered

    ; Size still insufficient: check if dimensions changed
    cmp edx, [term_cols]
    jne .gate_draw_warning
    cmp ecx, [term_rows]
    jne .gate_draw_warning
    jmp .gate_wait_loop

.gate_ctrl_c:
    mov ebx, EXIT_SUCCESS
    call app_exit

.gate_recovered:
    ; Append ansi_clear so subsequent normal frame redraw clears warning text
    mov esi, ansi_clear
    call buf_str

.gate_done:
    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; ui_draw_status: Append styled status message at (row, col 4).
;
; Purpose:  Positions cursor at (EAX, 4) and emits string at ESI styled
;           according to EBX:
;             STATUS_INFO (0): ansi_fg_bright_yellow
;             STATUS_OK (1):   ansi_bold + ansi_fg_bright_green
;             STATUS_ERR (2):  ansi_bold + ansi_fg_bright_red
;           If ESI is 0 (NULL), nothing is drawn.
;           Always emits ansi_reset after message.
; IN:       EAX = Row coordinate (1-based)
;           EBX = Status style (STATUS_INFO, STATUS_OK, STATUS_ERR)
;           ESI = Pointer to NUL-terminated message string (0 = none)
; OUT:      none
; CLOBBERS: EFLAGS only
; -----------------------------------------------------------------------------
ui_draw_status:
    save_regs
    push eax
    push ebx
    push esi

    test esi, esi
    jz .status_done             ; NULL pointer: do not draw anything

    ; Position cursor at (row, 4)
    mov ebx, 4
    call buf_goto

    ; Retrieve style from stack
    mov ebx, [esp + 4]

    cmp ebx, STATUS_OK
    je .status_style_ok
    cmp ebx, STATUS_ERR
    je .status_style_err

    ; STATUS_INFO: bright yellow
    mov esi, ansi_fg_bright_yellow
    call buf_str
    jmp .status_emit

.status_style_ok:
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_green
    call buf_str
    jmp .status_emit

.status_style_err:
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_red
    call buf_str

.status_emit:
    mov esi, [esp]              ; Retrieve message pointer
    call buf_str
    mov esi, ansi_reset
    call buf_str

.status_done:
    pop esi
    pop ebx
    pop eax
    restore_regs
    ret
