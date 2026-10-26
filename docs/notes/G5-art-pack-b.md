# G5: Art Pack B (Icons, Ornaments, Big Digits, and Widget Assets)

**Task Identifier:** `G5-art-pack-b`  
**Date:** October 26, 2026  
**Course:** CAO10 (Group 8)  
**Audience:** University Assembly Evaluator & Senior Graphics Reviewer  
**Status:** Complete & Fully Verified  

---

## 1. Task Summary

Task G5 implements the complete "Art Pack B" for Pawmodoro v3, establishing all icons, decorative ornaments, big and compact numeric/timer digits, UI widget primitives, approved glyph extensions, and the theme-aware title gradient engine. All assets adhere to the half-block architecture ($2 \text{ pixel rows} = 1 \text{ terminal cell row}$) and the 24-slot semantic theme system established in PRD v3 §4, §5, §10, and §12.2.

### What Was Delivered
1. **14 Canonical Icon Families (28 Sprite Variants):**
   - Standard ($6\times 3$ cells = $6\times 6$ pixels) and Compact ($4\times 2$ cells = $4\times 4$ pixels) variants for:
     1. Tomato / Start Focus
     2. Checklist with Paw / Habits
     3. Open Journal with Pen / Journal
     4. Mechanical Gear with Kitten / Settings
     5. Exit Door with Walking Cat / Quit
     6. Cat Paw
     7. 5-Point Star
     8. Sparkle (4-point star cross)
     9. Checkmark
     10. Heart
     11. Flame (Streak)
     12. Crescent Moon
     13. Notification Bell
     14. Lock-Free Plus Symbol
2. **Decorative Ornaments (4 Sprite Variants):**
   - `sprite_vine_corner_tl`: Top-left corner decorative leafy vine with flower buds ($8\times 4$ cells = $8\times 8$ pixels).
   - `sprite_vine_corner_br`: Bottom-right corner complementary vine ($8\times 4$ cells = $8\times 8$ pixels).
   - `sprite_scattered_star`: Small ambient sparkle star ($2\times 1$ cells = $2\times 2$ pixels).
   - `sprite_scattered_paw`: Small ambient cat paw print ($2\times 1$ cells = $2\times 2$ pixels).
3. **Digit Font Sets & Rendering Helper (`bigdigit_draw`):**
   - **Large Digits ($5\times 4$ cells = $5\times 8$ pixels):** Digits `0` through `9` and aligned colon `:`.
   - **Compact Digits ($3\times 2$ cells = $3\times 4$ pixels):** Digits `0` through `9` and compact colon `:`.
   - **ASCII Large Digits:** Hand-crafted 7-bit multiline text representations (4 lines $\times$ 5 characters) for digits `0`–`9` and colon.
   - **`bigdigit_draw` Procedure:** Public drawing procedure supporting both numeric formatting (`0`..`99`) and timer duration (`00:00`..`99:59`) with 1-cell gaps, range clamping, single `out_buf` writes, and automatic ASCII mode fallback.
4. **Widget Primitives (10 Sprite Variants):**
   - `sprite_widget_toggle`: Animated pill toggle switch ($6\times 2$ cells = $6\times 4$ pixels) with 2 frames (`OFF` on dim track, `ON` on active accent/ok track) and ASCII fallbacks `[ OFF]` / `[ ON ]`.
   - Button caps: `sprite_btn_cap_l` and `sprite_btn_cap_r` ($2\times 1$ cells = $2\times 2$ pixels).
   - Progress bar pieces: `sprite_prog_track_empty` and `sprite_prog_track_fill` ($2\times 1$ cells).
   - Progress bar slider socket: `sprite_prog_marker_socket` ($2\times 1$ cells) providing the mounting groove for the habit cat-head marker.
   - Panel rounded corners: `sprite_panel_corner_tl` and `sprite_panel_corner_br` ($1\times 1$ cell).
   - Navigation tabs: `sprite_tab_active` and `sprite_tab_inactive` ($2\times 1$ cells).
