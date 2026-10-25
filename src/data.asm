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
    ansi_reverse:           db CHAR_ESC, "[7m", CHAR_NULL       ; Enable reverse video (highlighting)
    ansi_bell:              db CHAR_BELL, CHAR_NULL             ; Terminal audio bell (0x07)
    ansi_csi:               db CHAR_ESC, "[", CHAR_NULL         ; Control Sequence Introducer (CSI)

    ; -------------------------------------------------------------------------
    ; G1 Rendering Core State & Diagnostics (PRD_V3 §4.2, §5.1, §7.2, §10)
    ; -------------------------------------------------------------------------
    global gfx_overflow
    global gfx_frame_bytes
    global gfx_fg
    global gfx_bg
    global term_has_ech

    gfx_overflow:           dd 0            ; Output buffer overflow flag (0=ok, 1=overflow)
    gfx_frame_bytes:        dd 0            ; Transmitted byte count of most recent frame
    gfx_fg:                 dw GFX_SLOT_UNKNOWN ; Current tracked foreground theme-slot ID
    gfx_bg:                 dw GFX_SLOT_UNKNOWN ; Current tracked background theme-slot ID
    term_has_ech:           dd 1            ; Terminal ECH capability flag (1=supported, 0=fallback)

    ; G1 Demo & Diagnostic Strings
    gfx_demo_title:         db "Pawmodoro v3 G1 Render Core Demo", CHAR_NULL
    gfx_demo_subtitle:      db "Primitives: fill_screen_bg, fill_rect, hline, vline, text_clip", CHAR_NULL
    gfx_demo_long:          db "This is a very long string designed to test display column clipping to 20 cols", CHAR_NULL
    gfx_demo_hint:          db "Press any key to return to Main Menu...", CHAR_NULL
    str_flag_test_overflow: db "--test-overflow", CHAR_NULL

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
    out_buf:                resb OUT_BUF_SIZE           ; 16384 bytes
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

    ; Pose 3: Happy cat (Pomodoro complete, habit check-in)
    cat_p3_l1:              db " /\_/\ ", CHAR_NULL
    cat_p3_l2:              db "( ^.^ )", CHAR_NULL
    cat_p3_l3:              db " > * < ", CHAR_NULL

    ; Pose 4: Surprised cat (error, confirmation)
    cat_p4_l1:              db " /\_/\ ", CHAR_NULL
    cat_p4_l2:              db "( O.O )", CHAR_NULL
    cat_p4_l3:              db " > o < ", CHAR_NULL

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
    menu_item_5:            db "[5] Settings", CHAR_NULL
    menu_item_q:            db "[Q] Quit", CHAR_NULL

    ; Stub Screen Titles & Content (PRD §5)
    title_timer:            db "FOCUS TIMER", CHAR_NULL
    title_habits:           db "HABIT TRACKER", CHAR_NULL
    title_journal:          db "JOURNAL", CHAR_NULL
    stub_msg:               db "Coming soon — press B to go back", CHAR_NULL
    stub_key_help:          db "[B] Back", CHAR_NULL

    ; Dashboard summary statistics placeholders (T6/T7 will replace with real data)
    dash_pomodoros:         dd 0
    dash_habits_done:       dd 0
    dash_habits_total:      dd 0

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
    timer_lbl_paused:           db "[PAUSED]", CHAR_NULL
    timer_lbl_cycle_prefix:     db "Cycle: ", CHAR_NULL

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

; =============================================================================
; Task 6 File Persistence & Pomodoro Statistics (PRD §4.5 FR-D2, FR-D4)
; =============================================================================
section .data

    ; File Paths (relative to current working directory)
    path_stats:                 db "stats.dat", CHAR_NULL

    ; Error & Warning Messages
    err_could_not_save:         db "Could not save", CHAR_NULL

section .bss

    ; Contiguous 12-byte stats.dat record structure (PRD §4.5 FR-D2)
    ; Layout: day (dword, offset 0), today_count (dword, offset 4), total_count (dword, offset 8)
    stats_data:
    stats_day:                  resd 1          ; Day number of last completed session
    stats_today_count:          resd 1          ; Completed focus sessions today
    stats_total_count:          resd 1          ; All-time completed focus sessions

    ; Persistence Status Flag (0 = OK, 1 = Save Failed)
    stats_save_failed:          resd 1          ; Save failure indicator for timer UI

; =============================================================================
; Task 7 Habit Tracker Data & Buffers (PRD §4.3, §4.5 FR-D3)
; =============================================================================
section .data

    ; File Paths (relative to current working directory)
    path_habits:                db "habits.dat", CHAR_NULL

    ; Screen Headers & UI Labels
    habits_hdr:                 db "#  HABIT        LAST 7 DAYS         STREAK TOTAL", CHAR_NULL
    habits_hdr_num:             db "#", CHAR_NULL
    habits_hdr_name:            db "HABIT", CHAR_NULL
    habits_hdr_squares:         db "LAST 7 DAYS", CHAR_NULL
    habits_hdr_streak:          db "STREAK", CHAR_NULL
    habits_hdr_total:           db "TOTAL", CHAR_NULL
    habits_help:                db "[A] Add  [1-8] Check in today  [D] Delete  [B] Back", CHAR_NULL

    ; Feedback and Status Messages (ASCII only)
    habit_msg_empty:            db "No habits yet - press A to add one.", CHAR_NULL
    habit_msg_checked_in:       db "Checked in!", CHAR_NULL
    habit_msg_already:          db "Already done today", CHAR_NULL
    habit_msg_full:             db "Habit list full (max 8)", CHAR_NULL
    habit_msg_no_habit:         db "No such habit", CHAR_NULL
    habit_msg_no_delete:        db "No habits to delete", CHAR_NULL
    habit_msg_deleted:          db "Habit deleted", CHAR_NULL
    habit_msg_add_prompt:       db "New habit name (max 31, Enter alone cancels): ", CHAR_NULL
    habit_msg_del_prompt:       db "Delete which habit? (1-N, other key cancels): ", CHAR_NULL

