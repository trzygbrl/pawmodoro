# Pawmodoro

**Pawmodoro** is an interactive, distraction-free terminal productivity application written in pure **32-bit x86 Assembly (NASM)** for Linux. The application interfaces directly with the Linux kernel using the legacy `int 0x80` system call interface with zero C runtime (`libc`) dependencies (`-nostdlib`).

Pawmodoro combines an adaptive Pomodoro countdown timer with animated ASCII cat art, a daily habit tracker with 7-day visual history and streak calculation, an append-only timestamped personal journal with entry browsing and atomic deletion, persistent customizable 256-color themes, synthesized sound effects via external audio streaming, and layered terminal notifications inside an ANSI/VT100 terminal user interface.

---

## Key Features

- **Pure 32-bit Assembly Execution:** Zero external runtime dependencies (`nostdlib`). Direct Linux kernel `int 0x80` syscall dispatch for file I/O, process management, terminal control, and timekeeping.
- **Tear-Free Frame Rendering:** Frame buffers are aggregated in an internal 8,192-byte output buffer (`out_buf`) and flushed to standard output in a single `sys_write` call per frame, completely eliminating visual flicker.
- **Adaptive Terminal Layout Engine:** Queries terminal geometry dynamically via `sys_ioctl(TIOCGWINSZ)`. Layout automatically adapts between 80 and 100 columns (`ui_w = min(cols - 2, 100)`), horizontally centered with dynamic margins, with a synchronous safeguard gate enforcing the minimum 80×24 geometry.
- **Interactive Pomodoro Engine:** Standard 25-minute focus intervals, 5-minute short breaks, and 15-minute long breaks (or toggleable demo mode: 10s focus / 5s short break / 8s long break) with big ASCII countdown digits, cycle progress indicators, pause/resume, and phase skipping.
- **Visual Cat Art & Multi-Frame Animation:** Context-aware ASCII cat art (idle, focused work, sleeping break) with animated tail flicking, purring, and eye blinking driven by a 10 Hz timing loop with dirty-cell partial redraws and a 5 FPS write ceiling (or static rendering with zero idle writes under Reduce Motion).
- **Habit Tracker with 7-Day History:** Tracks up to 8 habits with bitwise shift history representations (`[#]` check-in vs `[.]` missed in ASCII mode, `[✓]` in UTF-8), consecutive active day streaks, cumulative check-in counters, and row deletion.
- **Personal Journal with In-Place Deletion:** Append-only log with local calendar timestamps (`YYYY-MM-DD HH:MM | <text>`), full-screen scrolling entry viewer with line wrapping (up to 200 characters per note), and atomic deletion using a staging temporary file (`journal.tmp`) and `sys_rename`.
- **Persistent Settings & 256-Color Themes:** 8 selectable themes (Default Amber, Catppuccin Mocha, Nord, Tokyo Night, Solarized Dark, Gruvbox, Cyberpunk, and Custom Palette) with an interactive 12-slot color editor, Reduce Motion toggle, audio volume control, ASCII/UTF-8 box-drawing selection, and layered completion notifications, all serialized to a compact 24-byte `settings.dat` file.
- **Integer Sound Synthesis:** Waveform generation (square, triangle, noise) implemented entirely with integer arithmetic (no x87 FPU or SSE instructions), streamed via non-blocking pipes to an external audio player (`paplay` or `aplay`), with graceful degradation to the ASCII terminal bell (`\a`).
- **Fault-Tolerant Terminal State Machine:** Non-blocking raw mode for instantaneous single-key dispatch, canonical cooked mode for text entry, and signal handlers (`SIGHUP`, `SIGINT`, `SIGTERM`) guaranteeing clean terminal restoration under all exit conditions.

---

## Environment & Toolchain Setup

Pawmodoro targets the **i386 ELF** binary format on Linux. It runs natively on 32-bit x86 Linux or on 64-bit Linux (`x86_64`) kernels configured with 32-bit compatibility support.

### Prerequisites (Ubuntu / Debian / WSL2)

Install the required build tools, terminal multiplexer, and utilities:

