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
SYS_TIME                equ 13          ; Get time in seconds since Unix epoch
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
CHAR_PLUS               equ 43          ; Plus symbol ('+')
CHAR_MINUS              equ 45          ; Hyphen/dash symbol ('-')
CHAR_ZERO               equ 48          ; ASCII digit zero ('0')
CHAR_COLON              equ 58          ; Colon symbol (':')
CHAR_SEMICOLON          equ 59          ; Semicolon symbol (';')
CHAR_LBRACKET           equ 91          ; Left square bracket ('[')
CHAR_UPPER_H            equ 72          ; Uppercase letter H ('H')
CHAR_PIPE               equ 124         ; Vertical bar / pipe symbol ('|')

KEY_CTRL_C              equ 3           ; ASCII 3 (ETX / Ctrl+C)
KEY_BACKSPACE           equ 127         ; Backspace / Delete
KEY_ENTER               equ 10          ; Enter / Line Feed
KEY_ESC                 equ 27          ; Escape key
KEY_SPACE               equ 32          ; Spacebar key
KEY_NONE                equ -1          ; Sentinel value: no key available

; =============================================================================
; Memory Buffer Sizes (.bss Budget, PRD §6.5)
; =============================================================================
OUT_BUF_SIZE            equ 8192        ; Terminal output frame buffer size
IN_BUF_SIZE             equ 16          ; Raw keyboard input buffer size
LINE_BUF_SIZE           equ 256         ; Line input editing buffer size
FILE_BUF_SIZE           equ 512         ; File persistence I/O buffer size
JRNL_BUF_SIZE           equ 4096        ; Journal viewing read buffer size
TIMESPEC_SIZE           equ 8           ; struct timespec size (2 dwords: sec, nsec)

; =============================================================================
; Application Domain Limits (PRD §4.3, §4.4)
; =============================================================================
MAX_HABITS              equ 8           ; Maximum number of tracked habits
HABIT_NAME_MAX          equ 31          ; Maximum characters in a habit name
HABIT_RECORD_SIZE       equ 48          ; Bytes per habit record in habits.dat
JOURNAL_ENTRY_MAX       equ 200         ; Maximum characters per journal entry
JOURNAL_VIEW_LINES      equ 10          ; Number of recent entries shown in view
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

; =============================================================================
; Terminal & Key Processing Constants (Task 2 Additions)
; =============================================================================
FD_STDERR               equ 2           ; Standard error file descriptor
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
; Task 4 Additions: UI Frame Geometry, Cat Art & Shell Navigation (PRD §4.1, §5)
; =============================================================================
UI_FRAME_WIDTH          equ 56          ; Total frame width in columns
UI_FRAME_INNER_WIDTH    equ 54          ; Inner horizontal border width (56 - 2)
UI_FRAME_COL_LEFT       equ 1           ; Left border column
UI_FRAME_COL_RIGHT      equ 56          ; Right border column

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
UI_MENU_ROW_ITEMQ       equ 12          ; Menu option Q (Quit) row
UI_MENU_ROW_BOTTOM      equ 13          ; Bottom border row
UI_MENU_ROW_BELOW       equ 14          ; Row below frame for erase_eos

; Main Menu Column Coordinates
UI_MENU_COL_CAT         equ 4           ; Cat ASCII art column
UI_MENU_COL_TITLE       equ 14          ; Main title & tagline column
UI_MENU_COL_CONTENT     equ 4           ; Dashboard and menu items column

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

; Cat Poses (PRD §6.4)
CAT_POSE_IDLE           equ 0           ; Pose 0: Idle cat (main menu)
CAT_POSE_WORKING        equ 1           ; Pose 1: Working / focused eyes (timer focus)
CAT_POSE_RESTING        equ 2           ; Pose 2: Resting / sleeping (timer break)
CAT_POSE_MAX            equ 2           ; Maximum valid pose index
CAT_LINES               equ 3           ; Number of lines in cat ASCII art

; Keyboard Input Constants (Task 4 Additions)
CHAR_SLASH              equ 47          ; Slash symbol ('/')
KEY_1                   equ 49          ; ASCII '1'
KEY_2                   equ 50          ; ASCII '2'
KEY_3                   equ 51          ; ASCII '3'
KEY_4                   equ 52          ; ASCII '4'
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

