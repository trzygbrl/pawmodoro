; =============================================================================
; Pawmodoro - Data and Memory Buffers (src/data.asm)
;
; Purpose: Static string definitions (ANSI escape sequences) and runtime memory
;          allocations in .bss per PRD §3.3 and §6.5.
; =============================================================================

; =============================================================================
; DATA SECTION (.data) - Static Read-Only / Initialized Assets
; =============================================================================
section .data

    ; -------------------------------------------------------------------------
    ; Terminal Control ANSI Escape Sequences (PRD §3.3)
    ; All strings are NUL-terminated for compatibility with buf_str and str_len.
    ; -------------------------------------------------------------------------
    ansi_clear:             db CHAR_ESC, "[2J", CHAR_NULL       ; Clear entire screen
    ansi_home:              db CHAR_ESC, "[H", CHAR_NULL        ; Move cursor to (1,1)
    ansi_erase_eol:         db CHAR_ESC, "[K", CHAR_NULL        ; Erase from cursor to EOL
    ansi_hide_cursor:       db CHAR_ESC, "[?25l", CHAR_NULL     ; Hide cursor
    ansi_show_cursor:       db CHAR_ESC, "[?25h", CHAR_NULL     ; Show cursor
    ansi_alt_on:            db CHAR_ESC, "[?1049h", CHAR_NULL   ; Switch to alternate screen buffer
    ansi_alt_off:           db CHAR_ESC, "[?1049l", CHAR_NULL   ; Switch to standard screen buffer
    ansi_reset:             db CHAR_ESC, "[0m", CHAR_NULL       ; Reset all attributes/colors
    ansi_bold:              db CHAR_ESC, "[1m", CHAR_NULL       ; Enable bold font weight
    ansi_bell:              db CHAR_BELL, CHAR_NULL             ; Terminal audio bell (0x07)

    ; -------------------------------------------------------------------------
    ; 16-Color Terminal Foreground Sequences (PRD §3.3)
    ; Standard colors (30-37m)
    ; -------------------------------------------------------------------------
    ansi_fg_black:          db CHAR_ESC, "[30m", CHAR_NULL
    ansi_fg_red:            db CHAR_ESC, "[31m", CHAR_NULL
    ansi_fg_green:          db CHAR_ESC, "[32m", CHAR_NULL
    ansi_fg_yellow:         db CHAR_ESC, "[33m", CHAR_NULL
    ansi_fg_blue:           db CHAR_ESC, "[34m", CHAR_NULL
    ansi_fg_magenta:        db CHAR_ESC, "[35m", CHAR_NULL
    ansi_fg_cyan:           db CHAR_ESC, "[36m", CHAR_NULL
    ansi_fg_white:          db CHAR_ESC, "[37m", CHAR_NULL

    ; Bright / High-Intensity colors (90-97m)
    ansi_fg_bright_black:   db CHAR_ESC, "[90m", CHAR_NULL
    ansi_fg_bright_red:     db CHAR_ESC, "[91m", CHAR_NULL
    ansi_fg_bright_green:   db CHAR_ESC, "[92m", CHAR_NULL
    ansi_fg_bright_yellow:  db CHAR_ESC, "[93m", CHAR_NULL
    ansi_fg_bright_blue:    db CHAR_ESC, "[94m", CHAR_NULL
    ansi_fg_bright_magenta: db CHAR_ESC, "[95m", CHAR_NULL
    ansi_fg_bright_cyan:    db CHAR_ESC, "[96m", CHAR_NULL
    ansi_fg_bright_white:   db CHAR_ESC, "[97m", CHAR_NULL

