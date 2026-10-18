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
