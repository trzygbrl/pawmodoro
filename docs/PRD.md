# Pawmodoro — Product Requirements Document (PRD)

**Version:** 1.0 (Week 3 Prototype) · **Course:** CAO10 · **Group:** 8
**Product:** Pawmodoro — an Assembly-based terminal productivity application
**Audience of this document:** an AI prompt-writer and a coding agent. Keep this file in the repo at `docs/PRD.md`.

> The generic "Mini Calculator" title in the instructor's project guide is only a template. This project is **Pawmodoro** (see Chapters 1–2). The Week 3 guide requirements still apply: working prototype, assembly source with inline comments, test cases, screenshots, Chapter 3 draft.

---

## 1. Product Overview

Pawmodoro combines three productivity functions in one lightweight terminal program written entirely in **NASM x86 (32-bit) Assembly for Linux**, with a cozy cat/ASCII-art interface:

1. **Pomodoro timer** — 25 min focus, 5 min short break, 15 min long break.
2. **Habit tracker** — record recurring habits, daily check-ins, streaks, last-7-days history.
3. **Journal / notes** — short timestamped text entries saved to a file.

**Problem (from Chapter 1):** people switch between separate tools for focus time, habits, and notes. Pawmodoro puts them in one place while demonstrating that Assembly can build a complete, user-facing application.

**Week 3 goal:** a working, demo-able prototype where all three features run, persist data between runs, and the terminal is always restored cleanly on exit.

## 2. Goals and Non-Goals

**Goals (map to Chapter 1 specific objectives)**

| # | Objective | Satisfied by |
|---|-----------|--------------|
| O1 | Pomodoro timer with work/break periods | FR-T* |
| O2 | Habit tracker showing consistency over time | FR-H* |
| O3 | Journal/notes feature | FR-J* |
| O4 | Core functions implemented in Assembly | All modules; no libc, no C |
| O5 | Terminal UI: menus, text feedback, ASCII art | FR-U* |

**Non-goals:** GUI, cloud sync, networking, accounts, social features, external service integration, sound beyond the terminal bell, claiming Pawmodoro is more effective than other apps.

## 3. Platform and Toolchain

- **OS:** 32-bit Linux ABI. Develop on Ubuntu (native, VM, or **WSL2**). 64-bit Linux kernels run 32-bit ELF binaries; if a hello-world fails with "Exec format error", enable 32-bit support / use a VM.
- **Assembler:** `nasm -f elf32 -g -F dwarf`
- **Linker:** `ld -m elf_i386` (no libc, entry label `_start`)
- **System calls:** `int 0x80` only. No `printf`, no C runtime.
- **Terminal:** ANSI/VT100 capable, minimum **80×24**.
- **Build tool:** `Makefile` with targets `all`, `run`, `debug` (gdb), `clean`.
- **Run location:** data files are created in the current working directory.

### 3.1 Syscall reference (i386)

| Name | EAX | EBX | ECX | EDX |
|------|-----|-----|-----|-----|
| exit | 1 | exit code | | |
| read | 3 | fd | buffer | count |
| write | 4 | fd | buffer | count |
| open | 5 | path | flags | mode |
| close | 6 | fd | | |
| time | 13 | 0 | | |
| ioctl | 54 | fd | request | arg pointer |
| nanosleep | 162 | &timespec | 0 | |

Open flags: `O_RDONLY=0`, `O_WRONLY=1`, `O_CREAT=0x40`, `O_TRUNC=0x200`, `O_APPEND=0x400`; file mode `0644` octal (`420` decimal). `timespec` = two dwords `{tv_sec, tv_nsec}`. Return value in EAX; negative = error.

### 3.2 Terminal control (termios via ioctl)

- `TCGETS = 0x5401`, `TCSETS = 0x5402`. `struct termios` (i386) is **36 bytes**: `c_iflag`@0, `c_oflag`@4, `c_cflag`@8, `c_lflag`@12 (dwords), `c_line`@16, `c_cc[19]`@17.
- `c_lflag` bits: `ISIG=0x01`, `ICANON=0x02`, `ECHO=0x08`. `c_cc` indexes: `VTIME=5`, `VMIN=6`.
- **Raw mode** (menus, timer): clear `ICANON|ECHO|ISIG`; set `VMIN=0`, `VTIME=0` so `read` returns immediately. Ctrl+C arrives as byte `3` and the program treats it as "quit" (and must restore the terminal).
- **Cooked mode** (typing names/notes): restore the saved original termios so the user gets echo and backspace editing.

