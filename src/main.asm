; =============================================================================
; Pawmodoro - Main Entry Point (src/main.asm)
;
; Purpose: Top-level entry point and Task 3 time & date verification demo.
; Note:    This is the Task 3 (task-3-time) temporary demo. It queries the local
;          day number, calendar date, and HH:MM time, verifies the Hinnant test
;          vectors, tests 10 x 100 ms sleep, and cleanly exits with status 0.
; =============================================================================

; -----------------------------------------------------------------------------
; Modular Includes (PRD §6.1)
; Note: Paths are relative to repo root (working directory of make).
; -----------------------------------------------------------------------------
%include "src/constants.inc"
%include "src/macros.inc"
%include "src/data.asm"

; =============================================================================
; DEMO DATA ASSETS (Specific to Task 3 Demo, Temporary)
; =============================================================================
section .data
    demo_lbl_day_num:       db "Today's day number: ", CHAR_NULL
    demo_lbl_today_date:    db "Today's date: ", CHAR_NULL
    demo_lbl_local_time:    db "Current local time (HH:MM): ", CHAR_NULL
    demo_lbl_vec_0:         db "Day 0: ", CHAR_NULL
    demo_lbl_vec_10957:     db "Day 10957: ", CHAR_NULL
    demo_lbl_vec_19723:     db "Day 19723: ", CHAR_NULL
    demo_lbl_sleep:         db "Slept 10 x 100 ms", CHAR_LF, CHAR_NULL

; =============================================================================
; TEXT SECTION (.text)
; =============================================================================
section .text

%include "src/io.asm"
%include "src/term.asm"
%include "src/time.asm"

    global _start

; -----------------------------------------------------------------------------
; _start: Program entry point for Task 3 Time & Date Demo.
;
; Purpose:  Executes verification steps per PRD Task 3 requirements:
;           1. Print today's day number (time_today + buf_u32).
;           2. Print today's date (time_today + time_fmt_date + buf_str).
;           3. Print current local time (time_local + time_fmt_hhmm + buf_str).
;           4. Print the three test vectors (days 0, 10957, 19723).
;           5. Execute 10 x 100ms sleeps via time_sleep_100ms and report completion.
; IN:       none
; OUT:      none (process exits with status 0)
; CLOBBERS: EAX, EBX, ECX, EDX, ESI, EDI (irrelevant after process exit)
; -----------------------------------------------------------------------------
_start:
    ; -------------------------------------------------------------------------
    ; 1. Today's day number: time_today + buf_u32
    ; -------------------------------------------------------------------------
    mov esi, demo_lbl_day_num
    call buf_str
    call time_today             ; EAX = day number
    call buf_u32
    mov al, CHAR_LF
    call buf_char

    ; -------------------------------------------------------------------------
    ; 2. Today's date: time_today -> time_fmt_date -> print buffer
    ; -------------------------------------------------------------------------
    mov esi, demo_lbl_today_date
    call buf_str
    call time_today             ; EAX = day number
    mov edi, date_buf
    call time_fmt_date          ; writes "YYYY-MM-DD\0" into date_buf
    mov esi, date_buf
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; -------------------------------------------------------------------------
    ; 3. Current local time as HH:MM: time_local -> time_fmt_hhmm -> print buffer
    ; -------------------------------------------------------------------------
    mov esi, demo_lbl_local_time
    call buf_str
    call time_local             ; EAX = local seconds
    mov edi, time_buf
    call time_fmt_hhmm          ; writes "HH:MM\0" into time_buf
    mov esi, time_buf
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; -------------------------------------------------------------------------
    ; 4. Test vectors: days 0, 10957, 19723
    ; -------------------------------------------------------------------------
    ; Vector 1: Day 0 -> 1970-01-01
    mov esi, demo_lbl_vec_0
    call buf_str
    mov eax, TEST_VECTOR_0
    mov edi, date_buf
    call time_fmt_date
    mov esi, date_buf
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; Vector 2: Day 10957 -> 2000-01-01
    mov esi, demo_lbl_vec_10957
    call buf_str
    mov eax, TEST_VECTOR_10957
    mov edi, date_buf
    call time_fmt_date
    mov esi, date_buf
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; Vector 3: Day 19723 -> 2024-01-01
    mov esi, demo_lbl_vec_19723
    call buf_str
    mov eax, TEST_VECTOR_19723
    mov edi, date_buf
    call time_fmt_date
    mov esi, date_buf
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; Flush output buffer before starting sleep test
    call buf_flush

    ; -------------------------------------------------------------------------
    ; 5. Sleep test: call time_sleep_100ms ten times in a loop
    ; -------------------------------------------------------------------------
    mov ecx, SLEEP_DEMO_COUNT
.sleep_loop:
    push ecx
    call time_sleep_100ms
    pop ecx
    dec ecx
    jnz .sleep_loop

    ; Print completion message and flush
    mov esi, demo_lbl_sleep
    call buf_str
    call buf_flush

    ; -------------------------------------------------------------------------
    ; Exit process cleanly with code 0
    ; -------------------------------------------------------------------------
    syscall SYS_EXIT, EXIT_SUCCESS

; =============================================================================
; STACK NOTE SECTION
; =============================================================================
; Mark stack as non-executable to eliminate GNU ld warnings.
section .note.GNU-stack noalloc noexec nowrite progbits
