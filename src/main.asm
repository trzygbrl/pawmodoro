; =============================================================================
; Pawmodoro - Main Entry Point (src/main.asm)
;
; Purpose: Top-level entry point and Task 1 foundation verification demo.
; Note:    This is the Task 1 (task-1-foundation) temporary demo. It constructs
;          a complete visual frame (coloured ASCII box + self-test suite) in
;          memory using the output buffer and flushes it in a single sys_write.
; =============================================================================

; -----------------------------------------------------------------------------
; Modular Includes (PRD §6.1)
; Note: Paths are relative to repo root (working directory of make).
; -----------------------------------------------------------------------------
%include "src/constants.inc"
%include "src/macros.inc"
%include "src/data.asm"

; =============================================================================
; DEMO DATA & BSS ASSETS (Specific to Task 1 Demo)
; =============================================================================
section .data
    demo_title:         db "Pawmodoro Foundation Demo", CHAR_NULL
    demo_num_label:     db "Number: ", CHAR_NULL
    demo_time_label:    db "Time: ", CHAR_NULL
    demo_str_test:      db "Pawmodoro Assembly", CHAR_NULL

    str_u32_label:      db "[buf_u32]    0, 9, 10, 99, 100, 4294967295 -> ", CHAR_NULL
    str_sep:            db ", ", CHAR_NULL
    str_u32_2_label:    db "[buf_u32_2]  7, 42 -> ", CHAR_NULL
    str_mmss_label:     db "[buf_mmss]   0s, 247s, 1500s -> ", CHAR_NULL
    str_len_label:      db "[str_len]    len('Pawmodoro Assembly') -> ", CHAR_NULL
    str_copy_label:     db "[str_copy]   copied -> '", CHAR_NULL
    str_quote:          db "'", CHAR_NULL

section .bss
    demo_copy_buf:      resb 64

; =============================================================================
; TEXT SECTION (.text)
; =============================================================================
section .text

%include "src/io.asm"

    global _start

