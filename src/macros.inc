; =============================================================================
; Pawmodoro - Assembly Helper Macros (src/macros.inc)
;
; Purpose: Reusable macros for Linux system call dispatch and register
;          preservation adhering to the calling conventions in PRD §6.2.
; =============================================================================

; -----------------------------------------------------------------------------
; syscall: Linux 32-bit system call dispatch macro.
;
; Purpose:  Sets up system call arguments and executes 'int 0x80'.
; Syntax:   syscall <num> [, <arg1_ebx> [, <arg2_ecx> [, <arg3_edx>]]]
;
; IN:       %1 = Syscall number (placed in EAX)
;           %2 = (Optional) First argument (placed in EBX)
;           %3 = (Optional) Second argument (placed in ECX)
;           %4 = (Optional) Third argument (placed in EDX)
; OUT:      EAX = Syscall return value (kernel convention)
; CLOBBERS: EAX, and any argument registers provided (%2 -> EBX, %3 -> ECX, %4 -> EDX).
; -----------------------------------------------------------------------------
%macro syscall 1-4
    mov eax, %1
    %if %0 >= 2
        mov ebx, %2
    %endif
    %if %0 >= 3
        mov ecx, %3
    %endif
    %if %0 >= 4
        mov edx, %4
    %endif
    int 0x80
%endmacro

; -----------------------------------------------------------------------------
; save_regs: Push non-volatile scratch registers to the stack.
;
; Purpose:  Preserves EBX, ECX, EDX, ESI, EDI across a procedure call.
;           NOTE: EAX is deliberately NOT pushed so procedures can return a
;           computed value in EAX per PRD §6.2 rule 1.
;           PUSHA is deliberately NOT used because its counterpart POPA would
;           blindly overwrite EAX on procedure exit, destroying return values.
; CLOBBERS: none (ESP modified by pushes)
; -----------------------------------------------------------------------------
%macro save_regs 0
    push ebx
    push ecx
    push edx
    push esi
    push edi
%endmacro

; -----------------------------------------------------------------------------
; restore_regs: Pop registers saved by save_regs in reverse order.
;
; Purpose:  Restores EDI, ESI, EDX, ECX, EBX exactly as preserved.
;           NOTE: EAX remains untouched to preserve return values.
; CLOBBERS: none (ESP modified by pops)
; -----------------------------------------------------------------------------
%macro restore_regs 0
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
%endmacro