; =============================================================================
; BSS SECTION (.bss) - Uninitialized Runtime Buffers (PRD §6.5)
; =============================================================================
section .bss

    ; Output aggregation frame buffer and length tracker
    out_buf:                resb OUT_BUF_SIZE           ; 8192 bytes
    out_len:                resd 1                      ; Bytes currently written to out_buf

    ; Terminal & Line input buffers
    in_buf:                 resb IN_BUF_SIZE            ; 16 bytes
    line_buf:               resb LINE_BUF_SIZE          ; 256 bytes

    ; File I/O persistence buffers
    file_buf:               resb FILE_BUF_SIZE          ; 512 bytes
    jrnl_buf:               resb JRNL_BUF_SIZE          ; 4096 bytes

    ; Terminal termios state records
    termios_orig:           resb TERMIOS_SIZE           ; 36 bytes (saved cooked mode)
    termios_raw:            resb TERMIOS_SIZE           ; 36 bytes (configured raw mode)

    ; Sleep duration timer structure
    timespec:               resb TIMESPEC_SIZE          ; 8 bytes {tv_sec, tv_nsec}

    ; Application state variables
    state:                  resd 1                      ; Current application state (STATE_*)
    demo_mode:              resd 1                      ; Demo mode flag (0 = off, 1 = on)
    phase:                  resd 1                      ; Current timer phase
    session_no:             resd 1                      ; Focus session counter (1..4)
    ticks:                  resd 1                      ; Sub-second elapsed ticks
    paused:                 resd 1                      ; Timer paused flag (0 = running, 1 = paused)

; =============================================================================
; Task 2 Terminal Control Additions
; =============================================================================
section .data
    err_not_a_tty:          db "Error: Standard input is not a terminal.", CHAR_LF
    err_not_a_tty_len:      equ $ - err_not_a_tty

section .bss
    term_active:            resd 1                      ; Terminal active flag (1 = active, 0 = restored)

; =============================================================================
; Task 3 Time & Date Buffers (PRD §6.4)
; =============================================================================
    date_buf:               resb DATE_BUF_SIZE          ; 11 bytes: "YYYY-MM-DD\0"
    time_buf:               resb TIME_BUF_SIZE          ; 6 bytes: "HH:MM\0"

; =============================================================================
; Task 4 Shell & UI Data Assets (PRD §4.1, §5, §6.4)
; =============================================================================
section .data

    ; ANSI Sequence: Erase from cursor to end of screen (PRD §3.3)
    ansi_erase_eos:         db CHAR_ESC, "[J", CHAR_NULL        ; Erase from cursor to end of screen

    ; Cat ASCII Art Poses (PRD §6.4, 3 lines per pose, <= 11 columns wide)
    ; Pose 0: Idle cat (Main Menu)
    cat_p0_l1:              db " /\_/\ ", CHAR_NULL
    cat_p0_l2:              db "( o.o )", CHAR_NULL
    cat_p0_l3:              db " > ^ < ", CHAR_NULL

    ; Pose 1: Working cat with focused/closed eyes (Pomodoro focus)
    cat_p1_l1:              db " /\_/\ ", CHAR_NULL
    cat_p1_l2:              db "( -.- )", CHAR_NULL
    cat_p1_l3:              db " > ^ < ", CHAR_NULL

    ; Pose 2: Resting/sleeping cat (Pomodoro break)
    cat_p2_l1:              db " /\_/\   z", CHAR_NULL
    cat_p2_l2:              db "( u.u )  Z", CHAR_NULL
    cat_p2_l3:              db " > ^ < ", CHAR_NULL

    ; Main Menu UI Strings (PRD §5)
    menu_title:             db "P A W M O D O R O", CHAR_NULL
    menu_tagline:           db "cozy focus - habits - notes", CHAR_NULL
    dash_lbl_today:         db "Today: ", CHAR_NULL
    dash_lbl_pomos:         db " pomodoros      Habits: ", CHAR_NULL
    dash_lbl_done:          db " done", CHAR_NULL

    menu_item_1:            db "[1] Start focus session", CHAR_NULL
    menu_item_2:            db "[2] Habit tracker", CHAR_NULL
    menu_item_3:            db "[3] Journal", CHAR_NULL
    menu_item_4_prefix:     db "[4] Demo mode: ", CHAR_NULL
    menu_demo_off:          db "OFF", CHAR_NULL
    menu_demo_on:           db "ON", CHAR_NULL
    menu_item_q:            db "[Q] Quit", CHAR_NULL

    ; Stub Screen Titles & Content (PRD §5)
    title_timer:            db "FOCUS TIMER", CHAR_NULL
    title_habits:           db "HABIT TRACKER", CHAR_NULL
    title_journal:          db "JOURNAL", CHAR_NULL
    stub_msg:               db "Coming soon — press B to go back", CHAR_NULL
    stub_key_help:          db "[B] Back", CHAR_NULL

    ; Dashboard summary statistics placeholders (T6/T7 will replace with real data)
    dash_pomodoros:         dd 3
    dash_habits_done:       dd 2
    dash_habits_total:      dd 4

