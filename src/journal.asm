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

;=============================================================================
; Procedure: journal_add
; Purpose:   Formats a new journal entry: "YYYY-MM-DD HH:MM | <text>\n" in file_buf
;            and appends it to journal.txt via file_append per PRD §4.4 (FR-J2, FR-J3).
;            Calls time_local ONCE and derives day number by unsigned division
;            by SECONDS_PER_DAY. Sanitizes non-printable characters (< 0x20 or == 0x7F)
;            to '?' to prevent multi-line injection. Clamps text to JOURNAL_ENTRY_MAX
;            (200 characters). Returns FILE_ERR (-1) if text is empty (length 0).
; IN:        ESI = Pointer to NUL-terminated text string
; OUT:       EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on error/empty
; CLOBBERS:  EAX
;=============================================================================
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

;=============================================================================
; Procedure: journal_load_window
; Purpose:   Loads a bounded viewing window (up to JRNL_BUF_SIZE = 16384 bytes)
;            from journal.txt using raw Linux sys_lseek and sys_read.
;            - Obtains total file size via sys_lseek(fd, 0, SEEK_END).
;            - If EAX == 0 or target > file_size: target_end = file_size.
;            - If target_end <= JRNL_BUF_SIZE:
;                read_start = 0, bytes_to_read = target_end, is_partial = 0.
;              Otherwise:
;                read_start = target_end - JRNL_BUF_SIZE,
;                bytes_to_read = JRNL_BUF_SIZE, is_partial = 1.
;            - Closes fd unconditionally on all paths (no descriptor leaks).
;            - Stores read count in jrnl_bytes_loaded, read_start in
;              jrnl_window_offset, is_partial in jrnl_tail_partial, file_size
;              in jrnl_file_size. Missing or unreadable files safely set
;              jrnl_bytes_loaded = 0 and jrnl_file_size = 0.
; IN:        EAX = Target end byte offset (0 = file tail / EOF)
; OUT:       None (initializes jrnl_bytes_loaded, jrnl_window_offset,
;                 jrnl_tail_partial, jrnl_file_size)
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_load_window:
    save_regs
    push eax                    ; [esp] = requested target_end

    ; Default state: 0 bytes loaded, offset 0, not partial, file size 0
    mov dword [jrnl_bytes_loaded], 0
    mov dword [jrnl_window_offset], 0
    mov dword [jrnl_tail_partial], 0
    mov dword [jrnl_file_size], 0

    ; 1. Open journal.txt read-only
    mov ebx, path_journal
    mov ecx, O_RDONLY
    xor edx, edx
    syscall SYS_OPEN, ebx, ecx, edx
    test eax, eax
    js .win_open_failed         ; File missing or unreadable

    push eax                    ; [esp] = fd (previous [esp+4] = requested target_end)

    ; 2. Query file size via sys_lseek(fd, 0, SEEK_END)
    mov ebx, [esp]              ; EBX = fd
    xor ecx, ecx
    mov edx, SEEK_END
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    jle .win_close              ; Negative error or 0-byte file -> close and exit

    mov [jrnl_file_size], eax   ; Store total file size in bytes
    mov edx, eax                ; EDX = file_size

    ; 3. Determine target_end
    mov eax, [esp + 4]          ; Requested target_end
    test eax, eax
    jz .win_target_eof
    cmp eax, edx
    jbe .win_have_target

.win_target_eof:
    mov eax, edx                ; target_end = file_size

.win_have_target:
    ; EAX = target_end, EDX = file_size
    cmp eax, JRNL_BUF_SIZE      ; 16384
    jbe .win_seek_start

    ; target_end > 16384: position window start at target_end - 16384
    mov dword [jrnl_tail_partial], 1
    sub eax, JRNL_BUF_SIZE      ; EAX = read_start
    mov [jrnl_window_offset], eax
    mov ecx, eax                ; ECX = read_start offset
    mov ebx, [esp]              ; EBX = fd
    mov edx, SEEK_SET
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .win_close
    mov ecx, JRNL_BUF_SIZE      ; Bytes to read = 16384
    jmp .win_read_data

.win_seek_start:
    ; target_end <= 16384: read from offset 0
    mov dword [jrnl_tail_partial], 0
    mov dword [jrnl_window_offset], 0
    push eax                    ; preserve bytes to read (target_end)
    mov ebx, [esp + 4]          ; EBX = fd
    xor ecx, ecx                ; offset = 0
    mov edx, SEEK_SET           ; 0
    mov eax, SYS_LSEEK          ; 19
    int 0x80
    pop ecx                     ; restore bytes to read (target_end)
    test eax, eax
    js .win_close

.win_read_data:
    ; 4. Read into jrnl_buf: sys_read(fd = EBX, buf = jrnl_buf, count = ECX)
    mov edx, ecx                ; EDX = count to read
    mov ebx, [esp]              ; EBX = fd
    mov ecx, jrnl_buf           ; ECX = destination buffer pointer
    syscall SYS_READ, ebx, ecx, edx
    test eax, eax
    jle .win_close

    mov [jrnl_bytes_loaded], eax ; Store actual bytes read

.win_close:
    pop ebx                     ; Restore fd
    syscall SYS_CLOSE, ebx

.win_open_failed:
    pop eax                     ; Discard saved target_end
    restore_regs
    ret

;=============================================================================
; Procedure: journal_load_tail
; Purpose:   Loads the newest 16 KB window from the end of journal.txt.
; IN:        None
; OUT:       None (calls journal_load_window with target_end = 0)
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_load_tail:
    save_regs
    xor eax, eax                ; 0 = EOF / file tail
    call journal_load_window
    restore_regs
    ret

