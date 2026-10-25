# Task Note: V7 Animation Engine (`v7-animation`)

**Task ID:** `v7-animation`  
**Status:** Complete & Fully Verified  
**Date:** October 25, 2026  
**Course:** CAO10 — Computer Architecture and Organization (Group 8)  
**Binary:** 32-bit x86 ELF for Linux (`int 0x80`, pure integer assembly, no libc)

---

## 1. Executive Summary

Task V7 introduces a lightweight, non-blocking, event-driven animation engine to Pawmodoro without disturbing the core Pomodoro countdown, menu input loop, persistence formats, habit tracking, or terminal cleanup. Built entirely in 32-bit NASM assembly without floating-point instructions or libc, the engine delivers lively visual feedback—cat eye-blinking and tail-wagging, twinkling menu stars, an active theme title color wave, progress bar shimmer, rising break-time `zZ` garnish, natural focus completion confetti bursts, and habit check-in heart pops.

All animations strictly satisfy the single-`sys_write`-per-frame invariant and enforce an animation-specific ceiling of at most **5 writes per second** (flush throttled to at least 200 ms). When Reduce motion is enabled (`setting_anim == 0`) or the terminal size gate (< 80×24) is active, animation simulation and rendering are completely suspended, producing **zero idle writes** and keeping idle CPU utilization well below 1.0%.

---

## 2. Architecture & Design

### 2.1 10 Hz Non-blocking Timing & Integration
The animation engine is clocked by the application's existing 100 ms cadence (`time_sleep_100ms`). It introduces no busy-wait loops or independent sleep routines:
- **Menu Loop (`src/main.asm`):** `anim_tick` is called on each 100 ms wait iteration in `.wait_for_input`.
- **Timer Loop (`src/timer.asm`):** `anim_tick` is called on each 100 ms tick in `.tick_loop` and during the completion decision wait loops.
- **Habits Loop (`src/habits.asm`):** `anim_tick` is called in `.habits_wait_key` to advance and render active heart-pop particles.

### 2.2 32-bit Integer-Only LCG Pseudo-Random Generator
Random particle generation (confetti velocities, spawn positions, glyphs, and star twinkles) relies on an integer Linear Congruential Generator (LCG) implementing the standard modulo-$2^{32}$ recurrence:

$$\text{state}_{n+1} = (\text{state}_n \times 1664525 + 1013904223) \pmod{2^{32}}$$

- **Constants:** `ANIM_PRNG_MULT = 1664525`, `ANIM_PRNG_INC = 1013904223`.
- **Instruction Choice:** Standard x86 32-bit unsigned `MUL EDX` multiplies `EAX` by `ANIM_PRNG_MULT`, producing a 64-bit product in `EDX:EAX`. The high 32 bits in `EDX` are naturally discarded by subsequent addition, automatically executing the modulo-$2^{32}$ truncation in pure integer hardware without division or FPU instructions.
- **Degeneracy Guard:** If the resulting seed becomes zero, it resets to `ANIM_PRNG_FALLBACK_SEED` (`0x12345678`).
- **Seeding:** Seeded once at startup via `time_now` (Unix epoch time). If `time_now` fails or returns non-positive, the fallback seed is used.

### 2.3 Partial-Region Redraw Model & Single-Write Guarantee
Animations never clear or repaint the entire 80×24 screen on each tick. Instead, independent partial renderers append ANSI cursor movements (`ui_goto`) and colored glyphs directly into the shared output buffer (`out_buf`):
- `anim_draw_cat_region`: Emits lines 1–3 of the cat art at `(cat_row, cat_col)`.
- `anim_draw_title_region`: Emits the 17-character menu title with cyclic theme colors and 2 star garnishes.
- `anim_draw_progress_region`: Overlays a moving highlight shimmer across the 30-cell progress bar at Row 7, Col 5.
- `anim_draw_particles_region`: Erases old particle positions with spaces (`' '`) and renders updated coordinates for confetti, heart pop, and break `zZ`.

All dirty partial regions are composed into `out_buf` without intermediate flushes. `anim_render_dirty` flushes the aggregated buffer with **exactly one `sys_write`** (`int 0x80` with `EAX=4`), preserving the project's single-write-per-frame architectural invariant.

### 2.4 Performance Limits & Write-Rate Ceiling
The animation engine enforces strict performance limits:
- **Ceiling:** At most 5 animation-driven `sys_write` calls per second.
- **Mechanism:** `anim_throttle_count` increments on each 100 ms tick. `anim_render_dirty` only flushes if `anim_dirty_flags != 0` AND `anim_throttle_count >= ANIM_THROTTLE_TICKS` (where `ANIM_THROTTLE_TICKS = 2`, representing 200 ms).
- **Idle Suppression:** If no visual effect changes, no regions are flagged dirty and no write is issued.
- **Reduce Motion:** When `setting_anim == 0`, `anim_tick` and `anim_render_dirty` exit immediately on Gate 1. In an idle menu or timer, zero writes occur over arbitrary durations.
- **CPU Utilization:** Measured below 0.8% in `top`/`ps` under active animation.

