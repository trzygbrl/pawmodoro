# V2 Adaptive Layout Implementation Note

**Course & Project:** Computer Architecture and Organization (CAO10) — Pawmodoro  
**Author:** Engineering Team  
**Audience:** Undergraduate Computer Science Students  
**Topic:** Transitioning from Fixed 56-Column UI to Runtime-Adaptive Layout in x86 Assembly (Linux 32-bit `int 0x80`)

---

## 1. Overview & Objective

In version 1 (V1) of Pawmodoro, the terminal user interface was rendered with a hard-coded width of 56 columns anchored at the top-left of the terminal. As terminals vary widely in size (standard 80×24, modern 100×30, or widescreen 120×40), fixed geometry wasted screen space, crowded tabular habit data, and clipped habit names to a narrow 12 characters.

This V2 update introduces a **runtime-adaptive layout engine** written entirely in pure NASM x86 32-bit assembly without libc or external libraries. The new engine:
- Adapts frame width dynamically from 78 to 100 columns based on terminal size.
- Horizontally centers the frame within the physical terminal.
- Replaces absolute terminal cursor positions with frame-relative coordinates (`ui_goto`).
- Introduces safe UTF-8-aware string clipping (`buf_str_clip`).
- Expands the habit name display up to its full 31-character capacity.
- Expands the journal view display to `ui_w - 6` columns.
- Automatically detects terminal resize events while idle, recomputing geometry and redrawing without requiring keyboard input.
- Preserves the single-`sys_write`-per-frame rendering model.

---

## 2. Layout Geometry & Horizontal Centering

### 2.1 State Variables
In `src/data.asm` (`.bss`), three runtime variables track layout dimensions:
- `ui_w` (`resd 1`): Current frame width in columns (78 to 100).
- `ui_h` (`resd 1`): Current frame height in rows (equals physical `term_rows`).
- `ui_col0` (`resd 1`): Zero-based horizontal origin offset (the left margin in terminal columns).
- `ui_seen_cols`, `ui_seen_rows` (`resd 1`): Cached terminal dimensions used to detect size changes and clear stale characters.

### 2.2 Mathematical Formulas
Given terminal dimensions `term_cols` and `term_rows` obtained via `ioctl(0, TIOCGWINSZ, ...)`:
1. **Frame Width:**
   $$\text{ui\_w} = \min(\text{term\_cols} - 2, 100)$$
2. **Horizontal Margin:**
   $$\text{ui\_col0} = \lfloor(\text{term\_cols} - \text{ui\_w}) / 2\rfloor$$
3. **Frame Height:**
   $$\text{ui\_h} = \text{term\_rows}$$

### 2.3 Verified Dimensions
| Terminal Size | `ui_w` | Left Margin (`ui_col0`) | Absolute Column Extent |
|---|---|---|---|
| **80 × 24** | 78 | 1 | Columns 2 – 79 |
| **100 × 30** | 98 | 1 | Columns 2 – 99 |
| **120 × 40** | 100 | 10 | Columns 11 – 110 |

The minimum size gate remains strictly at **80×24**. If the terminal drops below 80 columns or 24 rows, `ui_size_gate` intercepts execution and prompts the user to resize before any screen rendering occurs.

---

## 3. Frame-Relative Positioning (`ui_goto`)

