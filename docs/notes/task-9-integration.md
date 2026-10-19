# Task 9: Integration & Polish Walkthrough

**Task ID:** `task-9-integration`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the architectural integration, signal-handling safety, terminal dimension gating, visual polish, and automated verification of Task 9 (Integration and Polish) for Pawmodoro. It details how the Pomodoro timer, habit tracker, and journal subsystems unite into a rock-solid, abuse-resilient terminal application written in 32-bit x86 NASM (Linux `int 0x80`, no libc).

---

## 1. Overview & Integration Architecture

Before Task 9, Pawmodoro's three primary modules—the Focus Timer (Tasks T4/T5), Habit Tracker (Task T7), and Journal (Task T8)—functioned independently with their own local states and file persistence:
- **Timer:** Maintained session counts, phase transitions, and saved completed focus sessions to `stats.dat`.
- **Habits:** Tracked habit completions in `habits.dat` and exported dashboard tallies.
- **Journal:** Appended timestamped reflections to `journal.txt`.

Task 9 integrates these capabilities into a single seamless workflow while hardening the application against all forms of interactive abuse:
1. **Cross-Feature Workflow (FR-T8):** Naturally completing a focus session now invites the user to capture a quick reflection that is directly appended to `journal.txt` via `journal_add` before continuing to the break.
2. **Dynamic Dashboard (FR-U7):** Every return to the main menu immediately refreshes the pomodoro and habit counters live from memory without disk latency.
3. **Fail-Safe Terminal Restoration (FR-U5):** Signal handlers for SIGHUP, SIGINT, and SIGTERM, coupled with a central exit coordinator and write-error recursion guard, guarantee that the user's terminal is restored under every conceivable exit path.
4. **Dimension Protection:** A terminal size gate (`TIOCGWINSZ`) halts rendering and alerts the user if the window shrinks below the required 80×24 layout, resuming cleanly when resized.
5. **Visual Uniformity:** Every framed view adheres to a uniform two-line footer convention (status message on row $N-1$, key help on row $N$), with border erase sequences wiping any wrapped text residue.

```
                      +-----------------------------------+
                      |         _start / main.asm         |
                      |   term_init -> term_install_sig   |
                      +-----------------+-----------------+
                                        |
               +------------------------+------------------------+
               |                        |                        |
               v                        v                        v
     +--------------------+   +--------------------+   +--------------------+
     |    Timer Screen    |   |   Habits Screen    |   |   Journal Screen   |
     | Focus / Break Loop |   |  Add / Done / Del  |   |   Add / Tail View  |
     +---------+----------+   +---------+----------+   +---------+----------+
               |                        |                        |
               | (Focus Natural Done)   |                        |
               v                        |                        |
     +--------------------+             |                        |
     |   FR-T8 Quick Note +-------------+------------------------+
     |   -> journal_add   |
     +---------+----------+
               |
               v (Any return to menu)
     +--------------------+
     | dashboard_refresh  |
     | -> stats_today     |
     | -> habits_sync_dash|
     +--------------------+
```

---

## 2. FR-T8: Quick-Note Flow After Focus Completion

### Purpose and Triggering Conditions
Under PRD §4.2 FR-T8, when a user finishes a focus session naturally (the countdown decrements all the way to 00:00), Pawmodoro offers the opportunity to record a brief note summarizing what was accomplished.
- **Trigger Condition:** Only entered via `.phase_natural_complete` when `phase == TIMER_PHASE_FOCUS`.
- **Excluded Paths:** Skipped sessions (`[S]`) and stopped sessions (`[Q]`) never trigger the prompt; they advance or exit immediately without interruption.

### Frame Progression & State Extension
The timer engine's completion frame renderer was extended to support distinct modal phases via `completion_flag` values:
- `TIMER_FRAME_RUNNING` (`0`): Normal countdown rendering with active footer `[P] Pause   [S] Skip   [Q] Stop`.
- `TIMER_FRAME_BREAK_DONE` (`1`): Break completed; displays bell and footer `[Any key] Continue   [Q] Stop and go back`.
- `TIMER_FRAME_FOCUS_DONE` (`2`): Focus naturally completed; message row displays `Focus complete! Add a quick note? (y/n)` and footer displays `[Y] Add note   [Any other key] Continue to break`.
- `TIMER_FRAME_NOTE_PROMPT` (`3`): Interactive prompt row displays `Note (max 200, Enter alone cancels): `.
- `TIMER_FRAME_NOTE_RESULT` (`4`): Result status displays either green `Note saved - press any key for a break.` or red `Could not save` with footer `[Any key] Continue to break`.

