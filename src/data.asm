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
