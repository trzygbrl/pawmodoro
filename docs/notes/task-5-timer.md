# Task 5: Pomodoro Timer Engine & View Walkthrough

**Task ID:** `task-5-timer`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the architecture and implementation of the Pomodoro timer engine completed in Task 5. It details the phase state machine and session progression, the non-blocking 100 ms timing loop, the zero-drift pause mechanism, fixed-point progress bar arithmetic via x86 `MUL`/`DIV`, control handover to `main.asm`, the Task 6 statistics hook, and system call verification (`strace`/`tmux`). Written in plain language, this guide enables any team member to confidently explain and defend the timer implementation during project evaluations.

---

## 1. Phase State Machine & Session Progression

### Phases and the Pomodoro Cycle (PRD §4.2 FR-T1, FR-T2)
The Pomodoro technique alternates between focused work intervals and recuperative rest breaks. In Pawmodoro, this is modeled with three symbolic phase identifiers defined in `src/constants.inc`:
- `PHASE_FOCUS` (`0`): Active work session (Standard: 25 min / Demo: 10 s).
- `PHASE_SHORT_BREAK` (`1`): Short rest interval (Standard: 5 min / Demo: 5 s).
- `PHASE_LONG_BREAK` (`2`): Extended rest interval awarded after every full cycle of 4 completed sessions (Standard: 15 min / Demo: 8 s).

Durations are stored in two lookup tables in `src/data.asm` (`timer_durations_normal` and `timer_durations_demo`). At the start of every phase, `timer_phase_start` checks `[demo_mode]`. Using scaled indexing `[table + phase*4]`, it loads the appropriate duration into `[total_secs]` and `[remaining_secs]` without magic numbers or branch-heavy conditionals.

### The Session Counter and Progression Logic
A Pomodoro cycle consists of `SESSIONS_PER_CYCLE` (4) completed focus intervals tracked by `[session_no]` (1..4):
1. **Focus Completion:** When a focus session runs naturally to 0, the session is officially marked completed (`focus_completed_flag = 1`).
2. **Break Assignment:**
   - If `session_no < 4`: The next phase is `PHASE_SHORT_BREAK`.
   - If `session_no == 4`: The next phase is `PHASE_LONG_BREAK`.
3. **Break Completion:**
   - While a break runs, the screen continues to display the session number it follows (e.g., Short Break shows "Session 1 of 4", Long Break shows "Session 4 of 4").
   - When a short break ends, `session_no` increments (`session_no++`) and the next phase is `PHASE_FOCUS`.
   - When a long break ends, the 4-session cycle is complete; `session_no` resets to 1 and the cycle restarts at `PHASE_FOCUS`.

### Design Decision: The Skipped-Focus Rule
A core usability principle of productivity timers is that skipping work should not award cycle progress. We formalized this behavior into an explicit state rule:
- **Skipping Focus (`S` key):** A user skipping a focus phase receives a short break to reset, but the session is **not completed** (`focus_completed_flag` remains `0`).
- **Skipping / Ending Break:** When a break concludes (or is skipped with `S`), `timer_advance_phase` inspects `[focus_completed_flag]`:
  - If `focus_completed_flag == 1` (focus was genuinely finished), `session_no` advances.
  - If `focus_completed_flag == 0` (focus was skipped), `session_no` **does not change**. The user is returned to the same focus session number to try again.

---

## 2. The 100 ms Tick Loop & Frame Throttling (FR-T5, FR-U4)

### Non-Blocking Event-Driven Timing Loop
A major pitfall in novice Assembly timers is "busy-waiting" (looping continuously checking the clock), which pegs CPU usage at 100%. Pawmodoro eliminates busy-waiting through a structured sleep-and-poll loop:

```nasm
.tick_loop:
    call time_sleep_100ms       ; sys_nanosleep(0 sec, 100,000,000 ns)
    call key_poll               ; Non-blocking keyboard check (read 1 byte)
    
    ; Handle keys immediately (latency <= 100 ms)
    cmp eax, KEY_CTRL_C
    je .key_ctrl_c
    cmp eax, KEY_Q
    je .key_q
    cmp eax, KEY_P
    je .key_p
    cmp eax, KEY_S
    je .key_s

    ; Check pause state
    cmp dword [paused], 1
    je .tick_loop

    ; Sub-second tick accumulation
    inc dword [ticks]
    cmp dword [ticks], TICKS_PER_SECOND ; 10 ticks = 1 second
    jb .tick_loop

    ; 1 full second elapsed
    mov dword [ticks], 0
    dec dword [remaining_secs]
    ...
```