### 3.3 ANSI sequences used

| Effect | Bytes |
|--------|-------|
| Clear screen / cursor home | `ESC[2J` / `ESC[H` |
| Move cursor | `ESC[<row>;<col>H` |
| Erase to end of line | `ESC[K` |
| Hide / show cursor | `ESC[?25l` / `ESC[?25h` |
| Alternate screen on / off | `ESC[?1049h` / `ESC[?1049l` |
| Reset / bold | `ESC[0m` / `ESC[1m` |
| Colors | `ESC[31m` red … `ESC[37m` white (16-color palette) |
| Bell | `0x07` |

## 4. Functional Requirements

### 4.1 Application shell (FR-U)
- **FR-U1** On start: switch to alternate screen, hide cursor, save termios, enter raw mode, load saved data.
- **FR-U2** Main menu with keys: `1` Start focus session · `2` Habit tracker · `3` Journal · `4` Toggle demo mode · `Q` Quit. Invalid keys are ignored.
- **FR-U3** Program is a **finite state machine**: `STATE_MENU`, `STATE_TIMER`, `STATE_HABITS`, `STATE_JOURNAL`, `STATE_QUIT`, dispatched with `CMP` + conditional jumps (or a jump table).
- **FR-U4** All drawing goes to an **output buffer** and is flushed with a **single `sys_write`** per frame (no flicker). Redraw uses cursor-home, not full clear, for animated screens.
- **FR-U5** Every exit path (Q, Ctrl+C, error) calls `term_restore` (original termios, show cursor, leave alternate screen, reset colors) before `sys_exit`.
- **FR-U6** ASCII-art cat in at least three poses: idle (menu), working (focus), resting (break). Cozy palette (warm red/yellow/cyan on default background).
- **FR-U7** Main menu shows a dashboard line: pomodoros completed today and habits done today (`done/total`).
- **FR-U8** Borders use plain ASCII (`+ - |`) in the prototype (UTF-8 box drawing is a stretch goal).

### 4.2 Pomodoro timer (FR-T)
- **FR-T1** Phases: `FOCUS` 25:00, `SHORT_BREAK` 5:00, `LONG_BREAK` 15:00. After every 4th completed focus session the next break is long; the counter then resets.
- **FR-T2** **Demo mode** (toggle on menu): FOCUS 10 s, SHORT 5 s, LONG 8 s — essential for testing and the live demo. Menu shows `Demo mode: ON/OFF`.
- **FR-T3** Screen shows phase name, session number (e.g. "Session 2 of 4"), remaining time `MM:SS`, a 30-character progress bar with percentage, the cat pose for the phase, and key help.
- **FR-T4** Keys during a phase: `P` pause/resume · `S` skip to next phase · `Q` stop and return to menu · Ctrl+C quit app. Paused state is shown on screen and the countdown freezes.
- **FR-T5** Timing uses `sys_nanosleep` in **100 ms** steps; ten steps = one second. Each step also polls the keyboard (non-blocking) so keys respond within ~0.1 s. Idle CPU use stays near zero.
- **FR-T6** When a phase ends: ring bell (`0x07`), show a completion message, wait for any key (Enter/Space) before starting the next phase.
- **FR-T7** A focus session counts as completed **only if it runs to zero** (a skipped or stopped session is not counted). Completed count is saved (see FR-D2).
- **FR-T8** After a completed focus session offer "Add a quick note? (y/n)"; `y` opens the journal line input and saves the entry (integration with FR-J).

