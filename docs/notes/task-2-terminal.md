# Task 2: Terminal Control & Keyboard Input Walkthrough

**Task ID:** `task-2-terminal`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the Linux terminal subsystem, termios structures, raw vs. cooked modes, non-blocking keyboard input polling, escape sequence handling, line input editing, and robust cleanup routines implemented in Task 2. It is written in plain language so any group member can confidently explain and demonstrate these components during project defense and live evaluations.

---

## 1. Cooked Mode vs. Raw Mode: Why Does Pawmodoro Need Both?

Standard Linux terminals operate in **Cooked (Canonical) Mode** by default. In cooked mode:
- The Linux kernel intercepts and buffers all keystrokes in a line discipline queue until the user presses Enter (`\n`).
- The kernel handles local echo (printing characters as you type) and line editing (processing Backspace, Delete, and Ctrl+U).
- Control characters trigger OS signals: pressing Ctrl+C raises `SIGINT` (killing the program), and Ctrl+Z raises `SIGTSTP`.

While cooked mode is ideal for shell command prompts and note-taking, it makes interactive terminal games, productivity timers, and menus impossible because:
1. `read` blocks until the user presses Enter (a Pomodoro timer cannot countdown or respond to a single keypress like 'P' or 'Q' without Enter).
2. Local echo would clutter the UI frames with typed characters.
3. Ctrl+C would abruptly terminate the application before it can save your data and restore the terminal.

**Raw Mode:**  
Pawmodoro switches the terminal into **Raw Mode** during menus and timer execution. In raw mode:
- Canonical line buffering and local echo are disabled.
- Keystrokes become immediately available to `read` as single bytes without waiting for Enter.
- Special signal keys (like Ctrl+C) are received as raw bytes rather than terminating the process.

Pawmodoro seamlessly switches between the two:
- **Raw mode** is used for menus, active Pomodoro sessions, and quick single-key navigation.
- **Cooked mode** is temporarily re-enabled by `read_line` whenever the user needs to type text (such as adding a new habit or writing a journal entry), providing full native Backspace editing.

---

## 2. The Linux `termios` Structure and Fields Modified

The Linux terminal attributes are configured using system call `ioctl` (number 54, `SYS_IOCTL`) with requests `TCGETS` (`0x5401`, read attributes) and `TCSETS` (`0x5402`, apply attributes).

On 32-bit x86 Linux, `struct termios` is exactly **36 bytes**:

```
+---------------------+---------------------+---------------------+---------------------+
| c_iflag (4 bytes)   | c_oflag (4 bytes)   | c_cflag (4 bytes)   | c_lflag (4 bytes)   |
| input modes @0      | output modes @4     | control modes @8    | local modes @12     |
+---------------------+---------------------+---------------------+---------------------+
| c_line (1 byte) @16 | c_cc[19] (19 bytes) control characters array @17..35            |
+---------------------+-----------------------------------------------------------------+
```

### The Exact Flags Modified for Raw Mode

1. **`c_lflag` (Offset 12, Local Flags):**
   We clear three specific bits:
   ```nasm
   and dword [termios_raw + C_LFLAG_OFFSET], ~(ICANON | ECHO | ISIG)
   ```
   - **`ICANON` (`0x02`):** Disables canonical mode. Input is processed byte-by-byte rather than line-by-line.
   - **`ECHO` (`0x08`):** Disables local echo. Typing does not visibly write over UI art.
   - **`ISIG` (`0x01`):** Disables signal generation for control keys. Ctrl+C arrives as byte `3` (`KEY_CTRL_C`) instead of terminating the app via `SIGINT`.
2. **`c_cc` Array (Offset 17, Control Characters):**
   We configure two control character parameters:
   - **`VMIN` (Index 6, Offset 23):** Set to `0`. Minimum number of characters for a non-canonical read.
   - **`VTIME` (Index 5, Offset 22):** Set to `0`. Timeout in deciseconds for non-canonical read.
   With `VMIN = 0` and `VTIME = 0`, any `sys_read` call returns **immediately** with 0 bytes if no key has been pressed. It never blocks or freezes the application!
3. **`c_oflag` (Output Flags) Left Untouched:**
   We deliberately do NOT touch `c_oflag` (`OPOST` remains enabled). This allows `\n` to automatically perform carriage return and line feed, keeping output formatting straightforward.

---

## 3. Why the Terminal Must Always Be Restored: `term_restore`

When Pawmodoro enters raw mode, switches to the alternate screen (`ESC[?1049h`), and hides the cursor (`ESC[?25l`), the terminal environment is heavily altered.

If the program were to exit without reversing these changes:
- Local echo would remain OFF: the user would type in their shell and see nothing on screen!
- Canonical mode would remain OFF: Enter and Backspace in the shell would break.
- The cursor would remain invisible.
- The user would be trapped in the alternate screen buffer.

