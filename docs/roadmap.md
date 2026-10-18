# Pawmodoro — Week 3 Roadmap (Prototype)

**Scope:** Week 3 only — *System Design & UI: implement core program logic, working prototype, screenshots, Chapter 3 draft.*
**Companion file:** `PRD.md` (attach it every time; keep a copy at `docs/PRD.md` in the repo).

---

## How to use this roadmap

For **each task**:

1. Open a fresh AI chat. Attach `PRD.md`.
2. Paste the **Standard Wrapper** (below), then paste that task's **Prompt-Builder Paragraph**. Send.
3. The AI returns one prompt in a code block. Copy it.
4. Paste that prompt into your **coding agent** (Claude Code, Cursor, Copilot agent, etc.) opened in the repo folder.
5. Run the task's **Verify** checklist yourself. If it passes, `git commit -m "Task Tn done"`. If not, use the **Fix Paragraph** at the bottom.
6. Read `docs/notes/<task>.md` the agent wrote and make sure someone in the group can explain the code (the rubric grades "Understanding of Assembly", and you will demo this).

Rules of thumb: one task per agent session · commit after every green task · never let the agent "refactor everything" · tasks run in order (each depends on the earlier ones).

### Standard Wrapper (paste before every task paragraph)

> You are an expert prompt engineer for AI coding agents. I attached the PRD for my university Assembly project, Pawmodoro (NASM, 32-bit Linux, terminal app). Write ONE self-contained prompt that I will paste into a coding agent working inside my repo. The prompt you write must: (1) start with a 2–3 sentence project context and give the agent the role of a senior x86 NASM developer; (2) tell the agent to read `docs/PRD.md` first and name the exact PRD sections it must follow; (3) list the exact files to create or edit and forbid touching any other file; (4) list every required procedure with its name and IN / OUT / CLOBBERS exactly as in PRD §6.4; (5) restate the coding conventions of PRD §6.2 (register-preserving procedures, header comment per procedure, inline comments, constants instead of magic numbers); (6) include acceptance criteria plus the exact shell commands to build and verify; (7) end by requiring a short report (what was built, how to test, known issues) and a plain-language explanation file `docs/notes/<task-id>.md`. Do not write any assembly yourself — output only the prompt, inside a single code block. The task is:

---

## Task Overview

| Task | Name | Day | Depends on |
|------|------|-----|-----------|
| T0 | Environment, repo skeleton, hello-world | 1 | — |
| T1 | Constants, macros, output buffer, ANSI helpers | 1 | T0 |
| T2 | Terminal control and keyboard input | 2 | T1 |
| T3 | Time and date utilities | 2 | T1 |
| T4 | UI framework, ASCII art, main menu, state machine | 3 | T1–T3 |
| T5 | Pomodoro timer | 3–4 | T4 |
| T6 | File persistence and pomodoro stats | 4 | T5 |
| T7 | Habit tracker | 5 | T6 |
| T8 | Journal | 5 | T6 |
| T9 | Integration and polish | 6 | T5–T8 |
| T10 | Testing, debugging, screenshots | 6–7 | T9 |
| T11 | Documentation and Chapter 3 draft | 7 | T10 |

---

## T0 — Environment, repo skeleton, hello-world

**Goal:** prove the toolchain works and create the project skeleton so every later task has a place to go.
**Produces:** folder layout from PRD §6.1, `Makefile`, `.gitignore`, minimal `src/main.asm`, `README.md` with setup steps.

> **Prompt-Builder Paragraph — T0**
> Build me a prompt for a coding agent to set up the Pawmodoro project skeleton. The agent must create the full repository layout from PRD §6.1 (empty placeholder `.asm`/`.inc` files with a one-line header comment each, plus `docs/notes/` and `tests/`), a `Makefile` with targets `all`, `run`, `debug` (launches gdb on the binary), and `clean` that assembles with `nasm -f elf32 -g -F dwarf -Wall src/main.asm -o build/pawmodoro.o` and links with `ld -m elf_i386`, a `.gitignore` ignoring `build/`, `*.dat`, and `journal.txt`, and a `README.md` containing Ubuntu/WSL2 setup (`sudo apt install nasm binutils make gdb tmux`) and build/run instructions. `main.asm` must contain only a working hello-world: `_start` writes "Pawmodoro boots!" plus a newline using `sys_write` (int 0x80) and exits with code 0 via `sys_exit`. Acceptance: `make` has no warnings, `./build/pawmodoro` prints the message, `echo $?` prints 0, and `file build/pawmodoro` reports an ELF 32-bit executable. Also ask the agent to explain what to do if the binary gives "Exec format error".

