# V9 — Notifications and Terminal Integration

This engineering document explains the design, assembly-level implementation, register contracts, settings persistence, and verification results for Task V9 (Notifications and Terminal Integration) in **Pawmodoro**, a terminal Pomodoro productivity tool written in 32-bit x86 NASM assembly for Linux without libc or C runtimes.

---

## 1. What changed

Task V9 implements configurable, layered notifications triggered on natural phase completion (and synchronized throughout countdown timing), while strictly preserving Pawmodoro's existing timer state machine, audio engine, one-frame-per-write rendering architecture, and terminal cleanup guarantees.

Five distinct notification layers are provided:

1. **Layer 1: Phase-Completion Audio Bell (`0x07`)**
   - Emits the standard ASCII Bell character (`0x07`, BEL) when a countdown phase naturally completes.
   - Operates as the baseline, zero-dependency completion alert.
   - Gated independently by the bell layer bit (`0x01`).

2. **Layer 2: Brief Screen Flash (`ESC[?5h` / `ESC[?5l`)**
   - On natural phase completion, inverts the terminal screen display via DEC private mode sequence `ESC[?5h`, delays approximately 150 ms via `sys_nanosleep`, and deactivates the inversion with `ESC[?5l`.
   - This 150 ms activation/deactivation pair represents the **sole explicitly permitted additional standalone terminal write** outside the normal buffered frame flush.
   - Guaranteed deactivation: even on unexpected signals or error exits, `term_restore` always transmits `ESC[?5l`.

3. **Layer 3: Continuously Updated Window Title (`OSC 0`)**
   - Batched directly into the normal frame buffer (`out_buf`) during each second's timer redraw with zero additional `sys_write` syscalls.
   - During countdown: `ESC]0;Pawmodoro - <PHASE> MM:SS\x07` (e.g. `ESC]0;Pawmodoro - FOCUS 24:59\x07`).
   - On phase completion: `ESC]0;Pawmodoro - Time's up!\x07`.
   - On returning to menu or exiting: restored cleanly to `ESC]0;Pawmodoro\x07`.

4. **Layer 4: Windows Terminal Taskbar Progress (`OSC 9;4`)**
   - Appends the Windows Terminal taskbar progress sequence to the frame buffer: `ESC]9;4;1;<percent>\x07` where `<percent>` is an integer computed as `(elapsed * 100) / total_secs` (clamped defensively to 0..100 without division by zero).
   - Automatically cleared via `ESC]9;4;0;0\x07` when:
     - The timer is paused (`paused == 1`).
     - A phase completes and the completion screen replaces the active countdown.
     - The timer returns to the dashboard menu (`Q` / stop).
     - The application exits through any normal or signal-driven shutdown path.

5. **Layer 5: Optional Desktop Notifications (`proc_spawn`)**
   - Attempts an asynchronous desktop toast upon natural phase completion without blocking timer execution or spawning zombie processes.
   - Primary Linux mechanism: checks if `/usr/bin/notify-send` is executable via `sys_access` (`X_OK`), then invokes `proc_spawn` with an argument vector (`notify-send`, `Pawmodoro`, `<phase message>`).
   - Experimental WSL fallback: if `/usr/bin/notify-send` is not installed and the environment is WSL, probes for `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe` and spawns a non-blocking balloon tip notification.
   - Silent nonfatal failure: if no notifier is present or process creation fails, Pawmodoro continues running smoothly without error.

6. **60-Second Repeat Reminder (`notify_reminder_tick`)**
   - While the completion screen waits for user keystroke acknowledgment, a 100 ms tick counter tracks elapsed time up to 600 ticks (60 seconds).
   - Every 60 seconds, enabled alert layers (bell, flash, toast) are re-triggered without restarting the timer, advancing the phase, or dropping user input.

---

## 2. How the settings work

The persistent settings model in `settings.dat` remains exactly 24 bytes, maintaining byte-level compatibility with PRD V2 §5:

- **Byte 21: `setting_notify` (Master Flag)**
  - `0`: Terminal integration disabled. Strictly suppresses Layers 2 through 5 (Screen Flash, Window Title, Taskbar Progress, Desktop Toast).
  - `1`: Terminal integration enabled. Layers 2 through 5 fire according to their bitmask configuration.
