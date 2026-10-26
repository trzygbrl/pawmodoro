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
%include "src/sprites.asm"

; =============================================================================
; TEXT SECTION (.text)
; =============================================================================
section .text

%include "src/io.asm"
%include "src/theme.asm"
%include "src/term.asm"
%include "src/time.asm"
%include "src/ui.asm"
%include "src/ui_components.asm"
%include "src/file.asm"
%include "src/settings.asm"
%include "src/settings_ui.asm"
%include "src/stats.asm"
%include "src/timer.asm"
%include "src/habits.asm"
%include "src/journal.asm"
%include "src/anim.asm"
%include "src/sfx.asm"
%include "src/gfx.asm"
%include "src/sprite.asm"
%include "src/layout.asm"
%include "src/widgets.asm"

section .text
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
    ; Check command-line arguments for diagnostic mode (--test-overflow)
    mov eax, [esp]              ; EAX = argc
    cmp eax, 2
    jl .start_normal
    mov esi, [esp + 8]          ; ESI = argv[1]
    mov edi, str_flag_test_overflow
.check_diag_loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .start_normal
    test al, al
    jz .run_overflow_diag
    inc esi
    inc edi
    jmp .check_diag_loop

.run_overflow_diag:
    call settings_load          ; Initialize active_palette
    call gfx_diag_run_all       ; Runs headless diagnostics and terminates via sys_exit

.start_normal:
    ; Capture environment pointer (envp) from initial process stack (PRD_V2 §9)
    mov eax, [esp]              ; EAX = argc
    lea edx, [esp + 8 + eax*4]  ; EDX = envp pointer
    mov [sfx_envp], edx

    ; -------------------------------------------------------------------------
    ; Step 1: Terminal Initialization & State Setup (FR-U1, FR-U5)
    ; -------------------------------------------------------------------------
    call term_init              ; Query terminal attributes and switch to alternate screen
    call term_install_signals   ; Install SIGHUP, SIGINT, SIGTERM signal handlers (Task 9)
    call term_raw               ; Configure non-canonical, non-blocking raw mode
    call settings_load          ; Load persisted settings.dat & initialize theme palette (Task V4)
    call sfx_init               ; Initialize sound engine & probe audio players (Task V8)
    call stats_load             ; Load persisted stats.dat into memory & sync dashboard (FR-U7, FR-D2)
    call habits_load            ; Load persisted habits.dat into memory & sync dashboard (FR-U7, FR-D3)
    call dashboard_refresh      ; Initialize live dashboard values in memory (Task 9)
    call anim_init              ; Initialize animation engine & seed PRNG (Task V7)

    mov dword [state], STATE_MENU
    mov dword [demo_mode], 0
    mov dword [dash_focus], 0
    mov dword [dash_prev_focus], 0
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

    cmp eax, STATE_SETTINGS
    je .render_settings

    cmp eax, STATE_QUIT
    je .handle_exit

    ; Unknown state fallback: return to menu
    mov dword [state], STATE_MENU
    jmp .render_menu

.render_settings:
    call settings_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop

.render_menu:
    call dashboard_refresh      ; Refresh live daily stats on every return to menu (Task 9)
    call ui_draw_menu
    jmp .flush_frame

.flush_frame:
    ; Flush aggregated frame buffer with a SINGLE sys_write (FR-U4)
    call buf_flush
    mov dword [need_redraw], 0

.wait_for_input:
    ; Low-CPU sleep loop checking terminal dimensions, ticking animation, and polling input
    call time_sleep_100ms
    ; Advance animation and flush dirty partial regions (Task V7)
    ; In STATE_MENU, anim_tick hardcodes 80x24 title coordinates (col 12, 14, 32)
    ; so only invoke anim_tick in menu if layout_tier == TIER_COMPACT
    cmp dword [state], STATE_MENU
    jne .do_anim_tick
    cmp dword [layout_tier], TIER_COMPACT
    jne .skip_anim_tick
.do_anim_tick:
    call anim_tick
.skip_anim_tick:
    call term_size_ok
    test eax, eax
    jz .main_resized            ; Terminal shrunk below 80x24: trigger redraw to enter ui_size_gate immediately
    ; Check if terminal dimensions changed while >= 80x24
    mov edx, [term_cols]
    cmp edx, [ui_seen_cols]
    jne .main_resized
    mov edx, [term_rows]
    cmp edx, [ui_seen_rows]
    jne .main_resized
    jmp .poll_input