### 4.3 Habit tracker (FR-H)
- **FR-H1** Up to **8** habits, names up to **31** characters.
- **FR-H2** Screen lists habits: number, name, last-7-days squares, current streak, total check-ins. Example row: `1. Drink water   [.][#][#][#][.][#][#]   streak 2   total 14`.
- **FR-H3** Keys: `A` add habit (cooked-mode line input; empty input cancels) · `1`–`8` check in that habit for today · `D` then number deletes a habit · `B` back.
- **FR-H4** Check-in rules (let `today` = local day number, `delta = today - last_day`):
  - `delta == 0` → already done today; show a message, change nothing.
  - otherwise `history = (delta >= 32 ? 0 : history << delta) | 1`; `streak = (delta == 1) ? streak + 1 : 1`; `total += 1`; `last_day = today`.
  - A new habit has `last_day = 0` (never checked in).
- **FR-H5** Display rules: show the streak as `0` if `today - last_day > 1`. For the 7 squares, shift `history` left by `(today - last_day)` for display only (if `< 32`) and show bits 6..0 oldest→newest; `#` = done, `.` = not done.
- **FR-H6** Habits persist in `habits.dat` and reload on next start.

### 4.4 Journal (FR-J)
- **FR-J1** Keys: `N` new entry (cooked-mode line input, max **200** characters; empty cancels) · `V` view the most recent **10** entries · `B` back.
- **FR-J2** Each entry is one line appended to `journal.txt`: `YYYY-MM-DD HH:MM | text\n` using local time (see §6.3).
- **FR-J3** `journal_add` is a reusable procedure (called by the journal screen and by the post-focus note prompt).
- **FR-J4** Viewing reads at most the last 4096 bytes of the file and prints the last 10 complete lines. If the file is missing/empty show "No entries yet."

### 4.5 Data and persistence (FR-D)
- **FR-D1** Missing files are not errors: treat as empty state and create on first save.
- **FR-D2** `stats.dat` (12 bytes): `day` (dword), `today_count` (dword), `total_count` (dword). On load, if `day != today`, reset `today_count = 0` and set `day = today`.
- **FR-D3** `habits.dat`: `count` (dword) followed by `count` records of 48 bytes: `name[32]` (NUL-terminated), `last_day` dd, `streak` dd, `total` dd, `history` dd.
- **FR-D4** A failed save shows a one-line "Could not save" message; the program keeps running.

## 5. Screen Wireframes (80×24, ASCII)

**Main menu**
```
+------------------------------------------------------+
|   /\_/\    P A W M O D O R O                         |
|  ( o.o )   cozy focus - habits - notes               |
|   > ^ <                                              |
+------------------------------------------------------+
|  Today: 3 pomodoros      Habits: 2/4 done            |
|                                                      |
|  [1] Start focus session                             |
|  [2] Habit tracker                                   |
|  [3] Journal                                         |
|  [4] Demo mode: OFF                                  |
|  [Q] Quit                                            |
+------------------------------------------------------+
```

**Timer**
```
+------------------------------------------------------+
|  FOCUS - Session 2 of 4                    [DEMO]    |
|                                                      |
|     /\_/\                                            |
|    ( -.- )     18:42                                 |
|     > ^ <                                            |
|   [################--------------]  55%              |
|                                                      |
|  [P] Pause    [S] Skip    [Q] Stop and go back       |
+------------------------------------------------------+
```

**Habits**
```
+------------------------------------------------------+
|  HABIT TRACKER                                       |
|  1. Drink water   [.][#][#][#][.][#][#]  streak 2    |
|  2. Read 10 pgs   [#][#][.][.][#][#][#]  streak 3    |
|                                                      |
|  [A] Add  [1-8] Check in today  [D] Delete  [B] Back |
+------------------------------------------------------+
```

