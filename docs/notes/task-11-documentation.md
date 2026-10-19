# Task 11 — Documentation, Source Comment Audit, and Chapter 3 Academic Draft

**Author / Proponents:** Trizy Gabriel N. Nicdao, Laurenze R. Punla, Kyla Catherine B. Yalung  
**Course & Section:** CAO10 — Computer Architecture and Organization (Group 8)  
**Instructor:** Mr. Ray A. Nicolas, MSIT  
**Date:** October 2026  
**Status:** Completed  

---

## 1. Executive Summary

Task 11 marks the culmination of the Week 3 deliverables for the **Pawmodoro** project. The purpose of this task is to transition the working assembly prototype into a fully documented, academically sound, and maintainable software engineering deliverable.

During this task, three major work packages were completed:
1. **Part A: Source Code Comment Audit:** A comprehensive audit of all 13 assembly files in `src/`. Uniform PRD §6.2 procedure headers were applied across all 36 contract procedures and internal helper routines. Inline comments were added to explain low-level register manipulations, system call numbers, and algorithmic logic, while preserving 100% of the underlying executable machine code (zero instructions modified, added, reordered, or removed).
2. **Part B: `README.md` Overhaul:** Complete rewriting of the project manual to provide clear environment setup guides (including 32-bit execution on 64-bit Linux/WSL2), a structured hotkey reference table across all four screens, detailed data storage specifications, test harness instructions, and documented system constraints.
3. **Part C: Chapter 3 Academic Draft (`docs/CHAPTER3_DRAFT.md`):** Authoring of the formal academic report chapter titled *"CHAPTER 3 — USER INTERFACE REQUIREMENTS AND IMPLEMENTATION"*, structured into eight detailed sections (3.1 to 3.8) with ASCII wireframes, finite state machine diagrams, `.bss` memory budgets, authentic code excerpts (<15 lines) for all 13 modules, an updated instruction set classification, testing methodology, and a 7-screenshot catalog.

---

## 2. Part A: Source Code Comment Audit

### 2.1 Uniform Procedure Header Standard
Every procedure across the codebase was standardized to follow the uniform comment block specified in PRD §6.2:

```nasm
;=============================================================================
; Procedure: <procedure_name>
; Purpose:   <Clear summary of function and behavior>
; IN:        <Register inputs and expected formats, or "None">
; OUT:       <Register outputs / return values, or "None">
; CLOBBERS:  <Documented clobbered registers (e.g. EAX), or "None (preserves all)">
;=============================================================================
```

### 2.2 Audited Modules
All 13 modules were audited and structured:
- `src/main.asm`: Added headers for `_start`, `main_loop`, and `app_exit`. Detailed the FSM dispatcher and synchronous window resize gate.
- `src/constants.inc`: Organized into functional banners (Syscalls, Termios, Colors, State Codes, Layout Offsets, Timing parameters).
- `src/macros.inc`: Documented `syscall`, `save_regs`, and `restore_regs` macros with exact register clobber contracts.
- `src/data.asm`: Grouped initialized ANSI string sequences and added detailed size and offset comments for `.bss` allocations.
- `src/io.asm`: Standardized headers for `buf_str`, `buf_char`, `buf_u32`, `buf_u32_2`, `buf_mmss`, `buf_repeat`, `buf_goto`, `buf_flush`, `str_len`, and `str_copy`. Added inline commentary on base-10 division and atomic `sys_write` flushing.
- `src/term.asm`: Audited `term_init`, `term_restore`, `term_raw`, `term_cooked`, `term_size_ok`, `term_install_signals`, `sig_handler`, `key_poll`, `key_wait`, and `read_line`. Clarified non-blocking raw configuration (`VMIN=0, VTIME=0`).
- `src/time.asm`: Audited `time_sleep_100ms`, `time_now`, `time_local`, `time_today`, `time_fmt_date`, and `time_fmt_hhmm`. Detailed unsigned integer math for calendar date conversion without floating-point instructions.
- `src/file.asm`: Standardized headers for `file_load`, `file_save`, and `file_append`. Clarified partial-read error checking and deterministic file descriptor closure.
- `src/stats.asm`: Audited `stats_load`, `stats_add_pomodoro`, and `stats_today`. Detailed day-rollover comparison logic.
- `src/ui.asm`: Audited `ui_draw_cat`, `ui_progress_bar`, `ui_draw_menu`, `ui_draw_frame`, `ui_draw_status`, and internal frame helpers. Documented multiplication and division routines for progress bar scaling.
- `src/timer.asm`: Standardized `timer_run`, `timer_draw`, `timer_phase_start`, `timer_advance_phase`, and `timer_skip_phase`. Detailed the 10 Hz non-blocking event loop.
- `src/habits.asm`: Audited `habits_run`, `habits_done_today`, `habits_add`, `habits_check_in`, `habits_delete`, and helper routines. Documented 32-bit history bitmask shifting and streak calculations.
- `src/journal.asm`: Audited `journal_run`, `journal_add`, `journal_load_tail`, and helper routines. Detailed reverse tail reading via `sys_lseek(SEEK_END)`.