**Verify:** ☐ builds with no warnings ☐ prints message ☐ exit code 0 ☐ `file` says 32-bit ELF ☐ repo initialised with git.

---

## T1 — Constants, macros, output buffer, ANSI helpers

**Goal:** the foundation every screen depends on: build a frame in memory, flush it with **one** write (no flicker).
**Files:** `constants.inc`, `macros.inc`, `data.asm` (ANSI strings + buffers), `io.asm`, `main.asm` (temporary demo).

> **Prompt-Builder Paragraph — T1**
> Build me a prompt for a coding agent to implement the foundation layer of Pawmodoro. Files: `constants.inc` (syscall numbers from PRD §3.1, open flags, key codes such as `KEY_ENTER`, `KEY_ESC`, `KEY_CTRL_C`, buffer sizes from §6.5, phase durations for normal and demo mode, `TZ_OFFSET`), `macros.inc` (a `syscall` helper macro and a macro to save/restore registers), `data.asm` (ANSI escape strings from PRD §3.3 as named constants — clear, home, hide/show cursor, alt-screen on/off, reset, bold, the 16-color foreground codes — and the `.bss` buffers from §6.5), and `io.asm` with exactly these procedures: `buf_str`, `buf_char`, `buf_u32` (unsigned decimal using `DIV` by 10), `buf_u32_2`, `buf_mmss`, `buf_repeat`, `buf_goto`, `buf_flush`, `str_len`, `str_copy`. Output buffer overflow must be prevented (stop appending when full). Temporarily make `main.asm` draw a coloured ASCII box with the number 12345 and the time 04:07 at a chosen screen position using `buf_goto`, flush once, and exit. Acceptance: output is correct for 0, 9, 10, 99, 100 and 4294967295; `buf_mmss` shows `00:00`, `04:07`, `25:00`; everything is written with a single `sys_write` per flush (verify with `strace -e write ./build/pawmodoro`).

**Verify:** ☐ box and numbers render correctly ☐ `strace` shows one write per frame ☐ every procedure has a header and inline comments.

---

## T2 — Terminal control and keyboard input

**Goal:** single-key input without Enter, non-blocking polling for the timer, normal line input for typing text, and a guaranteed clean exit.
**Files:** `term.asm`, `main.asm` (temporary key-echo demo).

> **Prompt-Builder Paragraph — T2**
> Build me a prompt for a coding agent to implement terminal control in `term.asm` for Pawmodoro, following PRD §3.2 and §6.4. Required procedures: `term_init` (save original termios with `ioctl TCGETS` into `termios_orig`, copy to `termios_raw`, enter the alternate screen, hide the cursor), `term_restore` (restore original termios, show cursor, reset colours, leave alternate screen — this must be the only cleanup path), `term_raw` (clear `ICANON`, `ECHO`, `ISIG`; set `VMIN=0`, `VTIME=0`; apply with `TCSETS`), `term_cooked` (apply the saved original settings), `key_poll` (non-blocking `sys_read` of one byte; return the key with letters a–z converted to uppercase, or -1 if no key; swallow ESC sequences such as arrow keys and return -1), `key_wait` (loop on `key_poll` with a 50 ms `sys_nanosleep` until a key arrives), and `read_line` (cooked-mode line input into `EDI` up to `ECX` characters, strip the newline, NUL-terminate, discard any extra typed characters so they do not leak into the next key read, then return to raw mode). Ctrl+C (byte 3) must be returned as a normal key so the program can quit cleanly. Temporary demo in `main.asm`: print each key code as it is pressed, `T` toggles a line-input prompt that echoes the typed text back, `Q` or Ctrl+C exits through `term_restore`. Acceptance: after exiting the shell has echo and a visible cursor, idle CPU stays near 0% (check with `top`), and `ioctl` failure (stdin not a terminal) exits gracefully with a message instead of crashing.

**Verify:** ☐ keys register instantly ☐ typing text works with backspace ☐ after quit, typing in the shell echoes normally ☐ Ctrl+C exits cleanly ☐ extra long input does not break the next prompt.

---

## T3 — Time and date utilities

**Goal:** sleeping, the clock, the local-day number, and printable dates/times.
**Files:** `time.asm`, `main.asm` (temporary demo).

