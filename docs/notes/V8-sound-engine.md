# Task V8 Implementation Notes: Synthesized Sound Effects Engine

## 1. Architectural Overview & What Was Built

Task V8 adds a synthesized sound effects engine to Pawmodoro in 32-bit x86 NASM assembly for Linux (`int 0x80`), operating without libc, floating-point instructions (no FPU, MMX, SSE), or external audio libraries.

The audio engine consists of two tightly coupled layers:
1. **Integer PCM Synthesizer (`synth_note`):** Real-time integer-only software synthesizer generating unsigned 8-bit mono PCM audio at 11,025 Hz into a dedicated 32 KB buffer (`sfx_buf` in `.bss`).
2. **Process & Pipe Dispatcher (`sfx_play` and `sfx_init`):** Low-level process lifecycle dispatcher that streams synthesized PCM buffers to an external audio player (`/usr/bin/paplay` or `/usr/bin/aplay`) via direct Linux system calls (`sys_pipe`, `sys_fork`, `sys_dup2`, `sys_execve`), running asynchronously without stalling the 100 ms timer loop.

When external players are unavailable or audio hardware is absent (such as in headless or minimal WSL environments), `sfx_play` provides a clean terminal bell fallback (`0x07`) for important events, while remaining completely silent for noncritical actions.

---

## 2. Core Procedures & Contracts

### `sfx_init`
- **Location:** `src/sfx.asm`
- **Purpose:** Initializes sound subsystem at application startup.
- **Contract:**
  - **IN:** None.
  - **OUT:** Caches detected player in `sfx_player_choice` (`PLAYER_PAPLAY`, `PLAYER_APLAY`, or `PLAYER_NONE`).
  - **CLOBBERS:** None (preserves all general-purpose registers).
- **Operation:**
  1. Installs `SIG_IGN` (1) for `SIGPIPE` (13) and `SIGCHLD` (17) using `sys_signal` (syscall 48).
  2. Probes `/usr/bin/paplay` using `sys_access` (syscall 33, `X_OK = 1`). If executable, records `PLAYER_PAPLAY`.
  3. If absent or unexecutable, probes `/usr/bin/aplay` using `sys_access`. If executable, records `PLAYER_APLAY`.
  4. If neither player is executable, records `PLAYER_NONE`.
  5. Never exits, crashes, or prints error diagnostics during probing.

### `synth_note`
- **Location:** `src/sfx.asm`
- **Purpose:** Synthesizes a single musical note, glide segment, or rest into `sfx_buf`.
- **Contract:**
  - **IN:** `EAX` = Frequency in Hz (e.g. 440; 0 = rest/silence), `ECX` = Duration in milliseconds (e.g. 50, 100), `EDX` = Waveform ID (`WAVE_SQUARE = 0`, `WAVE_TRIANGLE = 1`, `WAVE_REST = 2`).
  - **OUT:** `EAX` = Valid sample count generated. Appends PCM samples to `sfx_buf + [sfx_buf_len]` and advances `[sfx_buf_len]`.
  - **CLOBBERS:** `EAX` (return value; preserves `EBX`, `ECX`, `EDX`, `ESI`, `EDI`).
