# Pawmodoro Test Plan

**Document ID:** `tests/TEST_PLAN.md`  
**Course:** CAO10 (Group 8)  
**Product:** Pawmodoro (32-bit x86 NASM for Linux, `int 0x80`, no libc)  
**Target Architecture:** Linux x86 (IA-32) / x86_64 with 32-bit ELF support  

---

## 1. How to Run the Tests

### A. Prerequisites & Environment
1. **Operating System:** Ubuntu Linux 20.04/22.04 LTS (native, VM, or WSL2 on Windows 10/11).
2. **Tools Required:** `nasm`, `binutils` (`ld`), `make`, `tmux`, `coreutils` (`stat`, `wc`, `date`), and `util-linux`.
   ```bash
   sudo apt update && sudo apt install -y nasm binutils make tmux strace gdb
   ```
3. **Terminal Geometry:** Manual tests must be conducted in an ANSI/VT100 terminal emulator configured to **exactly 80 columns by 24 rows** with a readable monospace font.

### B. Compilation
Before executing any test scenario, build the binary from the repository root:
```bash
make clean && make
```
Verify that the build completes warning-free and produces a 32-bit ELF binary:
```bash
file build/pawmodoro
# Expected: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), statically linked
```

### C. Automated Smoke Test
To execute the automated end-to-end smoke test suite:
```bash
./tests/smoke.sh
```
To run the extended test suite including the complete 4-session Pomodoro cycle (~70s):
```bash
./tests/smoke.sh --full
```

### D. Manual Execution Protocol
For manual test cases:
1. Open a terminal window sized to 80×24 (`resize -s 24 80` or via tmux: `tmux new -s test -x 80 -y 24`).
2. Run tests in an isolated temporary directory to avoid contaminating production records:
   ```bash
   WORKDIR=$(mktemp -d) && cd "$WORKDIR" && /path/to/repo/build/pawmodoro
   ```
3. Follow the numbered steps in the table below.
4. Record observations in the **Actual result** column and mark **PASS** or **FAIL** in the **Pass/Fail** column.

---

## 2. Known Limitations (Documented System Behaviors, Not Bugs)

1. **Fixed UTC+8 Timezone:** Pawmodoro uses a hardcoded compile-time timezone offset (`TZ_OFFSET = 28800` seconds / +8 hours) per PRD §6.3. All timestamps in `journal.txt` and date computations reflect Philippine Standard Time (PST/UTC+8) regardless of host system locale settings.
2. **Sub-second Timer Drift:** Phase timing decrements every 10 ticks using `sys_nanosleep` (100 ms). Process scheduling jitter under virtualization (WSL/VM) may accumulate approximately 50–100 ms of clock drift per minute of active focus.
3. **Redraw-Boundary Window Size Checking:** Pawmodoro avoids asynchronous signal handler re-entrancy in assembly by querying `ioctl(0, TIOCGWINSZ, winsize)` synchronously during screen redraws (`ui_size_gate`). Resizing an idle screen will display the size warning upon the next keystroke or timer tick.
4. **Timer Freezing During Dimension Warning:** If the terminal is shrunk below 80×24 while the Pomodoro countdown is running, countdown decrements are paused while the `Please enlarge the terminal` gate is active. Timing resumes once the terminal is enlarged to at least 80×24.
5. **Raw vs. Cooked Ctrl+C Exit Codes:** Pressing Ctrl+C in raw mode (menus, timer) exits cleanly with exit code `0`. Pressing Ctrl+C while typing inside canonical cooked mode (habit name, journal note, quick note) triggers a kernel `SIGINT`, which `sig_handler` traps, cleanly restores the terminal, and exits with code `130` ($128 + \text{SIGINT}$).

---

## 3. Test Cases