section .bss

    ; Contiguous habit storage block for habits.dat (PRD §4.3 FR-H1, §4.5 FR-D3)
    ; Layout: count (dword, 0..8) followed by 8 records of 48 bytes (384 bytes)
    ; Total size = 388 bytes (dedicated persistent store)
    habit_data:
    habit_count:                resd 1
    habit_records:              resb (MAX_HABITS * HABIT_RECORD_SIZE)

    ; Runtime UI message pointer (0 = none, or pointer to NUL-terminated ASCII string)
    habit_msg:                  resd 1

; =============================================================================
; Task 8 & V3 Journal Subsystem Data & Buffers (PRD §4.4, §4.5, PRD_V2 §7, §12)
; =============================================================================
section .data

    ; File Paths (relative to current working directory)
    path_journal:               db "journal.txt", CHAR_NULL
    path_journal_tmp:           db "journal.tmp", CHAR_NULL

    ; UI Strings & Help Prompts
    jrnl_help:                  db "[Up/Dn] Move  [PgUp/Dn] Page  [Enter] View  [D] Del  [N] New  [B] Back", CHAR_NULL
    jrnl_help_full:             db "[Enter / B] Back to list   [D] Delete entry", CHAR_NULL
    jrnl_title_full:            db "JOURNAL - FULL ENTRY", CHAR_NULL
    jrnl_msg_initial_hint:      db "Press V to view recent entries.", CHAR_NULL
    jrnl_msg_empty:             db "No entries yet.", CHAR_NULL
    jrnl_msg_new_prompt:        db "New entry (max 200, Enter alone cancels): ", CHAR_NULL
    jrnl_msg_del_prompt:        db "Delete this entry? (y/n)", CHAR_NULL
    jrnl_msg_saved:             db "Entry saved", CHAR_NULL
    jrnl_msg_deleted:           db "Entry deleted", CHAR_NULL
    jrnl_msg_could_not_delete:  db "Could not delete", CHAR_NULL
    jrnl_sep:                   db " | ", CHAR_NULL
    jrnl_indent_str:            db "    ", CHAR_NULL

section .bss

    ; Runtime UI message pointer (0 = none, or pointer to NUL-terminated ASCII string)
    jrnl_msg:                   resd 1

    ; View state tracking (0 = unviewed/initial hint, 1 = recent entries loaded)
    jrnl_view_active:           resd 1

    ; Number of bytes loaded into jrnl_buf during active window read
    jrnl_bytes_loaded:          resd 1

    ; Whether the loaded window began in the middle of a file (file size > window size)
    jrnl_tail_partial:          resd 1

    ; Number of complete lines found in recent view (0..JRNL_MAX_ENTRIES)
    jrnl_line_count:            resd 1

    ; Table of up to 10 (start_ptr, length) pairs for legacy compatibility
    jrnl_lines:                 resd (JOURNAL_VIEW_LINES * 2)

    ; V3 Journal state & navigation variables (PRD_V2 §7, §12)
    jrnl_sel_idx:               resd 1          ; Selected entry index (0..jrnl_line_count - 1)
    jrnl_top_idx:               resd 1          ; First visible entry index in list view
    jrnl_window_offset:         resd 1          ; Absolute file byte offset of jrnl_buf[0]
    jrnl_file_size:             resd 1          ; Total file size in bytes
    jrnl_full_view:             resd 1          ; 1 = Full entry modal view, 0 = List view
    jrnl_confirm_del:           resd 1          ; 1 = Delete confirmation active, 0 = normal

    ; Table of up to JRNL_MAX_ENTRIES (32) entry records (4 dwords each = 16 bytes per entry):
    ; Offset +0:  entry_start_ptr (pointer into jrnl_buf)
    ; Offset +4:  entry_text_len  (length in bytes excluding LF)
    ; Offset +8:  entry_file_off  (absolute byte offset in journal.txt)
    ; Offset +12: entry_file_len  (total byte length in journal.txt including LF)
    jrnl_entries:               resd (JRNL_MAX_ENTRIES * 4)

    ; Dedicated 2 KB copy buffer for atomic file deletion (PRD_V2 §7, §12)
    del_copy_buf:               resb DEL_COPY_BUF_SIZE