---

## 3. Visual Effects Implementation Details

### A. Cat Blink & Tail Wag
- **Eye Blink:** In the main menu, cat eyes normally display `( o.o )`. Every 30 ticks (3.0 seconds), eyes close to `( -.- )` for 2 ticks (200 ms), then reopen. In timer focus mode, the cat remains focused `( -.- )`.
- **Tail Wag:** Line 3 of the cat cycles across three distinct 7-character poses (`cat_tail_0`, `cat_tail_1`, `cat_tail_2`): `" > ^ < "`, `" > ^ <~"`, and `"~> ^ < "` every 3 ticks (300 ms). Overwriting exactly 7 characters guarantees no stray artifacts on the terminal.
- **Restoration:** Canonical static cat art is restored immediately when leaving screens or entering Reduce motion.

### B. Rising Break-Time `zZ` Garnish
- During Short and Long breaks (`phase != PHASE_FOCUS`), a floating `zZ` garnish rises above the sleeping cat art:
  - Phase 0: `"z"` at (Row 4, Col 17) in `SLOT_DIM`.
  - Phase 1: `"Z"` at (Row 3, Col 18) in `SLOT_ACCENT`.
  - Phase 2: `"zZ"` at (Row 2, Col 19) in `SLOT_TITLE`.
  - Phases 3–4: Inactive delay / spaces.
- Old positions are cleanly erased with spaces (`"  "`), keeping all coordinates within safe bounds.

### C. Progress Bar Shimmer
- During active countdown, `anim_shimmer_pos` traverses the filled portion of the 30-cell bar.
- The active shimmer segment renders in `SLOT_ACCENT` (or `✦` / `*`), while normal segments render in `SLOT_BAR_FULL` (`▰` / `#`).
- Shimmer position advances every 2 ticks (200 ms) and wraps around to 0 upon reaching the filled boundary.
- All countdown mathematics, duration tracking, and percentage calculations remain 100% unaltered.

### D. Menu Title Color Wave
- The 17-character title `"P A W M O D O R O"` cycles across four active theme slots (`SLOT_TITLE`, `SLOT_ACCENT`, `SLOT_CAT`, `SLOT_TEXT`).
- `anim_title_wave_offset` advances every 2 ticks (200 ms).
- Respects the 256-color convention and dynamic custom palettes; zero hard-coded ANSI colors.

### E. Twinkling Menu Stars
- Two star garnishes are positioned at safe, unallocated coordinates on the menu title row: Star 1 at (Row 2, Col 12) and Star 2 at (Row 2, Col 32).
- Twinkle state cycles every 4 ticks (400 ms) between bright (`SLOT_ACCENT` / `✦`), dim (`SLOT_DIM` / `★`), and hidden (`' '`).
- Erased to `' '` when entering static or Reduce motion mode.

### F. Confetti Particle Simulation (Natural Focus Complete)
- Triggered exclusively on natural focus completion (countdown reaching 0), not on pause, skip, or stop.
- Simulates 20 compact particles (`CONFETTI_MAX = 20`, 40 bytes per struct) with integer kinematics:
  - Spawned at Rows 3..5, Cols 12..57.
  - Horizontal velocity $V_X \in \{-1, 0, 1\}$.
  - Initial upward velocity $V_Y = -1$.
  - Gravity simulation: Every 2 ticks, $V_Y$ increments downward up to terminal velocity $+2$.
  - Bounded coordinates: Automatically retired if crossing Row 2, Row 9, or terminal frame edges.
  - Old coordinates are erased with spaces (`' '`) before new glyphs are drawn.

### G. Heart-Pop Effect (Successful Habit Check-In)
- Triggered exclusively in `habits_check_in` after `habits_save` succeeds.
- Spawns a floating heart (`GLYPH_HEART`: `♥` in UTF-8, `v` in ASCII) at (Row $5 + \text{habit\_index}$, Col $\text{ui\_w} - 38$).
- Floats upward by 1 row every 2 ticks over a 6-tick (600 ms) lifetime.
- Erases previous position cleanly and self-retires.

---

## 4. State Interactions & Boundary Safety

1. **Reduce Motion (`setting_anim == 0`):**
   - Read from `settings.dat` offset 18 (`setting_anim`).
   - `anim_tick` and `anim_render_dirty` immediately exit.
   - Frame counters do not advance.
   - Idle screen emits 0 writes.
   - Static visual presentation restored immediately.

