; =============================================================================
; Pawmodoro - Journal Subsystem & Persistence (src/journal.asm)
;
; Purpose: Timestamped note entry appending, file tail seeking via sys_lseek,
;          backward line scanning, and modal UI view rendering per PRD §3.1,
;          §4.4 (FR-J1 to FR-J4), §4.5 (FR-D1, FR-D4), §5, §6.2, §6.3, §6.4.
; Reference: PRD §3.1, §4.4 (FR-J1–FR-J4), §4.5 (FR-D1, FR-D4), §5, §6.3, §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

; -----------------------------------------------------------------------------
; journal_add: Append one timestamped text entry to journal.txt.
;
; Purpose:  Formats a new journal entry: "YYYY-MM-DD HH:MM | <text>\n" in file_buf
;           and appends it to journal.txt via file_append per PRD §4.4 (FR-J2, FR-J3).
;           Calls time_local ONCE and derives the day number from that value by
;           unsigned division by SECONDS_PER_DAY (ensuring date and time cannot
;           disagree around midnight). Replaces any byte < 0x20 or == 0x7F with
;           '?' to prevent multi-line injection. Clamps text to JOURNAL_ENTRY_MAX
;           (200 characters). Returns FILE_ERR (-1) if text is empty (length 0).
; IN:       ESI = Pointer to NUL-terminated text string
; OUT:      EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on error/empty
; CLOBBERS: EAX, EFLAGS only (all other registers, including ESI/EDI, preserved)
; -----------------------------------------------------------------------------
journal_add:
    save_regs
    push esi                    ; [esp] = caller's original text pointer

    ; 1. Validate input text: empty input (length 0) returns FILE_ERR (-1)
    cmp byte [esi], CHAR_NULL
    je .add_empty

    ; 2. Sample local clock exactly ONCE to prevent midnight divergence (PRD §6.3)
    call time_local             ; EAX = current local time in seconds
    mov ebx, eax                ; EBX = local seconds

    ; Derive local day number: day_number = local_seconds / SECONDS_PER_DAY
    xor edx, edx                ; Zero EDX before unsigned division (never use cdq)
    mov ecx, SECONDS_PER_DAY
    div ecx                     ; EAX = quotient (day number)

    ; 3. Format calendar date string "YYYY-MM-DD\0" into date_buf
    mov edi, date_buf
    call time_fmt_date

    ; 4. Format time of day string "HH:MM\0" into time_buf
    mov eax, ebx                ; Restore sampled local seconds
    mov edi, time_buf
    call time_fmt_hhmm

    ; 5. Assemble persistent log line into file_buf
    ; Line format: Date (10) + Space (1) + Time (5) + " | " (3) + Text (<= 200) + LF (1)
    mov edi, file_buf

    ; Copy Date (10 bytes) from date_buf
    mov esi, date_buf
    mov ecx, JOURNAL_DATE_LEN   ; 10
    cld
    rep movsb

    ; Insert single space delimiter
    mov al, CHAR_SPACE
    stosb

    ; Copy Time (5 bytes) from time_buf
    mov esi, time_buf
    mov ecx, JOURNAL_TIME_LEN   ; 5
    rep movsb

    ; Copy Separator string " | " (3 bytes)
    mov esi, jrnl_sep
    mov ecx, JOURNAL_SEP_LEN    ; 3
    rep movsb

    ; Copy user text up to JOURNAL_ENTRY_MAX (200 characters) and sanitize
    mov esi, [esp]              ; Retrieve caller's original text pointer
    xor ecx, ecx                ; Character counter

.copy_text_loop:
    cmp ecx, JOURNAL_ENTRY_MAX
    jae .copy_text_done
    mov al, [esi]
    test al, al
    jz .copy_text_done

    ; Sanitize non-printable characters (< 0x20 or == 0x7F) to '?'
    cmp al, CHAR_SPACE
    jb .sanitize_char
    cmp al, 127
    je .sanitize_char
    jmp .store_char

.sanitize_char:
    mov al, CHAR_QUESTION

.store_char:
    stosb
    inc esi
    inc ecx
    jmp .copy_text_loop