;=============================================================================
; Procedure: journal_find_lines
; Purpose:   Scans jrnl_buf[0..jrnl_bytes_loaded) for complete physical lines
;            (up to JRNL_MAX_ENTRIES = 32 entries).
;            - If jrnl_tail_partial == 1, discards all bytes up to and including
;              the first LF in jrnl_buf to discard an incomplete leading line.
;            - Scans backwards from end of valid buffer, skipping trailing and
;              intermediate empty newlines.
;            - For each complete line, records:
;              [0]: start_ptr (pointer into jrnl_buf)
;              [4]: text_len (bytes excluding terminating LF)
;              [8]: file_off (absolute byte offset in journal.txt)
;              [12]: file_len (total bytes in journal.txt including LF)
;            - Reverses temporary results into jrnl_entries so entries are
;              ordered chronologically (oldest at index 0, newest at count - 1).
;            - Sets jrnl_line_count to the count of complete lines found.
;            - Sets jrnl_lines for legacy compatibility.
; IN:        None (reads jrnl_bytes_loaded, jrnl_tail_partial, jrnl_window_offset, jrnl_buf)
; OUT:       None (writes jrnl_line_count, jrnl_entries, jrnl_lines)
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_find_lines:
    push ebp
    mov ebp, esp
    save_regs
    push eax

    ; Allocate 512 bytes on stack for up to 32 temporary entries (16 bytes each)
    sub esp, 512

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

    ; Window read from middle of file: locate first LF to discard partial line
    xor ecx, ecx                ; ECX = scan index
.find_discard_partial_loop:
    cmp ecx, [jrnl_bytes_loaded]
    jae .find_no_lines          ; Entire buffer has no LF: no complete lines
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
    xor edx, edx                ; EDX = lines_found counter (0..JRNL_MAX_ENTRIES)

.scan_loop:
    cmp edx, JRNL_MAX_ENTRIES   ; 32
    jae .scan_done
    cmp esi, ebx                ; Cursor within valid range?
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
    ; ESI points to last non-LF character of line
    lea ecx, [esi + 1]          ; ECX = line_end (exclusive index of text)

.find_start_of_line:
    ; 2. Scan backwards for preceding LF or buffer start
.find_line_start_loop:
    cmp esi, ebx
    jl .at_buffer_start
    cmp byte [jrnl_buf + esi], CHAR_LF
    je .found_preceding_lf
    dec esi
    jmp .find_line_start_loop

.found_preceding_lf:
    lea eax, [esi + 1]          ; Line starts at ESI + 1
    jmp .calc_line_metadata

.at_buffer_start:
    mov eax, ebx                ; Line starts at valid_start (EBX)

.calc_line_metadata:
    ; EAX = line_start offset in jrnl_buf, ECX = line_end offset in jrnl_buf
    sub ecx, eax                ; ECX = text length in bytes (excluding LF)
    jz .scan_loop               ; Skip empty lines

    ; Check whether trailing LF existed in file buffer at index (line_start + text_len)
    mov edi, ecx                ; EDI = file_len initially = text_len
    push edx                    ; Preserve lines_found
    mov edx, eax
    add edx, ecx                ; EDX = line_end offset
    cmp edx, [jrnl_bytes_loaded]
    jae .no_trailing_lf
    cmp byte [jrnl_buf + edx], CHAR_LF
    jne .no_trailing_lf
    inc edi                     ; Trailing LF is present in file
.no_trailing_lf:
    pop edx                     ; Restore lines_found

    ; Store into temporary stack slot at [ebp - 512 + EDX*16]
    ; Preserve backward scan cursor (ESI) and valid_start (EBX)
    push esi
    push ebx

    mov ebx, edx
    shl ebx, 4
    lea ebx, [ebp + ebx - 512]  ; EBX = pointer to temporary entry slot

    ; 1. entry_start_ptr = jrnl_buf + line_start (in EAX)
    push eax
    add eax, jrnl_buf
    mov [ebx + 0], eax
    pop eax

    ; 2. entry_text_len = ECX
    mov [ebx + 4], ecx

    ; 3. entry_file_off = jrnl_window_offset + line_start (in EAX)
    push edx
    mov edx, [jrnl_window_offset]
    add edx, eax
    mov [ebx + 8], edx
    pop edx

    ; 4. entry_file_len = EDI
    mov [ebx + 12], edi

    pop ebx                     ; Restore valid_start
    pop esi                     ; Restore backward scan cursor

    inc edx                     ; lines_found++
    jmp .scan_loop

.scan_done:
    mov [jrnl_line_count], edx
    test edx, edx
    jz .find_cleanup

    ; Reverse temp stack array into jrnl_entries:
    ; temp[0] was newest line, temp[lines_found - 1] was oldest line.
    ; jrnl_entries[0] receives oldest, jrnl_entries[lines_found - 1] receives newest.
    xor ecx, ecx                ; ECX = dest index (0..lines_found - 1)

.reverse_loop:
    cmp ecx, edx
    jae .find_cleanup

    ; Source index: EAX = (lines_found - 1) - ECX
    mov eax, edx
    dec eax
    sub eax, ecx

    ; Compute source pointer: ESI = ebp - 512 + (EAX * 16)
    shl eax, 4
    lea esi, [ebp + eax - 512]

    ; Compute dest pointer: EDI = jrnl_entries + (ECX * 16)
    mov eax, ecx
    shl eax, 4
    lea edi, [jrnl_entries + eax]

    ; Copy 4 dwords (16 bytes)
    mov eax, [esi + 0]
    mov [edi + 0], eax
    mov eax, [esi + 4]
    mov [edi + 4], eax
    mov eax, [esi + 8]
    mov [edi + 8], eax
    mov eax, [esi + 12]
    mov [edi + 12], eax

    ; Also copy first 10 entries to jrnl_lines for legacy compatibility
    cmp ecx, JOURNAL_VIEW_LINES
    jae .skip_legacy
    mov eax, [edi + 0]
    mov [jrnl_lines + ecx*8], eax
    mov eax, [edi + 4]
    mov [jrnl_lines + ecx*8 + 4], eax