### 2.3 Strict Behavioral Invariance
Verification via `git diff -w src/` confirmed that zero operational instructions, register assignments, memory addresses, or jump targets were changed. The assembly output remains byte-for-byte behaviorally invariant.

---

## 3. Part B: `README.md` Overhaul

The root `README.md` was rewritten to serve as an authoritative, professional guide for evaluators, students, and instructors:
- **Academic Context:** Clearly documents CAO10 Group 8, Angeles University Foundation, and the proponents.
- **Environment & 32-Bit Toolchain Setup:** Detailed instructions for Debian/Ubuntu and WSL2, explaining the installation of `libc6-dev-i386` and enabling the 32-bit execution domain (`dpkg --add-architecture i386`).
- **Build & Execution Matrix:** Exact shell commands for `make`, `make run`, `make debug`, `make test`, and `make clean`.
- **Structured Hotkey Reference:** Dedicated table mapping hotkeys across Main Menu, Focus Timer, Habit Tracker, and Journal.
- **Data File Binary Layouts:** Byte-level diagrams for `stats.dat` (12 bytes), `habits.dat` (4-byte header + 48-byte records), and `journal.txt` (append-only ASCII/UTF-8 log).
- **Testing Instructions:** Guide to executing `./tests/smoke.sh` and extended scenario testing via `./tests/smoke.sh --full`.
- **Documented System Limitations:** Transparent explanation of fixed UTC+8 offset, 100 ms nanosleep drift, 80×24 window geometry, and terminal signal exit codes (0 vs 130).

---

## 4. Part C: Chapter 3 Academic Draft (`docs/CHAPTER3_DRAFT.md`)

`docs/CHAPTER3_DRAFT.md` was drafted in formal academic English following the required curriculum outline:
- **Section 3.1 (Interface Type and Rationale):** Contrasts TUI with CLI and GUI paradigms; details raw vs cooked mode; connects with Chapter 2 bare-metal foundations.
- **Section 3.2 (Interface Requirements):** Comprehensive keystroke dispatch matrix; 7 full ASCII wireframe diagrams; 56-column visual frame specifications; semantic color guidelines.
- **Section 3.3 (System Architecture):** Four-tier module hierarchy; deterministic Finite State Machine diagram; exhaustive State Transition Table; single-`sys_write` tear-free rendering pipeline.
- **Section 3.4 (Data Design):** Fixed-width binary schemas for `stats.dat` and `habits.dat`; day-rollover reset logic; 32-day bitmask shift arithmetic; append-only `journal.txt`; static `.bss` allocation budget table (~13 KB).
- **Section 3.5 (Implementation of Each Module):** Detailed engineering breakdown of all 13 modules, each containing an authentic code excerpt directly cited from `src/` strictly fewer than 15 lines.
- **Section 3.6 (Instruction Set Actually Used):** Full x86-32 instruction classification table; thorough technical analysis justifying extended instructions (`MUL`, `DIV`, `SHL`, `SHR`, `LEA`, `MOVZX`, `REP MOVSB`, `REP STOSB`, `TEST`, `NEG`, `CLD`, `PUSHA`/`POPA`); updated Figure 1 for the formal report.
- **Section 3.7 (Testing and Quality Assurance):** 49 manual test cases mapped to O1–O5; headless `tmux` automation in `smoke.sh`; `strace` profiling verifying 10 Hz cadence and 0.0% idle CPU load; list of resolved bugs.
- **Section 3.8 (Screenshot Catalog):** Tabulates the 7 required official demonstration figures with titles, captions, and step-by-step reproduction keystrokes.