### Step-by-Step Interactive Flow
1. **Decision Gate:** The completion frame paints with `completion_flag = 2`. The application blocks on `key_wait`.
   - `Ctrl+C`: Sets `state = STATE_QUIT`, breaking the loop and routing to `app_exit`.
   - `'Y'` / `'y'`: Advances to the note entry sub-state.
   - Any other key (including `'Q'`, Space, or Enter): Skips note taking and directly advances to the scheduled break phase.
2. **Note Input Modal:**
   - The timer paints the frame with `completion_flag = 3`.
   - To align cooked-mode typing immediately after the prompt, the cursor is positioned dynamically using `str_len` on `timer_msg_note_input`:
     $$\text{Cursor Col} = 4 + \text{strlen}(\text{"Note (max 200, Enter alone cancels): "})$$
   - Line input is gathered via `read_line` into `line_buf` with maximum length `JOURNAL_ENTRY_MAX` (`200` characters).
3. **Empty Input Cancellation:**
   - If `read_line` returns length `0` (Enter pressed alone), the note is cancelled silently with no disk activity and the timer transitions straight to the break.
4. **Persistence via `journal_add`:**
   - Non-empty text is passed via `mov esi, line_buf` to `journal_add`.
   - On success (`EAX == 0`), `timer_result_msg` is set to `timer_msg_note_saved` (green) and the frame is redrawn with `completion_flag = 4`. A final `key_wait` pauses until the user acknowledges, then advances to the break.
   - On failure (`EAX == -1`), `timer_result_msg` is set to `err_could_not_save` (red) and acknowledged similarly.
5. **Cooked-Mode Residue Cleanup:**
   - When the user types up to 200 characters in cooked mode, terminal line wrapping can splash characters across subsequent lines. Redrawing the entire frame immediately after `read_line` completely wipes this residue.

---

## 3. Live Dashboard Reload (`dashboard_refresh`)

### The Midnight & Navigation Stale Data Problem
Prior to Task 9, dashboard tallies (`dash_pomodoros`, `dash_habits_done`, `dash_habits_total`) were loaded once at startup. If the user finished a focus session or checked in a habit and returned to the main menu, or if midnight passed while the app remained open, the menu dashboard displayed obsolete counts unless the application was restarted.

### Memory Write-Through Architecture
Pawmodoro maintains in-memory state as the authoritative write-through cache:
- `stats_record`: The active day's pomodoro count is incremented in `.bss` and written to disk upon every completed focus phase.
- `habit_table`: Habit check-in bitmasks are updated in `.bss` and written to `habits.dat` upon every check-in.

`dashboard_refresh` leverages this write-through design by reading live memory without performing any disk I/O:
```nasm
; -----------------------------------------------------------------------------
; dashboard_refresh - Reload live metrics into menu dashboard variables
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only (all general-purpose registers preserved)
; -----------------------------------------------------------------------------
dashboard_refresh:
    save_regs

    ; 1. Query today's completed pomodoros from stats subsystem
    call stats_today            ; EAX = today's count (handles rollover)
    mov dword [dash_pomodoros], eax

    ; 2. Sync habit completion totals from habits subsystem
    call habits_sync_dashboard  ; Updates dash_habits_done, dash_habits_total

    restore_regs
    ret
```

### Call Points
`dashboard_refresh` is invoked:
1. In `_start` immediately after `stats_load` and `habits_load`.
2. Immediately before every invocation of `ui_draw_menu` in the main loop.
This guarantees that returning from the timer, habit tracker, or journal, as well as toggling demo mode, always displays 100% synchronized figures.

---

## 4. Exit Path Hardening & Signal Handling

### The Broken Terminal Vulnerability
Under raw terminal mode (`term_raw`), standard POSIX signals like `SIGINT` (generated by `Ctrl+C`) are suppressed because the tty driver does not interpret control characters. Instead, `0x03` is delivered as a raw byte to `key_poll`, which gracefully returns to the main loop and executes `term_restore`.