- **Mathematical Design:**
  - **Sample Count:** $N = (\text{duration\_ms} \times 11025) / 1000$ using 32-bit unsigned integer division (`mul`/`div`). Clamped to remaining buffer capacity (`SFX_BUF_SIZE - sfx_buf_len`).
  - **Phase Accumulator:** 32-bit unsigned integer phase accumulator $\phi \in [0, 2^{32}-1]$. Phase increment per sample is derived via 64-bit integer division:
    $$\Delta\phi = \frac{\text{freq} \times 2^{32}}{11025}$$
    With frequencies clamped to 5500 Hz (below the 5512.5 Hz Nyquist frequency), the 64-bit dividend in `EDX:EAX` (`EDX = freq`, `EAX = 0`) divides by 11025 without 32-bit quotient overflow.
  - **Waveform Synthesis:**
    - *Square Wave (`WAVE_SQUARE`):* Tested against MSB (bit 31) of phase accumulator $\phi$. If bit 31 is 0, sample value is $+A(t)$; if bit 31 is 1, sample value is $-A(t)$.
    - *Triangle Wave (`WAVE_TRIANGLE`):* Derived from high 16 bits of phase ($H = \phi \gg 16 \in [0, 65535]$):
      $$v = \begin{cases} H - 16384 & \text{if } H < 32768 \text{ (rising half)} \\ 49152 - H & \text{if } H \ge 32768 \text{ (falling half)} \end{cases}$$
      Scaled by current amplitude: $\text{displacement} = (v \times A(t)) \gg 14$.
    - *Rest (`WAVE_REST`):* Displacement is forced to 0 ($A(t) = 0$).
  - **Linear Decay Envelope:**
    $$A(t) = \frac{A_{\max} \times (N - t)}{N}$$
    Smoothly tapers amplitude from $A_{\max}$ at $t = 0$ to 0 at $t = N - 1$, preventing pop or click artifacts at note boundaries.
  - **Volume Scaling:** $A_{\max}$ is mapped from `setting_volume` (0..3) using `sfx_volume_table`:
    - Volume 0: $A_{\max} = 0$ (digital silence: all samples = 128).
    - Volume 1: $A_{\max} = 30$ (subtle / quiet).
    - Volume 2: $A_{\max} = 65$ (standard / balanced).
    - Volume 3: $A_{\max} = 110$ (maximum headroom).
  - **PCM Centering & Clamping:**
    $$\text{sample} = 128 + \text{displacement}$$
    Clamped strictly to $[0, 255]$ before storage.

### `sfx_play`
- **Location:** `src/sfx.asm`
- **Purpose:** Public dispatch procedure mapping sound IDs to step sequences, assembling PCM buffers, and triggering asynchronous player processes or bell fallback.
- **Contract:**
  - **IN:** `EAX` = Sound Effect ID (`SFX_START_CHIRP` through `SFX_SHORT_MEOW`).
  - **OUT:** `EAX` = 0 on success/silent dispatch, -1 on syscall error.
  - **CLOBBERS:** `EAX` (preserves `EBX`, `ECX`, `EDX`, `ESI`, `EDI`).
- **Operation:**
  1. Validates ID range (1..8). If `setting_sound == 0` or `setting_volume == 0`, exits immediately with 0 (guaranteed silence).
  2. If `sfx_player_choice == PLAYER_NONE`:
     - Emits `0x07` (`\a`) to stdout for important events: `SFX_START_CHIRP` (1), `SFX_FOCUS_FANFARE` (4), `SFX_BREAK_CHIME` (5).
     - Returns silently with 0 for noncritical events (`SFX_CLICK`, `SFX_CHECKIN_SPARKLE`, `SFX_ERROR_BOOP`, `SFX_DELETE_BLIP`, `SFX_SHORT_MEOW`).
  3. If player is available:
     - Resets `sfx_buf_len = 0`.
     - Iterates through the step sequence in `sfx_table`, invoking `synth_note` for each step until sentinel `(0, 0, 0)`.
     - Invokes `sys_pipe` (syscall 42) to create pipe `sfx_pipe_fds`.
     - Invokes `sys_fork` (syscall 2).
     - **In Child (`EAX == 0`):**
       - Closes pipe write end.
       - Duplicates pipe read end to `FD_STDIN` (0) via `sys_dup2` (syscall 63).
       - Opens `/dev/null` (`O_WRONLY = 1`) and duplicates over `FD_STDOUT` (1) and `FD_STDERR` (2).
       - Closes spare descriptors.
       - Invokes `sys_execve` (syscall 11) with player path, argv array, and inherited `sfx_envp`.
       - On any failure: calls `sys_exit(127)` directly without touching terminal state.
     - **In Parent (`EAX > 0`):**
       - Closes pipe read end immediately.
       - Writes synthesized PCM payload (`sfx_buf`, `sfx_buf_len`) in a single `sys_write` (syscall 4).
       - Closes pipe write end immediately to deliver EOF.
       - Returns to caller without blocking or calling `waitpid`.