2. **Timer Pause:**
   - When `paused == 1`, countdown is frozen.
   - `anim_tick` detects `paused == 1` and skips timer animation ticks. Cat tail, shimmer, and garnish freeze in place.
   - Key polling and application responsiveness remain instant (<= 100 ms).
   - Resuming unfreezes countdown and animation simultaneously.

3. **Terminal Size Gate (< 80×24):**
   - When `term_size_ok` returns 0, `anim_tick` and `anim_render_dirty` immediately return.
   - No particles are simulated or drawn while the enlargement message is displayed.

4. **Screen Transitions:**
   - Navigating between screens calls `anim_reset_effects`, deactivating active particles and resetting transient states.
   - Next screen's initial full-frame render wipes the screen cleanly.

---

## 5. Procedure Contracts (`src/anim.asm`)

All procedures adhere to PRD §6.2: registers are saved and restored using `save_regs` / `restore_regs` or explicit pushes, keeping the stack balanced on all paths.

| Procedure | IN | OUT | CLOBBERS | Purpose |
|---|---|---|---|---|
| `anim_init` | None | None | None | Seeds LCG PRNG via `time_now` (or fallback) and zeroes counters |
| `anim_rand` | None | `EAX` = 32-bit pseudo-random value | `EAX` | Computes next LCG value using 32-bit `MUL` with modulo $2^{32}$ |
| `anim_reset_effects` | None | None | None | Resets transient effect states and deactivates particles |
| `anim_on_focus_complete`| None | None | None | Initializes 20 confetti particles for natural focus completion |
| `anim_on_habit_checkin` | `EAX` = 0-based habit index (0..7) | None | None | Initializes heart-pop particle near checked-in habit row |
| `anim_draw_cat_region` | Implicit: `cat_row`, `cat_col`, blink/tail states | Appends to `out_buf` | None | Renders 3-line ASCII cat art with animated eyes and tail |
| `anim_draw_title_region` | Implicit: theme, wave offset, star state | Appends to `out_buf` | None | Renders menu title color wave and twinkling star garnishes |
| `anim_draw_progress_region`| Implicit: `total_secs`, `remaining_secs`, `shimmer_pos` | Appends to `out_buf` | None | Overlays moving shimmer highlight across 30-cell progress bar |
| `anim_draw_particles_region`| Implicit: confetti, heart-pop, break zZ | Appends to `out_buf` | None | Erases old positions and draws active simulation particles |
| `anim_render_dirty` | Implicit: `anim_dirty_flags`, `anim_throttle_count` | Appends & flushes `out_buf` | None | Coalesces dirty regions and flushes with one `sys_write` (<= 5 fps) |
| `anim_tick` | None | None | None | 10 Hz non-blocking clock advancing frame state and scheduling flushes |

---

## 6. Verification Results

### 6.1 Automated Smoke Tests (`tests/smoke.sh`)
```bash
./tests/smoke.sh
```
- **Result:** 21 passed, 0 failed.
- **Scenario 21 Verification:** Validates that active menu animation emits at most 5 writes/second (verified via timestamped `strace` log) and that toggling Reduce Motion (`anim=0`) yields exactly 0 writes while idle.

### 6.2 Extended 4-Session Cycle (`tests/smoke.sh --full`)
```bash
./tests/smoke.sh --full
```
- **Result:** Extended 4-session cycle completed successfully without timing drift, state corruption, or hangs.

### 6.3 Performance & Syscall Profiling
- **Syscall Frequency:**
  ```bash
  strace -f -tt -e trace=write -o /tmp/anim.log ./build/pawmodoro
  ```
  Measured write timestamps: exactly 5 writes per second while active in menu and timer.
- **Idle CPU Usage:**
  ```bash
  ps -o %cpu,cmd -C pawmodoro
  ```
  Measured: `0.8% CPU` utilization, well within the 1.0% limit.
- **ASCII Fallback Purity:**
  In `setting_charset = 1`, animation uses `#`, `-`, `*`, `v`, and ASCII cat tails. Scenario 19 confirms zero bytes $\ge 0x80$ across all screens.
- **Terminal Safety:**
  Ctrl+C during menu animation, timer countdown, confetti burst, or heart pop exits cleanly and restores cursor, echo, and alternate screen.

---

## 7. Known Issues & Limitations

1. **Terminal Scheduling Jitter under Virtualization:** On heavily loaded WSL2 or VM environments, `sys_nanosleep(100ms)` may occasionally see ±15 ms of scheduling jitter. The throttle logic (`anim_throttle_count >= 2`) accommodates this by ensuring flushes never occur faster than every 200 ms.
2. **Double-width Ambiguous Characters in CJK Locales:** As noted in PRD_V2 §3, glyphs like `★` and `♥` may occupy 2 columns in CJK terminals. In such environments, switching to ASCII mode (`setting_charset = 1`) emits single-column `*` and `v`, resolving any alignment differences.