- **Byte 22: `setting_notify_layers` (Layer Bitmask)**
  - Bit 0 (`0x01`): Layer 1 — Terminal Bell. (Default enabled, operates independently of the master flag).
  - Bit 1 (`0x02`): Layer 2 — Screen Flash.
  - Bit 2 (`0x04`): Layer 3 — Window Title.
  - Bit 3 (`0x08`): Layer 4 — Taskbar Progress.
  - Bit 4 (`0x10`): Layer 5 — Desktop Notification.
  - Default value: `0x01` (`DEFAULT_NOTIFY_LAYERS`).

### Settings UI Interaction (Screen Row 16 / Option 5)

On the Settings screen:
- Row 5 displays: `Terminal integration  < ON/OFF >  1:Bel  2:Flsh  3:Titl  4:Prog  5:Toast`.
- When an individual layer bit is enabled, its tag is displayed in `SLOT_OK` (green). When disabled, it appears in `SLOT_DIM` (gray).
- **Master toggle:** Pressing `Enter`, `Space`, `Left`, or `Right` while on Row 5 toggles `setting_notify` (`0 <-> 1`) and calls `settings_mutate_and_save`.
- **Individual layer toggles:** Pressing number keys `1`, `2`, `3`, `4`, or `5` while on Row 5 directly toggles the respective bit in `setting_notify_layers` and immediately saves to disk.
- **Context-sensitive footer:** The footer dynamically indicates `[Enter/Space] Master ON/OFF   [1-5] Toggle Layer   [B/Esc] Back`.

---

## 3. How process spawning works (`proc_spawn`)

To prevent code duplication between audio synthesis playback (V8) and desktop notifications (V9), `src/sfx.asm` introduces `proc_spawn`.

### Design & Safety Guarantees:
1. **Asynchronous Execution:** Spawns a child process via `sys_fork` (syscall 2). The parent process returns immediately (`EAX = 0`) without stalling timer countdown or audio synthesis.
2. **Standard I/O Redirection:**
   - In the child, standard input (fd 0) is redirected to `/dev/null` (`O_RDONLY`).
   - Standard output (fd 1) and standard error (fd 2) are redirected to `/dev/null` (`O_WRONLY`).
   - This ensures third-party executables never dump diagnostic text or corrupt the ncurses-like terminal UI.
3. **Execution & Child Failure Trap:**
   - Child executes the target binary with arguments via `sys_execve` (syscall 11).
   - If `execve` fails (e.g. binary missing or permission error), the child calls `sys_exit` with code 127 (`SYS_EXIT, 127`).
   - **Crucial Invariant:** The child NEVER calls `term_restore` or parent exit routines, preventing corrupting the parent's terminal state.
4. **Zombie Process Prevention:**
   - The application configures `SIGCHLD` disposition to `SIG_IGN` at initialization (`sys_signal(SIGCHLD, SIG_IGN)`). The Linux kernel automatically reaps terminated child processes without creating zombies or requiring parent blocking `waitpid` calls.
5. **Preserving V8 Audio Engine:**
   - The existing audio playback procedure (`sfx_play`) maintains its specialized unidirectional Linux pipe (`sys_pipe`) for streaming raw synthesized PCM samples to `aplay`/`paplay`. It does not conflict with `proc_spawn`.

---

## 4. Procedure contracts

All new and modified procedures adhere strictly to PRD §6.2: 32-bit x86 integer instructions only, no libc, no FPU/SSE, `int 0x80` syscall ABI, and complete register preservation of all non-output registers.

### 1. `proc_spawn`
- **Module:** `src/sfx.asm`
- **Purpose:** Launches an arbitrary executable with an argument vector asynchronously in a child process with `/dev/null` I/O redirection.
- **IN:**
  - `ESI` = pointer to NUL-terminated executable path string.
  - `EDI` = pointer to NULL-terminated array of 32-bit pointers to argument strings (`argv`).
- **OUT:**
  - `EAX` = `0` on success (process created), `-1` on error (fork failure).
- **CLOBBERS:** `EAX` (preserves `EBX`, `ECX`, `EDX`, `ESI`, `EDI`).

### 2. `notify_phase_complete`
- **Module:** `src/timer.asm`
- **Purpose:** Dispatches enabled notification layers on natural phase completion (Layer 1 bell, Layer 2 flash, Layer 5 toast).
- **IN:** None (reads `[phase]`, `[setting_notify]`, and `[setting_notify_layers]`).
- **OUT:** None.
- **CLOBBERS:** None (preserves all registers).