.skip_legacy:
    inc ecx
    jmp .reverse_loop

.find_no_lines:
    mov dword [jrnl_line_count], 0

.find_cleanup:
    add esp, 512                ; Deallocate local stack array
    pop eax
    restore_regs
    mov esp, ebp
    pop ebp
    ret

;=============================================================================
; Procedure: journal_wrap_segment
; Purpose:   Scans text at ESI (length ECX bytes) to find the wrap break point
;            that fits within EDX display columns. Prefers breaking at the last
;            space within budget; if no space exists, breaks at budget column.
; IN:        ESI = Pointer to text segment in memory,
;            ECX = Remaining byte length of text,
;            EDX = Display column budget for current visual row
; OUT:       EAX = Byte length of text to emit on this row,
;            EDX = Byte count to advance text pointer for next row (skips space),
;            EBX = Display columns occupied by emitted segment
; CLOBBERS:  EAX, EBX, EDX
;=============================================================================
journal_wrap_segment:
    push ecx
    push esi
    push ebp
    mov ebp, esp
    sub esp, 16                 ; [ebp - 4]:  last_space_byte (-1 if none)
                                ; [ebp - 8]:  last_space_col (0)
                                ; [ebp - 12]: col_count (0)
                                ; [ebp - 16]: byte_idx (0)
    push edi

    mov dword [ebp - 4], -1
    mov dword [ebp - 8], 0
    mov dword [ebp - 12], 0
    mov dword [ebp - 16], 0

.wrap_scan_loop:
    mov eax, [ebp - 16]         ; byte_idx
    cmp eax, ecx                ; Compare with total remaining bytes (ECX)
    jae .wrap_all_fit

    mov edi, esi
    add edi, eax                ; EDI = pointer to current character
    movzx eax, byte [edi]

    ; Check if space
    cmp al, CHAR_SPACE
    jne .wrap_not_space
    mov eax, [ebp - 16]
    mov [ebp - 4], eax          ; last_space_byte = byte_idx
    mov eax, [ebp - 12]
    mov [ebp - 8], eax          ; last_space_col = col_count
    mov eax, 1                  ; char_bytes = 1
    mov ebx, 1                  ; char_cols = 1
    jmp .wrap_check_budget

.wrap_not_space:
    push esi
    mov esi, edi
    call utf8_char_len          ; EAX = byte length (1..4)
    pop esi
    test eax, eax
    jnz .wrap_have_len
    mov eax, 1

.wrap_have_len:
    mov ebx, 1                  ; char_cols = 1 display column

.wrap_check_budget:
    ; Check if col_count + ebx > budget (EDX)
    mov edi, [ebp - 12]
    add edi, ebx
    cmp edi, edx
    jbe .wrap_advance

    ; Budget exceeded! Break at last space if one occurred on this line
    cmp dword [ebp - 4], -1
    je .wrap_break_no_space

    ; Break at last space
    mov eax, [ebp - 4]          ; EAX = bytes before space
    lea edx, [eax + 1]          ; EDX = advance past space for next line
    mov ebx, [ebp - 8]          ; EBX = columns at space
    jmp .wrap_finish

.wrap_break_no_space:
    ; No space: hard break at current byte_idx
    mov eax, [ebp - 16]
    test eax, eax
    jnz .wrap_break_now
    mov eax, 1                  ; Force at least 1 byte if budget was 0
.wrap_break_now:
    mov edx, eax                ; Advance same amount
    mov ebx, [ebp - 12]         ; Columns
    jmp .wrap_finish

.wrap_advance:
    add [ebp - 16], eax         ; byte_idx += char_bytes
    add [ebp - 12], ebx         ; col_count += char_cols
    jmp .wrap_scan_loop

.wrap_all_fit:
    mov eax, [ebp - 16]         ; All bytes fit on this visual row
    mov edx, eax
    mov ebx, [ebp - 12]

.wrap_finish:
    pop edi
    mov esp, ebp
    pop ebp
    pop esi
    pop ecx
    ret

;=============================================================================
; Procedure: journal_entry_row_count
; Purpose:   Calculates how many visual rows (1..4) an entry will occupy when
;            wrapped to (ui_w - 6) display columns.
; IN:        ESI = Pointer to entry string in memory,
;            ECX = Total entry length in bytes (excluding LF)
; OUT:       EAX = Visual row count (1..4)
; CLOBBERS:  EAX
;=============================================================================
journal_entry_row_count:
    save_regs
    push ecx
    push esi

    ; Compute total width W = ui_w - 6
    mov edx, [ui_w]
    sub edx, UI_JRN_TEXT_MARGIN

    ; Check if entry has standard 19-char timestamp prefix
    cmp ecx, JOURNAL_PREFIX_LEN
    jb .cnt_no_prefix
    cmp byte [esi + 10], CHAR_SPACE
    jne .cnt_no_prefix
    cmp byte [esi + 16], CHAR_SPACE
    jne .cnt_no_prefix
    cmp byte [esi + 17], CHAR_PIPE
    jne .cnt_no_prefix

    ; Has prefix: Row 1 text starts at esi + 19, budget = W - 19
    add esi, JOURNAL_PREFIX_LEN
    sub ecx, JOURNAL_PREFIX_LEN
    sub edx, JOURNAL_PREFIX_LEN
    jmp .cnt_row1

.cnt_no_prefix:
    ; No prefix: Row 1 budget = W

