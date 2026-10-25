# Developer Notes: Task V4 — Centralized 256-Color Theme Engine & Settings Persistence

## 1. Executive Summary

Task V4 establishes the foundation for centralized theming and persistent configuration in Pawmodoro (CAO10 Group 8 project, written in 32-bit x86 NASM assembly for Linux using direct `int 0x80` syscalls and no libc).

Prior to this task, UI colors were hard-coded throughout the screens using legacy direct 16-color ANSI escape sequences (`ansi_fg_*`). In V4, all color rendering across all screens has been migrated to an abstract 12-slot color palette model rendered via `ui_color` and `ui_bgcolor`. Seven distinct built-in themes plus custom theme support have been added, and a robust 24-byte binary persistence format (`settings.dat`) has been implemented to store user settings safely.

---

## 2. The Color-Slot Architecture

A **color slot** is an indirect semantic role (an index 0–11) rather than a fixed terminal color. Screen rendering procedures request colors by semantic meaning (such as "give me the title color" or "give me the border color"), and the theme engine maps that slot index to the concrete 256-color palette index defined in the currently active theme.

### The 12 Normative Color Slots

| Slot ID | Constant | Semantic Role | Screen Elements |
|---:|---|---|---|
| 0 | `SLOT_BORDER` | Borders & frames | Outer box frames (`+`, `-`, `\|`) and inner section dividers |
| 1 | `SLOT_TITLE` | Brand & screen titles | "PAWMODORO", "HABIT TRACKER", "JOURNAL", Phase titles |
| 2 | `SLOT_ACCENT` | Hints, badges, metrics | Key labels, `[DEMO]` badge, dashboard counters |
| 3 | `SLOT_TEXT` | Primary content | Timer countdown digits `MM:SS`, body text |
| 4 | `SLOT_DIM` | Secondary / inactive text | Empty state prompts, unchecked habits `[.]`, demo OFF |
| 5 | `SLOT_OK` | Positive / completed status | Checked habits `[#]`, demo ON, success status rows |
| 6 | `SLOT_WARN` | Warning / paused status | "PAUSED" indicator, info status rows, resize warning |
| 7 | `SLOT_ERR` | Error status | Save errors, deletion errors, failure status rows |
| 8 | `SLOT_CAT` | ASCII cat art | 3-line cat illustrations across all poses |
| 9 | `SLOT_BAR_FULL` | Progress bar filled | Filled `#` segments in Pomodoro progress bar |
| 10 | `SLOT_BAR_EMPTY` | Progress bar empty | Unfilled `-` segments in Pomodoro progress bar |
| 11 | `SLOT_HIGHLIGHT` | Selected row background | Journal list view selected entry row background |

---

## 3. Built-in Themes and Active Palette

Pawmodoro defines 7 built-in themes (indices 0–6) and a custom theme slot (index 7). Each built-in theme is defined as a contiguous 12-byte table in `src/data.asm`:

| Index | Theme Name | BORDER | TITLE | ACCENT | TEXT | DIM | OK | WARN | ERR | CAT | BAR_FULL | BAR_EMPTY | HIGHLIGHT |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | Strawberry Milk | 211 | 204 | 218 | 254 | 244 | 114 | 221 | 203 | 223 | 204 | 238 | 53 |
| 1 | Matcha Latte | 108 | 150 | 114 | 255 | 243 | 114 | 221 | 203 | 180 | 114 | 238 | 22 |
| 2 | Blueberry | 69 | 111 | 75 | 255 | 244 | 114 | 221 | 203 | 117 | 75 | 238 | 17 |
| 3 | Lavender Night | 141 | 183 | 147 | 253 | 243 | 114 | 221 | 203 | 225 | 141 | 237 | 54 |
| 4 | Sunset Peach | 215 | 209 | 216 | 255 | 244 | 114 | 221 | 203 | 223 | 209 | 238 | 94 |
| 5 | Mono Cozy | 245 | 255 | 250 | 252 | 240 | 250 | 255 | 255 | 252 | 255 | 238 | 240 |
| 6 | High Contrast | 231 | 231 | 226 | 231 | 250 | 46 | 226 | 196 | 231 | 231 | 240 | 21 |