```bash
sudo apt update
sudo apt install nasm binutils make gdb tmux strace
```

### Audio Dependencies

Pawmodoro synthesizes raw PCM audio (44.1 kHz, 16-bit signed, mono) in memory and streams it to an external audio playback utility via pipe. To enable audio output, ensure one of the following players is installed:

- **PulseAudio / PipeWire (Recommended):** `paplay` (typically provided by `pulseaudio-utils`)
- **ALSA Fallback:** `aplay` (typically provided by `alsa-utils`)

```bash
sudo apt install pulseaudio-utils alsa-utils
```

If neither player is installed or available in `PATH`, the application silently disables sound playback without crashing or stalling, and terminal bell alerts (`\a`) remain functional.

### Running on 64-bit Linux & WSL2

Because Pawmodoro issues direct `int 0x80` kernel system calls and does not link against the C runtime library, **no 32-bit multiarch libraries (such as `libc6:i386`) are required**.

If running on Windows:
- Run under **WSL2** (Windows Subsystem for Linux 2). Verify your installation with `wsl -l -v`.
- **WSL Audio Note:** Audio playback in WSL depends on WSLg (standard on Windows 11). On Windows 10 or custom WSL configurations without an active PulseAudio/PipeWire bridge, external audio players may fail to find a sound server. Pawmodoro detects player launch failure gracefully and falls back to terminal visual/bell notifications.
- Native x86_64 hardware is required. ARM-based hosts (such as Apple Silicon running ARM Linux VMs) require user-space emulation (`qemu-user-static`) to run 32-bit x86 binaries.

---

## Build, Run, & Debug Commands

All compilation, linking, execution, and debugging tasks are automated via `Makefile`:

| Command | Action |
|---|---|
| `make` | Assembles `src/main.asm` to `build/pawmodoro.o` and links `build/pawmodoro` (32-bit ELF) |
| `make run` | Builds and launches Pawmodoro in the active terminal |
| `./build/pawmodoro` | Runs the compiled binary directly |
| `make debug` | Builds with DWARF debugging symbols and launches `gdb` |
| `make clean` | Removes the `build/` directory and compiled object binaries |

---

## Interactive Controls Reference

Every screen in Pawmodoro is bound to specific keypresses in raw mode. Unhandled keys are silently ignored without redrawing or executing terminal writes.

### 1. Main Menu (Dashboard)
- `1` — Start Pomodoro Focus Session
- `2` — Open Habit Tracker
- `3` — Open Personal Journal
- `4` — Toggle Demo Mode ON / OFF (accelerates focus to 10s, short break to 5s, long break to 8s)
- `5` — Open Settings & Themes Menu
- `Q` / `Ctrl+C` — Cleanly exit application to shell (restores terminal state)

### 2. Pomodoro Timer
- `P` — Pause / Resume active countdown (toggles `[PAUSED]` indicator and freezes elapsed ticks)
- `S` — Skip current phase (advances immediately to the next scheduled break or focus phase)
- `Q` — Stop timer and return to Main Menu
- `Ctrl+C` — Clean exit to shell (terminal restored)
- *Post-Focus Prompt:* `Y` to open the quick-note reflection prompt, or any other key to continue directly to the break phase.

### 3. Habit Tracker
- `A` — Add new habit (prompts in cooked mode; max 31 characters; pressing Enter alone cancels)
- `1` – `8` — Check in corresponding habit row for today (once per calendar day)
- `D` — Delete habit (prompts for row number 1–8; any non-numeric key cancels)
- `B` — Return to Main Menu
- `Ctrl+C` — Clean exit to shell

### 4. Personal Journal
- `N` — New entry (prompts in cooked mode; max 200 characters; pressing Enter alone cancels)
- `Up` / `Down` — Select entry in the journal list
- `PgUp` / `PgDn` — Page through journal entries
- `Enter` — Open Full Entry View modal for the currently selected entry (word-wrapped)
- `D` — Delete currently selected entry (prompts for `[Y/N]` confirmation; atomic rewrite via `journal.tmp`)
- `V` — Refresh and view recent entries
- `B` — Return to Main Menu
- `Ctrl+C` — Clean exit to shell

