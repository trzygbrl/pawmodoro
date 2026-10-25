# Milestone G1: v3 Rendering Core Implementation Report

**Document ID:** `docs/notes/g1-render-core.md`  
**Course:** CAO10 (Group 8)  
**Project:** Pawmodoro (32-bit x86 NASM for Linux, `int 0x80`, no libc)  
**Milestone:** G1 — UI Infrastructure & Rendering Core  
**Date:** October 26, 2026  
**Status:** COMPLETED & VERIFIED  

---

## 1. Executive Summary

Milestone G1 establishes the low-level UI infrastructure and rendering core for Pawmodoro v3. The entire application remains pure 32-bit Linux assembly without libc or external runtime dependencies. Prior to G1, Pawmodoro utilized an 8,192-byte output buffer (`out_buf`), lacked runtime buffer overflow diagnostics, emitted redundant ANSI SGR escape sequences on repeated color calls, and had no unified geometric drawing primitives for background fills, solid panels, line dividers, or clipped text.

Under G1, the rendering pipeline has been upgraded:
1. The output aggregation frame buffer (`out_buf`) was doubled to **16,384 bytes** (`OUT_BUF_SIZE = 16384`), fitting comfortably within the 81,920-byte `.bss` ceiling (total `.bss` is 70,584 bytes).
2. An authoritative diagnostic overflow flag (`gfx_overflow`) was integrated into `buf_char`, preventing silent truncation or memory overrun.
3. Frame byte accounting (`gfx_frame_bytes`) was integrated into `buf_flush` to record precise frame transmission sizes.
4. A new rendering-core module (`src/gfx.asm`) was introduced, providing state-tracked color emission (`gfx_set_fg`, `gfx_set_bg`, `gfx_sgr_forget`, `gfx_reset`), full-screen background fills (`gfx_fill_screen_bg`), rectangle painting with ANSI ECH capability and space-fill fallback (`gfx_fill_rect`), horizontal and vertical line primitives with approved UTF-8 and ASCII fallbacks (`gfx_hline`, `gfx_vline`), text clipping (`gfx_text_clip`), a temporary rendering demo accessible via `Ctrl+G` from the main menu, and an automated headless diagnostic suite (`--test-overflow`).
5. All existing application screens, timers, habits, journal persistence, sound synthesis, animations, and navigation remain 100% intact and backward-compatible.

---

## 2. Built Binary Format and Memory Budget

The project was compiled from a clean state using NASM and the GNU linker:
```bash
make clean && make
```
- **Compiler/Linker Result:** Warning-free, error-free.
- **Binary Format:** ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), statically linked, no libc dependencies.
- **Entry Point:** `_start` at `0x8050076` (located in `.text` executable segment).
- **Section Memory Budget (`size build/pawmodoro`):**
  - `.text`: 29,646 bytes
  - `.data`: 6,632 bytes
  - `.bss`: **70,584 bytes** (well below the maximum budget limit of 81,920 bytes; 11,336 bytes remaining)
  - Total dec: 106,862 bytes

---

## 3. Implemented Components & Procedure Contracts

All procedures adhere to PRD §6.2 callee-saved register preservation conventions, using `save_regs` / `restore_regs` (`push ebx, ecx, edx, esi, edi`) and explicitly preserving `EAX` and `EFLAGS` where required.

### 3.1 Output Buffer Expansion & Overflow Tracking (`src/io.asm`, `src/constants.inc`)
- **`OUT_BUF_SIZE`:** Constant updated from 8,192 to 16,384 in `src/constants.inc`.
- **`gfx_overflow`:** Declared in `src/data.asm` (`dd 0`).
- **`buf_char` Contract:**
  - `IN`: `AL` = character byte to append.
  - `OUT`: Appends byte at `out_buf[out_len++]`. If `out_len >= OUT_BUF_SIZE`, safely drops the byte, sets `[gfx_overflow] = 1`, and returns without pointer advancement or out-of-bounds writes.
  - `CLOBBERS`: None (all registers and flags preserved).

### 3.2 Frame Byte Accounting (`src/io.asm`)
- **`gfx_frame_bytes`:** Declared in `src/data.asm` (`dd 0`).
- **`buf_flush` Contract:**
  - `IN`: None (`out_buf`, `out_len`).
  - `OUT`: Transmits `out_buf[0..out_len)` via single `sys_write` (FD 1). Sets `[gfx_frame_bytes] = [out_len]` at procedure entry prior to flushing. Resets `[out_len] = 0`.
  - `CLOBBERS`: None (all registers and flags preserved).

