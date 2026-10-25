; =============================================================================
; Pawmodoro - Terminal I/O & String Utilities (src/io.asm)
;
; Purpose: Output buffer aggregation, number-to-string formatting, terminal
;          cursor movement, single-write flushing, and string routines.
; Reference: PRD §4.1 FR-U4, §6.2, §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: buf_char
; Purpose:   Stores byte AL into out_buf at index out_len, advancing out_len.
;            Overflow Protection: If out_len has reached OUT_BUF_SIZE, the byte
;            is silently discarded to prevent buffer overrun and memory corruption.
; IN:        AL = ASCII byte / character to append
; OUT:       None (appends byte to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_char:
    push ecx
    mov ecx, [out_len]
    cmp ecx, OUT_BUF_SIZE
    jae .overflow_drop          ; Silently drop byte if buffer is at capacity

    mov [out_buf + ecx], al     ; Store character at current write offset
    inc ecx
    mov [out_len], ecx          ; Update length tracker

.overflow_drop:
    pop ecx
    ret

;=============================================================================
; Procedure: buf_str
; Purpose:   Iterates over the string at ESI and appends each character to out_buf
;            via buf_char until CHAR_NULL (0) is reached. The NUL byte is not appended.
; IN:        ESI = Pointer to NUL-terminated source string
; OUT:       None (appends string to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_str:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax

.str_loop:
    mov al, [esi]
    cmp al, CHAR_NULL
    je .str_done
    call buf_char               ; Append character to buffer
    inc esi                     ; Advance string pointer
    jmp .str_loop

.str_done:
    pop eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: buf_u32
; Purpose:   Converts unsigned 32-bit integer in EAX into ASCII decimal digits
;            using repeated unsigned DIV by 10 (DECIMAL_BASE). Digits are collected
;            in reverse on the stack and then appended in MSB-to-LSB order.
;            Zero (0) outputs a single "0". Supports full range 0..4294967295.
; IN:        EAX = 32-bit unsigned integer to append
; OUT:       None (appends decimal string to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_u32:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax                    ; Save input value to preserve EAX

    test eax, eax
    jnz .u32_nonzero

    ; Value is zero: emit single '0'
    mov al, CHAR_ZERO
    call buf_char
    jmp .u32_done

.u32_nonzero:
    xor ecx, ecx                ; Digit counter = 0
    mov ebx, DECIMAL_BASE       ; Radix 10 divisor

.u32_div_loop:
    xor edx, edx                ; Zero EDX before unsigned 32-bit DIV (never use CDQ)
    div ebx                     ; EAX = quotient, EDX = remainder (0..9)
    add dl, CHAR_ZERO           ; Convert remainder to ASCII digit
    push edx                    ; Save digit on stack
    inc ecx                     ; Increment digit count
    test eax, eax
    jnz .u32_div_loop

.u32_emit_loop:
    pop edx                     ; Retrieve digits in left-to-right order
    mov al, dl
    call buf_char
    dec ecx
    jnz .u32_emit_loop

.u32_done:
    pop eax                     ; Restore original EAX
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: buf_u32_2
; Purpose:   Formats value in EAX as exactly two decimal digits with a leading
;            zero if < 10. Values above 99 are clamped to 99 to prevent corruption.
; IN:        EAX = Unsigned integer (0..99)
; OUT:       None (appends 2 digits zero-padded [%02u] to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_u32_2:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax

    cmp eax, MAX_U32_2_CLAMP
    jbe .u32_2_valid
    mov eax, MAX_U32_2_CLAMP    ; Clamp out-of-range values to 99

.u32_2_valid:
    xor edx, edx
    mov ebx, DECIMAL_BASE
    div ebx                     ; EAX = tens digit, EDX = units digit

    add al, CHAR_ZERO           ; Format tens digit
    call buf_char

    mov al, dl
    add al, CHAR_ZERO           ; Format units digit
    call buf_char

    pop eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: buf_mmss
; Purpose:   Divides total seconds in EAX by 60 into minutes and seconds.
;            Both minutes and seconds are formatted as 2-digit zero-padded numbers
;            separated by a colon (':'). Minutes are clamped to 99 (maximum 99:59).
; IN:        EAX = Time in seconds (unsigned)
; OUT:       None (appends formatted MM:SS string to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_mmss:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax

    xor edx, edx
    mov ebx, SECONDS_PER_MINUTE
    div ebx                     ; EAX = minutes, EDX = seconds remainder (0..59)

    cmp eax, MAX_MM_CLAMP
    jbe .mmss_mins_ok
    mov eax, MAX_MM_CLAMP       ; Clamp minutes to 99
    mov edx, SECS_MAX_CLAMP     ; Clamp seconds to 59

.mmss_mins_ok:
    push edx                    ; Save seconds remainder

    ; Emit 2-digit minutes
    call buf_u32_2

    ; Emit colon separator
    mov al, CHAR_COLON
    call buf_char

    ; Emit 2-digit seconds
    pop eax                     ; Restore seconds remainder (0..59)
    call buf_u32_2

    pop eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: buf_repeat
; Purpose:   Appends the byte in AL to the output buffer ECX times.
;            If ECX is 0, nothing is appended.
; IN:        AL = ASCII character byte to repeat, ECX = Repetition count
; OUT:       None (appends character repeated ECX times to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_repeat:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax

    test ecx, ecx
    jz .repeat_done

    mov dl, al                  ; Preserve character in DL across loop

.repeat_loop:
    mov al, dl
    call buf_char
    dec ecx
    jnz .repeat_loop

.repeat_done:
    pop eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: buf_goto
; Purpose:   Formats row (EAX) and column (EBX) into an ANSI cursor position
;            escape sequence (ESC[<row>;<col>H) and appends it to out_buf. Coordinates are 1-based.
; IN:        EAX = Row coordinate (1-based), EBX = Column coordinate (1-based)
; OUT:       None (appends ANSI cursor sequence ESC[r;cH to out_buf)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_goto:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax

    push ebx                    ; Save column
    push eax                    ; Save row

    ; Emit ESC [
    mov al, CHAR_ESC
    call buf_char
    mov al, CHAR_LBRACKET
    call buf_char

    ; Emit row
    pop eax                     ; Restore row
    call buf_u32

    ; Emit ;
    mov al, CHAR_SEMICOLON
    call buf_char

    ; Emit col
    pop eax                     ; Restore col
    call buf_u32

    ; Emit H
    mov al, CHAR_UPPER_H
    call buf_char

    pop eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: buf_flush
; Purpose:   Flushes out_buf[0..out_len) to file descriptor 1 (STDOUT) in a
;            single sys_write call. If out_len is 0, returns immediately.
;            Handles partial writes by looping and retries on -ERR_EINTR.
;            Unconditionally resets out_len to 0 upon completion.
; IN:        None
; OUT:       None (single sys_write flushes out_buf, resets out_len index)
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_flush:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push eax

    mov edx, [out_len]
    test edx, edx
    jz .flush_done              ; Zero bytes buffered: do not perform syscall

    mov esi, out_buf            ; ESI = current buffer pointer
    mov edi, edx                ; EDI = remaining bytes to write

.flush_write_loop:
    ; syscall SYS_WRITE: EAX = 4, EBX = FD_STDOUT (1), ECX = ESI, EDX = EDI
    mov eax, SYS_WRITE
    mov ebx, FD_STDOUT
    mov ecx, esi
    mov edx, edi
    int 0x80

    ; Check result in EAX
    cmp eax, edi
    je .flush_done              ; Exactly all remaining bytes written (common path: 1 write!)

    test eax, eax
    jg .flush_short_write       ; Greater than 0: short write, advance and continue

    ; Return value <= 0
    cmp eax, -ERR_EINTR         ; Interrupted by signal: retry write
    je .flush_write_loop

    ; Negative error: check recursion guard [app_exiting]
    cmp dword [app_exiting], 1
    je .flush_done              ; In the middle of app_exit: discard buffer and return

    ; Fatal write error outside of app_exit
    mov dword [out_len], 0
    mov ebx, EXIT_FAILURE
    call app_exit

.flush_short_write:
    add esi, eax                ; Advance buffer pointer by bytes written
    sub edi, eax                ; Decrement remaining byte count
    test edi, edi
    jnz .flush_write_loop       ; Write remainder if bytes still pending

.flush_done:
    ; Unconditionally reset buffer index to prevent replaying data
    mov dword [out_len], 0

    pop eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: str_len
; Purpose:   Counts the number of bytes in string ESI up to, but not including,
;            the terminating CHAR_NULL byte.
; IN:        ESI = Pointer to NUL-terminated string
; OUT:       EAX = Length in bytes (excluding terminating NUL)
; CLOBBERS:  EAX
;=============================================================================
str_len:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    xor eax, eax                ; Initialize length counter to 0

.len_loop:
    cmp byte [esi], CHAR_NULL
    je .len_done
    inc esi
    inc eax
    jmp .len_loop

.len_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: str_copy
; Purpose:   Copies bytes from source ESI to destination EDI until CHAR_NULL
;            is copied. Returns the length of the string (excluding NUL) in EAX.
; IN:        ESI = Pointer to source string, EDI = Pointer to destination buffer
; OUT:       EAX = Bytes copied (excluding terminating NUL)
; CLOBBERS:  EAX
;=============================================================================
str_copy:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    xor eax, eax                ; Initialize copied byte counter to 0

.copy_loop:
    mov bl, [esi]
    mov [edi], bl               ; Copy byte including NUL
    cmp bl, CHAR_NULL
    je .copy_done
    inc esi
    inc edi
    inc eax
    jmp .copy_loop

.copy_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

;=============================================================================
; Procedure: utf8_char_len
; Purpose:   Inspects the UTF-8 sequence at ESI. Determines its byte length
;            and validates whether it is a well-formed printable UTF-8 glyph or
;            printable ASCII character. Control bytes (< 0x20, 0x7F, ESC),
;            invalid UTF-8 lead bytes, and incomplete/truncated continuation
;            sequences are flagged as invalid (CF = 1).
;            Note: Counting non-continuation bytes is a practical approximation
;            for the approved single-column glyph set, not a full Unicode width table.
; IN:        ESI = Pointer to character in memory
; OUT:       EAX = Byte length (0 if NUL, 1..4 if character/byte),
;            CF  = 0 if valid printable character, 1 if invalid/control/NUL
; CLOBBERS:  EAX
;=============================================================================
utf8_char_len:
    push ecx

    movzx eax, byte [esi]
    test al, al
    jz .utf8_nul                ; NUL terminator: length 0, CF=1

    ; Check ASCII (< 0x80)
    cmp al, 0x80
    jae .utf8_multibyte

    ; ASCII: length is 1 byte
    cmp al, CHAR_SPACE
    jb .utf8_invalid_byte       ; Control byte < 0x20
    cmp al, 127
    je .utf8_invalid_byte       ; DEL (0x7F)
    mov eax, 1
    clc                         ; CF = 0 (valid)
    pop ecx
    ret

.utf8_invalid_byte:
    mov eax, 1
    stc                         ; CF = 1 (invalid)
    pop ecx
    ret

.utf8_multibyte:
    ; Check 2-byte sequence: lead 0xC2..0xDF
    cmp al, 0xC2
    jb .utf8_invalid_byte       ; 0x80..0xC1 are invalid lead bytes
    cmp al, 0xDF
    jbe .utf8_check_2byte

    ; Check 3-byte sequence: lead 0xE0..0xEF
    cmp al, 0xEF
    jbe .utf8_check_3byte

    ; Check 4-byte sequence: lead 0xF0..0xF4
    cmp al, 0xF4
    jbe .utf8_check_4byte

    jmp .utf8_invalid_byte

.utf8_check_2byte:
    ; Expect 1 continuation byte at [esi + 1]
    mov cl, [esi + 1]
    and cl, 0xC0
    cmp cl, 0x80
    jne .utf8_invalid_byte      ; Missing / invalid continuation byte
    mov eax, 2
    clc
    pop ecx
    ret

.utf8_check_3byte:
    ; Expect 2 continuation bytes at [esi + 1], [esi + 2]
    mov cl, [esi + 1]
    and cl, 0xC0
    cmp cl, 0x80
    jne .utf8_invalid_byte
    mov cl, [esi + 2]
    and cl, 0xC0
    cmp cl, 0x80
    jne .utf8_invalid_byte
    mov eax, 3
    clc
    pop ecx
    ret

.utf8_check_4byte:
    ; Expect 3 continuation bytes at [esi + 1], [esi + 2], [esi + 3]
    mov cl, [esi + 1]
    and cl, 0xC0
    cmp cl, 0x80
    jne .utf8_invalid_byte
    mov cl, [esi + 2]
    and cl, 0xC0
    cmp cl, 0x80
    jne .utf8_invalid_byte
    mov cl, [esi + 3]
    and cl, 0xC0
    cmp cl, 0x80
    jne .utf8_invalid_byte
    mov eax, 4
    clc
    pop ecx
    ret

.utf8_nul:
    xor eax, eax
    stc                         ; CF = 1
    pop ecx
    ret

;=============================================================================
; Procedure: buf_str_clip
; Purpose:   Appends at most ECX display columns of NUL-terminated string ESI
;            to out_buf. Counts display columns (not bytes) by identifying UTF-8
;            sequences. Copies complete multibyte characters without splitting.
;            If string length exceeds ECX columns, appends clipping marker '~'
;            (UI_CLIP_MARKER) within the ECX column budget. If ECX is 0, emits
;            nothing. Sanitizes control characters (< 0x20, 0x7F, ESC) and
;            malformed UTF-8 sequences to '?' (CHAR_QUESTION).
; IN:        ESI = Pointer to NUL-terminated source string,
;            ECX = Maximum display columns allowed
; OUT:       Appends clipped string and optional marker to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
buf_str_clip:
    save_regs
    push eax
    sub esp, 16                 ; [esp] = max_cols, [esp+4] = budget, [esp+8] = needs_clip, [esp+12] = orig_esi

    mov [esp], ecx              ; Store max_cols
    mov [esp + 12], esi         ; Store original ESI
    mov dword [esp + 8], 0      ; needs_clip = 0

    ; If max_cols == 0, emit nothing
    test ecx, ecx
    jz .str_clip_done

    ; Pass 1: Measure total display columns of source string
    xor edx, edx                ; EDX = total display columns
    mov ebx, esi                ; EBX = scan pointer
.pass1_loop:
    cmp byte [ebx], CHAR_NULL
    je .pass1_done
    mov esi, ebx
    call utf8_char_len          ; EAX = byte length (1..4)
    test eax, eax
    jz .pass1_done
    add ebx, eax                ; Advance scan pointer by byte length
    inc edx                     ; 1 display column
    jmp .pass1_loop

.pass1_done:
    ; Compare total_cols (EDX) with max_cols ([esp])
    cmp edx, [esp]
    jbe .no_clip_needed

    ; Clipping required: needs_clip = 1
    mov dword [esp + 8], 1
    ; budget = max_cols - 1 (reserve 1 column for marker)
    mov eax, [esp]
    dec eax
    mov [esp + 4], eax
    jmp .pass2_init

.no_clip_needed:
    ; Fits completely: budget = max_cols
    mov eax, [esp]
    mov [esp + 4], eax

.pass2_init:
    ; Pass 2: Emit characters up to budget display columns
    mov esi, [esp + 12]         ; Restore ESI to start of string
    xor edx, edx                ; EDX = emitted column count

.pass2_loop:
    cmp edx, [esp + 4]          ; Check if reached column budget
    jae .pass2_done
    cmp byte [esi], CHAR_NULL
    je .pass2_done

    call utf8_char_len          ; EAX = byte length, CF = 1 if invalid
    test eax, eax
    jz .pass2_done

    jc .emit_sanitized

    ; Valid character: emit EAX bytes
    push ecx
    mov ecx, eax
.emit_bytes_loop:
    mov al, [esi]
    cmp byte [setting_charset], 1
    jne .emit_byte_raw
    cmp al, 128
    jb .emit_byte_raw
    mov al, CHAR_QUESTION
.emit_byte_raw:
    call buf_char
    inc esi
    dec ecx
    jnz .emit_bytes_loop
    pop ecx
    inc edx                     ; Column count++
    jmp .pass2_loop

.emit_sanitized:
    add esi, eax                ; Advance by byte length (1)
    mov al, CHAR_QUESTION       ; '?'
    call buf_char
    inc edx                     ; Column count++
    jmp .pass2_loop

.pass2_done:
    ; Emit clipping marker '~' if clipping was required
    cmp dword [esp + 8], 1
    jne .str_clip_done
    cmp dword [esp], 0
    jbe .str_clip_done
    mov al, UI_CLIP_MARKER      ; '~'
    call buf_char

.str_clip_done:
    add esp, 16
    pop eax
    restore_regs
    ret