.cnt_row1:
    call journal_wrap_segment   ; EAX = bytes, EDX = advance, EBX = cols
    cmp edx, ecx
    jae .cnt_ret1
    add esi, edx
    sub ecx, edx

    ; Continuation budget = W - 4
    mov edx, [ui_w]
    sub edx, UI_JRN_TEXT_MARGIN
    sub edx, UI_JRN_INDENT_COLS

    ; Row 2
    call journal_wrap_segment
    cmp edx, ecx
    jae .cnt_ret2
    add esi, edx
    sub ecx, edx

    ; Row 3
    call journal_wrap_segment
    cmp edx, ecx
    jae .cnt_ret3

    ; Row 4
    mov eax, 4
    jmp .cnt_done

.cnt_ret1:
    mov eax, 1
    jmp .cnt_done
.cnt_ret2:
    mov eax, 2
    jmp .cnt_done
.cnt_ret3:
    mov eax, 3

.cnt_done:
    pop esi
    pop ecx
    restore_regs
    ret

;=============================================================================
; Procedure: journal_draw_entry
; Purpose:   Renders entry at index EAX starting at screen row EBX.
;            - Wraps text across up to 4 visual rows at (ui_w - 6) columns.
;            - Row 1 shows timestamp prefix; continuation rows indented 4 spaces.
;            - If EDX == 1, applies ansi_reverse to entry rows and pads with
;              spaces up to (ui_w - 6) columns, followed by ansi_reset.
;            - Sanitizes unprintable/control characters to '?'.
; IN:        EAX = Entry index (0..jrnl_line_count - 1),
;            EBX = Screen row coordinate,
;            EDX = 1 if highlighted (selected), 0 otherwise
; OUT:       EAX = Number of visual rows rendered (1..4)
; CLOBBERS:  EAX
;=============================================================================
journal_draw_entry:
    save_regs
    push ebp
    mov ebp, esp
    sub esp, 32                 ; [ebp - 4]:  entry_idx
                                ; [ebp - 8]:  start_row
                                ; [ebp - 12]: is_highlighted
                                ; [ebp - 16]: total_w (ui_w - 6)
                                ; [ebp - 20]: text_ptr
                                ; [ebp - 24]: rem_len
                                ; [ebp - 28]: curr_row
                                ; [ebp - 32]: rows_rendered

    mov [ebp - 4], eax
    mov [ebp - 8], ebx
    mov [ebp - 28], ebx
    mov [ebp - 12], edx
    mov dword [ebp - 32], 0

    ; Compute total width W = ui_w - 6
    mov eax, [ui_w]
    sub eax, UI_JRN_TEXT_MARGIN
    mov [ebp - 16], eax

    ; Retrieve entry pointer and length
    mov eax, [ebp - 4]
    shl eax, 4                  ; index * 16
    mov esi, [jrnl_entries + eax]
    mov ecx, [jrnl_entries + eax + 4]
    mov [ebp - 20], esi
    mov [ebp - 24], ecx

    ; -------------------------------------------------------------------------
    ; Visual Row 1: Timestamp + Initial text segment
    ; -------------------------------------------------------------------------
    mov eax, [ebp - 28]         ; row
    mov ebx, UI_JRN_COL_TEXT    ; Col 4
    call ui_goto

    ; If highlighted, emit background color and reverse video sequence
    cmp dword [ebp - 12], 0
    jz .row1_no_rev
    mov al, SLOT_HIGHLIGHT
    call ui_bgcolor
    mov esi, ansi_reverse
    call buf_str

.row1_no_rev:
    ; Check if entry has standard 19-char timestamp prefix
    mov ecx, [ebp - 24]
    mov esi, [ebp - 20]
    cmp ecx, JOURNAL_PREFIX_LEN
    jb .row1_no_prefix
    cmp byte [esi + 10], CHAR_SPACE
    jne .row1_no_prefix
    cmp byte [esi + 16], CHAR_SPACE
    jne .row1_no_prefix
    cmp byte [esi + 17], CHAR_PIPE
    jne .row1_no_prefix

    ; Has prefix: emit 19 prefix bytes to out_buf
    push ecx
    mov ecx, JOURNAL_PREFIX_LEN
.emit_prefix_loop:
    mov al, [esi]
    call buf_char
    inc esi
    dec ecx
    jnz .emit_prefix_loop
    pop ecx

    add dword [ebp - 20], JOURNAL_PREFIX_LEN
    sub dword [ebp - 24], JOURNAL_PREFIX_LEN

    ; Budget left on Row 1 = total_w - 19
    mov edx, [ebp - 16]
    sub edx, JOURNAL_PREFIX_LEN
    xor edi, edi
    add edi, JOURNAL_PREFIX_LEN ; EDI = columns used so far on Row 1 (19)
    jmp .row1_wrap

.row1_no_prefix:
    mov edx, [ebp - 16]         ; Budget = total_w
    xor edi, edi                ; 0 columns used so far

.row1_wrap:
    ; Wrap text segment: ESI = text_ptr, ECX = rem_len, EDX = budget
    mov esi, [ebp - 20]
    mov ecx, [ebp - 24]
    call journal_wrap_segment   ; EAX = bytes to emit, EDX = advance bytes, EBX = cols used

    ; Emit EAX bytes from ESI with sanitization
    push edx
    push ecx
    mov ecx, eax
.emit_row1_text:
    test ecx, ecx
    jz .emit_row1_done
    mov al, [esi]
    cmp al, CHAR_SPACE
    jb .row1_san
    cmp al, 127
    je .row1_san
    cmp al, CHAR_ESC
    je .row1_san
    jmp .row1_put
.row1_san:
    mov al, CHAR_QUESTION
.row1_put:
    call buf_char
    inc esi
    dec ecx
    jmp .emit_row1_text

