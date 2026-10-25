; =============================================================================
; Pawmodoro - Terminal Control & Input Engine (src/term.asm)
;
; Purpose: Raw/cooked mode terminal management via ioctl (TCGETS/TCSETS),
;          cursor visibility, alternate screen buffering, non-blocking keyboard
;          polling, blocking key waiting with 50ms sleep, and line input reading.
; Reference: PRD §3.2, §4.1 FR-U1/FR-U5, §6.2, §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: term_init
; Purpose:   Saves original termios attributes via ioctl TCGETS into termios_orig.
;            If stdin is not a terminal (ioctl fails with negative status), writes
;            a descriptive error to stderr (fd 2) and exits with EXIT_FAILURE
;            WITHOUT emitting any terminal escape sequences.
;            On success, initializes termios_raw as a copy of termios_orig, switches
;            to the alternate screen buffer, hides the cursor, flushes output once,
;            and sets term_active = 1.
; IN:        None
; OUT:       None (saves termios, enters alt screen [ESC[?1049h], hides cursor)
; CLOBBERS:  None (preserves all)
;=============================================================================
term_init:
    save_regs

    ; Query current terminal attributes from STDIN
    syscall SYS_IOCTL, FD_STDIN, TCGETS, termios_orig
    test eax, eax
    js .init_not_a_tty          ; Negative return indicates not a TTY or ioctl error

    ; Copy termios_orig into termios_raw (TERMIOS_SIZE bytes)
    cld
    mov esi, termios_orig
    mov edi, termios_raw
    mov ecx, TERMIOS_SIZE
    rep movsb

    ; Switch to alternate screen and hide cursor
    mov esi, ansi_alt_on
    call buf_str
    mov esi, ansi_hide_cursor
    call buf_str
    call buf_flush

    ; Mark terminal as actively initialized
    mov dword [term_active], 1

    restore_regs
    ret

.init_not_a_tty:
    ; Standard input is not a terminal: report to stderr and exit immediately
    syscall SYS_WRITE, FD_STDERR, err_not_a_tty, err_not_a_tty_len
    syscall SYS_EXIT, EXIT_FAILURE

;=============================================================================
; Procedure: term_restore
; Purpose:   The single unified terminal cleanup routine. Restores original termios
;            attributes (termios_orig) via TCSETS, resets terminal styles, restores
;            cursor visibility, switches back from alternate screen, flushes output,
;            and clears term_active. If term_active is 0, execution returns safely
;            without performing redundant operations (safe to call multiple times).
; IN:        None
; OUT:       None (restores termios, leaves alt screen [ESC[?1049l], shows cursor)
; CLOBBERS:  None (preserves all)
;=============================================================================
term_restore:
    save_regs

    ; Check if terminal initialization is currently active
    cmp dword [term_active], 0
    je .restore_done            ; Already restored or never initialized: do nothing

    ; Restore original termios settings
    syscall SYS_IOCTL, FD_STDIN, TCSETS, termios_orig

    ; Discard any incomplete buffered drawing frame
    mov dword [out_len], 0

    ; Reset flash, taskbar progress, window title, attributes, cursor, and alternate screen
    mov esi, ansi_flash_off
    call buf_str
    mov esi, ansi_taskbar_clear
    call buf_str
    mov esi, ansi_title_restore
    call buf_str
    mov esi, ansi_reset
    call buf_str
    mov esi, ansi_show_cursor
    call buf_str
    mov esi, ansi_alt_off
    call buf_str
    call buf_flush

    ; Clear active flag
    mov dword [term_active], 0

.restore_done:
    restore_regs
    ret

;=============================================================================
; Procedure: term_raw
; Purpose:   Disables ICANON, ECHO, and ISIG flags in termios_raw c_lflag, sets
;            VMIN = 0 and VTIME = 0 in c_cc, and applies settings via TCSETS.
;            Output post-processing (c_oflag) is left untouched.
;            Because ISIG is cleared, Ctrl+C is delivered as byte 3 without raising
;            kernel SIGINT signals. This operation is idempotent.
; IN:        None
; OUT:       None (switches termios to non-blocking raw mode [VMIN=0, VTIME=0])
; CLOBBERS:  None (preserves all)
;=============================================================================
term_raw:
    save_regs

    ; Clear ICANON (canonical mode), ECHO (local echo), and ISIG (signals)
    and dword [termios_raw + C_LFLAG_OFFSET], ~(ICANON | ECHO | ISIG)

    ; Configure non-blocking reads (return immediately with available bytes)
    mov byte [termios_raw + C_CC_OFFSET + VMIN], 0
    mov byte [termios_raw + C_CC_OFFSET + VTIME], 0

    ; Apply raw configuration
    syscall SYS_IOCTL, FD_STDIN, TCSETS, termios_raw
    test eax, eax
    js .raw_failed

    restore_regs
    ret

.raw_failed:
    mov ebx, EXIT_FAILURE
    call app_exit

;=============================================================================
; Procedure: term_cooked
; Purpose:   Applies original termios settings (termios_orig) via TCSETS so the
;            user has local echo, canonical line buffering, and backspace editing.
; IN:        None
; OUT:       None (switches termios to canonical cooked mode with echo)
; CLOBBERS:  None (preserves all)
;=============================================================================
term_cooked:
    save_regs

    syscall SYS_IOCTL, FD_STDIN, TCSETS, termios_orig
    test eax, eax
    js .cooked_failed

    restore_regs
    ret

.cooked_failed:
    mov ebx, EXIT_FAILURE
    call app_exit

;=============================================================================
; Procedure: key_poll
; Purpose:   Reads keyboard input from FD_STDIN non-blockingly.
;            - If no data is available (returns <= 0), returns KEY_NONE (-1).
;            - Lowercase letters ('a'..'z') are automatically converted to uppercase.
;            - Lone ESC (byte 27 with no subsequent bytes within ~5 ms) returns KEY_ESC (27).
;            - Recognized CSI and SS3 escape sequences return extended key codes:
;                ESC [ A / ESC O A -> KEY_UP (0x101)
;                ESC [ B / ESC O B -> KEY_DOWN (0x102)
;                ESC [ C / ESC O C -> KEY_RIGHT (0x103)
;                ESC [ D / ESC O D -> KEY_LEFT (0x104)
;                ESC [ 5 ~         -> KEY_PGUP (0x105)
;                ESC [ 6 ~         -> KEY_PGDN (0x106)
;                ESC [ H / ESC O H / ESC [ 1 ~ -> KEY_HOME (0x107)
;                ESC [ F / ESC O F / ESC [ 4 ~ -> KEY_END (0x108)
;                ESC [ 3 ~         -> KEY_DELETE (0x109)
;            - Unknown or malformed escape sequences are consumed and drained
;              up to their sequence terminator, returning KEY_NONE (-1) without
;              leaking sequence bytes to the application.
;            - Ctrl+C is returned as KEY_CTRL_C (3).
; IN:        None
; OUT:       EAX = Uppercase ASCII key (0..255), extended key code (KEY_UP..KEY_DELETE),
;                  or -1 (KEY_NONE)
; CLOBBERS:  EAX
;=============================================================================
key_poll:
    save_regs

    ; Step 1: Attempt non-blocking 1-byte read from standard input
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_got_key            ; Exactly 1 byte read

    ; Check if no data is available or non-fatal interruption
    test eax, eax
    jz .poll_no_key             ; 0 = no data ready / EOF
    cmp eax, -ERR_EINTR         ; Interrupted by signal (-4)
    je .poll_no_key
    cmp eax, -ERR_EAGAIN        ; Resource temporarily unavailable (-11)
    je .poll_no_key

    ; Unhandled negative status: fatal sys_read error
    mov ebx, EXIT_FAILURE
    call app_exit

.poll_got_key:
    ; Check if byte is Escape (CHAR_ESC = 27)
    cmp byte [in_buf], CHAR_ESC
    je .poll_check_escape

    ; Convert lowercase letters 'a'..'z' to uppercase
    mov al, [in_buf]
    cmp al, CHAR_LOWER_A
    jb .poll_return_char
    cmp al, CHAR_LOWER_Z
    ja .poll_return_char
    and al, ~CASE_BIT_MASK      ; Clear bit 5 to convert to uppercase

.poll_return_char:
    movzx eax, al               ; Zero-extend character byte into EAX
    jmp .poll_done

; -----------------------------------------------------------------------------
; Escape Sequence Handling
; -----------------------------------------------------------------------------
.poll_check_escape:
    ; Probe non-blockingly for follow-up escape sequence byte
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_got_byte2          ; Immediate follow-up byte available

    ; No byte immediately available: sleep ~5 ms grace period to prevent
    ; slow or packet-fragmented escape sequences from misfiring as lone ESC
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_5MS
    syscall SYS_NANOSLEEP, timespec, 0

    ; Re-check input once after 5 ms grace period
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_got_byte2

    ; Genuinely lone Escape key pressed by user
    mov eax, KEY_ESC
    jmp .poll_done

.poll_got_byte2:
    mov bl, byte [in_buf]       ; BL = second byte of escape sequence

    cmp bl, CHAR_LBRACKET       ; '[' (0x5B = 91) -> CSI sequence
    je .poll_parse_csi

    cmp bl, CHAR_UPPER_O        ; 'O' (0x4F = 79) -> SS3 sequence
    je .poll_parse_ss3

    ; Any other byte after ESC (e.g. Alt+key or unsupported ESC prefix):
    ; Consume it and return KEY_NONE (-1)
    mov eax, KEY_NONE
    jmp .poll_done

; -----------------------------------------------------------------------------
; Parse SS3 Sequences (ESC O <char>)
; -----------------------------------------------------------------------------
.poll_parse_ss3:
    ; Read byte 3
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_check_ss3_byte3

    ; Probe with 5 ms grace sleep if byte 3 is delayed
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_5MS
    syscall SYS_NANOSLEEP, timespec, 0
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    jne .poll_discard_unknown   ; Incomplete sequence -> return -1

.poll_check_ss3_byte3:
    mov al, byte [in_buf]       ; AL = byte 3

    cmp al, 'A'
    je .poll_return_up
    cmp al, 'B'
    je .poll_return_down
    cmp al, 'C'
    je .poll_return_right
    cmp al, 'D'
    je .poll_return_left
    cmp al, 'H'
    je .poll_return_home
    cmp al, 'F'
    je .poll_return_end

    ; Unsupported SS3 sequence: drain any immediate extra bytes and ignore
    mov edi, 8
.poll_drain_ss3_loop:
    dec edi
    jz .poll_discard_unknown
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_drain_ss3_loop
    jmp .poll_discard_unknown

; -----------------------------------------------------------------------------
; Parse CSI Sequences (ESC [ ...)
; Note: ESI and EDI are preserved across syscall invocations (syscall macro
; clobbers EAX, EBX, ECX, EDX). ESI stores byte 3; EDI bounds drain iterations.
; -----------------------------------------------------------------------------
.poll_parse_csi:
    ; Read byte 3
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_check_csi_byte3

    ; Probe with 5 ms grace sleep if byte 3 is delayed
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_5MS
    syscall SYS_NANOSLEEP, timespec, 0
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    jne .poll_discard_unknown   ; Incomplete CSI sequence -> return -1

.poll_check_csi_byte3:
    movzx esi, byte [in_buf]    ; ESI = byte 3 (preserved across syscall)

    ; Single-character CSI sequences: ESC [ A/B/C/D/H/F
    cmp esi, 'A'
    je .poll_return_up
    cmp esi, 'B'
    je .poll_return_down
    cmp esi, 'C'
    je .poll_return_right
    cmp esi, 'D'
    je .poll_return_left
    cmp esi, 'H'
    je .poll_return_home
    cmp esi, 'F'
    je .poll_return_end

    ; Numbered CSI sequences: ESC [ <num> ~
    ; Check for '3', '5', '6', '1', '4'
    cmp esi, '3'
    je .poll_read_csi_tilde
    cmp esi, '5'
    je .poll_read_csi_tilde
    cmp esi, '6'
    je .poll_read_csi_tilde
    cmp esi, '1'
    je .poll_read_csi_tilde
    cmp esi, '4'
    je .poll_read_csi_tilde

    ; Not a recognized single character or supported numbered prefix.
    ; Check if byte 3 is already a CSI sequence terminator (0x40 - 0x7E)
    cmp esi, 0x40
    jb .poll_drain_csi_start
    cmp esi, 0x7E
    jbe .poll_discard_unknown   ; Sequence terminator already consumed

    jmp .poll_drain_csi_start

.poll_read_csi_tilde:
    ; Read byte 4 (ESI still holds byte 3 across syscall)
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_check_csi_tilde

    ; Probe with 5 ms grace sleep if byte 4 is delayed
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_5MS
    syscall SYS_NANOSLEEP, timespec, 0
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    jne .poll_discard_unknown

.poll_check_csi_tilde:
    cmp byte [in_buf], CHAR_TILDE   ; '~' (0x7E)
    jne .poll_drain_csi_check_cur   ; Byte 4 is not '~' (e.g. modified key ESC [ 1 ; 5 A) -> drain

    ; Byte 4 is '~': match saved byte 3 in ESI to appropriate key code
    cmp esi, '3'
    je .poll_return_delete
    cmp esi, '5'
    je .poll_return_pgup
    cmp esi, '6'
    je .poll_return_pgdn
    cmp esi, '1'
    je .poll_return_home
    cmp esi, '4'
    je .poll_return_end

    jmp .poll_discard_unknown

; -----------------------------------------------------------------------------
; Unknown CSI Sequence Drain Loop
; Consumes bytes until a standard CSI terminator (0x40 - 0x7E) is encountered,
; bounded to at most 16 bytes to prevent infinite loops on malformed streams.
; Uses EDI as loop counter (preserved across syscall).
; -----------------------------------------------------------------------------
.poll_drain_csi_check_cur:
    ; Check if the byte already in in_buf is a terminator (0x40 - 0x7E)
    movzx eax, byte [in_buf]
    cmp eax, 0x40
    jb .poll_drain_csi_start
    cmp eax, 0x7E
    jbe .poll_discard_unknown   ; Current byte was terminator: fully drained

.poll_drain_csi_start:
    mov edi, 16                 ; Bounded iteration counter (max 16 bytes)

.poll_drain_csi_loop:
    dec edi
    jz .poll_discard_unknown    ; Bound reached: stop draining

    ; Read next byte non-blockingly
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    jne .poll_discard_unknown   ; No more bytes ready: stop draining

    movzx eax, byte [in_buf]
    cmp eax, 0x40
    jb .poll_drain_csi_loop
    cmp eax, 0x7E
    jbe .poll_discard_unknown   ; Terminator reached: sequence fully consumed!
    jmp .poll_drain_csi_loop

; -----------------------------------------------------------------------------
; Key Return Points
; -----------------------------------------------------------------------------
.poll_return_up:
    mov eax, KEY_UP
    jmp .poll_done

.poll_return_down:
    mov eax, KEY_DOWN
    jmp .poll_done

.poll_return_right:
    mov eax, KEY_RIGHT
    jmp .poll_done

.poll_return_left:
    mov eax, KEY_LEFT
    jmp .poll_done

.poll_return_pgup:
    mov eax, KEY_PGUP
    jmp .poll_done

.poll_return_pgdn:
    mov eax, KEY_PGDN
    jmp .poll_done

.poll_return_home:
    mov eax, KEY_HOME
    jmp .poll_done

.poll_return_end:
    mov eax, KEY_END
    jmp .poll_done

.poll_return_delete:
    mov eax, KEY_DELETE
    jmp .poll_done

.poll_discard_unknown:
    mov eax, KEY_NONE
    jmp .poll_done

.poll_no_key:
    mov eax, KEY_NONE

.poll_done:
    restore_regs
    ret

;=============================================================================
; Procedure: key_wait
; Purpose:   Repeatedly calls key_poll. If no key is ready (KEY_NONE), sleeps for
;            50 milliseconds (50,000,000 ns) using sys_nanosleep before retrying.
;            Eliminates busy-waiting and keeps CPU usage near 0%.
; IN:        None
; OUT:       EAX = Uppercase key (blocks, polling non-blockingly at 50 ms cadence)
; CLOBBERS:  EAX
;=============================================================================
key_wait:
    save_regs

.wait_loop:
    call key_poll
    cmp eax, KEY_NONE
    jne .wait_done

    ; Set up timespec structure for 50 ms sleep (0 sec, 50,000,000 nsec)
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_50MS
    syscall SYS_NANOSLEEP, timespec, 0
    jmp .wait_loop

.wait_done:
    restore_regs
    ret

;=============================================================================
; Procedure: read_line
; Purpose:   Flushes pending output, activates cooked mode (local echo and backspace
;            editing), and shows the cursor. Reads up to ECX + 1 characters into
;            buffer EDI. If input ends with newline, the newline is stripped. If
;            input exceeds ECX characters, the string is truncated at ECX and any
;            remaining characters on that line are drained until newline is consumed.
;            Always NUL-terminates the stored string, hides cursor, returns terminal
;            to raw mode, and returns string length in EAX.
; IN:        EDI = Destination buffer (capacity >= ECX + 2 bytes), ECX = Max characters
; OUT:       EAX = Length in bytes (NUL-terminated, strips LF, discards overflow)
; CLOBBERS:  EAX
;=============================================================================
read_line:
    save_regs

    push edi                    ; [esp + 4] = caller buffer pointer
    push ecx                    ; [esp] = max character capacity

    ; Step 1: Flush pending output so prompt is fully visible
    call buf_flush

    ; Step 2: Switch to cooked mode and show cursor for interactive editing
    call term_cooked
    mov esi, ansi_show_cursor
    call buf_str
    call buf_flush

    ; Step 3: Read up to max_chars + 1 bytes in cooked mode
    mov edi, [esp + 4]          ; EDI = dest buffer
    mov edx, [esp]              ; EDX = max_chars
    inc edx                     ; EDX = count = max_chars + 1
    mov ecx, edi                ; ECX = buffer address
    mov ebx, FD_STDIN           ; EBX = stdin
    mov eax, SYS_READ           ; EAX = sys_read (3)
    int 0x80

    cmp eax, 0
    jle .line_empty             ; 0 = EOF, negative = read error

    ; Check if the last byte read is a newline (CHAR_LF = 10)
    mov ebx, eax                ; EBX = bytes read
    mov edx, [esp]              ; EDX = max_chars
    mov edi, [esp + 4]          ; EDI = dest buffer

    cmp byte [edi + ebx - 1], CHAR_LF
    jne .line_overflow

    ; Input was within capacity: strip trailing newline and NUL-terminate
    dec ebx                     ; Exclude newline from stored length
    mov byte [edi + ebx], CHAR_NULL
    mov eax, ebx                ; Return length
    jmp .line_cleanup

.line_overflow:
    ; Input exceeded capacity: truncate stored text at max_chars
    mov byte [edi + edx], CHAR_NULL

    ; Drain remaining line characters in cooked mode until newline is consumed
.line_drain_loop:
    mov eax, SYS_READ
    mov ebx, FD_STDIN
    mov ecx, in_buf
    mov edx, 1
    int 0x80

    cmp eax, 0
    jle .line_drain_done
    cmp byte [in_buf], CHAR_LF
    je .line_drain_done
    jmp .line_drain_loop

.line_drain_done:
    mov edx, [esp]              ; EDX = max_chars
    mov eax, edx                ; Return max_chars as stored length
    jmp .line_cleanup

.line_empty:
    ; EOF or error encountered: produce empty NUL-terminated string
    mov edi, [esp + 4]
    mov byte [edi], CHAR_NULL
    xor eax, eax                ; Return length 0

.line_cleanup:
    add esp, 8                  ; Clean up pushed edi and max_chars
    push eax                    ; Preserve computed return length

    ; Hide cursor and restore raw mode
    mov esi, ansi_hide_cursor
    call buf_str
    call buf_flush
    call term_raw

    pop eax                     ; Restore return length
    restore_regs
    ret

;=============================================================================
; Procedure: sig_handler
; Purpose:   Invoked by kernel on SIGHUP (1), SIGINT (2), or SIGTERM (15).
;            Calls app_exit(EXIT_SIGNALED = 130) to guarantee term_restore is
;            executed before terminating, preventing a corrupted terminal shell.
; IN:        Signal number on stack (kernel convention, ignored)
; OUT:       None (never returns)
; CLOBBERS:  None (process terminates via app_exit)
;=============================================================================
sig_handler:
    mov ebx, EXIT_SIGNALED      ; 130 (128 + SIGINT)
    call app_exit
    ; app_exit never returns

;=============================================================================
; Procedure: term_install_signals
; Purpose:   Installs sig_handler for SIGHUP (1), SIGINT (2), and SIGTERM (15)
;            using sys_signal (syscall 48).
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
term_install_signals:
    save_regs

    syscall SYS_SIGNAL, SIGHUP, sig_handler
    syscall SYS_SIGNAL, SIGINT, sig_handler
    syscall SYS_SIGNAL, SIGTERM, sig_handler

    restore_regs
    ret

;=============================================================================
; Procedure: term_size_ok
; Purpose:   Issues ioctl TIOCGWINSZ (0x5413) on FD_STDIN to query terminal size.
;            If the ioctl fails (negative status) or either dimension is 0,
;            assumes the size is fine (returns EAX = 1).
;            Otherwise, extracts ws_row (word @ 0) and ws_col (word @ 2)
;            using movzx into term_rows and term_cols.
;            If term_cols >= TERM_MIN_COLS (80) and term_rows >= TERM_MIN_ROWS (24),
;            returns EAX = 1. Otherwise, returns EAX = 0.
; IN:        None
; OUT:       EAX = 1 if >= 80x24 or size unknown, 0 if too small;
;            Stores last rows/cols into [term_rows] and [term_cols]
; CLOBBERS:  EAX
;=============================================================================
term_size_ok:
    save_regs

    ; Query window size via ioctl TIOCGWINSZ
    syscall SYS_IOCTL, FD_STDIN, TIOCGWINSZ, winsize
    test eax, eax
    js .size_unknown            ; ioctl failed: assume size is fine

    ; Read ws_row (word at offset 0) and ws_col (word at offset 2)
    movzx eax, word [winsize + WINSIZE_OFF_ROWS]
    mov [term_rows], eax
    movzx edx, word [winsize + WINSIZE_OFF_COLS]
    mov [term_cols], edx

    ; If either rows or cols is 0, treat as unknown/fine
    test eax, eax
    jz .size_unknown
    test edx, edx
    jz .size_unknown

    ; Check cols >= TERM_MIN_COLS (80) and rows >= TERM_MIN_ROWS (24)
    cmp edx, TERM_MIN_COLS
    jb .size_too_small
    cmp eax, TERM_MIN_ROWS
    jb .size_too_small

    ; Size is at least 80x24
    mov eax, 1
    jmp .size_done

.size_too_small:
    xor eax, eax                ; EAX = 0
    jmp .size_done

.size_unknown:
    mov eax, 1

.size_done:
    restore_regs
    ret