---

## 5. Verification and Quality Evidence

### 5.1 Warning-Free Compilation
```bash
make clean && make
```
*Result:*
- Object file `build/pawmodoro.o` assembled with `nasm -f elf32 -g -F dwarf -Wall`.
- Executable binary `build/pawmodoro` linked with `ld -m elf_i386`.
- **Zero compiler warnings, zero linker warnings, zero errors.**

### 5.2 Automated Smoke Test Suite (`./tests/smoke.sh`)
```bash
./tests/smoke.sh
```
*Result:*
```
=== 1. Building Pawmodoro ===
PASS: Build warning-free (32-bit ELF binary generated)
=== 2. Running Scenarios ===
PASS: Scenario 1 - Menu title, dashboard, and demo mode indicator
PASS: Scenario 2 - Invalid keys ignored without screen corruption
PASS: Scenario 3 - Key 4 toggles demo mode ON with status update
PASS: Scenario 4 - Key 1 starts focus timer with demo badge and controls
PASS: Scenario 5 - Pause freezes countdown and resume continues
PASS: Scenario 6 - Focus natural completion and quick-note save
PASS: Scenario 7 - Break transition and skip via key S
PASS: Scenario 8 - Return to menu, dashboard updated, stats.dat is 12 bytes
PASS: Scenario 9 - Habits add, check-in, duplicate guard, and 52B habits.dat
PASS: Scenario 10 - Journal add, view, and UTC+8 timestamp verified
PASS: Scenario 11 - Truncated/corrupted data treated safely as empty state
PASS: Scenario 12 - Raw mode Ctrl+C exits with code 0 and restores terminal
PASS: Scenario 13 - Cooked mode Ctrl+C intercepted, terminal restored, exit 130
PASS: Scenario 14 - Stdin redirection from /dev/null exits 1 with clear error
PASS: Scenario 15 - Size gate triggers on < 80x24 and recovers on resize
PASS: Scenario 16 - Zero screen overflow past column 56 across all screens
=============================================================================
SMOKE TEST RESULTS: 16 passed, 0 failed
=============================================================================
```

### 5.3 Extended Scenario Test (`./tests/smoke.sh --full`)
```bash
./tests/smoke.sh --full
```
*Result:*
```
=== Running Extended Scenario: Full 4-Session Pomodoro Cycle ===
PASS: Extended Scenario - Complete 4-session cycle ending in LONG BREAK and reset
=============================================================================
SMOKE TEST RESULTS: 17 passed, 0 failed
=============================================================================
```

---

## 6. Documented System Constraints and Pedagogical Trade-offs

For academic transparency, the following technical trade-offs are explicitly recorded:
1. **Compile-Time Timezone Offset:** The application implements a fixed compile-time offset `TZ_OFFSET = 28800` (UTC+8, Philippine Standard Time). Dynamically parsing `/etc/localtime` or querying glibc timezone functions was intentionally avoided to preserve zero-libc purity.
2. **Sub-Second Sleep Jitter:** The timing engine utilizes `sys_nanosleep` with a 100-millisecond quantum. Due to host OS scheduling latency and terminal drawing time, cumulative clock drift is approximately 50–100 ms per minute, which is negligible for human productivity intervals.
3. **80×24 Geometry Requirement:** The visual frame requires a minimum terminal geometry of 80 columns by 24 rows. Smaller windows synchronously trigger the size gate overlay until resized.
4. **Clean Exit Code Differentiation:** Normal raw-mode termination yields exit code 0 (`EXIT_SUCCESS`). Interruption during cooked-mode line editing (e.g. typing a habit name) returns exit code 130 (`128 + SIGINT`) while cleanly restoring terminal attributes.