### Theme Separation & Active Palette
- `active_palette` (12 bytes): The live color array that `ui_color` and `ui_bgcolor` read from on every render. Initialized to Strawberry Milk (Theme 0) so the application opens with its familiar warm aesthetic.
- `custom_palette` (12 bytes): The persisted custom color values from `settings.dat`. Selecting built-in themes 0–6 copies colors from `themes_table` to `active_palette` without overwriting `custom_palette`. Selecting theme 7 copies `custom_palette` to `active_palette`.

---

## 4. Theme Engine Implementation (`src/theme.asm`)

The theme engine exposes two core rendering procedures:
1. `ui_color`:
   - **IN:** `AL` = Slot ID (0–11).
   - **OUT:** Appends ANSI foreground sequence `ESC[38;5;Nm` to `out_buf`.
   - **CLOBBERS:** None (preserves all general-purpose registers and EFLAGS).
   - **Validation:** If `AL >= NUM_SLOTS` (12), silently returns without modifying `out_buf` or crashing.
2. `ui_bgcolor`:
   - **IN:** `AL` = Slot ID (0–11).
   - **OUT:** Appends ANSI background sequence `ESC[48;5;Nm` to `out_buf`.
   - **CLOBBERS:** None (preserves all general-purpose registers and EFLAGS).
   - **Validation:** If `AL >= NUM_SLOTS` (12), silently returns.

### Rendering Architecture
- Both procedures format the 0–255 color index dynamically using `buf_u32` and append directly to the existing memory buffer `out_buf`.
- No direct system calls (`sys_write`) are made inside `ui_color` or `ui_bgcolor`. The entire frame is flushed once at the end of the frame via `buf_flush`, strictly preserving the single-`sys_write`-per-frame requirement.

---

## 5. Settings Persistence Engine (`src/settings.asm`)

Settings are stored in the current working directory in a compact, fixed-size 24-byte little-endian binary file named `settings.dat`.

### Binary Layout

| Offset | Size | Type | Field Name | Valid Values | Default Value |
|---:|---:|---|---|---|---|
| 0 | 4 | dword | `magic` | Exact little-endian `0x53574150` ("PAWS") | `0x53574150` |
| 4 | 1 | byte | `version` | Must be `1` | `1` |
| 5 | 1 | byte | `theme` | `0`–`7` (0–6 built-in, 7 custom) | `0` (Strawberry Milk) |
| 6 | 12 | 12 bytes | `custom[0..11]` | Each byte `0`–`255` | Copy of Strawberry Milk palette |
| 18 | 1 | byte | `anim` | `0` (reduced motion) or `1` (animations ON) | `1` |
| 19 | 1 | byte | `sound` | `0` (OFF) or `1` (ON) | `0` |
| 20 | 1 | byte | `charset` | `0` (UTF-8) or `1` (ASCII) | `0` |
| 21 | 1 | byte | `notify` | `0` (OFF) or `1` (ON) | `0` |
| 22 | 1 | byte | `notify_layers`| Bitmask: only bits 0..4 permitted (`& ~0x1F == 0`)| `0x01` (bell only) |
| 23 | 1 | byte | `volume` | `0`–`3` | `2` (medium) |

### Validation & Fallback Rules
1. **Missing File:** On startup, if `settings.dat` does not exist, `settings_load` leaves defaults in place without displaying any error message.
2. **Truncated File (`size < 24`):** If fewer than 24 bytes are read, the file is rejected in full and complete defaults are retained.
3. **Bad Magic / Version:** If the magic dword is not `'PAWS'` or version != 1, all defaults are retained.
4. **Field Range Checking:** If any scalar field exceeds its valid range (theme > 7, boolean > 1, invalid notification bits, volume > 3), the entire record is rejected and complete defaults are retained. Partial settings are never applied.
5. **Save Failure Flag:** `settings_save_err` is set to 1 if in-memory settings fail validation or if `file_save` fails (e.g. read-only disk). It is cleared to 0 on a successful save.
6. **Safe Oversized File Detection:** `settings_load` requests 25 bytes (`SETTINGS_FILE_SIZE + 1`) into a 32-byte buffer. If the file contains 25 or more bytes, `file_load` returns 25 (or more), which does not equal 24, triggering complete fallback to defaults without modifying `src/file.asm`.