.copy_text_done:
    ; Append terminating newline (CHAR_LF)
    mov al, CHAR_LF
    stosb

    ; 6. Calculate total assembled byte length
    mov ecx, edi
    sub ecx, file_buf           ; ECX = total bytes to append

    ; 7. Append assembled line to journal.txt via file_append
    mov esi, path_journal
    mov edi, file_buf
    call file_append            ; EAX = FILE_OK (0) or FILE_ERR (-1)

    pop esi                     ; Discard saved text pointer
    restore_regs
    ret

.add_empty:
    pop esi                     ; Discard saved text pointer
    mov eax, FILE_ERR           ; Return -1 on empty text input
    restore_regs
    ret

; -----------------------------------------------------------------------------
; journal_load_tail: Load up to the last 4096 bytes of journal.txt into jrnl_buf.
;
; Purpose:  Implements FR-J4 tail loading via raw Linux x86 system calls:
;           1. sys_open(path_journal, O_RDONLY, 0)
;           2. sys_lseek(fd, 0, SEEK_END) to obtain exact file size.
;           3. If size > JRNL_BUF_SIZE (4096):
;              sys_lseek(fd, size - 4096, SEEK_SET) and jrnl_tail_partial = 1.
;              Otherwise:
;              sys_lseek(fd, 0, SEEK_SET) and jrnl_tail_partial = 0.
;           4. sys_read(fd, jrnl_buf, 4096) to load tail bytes.
;           5. sys_close(fd) on EVERY path where open succeeded (no fd leaks).
;           Stores loaded count in jrnl_bytes_loaded. Missing, empty, or unreadable
;           files set jrnl_bytes_loaded = 0 safely without crashing (FR-D1).
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only (all registers preserved)
; -----------------------------------------------------------------------------
journal_load_tail:
    save_regs
    push eax

    ; Default state: 0 bytes loaded, not partial
    mov dword [jrnl_bytes_loaded], 0
    mov dword [jrnl_tail_partial], 0

    ; 1. Open journal.txt read-only
    mov ebx, path_journal
    mov ecx, O_RDONLY
    xor edx, edx
    syscall SYS_OPEN, ebx, ecx, edx
    test eax, eax
    js .load_open_failed        ; Open failed (missing file): treat as empty state

    ; Open succeeded: preserve file descriptor on stack
    push eax                    ; [esp] = fd

    ; 2. Query file size via sys_lseek(fd, 0, SEEK_END)
    mov ebx, [esp]              ; EBX = fd
    xor ecx, ecx                ; ECX = offset 0
    mov edx, SEEK_END           ; EDX = 2 (SEEK_END)
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .load_close              ; Negative: lseek error -> close and treat as empty
    jz .load_close              ; Zero: empty file (0 bytes) -> close

    ; 3. Determine seek position based on file size (EAX)
    cmp eax, JRNL_BUF_SIZE      ; 4096
    jbe .load_seek_start

    ; File size > 4096: position file offset to (size - 4096)
    mov dword [jrnl_tail_partial], 1
    sub eax, JRNL_BUF_SIZE      ; EAX = size - 4096
    mov ecx, eax                ; Stage offset into ECX
    mov ebx, [esp]              ; EBX = fd
    mov edx, SEEK_SET           ; EDX = 0 (SEEK_SET)
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .load_close              ; Seek failed
    jmp .load_read_data

.load_seek_start:
    ; File size <= 4096: rewind to beginning of file (offset 0)
    mov dword [jrnl_tail_partial], 0
    mov ebx, [esp]              ; EBX = fd
    xor ecx, ecx                ; ECX = offset 0
    mov edx, SEEK_SET           ; EDX = 0 (SEEK_SET)
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .load_close              ; Seek failed

.load_read_data:
    ; 4. Read up to JRNL_BUF_SIZE (4096) bytes into jrnl_buf
    mov ebx, [esp]              ; EBX = fd
    mov ecx, jrnl_buf           ; ECX = destination buffer pointer
    mov edx, JRNL_BUF_SIZE      ; EDX = maximum bytes to read (4096)
    syscall SYS_READ, ebx, ecx, edx
    test eax, eax
    jle .load_close             ; <= 0 indicates read error or unexpected EOF

    ; Store count of bytes actually read
    mov [jrnl_bytes_loaded], eax

.load_close:
    ; 5. Close file descriptor unconditionally to prevent leaks
    pop ebx                     ; EBX = fd
    syscall SYS_CLOSE, ebx
    jmp .load_exit

.load_open_failed:
    ; File missing: jrnl_bytes_loaded remains 0

