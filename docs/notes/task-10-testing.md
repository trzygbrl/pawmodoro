# Task 10: Automated Testing & Verification Walkthrough

**Task ID:** `task-10-testing`  
**Course:** CAO10 (Group 8)  
**Product:** Pawmodoro (32-bit x86 NASM for Linux, `int 0x80`, no libc)  
**Target Environment:** Linux x86 / x86_64 with 32-bit ELF execution  

---

## 1. Overview & Quality Assurance Philosophy

Pawmodoro is implemented in pure 32-bit x86 assembly without standard C library wrappers (`int 0x80` syscalls only). In standard high-level applications, unit testing frameworks (like JUnit, pytest, or GoogleTest) can mock functions or isolate objects. For a bare-metal assembly terminal application, however, reliability must be verified at the **system interface**:
- The binary communicates directly with the Linux kernel terminal subsystem (termios, ioctl, signals).
- All visual state is drawn via aggregated ANSI escape sequences flushed to standard output.
- All persistent state is saved directly to raw binary structures (`stats.dat`, `habits.dat`) and append-only text logs (`journal.txt`).

Task 10 establishes a rigorous, dual-layered test infrastructure:
1. **The Comprehensive Test Plan ([tests/TEST_PLAN.md](file:///c:/Users/ideapad%20Slim%203/Documents/BSCS3A/CA010/CAO10%20Final%20Project/pawmodoro/tests/TEST_PLAN.md)):** 49 structured manual test cases covering functional, non-functional, edge-case, and fault-injection requirements mapped directly to PRD §2 objectives (O1–O5) and PRD §8 acceptance criteria.
2. **The Automated Smoke Suite ([tests/smoke.sh](file:///c:/Users/ideapad%20Slim%203/Documents/BSCS3A/CA010/CAO10%20Final%20Project/pawmodoro/tests/smoke.sh)):** A deterministic, headless regression test script using `tmux` to simulate user keystrokes, capture screen buffers, verify persistence artifacts, and enforce strict timing contracts.

---

## 2. Test Architecture: Headless Terminal Automation via tmux

### Why Headless Assembly Testing Requires tmux
Terminal programs configured in raw mode (`ICANON` and `ECHO` disabled) require an active pseudoterminal (pty). If an automated test simply redirects `stdin` from a pipe (`echo "1" | ./build/pawmodoro`), the kernel reports that standard input is not a terminal, and Pawmodoro cleanly aborts per PRD §4.1 FR-U1.

To automate testing without human intervention, `tests/smoke.sh` launches a detached virtual terminal using `tmux`:
```bash
tmux new-session -d -s "$TMUX_SESSION" -x 80 -y 24 -c "$TMP_DIR" bash
```
- `-x 80 -y 24`: Enforces the exact 80×24 geometry demanded by PRD §3.
- `send-keys`: Injects keystrokes directly into the pty's input queue.
- `capture-pane -p`: Dumps the terminal's 80×24 character matrix as plain text, allowing automated assertion via `grep` and `awk`.

```
                  +---------------------------------------+
                  |            tests/smoke.sh             |
                  +----+-----------------------------+----+
                       |                             ^
             send-keys |                             | capture-pane -p
                       v                             |
        +---------------------------------------------------+
        |       Virtual Terminal Session (tmux 80x24)       |
        |  +---------------------------------------------+  |
        |  |          ./build/pawmodoro (PID)            |  |
        |  |  [raw mode] [alt screen] [single sys_write] |  |
        |  +---------------------------------------------+  |
        |                         |                         |
        |                         v (file I/O)              |
        |             /tmp/paw_smoke_XXXXXX/                |
        |             stats.dat, habits.dat, journal.txt    |
        +---------------------------------------------------+
```

### Dynamic Event Polling (`wait_for`) vs. Fragile Sleep Timers
A naive automated test script might insert arbitrary sleeps (`sleep 10`) to wait for the Pomodoro countdown. However, fixed sleeps introduce race conditions and unnecessary latency:
- On fast physical hardware, fixed sleeps waste test time.
- Under virtualized environments (WSL2 or CI runners), process scheduling delays can cause timer events to take slightly longer than 10.0 seconds, causing false test failures.

In `tests/smoke.sh`, all assertions use an active polling helper (`wait_for`):
```bash
wait_for() {
    local pattern="$1"
    local timeout="${2:-25}"
    local start
    start=$(date +%s)
    while true; do
        if cap | grep -q -- "$pattern"; then
            return 0
        fi
        local now
        now=$(date +%s)
        if [ $((now - start)) -ge "$timeout" ]; then
            return 1
        fi
        sleep 0.2
    done
}
```
This helper samples the screen every 200 ms. As soon as the expected text appears, execution proceeds immediately.

### Sandbox Isolation via `mktemp -d`
Pawmodoro resolves all persistence paths relative to the current working directory (`stats.dat`, `habits.dat`, `journal.txt`). If tests ran in the repository root, test records would overwrite real user data and pollute `git status`.

`tests/smoke.sh` creates an isolated sandbox directory using `mktemp -d /tmp/paw_smoke_XXXXXX` and launches the process inside that directory. An automated bash exit trap guarantees that both the temporary directory and the background `tmux` session are destroyed when the test suite terminates:
```bash
cleanup() {
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM
```

---

## 3. System Call Audit & Verification (`strace`)

Under PRD §4.1 (FR-U4), §4.2 (FR-T5), and §7 (Non-Functional Requirements), Pawmodoro makes strict architectural commitments regarding system call efficiency. We verified these contracts using Linux `strace`.

### A. Output Aggregation: Single `sys_write` Per Visual Frame
To prevent screen flickering and tearing, all rendering is staged in `out_buf` (8192-byte buffer in `.bss`) and flushed in one syscall. Furthermore, ignored keystrokes must trigger zero writes.

We verified this contract by tracing `write` syscalls during menu display, key mashing, and timer start:
```text
514   write(1, "\33[?1049h\33[?25l", 14) = 14
514   write(1, "\33[1;1H\33[1;1H+-------------------"..., 810) = 810
514   write(1, "\33[1;1H\33[1;1H+-------------------"..., 507) = 507
514   write(1, "\33[1;1H\33[1;1H+-------------------"..., 810) = 810
514   write(1, "\33[0m\33[?25h\33[?1049l", 18) = 18
514   +++ exited with 0 +++
```

**Analysis:**
1. **Startup (14 bytes):** Alternate screen on (`ESC[?1049h`) and cursor hidden (`ESC[?25l`).
2. **Main Menu Frame (810 bytes):** The entire 15-row framed menu is flushed in a **single write call**.
3. **Ignored Keys:** Pressing `X`, `9`, and Spacebar produced **zero additional write calls**, proving that unrecognized keys do not trigger wasteful redraws.
4. **Timer Frame (507 bytes):** Navigating to the Pomodoro timer flushed the timer layout in a single write call.
5. **Clean Exit (18 bytes):** On quit, `term_restore` flushed the reset sequence (`ESC[0mESC[?25hESC[?1049l`), exactly 18 bytes.

### B. Syscall Frequency & Clock Cadence (`strace -c`)
We traced syscall counts over a 20-second active demo session (10-second focus countdown + break transition):

```text
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 57.43    0.021965         109       200           nanosleep
 32.35    0.012371          61       201           read
  4.25    0.001624          52        31           ioctl
  3.83    0.001466          81        18           write
  1.70    0.000652          59        11           time
  0.33    0.000125          41         3         2 open
  0.11    0.000043          43         1           close
  0.00    0.000000           0         3           signal
------ ----------- ----------- --------- --------- ----------------
100.00    0.038246          81       468         2 total
```

**Proof of Contract Compliance:**
- **Nanosleep (200 calls):** Exactly 10 calls per second over 20 seconds, confirming that `time_sleep_100ms` regulates the timer clock at precisely 10 Hz without busy-waiting.
- **Read (201 calls):** Exactly 10 non-blocking keyboard polls per second via `key_poll`, ensuring responsive key dispatch (< 100 ms latency).
- **Write (18 calls):** 1 startup + 1 menu + 1 demo toggle + 1 timer start + 10 countdown frames (one frame per second) + 1 completion prompt + 1 break + 1 menu return + 1 exit write.
- **Signal (3 calls):** Confirms installation of handlers for `SIGHUP`, `SIGINT`, and `SIGTERM`.

### C. CPU Utilization
Measured via `ps -o %cpu= -p <PID>`:
- **Main Menu (Idle):** **0.0%**
- **Timer Countdown (Active):** **0.0%**
Because Pawmodoro sleeps using `sys_nanosleep` rather than spinning in an instruction loop, CPU consumption is undetectable by the operating system, satisfying PRD §7 (< 1% CPU).

---

## 4. Bugs Discovered & Resolved in Task 10

### Bug 1: Idle Menu Resize Did Not Trigger Size Gate Until Keypress
- **Symptom:** In Scenario 15 of `tests/smoke.sh`, resizing the terminal window from 80×24 to 60×20 via `tmux resize-window -x 60 -y 20` while on the main menu failed to display `Please enlarge the terminal`. The warning only appeared after pressing a key.
- **Root Cause:** In [src/main.asm](file:///c:/Users/ideapad%20Slim%203/Documents/BSCS3A/CA010/CAO10%20Final%20Project/pawmodoro/src/main.asm), the main menu loop used `call key_wait`. `key_wait` looped internally checking for keystrokes and sleeping 50 ms. Because `main.asm` was blocked inside `key_wait` and `need_redraw` was 0, `main.asm` never invoked `ui_draw_menu` (which houses `ui_size_gate`).
- **Fix:** Refactored `.wait_for_input` in [src/main.asm](file:///c:/Users/ideapad%20Slim%203/Documents/BSCS3A/CA010/CAO10%20Final%20Project/pawmodoro/src/main.asm) into a non-blocking 100 ms cadence:
  ```nasm
  .wait_for_input:
      ; Low-CPU sleep loop checking terminal dimensions and polling input (FR-U1, FR-T5)
      call time_sleep_100ms
      call term_size_ok
      test eax, eax
      jnz .poll_input
      ; Terminal shrunk below 80x24: trigger redraw to enter ui_size_gate immediately
      mov dword [need_redraw], 1
      jmp .main_loop

  .poll_input:
      call key_poll
      cmp eax, KEY_NONE
      je .wait_for_input
  ```
  Now, if the terminal window is shrunk while idle on the menu, `term_size_ok` detects the undersized geometry within 100 ms, sets `need_redraw = 1`, and routes directly into `ui_size_gate`.

---

## 5. Screenshot Guide for the Final Project Report

To capture the required figures for Chapter 3 of the final report, execute the steps below in an authentic terminal emulator (e.g. Windows Terminal, GNOME Terminal, or Alacritty) configured to **exactly 80 columns by 24 rows** with a crisp, readable font.

> [!IMPORTANT]
> Capture full terminal windows showing the entire 56-column frame and outer margins. Do not crop out borders.

### Screenshot 1: Main Menu with Non-Zero Dashboard
- **Objective:** Demonstrates application branding, ASCII cat pose 0 (idle), and live dashboard metrics.
- **Steps:**
  1. In a clean directory, seed 2 completed pomodoros and 1 habit:
     ```bash
     DAY=$(( ($(date +%s) + 28800) / 86400 ))
     printf "\x$(printf '%02x' $((DAY & 0xFF)))\x$(printf '%02x' $(((DAY>>8) & 0xFF)))\x00\x00\x02\x00\x00\x00\x05\x00\x00\x00" > stats.dat
     ```
  2. Launch `./build/pawmodoro`.
  3. Press `2`, `A`, type `Read assembly docs`, press `Enter`.
  4. Press `1` to check in.
  5. Press `B` to return to the menu.
- **Visual Verification:** Header `P A W M O D O R O`, cat `( o.o )`, dashboard line `Today: 2 pomodoros      Habits: 1/1 done`, menu items `[1]` to `[4]`, footer `[1-4] Select an option   [Q] Quit`.

### Screenshot 2: Timer Focus Phase
- **Objective:** Demonstrates active countdown, session progress bar, and ASCII cat pose 1 (working).
- **Steps:**
  1. From the main menu, press `4` to enable Demo mode.
  2. Press `1` to start the focus timer.
  3. Capture after 3–4 seconds.
- **Visual Verification:** Title `FOCUS - Session 1 of 4  [DEMO]`, working cat with closed eyes `( -.- )`, active countdown (e.g. `00:07`), 30-character progress bar with percentage, footer `[P] Pause    [S] Skip    [Q] Stop and go back`.

### Screenshot 3: Timer Paused State
- **Objective:** Demonstrates the pause control and countdown freezing.
- **Steps:**
  1. While in the focus timer (from Screenshot 2), press `P`.
- **Visual Verification:** Message row displays bold bright yellow `PAUSED`, footer updates to `[P] Resume   [S] Skip    [Q] Stop and go back`.

### Screenshot 4: Break Phase (Short Break)
- **Objective:** Demonstrates phase transition and ASCII cat pose 2 (resting with 'zZ').
- **Steps:**
  1. From the timer, press `S` (skip) to advance directly to the break.
- **Visual Verification:** Title `SHORT BREAK - Session 1 of 4  [DEMO]`, sleeping cat `( u.u )  Z`, countdown `00:05`.

### Screenshot 5: Habit Tracker with Streaks & 7-Day History
- **Objective:** Demonstrates habit table layout, streak counting, and 7-day bitmask squares.
- **Steps:**
  1. Compute today's day number:
     ```bash
     DAY=$(( ($(date +%s) + 28800) / 86400 ))
     echo "Today is Day Number: $DAY"
     ```
  2. Create 3 distinct habits with differing histories and streaks using `printf` or interactive entry:
     - Habit 1: Checked in today (streak 3, last_day = $DAY$).
     - Habit 2: Checked in yesterday (streak 5, last_day = $DAY - 1$).
     - Habit 3: Missed 3 days (streak 0, last_day = $DAY - 3$).
  3. Start `./build/pawmodoro` and press `2`.
- **Visual Verification:** Header `#  HABIT        LAST 7 DAYS         STREAK TOTAL`, rows showing visual squares `[#]` and `[ ]`, distinct streaks (e.g. `streak 3`, `streak 5`, `streak 0`), footer `[A] Add  [1-8] Check in today  [D] Delete  [B] Back`.

### Screenshot 6: Journal View
- **Objective:** Demonstrates timestamped note history and chronological oldest-to-newest ordering.
- **Steps:**
  1. Press `3` from the main menu.
  2. Press `N`, enter `Completed CPU module review`, press `Enter`.
  3. Press `N`, enter `Implemented signal handlers`, press `Enter`.
  4. Press `V` to view recent entries.
- **Visual Verification:** Header `JOURNAL`, list of entries formatted as `YYYY-MM-DD HH:MM | <text>`, footer `[N] New entry   [V] View recent   [B] Back`.

### Screenshot 7: Post-Session Quick-Note Prompt (FR-T8)
- **Objective:** Demonstrates cross-subsystem integration between Focus Timer and Journal.
- **Steps:**
  1. From the main menu, press `4` (Demo mode ON), then `1`.
  2. Wait 10 seconds for the countdown to reach `00:00`.
  3. Capture the decision prompt: `Focus complete! Add a quick note? (y/n)`.
  4. Press `Y` and capture the input prompt: `Note (max 200, Enter alone cancels): `.
- **Visual Verification:** Contextual status line, prompt row with cursor positioned immediately after the colon, footer `[Y] Add note   [Any other key] Continue to break`.

---

## 6. Questions a Grader Might Ask

**Q1: Why does `tests/smoke.sh` use tmux rather than simple shell command redirection?**  
*Answer:* Pawmodoro verifies on startup that standard input is an authentic terminal device (`isatty(0)` via `ioctl TCGETS`). If standard input is a pipe or redirected file (e.g. `echo "1" | ./pawmodoro`), Pawmodoro rejects the execution and exits with an error code to protect the terminal. `tmux` spawns a real Linux pseudoterminal (pty) with fixed 80×24 geometry, allowing headless automation to exercise real raw and cooked termios switches exactly as a human user would.

**Q2: How does `tests/smoke.sh` ensure that test runs do not corrupt existing user data?**  
*Answer:* The script creates an isolated temporary directory using `mktemp -d /tmp/paw_smoke_XXXXXX` and launches Pawmodoro with that temporary directory as its working directory. Because Pawmodoro resolves data files (`stats.dat`, `habits.dat`, `journal.txt`) relative to current working directory, all test records are created inside the sandbox. A bash trap on `EXIT` ensures that this sandbox directory is deleted when the test completes.

**Q3: What does the system call audit prove about Pawmodoro's performance and architecture?**  
*Answer:* Using `strace`, we proved two architectural guarantees:
1. **Zero-flicker output aggregation:** Visual updates are staged in an internal buffer and output with exactly **one `sys_write` per frame**. Keystrokes that are ignored produce zero `sys_write` calls.
2. **Sub-1% CPU consumption:** The timer countdown and keyboard poll loop execute a 100 ms `sys_nanosleep` per tick (~10 calls per second), allowing the Linux kernel to put the process into deep sleep between ticks rather than consuming CPU in a spinlock.

**Q4: How does Pawmodoro handle terminal resizing if the window is shrunk below 80×24 while the user is idle on the menu?**  
*Answer:* In Task 10, we hardened `main.asm`'s menu wait loop to poll `term_size_ok` every 100 ms alongside `key_poll`. If `ioctl(0, TIOCGWINSZ, winsize)` reports columns $< 80$ or rows $< 24$, the loop sets `need_redraw = 1` and routes immediately into `ui_size_gate`. The gate clears the display, shows an enlarge warning, and blocks until the terminal is enlarged back to 80×24, repainting the menu automatically.