; =============================================================================
; Task 9 Integration, Signals, Size Gate, and Status Data & Buffers
; =============================================================================
section .data

    ; Timer Quick-Note & Completion Strings (PRD §4.2 FR-T8)
    timer_msg_focus_prompt:     db "Focus complete! Add a quick note? (y/n)", CHAR_NULL
    timer_msg_note_input:       db "Note (max 200, Enter alone cancels): ", CHAR_NULL
    timer_msg_note_saved:       db "Note saved - press any key for a break.", CHAR_NULL

    timer_help_focus_prompt:    db "[Y] Add note   [Any other key] Continue to break", CHAR_NULL
    timer_help_break_done:      db "[Any key] Continue   [Q] Stop and go back", CHAR_NULL
    timer_help_note_result:     db "[Any key] Continue to break", CHAR_NULL

    ; Terminal Size Warning Strings (PRD §4.1, 80x24 Gate)
    ui_msg_enlarge:             db "Please enlarge the terminal", CHAR_NULL
    ui_msg_need_prefix:         db "(need 80x24, now ", CHAR_NULL
    ui_msg_need_x:              db "x", CHAR_NULL
    ui_msg_need_suffix:         db ")", CHAR_NULL

    ; Main Menu Footer & Demo Status Strings (PRD §5)
    menu_help:                  db "[1-5] Select an option   [Q] Quit", CHAR_NULL
    menu_msg_demo_on:           db "Demo mode ON (10 s focus)", CHAR_NULL
    menu_msg_demo_off:          db "Demo mode OFF", CHAR_NULL

section .bss

    ; Exit Recursion Guard (1 = app_exit in progress, prevents recursive flush errors)
    app_exiting:                resd 1

    ; Terminal Size Gate Structure and Cached Dimensions
    winsize:                    resb WINSIZE_SIZE           ; 8 bytes {ws_row, ws_col, ws_xpixel, ws_ypixel}
    term_cols:                  resd 1                      ; Cached terminal columns
    term_rows:                  resd 1                      ; Cached terminal rows

    ; Adaptive UI layout variables (PRD v2 §2)
    ui_w:                       resd 1                      ; Frame width in columns (min(term_cols - 2, 100))
    ui_h:                       resd 1                      ; Terminal height in rows (term_rows)
    ui_col0:                    resd 1                      ; 0-based horizontal frame margin ((term_cols - ui_w) / 2)
    ui_seen_cols:               resd 1                      ; Last rendered terminal width for resize detection
    ui_seen_rows:               resd 1                      ; Last rendered terminal height for resize detection

    ; Main Menu Status Message Pointer and Style
    menu_msg:                   resd 1                      ; Pointer to status string (0 = none)
    menu_msg_style:             resd 1                      ; STATUS_INFO, STATUS_OK, or STATUS_ERR

    ; Timer Quick-Note Result Message Pointer and Style
    timer_result_msg:           resd 1                      ; Pointer to result string
    timer_result_style:         resd 1                      ; STATUS_OK or STATUS_ERR