> **Prompt-Builder Paragraph — T3**
> Build me a prompt for a coding agent to implement `time.asm` for Pawmodoro using PRD §6.3 and §6.4. Procedures: `time_sleep_100ms` (`sys_nanosleep` with a timespec of 0 s and 100,000,000 ns), `time_now` (`sys_time`), `time_local` (UTC + `TZ_OFFSET`), `time_today` (day number = local seconds / 86400), `time_fmt_date` (day number to `YYYY-MM-DD` with NUL terminator using an integer civil-from-days algorithm, Howard Hinnant's, using only 32-bit integer instructions and commented step by step), and `time_fmt_hhmm` (local seconds to `HH:MM`). Add a temporary demo in `main.asm` that prints today's day number, today's date, the current time, and also runs the date formatter on the test vectors 0, 10957 and 19723, which must print 1970-01-01, 2000-01-01 and 2024-01-01. Acceptance: the printed date and time match the output of `date` on a machine set to UTC+8; sleeping ten times in a loop takes about 1 second (verify with `time ./build/pawmodoro`).

**Verify:** ☐ three test vectors correct ☐ date/time match `date` ☐ 10 × 100 ms ≈ 1 s.

---

## T4 — UI framework, ASCII art, main menu, state machine

**Goal:** the app shell: a menu you can navigate, art, and the finite state machine that later tasks plug into.
**Files:** `ui.asm`, `data.asm` (art + strings), `main.asm`.

> **Prompt-Builder Paragraph — T4**
> Build me a prompt for a coding agent to implement the Pawmodoro application shell. In `ui.asm` implement `ui_draw_cat` (three poses: 0 idle, 1 working with closed/focused eyes, 2 resting/sleeping; small ASCII cats styled like `/\_/\ ( o.o ) > ^ <`), a frame/border helper using plain ASCII `+ - |` at 56 columns wide, and the main-menu renderer matching the wireframe in PRD §5 (title, dashboard line with placeholder values, menu items 1–4 and Q, and `Demo mode: ON/OFF` reflecting a `demo_mode` variable). In `main.asm` implement `_start` (term_init, term_raw, main loop) and the finite state machine from FR-U3: states `STATE_MENU`, `STATE_TIMER`, `STATE_HABITS`, `STATE_JOURNAL`, `STATE_QUIT`, dispatched with `CMP`/conditional jumps. Keys: `1`, `2`, `3` enter a stub screen that says "Coming soon — press B to go back"; `4` toggles `demo_mode` and redraws; `Q` or Ctrl+C go to `STATE_QUIT`, which calls `term_restore` and exits. Redraw only when the state or data changes, using `buf_goto` home rather than a full clear, and flush once per frame. Acceptance: menu fits 80×24, invalid keys do nothing, there is no flicker (verify with `strace -e write` that each redraw is one write), and exit restores the terminal.

**Verify:** ☐ menu looks like the wireframe ☐ every stub screen returns with B ☐ demo toggle flips ☐ no flicker ☐ clean exit.

---

## T5 — Pomodoro timer

**Goal:** the core feature (Objective O1). Complete phase cycle with pause/skip/stop.
**Files:** `timer.asm`, `ui.asm` (progress bar), `data.asm`, `main.asm` (hook `STATE_TIMER`).

> **Prompt-Builder Paragraph — T5**
> Build me a prompt for a coding agent to implement the Pomodoro timer in `timer.asm` according to PRD §4.2 (FR-T1 to FR-T7; skip the post-session note prompt, which comes in T9). Entry point `timer_run` returns to the menu when the user leaves. Phases: FOCUS, SHORT_BREAK, LONG_BREAK with durations from `constants.inc` for normal mode (25/5/15 min) and demo mode (10/5/8 s); every fourth completed focus session is followed by a long break, after which the session counter resets. Timing loop: ten iterations of `time_sleep_100ms` per second, polling `key_poll` each iteration, so a key press is handled within ~100 ms. Keys: `P` pause/resume (countdown freezes and the screen shows PAUSED), `S` skip to the next phase, `Q` stop and return to the menu, Ctrl+C quits the app via `term_restore`. Implement `ui_progress_bar` (30 characters, `#` filled and `-` empty, plus percentage, computed with `MUL`/`DIV`) and render the screen from the PRD §5 wireframe: phase name, "Session n of 4", `MM:SS`, bar, key help, `[DEMO]` tag, the cat pose matching the phase. When a phase reaches zero: write the bell byte 0x07, show a completion message, and wait for a keypress before the next phase. A focus phase counts as completed only if it ran to zero — expose a variable `focus_completed_flag` (or a procedure hook) for T6 to use. Acceptance: demo mode runs a full focus→break→…→long break cycle; pause really freezes time; screen updates once per second with no flicker; CPU stays near 0%.

**Verify:** ☐ demo-mode full cycle ☐ pause/resume ☐ skip and stop ☐ bell rings ☐ long break after 4th focus ☐ `top` shows ~0% CPU.

---

## T6 — File persistence and pomodoro stats

**Goal:** reusable file I/O plus the first persisted data (pomodoros per day).
**Files:** `file.asm`, `stats.asm`, `timer.asm` (hook), `ui.asm` (dashboard line), `main.asm`.

> **Prompt-Builder Paragraph — T6**
> Build me a prompt for a coding agent to implement persistence for Pawmodoro. In `file.asm` implement `file_load` (open read-only, read up to `ECX` bytes into `EDI`, close; return bytes read or -1 if the file does not exist), `file_save` (open with `O_WRONLY|O_CREAT|O_TRUNC`, mode 0644, write, close; return 0 or -1) and `file_append` (`O_WRONLY|O_CREAT|O_APPEND`). In `stats.asm` implement `stats_load`, `stats_add_pomodoro` and `stats_today` using the 12-byte `stats.dat` layout from FR-D2 (`day`, `today_count`, `total_count`) with the day-rollover rule: if the stored day differs from `time_today`, reset `today_count` to 0. Hook `stats_add_pomodoro` into the timer so it runs only when a focus phase completes naturally, and make the main menu dashboard show the real "Today: N pomodoros" value, loaded at startup. Handle errors without crashing: a missing file means zero counts; a failed save shows a one-line "Could not save" message. Acceptance: complete a demo-mode focus session, quit, restart — the count is still there; inspect `stats.dat` with `xxd` and confirm 12 bytes; deleting `stats.dat` resets to 0; editing the stored day to an older value resets today's count but keeps the total.

**Verify:** ☐ count survives restart ☐ skipped session not counted ☐ `xxd stats.dat` is 12 bytes ☐ missing file handled ☐ day rollover works.

---

## T7 — Habit tracker

**Goal:** Objective O2 — record habits, daily check-ins, streaks, 7-day history.
**Files:** `habits.asm`, `ui.asm`, `data.asm`, `main.asm` (hook `STATE_HABITS`), dashboard line.

> **Prompt-Builder Paragraph — T7**
> Build me a prompt for a coding agent to implement the habit tracker in `habits.asm` according to PRD §4.3 (FR-H1–FR-H6) and §4.5 (FR-D3). Data: up to 8 records of 48 bytes (`name[32]`, `last_day`, `streak`, `total`, `history` dwords) loaded from and saved to `habits.dat` (a leading dword count, then the records) using `file_load`/`file_save`. Screen per the PRD §5 wireframe listing number, name, seven `[#]`/`[.]` squares, streak and total. Keys: `A` add (switch to cooked mode, `read_line` up to 31 characters, empty input cancels, reject when 8 habits exist), `1`–`8` check in for today, `D` followed by a number deletes a habit and shifts the following records up, `B` back. Implement the check-in rules exactly as FR-H4 (`delta = today - last_day`; same-day check-in shows "already done today"; history is shifted left by `delta` and bit 0 set; streak increments only when `delta == 1`, else resets to 1) and the display rules of FR-H5 (streak shown as 0 if more than one day was missed; shift history by `today - last_day` for display only). Use `SHL`, `OR`, `AND`, `TEST` for the bitmask work and comment them. Export `habits_done_today` (returns done count in EAX and total in EBX) and show "Habits: done/total" on the main menu. Acceptance: add three habits, check in, restart and see the data persist; checking in twice on the same day is refused; hand-edit `last_day` in `habits.dat` (with a hex editor or a small shell `printf`) to yesterday and to three days ago to verify streak continue/reset and the squares.

**Verify:** ☐ add/check/delete ☐ restart keeps data ☐ same-day double check-in blocked ☐ streak continues for yesterday, resets after a gap ☐ 9th habit rejected ☐ 40-character name is truncated safely.

---

## T8 — Journal

**Goal:** Objective O3 — save and view short timestamped notes.
**Files:** `journal.asm`, `ui.asm`, `data.asm`, `main.asm` (hook `STATE_JOURNAL`).

> **Prompt-Builder Paragraph — T8**
> Build me a prompt for a coding agent to implement the journal in `journal.asm` according to PRD §4.4 (FR-J1–FR-J4). `journal_add` takes a NUL-terminated text pointer in `ESI`, builds the line `YYYY-MM-DD HH:MM | text\n` in a scratch buffer using `time_fmt_date` and `time_fmt_hhmm`, and appends it to `journal.txt` with `file_append`; it returns 0 or -1 and must be reusable by other modules. The journal screen (`journal_run`) has keys `N` (cooked-mode `read_line`, max 200 characters, empty input cancels, confirmation message on save), `V` (read the last 4096 bytes of `journal.txt` into `jrnl_buf` — use `sys_lseek` or read the whole file and keep the tail — and print the last 10 complete lines, scanning backwards for newline bytes; show "No entries yet." if the file is missing or empty), and `B` back. Screen layout follows the PRD §5 wireframe. Long lines must not overflow the 80-column screen (truncate on display only; keep the full text in the file). Acceptance: add three notes, view them in order with correct timestamps, restart and view again, view with no file, add a 300-character note and confirm only 200 characters are stored, and `cat journal.txt` shows readable lines.

**Verify:** ☐ entries append ☐ timestamps match `date` ☐ view shows the latest 10 ☐ missing file message ☐ file is plain readable text.

---

## T9 — Integration and polish

**Goal:** make the three features feel like one product (the thesis of Chapter 1) and harden edge cases.
**Files:** any module, but only for the listed changes.

> **Prompt-Builder Paragraph — T9**
> Build me a prompt for a coding agent to integrate and polish the Pawmodoro prototype. All three features already work; the agent must not rewrite them. Required changes: (1) FR-T8 — after a focus phase completes naturally, show "Add a quick note? (y/n)"; `Y` opens `read_line` and saves via `journal_add`, anything else continues to the break; (2) the main-menu dashboard must reload live values on every return to the menu (pomodoros today, habits done/total); (3) make sure every exit path — Q, Ctrl+C, and any failed syscall — goes through `term_restore`; (4) handle a terminal smaller than 80×24 by showing a "Please enlarge the terminal" message (use `ioctl TIOCGWINSZ = 0x5413`) instead of a broken layout; (5) add consistent footer key-help lines on all screens and a short status/message line for feedback such as "Saved", "Already done today", "Could not save"; (6) fix any visual glitches such as leftover characters when a shorter line replaces a longer one (use `ESC[K`). Provide a checklist the agent must run: key mashing on every screen, empty inputs, 300-character inputs, missing and corrupted data files (truncate `habits.dat` to 10 bytes and confirm the program does not crash — treat invalid data as empty), and Ctrl+C on every screen. The agent must list every file it changed and why.

**Verify:** ☐ note prompt after a focus session works ☐ dashboard updates ☐ Ctrl+C everywhere is clean ☐ corrupted `habits.dat` does not crash ☐ small-terminal message.

---

## T10 — Testing, debugging, screenshots

**Goal:** the "Create test cases" and "Validate logic through testing" requirements, plus screenshots for the paper.
**Files:** `tests/TEST_PLAN.md`, `tests/smoke.sh`.

> **Prompt-Builder Paragraph — T10**
> Build me a prompt for a coding agent to create the test assets for the Pawmodoro prototype and to fix any bugs they reveal. Deliver `tests/TEST_PLAN.md` containing a table of at least 30 test cases with columns: ID, Feature, Objective (O1–O5), Preconditions, Steps, Expected result, Actual result (blank), Pass/Fail (blank). Cover: boot/menu/exit and terminal restoration, timer phases and cycle, pause/skip/stop, demo mode, bell, pomodoro persistence, habit add/check-in/delete/streak/history, journal add/view/limits, corrupted or missing data, invalid input, and Ctrl+C. Also deliver `tests/smoke.sh`, an automated smoke test using `tmux` (`new-session -d`, `send-keys`, `capture-pane -p`) that builds the program, launches it in a detached 80×24 session with a temporary working directory, drives demo-mode scenarios, and greps the captured screen for expected text (menu title, "Session 1 of 4", "Habits:", a journal line), printing PASS/FAIL per check. Then the agent must run the smoke test, run sanity checks with `strace -e write` and `strace -c`, debug failures with gdb or `strace` (using the `-g` symbols), fix root causes with minimal changes, and report each bug found: symptom, cause, fix. Finally, list which screens to screenshot for the report (menu, timer focus, timer paused, break, habits with streaks, journal view, post-session note prompt) with the key presses needed to reach each.

**Verify:** ☐ every test case run by a human and Pass/Fail filled ☐ smoke script passes ☐ all 7 screenshots captured (full terminal window, readable font) ☐ bug list saved for Chapter 4 ("Challenges").

---

## T11 — Documentation and Chapter 3 draft

**Goal:** the written Week 3 deliverables: commented code, README, and Chapter 3 (User Interface Requirements & Implementation).
**Files:** `README.md`, `docs/CHAPTER3_DRAFT.md`, code comments.

> **Prompt-Builder Paragraph — T11**
> Build me a prompt for a coding agent (or writing assistant) to produce the Week 3 documentation for Pawmodoro by reading the actual source in `src/`, `tests/TEST_PLAN.md`, and `docs/notes/`. Part A: audit every `.asm` and `.inc` file and add missing procedure headers (purpose, IN, OUT, CLOBBERS) and inline comments without changing any behaviour; confirm the build still passes. Part B: update `README.md` (setup, build, run, controls, data files, limitations such as fixed UTC+8 and 100 ms timing drift). Part C: write `docs/CHAPTER3_DRAFT.md` titled "CHAPTER 3 — USER INTERFACE REQUIREMENTS AND IMPLEMENTATION" in formal academic English with these sections: 3.1 Interface type and rationale (terminal UI with ANSI escape sequences, linking to Chapter 2); 3.2 Interface requirements (function keys per screen, screen layouts); 3.3 System architecture (module diagram described in text, finite state machine with a transition table); 3.4 Data design (binary and text file formats with byte layouts); 3.5 Implementation of each module (core logic, control flow, data storage) with short code excerpts under 15 lines each; 3.6 Instruction set actually used — a table grouped like Chapter 2, **including instructions not listed in Chapter 2** (such as `MUL`, `DIV`, `SHL`, `SHR`, `LEA`, `MOVZX`, `REP MOVSB`, `TEST`) so Figure 1 can be updated; 3.7 Testing (summary of test cases and results, bug list); 3.8 Screenshot list with captions. Only describe what the code really does and mark any claim the agent cannot verify as TODO. Output Markdown that I can paste into our Word document.

**Verify:** ☐ every procedure has a header ☐ README works on a clean clone ☐ Chapter 3 matches the code (read it once against the source) ☐ Figure 1 (instruction chart) updated.

---

## Fix Paragraph (use any time a task fails)

> **Prompt-Builder Paragraph — Fix**
> Build me a prompt for a coding agent to fix a bug in Pawmodoro. Context: the task I just finished is **[Tn — name]**. Here is the symptom: **[what you did, what you expected, what happened]**. Here are the exact build/runtime messages and any `strace` or `gdb` output: **[paste]**. The agent must read `docs/PRD.md` and only the files involved, reproduce the problem first, explain the root cause in plain language, make the smallest possible fix, avoid touching unrelated code or renaming procedures, rebuild with no warnings, re-run the task's verification steps, and report what changed. If the fix needs an interface change, the agent must stop and ask before making it.

---

## Week 3 Definition of Done (maps to the instructor's guide and rubric)

| Guide deliverable | Evidence | Rubric criterion |
|-------------------|----------|------------------|
| Working prototype | PRD §8 criteria 1–7 pass | Program Functionality |
| Assembly source with inline comments | headers + comments in all `src/` files | Code Quality & Documentation |
| Test cases | `tests/TEST_PLAN.md` filled in, smoke test | Understanding of Assembly, Functionality |
| Screenshots | 7 screenshots from T10 | Presentation & Reporting |
| Chapter 3 draft | `docs/CHAPTER3_DRAFT.md` pasted to the group document | Interface & Usability, Research & Analysis |
| Ability to explain the code | `docs/notes/*.md` read by the group; every member can trace one feature end-to-end | Understanding of Assembly |

**Suggested split for 4 members (after T4 the modules are independent):** one member each owns T5 (timer), T7 (habits), T8 (journal), and one owns T10–T11 (tests, docs). T0–T4 and T6 should be done together so everyone works from the same foundation. Merge through git, one task per branch.
