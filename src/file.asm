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

;=============================================================================
; Procedure: file_load
; Purpose:   Opens file for reading (O_RDONLY). If open fails (negative return),
;            returns FILE_ERR (-1) immediately without calling close.
;            If open succeeds, reads up to ECX bytes into EDI.
;            Always closes the opened file descriptor via sys_close regardless
;            of read success or failure.
;            If read returns a negative value, returns FILE_ERR (-1).
;            Otherwise, returns the number of bytes read in EAX (0 for empty file).
; IN:        ESI = Pointer to NUL-terminated file path string
;            EDI = Destination buffer pointer
;            ECX = Maximum bytes to read
; OUT:       EAX = Bytes read (>= 0), or -1 (FILE_ERR) on error/missing file
; CLOBBERS:  EAX
;=============================================================================
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

;=============================================================================
; Procedure: file_write_common
; Purpose:   Opens file with flags in EDX and permissions mode FILE_MODE_0644.
;            If open fails (negative return), returns FILE_ERR (-1).
;            If open succeeds, writes ECX bytes from EDI via sys_write.
;            Always closes the descriptor via sys_close if open succeeded.
;            Verifies that bytes written equals requested length ECX.
;            If write failed or was short, returns FILE_ERR (-1).
;            Otherwise returns FILE_OK (0).
; IN:        ESI = Pointer to NUL-terminated file path string
;            EDI = Source buffer pointer
;            ECX = Length in bytes to write
;            EDX = sys_open flags (O_SAVE_FLAGS or O_APPEND_FLAGS)
; OUT:       EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on error
; CLOBBERS:  EAX
;=============================================================================
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

;=============================================================================
; Procedure: file_save
; Purpose:   Opens file with O_WRONLY | O_CREAT | O_TRUNC (O_SAVE_FLAGS = 0x241)
;            and mode FILE_MODE_0644 (420 dec). Writes ECX bytes, closes file.
;            Returns FILE_OK (0) on success, FILE_ERR (-1) on open/write failure.
; IN:        ESI = Pointer to NUL-terminated file path string
;            EDI = Source buffer pointer
;            ECX = Length in bytes to write
; OUT:       EAX = 0 on success, -1 on error (creates/truncates 0644)
; CLOBBERS:  EAX
;=============================================================================
file_save:
    save_regs
    mov edx, O_SAVE_FLAGS       ; O_WRONLY | O_CREAT | O_TRUNC (0x241)
    call file_write_common
    restore_regs
    ret

;=============================================================================
; Procedure: file_append
; Purpose:   Opens file with O_WRONLY | O_CREAT | O_APPEND (O_APPEND_FLAGS = 0x441)
;            and mode FILE_MODE_0644 (420 dec). Writes ECX bytes, closes file.
;            Returns FILE_OK (0) on success, FILE_ERR (-1) on open/write failure.
; IN:        ESI = Pointer to NUL-terminated file path string
;            EDI = Source buffer pointer
;            ECX = Length in bytes to write
; OUT:       EAX = 0 on success, -1 on error (appends 0644)
; CLOBBERS:  EAX
;=============================================================================
file_append:
    save_regs
    mov edx, O_APPEND_FLAGS     ; O_WRONLY | O_CREAT | O_APPEND (0x441)
    call file_write_common
    restore_regs
    ret

;=============================================================================
; Procedure: file_delete_range
; Purpose:   Safely removes the byte range [start, end) from the file at path ESI.
;            Copies pre-range and post-range chunks through the dedicated 2 KB
;            copy buffer (del_copy_buf) into temporary file journal.tmp, then
;            atomically renames journal.tmp over the original file (SYS_RENAME).
;            On any failure before a successful rename, closes descriptors,
;            unlinks journal.tmp (SYS_UNLINK), and leaves the original file
;            byte-identical.
; IN:        ESI = Pointer to NUL-terminated file path string,
;            EAX = Inclusive start byte offset (0-based),
;            EDX = Exclusive end byte offset (0-based)
; OUT:       EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on error
; CLOBBERS:  EAX
;=============================================================================
file_delete_range:
    push ebp
    mov ebp, esp
    sub esp, 32                 ; Local stack variables:
                                ; [ebp - 4]:  start_off
                                ; [ebp - 8]:  end_off
                                ; [ebp - 12]: file_size
                                ; [ebp - 16]: fd_in
                                ; [ebp - 20]: fd_out
                                ; [ebp - 24]: orig_path
                                ; [ebp - 28]: rem_bytes
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov [ebp - 4], eax          ; start_off
    mov [ebp - 8], edx          ; end_off
    mov [ebp - 24], esi         ; orig_path

    ; 1. Sanity check: reject negative offsets or start > end
    cmp eax, 0
    jl .del_err_param
    cmp edx, 0
    jl .del_err_param
    cmp eax, edx
    ja .del_err_param

    ; 2. Open original file read-only (sys_open)
    mov ebx, [ebp - 24]
    mov ecx, O_RDONLY
    xor edx, edx
    syscall SYS_OPEN, ebx, ecx, edx
    test eax, eax
    js .del_err_param           ; Open failed (file missing/unreadable)
    mov [ebp - 16], eax         ; fd_in

    ; 3. Query file size via sys_lseek(fd_in, 0, SEEK_END)
    mov ebx, [ebp - 16]
    xor ecx, ecx
    mov edx, SEEK_END
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .del_err_close_in
    mov [ebp - 12], eax         ; file_size

    ; 4. Validate offsets against actual file_size
    mov eax, [ebp - 4]          ; start_off
    cmp eax, [ebp - 12]
    ja .del_err_close_in
    mov edx, [ebp - 8]          ; end_off
    cmp edx, [ebp - 12]
    ja .del_err_close_in

    ; Check if start == end (empty range: no-op success)
    cmp eax, edx
    je .del_noop

    ; 5. Rewind fd_in to beginning of file (offset 0)
    mov ebx, [ebp - 16]
    xor ecx, ecx
    mov edx, SEEK_SET
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .del_err_close_in

    ; 6. Create/open temporary file: journal.tmp
    mov ebx, path_journal_tmp
    mov ecx, O_SAVE_FLAGS       ; O_WRONLY | O_CREAT | O_TRUNC (0x241)
    mov edx, FILE_MODE_0644     ; 0644 octal (420 dec)
    syscall SYS_OPEN, ebx, ecx, edx
    test eax, eax
    js .del_err_close_in        ; Create temp failed: do NOT unlink (e.g. dir exists)
    mov [ebp - 20], eax         ; fd_out

    ; 7. Phase 1: Copy bytes before start offset
    mov eax, [ebp - 4]          ; rem_bytes = start_off
    mov [ebp - 28], eax