.emit_row1_done:
    pop ecx
    pop edx                     ; EDX = advance bytes

    ; Update text_ptr and rem_len
    add [ebp - 20], edx
    sub [ebp - 24], edx

    ; Add columns used by text to EDI
    add edi, ebx

    ; If highlighted, pad with spaces up to total_w and emit reset
    cmp dword [ebp - 12], 0
    jz .row1_finish
    mov ecx, [ebp - 16]
    sub ecx, edi                ; ECX = spaces needed
    test ecx, ecx
    jle .row1_reset
    mov al, CHAR_SPACE
    call buf_repeat
.row1_reset:
    mov esi, ansi_reset
    call buf_str

.row1_finish:
    inc dword [ebp - 32]        ; rows_rendered = 1
    ; Check if remaining length is 0 (all text displayed)
    cmp dword [ebp - 24], 0
    jle .entry_draw_done

    ; -------------------------------------------------------------------------
    ; Continuation Rows (up to row 4)
    ; -------------------------------------------------------------------------
.cont_rows_loop:
    cmp dword [ebp - 32], JRNL_MAX_VISUAL_ROWS ; 4
    jae .entry_draw_done
    cmp dword [ebp - 24], 0
    jle .entry_draw_done

    ; Advance current row
    inc dword [ebp - 28]

    ; Position cursor at (curr_row, Col 4)
    mov eax, [ebp - 28]
    mov ebx, UI_JRN_COL_TEXT
    call ui_goto

    ; If highlighted, emit background color and reverse video
    cmp dword [ebp - 12], 0
    jz .cont_no_rev
    mov al, SLOT_HIGHLIGHT
    call ui_bgcolor
    mov esi, ansi_reverse
    call buf_str

.cont_no_rev:
    ; Emit 4 indentation spaces
    mov ecx, UI_JRN_INDENT_COLS ; 4
    mov al, CHAR_SPACE
    call buf_repeat

    ; Budget for continuation row = total_w - 4
    mov edx, [ebp - 16]
    sub edx, UI_JRN_INDENT_COLS
    mov edi, UI_JRN_INDENT_COLS ; EDI = 4 columns used

    ; Wrap segment
    mov esi, [ebp - 20]
    mov ecx, [ebp - 24]
    call journal_wrap_segment   ; EAX = bytes to emit, EDX = advance, EBX = cols

    ; If this is visual row 4 and more text remains, clamp with '~'
    cmp dword [ebp - 32], 3     ; Visual row 4 (0-based 3)
    jne .emit_cont_text_normal
    cmp edx, [ebp - 24]
    jae .emit_cont_text_normal

    ; Reserve 1 column for '~' marker
    test eax, eax
    jz .emit_cont_text_normal
    dec eax

.emit_cont_text_normal:
    push edx
    push ecx
    mov ecx, eax
.emit_cont_text_loop:
    test ecx, ecx
    jz .emit_cont_text_done
    mov al, [esi]
    cmp al, CHAR_SPACE
    jb .cont_san
    cmp al, 127
    je .cont_san
    cmp al, CHAR_ESC
    je .cont_san
    jmp .cont_put
.cont_san:
    mov al, CHAR_QUESTION
.cont_put:
    call buf_char
    inc esi
    dec ecx
    jmp .emit_cont_text_loop

.emit_cont_text_done:
    pop ecx
    pop edx

    ; Check if marker '~' needed on visual row 4
    cmp dword [ebp - 32], 3
    jne .cont_no_marker
    cmp edx, [ebp - 24]
    jae .cont_no_marker
    mov al, UI_CLIP_MARKER      ; '~'
    call buf_char

.cont_no_marker:
    add [ebp - 20], edx
    sub [ebp - 24], edx
    add edi, ebx

    ; If highlighted, pad and reset
    cmp dword [ebp - 12], 0
    jz .cont_row_finish
    mov ecx, [ebp - 16]
    sub ecx, edi
    test ecx, ecx
    jle .cont_row_reset
    mov al, CHAR_SPACE
    call buf_repeat
.cont_row_reset:
    mov esi, ansi_reset
    call buf_str

.cont_row_finish:
    inc dword [ebp - 32]
    jmp .cont_rows_loop

.entry_draw_done:
    mov eax, [ebp - 32]         ; Return visual rows rendered
    mov esp, ebp
    pop ebp
    restore_regs
    ret

;=============================================================================
; Procedure: journal_ensure_visible
; Purpose:   Adjusts jrnl_top_idx so that the selected entry (jrnl_sel_idx)
;            is visible within available screen rows (Rows 4..13 = 10 rows).
; IN:        None (reads jrnl_sel_idx, jrnl_top_idx, jrnl_line_count)
; OUT:       None (updates jrnl_top_idx in memory)
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_ensure_visible:
    save_regs

    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .ens_done

    ; If sel < top: top = sel
    mov eax, [jrnl_sel_idx]
    cmp eax, [jrnl_top_idx]
    jae .ens_check_bottom
    mov [jrnl_top_idx], eax
    jmp .ens_done

.ens_check_bottom:
    ; Calculate if jrnl_sel_idx fits on page starting at jrnl_top_idx
.ens_check_loop:
    mov esi, [jrnl_top_idx]
    cmp esi, [jrnl_sel_idx]
    jae .ens_done

    ; Sum visual rows from jrnl_top_idx to jrnl_sel_idx
    xor edx, edx                ; EDX = total visual rows
.ens_sum_loop:
    cmp esi, [jrnl_sel_idx]
    ja .ens_fits

    push esi
    push edx
    mov eax, esi
    shl eax, 4
    mov esi, [jrnl_entries + eax]     ; start_ptr
    mov ecx, [jrnl_entries + eax + 4] ; text_len
    call journal_entry_row_count      ; EAX = visual rows (1..4)
    pop edx
    pop esi

    add edx, eax
    inc esi
    jmp .ens_sum_loop

.ens_fits:
    cmp edx, 10                 ; Available rows = 13 - 4 + 1 = 10
    jbe .ens_done               ; Fits within 10 rows!

    ; Does not fit: advance jrnl_top_idx by 1 and re-check
    inc dword [jrnl_top_idx]
    jmp .ens_check_loop

