# Pawmodoro — PRD v3 Addendum (Visual Redesign & Terminal GUI Specification)

**Version:** 3.0-draft · **Course:** CAO10 · **Group:** 8 · **Task:** G0 (Specification & Reference Architecture — Documentation Only)  
**Baseline Documents:** `docs/PRD.md` (v1.0), `docs/PRD_V2.md` (v2.0-draft)  
**Implementation Roadmap:** `docs/roadmap_v3.md` (Tasks G0–G15)  
**Visual Reference Mockup:** `docs/reference/reference_home_page.jpg` (referred to as `docs/reference/target-dashboard.png` in roadmap; 1,858,686 bytes)  

> **DOCUMENT STATUS: SPECIFICATION ONLY (G0)**  
> This document is an authoritative engineering specification and addendum. It establishes the normative requirements, binary layouts, visual contracts, memory budgets, and acceptance criteria for Tasks G1 through G15.  
> **No application source code, build scripts, test suites, or binary data formats are modified by Task G0.**  
> Statements designated **[Repo fact]** represent verified measurements and contracts established by inspecting the active codebase; statements designated **[v3 requirement]** represent binding normative specifications for future tasks; statements designated **[Proposed v3 decision]** document design choices that govern upcoming tasks unless formally amended.

---

## 1. Document Status, Purpose, Scope, Terminology, and Normative Language

### 1.1 Purpose and Scope
Pawmodoro's core productivity features (Pomodoro timer, 8-item habit tracker, timestamped journal, persistence engine, and terminal restoration) are fully functional in 32-bit Linux x86 Assembly (NASM, `int 0x80`, zero libc dependencies). The v3 milestone transforms Pawmodoro's visual presentation into a modern, rich, cohesive "terminal GUI" inspired by cozy desktop applications while strictly preserving all underlying business logic, state machines, timing rules, and data persistence guarantees.

### 1.2 Normative Language
The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this document are to be interpreted as described in BCP 14 (RFC 2119 / RFC 8174).

### 1.3 Terminology
- **Terminal Cell:** A single character position on the screen, addressed by 1-based `(row, col)`.
- **Half-Block Pixel:** A sub-cell display unit. One terminal cell contains exactly two vertically stacked half-block pixels using the Unicode upper-half block glyph `▀` (`U+2580`). The top pixel color is governed by the foreground ANSI color escape; the bottom pixel color is governed by the background ANSI color escape.
- **Pixel Row:** A vertical coordinate in half-block space. Pixel row index = `(cell_row - 1) * 2 + (0 for top, 1 for bottom)`. A terminal height of $H$ rows provides $2H$ pixel rows.
- **Theme Slot:** A logical color index (0–23) mapped to a 256-color palette value (0–255). All application drawing MUST reference theme slots, never literal color escapes.
- **Cat Coat Preset:** A persistent configuration profile that selectively overrides the six cat-art theme slots (18–23) without mutating the user's interface palette.
- **Layout Tier:** A deterministic rendering configuration selected dynamically based on terminal dimensions: *Compact* (80–99 columns or <30 rows), *Standard* (100–119 columns and 30–35 rows), and *Grand* (≥120 columns and ≥36 rows).
- **SGR Mouse Mode:** Extended xterm 1006 tracking mode (`ESC[?1000h` + `ESC[?1006h`) returning decimal coordinates `ESC[<b;x;yM` / `ESC[<b;x;ym`.

---

## 2. Authority, Precedence, and Supersession

### 2.1 Precedence Hierarchy
1. `docs/PRD.md` (v1.0) remains the foundational baseline for all core application mechanics, timer durations, habit calculations, persistence principles, and assembly coding conventions.
2. `docs/PRD_V2.md` (v2.0) supplements v1 and remains in full force for all non-superseded additions (256-color slot model concept, sound synthesis via external player, notification layers, extended navigation keys `KEY_UP`..`KEY_DELETE`).
3. `docs/PRD_V3.md` (this document) is authoritative **only** for the v3 visual redesign, layout tiers, half-block graphics engine, extended theme slots, cat coat presets, `settings.dat` v2 format, mouse input subsystem, and explicitly enumerated supersessions.
4. Any requirement in v1 or v2 not explicitly superseded or amended below remains in full effect. No developer or agent is authorized to refactor unrelated functionality.

### 2.2 Complete Supersession Table

| Baseline Item | Previous Document & Section | Status | Exact Change in v3 | Controlling v3 Section |
|---|---|---|---|---|
| Maximum Frame Width | `PRD_V2.md` §2 (`UI_FRAME_MAX_WIDTH = 100`) | **Superseded** | Frame width cap raised from 100 to 120 columns (`UI_FRAME_MAX_WIDTH = 120`). Formula: `ui_w = min(term_cols - 2, 120)`. Centering retained. | §3.2 |
| Frame Layout Strategy | `PRD.md` §5, `PRD_V2.md` §2, `src/ui.asm` | **Superseded** | Replaced rigid row constants and state-based border guessing with three responsive layout tiers (*Compact*, *Standard*, *Grand*) and rectangle-based composition. | §3.1, §3.3 |
| Theme Slot Count | `PRD_V2.md` §4 (`NUM_SLOTS = 12`, slots 0–11) | **Extended** | Slots 0–11 preserved with original IDs and semantics; slots 12–23 added (`SLOT_BG`, `SLOT_SURFACE`, `SLOT_SURFACE_ALT`, `SLOT_BORDER_FOCUS`, `SLOT_TITLE_ALT`, `SLOT_TEXT_INV`, and 6 art slots). Total slots = 24. | §5.1, §5.2 |
| Cat Appearance Model | `PRD.md` §4.1 (FR-U6), `PRD_V2.md` §4 (`SLOT_CAT`) | **Extended** | Added persistent Cat Coat presets overriding slots 18–23; cat art renders via half-block sprites in addition to ASCII fallbacks. | §4.1, §5.3 |
| Output Buffer Size | `PRD.md` §6.5, `PRD_V2.md` §12 (`OUT_BUF_SIZE = 8192`) | **Superseded** | Buffer capacity doubled from 8,192 bytes to 16,384 bytes (`OUT_BUF_SIZE = 16384`) in `.bss`. Overflow flag added. | §8.1 |
| Approved Character Set | `PRD_V2.md` §3 (Glyph Table) | **Extended** | Added half-block and shading glyphs (`▀`, `▄`, `█`, `▌`, `▐`, `░`, `▒`, `▓`, `✓`) with mandatory 7-bit ASCII equivalents. Emoji remain strictly banned. | §7.1 |
| Settings File Format | `PRD_V2.md` §5 (`settings.dat`, 24 bytes, version 1) | **Superseded** | Upgraded to `settings.dat` version 2 (48 bytes). Retains magic `PAWS`; loads 24-byte v1 files transparently with documented defaults. | §6.1, §6.2 |
| Screen Clearing & Background | `PRD.md` §3.3 (`ESC[2J` / `ESC[H`), `PRD_V2.md` §2 | **Extended** | Screen clear sets background color to `SLOT_BG` before erase. Panel fills use surface slots (`SLOT_SURFACE`, `SLOT_SURFACE_ALT`). | §8.3 |
| Input Device Protocol | `PRD.md` §3.2, `PRD_V2.md` §6 (keyboard only) | **Extended** | Added xterm SGR mouse reporting (`KEY_MOUSE = 0x10A`), coordinate dispatch, and widget hit testing. Keyboard navigation remains fully operational. | §9.1, §9.2 |
| Main Menu Composition | `PRD.md` §5 (Wireframe), `PRD_V2.md` §1 (FR-U2) | **Superseded** | Transformed into the full Dashboard mockup matching `docs/reference/reference_home_page.jpg` with sidebar, stat cards, mascot, and quick journal. | §10.1, §10.2 |

---

## 3. Responsive Layout Tiers and Geometry

### 3.1 Tier Selection Rules
Pawmodoro v3 dynamically selects between three responsive layout tiers based on both width (`term_cols`) and height (`term_rows`). Layout decisions are recomputed whenever `(term_cols, term_rows)` change at redraw boundaries.

