; =============================================================================
; Pawmodoro - Habit Tracker Engine & Persistence (src/habits.asm)
;
; Purpose: Habit lifecycle management, daily check-in validation, 7-day visual
;          history bitmasking, persistence in habits.dat, and UI view rendering
;          per PRD §4.3 (FR-H1 to FR-H6), §4.5 (FR-D1, FR-D3, FR-D4), §5, §6.4.
; Reference: PRD §4.3 (FR-H1–FR-H6), §4.5 (FR-D1, FR-D3, FR-D4), §5, §6.3, §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: habits_get_record
; Purpose:   Calculates habit_records + (index * 48) using LEA and SHL arithmetic.
;            Adheres to coding conventions prohibiting IMUL instructions.
; IN:        EAX = Record index (0..MAX_HABITS - 1)
; OUT:       EAX = Pointer to habit record in memory
; CLOBBERS:  EAX
;=============================================================================
habits_get_record:
    lea eax, [eax + eax*2]      ; EAX = index * 3
    shl eax, 4                  ; EAX = (index * 3) * 16 = index * 48
    add eax, habit_records      ; EAX = habit_records + (index * 48)
    ret

;=============================================================================
; Procedure: habits_done_today
; Purpose:   Iterates over all stored habits. Compares each habit's last_day
;            against current local day (time_today). If last_day == today, increments
;            done count. Returns done count in EAX and total habit count in EBX.
;            CRITICAL CALLING CONVENTION NOTE:
;            Does NOT use save_regs / restore_regs because EBX is a documented
;            procedure output register. Manually pushes and pops ECX, EDX, ESI, EDI.
; IN:        None
; OUT:       EAX = Habits checked in today, EBX = Total habit count
; CLOBBERS:  EAX, EBX
;=============================================================================
habits_done_today:
    push ecx
    push edx
    push esi
    push edi

    ; Obtain current local day number
    call time_today             ; EAX = current local day number
    mov edx, eax                ; EDX = today

    xor eax, eax                ; EAX = done count accumulator (0)
    mov ebx, [habit_count]      ; EBX = total habit count
    test ebx, ebx
    jz .done_today_exit

    mov esi, habit_records      ; ESI = base of records array
    mov ecx, ebx                ; ECX = iteration counter

.done_today_loop:
    cmp [esi + HABIT_OFFSET_LAST_DAY], edx
    jne .done_today_next
    inc eax                     ; Habit checked in today: increment done counter

.done_today_next:
    add esi, HABIT_RECORD_SIZE  ; Advance to next 48-byte record
    dec ecx
    jnz .done_today_loop

.done_today_exit:
    pop edi
    pop esi
    pop edx
    pop ecx
    ret

;=============================================================================
; Procedure: habits_sync_dashboard
; Purpose:   Invokes habits_done_today and updates dash_habits_done and
;            dash_habits_total in src/data.asm so the main menu displays
;            accurate live statistics upon startup and return.
; IN:        None
; OUT:       None (updates [dash_habits_done] and [dash_habits_total])
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_sync_dashboard:
    save_regs
    call habits_done_today      ; EAX = done today, EBX = total
    mov [dash_habits_done], eax
    mov [dash_habits_total], ebx
    restore_regs
    ret

;=============================================================================
; Procedure: habits_save
; Purpose:   Calculates the exact byte length to persist: 4 bytes for habit_count
;            plus 48 bytes per habit record (4 + count*48). A zero-habit file is
;            valid and occupies exactly 4 bytes. Writes data via file_save.
; IN:        None
; OUT:       EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on write failure
; CLOBBERS:  EAX
;=============================================================================
habits_save:
    save_regs

    ; Calculate write length: 4 + (count * 48)
    mov edx, [habit_count]
    lea ecx, [edx + edx*2]      ; ECX = count * 3
    shl ecx, 4                  ; ECX = count * 48
    add ecx, HABIT_HEADER_SIZE  ; ECX = 4 + count * 48

    ; Call file_save(path = path_habits, buf = habit_data, len = ECX)
    mov esi, path_habits
    mov edi, habit_data
    call file_save              ; EAX = 0 or -1

    restore_regs
    ret