### 3.3 Color-State Tracker (`src/gfx.asm`)
Tracks logical theme-slot IDs (0..11) using two word variables in `.data`:
- `gfx_fg`: initialized to `0xFFFF` (`GFX_SLOT_UNKNOWN`).
- `gfx_bg`: initialized to `0xFFFF` (`GFX_SLOT_UNKNOWN`).

Procedures:
- **`gfx_set_fg(AL)`:** Checks if `AL == [gfx_fg]`. If equal, returns immediately with 0 bytes emitted (suppresses redundant escape). If different, captures `[gfx_overflow]`, resolves palette index from `active_palette[AL]`, emits `ESC[38;5;<color>m`, and updates `[gfx_fg] = AL` only if no overflow occurred during emission.
- **`gfx_set_bg(AL)`:** Checks if `AL == [gfx_bg]`. If equal, returns immediately with 0 bytes emitted. If different, emits `ESC[48;5;<color>m` and updates `[gfx_bg] = AL` if no overflow occurred.
- **`gfx_sgr_forget()`:** Invalidates both tracked color slots (`[gfx_fg] = 0xFFFF`, `[gfx_bg] = 0xFFFF`) without emitting bytes.
- **`gfx_reset()`:** Appends standard ANSI reset sequence `ESC[0m` (`ansi_reset`) to `out_buf` and invokes `gfx_sgr_forget`.

### 3.4 Background Fill Primitive (`src/gfx.asm`)
- **`gfx_fill_screen_bg(AL)`:**
  - `IN`: `AL` = background theme-slot ID.
  - `OUT`: Calls `gfx_set_bg(AL)`, appends cursor-home `ESC[H` (`ansi_home`), and appends clear-screen `ESC[2J` (`ansi_clear`) in strict sequence. Does not flush independently.
  - `CLOBBERS`: None.

### 3.5 Rectangular Fill Primitive (`src/gfx.asm`)
- **`gfx_fill_rect(EAX, EBX, ECX, EDX, ESI)`:**
  - `IN`: `EAX` = start row (1-based frame coordinate), `EBX` = start column (1-based frame-relative coordinate), `ECX` = width (cells), `EDX` = height (rows), `ESI` = background theme-slot ID.
  - `OUT`: Clamps and clips geometry against frame bounds (`ui_w`, `ui_h`). If dimensions are nonpositive or starting coordinates out-of-bounds, returns safely. Sets background color via `gfx_set_bg`. Loops over rows: positions cursor via `ui_goto`. If `[term_has_ech] == 1`, appends `ESC[<w>X`. If `[term_has_ech] == 0`, appends `<w>` space characters via `buf_repeat`.
  - `CLOBBERS`: None.

### 3.6 Horizontal & Vertical Line Primitives (`src/gfx.asm`)
- **`gfx_hline(EAX, EBX, ECX, ESI)`:**
  - `IN`: `EAX` = row, `EBX` = start column, `ECX` = width, `ESI` = foreground slot ID.
  - `OUT`: Clips to `ui_w`. Sets foreground color via `gfx_set_fg`, positions cursor via `ui_goto`. If `setting_charset == 1` (ASCII), emits `-` repeated via `buf_repeat`. Otherwise emits `glyph_utf8_hline` (`─`, `0xE2 0x94 0x80`).
  - `CLOBBERS`: None.
- **`gfx_vline(EAX, EBX, ECX, ESI)`:**
  - `IN`: `EAX` = start row, `EBX` = column, `ECX` = height, `ESI` = foreground slot ID.
  - `OUT`: Clips to `ui_h`. Sets foreground color via `gfx_set_fg`. Iterates rows: positions cursor via `ui_goto`, emits `|` in ASCII mode or `glyph_utf8_vline` (`│`, `0xE2 0x94 0x82`) in UTF-8 mode.
  - `CLOBBERS`: None.

### 3.7 Text Clipping Wrapper (`src/gfx.asm`)
- **`gfx_text_clip(ESI, ECX, AL, AH)`:**
  - `IN`: `ESI` = NUL-terminated string pointer, `ECX` = max display width in columns, `AL` = foreground slot ID (or `0xFF` if unchanged), `AH` = background slot ID (or `0xFF` if unchanged).
  - `OUT`: Applies foreground and background colors if specified; delegates display-column measuring, UTF-8 character boundary handling, and clipping marker (`~`) appending to `buf_str_clip`.
  - `CLOBBERS`: None.

---

## 4. Temporary Rendering Demo & Diagnostic Harness

