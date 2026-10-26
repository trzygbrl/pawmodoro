; =============================================================================
; Pawmodoro - System and Application Constants (src/constants.inc)
;
; Purpose: Centralized symbolic constants for system calls, I/O parameters,
;          termios structures, keys, buffer sizes, durations, and state values.
; Reference: PRD §3.1, §3.2, §4.2, §6.3, §6.5
; =============================================================================

; =============================================================================
; Linux x86 System Calls (int 0x80) & Standard File Descriptors
; =============================================================================
SYS_EXIT                equ 1           ; Terminate calling process
SYS_READ                equ 3           ; Read from file descriptor
SYS_WRITE               equ 4           ; Write to file descriptor
SYS_OPEN                equ 5           ; Open/create file
SYS_CLOSE               equ 6           ; Close file descriptor
SYS_UNLINK              equ 10          ; Delete a name and possibly the file it refers to
SYS_TIME                equ 13          ; Get time in seconds since Unix epoch
SYS_RENAME              equ 38          ; Change the name or location of a file
SYS_IOCTL               equ 54          ; I/O control operation
SYS_NANOSLEEP           equ 162         ; High-resolution sleep

FD_STDIN                equ 0           ; Standard input file descriptor
FD_STDOUT               equ 1           ; Standard output file descriptor
EXIT_SUCCESS            equ 0           ; Successful process exit code
EXIT_FAILURE            equ 1           ; Failure process exit code

; =============================================================================
; File Open Flags (sys_open) and Creation Modes
; =============================================================================
O_RDONLY                equ 0           ; Open for reading only
O_WRONLY                equ 1           ; Open for writing only
O_CREAT                 equ 0x40        ; Create file if it does not exist (64 dec)
O_TRUNC                 equ 0x200       ; Truncate file length to 0 (512 dec)
O_APPEND                equ 0x400       ; Append writes to end of file (1024 dec)
FILE_MODE_0644          equ 420         ; Default permissions (0644 octal = 420 dec)

; =============================================================================
; Terminal I/O Control (termios ioctl) Constants (PRD §3.2)
; =============================================================================
TCGETS                  equ 0x5401      ; ioctl request: get terminal attributes
TCSETS                  equ 0x5402      ; ioctl request: set terminal attributes
TERMIOS_SIZE            equ 36          ; struct termios size in bytes (i386)

ISIG                    equ 0x01        ; Enable signals (c_lflag bit)
ICANON                  equ 0x02        ; Canonical line input mode (c_lflag bit)
ECHO                    equ 0x08        ; Local echo enabled (c_lflag bit)

VTIME                   equ 5           ; Timeout in deciseconds (c_cc index)
VMIN                    equ 6           ; Minimum characters for read (c_cc index)

C_LFLAG_OFFSET          equ 12          ; Offset of c_lflag in struct termios
C_CC_OFFSET             equ 17          ; Offset of c_cc array in struct termios

; =============================================================================
; ASCII Character and Key Codes
; =============================================================================
CHAR_NULL               equ 0           ; NUL terminator
CHAR_BELL               equ 7           ; Terminal audio bell (\a)
CHAR_LF                 equ 10          ; Line feed (\n)
CHAR_ESC                equ 27          ; Escape character (0x1B)
CHAR_SPACE              equ 32          ; Space character (' ')
CHAR_HASH               equ 35          ; Hash / pound symbol ('#')
CHAR_PERCENT            equ 37          ; Percent symbol ('%')
CHAR_PLUS               equ 43          ; Plus symbol ('+')
CHAR_ASTERISK           equ 42          ; Asterisk symbol ('*')
CHAR_MINUS              equ 45          ; Hyphen/dash symbol ('-')
CHAR_ZERO               equ 48          ; ASCII digit zero ('0')
CHAR_COLON              equ 58          ; Colon symbol (':')
CHAR_SEMICOLON          equ 59          ; Semicolon symbol (';')
CHAR_LBRACKET           equ 91          ; Left square bracket ('[')
CHAR_RBRACKET           equ 93          ; Right square bracket (']')
CHAR_UPPER_H            equ 72          ; Uppercase letter H ('H')
CHAR_PIPE               equ 124         ; Vertical bar / pipe symbol ('|')
CHAR_TILDE              equ 126         ; Tilde symbol ('~', 0x7E)
CHAR_UPPER_O            equ 79          ; Uppercase letter O ('O')
CHAR_LOWER_M            equ 109         ; ASCII lowercase letter m ('m', for ANSI escapes)


KEY_CTRL_C              equ 3           ; ASCII 3 (ETX / Ctrl+C)
KEY_TAB                 equ 9           ; ASCII 9 (Horizontal Tab)
KEY_BACKSPACE           equ 127         ; Backspace / Delete
KEY_ENTER               equ 10          ; Enter / Line Feed
KEY_ESC                 equ 27          ; Escape key
KEY_SPACE               equ 32          ; Spacebar key
KEY_NONE                equ -1          ; Sentinel value: no key available

