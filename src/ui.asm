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

;=============================================================================
; Procedure: ui_draw_cat
; Purpose:   Renders a 3-line ASCII cat (at most 11 columns wide) using absolute
;            positioning at coordinates (cat_row, cat_col). Applies a cozy warm
;            yellow color palette and always restores standard text styling.
;            Out-of-range pose numbers default to pose 0 (idle).
; IN:        EAX = Pose number:
;                  0 = Idle cat (main menu)
;                  1 = Working cat with focused eyes (timer focus)
;                  2 = Resting / sleeping cat with "zZ" (timer break)
;            Implicit inputs:
;                  dword [cat_row] = 1-based top row coordinate
;                  dword [cat_col] = 1-based left column coordinate
; OUT:       Appends ASCII cat art to output buffer
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_draw_cat:
    save_regs
    push eax

    ; Clamp / validate pose number (default to 0 if > 4)
    cmp eax, CAT_POSE_WORKING
    je .pose_1
    cmp eax, CAT_POSE_RESTING
    je .pose_2
    cmp eax, CAT_POSE_HAPPY
    je .pose_3
    cmp eax, CAT_POSE_SURPRISED
    je .pose_4

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
    jmp .render_art

.pose_3:
    mov esi, cat_p3_l1
    mov edx, cat_p3_l2
    mov ecx, cat_p3_l3
    jmp .render_art

.pose_4:
    mov esi, cat_p4_l1
    mov edx, cat_p4_l2
    mov ecx, cat_p4_l3

.render_art:
    ; Apply cat artwork color slot
    mov al, SLOT_CAT
    call ui_color

    ; Line 1: cat_row, cat_col
    mov eax, [cat_row]
    mov ebx, [cat_col]
    call ui_goto
    call buf_str

    ; Line 2: cat_row + 1, cat_col
    mov eax, [cat_row]
    inc eax
    mov ebx, [cat_col]
    call ui_goto
    mov esi, edx                ; Line 2 pointer
    call buf_str

    ; Line 3: cat_row + 2, cat_col
    mov eax, [cat_row]
    add eax, 2
    mov ebx, [cat_col]
    call ui_goto
    mov esi, ecx                ; Line 3 pointer
    call buf_str

    ; Always restore default attributes
    mov esi, ansi_reset
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_frame_emit_dashes
; Purpose:   Emits (ui_w - 2) horizontal border dashes:
;            In UTF-8 mode: '─' (0xE2, 0x94, 0x80)
;            In ASCII mode: '-' (CHAR_MINUS)
; IN:        None (uses [ui_w] and [setting_charset])
; OUT:       Appends dashes to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_frame_emit_dashes:
    save_regs
    push eax
    push ecx

    mov ecx, [ui_w]
    sub ecx, 2
    jbe .dashes_done

    cmp byte [setting_charset], 1
    je .dashes_ascii

.dashes_utf8_loop:
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x80                ; '─'
    call buf_char
    dec ecx
    jnz .dashes_utf8_loop
    jmp .dashes_done

.dashes_ascii:
    mov al, CHAR_MINUS
    call buf_repeat

.dashes_done:
    pop ecx
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_frame_hline_top
; Purpose:   Draws the top border of the frame:
;            ╭───╮ (UTF-8) or +---+ (ASCII)
; IN:        EAX = Row coordinate (1-based)
; OUT:       Appends top frame line to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_frame_hline_top:
    save_regs
    push eax

    mov ebx, 1
    call ui_goto

    mov al, SLOT_BORDER
    call ui_color

    cmp byte [setting_charset], 1
    je .top_l_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x95
    call buf_char
    mov al, 0xAD                ; '╭'
    call buf_char
    jmp .top_dashes
.top_l_ascii:
    mov al, CHAR_PLUS
    call buf_char

.top_dashes:
    call ui_frame_emit_dashes

    cmp byte [setting_charset], 1
    je .top_r_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x95
    call buf_char
    mov al, 0xAE                ; '╮'
    call buf_char
    jmp .top_done
.top_r_ascii:
    mov al, CHAR_PLUS
    call buf_char

.top_done:
    mov esi, ansi_reset
    call buf_str
    mov esi, ansi_erase_eol
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_frame_hline_bot
; Purpose:   Draws the bottom border of the frame:
;            ╰───╯ (UTF-8) or +---+ (ASCII)
; IN:        EAX = Row coordinate (1-based)
; OUT:       Appends bottom frame line to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_frame_hline_bot:
    save_regs
    push eax

    mov ebx, 1
    call ui_goto

    mov al, SLOT_BORDER
    call ui_color

    cmp byte [setting_charset], 1
    je .bot_l_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x95
    call buf_char
    mov al, 0xB0                ; '╰'
    call buf_char
    jmp .bot_dashes
.bot_l_ascii:
    mov al, CHAR_PLUS
    call buf_char

.bot_dashes:
    call ui_frame_emit_dashes

    cmp byte [setting_charset], 1
    je .bot_r_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x95
    call buf_char
    mov al, 0xAF                ; '╯'
    call buf_char
    jmp .bot_done
.bot_r_ascii:
    mov al, CHAR_PLUS
    call buf_char

.bot_done:
    mov esi, ansi_reset
    call buf_str
    mov esi, ansi_erase_eol
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_frame_hline_mid
; Purpose:   Draws a middle separator line across the frame:
;            ├───┤ (UTF-8) or +---+ (ASCII)
; IN:        EAX = Row coordinate (1-based)
; OUT:       Appends middle frame separator to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_frame_hline_mid:
    save_regs
    push eax

    mov ebx, 1
    call ui_goto

    mov al, SLOT_BORDER
    call ui_color

    cmp byte [setting_charset], 1
    je .mid_l_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x9C                ; '├'
    call buf_char
    jmp .mid_dashes