### Why Rendering is Throttled to 1 Hz
Terminal I/O is comparatively slow and CPU-intensive. Re-rendering the full 56-column frame every 100 ms would trigger 10 writes per second, causing terminal buffer backpressure and subtle screen flutter.

In Pawmodoro:
1. Sub-second ticks (`[ticks]`, 0..9) accumulate in memory without triggering screen updates.
2. A redraw occurs **only when the displayed second changes** (every 10th tick), or when user input changes the visible interface (pressing `P` to pause/resume or `S` to skip).
3. Any unhandled key (e.g. arrow keys, space, letters) is discarded without triggering a redraw.
4. As a result, the application generates **exactly one frame per second** while running, and idle CPU utilization stays at **0.0%**.

---

## 3. How Pause Freezes Time Without Drift

When the user presses `P`:
1. `xor dword [paused], 1` toggles the pause flag between `0` (running) and `1` (paused).
2. `timer_draw` is immediately called and flushed, displaying the bright yellow `PAUSED` label at `(Row 5, Col 27)` and swapping `[P] Pause` to `[P] Resume` on the help row.
3. In subsequent iterations of `.tick_loop`, the check `cmp dword [paused], 1 / je .tick_loop` short-circuits execution before `[ticks]` or `[remaining_secs]` can be modified.
4. The application continues sleeping 100 ms and polling keys non-blockingly, so pressing `P` resumes countdown instantaneously with zero drift: elapsed sub-second ticks resume exactly where they were suspended.

---

## 4. Progress Bar Arithmetic (`ui_progress_bar`)

### Contract and Mathematics (PRD §6.4)
Procedure `ui_progress_bar` computes both the character fill count and display percentage from integer inputs:
- `EAX` = elapsed time in seconds (`total_secs - remaining_secs`)
- `ECX` = total phase duration in seconds (`total_secs`)

It appends to `out_buf`:
```text
[ + filled '#' + empty '-' + ]  + percentage + %
```
where the inner bar is fixed at `PROGRESS_BAR_WIDTH` (30 characters) and scale is `PERCENT_SCALE` (100).

The mathematical formulas are:
$$\text{filled} = \frac{\text{elapsed} \times 30}{\text{total}}$$
$$\text{percent} = \frac{\text{elapsed} \times 100}{\text{total}}$$

### Register Preservation and x86 Integer Division
In x86 assembly, 32-bit unsigned division (`DIV r32`) divides the 64-bit pair `EDX:EAX` by the operand. If `EDX` contains garbage or signed sign-bits from `CDQ`, division will compute erroneous results or trigger a hardware divide exception (`#DE`).

Per PRD §6.2, we strictly follow the unsigned integer convention:
1. Clamp `elapsed` to `total` so `elapsed <= total`.
2. Guard against division by zero: if `total == 0`, immediately output 30 filled characters and `100%`.
3. Before `div ecx`, explicitly clear `EDX` via `xor edx, edx` (never `CDQ`).
4. Preserve all registers using `save_regs` / `restore_regs` and `push eax` / `pop eax` (never `PUSHA`/`POPA`).

### Worked Example: 5 of 10 Seconds (Demo Focus)
Given $\text{elapsed} = 5$ and $\text{total} = 10$:

1. **Calculate Filled Characters:**
   - $\text{EAX} = 5$
   - `mov edx, 30` $\rightarrow$ `mul edx` $\rightarrow \text{EAX} = 150, \text{EDX} = 0$.
   - `xor edx, edx` $\rightarrow \text{EDX} = 0$.
   - `div ecx` (divide by 10) $\rightarrow$ quotient in $\text{EAX} = 15$, remainder in $\text{EDX} = 0$.
   - Filled count = 15. Empty count = $30 - 15 = 15$.

