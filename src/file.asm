; =============================================================================
; Pawmodoro - File Persistence Engine (src/file.asm)
;
; Purpose: Raw Linux x86 system call routines for file persistence:
;          file_load (read), file_save (truncate/create), and file_append (append).
; Reference: PRD §3.1 (Syscall table, open flags, mode 0644), §4.5, §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

; -----------------------------------------------------------------------------
; file_load: Read up to ECX bytes from file at path ESI into buffer EDI.
;
; Purpose:  Opens file for reading (O_RDONLY). If open fails (negative return),
;           returns FILE_ERR (-1) immediately without calling close.
;           If open succeeds, reads up to ECX bytes into EDI.
;           Always closes the opened file descriptor via sys_close regardless
;           of read success or failure.
;           If read returns a negative value, returns FILE_ERR (-1).
;           Otherwise, returns the number of bytes read in EAX (0 for empty file).
; IN:       ESI = Pointer to NUL-terminated file path string
;           EDI = Destination buffer pointer
;           ECX = Maximum bytes to read
; OUT:      EAX = Bytes read (>= 0), or FILE_ERR (-1) on error/missing file
; CLOBBERS: EAX, EFLAGS only (all other registers preserved)
; -----------------------------------------------------------------------------
file_load:
    save_regs

    ; Preserve destination buffer and max bytes across open syscall
    push ecx                    ; [esp + 4] = max bytes to read
    push edi                    ; [esp]     = destination buffer pointer

    ; 1. Open file for reading (sys_open)
    ; sys_open(path = ESI, flags = O_RDONLY, mode = 0)
    mov ebx, esi                ; EBX = path
    mov ecx, O_RDONLY           ; ECX = flags
    xor edx, edx                ; EDX = mode 0
    syscall SYS_OPEN, ebx, ecx, edx
    test eax, eax
    js .load_open_err           ; Negative return indicates file missing or open error

    ; Open succeeded: EAX contains file descriptor (fd)
    mov ebx, eax                ; EBX = fd
    pop edi                     ; Restore destination buffer pointer
    pop ecx                     ; Restore max bytes to read
    push ebx                    ; [esp] = saved fd for close syscall

    ; 2. Read from file into buffer (sys_read)
    ; sys_read(fd = EBX, buf = EDI, count = ECX)
    mov edx, ecx                ; EDX = count (max bytes)
    mov ecx, edi                ; ECX = buffer pointer
    syscall SYS_READ, ebx, ecx, edx
    mov esi, eax                ; Preserve read result (bytes read or negative error)

    ; 3. Close file descriptor (sys_close)
    ; sys_close(fd = [esp])
    pop ebx                     ; Restore fd from stack
    syscall SYS_CLOSE, ebx

    ; 4. Check read result in ESI
    test esi, esi
    js .load_read_err           ; Negative return indicates read error

    ; Read succeeded: EAX = bytes read (0 for empty file, > 0 for data)
    mov eax, esi
    jmp .load_done

.load_read_err:
    mov eax, FILE_ERR           ; Return -1 on read failure
    jmp .load_done

.load_open_err:
    add esp, 8                  ; Clean up pushed ecx and edi
    mov eax, FILE_ERR           ; Return -1 on open failure

.load_done:
    restore_regs
    ret