However, during line input (`read_line` in habits, journal, and the new quick-note prompt), the terminal must be switched to canonical cooked mode (`term_cooked`). Cooked mode enables `ISIG` and `ECHO`. If a user pressed `Ctrl+C` while typing:
1. The kernel tty layer generated `SIGINT` (signal 2).
2. Because no signal handler was registered, Linux executed the default action: terminating the process immediately.
3. The process died without invoking `term_restore`.
4. **Symptom:** The user's shell remained trapped in the alternate screen buffer (`?1049h`), with the hardware cursor hidden (`?25l`) and echo disabled.

### The Solution: Signal Interception & Centralized Exit
To eliminate every possibility of an un-restored terminal, Task 9 introduced signal installation and a centralized exit procedure:

```
                      +-------------------------------+
                      |   Kernel Signal or Normal Q   |
                      +---------------+---------------+
                                      |
         +----------------------------+----------------------------+
         |                                                         |
         v (SIGHUP / SIGINT / SIGTERM)                             v (Menu 'Q' / Normal)
+------------------------+                               +------------------------+
|      sig_handler       |                               |      .handle_exit      |
|    EBX = 130 (SIG)     |                               |      EBX = 0 (SUCCESS) |
+-----------+------------+                               +-----------+------------+
            |                                                        |
            +----------------------------+---------------------------+
                                         |
                                         v
                              +--------------------+
                              |      app_exit      |
                              | [app_exiting] = 1  |
                              | call term_restore  |
                              | sys_exit(EBX)      |
                              +--------------------+
```

#### 1. Signal Installation (`term_install_signals`)
Installed in `_start` right after `term_init` succeeds. It registers `sig_handler` for `SIGHUP` (1), `SIGINT` (2), and `SIGTERM` (15) via `sys_signal` (syscall 48):
```nasm
term_install_signals:
    save_regs
    mov eax, SYS_SIGNAL         ; 48
    mov ebx, SIGHUP             ; 1
    mov ecx, sig_handler
    int 0x80

    mov eax, SYS_SIGNAL         ; 48
    mov ebx, SIGINT             ; 2
    mov ecx, sig_handler
    int 0x80

    mov eax, SYS_SIGNAL         ; 48
    mov ebx, SIGTERM            ; 15
    mov ecx, sig_handler
    int 0x80
    restore_regs
    ret
```

#### 2. The Signal Handler (`sig_handler`)
When a signal arrives, the kernel creates a stack frame containing the signal number and invokes `sig_handler`. The handler terminates the application with standard Linux signal exit code `130` ($128 + \text{SIGINT}$):
```nasm
sig_handler:
    mov ebx, EXIT_SIGNALED      ; 130
    jmp app_exit                ; Never returns
```

#### 3. Central `app_exit` & Recursion Guard
All termination paths (normal quit, fatal error, signals) funnel into `app_exit`. To prevent infinite recursive loops (e.g. if `sys_write` inside `term_restore` fails), `app_exit` sets an atomic flag `[app_exiting] = 1`:
```nasm
app_exit:
    mov dword [app_exiting], 1  ; Set guard flag
    push ebx                    ; Preserve exit code across restore
    call term_restore           ; Reset alternate screen, show cursor, cooked
    pop ebx                     ; Restore exit code
    mov eax, SYS_EXIT           ; 1
    int 0x80
    hlt
```

#### 4. `buf_flush` Short-Write & Error Handling
`buf_flush` now audits the return value of `sys_write`:
- **Short Write:** If `sys_write` outputs fewer bytes than requested (e.g. due to pipe buffer saturation), it advances the buffer pointer and writes the remainder in a loop.
- **Interrupted Syscall (`-EINTR`):** Retried automatically without treating it as an error.
- **Unrecoverable Failure:** If `[app_exiting] == 1`, it resets `out_len` and returns to prevent recursive crashing. If `[app_exiting] == 0`, it invokes `app_exit(EXIT_FAILURE)`.

---

## 5. Terminal Size Gate (`TIOCGWINSZ`)