; =============================================================================
; Task V4 Theme Engine and Settings Persistence Data & Buffers (PRD_V2 §4, §5)
; =============================================================================
section .data

    ; ANSI 256-Color Escape Prefixes (PRD_V2 §4)
    ; ESC [ 3 8 ; 5 ; <N> m (foreground)
    ansi_fg_256_prefix:         db CHAR_ESC, "[38;5;", CHAR_NULL
    ; ESC [ 4 8 ; 5 ; <N> m (background)
    ansi_bg_256_prefix:         db CHAR_ESC, "[48;5;", CHAR_NULL

    ; Settings Persistence File Path
    path_settings:              db "settings.dat", CHAR_NULL

    ; -------------------------------------------------------------------------
    ; 7 Built-in Theme Palettes (Task V4, PRD_V2 §4)
    ; Exactly 12 bytes each in normative slot order:
    ; 0:BORDER, 1:TITLE, 2:ACCENT, 3:TEXT, 4:DIM, 5:OK, 6:WARN, 7:ERR, 8:CAT,
    ; 9:BAR_FULL, 10:BAR_EMPTY, 11:HIGHLIGHT
    ; -------------------------------------------------------------------------
    themes_table:
        ; Theme 0: Strawberry Milk (default warm look)
        db 211, 204, 218, 254, 244, 114, 221, 203, 223, 204, 238, 53
        ; Theme 1: Matcha Latte
        db 108, 150, 114, 255, 243, 114, 221, 203, 180, 114, 238, 22
        ; Theme 2: Blueberry
        db 69,  111, 75,  255, 244, 114, 221, 203, 117, 75,  238, 17
        ; Theme 3: Lavender Night
        db 141, 183, 147, 253, 243, 114, 221, 203, 225, 141, 237, 54
        ; Theme 4: Sunset Peach
        db 215, 209, 216, 255, 244, 114, 221, 203, 223, 209, 238, 94
        ; Theme 5: Mono Cozy
        db 245, 255, 250, 252, 240, 250, 255, 255, 252, 255, 238, 240
        ; Theme 6: High Contrast
        db 231, 231, 226, 231, 250, 46,  226, 196, 231, 231, 240, 21

    ; Theme Name Strings and Pointer Table (for all 8 themes including Custom)
    theme_name_0:               db "Strawberry Milk", CHAR_NULL
    theme_name_1:               db "Matcha Latte", CHAR_NULL
    theme_name_2:               db "Blueberry", CHAR_NULL
    theme_name_3:               db "Lavender Night", CHAR_NULL
    theme_name_4:               db "Sunset Peach", CHAR_NULL
    theme_name_5:               db "Mono Cozy", CHAR_NULL
    theme_name_6:               db "High Contrast", CHAR_NULL
    theme_name_7:               db "Custom", CHAR_NULL

    theme_names:
        dd theme_name_0
        dd theme_name_1
        dd theme_name_2
        dd theme_name_3
        dd theme_name_4
        dd theme_name_5
        dd theme_name_6
        dd theme_name_7

    ; Active 12-byte Palette read by ui_color and ui_bgcolor
    ; Initialized to Strawberry Milk palette
    active_palette:
        db 211, 204, 218, 254, 244, 114, 221, 203, 223, 204, 238, 53

    ; Persisted 12-byte Custom Palette (separate from built-ins, default copy of Strawberry Milk)
    custom_palette:
        db 211, 204, 218, 254, 244, 114, 221, 203, 223, 204, 238, 53

    ; In-Memory Settings State Variables (.data initialized to defaults)
    setting_theme:              db 0            ; Active theme index (0..7)
    setting_anim:               db 1            ; Animation flag (0 or 1)
    setting_sound:              db 0            ; Sound flag (0 or 1)
    setting_charset:            db 0            ; Charset flag (0 = UTF-8, 1 = ASCII)
    setting_notify:             db 0            ; Notification master flag (0 or 1)
    setting_notify_layers:      db 0x01         ; Notification layer bitmask (b0 = bell)
    setting_volume:             db 2            ; Volume (0..3)
    settings_save_err:          db 0            ; Save failure flag (0 = OK, 1 = failure)

section .bss

    settings_buf:               resb 32

; =============================================================================
; Task V5 Settings Screen UI Strings and State Variables (PRD_V2 §4, §5, §6)
; =============================================================================
section .data

    ; Titles
    title_settings:             db "SETTINGS", CHAR_NULL
    title_settings_colors:      db "SETTINGS - CUSTOMIZE COLORS", CHAR_NULL

    ; Setting row labels (7 rows)
    settings_lbl_theme:         db "Theme", CHAR_NULL
    settings_lbl_customize:     db "Customize colors", CHAR_NULL
    settings_lbl_anim:          db "Animations", CHAR_NULL
    settings_lbl_sound:         db "Sound & Volume", CHAR_NULL
    settings_lbl_charset:       db "Charset", CHAR_NULL
    settings_lbl_notify:        db "Terminal integration", CHAR_NULL
    settings_lbl_reset:         db "Reset to defaults", CHAR_NULL

    ; Values and status strings
    settings_val_on:            db "ON", CHAR_NULL
    settings_val_off:           db "OFF", CHAR_NULL
    settings_val_reduce_motion: db "OFF (Reduce motion)", CHAR_NULL
    settings_val_utf8:          db "UTF-8", CHAR_NULL
    settings_val_ascii:         db "ASCII", CHAR_NULL

    settings_hint_customize:    db "[Enter] Open color editor", CHAR_NULL
    settings_hint_reset:        db "[Enter] Reset all to defaults", CHAR_NULL
    settings_confirm_prompt:    db "Reset all settings to defaults? (y/n)", CHAR_NULL

    settings_msg_saved:         db "Saved", CHAR_NULL
    settings_msg_could_not_save: db "Could not save", CHAR_NULL

    ; Sample line elements
    settings_sample_lbl:        db "Sample: ", CHAR_NULL
    settings_sample_title:      db "Title ", CHAR_NULL
    settings_sample_text:       db "Text ", CHAR_NULL
    settings_sample_accent:     db "Accent ", CHAR_NULL
    settings_sample_ok:         db "[OK] ", CHAR_NULL
    settings_sample_warn:       db "[WARN] ", CHAR_NULL
    settings_sample_err:        db "[ERR]", CHAR_NULL

    ; Slot names for color editor
    slot_name_0:                db " 0: BORDER   ", CHAR_NULL
    slot_name_1:                db " 1: TITLE    ", CHAR_NULL
    slot_name_2:                db " 2: ACCENT   ", CHAR_NULL
    slot_name_3:                db " 3: TEXT     ", CHAR_NULL
    slot_name_4:                db " 4: DIM      ", CHAR_NULL
    slot_name_5:                db " 5: OK       ", CHAR_NULL
    slot_name_6:                db " 6: WARN     ", CHAR_NULL
    slot_name_7:                db " 7: ERR      ", CHAR_NULL
    slot_name_8:                db " 8: CAT      ", CHAR_NULL
    slot_name_9:                db " 9: BAR_FULL ", CHAR_NULL
    slot_name_10:               db "10: BAR_EMPTY", CHAR_NULL
    slot_name_11:               db "11: HIGHLIGHT", CHAR_NULL

    slot_names:
        dd slot_name_0, slot_name_1, slot_name_2, slot_name_3
        dd slot_name_4, slot_name_5, slot_name_6, slot_name_7
        dd slot_name_8, slot_name_9, slot_name_10, slot_name_11

    ; Key help strings
    settings_help_main:         db "[Up/Down] Select   [Left/Right] Change   [Enter] Edit/Toggle   [B/Esc] Back", CHAR_NULL
    settings_help_notify:       db "[Enter/Space] Master ON/OFF   [1-5] Toggle Layer   [B/Esc] Back", CHAR_NULL
    settings_help_colors:       db "[Up/Down] Slot  [Left/Right] +/-1  [PgUp/PgDn] +/-16  [B/Esc] Back", CHAR_NULL
    settings_help_confirm:      db "[Y] Confirm reset   [N/Esc/B] Cancel", CHAR_NULL

    ; Sound & Volume helpers
    settings_lbl_sound_prefix:  db "Sound: ", CHAR_NULL
    settings_lbl_vol_prefix:    db "   Vol: < ", CHAR_NULL
    settings_lbl_vol_suffix:    db " > (0-3)", CHAR_NULL

    ; =========================================================================
    ; Task V6 / v12 Additions: Shared UI Assets & Glyphs
    ; =========================================================================
    menu_title_compact:         db "PAWMODORO", CHAR_NULL

    ; Status Markers (PRD_V2 §13, v12)
    status_marker_ok:           db "[OK] ", CHAR_NULL
    status_marker_warn:         db "[!] ", CHAR_NULL
    status_marker_err:          db "[ERR] ", CHAR_NULL
    status_marker_info:         db "[i] ", CHAR_NULL

    ; Deterministic Greetings (Local time hour of day)
    greeting_morning:           db "Good morning, ready to focus?", CHAR_NULL
    greeting_afternoon:         db "Good afternoon, keep up the momentum!", CHAR_NULL
    greeting_evening:           db "Good evening, wrap up your day peacefully.", CHAR_NULL

    ; Deterministic Daily Cozy Tips (time_today % 7)
    cozy_tip_0:                 db "Tip: Take deep breaths and drink water between pomodoros.", CHAR_NULL
    cozy_tip_1:                 db "Tip: Small daily habits compound into giant life achievements.", CHAR_NULL
    cozy_tip_2:                 db "Tip: Clear your desk of clutter before starting your focus session.", CHAR_NULL
    cozy_tip_3:                 db "Tip: Reflect on today's small wins in your Pawmodoro journal.", CHAR_NULL
    cozy_tip_4:                 db "Tip: Rest your eyes on distant objects during short breaks.", CHAR_NULL
    cozy_tip_5:                 db "Tip: Consistency beats intensity. Focus on showing up every day.", CHAR_NULL
    cozy_tip_6:                 db "Tip: Celebrate every completed session! A happy cat is cheering for you.", CHAR_NULL

    cozy_tips_table:
        dd cozy_tip_0, cozy_tip_1, cozy_tip_2, cozy_tip_3
        dd cozy_tip_4, cozy_tip_5, cozy_tip_6

    ; Dashboard Card Labels
    dash_card_pomo:             db "POMODOROS", CHAR_NULL
    dash_card_habits:           db "HABITS", CHAR_NULL
    dash_card_streak:           db "STREAK", CHAR_NULL
    dash_lbl_streak:            db "Current streak: ", CHAR_NULL
    dash_lbl_days:              db " days", CHAR_NULL
    dash_badge_demo:            db "[DEMO]", CHAR_NULL

    ; UI UTF-8 Glyphs
    glyph_utf8_hline:           db 0xE2, 0x94, 0x80, CHAR_NULL  ; ─
    glyph_utf8_vline:           db 0xE2, 0x94, 0x82, CHAR_NULL  ; │
    glyph_utf8_corner_tl:       db 0xE2, 0x95, 0xAD, CHAR_NULL  ; ╭
    glyph_utf8_corner_tr:       db 0xE2, 0x95, 0xAE, CHAR_NULL  ; ╮
    glyph_utf8_corner_bl:       db 0xE2, 0x95, 0xB0, CHAR_NULL  ; ╰
    glyph_utf8_corner_br:       db 0xE2, 0x95, 0xAF, CHAR_NULL  ; ╯
    glyph_utf8_tee_left:        db 0xE2, 0x94, 0x9C, CHAR_NULL  ; ├
    glyph_utf8_tee_right:       db 0xE2, 0x94, 0xA4, CHAR_NULL  ; ┤
    glyph_utf8_star:            db 0xE2, 0x98, 0x85, CHAR_NULL  ; ★
    glyph_utf8_heart:           db 0xE2, 0x99, 0xA5, CHAR_NULL  ; ♥
    glyph_utf8_dot_filled:      db 0xE2, 0x97, 0x8F, CHAR_NULL  ; ●
    glyph_utf8_dot_empty:       db 0xE2, 0x97, 0x8B, CHAR_NULL  ; ○
    glyph_utf8_bar_full:        db 0xE2, 0x96, 0xB0, CHAR_NULL  ; ▰
    glyph_utf8_bar_empty:       db 0xE2, 0x96, 0xB1, CHAR_NULL  ; ▱
    glyph_utf8_sparkle:         db 0xE2, 0x9C, 0xA6, CHAR_NULL  ; ✦

    glyph_utf8_table:
        dd glyph_utf8_hline, glyph_utf8_vline
        dd glyph_utf8_corner_tl, glyph_utf8_corner_tr
        dd glyph_utf8_corner_bl, glyph_utf8_corner_br
        dd glyph_utf8_tee_left, glyph_utf8_tee_right
        dd glyph_utf8_star, glyph_utf8_heart
        dd glyph_utf8_dot_filled, glyph_utf8_dot_empty
        dd glyph_utf8_bar_full, glyph_utf8_bar_empty
        dd glyph_utf8_sparkle

    ; UI ASCII Fallback Glyphs
    glyph_ascii_hline:          db "-", CHAR_NULL
    glyph_ascii_vline:          db "|", CHAR_NULL
    glyph_ascii_corner_tl:      db "+", CHAR_NULL
    glyph_ascii_corner_tr:      db "+", CHAR_NULL
    glyph_ascii_corner_bl:      db "+", CHAR_NULL
    glyph_ascii_corner_br:      db "+", CHAR_NULL
    glyph_ascii_tee_left:       db "+", CHAR_NULL
    glyph_ascii_tee_right:      db "+", CHAR_NULL
    glyph_ascii_star:           db "*", CHAR_NULL
    glyph_ascii_heart:          db "v", CHAR_NULL
    glyph_ascii_dot_filled:     db "@", CHAR_NULL
    glyph_ascii_dot_empty:      db "o", CHAR_NULL
    glyph_ascii_bar_full:       db "#", CHAR_NULL
    glyph_ascii_bar_empty:      db "-", CHAR_NULL
    glyph_ascii_sparkle:        db "*", CHAR_NULL

    glyph_ascii_table:
        dd glyph_ascii_hline, glyph_ascii_vline
        dd glyph_ascii_corner_tl, glyph_ascii_corner_tr
        dd glyph_ascii_corner_bl, glyph_ascii_corner_br
        dd glyph_ascii_tee_left, glyph_ascii_tee_right
        dd glyph_ascii_star, glyph_ascii_heart
        dd glyph_ascii_dot_filled, glyph_ascii_dot_empty
        dd glyph_ascii_bar_full, glyph_ascii_bar_empty
        dd glyph_ascii_sparkle

    ; Task V7 Animation Strings & Tables
    cat_tail_0:                 db " > ^ < ", CHAR_NULL
    cat_tail_1:                 db " > ^ <~", CHAR_NULL
    cat_tail_2:                 db "~> ^ < ", CHAR_NULL
    cat_tail_table:             dd cat_tail_0, cat_tail_1, cat_tail_2

    cat_eyes_blink:             db "( -.- )", CHAR_NULL

    title_wave_slots:           db SLOT_TITLE, SLOT_ACCENT, SLOT_CAT, SLOT_TEXT
    TITLE_WAVE_SLOTS_LEN        equ 4

    anim_zz_str_z:              db "z", CHAR_NULL
    anim_zz_str_Z:              db "Z", CHAR_NULL
    anim_zz_str_zZ:             db "zZ", CHAR_NULL
    anim_zz_spaces:             db "  ", CHAR_NULL

section .bss

    ; Settings UI state tracking
    settings_sel_row:           resd 1          ; Currently selected row on main settings screen (0..6)
    settings_view_mode:         resd 1          ; SETTINGS_MODE_* (0 = main, 1 = color editor, 2 = confirm)
    settings_color_slot:        resd 1          ; Currently selected slot in color editor (0..11)
    settings_status_msg:        resd 1          ; Pointer to status message (or 0)
    settings_status_style:      resd 1          ; STATUS_OK or STATUS_ERR

    ; Screen bottom row tracking for clearing stale cells
    ui_screen_bottom_row:       resd 1

    ; Task V7: Animation Engine State & Storage (PRD_V2 §12)
    anim_prng_seed:             resd 1          ; LCG PRNG 32-bit state
    anim_frame_count:           resd 1          ; 100ms animation frame counter
    anim_throttle_count:        resd 1          ; Ticks since last animation write
    anim_dirty_flags:           resd 1          ; Bitmask of dirty regions

    ; Effect States
    anim_cat_blink_state:       resd 1          ; 0 = normal eyes, 1 = blink (closed)
    anim_cat_tail_state:        resd 1          ; 0..2 tail pose index
    anim_title_wave_offset:     resd 1          ; 0..3 color wave index
    anim_star_twinkle_state:    resd 1          ; 0..3 star twinkle state
    anim_shimmer_pos:           resd 1          ; 0..29 progress bar shimmer index
    anim_zz_phase:              resd 1          ; 0..4 break zZ phase
    anim_zz_old_x:              resd 1          ; Old column of zZ garnish
    anim_zz_old_y:              resd 1          ; Old row of zZ garnish

    ; Confetti particle storage (20 particles * 40 bytes = 800 bytes)
    anim_confetti_particles:    resb CONFETTI_MAX * PARTICLE_SIZE

    ; Heart-pop effect state
    heart_pop_active:           resd 1          ; 1 = active, 0 = inactive
    heart_pop_x:                resd 1          ; Column
    heart_pop_y:                resd 1          ; Row
    heart_pop_old_x:            resd 1          ; Old column (for erasing)
    heart_pop_old_y:            resd 1          ; Old row (for erasing)
    heart_pop_life:             resd 1          ; Remaining lifetime

; =============================================================================
; Task V8 Additions: Synthesized Sound Effects Engine (PRD_V2 §9, §12)
; =============================================================================
section .data

    ; Audio player executable paths and command-line arguments
    paplay_path:                db "/usr/bin/paplay", CHAR_NULL
    paplay_arg0:                db "paplay", CHAR_NULL
    paplay_arg1:                db "--raw", CHAR_NULL
    paplay_arg2:                db "--format=u8", CHAR_NULL
    paplay_arg3:                db "--rate=11025", CHAR_NULL
    paplay_arg4:                db "--channels=1", CHAR_NULL

    paplay_argv:
        dd paplay_arg0
        dd paplay_arg1
        dd paplay_arg2
        dd paplay_arg3
        dd paplay_arg4
        dd 0

    aplay_path:                 db "/usr/bin/aplay", CHAR_NULL
    aplay_arg0:                 db "aplay", CHAR_NULL
    aplay_arg1:                 db "-q", CHAR_NULL
    aplay_arg2:                 db "-t", CHAR_NULL
    aplay_arg3:                 db "raw", CHAR_NULL
    aplay_arg4:                 db "-f", CHAR_NULL
    aplay_arg5:                 db "U8", CHAR_NULL
    aplay_arg6:                 db "-r", CHAR_NULL
    aplay_arg7:                 db "11025", CHAR_NULL
    aplay_arg8:                 db "-c", CHAR_NULL
    aplay_arg9:                 db "1", CHAR_NULL

    aplay_argv:
        dd aplay_arg0
        dd aplay_arg1
        dd aplay_arg2
        dd aplay_arg3
        dd aplay_arg4
        dd aplay_arg5
        dd aplay_arg6
        dd aplay_arg7
        dd aplay_arg8
        dd aplay_arg9
        dd 0

    dev_null_path:              db "/dev/null", CHAR_NULL
    sfx_default_envp:           dd 0
    sfx_bell_char:              db CHAR_BELL

    ; Volume scaling lookup table (indexed by setting_volume: 0..3)
    ; 0: muted (0), 1: 25% (30), 2: 50% (65), 3: 100% (110)
    sfx_volume_table:           db 0, 30, 65, 110

    ; Sound Step Tables for Synthesizer Engine (PRD_V2 §9)
    ; Format per step:
    ;   dd frequency_hz     ; Frequency in Hz (0 = rest/silent)
    ;   dd duration_ms      ; Duration in milliseconds
    ;   dd waveform_id      ; WAVE_SQUARE, WAVE_TRIANGLE, or WAVE_REST
    ; Sentinel: dd 0, 0, 0
    sfx_seq_start_chirp:
        dd 587, 40, WAVE_TRIANGLE
        dd 880, 60, WAVE_TRIANGLE
        dd 0, 0, 0

    sfx_seq_click:
        dd 1200, 12, WAVE_SQUARE
        dd 0, 0, 0

    sfx_seq_checkin_sparkle:
        dd 523, 50, WAVE_TRIANGLE
        dd 659, 50, WAVE_TRIANGLE
        dd 784, 50, WAVE_TRIANGLE
        dd 1046, 80, WAVE_TRIANGLE
        dd 0, 0, 0

    sfx_seq_focus_fanfare:
        dd 392, 80, WAVE_TRIANGLE
        dd 523, 80, WAVE_TRIANGLE
        dd 659, 80, WAVE_TRIANGLE
        dd 784, 120, WAVE_TRIANGLE
        dd 0, 30, WAVE_REST
        dd 659, 60, WAVE_TRIANGLE
        dd 784, 200, WAVE_TRIANGLE
        dd 0, 0, 0

    sfx_seq_break_chime:
        dd 659, 70, WAVE_TRIANGLE
        dd 0, 20, WAVE_REST
        dd 988, 140, WAVE_TRIANGLE
        dd 0, 0, 0

    sfx_seq_error_boop:
        dd 180, 80, WAVE_SQUARE
        dd 0, 20, WAVE_REST
        dd 140, 120, WAVE_SQUARE
        dd 0, 0, 0

    sfx_seq_delete_blip:
        dd 880, 35, WAVE_SQUARE
        dd 440, 45, WAVE_SQUARE
        dd 220, 55, WAVE_SQUARE
        dd 0, 0, 0

    sfx_seq_short_meow:
        dd 450, 30, WAVE_TRIANGLE
        dd 520, 30, WAVE_TRIANGLE
        dd 620, 35, WAVE_TRIANGLE
        dd 740, 40, WAVE_TRIANGLE
        dd 850, 45, WAVE_TRIANGLE
        dd 880, 30, WAVE_TRIANGLE
        dd 840, 30, WAVE_TRIANGLE
        dd 890, 30, WAVE_TRIANGLE
        dd 830, 30, WAVE_TRIANGLE
        dd 760, 35, WAVE_TRIANGLE
        dd 680, 35, WAVE_TRIANGLE
        dd 580, 40, WAVE_TRIANGLE
        dd 480, 50, WAVE_TRIANGLE
        dd 0, 0, 0

    sfx_table:
        dd 0
        dd sfx_seq_start_chirp
        dd sfx_seq_click
        dd sfx_seq_checkin_sparkle
        dd sfx_seq_focus_fanfare
        dd sfx_seq_break_chime
        dd sfx_seq_error_boop
        dd sfx_seq_delete_blip
        dd sfx_seq_short_meow

section .bss

    ; Task V8: Sound Engine State & 32 KB PCM Buffer (PRD_V2 §9, §12)
    sfx_envp:                   resd 1          ; Inherited environment pointer
    sfx_player_choice:          resd 1          ; PLAYER_NONE, PLAYER_PAPLAY, or PLAYER_APLAY
    sfx_pipe_fds:               resd 2          ; Pipe fds: [0]=read, [1]=write
    sfx_buf_len:                resd 1          ; Valid PCM bytes currently in sfx_buf
    sfx_buf:                    resb SFX_BUF_SIZE ; 32 KB unsigned 8-bit mono PCM buffer

; =============================================================================
; Task V9 Additions: Notifications & Terminal Integration (PRD_V2 §10, §12)
; =============================================================================
section .data

    ; Layer 2: Screen flash sequences
    ansi_flash_on:              db CHAR_ESC, "[?5h", CHAR_NULL
    ansi_flash_off:             db CHAR_ESC, "[?5l", CHAR_NULL

    ; Layer 3: Continuously updated window title sequences
    ansi_title_prefix:          db CHAR_ESC, "]0;Pawmodoro - ", CHAR_NULL
    ansi_title_done:            db CHAR_ESC, "]0;Pawmodoro - Time's up!", CHAR_BELL, CHAR_NULL
    ansi_title_restore:         db CHAR_ESC, "]0;Pawmodoro", CHAR_BELL, CHAR_NULL
    title_phase_focus:          db "FOCUS ", CHAR_NULL
    title_phase_short:          db "SHORT BREAK ", CHAR_NULL
    title_phase_long:           db "LONG BREAK ", CHAR_NULL

    ; Layer 4: Windows Terminal taskbar progress sequences (OSC 9;4)
    ansi_taskbar_clear:         db CHAR_ESC, "]9;4;0;0", CHAR_BELL, CHAR_NULL
    ansi_taskbar_prefix_running: db CHAR_ESC, "]9;4;1;", CHAR_NULL

    ; Layer 5: Desktop notifications (Linux notify-send & experimental WSL PowerShell)
    notif_send_path:            db "/usr/bin/notify-send", CHAR_NULL
    notif_title:                db "Pawmodoro", CHAR_NULL
    notif_msg_focus:            db "Focus complete! Time for a break.", CHAR_NULL
    notif_msg_break:            db "Break complete! Ready to focus?", CHAR_NULL
    notif_send_arg0:            db "notify-send", CHAR_NULL

    notif_argv_focus:
        dd notif_send_arg0
        dd notif_title
        dd notif_msg_focus
        dd 0

    notif_argv_break:
        dd notif_send_arg0
        dd notif_title
        dd notif_msg_break
        dd 0

    powershell_path:            db "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe", CHAR_NULL
    powershell_arg0:            db "powershell.exe", CHAR_NULL
    powershell_arg1:            db "-NoProfile", CHAR_NULL
    powershell_arg2:            db "-NonInteractive", CHAR_NULL
    powershell_arg3:            db "-Command", CHAR_NULL
    powershell_cmd_focus:       db "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');$n=New-Object System.Windows.Forms.NotifyIcon;$n.Icon=[System.Drawing.SystemIcons]::Information;$n.Visible=$true;$n.ShowBalloonTip(3000,'Pawmodoro','Focus complete! Time for a break.',[System.Windows.Forms.ToolTipIcon]::Info);Start-Sleep -m 200", CHAR_NULL
    powershell_cmd_break:       db "[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');$n=New-Object System.Windows.Forms.NotifyIcon;$n.Icon=[System.Drawing.SystemIcons]::Information;$n.Visible=$true;$n.ShowBalloonTip(3000,'Pawmodoro','Break complete! Ready to focus?',[System.Windows.Forms.ToolTipIcon]::Info);Start-Sleep -m 200", CHAR_NULL

    powershell_argv_focus:
        dd powershell_arg0
        dd powershell_arg1
        dd powershell_arg2
        dd powershell_arg3
        dd powershell_cmd_focus
        dd 0

    powershell_argv_break:
        dd powershell_arg0
        dd powershell_arg1
        dd powershell_arg2
        dd powershell_arg3
        dd powershell_cmd_break
        dd 0

    ; Settings UI Layer Indicators for Row 5
    settings_lbl_layer_1:       db " 1:Bel", CHAR_NULL
    settings_lbl_layer_2:       db " 2:Flsh", CHAR_NULL
    settings_lbl_layer_3:       db " 3:Titl", CHAR_NULL
    settings_lbl_layer_4:       db " 4:Prog", CHAR_NULL
    settings_lbl_layer_5:       db " 5:Toast", CHAR_NULL

section .bss

    ; Task V9: State variables
    completion_reminder_ticks:  resd 1          ; Counter for 60s reminder ticks (0..600)
    flash_timespec:             resb TIMESPEC_SIZE ; Dedicated 150ms nanosleep timespec