section .bss

    ; Cat ASCII art position coordinates (implicit inputs to ui_draw_cat)
    cat_row:                resd 1                      ; Row coordinate (1-based)
    cat_col:                resd 1                      ; Column coordinate (1-based)

    ; Screen redraw tracking flag (1 = redraw needed, 0 = clean)
    need_redraw:            resd 1                      ; Redraw dirty flag

; =============================================================================
; Task 5 Pomodoro Timer Strings and Buffers (PRD §4.2, §5, §6.4)
; =============================================================================
section .data

    ; Timer Phase Titles
    timer_lbl_focus:            db "FOCUS", CHAR_NULL
    timer_lbl_short:            db "SHORT BREAK", CHAR_NULL
    timer_lbl_long:             db "LONG BREAK", CHAR_NULL

    ; Title formatting strings
    timer_lbl_session_prefix:   db " - Session ", CHAR_NULL
    timer_lbl_session_suffix:   db " of 4", CHAR_NULL
    timer_lbl_demo:             db "[DEMO]", CHAR_NULL

    ; Timer Status Strings
    timer_lbl_paused:           db "PAUSED", CHAR_NULL

    ; Key Help Prompts
    timer_help_running:         db "[P] Pause    [S] Skip    [Q] Stop and go back", CHAR_NULL
    timer_help_paused:          db "[P] Resume   [S] Skip    [Q] Stop and go back", CHAR_NULL

    ; Phase Completion Messages (ASCII only, no UTF-8)
    timer_msg_focus_done:       db "Focus complete! Press any key for a break.", CHAR_NULL
    timer_msg_break_done:       db "Break over! Press any key to focus.", CHAR_NULL

    ; Duration Tables Indexed by Phase (PHASE_FOCUS=0, PHASE_SHORT_BREAK=1, PHASE_LONG_BREAK=2)
    timer_durations_normal:
        dd TIMER_FOCUS_SECS             ; 1500 seconds (25 minutes)
        dd TIMER_SHORT_BREAK_SECS       ; 300 seconds (5 minutes)
        dd TIMER_LONG_BREAK_SECS        ; 900 seconds (15 minutes)

    timer_durations_demo:
        dd TIMER_DEMO_FOCUS_SECS        ; 10 seconds
        dd TIMER_DEMO_SHORT_BREAK_SECS  ; 5 seconds
        dd TIMER_DEMO_LONG_BREAK_SECS   ; 8 seconds

    ; Phase Title Pointers Table Indexed by Phase
    timer_phase_titles:
        dd timer_lbl_focus
        dd timer_lbl_short
        dd timer_lbl_long

    ; Cat Pose Table Indexed by Phase (Pose 1 = Working, Pose 2 = Resting)
    timer_phase_poses:
        dd CAT_POSE_WORKING             ; Focus -> Working pose
        dd CAT_POSE_RESTING             ; Short Break -> Resting pose
        dd CAT_POSE_RESTING             ; Long Break -> Resting pose

section .bss

    ; Runtime Timer Variables
    remaining_secs:             resd 1  ; Remaining seconds in current phase
    total_secs:                 resd 1  ; Total duration in seconds for current phase
    focus_completed_flag:       resd 1  ; Set to 1 on natural focus completion, 0 on skip/start