5. **Approved-Glyph Table Extension (`glyph_*`):**
   - Added all 9 requested graphical glyphs: `▀`, `▄`, `█`, `▌`, `▐`, `░`, `▒`, `▓`, `✓`.
   - Expanded table from 15 to 24 glyphs (`GLYPH_COUNT equ 24`) in `src/constants.inc` and `src/data.asm`.
   - Bound 100% strict 7-bit ASCII fallbacks (zero bytes $\ge 0x80$).
   - Integrated live glyph preview strip into the hidden sprite viewer (`Ctrl+V`) on row 8.
6. **Title Gradient Engine (`title_gradient`):**
   - Added `title_gradient` helper in `src/ui.asm`.
   - Renders spaced titles (`P A W M O D O R O`, 1 space between characters) using a precomputed 12-entry ANSI 256-color ramp per theme stored in `theme_title_ramps` (8 themes $\times$ 12 bytes = 96 bytes in `.data`).
   - Smooth transition from `SLOT_TITLE` to `SLOT_TITLE_ALT` without runtime floating-point or RGB interpolation.
7. **Sprite Viewer Integration:**
   - Extended registry table from 23 to **87 sprites** (`sprite_count: dd 87`), allowing developer inspection of every G4 cat and G5 icon, digit, ornament, and widget.

---

## 2. Reference Images Inspected

All reference crops and mockups were inspected directly using IDE image inspection tools:

| Image Path | Resolution | Observations & Design Integration |
|---|---|---|
| `docs/reference/sprites/target-dashboard.png` | 2400×1440 | Reference mockup showing sidebar icon buttons, card corner vines, spaced gradient header, and habit progress slider. |
| `docs/reference/sprites/target-dashboard.jpg` | 1920×1152 | Visual source of truth (formerly `reference_home_page.jpg`). Verified icon and widget layouts. |
| `docs/reference/sprites/start_focus_session.png` | 1024×1024 | Tomato clock with cat ears, green leaf stem, white dial face, and paw print; mapped to `icon_timer`. |
| `docs/reference/sprites/habit_tracker.png` | 1024×1024 | Tan clipboard with checkmarks and cat paw badge; mapped to `icon_habits`. |
| `docs/reference/sprites/journal.png` | 1024×1024 | Open hardcover notebook with ruled lines and tilted pencil with eraser; mapped to `icon_journal`. |
| `docs/reference/sprites/settings.png` | 1024×1024 | Industrial gear with cute cat peeking through center hole; mapped to `icon_settings`. |
| `docs/reference/sprites/quit.png` | 1024×1024 | Open door with pink exit arrow and cat silhouette walking through; mapped to `icon_quit`. |
| `docs/reference/sprites/sparkle.png` | 1024×1024 | Four-point star sparkles and cross glints; mapped to `icon_sparkle` and `scattered_star`. |

*Image Inspection Note:* While crops existed for Timer, Habits, Journal, Settings, Quit, and Sparkle, individual standalone crops for Paw, Star, Checkmark, Heart, Flame, Moon, Bell, Plus, Digits, and Widgets were not present in `docs/reference/sprites/`. They were hand-authored in pixel art following the identical aesthetic, proportions, and theme-slot bindings of the reference dashboard.

---

## 3. Files Created or Changed (Strict Allowlist Scope)

Only permitted files within the explicit allowlist were modified or created:

| File Path | Status | Rationale & Changes Made |
|---|---|---|
| `src/constants.inc` | Modified | Added glyph IDs `GLYPH_HALF_UPPER` (15) through `GLYPH_CHECKMARK` (23); updated `GLYPH_COUNT` to 24; added format flags `BIGDIGIT_FMT_NUM` (0) and `BIGDIGIT_FMT_MMSS` (1). |
| `src/data.asm` | Modified | Added 9 new UTF-8 glyph definitions and 7-bit ASCII fallbacks to `glyph_utf8_table` and `glyph_ascii_table`; added precomputed 12-entry theme gradient color ramps `theme_title_ramps` (96 bytes); added ASCII large digit font strings `ascii_bigdigit_lines`. |
| `src/ui.asm` | Modified | Implemented `bigdigit_draw` (numeric and MM:SS digit composition with UTF-8 half-block and ASCII modes) and `title_gradient` (spaced title with precomputed 12-step theme color ramp). |
| `src/sprites.asm` | Modified | Appended 64 new G5 sprite definitions (14 icons $\times$ 2 tiers, 11 large digits, 11 compact digits, 4 ornaments, 10 widget pieces); added `digit_large_sprites` and `digit_compact_sprites` pointer tables; expanded `sprite_table` and `sprite_names` to 87 entries (`sprite_count: dd 87`). |
| `src/sprite.asm` | Modified | Extended sprite viewer to display the live approved-glyph preview strip on row 8 in both UTF-8 and ASCII modes. |
| `tests/smoke.sh` | Modified | Added Scenario 36 verifying stripped ELF executable size ($< 64\text{ KB}$), `.bss` size ($\le 81,920\text{ B}$), approved glyph preview strip in viewer, big digit inspection via navigation, and strict ASCII purity. |
| `tests/TEST_PLAN.md` | Modified | Added test cases TC-143 through TC-149 and mapped Check 36. |
| `docs/notes/G5-art-pack-b.md` | Created | This engineering implementation and verification report. |

---

## 4. Complete Asset Inventory

### A. Large & Compact Digits Font
- **Large Digits ($5\times 4$ cells = $5\times 8$ px):**
  - `sprite_digit_large_0` .. `sprite_digit_large_9`
  - `sprite_digit_large_colon` ($3\times 4$ cells = $3\times 8$ px)
- **Compact Digits ($3\times 2$ cells = $3\times 4$ px):**
  - `sprite_digit_compact_0` .. `sprite_digit_compact_9`
  - `sprite_digit_compact_colon` ($2\times 2$ cells = $2\times 4$ px)
- **ASCII Large Digits:**
  - 11 entries in `ascii_bigdigit_lines` (digits 0..9 and colon), each 4 lines high $\times$ 5 characters wide.