; -----------------------------------------------------------------------------
; _start: Program entry point for Task 1 Foundation Demo.
;
; Purpose:  Builds a complete terminal frame in out_buf containing a styled
;           ASCII box (with 12345 and 04:07) and self-test verification lines,
;           then outputs the entire frame in a single sys_write via buf_flush.
; IN:       none
; OUT:      none (process exits with status 0)
; CLOBBERS: EAX, EBX, ECX, EDX, ESI, EDI (irrelevant after process exit)
; -----------------------------------------------------------------------------
_start:
    ; -------------------------------------------------------------------------
    ; Frame Step 1: Clear screen and reset cursor position
    ; -------------------------------------------------------------------------
    mov esi, ansi_clear
    call buf_str
    mov esi, ansi_home
    call buf_str

    ; -------------------------------------------------------------------------
    ; Frame Step 2: Draw Coloured ASCII Box (Rows 2..5, Cols 4..47)
    ; -------------------------------------------------------------------------
    ; Box Top Border (Row 2, Col 4)
    mov eax, 2
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov al, CHAR_PLUS
    call buf_char
    mov al, CHAR_MINUS
    mov ecx, 42
    call buf_repeat
    mov al, CHAR_PLUS
    call buf_char
    mov al, CHAR_LF
    call buf_char

    ; Box Row 3: Title
    mov eax, 3
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov al, CHAR_PIPE
    call buf_char
    mov al, CHAR_SPACE
    mov ecx, 8
    call buf_repeat
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov esi, ansi_bold
    call buf_str
    mov esi, demo_title
    call buf_str
    mov esi, ansi_reset
    call buf_str
    mov esi, ansi_fg_cyan
    call buf_str
    mov al, CHAR_SPACE
    mov ecx, 9
    call buf_repeat
    mov al, CHAR_PIPE
    call buf_char
    mov al, CHAR_LF
    call buf_char

    ; Box Row 4: Values (Number: 12345, Time: 04:07)
    mov eax, 4
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov al, CHAR_PIPE
    call buf_char
    mov al, CHAR_SPACE
    mov ecx, 4
    call buf_repeat

    ; "Number: 12345"
    mov esi, ansi_fg_white
    call buf_str
    mov esi, demo_num_label
    call buf_str
    mov esi, ansi_fg_bright_green
    call buf_str
    mov eax, 12345
    call buf_u32

    mov al, CHAR_SPACE
    mov ecx, 6
    call buf_repeat

    ; "Time: 04:07"
    mov esi, ansi_fg_white
    call buf_str
    mov esi, demo_time_label
    call buf_str
    mov esi, ansi_fg_bright_green
    call buf_str
    mov eax, 247                ; 247 seconds = 04:07
    call buf_mmss

    mov esi, ansi_reset
    call buf_str
    mov esi, ansi_fg_cyan
    call buf_str
    mov al, CHAR_SPACE
    mov ecx, 7
    call buf_repeat
    mov al, CHAR_PIPE
    call buf_char
    mov al, CHAR_LF
    call buf_char

    ; Box Bottom Border (Row 5, Col 4)
    mov eax, 5
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov al, CHAR_PLUS
    call buf_char
    mov al, CHAR_MINUS
    mov ecx, 42
    call buf_repeat
    mov al, CHAR_PLUS
    call buf_char
    mov al, CHAR_LF
    call buf_char

    ; -------------------------------------------------------------------------
    ; Frame Step 3: Self-Test Verification Block Below Box
    ; -------------------------------------------------------------------------
    ; Test 1: buf_u32 (Row 7, Col 4)
    mov eax, 7
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, str_u32_label
    call buf_str
    mov esi, ansi_fg_white
    call buf_str

    mov eax, 0
    call buf_u32
    mov esi, str_sep
    call buf_str

    mov eax, 9
    call buf_u32
    mov esi, str_sep
    call buf_str

    mov eax, 10
    call buf_u32
    mov esi, str_sep
    call buf_str

    mov eax, 99
    call buf_u32
    mov esi, str_sep
    call buf_str

    mov eax, 100
    call buf_u32
    mov esi, str_sep
    call buf_str

    mov eax, 4294967295         ; Maximum 32-bit unsigned integer (0xFFFFFFFF)
    call buf_u32
    mov al, CHAR_LF
    call buf_char

    ; Test 2: buf_u32_2 (Row 9, Col 4)
    mov eax, 9
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, str_u32_2_label
    call buf_str
    mov esi, ansi_fg_white
    call buf_str

    mov eax, 7
    call buf_u32_2
    mov esi, str_sep
    call buf_str

    mov eax, 42
    call buf_u32_2
    mov al, CHAR_LF
    call buf_char

    ; Test 3: buf_mmss (Row 11, Col 4)
    mov eax, 11
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, str_mmss_label
    call buf_str
    mov esi, ansi_fg_white
    call buf_str

    mov eax, 0                  ; 00:00
    call buf_mmss
    mov esi, str_sep
    call buf_str

    mov eax, 247                ; 04:07
    call buf_mmss
    mov esi, str_sep
    call buf_str

    mov eax, 1500               ; 25:00
    call buf_mmss
    mov al, CHAR_LF
    call buf_char

    ; Test 4: str_len (Row 13, Col 4)
    mov eax, 13
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, str_len_label
    call buf_str
    mov esi, ansi_fg_white
    call buf_str

    mov esi, demo_str_test
    call str_len
    call buf_u32
    mov al, CHAR_LF
    call buf_char

    ; Test 5: str_copy (Row 15, Col 4)
    mov eax, 15
    mov ebx, 4
    call buf_goto
    mov esi, ansi_fg_bright_cyan
    call buf_str
    mov esi, str_copy_label
    call buf_str
    mov esi, ansi_fg_white
    call buf_str

    mov esi, demo_str_test
    mov edi, demo_copy_buf
    call str_copy

    mov esi, demo_copy_buf
    call buf_str
    mov esi, str_quote
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; -------------------------------------------------------------------------
    ; Frame Step 4: Final attributes reset and trailing newline inside frame
    ; -------------------------------------------------------------------------
    mov eax, 17
    mov ebx, 1
    call buf_goto
    mov esi, ansi_reset
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; -------------------------------------------------------------------------
    ; Frame Step 5: Single sys_write flush and clean exit
    ; -------------------------------------------------------------------------
    call buf_flush

    syscall SYS_EXIT, EXIT_SUCCESS

; =============================================================================
; STACK NOTE SECTION
; =============================================================================
; Mark stack as non-executable to eliminate GNU ld warnings.
section .note.GNU-stack noalloc noexec nowrite progbits