;=============================================================================
; Procedure: habits_load
; Purpose:   Reads up to HABIT_MAX_FILE_SIZE (388) bytes from habits.dat via
;            file_load into habit_data. Validates integrity per PRD §4.5 FR-D1,
;            FR-D3, and §7. Treats file as empty state (habit_count = 0) if:
;            1. Bytes read < 4 (missing file returns -1, empty file returns 0).
;            2. Stored habit_count > MAX_HABITS (8).
;            3. Bytes read < (4 + count*48) (truncated/corrupted file).
;            After a valid load, forces byte 31 of every habit's name to NUL
;            to prevent string buffer overreads. Syncs dashboard statistics.
;            Never crashes and never prints to stderr.
; IN:        None
; OUT:       None (initializes habit_data, syncs dashboard counters)
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_load:
    save_regs
    push eax

    ; Attempt to load maximum habit storage block (388 bytes)
    mov esi, path_habits
    mov edi, habit_data
    mov ecx, HABIT_MAX_FILE_SIZE
    call file_load

    ; Check 1: Return must be at least HABIT_MIN_FILE_SIZE (4 bytes)
    ; Note: file_load returns -1 on error/missing file; test sign bit
    test eax, eax
    js .load_empty
    cmp eax, HABIT_MIN_FILE_SIZE
    jb .load_empty

    ; Check 2: Stored habit count must be <= MAX_HABITS (8)
    mov edx, [habit_count]
    cmp edx, MAX_HABITS
    ja .load_empty

    ; Check 3: Bytes read must be >= 4 + (count * 48)
    lea ecx, [edx + edx*2]      ; ECX = count * 3
    shl ecx, 4                  ; ECX = count * 48
    add ecx, HABIT_HEADER_SIZE  ; ECX = 4 + count * 48
    cmp eax, ecx
    jb .load_empty

    ; File is valid! Ensure byte 31 of every habit name is NUL-terminated
    mov ecx, [habit_count]
    test ecx, ecx
    jz .load_sync

    mov edi, habit_records
.load_nul_loop:
    mov byte [edi + HABIT_NAME_MAX], CHAR_NULL
    add edi, HABIT_RECORD_SIZE
    dec ecx
    jnz .load_nul_loop
    jmp .load_sync

.load_empty:
    ; Fallback to empty state: habit_count = 0
    mov dword [habit_count], 0