.main_resized:
    call anim_reset_effects
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
    ; Global exit: 'Q', 'q', or Ctrl+C
    cmp eax, KEY_Q
    je .handle_exit
    cmp eax, 113                ; 'q'
    je .handle_exit
    cmp eax, KEY_CTRL_C
    je .handle_exit

    ; Up / Down: Move sidebar focus (wrap 0..5) with dirty-region partial redraw
    cmp eax, KEY_UP
    je .menu_focus_up
    cmp eax, KEY_DOWN
    je .menu_focus_down

    ; Enter: Activate focused sidebar control
    cmp eax, KEY_ENTER
    je .menu_activate_focus
    cmp eax, 13
    je .menu_activate_focus

    ; 'J' / 'j' -> Open Quick Journal new-entry prompt directly
    cmp eax, KEY_J
    je .menu_to_quick_journal
    cmp eax, 106                ; 'j'
    je .menu_to_quick_journal

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

    ; '5' -> Enter Settings screen
    cmp eax, KEY_5
    je .menu_to_settings

%ifdef G1_DEMO_ENABLED
    ; Ctrl+G -> Enter temporary G1 rendering demo (PRD_V3 §11)
    cmp eax, KEY_CTRL_G
    je .menu_to_g1_demo
%endif

%ifdef SPRITE_VIEWER_ENABLED
    ; Ctrl+V -> Enter hidden sprite viewer (PRD_V3 §sprites)
    cmp eax, KEY_CTRL_V
    je .menu_to_sprite_viewer
%endif

    ; Ctrl+L -> Enter hidden G6 layout & widget test screen
    cmp eax, KEY_CTRL_L
    je .menu_to_layout_test

    ; Any other key is ignored: no redraw, no write!
    jmp .main_loop

.menu_focus_up:
    mov eax, [dash_focus]
    mov [dash_prev_focus], eax
    dec eax
    jns .focus_up_ok
    mov eax, 5                  ; Wrap 0 -> 5
.focus_up_ok:
    mov [dash_focus], eax
    mov ebx, eax                ; EBX = new_focus
    mov eax, [dash_prev_focus]  ; EAX = prev_focus
    call ui_draw_menu_focus_change
    jmp .main_loop

.menu_focus_down:
    mov eax, [dash_focus]
    mov [dash_prev_focus], eax
    inc eax
    cmp eax, 6
    jb .focus_down_ok
    xor eax, eax                ; Wrap 5 -> 0
.focus_down_ok:
    mov [dash_focus], eax
    mov ebx, eax                ; EBX = new_focus
    mov eax, [dash_prev_focus]  ; EAX = prev_focus
    call ui_draw_menu_focus_change
    jmp .main_loop

.menu_activate_focus:
    mov eax, [dash_focus]
    cmp eax, 0
    je .menu_to_timer
    cmp eax, 1
    je .menu_to_habits
    cmp eax, 2
    je .menu_to_journal
    cmp eax, 3
    je .menu_toggle_demo
    cmp eax, 4
    je .menu_to_settings
    cmp eax, 5
    je .handle_exit
    jmp .main_loop

.menu_to_quick_journal:
    call anim_reset_effects
    call journal_new_entry
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    call dashboard_refresh
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_to_layout_test:
    call anim_reset_effects
    call layout_test_screen_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop

%ifdef SPRITE_VIEWER_ENABLED
.menu_to_sprite_viewer:
    call anim_reset_effects
    call sprite_viewer_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop
%endif

%ifdef G1_DEMO_ENABLED
.menu_to_g1_demo:
    call anim_reset_effects
    call gfx_run_demo
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop
%endif

.menu_to_settings:
    call anim_reset_effects
    mov dword [state], STATE_SETTINGS
    call settings_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_to_timer:
    call anim_reset_effects
    call timer_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_to_habits:
    call anim_reset_effects
    call habits_run
    cmp dword [state], STATE_QUIT
    je .handle_exit
    mov dword [state], STATE_MENU
    call habits_sync_dashboard
    mov dword [need_redraw], 1
    jmp .main_loop

.menu_to_journal:
    call anim_reset_effects
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

    call journal_load_tail      ; Load newest entries for dashboard recent notes card
    call journal_find_lines

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