---

## 6. Summary of Changed Files

Only permitted files were created or modified:

1. `src/constants.inc`: Added 12 color slot constants (`SLOT_BORDER` .. `SLOT_HIGHLIGHT`), theme indices, settings layout offsets, validation masks, and `CHAR_LOWER_M`.
2. `src/data.asm`: Added 256-color escape prefixes (`ansi_fg_256_prefix`, `ansi_bg_256_prefix`), `themes_table` (84 bytes for 7 themes), theme names table, `active_palette`, `custom_palette`, setting variables, and `settings_buf` (32 bytes).
3. `src/theme.asm` (new): Implemented `ui_color` and `ui_bgcolor` with bounds checking and complete register/flags preservation.
4. `src/settings.asm` (new): Implemented `settings_set_defaults`, `settings_apply_palette`, `settings_load`, and `settings_save`.
5. `src/main.asm`: Included `src/theme.asm` and `src/settings.asm`, added `call settings_load` during initialization.
6. `src/ui.asm`: Replaced all legacy `ansi_fg_*` with semantic slot calls; added `SLOT_BORDER` to frame routines and `SLOT_BAR_FULL`/`SLOT_BAR_EMPTY` to `ui_progress_bar`.
7. `src/timer.asm`: Replaced legacy colors with `SLOT_TITLE`, `SLOT_ACCENT`, `SLOT_TEXT`, and `SLOT_WARN`.
8. `src/habits.asm`: Replaced legacy colors with `SLOT_TITLE`, `SLOT_DIM`, `SLOT_OK`, `SLOT_WARN`, and `SLOT_ERR`.
9. `src/journal.asm`: Replaced legacy colors with `SLOT_TITLE`, `SLOT_DIM`, `SLOT_OK`, `SLOT_WARN`, `SLOT_ERR`, and added `SLOT_HIGHLIGHT` background coloring for selected entries.
10. `docs/notes/v4-theme-engine.md` (this file): Architectural documentation and test procedures.

---

## 7. How to Build and Test

### Building
```bash
make clean
make
```

### Automated Smoke Tests
```bash
tests/smoke.sh
```

### Verifying Legacy Color Elimination
Verify that no `ansi_fg_` calls remain in the screen rendering modules:
```bash
grep -n 'ansi_fg_' src/ui.asm src/timer.asm src/habits.asm src/journal.asm src/main.asm
```
*(Must output 0 matches with exit status 1)*.

### Verifying Prohibited Instructions
Verify that no floating-point or SSE vector instructions were introduced:
```bash
grep -nE '\b(fld|fst|fadd|fsub|fmul|fdiv|movaps|movups|addps|subps|mulps|divps)\b' src/theme.asm src/settings.asm
```
*(Must output 0 matches with exit status 1)*.

---

## 8. Architectural Limitations & Decisions

1. **No-Libc Register Discipline:** All procedures strictly preserve general-purpose registers (`push`/`pop` of `eax`, `ebx`, `ecx`, `edx`, `esi`, `edi`) and flags (`pushf`/`popf`), ensuring zero side effects on calling code.
2. **256-Color Support Requirement:** The terminal must support standard xterm 256-color escapes (`ESC[38;5;Nm`). Truecolor (`38;2`) is deliberately omitted in conformance with the PRD memory and simplicity budget.
3. **Oversized File Detection:** `file_load` in `src/file.asm` reads up to `count` bytes using `sys_read`. By requesting `count = 25` into our 32-byte `settings_buf`, any file larger than 24 bytes returns a count $\ge 25$, allowing exact detection of oversized files up to buffer capacity without altering `src/file.asm`. Files significantly larger than the buffer capacity will still read at least 25 bytes and thus be rejected.
