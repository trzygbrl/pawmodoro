; =============================================================================
; Pawmodoro - Pomodoro Timer Engine & View (src/timer.asm)
;
; Purpose: Core Pomodoro countdown timer state machine, 100ms timing loop,
;          keyboard polling, phase transitions, and UI rendering per PRD §4.2,
;          §5, and §6.4.
; Reference: PRD §4.2 (FR-T1 to FR-T7), §5 (Timer wireframe), §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: timer_draw
; Purpose:   Assembles the entire Pomodoro Timer frame in out_buf adhering to the
;            PRD §5 wireframe. Implements the two-phase rendering model:
;            Phase 1: Moves cursor to (1,1), draws borders and cleared rows
;                     (Rows 1..10), and clears lines below frame with ESC[J.
;            Phase 2: Overlays title ("<PHASE> - Session n of 4"), demo tag
;                     ("[DEMO]"), cat ASCII art (working/resting pose), time display
;                     (MM:SS with "PAUSED" indicator if paused), 30-char progress
;                     bar via ui_progress_bar, phase message / prompt on Row 8,
;                     and context-sensitive key help on Row 9.
;            NOTE: Does NOT flush the buffer. Caller invokes buf_flush (or appends
;                  the audio bell before flushing).
; IN:        EAX = Frame completion / prompt mode:
;                  TIMER_FRAME_RUNNING (0): Normal active/paused frame
;                  TIMER_FRAME_BREAK_DONE (1): Break over message & help
;                  TIMER_FRAME_FOCUS_DONE (2): Focus complete note prompt & help
;                  TIMER_FRAME_NOTE_PROMPT (3): Note input prompt (row 8)
;                  TIMER_FRAME_NOTE_RESULT (4): Note result status (timer_result_msg)
; OUT:       Appends entire frame escape sequences and text to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
timer_draw:
    call ui_size_gate           ; Terminal dimension check gate (Task 9)
    call ui_layout_update       ; Recalculate adaptive layout geometry (PRD v2 §2)
    save_regs
    push eax                    ; [esp] = frame mode (0..4)
    mov dword [ui_screen_bottom_row], UI_TIMER_ROW_BOTTOM

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Borders and Erase Inner Rows (FR-U4)
    ; -------------------------------------------------------------------------
    ; Start frame at home position (1, 1)
    mov eax, UI_TIMER_ROW_TOP
    mov ebx, 1
    call ui_goto

    ; Row 1: Top border line
    mov eax, UI_TIMER_ROW_TOP
    call ui_frame_hline

    ; Rows 2..9: Erase each row with ESC[K and anchor right border '|' at col ui_w
    mov eax, UI_TIMER_ROW_TITLE
    call ui_frame_row
    mov eax, UI_TIMER_ROW_BLANK1
    call ui_frame_row
    mov eax, UI_TIMER_ROW_CAT1
    call ui_frame_row
    mov eax, UI_TIMER_ROW_CAT2
    call ui_frame_row
    mov eax, UI_TIMER_ROW_CAT3
    call ui_frame_row
    mov eax, UI_TIMER_ROW_PROGRESS
    call ui_frame_row
    mov eax, UI_TIMER_ROW_MSG
    call ui_frame_row
    mov eax, UI_TIMER_ROW_HELP
    call ui_frame_row

    ; Row 10: Bottom border line
    mov eax, UI_TIMER_ROW_BOTTOM
    call ui_frame_hline

    ; Row 11: Erase to bottom of terminal screen (ESC[J) to clear leftover lines
    mov eax, UI_TIMER_ROW_BELOW
    mov ebx, 1
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content at Absolute Cursor Coordinates
    ; -------------------------------------------------------------------------
    ; 1. Title Row (Row 2, Col 4): "<PHASE> - Session n of 4"
    mov eax, UI_TIMER_ROW_TITLE
    mov ebx, UI_TIMER_COL_TITLE
    call ui_goto

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TITLE
    call ui_color

    ; Fetch phase title pointer from table
    mov edx, [phase]
    mov esi, [timer_phase_titles + edx*4]
    call buf_str

    ; Append " - Session "
    mov esi, timer_lbl_session_prefix
    call buf_str

    ; Append current session number (1..4)
    mov eax, [session_no]
    call buf_u32

    ; Append " of 4"
    mov esi, timer_lbl_session_suffix
    call buf_str

    mov esi, ansi_reset
    call buf_str

    ; 2. [DEMO] badge at (Row 2, Col ui_w - 8) if demo_mode == 1
    cmp dword [demo_mode], 1
    jne .skip_demo_badge

    mov eax, UI_TIMER_ROW_TITLE
    mov ebx, [ui_w]
    sub ebx, UI_TIMER_OFF_DEMO  ; ui_w - 8
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, timer_lbl_demo
    call buf_str
    mov esi, ansi_reset
    call buf_str

.skip_demo_badge:
    ; 2b. Cycle dots at Row 3, Col 4: "Cycle: ● ○ ○ ○"
    mov eax, UI_TIMER_ROW_BLANK1
    mov ebx, UI_TIMER_COL_TITLE
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov esi, timer_lbl_cycle_prefix ; "Cycle: "
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; Render 4 session dots: 1..session_no filled (SLOT_ACCENT), rest empty (SLOT_DIM)
    mov ecx, 1
.cycle_dots_loop:
    cmp ecx, [session_no]
    ja .dot_empty
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_DOT_FILLED
    call ui_glyph_str
    call buf_str
    jmp .dot_space
.dot_empty:
    mov al, SLOT_DIM
    call ui_color
    mov eax, GLYPH_DOT_EMPTY
    call ui_glyph_str
    call buf_str
.dot_space:
    mov esi, ansi_reset
    call buf_str
    mov al, CHAR_SPACE
    call buf_char
    inc ecx
    cmp ecx, SESSIONS_PER_CYCLE ; 4
    jbe .cycle_dots_loop

    ; 3. Cat ASCII art at Row 4, Col 6 (Working pose for Focus, Resting for Breaks, Happy for Focus Done)
    mov dword [cat_row], UI_TIMER_ROW_CAT1
    mov dword [cat_col], UI_TIMER_COL_CAT
    mov edx, [esp]              ; Frame mode
    cmp edx, TIMER_FRAME_FOCUS_DONE
    je .cat_pose_happy
    mov edx, [phase]
    mov eax, [timer_phase_poses + edx*4]
    jmp .cat_draw_call
.cat_pose_happy:
    mov eax, CAT_POSE_HAPPY
.cat_draw_call:
    call ui_draw_cat

    ; 4. Time display MM:SS at Row 5, Col 20 (beside middle cat row)
    mov eax, UI_TIMER_ROW_CAT2
    mov ebx, UI_TIMER_COL_TIME
    call ui_goto

    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_TEXT
    call ui_color
    mov eax, [remaining_secs]
    call buf_mmss
    mov esi, ansi_reset
    call buf_str

    ; 5. "PAUSED" indicator at Row 5, Col 27 if paused == 1
    cmp dword [paused], 1
    jne .skip_paused_label

    mov eax, UI_TIMER_ROW_CAT2
    mov ebx, UI_TIMER_COL_PAUSED
    call ui_goto
    mov esi, ansi_bold
    call buf_str
    mov al, SLOT_WARN
    call ui_color
    mov esi, timer_lbl_paused
    call buf_str
    mov esi, ansi_reset
    call buf_str

.skip_paused_label:
    ; 6. Progress bar at Row 7, Col 5 (elapsed = total - remaining)
    mov eax, UI_TIMER_ROW_PROGRESS
    mov ebx, UI_TIMER_COL_PROGRESS
    call ui_goto

    mov eax, [total_secs]
    sub eax, [remaining_secs]    ; EAX = elapsed seconds
    mov ecx, [total_secs]        ; ECX = total seconds
    call ui_progress_bar

    ; 7. Completion message / prompt at Row 8, Col 4
    mov edx, [esp]              ; EDX = frame mode (0..4)

    cmp edx, TIMER_FRAME_RUNNING
    je .skip_msg                ; Mode 0: Row 8 is blank

    cmp edx, TIMER_FRAME_BREAK_DONE
    je .draw_break_done_msg

    cmp edx, TIMER_FRAME_FOCUS_DONE
    je .draw_focus_done_msg

    cmp edx, TIMER_FRAME_NOTE_PROMPT
    je .draw_note_prompt_msg

    cmp edx, TIMER_FRAME_NOTE_RESULT
    je .draw_note_result_msg

    jmp .skip_msg

.draw_break_done_msg:
    mov eax, UI_TIMER_ROW_MSG
    mov ebx, STATUS_OK
    mov esi, timer_msg_break_done
    call ui_draw_status
    jmp .skip_msg

.draw_focus_done_msg:
    mov eax, UI_TIMER_ROW_MSG
    mov ebx, STATUS_OK
    mov esi, timer_msg_focus_prompt
    call ui_draw_status

    ; Check if "Could not save" warning should be displayed on Row 3 (FR-D4)
    ; Displayed on FOCUS completion when stats_save_failed == STATS_SAVE_FAILED
    cmp dword [stats_save_failed], STATS_SAVE_FAILED
    jne .skip_msg

    mov eax, UI_TIMER_ROW_BLANK1
    mov ebx, STATUS_ERR
    mov esi, err_could_not_save
    call ui_draw_status
    jmp .skip_msg

.draw_note_prompt_msg:
    mov eax, UI_TIMER_ROW_MSG
    mov ebx, UI_TIMER_COL_MSG
    mov esi, timer_msg_note_input
    call ui_text_at
    jmp .skip_msg

.draw_note_result_msg:
    mov eax, UI_TIMER_ROW_MSG
    mov ebx, [timer_result_style]
    mov esi, [timer_result_msg]
    call ui_draw_status

.skip_msg:
    ; 8. Key help prompt at Row 9, Col 4
    mov edx, [esp]              ; EDX = frame mode (0..4)

    cmp edx, TIMER_FRAME_RUNNING
    je .help_mode_running

    cmp edx, TIMER_FRAME_BREAK_DONE
    je .help_mode_break_done

    cmp edx, TIMER_FRAME_FOCUS_DONE
    je .help_mode_focus_done

    cmp edx, TIMER_FRAME_NOTE_PROMPT
    je .help_done               ; Row 9 is blank during interactive note input

    cmp edx, TIMER_FRAME_NOTE_RESULT
    je .help_mode_note_result

    jmp .help_done

.help_mode_running:
    mov eax, UI_TIMER_ROW_HELP
    mov ebx, UI_TIMER_COL_HELP
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    cmp dword [paused], 1
    jne .emit_running_help
    mov esi, timer_help_paused
    jmp .emit_running_text
.emit_running_help:
    mov esi, timer_help_running
.emit_running_text:
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .help_done

.help_mode_break_done:
    mov eax, UI_TIMER_ROW_HELP
    mov ebx, UI_TIMER_COL_HELP
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, timer_help_break_done
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .help_done

.help_mode_focus_done:
    mov eax, UI_TIMER_ROW_HELP
    mov ebx, UI_TIMER_COL_HELP
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, timer_help_focus_prompt
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .help_done

.help_mode_note_result:
    mov eax, UI_TIMER_ROW_HELP
    mov ebx, UI_TIMER_COL_HELP
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, timer_help_note_result
    call buf_str
    mov esi, ansi_reset
    call buf_str

.help_done:
    ; Append terminal integration sequences (Layer 3 title & Layer 4 taskbar progress)
    ; to out_buf so they are flushed as part of the normal frame in a single sys_write!
    mov eax, [esp]              ; Frame mode (0..4)
    call notify_title_update
    mov eax, [esp]
    call notify_progress_update

    pop eax                     ; Restore frame mode
    restore_regs
    ret

;=============================================================================
; Procedure: timer_phase_start
; Purpose:   Sets up total duration from normal/demo tables based on [demo_mode],
;            initializes remaining_secs = total_secs, ticks = 0, paused = 0,
;            and resets focus_completed_flag = 0 if entering PHASE_FOCUS.
;            Renders the initial frame (0% elapsed) and flushes out_buf once.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
timer_phase_start:
    save_regs
    push eax

    ; Reset focus_completed_flag to 0 at the start of every FOCUS phase
    cmp dword [phase], PHASE_FOCUS
    jne .phase_load_duration
    mov dword [focus_completed_flag], 0
    mov dword [stats_save_failed], STATS_SAVE_OK

.phase_load_duration:
    ; Choose duration table according to demo_mode
    mov edx, timer_durations_normal
    cmp dword [demo_mode], 1
    jne .phase_got_table
    mov edx, timer_durations_demo

.phase_got_table:
    mov eax, [phase]
    mov eax, [edx + eax*4]      ; EAX = duration in seconds
    mov [total_secs], eax
    mov [remaining_secs], eax

    ; Reset tick counter and paused state
    mov dword [ticks], 0
    mov dword [paused], 0

    ; Draw initial frame and flush to screen in a single sys_write
    xor eax, eax                ; 0 = normal active frame
    call timer_draw
    call buf_flush

    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: timer_advance_phase
; Purpose:   Implements standard Pomodoro cycle progression:
;            - After completed FOCUS:
;              If session_no == SESSIONS_PER_CYCLE (4):
;                next phase is PHASE_LONG_BREAK.
;              Else:
;                next phase is PHASE_SHORT_BREAK.
;            - After break (SHORT_BREAK or LONG_BREAK):
;              next phase is PHASE_FOCUS.
;              If focus_completed_flag == 1:
;                If current phase was LONG_BREAK:
;                  session_no resets to 1.
;                Else:
;                  session_no increments.
; IN:        None
; OUT:       Updates [phase] and [session_no]
; CLOBBERS:  None (preserves all)
;=============================================================================
timer_advance_phase:
    save_regs
    push eax

    cmp dword [phase], PHASE_FOCUS
    jne .advance_break

    ; Completed FOCUS phase: check if cycle is complete
    cmp dword [session_no], SESSIONS_PER_CYCLE
    jae .advance_to_long_break
    mov dword [phase], PHASE_SHORT_BREAK
    jmp .advance_done

.advance_to_long_break:
    mov dword [phase], PHASE_LONG_BREAK
    jmp .advance_done

.advance_break:
    ; Completed break phase: advance session counter if focus was completed
    cmp dword [focus_completed_flag], 1
    jne .advance_to_focus

    cmp dword [phase], PHASE_LONG_BREAK
    je .advance_reset_session
    inc dword [session_no]
    jmp .advance_to_focus

.advance_reset_session:
    mov dword [session_no], 1

.advance_to_focus:
    mov dword [phase], PHASE_FOCUS

.advance_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: timer_skip_phase
; Purpose:   Implements the Pomodoro skip rules:
;            - A skipped FOCUS phase is NOT completed (focus_completed_flag
;              remains 0) and transitions to PHASE_SHORT_BREAK without advancing
;              session_no.
;            - A skipped break transitions to PHASE_FOCUS. If the preceding
;              focus was completed, session_no advances (or resets to 1 after
;              LONG_BREAK); if the preceding focus was skipped, session_no
;              does not change.
; IN:        None
; OUT:       Updates [phase] and [session_no]
; CLOBBERS:  None (preserves all)
;=============================================================================
timer_skip_phase:
    save_regs
    push eax

    cmp dword [phase], PHASE_FOCUS
    jne .skip_break

    ; Skipping a FOCUS phase: go to SHORT_BREAK, session_no unchanged
    mov dword [phase], PHASE_SHORT_BREAK
    jmp .skip_done

.skip_break:
    ; Skipping a break: check if preceding focus was completed
    cmp dword [focus_completed_flag], 1
    jne .skip_to_focus

    ; Preceding focus was completed: advance session counter
    cmp dword [phase], PHASE_LONG_BREAK
    je .skip_reset_session
    inc dword [session_no]
    jmp .skip_to_focus

.skip_reset_session:
    mov dword [session_no], 1

.skip_to_focus:
    mov dword [phase], PHASE_FOCUS

.skip_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: timer_run
; Purpose:   Initializes Pomodoro state (PHASE_FOCUS, session 1), starts the first
;            phase, and enters the non-blocking 100ms timing loop.
;            Polls keys each tick, handles P (pause toggle), S (skip phase),
;            Q (stop and return to menu), and Ctrl+C (quit application).
;            When running, decrements remaining_secs every 10 ticks (1 second) and
;            redraws the frame once per second.
;            When a phase naturally completes (remaining_secs reaches 0), renders
;            the completion frame with audio bell in a single sys_write, waits for
;            user keypress, and transitions to the next phase in the Pomodoro cycle.
;            Before returning, sets [state] to STATE_MENU (on Q/stop) or STATE_QUIT
;            (on Ctrl+C).
; IN:        None
; OUT:       None (returns to menu on quit)
; CLOBBERS:  None (preserves all)
;=============================================================================
timer_run:
    save_regs
    push eax

    ; Initialize Pomodoro cycle state (FR-T1)
    mov dword [state], STATE_TIMER
    mov dword [phase], PHASE_FOCUS
    mov dword [session_no], 1
    mov dword [focus_completed_flag], 0

    ; Play timer start chirp sound effect (Task V8)
    mov eax, SFX_START_CHIRP
    call sfx_play

.phase_entry:
    call timer_phase_start

.tick_loop:
    ; Low-CPU 100ms sleep via sys_nanosleep (FR-T5)
    call time_sleep_100ms

    ; Event-driven animation tick (Task V7, PRD_V2 §8)
    call anim_tick

    ; Non-blocking keyboard poll
    call key_poll

    ; Check if a key was returned
    cmp eax, KEY_NONE
    je .no_key

    ; Dispatch key
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c

    cmp eax, KEY_Q
    je .key_q

    cmp eax, KEY_P
    je .key_p

    cmp eax, KEY_S
    je .key_s

    ; Unknown key: silently ignored, no state change, no redraw!
    jmp .no_key

.key_ctrl_c:
    ; Global quit: set STATE_QUIT and return to main shell
    call anim_reset_effects
    call notify_clear_external
    mov dword [state], STATE_QUIT
    jmp .timer_exit

.key_q:
    ; Stop timer: set STATE_MENU and return to main shell
    call anim_reset_effects
    call notify_clear_external
    mov dword [state], STATE_MENU
    jmp .timer_exit

.key_p:
    ; Toggle pause state (0 <-> 1)
    xor dword [paused], 1
    xor eax, eax                ; Redraw normal frame showing updated pause status
    call timer_draw
    call buf_flush
    jmp .tick_loop

.key_s:
    ; Skip current phase early (no confetti on skip!)
    call anim_reset_effects
    call timer_skip_phase
    jmp .phase_entry

.no_key:
    ; Check if terminal dimensions changed while idle (including when paused)
    call term_size_ok
    test eax, eax
    jz .timer_resized           ; Shrunk below 80x24: trigger redraw (enters size gate)
    mov edx, [term_cols]
    cmp edx, [ui_seen_cols]
    jne .timer_resized
    mov edx, [term_rows]
    cmp edx, [ui_seen_rows]
    jne .timer_resized
    jmp .timer_check_paused

.timer_resized:
    xor eax, eax                ; Normal running/paused frame (mode 0)
    call timer_draw
    call buf_flush

.timer_check_paused:
    ; If paused, countdown is frozen: do not advance ticks or seconds
    cmp dword [paused], 1
    je .tick_loop

    ; Running: advance 100ms sub-second tick counter
    inc dword [ticks]
    cmp dword [ticks], TICKS_PER_SECOND
    jb .tick_loop               ; Less than 1 second elapsed: no redraw!

    ; 1 full second elapsed: reset ticks and decrement remaining time
    mov dword [ticks], 0
    dec dword [remaining_secs]

    ; Check if countdown has reached 0
    cmp dword [remaining_secs], 0
    jle .phase_natural_complete

    ; Redraw screen once per second (FR-U4, FR-T5)
    xor eax, eax
    call timer_draw
    call buf_flush
    jmp .tick_loop

.phase_natural_complete:
    ; Natural completion: check if focus completed
    cmp dword [phase], PHASE_FOCUS
    jne .break_natural_complete

    ; Focus phase naturally completed (FR-T6, FR-T8)
    mov dword [focus_completed_flag], 1
    call stats_add_pomodoro
    call anim_on_focus_complete ; Trigger confetti burst only on natural focus complete (Task V7)

    ; Render focus completion frame (mode 2) in a single write
    mov eax, TIMER_FRAME_FOCUS_DONE
    call timer_draw
    call buf_flush

    ; Play focus-complete fanfare (Task V8)
    mov eax, SFX_FOCUS_FANFARE
    call sfx_play

    ; Dispatch configured completion notification layers (Task V9: Bell, Flash, Toast)
    call notify_phase_complete
    mov dword [completion_reminder_ticks], 0

.focus_wait_decision:
    ; Wait for user decision while continuing animation tick
    call time_sleep_100ms
    call anim_tick
    call notify_reminder_tick   ; Check 60s reminder interval
    call key_poll
    cmp eax, KEY_NONE
    je .focus_wait_decision

    cmp eax, KEY_CTRL_C
    je .key_ctrl_c
    cmp eax, KEY_Y
    je .do_quick_note

    ; Any other key (including Q): advance directly to break
    jmp .advance_to_break

.do_quick_note:
    call anim_reset_effects

    ; Redraw frame with note prompt on row 8 (mode 3)
    mov eax, TIMER_FRAME_NOTE_PROMPT
    call timer_draw

    ; Position cursor right after prompt on Row 8
    mov esi, timer_msg_note_input
    call str_len                ; EAX = prompt length
    mov ebx, UI_TIMER_COL_MSG
    add ebx, eax                ; EBX = col right after prompt
    mov eax, UI_TIMER_ROW_MSG
    call ui_goto

    ; Read note text via read_line in cooked mode
    mov edi, line_buf
    mov ecx, JOURNAL_ENTRY_MAX
    call read_line              ; EAX = length of entered text

    ; Empty input cancels silently and continues to break
    test eax, eax
    jz .advance_to_break

    ; Non-empty: call journal_add
    mov esi, line_buf
    call journal_add            ; EAX = 0 ok, -1 err
    test eax, eax
    jnz .note_save_error

    ; Note saved successfully
    mov dword [timer_result_msg], timer_msg_note_saved
    mov dword [timer_result_style], STATUS_OK
    mov eax, SFX_CLICK
    call sfx_play
    jmp .show_note_feedback

.note_save_error:
    mov dword [timer_result_msg], err_could_not_save
    mov dword [timer_result_style], STATUS_ERR
    mov eax, SFX_ERROR_BOOP
    call sfx_play

.show_note_feedback:
    ; Redraw completion frame with feedback message (mode 4)
    ; This redraw wipes cooked mode echo residue
    mov eax, TIMER_FRAME_NOTE_RESULT
    call timer_draw
    call buf_flush

    ; Wait for keypress before advancing to break
    call key_wait
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c
    jmp .advance_to_break

.break_natural_complete:
    ; Break phase naturally completed (FR-T6)
    call anim_reset_effects
    mov eax, TIMER_FRAME_BREAK_DONE
    call timer_draw
    call buf_flush

    ; Play break chime (Task V8)
    mov eax, SFX_BREAK_CHIME
    call sfx_play

    ; Dispatch configured completion notification layers (Task V9: Bell, Flash, Toast)
    call notify_phase_complete
    mov dword [completion_reminder_ticks], 0

.break_wait_decision:
    ; Wait for user input while ticking animation
    call time_sleep_100ms
    call anim_tick
    call notify_reminder_tick   ; Check 60s reminder interval
    call key_poll
    cmp eax, KEY_NONE
    je .break_wait_decision

    cmp eax, KEY_CTRL_C
    je .key_ctrl_c
    cmp eax, KEY_Q
    je .key_q

.advance_to_break:
    ; Advance phase and session counter
    call anim_reset_effects
    call timer_advance_phase
    jmp .phase_entry

.timer_exit:
    call anim_reset_effects
    call notify_clear_external
    pop eax
    restore_regs
    ret

; =============================================================================
; Task V9 Notification & Terminal Integration Procedures (PRD_V2 §10, §14)
; =============================================================================

;=============================================================================
; Procedure: notify_phase_complete
; Purpose:   Dispatches configured notification layers on natural phase completion:
;            - Layer 1 (Bell): 0x07 emitted if NOTIFY_LAYER_BELL bit set in
;              setting_notify_layers (independent of master flag).
;            - Layers 2..5 (Flash, Toast): gated by master flag setting_notify:
;              - Layer 2 (Flash): ESC[?5h -> 150ms sleep -> ESC[?5l (permitted standalone write).
;              - Layer 5 (Desktop toast): notify-send or WSL PowerShell via proc_spawn.
;            Does not crash, terminate application, or alter timer semantics.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_phase_complete:
    save_regs

    ; Layer 1: Terminal Bell (gated independently by NOTIFY_LAYER_BELL bit)
    test byte [setting_notify_layers], NOTIFY_LAYER_BELL
    jz .check_master_notify
    syscall SYS_WRITE, FD_STDOUT, sfx_bell_char, 1

.check_master_notify:
    ; Master notification flag (setting_notify) gates layers 2..5
    cmp byte [setting_notify], 1
    jne .complete_done

    ; Layer 2: Screen Flash
    test byte [setting_notify_layers], NOTIFY_LAYER_FLASH
    jz .check_toast
    call notify_screen_flash

.check_toast:
    ; Layer 5: Desktop Toast
    test byte [setting_notify_layers], NOTIFY_LAYER_TOAST
    jz .complete_done
    call notify_desktop_toast

.complete_done:
    restore_regs
    ret

;=============================================================================
; Procedure: notify_screen_flash
; Purpose:   Activates terminal screen flash for ~150 ms using sys_nanosleep,
;            then deactivates it. This is the ONE explicitly permitted standalone
;            terminal write outside the normal frame buffer flush.
;            Guarantees deactivation sequence is written.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_screen_flash:
    save_regs

    ; Write activation sequence ESC[?5h (length 5)
    syscall SYS_WRITE, FD_STDOUT, ansi_flash_on, 5

    ; Sleep ~150 ms via sys_nanosleep (0 sec, 150,000,000 nsec)
    mov dword [flash_timespec], 0
    mov dword [flash_timespec + 4], FLASH_DELAY_NS
    syscall SYS_NANOSLEEP, flash_timespec, 0

    ; Write deactivation sequence ESC[?5l (length 5)
    syscall SYS_WRITE, FD_STDOUT, ansi_flash_off, 5

    restore_regs
    ret

;=============================================================================
; Procedure: notify_title_update
; Purpose:   Appends the current window-title escape sequence to out_buf:
;            - If disabled (setting_notify == 0 or title layer bit cleared): no-op.
;            - On completion (modes 1..4): ESC]0;Pawmodoro - Time's up! BEL
;            - During timer phase (mode 0): ESC]0;Pawmodoro - <PHASE> MM:SS BEL
;            Integrated into normal frame rendering; no standalone sys_write.
; IN:        EAX = Frame mode (0 = running, 1..4 = completion / note)
; OUT:       Appends title sequence to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_title_update:
    save_regs
    push eax                    ; [esp] = frame mode

    ; Gating: Master notify flag must be enabled AND title layer bit (0x04) set
    cmp byte [setting_notify], 1
    jne .title_done
    test byte [setting_notify_layers], NOTIFY_LAYER_TITLE
    jz .title_done

    mov edx, [esp]              ; EDX = frame mode
    test edx, edx
    jz .title_running

    ; Completion title: ESC]0;Pawmodoro - Time's up! BEL
    mov esi, ansi_title_done
    call buf_str
    jmp .title_done

.title_running:
    ; Active countdown title: ESC]0;Pawmodoro - <PHASE> MM:SS BEL
    mov esi, ansi_title_prefix
    call buf_str

    ; Append uppercase phase name
    mov edx, [phase]
    cmp edx, PHASE_SHORT_BREAK
    je .title_phase_sb
    cmp edx, PHASE_LONG_BREAK
    je .title_phase_lb
    mov esi, title_phase_focus
    call buf_str
    jmp .title_time

.title_phase_sb:
    mov esi, title_phase_short
    call buf_str
    jmp .title_time

.title_phase_lb:
    mov esi, title_phase_long
    call buf_str

.title_time:
    ; Format remaining_secs as MM:SS (guaranteed non-negative)
    mov eax, [remaining_secs]
    test eax, eax
    jns .title_sec_valid
    xor eax, eax

.title_sec_valid:
    xor edx, edx
    mov ecx, 60
    div ecx                     ; EAX = minutes, EDX = seconds
    push edx                    ; Save seconds

    ; Format minutes (2 digits)
    xor edx, edx
    mov ecx, 10
    div ecx                     ; EAX = tens, EDX = ones
    add al, '0'
    call buf_char
    add dl, '0'
    mov al, dl
    call buf_char

    ; Colon separator
    mov al, ':'
    call buf_char

    ; Format seconds (2 digits)
    pop eax                     ; EAX = seconds
    xor edx, edx
    mov ecx, 10
    div ecx                     ; EAX = tens, EDX = ones
    add al, '0'
    call buf_char
    add dl, '0'
    mov al, dl
    call buf_char

    ; Terminating BEL (0x07)
    mov al, CHAR_BELL
    call buf_char

.title_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: notify_progress_update
; Purpose:   Appends Windows Terminal OSC 9;4 taskbar progress sequence to out_buf:
;            - If disabled: no-op.
;            - If completion mode (1..4) or paused (paused == 1): ESC]9;4;0;0 BEL (clear)
;            - If running: ESC]9;4;1;<percent> BEL (0..100)
;            Integrated into normal frame rendering; no standalone sys_write.
; IN:        EAX = Frame mode (0 = running, 1..4 = completion / note)
; OUT:       Appends taskbar progress sequence to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_progress_update:
    save_regs
    push eax

    ; Gating: Master notify flag must be enabled AND progress layer bit (0x08) set
    cmp byte [setting_notify], 1
    jne .progress_done
    test byte [setting_notify_layers], NOTIFY_LAYER_PROGRESS
    jz .progress_done

    mov edx, [esp]              ; EDX = frame mode
    test edx, edx
    jnz .progress_clear         ; Completion screen: clear progress

    cmp dword [paused], 1
    je .progress_clear          ; Paused: clear taskbar progress per requirements

    ; Calculate active percentage: (elapsed * 100) / total_secs
    mov ecx, [total_secs]
    test ecx, ecx
    jz .progress_clear          ; Avoid division by zero!

    mov eax, [remaining_secs]
    cmp eax, ecx
    ja .progress_zero_pct       ; remaining > total (sanity check)

    mov edx, ecx
    sub edx, eax                ; EDX = elapsed seconds
    imul edx, 100               ; EDX = elapsed * 100
    mov eax, edx
    xor edx, edx
    div ecx                     ; EAX = percentage (0..100)

    cmp eax, 100
    jbe .progress_emit
    mov eax, 100
    jmp .progress_emit

.progress_zero_pct:
    xor eax, eax

.progress_emit:
    push eax                    ; Save percent
    mov esi, ansi_taskbar_prefix_running
    call buf_str
    pop eax
    call buf_u32
    mov al, CHAR_BELL
    call buf_char
    jmp .progress_done

.progress_clear:
    mov esi, ansi_taskbar_clear
    call buf_str

.progress_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: notify_clear_external
; Purpose:   Resets external notification state:
;            - Clears Windows Terminal taskbar progress (ESC]9;4;0;0 BEL).
;            - Restores window title to "Pawmodoro" (ESC]0;Pawmodoro BEL).
;            Flushes immediately to ensure clean external state on menu return or exit.
;            Idempotent and safe to call multiple times.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_clear_external:
    save_regs

    ; Discard any pending frame buffer and append clear sequences
    mov dword [out_len], 0
    mov esi, ansi_taskbar_clear
    call buf_str
    mov esi, ansi_title_restore
    call buf_str
    call buf_flush

    restore_regs
    ret