; -----------------------------------------------------------------------------
; file_write_common: Internal helper for file_save and file_append.
;
; Purpose:  Opens file with flags in EDX and permissions mode FILE_MODE_0644.
;           If open fails (negative return), returns FILE_ERR (-1).
;           If open succeeds, writes ECX bytes from EDI via sys_write.
;           Always closes the descriptor via sys_close if open succeeded.
;           Verifies that bytes written equals requested length ECX.
;           If write failed or was short, returns FILE_ERR (-1).
;           Otherwise returns FILE_OK (0).
; IN:       ESI = Pointer to NUL-terminated file path string
;           EDI = Source buffer pointer
;           ECX = Length in bytes to write
;           EDX = sys_open flags (O_SAVE_FLAGS or O_APPEND_FLAGS)
; OUT:      EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on error
; CLOBBERS: EAX, EFLAGS (all caller registers preserved by caller wrappers)
; -----------------------------------------------------------------------------
file_write_common:
    push ecx                    ; [esp + 4] = length in bytes
    push edi                    ; [esp]     = source buffer pointer

    ; 1. Open / create file (sys_open)
    ; sys_open(path = ESI, flags = EDX, mode = FILE_MODE_0644)
    mov ebx, esi                ; EBX = path
    mov ecx, edx                ; ECX = flags
    mov edx, FILE_MODE_0644     ; EDX = mode 0644 (420 dec)
    syscall SYS_OPEN, ebx, ecx, edx
    test eax, eax
    js .write_open_err          ; Negative return indicates open/create error

    ; Open succeeded: EAX contains file descriptor (fd)
    mov ebx, eax                ; EBX = fd
    pop edi                     ; Restore source buffer pointer
    pop ecx                     ; Restore length in bytes
    push ecx                    ; [esp + 4] = expected byte count
    push ebx                    ; [esp]     = saved fd for close syscall

    ; 2. Write buffer contents to file (sys_write)
    ; sys_write(fd = EBX, buf = EDI, count = ECX)
    mov edx, ecx                ; EDX = count (length in bytes)
    mov ecx, edi                ; ECX = buffer pointer
    syscall SYS_WRITE, ebx, ecx, edx
    mov esi, eax                ; Preserve write result (bytes written or negative error)

    ; 3. Close file descriptor (sys_close)
    ; sys_close(fd = [esp])
    pop ebx                     ; Restore fd from stack
    syscall SYS_CLOSE, ebx

    ; 4. Verify write result: must equal expected length ([esp])
    pop ecx                     ; Restore expected byte count
    cmp esi, ecx
    jne .write_err              ; Negative return or short write: treat as error!

    mov eax, FILE_OK            ; 0 = Success
    ret

.write_err:
    mov eax, FILE_ERR           ; -1 = Error
    ret

.write_open_err:
    add esp, 8                  ; Clean up pushed ecx and edi
    mov eax, FILE_ERR           ; -1 = Error
    ret

; -----------------------------------------------------------------------------
; file_save: Write ECX bytes from EDI to file ESI, truncating/creating as mode 0644.
;
; Purpose:  Opens file with O_WRONLY | O_CREAT | O_TRUNC (O_SAVE_FLAGS = 0x241)
;           and mode FILE_MODE_0644 (420 dec). Writes ECX bytes, closes file.
;           Returns FILE_OK (0) on success, FILE_ERR (-1) on open/write failure.
; IN:       ESI = Pointer to NUL-terminated file path string
;           EDI = Source buffer pointer
;           ECX = Length in bytes to write
; OUT:      EAX = 0 on success, -1 on error
; CLOBBERS: EAX, EFLAGS only (all other registers preserved)
; -----------------------------------------------------------------------------
file_save:
    save_regs
    mov edx, O_SAVE_FLAGS       ; O_WRONLY | O_CREAT | O_TRUNC (0x241)
    call file_write_common
    restore_regs
    ret

; -----------------------------------------------------------------------------
; file_append: Append ECX bytes from EDI to file ESI, creating as mode 0644 if missing.
;
; Purpose:  Opens file with O_WRONLY | O_CREAT | O_APPEND (O_APPEND_FLAGS = 0x441)
;           and mode FILE_MODE_0644 (420 dec). Writes ECX bytes, closes file.
;           Returns FILE_OK (0) on success, FILE_ERR (-1) on open/write failure.
; IN:       ESI = Pointer to NUL-terminated file path string
;           EDI = Source buffer pointer
;           ECX = Length in bytes to write
; OUT:      EAX = 0 on success, -1 on error
; CLOBBERS: EAX, EFLAGS only (all other registers preserved)
; -----------------------------------------------------------------------------
file_append:
    save_regs
    mov edx, O_APPEND_FLAGS     ; O_WRONLY | O_CREAT | O_APPEND (0x441)
    call file_write_common
    restore_regs
    ret