.load_exit:
    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; journal_find_lines: Scan loaded buffer backwards to locate last 10 complete lines.
;
; Purpose:  Scans jrnl_buf[0..jrnl_bytes_loaded) backwards to record up to
;           JOURNAL_VIEW_LINES (10) complete lines per PRD §4.4 (FR-J4).
;           - If jrnl_tail_partial == 1, discards all bytes up to and including
;             the first LF in jrnl_buf to prevent displaying a chopped line.
;           - Skips trailing and intermediate empty lines.
;           - If the file does not end with LF, treats buffer end as line end.
;           - Stores lines in jrnl_lines as (start_ptr, length) pairs ordered
;             oldest to newest, top to bottom.
;           - Stores count of valid lines in jrnl_line_count (0..10).
; IN:       none (reads jrnl_bytes_loaded, jrnl_tail_partial, jrnl_buf)
; OUT:      none (writes jrnl_line_count, jrnl_lines)
; CLOBBERS: EFLAGS only (all registers preserved)
; -----------------------------------------------------------------------------
journal_find_lines:
    save_regs
    push eax

    ; Allocate 80 bytes on stack for up to 10 temporary lines (pairs of {ptr, len})
    sub esp, 80

    ; Reset line count
    mov dword [jrnl_line_count], 0

    ; Check if any bytes were loaded
    mov eax, [jrnl_bytes_loaded]
    test eax, eax
    jz .find_no_lines

    ; Determine valid search start offset (EBX)
    xor ebx, ebx                ; Default valid_start = 0
    cmp dword [jrnl_tail_partial], 0
    je .find_start_search

    ; Tail was read from middle of file: locate first LF to discard partial line
    xor ecx, ecx                ; ECX = scan index
.find_discard_partial_loop:
    cmp ecx, [jrnl_bytes_loaded]
    jae .find_no_lines          ; Entire buffer has no LF: no complete lines exist
    cmp byte [jrnl_buf + ecx], CHAR_LF
    je .find_found_partial_lf
    inc ecx
    jmp .find_discard_partial_loop

.find_found_partial_lf:
    inc ecx                     ; First complete line starts right after first LF
    mov ebx, ecx                ; EBX = valid_start
    cmp ebx, [jrnl_bytes_loaded]
    jae .find_no_lines          ; Discard extended to end of buffer

.find_start_search:
    ; Initialize backward search cursor: ESI = bytes_loaded - 1
    mov esi, [jrnl_bytes_loaded]
    dec esi                     ; ESI = cursor index (N - 1)
    xor edx, edx                ; EDX = lines_found counter (0..10)

.scan_loop:
    cmp edx, JOURNAL_VIEW_LINES ; 10
    jae .scan_done
    cmp esi, ebx                ; Cursor within valid range? (signed compare for ESI < 0)
    jl .scan_done

    ; 1. Skip trailing / intermediate empty newlines
.skip_lf_loop:
    cmp esi, ebx
    jl .scan_done
    cmp byte [jrnl_buf + esi], CHAR_LF
    jne .found_line_end
    dec esi
    jmp .skip_lf_loop

.found_line_end:
    ; ESI points to last character of line
    lea ecx, [esi + 1]          ; ECX = line_end (exclusive offset)

    ; 2. Scan backwards for preceding LF or buffer start
.find_line_start_loop:
    cmp esi, ebx
    jl .at_buffer_start
    cmp byte [jrnl_buf + esi], CHAR_LF
    je .found_preceding_lf
    dec esi
    jmp .find_line_start_loop

.found_preceding_lf:
    ; Preceding LF is at index ESI: line starts at ESI + 1
    lea eax, [esi + 1]          ; EAX = line_start offset
    jmp .calc_line_len

.at_buffer_start:
    ; Reached search boundary without preceding LF: line starts at valid_start (EBX)
    mov eax, ebx                ; EAX = line_start offset

.calc_line_len:
    ; Calculate line length: length = line_end (ECX) - line_start (EAX)
    sub ecx, eax                ; ECX = line length in bytes
    add eax, jrnl_buf           ; Convert offset to absolute memory pointer

    ; Store in temporary stack array: [esp + EDX*8] = start_ptr, [esp + EDX*8 + 4] = len
    mov [esp + edx*8], eax
    mov [esp + edx*8 + 4], ecx
    inc edx                     ; lines_found++
    jmp .scan_loop