### The 80×24 Geometry Requirement
Pawmodoro's UI frames are 56 columns wide and up to 18 rows high. To ensure borders, ASCII art, and status lines render without wrapping or truncating, the PRD mandates a minimum terminal dimension of **80 columns by 24 rows** (the standard VT100/ANSI baseline).

### The Linux `winsize` Structure
Terminal dimensions are queried from the tty driver using `ioctl(0, TIOCGWINSZ, winsize)`. The Linux kernel defines `struct winsize` as 4 consecutive 16-bit words (8 bytes total):
```c
struct winsize {
    unsigned short ws_row;     /* Offset 0: rows in characters */
    unsigned short ws_col;     /* Offset 2: columns in characters */
    unsigned short ws_xpixel;  /* Offset 4: horizontal pixel size (unused) */
    unsigned short ws_ypixel;  /* Offset 6: vertical pixel size (unused) */
};
```

In Pawmodoro:
```nasm
WINSIZE_SIZE        equ 8
WINSIZE_OFF_ROWS    equ 0
WINSIZE_OFF_COLS    equ 2
```

### Evaluation Logic (`term_size_ok`)
`term_size_ok` queries `ioctl(STDIN_FILENO, TIOCGWINSZ, winsize)`:
1. **Fallback for Non-TTY/Pipes:** If `ioctl` returns a negative error code (e.g. `ENOTTY`), or if both rows and cols are reported as 0, `term_size_ok` assumes the terminal is acceptable (`EAX = 1`).
2. **Dimension Check:** Words are extracted using zero-extension (`movzx`):
   ```nasm
   movzx eax, word [winsize + WINSIZE_OFF_COLS]
   movzx edx, word [winsize + WINSIZE_OFF_ROWS]
   ```
3. **Threshold Gate:** If `cols < 80` or `rows < 24`, it stores the dimensions in `term_cols` and `term_rows` and returns `EAX = 0` (too small). Otherwise, it returns `EAX = 1`.

### The Blocking Size Gate (`ui_size_gate`)
Called as the **very first instruction** of every primary screen renderer (`ui_draw_menu`, `timer_draw`, `habits_draw`, `journal_draw`):
```nasm
ui_size_gate:
    save_regs
.check:
    call term_size_ok
    test eax, eax
    jnz .done                   ; Terminal is >= 80x24: return immediately

    ; Clear screen and display enlarge warning
    call buf_reset
    mov esi, ansi_clear
    call buf_str
    mov esi, ansi_home
    call buf_str

    ; Row 1: Please enlarge the terminal
    mov esi, ui_msg_enlarge
    call buf_str
    mov al, CHAR_LF
    call buf_char

    ; Row 2: (need 80x24, now <cols>x<rows>)
    mov esi, ui_msg_need_prefix
    call buf_str
    mov eax, dword [term_cols]
    call buf_u32
    mov esi, ui_msg_need_x
    call buf_str
    mov eax, dword [term_rows]
    call buf_u32
    mov esi, ui_msg_need_suffix
    call buf_str
    call buf_flush

.loop:
    call time_sleep_100ms
    call key_poll
    cmp eax, KEY_CTRL_C
    jne .check_size
    ; Ctrl+C pressed while inside gate -> clean exit
    mov ebx, EXIT_SUCCESS
    call app_exit

.check_size:
    call term_size_ok
    test eax, eax
    jz .loop                    ; Still too small: keep waiting

    ; Terminal enlarged! Clear screen so normal frame paints on clean canvas
    call buf_reset
    mov esi, ansi_clear
    call buf_str
    call buf_flush

.done:
    restore_regs
    ret
```

### Documented Limitations
1. **Redraw Boundary Detection:** Because Pawmodoro does not hook `SIGWINCH` (avoiding complex asynchronous signal re-entrancy in assembly), window size changes are evaluated at each screen redraw.
2. **Timer Freeze During Gating:** If the terminal is shrunk while the Pomodoro timer is running, the countdown ticks are temporarily paused while the size gate is active. Once the window is enlarged to 80×24, the timer resumes.

---

## 6. Unified Status & Key-Help Footer Conventions

To provide an intuitive, polished user experience across all three subsystems, every framed screen adheres to a strict footer convention:
- **Status/Message Row (Col 4):** Displays contextual alerts, check-in confirmations, error messages, or demo mode notices.
- **Key-Help Row (Col 4):** Displays valid keyboard shortcuts for the current view.
- **Bottom Border:** Horizontal frame border terminating the window.