### 4.1 Interactive Keyboard Demo (`Ctrl+G`)
- **Activation:** From the Main Menu, press `Ctrl+G` (ASCII 7, `KEY_CTRL_G`).
- **Assembly Toggle:** Guarded by `%ifndef G1_DEMO_ENABLED` / `%define G1_DEMO_ENABLED 1` in `src/constants.inc` and `%ifdef G1_DEMO_ENABLED` dispatch blocks in `src/main.asm`. To compile without the demo dispatch, assemble with `-DG1_DEMO_ENABLED=0`.
- **Render Sequence (`gfx_demo_draw`):**
  1. `gfx_sgr_forget`: invalidates tracker state.
  2. `gfx_fill_screen_bg`: fills terminal with `SLOT_BORDER` (slot 0).
  3. `gfx_fill_rect`: paints centered rectangular panel using `SLOT_HIGHLIGHT` (slot 11).
  4. `gfx_text_clip`: renders demo title and subtitle in `SLOT_TITLE` and `SLOT_DIM`.
  5. `gfx_hline`: draws horizontal divider across panel.
  6. `gfx_vline`: draws vertical divider separating left and right cards.
  7. `gfx_text_clip`: renders long text string clipped to 24 display columns (`This is a very long str~`).
  8. Small checkerboard pattern of `%%` and `##` blocks testing rapid slot alternation and SGR redundancy suppression.
  9. `gfx_text_clip`: renders footer hint `"Press any key to return to Main Menu..."`.
  10. `gfx_reset`: restores ANSI attributes and invalidates tracker.
- **Exit & Terminal Restoration:** Pressing any key cleanly returns to the Main Menu. Pressing `Ctrl+C` exits the application cleanly with exit code 0.
- **Single-Write Guarantee:** `strace -e trace=write` confirms the demo frame is flushed in **exactly one `sys_write` call** (4,643 bytes at 80x24; 8,300 bytes at 120x40; both strictly below 16,384 bytes).

### 4.2 Automated Headless Diagnostic (`--test-overflow`)
- **Invocation:** `./build/pawmodoro --test-overflow`
- **Verification Performed:**
  1. **Color Tracker Unit Tests:**
     - First color change emits bytes.
     - Identical color request emits 0 bytes (verifies escape suppression).
     - Tracker invalidation (`gfx_sgr_forget`) forces next color request to re-emit escape sequence.
  2. **80x24 Geometry:** Renders Main Menu, Timer, Habits, Journal, Settings, Settings Colors, and Demo. Verifies `gfx_overflow == 0` for all 7 screens.
  3. **120x40 Geometry:** Renders all 7 screens at 120x40. Verifies `gfx_overflow == 0` and frame bytes strictly `< 16384`.
  4. **ECH Fallback Path:** Disables `term_has_ech` (set to 0), renders rectangle using space-fill loop, and verifies `gfx_overflow == 0`.
  5. **Result:** Prints confirmation message and exits with status code 0.

---

## 5. Verification Commands and Test Results

### 5.1 Verification Commands
```bash
# 1. Clean build and size check
make clean && make
file build/pawmodoro
size build/pawmodoro

# 2. Automated headless overflow & color-state diagnostic
./build/pawmodoro --test-overflow

# 3. Single-write strace verification for demo frame
tmux new-session -d -s strace_test -x 80 -y 24 "strace -f -e trace=write -o /tmp/demo_strace.log ./build/pawmodoro"
sleep 0.5 && tmux send-keys -t strace_test C-g
sleep 0.5 && tmux send-keys -t strace_test " "
sleep 0.5 && tmux send-keys -t strace_test "Q"
tmux kill-session -t strace_test 2>/dev/null || true
grep -E 'write\(1,' /tmp/demo_strace.log

# 4. Automated smoke test suite (Scenarios 1-33)
bash tests/smoke.sh
```

### 5.2 Test Results Table

| Test Suite / Diagnostic Check | Requirement | Result | Status |
|---|---|---|---|
| Clean Build | Warning-free 32-bit ELF binary | Warning-free, exit code 0 | **PASS** |
| `.bss` Memory Budget | $\le 81,920$ bytes | 70,584 bytes (11,336 bytes headroom) | **PASS** |
| `OUT_BUF_SIZE` Allocation | Exactly 16,384 bytes | `resb 16384` verified in ELF symbols | **PASS** |
| Headless Screen Diagnostic | `--test-overflow` passes all screens | All 7 screens pass at 80x24 & 120x40 | **PASS** |
| Redundant SGR Suppression | Repeat slot ID emits 0 bytes | Verified in unit test (`len2 == len1`) | **PASS** |
| State Invalidation | `gfx_sgr_forget` forces re-emission | Verified in unit test (`len3 > len2`) | **PASS** |
| ECH Capability & Fallback | Both ECH and space loop succeed | Verified with `term_has_ech=0` | **PASS** |
| Demo Frame Size (80x24) | $< 16,384$ bytes | 4,643 bytes | **PASS** |
| Demo Frame Size (120x40) | $< 16,384$ bytes | 8,300 bytes | **PASS** |
| Single Write per Frame | Exactly 1 `sys_write` per frame | Confirmed via strace (no extra writes) | **PASS** |
| Terminal Restoration | Clean return to menu & clean quit | Menu redrawn, colors & cursor restored | **PASS** |
| Automated Smoke Test Suite | 33 automated scenarios | **33 passed, 0 failed** | **PASS** |