Tier selection is strictly deterministic:
```
if (term_cols >= 120 && term_rows >= 36) then
    TIER = TIER_GRAND
else if (term_cols >= 100 && term_rows >= 30) then
    TIER = TIER_STANDARD
else
    TIER = TIER_COMPACT
```

| Tier Name | Width Condition | Height Condition | Primary Visual Presentation |
|---|---|---|---|
| **Compact** | 80–99 columns | OR < 30 rows | 1-row compact sidebar buttons, 2×2 stacked dashboard cards, smaller sprite crops, reduced decorative detail. Essential navigation 100% accessible. |
| **Standard** | 100–119 columns | AND 30–35 rows | Bordered 3-row sidebar buttons with icons, standard horizontal dashboard composition, intermediate mascot sprites, moderate ornaments. |
| **Grand** | ≥ 120 columns | AND ≥ 36 rows | Full reference mockup layout: spacious cards, 3-row sidebar buttons with full icons, full-size tomato-cat mascot, corner vine ornaments, decorative stars and paws. |

**Small-Terminal Gate:** If `term_cols < 80` OR `term_rows < 24`, the existing dimension gate remains active: screen clears and displays `"Please enlarge the terminal (need 80x24, now <cols>x<rows>)"`. No application frame is rendered below 80×24.

### 3.2 Frame Geometry and Centering
- **Usable Frame Width:**
  $$\text{ui\_w} = \min(\text{term\_cols} - 2, 120)$$
- **Horizontal Centering:**
  $$\text{margin} = \lfloor (\text{term\_cols} - \text{ui\_w}) / 2 \rfloor$$
  The outer frame spans absolute 1-based columns from $\text{margin} + 1$ to $\text{margin} + \text{ui\_w}$.
- **Usable Frame Height:**
  $$\text{ui\_h} = \text{term\_rows}$$
  The outer frame spans absolute rows from $1$ to $\text{term\_rows}$.
- **Boundary Invariant:** No frame border, panel, card, sprite, text cell, ornament, cursor position, or mouse hitbox may be placed outside columns $1 \dots \text{term\_cols}$ or rows $1 \dots \text{term\_rows}$.

### 3.3 Dashboard Composition Across Tiers

| Dashboard Element | Compact Tier (80×24) | Standard Tier (100×30) | Grand Tier (120×36) |
|---|---|---|---|
| **Header Cat Logo** | Small crop (8×4 cells) or omitted if height < 26 | Standard crop (12×6 cells) | Full reference crop (14×7 cells) |
| **Title & Sparkle** | `PAWMODORO ✦` (compact spacing) | `P A W M O D O R O ✦` (spaced gradient) | `P A W M O D O R O ✦` (spaced gradient + sparkle) |
| **Tagline & Greeting** | Tagline visible; greeting condensed | Full tagline + time-of-day greeting | Full tagline + greeting + sleeping cat |
| **Sleeping Cat** | Hidden if width < 90 | Visible (6×3 cells) | Full crop (8×4 cells) |
| **Sidebar Layout** | Left column, width 22 cols, 1-row buttons | Left column, width 26 cols, 3-row bordered buttons | Left column, width 28 cols, 3-row bordered buttons |
| **Sidebar Buttons** | `[1] Focus`, `[2] Habits`, `[3] Notes`, etc. | 3-row bordered with icons (Start, Habits, Journal, Demo, Settings, Quit) | 3-row bordered with full icons & focused highlight |
| **Demo Toggle** | Compact toggle line `Demo: OFF/ON` | Horizontal toggle switch card | Full toggle switch card with pill slider |
| **Today's Progress** | Stacked vertically; cards 1-column wide | Horizontal arrangement: Stat, Habits, Tip | Full 3-card layout: Mascot Stat, Habits Bar, Tip |
| **Mascot Card** | Compact stat box: "13 Pomodoros" + small cat | Stat box + medium mascot sprite (10×5 cells) | Stat box + large glowing tomato mascot (14×7 cells) |
| **Habits Card** | 1-line progress `[#][#]...` + text | Card with cat-head progress bar slider | Card with detailed cat-head progress slider & ratio |
| **Daily Tip Card** | Single line clamped text | Framed card with wrapped 2-line tip | Framed card with sparkle header & wrapped text |
| **Quick Journal** | Shortcut key hint `[J] New Note` | Quick Journal card (top 2 entries) | Full Quick Journal button + card (last 3 entries) |
| **Ornaments** | All decorative vines/stars hidden | Decorative stars only; vines hidden | Full corner vines, leaf clusters, stars, paw prints |

---

## 4. Half-Block Sprite Model and Binary Representation

### 4.1 Pixel and Color Architecture
- **Vertical Resolution Doubling:** Each terminal cell represents two vertical half-block pixels.
  - Character `▀` (`U+2580`): displays top pixel in Foreground color, bottom pixel in Background color.
  - Character `▄` (`U+2584`): displays bottom pixel in Foreground color, top pixel in Background color.
  - Character Space (`0x20`): used when both top and bottom pixels share the identical color, setting that color as Background.
- **Transparency Handling:** Sprite pixel index `0` represents transparent. A transparent pixel is never painted with a fixed universal color; it is dynamically filled using the caller-supplied surface color slot (`SLOT_SURFACE` or `SLOT_SURFACE_ALT`).
  - Top pixel transparent, bottom pixel colored: rendered as `▄` with Foreground = bottom color, Background = caller's surface slot.
  - Bottom pixel transparent, top pixel colored: rendered as `▀` with Foreground = top color, Background = caller's surface slot.
  - Both pixels transparent: rendered as Space (`0x20`) with Background = caller's surface slot.
- **Even Pixel Height Invariant:** All sprites MUST possess an **even** number of pixel rows ($H_{\text{pixels}} = 2 \times H_{\text{cells}}$). This guarantees that every pixel row pairs deterministically into integer cell rows without partial-cell ambiguity.
- **Palette Slot Indirection:** Sprites store zero hard-coded ANSI color values. Pixel values represent palette indices (1–15) that map through a per-sprite palette table to the application's 24 extended theme slots.

### 4.2 Deterministic Sprite Binary Format (`.spr`)
All compiled sprite assets embedded in `.data` follow a deterministic, byte-aligned structure:

```
+-----------------------------------------------------------------------+
| Offset | Width  | Field Name      | Description                       |
+-----------------------------------------------------------------------+
| 0x00   | 1 byte | width_cells     | Width of sprite in terminal cells |
| 0x01   | 1 byte | height_pixels   | Height in pixel rows (MUST BE EVEN)|
| 0x02   | 1 byte | frame_count     | Number of animation frames (>= 1) |
| 0x03   | 1 byte | palette_entries | Number of mapped theme slots (<=15)|
| 0x04   | N bytes| slot_map[N]     | Theme slot ID per palette index   |
|        |        |                 | (N = palette_entries, 1 <= N <= 15)|
+-----------------------------------------------------------------------+
| Followed by frame_count Run-Length Encoded (RLE) streams:             |
|   For each frame:                                                     |
|     Repeat until total decoded pixels == (width_cells * height_pixels):|
|       1 byte: run_length (1..255)                                     |
|       1 byte: palette_index (0 = transparent, 1..palette_entries)     |
|     1 byte: FRAME_END sentinel (0x00)                                 |
+-----------------------------------------------------------------------+
| Followed by ASCII Fallback Art block:                                 |
|   1 byte: ascii_lines (equal to height_cells = height_pixels / 2)     |
|   For each line:                                                      |
|     1 byte: line_length (equal to width_cells)                        |
|     line_length bytes: ASCII character string (all bytes < 0x80)      |
+-----------------------------------------------------------------------+
```