### 5. Settings & Themes
- `Up` / `Down` — Navigate settings options:
  - `Theme` (cycles through 8 themes)
  - `Reduce Motion` (OFF / ON — disables animations and idle redraws)
  - `Sound` (ON / OFF — synthesized audio playback)
  - `Sound Volume` (adjusts volume level: 25%, 50%, 75%, 100%)
  - `Bell` (ON / OFF — terminal audible/visual bell alert `\a`)
  - `Charset` (UTF-8 rounded borders vs ASCII fallback)
  - `Notifications` (None, Bell, Flash, Title, Progress, All)
- `Left` / `Right` or `Space` / `Enter` — Cycle option value backward / forward
- `C` — Open Custom Color Editor (available when `Theme: Custom` is highlighted)
- `R` — Reset all settings to defaults (prompts for `[Y/N]` confirmation)
- `B` — Save and return to Main Menu
- `Ctrl+C` — Clean exit to shell

#### Custom Color Editor (Modal)
- `Up` / `Down` — Select palette color slot (0: Background, 1: Frame/Border, 2: Text Normal, 3: Text Dim, 4: Accent Primary, 5: Accent Secondary, 6: Success/Focus, 7: Warning/Pause, 8: Break/Rest, 9: Error, 10: Highlight, 11: Extra)
- `Left` / `Right` — Adjust 256-color ANSI index (0–255)
- `Enter` — Save palette and return to Settings menu
- `Esc` / `B` — Cancel edits and discard changes

---

## Themes & Settings Configuration

### Built-In Color Themes

Pawmodoro supports 8 pre-configured 256-color palettes utilizing standard ANSI extended color sequences (`ESC[38;5;Nm` and `ESC[48;5;Nm`):

0. **Default Amber:** Warm retro terminal styling with golden yellow accents.
1. **Catppuccin Mocha:** Soothing pastel palette featuring soft blues, mauves, and lavenders.
2. **Nord:** Arctic, north-bluish palette with crisp icy blues and cool slates.
3. **Tokyo Night:** Deep dark-blue aesthetic inspired by neon Tokyo city lights.
4. **Solarized Dark:** Classic precision color scheme with teal and cyan foregrounds.
5. **Gruvbox:** Earthy retro groove palette featuring warm oranges, browns, and greens.
6. **Cyberpunk:** High-contrast neon aesthetic with vibrant magenta and electric yellow accents.
7. **Custom Palette:** User-customizable 12-slot color palette editable directly in the UI.

### Settings Persistence (`settings.dat`)

All user preferences are automatically persisted to `settings.dat` in the current working directory upon any modification:

- **File Size:** Exactly 24 bytes binary.
- **Binary Structure:**
  - `0x00..0x03` (4 bytes): Magic header `PAWS` (`0x53574150`).
  - `0x04..0x05` (2 bytes): Format version (`0x0001`).
  - `0x06..0x07` (2 bytes): Reserved flags.
  - `0x08` (1 byte): Active theme index (`0..7`).
  - `0x09` (1 byte): Animation enabled (`1` = active animations, `0` = Reduce Motion).
  - `0x0A` (1 byte): Sound enabled (`1` = ON, `0` = OFF).
  - `0x0B` (1 byte): Sound volume (`1..4` representing 25%, 50%, 75%, 100%).
  - `0x0C` (1 byte): Bell enabled (`1` = ON, `0` = OFF).
  - `0x0D` (1 byte): Charset mode (`0` = UTF-8 rounded, `1` = strict 7-bit ASCII).
  - `0x0E` (1 byte): Notification mode (`0` = None, `1` = Bell, `2` = Flash, `3` = Title, `4` = Progress, `5` = All).
  - `0x0F` (1 byte): Reserved alignment padding.
  - `0x10..0x1B` (12 bytes): Custom palette color indices for color slots 0 through 11.
- **Error Handling:** If `settings.dat` is missing, unreadable, or corrupted (invalid magic or short read), Pawmodoro silently applies built-in default values and creates a clean 24-byte file upon the next setting update.