### Screen Layout Geometry Comparison

| Screen | Frame Height | Interior Rows | Status Row | Key-Help Row | Bottom Border |
|---|---|---|---|---|---|
| **Timer** | 10 rows | 2–9 | Row 8 | Row 9 | Row 10 |
| **Habits** | 16 rows | 2–15 | Row 14 | Row 15 | Row 16 |
| **Journal** | 17 rows | 2–16 | Row 15 | Row 16 | Row 17 |
| **Main Menu** | 15 rows | 2–14 | Row 13 | Row 14 | Row 15 |

### Standardized Status Helper (`ui_draw_status`)
Implemented in `src/ui.asm`, `ui_draw_status` formats status messages consistently:
- **Input:** `EAX` = row number, `ESI` = pointer to string (`0` = draw blank row), `EBX` = style code (`STATUS_INFO`, `STATUS_OK`, `STATUS_ERR`).
- **Styling:**
  - `STATUS_INFO` (`1`): Bold bright yellow (`ESC[1;93m`)
  - `STATUS_OK` (`2`): Bold bright green (`ESC[1;92m`)
  - `STATUS_ERR` (`3`): Bold bright red (`ESC[1;91m`)
- Automatically wraps the content inside `ui_frame_row` at column 4, ensuring alignment with the frame border.

---

## 7. Visual Glitch Eradication

### 1. Border Wrap Artifacts Fixed via `ansi_erase_eol`
**Symptom:** When a user entered a long string (up to 200 characters) in cooked mode, terminal linewrap caused trailing characters to spill onto rows occupied by horizontal borders (rows 1, 5, 13, 15, 17). Redrawing the border repainted the `+---+` sequence, but leftover characters remained visible to the right of column 56.  
**Cause:** `ui_frame_hline` rendered the border characters up to column 56 but did not instruct the terminal emulator to erase the remainder of the physical scanline.  
**Fix:** In `src/ui.asm`, `ui_frame_hline` was updated to append `ansi_erase_eol` (`ESC[K`) immediately following the closing `+`:
```nasm
    ; Right border '+'
    mov al, CHAR_PLUS
    call buf_char

    ; Erase remainder of line to prevent wrapped text artifacts
    mov esi, ansi_erase_eol
    call buf_str
```

### 2. Inactive Timer Footer on Completion Frames
**Symptom:** When a focus or break session reached 00:00, the completion frame continued to display `[P] Pause [S] Skip [Q] Stop`, despite none of those keys performing those actions on completion frames.  
**Cause:** `timer_draw` previously painted the identical static footer regardless of whether the phase was active or completed.  
**Fix:** `timer_draw` now inspects `completion_flag` and renders contextually appropriate help:
- Running: `[P] Pause   [S] Skip   [Q] Stop`
- Break Complete: `[Any key] Continue   [Q] Stop and go back`
- Focus Complete: `[Y] Add note   [Any other key] Continue to break`

---

## 8. Latent Bug Fix in `stats_load`

**Symptom:** If `stats.dat` was missing, truncated, or unreadable, `stats_load` failed to take the `.load_empty_state` branch, relying accidentally on uninitialized memory.  
**Cause:** `file_load` returns `FILE_ERR` (`-1` / `0xFFFFFFFF`) on read failure. In `src/stats.asm`, the validation check performed:
```nasm
cmp eax, STATS_RECORD_SIZE      ; STATS_RECORD_SIZE = 12
jb .load_empty_state
```
Because `jb` (Jump if Below) is an **unsigned comparison**, `0xFFFFFFFF` is treated as $4,294,967,295$, which is greater than 12. Consequently, the jump was not taken.  
**Fix:** Inserted a signedness check before the unsigned comparison, matching the safe pattern established in `habits_load`:
```nasm
test eax, eax
js .load_empty_state            ; Jump if sign bit set (negative error return)
cmp eax, STATS_RECORD_SIZE
jb .load_empty_state            ; Jump if below 12 bytes
```

---

## 9. Verification & Test Evidence

All 13 mandatory checklist tests were executed inside automated WSL tmux test harnesses against the final executable.