### 4.3 Sprite Format Validation and Safety Rules
The sprite decoder (`sprite_draw`) MUST enforce strict validation before and during rasterization:
1. **Dimension Sanity:** `width_cells > 0`, `height_pixels > 0`, `height_pixels % 2 == 0`. If violated, decoding aborts with no output.
2. **Palette Bounds:** `palette_entries <= 15`. Any pixel containing index $> \text{palette\_entries}$ is clamped to transparent (`0`) to prevent out-of-bounds palette lookup.
3. **Run-Length Bounds:** If a run length would cause decoded pixels in the current frame to exceed $W_{\text{cells}} \times H_{\text{pixels}}$, the run is truncated to the exact remaining pixel count, and the frame is terminated.
4. **Zero-Length Run Guard:** A run length of `0` in the RLE stream is treated as an illegal token; the decoder skips to the next frame or aborts.
5. **Clipping:** Pixels outside the visible terminal or designated panel clipping boundary are discarded without appending escape sequences or characters to `out_buf`.
6. **No Dynamic Memory:** All decoding occurs on the fly using CPU registers and small stack-allocated variables.

### 4.4 ASCII Fallback and Sprite Budget
- **ASCII Purity:** In ASCII mode (`setting_charset = 1`), `sprite_draw` transparently redirects to `sprite_draw_ascii`, which outputs the embedded ASCII fallback block. Application output in ASCII mode MUST NOT emit any byte $\ge \text{0x80}$.
- **Storage Budget:** The total initialized sprite asset payload in `.data` across all mascots, cats, icons, digits, and ornaments MUST NOT exceed **24 KiB (24,576 bytes)**, inclusive of headers, RLE data, and ASCII fallback strings.

---

## 5. Extended Theme Model and Cat Coat Presets

### 5.1 Preservation of Slots 0–11 (v2 Compatibility)
The twelve theme slots defined in `PRD_V2.md` §4 are immutable. Their IDs, names, and semantic roles MUST NOT be altered, renumbered, or reassigned:

| Slot ID | Symbolic Constant | Semantic Use |
|---:|---|---|
| 0 | `SLOT_BORDER` | Window frames, card outlines, panel dividers |
| 1 | `SLOT_TITLE` | Main headings, brand title start gradient |
| 2 | `SLOT_ACCENT` | Interactive hints, key badges, decorative sparkle |
| 3 | `SLOT_TEXT` | Primary readable text and labels |
| 4 | `SLOT_DIM` | Secondary text, inactive items, timestamps |
| 5 | `SLOT_OK` | Success badges, habit completed checkmarks |
| 6 | `SLOT_WARN` | Warning messages, paused indicators |
| 7 | `SLOT_ERR` | Error messages, failed save alerts |
| 8 | `SLOT_CAT` | Legacy cat art fallback color |
| 9 | `SLOT_BAR_FULL` | Filled progress bar segments |
| 10 | `SLOT_BAR_EMPTY` | Empty progress bar track segments |
| 11 | `SLOT_HIGHLIGHT` | Selected menu item / row background fill |

### 5.2 Extended Theme Slots 12–23
To support full dark-surface rendering, gradients, and multi-tone pixel-art sprites, twelve additional slots are introduced:

| Slot ID | Symbolic Constant | Justification & Intended Use | Proposed Theme 0 Default (256-color) |
|---:|---|---|---:|
| 12 | `SLOT_BG` | Application root background. Clear screen paints entire terminal in this color. Distinguishes app surface from terminal default. | 234 (Very dark charcoal/black) |
| 13 | `SLOT_SURFACE` | Sidebar and large panel surface background. Provides depth layering above `SLOT_BG`. | 235 (Dark slate/charcoal) |
| 14 | `SLOT_SURFACE_ALT` | Inner card background (Mascot card, Habits card, Daily Tip card). Lightest background layer. | 236 (Deep warm gray) |
| 15 | `SLOT_BORDER_FOCUS` | Highlighted/active card or button border. Distinguishes focused controls without relying solely on fill. | 211 (Soft light pink) |
| 16 | `SLOT_TITLE_ALT` | End color for the brand title gradient (`PAWMODORO`). Interpolates from `SLOT_TITLE` (slot 1). | 218 (Light blush pink) |
| 17 | `SLOT_TEXT_INV` | Text color drawn over highlighted buttons (e.g. dark text on pink button fill). | 234 (Dark charcoal) |
| 18 | `SLOT_FUR` | Base fur color for cat mascots, header logo, and progress markers. Overridden by coat presets. | 216 (Warm peach / cream-orange) |
| 19 | `SLOT_FUR_SHADE` | Shading and shadow tone for cat fur. Provides depth and rounded volume. Overridden by coat presets. | 173 (Muted terracotta / dark orange) |
| 20 | `SLOT_FUR_STRIPE` | Forehead and body stripes for tabby markings. Overridden by coat presets. | 137 (Warm medium brown) |
| 21 | `SLOT_EAR_BLUSH` | Inner ear fill and blushing cheeks on cat faces. | 211 (Soft petal pink) |
| 22 | `SLOT_OUTLINE` | Perimeter outline separating sprite from panel background. Preserves contrast on dark panels. | 52 (Deep dark maroon / black-brown) |
| 23 | `SLOT_EYE_NOSE` | Cat facial details: eyes, pupils, nose, mouth line. | 233 (Near black) |

### 5.3 Cat Coat Presets
Cat coats provide instant recoloring of all feline assets without altering the interface theme. Presets override only slots 18 (`SLOT_FUR`), 19 (`SLOT_FUR_SHADE`), 20 (`SLOT_FUR_STRIPE`), 21 (`SLOT_EAR_BLUSH`), 22 (`SLOT_OUTLINE`), and 23 (`SLOT_EYE_NOSE`):

| Preset ID | Coat Preset Name | SLOT_FUR (18) | SLOT_FUR_SHADE (19) | SLOT_FUR_STRIPE (20) | SLOT_EAR_BLUSH (21) | SLOT_OUTLINE (22) | SLOT_EYE_NOSE (23) |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | **Orange Tabby (Default)** | 216 (Peach/Orange) | 173 (Warm Rust) | 137 (Brown Stripe) | 211 (Pink Blush) | 52 (Dark Maroon) | 233 (Dark Charcoal) |
| 1 | **Gray Tabby** | 249 (Light Silver) | 245 (Medium Gray) | 240 (Slate Stripe) | 218 (Soft Pink) | 236 (Dark Slate) | 232 (Black) |
| 2 | **Black Cat** | 235 (Jet Black) | 233 (Deep Shadow) | 237 (Subtle Sheen) | 211 (Pink Blush) | 232 (Pure Black) | 220 (Golden Amber Eyes) |
| 3 | **White Cat** | 255 (Pure White) | 251 (Soft Off-White)| 253 (Warm White) | 218 (Petal Blush) | 244 (Light Outline)| 75 (Sky Blue Eyes) |
| 4 | **Cream / Calico** | 223 (Warm Cream) | 216 (Light Peach) | 173 (Ginger Patch) | 211 (Pink Blush) | 95 (Warm Umber) | 233 (Dark Charcoal) |
| 5 | **Tuxedo** | 234 (Black Body) | 232 (Black Shadow) | 255 (White Bib/Paw)| 211 (Pink Blush) | 232 (Black Outline)| 114 (Emerald Eyes) |
| 6 | **Custom** | Custom value | Custom value | Custom value | Custom value | Custom value | Custom value |

**Runtime Separation:** The active runtime palette (`active_palette`, 24 bytes in `.bss`) is dynamically constructed by copying the selected theme's base 24-slot values and then applying the active coat preset's overrides to slots 18–23. Editing an individual art slot in the color editor automatically sets `setting_coat = 6` (Custom) to prevent unintended overwriting of built-in presets.

---

## 6. Persistent Settings: `settings.dat` Version 2

### 6.1 Version 2 Binary File Layout
The persistent settings file `settings.dat` is located in the application working directory. Version 2 expands the file to **exactly 48 bytes**, little-endian, with zero padding gaps:

