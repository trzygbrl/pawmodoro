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

; -----------------------------------------------------------------------------
; _start: Program entry point and shell finite state machine.
;
; Purpose:  Initializes terminal raw mode, configures initial application state
;           (STATE_MENU), enters the non-blocking event loop, dispatches renderers
;           on need_redraw, sleeps 50 ms via key_wait when idle, and ensures
;           term_restore is executed on all exit paths.
; IN:       none
; OUT:      none (process exits with status 0 via sys_exit)
; CLOBBERS: EAX, EBX, ECX, EDX, ESI, EDI (irrelevant after process exit)
; -----------------------------------------------------------------------------
_start:
    ; -------------------------------------------------------------------------
    ; Step 1: Terminal Initialization & State Setup (FR-U1, FR-U5)
    ; -------------------------------------------------------------------------
    call term_init
    call term_install_signals   ; Install SIGHUP, SIGINT, SIGTERM signal handlers (Task 9)
    call term_raw
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

    ; -------------------------------------------------------------------------
    ; Step 3: Wait for Keystroke (Low CPU sleep loop via key_wait)
    ; -------------------------------------------------------------------------
.wait_for_input:
    call key_wait               ; Blocks sleeping 50 ms per check; returns uppercase key in EAX

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

; -----------------------------------------------------------------------------
; dashboard_refresh: Update dashboard statistics from in-memory stores.
;
; Purpose:  Reloads live daily statistics into dashboard display variables:
;           1. Queries stats_today to update dash_pomodoros with today's count.
;           2. Invokes habits_sync_dashboard to refresh dash_habits_done and
;              dash_habits_total.
;           Does not perform file I/O; reads current in-memory write-through data.
; IN:       none
; OUT:      Updates [dash_pomodoros], [dash_habits_done], [dash_habits_total]
; CLOBBERS: EFLAGS only
; -----------------------------------------------------------------------------
dashboard_refresh:
    save_regs

    call stats_today            ; EAX = today's completed pomodoros
    mov [dash_pomodoros], eax

    call habits_sync_dashboard  ; Updates dash_habits_done and dash_habits_total

    restore_regs
    ret

; -----------------------------------------------------------------------------
; app_exit: Centralized process exit routine with guaranteed terminal cleanup.
;
; Purpose:  Sets the exiting flag [app_exiting] = 1 to prevent recursive exit calls
;           from buf_flush, invokes term_restore to return the terminal to original
;           cooked mode, and terminates the process via sys_exit with code in EBX.
; IN:       EBX = Process exit code
; OUT:      Never returns
; CLOBBERS: n/a
; -----------------------------------------------------------------------------
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