2. **Calculate Percentage:**
   - $\text{EAX} = 5$
   - `mov edx, 100` $\rightarrow$ `mul edx` $\rightarrow \text{EAX} = 500, \text{EDX} = 0$.
   - `xor edx, edx` $\rightarrow \text{EDX} = 0$.
   - `div ecx` (divide by 10) $\rightarrow$ quotient in $\text{EAX} = 50$, remainder in $\text{EDX} = 0$.
   - Percentage = 50%.

3. **Output Emission:**
   - Appends `'['`
   - Emits 15 `'#'` characters via `buf_repeat`
   - Emits 15 `'-'` characters via `buf_repeat`
   - Appends `']'`
   - Appends two spaces `"  "`
   - Emits decimal `"50"` via `buf_u32`
   - Appends `'%'`
   - Result in `out_buf`: `[###############---------------]  50%`.

---

## 5. Control Handover to `main.asm` & Safe Exit Architecture

### Single Responsibility Cleanup (FR-U5)
Pawmodoro maintains a single, unified cleanup path located in `src/main.asm` (`.handle_exit`), which restores cooked canonical terminal mode, unhides the cursor, leaves the alternate screen buffer, and resets color styles before calling `sys_exit`.

No sub-procedure or module is permitted to call `sys_exit` directly on normal user exit.

### Handover Protocol
`timer_run` operates as a self-contained modal loop. Control handover is clean and explicit:
- **User Presses 'Q':**
  1. `timer_run` sets `[state] = STATE_MENU`.
  2. `timer_run` executes `ret` back to `main.asm`.
  3. `main.asm` sets `need_redraw = 1` and returns to `.main_loop`, which cleanly renders and flushes the main menu.
- **User Presses Ctrl+C (Byte 3):**
  1. Because terminal raw mode clears `ISIG`, Ctrl+C does not raise an asynchronous OS `SIGINT`. It arrives as a standard byte `3` (`KEY_CTRL_C`).
  2. `timer_run` catches `KEY_CTRL_C`, sets `[state] = STATE_QUIT`, and executes `ret`.
  3. In `main.asm`, the dispatch detects `[state] == STATE_QUIT` and jumps directly to `.handle_exit`.
  4. `term_restore` executes, and the terminal is left 100% pristine.

---

## 6. Phase Completion, Audio Bell & Task 6 Hook

When `remaining_secs` reaches 0 naturally:
1. If the completed phase was `PHASE_FOCUS`:
   - It sets `mov dword [focus_completed_flag], 1`.
   - It marks the exact integration point for Task 6:
     ```nasm
     ; T6 HOOK: call stats_add_pomodoro here
     ```
2. `timer_draw` renders the completion frame showing `00:00`, `100%`, and the completion prompt on Row 8:
   - Focus: `"Focus complete! Press any key for a break."`
   - Break: `"Break over! Press any key to focus."`
3. The terminal audio bell byte (`ansi_bell`, `0x07`) is appended to `out_buf`.
4. `buf_flush` writes both the completion frame and the bell in **exactly one `sys_write` call**.
5. The engine calls `key_wait` to pause until the user acknowledges with any key before starting the next phase.

---

## 7. Verification and Test Evidence

### Build Verification
```bash
make clean && make
file build/pawmodoro
```
**Output:**
```text
rm -rf build
mkdir -p build
nasm -f elf32 -g -F dwarf -Wall src/main.asm -o build/pawmodoro.o
ld -m elf_i386 build/pawmodoro.o -o build/pawmodoro
build/pawmodoro: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), statically linked, with debug_info, not stripped
```
*(Zero warnings, zero errors)*

### Automated Terminal Capture (`tmux`)

**1. Focus Session Running (Demo Mode, Pose 1 Working Cat):**
```text
+------------------------------------------------------+
|  FOCUS - Session 1 of 4                    [DEMO]    |
|                                                      |
|     /\_/\                                            |
|    ( -.- )       00:08                               |
|     > ^ <                                            |
|   [######------------------------]  20%              |
|                                                      |
|  [P] Pause    [S] Skip    [Q] Stop and go back       |
+------------------------------------------------------+
```