```
+--------+--------+------------------------+---------------------------------------+
| Offset | Width  | Field Name             | Valid Range & Meaning                |
+--------+--------+------------------------+---------------------------------------+
| 0x00   | 4 byte | magic                  | Exactly 'PAWS' (dword 0x53574150)     |
| 0x04   | 1 byte | version                | Exactly 2 (0x02)                      |
| 0x05   | 1 byte | theme                  | 0..6 = Built-in themes, 7 = Custom    |
| 0x06   | 24 byte| custom_palette[0..23]  | Palette index (0..255) for slots 0..23|
| 0x1E   | 1 byte | anim                   | 0 = Reduce Motion, 1 = Animations ON  |
| 0x1F   | 1 byte | sound                  | 0 = Sound OFF, 1 = Sound ON           |
| 0x20   | 1 byte | charset                | 0 = UTF-8 mode, 1 = Strict ASCII mode |
| 0x21   | 1 byte | notify                 | 0 = Notifications OFF, 1 = Master ON  |
| 0x22   | 1 byte | notify_layers          | Bitmask: b0=bell, b1=flash, b2=title, |
|        |        |                        | b3=progress, b4=desktop (mask 0x1F)   |
| 0x23   | 1 byte | volume                 | 0..3 (0=mute, 1=25%, 2=50%, 3=100%)   |
| 0x24   | 1 byte | mouse                  | 0 = Mouse OFF, 1 = Mouse ON           |
| 0x25   | 1 byte | coat                   | 0..5 = Presets, 6 = Custom coat       |
| 0x26   | 6 byte | reserved               | Reserved for v3 extensions; MUST be 0 |
+--------+--------+------------------------+---------------------------------------+
| TOTAL: 48 bytes (0x00 .. 0x2F)                                                   |
+----------------------------------------------------------------------------------+
```

### 6.2 Validation and Backward-Compatible Migration
1. **Migration from Version 1 (24 bytes):**
   - If a file is loaded with length $\ge 24$ bytes, magic `PAWS`, and version `1`:
     - Load `theme`, `custom_palette[0..11]`, `anim`, `sound`, `charset`, `notify`, `notify_layers`, and `volume` directly from the v1 fields.
     - Populate new custom slots 12–23 from the default Theme 0 palette.
     - Populate `mouse` with default `1` (Enabled).
     - Populate `coat` with default `0` (Orange Tabby).
     - Zero out `reserved[0..5]`.
     - In-memory state is marked migrated; the file is rewritten in full 48-byte Version 2 format on the next save operation.
2. **Deterministic Rejection and Fallback:**
   - Any file that is missing, truncated ($< 24$ bytes), has bad magic ($\ne \text{'PAWS'}$), an unsupported version ($> 2$ or 0), corrupted field ranges (`theme > 7`, `anim > 1`, `sound > 1`, `charset > 1`, `volume > 3`, `mouse > 1`, `coat > 6`, or `notify_layers & ~0x1F != 0`), or contains unexpected file length (not 24 and not 48 bytes) is **strictly rejected**.
   - Upon rejection, all settings fall back safely to in-memory factory defaults. The corrupted file on disk is left untouched until a user action explicitly triggers a save.
3. **Save Isolation:** If `settings.dat` cannot be written (e.g. read-only filesystem or a directory named `settings.dat`), a non-fatal `"Could not save"` status is displayed, in-memory settings remain active, and the application continues running without data corruption.

---

## 7. Approved Glyphs and ASCII Fallback Mode

### 7.1 Extended Approved Glyphs Table
All application-generated visual elements MUST use only code points from the approved glyph set. Emoji are strictly prohibited across all screens, buttons, cards, and decorations:

| UTF-8 Code Point | Character Name | Required ASCII Equivalent | Primary Purpose in v3 |
|---|---|---|---|
| `▀` (`U+2580`) | Upper Half Block | `#` | Top half-block pixel rendering, drop shadows |
| `▄` (`U+2584`) | Lower Half Block | `#` | Bottom half-block pixel rendering |
| `█` (`U+2588`) | Full Block | `#` | Solid sprite cells, filled button caps |
| `▌` (`U+258C`) | Left Half Block | `#` | Vertical sub-cell dividers, toggle caps |
| `▐` (`U+2590`) | Right Half Block | `#` | Vertical sub-cell dividers, toggle caps |
| `░` (`U+2591`) | Light Shade | `.` | Background card texture, soft glow approximations |
| `▒` (`U+2592`) | Medium Shade | `:` | Shading ramps, drop shadow dithering |
| `▓` (`U+2593`) | Dark Shade | `#` | Heavy shadow dithering, deep panel borders |
| `✓` (`U+2713`) | Checkmark | `v` | Checklist items, completed habit stamps |
| `─` (`U+2500`) | Horizontal Box Line | `-` | Panel borders and horizontal card dividers |
| `│` (`U+2502`) | Vertical Box Line | `\|` | Panel borders and vertical card dividers |
| `╭ ╮ ╰ ╯` | Rounded Box Corners | `+` | Rounded card and button corners |
| `├ ┤ ┬ ┴ ┼` | Box Junction Tees | `+` | Connected panel frames and table junctions |
| `★` (`U+2605`) | Filled Star | `*` | Ornaments, achievements, streak markers |
| `♥` (`U+2665`) | Heart | `v` | Health, pomodoro reward garnish |
| `●` (`U+25CF`) | Filled Circle | `@` | Cycle progress dots, toggle switch knob |
| `○` (`U+25CB`) | Empty Circle | `o` | Inactive cycle progress dots, empty radio knob |
| `▰` (`U+25B0`) | Parallelogram Filled | `#` | Segmented progress bar active segment |
| `▱` (`U+25B1`) | Parallelogram Empty | `-` | Segmented progress bar inactive segment |
| `✦` (`U+2726`) | Four-Pointed Black Star | `*` | Title brand sparkle, daily tip header badge |

### 7.2 ASCII Mode Purity Mandate
When `setting_charset = 1`:
1. Every emitted byte generated by the application MUST satisfy `byte < 0x80` (7-bit ASCII).
2. Every half-block sprite MUST be replaced by its multi-line ASCII-art equivalent.
3. Every box border, rounded corner, progress segment, and ornament MUST emit its documented ASCII equivalent.
4. User text (journal entries, habit names) containing non-ASCII bytes is sanitized for display by substituting `?` for any byte $\ge \text{0x80}$. Stored files are never modified.

---

## 8. Rendering Architecture, Buffer Safety, and State Optimization

### 8.1 Output Buffer Capacity and Overflow Invariant
- **Capacity:** The primary aggregation buffer `out_buf` in `.bss` is allocated **16,384 bytes** (`OUT_BUF_SIZE = 16384`).
- **Capacity Invariant:**
  $$0 \le \text{out\_len} \le \text{OUT\_BUF\_SIZE}$$
  Every append operation of $N$ bytes MUST verify $N \le \text{OUT\_BUF\_SIZE} - \text{out\_len}$ before writing.
- **Overflow Detection Contract:**
  1. If an append exceeds remaining capacity, the write is dropped and the global flag `gfx_overflow` is set to `1`.
  2. An overflowed frame is considered corrupted and MUST NOT be flushed to standard output as a valid frame.
  3. `buf_flush` clears `gfx_overflow` after reporting or aborting.
- **Single-Write Guarantee:** Exactly one `sys_write` syscall to `FD_STDOUT` (1) is emitted per successfully constructed frame.

### 8.2 Local Color-Escape Skipping (`gfx_*`)
Emitting ANSI color sequences for every cell produces excessive escape overhead (~25 bytes per cell). v3 introduces local color-state caching:
1. **Scope:** Color caching is strictly local to `gfx_*` and `sprite_*` routines. Global caching across the entire application is prohibited because legacy procedures emit raw `ansi_reset` (`ESC[0m`), which would desynchronize a global cache.
2. **State Variables:** `gfx_fg` (word) and `gfx_bg` (word), initialized to `0xFFFF` (state unknown).
3. **Lifecycle:**
   - On entry to a graphics rendering block: call `gfx_sgr_forget`, which sets `gfx_fg = 0xFFFF` and `gfx_bg = 0xFFFF`.
   - `gfx_set_fg(slot)`: resolves the 256-color palette index $C$. If `gfx_fg == C`, no bytes are emitted. If different, emits `ESC[38;5;<C>m` and updates `gfx_fg = C`.
   - `gfx_set_bg(slot)`: resolves palette index $C$. If `gfx_bg == C`, no bytes are emitted. If different, emits `ESC[48;5;<C>m` and updates `gfx_bg = C`.
   - On exit from graphics routines: call `gfx_sgr_forget` and emit `ansi_reset` (`ESC[0m`).

