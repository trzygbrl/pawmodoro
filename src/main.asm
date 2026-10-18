; =============================================================================
; Pawmodoro - Main Entry Point (src/main.asm)
;
; Purpose: Program entry point and initial hello-world proof of toolchain.
; Note:    This is the Task 0 (task-0-skeleton) hello-world implementation.
;          Per Task 0 specifications, placeholder modules are NOT %included here
;          yet to prevent assembling empty placeholder comments. Includes will
;          be introduced in subsequent tasks as modules are implemented.
; =============================================================================

; =============================================================================
; CONSTANTS
; (Defined locally for Task 0; will migrate to src/constants.inc in a later task)
; =============================================================================
SYS_EXIT        equ 1       ; Linux x86 sys_exit syscall number (EAX = 1)
SYS_WRITE       equ 4       ; Linux x86 sys_write syscall number (EAX = 4)
FD_STDOUT       equ 1       ; Standard output file descriptor (EBX = 1)
EXIT_SUCCESS    equ 0       ; Process exit code for successful termination (EBX = 0)
CHAR_LF         equ 10      ; ASCII newline (Line Feed) character byte

; =============================================================================
; DATA SECTION (.data)
; =============================================================================
section .data

    ; Boot message emitted by Task 0 to prove toolchain execution.
    ; "Pawmodoro boots!" (16 characters) + Line Feed (1 byte) = 17 bytes total.
    boot_msg:       db "Pawmodoro boots!", CHAR_LF
    boot_msg_len:   equ $ - boot_msg    ; Computed automatically by label arithmetic

; =============================================================================
; TEXT SECTION (.text)
; =============================================================================
section .text

    global _start

; -----------------------------------------------------------------------------
; _start: Program entry point.
;
; Purpose:  Program entry; print the boot message, then exit cleanly.
; IN:       none (the kernel sets up the process; the stack holds argc and argv,
;           which are ignored).
; OUT:      none. It never returns; the process exits with code 0.
; CLOBBERS: EAX, EBX, ECX, EDX (irrelevant after exit; stated for completeness).
; -----------------------------------------------------------------------------
_start:
    ; -------------------------------------------------------------------------
    ; Step 1: Write boot message to stdout via sys_write (Linux syscall 4)
    ; -------------------------------------------------------------------------
    mov eax, SYS_WRITE          ; Syscall number 4: sys_write
    mov ebx, FD_STDOUT          ; Argument 1 (EBX): Target file descriptor (stdout)
    mov ecx, boot_msg           ; Argument 2 (ECX): Pointer to message buffer in .data
    mov edx, boot_msg_len       ; Argument 3 (EDX): Byte count to write
    int 0x80                    ; Invoke Linux kernel interrupt for 32-bit syscall

    ; -------------------------------------------------------------------------
    ; Step 2: Terminate program cleanly via sys_exit (Linux syscall 1)
    ; -------------------------------------------------------------------------
    mov eax, SYS_EXIT           ; Syscall number 1: sys_exit
    mov ebx, EXIT_SUCCESS       ; Argument 1 (EBX): Return status code 0 (success)
    int 0x80                    ; Invoke Linux kernel interrupt to exit process

; =============================================================================
; STACK NOTE SECTION
; =============================================================================
; Explicitly mark stack memory as non-executable (noalloc, noexec, nowrite) to
; prevent GNU ld (binutils 2.39+) from issuing executable stack warnings.
section .note.GNU-stack noalloc noexec nowrite progbits