```
+-------------------------------------------------------------------------------+
|                      PAWMODORO VERIFICATION CHECKLIST                         |
+----+----------------------------------------------+---------------+-----------+
| #  | Test Description                             | Condition     | Result    |
+----+----------------------------------------------+---------------+-----------+
| 1  | Key mashing (200 keys, arrows, F-keys, etc.)  | No overflow   | PASS      |
| 2  | Empty inputs at all interactive prompts      | Safe cancel   | PASS      |
| 3  | 300-char input clamping and boundary audit   | <= 220 bytes  | PASS      |
| 4  | Missing persistence data files startup       | Zero default  | PASS      |
| 5  | Corrupted data files & unwriteable directory | Error notice  | PASS      |
| 6  | Ctrl+C signal handling on all 8 views        | Code 0 / 130  | PASS      |
| 7  | Broken stdout (/dev/full) & UNIX signals     | Term restored | PASS      |
| 8  | FR-T8 Quick-note post-focus completion flow  | Journal note  | PASS      |
| 9  | Live menu dashboard refresh across views     | Live counters | PASS      |
| 10 | Terminal size gate (< 80x24) & auto-recovery | Clean resize  | PASS      |
| 11 | Two-line status and footer alignment         | Fits 52 cols  | PASS      |
| 12 | Strace audit: single write & syscall sanity  | 1 write/frame | PASS      |
| 13 | Full Pomodoro regression cycle (4 sessions)  | Long break    | PASS      |
+----+----------------------------------------------+---------------+-----------+
```

### Detailed Evidence Highlights

#### Check 1: Key Mashing & Frame Overflow
- **Command:** Mashed random alphanumeric characters, spacebar, arrows, and function keys across Menu, Timer, Habits, and Journal screens.
- **Output:** `overflow` script returned 0 lines wider than 56 columns. Exited cleanly with `EXIT=0`.

#### Check 3: 300-Character Input Clamping
- **Command:** Input 300 characters at the quick-note prompt.
- **Audit:**
  ```bash
  tail -n 1 journal.txt | wc -c
  # Output: 220
  ```
  Exactly matches $19\text{ (timestamp)} + 200\text{ (clamped text)} + 1\text{ (LF)}$.

#### Check 6: Fail-Safe Ctrl+C Audit Across All Views
- Menu: `EXIT=0` (raw mode)
- Timer Running: `EXIT=0` (raw mode)
- Timer Paused: `EXIT=0` (raw mode)
- Habits View: `EXIT=0` (raw mode)
- Habits Name Prompt: `EXIT=130` (cooked mode SIGINT via `sig_handler`)
- Journal View: `EXIT=0` (raw mode)
- Journal Entry Prompt: `EXIT=130` (cooked mode SIGINT via `sig_handler`)
- Size Gate Warning: `EXIT=0` (raw mode)
- In all cases, `tmux display -p '#{alternate_on} #{cursor_flag}'` returned `0 1` (alternate screen dismissed, cursor restored).

#### Check 7: Failed stdout and OS Signals
- **Command:** `./pawmodoro > /dev/full`
- **Result:** Detected `sys_write` failure, invoked `term_restore`, exited with code `1`.
- **Command:** `kill -TERM <pid>` and `kill -HUP <pid>`
- **Result:** Intercepted by `sig_handler`, restored terminal, exited with code `130`.

#### Check 10: Size Gate & Auto-Recovery
- Window initialized to 60×20: screen displayed:
  ```
  Please enlarge the terminal
  (need 80x24, now 60x20)
  ```
- Window resized via `tmux resize-window -x 80 -y 24`: size gate loop exited automatically without any keypress, repainting the full main menu cleanly.

#### Check 12: System Call Audit (`strace`)
```bash
strace -e trace=write,ioctl,signal ./pawmodoro
```
- Registered signal handlers: `signal(SIGHUP)`, `signal(SIGINT)`, `signal(SIGTERM)`.
- Terminal queries: `ioctl(0, TIOCGWINSZ, ...)`.
- Redraw: Exactly one `write(1, ...)` per frame update; ignored keys trigger zero writes.

---

## 10. Questions a Grader Might Ask