**2. Paused State (Countdown Frozen, PAUSED Indicator, Resume Help):**
```text
+------------------------------------------------------+
|  FOCUS - Session 1 of 4                    [DEMO]    |
|                                                      |
|     /\_/\                                            |
|    ( -.- )       00:08  PAUSED                       |
|     > ^ <                                            |
|   [######------------------------]  20%              |
|                                                      |
|  [P] Resume   [S] Skip    [Q] Stop and go back       |
+------------------------------------------------------+
```

**3. Natural Completion (00:00, 100%, Audio Bell, Prompt on Row 8):**
```text
+------------------------------------------------------+
|  FOCUS - Session 1 of 4                    [DEMO]    |
|                                                      |
|     /\_/\                                            |
|    ( -.- )       00:00                               |
|     > ^ <                                            |
|   [##############################]  100%             |
|  Focus complete! Press any key for a break.          |
|  [P] Pause    [S] Skip    [Q] Stop and go back       |
+------------------------------------------------------+
```

**4. Short Break (Pose 2 Resting Cat with "zZ", 00:05):**
```text
+------------------------------------------------------+
|  SHORT BREAK - Session 1 of 4              [DEMO]    |
|                                                      |
|     /\_/\   z                                        |
|    ( u.u )  Z    00:05                               |
|     > ^ <                                            |
|   [------------------------------]  0%               |
|                                                      |
|  [P] Pause    [S] Skip    [Q] Stop and go back       |
+------------------------------------------------------+
```

**5. Full 4-Session Cycle Transition Sequence:**
```text
Focus 1 (10s) -> Short Break 1 (5s)
Focus 2 (10s) -> Short Break 2 (5s)
Focus 3 (10s) -> Short Break 3 (5s)
Focus 4 (10s) -> Long Break (8s)
Roll-over -> Focus 1 (10s) of next cycle
```

### System Call Evidence (`strace`)
We traced system call execution over a complete 10-second demo session:
```bash
strace -e trace=write,read,nanosleep -o /tmp/paw.strace ./build/pawmodoro
```
**Results:**
- Total `write(1)` calls: **15** (Initial terminal setup, menu render, 10 timer frames at 1 per second, completion frame with bell, menu restoration, and clean exit).
- Total `nanosleep` calls: **107** (~10 sleeps per second during the 10-second active period).
- Idle CPU usage measured with `ps -o %cpu,cmd -C pawmodoro`: **0.0%**.

---

## 8. Questions a Grader Might Ask

**Q1: Why did you use a 100 ms sleep loop instead of sleeping for 1 whole second?**  
*Answer:* A 1-second sleep would make keyboard input feel laggy and unresponsive, as keys would take up to a full second to register. By sleeping in 100 ms increments and polling non-blockingly, keystrokes (like Pause, Skip, or Quit) respond within 0.1 seconds, giving the user a snappy, professional experience while keeping CPU usage at 0.0%.

**Q2: Why does `ui_progress_bar` use `xor edx, edx` before every `div` instruction?**  
*Answer:* In 32-bit x86 assembly, `div reg` divides the combined 64-bit value in `EDX:EAX`. For unsigned arithmetic, `EDX` must contain the high 32 bits (which is 0). If `EDX` were not explicitly zeroed, leftover values from prior operations would corrupt the quotient or trigger a `#DE` divide-by-zero hardware exception.

**Q3: What happens to the session counter if a user skips a focus phase?**  
*Answer:* Under our design decision, skipping a focus phase does not count as completing work. The user transitions to a short break, but `focus_completed_flag` remains 0. When that break finishes, `session_no` does not advance, ensuring the user must actually finish the focus time to earn cycle progress.

**Q4: How did you combine the visual completion frame and the terminal bell into a single system call?**  
*Answer:* We assemble the completion screen inside `out_buf` using `timer_draw`, and then immediately append the ASCII bell byte (`0x07`, `ansi_bell`) into `out_buf` before calling `buf_flush`. This ensures the terminal emulator receives both the visual frame and the audio bell in a single atomic `sys_write(1, out_buf, len)` call, eliminating flicker and multiple syscall overhead.
