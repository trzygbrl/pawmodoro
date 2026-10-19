# Pawmodoro

**Pawmodoro** is an interactive, distraction-free terminal productivity application written in pure **32-bit x86 Assembly (NASM)** for Linux. The application interfaces directly with the Linux kernel using the legacy `int 0x80` system call interface with zero C runtime (`libc`) dependencies.

Pawmodoro combines a Pomodoro countdown timer with cozy ASCII art, a daily habit tracker with 7-day visual history and streak calculation, and an append-only timestamped personal journal inside an ANSI/VT100 terminal user interface.

---

## Key Features

- **Pure 32-bit Assembly Execution:** Zero external library runtime dependencies (`nostdlib`). Direct Linux kernel `int 0x80` syscall dispatch for file I/O, terminal control, and timing.
- **Tear-Free Frame Rendering:** Frame buffers are aggregated in an internal 8,192-byte buffer (`out_buf`) and flushed to the terminal in a single `sys_write` call per frame, completely eliminating visual flicker.
- **Interactive Pomodoro Engine:** Standard 25-minute focus intervals, 5-minute short breaks, and 15-minute long breaks (or toggleable high-speed demo mode: 10s focus / 5s short break / 8s long break) with pause, resume, and skip support.
- **Visual Cat Art & Progress Bar:** 3-pose ASCII cat art (idle, focused work, sleeping break) paired with a real-time 30-column progress bar and audio bell alerts (`\a`).
- **Habit Tracker with 7-Day History:** Up to 8 tracked habits with bitwise shift history representations (`[#]` check-in vs `[.]` missed), automatic streak tracking, duplicate name detection, and interactive row deletion.
- **Append-Only Timestamped Journal:** Real-time log appending formatted with local calendar date and time (`YYYY-MM-DD HH:MM | <text>`), backwards tail scanning for the 10 most recent entries, and input sanitization.
- **Reliable Terminal State Machine:** Automatic terminal size gating (enforces 80×24 geometry), raw non-canonical polling for instantaneous dispatch, cooked line discipline for text editing, and POSIX signal handlers (`SIGHUP`, `SIGINT`, `SIGTERM`) guaranteeing clean terminal restoration.

---

## Environment & Toolchain Setup

Pawmodoro targets the **i386 ELF** binary format on Linux. It runs natively on 32-bit x86 Linux or on 64-bit Linux (`x86_64`) kernels configured with 32-bit compatibility support.

### Prerequisites (Ubuntu / Debian / WSL2)

Install the required build tools, terminal multiplexer, and debuggers:

```bash
sudo apt update
sudo apt install nasm binutils make gdb tmux strace
```

### Enabling 32-bit ELF Execution

Modern 64-bit Linux distributions and WSL2 kernels support 32-bit ELF binaries out of the box. Because Pawmodoro issues direct `int 0x80` kernel system calls and does not link against the C runtime, **no 32-bit multiarch libraries (such as `libc6:i386`) are required**.

If running on Windows:
- Run under **WSL2** (Windows Subsystem for Linux 2). Verify your installation with `wsl -l -v`. WSL1 lacks full compatibility for certain 32-bit system call behaviors.
- Native x86_64 hardware is required. ARM-based hosts (such as Apple Silicon Macs running ARM Linux VMs) require emulation (e.g., `qemu-user-static`) to run x86-32 binaries.

---

## Build, Run, & Debug Commands

All compilation, linking, execution, and debugging tasks are automated via `Makefile`:

| Command | Action |
|---|---|
| `make` | Compiles `src/main.asm` to `build/pawmodoro.o` and links `build/pawmodoro` (32-bit ELF) |
| `make run` | Builds and launches Pawmodoro in the active terminal |
| `./build/pawmodoro` | Runs the compiled binary directly |
| `make debug` | Builds with DWARF debugging symbols and launches `gdb` |
| `make clean` | Removes the `build/` directory and compiled object binaries |

---

## Interactive Controls Reference

Every screen in Pawmodoro is strictly bound to specific keypresses. Unhandled keys are silently ignored without redrawing or executing terminal writes.

### 1. Main Menu (Dashboard)
- `1` — Start Pomodoro Focus Session
- `2` — Open Habit Tracker
- `3` — Open Personal Journal
- `4` — Toggle Demo Mode ON / OFF (accelerates focus to 10s, short break to 5s, long break to 8s)
- `Q` / `Ctrl+C` — Cleanly exit application to shell

### 2. Pomodoro Timer
- `P` — Pause / Resume active countdown
- `S` — Skip current phase (advances immediately to next scheduled phase)
- `Q` — Stop timer and return to Main Menu
- `Ctrl+C` — Clean exit to shell (terminal restored)
- *Post-Focus Prompt:* `Y` to open quick-note prompt, or any other key to continue to break

### 3. Habit Tracker
- `A` — Add new habit (prompts in cooked mode; max 31 characters; pressing Enter alone cancels)
- `1` – `8` — Check in corresponding habit for today (once per day)
- `D` — Delete habit (prompts for number 1–8; any non-numeric key cancels)
- `B` — Return to Main Menu
- `Ctrl+C` — Clean exit to shell