### 8.3 Screen Clear, Background Erase, and Rectangles
- **Screen Erase:** A full screen redraw sets the background color to `SLOT_BG`, moves the cursor to (1,1), and emits `ESC[2J` (Erase Display). In ANSI-compliant terminals, `ESC[2J` fills all erased cells with the currently active background color.
- **Rectangle Drawing (`gfx_fill_rect`):**
  - Inputs: `EAX` = row, `EBX` = frame-relative column, `ECX` = width, `EDX` = height, `ESI` = background slot.
  - Draws row by row using cursor positioning (`buf_goto`), sets background color via `gfx_set_bg`, and emits Erase Character (`ESC[<n>X`) where supported, with fallback space-fill loop.
  - Rectangles are clipped strictly to `(ui_w, ui_h)`.

---

## 9. Mouse Support and Input Event Contracts

### 9.1 SGR Protocol and Lifecycle
- **Activation:** Emitted during `term_init` after alternate screen entry:
  - `ESC[?1000h` (enable basic mouse click reporting)
  - `ESC[?1006h` (enable SGR extended coordinate reporting)
- **Deactivation:** Emitted on EVERY exit path in `term_restore`:
  - `ESC[?1006l`
  - `ESC[?1000l`
  Deactivation is mandatory on normal exit, Ctrl+C interrupt, terminal resize errors, and fatal crashes.
- **Typing Isolation:** Mouse reporting MUST be disabled immediately prior to entering canonical cooked-mode line input (`read_line`), and re-enabled upon return to raw mode.