.load_sync:
    ; Synchronize dashboard summary counters
    call habits_sync_dashboard

    ; Reset UI message pointer
    mov dword [habit_msg], 0

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: habits_draw_row
; Purpose:   Assembles row (5 + index) for habit record index EAX.
;            - Column 4: Number (e.g. "1.")
;            - Column 7: Name (up to HABIT_NAME_DISPLAY = 12 characters).
;                        Sanitizes bytes < 0x20 or == 0x7F to '?' to prevent ANSI injection.
;            - Column 20: 7 history squares ([#] or [.]) based on shifted history bitmask.
;            - Column 43: Streak count (0 if delta > 1 or last_day == 0).
;            - Column 50: Lifetime total check-ins.
; IN:        EAX = Record index (0..MAX_HABITS - 1),
;            EBX = Screen row coordinate (UI_HAB_ROW_FIRST + index),
;            EDX = Current local day number (from time_today)
; OUT:       Appends formatted habit row text to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_draw_row:
    save_regs
    push edx                    ; [esp + 8] = today's day number
    push ebx                    ; [esp + 4] = screen row coordinate
    push eax                    ; [esp]     = habit index (0..7)

    ; 1. Obtain record address
    call habits_get_record      ; EAX = record address
    mov esi, eax                ; ESI = record pointer

    ; 2. Render Habit Number at (Row, Col 4): "<num>."
    mov eax, [esp + 4]          ; EAX = row
    mov ebx, UI_HAB_COL_NUM     ; EBX = Col 4
    call ui_goto

    mov eax, [esp]              ; EAX = index (0..7)
    inc eax                     ; Display 1-based (1..8)
    call buf_u32
    mov al, CHAR_DOT            ; '.'
    call buf_char

    ; 3. Render Habit Name at (Row, Col 7) - Clipped via buf_str_clip
    mov eax, [esp + 4]
    mov ebx, UI_HAB_COL_NAME
    call ui_goto

    ; Available width for habit name:
    ; squares start at (ui_w - 36). Leaving 1 space gap before squares:
    ; available = (ui_w - 36) - 1 - col_name = ui_w - 44
    ; Clamp available columns to HABIT_NAME_MAX (31)
    mov ecx, [ui_w]
    sub ecx, 44
    cmp ecx, HABIT_NAME_MAX     ; 31
    jbe .row_clip_calc
    mov ecx, HABIT_NAME_MAX

.row_clip_calc:
    push esi
    add esi, HABIT_OFFSET_NAME  ; Pointer to habit name string
    call buf_str_clip
    pop esi

.row_name_done:
    ; 4. Calculate delta = today - last_day (with last_day > today edge case guard)
    mov edx, [esp + 8]          ; EDX = today's day number
    mov eax, [esi + HABIT_OFFSET_LAST_DAY] ; EAX = last_day

    test eax, eax
    jz .row_new_habit           ; last_day == 0: new habit never checked in

    cmp eax, edx
    ja .row_future_day          ; last_day > today: clock shifted back or hand-edited future

    ; delta = today - last_day
    mov ecx, edx
    sub ecx, eax                ; ECX = delta (>= 0)
    jmp .row_calc_streak

.row_new_habit:
    mov ecx, BITS_PER_DWORD     ; Treat new habit as huge delta (>= 32)
    xor edx, edx                ; Displayed streak = 0
    xor edi, edi                ; Shifted history = 0
    jmp .row_render_squares

.row_future_day:
    xor ecx, ecx                ; Treat future day as delta = 0 (same as today)

.row_calc_streak:
    ; Displayed streak rule (FR-H5):
    ; If delta > 1, streak is broken -> display 0. Otherwise, display stored streak.
    cmp ecx, 1
    ja .row_streak_broken
    mov edx, [esi + HABIT_OFFSET_STREAK] ; EDX = streak
    jmp .row_calc_history

.row_streak_broken:
    xor edx, edx                ; Display streak as 0

.row_calc_history:
    ; Shift history for 7 squares display (FR-H5):
    ; shifted = (delta >= 32 ? 0 : history << delta)
    mov eax, [esi + HABIT_OFFSET_HISTORY]
    cmp ecx, BITS_PER_DWORD     ; 32
    jae .row_hist_zero
    shl eax, cl                 ; Shift history left by delta
    mov edi, eax                ; EDI = shifted history
    jmp .row_render_squares

.row_hist_zero:
    xor edi, edi                ; EDI = 0

.row_render_squares:
    ; EDX currently holds the displayed streak
    ; EDI currently holds the shifted history bitmask
    push edx                    ; [esp] = displayed streak

    ; 5. Render 7 History Squares at (Row, Col ui_w - 36)
    mov eax, [esp + 8]          ; EAX = row coordinate
    mov ebx, [ui_w]
    sub ebx, UI_HAB_OFF_SQUARES ; ui_w - 36
    call ui_goto

    ; Iterate bits 6 down to 0 (oldest on left, newest on right)
    mov ecx, 6                  ; ECX = bit index (6..0)

.row_squares_loop:
    bt edi, ecx                 ; Test bit ECX of shifted history bitmask
    jc .row_square_done

    ; Bit is 0: not done -> dim "[.]"
    mov al, SLOT_DIM
    call ui_color
    mov al, CHAR_LBRACKET       ; '['
    call buf_char
    mov al, CHAR_DOT            ; '.'
    call buf_char
    mov al, CHAR_RBRACKET       ; ']'
    call buf_char
    mov esi, ansi_reset
    call buf_str
    jmp .row_square_next

.row_square_done:
    ; Bit is 1: checked in -> bright green "[#]"
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_OK
    call ui_color
    mov al, CHAR_LBRACKET       ; '['
    call buf_char
    mov al, CHAR_HASH           ; '#'
    call buf_char
    mov al, CHAR_RBRACKET       ; ']'
    call buf_char
    mov esi, ansi_reset
    call buf_str

.row_square_next:
    dec ecx
    jns .row_squares_loop       ; Loop until ECX becomes negative (6 down to 0)

    ; 6. Render Streak at (Row, Col ui_w - 13)
    mov eax, [esp + 8]          ; EAX = row coordinate
    mov ebx, [ui_w]
    sub ebx, UI_HAB_OFF_STREAK  ; ui_w - 13
    call ui_goto

    pop eax                     ; Restore displayed streak from stack
    call buf_u32

    ; 7. Render Total Check-ins at (Row, Col ui_w - 6)
    mov eax, [esp + 4]          ; EAX = row coordinate
    mov ebx, [ui_w]
    sub ebx, UI_HAB_OFF_TOTAL   ; ui_w - 6
    call ui_goto

    mov eax, [esp]              ; EAX = habit index
    call habits_get_record      ; EAX = record pointer
    mov eax, [eax + HABIT_OFFSET_TOTAL]
    call buf_u32

    ; Clean up stack frame
    add esp, 12                 ; Discard habit index, row, today
    restore_regs
    ret

;=============================================================================
; Procedure: habits_draw
; Purpose:   Constructs the 56-column Habit Tracker screen in out_buf adhering
;            to PRD §5 wireframe. Implements the two-phase rendering pattern:
;            Phase 1: Moves cursor to (1,1), draws borders and cleared rows
;                     (Rows 1..16), and clears below the frame with ESC[J.
;            Phase 2: Overlays title, column headers, separator, habit records,
;                     feedback message, and key help prompts.
;            NOTE: Does NOT flush the buffer. Caller invokes buf_flush.
; IN:        None
; OUT:       Appends entire frame escape sequences and text to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_draw:
    call ui_size_gate           ; Terminal dimension check gate (Task 9)
    call ui_layout_update       ; Recalculate adaptive layout geometry (PRD v2 §2)
    save_regs
    mov dword [ui_screen_bottom_row], UI_HAB_ROW_BOTTOM

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Borders and Erase Inner Rows (FR-U4)
    ; -------------------------------------------------------------------------
    ; Position cursor at home (1,1)
    mov eax, UI_HAB_ROW_TOP
    mov ebx, 1
    call ui_goto

    ; Row 1: Top border line
    mov eax, UI_HAB_ROW_TOP
    call ui_frame_hline

    ; Rows 2..15: Erase each row with ESC[K and anchor right border '|' at col ui_w
    mov ecx, UI_HAB_ROW_TITLE   ; Row 2
.draw_erase_loop:
    mov eax, ecx
    call ui_frame_row
    inc ecx
    cmp ecx, UI_HAB_ROW_HELP    ; Row 15
    jbe .draw_erase_loop

    ; Row 16: Bottom border line
    mov eax, UI_HAB_ROW_BOTTOM
    call ui_frame_hline

    ; Row 17: Erase to bottom of terminal screen (ESC[J)
    mov eax, UI_HAB_ROW_BELOW
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content at Absolute Cursor Coordinates
    ; -------------------------------------------------------------------------
    ; 1. Title Row (Row 2, Col 4): "HABIT TRACKER" (bold bright cyan)
    mov eax, UI_HAB_ROW_TITLE
    mov ebx, UI_HAB_COL_TITLE
    call ui_goto

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    mov esi, title_habits       ; "HABIT TRACKER"
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 2. Column Headers (Row 3, adaptive columns)
    mov eax, UI_HAB_ROW_HEADER
    mov ebx, UI_HAB_COL_NUM     ; Col 4
    call ui_goto
    mov esi, habits_hdr_num     ; "#"
    call buf_str

    mov eax, UI_HAB_ROW_HEADER
    mov ebx, UI_HAB_COL_NAME    ; Col 7
    call ui_goto
    mov esi, habits_hdr_name    ; "HABIT"
    call buf_str

    mov eax, UI_HAB_ROW_HEADER
    mov ebx, [ui_w]
    sub ebx, UI_HAB_OFF_SQUARES ; ui_w - 36
    call ui_goto
    mov esi, habits_hdr_squares ; "LAST 7 DAYS"
    call buf_str

    mov eax, UI_HAB_ROW_HEADER
    mov ebx, [ui_w]
    sub ebx, UI_HAB_OFF_STREAK  ; ui_w - 13
    call ui_goto
    mov esi, habits_hdr_streak  ; "STREAK"
    call buf_str

    mov eax, UI_HAB_ROW_HEADER
    mov ebx, [ui_w]
    sub ebx, UI_HAB_OFF_TOTAL   ; ui_w - 6
    call ui_goto
    mov esi, habits_hdr_total   ; "TOTAL"
    call buf_str

    ; 3. Separator Border (Row 4)
    mov eax, UI_HAB_ROW_SEP
    mov ebx, 1
    call ui_goto
    mov eax, UI_HAB_ROW_SEP
    call ui_frame_hline

    ; 4. Habit Records (Rows 5..12)
    call time_today             ; EAX = current local day number
    mov edx, eax                ; EDX = today

    mov ecx, [habit_count]
    test ecx, ecx
    jnz .draw_records_exist

    ; Empty state: show prompt message on Row 5
    mov eax, UI_HAB_ROW_FIRST
    mov ebx, UI_HAB_COL_NUM
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov esi, habit_msg_empty    ; "No habits yet - press A to add one."
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .draw_feedback_msg

.draw_records_exist:
    xor ecx, ecx                ; ECX = habit record index (0..habit_count - 1)

.draw_records_loop:
    push ecx                    ; [esp + 4] = index
    push edx                    ; [esp]     = today

    mov eax, ecx                ; EAX = index
    mov ebx, UI_HAB_ROW_FIRST
    add ebx, ecx                ; EBX = row coordinate (5 + index)
    ; EDX is already today
    call habits_draw_row

    pop edx
    pop ecx

    inc ecx
    cmp ecx, [habit_count]
    jb .draw_records_loop

.draw_feedback_msg:
    ; 5. Message Row (Row 14, Col 4)
    mov esi, [habit_msg]
    test esi, esi
    jz .draw_key_help

    mov eax, UI_HAB_ROW_MSG
    cmp esi, err_could_not_save
    je .msg_style_err
    cmp esi, habit_msg_checked_in
    je .msg_style_ok
    cmp esi, habit_msg_deleted
    je .msg_style_ok

    mov ebx, STATUS_INFO
    call ui_draw_status
    jmp .clear_msg

.msg_style_err:
    mov ebx, STATUS_ERR
    call ui_draw_status
    jmp .clear_msg

.msg_style_ok:
    mov ebx, STATUS_OK
    call ui_draw_status

.clear_msg:
    mov dword [habit_msg], 0

.draw_key_help:
    ; 6. Key Help Prompt (Row 15, Col 4)
    mov eax, UI_HAB_ROW_HELP
    mov ebx, UI_HAB_COL_HELP
    call ui_goto

    mov esi, habits_help
    call buf_str

    restore_regs
    ret

;=============================================================================
; Procedure: habits_check_in
; Purpose:   Implements FR-H4 check-in rules:
;            1. Maps key to 0-based habit index (key - KEY_1).
;            2. Validates index < habit_count (rejects invalid numbers with message).
;            3. Computes delta = today - last_day (guarding last_day > today).
;            4. If delta == 0: sets "Already done today", no state change, no save.
;            5. If delta > 0:
;               - history = (delta >= 32 ? 0 : history << delta) | 1
;               - streak = (delta == 1) ? streak + 1 : 1
;               - total += 1
;               - last_day = today
;               - syncs dashboard and saves to habits.dat.
; IN:        EAX = Key code (KEY_1..KEY_8)
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_check_in:
    save_regs
    push eax                    ; [esp] = key code

    sub eax, KEY_1              ; EAX = 0-based habit index (0..7)
    cmp eax, [habit_count]
    jae .chk_no_habit

    ; Valid habit index
    call habits_get_record      ; EAX = pointer to record
    mov esi, eax                ; ESI = record pointer

    call time_today             ; EAX = today's day number
    mov edx, eax                ; EDX = today

    mov ebx, [esi + HABIT_OFFSET_LAST_DAY] ; EBX = last_day

    ; Edge case: if last_day > today (clock shifted back or hand-edited future day),
    ; treat as delta = 0 ("Already done today")
    cmp ebx, edx
    ja .chk_already_done

    ; Calculate delta = today - last_day
    mov ecx, edx
    sub ecx, ebx                ; ECX = delta

    test ecx, ecx
    jz .chk_already_done

    ; Delta > 0: perform check-in
    ; 1. History update: (delta >= 32 ? 0 : history << delta) | 1
    mov eax, [esi + HABIT_OFFSET_HISTORY]
    cmp ecx, BITS_PER_DWORD     ; 32
    jae .chk_hist_zero
    shl eax, cl                 ; Shift history left by delta
    jmp .chk_hist_set_bit0

.chk_hist_zero:
    xor eax, eax

.chk_hist_set_bit0:
    or eax, 1                   ; Set bit 0 (checked in today)
    mov [esi + HABIT_OFFSET_HISTORY], eax

    ; 2. Streak update: (delta == 1) ? streak + 1 : 1
    cmp ecx, 1
    je .chk_inc_streak
    mov dword [esi + HABIT_OFFSET_STREAK], 1
    jmp .chk_update_total

.chk_inc_streak:
    inc dword [esi + HABIT_OFFSET_STREAK]

.chk_update_total:
    ; 3. Total count update: total += 1
    inc dword [esi + HABIT_OFFSET_TOTAL]

    ; 4. Update last_day = today
    mov [esi + HABIT_OFFSET_LAST_DAY], edx

    ; Synchronize dashboard summary counters
    call habits_sync_dashboard

    ; Persist updated data to habits.dat
    call habits_save
    test eax, eax
    jz .chk_save_ok

    ; Save failed: flag error for display (FR-D4)
    mov dword [habit_msg], err_could_not_save
    jmp .chk_finish

.chk_save_ok:
    mov dword [habit_msg], habit_msg_checked_in
    jmp .chk_finish

.chk_already_done:
    mov dword [habit_msg], habit_msg_already
    jmp .chk_finish

.chk_no_habit:
    mov dword [habit_msg], habit_msg_no_habit

.chk_finish:
    mov dword [need_redraw], 1
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: habits_add
; Purpose:   Implements FR-H3 addition:
;            1. Rejects if habit_count == MAX_HABITS (8) with error message.
;            2. Displays prompt on Row 14, flushes frame, and invokes read_line
;               with line_buf and max length HABIT_NAME_MAX (31 chars).
;            3. Empty input cancels with no changes.
;            4. Non-empty input zeroes the new record, copies the name, initializes
;               numeric fields to 0, increments habit_count, syncs dashboard,
;               and saves to habits.dat.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_add:
    save_regs

    ; Check if habit capacity reached (FR-H3)
    cmp dword [habit_count], MAX_HABITS
    jae .add_list_full

    ; Set prompt message and render frame
    mov dword [habit_msg], habit_msg_add_prompt
    call habits_draw

    ; Position cursor at end of prompt on Row 14 (prompt length = 46 chars, col = 50)
    mov eax, UI_HAB_ROW_MSG
    mov ebx, UI_HAB_COL_MSG + 46 ; Col 50
    call ui_goto

    ; Read interactive line input via read_line in cooked mode
    mov edi, line_buf
    mov ecx, HABIT_NAME_MAX     ; 31 characters max
    call read_line              ; EAX = length of entered text

    ; Empty input cancels addition
    test eax, eax
    jz .add_canceled

    ; Non-empty name: initialize new habit record
    mov eax, [habit_count]      ; New record index = current habit_count
    call habits_get_record      ; EAX = pointer to new record
    mov edi, eax                ; EDI = dest record pointer

    ; 1. Zero out entire 48-byte record
    push edi
    mov ecx, HABIT_RECORD_SIZE  ; 48 bytes
    xor al, al
    cld
    rep stosb
    pop edi

    ; 2. Copy name from line_buf into record name field
    push edi
    mov esi, line_buf
    call str_copy
    pop edi

    ; Ensure byte 31 is NUL-terminated
    mov byte [edi + HABIT_NAME_MAX], CHAR_NULL

    ; 3. last_day, streak, total, history are already 0 from stosb

    ; 4. Increment habit count
    inc dword [habit_count]

    ; 5. Synchronize dashboard summary counters
    call habits_sync_dashboard

    ; 6. Persist to habits.dat
    call habits_save
    test eax, eax
    jz .add_save_ok

    mov dword [habit_msg], err_could_not_save
    jmp .add_done

.add_save_ok:
    mov dword [habit_msg], 0    ; Clear message on successful add
    jmp .add_done

.add_list_full:
    mov dword [habit_msg], habit_msg_full
    jmp .add_done

.add_canceled:
    mov dword [habit_msg], 0    ; Clear prompt on cancel

.add_done:
    mov dword [need_redraw], 1
    restore_regs
    ret

;=============================================================================
; Procedure: habits_delete
; Purpose:   Implements FR-H3 deletion:
;            1. If habit_count == 0, shows message and cancels.
;            2. Displays delete prompt on Row 14, flushes frame, and waits for key.
;            3. If user presses Ctrl+C, sets STATE_QUIT and returns.
;            4. If user presses a number outside 1..habit_count, cancels silently.
;            5. If valid number selected:
;               - Shifts all subsequent records up by one record via REP MOVSB.
;               - Zeroes out the now-unused last record via REP STOSB.
;               - Decrements habit_count, syncs dashboard, and saves to habits.dat.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_delete:
    save_regs

    ; Check if any habits exist to delete
    cmp dword [habit_count], 0
    je .del_empty

    ; Show delete prompt on message row
    mov dword [habit_msg], habit_msg_del_prompt
    call habits_draw
    call buf_flush

    ; Wait for key selection
    call key_wait

    ; Handle global Ctrl+C exit
    cmp eax, KEY_CTRL_C
    je .del_exit_quit

    ; Validate selected key is in range [KEY_1 .. KEY_1 + habit_count - 1]
    cmp eax, KEY_1
    jb .del_canceled
    mov edx, [habit_count]
    add edx, KEY_1 - 1
    cmp eax, edx
    ja .del_canceled

    ; Valid habit number chosen!
    ; Calculate 0-based deletion index: del_index = key - KEY_1
    sub eax, KEY_1              ; EAX = del_index (0..habit_count - 1)
    mov edx, eax                ; EDX = del_index

    ; Compute destination address (record being deleted)
    call habits_get_record      ; EAX = destination record pointer
    mov edi, eax                ; EDI = destination record

    ; Compute source address (next record: del_index + 1)
    mov eax, edx
    inc eax                     ; EAX = del_index + 1
    call habits_get_record      ; EAX = source record pointer
    mov esi, eax                ; ESI = source record

    ; Calculate count of subsequent records to shift up: (habit_count - 1) - del_index
    mov ecx, [habit_count]
    dec ecx
    sub ecx, edx                ; ECX = records to shift

    test ecx, ecx
    jz .del_clear_last_record

    ; Convert record count to byte count: bytes = records * 48
    lea ecx, [ecx + ecx*2]      ; ECX = records * 3
    shl ecx, 4                  ; ECX = records * 48

    ; Shift records forward into deleted slot (safe forward copy: dest < src)
    cld
    rep movsb

.del_clear_last_record:
    ; Zero out the vacated record at the end of the active list (old habit_count - 1)
    mov eax, [habit_count]
    dec eax
    call habits_get_record      ; EAX = old last record pointer
    mov edi, eax
    mov ecx, HABIT_RECORD_SIZE  ; 48 bytes
    xor al, al
    cld
    rep stosb

    ; Decrement habit count
    dec dword [habit_count]

    ; Synchronize dashboard summary counters
    call habits_sync_dashboard

    ; Persist changes to habits.dat
    call habits_save
    test eax, eax
    jz .del_save_ok

    mov dword [habit_msg], err_could_not_save
    jmp .del_finish

.del_save_ok:
    mov dword [habit_msg], habit_msg_deleted
    jmp .del_finish

.del_empty:
    mov dword [habit_msg], habit_msg_no_delete
    jmp .del_finish

.del_canceled:
    mov dword [habit_msg], 0
    jmp .del_finish

.del_exit_quit:
    mov dword [state], STATE_QUIT
    restore_regs
    ret

.del_finish:
    mov dword [need_redraw], 1
    restore_regs
    ret

;=============================================================================
; Procedure: habits_run
; Purpose:   Runs the modal event loop for the Habit Tracker screen:
;            - Renders frame on need_redraw dirty flag via habits_draw + buf_flush.
;            - Blocks sleeping 50ms per poll via key_wait (near 0% idle CPU).
;            - Dispatches interactive commands:
;              * 'A' -> Add new habit
;              * 'D' -> Delete existing habit
;              * '1'..'8' -> Check in habit today
;              * 'B' -> Return to main menu (sets STATE_MENU and returns)
;              * Ctrl+C -> Exit application (sets STATE_QUIT and returns)
;            - Ignores unhandled keys without redrawing or triggering sys_write.
; IN:        None
; OUT:       None (returns to menu on exit)
; CLOBBERS:  None (preserves all)
;=============================================================================
habits_run:
    save_regs

    ; Set initial modal state and mark frame dirty for initial render
    mov dword [state], STATE_HABITS
    mov dword [habit_msg], 0
    mov dword [need_redraw], 1

.habits_loop:
    ; Redraw frame only when flagged dirty
    cmp dword [need_redraw], 0
    je .habits_wait_key

    call habits_draw
    call buf_flush              ; Single sys_write per frame (FR-U4)
    mov dword [need_redraw], 0

.habits_wait_key:
    ; Low-CPU 50ms sleep via sys_nanosleep while polling for terminal resize (PRD v2 §2)
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_50MS
    syscall SYS_NANOSLEEP, timespec, 0

    call term_size_ok
    test eax, eax
    jz .habits_need_redraw      ; Shrunk below 80x24: trigger redraw (enters size gate)
    mov edx, [term_cols]
    cmp edx, [ui_seen_cols]
    jne .habits_need_redraw
    mov edx, [term_rows]
    cmp edx, [ui_seen_rows]
    jne .habits_need_redraw

    call key_poll
    cmp eax, KEY_NONE
    je .habits_wait_key
    jmp .habits_dispatch_key

.habits_need_redraw:
    mov dword [need_redraw], 1
    jmp .habits_loop

.habits_dispatch_key:
    ; Dispatch global and navigation keys
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c

    cmp eax, KEY_B
    je .key_b

    cmp eax, KEY_A
    je .key_a

    cmp eax, KEY_D
    je .key_d

    ; Check if digit '1'..'8'
    cmp eax, KEY_1
    jb .unknown_key
    cmp eax, KEY_8
    jbe .key_digit

.unknown_key:
    ; Any other key (arrows, space, letters) does nothing: no redraw, no write!
    jmp .habits_loop

.key_ctrl_c:
    mov dword [state], STATE_QUIT
    jmp .habits_exit

.key_b:
    mov dword [state], STATE_MENU
    jmp .habits_exit

.key_a:
    call habits_add
    jmp .habits_loop

.key_d:
    call habits_delete
    jmp .habits_loop

.key_digit:
    call habits_check_in
    jmp .habits_loop

.habits_exit:
    restore_regs
    ret
