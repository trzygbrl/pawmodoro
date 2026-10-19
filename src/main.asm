; =============================================================================
; Pawmodoro - Main Entry Point & Finite State Machine (src/main.asm)
;
; Purpose: Top-level application shell, lifecycle initialization, main loop,
;          and finite state machine dispatch per PRD §4.1 (FR-U1, FR-U3, FR-U5).
; =============================================================================

; -----------------------------------------------------------------------------
; Modular Includes (PRD §6.1)
; Note: Paths are relative to repo root (working directory of make).
; -----------------------------------------------------------------------------
%include "src/constants.inc"
%include "src/macros.inc"
%include "src/data.asm"

; =============================================================================
; TEXT SECTION (.text)
; =============================================================================
section .text

%include "src/io.asm"
%include "src/term.asm"
%include "src/time.asm"
%include "src/ui.asm"
%include "src/file.asm"
%include "src/stats.asm"
%include "src/timer.asm"
%include "src/habits.asm"
%include "src/journal.asm"

    global _start

;=============================================================================
; Procedure: _start
; Purpose:   Top-level application shell entry point and finite state machine.
;            Initializes terminal raw mode, loads persistent data stores,
;            manages the 10 Hz non-blocking event and redraw loop, dispatches
;            subsystem runners, and guarantees clean terminal restoration.
; IN:        None
; OUT:       None (process terminates via sys_exit with status code in EBX)
; CLOBBERS:  EAX, EBX, ECX, EDX, ESI, EDI (registers discarded on process exit)
;=============================================================================
_start:
    ; -------------------------------------------------------------------------
    ; Step 1: Terminal Initialization & State Setup (FR-U1, FR-U5)
    ; -------------------------------------------------------------------------
    call term_init              ; Query terminal attributes and switch to alternate screen
    call term_install_signals   ; Install SIGHUP, SIGINT, SIGTERM signal handlers (Task 9)
    call term_raw               ; Configure non-canonical, non-blocking raw mode
    call stats_load             ; Load persisted stats.dat into memory & sync dashboard (FR-U7, FR-D2)
    call habits_load            ; Load persisted habits.dat into memory & sync dashboard (FR-U7, FR-D3)
    call dashboard_refresh      ; Initialize live dashboard values in memory (Task 9)

    mov dword [state], STATE_MENU
    mov dword [demo_mode], 0
    mov dword [menu_msg], 0
    mov dword [menu_msg_style], STATUS_INFO
    mov dword [need_redraw], 1

    ; -------------------------------------------------------------------------
    ; Step 2: Main Event & Redraw Loop (FR-U3, FR-U4)
    ; -------------------------------------------------------------------------
.main_loop:
    ; Check if screen needs redraw
    cmp dword [need_redraw], 0
    je .wait_for_input

    ; Dispatch renderer according to current state
    mov eax, [state]

    cmp eax, STATE_MENU
    je .render_menu

    cmp eax, STATE_QUIT
    je .handle_exit

    ; Unknown state fallback: return to menu
    mov dword [state], STATE_MENU
    jmp .render_menu

.render_menu:
    call dashboard_refresh      ; Refresh live daily stats on every return to menu (Task 9)
    call ui_draw_menu
    jmp .flush_frame

.flush_frame:
    ; Flush aggregated frame buffer with a SINGLE sys_write (FR-U4)
    call buf_flush
    mov dword [need_redraw], 0

.wait_for_input:
    ; Low-CPU sleep loop checking terminal dimensions and polling input (FR-U1, FR-T5)
    call time_sleep_100ms
    call term_size_ok
    test eax, eax
    jnz .poll_input
    ; Terminal shrunk below 80x24: trigger redraw to enter ui_size_gate immediately
    mov dword [need_redraw], 1
    jmp .main_loop

.poll_input:
    call key_poll
    cmp eax, KEY_NONE
    je .wait_for_input

    ; Dispatch key processing by current state
    mov edx, [state]

    cmp edx, STATE_MENU
    je .handle_menu_key

    cmp edx, STATE_QUIT
    je .handle_exit

    jmp .main_loop