**Q1: Why did pressing Ctrl+C while typing a journal entry or habit name previously break the terminal, and how was it solved?**  
*Answer:* In normal menu and timer operation, Pawmodoro runs in raw mode where the terminal driver does not generate signals for `Ctrl+C` (`0x03`), allowing `key_poll` to read it as a normal key and execute a clean shutdown. When accepting string input, however, the terminal switches to cooked mode (`term_cooked`), enabling `ISIG`. Pressing `Ctrl+C` in cooked mode sent a kernel `SIGINT` to the process. Because no signal handler was installed, Linux terminated the program immediately, leaving the alternate screen buffer active and the cursor hidden. We solved this by implementing `term_install_signals` using `sys_signal` (syscall 48) for `SIGHUP`, `SIGINT`, and `SIGTERM`. The handler routes directly to `app_exit`, ensuring `term_restore` always runs before the process terminates with exit code 130.

**Q2: How does `buf_flush` prevent an infinite recursion if writing to the terminal fails?**  
*Answer:* If `sys_write` fails with an unrecoverable error, `buf_flush` normally calls `app_exit(EXIT_FAILURE)`. However, `app_exit` itself invokes `term_restore`, which must flush terminal reset escape sequences (`ESC[0m`, `ESC[?25h`, `ESC[?1049l`) through `buf_flush`. To prevent an endless loop if stdout is broken (e.g. redirected to a full filesystem via `/dev/full`), `app_exit` sets the global flag `app_exiting = 1`. When `buf_flush` detects this flag, it clears `out_len` and returns immediately instead of calling `app_exit` again.

**Q3: Why doesn't `dashboard_refresh` reload `stats.dat` and `habits.dat` from disk on every return to the menu?**  
*Answer:* Pawmodoro's data architecture is write-through: all modifications to pomodoro session counts and habit check-in bitmasks update the in-memory structures before being written to disk. Re-reading the files from disk on every menu return would introduce unnecessary filesystem syscalls and disk latency. Querying `stats_today` and `habits_sync_dashboard` directly from memory is instantaneous, 100% accurate, and automatically handles midnight date transitions.

**Q4: How does the terminal size gate work without using `SIGWINCH`?**  
*Answer:* Installing a `SIGWINCH` handler in 32-bit x86 assembly without libc requires complex re-entrancy safeguards because a signal can interrupt the CPU while it is in the middle of modifying `out_buf` or executing a syscall. Instead, `ui_size_gate` is called synchronously at the entry of every screen redraw. It queries `ioctl(0, TIOCGWINSZ, winsize)`. If rows $< 24$ or columns $< 80$, it enters a low-CPU poll loop (`time_sleep_100ms` and `key_poll`), testing the dimensions on every tick. The moment the user resizes the terminal to 80×24 or larger, the loop exits, issues an ANSI clear sequence, and paints the full interface without requiring any user input.

**Q5: Why does pressing 'Q' on the focus-complete frame continue to the break instead of stopping the timer?**  
*Answer:* On the focus-complete frame, the prompt asks: `Focus complete! Add a quick note? (y/n)` with footer `[Y] Add note   [Any other key] Continue to break`. At this stage, the focus session has already completed naturally and been recorded to `stats.dat`. To ensure a smooth, uninterrupted Pomodoro flow, any keypress other than 'Y' (including 'Q' or Space) signals that the user wishes to proceed directly to their scheduled rest break without logging a note. On break-complete frames, however, 'Q' retains its traditional behavior (`[Any key] Continue   [Q] Stop and go back`) to allow returning to the main menu before starting the next focus cycle.

**Q6: What was the bug in `stats_load`, and why did it only affect error handling?**  
*Answer:* `stats_load` compared the return value of `file_load` against `STATS_RECORD_SIZE` (`12`) using the `jb` (Jump if Below) instruction. In x86 assembly, `jb` performs an unsigned comparison. When `file_load` fails, it returns `-1` (`0xFFFFFFFF`). Treated as an unsigned 32-bit integer, `0xFFFFFFFF` is $4,294,967,295$, which is greater than 12. Consequently, the procedure failed to jump to `.load_empty_state`, falling through as if 12 valid bytes had been read. We corrected this by adding `test eax, eax` followed by `js .load_empty_state` prior to the unsigned comparison.