### 3. `notify_screen_flash`
- **Module:** `src/timer.asm`
- **Purpose:** Standalone terminal write routine that emits `ESC[?5h`, sleeps ~150 ms via `sys_nanosleep`, and deactivates with `ESC[?5l`.
- **IN:** None.
- **OUT:** None.
- **CLOBBERS:** None (preserves all registers).

### 4. `notify_title_update`
- **Module:** `src/timer.asm`
- **Purpose:** Appends OSC 0 title escape sequences to `out_buf` during frame rendering (countdown `ESC]0;Pawmodoro - <PHASE> MM:SS\x07` or completion `ESC]0;Pawmodoro - Time's up!\x07`).
- **IN:** `EAX` = frame mode (0 = running countdown, 1..4 = completion screen / note prompt).
- **OUT:** Appends formatted bytes to `out_buf`.
- **CLOBBERS:** None (preserves all registers).

### 5. `notify_progress_update`
- **Module:** `src/timer.asm`
- **Purpose:** Appends Windows Terminal OSC 9;4 taskbar progress sequences to `out_buf` during frame rendering (state 1 running `ESC]9;4;1;<percent>\x07` or state 0 clear `ESC]9;4;0;0\x07` on pause/completion).
- **IN:** `EAX` = frame mode (0 = running, 1..4 = completion).
- **OUT:** Appends formatted bytes to `out_buf`.
- **CLOBBERS:** None (preserves all registers).

### 6. `notify_clear_external`
- **Module:** `src/timer.asm`
- **Purpose:** Resets external terminal title to `Pawmodoro` and clears taskbar progress. Flushes buffer immediately. Idempotent and safe to call repeatedly.
- **IN:** None.
- **OUT:** None.
- **CLOBBERS:** None (preserves all registers).

### 7. `notify_desktop_toast`
- **Module:** `src/timer.asm`
- **Purpose:** Probes `/usr/bin/notify-send` (or WSL `powershell.exe`) and launches desktop notification via `proc_spawn`.
- **IN:** None (reads `[phase]`).
- **OUT:** None.
- **CLOBBERS:** None (preserves all registers).

### 8. `notify_reminder_tick`
- **Module:** `src/timer.asm`
- **Purpose:** Ticks the 100 ms completion wait timer and re-dispatches alerts every 60 seconds (600 ticks).
- **IN:** None.
- **OUT:** None.
- **CLOBBERS:** None (preserves all registers).

### 9. `term_restore` (Modified)
- **Module:** `src/term.asm`
- **Purpose:** Unified cleanup routine called on normal exit, Ctrl+C, signals, and errors.
- **Changes:** Appends `ansi_flash_off`, `ansi_taskbar_clear`, and `ansi_title_restore` to ensure flash, taskbar, and title are always restored.
- **Contract:** Unchanged (`IN`: None, `OUT`: None, `CLOBBERS`: None).

---

## 5. Terminal compatibility

| Notification Layer | Escape Sequence / Mechanism | Windows Terminal | XTerm / GNOME Terminal / Alacritty | Tmux / Screen | Linux Virtual Console (TTY) |
|---|---|---|---|---|---|
| **Layer 1: Bell** | `0x07` (ASCII BEL) | Supported (audio/visual bell configured by user) | Supported | Supported | Supported (PC speaker beep) |
| **Layer 2: Screen Flash** | `ESC[?5h` / `ESC[?5l` | Supported (DEC private mode reverse video) | Supported in XTerm; ignored gracefully in modern libvte | Passed through or ignored gracefully | Supported on VGA text console |
| **Layer 3: Window Title** | `ESC]0;...BEL` | Supported | Widely supported | Supported (updates window/pane title) | Ignored safely without artifact |
| **Layer 4: Taskbar Progress** | `ESC]9;4;1;<percent>BEL` | Supported (colors taskbar icon green/yellow/red) | Ignored safely by standard XTerm/libvte | Ignored safely or passed through | Ignored safely without artifact |
| **Layer 5: Linux Toast** | `/usr/bin/notify-send` | N/A (requires DBus & Notification Daemon) | Supported on desktop environments (GNOME, KDE, XFCE) | Supported on desktop | Headless/TTY fails gracefully (no daemon) |
| **Layer 5: WSL Toast** | `powershell.exe` Balloon Tip | Supported under WSL host | N/A (WSL-specific fallback) | Supported under WSL | N/A |

---

## 6. How to test

### Step 1: Clean Build
```bash
make clean
make
```
Verify zero assembler warnings under NASM `-Wall`.