### 9.2 Event Parser and `KEY_MOUSE` Contract
- **Input Sequence:** SGR mouse events follow the format:
  $$\text{ESC} \ [ \ < \ b \ ; \ x \ ; \ y \ (M \mid m)$$
  where $b$ is the button code in decimal, $x$ is 1-based column, $y$ is 1-based row, `M` indicates button press, and `m` indicates button release.
- **Parsing Rules:**
  - Parser reads $b, x, y$ with bounded digit accumulation (up to 4 digits per field to prevent integer overflow).
  - Wheel events ($b = 64$ for wheel up, $b = 65$ for wheel down) are translated directly to `KEY_UP` and `KEY_DOWN`.
  - Right-clicks ($b = 2$) and middle-clicks ($b = 1$) are ignored.
  - Releases (`m`) are discarded; only presses (`M`) trigger actions.
  - Malformed or partial mouse sequences are drained up to terminating character without leaking raw characters to the keyboard queue.
- **Event Contract:**
  - `KEY_MOUSE` constant: `0x10A` (defined in `constants.inc`).
  - Upon parsing a valid press, `key_poll` returns `EAX = KEY_MOUSE`.
  - Event details are populated in `.bss`:
    - `mouse_btn` (dword): button code (0 = primary/left).
    - `mouse_row` (dword): absolute 1-based terminal row.
    - `mouse_col` (dword): frame-relative column ($x - \text{margin}$).

### 9.3 Widget Hit Testing
Each interactive screen maintains a hit-test registry:
- `hit_clear()`: resets hit-test entry count to 0.
- `hit_add(row, col, width, height, action_id)`: registers a bounding box and associated action identifier.
- `hit_find(row, col)`: returns `action_id` in `EAX` if coordinate falls within an active hitbox, or `-1` if none.

---

## 10. Target Dashboard Mockup Specification and Data Mapping

### 10.1 Visual Hierarchy and Composition
Based on direct inspection of the visual reference mockup (`docs/reference/reference_home_page.jpg`):
1. **Window Frame & Margins:** Dark charcoal background (`SLOT_BG`), framed in soft pink border (`SLOT_BORDER`), centered horizontally.
2. **Header Zone:** Left-aligned pixel-art cat head (`logo_cat`), followed by spaced gradient title `P A W M O D O R O ✦`, tagline `cozy focus - habits - notes`, and time-of-day greeting terminated with a sleeping cat sprite (`sleeping_cat`).
3. **Sidebar Panel (Left):** Bounded panel enclosing navigation buttons:
   - *Start Focus Session* (tomato clock icon, highlighted with salmon fill and dark inverted text).
   - *Habit Tracker* (clipboard checklist icon with paw mark).
   - *Journal* (open notebook icon with pencil and sparkles).
   - *Demo Mode* (pill toggle switch card showing OFF / ON).
   - *Settings* (gear icon with peeking kitten).
   - *Quit* (open door icon with exit arrow and cat silhouette).
4. **Today's Progress Panel (Right):** Large rounded panel enclosing three cards:
   - *Mascot Stat Card (Left):* Centered count "13 Pomodoros" above a large glowing tomato-cat mascot (`tomato_mascot`).
   - *Habits Card (Center Top):* Header "Habits", ratio "1/5 Done", track with filled progress and a cat-head slider (`habits_cat_head`).
   - *Daily Tip Card (Center Bottom):* Sparkle icon "✦ Daily Tip", followed by curated text: "Tip: Reflect on today's small wins in your Pawmodoro journal."
5. **Quick Journal Panel (Far Right):** Top button "🐾 Quick Journal"; bottom card listing recent notes with paw bullets and floral vine corner decorations.

### 10.2 Widget-to-Data Mapping Table

| Mockup Element | Widget / Sprite | Backing Data Source | Interaction Behavior | Layout Tier Behavior | Classification |
|---|---|---|---|---|---|
| **Header Cat Logo** | Sprite `logo_cat` | None (static art) | Clicking mascot plays happy purr/meow | Grand: 14×7 cells; Standard: 12×6; Compact: 8×4 | Decorative / Branded |
| **Spaced Title** | `title_gradient` | Static string | None | Centered / left aligned; gradient across slots 1→16 | Informative / Branded |
| **Title Sparkle** | Sprite `sparkle` / `✦` | None | None | Grand: sprite; Standard/Compact: glyph `✦` | Decorative |
| **Tagline** | Text label | Static string | None | Hidden in Compact if height < 28 | Informative |
| **Greeting Text** | Text label | `ui_greeting_get` (hour-based) | None | Full text in Grand/Standard; condensed in Compact | Informative / Live |
| **Sleeping Cat** | Sprite `sleeping_cat` | None (breathing anim) | Clicking cat triggers ear twitch | Grand: 8×4 cells; Standard: 6×3; Compact: hidden | Decorative |
| **Sidebar: Start Focus** | `wdg_button` + `icon_timer` | Timer FSM | Key `1`, Enter on focus, or Mouse click | Grand/Std: 3-row bordered; Compact: 1-row | Interactive Control |
| **Sidebar: Habits** | `wdg_button` + `icon_habits`| Habits subsystem | Key `2`, Enter on focus, or Mouse click | Grand/Std: 3-row bordered; Compact: 1-row | Interactive Control |
| **Sidebar: Journal** | `wdg_button` + `icon_journal`| Journal subsystem | Key `3`, Enter on focus, or Mouse click | Grand/Std: 3-row bordered; Compact: 1-row | Interactive Control |
| **Sidebar: Demo Toggle**| `wdg_toggle` | `[demo_mode]` variable | Key `4` or Mouse click toggles 10s demo | Grand/Std: toggle switch card; Compact: text line | Interactive Control |
| **Sidebar: Settings** | `wdg_button` + `icon_settings`| Settings subsystem | Key `5`, Enter on focus, or Mouse click | Grand/Std: 3-row bordered; Compact: 1-row | Interactive Control |
| **Sidebar: Quit** | `wdg_button` + `icon_quit` | Application exit | Key `Q`, Enter on focus, or Mouse click | Grand/Std: 3-row bordered; Compact: 1-row | Interactive Control |
| **Today's Progress** | `wdg_panel` | Container | None | Grand/Std: right panel; Compact: stacked | Layout Container |
| **Mascot Stat Card** | `wdg_stat_card` + `tomato_mascot` | `dash_pomodoros` (today's count) | None | Grand: 14×7 mascot; Std: 10×5; Compact: text only | Informative / Live |
| **Habits Card** | `wdg_progress_cat` | `habits_done_today` (`done/total`) | None | Cat head rides fill end: `done * width / total` | Informative / Live |
| **Daily Tip Card** | `wdg_tip_card` | `ui_tip_get` (day-modulo) | None | Grand/Std: framed card; Compact: clamped 1-line | Informative |
| **Quick Journal Button**| `wdg_button` | Journal prompt | Key `J` or Mouse click opens new entry directly | Grand/Std: visible; Compact: key hint `[J]` | Interactive Control |
| **Quick Journal Card** | `wdg_card` + list rows | Last 3 lines of `journal.txt` | Clicking an entry opens Journal screen | Grand: 3 entries; Std: 2 entries; Compact: hidden | Informative / Live |
| **Vine Corner Ornaments**| Sprite `ornament_vine` | None (static art) | None | Grand only; hidden in Standard and Compact | Decorative |
| **Star / Paw Ornaments**| Sprites `star`, `paw` | None (sparkle anim) | None | Grand only; hidden in Standard and Compact | Decorative |

---

## 11. Memory, Section Sizes, and ELF Budgets

### 11.1 `.bss` Runtime Memory Budget and Arithmetic
- **Current Baseline [Repo fact]:** Measured from current build (`build/pawmodoro` via `size`):
  $$\text{Current .bss} = 62,392 \text{ bytes}$$
- **Planned Growth:** Output buffer expands from 8,192 bytes to 16,384 bytes:
  $$\Delta \text{out\_buf} = 16,384 - 8,192 = +8,192 \text{ bytes}$$
- **Projected `.bss` Before New Allocations [Projection]:**
  $$62,392 + 8,192 = 70,584 \text{ bytes}$$
- **Target `.bss` Hard Cap:** **81,920 bytes (80 KiB)**.
- **Available Headroom for v3 Allocations:**
  $$81,920 - 70,584 = 11,336 \text{ bytes}$$

| Allocation Item | Size (Bytes) | Category | Description |
|---|---:|---|---|
| `out_buf` expansion | 8,192 | I/O Frame Buffer | Expanded from 8,192 to 16,384 bytes |
| `active_palette` extension | 12 | Theme Engine | Expanded from 12 to 24 bytes (slots 12–23) |
| `custom_palette` extension | 12 | Settings Engine | Expanded from 12 to 24 bytes |
| `hit_test_table` | 512 | Mouse Subsystem | 32 entries × 16 bytes (row, col, w, h, action) |
| `hit_test_count` | 4 | Mouse Subsystem | Active hitbox count dword |
| Mouse coordinates | 12 | Mouse Subsystem | `mouse_btn`, `mouse_row`, `mouse_col` (3 dwords) |
| Graphics state | 16 | Render Engine | `gfx_fg`, `gfx_bg`, `gfx_overflow`, `gfx_frame_bytes` |
| Layout state | 24 | Layout Engine | `ui_tier`, `ui_w`, `ui_h`, `margin`, `card_rects` |
| **Total Projected v3 Additions** | **8,784** | | **Well within 11,336 byte headroom** |

### 11.2 `.data` Initialized Asset Budget
All compiled sprite data, palette mapping tables, run-length sequences, and ASCII fallback strings reside in `.data`.
- **Enforcement Threshold:** Total sprite payload in `.data` MUST NOT exceed **24,576 bytes (24 KiB)**.
- **Measurement Convention:** Verified using `readelf -s build/pawmodoro.o | grep 'sprite_'` and calculating the distance from `sprite_table_start` to `sprite_table_end`.

### 11.3 ELF Binary Size Goal
- Runtime `.bss` allocation contributes to memory resident size but occupies zero disk bytes in the ELF executable.
- The compiled ELF binary target goal remains approximately **64 KiB** for stripped release builds.
- **Current Baseline [Repo fact]:**
  - Section `.text`: 27,596 bytes
  - Section `.data`: 5,911 bytes
  - Section `.bss`: 62,392 bytes (NOBITS)
  - Raw code + data payload ($27,596 + 5,911$): **33,507 bytes** (~32.7 KiB).
  - Unstripped ELF on disk with DWARF debug symbols: 115,388 bytes.

### 11.4 Exact Measurement Commands
Every implementation task MUST report actual measurements using these exact commands:
```bash
size build/pawmodoro
readelf -S build/pawmodoro
stat -c '%s bytes' build/pawmodoro
```

---

## 12. Procedure Contracts and Assembly Conventions

### 12.1 Mandatory Conventions (Restatement of PRD §6.2)
1. **Calling Convention:** Arguments passed in registers as documented. Return values in `EAX`. Callee MUST preserve all modified registers except documented return values (push/pop).
2. **Procedure Headers:** Every procedure MUST begin with a standardized documentation header:
   ```nasm
   ;=============================================================================
   ; Procedure: module_name
   ; Purpose:   Clear, concise description of functionality.
   ; IN:        Register parameter list
   ; OUT:       Register return value list
   ; CLOBBERS:  None (or explicitly documented clobbered registers)
   ;=============================================================================
   ```
3. **Instruction Restrictions:** Plain 32-bit integer x86 instructions only. **No FPU opcodes, no SSE/AVX registers, no libc calls.**
4. **Symbolic Constants:** No raw numeric literals for syscall numbers, colors, dimensions, keys, or offsets.

### 12.2 Planned New and Changed Procedure Contracts

#### Module: `gfx.asm` (Render Core)
- `gfx_set_fg`:
  - **Purpose:** Compares requested slot against `gfx_fg`. If different, appends `ESC[38;5;<c>m` to `out_buf` and updates `gfx_fg`.
  - **IN:** `AL` = theme slot ID (0–23)
  - **OUT:** None
  - **CLOBBERS:** None
- `gfx_set_bg`:
  - **Purpose:** Compares requested slot against `gfx_bg`. If different, appends `ESC[48;5;<c>m` to `out_buf` and updates `gfx_bg`.
  - **IN:** `AL` = theme slot ID (0–23)
  - **OUT:** None
  - **CLOBBERS:** None
- `gfx_sgr_forget`:
  - **Purpose:** Invalids local color cache by setting `gfx_fg = 0xFFFF` and `gfx_bg = 0xFFFF`.
  - **IN:** None
  - **OUT:** None
  - **CLOBBERS:** None
- `gfx_fill_screen_bg`:
  - **Purpose:** Sets background to `SLOT_BG`, moves cursor to (1,1), and emits `ESC[2J` to erase screen in background color.
  - **IN:** `AL` = background slot ID (`SLOT_BG`)
  - **OUT:** None
  - **CLOBBERS:** None
- `gfx_fill_rect`:
  - **Purpose:** Fills a bounded rectangular area with a background color slot, respecting clipping.
  - **IN:** `EAX` = 1-based start row, `EBX` = 1-based frame col, `ECX` = width cells, `EDX` = height cells, `ESI` = background slot ID
  - **OUT:** None
  - **CLOBBERS:** None

#### Module: `sprite.asm` (Sprite Engine)
- `sprite_draw`:
  - **Purpose:** Renders one animation frame of a half-block sprite at designated coordinates. In ASCII mode, automatically delegates to `sprite_draw_ascii`.
  - **IN:** `ESI` = pointer to sprite asset, `EAX` = start row, `EBX` = frame-relative start col, `ECX` = frame index (0-based), `EDX` = transparent surface slot ID
  - **OUT:** None
  - **CLOBBERS:** None
- `sprite_draw_ascii`:
  - **Purpose:** Renders the ASCII-art fallback representation of a sprite.
  - **IN:** `ESI` = pointer to sprite asset, `EAX` = start row, `EBX` = frame-relative start col, `EDX` = text color slot ID
  - **OUT:** None
  - **CLOBBERS:** None
- `sprite_info`:
  - **Purpose:** Queries dimensions and metadata of a sprite asset.
  - **IN:** `ESI` = pointer to sprite asset
  - **OUT:** `EAX` = width in cells, `EBX` = height in cells, `ECX` = animation frame count
  - **CLOBBERS:** None

#### Module: `layout.asm` (Responsive Engine)
- `layout_update`:
  - **Purpose:** Queries terminal size, determines active tier (Compact, Standard, Grand), calculates `ui_w` and `margin`.
  - **IN:** None
  - **OUT:** `EAX` = active tier ID (0 = Compact, 1 = Standard, 2 = Grand)
  - **CLOBBERS:** None
- `layout_rect`:
  - **Purpose:** Returns bounding box for a designated dashboard region based on the active tier.
  - **IN:** `EAX` = region identifier (`REGION_SIDEBAR`, `REGION_MASCOT_CARD`, etc.)
  - **OUT:** `EAX` = row, `EBX` = col, `ECX` = width, `EDX` = height
  - **CLOBBERS:** None

#### Module: `term.asm` (Terminal & Mouse Extensions)
- `term_mouse_on`:
  - **Purpose:** Emits `ESC[?1000h` and `ESC[?1006h` to enable SGR mouse tracking.
  - **IN:** None
  - **OUT:** None
  - **CLOBBERS:** None
- `term_mouse_off`:
  - **Purpose:** Emits `ESC[?1006l` and `ESC[?1000l` to disable SGR mouse tracking.
  - **IN:** None
  - **OUT:** None
  - **CLOBBERS:** None
- `key_poll` (Amended):
  - **Purpose:** Non-blocking poll. If an SGR mouse event sequence is present, parses coordinates, populates `mouse_btn`, `mouse_row`, `mouse_col`, and returns `EAX = KEY_MOUSE (0x10A)`. Keyboard behavior remains identical.
  - **IN:** None
  - **OUT:** `EAX` = key code / `KEY_MOUSE` / `-1` (none)
  - **CLOBBERS:** None

---

## 13. Functional Requirements: `FR-G1` Onward

| ID | Requirement | Acceptance Criterion | Verification Method | Implementation Task | Regression Risk |
|---|---|---|---|---|---|
| **FR-G1** | PRD v3 Supersession Authority | Documentation explicitly establishes that v1/v2 remain baseline and only enumerated items are superseded; no source code modified in G0. | `git diff --name-only` confirms only permitted docs changed. | Task G0 | Low |
| **FR-G2** | Responsive Layout Tiers | Application deterministically selects Compact (<100 cols or <30 rows), Standard (≥100×30), or Grand (≥120×36). | Resize tmux to 80×24, 100×30, 120×36; assert correct tier identifier. | Task G6 | Medium (layout miscalculation) |
| **FR-G3** | Frame Width & Centering | Frame width is `min(term_cols-2, 120)`; horizontally centered via integer division. | Inspect screen capture at 80×24 (width 78), 100×30 (width 98), 120×36 (width 118 or 120). | Task G6 | Medium (off-by-one borders) |
| **FR-G4** | Half-Block Pixel Rendering | Two vertical pixels rendered per cell using `▀`, `▄`, space, and surface fill for transparent pixels. | Converted test sprite rendered in viewer; compare half-block character stream. | Task G3 | Medium (ANSI color desync) |
| **FR-G5** | Sprite Header & RLE Format | Sprite decoder reads width, even height, frame count, palette table, and validates run lengths against bounds. | Feed valid and truncated sprite streams to `sprite_draw`; assert zero buffer overruns. | Task G3 | High (decoder memory corruption) |
| **FR-G6** | ASCII Sprite Fallback | When `setting_charset = 1`, all sprites render as ASCII-art fallbacks with zero bytes $\ge \text{0x80}$. | `LC_ALL=C grep -P "[\x80-\xFF]"` on screen captures emits 0 matches. | Task G3, G4, G5 | Low |
| **FR-G7** | Extended 24-Slot Theme Model | Exactly 24 slots defined; slots 0–11 match v2; slots 12–23 provide background, surfaces, and art slots. | `grep NUM_SLOTS src/constants.inc` equals 24; color editor accesses both groups. | Task G2 | Medium (theme desync) |
| **FR-G8** | Cat Coat Presets | Six coat presets override slots 18–23 without mutating interface slots or corrupting base theme. | Cycle coats in Settings; assert fur slots update and interface slots remain identical. | Task G2 | Low |
| **FR-G9** | `settings.dat` v2 Layout | Exact 48-byte layout with magic `PAWS`, version 2, 24-slot palette, mouse, and coat settings. | `stat -c %s settings.dat` equals 48; offsets match §6.1. | Task G2 | High (settings truncation) |
| **FR-G10** | Backward-Compatible v1 Migration | Valid 24-byte v1 settings file loads correctly with default coat/mouse, and migrates to 48 bytes on save. | Seed 24-byte v1 file; run app; save; assert file upgraded to 48 bytes. | Task G2 | High (user settings loss) |
| **FR-G11** | Corrupt Settings Fallback | Truncated, oversized, bad-magic, or out-of-range settings files safely fall back to defaults. | Seed bad variants; assert app boots to defaults with zero crashes. | Task G2 | Medium |
| **FR-G12** | Approved Glyph Set & Emoji Ban | UI uses only approved UTF-8 glyphs; zero emoji characters emitted in any application screen. | Audit screen output with regex; assert zero emoji codepoints. | Task G5 | Low |
| **FR-G13** | 16,384-Byte Output Buffer | `OUT_BUF_SIZE = 16384` in `.bss`; `buf_char` tracks capacity and sets `gfx_overflow` on overflow. | Inspect `.bss` allocation; trigger overflow in unit test and assert flag set. | Task G1 | High (buffer overflow) |
| **FR-G14** | Buffer Overflow Invariant | Frame construction never emits corrupted/partial frame upon buffer overflow; exactly one write per valid frame. | Scripted stress test with 140×50 screen; verify zero writes $> 16384$ bytes. | Task G1 | High |
| **FR-G15** | Local Color-Escape Skipping | `gfx_set_fg`/`gfx_set_bg` skip escape output when requested color matches tracked state; local forget on boundary. | `strace` write byte count of sprite render; verify repeated colors emit 1 cell byte. | Task G1 | Medium |
| **FR-G16** | Background Surface Painting | Full redraw paints terminal with `SLOT_BG` background erase; panels filled via `gfx_fill_rect`. | Visual inspection of tmux pane background; no terminal-default background visible. | Task G1 | Low |
| **FR-G17** | Dashboard Visual Parity | Main menu accurately renders sidebar, mascot stat card, habits bar, tip, and quick journal per reference mockup. | Human comparison of 120×36 screenshot against `docs/reference/reference_home_page.jpg`. | Task G7 | High (layout deviation) |
| **FR-G18** | Widget Data Binding | Dashboard widgets bind to real live counters (`dash_pomodoros`, `habits_done_today`, journal lines). | Check in a habit or finish focus session; assert dashboard counters increment. | Task G7 | Medium |
| **FR-G19** | Mouse Click Reporting | SGR mouse mode enabled at startup, disabled on exit; left clicks dispatched to hit-test actions. | Send SGR click sequence via `tmux send-keys`; assert target button activates. | Task G13 | High (terminal left in mouse mode) |
| **FR-G20** | Mouse Exit Cleanup | Mouse mode tracking unconditionally disabled on normal quit, Ctrl+C, or fatal error exit. | Quit app; verify terminal shell does not echo raw mouse escape sequences. | Task G13 | Critical (broken user terminal) |
| **FR-G21** | Memory Budget Compliance | `.bss` size remains $\le \text{81,920 bytes}$; `.data` sprite payload $\le \text{24,576 bytes}$. | `size build/pawmodoro` and readelf inspection against documented caps. | Task G14 | High (memory bloat) |
| **FR-G22** | Smoke Suite Repair | Five defective smoke scenarios (21, 27, 29, 30, 31) and `grep -P` checks repaired and passing. | `bash tests/smoke.sh` passes all scenarios under automated verification. | Task G14 | Medium |

---

## 14. Existing Tests, Smoke Checks, and `TEST_PLAN.md` Impact

### 14.1 Inventory of Test Assumptions Requiring v3 Updates
1. **Frame Boundary Assertions:** Existing smoke checks (Scenario 16, Scenario 28) and `overflow_check()` in `tests/smoke.sh` assume a maximum frame width of 79 columns (`length($0)>79`) or 100 columns. These must be updated for the 120-column maximum in the Grand tier.
2. **Settings Fixture Size:** Existing tests in Scenario 17, 23, and 24 assert `stat -c %s settings.dat == 24`. These must be updated to expect 48 bytes for Version 2, while adding test cases that verify loading of legacy 24-byte Version 1 files.
3. **Menu Item Numbering & Layout:** Main menu tests currently search for `[1] Start focus session` through `[5] Settings`. v3 dashboard sidebar layout changes text strings and adds button icons.

### 14.2 Detailed Investigation of the Five Suspect Smoke Checks
Direct inspection of `tests/smoke.sh` confirms five defective scenarios that pass vacuously or rely on flawed logic:

1. **Scenario 21 (Animation Throttle & Reduce Motion 0 Idle Writes):**
   - *Defect:* Lines 707–714 execute `rm -f "$ANIM_LOG"` while `strace` is actively writing to that file path. In Linux, deleting an open file removes the directory entry while the process continues writing to the unlinked inode. The subsequent bash check `if [ -f "$ANIM_LOG" ]` evaluates to FALSE, causing the script to unconditionally set `IDLE_WRITES=0`.
   - *Required Repair (Task G14):* Do not delete the active log file. Record the file line count or byte offset prior to the idle sleep window, and measure only newly appended lines.
2. **Scenario 27 (Strict 7-Bit ASCII Mode Purity):**
   - *Defect:* Lines 1001–1006 construct a `settings.dat` fixture using Python:
     `magic = b'PAWM'; data = magic + bytes([2,0,0,0, ...])` (total 28 bytes).
     The loader strictly checks `magic == 'PAWS'` (0x53574150), `version == 1`, and `length == 24`. Because magic is `'PAWM'`, the loader rejects the file and falls back to ALL DEFAULTS (`DEFAULT_CHARSET = 0`, UTF-8 mode!). The test intended to test ASCII mode but actually ran in UTF-8 mode. Furthermore, `grep -P "[\x80-\xFF]"` without `LC_ALL=C` fails to reliably detect non-ASCII bytes in UTF-8 locales.
   - *Required Repair (Task G14):* Write a valid settings fixture with magic `PAWS`, valid version, and valid size. Enforce `LC_ALL=C` when scanning for bytes $\ge \text{0x80}$.
3. **Scenario 29 (Reduce Motion Persistence & 0 Idle Writes):**
   - *Defect:* Lines 1120–1125 write a fixture with magic `'PAWM'` and 28 bytes length, which the loader rejects, falling back to default (`anim = 1`, animations ON!). Then lines 1134–1140 delete `$RM_LOG` while `strace` is running, exactly as in Scenario 21, guaranteeing `RM_WRITES=0`.
   - *Required Repair (Task G14):* Use valid magic and length for settings, and compute delta writes without unlinking the active strace log.
4. **Scenario 30 (Sound Disabled Subprocess Check):**
   - *Defect:* Lines 1163–1168 write a fixture with magic `'PAWM'`. The loader rejects it and falls back to defaults (`DEFAULT_SOUND = 0`). The test passes by accident because sound happens to be disabled by default.
   - *Required Repair (Task G14):* Use valid magic `PAWS` and valid v2 file layout.
5. **Scenario 31 (Missing Player Degradation):**
   - *Defect:* Lines 1216–1221 write a fixture with magic `'PAWM'`, attempting to set `sound = 1`. The loader rejects it, falling back to `DEFAULT_SOUND = 0` (Sound OFF!). The test claims to verify missing player degradation with sound enabled, but sound was completely disabled.
   - *Required Repair (Task G14):* Use valid magic `PAWS` and valid v2 file layout with `sound = 1`.

---

## 15. Implementation Traceability and Task Dependencies

### 15.1 Task Traceability Matrix

| Task ID | Task Scope | Primary Deliverables | Preceding Dependencies |
|---|---|---|---|
| **G0** | Specification & Reference Asset Guide | `docs/PRD_V3.md`, `docs/reference/README.md`, `docs/notes/G0.md` | Baseline v1/v2 |
| **G1** | Render Core | 16 KB `out_buf`, `gfx_set_fg/bg`, `gfx_fill_screen_bg`, `gfx_fill_rect`, overflow tracking | G0 |
| **G2** | Theme v2 & Settings v2 | 24 theme slots, coat presets, `settings.dat` v2 layout & migration | G1 |
| **G3** | Sprite Engine & Tooling | `sprite_draw`, RLE decoder, ASCII fallback, `tools/png2sprite.py`, sprite viewer | G1, G2 |
| **G4** | Art Pack A (Cats & Mascots) | Sprites: `logo_cat`, `tomato_mascot`, `sleeping_cat`, `habits_cat_head`, timer cats | G3 |
| **G5** | Art Pack B (Icons, Digits, Ornaments) | Sidebar icons, big digits, toggle switches, vines, stars, paws | G3 |
| **G6** | Layout Engine & Widget Library | Tiers (Compact/Std/Grand), `layout_rect`, `wdg_panel`, `wdg_button`, `wdg_card` | G4, G5 |
| **G7** | Dashboard (Main Menu) | Full reference dashboard composition matching mockup, widget data binding | G6 |
| **G8** | Timer Scene Redesign | Big countdown digits, scene cats (work/break), segmented progress bar | G7 |
| **G9** | Habits Screen Redesign | Habit card rows, cat-head progress bar, stamp checkmarks, streak flame | G7 |
| **G10** | Journal Screen Redesign | Notebook style, date chips, wrapped text cards, styled delete confirm | G7 |
| **G11** | Settings & Color Editor | Two-column preferences window, live preview panel, 24-slot color editor | G7 |
| **G12** | Animation v3 | Cat blink/breathing, title shimmer, star twinkles, confetti burst | G8–G11 |
| **G13** | Mouse Support | SGR mouse reporting, `KEY_MOUSE`, hit-test dispatch, Settings toggle | G7–G11 |
| **G14** | Integration & Stabilization | Repair suspect smoke tests, 30+ new test cases in `TEST_PLAN.md`, screenshots | G12, G13 |
| **G15** | Documentation Sync | Update `README.md`, `docs/CHAPTER3_DRAFT.md`, audit code comments | G14 |

---

## 16. Known Limitations, Visual Review Protocols, and Open Decisions

1. **Resolution Approximation:** Terminal half-block cells cannot represent micro-pixel details (sub-pixel anti-aliasing, soft drop-shadow blurs). These are approximated using 256-color ramps and shading glyphs (`░▒▓`).
2. **Terminal Emulator Font Dependency:** Pixel art relies on terminal character cells having an aspect ratio of approximately 1:2 (width to height). Fonts with non-standard cell ratios may cause sprites to appear vertically stretched or squashed.
3. **Visual Verification Protocol:** Automated headless tests (`tests/smoke.sh`) verify state machines, byte-level output, and buffer safety. Visual aesthetics MUST be verified by a human reviewer comparing screenshots captured at **80×24**, **100×30**, and **120×36** against `docs/reference/reference_home_page.jpg`.
4. **Mouse Coordinate Translations:** Under nested tmux sessions or non-standard terminal multiplexers, SGR mouse coordinate reporting requires verification that client terminal offsets match internal `term_cols`/`term_rows` cache.
