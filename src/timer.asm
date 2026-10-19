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
    save_regs
    push eax                    ; [esp] = frame mode (0..4)

    ; -------------------------------------------------------------------------
    ; Phase 1: Draw Frame Borders and Erase Inner Rows (FR-U4)
    ; -------------------------------------------------------------------------
    ; Start frame at home position (1, 1)
    mov eax, UI_TIMER_ROW_TOP
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto

    ; Row 1: Top border line
    mov eax, UI_TIMER_ROW_TOP
    call ui_frame_hline

    ; Rows 2..9: Erase each row with ESC[K and anchor right border '|' at col 56
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
    mov ebx, UI_FRAME_COL_LEFT
    call buf_goto
    mov esi, ansi_erase_eos
    call buf_str

    ; -------------------------------------------------------------------------
    ; Phase 2: Overlay Content at Absolute Cursor Coordinates
    ; -------------------------------------------------------------------------
    ; 1. Title Row (Row 2, Col 4): "<PHASE> - Session n of 4"
    mov eax, UI_TIMER_ROW_TITLE
    mov ebx, UI_TIMER_COL_TITLE
    call buf_goto

    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_cyan
    call buf_str

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

    ; 2. [DEMO] badge at (Row 2, Col 46) if demo_mode == 1
    cmp dword [demo_mode], 1
    jne .skip_demo_badge

    mov eax, UI_TIMER_ROW_TITLE
    mov ebx, UI_TIMER_COL_DEMO
    call buf_goto
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_green
    call buf_str
    mov esi, timer_lbl_demo
    call buf_str
    mov esi, ansi_reset
    call buf_str

.skip_demo_badge:
    ; 3. Cat ASCII art at Row 4, Col 6 (Working pose for Focus, Resting for Breaks)
    mov dword [cat_row], UI_TIMER_ROW_CAT1
    mov dword [cat_col], UI_TIMER_COL_CAT
    mov edx, [phase]
    mov eax, [timer_phase_poses + edx*4]
    call ui_draw_cat

    ; 4. Time display MM:SS at Row 5, Col 20 (beside middle cat row)
    mov eax, UI_TIMER_ROW_CAT2
    mov ebx, UI_TIMER_COL_TIME
    call buf_goto

    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_white
    call buf_str
    mov eax, [remaining_secs]
    call buf_mmss
    mov esi, ansi_reset
    call buf_str

    ; 5. "PAUSED" indicator at Row 5, Col 27 if paused == 1
    cmp dword [paused], 1
    jne .skip_paused_label

    mov eax, UI_TIMER_ROW_CAT2
    mov ebx, UI_TIMER_COL_PAUSED
    call buf_goto
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_yellow
    call buf_str
    mov esi, timer_lbl_paused
    call buf_str
    mov esi, ansi_reset
    call buf_str

.skip_paused_label:
    ; 6. Progress bar at Row 7, Col 5 (elapsed = total - remaining)
    mov eax, UI_TIMER_ROW_PROGRESS
    mov ebx, UI_TIMER_COL_PROGRESS
    call buf_goto

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
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
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
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov esi, timer_help_break_done
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .help_done

.help_mode_focus_done:
    mov eax, UI_TIMER_ROW_HELP
    mov ebx, UI_TIMER_COL_HELP
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov esi, timer_help_focus_prompt
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .help_done

.help_mode_note_result:
    mov eax, UI_TIMER_ROW_HELP
    mov ebx, UI_TIMER_COL_HELP
    call buf_goto
    mov esi, ansi_fg_cyan
    call buf_str
    mov esi, timer_help_note_result
    call buf_str
    mov esi, ansi_reset
    call buf_str

.help_done:
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

.phase_entry:
    call timer_phase_start

.tick_loop:
    ; Low-CPU 100ms sleep via sys_nanosleep (FR-T5)
    call time_sleep_100ms

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
    mov dword [state], STATE_QUIT
    jmp .timer_exit

.key_q:
    ; Stop timer: set STATE_MENU and return to main shell
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
    ; Skip current phase early
    call timer_skip_phase
    jmp .phase_entry

.no_key:
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

    ; Render focus completion frame (mode 2) with bell in a single write
    mov eax, TIMER_FRAME_FOCUS_DONE
    call timer_draw
    mov esi, ansi_bell
    call buf_str
    call buf_flush

    ; Wait for user decision
    call key_wait
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c
    cmp eax, KEY_Y
    je .do_quick_note

    ; Any other key (including Q): advance directly to break
    jmp .advance_to_break

.do_quick_note:
    ; Redraw frame with note prompt on row 8 (mode 3)
    mov eax, TIMER_FRAME_NOTE_PROMPT
    call timer_draw

    ; Position cursor right after prompt on Row 8
    mov esi, timer_msg_note_input
    call str_len                ; EAX = prompt length
    mov ebx, UI_TIMER_COL_MSG
    add ebx, eax                ; EBX = col right after prompt
    mov eax, UI_TIMER_ROW_MSG
    call buf_goto

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
    jmp .show_note_feedback

.note_save_error:
    mov dword [timer_result_msg], err_could_not_save
    mov dword [timer_result_style], STATUS_ERR

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
    mov eax, TIMER_FRAME_BREAK_DONE
    call timer_draw
    mov esi, ansi_bell
    call buf_str
    call buf_flush

    ; Wait for user input: Q stops and returns to menu, any other key continues
    call key_wait
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c
    cmp eax, KEY_Q
    je .key_q

.advance_to_break:
    ; Advance phase and session counter
    call timer_advance_phase
    jmp .phase_entry

.timer_exit:
    pop eax
    restore_regs
    ret