.scan_done:
    ; Store total number of lines found
    mov [jrnl_line_count], edx
    test edx, edx
    jz .find_cleanup

    ; Reverse temp stack array into jrnl_lines:
    ; temp[0] was the newest line (bottom-most in file)
    ; temp[lines_found - 1] was the oldest line (top-most in file)
    ; jrnl_lines[0] receives oldest, jrnl_lines[lines_found - 1] receives newest
    xor ecx, ecx                ; ECX = dest index (0..lines_found - 1)

.reverse_loop:
    cmp ecx, edx
    jae .find_cleanup

    ; Compute source index: ESI = (lines_found - 1) - ECX
    mov esi, edx
    dec esi
    sub esi, ecx

    ; Copy pair: start pointer and length
    mov eax, [esp + esi*8]
    mov ebx, [esp + esi*8 + 4]
    mov [jrnl_lines + ecx*8], eax
    mov [jrnl_lines + ecx*8 + 4], ebx

    inc ecx
    jmp .reverse_loop

.find_no_lines:
    mov dword [jrnl_line_count], 0

.find_cleanup:
    add esp, 80                 ; Deallocate local stack array
    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; journal_draw_row: Render a single journal entry line at specified row.
;
; Purpose:  Positions cursor at (EAX, UI_JRN_COL_TEXT = 4) and appends at most
;           JOURNAL_DISPLAY_WIDTH (52) characters from [ESI] up to length ECX.
;           Sanitizes non-printable characters (< 0x20 or == 0x7F) to '?' to
;           prevent terminal escape sequence injection from corrupt files.
;           Guarantees line does not exceed column 55, preserving the right border
;           at column 56. Does not modify source buffer or file content.
; IN:       EAX = Screen row coordinate (UI_JRN_ROW_FIRST + index)
;           ESI = Pointer to line start in jrnl_buf
;           ECX = Line length in bytes
; OUT:      Appends formatted text to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
journal_draw_row:
    save_regs
    push eax

    ; Position cursor at (row, Col 4)
    mov ebx, UI_JRN_COL_TEXT    ; 4
    call buf_goto

    ; Clamp display length to JOURNAL_DISPLAY_WIDTH (52 columns)
    cmp ecx, JOURNAL_DISPLAY_WIDTH
    jbe .row_len_clamped
    mov ecx, JOURNAL_DISPLAY_WIDTH

.row_len_clamped:
    test ecx, ecx
    jz .row_draw_exit

.row_char_loop:
    mov al, [esi]

    ; Sanitize non-printable characters (< 0x20 or == 0x7F)
    cmp al, CHAR_SPACE
    jb .row_sanitize
    cmp al, 127
    je .row_sanitize
    jmp .row_emit_char

.row_sanitize:
    mov al, CHAR_QUESTION

.row_emit_char:
    call buf_char
    inc esi
    dec ecx
    jnz .row_char_loop

.row_draw_exit:
    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; journal_draw: Assemble the complete Journal screen frame into out_buf.