### The Single Cleanup Path
To guarantee that the terminal is never left broken:
- `term_restore` is the single, centralized cleanup procedure in the application.
- It restores `termios_orig` via `TCSETS`.
- It resets text colors/styles (`ansi_reset`), shows the cursor (`ansi_show_cursor`), and switches back to the primary screen buffer (`ansi_alt_off`).
- It uses an internal flag (`term_active`) to be completely **idempotent**: calling it twice or calling it before `term_init` is 100% safe.
- Every exit path in the program (pressing 'Q', pressing Ctrl+C, or encountering an unrecoverable error) calls `term_restore` before `sys_exit`.

---

## 4. Keyboard Input Mechanics: `key_poll` and `key_wait`

### Non-Blocking Input with `key_poll`
`key_poll` calls `sys_read(FD_STDIN, in_buf, 1)`:
- If 0 bytes are read, it returns `KEY_NONE` (`-1`).
- Lowercase letters (`'a'..'z'`) are converted to uppercase (`'A'..'Z'`) by masking out bit 5 (`and al, ~CASE_BIT_MASK`), so menus can handle `'q'` and `'Q'` identically.
- The byte is returned zero-extended in `EAX` (`0..255`), ensuring it never collides with `-1`.

### How Escape Sequences are Swallowed
When a user presses an arrow key (such as Up Arrow), the terminal sends a 3-byte escape sequence: `ESC [ A` (`27`, `91`, `65`).
- If `key_poll` read only the first byte, it would see `27` and might interpret it as the Escape key, leaving `[` and `A` in the buffer to be mistakenly read as subsequent keystrokes!
- **Our Solution:** When `key_poll` sees `CHAR_ESC` (`27`), it immediately performs a non-blocking check for follow-up bytes:
  - If no follow-up byte is in the queue, it was a genuine lone Escape press $\rightarrow$ returns `KEY_ESC` (`27`).
  - If follow-up bytes are present, it is a multi-byte escape sequence (arrow key, Home, End, F-key) $\rightarrow$ it drains all remaining bytes in the burst and returns `KEY_NONE` (`-1`). Nothing leaks into subsequent polls!

### Why `key_wait` Sleeps 50 Milliseconds
A naive event loop that repeatedly polls `key_poll` in a tight loop would consume 100% of a CPU core (busy-waiting).  
Instead, `key_wait` checks `key_poll`, and if no key is ready, invokes `sys_nanosleep` for 50 milliseconds (`NANOSLEEP_50MS = 50,000,000 ns`).  
- 50 ms provides snappy, lag-free user responsiveness (20 checks per second).
- Idle CPU usage remains at **0.0%**, as verified by `top`.

---

## 5. Line Input and Overflow Draining: `read_line`

When the user enters text in cooked mode (for example, typing a 10-character habit name), `read_line`:
1. Flushes any pending prompt text to stdout.
2. Temporarily switches to cooked mode (`term_cooked`) and unhides the cursor.
3. Requests `max_chars + 1` bytes from `sys_read`.
4. Handles two distinct input scenarios:
   - **Normal Input:** The user types within the limit and presses Enter. The trailing newline (`\n`) is read, stripped, replaced with `\0`, and the exact length is returned.
   - **Overlong Input:** If the user types 60 characters into a 20-character limit, `sys_read` returns the first 21 bytes without a newline. The string is truncated cleanly at 20 characters (`[edi + 20] = 0`). Then, `read_line` enters a drain loop reading single bytes in cooked mode until the newline is consumed. This prevents leftover characters from spilling over as phantom keypresses into the next raw-mode menu!
5. Re-hides the cursor, restores raw mode (`term_raw`), and returns the stored length in `EAX`.

---

## 6. How to Debug Terminal Control with `strace` and `gdb`

### System Call Tracing with `strace`
To trace terminal mode switches and sleep cycles in real time:
```bash
strace -e trace=ioctl,read,write,nanosleep ./build/pawmodoro
```
- Verify `ioctl(0, TCGETS, ...)` on boot.
- Verify `ioctl(0, TCSETS, ...)` switching between raw and cooked modes.
- Verify `nanosleep({tv_sec=0, tv_nsec=50000000})` every 50 ms during idle periods.
- Verify `ioctl(0, TCSETS, ...)` restoring original settings on exit.

### Register Inspection with `gdb`
Launch the debugger using the Makefile target:
```bash
make debug
```
Set breakpoints at procedure entry and exit to verify register preservation:
```gdb
break term_raw
break key_wait
run
info registers
continue
```
All general-purpose registers (`EBX`, `ECX`, `EDX`, `ESI`, `EDI`) are preserved across procedure boundaries per PRD §6.2 rule 1.