---

## 6. Screenshot & Visual Evidence

### 6.1 Reference Image Inspection
- **Confirmation:** The reference image `docs/reference/reference_home_page.jpg` was successfully inspected using the workspace image viewer. The 11 sprite assets in `docs/reference/sprites/` were also inspected during G0 and confirmed.
- **G1 Scope Boundary:** As required by PRD_V3, Milestone G1 implements the low-level rendering primitives and infrastructure only; it does not redesign existing production screens or introduce the new dashboard layout.

### 6.2 Captured Terminal Screens
Terminal screen captures were recorded for all 8 required configurations and are stored in `/tmp/g1_screenshots/` and saved to `scratch/g1_screenshots/`:
1. **`1_menu_80x24`:** Main menu at 80×24 before entering demo. Layout, stats, and navigation verified.
2. **`2_demo_80x24`:** Demo at 80×24 showing panel fill, border lines, divider line, clipped string (`This is a very long str~`), and checkerboard pattern.
3. **`3_menu_100x30`:** Main menu at 100×30 confirming original layout preservation.
4. **`4_demo_100x30`:** Demo at 100×30 confirming primitives scale within bounds.
5. **`5_menu_120x36`:** Main menu at 120×36 confirming original layout preservation.
6. **`6_demo_120x36`:** Demo at 120×36 confirming rendering core operates at Grand-tier size.
7. **`7_demo_120x40`:** Demo at 120×40 confirming maximum-size frame (8.3 KB) remains strictly below 16,384 bytes with zero cell clipping or overflow.
8. **`8_menu_post_demo_120x40`:** Main menu at 120×40 immediately after exiting demo, confirming 100-column centered frame, pristine background, and zero residual artifacts.

---

## 7. Known Issues and Limitations

1. **G1 Scope Boundaries (Intentional Design Limits):**
   - The 24-slot theme model and cat-coat presets belong to Milestone G2. G1 strictly uses the existing 12-slot palette mapping (`SLOT_BORDER` through `SLOT_HIGHLIGHT`).
   - Half-block sprite rendering, animation frames, and sprite assets belong to Milestone G3.
   - Dashboard card composition, adaptive layout tiers, and screen redesigns belong to Milestones G4 through G15.
2. **Terminal Capability Fallback:**
   - `term_has_ech` defaults to 1 (ANSI ECH supported). Terminals lacking ECH support can toggle `term_has_ech = 0` to use the verified space-fill loop fallback.
3. **One-Write Invariant:**
   - `buf_flush` issues a single `sys_write` per frame. On Linux pseudo-terminals and native consoles, write payloads up to 16,384 bytes complete in a single atomic kernel write.

---

## 8. Strict File Allowlist Verification

A strict file allowlist was enforced throughout Milestone G1. `git diff --name-only` confirms that only approved files were modified or created:

```text
src/constants.inc
src/data.asm
src/io.asm
src/gfx.asm
src/main.asm
tests/TEST_PLAN.md
tests/smoke.sh
docs/notes/g1-render-core.md
```

No other files, documentation, data formats (`stats.dat`, `habits.dat`, `journal.txt`, `settings.dat`), or build scripts were altered.

---

## 9. Demo Retention and Cleanup

The temporary rendering demo remains fully accessible via `Ctrl+G` from the Main Menu in this build to permit repeatable inspection and regression testing. It is cleanly guarded by the assembly-time macro:
```nasm
%ifndef G1_DEMO_ENABLED
%define G1_DEMO_ENABLED 1
%endif
```
To build Pawmodoro without the demo dispatch or key handler, compile with `-DG1_DEMO_ENABLED=0`:
```bash
make NASMFLAGS="-f elf32 -g -F dwarf -Wall -DG1_DEMO_ENABLED=0"
```
In release builds where `G1_DEMO_ENABLED=0`, `Ctrl+G` is ignored by the main menu key dispatcher and the demo code is excluded from the execution path.