| ID | Feature | Objective | Preconditions | Steps | Expected result | Actual result | Pass/Fail |
|---|---|---|---|---|---|---|---|
| TC-01 | Main menu layout and rendering (FR-U1, FR-U2, FR-U6, FR-U7, FR-U8) | O4, O5 | Clean working dir, 80x24 terminal | 1. Run `./build/pawmodoro` | Screen shows 56-col box frame, title `P A W M O D O R O`, tagline `cozy focus - habits - notes`, idle cat `( o.o )`, dashboard `Today: 0 pomodoros      Habits: 0/0 done`, items `[1]` to `[4]`, `[Q] Quit`, footer `[1-4] Select an option   [Q] Quit`. | | |
| TC-02 | Invalid menu key handling (FR-U2) | O5 | Main menu displayed | 1. Press `X`<br>2. Press `9`<br>3. Press `Space`<br>4. Press `Enter`<br>5. Press `Up Arrow` | No screen change, no flickering, no stray characters, no system crash. Menu stays identical. | | |
| TC-03 | Clean menu exit via Q (FR-U2, FR-U5) | O4, O5 | Main menu displayed | 1. Press `Q` | Application exits immediately. Terminal restored: alternate screen left, cursor visible, terminal echo enabled, shell prompt active, exit code 0. | | |
| TC-04 | Clean menu exit via Ctrl+C (FR-U5) | O4, O5 | Main menu displayed | 1. Press `Ctrl+C` | Application exits immediately. Terminal restored: echo enabled, cursor visible, exit code 0. | | |
| TC-05 | Non-TTY standard input detection (FR-U1, FR-U5) | O4, O5 | Linux shell | 1. Run `./build/pawmodoro < /dev/null` | Prints `Error: Standard input is not a terminal.` to stderr and exits with code 1 without corrupting shell. | | |
| TC-06 | Terminal dimension gate under 80x24 (FR-U1) | O5 | Terminal window 70x20 | 1. Run `./build/pawmodoro` | Screen clears and displays: `Please enlarge the terminal` on row 1, `(need 80x24, now 70x20)` on row 2. No menu elements rendered. | | |
| TC-07 | Terminal dimension gate recovery (FR-U1) | O5 | Terminal in 70x20 gate from TC-06 | 1. Resize terminal window to 80x24 | Gate loop detects dimensions, clears screen, and renders full main menu without requiring keypress. | | |
| TC-08 | Demo mode toggle and visual feedback (FR-T2) | O1, O5 | Main menu displayed | 1. Press `4`<br>2. Observe menu<br>3. Press `4` again | On first press, menu item 4 updates to `[4] Demo mode: ON` and row 13 shows `Demo mode ON (10 s focus)` in bright yellow. On second press, updates to `[4] Demo mode: OFF` and `Demo mode OFF`. | | |
| TC-09 | Timer startup and focus display (FR-T1, FR-T2, FR-T3, FR-U6) | O1, O5 | Demo mode ON | 1. Press `1` | Screen title `FOCUS - Session 1 of 4  [DEMO]`, working cat `( -.- )`, initial countdown `00:10`, 30-char progress bar `[>-----------------------------]   0%`, footer `[P] Pause    [S] Skip    [Q] Stop and go back`. | | |
| TC-10 | Timer pause and resume functionality (FR-T4) | O1, O5 | Timer running in focus phase | 1. Wait until countdown reaches `00:07`<br>2. Press `P`<br>3. Wait 3 seconds<br>4. Press `P` | At step 2, message row displays `PAUSED` and footer shows `[P] Resume   [S] Skip    [Q] Stop and go back`. Countdown stays frozen at `00:07` over 3 seconds. At step 4, `PAUSED` clears and countdown resumes decrementing. | | |
| TC-11 | Timer skip focus phase without credit (FR-T4, FR-T7) | O1, O5 | Timer running in Session 1 focus | 1. Press `S` | Timer immediately advances to `SHORT BREAK - Session 1 of 4` with resting cat `( u.u )  Z`. Skipped focus is not counted in stats. | | |
| TC-12 | Timer skip break phase (FR-T4) | O1, O5 | Timer running in Short Break 1 | 1. Press `S` | Timer immediately advances to `FOCUS - Session 2 of 4` with working cat `( -.- )` and reset countdown. | | |
| TC-13 | Timer stop and return to menu via Q (FR-T4, FR-T7) | O1, O5 | Timer running in Focus Session 2 | 1. Press `Q` | Timer stops immediately. Screen returns to main menu with clean frame. Focus count remains unincremented. | | |
| TC-14 | Timer quit via Ctrl+C (FR-T4, FR-U5) | O1, O5 | Timer running or paused | 1. Press `1`<br>2. Press `Ctrl+C` | Program terminates cleanly from timer. Terminal restored: cursor visible, echo on, exit code 0. | | |
| TC-15 | Bell sound and natural focus completion (FR-T5, FR-T6, FR-T7) | O1, O5 | Demo mode ON, focus started | 1. Allow countdown to run naturally from `00:10` to `00:00` | Terminal emits audio bell (`\x07`), session completes. Status shows `Focus complete! Add a quick note? (y/n)` and footer `[Y] Add note   [Any other key] Continue to break`. | | |
| TC-16 | Post-focus quick-note addition (FR-T8, FR-J3) | O1, O3, O4 | Focus naturally completed (TC-15) | 1. Press `Y`<br>2. Type `Trained neural net`<br>3. Press `Enter` | Row 8 displays `Note (max 200, Enter alone cancels): `. After Enter, shows green `Note saved - press any key for a break.` and footer `[Any key] Continue to break`. `journal.txt` contains line with `Trained neural net`. | | |
| TC-17 | Post-focus quick-note cancellation (FR-T8) | O1, O3 | Focus naturally completed (TC-15) | 1. Press `Y`<br>2. Press `Enter` alone | Note entry cancels silently. Timer advances immediately to `SHORT BREAK - Session 1 of 4`. No entry added to `journal.txt`. | | |
| TC-18 | Post-focus skip note via any other key (FR-T8) | O1 | Focus naturally completed (TC-15) | 1. Press `Space` (or `Q`, `N`, Enter) | Prompt is bypassed. Timer advances immediately to `SHORT BREAK - Session 1 of 4`. No entry added to `journal.txt`. | | |
| TC-19 | Post-focus note 300-char input clamping (FR-T8, FR-J1) | O1, O3 | Focus naturally completed | 1. Press `Y`<br>2. Type 300 `A` characters<br>3. Press `Enter` | Exactly 200 `A` characters stored in `journal.txt`. Total line length in file is exactly 220 bytes. Terminal frame repainted cleanly without wrapped text corruption. | | |
| TC-20 | Full 4-session cycle with long break and reset (FR-T1, FR-T2) | O1, O5 | Demo mode ON | 1. Complete Session 1 focus & short break<br>2. Complete Session 2 focus & short break<br>3. Complete Session 3 focus & short break<br>4. Complete Session 4 focus | After 4th focus, timer displays `LONG BREAK - Session 4 of 4  [DEMO]` with duration `00:08`. After long break ends, next session resets to `FOCUS - Session 1 of 4`. | | |
| TC-21 | Pomodoro stats persistence in stats.dat (FR-D2, FR-T7) | O1, O4 | Clean temp dir, Demo mode ON | 1. Complete 1 focus naturally<br>2. Press `Space`, then `Q`<br>3. Quit app (`Q`)<br>4. Inspect `stats.dat`<br>5. Restart app | File `stats.dat` exists and is exactly 12 bytes (`stat -c %s stats.dat`). On restart, main menu displays `Today: 1 pomodoros`. | | |
| TC-22 | Pomodoro stats day rollover preservation (FR-D2, FR-T7) | O1, O4 | Clean working dir | 1. Seed `stats.dat` with yesterday's day number: `printf '\x01\x00\x00\x00\x03\x00\x00\x00\x07\x00\x00\x00' > stats.dat`<br>2. Run `./build/pawmodoro` | Main menu shows `Today: 0 pomodoros` (today's count reset for new day). Completing a session saves `today=1` and `total=8`, preserving historical total. | | |
| TC-23 | Missing or corrupted stats.dat handling (FR-D1, FR-D2) | O1, O4 | Clean working dir | 1. Run without `stats.dat`<br>2. Quit, write corrupted file: `printf 'abcde' > stats.dat`<br>3. Restart | In both cases, application starts without crashing. Dashboard initializes with `Today: 0 pomodoros`. | | |
| TC-24 | Unwritable stats.dat directory error handling (FR-D4) | O1, O4 | Clean working dir, Demo mode ON | 1. Create directory `mkdir stats.dat`<br>2. Run `./build/pawmodoro`<br>3. Complete a focus session | Completing focus session displays bold red `Could not save` on timer status row. Application does not crash, and timer advances to break normally. | | |
| TC-25 | Habit addition and display (FR-H1, FR-H2, FR-H3) | O2, O5 | Clean working dir | 1. Run app, press `2`<br>2. Press `A`<br>3. Type `Read 20 pages`<br>4. Press `Enter` | Screen shows habit row `1. Read 20 pages                 [ ][ ][ ][ ][ ][ ][ ]   streak 0   total 0`. Status row displays empty. | | |
| TC-26 | Habit empty name cancellation (FR-H3) | O2, O5 | Habits screen displayed | 1. Press `A`<br>2. Press `Enter` alone | Habit input cancelled. No habit added. Screen returns to habit tracker without errors or file modifications. | | |
| TC-27 | Habit name clamping at 31 characters (FR-H1, FR-H3) | O2, O5 | Habits screen displayed | 1. Press `A`<br>2. Type `1234567890123456789012345678901234567890`<br>3. Press `Enter` | Habit name truncated to first 31 characters (`1234567890123456789012345678901`). Rendered cleanly within column bounds. | | |
| TC-28 | Habit list full rejection on 9th habit (FR-H1) | O2, O5 | 8 habits already added | 1. Press `A` | Input prompt does not open. Status row displays `Habit list full (max 8)` in bold red. | | |
| TC-29 | Habit daily check-in and duplicate rejection (FR-H4) | O2, O5 | 1 habit added | 1. Press `1`<br>2. Observe status & squares<br>3. Press `1` again | Step 1 updates status to bold green `Checked in!`, squares to `[ ][ ][ ][ ][ ][ ][#]`, `streak 1`, `total 1`. Step 3 displays yellow `Already done today` and values remain unchanged. | | |
| TC-30 | Habit deletion and table shift (FR-H3) | O2, O5 | 3 habits added: H1, H2, H3 | 1. Press `D`<br>2. Press `2` | Prompt `Delete which habit? (1-N, other key cancels): ` appears. Pressing `2` deletes H2. H3 shifts up to slot 2. Status displays `Habit deleted`. | | |
| TC-31 | Habit streak and 7-day squares calculation (FR-H4, FR-H5) | O2, O5 | Clean working dir | 1. Compute today day number $D$<br>2. Seed `habits.dat` with `last_day = D - 1`, `history = 0x03`, `streak = 2`<br>3. Start app, press `2`<br>4. Check in habit `1` | Before check-in: squares show `[ ][ ][ ][ ][ ][#][ ]`, streak shows `2`. After check-in `1`: squares show `[ ][ ][ ][ ][ ][#][#]`, streak increments to `3`, total increments by 1. | | |
| TC-32 | Habit data persistence across restarts (FR-H6, FR-D3) | O2, O4 | 1 habit checked in | 1. Press `B` to menu<br>2. Press `Q` to quit<br>3. Check file size: `stat -c %s habits.dat`<br>4. Restart app, press `2` | File `habits.dat` is exactly 52 bytes ($4 + 48$). Upon restart, habit name, squares `[#]`, streak `1`, and total `1` are fully restored. | | |
| TC-33 | Habits dashboard live synchronization (FR-U7, FR-H6) | O2, O5 | 2 habits created, 0 checked in | 1. Verify menu shows `Habits: 0/2 done`<br>2. Press `2`, check in habit 1 (`1`)<br>3. Press `B` to menu | Menu immediately reflects `Habits: 1/2 done` without restarting application. | | |
| TC-34 | Corrupted or truncated habits.dat handling (FR-D1, FR-D3) | O2, O4 | Clean working dir | 1. Write corrupted file: `truncate -s 10 habits.dat`<br>2. Run `./build/pawmodoro`<br>3. Quit, seed count=9: `printf '\x09\x00\x00\x00' > habits.dat`<br>4. Restart | In both cases, application starts without crashing. Invalid data treated as empty (`Habits: 0/0 done`, `No habits yet`). | | |
| TC-35 | Ctrl+C signal handling during habit name entry (FR-U5, FR-H3) | O2, O4 | Habits screen displayed | 1. Press `A`<br>2. Type `Meditat`<br>3. Press `Ctrl+C` | Program intercepts SIGINT cleanly. Terminal restored: alternate screen left, cursor visible, echo on. Shell receives exit code 130. | | |
| TC-36 | Journal new entry creation with local timestamp (FR-J1, FR-J2) | O3, O4 | Clean working dir | 1. Run app, press `3`<br>2. Press `N`<br>3. Type `Morning review`<br>4. Press `Enter` | Prompt `New entry (max 200, Enter alone cancels): `. After Enter, displays green `Entry saved`. `journal.txt` created with format `YYYY-MM-DD HH:MM \| Morning review\n` matching UTC+8 local time. | | |
| TC-37 | Journal empty entry cancellation (FR-J1) | O3, O5 | Journal screen displayed | 1. Press `N`<br>2. Press `Enter` alone | Entry prompt cancelled. No file created or appended. Screen returns to journal view without status error. | | |
| TC-38 | Journal entry 300-char clamping and 220-byte limit (FR-J1, FR-J2) | O3, O4 | Journal screen displayed | 1. Press `N`<br>2. Type 300 `X` characters<br>3. Press `Enter`<br>4. Check file: `tail -n 1 journal.txt \| wc -c` | Output of `wc -c` is exactly 220 bytes ($19\text{ timestamp prefix} + 200\text{ characters} + 1\text{ LF}$). Screen not corrupted. | | |
| TC-39 | Journal selectable list and navigation (FR-J1, PRD v2 §7) | O3, O5 | Multiple entries in `journal.txt` | 1. Press `3`<br>2. Press `Up`/`Down` | Screen displays scrollable, selectable list. Selected entry is highlighted in reverse video (`\x1b[7m`). Up/Down moves highlight without selecting outside valid entries. | | |
| TC-40 | Journal empty or missing file handling (FR-D1, FR-J4) | O3, O5 | Missing or 0-byte `journal.txt` | 1. Press `3` | Screen displays `No entries yet.` in dim text. Key navigation and deletion are safely disabled. | | |
| TC-41 | Journal bounded 16 KB window reading (PRD v2 §7, §12) | O3, O4 | File > 16 KB (e.g. 24 KB) | 1. Start app, press `3`<br>2. Press `PgUp` | Loads bounded viewing window of at most 16 KB via `sys_lseek`. Incomplete leading line discarded cleanly. Never loads entire file into memory. | | |
| TC-42 | Journal adaptive UTF-8 word-wrapping (PRD v2 §2, §3, §7) | O3, O5 | 200-char entry in `journal.txt` | 1. Press `3` | Entry wraps across up to 4 visual rows at `ui_w - 6` columns. First row displays timestamp; continuation rows indented 4 spaces. Valid UTF-8 code points never split across rows. Entire 200-char entry readable. | | |
| TC-43 | Journal ANSI escape code neutralization (FR-J2, FR-J4, PRD v2 §3) | O3, O5 | Clean working dir | 1. Seed `journal.txt` with raw ESC bytes: `printf '2026-10-19 12:00 \| \x1b[31mRed\x1b[0m\n' > journal.txt`<br>2. Press `3` | ESC byte (`0x1b`) and control bytes rendered safely as `?`. Terminal color palette and cursor position are not corrupted. | | |
| TC-44 | Plain readable journal.txt file format (FR-J2) | O3, O4 | Several entries recorded | 1. Quit app<br>2. Run `cat journal.txt` | Plain, human-readable ASCII/UTF-8 log. Zero binary bytes, zero NUL bytes, zero carriage returns (`\r`). | | |
| TC-45 | Ctrl+C signal handling at journal entry prompt (FR-U5, FR-J1) | O3, O4 | Journal screen displayed | 1. Press `N`<br>2. Type `Draft note`<br>3. Press `Ctrl+C` | Kernel SIGINT trapped by `sig_handler`. Terminal restored: alternate screen dismissed, cursor shown, echo on. Shell receives exit code 130. | | |
| TC-46 | Key mashing and frame overflow immunity (FR-U2, FR-U8) | O5 | All screens (Menu, Timer, Habits, Journal) | 1. Rapidly input 200 random keys including digits, letters, Space, Enter, Up/Down, F1-F12 | No application crash, no hanging, no characters printed outside adaptive `ui_w` frame boundary. | | |
| TC-47 | OS signal handling for SIGHUP and SIGTERM (FR-U5) | O4, O5 | Background tmux session | 1. Run app<br>2. Send `kill -TERM <pid>`<br>3. Restart, send `kill -HUP <pid>` | In both cases, signals intercepted by `sig_handler`. Terminal restored cleanly, program exits with code 130. | | |
| TC-48 | Output redirection to /dev/full error handling (FR-U4, FR-U5) | O4, O5 | Linux shell | 1. Run `./build/pawmodoro > /dev/full` | Write error detected by `buf_flush`. Exits immediately with code 1 without recursive loop or hang. Terminal restored. | | |
| TC-49 | Low-CPU idle and 100ms timer ticking (FR-T5) | O1, O4 | App running on menu and in timer focus | 1. Measure CPU utilization: `ps -o %cpu,cmd -C pawmodoro` | CPU usage remains below 1.0% in both menu and active timer focus due to `sys_nanosleep(50ms/100ms)`. | | |
| TC-50 | Journal full-entry modal view (Enter key) (PRD v2 §7) | O3, O5 | Journal list displayed | 1. Select entry<br>2. Press `Enter`<br>3. Press `Enter` or `B` | Step 2 displays modal `JOURNAL - FULL ENTRY` with complete wrapped entry and footer `[Enter / B] Back to list   [D] Delete entry`. Step 3 returns to list view. | | |
| TC-51 | Journal entry deletion confirmation & cancellation (PRD v2 §7) | O3, O5 | Journal list displayed with entries | 1. Select entry<br>2. Press `D`<br>3. Press `N` | Step 2 displays `Delete this entry? (y/n)`. Step 3 cancels prompt; original `journal.txt` remains byte-for-byte unchanged; list returns to active state. | | |
| TC-52 | Journal entry deletion execution & selection clamping (PRD v2 §7) | O3, O4, O5 | 3 entries in `journal.txt` | 1. Select entry 2<br>2. Press `D`<br>3. Press `Y` | Exactly entry 2 is deleted from disk. Selection clamps to valid remaining entry. Status row shows `Entry deleted`. If only entry was deleted, file is 0 bytes and screen shows `No entries yet.`. | | |
| TC-53 | Atomic file deletion via dedicated 2 KB buffer & rename (PRD v2 §7) | O3, O4 | Valid journal file | 1. Delete entry under `strace` | Trace verifies copy in 2048-byte chunks using `del_copy_buf`, writes to `journal.tmp`, atomically calls `rename("journal.tmp", "journal.txt")`, leaving zero temporary files. | | |
| TC-54 | Deletion failure safety on blocked temporary file (PRD v2 §7) | O3, O4 | Directory `mkdir journal.tmp` exists | 1. Attempt to delete entry | Deletion fails cleanly. Status row displays `Could not delete`. Original `journal.txt` is preserved byte-for-byte; directory `journal.tmp` is untouched. | | |
| TC-55 | Large file chunked backward paging and deletion (PRD v2 §7) | O3, O4 | Journal file > 16 KB | 1. Press `PgUp` repeatedly<br>2. Delete an entry from an older chunk | Successfully navigates older chunks; deletes physical entry from disk at correct byte offset; remaining file contents and timestamps stay intact. | | |
| TC-56 | Ctrl+C terminal restoration across all journal prompts (PRD v2 §7, §14) | O3, O4 | At list, in full view, or delete prompt | 1. Press `Ctrl+C` | Terminal cleanly restored: cooked mode re-enabled, alternate screen dismissed, cursor shown, shell exit code 0 or 130. | | |
| TC-57 | Cohesive dashboard elements and daily greetings (PRD v2 §4, §13) | O5 | Main menu displayed | 1. Inspect row 4 greeting & row 6 tip | Deterministic time-of-day greeting and daily cozy tip displayed with clean formatting. | | |
| TC-58 | Pomodoro cycle dots and [PAUSED] status badge (PRD v2 §4, §5) | O1, O5 | Timer active and paused | 1. Inspect row 3 cycle dots<br>2. Press `P` | Session dots reflect cycle position (● filled, ○ empty); `[PAUSED]` badge renders cleanly. | | |
| TC-59 | Strict 7-bit ASCII mode output purity (PRD v2 §3, FR-V8) | O4, O5 | Settings `charset=1` (ASCII mode) | 1. Visit Menu, Timer, Habits, Journal, Settings | Output contains strictly bytes in range `0x00..0x7F`. Zero bytes $\ge 0x80$ emitted. | | |
| TC-60 | UTF-8 rounded borders across all 5 screens (PRD v2 §3, FR-V7) | O5 | Default UTF-8 mode | 1. Visit Menu, Timer, Habits, Journal, Settings | Top and bottom borders use rounded corner glyphs `╭`, `╮`, `╰`, `╯` with `─` and `│`. | | |
| TC-61 | Animation write throttling ceiling (<= 5 writes/s) (PRD v2 §8, FR-V32) | O1, O4 | Animation enabled in menu and timer | 1. Run under `strace -e trace=write`<br>2. Monitor 1-second write count | At most 5 animation-driven writes emitted per second due to 200ms flush throttling. | | |
| TC-62 | Integer-only LCG pseudo-random generator (PRD v2 §8) | O4 | Linux environment | 1. Launch Pawmodoro repeatedly | PRNG seeded from `time_now`. Uses 32-bit `MUL` with modulo $2^{32}$ recurrence; produces deterministic sequences for fixed seed. | | |
| TC-63 | Cat blink and tail-wag animation (PRD v2 §8) | O5 | Main menu or active timer | 1. Observe cat over 5 seconds | Cat eyes blink closed every 3.0 seconds for 200 ms. Tail cycles 3 distinct poses every 300 ms. | | |
| TC-64 | Menu title color wave and twinkling stars (PRD v2 §8) | O5 | Main menu active | 1. Observe menu title and garnish | Title characters cycle across active theme slots without hardcoded ANSI escapes. Two star garnishes twinkle without corrupting text. | | |
| TC-65 | Progress bar shimmer visual overlay (PRD v2 §8) | O1, O5 | Active timer focus countdown | 1. Observe 30-cell progress bar | Shimmer highlight traverses filled progress bar cells without altering elapsed time or percentage. | | |
| TC-66 | Break-time rising "zZ" garnish (PRD v2 §8) | O1, O5 | Timer in Short/Long Break | 1. Complete focus session or enter break | Floating "zZ" garnish rises from cat sleeping area over time and cleans up before next phase. | | |
| TC-67 | Confetti burst upon natural focus completion (PRD v2 §8) | O1, O5 | Demo mode ON, focus timer | 1. Allow focus countdown to naturally reach 0 | 20 confetti particles burst upward and fall with integer gravity simulation. Particles expire cleanly. Skipped focus does not spawn confetti. | | |
| TC-68 | Heart-pop effect on successful habit check-in (PRD v2 §8) | O2, O5 | Habits tracker screen | 1. Press `1` to check in habit | Heart glyph floats upward near checked-in habit row over 600 ms and clears. Rejected/duplicate check-ins do not trigger effect. | | |
| TC-69 | Reduce motion (anim=0) complete suppression (PRD v2 §8, FR-V31) | O4, O5 | Settings `anim=0` | 1. Observe menu idle under strace | Exactly 0 writes emitted while idle. All animation effects frozen; static canonical visuals restored immediately. | | |
| TC-70 | Terminal size gate (< 80x24) animation freeze (PRD v2 §2, §8) | O4, O5 | Terminal resized to 70x20 | 1. Resize during active animation | Dimension gate screen displayed; all animation simulation, drawing, and flushes completely suspended. | | |
| TC-71 | Single sys_write per composed partial redraw frame (PRD v2 §8, FR-V30) | O4, O5 | Multiple dirty animation regions | 1. Run under `strace -e trace=write` during menu/timer animation | Exactly one `sys_write` emitted per composed animation frame, aggregating all dirty regions. | | |
| TC-72 | Timer pause freezes animation without blocking input (PRD v2 §8) | O1, O5 | Timer running | 1. Press `P` to pause timer | Countdown and timer animation freeze. Key handling remains responsive; resuming unfreezes animation. | | |