---

## Audio Architecture & Requirements

Pawmodoro synthesizes sound effects programmatically at runtime without external audio asset files or floating-point instructions:

- **Synthesizer Implementation:** Employs pure integer arithmetic to generate 44.1 kHz, 16-bit signed mono PCM waveforms (square waves, triangle waves, and pseudo-random noise bursts) directly into an internal 32,768-byte synthesis buffer (`sfx_buf`).
- **Sound Events:** Distinct audio cues accompany timer completion, phase transitions, habit check-in, habit deletion, journal operations, settings adjustments, and invalid keystrokes.
- **Process Spawning & IPC:** To play audio without blocking the main event loop, the application forks a child process via `sys_fork` (syscall 2), creates a non-blocking IPC pipe via `sys_pipe` (syscall 42), redirects the pipe read end to standard input (`sys_dup2`), and invokes `paplay` or `aplay` via `sys_execve` (syscall 11).
- **Signal & Process Safety:** The parent process sets `SIGCHLD` and `SIGPIPE` handlers to `SIG_IGN` or safe cleanup routines, actively avoiding zombie process accumulation and preventing pipeline crashes if the external player exits prematurely.
- **Audible Bell Fallback:** If audio playback is disabled or external players are absent, Pawmodoro utilizes the standard terminal bell sequence (`\a`, ASCII `0x07`) when `bell_enabled` is active.

### Practical Audio Troubleshooting

1. **Verify Player Availability:** Run `command -v paplay` and `command -v aplay` in your shell. At least one must return an executable path.
2. **Test Audio Independently:** Verify host audio output outside Pawmodoro:
   ```bash
   paplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null || aplay /usr/share/sounds/alsa/Front_Center.wav
   ```
3. **WSLg Considerations:** Under Windows Subsystem for Linux, audio streaming requires WSLg (default on Windows 11). On Windows 10, WSL lacks built-in PulseAudio forwarding unless manually configured with an X11/PulseAudio server. Pawmodoro operates cleanly with sound disabled if host audio forwarding is unavailable.

---

## Data Files & Storage Specifications

Pawmodoro maintains its runtime data files in the current working directory. All persistent files are opened with mode `0644` (`-rw-r--r--`). To preserve your statistics, habits, journal, and settings across sessions, always launch Pawmodoro from the same working directory.

### 1. `stats.dat` (12 Bytes Binary)
Stores completed Pomodoro focus counts:
- `0x00..0x03` (4 bytes): `stats_day` — 32-bit unsigned integer day number since Unix epoch (local civil time).
- `0x04..0x07` (4 bytes): `today_count` — Focus sessions completed today (automatically resets to 0 upon day rollover).
- `0x08..0x0B` (4 bytes): `total_count` — All-time lifetime completed focus sessions.

### 2. `habits.dat` (Variable Length Binary, 4 to 388 Bytes)
Stores up to 8 user habits in a compact binary record layout:
- `0x00..0x03` (4 bytes): `habit_count` — 32-bit unsigned integer ($N \in [0, 8]$).
- Up to 8 records of 48 bytes each:
  - `+0x00..0x1F` (32 bytes): Habit name string (`NUL`-terminated ASCII, up to 31 characters).
  - `+0x20..0x23` (4 bytes): `last_day` — Last day number checked in.
  - `+0x24..0x27` (4 bytes): `streak` — Consecutive active check-in day streak count.
  - `+0x28..0x2B` (4 bytes): `total` — Lifetime cumulative check-in count.
  - `+0x2C..0x2F` (4 bytes): `history` — 32-bit bitmask where bit 0 is today, bit 1 is yesterday, etc.

### 3. `journal.txt` (Append-Only Text File)
Stores reflections and session notes in human-readable plain text:
```text
YYYY-MM-DD HH:MM | <user note text>
```
Each entry occupies a single line terminated with `\n` (`0x0A`). Input text is accepted up to 200 characters (`JOURNAL_ENTRY_MAX = 200`). Non-printable control characters (< `0x20` or == `0x7F`) are sanitized to prevent escape injection.