.copy_pre_loop:
    mov eax, [ebp - 28]
    test eax, eax
    jz .copy_pre_done

    mov ecx, DEL_COPY_BUF_SIZE  ; 2048
    cmp eax, ecx
    jbe .copy_pre_chunk
    mov eax, ecx

.copy_pre_chunk:
    ; Read chunk from fd_in
    mov ebx, [ebp - 16]         ; fd_in
    mov ecx, del_copy_buf
    mov edx, eax                ; bytes to read
    syscall SYS_READ, ebx, ecx, edx
    test eax, eax
    jle .del_fail_cleanup       ; Read error or unexpected EOF

    ; Write chunk to fd_out
    push eax                    ; Preserve bytes read
    mov ebx, [ebp - 20]         ; fd_out
    mov ecx, del_copy_buf
    mov edx, eax                ; bytes to write
    syscall SYS_WRITE, ebx, ecx, edx
    pop ecx                     ; Restore expected byte count
    cmp eax, ecx
    jne .del_fail_cleanup       ; Write error or short write

    sub [ebp - 28], eax         ; rem_bytes -= bytes written
    jmp .copy_pre_loop

.copy_pre_done:
    ; 8. Phase 2: Seek fd_in past deleted range to end_off
    mov ebx, [ebp - 16]         ; fd_in
    mov ecx, [ebp - 8]          ; end_off
    mov edx, SEEK_SET
    syscall SYS_LSEEK, ebx, ecx, edx
    test eax, eax
    js .del_fail_cleanup

    ; 9. Phase 3: Copy bytes after end offset: rem_bytes = file_size - end_off
    mov eax, [ebp - 12]         ; file_size
    sub eax, [ebp - 8]          ; - end_off
    mov [ebp - 28], eax

.copy_post_loop:
    mov eax, [ebp - 28]
    test eax, eax
    jz .copy_post_done

    mov ecx, DEL_COPY_BUF_SIZE  ; 2048
    cmp eax, ecx
    jbe .copy_post_chunk
    mov eax, ecx

.copy_post_chunk:
    ; Read chunk from fd_in
    mov ebx, [ebp - 16]         ; fd_in
    mov ecx, del_copy_buf
    mov edx, eax
    syscall SYS_READ, ebx, ecx, edx
    test eax, eax
    jle .del_fail_cleanup

    ; Write chunk to fd_out
    push eax
    mov ebx, [ebp - 20]         ; fd_out
    mov ecx, del_copy_buf
    mov edx, eax
    syscall SYS_WRITE, ebx, ecx, edx
    pop ecx
    cmp eax, ecx
    jne .del_fail_cleanup

    sub [ebp - 28], eax
    jmp .copy_post_loop

.copy_post_done:
    ; 10. Close both file descriptors unconditionally
    mov ebx, [ebp - 20]         ; fd_out
    syscall SYS_CLOSE, ebx
    mov ebx, [ebp - 16]         ; fd_in
    syscall SYS_CLOSE, ebx

    ; 11. Atomic rename: rename(path_journal_tmp, orig_path)
    mov ebx, path_journal_tmp   ; oldpath
    mov ecx, [ebp - 24]         ; newpath
    syscall SYS_RENAME, ebx, ecx
    test eax, eax
    jnz .del_rename_failed

    ; Success: return 0
    xor eax, eax
    jmp .del_return

.del_rename_failed:
    ; Unlink temp file on rename failure
    mov ebx, path_journal_tmp
    syscall SYS_UNLINK, ebx
    mov eax, FILE_ERR
    jmp .del_return

.del_fail_cleanup:
    ; Close descriptors and unlink temp file
    mov ebx, [ebp - 20]
    syscall SYS_CLOSE, ebx
    mov ebx, [ebp - 16]
    syscall SYS_CLOSE, ebx
    mov ebx, path_journal_tmp
    syscall SYS_UNLINK, ebx
    mov eax, FILE_ERR
    jmp .del_return

.del_noop:
    mov ebx, [ebp - 16]
    syscall SYS_CLOSE, ebx
    xor eax, eax                ; Success (no-op)
    jmp .del_return

.del_err_close_in:
    mov ebx, [ebp - 16]
    syscall SYS_CLOSE, ebx

.del_err_param:
    mov eax, FILE_ERR

.del_return:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    mov esp, ebp
    pop ebp
    ret