### B. 14 Icon Families
| Icon Name | Standard Size (Cells / Px) | Compact Size (Cells / Px) | Semantic Theme Slots | ASCII Fallback |
|---|---|---|---|---|
| Tomato / Timer | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_TITLE`, `SLOT_OK`, `SLOT_ACCENT`, `SLOT_OUTLINE` | `[TIMER]`, `[TM]` |
| Checklist / Habits | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_SURFACE_ALT`, `SLOT_OK`, `SLOT_EAR_BLUSH`, `SLOT_OUTLINE` | `[LIST]`, `[HB]` |
| Journal / Book | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_TITLE`, `SLOT_SURFACE_ALT`, `SLOT_ACCENT`, `SLOT_OUTLINE` | `[BOOK]`, `[JN]` |
| Gear / Settings | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_OUTLINE`, `SLOT_FUR`, `SLOT_EAR_BLUSH`, `SLOT_EYE_NOSE` | `[GEAR]`, `[ST]` |
| Door / Quit | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_TITLE_ALT`, `SLOT_EAR_BLUSH`, `SLOT_TEXT`, `SLOT_OUTLINE` | `[EXIT]`, `[QT]` |
| Paw | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_FUR`, `SLOT_EAR_BLUSH`, `SLOT_OUTLINE` | `( ^ )`, `(^)` |
| Star | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_ACCENT`, `SLOT_WARN` | `[ * ]`, `[*]` |
| Sparkle | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_ACCENT`, `SLOT_TITLE_ALT` | `+ * +`, `+*` |
| Checkmark | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_OK`, `SLOT_OUTLINE` | `[ V ]`, `[V]` |
| Heart | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_TITLE`, `SLOT_EAR_BLUSH` | `< 3 >`, `<3` |
| Flame (Streak) | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_TITLE`, `SLOT_WARN`, `SLOT_ACCENT` | `( ^ )`, `(^)` |
| Moon | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_ACCENT`, `SLOT_TITLE_ALT` | `( ) )`, `())` |
| Bell | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_ACCENT`, `SLOT_WARN` | `( o )`, `(o)` |
| Plus (Lock-Free) | $6\times 3$ ($6\times 6$) | $4\times 2$ ($4\times 4$) | `SLOT_ACCENT`, `SLOT_OUTLINE` | `[ + ]`, `[+]` |

### C. Ornaments
- `sprite_vine_corner_tl`: Top-left corner vine ($8\times 4$ cells = $8\times 8$ px).
- `sprite_vine_corner_br`: Bottom-right corner vine ($8\times 4$ cells = $8\times 8$ px).
- `sprite_scattered_star`: Small ambient sparkle star ($2\times 1$ cells = $2\times 2$ px).
- `sprite_scattered_paw`: Small ambient cat paw print ($2\times 1$ cells = $2\times 2$ px).

### D. Widget Pieces
- `sprite_widget_toggle`: Pill toggle switch ($6\times 2$ cells = $6\times 4$ px, 2 frames: `OFF` and `ON`).
- `sprite_btn_cap_l` & `sprite_btn_cap_r`: Button cap left/right rounded terminals ($2\times 1$ cells).
- `sprite_prog_track_empty` & `sprite_prog_track_fill`: Progress track segments ($2\times 1$ cells).
- `sprite_prog_marker_socket`: Groove socket for cat-head marker ($2\times 1$ cells).
- `sprite_panel_corner_tl` & `sprite_panel_corner_br`: Rounded panel corner subpixels ($1\times 1$ cell).
- `sprite_tab_active` & `sprite_tab_inactive`: Tab boundaries ($2\times 1$ cells).

---

## 5. Procedure Contracts: IN / OUT / CLOBBERS

### 1. `bigdigit_draw` (`src/ui.asm`)
- **Purpose:** Composes large numeric or countdown time digits into `out_buf` at designated terminal coordinates with 1-cell horizontal gaps and aligned colon. Supports UTF-8 half-block and ASCII fallback modes.
- **IN:**
  - `EAX` = Starting terminal row (1-based, existing UI coordinates).
  - `EBX` = Starting terminal column (1-based).
  - `ECX` = Numeric value (`0`..`99`) or duration in seconds (`0`..`5999`).
  - `EDX` = Format flag:
    - `BIGDIGIT_FMT_NUM` (0) = Ordinary numeric display (`0`..`99`).
    - `BIGDIGIT_FMT_MMSS` (1) = Minutes:Seconds display (`00:00`..`99:59`).
- **OUT:** Appends complete formatted glyphs and spacing escapes to `out_buf`. Does not flush or issue independent `sys_write`.
- **CLOBBERS:** None (preserves all general-purpose registers `EAX`, `EBX`, `ECX`, `EDX`, `ESI`, `EDI`, `EBP`, and EFLAGS).

### 2. `title_gradient` (`src/ui.asm`)
- **Purpose:** Renders spaced title string (`P A W M O D O R O`, 1 space between characters) with a theme-aware color gradient into `out_buf`. Transitions smoothly from `SLOT_TITLE` to `SLOT_TITLE_ALT` across a precomputed 12-entry ANSI 256-color ramp per theme.
- **IN:**
  - `ESI` = Pointer to NUL-terminated title string.
  - `EAX` = Starting terminal row (1-based).
  - `EBX` = Starting terminal column (1-based).
  - `CL`  = Starting color slot (`SLOT_TITLE`).
  - `CH`  = Ending color slot (`SLOT_TITLE_ALT`).
- **OUT:** Appends spaced, gradient-colored title escapes and characters to `out_buf`. Restores default text color on exit.
- **CLOBBERS:** None (preserves all general-purpose registers `EAX`, `EBX`, `ECX`, `EDX`, `ESI`, `EDI`, `EBP`, and EFLAGS).

### 3. `ui_glyph_str` (`src/ui_components.asm`, Preserved Contract)
- **IN:** `EAX` = Glyph ID (`0`..`GLYPH_COUNT-1`, `0`..`23`).
- **OUT:** `ESI` = Pointer to NUL-terminated glyph string (UTF-8 multibyte sequence or 7-bit ASCII fallback based on `setting_charset`).
- **CLOBBERS:** Preserves all other registers.

---

## 6. Theme and ASCII Fallback Behavior

### Theme Dynamic Recoloring
- All icons, ornaments, digits, and widgets resolve their colors exclusively through the 24 semantic theme slots (`SLOT_TITLE`, `SLOT_TITLE_ALT`, `SLOT_OK`, `SLOT_ACCENT`, `SLOT_FUR`, `SLOT_EAR_BLUSH`, `SLOT_OUTLINE`, etc.).
- Zero hard-coded ANSI color escapes are embedded in sprite definitions.
- Changing the active theme (e.g. from Strawberry Milk to Matcha Latte, Blueberry, Lavender Night, Sunset Peach, Mono Cozy, or High Contrast) immediately recolors all G5 artwork without modifying binary sprite data.

### Title Gradient Ramps
- `theme_title_ramps` contains a precomputed 12-entry 256-color ramp for each of the 8 themes (96 bytes total).
- Character color indices are computed deterministically via integer arithmetic: $\text{ramp\_idx} = \min((i \times 12) / L, 11)$.
- No floating-point instructions or runtime RGB interpolations are used.

### Strict 7-Bit ASCII Fallback
- Every icon, ornament, digit, widget, and approved glyph provides an explicit 7-bit ASCII representation.
- In ASCII mode (`setting_charset == 1`):
  - Large digits render via `ascii_bigdigit_lines` (4 lines of plain ASCII characters `_`, `|`, `/`, `\`, `o`).
  - Glyphs render as `-`, `_`, `#`, `|`, `.`, `:`, `v`.
  - Zero application-generated bytes $\ge 0x80$ are emitted.

