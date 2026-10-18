; =============================================================================
; Pawmodoro - Main Entry Point (src/main.asm)
;
; Purpose: Top-level entry point and Task 2 terminal & keyboard verification demo.
; Note:    This is the Task 2 (task-2-terminal) temporary demo. It initializes
;          the terminal in raw mode, polls keystrokes, provides interactive line
;          reading with backspace editing, and cleanly restores the terminal.
; =============================================================================

; -----------------------------------------------------------------------------
; Modular Includes (PRD §6.1)
; Note: Paths are relative to repo root (working directory of make).
; -----------------------------------------------------------------------------
%include "src/constants.inc"
%include "src/macros.inc"
%include "src/data.asm"

; =============================================================================
; DEMO DATA ASSETS (Specific to Task 2 Demo)
; =============================================================================
section .data
    demo_title:         db "Pawmodoro Terminal & Keyboard Demo (Task 2)", CHAR_LF, CHAR_NULL
    demo_instr:         db "Press keys. T = type a line. Q or Ctrl+C = quit.", CHAR_LF, CHAR_LF, CHAR_NULL
    demo_prompt:        db "Type something: ", CHAR_NULL
    demo_typed_prefix:  db "You typed: ", CHAR_NULL
    demo_len_prefix:    db " (len: ", CHAR_NULL
    demo_paren_close:   db ")", CHAR_LF, CHAR_NULL
    demo_keycode_prefix:db "Key code: ", CHAR_NULL

; =============================================================================
; TEXT SECTION (.text)
; =============================================================================
section .text

%include "src/io.asm"
%include "src/term.asm"

    global _start

; -----------------------------------------------------------------------------
; _start: Program entry point for Task 2 Terminal Demo.
;
; Purpose:  Initializes terminal raw mode, displays interactive instructions,
;           enters an event loop waiting for keystrokes, handles 'T' for line
;           editing, prints decimal key codes, and cleans up on 'Q' or Ctrl+C.
; IN:       none
; OUT:      none (process exits with status 0)
; CLOBBERS: EAX, EBX, ECX, EDX, ESI, EDI (irrelevant after process exit)
; -----------------------------------------------------------------------------
_start:
    ; -------------------------------------------------------------------------
    ; Step 1: Initialize terminal environment (alternate screen, hide cursor)
    ; -------------------------------------------------------------------------
    call term_init
    call term_raw

    ; -------------------------------------------------------------------------
    ; Step 2: Clear screen and display demo header
    ; -------------------------------------------------------------------------
    mov esi, ansi_clear
    call buf_str
    mov esi, ansi_home
    call buf_str

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
    mov esi, demo_instr
    call buf_str
    mov esi, ansi_reset
    call buf_str

    call buf_flush

    ; -------------------------------------------------------------------------
    ; Step 3: Event Loop - Wait for and process keypresses
    ; -------------------------------------------------------------------------
.event_loop:
    call key_wait

    ; Check for quit conditions: 'Q' or Ctrl+C
    cmp eax, KEY_Q
    je .exit_clean
    cmp eax, KEY_CTRL_C
    je .exit_clean

    ; Check for line input demo: 'T'
    cmp eax, KEY_T
    je .handle_type_line

    ; Default key handler: print decimal key code
    mov esi, demo_keycode_prefix
    call buf_str
    call buf_u32
    mov al, CHAR_LF
    call buf_char
    call buf_flush
    jmp .event_loop

.handle_type_line:
    ; Prompt user for line input
    mov esi, ansi_fg_bright_green
    call buf_str
    mov esi, demo_prompt
    call buf_str
    mov esi, ansi_reset
    call buf_str
    call buf_flush

    ; Read interactive line (max 20 characters for easy overflow testing)
    mov edi, line_buf
    mov ecx, READ_LINE_DEMO_MAX
    call read_line
    push eax                    ; Save stored string length

    ; Echo typed text
    mov esi, demo_typed_prefix
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov esi, line_buf
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Echo length
    mov esi, demo_len_prefix
    call buf_str
    pop eax                     ; Restore length
    call buf_u32
    mov esi, demo_paren_close
    call buf_str
    call buf_flush

    jmp .event_loop

    ; -------------------------------------------------------------------------
    ; Step 4: Clean exit path - restore cooked mode, normal screen, and exit
    ; -------------------------------------------------------------------------
.exit_clean:
    call term_restore
    syscall SYS_EXIT, EXIT_SUCCESS

; =============================================================================
; STACK NOTE SECTION
; =============================================================================
; Mark stack as non-executable to eliminate GNU ld warnings.
section .note.GNU-stack noalloc noexec nowrite progbits