### Step 2: Automated Smoke Regression Test Suite
```bash
bash tests/smoke.sh
```
Executes all 22 automated end-to-end scenarios covering startup, timer states, persistence, memory bounds, signals, and raw terminal cleanup.

### Step 3: Interactive Verification of Layer Controls
1. Launch `./build/pawmodoro`.
2. Press `5` to open the Settings screen.
3. Move down to Row 5: `Terminal integration`.
4. Observe the layer indicators: `1:Bel  2:Flsh  3:Titl  4:Prog  5:Toast`.
5. Press `Enter` or `Space` to toggle master notification ON/OFF.
6. Press keys `1`, `2`, `3`, `4`, `5` to toggle individual layers. Notice the color changes between green (`SLOT_OK`) and dim gray (`SLOT_DIM`).
7. Press `B` to return to menu and `Q` to quit. Inspect `hexdump -C settings.dat` to confirm bytes 21 and 22 reflect the changes.

### Step 4: Verification of Countdown & Completion Sequences
1. Set `settings.dat` notification master to 1 and layer mask to `0x1F`.
2. Launch `./build/pawmodoro`.
3. Press `4` to enable `[DEMO]` mode.
4. Press `1` to begin Focus session (10 seconds).
5. In Windows Terminal:
   - Notice the tab title updates dynamically: `Pawmodoro - FOCUS 00:09` down to `00:00`.
   - Notice the taskbar icon displays a progressing green bar from 0% to 100%.
   - Press `P` to pause: notice the taskbar progress indicator immediately clears. Press `P` to resume.
6. When 00:00 is reached:
   - Terminal screen flashes reverse video for ~150 ms.
   - Bell sounds (if terminal audio bell enabled).
   - Window title displays `Pawmodoro - Time's up!`.
   - Taskbar progress bar clears.
   - Desktop notification appears (if on desktop with `notify-send` or WSL host).
7. Press `Q` to dismiss completion and return to menu:
   - Title resets to `Pawmodoro`.

---

## 7. Verification results

- **Build verified:** `nasm` assembled `src/main.asm` with zero warnings; statically linked with `ld -m elf_i386` into `build/pawmodoro`.
- **Memory budget verified:**
  - Binary format: ELF 32-bit LSB executable, Intel 80386, statically linked.
  - Section sizes: `.text` = 27,537 B, `.data` = 5,911 B, `.bss` = 62,392 B.
  - `.bss` usage of 62,392 B is well within the 81,920 B ceiling mandated by PRD V2 §12.
- **Automated tests verified:** `tests/smoke.sh` completed with all 22 scenarios passing.
- **Escape-sequence verified:** Automated tests verified that:
  - `ESC]0;Pawmodoro - FOCUS ...\x07` is emitted during countdown.
  - `ESC]0;Pawmodoro - Time's up!\x07` is emitted on completion.
  - `ESC]9;4;1;<percent>\x07` is emitted during countdown.
  - `ESC]9;4;0;0\x07` is emitted on pause, completion, and exit.
  - `ESC[?5h` and `ESC[?5l` are emitted on natural completion.
  - `ESC]0;Pawmodoro\x07` is emitted on exit.
  - When master `setting_notify == 0`, layers 2–5 are strictly suppressed.
- **Process-launch verified:** Generalized `proc_spawn` was exercised with asynchronous execution and verified to return cleanly without zombie processes or child terminal leakage.
- **Terminal restoration verified:** Tested under raw and cooked Ctrl+C, exit keys, and error paths. Cursor is visible, alternate screen is vacated, taskbar progress is cleared, and terminal modes are restored.

---

## 8. Known issues and limitations

1. **Terminal-Specific Sequences:**
   - Taskbar progress (`OSC 9;4`) is specific to Windows Terminal and compatible emulators. Standard xterm or Linux VT consoles ignore this sequence without error.
   - Screen flash (`ESC[?5h` / `ESC[?5l`) depends on terminal emulator implementation; modern VTE-based terminals may ignore DEC private mode 5.
2. **Desktop Notifiers in Headless / Minimal Environments:**
   - In containerized environments, minimal WSL distributions without GUI desktop integrations, or SSH sessions lacking DBus, `/usr/bin/notify-send` is absent. Pawmodoro detects this via `sys_access` and safely defaults to a silent no-op.
3. **WSL PowerShell Fallback:**
   - The PowerShell fallback requires WSL interop to be enabled (default in WSL2) and is designed as an experimental best-effort mechanism.
