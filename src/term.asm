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

; -----------------------------------------------------------------------------
; term_init: Initialize terminal state, alternate screen, and hide cursor.
;
; Purpose:  Saves original termios attributes via ioctl TCGETS into termios_orig.
;           If stdin is not a terminal (ioctl fails with negative status), writes
;           a descriptive error to stderr (fd 2) and exits with EXIT_FAILURE
;           WITHOUT emitting any terminal escape sequences.
;           On success, initializes termios_raw as a copy of termios_orig, switches
;           to the alternate screen buffer, hides the cursor, flushes output once,
;           and sets term_active = 1.
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; term_restore: Restore original cooked terminal state and leave alternate screen.
;
; Purpose:  The single unified terminal cleanup routine. Restores original termios
;           attributes (termios_orig) via TCSETS, resets terminal styles, restores
;           cursor visibility, switches back from alternate screen, flushes output,
;           and clears term_active. If term_active is 0, execution returns safely
;           without performing redundant operations (safe to call multiple times).
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only
; -----------------------------------------------------------------------------
term_restore:
    save_regs

    ; Check if terminal initialization is currently active
    cmp dword [term_active], 0
    je .restore_done            ; Already restored or never initialized: do nothing

    ; Restore original termios settings
    syscall SYS_IOCTL, FD_STDIN, TCSETS, termios_orig

    ; Discard any incomplete buffered drawing frame
    mov dword [out_len], 0

    ; Reset styles, show cursor, and return to primary screen buffer (in that order)
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

; -----------------------------------------------------------------------------
; term_raw: Switch terminal into raw non-canonical mode.
;
; Purpose:  Disables ICANON, ECHO, and ISIG flags in termios_raw c_lflag, sets
;           VMIN = 0 and VTIME = 0 in c_cc, and applies the settings via TCSETS.
;           Output post-processing (c_oflag) is left untouched.
;           Because ISIG is cleared, Ctrl+C is delivered as byte 3 without raising
;           kernel SIGINT signals. This operation is idempotent.
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only
; -----------------------------------------------------------------------------
term_raw:
    save_regs

    ; Clear ICANON (canonical mode), ECHO (local echo), and ISIG (signals)
    and dword [termios_raw + C_LFLAG_OFFSET], ~(ICANON | ECHO | ISIG)

    ; Configure non-blocking reads (return immediately with available bytes)
    mov byte [termios_raw + C_CC_OFFSET + VMIN], 0
    mov byte [termios_raw + C_CC_OFFSET + VTIME], 0

    ; Apply raw configuration
    syscall SYS_IOCTL, FD_STDIN, TCSETS, termios_raw

    restore_regs
    ret

; -----------------------------------------------------------------------------
; term_cooked: Switch terminal into standard cooked line mode.
;
; Purpose:  Applies original termios settings (termios_orig) via TCSETS so the
;           user has local echo, canonical line buffering, and backspace editing.
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only
; -----------------------------------------------------------------------------
term_cooked:
    save_regs

    syscall SYS_IOCTL, FD_STDIN, TCSETS, termios_orig

    restore_regs
    ret

; -----------------------------------------------------------------------------
; key_poll: Non-blocking single-key poll.
;
; Purpose:  Reads a single byte from FD_STDIN without blocking.
;           - If no data is available (returns <= 0), returns KEY_NONE (-1).
;           - Lowercase letters ('a'..'z') are automatically converted to uppercase.
;           - Lone ESC (byte 27 with no subsequent bytes) returns KEY_ESC (27).
;           - Multi-byte escape sequences (such as arrow keys ESC [ A) are consumed
;             and completely drained non-blockingly, returning KEY_NONE (-1) so
;             no stray escape characters leak into subsequent polls.
;           - Ctrl+C is returned as KEY_CTRL_C (3).
;           - Character code is returned zero-extended in EAX (0..255).
; IN:       none
; OUT:      EAX = Key code (0..255) or KEY_NONE (-1)
; CLOBBERS: EAX, EFLAGS
; -----------------------------------------------------------------------------
key_poll:
    save_regs

    ; Attempt non-blocking 1-byte read from standard input
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    jne .poll_no_key            ; 0 = no data, negative = error/interrupt

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

.poll_check_escape:
    ; Probe non-blockingly for follow-up escape sequence bytes
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    jne .poll_lone_esc          ; No subsequent bytes: user pressed lone Escape key

    ; Multi-byte escape sequence detected (e.g. arrow keys, function keys).
    ; Drain all remaining bytes of the burst so nothing leaks into next poll.
.poll_drain_esc_loop:
    syscall SYS_READ, FD_STDIN, in_buf, 1
    cmp eax, 1
    je .poll_drain_esc_loop

    mov eax, KEY_NONE           ; Discard multi-byte escape sequences
    jmp .poll_done

.poll_lone_esc:
    mov eax, KEY_ESC
    jmp .poll_done

.poll_no_key:
    mov eax, KEY_NONE

.poll_done:
    restore_regs
    ret

; -----------------------------------------------------------------------------
; key_wait: Blocking key reader with low-CPU sleep loop.
;
; Purpose:  Repeatedly calls key_poll. If no key is ready (KEY_NONE), sleeps for
;           50 milliseconds (50,000,000 ns) using sys_nanosleep before retrying.
;           Eliminates busy-waiting and keeps CPU usage near 0%.
; IN:       none
; OUT:      EAX = Key code (guaranteed valid key, never KEY_NONE)
; CLOBBERS: EAX, EFLAGS
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; read_line: Read a line of user input in cooked mode with editing and draining.
;
; Purpose:  Flushes pending output, activates cooked mode (local echo and backspace
;           editing), and shows the cursor. Reads up to ECX + 1 characters into
;           buffer EDI. If input ends with newline, the newline is stripped. If
;           input exceeds ECX characters, the string is truncated at ECX and any
;           remaining characters on that line are drained until newline is consumed.
;           Always NUL-terminates the stored string, hides cursor, returns terminal
;           to raw mode, and returns string length in EAX.
; IN:       EDI = Destination buffer (must have capacity >= ECX + 2 bytes)
;           ECX = Maximum allowed characters
; OUT:      EAX = Length of stored string (without NUL)
; CLOBBERS: EAX, EFLAGS
; -----------------------------------------------------------------------------
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