### 4. Personal Journal
- `N` — New entry (prompts in cooked mode; max 200 characters; pressing Enter alone cancels)
- `V` — View 10 most recent entries (chronological top-to-bottom, oldest to newest)
- `B` — Return to Main Menu
- `Ctrl+C` — Clean exit to shell

---

## Data Files & Storage Specifications

Pawmodoro maintains three persistent data files in the working directory. In accordance with PRD §4.5, all files are opened with mode `0644` (`-rw-r--r--`). Corrupted, missing, or truncated files are handled gracefully by defaulting to empty state without throwing runtime errors.

### 1. `stats.dat` (12 Bytes Binary)
Stores completed Pomodoro focus sessions.
- **Offset 0..3 (4 bytes):** `day` — 32-bit unsigned integer day number since Unix epoch (local time).
- **Offset 4..7 (4 bytes):** `today_count` — Focus sessions completed today (automatically resets to 0 when `day` does not match today's date).
- **Offset 8..11 (4 bytes):** `total_count` — All-time lifetime completed focus sessions.

### 2. `habits.dat` (Variable Length Binary, 4 to 388 Bytes)
Stores up to 8 user habits in a compact binary record layout.
- **Offset 0..3 (4 bytes):** `habit_count` — 32-bit unsigned integer (0..8).
- **Offset 4..387 (Up to 8 records of 48 bytes each):**
  - `+0..31` (32 bytes): Habit name string (`NUL`-terminated ASCII, sanitized).
  - `+32..35` (4 bytes): `last_day` — Last day number checked in.
  - `+36..39` (4 bytes): `streak` — Consecutive active check-in day streak count.
  - `+40..43` (4 bytes): `total` — Lifetime check-in count.
  - `+44..47` (4 bytes): `history` — 32-bit bitmask where bit 0 is today, bit 1 is yesterday, etc. Shifted left by the day delta upon each check-in.

### 3. `journal.txt` (Append-Only Text File)
Stores short notes and session reflections in human-readable plain text format:
```text
YYYY-MM-DD HH:MM | <user note text>
```
Each entry occupies a single line ending with `\n` (`0x0A`). Non-printable control characters (< `0x20` or == `0x7F`) are sanitized to `?` upon insertion to prevent escape injection or terminal corruption.

---

## Testing & Quality Assurance

Pawmodoro includes an automated smoke test suite implemented in `tests/smoke.sh` using headless `tmux` sessions.

### Running Automated Tests

Run the core 16 verification scenarios:
```bash
./tests/smoke.sh
```

Run the full extended test suite (includes the full 4-session Pomodoro cycle test in demo mode):
```bash
./tests/smoke.sh --full
```

### Smoke Test Scenario Coverage
1. Main menu title, dashboard stats, and demo mode indicator
2. Invalid keystroke rejection without visual tearing
3. Demo mode toggle (Key `4`)
4. Pomodoro timer initialization and `[DEMO]` indicator (Key `1`)
5. Timer pause (`P`) and resume (`P`) countdown verification
6. Natural focus completion and quick-note prompt integration
7. Break phase transition and phase skipping (`S`)
8. Main menu dashboard synchronization and 12-byte `stats.dat` persistence
9. Habit creation, check-in, duplicate prevention, and binary `habits.dat` integrity
10. Journal entry recording, tail scanning, and UTC+8 timestamp validation
11. Resilient startup on truncated or corrupted binary data files
12. Raw mode `Ctrl+C` clean exit with status code `0`
13. Cooked mode `Ctrl+C` intercept and signal restoration with exit code `130`
14. Non-interactive standard input error handling (`/dev/null` redirection exit `1`)
15. Terminal resize gating on windows smaller than 80×24
16. Strict boundary verification preventing horizontal frame overflow past column 56
17. *(Extended `--full`)* Complete 4-session cycle transitioning into long break

---

## Documented System Limitations

In accordance with PRD §6.3, §7, and §10, the prototype operates with the following documented architectural trade-offs:

1. **Fixed Timezone Offset (`TZ_OFFSET`):** Timezone calculations are compile-time constants set to `TZ_OFFSET = 28800` seconds (UTC+8, Philippine Standard Time). Host system timezone files (`/etc/localtime`) are bypassed to avoid runtime parser overhead.
2. **Sub-Second Timing Drift:** The Pomodoro timer loop sleeps in 100 ms increments using `sys_nanosleep`. Due to Linux kernel scheduling jitter and system load, cumulative sub-second drift (~50–100 ms per minute) can occur.
3. **Strict Terminal Geometry (80×24):** Pawmodoro requires a terminal window of at least 80 columns by 24 rows. If the window falls below this geometry, the synchronous resize gate (`ui_size_gate`) halts rendering and prompts the user to enlarge the screen.
4. **Exit Status Code Semantics:** Clean exits via key `Q` or `Ctrl+C` in raw mode return status code `0` (`EXIT_SUCCESS`). Exits triggered by `Ctrl+C` (`SIGINT`) during cooked mode line input return status code `130` (`128 + SIGINT`) per POSIX standards.