.mid_l_ascii:
    mov al, CHAR_PLUS
    call buf_char

.mid_dashes:
    call ui_frame_emit_dashes

    cmp byte [setting_charset], 1
    je .mid_r_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0xA4                ; '┤'
    call buf_char
    jmp .mid_done
.mid_r_ascii:
    mov al, CHAR_PLUS
    call buf_char

.mid_done:
    mov esi, ansi_reset
    call buf_str
    mov esi, ansi_erase_eol
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_frame_hline
; Purpose:   Positions cursor at frame (row, 1) and draws an adaptive horizontal
;            border line. Dispatches automatically to top border, bottom border,
;            or middle divider based on Row and State. Total width is ui_w cols.
;            Appends ESC[K to clear remainder of line.
;
; DEPRECATED: Retained for backward compatibility with unmigrated screens.
;             Preferred replacement API in new code: explicit calls to wdg_panel
;             or gfx_hline.
; IN:        EAX = Row coordinate (1-based)
; OUT:       Appends horizontal frame line to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_frame_hline:
    save_regs
    push eax

    cmp eax, 1
    je .call_top
    cmp eax, [ui_screen_bottom_row]
    je .call_bot
    cmp eax, 10
    je .check_timer_bot
    cmp eax, 16
    je .check_hab_bot
    cmp eax, 17
    je .check_jrn_bot
    cmp eax, 22
    je .call_bot
    cmp eax, 23
    je .call_bot

    call ui_frame_hline_mid
    jmp .hline_ret

.check_timer_bot:
    cmp dword [state], STATE_TIMER
    je .call_bot
    call ui_frame_hline_mid
    jmp .hline_ret

.check_hab_bot:
    cmp dword [state], STATE_HABITS
    je .call_bot
    cmp dword [state], STATE_MENU
    je .call_bot
    call ui_frame_hline_mid
    jmp .hline_ret

.check_jrn_bot:
    cmp dword [state], STATE_JOURNAL
    je .call_bot
    call ui_frame_hline_mid
    jmp .hline_ret

.call_top:
    call ui_frame_hline_top
    jmp .hline_ret

.call_bot:
    call ui_frame_hline_bot

.hline_ret:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_frame_row
; Purpose:   Positions cursor at frame (row, 1), writes left border ('│' or '|'),
;            erases from cursor to end of line via ESC[K, positions cursor at
;            frame column ui_w, and writes right border ('│' or '|').
; IN:        EAX = Row coordinate (1-based)
; OUT:       Appends cleared framed row to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_frame_row:
    save_regs
    push eax

    ; 1. Move to frame (row, 1)
    mov ebx, 1
    call ui_goto

    ; 2. Emit border color and left border ('│' in UTF-8 or '|' in ASCII)
    mov al, SLOT_BORDER
    call ui_color
    cmp byte [setting_charset], 1
    je .row_l_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x82                ; '│'
    call buf_char
    jmp .row_l_done
.row_l_ascii:
    mov al, CHAR_PIPE
    call buf_char
.row_l_done:
    ; Erase row interior with theme background color
    mov al, SLOT_BG
    call ui_bgcolor
    mov esi, ansi_erase_eol
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 4. Move directly to frame right border column ui_w
    mov eax, [esp]              ; Retrieve row
    mov ebx, [ui_w]
    call ui_goto

    ; 5. Emit border color and right border ('│' in UTF-8 or '|' in ASCII)
    mov al, SLOT_BORDER
    call ui_color
    cmp byte [setting_charset], 1
    je .row_r_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x94
    call buf_char
    mov al, 0x82                ; '│'
    call buf_char
    jmp .row_r_done
.row_r_ascii:
    mov al, CHAR_PIPE
    call buf_char
.row_r_done:
    mov esi, ansi_reset
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_text_at
; Purpose:   Helper routine that positions cursor at frame-relative (row, col)
;            and appends the string at ESI to out_buf.
; IN:        EAX = Row coordinate (1-based), EBX = Column coordinate (1-based, frame-relative),
;            ESI = Pointer to NUL-terminated string
; OUT:       Appends positioning and text to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_text_at:
    save_regs
    push eax

    call ui_goto
    call buf_str

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_goto
; Purpose:   Translates 1-based frame-relative coordinates (row, col) to absolute
;            terminal coordinates using ui_col0 (col_abs = col + ui_col0, row_abs = row)
;            and appends the ANSI cursor sequence ESC[r;cH to out_buf via buf_goto.
; IN:        EAX = Row coordinate (1-based)
;            EBX = Frame-relative column coordinate (1-based)
; OUT:       Appends ANSI cursor sequence to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_goto:
    save_regs
    push eax

    add ebx, [ui_col0]          ; Translate frame-relative col to absolute terminal col
    call buf_goto

    pop eax
    restore_regs
    ret

;=============================================================================
;=============================================================================
; Procedure: ui_layout_update
; Purpose:   Compatibility wrapper for layout_update (PRD_V3 §3.1, Task G6).
;            Maintains legacy procedure contract for unmigrated callers.
; IN:        None (uses [term_cols] and [term_rows])
; OUT:       Updates [layout_tier], [ui_w], [ui_h], [ui_col0], [ui_seen_cols], [ui_seen_rows]
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_layout_update:
    jmp layout_update

;=============================================================================
; Procedure: ui_draw_menu
; Purpose:   Draws all outer borders and clears inner rows first, wipes remaining
;            screen area below row 13 with ESC[J, then overlays cat art, bold
;            titles, daily statistics dashboard, and menu options.
; IN:        None (reads demo_mode, dash_pomodoros, dash_habits_done, dash_habits_total)
; OUT:       Appends complete menu frame to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_draw_menu:
    call ui_size_gate
    call ui_layout_update
    save_regs
    push eax

    ; Frame begins with cursor home via ui_goto(1, 1)
    mov eax, UI_MENU_ROW_TOP
    mov ebx, 1
    call ui_goto

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
    mov eax, UI_MENU_ROW_ITEM5
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
    mov ebx, 1
    call buf_goto
    mov al, SLOT_BG
    call ui_bgcolor
    mov esi, ansi_erase_eos
    call buf_str
    mov esi, ansi_reset
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
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, menu_title
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 3. Tagline "cozy focus - habits - notes" at Row 3, Col 14
    mov eax, UI_MENU_ROW_TAGLINE
    mov ebx, UI_MENU_COL_TITLE
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, menu_tagline
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 3b. Deterministic greeting at Row 4, Col 14
    mov eax, UI_MENU_ROW_CAT3
    mov ebx, UI_MENU_COL_TITLE
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    call ui_greeting_get
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 4. Dashboard line at Row 6, Col 4: "Today: N pomodoros      Habits: D/T done"
    mov eax, UI_MENU_ROW_DASH
    mov ebx, UI_MENU_COL_CONTENT
    call ui_goto

    mov esi, dash_lbl_today
    call buf_str
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, [dash_pomodoros]
    call buf_u32
    mov esi, ansi_reset
    call buf_str

    mov esi, dash_lbl_pomos
    call buf_str
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, [dash_habits_done]
    call buf_u32
    mov esi, ansi_reset
    call buf_str

    mov al, CHAR_SLASH
    call buf_char

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, [dash_habits_total]
    call buf_u32
    mov esi, ansi_reset
    call buf_str

    mov esi, dash_lbl_done
    call buf_str

    ; 4b. Deterministic daily cozy tip at Row 7, Col 4
    mov eax, UI_MENU_ROW_BLANK
    mov ebx, UI_MENU_COL_CONTENT
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str
    mov al, CHAR_SPACE
    call buf_char
    mov al, SLOT_DIM
    call ui_color
    call ui_tip_get
    call buf_str
    mov esi, ansi_reset
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
    call ui_goto
    mov esi, menu_item_4_prefix
    call buf_str

    cmp dword [demo_mode], 0
    jne .menu_demo_active
    mov al, SLOT_DIM
    call ui_color
    mov esi, menu_demo_off
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .menu_item_5

.menu_demo_active:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_OK
    call ui_color
    mov esi, menu_demo_on
    call buf_str
    mov esi, ansi_reset
    call buf_str
    mov al, CHAR_SPACE
    call buf_char
    mov al, CHAR_SPACE
    call buf_char
    mov al, SLOT_WARN
    call ui_color
    mov esi, dash_badge_demo
    call buf_str
    mov esi, ansi_reset
    call buf_str

.menu_item_5:
    ; [5] Settings
    mov eax, UI_MENU_ROW_ITEM5
    mov ebx, UI_MENU_COL_CONTENT
    mov esi, menu_item_5
    call ui_text_at

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

;=============================================================================
; Procedure: ui_draw_stub
; Purpose:   Draws a framed screen for placeholder screens (Timer, Habits,
;            Journal) with the given title and standard prompt:
;            "Coming soon — press B to go back". Wipes remaining lines below row 8.
; IN:        ESI = Pointer to NUL-terminated screen title string
; OUT:       Appends framed stub screen to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_draw_stub:
    call ui_size_gate
    call ui_layout_update
    save_regs
    push eax
    push esi                    ; Preserve title pointer across frame calls

    ; Frame begins with cursor home via ui_goto(1, 1)
    mov eax, UI_STUB_ROW_TOP
    mov ebx, 1
    call ui_goto

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
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content (Title, Message, Key Help)
    ; -------------------------------------------------------------------------
    ; 1. Title at Row 2, Col 4
    mov eax, UI_STUB_ROW_TITLE
    mov ebx, UI_STUB_COL_TITLE
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
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

;=============================================================================
; Procedure: ui_progress_bar
; Purpose:   Calculates proportion of elapsed time (EAX) against total duration (ECX)
;            and formats a 30-character progress bar:
;            '[' + filled '#' characters + empty '-' characters + ']' + "  " + percentage + '%'.
;            The number of filled characters is (elapsed * 30) / total.
;            The percentage is (elapsed * 100) / total.
;            Arithmetic uses unsigned MUL and DIV, with EDX explicitly zeroed.
;            Elapsed is clamped to total. If total is 0, progress is treated as 100%.
; IN:        EAX = Elapsed time in seconds, ECX = Total phase duration in seconds
; OUT:       Appends 30-char bar ([###---]) and percentage to buffer
; CLOBBERS:  None (preserves all)
;=============================================================================
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

    ; 2. Emit filled segments (EBX times) with SLOT_BAR_FULL
    mov al, SLOT_BAR_FULL
    call ui_color
    mov ecx, ebx
    test ecx, ecx
    jz .pb_empty_segments

.pb_fill_loop:
    cmp byte [setting_charset], 1
    je .pb_fill_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x96
    call buf_char
    mov al, 0xB0                ; '▰'
    call buf_char
    jmp .pb_fill_next
.pb_fill_ascii:
    mov al, CHAR_HASH
    call buf_char
.pb_fill_next:
    dec ecx
    jnz .pb_fill_loop

.pb_empty_segments:
    mov esi, ansi_reset
    call buf_str

    ; 3. Emit empty segments (PROGRESS_BAR_WIDTH - EBX times) with SLOT_BAR_EMPTY
    mov al, SLOT_BAR_EMPTY
    call ui_color
    mov ecx, PROGRESS_BAR_WIDTH
    sub ecx, ebx
    test ecx, ecx
    jz .pb_close_bracket

.pb_empty_loop:
    cmp byte [setting_charset], 1
    je .pb_empty_ascii
    mov al, 0xE2
    call buf_char
    mov al, 0x96
    call buf_char
    mov al, 0xB1                ; '▱'
    call buf_char
    jmp .pb_empty_next
.pb_empty_ascii:
    mov al, CHAR_MINUS
    call buf_char
.pb_empty_next:
    dec ecx
    jnz .pb_empty_loop

.pb_close_bracket:
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

    ; 6. Emit percentage integer as decimal digits
    mov eax, edi
    call buf_u32

    ; 7. Emit '%'
    mov al, CHAR_PERCENT
    call buf_char

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_size_gate
; Purpose:   Checks if terminal size is at least 80x24 via term_size_ok.
;            If smaller than 80x24, loops displaying an enlarge warning:
;              Row 1: "Please enlarge the terminal"
;              Row 2: "(need 80x24, now <cols>x<rows>)"
;            During loop, sleeps 100ms via time_sleep_100ms and polls for Ctrl+C.
;            If Ctrl+C is pressed, calls app_exit(EXIT_SUCCESS).
;            When dimensions recover to >= 80x24, appends ansi_clear to out_buf so
;            subsequent screen redraw paints on a pristine screen, and returns.
; IN:        None
; OUT:       None (gates execution until dimensions >= 80x24 or unknown)
; CLOBBERS:  None (preserves all)
;=============================================================================
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
    mov al, SLOT_WARN
    call ui_color
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
    mov al, SLOT_BG
    call ui_bgcolor
    mov esi, ansi_clear
    call buf_str
    mov esi, ansi_reset
    call buf_str

.gate_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: ui_draw_status
; Purpose:   Positions cursor at (EAX, 4) and emits string at ESI styled
;            according to EBX:
;              STATUS_INFO (0): SLOT_WARN
;              STATUS_OK (1):   ansi_bold + SLOT_OK
;              STATUS_ERR (2):  ansi_bold + SLOT_ERR
;            If ESI is 0 (NULL), nothing is drawn.
;            Always emits ansi_reset after message.
; IN:        EAX = Row coordinate (1-based), EBX = Status style,
;            ESI = Pointer to NUL-terminated message string (0 = none)
; OUT:       None (appends styled status message to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
ui_draw_status:
    save_regs
    push eax
    push ebx
    push esi

    test esi, esi
    jz .status_done             ; NULL pointer: do not draw anything

    ; Position cursor at frame (row, 4)
    mov ebx, 4
    call ui_goto

    ; Retrieve style from stack
    mov ebx, [esp + 4]

    cmp ebx, STATUS_OK
    je .status_style_ok
    cmp ebx, STATUS_ERR
    je .status_style_err

    ; STATUS_INFO: warning/info slot with [i] marker
    mov al, SLOT_WARN
    call ui_color
    mov esi, status_marker_info
    call buf_str
    jmp .status_emit

.status_style_ok:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_OK
    call ui_color
    mov esi, status_marker_ok
    call buf_str
    jmp .status_emit

.status_style_err:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ERR
    call ui_color
    mov esi, status_marker_err
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

; =============================================================================
; Task G5 Procedures: Big Digit Display & Theme Title Gradient (PRD_V3 §6, §10)
; =============================================================================

global bigdigit_draw
global title_gradient

;=============================================================================
; Procedure: bigdigit_draw
; Purpose:   Renders large pixel-art timer/numeric digits into out_buf at (row, col)
;            with a 1-cell horizontal gap between glyphs. In UTF-8 mode, draws
;            5x4-cell half-block sprites; in ASCII mode (setting_charset == 1),
;            renders 5x4 7-bit ASCII text representations.
; IN:        EAX = Starting terminal row (1-based)
;            EBX = Starting terminal column (1-based)
;            ECX = Numeric value (0..99) or duration in seconds (0..5999)
;            EDX = Format flag:
;                  BIGDIGIT_FMT_NUM (0)  = Ordinary numeric display (0..99)
;                  BIGDIGIT_FMT_MMSS (1) = Minutes:Seconds display (00:00..99:59)
; OUT:       Appends complete formatted digits to out_buf (leaves cursor at end)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
bigdigit_draw:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    sub esp, 28                 ; Local frame:
                                ; [esp + 0]  = d0 (first digit, 0..9)
                                ; [esp + 4]  = d1 (second digit, 0..9)
                                ; [esp + 8]  = d2 (third digit, 0..9 or -1)
                                ; [esp + 12] = d3 (fourth digit, 0..9 or -1)
                                ; [esp + 16] = format flag (0 or 1)
                                ; [esp + 20] = start_row (1-based)
                                ; [esp + 24] = start_col (1-based)

    mov [esp + 20], eax         ; Save row
    mov [esp + 24], ebx         ; Save col
    mov [esp + 16], edx         ; Save format

    ; -------------------------------------------------------------------------
    ; 1. Input Validation and Digit Decomposition
    ; -------------------------------------------------------------------------
    cmp edx, BIGDIGIT_FMT_MMSS
    jne .fmt_numeric

    ; --- Format MM:SS ---
    ; Clamp seconds to 0..5999 (99:59)
    test ecx, ecx
    jns .val_not_neg
    xor ecx, ecx
.val_not_neg:
    cmp ecx, 5999
    jbe .val_sec_ok
    mov ecx, 5999
.val_sec_ok:
    ; Minutes M = ECX / 60, Seconds S = ECX % 60
    mov eax, ecx
    xor edx, edx
    mov ebx, 60
    div ebx                     ; EAX = M, EDX = S

    ; d0 = M / 10, d1 = M % 10
    push edx                    ; Save seconds S
    xor edx, edx
    mov ebx, 10
    div ebx
    mov [esp + 4], eax          ; d0 = M / 10
    mov [esp + 8], edx          ; d1 = M % 10
    pop eax                     ; EAX = seconds S

    ; d2 = S / 10, d3 = S % 10
    xor edx, edx
    mov ebx, 10
    div ebx
    mov [esp + 8], eax          ; d2 = S / 10
    mov [esp + 12], edx         ; d3 = S % 10
    jmp .draw_digits

.fmt_numeric:
    ; --- Format Numeric (0..99) ---
    mov dword [esp + 16], BIGDIGIT_FMT_NUM ; Force safe format 0
    test ecx, ecx
    jns .num_not_neg
    xor ecx, ecx
.num_not_neg:
    cmp ecx, 99
    jbe .num_ok
    mov ecx, 99
.num_ok:
    mov eax, ecx
    xor edx, edx
    mov ebx, 10
    div ebx
    mov [esp + 0], eax          ; d0 = val / 10
    mov [esp + 4], edx          ; d1 = val % 10
    mov dword [esp + 8], -1     ; d2 = none
    mov dword [esp + 12], -1    ; d3 = none

.draw_digits:
    ; -------------------------------------------------------------------------
    ; 2. Charset Branch: ASCII mode vs UTF-8 half-block mode
    ; -------------------------------------------------------------------------
    cmp byte [setting_charset], 1
    je .draw_ascii_mode

    ; -------------------------------------------------------------------------
    ; 3. UTF-8 Half-Block Rendering Path (using sprite_draw)
    ; -------------------------------------------------------------------------
    ; Draw d0 at (start_row, start_col)
    mov edx, [esp + 0]          ; edx = d0
    mov esi, [digit_large_sprites + edx*4]
    mov eax, [esp + 20]         ; row
    mov ebx, [esp + 24]         ; col
    xor ecx, ecx                ; frame 0
    mov edx, SLOT_BG
    call sprite_draw

    ; Draw d1 at (start_row, start_col + 6)
    mov edx, [esp + 4]          ; edx = d1
    mov esi, [digit_large_sprites + edx*4]
    mov eax, [esp + 20]         ; row
    mov ebx, [esp + 24]
    add ebx, 6                  ; col + 6 (5 cells + 1 gap)
    xor ecx, ecx
    mov edx, SLOT_BG
    call sprite_draw

    ; If format != MMSS, done with UTF-8
    cmp dword [esp + 16], BIGDIGIT_FMT_MMSS
    jne .bigdigit_exit

    ; Draw Colon ':' at (start_row, start_col + 12)
    mov esi, [digit_large_sprites + 10*4] ; colon sprite
    mov eax, [esp + 20]
    mov ebx, [esp + 24]
    add ebx, 12                 ; col + 12
    xor ecx, ecx
    mov edx, SLOT_BG
    call sprite_draw

    ; Draw d2 at (start_row, start_col + 16)
    mov edx, [esp + 8]          ; edx = d2
    mov esi, [digit_large_sprites + edx*4]
    mov eax, [esp + 20]
    mov ebx, [esp + 24]
    add ebx, 16                 ; col + 16 (12 + 3 colon + 1 gap)
    xor ecx, ecx
    mov edx, SLOT_BG
    call sprite_draw

    ; Draw d3 at (start_row, start_col + 22)
    mov edx, [esp + 12]         ; edx = d3
    mov esi, [digit_large_sprites + edx*4]
    mov eax, [esp + 20]
    mov ebx, [esp + 24]
    add ebx, 22                 ; col + 22 (16 + 5 + 1)
    xor ecx, ecx
    mov edx, SLOT_BG
    call sprite_draw
    jmp .bigdigit_exit

    ; -------------------------------------------------------------------------
    ; 4. ASCII Mode Rendering Path (7-bit characters, 4 lines high)
    ; -------------------------------------------------------------------------
.draw_ascii_mode:
    xor ebp, ebp                ; ebp = line index (0..3)

.ascii_line_loop:
    cmp ebp, 4
    jae .bigdigit_exit

    ; Position cursor at (start_row + ebp, start_col)
    mov eax, [esp + 20]
    add eax, ebp
    mov ebx, [esp + 24]
    call ui_goto

    ; Apply title color for ASCII digits
    mov al, SLOT_TITLE
    call ui_color

    ; --- Emit d0 line ebp (5 chars) ---
    mov eax, [esp + 0]          ; d0
    imul eax, 20                ; 20 bytes per digit (4 lines * 5 chars)
    lea edx, [ebp * 4 + ebp]    ; edx = ebp * 5
    add eax, edx
    lea esi, [ascii_bigdigit_lines + eax]
    mov ecx, 5
.emit_d0_chars:
    lodsb
    call buf_char
    loop .emit_d0_chars

    ; 1-cell gap
    mov al, CHAR_SPACE
    call buf_char

    ; --- Emit d1 line ebp (5 chars) ---
    mov eax, [esp + 4]          ; d1
    imul eax, 20
    lea edx, [ebp * 4 + ebp]
    add eax, edx
    lea esi, [ascii_bigdigit_lines + eax]
    mov ecx, 5
.emit_d1_chars:
    lodsb
    call buf_char
    loop .emit_d1_chars

    ; Check if MM:SS format
    cmp dword [esp + 16], BIGDIGIT_FMT_MMSS
    jne .ascii_line_next

    ; --- Emit Colon line ebp (3 chars: center 3 of 5) ---
    mov al, CHAR_SPACE
    call buf_char
    mov eax, 10                 ; colon index = 10
    imul eax, 20
    lea edx, [ebp * 4 + ebp]
    add eax, edx
    add eax, 1                  ; offset into 3 center chars
    lea esi, [ascii_bigdigit_lines + eax]
    mov ecx, 3
.emit_colon_chars:
    lodsb
    call buf_char
    loop .emit_colon_chars

    mov al, CHAR_SPACE
    call buf_char

    ; --- Emit d2 line ebp (5 chars) ---
    mov eax, [esp + 8]          ; d2
    imul eax, 20
    lea edx, [ebp * 4 + ebp]
    add eax, edx
    lea esi, [ascii_bigdigit_lines + eax]
    mov ecx, 5
.emit_d2_chars:
    lodsb
    call buf_char
    loop .emit_d2_chars

    mov al, CHAR_SPACE
    call buf_char

    ; --- Emit d3 line ebp (5 chars) ---
    mov eax, [esp + 12]         ; d3
    imul eax, 20
    lea edx, [ebp * 4 + ebp]
    add eax, edx
    lea esi, [ascii_bigdigit_lines + eax]
    mov ecx, 5
.emit_d3_chars:
    lodsb
    call buf_char
    loop .emit_d3_chars

.ascii_line_next:
    inc ebp
    jmp .ascii_line_loop

.bigdigit_exit:
    ; Restore text color and reset styles
    mov al, SLOT_TEXT
    call ui_color
    call gfx_sgr_forget

    add esp, 28
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
; Procedure: title_gradient
; Purpose:   Renders spaced title string with a theme-aware color gradient into
;            out_buf. Spaced letters like "P A W M O D O R O" transition smoothly
;            from SLOT_TITLE to SLOT_TITLE_ALT across a precomputed 12-entry
;            color ramp per theme.
; IN:        ESI = Pointer to NUL-terminated title string
;            EAX = Starting terminal row (1-based)
;            EBX = Starting terminal column (1-based)
;            CL  = Starting color slot (SLOT_TITLE)
;            CH  = Ending color slot (SLOT_TITLE_ALT)
; OUT:       Appends spaced, gradient-colored title to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
title_gradient:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    test esi, esi
    jz .tg_done

    ; Measure string length
    xor edx, edx
.tg_len_loop:
    cmp byte [esi + edx], 0
    je .tg_len_found
    inc edx
    jmp .tg_len_loop
.tg_len_found:
    test edx, edx
    jz .tg_done                 ; Empty string: exit

    mov ebp, edx                ; EBP = length (L)

    ; Position cursor at (row, col)
    call ui_goto

    ; Determine active theme ramp base
    movzx eax, byte [setting_theme]
    cmp eax, NUM_BUILTIN_THEMES
    jb .tg_theme_ok
    xor eax, eax
.tg_theme_ok:
    imul eax, 12                ; 12 bytes per ramp
    lea edi, [theme_title_ramps + eax] ; EDI = ramp table pointer

    xor ecx, ecx                ; ECX = character index i (0..L-1)

.tg_char_loop:
    cmp ecx, ebp
    jae .tg_finish

    ; Compute ramp index: ramp_idx = (i * 12) / L
    mov eax, ecx
    imul eax, 12
    xor edx, edx
    div ebp                     ; EAX = quotient (0..11)
    cmp eax, 11
    jbe .tg_ramp_ok
    mov eax, 11
.tg_ramp_ok:
    ; Look up color byte (0..255)
    movzx eax, byte [edi + eax]

    ; Emit ESC[38;5;Nm escape sequence
    push esi
    mov esi, ansi_fg_256_prefix
    call buf_str
    call buf_u32
    mov al, CHAR_LOWER_M
    call buf_char
    pop esi

    ; Emit character ESI[i]
    mov al, [esi + ecx]
    call buf_char

    ; If not last character, emit space
    mov eax, ecx
    inc eax
    cmp eax, ebp
    jae .tg_next_char
    mov al, CHAR_SPACE
    call buf_char

.tg_next_char:
    inc ecx
    jmp .tg_char_loop

.tg_finish:
    ; Invalidate color cache and restore standard text color
    call gfx_sgr_forget
    mov al, SLOT_TEXT
    call ui_color

.tg_done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

; =============================================================================
; Task G6 Additions: Layout Test Screen (PRD_V3 §3, §10; Task G6)
; =============================================================================

;=============================================================================
; Procedure: layout_test_screen_draw
; Purpose:   Draws the hidden G6 layout and widget test screen. Exercises all
;            eleven widgets (wdg_panel, wdg_card, wdg_button, wdg_toggle,
;            wdg_progress_cat, wdg_stat_card, wdg_tip_card, wdg_list_row,
;            wdg_badge, wdg_keybar, wdg_checkbox_row) across all states and
;            demonstrates layout_split_h and layout_split_v.
; IN:        None
; OUT:       Appends complete frame to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
layout_test_screen_draw:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; 1. Recalculate layout geometry and tier
    call layout_update

    ; 2. Invalidate color cache and fill screen background in SLOT_BG
    call gfx_sgr_forget
    call gfx_fill_screen_bg

    ; -------------------------------------------------------------------------
    ; 3. Draw Header Region: banner, title, tier, mode, and state badges
    ; -------------------------------------------------------------------------
    mov eax, REGION_HEADER
    call layout_rect
    ; EAX = row, EBX = col, ECX = w, EDX = h
    ; Draw header panel
    push eax
    push ebx
    push ecx
    push edx
    mov esi, str_g6_title
    mov edi, WDG_PANEL_FLAG_TAB
    call wdg_panel
    pop edx
    pop ecx
    pop ebx
    pop eax

    ; Inside header: row + 1: title string
    inc eax
    add ebx, 2
    sub ecx, 4
    cmp ecx, 2
    jl .skip_header_content

    ; Title text
    mov esi, str_g6_title
    mov dl, SLOT_TITLE
    mov dh, SLOT_SURFACE
    call wdg_clip_text

    ; Subtitle badges at row + 2
    inc eax
    ; Tier badge
    mov esi, str_g6_tier_compact
    cmp dword [layout_tier], TIER_GRAND
    je .hdr_badge_grand
    cmp dword [layout_tier], TIER_STANDARD
    je .hdr_badge_std
    jmp .hdr_badge_draw
.hdr_badge_grand:
    mov esi, str_g6_tier_grand
    jmp .hdr_badge_draw
.hdr_badge_std:
    mov esi, str_g6_tier_standard
.hdr_badge_draw:
    mov dl, SLOT_ACCENT
    mov dh, SLOT_SURFACE
    call wdg_clip_text

.skip_header_content:

    ; -------------------------------------------------------------------------
    ; 4. Draw Footer Region: wdg_keybar with key hints
    ; -------------------------------------------------------------------------
    mov eax, REGION_FOOTER
    call layout_rect
    mov esi, g6_test_keybar_hints
    call wdg_keybar

    ; -------------------------------------------------------------------------
    ; 5. Draw Sidebar Region: buttons, toggles, checkboxes
    ; -------------------------------------------------------------------------
    mov eax, REGION_SIDEBAR
    call layout_rect
    ; EAX = row, EBX = col, ECX = w, EDX = h
    ; Panel outline for sidebar
    push eax
    push ebx
    push ecx
    push edx
    mov esi, 0
    mov edi, WDG_PANEL_FLAG_NONE
    call wdg_panel
    pop edx
    pop ecx
    pop ebx
    pop eax

    ; Inner sidebar controls:
    ; Row 1: Focus button (state = layout_test_state)
    inc eax
    add ebx, 2
    sub ecx, 4
    cmp ecx, 6
    jl .sidebar_done

    push eax
    push edx
    mov edx, 2                  ; height = 2
    mov esi, sprite_icon_timer_compact
    mov edi, str_g6_btn_focus
    mov ebp, [layout_test_state]
    call wdg_button
    pop edx
    pop eax

    ; Row 2: Habits button (normal)
    add eax, 3
    cmp eax, [ui_h]
    jg .sidebar_done
    push eax
    push edx
    mov edx, 2
    mov esi, sprite_icon_habits_compact
    mov edi, str_g6_btn_habits
    mov ebp, WDG_STATE_NORMAL
    call wdg_button
    pop edx
    pop eax

    ; Row 3: Journal button (pressed test)
    add eax, 3
    cmp eax, [ui_h]
    jg .sidebar_done
    push eax
    push edx
    mov edx, 2
    mov esi, sprite_icon_journal_compact
    mov edi, str_g6_btn_journal
    mov ebp, WDG_STATE_PRESSED
    call wdg_button
    pop edx
    pop eax

    ; Row 4: Demo toggle widget
    add eax, 3
    cmp eax, [ui_h]
    jg .sidebar_done
    push eax
    push edx
    mov edx, 2
    mov esi, str_g6_toggle_label
    mov edi, [demo_mode]
    call wdg_toggle
    pop edx
    pop eax

    ; Row 5: Checkbox row (checked)
    add eax, 3
    cmp eax, [ui_h]
    jg .sidebar_done
    push eax
    push edx
    mov edx, 1
    mov esi, str_g6_check_lbl
    mov edi, 1                  ; checked = 1
    call wdg_checkbox_row
    pop edx
    pop eax

    ; Row 6: Checkbox row (unchecked)
    inc eax
    cmp eax, [ui_h]
    jg .sidebar_done
    push eax
    push edx
    mov edx, 1
    mov esi, str_g6_list_label2
    xor edi, edi                ; checked = 0
    call wdg_checkbox_row
    pop edx
    pop eax

.sidebar_done:

    ; -------------------------------------------------------------------------
    ; 6. Draw Card Regions Inside MAIN
    ; -------------------------------------------------------------------------

    ; CARD_POMO: Stat card with mascot
    mov eax, REGION_CARD_POMO
    call layout_rect
    mov esi, 13                 ; Pomodoros count
    mov edi, str_g6_stat_caption
    call wdg_stat_card

    ; CARD_HABITS: Progress cat card
    mov eax, REGION_CARD_HABITS
    call layout_rect
    ; Draw outer card
    push eax
    push ebx
    push ecx
    push edx
    mov esi, str_g6_card_title
    mov edi, SLOT_SURFACE_ALT
    call wdg_card
    pop edx
    pop ecx
    pop ebx
    pop eax

    ; Inside habits card: wdg_progress_cat
    inc eax
    add ebx, 2
    sub ecx, 4
    cmp ecx, 8
    jl .skip_habits_bar

    ; Progress 1: 3/5 with cat head
    push eax
    push edx
    mov edx, 2
    mov esi, 3
    mov edi, 5
    call wdg_progress_cat
    pop edx
    pop eax

    ; Progress 2 (if height >= 6): m = 0 guard test (0/0)
    add eax, 3
    cmp edx, 6
    jl .skip_habits_bar
    push eax
    push edx
    mov edx, 2
    xor esi, esi
    xor edi, edi                ; m = 0!
    call wdg_progress_cat
    pop edx
    pop eax

.skip_habits_bar:

    ; CARD_TIP: Tip card with word wrap
    mov eax, REGION_CARD_TIP
    call layout_rect
    mov esi, str_g6_tip_body
    call wdg_tip_card

    ; CARD_JOURNAL_BTN: Action button
    mov eax, REGION_CARD_JOURNAL_BTN
    call layout_rect
    mov esi, 0
    mov edi, str_g6_btn_journal
    mov ebp, WDG_STATE_NORMAL
    call wdg_button

    ; CARD_JOURNAL: Recent notes list rows and badges
    mov eax, REGION_CARD_JOURNAL
    call layout_rect
    ; Draw outer card
    push eax
    push ebx
    push ecx
    push edx
    mov esi, str_g6_long_title  ; Test long title clipping!
    mov edi, SLOT_SURFACE_ALT
    call wdg_card
    pop edx
    pop ecx
    pop ebx
    pop eax

    ; Inside card: list rows
    inc eax
    add ebx, 2
    sub ecx, 4
    cmp ecx, 10
    jl .skip_journal_content

    ; List Row 1: Selected
    push eax
    push edx
    mov edx, 1
    mov esi, str_g6_list_label1
    mov edi, str_g6_list_val1
    mov ebp, 1                  ; selected = 1
    call wdg_list_row
    pop edx
    pop eax

    ; List Row 2: Unselected
    inc eax
    push eax
    push edx
    mov edx, 1
    mov esi, str_g6_list_label2
    mov edi, str_g6_list_val2
    xor ebp, ebp                ; selected = 0
    call wdg_list_row
    pop edx
    pop eax

    ; Badges row:
    inc eax
    push eax
    push ebx
    push ecx
    push edx
    mov edx, 1
    mov ecx, 6
    mov esi, str_g6_badge_new
    mov dl, SLOT_OK
    mov dh, SLOT_SURFACE
    call wdg_badge

    ; Second badge
    add ebx, 7
    mov ecx, 6
    mov esi, str_g6_badge_pro
    mov dl, SLOT_ACCENT
    mov dh, SLOT_SURFACE
    call wdg_badge

    ; Intentionally narrow/clipped badge test
    add ebx, 7
    mov ecx, 6                  ; only 6 cols for VERY_LONG_BADGE_TEXT
    mov esi, str_g6_badge_clipped
    mov dl, SLOT_WARN
    mov dh, SLOT_SURFACE
    call wdg_badge

    pop edx
    pop ecx
    pop ebx
    pop eax

.skip_journal_content:

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
; Procedure: layout_test_screen_run
; Purpose:   Interactive runner for the hidden layout and widget test screen.
;            Handles resize, theme/coat cycling, ASCII toggle, state toggling,
;            and clean return to main menu.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
layout_test_screen_run:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Save active settings
    mov al, [setting_theme]
    push eax                    ; [esp+8] = saved theme
    mov al, [setting_coat]
    push eax                    ; [esp+4] = saved coat
    mov al, [setting_charset]
    push eax                    ; [esp] = saved charset

    ; Initialize test state: normal (0)
    mov dword [layout_test_state], WDG_STATE_NORMAL

.test_redraw_loop:
    call layout_test_screen_draw
    ; Single-write flush per frame (PRD_V3 invariant!)
    call buf_flush

.test_key_loop:
    call key_wait
    cmp eax, KEY_NONE
    je .test_key_loop

    ; --- Key Dispatches ---
    ; Escape or 'Q' or 'q' -> Exit test screen cleanly
    cmp eax, KEY_ESC
    je .test_exit_clean
    cmp eax, 'q'
    je .test_exit_clean
    cmp eax, 'Q'
    je .test_exit_clean
    cmp eax, CHAR_SPACE
    je .test_exit_clean
    cmp eax, KEY_ENTER
    je .test_exit_clean

    ; Ctrl+C -> Signal app exit
    cmp eax, KEY_CTRL_C
    jne .test_check_theme
    mov dword [state], STATE_QUIT
    jmp .test_exit_clean

.test_check_theme:
    ; 't' or 'T' -> Cycle theme (0..6)
    cmp eax, 't'
    je .cycle_theme
    cmp eax, 'T'
    je .cycle_theme
    jmp .test_check_coat

.cycle_theme:
    movzx eax, byte [setting_theme]
    inc eax
    cmp eax, 7
    jb .theme_ok
    xor eax, eax
.theme_ok:
    mov [setting_theme], al
    call settings_apply_palette
    jmp .test_redraw_loop

.test_check_coat:
    ; 'c' or 'C' -> Cycle cat coat (0..5)
    cmp eax, 'c'
    je .cycle_coat
    cmp eax, 'C'
    je .cycle_coat
    jmp .test_check_ascii

.cycle_coat:
    movzx eax, byte [setting_coat]
    inc eax
    cmp eax, 6
    jb .coat_ok
    xor eax, eax
.coat_ok:
    mov [setting_coat], al
    mov al, [setting_theme]
    call settings_apply_palette
    jmp .test_redraw_loop

.test_check_ascii:
    ; 'a' or 'A' -> Toggle ASCII mode (0 <-> 1)
    cmp eax, 'a'
    je .toggle_ascii
    cmp eax, 'A'
    je .toggle_ascii
    jmp .test_check_states

.toggle_ascii:
    xor byte [setting_charset], 1
    jmp .test_redraw_loop

.test_check_states:
    ; '1' -> Normal state
    cmp eax, '1'
    jne .check_st2
    mov dword [layout_test_state], WDG_STATE_NORMAL
    jmp .test_redraw_loop
.check_st2:
    ; '2' -> Focused state
    cmp eax, '2'
    jne .check_st3
    mov dword [layout_test_state], WDG_STATE_FOCUSED
    jmp .test_redraw_loop
.check_st3:
    ; '3' -> Pressed state
    cmp eax, '3'
    jne .test_redraw_loop
    mov dword [layout_test_state], WDG_STATE_PRESSED
    jmp .test_redraw_loop

.test_exit_clean:
    ; Restore saved settings so test doesn't inadvertently alter user settings
    pop eax
    mov [setting_charset], al
    pop eax
    mov [setting_coat], al
    pop eax
    mov [setting_theme], al
    call settings_apply_palette

    ; Clean up screen and signal redraw to menu
    call gfx_fill_screen_bg
    mov dword [need_redraw], 1

    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret
