# Pawmodoro v3 — Sprite Asset Preparation & Reference Guide

**Document Purpose:** Practical, engineering-grounded guide for human asset preparation, sprite cropping, color mapping, and conversion for Pawmodoro v3.  
**Target Milestone:** Tasks G3, G4, and G5 (Sprite Engine and Art Packs).  
**Source Visual Reference:** `docs/reference/reference_home_page.jpg` (referred to as `docs/reference/target-dashboard.png` in roadmap; 1,858,686 bytes).  
**Target Crop Storage Directory:** `docs/reference/sprites/`.  

---

## 1. Asset Philosophy and Architecture

### 1.1 Why Reference Crops Are Mandatory
In terminal user interfaces, generating visually cohesive pixel art by algorithmic guessing or generative text prompts invariably leads to disjointed styles, inconsistent color palettes, mismatched outlines, and misaligned cell boundaries. The visual source of truth for Pawmodoro v3 is the reference dashboard mockup (`docs/reference/reference_home_page.jpg`).

Every sprite asset used in Pawmodoro v3 MUST be directly cropped or adapted from the reference mockup and stored in `docs/reference/sprites/`. This ensures that:
1. Proportions, eye styles, ear geometries, and line weights remain harmonious across all screens.
2. The mascot ("tomato-cat") and feline avatars reflect identical brand identity.
3. Every crop can be visually audited side-by-side against the original mockup before compilation.

### 1.2 Zero-Runtime-Dependency Principle
- **100% Assembly Runtime:** The compiled Pawmodoro executable contains zero Python, C runtime, or external image-decoding libraries. All sprite rendering is executed entirely by 32-bit x86 NASM instructions (`src/sprite.asm`) reading precompiled byte arrays in the `.data` section.
- **Development-Time Converter:** The image conversion utility (`tools/png2sprite.py`) is strictly an offline build tool used during development. It requires Python 3 and Pillow to parse transparent PNG crops, quantize colors, and generate formatted NASM source code. It is never invoked by the running terminal application.

### 1.3 Theme Slots and Dynamic Recoloring
Sprites do NOT embed hardcoded ANSI terminal escapes or absolute RGB values. Instead:
- Sprite binary data stores palette indices (1–15) per pixel.
- Index `0` represents a transparent pixel (filled dynamically at runtime with the caller-supplied surface color slot, such as `SLOT_SURFACE` or `SLOT_SURFACE_ALT`).
- Indices 1–15 map through a small header table to the application's 24 extended theme slots (`SLOT_FUR`, `SLOT_FUR_SHADE`, `SLOT_EAR_BLUSH`, `SLOT_OUTLINE`, `SLOT_EYE_NOSE`, etc.).
- When the user selects a new theme or cycles their Cat Coat preset (Orange Tabby, Gray Tabby, Black, White, Cream, Tuxedo), all sprites recolor instantly without regenerating binary assets.

### 1.4 ASCII Fallback Art
Every sprite format entry contains an integrated multi-line 7-bit ASCII representation. When Pawmodoro runs with `setting_charset = 1` (ASCII fallback mode):
- Half-block Unicode characters (`▀`, `▄`) are bypassed.
- The sprite engine outputs the corresponding ASCII art fallback.
- No byte $\ge \text{0x80}$ is ever emitted.

---

## 2. Technical Image Inspection Report

The visual assets in `docs/reference/` and `docs/reference/sprites/` were directly inspected using the IDE image inspection tools:

1. **`docs/reference/reference_home_page.jpg` (Full Mockup):**
   - High-resolution capture of the target GUI-style dashboard.
   - Shows window header with `logo_cat`, spaced title `P A W M O D O R O ✦`, tagline, time greeting with curled `sleeping_cat`.
   - Shows sidebar with 6 rounded bordered pill buttons with custom icons.
   - Shows "Today's Progress" with glowing tomato mascot, habits progress bar with cat-head marker, daily tip card, and quick journal card with vine corners.
2. **`docs/reference/sprites/` Existing Inventory:**
   - `Gemini_Generated_Image_dvrcb7dvrcb7dvrc.jpg`: Master sheet displaying the 10 core sprite elements with labeled captions.
   - `logo_cat.png`: 14×14 cell headshot crop with pink ears, white muzzle, tabby stripes.
   - `tomato_mascot.png`: Tomato body with cat ears, green leaf stem, cheek blush.
   - `habits_cat_head.png`: Small headshot designed as the slider marker on progress bars.
   - `sleeping_cat.png`: Curled resting cat with closed eyes.
   - `start_focus_session.png`: Tomato clock with cat ears and paw prints on clock face.
   - `habit_tracker.png`: Clipboard with checklist and paw mark.
   - `journal.png`: Open notebook with pencil and sparkles.
   - `settings.png`: Mechanical gear with small kitten peeking through center hole.
   - `quit.png`: Open door with pink exit arrow and cat walking through.
   - `sparkle.png`: 4-point stars in multi-color pastel tones.

---

## 3. Complete Sprite Asset Inventory

Every sprite asset required for Tasks G3–G12 is cataloged below. All pixel heights MUST be **even** numbers ($H_{\text{pixels}} = 2 \times H_{\text{cells}}$):

| Asset Name | Source File / Region | Intended UI Placement | Compact (W×H cells) | Standard (W×H cells) | Grand (W×H cells) | Frames | ASCII Fallback | Priority |
|---|---|---|---|---|---|---:|---|---|
| `logo_cat` | `logo_cat.png` | Main header brand avatar (left of title) | 8×4 (16 px) | 12×6 (24 px) | 14×7 (28 px) | 3 (idle, blink, ear-twitch) | 3-line ASCII cat head | **Mandatory** |
| `sleeping_cat` | `sleeping_cat.png` | Header greeting line (right of text) | Hidden | 6×3 (12 px) | 8×4 (16 px) | 2 (breathing 1, 2) | `( u.u ) zZ` | **Mandatory** |
| `tomato_mascot` | `tomato_mascot.png` | Today's Progress mascot stat card | 6×3 (12 px) | 10×5 (20 px) | 14×7 (28 px) | 4 (idle, bounce, happy, sleep) | Multi-line `(o.o)` tomato | **Mandatory** |
| `habits_cat_head`| `habits_cat_head.png` | Habits progress bar slider & timer marker | 3×2 (8 px) | 4×2 (8 px) | 4×2 (8 px) | 2 (idle, blink) | `(=^.^=)` | **Mandatory** |
| `icon_timer` | `start_focus_session.png` | Sidebar button 1 (Start Focus Session) | 4×2 (8 px) | 6×3 (12 px) | 6×3 (12 px) | 1 | `[TIMER]` | **Mandatory** |
| `icon_habits` | `habit_tracker.png` | Sidebar button 2 (Habit Tracker) | 4×2 (8 px) | 6×3 (12 px) | 6×3 (12 px) | 1 | `[LIST]` | **Mandatory** |
| `icon_journal` | `journal.png` | Sidebar button 3 (Journal) | 4×2 (8 px) | 6×3 (12 px) | 6×3 (12 px) | 1 | `[BOOK]` | **Mandatory** |
| `icon_settings`| `settings.png` | Sidebar button 5 (Settings) | 4×2 (8 px) | 6×3 (12 px) | 6×3 (12 px) | 1 | `[GEAR]` | **Mandatory** |
| `icon_quit` | `quit.png` | Sidebar button 6 (Quit) | 4×2 (8 px) | 6×3 (12 px) | 6×3 (12 px) | 1 | `[EXIT]` | **Mandatory** |
| `toggle_switch`| Mockup sidebar row 4 | Demo mode toggle switch card | 4×1 (2 px) | 6×2 (4 px) | 6×2 (4 px) | 2 (OFF, ON) | `[OFF]` / `[ON]` | **Mandatory** |
| `sparkle_star` | `sparkle.png` | Title ornament & Daily Tip badge | 2×1 (2 px) | 3×2 (4 px) | 4×2 (8 px) | 2 (twinkle 1, 2) | `*` / `✦` | **Mandatory** |
| `paw_bullet` | Mockup Quick Journal | Bullets on recent journal entries & cards | 2×1 (2 px) | 2×1 (2 px) | 3×2 (4 px) | 1 | `*` | **Mandatory** |
| `vine_corner_tl`| Mockup Quick Journal | Top-left corner decorative vine & leaves | Hidden | Hidden | 8×4 (16 px) | 1 | Plain box corner | Optional (Grand) |
| `vine_corner_br`| Mockup Quick Journal | Bottom-right corner vine & leaves | Hidden | Hidden | 8×4 (16 px) | 1 | Plain box corner | Optional (Grand) |
| `big_digits` | Generated font | Pomodoro timer countdown display (`MM:SS`) | 3×2 per digit | 5×4 per digit | 5×4 per digit | 11 (0-9, colon) | Standard text digits | **Mandatory** |
| `cat_working` | Roadmap G4 / G8 | Timer focus scene (cat at desk/laptop) | 6×3 (12 px) | 10×5 (20 px) | 14×7 (28 px) | 2 (typing, focused) | `( -.- ) [__]` | **Mandatory** |
| `cat_resting` | Roadmap G4 / G8 | Timer break scene (cat in bed with moon) | 6×3 (12 px) | 10×5 (20 px) | 14×7 (28 px) | 2 (curled, zZ) | `( u.u )  Z` | **Mandatory** |
| `cat_cheering` | Roadmap G4 / G8 | Focus completion & habit check-in pop | 6×3 (12 px) | 10×5 (20 px) | 14×7 (28 px) | 2 (arms up, happy) | `\(^.^)/` | **Mandatory** |
| `cat_surprised`| Roadmap G4 / G10 | Delete confirm dialog & error modal | 6×3 (12 px) | 8×4 (16 px) | 10×5 (20 px) | 1 | `( O.O )` | **Mandatory** |
| `cat_strolling`| Roadmap G12 | Ambient footer stroll across terminal bottom | Hidden | 6×2 (4 px) | 6×2 (4 px) | 3 (walk cycle) | `~(=^..^)` | Optional (Ambient) |

---

## 4. Planned Converter Specification (`tools/png2sprite.py`)

### 4.1 Converter Architecture (Planned for Task G3)
The converter will be a standalone Python 3 utility using Pillow:
- **Input:** A high-resolution or cleanly segmented PNG image with an alpha channel (transparency).
- **Slot Mapping Table (`.json`):** A JSON configuration specifying which source RGB values or ranges map to which application theme slots (0–23).
- **Scaling:** Uses nearest-neighbor or box-downsampling to preserve clean pixel-art edges at the target cell dimensions.
- **Run-Length Encoding:** Scans pixels row by row, pairs vertical half-blocks, aggregates repeated indices into `(count, index)` tuples, and formats them as NASM `db` directives.
- **ASCII Fallback Generation:** Generates a matched ASCII-art bounding grid containing only 7-bit ASCII characters.

### 4.2 Proposed Command-Line Interface (Target for G3)
> **NOTE:** This syntax is proposed for implementation in Task G3. Do not attempt to run this script during Task G0.

```bash
# Example syntax for converting the Tomato Mascot sprite:
python3 tools/png2sprite.py \
    --input docs/reference/sprites/tomato_mascot.png \
    --output src/sprites/tomato_mascot.inc \
    --name sprite_tomato_mascot \
    --width-cells 14 \
    --height-pixels 28 \
    --map tools/maps/tomato_mascot_map.json \
    --ascii-fallback " (\\_/)\n (o.o)\n ( > < )" \
    --preview-ascii
```

### 4.3 Validation Constraints Enforced by Converter
The converter MUST reject source inputs or abort with an error code if:
1. Target `height-pixels` is an odd number.
2. The image uses more than 15 unique palette slot mappings.
3. An unmapped color cannot be deterministically resolved to an approved theme slot.
4. The generated RLE payload exceeds the allocated sprite size threshold.
5. The output contains any non-ASCII characters in the ASCII fallback block.

---

## 5. Human Asset-Preparation Checklist

Before passing crops to the converter in Task G3–G5, the human designer must verify each crop in `docs/reference/sprites/`:

- [ ] **Transparent Background:** The background surrounding the artwork is fully transparent (Alpha = 0). There are no lingering white, gray, or black matte fringes around the outlines.
- [ ] **Tight Crop:** The bounding box is cropped closely to the sprite perimeter, with zero excess empty rows or columns on any side.
- [ ] **Even Vertical Height:** The height of the crop in pixels must correspond to an even target half-block pixel count (e.g. 16, 20, 24, 28 pixels).
- [ ] **Clean Outline:** Outlines use a consistent dark tone (`SLOT_OUTLINE`, slot 22) rather than semi-transparent anti-aliased gradations that create muddy borders when quantized.
- [ ] **Distinct Art Zones:** Fur, inner ears, cheek blush, eyes, and highlights use distinct color fills matching the extended art slots:
  - Base fur $\rightarrow$ `SLOT_FUR` (slot 18)
  - Shaded fur $\rightarrow$ `SLOT_FUR_SHADE` (slot 19)
  - Tabby stripes $\rightarrow$ `SLOT_FUR_STRIPE` (slot 20)
  - Inner ears / blush $\rightarrow$ `SLOT_EAR_BLUSH` (slot 21)
  - Outline $\rightarrow$ `SLOT_OUTLINE` (slot 22)
  - Facial details $\rightarrow$ `SLOT_EYE_NOSE` (slot 23)
- [ ] **Visual Audit:** When viewed in the future sprite viewer (`Ctrl+V`), the converted sprite is recognizable and free of noise at both 80×24 and 120×36 terminal resolutions.