---

## 7. Sprite-Data and Executable Sizes

### Measurements
- **G4 Base Sprite Payload:** 6,374 bytes
- **G5 New Sprite Payload:** 3,133 bytes
- **Combined G4 + G5 Sprite Payload:** **9,507 bytes (9.28 KiB)** (12,327 bytes including all pointer tables and string labels)
- **Hard Limit:** $\le 24,576\text{ bytes (24 KiB)}$
- **Remaining Sprite Headroom:** **12,249 bytes (49.8% headroom below the 24 KiB limit)**
- **Executable Size:**
  - Unstripped ELF (with DWARF debug symbols): 173,156 bytes
  - **Stripped ELF Executable:** **61,800 bytes (< 65,536 bytes / 64 KB limit)**
  - Margin under 64 KB: **3,736 bytes headroom**
- **Section Sizes (`size build/pawmodoro`):**
  - `text`: 35,770 bytes
  - `data`: 20,612 bytes
  - `bss`: 70,616 bytes ($\le 81,920\text{ bytes limit}$)

---

## 8. Build and Test Results

### Build Verification
Command:
```bash
make clean && make
```
Output:
```text
rm -rf build
mkdir -p build
nasm -f elf32 -g -F dwarf -Wall src/main.asm -o build/pawmodoro.o
ld -m elf_i386 build/pawmodoro.o -o build/pawmodoro
```
- **Exit Status:** `0` (Zero compiler warnings, zero linker errors).