; -----------------------------------------------------------------------------
; State Handler: STATE_MENU Keys (FR-U2)
; -----------------------------------------------------------------------------
.handle_menu_key:
    ; Global exit: 'Q' or Ctrl+C
    cmp eax, KEY_Q
    je .handle_exit
    cmp eax, KEY_CTRL_C
    je .handle_exit

    ; '1' -> Enter Pomodoro Timer (calls timer_run per Task 5)
    cmp eax, KEY_1
    je .menu_to_timer

    ; '2' -> Enter Habit Tracker stub screen
    cmp eax, KEY_2
    je .menu_to_habits

    ; '3' -> Enter Journal stub screen
    cmp eax, KEY_3
    je .menu_to_journal

    ; '4' -> Toggle demo mode (0 <-> 1)
    cmp eax, KEY_4
    je .menu_toggle_demo

    ; Any other key is ignored: no redraw, no write!
    jmp .main_loop

.menu_to_timer:
    call timer_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_to_habits:
    call habits_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    call habits_sync_dashboard
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_to_journal:
    call journal_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_toggle_demo:
    xor dword [demo_mode], 1    ; Flip demo_mode between 0 and 1
    cmp dword [demo_mode], 1
    je .demo_active
    mov dword [menu_msg], menu_msg_demo_off
    mov dword [menu_msg_style], STATUS_INFO
    jmp .demo_set_done

.demo_active:
    mov dword [menu_msg], menu_msg_demo_on
    mov dword [menu_msg_style], STATUS_OK

.demo_set_done:
    mov dword [need_redraw], 1
    jmp .main_loop

; -----------------------------------------------------------------------------
; State Handler: Stub Screens (Timer, Habits, Journal) Keys
; -----------------------------------------------------------------------------
.handle_stub_key:
    ; Global exit: Ctrl+C (FR-U5 clean exit on every screen)
    cmp eax, KEY_CTRL_C
    je .handle_exit

    ; 'B' (or 'b', uppercased by key_wait) -> Return to Main Menu
    cmp eax, KEY_B
    je .stub_to_menu

    ; Any other key is ignored: no redraw, no write!
    jmp .main_loop

.stub_to_menu:
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop

; -----------------------------------------------------------------------------
; State Handler: STATE_QUIT & Cleanup (FR-U5)
; -----------------------------------------------------------------------------
.handle_exit:
    mov ebx, EXIT_SUCCESS
    call app_exit

;=============================================================================
; Procedure: dashboard_refresh
; Purpose:   Update dashboard statistics from in-memory stores by querying
;            stats_today and habits_sync_dashboard.
; IN:        None
; OUT:       Updates [dash_pomodoros], [dash_habits_done], [dash_habits_total]
; CLOBBERS:  None (preserves all)
;=============================================================================
dashboard_refresh:
    save_regs

    call stats_today            ; EAX = today's completed pomodoros
    mov [dash_pomodoros], eax

    call habits_sync_dashboard  ; Updates dash_habits_done and dash_habits_total

    restore_regs
    ret

;=============================================================================
; Procedure: app_exit
; Purpose:   Centralized process exit routine with guaranteed terminal cleanup.
;            Sets recursion guard [app_exiting] = 1, invokes term_restore to
;            return the terminal to original cooked mode, and terminates the
;            process via sys_exit with code in EBX.
; IN:        EBX = Process exit code (0 = success, 1 = failure, 130 = signaled)
; OUT:       None (never returns)
; CLOBBERS:  None (process terminates)
;=============================================================================
app_exit:
    mov dword [app_exiting], 1  ; Prevent re-entrant exit during term_restore
    push ebx                    ; Preserve exit code across term_restore
    call term_restore
    pop ebx                     ; Restore exit code
    syscall SYS_EXIT, ebx

; =============================================================================
; STACK NOTE SECTION
; =============================================================================
; Mark stack as non-executable to eliminate GNU ld warnings.
section .note.GNU-stack noalloc noexec nowrite progbits