---

## 3. Sound Effects Sequence Table

All 8 requested sound effects are defined in `.data` step tables:

| ID | Constant | Name | Sequence Breakdown | Total Duration | Use Case |
|---|---|---|---|---|---|
| 1 | `SFX_START_CHIRP` | Start Chirp | 587 Hz (40 ms) → 880 Hz (60 ms), triangle wave | 100 ms (~1,102 samples) | Timer start hook (`timer_run`) |
| 2 | `SFX_CLICK` | Click | 1200 Hz (12 ms), square wave | 12 ms (~132 samples) | Journal note save success |
| 3 | `SFX_CHECKIN_SPARKLE` | Check-in Sparkle | C5 (523 Hz, 50 ms) → E5 (659 Hz, 50 ms) → G5 (784 Hz, 50 ms) → C6 (1046 Hz, 80 ms), triangle wave | 230 ms (~2,535 samples) | Habit daily check-in success |
| 4 | `SFX_FOCUS_FANFARE` | Focus Fanfare | G4 (80 ms) → C5 (80 ms) → E5 (80 ms) → G5 (120 ms) → Rest (30 ms) → E5 (60 ms) → G5 (200 ms) | 650 ms (~7,166 samples) | Natural focus session completion |
| 5 | `SFX_BREAK_CHIME` | Break Chime | E5 (659 Hz, 70 ms) → Rest (20 ms) → B5 (988 Hz, 140 ms) | 230 ms (~2,535 samples) | Natural break phase completion |
| 6 | `SFX_ERROR_BOOP` | Error Boop | 180 Hz (80 ms) → Rest (20 ms) → 140 Hz (120 ms), square wave | 220 ms (~2,425 samples) | Save/delete error paths |
| 7 | `SFX_DELETE_BLIP` | Delete Blip | A5 (880 Hz, 35 ms) → A4 (440 Hz, 45 ms) → A3 (220 Hz, 55 ms), square wave | 135 ms (~1,488 samples) | Journal entry deletion success |
| 8 | `SFX_SHORT_MEOW` | Short Meow | 13-step glide with vibrato: 450→520→620→740→850 Hz (glide up) → 880→840→890→830 Hz (vibrato peak) → 760→680→580→480 Hz (glide down) | 455 ms (~5,016 samples) | Cat interactive sound effect |

---

## 4. Signal Handling & Process Safety

1. **`SIGPIPE` (signal 13):**
   - Configured with `SIG_IGN` (1) via `sys_signal` in `sfx_init`.
   - If an external player exits before reading the full buffer, the parent's `sys_write` returns `-EPIPE` (-32) rather than raising a terminating signal.
2. **`SIGCHLD` (signal 17):**
   - Configured with `SIG_IGN` (1) via `sys_signal` in `sfx_init`.
   - Under Linux kernel semantics, ignoring `SIGCHLD` causes child processes to be automatically reaped upon termination without requiring `waitpid` or creating defunct zombie entries (`ps axo stat | grep Z` remains clean).
3. **No Terminal Corruption from Child:**
   - Child redirects standard output and standard error to `/dev/null`.
   - On `execve` failure, child exits with status 127 via `sys_exit(127)` directly without invoking `term_restore` or application cleanup.
4. **Buffer Lifetime & Reentrancy:**
   - Linux `sys_write` transfers memory synchronously into the kernel pipe buffer before returning. Once the single parent `write` completes, `sfx_buf` can safely be overwritten by subsequent `sfx_play` calls without race conditions.

---

## 5. Event Hooks Integration

One-line `sfx_play` calls were integrated at existing event boundaries:

- **`src/timer.asm`:**
  - Timer start (`timer_run` entry): `mov eax, SFX_START_CHIRP; call sfx_play`.
  - Natural focus completion (`.phase_natural_complete`): `mov eax, SFX_FOCUS_FANFARE; call sfx_play`.
  - Natural break completion (`.break_natural_complete`): `mov eax, SFX_BREAK_CHIME; call sfx_play`.
  - Quick note save success: `mov eax, SFX_CLICK; call sfx_play`.
  - Quick note save error: `mov eax, SFX_ERROR_BOOP; call sfx_play`.
  *(Unconditional terminal bells removed from completion routines in favor of managed `sfx_play` dispatch).*