### Automated Smoke Test Suite
Command:
```bash
bash tests/smoke.sh
```
Output:
```text
[PASS] Check 1: Binary exists and is executable
...
[PASS] Check 35: Sprite viewer Ctrl+V, theme/coat cycle, ASCII purity, clipping, and clean return
[PASS] Check 36: G5 Art Pack B: Glyphs strip, Big digits, 14 Icons, ASCII purity, and ELF < 64 KB
=============================================================================
SMOKE TEST RESULTS: 36 passed, 0 failed
=============================================================================
```
- **Exit Status:** `0` (36 / 36 checks passed).

---

## 9. Screenshots and Visual Comparison

Screenshots were captured using automated tmux test harnesses and saved in the external artifact scratch directory (`scratch/screenshots_g5/`):

1. **`G5-compact-dashboard-80x24.png`** (80×24 Compact tier):
   - Confirms compact dashboard layout, size gate boundaries, and zero row overflows.
2. **`G5-standard-dashboard-100x30.png`** (100×30 Standard tier):
   - Confirms standard centered layout with clean margins and balanced proportions.
3. **`G5-grand-dashboard-120x36.png`** (120×36 Grand tier):
   - Confirms expansive grand dashboard layout with ample breathing room.
4. **`G5-icons-and-ornaments.png`** (100×30):
   - Sprite viewer capture displaying Icon Timer ($6\times 3$ cells) with red tomato body, green leaf cap, white dial face, and paw print, along with corner vine ornaments.
5. **`G5-large-and-compact-digits.png`** (100×30):
   - Sprite viewer capture displaying Large Digit 0 ($5\times 4$ cells = $5\times 8$ px) with uniform stroke thickness and balanced proportions.
6. **`G5-widgets-and-glyphs.png`** (100×30):
   - Sprite viewer capture displaying the pill toggle switch and row 8 Approved Glyphs preview strip (`─ │ ╭ ╮ ╰ ╯ ├ ┤ ★ ♥ ● ○ ▰ ▱ ✦ ▀ ▄ █ ▌ ▐ ░ ▒ ▓ ✓`).
7. **`G5-ascii-mode.png`** (100×30):
   - Sprite viewer in ASCII fallback mode (`setting_charset == 1`) displaying clean 7-bit ASCII glyphs and text art with zero bytes $\ge 0x80$.
8. **`G5-theme-variation.png`** (100×30):
   - Live theme switching in the viewer displaying immediate recoloring of foreground and accent slots under Blueberry and Matcha Latte themes.

---

## 10. Known Issues and Remaining Differences

1. **Terminal Half-Block Resolution:** Terminal cells use Unicode half-blocks (`▀`, `▄`), creating approximately $1:1$ square subpixels. Icons at $6\times 6$ subpixels achieve crisp retro icon silhouettes rather than continuous raster curves.
2. **Missing Standalone Crops for Secondary Icons:** Standalone PNG crops were provided for Timer, Habits, Journal, Settings, Quit, and Sparkle, but not for Paw, Star, Checkmark, Heart, Flame, Moon, Bell, Plus, Digits, and Widgets. As permitted by the specification, these were faithfully hand-authored to match the styling, palette, and proportions of the dashboard reference.

---

## 11. Unchanged Behavior and Data Formats

- **Runtime Logic Intact:** Timer state machine, countdown ticking, pause/resume, habit check-ins, journal entries, sound effects, notifications, and settings screens remain 100% untouched.
- **Data Stores Unchanged:** Formats of `stats.dat` (12 bytes), `habits.dat` (52 bytes), `journal.txt` (text log), and `settings.dat` (48 bytes v2) remain completely unmodified.
- **Procedure Calling Conventions:** All existing procedure contracts in `src/sprite.asm`, `src/theme.asm`, `src/gfx.asm`, `src/term.asm`, and `src/main.asm` were strictly preserved.
- **Strict Single-Write Invariant:** All frames render through `out_buf` (16,384 bytes) and flush with exactly one `sys_write` syscall (`int 0x80`).