;
; Purpose:  Constructs the 56-column Journal screen in out_buf per PRD §5 wireframe.
;           Implements the two-phase rendering pattern:
;           Phase 1: Moves cursor to (1,1), draws borders and cleared rows
;                    (Rows 1..17), and clears below the frame with ESC[J.
;           Phase 2: Overlays title, separator, entry records (up to 10) or
;                    hints/empty state, feedback message, and key help prompts.
;           NOTE: Does NOT flush the buffer. Caller invokes buf_flush.
; IN:       none
; OUT:      Appends entire frame escape sequences and text to out_buf
; CLOBBERS: none (EFLAGS only; all registers preserved)
; -----------------------------------------------------------------------------
journal_draw:
    call ui_size_gate           ; Terminal dimension check gate (Task 9)
    save_regs

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Borders and Erase Inner Rows (FR-U4)
    ; -------------------------------------------------------------------------
    ; Position cursor at home (1,1)
    mov eax, UI_JRN_ROW_TOP
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto

    ; Row 1: Top border line
    mov eax, UI_JRN_ROW_TOP
    call ui_frame_hline
    mov esi, ansi_erase_eol
    call buf_str

    ; Rows 2..16: Erase each row with ESC[K and anchor right border '|' at col 56
    mov ecx, UI_JRN_ROW_TITLE   ; Row 2
.draw_erase_loop:
    mov eax, ecx
    call ui_frame_row
    inc ecx
    cmp ecx, UI_JRN_ROW_HELP    ; Row 16
    jbe .draw_erase_loop

    ; Row 17: Bottom border line
    mov eax, UI_JRN_ROW_BOTTOM
    call ui_frame_hline
    mov esi, ansi_erase_eol
    call buf_str

    ; Row 18: Erase to bottom of terminal screen (ESC[J)
    mov eax, UI_JRN_ROW_BELOW
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content at Absolute Cursor Coordinates
    ; -------------------------------------------------------------------------
    ; 1. Title Row (Row 2, Col 4): "JOURNAL" (bold bright cyan)
    mov eax, UI_JRN_ROW_TITLE
    mov ebx, UI_JRN_COL_TITLE
    call buf_goto

    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, title_journal       ; "JOURNAL"
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 2. Separator Border (Row 3)
    mov eax, UI_JRN_ROW_SEP
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto
    mov eax, UI_JRN_ROW_SEP
    call ui_frame_hline
    mov esi, ansi_erase_eol
    call buf_str

    ; 3. Journal Content Area (Rows 4..13)
    ; Check if view recent (V) has been activated
    cmp dword [jrnl_view_active], 0
    jne .draw_view_active

    ; View not active: show dim hint "Press V to view recent entries."
    mov eax, UI_JRN_ROW_FIRST
    mov ebx, UI_JRN_COL_TEXT
    call buf_goto
    mov esi, ansi_fg_bright_black
    call buf_str
    mov esi, jrnl_msg_initial_hint
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .draw_feedback_msg

.draw_view_active:
    ; View is active: check if any lines exist
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jnz .draw_entries_exist

    ; No lines exist: show "No entries yet."
    mov eax, UI_JRN_ROW_FIRST
    mov ebx, UI_JRN_COL_TEXT
    call buf_goto
    mov esi, ansi_fg_bright_black
    call buf_str
    mov esi, jrnl_msg_empty      ; "No entries yet."
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .draw_feedback_msg

.draw_entries_exist:
    ; Render up to 10 stored lines
    xor ecx, ecx                ; ECX = line index (0..jrnl_line_count - 1)

.draw_entries_loop:
    push ecx

    mov eax, UI_JRN_ROW_FIRST
    add eax, ecx                ; Row = 4 + index
    mov esi, [jrnl_lines + ecx*8]     ; Line start pointer
    mov ecx, [jrnl_lines + ecx*8 + 4] ; Line length in bytes
    call journal_draw_row

    pop ecx
    inc ecx
    cmp ecx, [jrnl_line_count]
    jb .draw_entries_loop

.draw_feedback_msg:
    ; 4. Message Row (Row 15, Col 4)
    mov esi, [jrnl_msg]
    test esi, esi
    jz .draw_key_help

    mov eax, UI_JRN_ROW_MSG
    mov ebx, UI_JRN_COL_MSG
    call buf_goto

    ; Format message color according to category
    cmp esi, err_could_not_save
    je .msg_color_red
    cmp esi, jrnl_msg_saved
    je .msg_color_green

    ; Default: yellow for prompts
    mov esi, ansi_fg_bright_yellow
    call buf_str
    jmp .msg_print_body

.msg_color_red:
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_red
    call buf_str
    jmp .msg_print_body

.msg_color_green:
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_green
    call buf_str

.msg_print_body:
    mov esi, [jrnl_msg]
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; One-time message display: clear message pointer
    mov dword [jrnl_msg], 0

.draw_key_help:
    ; 5. Key Help Prompt (Row 16, Col 4)
    mov eax, UI_JRN_ROW_HELP
    mov ebx, UI_JRN_COL_HELP
    call buf_goto

    mov esi, jrnl_help
    call buf_str

    restore_regs
    ret

; -----------------------------------------------------------------------------
; journal_new_entry: Interactive addition of a new journal entry (Key 'N').
;
; Purpose:  Implements FR-J1 line input and FR-J3 entry addition:
;           1. Sets prompt on Row 15, draws frame, and flushes output buffer.
;           2. Positions cursor directly after prompt (computed via str_len).
;           3. Calls read_line with line_buf and capacity JOURNAL_ENTRY_MAX (200).
;           4. Empty input cancels: writes nothing, clears prompt.
;           5. Non-empty input calls journal_add:
;              - On success: sets "Entry saved". If view is active, refreshes view.
;              - On failure: sets "Could not save" (FR-D4).
;           6. Always sets need_redraw = 1 to clean up cooked mode echo.
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only (all registers preserved)
; -----------------------------------------------------------------------------
journal_new_entry:
    save_regs

    ; Set prompt message and render frame
    mov dword [jrnl_msg], jrnl_msg_new_prompt
    call journal_draw

    ; Position cursor at end of prompt on Row 15
    mov esi, jrnl_msg_new_prompt
    call str_len                ; EAX = length of prompt string
    mov ebx, UI_JRN_COL_MSG
    add ebx, eax                ; EBX = column coordinate right after prompt
    mov eax, UI_JRN_ROW_MSG
    call buf_goto

    ; Read interactive line input via read_line in cooked mode
    mov edi, line_buf
    mov ecx, JOURNAL_ENTRY_MAX  ; 200 characters max
    call read_line              ; EAX = length of entered text

    ; Empty input cancels addition
    test eax, eax
    jz .new_canceled

    ; Call journal_add(ESI = line_buf)
    mov esi, line_buf
    call journal_add            ; EAX = FILE_OK (0) or FILE_ERR (-1)
    test eax, eax
    jnz .new_failed

    ; Save succeeded: show confirmation message
    mov dword [jrnl_msg], jrnl_msg_saved

    ; If view is currently active, refresh view to immediately display new entry
    cmp dword [jrnl_view_active], 0
    je .new_finish

    call journal_load_tail
    call journal_find_lines
    jmp .new_finish

.new_failed:
    ; Save failed: show error message (FR-D4)
    mov dword [jrnl_msg], err_could_not_save
    jmp .new_finish

.new_canceled:
    mov dword [jrnl_msg], 0     ; Clear prompt on cancel

.new_finish:
    mov dword [need_redraw], 1
    restore_regs
    ret

; -----------------------------------------------------------------------------
; journal_run: Main modal loop for Journal screen (FR-J1).
;
; Purpose:  Runs the modal event loop for the Journal screen:
;           - Renders frame on need_redraw dirty flag via journal_draw + buf_flush.
;           - Blocks sleeping 50ms per poll via key_wait (near 0% idle CPU).
;           - Dispatches interactive commands:
;             * 'N' -> Add new journal entry
;             * 'V' -> View recent 10 entries
;             * 'B' -> Return to main menu (sets STATE_MENU and returns)
;             * Ctrl+C -> Exit application (sets STATE_QUIT and returns)
;           - Ignores unhandled keys without redrawing or triggering sys_write.
; IN:       none
; OUT:      none (sets [state] = STATE_MENU or STATE_QUIT)
; CLOBBERS: EFLAGS only (all registers preserved)
; -----------------------------------------------------------------------------
journal_run:
    save_regs

    ; Set initial modal state and mark frame dirty for initial render
    mov dword [state], STATE_JOURNAL
    mov dword [jrnl_msg], 0
    mov dword [jrnl_view_active], 0
    mov dword [need_redraw], 1

.journal_loop:
    ; Redraw frame only when flagged dirty
    cmp dword [need_redraw], 0
    je .journal_wait_key

    call journal_draw
    call buf_flush              ; Single sys_write per frame (FR-U4)
    mov dword [need_redraw], 0

.journal_wait_key:
    call key_wait               ; Blocks sleeping 50ms; returns uppercase key in EAX

    ; Dispatch global and navigation keys
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c

    cmp eax, KEY_B
    je .key_b

    cmp eax, KEY_N
    je .key_n

    cmp eax, KEY_V
    je .key_v

    ; Any other key does nothing: no redraw, no write!
    jmp .journal_loop

.key_ctrl_c:
    mov dword [state], STATE_QUIT
    jmp .journal_exit

.key_b:
    mov dword [state], STATE_MENU
    jmp .journal_exit

.key_n:
    call journal_new_entry
    jmp .journal_loop

.key_v:
    mov dword [jrnl_view_active], 1
    call journal_load_tail
    call journal_find_lines
    mov dword [need_redraw], 1
    jmp .journal_loop

.journal_exit:
    restore_regs
    ret