; =============================================================================
; Extended Navigation Key Codes (Task V1, PRD_V2 §6)
; Values are distinct integers above 255.
; =============================================================================
KEY_UP                  equ 0x101       ; Up arrow (ESC [ A / ESC O A)
KEY_DOWN                equ 0x102       ; Down arrow (ESC [ B / ESC O B)
KEY_RIGHT               equ 0x103       ; Right arrow (ESC [ C / ESC O C)
KEY_LEFT                equ 0x104       ; Left arrow (ESC [ D / ESC O D)
KEY_PGUP                equ 0x105       ; Page Up (ESC [ 5 ~)
KEY_PGDN                equ 0x106       ; Page Down (ESC [ 6 ~)
KEY_HOME                equ 0x107       ; Home (ESC [ H / ESC O H / ESC [ 1 ~)
KEY_END                 equ 0x108       ; End (ESC [ F / ESC O F / ESC [ 4 ~)
KEY_DELETE              equ 0x109       ; Delete (ESC [ 3 ~)

CHAR_UPPER_X           equ 88          ; Uppercase letter X ('X', for ANSI ECH sequence ESC[<n>X)
KEY_CTRL_G              equ 7           ; ASCII 7 (BEL / Ctrl+G, temporary G1 demo key)
KEY_CTRL_V              equ 22          ; ASCII 22 (SYN / Ctrl+V, hidden sprite viewer key, PRD_V3 §sprites)
GFX_SLOT_UNKNOWN        equ 0xFFFF      ; Sentinel value for untracked/unknown color slot ID

; G1 Rendering Core Demo Toggle (Assembly-time switch, PRD_V3 §11)
%ifndef G1_DEMO_ENABLED
%define G1_DEMO_ENABLED 1
%endif

; Sprite Engine & Hidden Viewer Toggle (Assembly-time switch, PRD_V3 §sprites)
%ifndef SPRITE_VIEWER_ENABLED
%define SPRITE_VIEWER_ENABLED 1
%endif

; Sprite Format & Encoding Constants (PRD_V3 §4.2)
SPRITE_MAX_PALETTE      equ 15          ; Maximum mapped theme slots per sprite
SPRITE_FRAME_END_SENTINEL equ 0         ; Frame RLE terminator sentinel (0x00)

; Half-Block Unicode UTF-8 Byte Sequences (PRD_V3 §4.1)
UTF8_HALF_UPPER_B1      equ 0xE2
UTF8_HALF_UPPER_B2      equ 0x96
UTF8_HALF_UPPER_B3      equ 0x80        ; U+2580 (▀)

UTF8_HALF_LOWER_B1      equ 0xE2
UTF8_HALF_LOWER_B2      equ 0x96
UTF8_HALF_LOWER_B3      equ 0x84        ; U+2584 (▄)

; =============================================================================
; Memory Buffer Sizes (.bss Budget, PRD §6.5, PRD_V3 §4.1)
; =============================================================================
OUT_BUF_SIZE            equ 16384       ; Terminal output frame buffer size (increased from 8192 for v3)
IN_BUF_SIZE             equ 16          ; Raw keyboard input buffer size
LINE_BUF_SIZE           equ 256         ; Line input editing buffer size
FILE_BUF_SIZE           equ 512         ; File persistence I/O buffer size
JRNL_BUF_SIZE           equ 16384       ; Journal viewing read buffer size (16 KB, PRD v2 §7, §12)
DEL_COPY_BUF_SIZE       equ 2048        ; Dedicated file deletion copy buffer size (2 KB, PRD v2 §7)
TIMESPEC_SIZE           equ 8           ; struct timespec size (2 dwords: sec, nsec)

; =============================================================================
; Application Domain Limits (PRD §4.3, §4.4)
; =============================================================================
MAX_HABITS              equ 8           ; Maximum number of tracked habits
HABIT_NAME_MAX          equ 31          ; Maximum characters in a habit name
HABIT_RECORD_SIZE       equ 48          ; Bytes per habit record in habits.dat
JOURNAL_ENTRY_MAX       equ 200         ; Maximum characters per journal entry
JOURNAL_VIEW_LINES      equ 10          ; Number of recent entries shown in view
JRNL_MAX_ENTRIES        equ 32          ; Maximum cached entries in active viewing window
JRNL_MAX_VISUAL_ROWS    equ 4           ; Maximum visual wrapped rows per entry
UI_JRN_INDENT_COLS      equ 4           ; Continuation row indentation in columns
SESSIONS_PER_CYCLE      equ 4           ; Completed focus sessions before long break

; =============================================================================
; Pomodoro Phase Durations in Seconds (PRD §4.2 FR-T1, FR-T2)
; =============================================================================
; Standard mode
TIMER_FOCUS_SECS        equ 1500        ; 25 minutes
TIMER_SHORT_BREAK_SECS  equ 300         ; 5 minutes
TIMER_LONG_BREAK_SECS   equ 900         ; 15 minutes

; Demo mode
TIMER_DEMO_FOCUS_SECS   equ 10          ; 10 seconds
TIMER_DEMO_SHORT_BREAK_SECS equ 5       ; 5 seconds
TIMER_DEMO_LONG_BREAK_SECS  equ 8       ; 8 seconds

; =============================================================================
; Time and Arithmetic Constants (PRD §6.3)
; =============================================================================
TZ_OFFSET               equ 28800       ; UTC+8 timezone offset in seconds (Philippines)
SECONDS_PER_DAY         equ 86400       ; Seconds in 24 hours
SECONDS_PER_HOUR        equ 3600        ; Seconds in 1 hour
SECONDS_PER_MINUTE      equ 60          ; Seconds in 1 minute
DECIMAL_BASE            equ 10          ; Base 10 for radix conversion
MAX_U32_2_CLAMP         equ 99          ; Upper clamp limit for buf_u32_2
MAX_MM_CLAMP            equ 99          ; Upper clamp limit for minutes in buf_mmss
SECS_MAX_CLAMP          equ 59          ; Maximum seconds in MM:SS display

; =============================================================================
; Application State Identifiers (Finite State Machine, PRD §4.1 FR-U3)
; =============================================================================
STATE_MENU              equ 0           ; Main menu dashboard
STATE_TIMER             equ 1           ; Pomodoro active timer
STATE_HABITS            equ 2           ; Habit tracker view/edit
STATE_JOURNAL           equ 3           ; Journal view/add
STATE_QUIT              equ 4           ; Application exit state
STATE_SETTINGS          equ 5           ; Settings screen & color editor (PRD_V2 §6)
STATE_VIEWER            equ 6           ; Hidden sprite viewer (PRD_V3 §sprites)

; =============================================================================
; Terminal & Key Processing Constants (Task 2 Additions)
; =============================================================================
FD_STDERR               equ 2           ; Standard error file descriptor
NANOSLEEP_5MS           equ 5000000     ; 5 ms in nanoseconds (for key_poll ESC grace period)
NANOSLEEP_50MS          equ 50000000    ; 50 ms in nanoseconds (for key_wait polling)

CHAR_LOWER_A            equ 97          ; ASCII lowercase 'a'
CHAR_LOWER_Z            equ 122         ; ASCII lowercase 'z'
CASE_BIT_MASK           equ 0x20        ; Bit 5 mask for ASCII case conversion

KEY_Q                   equ 81          ; ASCII uppercase 'Q' (Quit key)
KEY_T                   equ 84          ; ASCII uppercase 'T' (Type line demo key)
READ_LINE_DEMO_MAX      equ 20          ; Demo line length limit for read_line test

; =============================================================================
; Time and Date Constants (Task 3 Additions, PRD §6.3, §6.4)
; =============================================================================
NANOSLEEP_100MS         equ 100000000   ; 100 ms in nanoseconds (for time_sleep_100ms)
SECONDS_PER_HOUR        equ 3600        ; Seconds in 1 hour (for HH:MM calculation)
DATE_BUF_SIZE           equ 11          ; 11 bytes: "YYYY-MM-DD\0"
TIME_BUF_SIZE           equ 6           ; 6 bytes: "HH:MM\0"

; Howard Hinnant's civil_from_days algorithm constants
CIVIL_EPOCH_SHIFT       equ 719468      ; Days from 0000-03-01 to 1970-01-01
CIVIL_ERA_DAYS          equ 146097      ; Days in one 400-year Gregorian cycle (era)
CIVIL_YEARS_ERA         equ 400         ; Years in one Gregorian era
CIVIL_YEARS_CENTURY     equ 100         ; Years in a century (for yoe/100)
CIVIL_DAYS_4Y           equ 1460        ; Days in 4 years (365*4)
CIVIL_DAYS_100Y         equ 36524       ; Days in 100 years excluding century leap
CIVIL_DAYS_400Y_M1      equ 146096      ; 146097 - 1 (boundary check divisor)
CIVIL_DAYS_YEAR         equ 365         ; Standard days in a non-leap year
CIVIL_MONTH_SCALE       equ 153         ; Scale factor for month calculation (5-month cycle: 153 days)
CIVIL_MONTH_SHIFT       equ 2           ; Offset shift in Hinnant month formula
CIVIL_DAY_SCALE         equ 5           ; Divisor for day-of-month calculation
CIVIL_MONTH_CUTOFF      equ 10          ; Cutoff threshold separating Jan/Feb from Mar..Dec
CIVIL_MONTH_ADJ_EARLY   equ 3           ; Month adjustment for March..December (m = mp + 3)
CIVIL_MONTH_ADJ_LATE    equ 9           ; Month adjustment for January..February (m = mp - 9)
CIVIL_YEAR_ADJ_MONTH    equ 2           ; Month threshold (m <= 2) for Gregorian year roll-over

; Decimal radix powers for zero-padded numeric string formatting
DECIMAL_1000            equ 1000        ; Divisor for thousands digit in 4-digit formatting
DECIMAL_100             equ 100         ; Divisor for hundreds digit in 4-digit formatting

; Task 3 Test Vectors and Demo Constants
TEST_VECTOR_0           equ 0           ; Day number for 1970-01-01
TEST_VECTOR_10957       equ 10957       ; Day number for 2000-01-01 (Y2K)
TEST_VECTOR_19723       equ 19723       ; Day number for 2024-01-01
SLEEP_DEMO_COUNT        equ 10          ; 10 iterations of 100ms sleep for demo

; =============================================================================
; Task 4 & V2 Additions: UI Frame Geometry, Cat Art & Adaptive Layout (PRD v2 §2)
; =============================================================================
UI_FRAME_WIDTH          equ 56          ; Legacy fixed frame width in columns
UI_FRAME_INNER_WIDTH    equ 54          ; Legacy inner horizontal border width (56 - 2)
UI_FRAME_COL_LEFT       equ 1           ; Frame-relative left border column
UI_FRAME_COL_RIGHT      equ 56          ; Legacy right border column

; V3 Adaptive Layout Constants (PRD_V3 §3.2)
UI_FRAME_MAX_WIDTH      equ 120         ; Maximum frame width in columns (PRD_V3 §3.2)
UI_FRAME_MARGIN_COLS    equ 2           ; Margin subtracted from term_cols (term_cols - 2)
UI_CLIP_MARKER          equ CHAR_TILDE  ; '~' (0x7E) clipping marker for truncated text
UI_TIMER_OFF_DEMO       equ 8           ; Offset from ui_w to [DEMO] badge column (ui_w - 8)
UI_HAB_OFF_SQUARES      equ 36          ; Offset from ui_w to 7-day history squares (ui_w - 36)
UI_HAB_OFF_STREAK       equ 13          ; Offset from ui_w to streak count (ui_w - 13)
UI_HAB_OFF_TOTAL        equ 6           ; Offset from ui_w to total check-ins (ui_w - 6)
UI_JRN_TEXT_MARGIN      equ 6           ; Journal display width margin (ui_w - 6)

; Main Menu Row Coordinates
UI_MENU_ROW_TOP         equ 1           ; Top border row
UI_MENU_ROW_TITLE       equ 2           ; Title and Cat line 1 row
UI_MENU_ROW_TAGLINE     equ 3           ; Tagline and Cat line 2 row
UI_MENU_ROW_CAT3        equ 4           ; Cat line 3 row
UI_MENU_ROW_SEP         equ 5           ; Middle separator border row
UI_MENU_ROW_DASH        equ 6           ; Dashboard summary statistics row
UI_MENU_ROW_BLANK       equ 7           ; Blank spacing row
UI_MENU_ROW_ITEM1       equ 8           ; Menu option 1 (Timer) row
UI_MENU_ROW_ITEM2       equ 9           ; Menu option 2 (Habits) row
UI_MENU_ROW_ITEM3       equ 10          ; Menu option 3 (Journal) row
UI_MENU_ROW_ITEM4       equ 11          ; Menu option 4 (Demo mode) row
UI_MENU_ROW_ITEM5       equ 12          ; Menu option 5 (Settings) row
UI_MENU_ROW_ITEMQ       equ 13          ; Menu option Q (Quit) row
UI_MENU_ROW_STATUS      equ 14          ; Menu status / feedback message row
UI_MENU_ROW_HELP        equ 15          ; Menu key help prompt row
UI_MENU_ROW_BOTTOM      equ 16          ; Bottom border row
UI_MENU_ROW_BELOW       equ 17          ; Row below frame for erase_eos

; Main Menu Column Coordinates
UI_MENU_COL_CAT         equ 4           ; Cat ASCII art column
UI_MENU_COL_TITLE       equ 14          ; Main title & tagline column
UI_MENU_COL_CONTENT     equ 4           ; Dashboard and menu items column
UI_MENU_COL_STATUS      equ 4           ; Menu status start column
UI_MENU_COL_HELP        equ 4           ; Menu key help start column

; Stub Screen Row Coordinates
UI_STUB_ROW_TOP         equ 1           ; Top border row
UI_STUB_ROW_TITLE       equ 2           ; Screen title row
UI_STUB_ROW_SEP         equ 3           ; Separator border row
UI_STUB_ROW_BLANK1      equ 4           ; Blank spacing row
UI_STUB_ROW_MSG         equ 5           ; "Coming soon" message row
UI_STUB_ROW_BLANK2      equ 6           ; Blank spacing row
UI_STUB_ROW_KEY         equ 7           ; Key help ("[B] Back") row
UI_STUB_ROW_BOTTOM      equ 8           ; Bottom border row
UI_STUB_ROW_BELOW       equ 9           ; Row below frame for erase_eos

; Stub Screen Column Coordinates
UI_STUB_COL_TITLE       equ 4           ; Title text column
UI_STUB_COL_CONTENT     equ 4           ; Message and key text column

; Cat Poses (PRD §6.4, PRD_V2 §8, v12)
CAT_POSE_IDLE           equ 0           ; Pose 0: Idle cat (main menu)
CAT_POSE_WORKING        equ 1           ; Pose 1: Working / focused eyes (timer focus)
CAT_POSE_RESTING        equ 2           ; Pose 2: Resting / sleeping (timer break)
CAT_POSE_SLEEPY         equ 2           ; Synonym for resting pose
CAT_POSE_HAPPY          equ 3           ; Pose 3: Happy cat (timer complete, habit check-in)
CAT_POSE_SURPRISED      equ 4           ; Pose 4: Surprised cat (error, confirmation)
CAT_POSE_MAX            equ 4           ; Maximum valid pose index
CAT_LINES               equ 3           ; Number of lines in cat ASCII art

; Keyboard Input Constants (Task 4 Additions)
CHAR_SLASH              equ 47          ; Slash symbol ('/')
KEY_1                   equ 49          ; ASCII '1'
KEY_2                   equ 50          ; ASCII '2'
KEY_3                   equ 51          ; ASCII '3'
KEY_4                   equ 52          ; ASCII '4'
KEY_5                   equ 53          ; ASCII '5' (Settings key, PRD_V2 §6)
KEY_B                   equ 66          ; ASCII 'B' (uppercase, from key_wait)

; =============================================================================
; Task 5 Additions: Pomodoro Timer Engine & UI Constants (PRD §4.2, §5, §6.4)
; =============================================================================
; Pomodoro Phase Identifiers
PHASE_FOCUS             equ 0           ; Active work/focus period
PHASE_SHORT_BREAK       equ 1           ; Rest period between regular sessions
PHASE_LONG_BREAK        equ 2           ; Extended rest period after full cycle

; Progress Bar Geometry and Scale (PRD §4.2 FR-T3, §6.4)
PROGRESS_BAR_WIDTH      equ 30          ; Progress bar inner width in characters
PERCENT_SCALE           equ 100         ; Percentage multiplication scale (100%)

; Additional ASCII Characters for Progress Bar & Timer UI
CHAR_HASH               equ 35          ; ASCII '#' (progress bar filled character)
CHAR_PERCENT            equ 37          ; ASCII '%' (percentage symbol)
CHAR_RBRACKET           equ 93          ; ASCII ']' (right square bracket)

; Sub-second Tick Rate
TICKS_PER_SECOND        equ 10          ; Number of 100ms ticks per second

; Timer Interactive Key Codes (Uppercase, from key_poll / key_wait)
KEY_P                   equ 80          ; ASCII 'P' (Pause / Resume toggle)
KEY_S                   equ 83          ; ASCII 'S' (Skip phase)

; Timer Screen Row Coordinates (56-column frame)
UI_TIMER_ROW_TOP        equ 1           ; Top border row
UI_TIMER_ROW_TITLE      equ 2           ; Title row ("FOCUS - Session n of 4" / [DEMO])
UI_TIMER_ROW_BLANK1     equ 3           ; Blank row between title and cat
UI_TIMER_ROW_CAT1       equ 4           ; Cat ASCII art line 1 row
UI_TIMER_ROW_CAT2       equ 5           ; Cat line 2 and time display row (MM:SS / PAUSED)
UI_TIMER_ROW_CAT3       equ 6           ; Cat line 3 row
UI_TIMER_ROW_PROGRESS   equ 7           ; Progress bar row
UI_TIMER_ROW_MSG        equ 8           ; Blank / phase completion message row
UI_TIMER_ROW_HELP       equ 9           ; Key navigation help row
UI_TIMER_ROW_BOTTOM     equ 10          ; Bottom border row
UI_TIMER_ROW_BELOW      equ 11          ; Row below frame for erase_eos (ESC[J)

; Timer Screen Column Coordinates
UI_TIMER_COL_TITLE      equ 4           ; Title text column
UI_TIMER_COL_DEMO       equ 46          ; [DEMO] badge column
UI_TIMER_COL_CAT        equ 6           ; Cat ASCII art start column
UI_TIMER_COL_TIME       equ 20          ; MM:SS display column
UI_TIMER_COL_PAUSED     equ 27          ; PAUSED status label column
UI_TIMER_COL_PROGRESS   equ 5           ; Progress bar start column
UI_TIMER_COL_MSG        equ 4           ; Phase completion message column
UI_TIMER_COL_HELP       equ 4           ; Key help text column

; =============================================================================
; Task 6 Additions: File Persistence & Pomodoro Statistics (PRD §4.5 FR-D2, FR-D4)
; =============================================================================
; File Operation Return Codes and Error Sentinels
FILE_OK                 equ 0           ; File operation success code
FILE_ERR                equ -1          ; File operation error code / missing file

; File Open Combined Flags (sys_open, PRD §3.1)
O_SAVE_FLAGS            equ (O_WRONLY | O_CREAT | O_TRUNC)  ; 0x241 (577 dec) - Truncate and write
O_APPEND_FLAGS          equ (O_WRONLY | O_CREAT | O_APPEND) ; 0x441 (1089 dec) - Append to end of file

; Stats Record Layout & Size (PRD §4.5 FR-D2: 12 bytes little-endian dwords)
STATS_RECORD_SIZE       equ 12          ; Size of stats.dat record in bytes (3 dwords)
STATS_OFFSET_DAY        equ 0           ; Offset of day field (dword)
STATS_OFFSET_TODAY      equ 4           ; Offset of today_count field (dword)
STATS_OFFSET_TOTAL      equ 8           ; Offset of total_count field (dword)

; Stats Save Status Flag Values
STATS_SAVE_OK           equ 0           ; Last save succeeded
STATS_SAVE_FAILED       equ 1           ; Last save failed

; =============================================================================
; Task 7 Additions: Habit Tracker Constants (PRD §4.3, §4.5, §5, §6.4)
; =============================================================================
; Additional ASCII Characters and Key Codes
CHAR_DOT                equ 46          ; ASCII '.' (empty history square)
CHAR_QUESTION           equ 63          ; ASCII '?' (sanitized unprintable character)

KEY_5                   equ 53          ; ASCII '5'
KEY_6                   equ 54          ; ASCII '6'
KEY_7                   equ 55          ; ASCII '7'
KEY_8                   equ 56          ; ASCII '8'
KEY_A                   equ 65          ; ASCII uppercase 'A' (Add habit)
KEY_D                   equ 68          ; ASCII uppercase 'D' (Delete habit)

; Habit Record Offsets and File Geometry (PRD §4.3 FR-H1, §4.5 FR-D3)
HABIT_OFFSET_NAME       equ 0           ; Offset of name[32] string
HABIT_OFFSET_LAST_DAY   equ 32          ; Offset of last_day dword
HABIT_OFFSET_STREAK     equ 36          ; Offset of streak dword
HABIT_OFFSET_TOTAL      equ 40          ; Offset of total dword
HABIT_OFFSET_HISTORY    equ 44          ; Offset of history dword (32-bit bitmask)

HABIT_HEADER_SIZE       equ 4           ; Size of habit_count dword in habits.dat
HABIT_MAX_FILE_SIZE     equ 388         ; 4 + (MAX_HABITS * HABIT_RECORD_SIZE) = 4 + 384
HABIT_MIN_FILE_SIZE     equ 4           ; Minimum valid file size (count dword)

HABIT_NAME_DISPLAY      equ 12          ; Truncated display width for habit name
HABIT_DAYS_DISPLAY      equ 7           ; Number of history days displayed (squares)
BITS_PER_DWORD          equ 32          ; 32 bits for shift guard check

; Habit Screen Row Coordinates (56-column frame)
UI_HAB_ROW_TOP          equ 1           ; Top border row
UI_HAB_ROW_TITLE        equ 2           ; Title row ("HABIT TRACKER")
UI_HAB_ROW_HEADER       equ 3           ; Column headers row (# HABIT LAST 7 DAYS...)
UI_HAB_ROW_SEP          equ 4           ; Separator border row
UI_HAB_ROW_FIRST        equ 5           ; First habit record row (Row 5)
UI_HAB_ROW_LAST         equ 12          ; Last habit record row (Row 12, max 8 habits)
UI_HAB_ROW_BLANK        equ 13          ; Blank spacing row
UI_HAB_ROW_MSG          equ 14          ; User prompt / feedback message row
UI_HAB_ROW_HELP         equ 15          ; Key help prompt row
UI_HAB_ROW_BOTTOM       equ 16          ; Bottom border row
UI_HAB_ROW_BELOW        equ 17          ; Row below frame for erase_eos (ESC[J)

; Habit Screen Column Coordinates
UI_HAB_COL_TITLE        equ 4           ; Title start column
UI_HAB_COL_NUM          equ 4           ; Habit number column
UI_HAB_COL_NAME         equ 7           ; Habit name start column
UI_HAB_COL_SQUARES      equ 20          ; 7-day history squares start column
UI_HAB_COL_STREAK       equ 43          ; Streak count column
UI_HAB_COL_TOTAL        equ 50          ; Total check-in count column
UI_HAB_COL_MSG          equ 4           ; Message text column
UI_HAB_COL_HELP         equ 4           ; Key help text column

; =============================================================================
; Task 8 Additions: Journal Subsystem Constants (PRD §3.1, §4.4, §5, §6.4)
; =============================================================================
; Reposition read/write file offset syscall and seek whence flags (PRD §3.1)
SYS_LSEEK               equ 19          ; Linux sys_lseek system call number
SEEK_SET                equ 0           ; Seek relative to beginning of file
SEEK_END                equ 2           ; Seek relative to end of file

; Journal Line Format Constants
JOURNAL_DATE_LEN        equ 10          ; Length of "YYYY-MM-DD" date string (10 bytes)
JOURNAL_TIME_LEN        equ 5           ; Length of "HH:MM" time string (5 bytes)
JOURNAL_SEP_LEN         equ 3           ; Length of " | " separator string (3 bytes)
JOURNAL_PREFIX_LEN      equ 19          ; Prefix: date(10) + space(1) + time(5) + sep(3) = 19
JOURNAL_MAX_LINE        equ 220         ; Prefix(19) + Max Entry(200) + LF(1) = 220 bytes
JOURNAL_DISPLAY_WIDTH   equ 52          ; Max characters displayed per journal row (52 cols)

; Journal Screen Row Coordinates (56-column frame)
UI_JRN_ROW_TOP          equ 1           ; Top border row
UI_JRN_ROW_TITLE        equ 2           ; Title row ("JOURNAL")
UI_JRN_ROW_SEP          equ 3           ; Separator border row
UI_JRN_ROW_FIRST        equ 4           ; First entry row (Row 4)
UI_JRN_ROW_LAST         equ 13          ; Last entry row (Row 13, max 10 entries)
UI_JRN_ROW_BLANK        equ 14          ; Blank spacing row
UI_JRN_ROW_MSG          equ 15          ; User prompt / feedback message row
UI_JRN_ROW_HELP         equ 16          ; Key help prompt row
UI_JRN_ROW_BOTTOM       equ 17          ; Bottom border row
UI_JRN_ROW_BELOW        equ 18          ; Row below frame for erase_eos (ESC[J)

; Journal Screen Column Coordinates
UI_JRN_COL_TITLE        equ 4           ; Title start column
UI_JRN_COL_TEXT         equ 4           ; Entry text column
UI_JRN_COL_MSG          equ 4           ; Message text column
UI_JRN_COL_HELP         equ 4           ; Key help text column

; Keyboard Input Constants (Task 8 Additions)
KEY_N                   equ 78          ; ASCII uppercase 'N' (New entry)
KEY_V                   equ 86          ; ASCII uppercase 'V' (View recent)

; =============================================================================
; Task 9 Additions: Integration, Signals, Size Gate, and Status Styling
; =============================================================================
; Linux Signal Handling (PRD §4.1 FR-U5)
SYS_SIGNAL              equ 48          ; Linux sys_signal system call number
SIGHUP                  equ 1           ; Hangup detected on controlling terminal
SIGINT                  equ 2           ; Interrupt from keyboard (Ctrl+C)
SIGTERM                 equ 15          ; Termination signal
EXIT_SIGNALED           equ 130         ; Standard exit code for SIGINT interruption (128 + 2)

; System Error Codes (errno return values)
ERR_EINTR               equ 4           ; Interrupted system call
ERR_EAGAIN              equ 11          ; Resource temporarily unavailable

; Terminal Window Size Query (PRD §4.1, ioctl TIOCGWINSZ)
TIOCGWINSZ              equ 0x5413      ; ioctl request: get terminal window size
WINSIZE_SIZE            equ 8           ; struct winsize size in bytes
WINSIZE_OFF_ROWS        equ 0           ; Offset of ws_row (word) in struct winsize
WINSIZE_OFF_COLS        equ 2           ; Offset of ws_col (word) in struct winsize
TERM_MIN_COLS           equ 80          ; Minimum required terminal width in columns
TERM_MIN_ROWS           equ 24          ; Minimum required terminal height in rows

; UI Status Message Styling Identifiers (PRD §4.1, §5)
STATUS_INFO             equ 0           ; Information style: bright yellow
STATUS_OK               equ 1           ; Success style: bold green
STATUS_ERR              equ 2           ; Error style: bold red

; Timer Completion Frame Modes (Task 9 Additions, FR-T8)
TIMER_FRAME_RUNNING     equ 0           ; Active/paused timer countdown frame
TIMER_FRAME_BREAK_DONE  equ 1           ; Break completed naturally
TIMER_FRAME_FOCUS_DONE  equ 2           ; Focus completed naturally (quick note prompt)
TIMER_FRAME_NOTE_PROMPT equ 3           ; Note entry active prompt
TIMER_FRAME_NOTE_RESULT equ 4           ; Note save result status message

KEY_Y                   equ 89          ; ASCII uppercase 'Y'

; =============================================================================
; =============================================================================
; Task V4 & G2: 256-Color Theme Engine & Settings Persistence (PRD_V2 §4, §5, PRD_V3 §5, §6)
; =============================================================================

; 24 Color Slots (Normative Order 0..23, PRD_V2 §4, PRD_V3 §5.1, §5.2)
SLOT_BORDER             equ 0           ; Frames, dividers, borders
SLOT_TITLE              equ 1           ; Headings, brand title
SLOT_ACCENT             equ 2           ; Interactive hints, key labels, badges
SLOT_TEXT               equ 3           ; Primary body text
SLOT_DIM                equ 4           ; Secondary labels, inactive items
SLOT_OK                 equ 5           ; Success, completed status
SLOT_WARN               equ 6           ; Warning, paused status
SLOT_ERR                equ 7           ; Error messages, failed status
SLOT_CAT                equ 8           ; Cat ASCII artwork
SLOT_BAR_FULL           equ 9           ; Filled progress bar segments
SLOT_BAR_EMPTY          equ 10          ; Empty progress bar segments
SLOT_HIGHLIGHT          equ 11          ; Selected row background
SLOT_BG                 equ 12          ; Application root background
SLOT_SURFACE            equ 13          ; Sidebar and large panel surface background
SLOT_SURFACE_ALT        equ 14          ; Inner card background
SLOT_BORDER_FOCUS       equ 15          ; Highlighted/active card or button border
SLOT_TITLE_ALT          equ 16          ; End color for brand title gradient
SLOT_TEXT_INV           equ 17          ; Text drawn over highlighted buttons
SLOT_FUR                equ 18          ; Base fur color for cat art
SLOT_FUR_SHADE          equ 19          ; Fur shading / shadow tone
SLOT_FUR_STRIPE         equ 20          ; Fur tabby stripes
SLOT_EAR_BLUSH          equ 21          ; Inner ear fill and cheek blush
SLOT_OUTLINE            equ 22          ; Outer contour outline
SLOT_EYE_NOSE           equ 23          ; Eyes, pupils, nose, mouth

; Theme Subsystem Constants
NUM_SLOTS               equ 24          ; Number of color slots per palette (24 slots, PRD_V3 §5)
NUM_INTERFACE_SLOTS     equ 18          ; Interface slots 0..17
NUM_ART_SLOTS           equ 6           ; Art slots 18..23
SLOT_ART_START          equ 18          ; First art slot ID
SLOT_ART_END            equ 23          ; Last art slot ID
NUM_BUILTIN_THEMES      equ 7           ; Number of built-in themes (0..6)
THEME_CUSTOM_INDEX      equ 7           ; Theme index for custom user palette
THEME_MAX_INDEX         equ 7           ; Maximum valid theme index (0..7)
COLOR_256_MAX           equ 255         ; Maximum 256-color palette index

; Cat Coat Presets (PRD_V3 §5.3)
COAT_ORANGE             equ 0           ; Orange Tabby (Default)
COAT_GRAY               equ 1           ; Gray Tabby
COAT_BLACK              equ 2           ; Black Cat
COAT_WHITE              equ 3           ; White Cat
COAT_CREAM              equ 4           ; Cream / Calico
COAT_TUXEDO             equ 5           ; Tuxedo
COAT_CUSTOM             equ 6           ; Custom user-defined art colors
NUM_COATS               equ 7           ; 7 coat options (0..6)
COAT_MAX_INDEX          equ 6           ; Maximum valid coat index (0..6)
DEFAULT_COAT            equ 0           ; Default coat: Orange Tabby
DEFAULT_MOUSE           equ 1           ; Default mouse: enabled (1)

; Built-in Theme Indices
THEME_STRAWBERRY        equ 0           ; Strawberry Milk (default warm look)
THEME_MATCHA            equ 1           ; Matcha Latte
THEME_BLUEBERRY         equ 2           ; Blueberry
THEME_LAVENDER          equ 3           ; Lavender Night
THEME_SUNSET            equ 4           ; Sunset Peach
THEME_MONO              equ 5           ; Mono Cozy
THEME_CONTRAST          equ 6           ; High Contrast
THEME_CUSTOM            equ 7           ; Custom user-defined palette

; Settings Persistence File Format (settings.dat v1 = 24 bytes, v2 = 48 bytes, PRD_V3 §6)
SETTINGS_FILE_SIZE      equ 48          ; Version 2 exact file size in bytes
SETTINGS_V1_FILE_SIZE   equ 24          ; Version 1 legacy file size in bytes
SETTINGS_MAGIC          equ 0x53574150  ; Little-endian magic dword ('PAWS': 0x50, 0x41, 0x57, 0x53)
SETTINGS_VERSION        equ 2           ; Version 2
SETTINGS_V1_VERSION     equ 1           ; Version 1

; Version 2 Field Offsets (PRD_V3 §6.1)
SETTINGS_OFF_MAGIC      equ 0           ; Offset 0: 4 bytes dword magic
SETTINGS_OFF_VERSION    equ 4           ; Offset 4: 1 byte version (2)
SETTINGS_OFF_THEME      equ 5           ; Offset 5: 1 byte active theme index (0..7)
SETTINGS_OFF_CUSTOM     equ 6           ; Offset 6: 24 bytes custom palette indices
SETTINGS_OFF_ANIM       equ 30          ; Offset 30 (0x1E): 1 byte animation flag (0 or 1)
SETTINGS_OFF_SOUND      equ 31          ; Offset 31 (0x1F): 1 byte sound flag (0 or 1)
SETTINGS_OFF_CHARSET    equ 32          ; Offset 32 (0x20): 1 byte charset flag (0 = UTF-8, 1 = ASCII)
SETTINGS_OFF_NOTIFY     equ 33          ; Offset 33 (0x21): 1 byte notification master flag (0 or 1)
SETTINGS_OFF_LAYERS     equ 34          ; Offset 34 (0x22): 1 byte notification layers bitmask
SETTINGS_OFF_VOLUME     equ 35          ; Offset 35 (0x23): 1 byte audio volume (0..3)
SETTINGS_OFF_MOUSE      equ 36          ; Offset 36 (0x24): 1 byte mouse flag (0 or 1)
SETTINGS_OFF_COAT       equ 37          ; Offset 37 (0x25): 1 byte coat index (0..6)
SETTINGS_OFF_RESERVED   equ 38          ; Offset 38 (0x26): 6 bytes reserved (MUST be 0)
SETTINGS_RESERVED_LEN   equ 6           ; Reserved field length in bytes

; Legacy Version 1 Field Offsets (for migration)
SETTINGS_V1_OFF_ANIM    equ 18
SETTINGS_V1_OFF_SOUND   equ 19
SETTINGS_V1_OFF_CHARSET equ 20
SETTINGS_V1_OFF_NOTIFY  equ 21
SETTINGS_V1_OFF_LAYERS  equ 22
SETTINGS_V1_OFF_VOLUME  equ 23

; Settings Field Validation Limits & Default Values (PRD_V2 §5, PRD_V3 §6.1)
NOTIFY_LAYERS_MASK      equ 0x1F        ; Valid bits 0..4 (bell, flash, title, progress, desktop)
MAX_VOLUME              equ 3           ; Maximum valid volume level (0..3)
DEFAULT_ANIM            equ 1           ; Default animation: enabled (1)
DEFAULT_SOUND           equ 0           ; Default sound: disabled (0)
DEFAULT_CHARSET         equ 0           ; Default charset: UTF-8 (0)
DEFAULT_NOTIFY          equ 0           ; Default notification master: disabled (0)
DEFAULT_NOTIFY_LAYERS   equ 0x01        ; Default notification layers: bell only (bit 0)
DEFAULT_VOLUME          equ 2           ; Default volume: 2 (medium)

; =============================================================================
; Task V5 & G2: Settings Screen & Custom Color Editor (PRD_V2 §4, §5, §6, PRD_V3 §5)
; =============================================================================
SETTINGS_ROW_COUNT      equ 8           ; 8 selectable settings rows (0..7)
SETTINGS_ROW_THEME      equ 0           ; Theme cycle row
SETTINGS_ROW_CUSTOMIZE  equ 1           ; Customize colors row
SETTINGS_ROW_COAT       equ 2           ; Cat coat cycle row
SETTINGS_ROW_ANIM       equ 3           ; Animations on/off row
SETTINGS_ROW_SOUND      equ 4           ; Sound on/off & volume row
SETTINGS_ROW_CHARSET    equ 5           ; Charset UTF-8 / ASCII row
SETTINGS_ROW_NOTIFY     equ 6           ; Terminal integration on/off row
SETTINGS_ROW_RESET      equ 7           ; Reset to defaults row

; Color Editor Group Identifiers (PRD_V3 §5, G2)
COLOR_GROUP_INTERFACE   equ 0           ; Interface slots 0..17
COLOR_GROUP_ART         equ 1           ; Art slots 18..23

; Settings Sub-View Modes
SETTINGS_MODE_MAIN      equ 0           ; Main settings list
SETTINGS_MODE_COLORS    equ 1           ; Dedicated color editor
SETTINGS_MODE_CONFIRM   equ 2           ; Reset confirmation modal

; Color Editor 16x16 Palette Grid Constants
COLOR_GRID_ROWS         equ 16          ; 16 rows of colors
COLOR_GRID_COLS         equ 16          ; 16 columns of colors
COLOR_STEP_PG           equ 16          ; Step size for PgUp / PgDn (+/- 16)

; =============================================================================
; Task V6 / v12 Additions: Cohesive Terminal UI Components & Glyphs
; =============================================================================
GLYPH_HLINE             equ 0           ; ─ or -
GLYPH_VLINE             equ 1           ; │ or |
GLYPH_CORNER_TL         equ 2           ; ╭ or +
GLYPH_CORNER_TR         equ 3           ; ╮ or +
GLYPH_CORNER_BL         equ 4           ; ╰ or +
GLYPH_CORNER_BR         equ 5           ; ╯ or +
GLYPH_TEE_LEFT          equ 6           ; ├ or +
GLYPH_TEE_RIGHT         equ 7           ; ┤ or +
GLYPH_STAR              equ 8           ; ★ or *
GLYPH_HEART             equ 9           ; ♥ or v
GLYPH_DOT_FILLED        equ 10          ; ● or @
GLYPH_DOT_EMPTY         equ 11          ; ○ or o
GLYPH_BAR_FULL          equ 12          ; ▰ or #
GLYPH_BAR_EMPTY         equ 13          ; ▱ or -
GLYPH_SPARKLE           equ 14          ; ✦ or *
GLYPH_HALF_UPPER        equ 15          ; ▀ or -
GLYPH_HALF_LOWER        equ 16          ; ▄ or _
GLYPH_BLOCK_FULL        equ 17          ; █ or #
GLYPH_BLOCK_LEFT        equ 18          ; ▌ or |
GLYPH_BLOCK_RIGHT       equ 19          ; ▐ or |
GLYPH_SHADE_LIGHT       equ 20          ; ░ or .
GLYPH_SHADE_MED         equ 21          ; ▒ or :
GLYPH_SHADE_DARK        equ 22          ; ▓ or #
GLYPH_CHECKMARK         equ 23          ; ✓ or v
GLYPH_COUNT             equ 24

; Big Digit Formatting Flags (Task G5, PRD_V3 §10, §bigdigit_draw)
BIGDIGIT_FMT_NUM        equ 0           ; Ordinary numeric format (0..99)
BIGDIGIT_FMT_MMSS       equ 1           ; Minutes:Seconds format (00:00..99:59)

COZY_TIPS_COUNT         equ 7           ; Number of deterministic daily cozy tips

; =============================================================================
; Task V7 Additions: Animation Engine & Particle System (PRD_V2 §8, §13.5)
; =============================================================================
ANIM_THROTTLE_TICKS     equ 2           ; 2 ticks (200ms) = 5 fps maximum write rate
ANIM_PRNG_MULT          equ 1664525     ; Standard Numerical Recipes LCG multiplier
ANIM_PRNG_INC           equ 1013904223  ; Standard Numerical Recipes LCG increment
ANIM_PRNG_FALLBACK_SEED equ 0x12345678  ; Deterministic nonzero fallback seed

; Animation Region Dirty Flags Bitmask
ANIM_DIRTY_CAT          equ 0x01        ; Cat art region dirty
ANIM_DIRTY_TITLE        equ 0x02        ; Menu title & stars region dirty
ANIM_DIRTY_PROGRESS     equ 0x04        ; Progress bar shimmer dirty
ANIM_DIRTY_PARTICLES    equ 0x08        ; Confetti / heart-pop / zZ garnish dirty

; Effect Timings (in 100ms ticks)
ANIM_BLINK_INTERVAL     equ 30          ; Blink every 30 ticks (3.0 seconds)
ANIM_BLINK_DURATION     equ 2           ; Blink duration = 2 ticks (200 ms)
ANIM_TAIL_PERIOD        equ 3           ; Tail pose changes every 3 ticks (300 ms)
ANIM_TAIL_POSES         equ 3           ; 3 distinct tail poses (0, 1, 2)
ANIM_SHIMMER_PERIOD     equ 2           ; Shimmer advances every 2 ticks (200 ms)
ANIM_ZZ_PERIOD          equ 3           ; Break zZ step period (300 ms)
ANIM_HEART_POP_LIFE     equ 6           ; Heart-pop lifetime = 6 ticks (600 ms)

; Particle System Constants
CONFETTI_MAX            equ 20          ; 20 confetti particles
PARTICLE_OFF_X          equ 0           ; Column (dword)
PARTICLE_OFF_Y          equ 4           ; Row (dword)
PARTICLE_OFF_OLD_X      equ 8           ; Previous column for erasing (dword)
PARTICLE_OFF_OLD_Y      equ 12          ; Previous row for erasing (dword)
PARTICLE_OFF_VX         equ 16          ; Signed horizontal velocity (dword)
PARTICLE_OFF_VY         equ 20          ; Signed vertical velocity (dword)
PARTICLE_OFF_LIFE       equ 24          ; Remaining lifetime in ticks (dword)
PARTICLE_OFF_ACTIVE     equ 28          ; 1 = active, 0 = inactive (dword)
PARTICLE_OFF_GLYPH      equ 32          ; Glyph ID: GLYPH_STAR.. (dword)
PARTICLE_OFF_SLOT       equ 36          ; Color slot ID (dword)
PARTICLE_SIZE           equ 40          ; 40 bytes per particle struct

; =============================================================================
; Task V8 Additions: Synthesized Sound Effects Engine (PRD_V2 §9, §11, §13.5)
; =============================================================================
; Linux Syscalls for Sound Engine Process & Pipe Lifecycle (PRD_V2 §11)
SYS_FORK                equ 2           ; Create child process for audio playback
SYS_EXECVE              equ 11          ; Execute external audio player
SYS_ACCESS              equ 33          ; Check file accessibility (probe player)
SYS_PIPE                equ 42          ; Create unidirectional data channel
SYS_DUP2                equ 63          ; Duplicate a file descriptor

; sys_access check mode
X_OK                    equ 1           ; Test for execute permission

; POSIX Signal Numbers and Dispositions (PRD_V2 §9)
SIGPIPE                 equ 13          ; Broken pipe: write to pipe with no readers
SIGCHLD                 equ 17          ; Child stopped or terminated
SIG_IGN                 equ 1           ; Ignore signal disposition

; Audio Synthesis & Format Constants (PRD_V2 §9)
AUDIO_SAMPLE_RATE       equ 11025       ; 11025 Hz sample rate
AUDIO_CHANNELS          equ 1           ; Mono (1 channel)
AUDIO_BYTES_PER_SAMPLE  equ 1           ; 8-bit unsigned PCM
SFX_BUF_SIZE            equ 32768       ; 32 KB PCM buffer in .bss (~2.97 seconds)
PCM_CENTER              equ 128         ; Digital silence / center for unsigned 8-bit PCM
PCM_MIN                 equ 0           ; Minimum 8-bit PCM value
PCM_MAX                 equ 255         ; Maximum 8-bit PCM value

; Waveform Type Identifiers
WAVE_SQUARE             equ 0           ; Square waveform
WAVE_TRIANGLE           equ 1           ; Triangle waveform
WAVE_REST               equ 2           ; Rest (silence at center 128)

; Sound Effect Identifiers
SFX_NONE                equ 0           ; No sound effect
SFX_START_CHIRP         equ 1           ; Short rising chirp (timer start)
SFX_CLICK               equ 2           ; Short subtle square-wave click
SFX_CHECKIN_SPARKLE     equ 3           ; Four-note C-E-G-C arpeggio (habit check-in)
SFX_FOCUS_FANFARE       equ 4           ; Celebratory sequence (focus completion)
SFX_BREAK_CHIME         equ 5           ; Soft chime (break transition/completion)
SFX_ERROR_BOOP          equ 6           ; Short low-pitched sound (recoverable error)
SFX_DELETE_BLIP         equ 7           ; Short descending blip (journal delete)
SFX_SHORT_MEOW          equ 8           ; Cat pitch glide with vibrato
SFX_COUNT               equ 8           ; Total distinct sound effects

; Audio Player Types (probed via sys_access at startup)
PLAYER_NONE             equ 0           ; No working player detected (use bell fallback)
PLAYER_PAPLAY           equ 1           ; PulseAudio paplay (/usr/bin/paplay)
PLAYER_APLAY            equ 2           ; ALSA aplay (/usr/bin/aplay)

; =============================================================================
; Task V9 Additions: Notifications & Terminal Integration (PRD_V2 §10, §11, §12)
; =============================================================================
NOTIFY_LAYER_BELL       equ 0x01        ; Layer 1: Terminal bell (0x07)
NOTIFY_LAYER_FLASH      equ 0x02        ; Layer 2: Screen flash (ESC[?5h / ESC[?5l)
NOTIFY_LAYER_TITLE      equ 0x04        ; Layer 3: Window title (ESC]0;...)
NOTIFY_LAYER_PROGRESS   equ 0x08        ; Layer 4: Taskbar progress (ESC]9;4;...)
NOTIFY_LAYER_TOAST      equ 0x10        ; Layer 5: Desktop toast (notify-send / powershell)

FLASH_DELAY_NS          equ 150000000   ; Screen flash duration: 150 ms (150,000,000 ns)
NOTIFY_REMINDER_TICKS   equ 600         ; 60 seconds at 100ms ticks = 600 ticks

TASKBAR_STATE_CLEAR     equ 0           ; OSC 9;4 state 0: clear / no progress
TASKBAR_STATE_RUNNING   equ 1           ; OSC 9;4 state 1: normal progress
TASKBAR_STATE_PAUSED    equ 4           ; OSC 9;4 state 4: paused

; =============================================================================
; Task G6 Additions: Layout Tiers, Dashboard Regions & Widget System (PRD_V3 §3)
; =============================================================================

; Responsive Layout Tiers (PRD_V3 §3.1)
TIER_COMPACT            equ 0           ; Width 80-99 cols OR height < 30 rows
TIER_STANDARD           equ 1           ; Width 100-119 cols AND height 30-35 rows
TIER_GRAND              equ 2           ; Width >= 120 cols AND height >= 36 rows

; Named Dashboard Regions (G6 §3.A2)
REGION_HEADER           equ 0           ; Header top area
REGION_SIDEBAR          equ 1           ; Left sidebar panel
REGION_MAIN             equ 2           ; Main content panel
REGION_FOOTER           equ 3           ; Bottom status / keybar area
REGION_CARD_POMO        equ 4           ; Today's progress mascot / stat card
REGION_CARD_HABITS      equ 5           ; Habits progress slider card
REGION_CARD_TIP         equ 6           ; Daily tip card
REGION_CARD_JOURNAL_BTN equ 7           ; Quick journal action button
REGION_CARD_JOURNAL     equ 8           ; Quick journal recent notes card
REGION_COUNT            equ 9           ; Total named regions

; Rectangle Structure Offsets (16 bytes per rect_t)
RECT_ROW                equ 0           ; 1-based row coordinate (dword)
RECT_COL                equ 4           ; 1-based column coordinate (dword)
RECT_W                  equ 8           ; Width in terminal cells (dword)
RECT_H                  equ 12          ; Height in terminal rows (dword)
RECT_SIZE               equ 16          ; Total byte size of rectangle struct

; Reusable Widget States & Flags (G6 §3.B)
WDG_STATE_NORMAL        equ 0           ; Default unselected widget state
WDG_STATE_FOCUSED       equ 1           ; Keyboard / mouse focused widget state
WDG_STATE_PRESSED       equ 2           ; Actively triggered / clicked widget state

; Widget Panel Flags
WDG_PANEL_FLAG_NONE     equ 0           ; Plain rounded panel without decorations
WDG_PANEL_FLAG_TAB      equ 1           ; Draw title tab on top border
WDG_PANEL_FLAG_FOCUS    equ 2           ; Highlight border with SLOT_BORDER_FOCUS
WDG_PANEL_FLAG_SHADOW   equ 4           ; Subtle drop shadow along right and bottom edges

; Widget Toggle States
WDG_TOGGLE_OFF          equ 0           ; Toggle switch OFF state
WDG_TOGGLE_ON           equ 1           ; Toggle switch ON state

; Keybar Entry Structure Offsets
KEYBAR_ENTRY_KEY        equ 0           ; Pointer to key label string (e.g. "Q")
KEYBAR_ENTRY_DESC       equ 4           ; Pointer to description string (e.g. "Quit")
KEYBAR_ENTRY_PRIO       equ 8           ; Priority (0 = highest / always show, 1..3 = lower)
KEYBAR_ENTRY_SIZE       equ 12          ; 12 bytes per keybar hint definition

; Shortcut Keys
KEY_CTRL_L              equ 12          ; ASCII 12 (FF / Ctrl+L, hidden G6 layout test screen)