- **`src/habits.asm`:**
  - Habit check-in success (`.chk_save_ok`): `mov eax, SFX_CHECKIN_SPARKLE; call sfx_play`.
  - Habit save error (`.chk_finish` failure path): `mov eax, SFX_ERROR_BOOP; call sfx_play`.
- **`src/journal.asm`:**
  - Journal entry save success (`journal_new_entry`): `mov eax, SFX_CLICK; call sfx_play`.
  - Journal entry save error: `mov eax, SFX_ERROR_BOOP; call sfx_play`.
  - Journal entry delete success (`journal_delete_prompt`): `mov eax, SFX_DELETE_BLIP; call sfx_play`.
  - Journal entry delete error: `mov eax, SFX_ERROR_BOOP; call sfx_play`.

---

## 6. Settings Integration

Sound configuration uses the existing 24-byte `settings.dat` structure from PRD v2 §5:
- **Offset 19:** `setting_sound` (`0` = Disabled, `1` = Enabled; default `0`).
- **Offset 23:** `setting_volume` (`0`..`3`; default `2`).

Both settings are managed in-memory and persisted via `src/settings.asm` and adjustable via the interactive Settings screen (`src/settings_ui.asm`). No changes to file format or offsets were made.

---

## 7. Memory Budget Verification

- Baseline `.bss` prior to Task V8: 29,592 bytes.
- Added in Task V8:
  - `sfx_envp`: 4 bytes
  - `sfx_player_choice`: 4 bytes
  - `sfx_pipe_fds`: 8 bytes
  - `sfx_buf_len`: 4 bytes
  - `sfx_buf`: 32,768 bytes
- New total `.bss`: **62,380 bytes**.
- Hard cap from PRD v2 §12: **81,920 bytes (80 KiB)**.
- Margin remaining: **19,540 bytes** headroom.

---

## 8. Verification & Test Commands

### Build & Warning Check
```bash
make clean && make 2>&1 | tee /tmp/pawmodoro-sfx-build.log
if grep -i 'warning:' /tmp/pawmodoro-sfx-build.log; then echo 'WARNINGS FOUND'; else echo 'NO WARNINGS FOUND'; fi
```

### Pure Integer Verification (No FPU/SSE/MMX)
```bash
objdump -d build/pawmodoro | grep -E '\bfld|\bfst|\bfadd|\bfsub|\bfmul|\bfdiv|\bxmm|\bymm|\bzmm' || echo 'CLEAN INTEGER ONLY'
```

### Process Cleanup & Zombie Check
```bash
ps -eo pid,ppid,stat,comm,args | grep -E '[p]aplay|[a]play' || echo 'NO PLAYERS'
ps axo stat | grep Z || echo 'ZERO ZOMBIES'
```

### Automated Regression Suite
```bash
bash tests/smoke.sh
```
*Result: 22 passed, 0 failed.*

---

## 9. Known Limitations

1. **External Player Availability:**
   - Pawmodoro relies on `/usr/bin/paplay` (PulseAudio) or `/usr/bin/aplay` (ALSA) to output sound to audio hardware. If neither is installed, audio gracefully degrades to the terminal bell (`0x07`) for important events only.
2. **WSL Audio Support:**
   - On Windows Subsystem for Linux (WSL), audio output through `paplay` requires WSLg (WSL2 with PulseAudio server forwarding) or a configured pulse socket over `XDG_RUNTIME_DIR`. In environments without audio servers, playback child processes exit silently without application disruption.
3. **Pipe Blocking Mitigation:**
   - The Linux pipe buffer capacity defaults to 65,536 bytes (64 KB). Because the maximum synthesized payload `sfx_buf` is strictly 32,768 bytes (32 KB), a single `sys_write` completes immediately into kernel memory without blocking the parent process or delaying the 100 ms countdown loop.