.ens_done:
    restore_regs
    ret

;=============================================================================
; Procedure: journal_draw
; Purpose:   Constructs the Journal screen in out_buf.
;            - Phase 1: Clears borders and rows 1..17 with adaptive width ui_w.
;            - Phase 2: If jrnl_full_view == 1, renders full entry modal view.
;                       Otherwise renders selectable list with reverse-video
;                       highlight on jrnl_sel_idx.
; IN:        None
; OUT:       Appends escape sequences and text to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_draw:
    call ui_size_gate           ; Terminal dimension check gate (Task 9)
    call ui_layout_update       ; Recalculate adaptive layout geometry (PRD v2 §2)
    save_regs

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Borders and Erase Inner Rows
    ; -------------------------------------------------------------------------
    ; Position cursor at home (1,1)
    mov eax, UI_JRN_ROW_TOP
    mov ebx, 1
    call ui_goto

    ; Row 1: Top border line
    mov eax, UI_JRN_ROW_TOP
    call ui_frame_hline
    mov esi, ansi_erase_eol
    call buf_str

    ; Rows 2..16: Erase each row with ESC[K and anchor right border '|' at col ui_w
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
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content at Cursor Coordinates
    ; -------------------------------------------------------------------------
    ; 1. Title Row (Row 2, Col 4): "JOURNAL" or "JOURNAL - FULL ENTRY"
    mov eax, UI_JRN_ROW_TITLE
    mov ebx, UI_JRN_COL_TITLE
    call ui_goto

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color
    cmp dword [jrnl_full_view], 1
    je .draw_title_full
    mov esi, title_journal       ; "JOURNAL"
    jmp .draw_title_emit
.draw_title_full:
    mov esi, jrnl_title_full     ; "JOURNAL - FULL ENTRY"
.draw_title_emit:
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; 2. Separator Border (Row 3)
    mov eax, UI_JRN_ROW_SEP
    mov ebx, 1
    call ui_goto
    mov eax, UI_JRN_ROW_SEP
    call ui_frame_hline
    mov esi, ansi_erase_eol
    call buf_str

    ; 3. Journal Content Area (Rows 4..13)
    cmp dword [jrnl_full_view], 1
    je .draw_full_view

    ; List view mode: check if any lines exist
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jnz .draw_entries_exist

    ; No lines exist: show "No entries yet."
    mov eax, UI_JRN_ROW_FIRST
    mov ebx, UI_JRN_COL_TEXT
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov esi, jrnl_msg_empty      ; "No entries yet."
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .draw_feedback_msg

.draw_entries_exist:
    ; Ensure selected entry is visible
    call journal_ensure_visible

    ; Render entries starting from jrnl_top_idx
    mov ecx, [jrnl_top_idx]     ; ECX = entry index
    mov edx, UI_JRN_ROW_FIRST   ; EDX = current screen row (4)

.draw_entries_loop:
    cmp ecx, [jrnl_line_count]
    jae .draw_feedback_msg
    cmp edx, UI_JRN_ROW_LAST    ; Row 13
    ja .draw_feedback_msg

    push ecx
    push edx

    ; Check if entry index ECX == jrnl_sel_idx
    xor eax, eax
    cmp ecx, [jrnl_sel_idx]
    jne .draw_entry_not_sel
    inc eax                     ; EAX = 1 (highlighted)
.draw_entry_not_sel:
    push eax                    ; [esp] = is_highlighted
    mov eax, ecx                ; EAX = entry index
    mov ebx, edx                ; EBX = screen row
    pop edx                     ; EDX = is_highlighted
    call journal_draw_entry     ; Returns visual rows rendered in EAX

    pop edx                     ; Restore screen row
    pop ecx                     ; Restore entry index

    add edx, eax                ; Advance screen row
    inc ecx                     ; Next entry index
    jmp .draw_entries_loop

.draw_full_view:
    ; Full entry view: display selected entry starting at Row 4
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .draw_feedback_msg
    mov eax, [jrnl_sel_idx]
    cmp eax, ecx
    jae .draw_feedback_msg

    mov ebx, UI_JRN_ROW_FIRST   ; Row 4
    xor edx, edx                ; EDX = 0 (no reverse video highlight in full view)
    call journal_draw_entry
    jmp .draw_feedback_msg

.draw_feedback_msg:
    ; 4. Message Row (Row 15, Col 4)
    mov esi, [jrnl_msg]
    test esi, esi
    jz .draw_key_help

    mov eax, UI_JRN_ROW_MSG
    mov ebx, UI_JRN_COL_MSG
    call ui_goto

    cmp esi, err_could_not_save
    je .msg_color_red
    cmp esi, jrnl_msg_could_not_delete
    je .msg_color_red
    cmp esi, jrnl_msg_saved
    je .msg_color_green
    cmp esi, jrnl_msg_deleted
    je .msg_color_green

    ; Default: yellow for warnings/prompts
    mov al, SLOT_WARN
    call ui_color
    jmp .msg_print_body

.msg_color_red:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ERR
    call ui_color
    jmp .msg_print_body

.msg_color_green:
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_OK
    call ui_color

.msg_print_body:
    mov esi, [jrnl_msg]
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Clear message pointer only if not currently confirming deletion
    cmp dword [jrnl_msg], jrnl_msg_del_prompt
    je .draw_key_help
    mov dword [jrnl_msg], 0

.draw_key_help:
    ; 5. Key Help Prompt (Row 16, Col 4)
    mov eax, UI_JRN_ROW_HELP
    mov ebx, UI_JRN_COL_HELP
    call ui_goto

    cmp dword [jrnl_full_view], 1
    je .help_full
    cmp dword [jrnl_line_count], 0
    je .help_empty
    mov esi, jrnl_help
    jmp .help_emit
.help_full:
    mov esi, jrnl_help_full
    jmp .help_emit
.help_empty:
    mov esi, jrnl_help
.help_emit:
    call buf_str

    restore_regs
    ret

;=============================================================================
; Procedure: journal_delete_prompt
; Purpose:   Prompts user for deletion confirmation: "Delete this entry? (y/n)"
;            If user confirms ('y'/'Y'), invokes file_delete_range on the
;            exact file byte range [file_off, file_off + file_len).
;            Refreshes journal from disk on success and clamps selection.
;            Cancelling leaves the file 100% untouched.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_delete_prompt:
    save_regs

    ; Check if any entry exists to delete
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .del_prompt_done

    mov eax, [jrnl_sel_idx]
    cmp eax, ecx
    jae .del_prompt_done

    ; Set prompt message and redraw frame
    mov dword [jrnl_msg], jrnl_msg_del_prompt
    call journal_draw
    call buf_flush

.del_wait_key:
    call key_wait

    cmp eax, KEY_CTRL_C
    je .del_ctrl_c

    ; Case-insensitive check for 'Y' / 'y'
    cmp eax, KEY_Y              ; 89
    je .del_confirm_yes
    cmp eax, 121                ; 'y'
    je .del_confirm_yes

    ; Any other key: cancel deletion!
    mov dword [jrnl_msg], 0
    jmp .del_prompt_done

.del_confirm_yes:
    ; User confirmed: delete entry at jrnl_sel_idx
    mov eax, [jrnl_sel_idx]
    shl eax, 4                  ; index * 16
    mov esi, path_journal       ; ESI = path "journal.txt"
    mov edx, [jrnl_entries + eax + 8]   ; EDX = file_off
    mov ecx, [jrnl_entries + eax + 12]  ; ECX = file_len
    add ecx, edx                ; ECX = end_off = file_off + file_len
    mov eax, edx                ; EAX = start_off
    mov edx, ecx                ; EDX = end_off
    call file_delete_range      ; EAX = 0 (OK) or -1 (ERR)
    test eax, eax
    jnz .del_failed

    ; Delete succeeded!
    mov dword [jrnl_msg], jrnl_msg_deleted
    mov dword [jrnl_full_view], 0 ; Return to list if in full view

    ; Reload journal tail from disk
    call journal_load_tail
    call journal_find_lines

    ; Clamp selection to remaining entries
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .del_now_empty
    cmp [jrnl_sel_idx], ecx
    jb .del_clamp_ok
    dec ecx
    mov [jrnl_sel_idx], ecx
.del_clamp_ok:
    call journal_ensure_visible
    jmp .del_prompt_done

.del_now_empty:
    mov dword [jrnl_sel_idx], 0
    mov dword [jrnl_top_idx], 0
    jmp .del_prompt_done

.del_failed:
    mov dword [jrnl_msg], jrnl_msg_could_not_delete
    jmp .del_prompt_done

.del_ctrl_c:
    mov dword [state], STATE_QUIT

.del_prompt_done:
    mov dword [need_redraw], 1
    restore_regs
    ret

;=============================================================================
; Procedure: journal_new_entry
; Purpose:   Interactive addition of a new journal entry (Key 'N'):
;            1. Sets prompt on Row 15, draws frame, and flushes output buffer.
;            2. Positions cursor directly after prompt (computed via str_len).
;            3. Calls read_line with line_buf and capacity JOURNAL_ENTRY_MAX (200).
;            4. Empty input cancels: writes nothing, clears prompt.
;            5. Non-empty input calls journal_add:
;               - On success: sets "Entry saved". Refreshes view and selects new entry.
;               - On failure: sets "Could not save" (FR-D4).
;            6. Always sets need_redraw = 1 to clean up cooked mode echo.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
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
    call ui_goto

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
    mov dword [jrnl_full_view], 0

    ; Refresh view to immediately display new entry
    call journal_load_tail
    call journal_find_lines
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .new_finish
    dec ecx
    mov [jrnl_sel_idx], ecx     ; Select newly added entry at tail
    call journal_ensure_visible
    jmp .new_finish

.new_failed:
    mov dword [jrnl_msg], err_could_not_save
    jmp .new_finish

.new_canceled:
    mov dword [jrnl_msg], 0

.new_finish:
    mov dword [need_redraw], 1
    restore_regs
    ret

;=============================================================================
; Procedure: journal_run
; Purpose:   Runs the modal event loop for the Journal screen (FR-J1):
;            - Renders frame on need_redraw dirty flag via journal_draw + buf_flush.
;            - Dispatches interactive commands:
;              * Up / Down   -> Move selection between displayed entries
;              * PgUp / PgDn -> Page backward/forward through entries
;              * Enter       -> Toggle full-entry view for selected entry
;              * 'D' / Del   -> Delete selected entry with confirmation
;              * 'N'         -> Add new journal entry
;              * 'V'         -> Refresh view from disk
;              * 'B'         -> Return to menu (or leave full view)
;              * Ctrl+C      -> Exit application
; IN:        None
; OUT:       None (returns to menu on exit)
; CLOBBERS:  None (preserves all)
;=============================================================================
journal_run:
    save_regs

    mov dword [state], STATE_JOURNAL
    mov dword [jrnl_msg], 0
    mov dword [jrnl_full_view], 0
    mov dword [jrnl_view_active], 1

    ; Load entries on screen entry
    call journal_load_tail
    call journal_find_lines
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .run_init_empty
    dec ecx
    mov [jrnl_sel_idx], ecx     ; Highlight newest entry by default
    call journal_ensure_visible
    jmp .run_init_dirty

.run_init_empty:
    mov dword [jrnl_sel_idx], 0
    mov dword [jrnl_top_idx], 0

.run_init_dirty:
    mov dword [need_redraw], 1

.journal_loop:
    cmp dword [need_redraw], 0
    je .journal_wait_key

    call journal_draw
    call buf_flush              ; Single sys_write per frame (FR-U4)
    mov dword [need_redraw], 0

.journal_wait_key:
    ; Low-CPU 50ms sleep via sys_nanosleep while polling for terminal resize (PRD v2 §2)
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_50MS
    syscall SYS_NANOSLEEP, timespec, 0

    call term_size_ok
    test eax, eax
    jz .journal_need_redraw     ; Shrunk below 80x24: trigger redraw (enters size gate)
    mov edx, [term_cols]
    cmp edx, [ui_seen_cols]
    jne .journal_need_redraw
    mov edx, [term_rows]
    cmp edx, [ui_seen_rows]
    jne .journal_need_redraw

    call key_poll
    cmp eax, KEY_NONE
    je .journal_wait_key
    jmp .journal_dispatch_key

.journal_need_redraw:
    mov dword [need_redraw], 1
    jmp .journal_loop

.journal_dispatch_key:
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c

    cmp eax, KEY_B
    je .key_b

    cmp eax, KEY_UP
    je .key_up

    cmp eax, KEY_DOWN
    je .key_down

    cmp eax, KEY_PGUP
    je .key_pgup

    cmp eax, KEY_PGDN
    je .key_pgdn

    cmp eax, KEY_ENTER
    je .key_enter

    cmp eax, KEY_D
    je .key_d

    cmp eax, KEY_DELETE
    je .key_d

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
    cmp dword [jrnl_full_view], 1
    jne .key_b_to_menu
    mov dword [jrnl_full_view], 0
    mov dword [need_redraw], 1
    jmp .journal_loop

.key_b_to_menu:
    mov dword [state], STATE_MENU
    jmp .journal_exit

.key_up:
    cmp dword [jrnl_full_view], 1
    je .journal_loop
    mov eax, [jrnl_sel_idx]
    test eax, eax
    jz .journal_loop
    dec dword [jrnl_sel_idx]
    call journal_ensure_visible
    mov dword [need_redraw], 1
    jmp .journal_loop

.key_down:
    cmp dword [jrnl_full_view], 1
    je .journal_loop
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .journal_loop
    dec ecx
    cmp [jrnl_sel_idx], ecx
    jae .journal_loop
    inc dword [jrnl_sel_idx]
    call journal_ensure_visible
    mov dword [need_redraw], 1
    jmp .journal_loop

.key_pgup:
    cmp dword [jrnl_full_view], 1
    je .journal_loop
    mov eax, [jrnl_sel_idx]
    test eax, eax
    jz .pgup_load_older
    cmp eax, 5
    jb .pgup_clamp_zero
    sub dword [jrnl_sel_idx], 5
    jmp .pgup_vis
.pgup_clamp_zero:
    mov dword [jrnl_sel_idx], 0
.pgup_vis:
    call journal_ensure_visible
    mov dword [need_redraw], 1
    jmp .journal_loop

.pgup_load_older:
    ; Already at index 0. Can we load an older 16 KB chunk from the file?
    cmp dword [jrnl_window_offset], 0
    jbe .journal_loop           ; At beginning of file: cannot page older
    mov eax, [jrnl_entries + 8] ; file_off of oldest entry in window
    test eax, eax
    jz .journal_loop
    call journal_load_window
    call journal_find_lines
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .journal_loop
    dec ecx
    mov [jrnl_sel_idx], ecx     ; Select bottom of older page
    call journal_ensure_visible
    mov dword [need_redraw], 1
    jmp .journal_loop

.key_pgdn:
    cmp dword [jrnl_full_view], 1
    je .journal_loop
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .journal_loop
    dec ecx
    cmp [jrnl_sel_idx], ecx
    jae .pgdn_load_newer
    add dword [jrnl_sel_idx], 5
    cmp [jrnl_sel_idx], ecx
    jbe .pgdn_vis
    mov [jrnl_sel_idx], ecx
.pgdn_vis:
    call journal_ensure_visible
    mov dword [need_redraw], 1
    jmp .journal_loop

.pgdn_load_newer:
    ; Already at bottom of window. Check if newer entries exist in file
    mov eax, [jrnl_line_count]
    dec eax
    shl eax, 4                  ; index * 16
    mov edx, [jrnl_entries + eax + 8]   ; file_off
    add edx, [jrnl_entries + eax + 12]  ; + file_len
    cmp edx, [jrnl_file_size]
    jae .journal_loop           ; At end of file: cannot page newer

    ; target_end = min(jrnl_file_size, edx + JRNL_BUF_SIZE)
    lea eax, [edx + JRNL_BUF_SIZE]
    cmp eax, [jrnl_file_size]
    jbe .pgdn_target_ok
    mov eax, [jrnl_file_size]
.pgdn_target_ok:
    call journal_load_window
    call journal_find_lines
    mov dword [jrnl_sel_idx], 0
    mov dword [jrnl_top_idx], 0
    mov dword [need_redraw], 1
    jmp .journal_loop

.key_enter:
    mov ecx, [jrnl_line_count]
    test ecx, ecx
    jz .journal_loop
    xor dword [jrnl_full_view], 1
    mov dword [need_redraw], 1
    jmp .journal_loop

.key_d:
    call journal_delete_prompt
    jmp .journal_loop

.key_n:
    cmp dword [jrnl_full_view], 1
    jne .key_n_call
    mov dword [jrnl_full_view], 0
.key_n_call:
    call journal_new_entry
    jmp .journal_loop

.key_v:
    call journal_load_tail
    call journal_find_lines
    call journal_ensure_visible
    mov dword [need_redraw], 1
    jmp .journal_loop

.journal_exit:
    restore_regs
    ret