In V1, drawing procedures used `buf_goto(row, col)`, where `col` was an absolute physical terminal column. In V2:
- `ui_goto` accepts a frame-relative column coordinate in `EBX` (1-based: column 1 represents the frame's left border `|`).
- It translates the frame-relative column to an absolute terminal column:
  $$\text{absolute\_col} = \text{EBX} + \text{ui\_col0}$$
- It formats the standard ANSI sequence `ESC [ <row> ; <col> H` and appends it to `out_buf`.
- Registers (`EAX`, `EBX`, `ECX`, `EDX`, `ESI`, `EDI`) are preserved.

All frame borders (`ui_frame_hline`, `ui_frame_row`), labels (`ui_text_at`), and screen elements now use `ui_goto`. When `ui_layout_update` detects that physical terminal dimensions have changed, it appends `ESC [ 2 J` (`ansi_clear`) into `out_buf` to wipe stale characters outside the new frame boundaries before redrawing.

---

## 4. UTF-8 Display Column Counting & Clipping (`buf_str_clip`)

### 4.1 Display Columns vs. Byte Count
In UTF-8, characters can span 1 to 4 bytes:
- ASCII: 1 byte (`0x00`–`0x7F`)
- 2-byte sequence: lead byte `0xC2`–`0xDF`, 1 continuation byte (`0x80`–`0xBF`)
- 3-byte sequence: lead byte `0xE0`–`0xEF`, 2 continuation bytes
- 4-byte sequence: lead byte `0xF0`–`0xF4`, 3 continuation bytes

Treating byte count as display width would cause multibyte characters (such as box-drawing symbols, dashes, or non-Latin glyphs) to be prematurely clipped or split mid-character.

### 4.2 Algorithm in `buf_str_clip`
`buf_str_clip` takes `ESI` (pointer to string) and `ECX` (max display columns).
1. **Pass 1 (Measurement):** Scans the string using helper `utf8_char_len`. For each character, identifies byte length and advances. Each valid character counts as 1 display column.
2. **Budgeting & Marker Reservation:**
   - If `total_columns <= ECX`: fits completely. Budget is `ECX`, no marker needed.
   - If `total_columns > ECX`: clipping is needed. 1 column is reserved for marker `~` (`UI_CLIP_MARKER`), setting budget to `ECX - 1`.
   - Special cases: If `ECX == 0`, nothing is emitted.
3. **Pass 2 (Emission):** Emits characters up to the column budget into `out_buf`. If an invalid byte or control character (< `0x20` or `0x7F`) is encountered, it is sanitized to `?`. Complete multibyte sequences are copied without splitting.
4. **Marker Append:** If clipping occurred and `ECX > 0`, `~` is appended.

---

## 5. Screen Adaptations

### 5.1 Habit Tracker (`src/habits.asm`)
- **Full 31-character names:** In V1, habit names were clamped to 12 characters. In V2, `habits_draw_row` allocates `min(31, ui_w - 44)` columns. At 80×24, `ui_w = 78`, providing 34 columns—allowing the full 31-character habit name to display without truncation.
- **Dynamic Right-Anchored Columns:**
  - 7 History Squares `[#]/[.]`: positioned at `ui_w - 36`
  - Streak: positioned at `ui_w - 13`
  - Total: positioned at `ui_w - 6`
  - Right border `|`: anchored at `ui_w`
- Column headers dynamically align with these positions on Row 3.

### 5.2 Journal (`src/journal.asm`)
- Display width is expanded to `ui_w - 6` display columns (e.g., 72 columns at 80×24, 92 columns at 100×30).
- Lines are safely clipped via `buf_str_clip`, preventing overflow past the frame's right border.

### 5.3 Idle Resize Polling
- In all event loops (Menu in `src/main.asm`, Timer in `src/timer.asm`, Habits in `src/habits.asm`, Journal in `src/journal.asm`), idle waiting uses a 50 ms `sys_nanosleep` interval followed by `term_size_ok` polling.
- If physical columns or rows change while idle, `need_redraw = 1` is flagged, immediately recalculating geometry and repainting without requiring the user to press a key.

---

## 6. How to Build & Verify

### 6.1 Build
```bash
make clean
make
```
Ensure build produces `build/pawmodoro` warning-free.

### 6.2 Smoke Test Suite
```bash
bash tests/smoke.sh
```
All 16 test scenarios must pass (`16 passed, 0 failed`).

### 6.3 Verifying Single `sys_write` Per Frame
Run under `strace`:
```bash
strace -e trace=write ./build/pawmodoro
```
Observe that after terminal initialization (`\33[?1049h\33[?25l`), each screen frame is emitted via exactly one `write(1, ...)` syscall.

---

## 7. Known Architectural Limitations

1. **Approved Glyph Width Approximation:** Counting non-continuation bytes treats all printable UTF-8 characters as 1 column wide. Full East Asian wide glyphs (2 columns) or zero-width combining characters are not handled, adhering to the approved project single-column glyph specification.
2. **Journal Wrapping:** Journal lines exceeding `ui_w - 6` are cleanly clipped with `~`. Multi-line text wrapping and deletion belong to subsequent V2 tasks and are not implemented here.