---

## 4. Test Case Automation Mapping (`tests/smoke.sh`)

The automated smoke test script (`tests/smoke.sh`) provides headless regression coverage for the following test plan items:

| Smoke Check Scenario | Primary Test Plan IDs Covered |
|---|---|
| Check 1: Menu Title & Dashboard | TC-01 |
| Check 2: Invalid Keys Ignored | TC-02, TC-46 |
| Check 3: Demo Mode Toggle | TC-08 |
| Check 4: Timer Start & Layout | TC-09 |
| Check 5: Timer Pause & Resume | TC-10, TC-72 |
| Check 6: Natural Focus End & Quick Note | TC-15, TC-16, TC-67 |
| Check 7: Break Transition & Skip | TC-11, TC-12, TC-66 |
| Check 8: Menu Return & Stats 12B Check | TC-13, TC-21 |
| Check 9: Habits Add, Check-in & 52B Check | TC-25, TC-29, TC-32, TC-33, TC-68 |
| Check 10: Journal Add, View, Full View, Delete Cancel & Confirm | TC-36, TC-39, TC-42, TC-44, TC-50, TC-51, TC-52, TC-53 |
| Check 11: Corrupted Data Resilience | TC-23, TC-34 |
| Check 12: Raw Mode Ctrl+C & Term Restoration | TC-04, TC-56 |
| Check 13: Cooked Mode Ctrl+C (Exit 130) | TC-35, TC-45, TC-56 |
| Check 14: Non-TTY Stdin Rejection (Exit 1) | TC-05 |
| Check 15: Terminal Size Gate (< 80x24) & Auto-Recovery | TC-06, TC-07, TC-70 |
| Check 16: Zero Screen Overflow (> ui_w Columns) | TC-42, TC-46 |
| Check 17: Settings Navigation, Color Editor, Immediate Save & 24B Check | TC-54, TC-55 |
| Check 18: Cohesive Visual Elements (Greeting, Daily Tip, Cycle Dots, [PAUSED] Badge) | TC-57, TC-58 |
| Check 19: Strict 7-bit ASCII Fallback (Zero Bytes >= 0x80 across 5 Screens) | TC-59 |
| Check 20: UTF-8 Rounded Border Geometry (╭, ╰, ─, │ across 5 Screens) | TC-60 |
| Check 21: Animation Write Throttling (<= 5 fps) & Reduce Motion 0 Idle Writes | TC-61, TC-69, TC-71 |
| Extended (`--full`): 4-Session Pomodoro Cycle | TC-20 |