**Journal**
```
+------------------------------------------------------+
|  JOURNAL                                             |
|  2026-10-19 09:12 | finished chapter 3 outline       |
|  2026-10-19 10:40 | need to fix timer pause bug      |
|                                                      |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

## 6. Technical Architecture

### 6.1 Repository layout
```
pawmodoro/
  Makefile
  README.md
  docs/PRD.md, docs/ROADMAP.md, docs/notes/   (one explanation note per task)
  src/
    main.asm        ; _start, main loop, state machine; %includes everything below
    constants.inc   ; syscall numbers, key codes, sizes, durations, TZ_OFFSET
    macros.inc      ; syscall + save/restore macros
    data.asm        ; .data strings, ASCII art, ANSI strings; .bss buffers
    io.asm          ; output buffer + number/string helpers
    term.asm        ; termios, keyboard, line input
    time.asm        ; sleep, clock, date formatting
    file.asm        ; load / save / append
    stats.asm       ; stats.dat
    ui.asm          ; frames, cat art, progress bar, menu rendering
    timer.asm       ; pomodoro
    habits.asm      ; habit tracker
    journal.asm     ; journal
  tests/
    TEST_PLAN.md, smoke.sh
  build/            ; generated
```
`main.asm` `%include`s the other files so one object file is produced. Section order: `.data`, `.bss`, `.text`.

### 6.2 Coding conventions (mandatory for every task)
1. **Calling convention:** arguments in registers as documented per procedure; return value in `EAX`; a procedure **preserves every register it changes except its documented outputs** (push/pop). Strings are NUL-terminated.
2. **Every procedure** begins with a header comment: purpose, `IN:`, `OUT:`, `CLOBBERS:`.
3. **Inline comments** on every logical group of instructions explaining *why* (rubric: "clean, well-commented, structured"). Section banners between groups.
4. **Naming:** `snake_case`; module prefixes `buf_`, `str_`, `term_`, `key_`, `time_`, `file_`, `stats_`, `ui_`, `timer_`, `habits_`, `journal_` (helper labels inside a module may use the same prefix). Local labels start with `.`. Constants `UPPER_CASE` via `equ`.
5. **No magic numbers** — define constants in `constants.inc`.
6. **Instruction scope:** use plain x86-32 integer instructions. Allowed beyond Chapter 2's list: `MUL/DIV`, `SHL/SHR`, `LEA`, `MOVZX`, `REP MOVSB/STOSB`, `TEST`, `NEG`, `CLD`, `PUSHA/POPA`. No SSE/FPU, no libc.
7. **One task per session.** Do not modify files outside the task unless fixing a bug the task exposed; say so if you do.
8. Build must be warning-free: `nasm -f elf32 -g -F dwarf -Wall` .
9. After finishing, write `docs/notes/<task-id>.md` in plain language explaining how the code works (the group must be able to explain it in the demo).

### 6.3 Time model
- `sys_time` returns UTC seconds. **Local time = UTC + `TZ_OFFSET`**, where `TZ_OFFSET = 28800` (UTC+8, Philippines), a constant in `constants.inc`.
- **Day number** = `(unix_time + TZ_OFFSET) / 86400`. Habits and stats use day numbers (so "today" rolls over at local midnight).
- Day number → calendar date: use the standard "civil from days" integer algorithm (Howard Hinnant). Test vectors: `0 → 1970-01-01`, `10957 → 2000-01-01`, `19723 → 2024-01-01`.

### 6.4 Module interface contract

| Module | Procedure | IN | OUT |
|--------|-----------|----|-----|
| io | `buf_str` | `ESI` = string | appends to output buffer |
| io | `buf_char` | `AL` | appends one byte |
| io | `buf_u32` | `EAX` | appends decimal |
| io | `buf_u32_2` | `EAX` (0–99) | appends 2 digits, zero-padded |
| io | `buf_mmss` | `EAX` = seconds | appends `MM:SS` |
| io | `buf_repeat` | `AL` char, `ECX` count | appends repeated char |
| io | `buf_goto` | `EAX` row, `EBX` col (1-based) | appends `ESC[r;cH` |
| io | `buf_flush` | — | one `sys_write`, resets buffer |
| io | `str_len` / `str_copy` | `ESI` (/ `EDI` dest) | `EAX` = length |
| term | `term_init` / `term_restore` | — | save termios + alt screen + hide cursor / undo all |
| term | `term_raw` / `term_cooked` | — | switch mode |
| term | `key_poll` | — | `EAX` = key (letters uppercased) or `-1` none; escape sequences ignored (`-1`) |
| term | `key_wait` | — | `EAX` = key, blocks (sleeping 50 ms between polls) |
| term | `read_line` | `EDI` buffer, `ECX` max chars | `EAX` = length; NUL-terminated; newline stripped; extra input discarded |
| time | `time_sleep_100ms` | — | — |
| time | `time_now` / `time_local` | — | `EAX` UTC secs / local secs |
| time | `time_today` | — | `EAX` day number |
| time | `time_fmt_date` | `EAX` day, `EDI` buf (11 B) | `YYYY-MM-DD\0` |
| time | `time_fmt_hhmm` | `EAX` local secs, `EDI` buf (6 B) | `HH:MM\0` |
| file | `file_load` | `ESI` path, `EDI` buf, `ECX` max | `EAX` bytes read, `-1` if missing |
| file | `file_save` | `ESI` path, `EDI` buf, `ECX` len | `EAX` 0 ok / -1 error (truncate+create) |
| file | `file_append` | `ESI` path, `EDI` buf, `ECX` len | `EAX` 0 ok / -1 error |
| stats | `stats_load` / `stats_add_pomodoro` / `stats_today` | — | `EAX` = today's count (for `stats_today`) |
| ui | `ui_draw_cat` | `EAX` pose (0 idle, 1 work, 2 rest) | appends art |
| ui | `ui_progress_bar` | `EAX` elapsed, `ECX` total | appends 30-char bar + percent |
| timer | `timer_run` | — | returns to menu when user leaves |
| habits | `habits_run`, `habits_done_today` | — | `EAX` done, `EBX` total |
| journal | `journal_run`, `journal_add` | `ESI` = text | `EAX` 0 ok / -1 error |

### 6.5 Memory (.bss) budget
`out_buf` 8192 · `in_buf` 16 · `line_buf` 256 · `file_buf` 512 · `jrnl_buf` 4096 · `termios_orig` 36 · `termios_raw` 36 · `timespec` 8 · state variables (dwords): `state`, `demo_mode`, `phase`, `session_no`, `ticks`, `paused`.

## 7. Non-Functional Requirements
- **Reliability:** terminal always restored; no crash on empty/missing files, empty input, over-long input, or unknown keys.
- **Performance:** < 1% CPU while the timer runs; binary under ~64 KB.
- **Usability:** every screen shows its available keys; invalid keys do nothing; no key combination should leave the user stuck.
- **Maintainability:** modular files, headers, inline comments, constants instead of literals.
- **Portability:** documented one-line setup for Ubuntu/WSL2: `sudo apt install nasm binutils make gdb`.

## 8. Prototype Acceptance Criteria (Definition of Done)
1. `make && ./build/pawmodoro` launches the menu in an 80×24 terminal.
2. Demo mode full cycle works: focus → short break → … → long break after the 4th focus, with pause/skip/stop.
3. Habits can be added, checked in (once per day), deleted, and survive a restart; streak and 7-day squares follow FR-H4/H5.
4. Journal entries can be added and viewed, survive a restart, and carry a correct local timestamp.
5. Pomodoros-today and habits-today show on the main menu and survive a restart.
6. Quitting by `Q` or Ctrl+C leaves the shell normal (echo on, cursor visible, main screen restored).
7. No crash on: missing data files, empty input, 300-character input, random key mashing.
8. All source has procedure headers and inline comments; `docs/notes/` explains each module.

## 9. Stretch Goals (only after §8 passes)
Big ASCII digits for the countdown · two-frame cat animation · custom durations setting · UTF-8 box borders · "last note" on the dashboard · journal search · color themes.

## 10. Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| 32-bit binaries won't run on the dev machine | Verify in Task 0 with hello-world; use Ubuntu VM/WSL2 |
| Terminal left in raw mode after a crash | Single `term_restore` used by every exit path; test Ctrl+C |
| Timer drift from 100 ms steps | Accept and document as a limitation (optional fix: compare against `sys_time`) |
| Agent rewrites working modules | One task per session, commit after every task, strict "touch only these files" rule |
| Code nobody understands | `docs/notes/<task>.md` explanation per task; group reads and annotates before merging |
| Timezone wrong on other machines | `TZ_OFFSET` constant, documented as a limitation |