### 4. `settings.dat` (24 Bytes Binary)
Stores user configuration, feature toggles, and custom color slot mappings as detailed in the Settings section.

### 5. `journal.tmp` (Staging Temporary File)
Created during journal entry deletion. Pawmodoro copies the surviving journal records to `journal.tmp` using block file I/O, closes both descriptors, and atomically replaces `journal.txt` via `sys_rename` (syscall 38). If disk space is exhausted or a write error occurs, `journal.tmp` is unlinked and `journal.txt` remains unaltered.

---

## Testing & Quality Assurance

Pawmodoro includes an automated headless smoke test suite implemented in `tests/smoke.sh` using `tmux` virtual terminals.

### Running Automated Tests

Run the core 31 verification scenarios:
```bash
./tests/smoke.sh
```

Run the extended test suite (includes the full multi-session Pomodoro cycle verification):
```bash
./tests/smoke.sh --full
```

### Smoke Test Scenario Summary (31 Scenarios)
- **Scenarios 1–4:** Main menu rendering, key filtering, demo mode toggle, and focus timer initialization.
- **Scenarios 5–8:** Timer pause/resume, natural focus completion, quick-note saving, break skip (`S`), dashboard update, and 12-byte `stats.dat` persistence.
- **Scenarios 9–10:** Habit addition, check-in, 52-byte record integrity, journal addition, entry viewing, full view modal, and deletion confirmation.
- **Scenarios 11–14:** Truncated/corrupted file resilience, raw mode `Ctrl+C` exit (0), cooked mode `Ctrl+C` intercept (130), and non-TTY standard input error handling.
- **Scenarios 15–16:** Window resize gate (< 80×24) and screen boundary overflow protection across all screens.
- **Scenarios 17–20:** Settings navigation, color editor, 24-byte `settings.dat` persistence, visual elements (greeting, tips, cycle dots, pause badge), strict 7-bit ASCII mode, and UTF-8 rounded borders.
- **Scenarios 21–24:** Animation write throttle ($\le$ 5 FPS), Reduce Motion zero idle writes, integer sound synthesis, `.bss` allocation ceiling verification (62,392 B $\le$ 81,920 B), zero zombie subprocesses, theme persistence across restarts, and malformed settings recovery.
- **Scenarios 25–31:** Journal deletion safety with temporary staging, 200-character entry wrapping, wide terminal resizing (100 columns centered), sound disable pipe verification, and graceful missing-player degradation.

---

## Documented System Limitations & Known Behaviors

In accordance with PRD requirements and actual implementation behavior:

1. **Fixed Timezone Offset (`TZ_OFFSET`):** Timezone calculations use a compile-time constant set to `TZ_OFFSET = 28800` seconds (UTC+8, Philippine Standard Time). Host system timezone files (`/etc/localtime`) are bypassed to avoid runtime parsing overhead.
2. **Habit Name Validation:** The habit creation routine checks for non-empty input and enforces the 8-habit maximum capacity. Duplicate habit names are currently permitted and are not rejected by the input validator.
3. **Sub-Second Timing Drift:** The Pomodoro timer loop sleeps in 100 ms increments using `sys_nanosleep`. Minor cumulative sub-second scheduling drift (~50–100 ms per minute) may occur under heavy host system load.
4. **Minimum Terminal Geometry (80×24):** Pawmodoro requires a terminal window of at least 80 columns by 24 rows. If the window dimensions fall below this limit, rendering is paused and a clear resize notification is displayed until the terminal is enlarged.
5. **Terminal-Dependent Escape Sequences:** Advanced features such as desktop notifications (OSC 99 / OSC 9) and taskbar progress indicators (OSC 9;4) require terminal emulators that support these specifications (e.g., modern Windows Terminal, Kitty, Foot). Terminals without support ignore these escape sequences without displaying artifacts.
6. **Exit Status Code Semantics:** Normal exit via key `Q` or raw mode `Ctrl+C` returns status code `0` (`EXIT_SUCCESS`). Interruption during text entry in cooked mode returns status code `130` (`128 + SIGINT`) per POSIX standards.