;=============================================================================
; Procedure: notify_desktop_toast
; Purpose:   Sends an asynchronous desktop notification on phase completion:
;            1. Probes for /usr/bin/notify-send using sys_access (X_OK).
;               If available, spawns notify-send with title and phase-specific body.
;            2. If unavailable, probes for WSL PowerShell fallback
;               /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe.
;               If available, spawns PowerShell balloon tip notification.
;            3. If neither available or spawn fails, fails silently without error.
; IN:        None (uses current [phase] to select message body)
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_desktop_toast:
    save_regs

    ; Probe Linux /usr/bin/notify-send via sys_access (syscall 33, X_OK = 1)
    syscall SYS_ACCESS, notif_send_path, X_OK
    test eax, eax
    jnz .try_wsl_toast

    ; Linux notify-send is available: choose focus or break message
    mov esi, notif_send_path
    mov edi, notif_argv_focus
    cmp dword [phase], PHASE_FOCUS
    je .toast_spawn
    mov edi, notif_argv_break
    jmp .toast_spawn

.try_wsl_toast:
    ; Probe experimental WSL PowerShell executable
    syscall SYS_ACCESS, powershell_path, X_OK
    test eax, eax
    jnz .toast_done             ; No desktop notification mechanism available

    mov esi, powershell_path
    mov edi, powershell_argv_focus
    cmp dword [phase], PHASE_FOCUS
    je .toast_spawn
    mov edi, powershell_argv_break

.toast_spawn:
    ; Asynchronously spawn notification process via generalized proc_spawn
    call proc_spawn

.toast_done:
    restore_regs
    ret

;=============================================================================
; Procedure: notify_reminder_tick
; Purpose:   Counts 100ms ticks during completion-wait screens.
;            Every 60 seconds (NOTIFY_REMINDER_TICKS = 600 ticks), re-dispatches
;            enabled completion notifications (bell, flash, desktop toast)
;            without restarting the timer or dropping user keystrokes.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
notify_reminder_tick:
    save_regs

    inc dword [completion_reminder_ticks]
    cmp dword [completion_reminder_ticks], NOTIFY_REMINDER_TICKS
    jb .reminder_done

    ; 60 seconds elapsed: reset counter and re-dispatch alerts
    mov dword [completion_reminder_ticks], 0
    call notify_phase_complete

.reminder_done:
    restore_regs
    ret
