# G3: Sprite Engine, Authoring Pipeline, and Hidden Sprite Viewer

**Task Identifier:** `G3-sprite-engine`  
**Date:** October 26, 2026  
**Audience:** University Course Evaluator & Senior Engineering Reviewer  

---

## 1. Summary

Task G3 implements the v3 Sprite Engine, sprite authoring pipeline, and hidden development sprite viewer for Pawmodoro, completing the visual and low-level asset requirements defined in PRD v3 §4, §5, §10, and §12.2.

Key deliverables completed:
- **Canonical NASM Sprite Macros:** Standardized descriptor definitions (`SPRITE_BEGIN`, `SPRITE_PALETTE`, `SPRITE_RLE`, `SPRITE_FRAME_END`, `SPRITE_ASCII_BEGIN`, `SPRITE_ASCII_LINE`, `SPRITE_END`) in `src/sprites.asm`.
- **Runtime Sprite Engine:** On-the-fly RLE stream decoding, half-block (`▀` / `▄`) compositing supporting all five transparent/opaque cell rendering combinations, full 4-edge and 4-corner clipping, bounded rectangular erasure (`sprite_erase`), metadata query (`sprite_info`), and strict 7-bit ASCII fallback (`sprite_draw_ascii`) in `src/sprite.asm`.
- **Theme & Coat Slot Indirection:** Transparent palette-to-theme-slot mapping allowing runtime recoloring across all 7 built-in themes and 7 cat-coat presets without modifying sprite binary data.
- **Single-Write Frame Flush:** Complete integration into Pawmodoro's 16,384-byte output buffer (`out_buf`), with zero independent `sys_write` syscalls per frame and automatic SGR cache synchronization via `gfx_sgr_forget`.
- **Authoring Pipeline (`tools/png2sprite.py`):** Standalone Python 3 / Pillow development CLI tool converting PNG images into canonical NASM sprite definitions, producing deterministic luminance ASCII representations, generating 1:1 half-block PNG previews, and providing an automated 18/18 test suite.
- **Reference Test Sprite:** Real crop of the Pawmodoro cat mascot (`docs/reference/sprites/logo_cat_crop.png`) converted to a 20×10 terminal cell (20×20 pixel) sprite, consuming only 423 bytes of RLE data and 646 bytes total binary data.
- **Hidden Development Viewer:** Interactive viewer accessible from the main menu via `Ctrl+V`, supporting sprite selection, frame stepping, theme cycling, coat cycling, ASCII fallback toggle, fill-slot switching, edge/corner clipping verification, and clean menu restoration via `Escape`.

---

## 2. Files Changed (Allowlist Scope)

Only permitted files within the exact task allowlist were modified or created:

| File Path | Status | Rationale & Changes Made |
|---|---|---|
| `src/sprite.asm` | Created | Core sprite rendering engine, RLE decoder, half-block cell compositor, ASCII fallback renderer, `sprite_info`, `sprite_erase`, clipping helpers, and hidden viewer loop and frame renderer. |
| `src/sprites.asm` | Created | Canonical NASM sprite definition macros, converted test sprite (`sprite_logo_cat`), and `sprite_table`. |
| `src/constants.inc` | Modified | Added `KEY_CTRL_V` (22), `SPRITE_VIEWER_ENABLED` (1), `STATE_VIEWER` (6), `SPRITE_MAX_PALETTE` (15), `SPRITE_FRAME_END_SENTINEL` (0), and UTF-8 half-block byte constants (`GLYPH_HALF_TOP_B1..B3`, `GLYPH_HALF_BOT_B1..B3`). |
| `src/main.asm` | Modified | Included `src/sprites.asm` and `src/sprite.asm`; added `KEY_CTRL_V` dispatch from the main menu loop. |
| `tools/png2sprite.py` | Created | Development-only PNG to NASM sprite converter with CLI, Pillow image processing, Euclidean palette quantization, run splitting, ASCII generation, and half-block preview generation. |
| `docs/reference/sprites/logo_cat_crop.png` | Created | Converted test sprite source image (472×380 px, transparent background) derived directly from the logo cat crop. |
| `tests/smoke.sh` | Modified | Added Scenario 35 testing sprite viewer entry (`Ctrl+V`), theme/coat cycling, strict ASCII mode purity, corner clipping, and clean return to menu. |
| `tests/TEST_PLAN.md` | Modified | Added test cases TC-136 through TC-142 and mapped Check 35 to the automated test suite. |
| `docs/notes/g3-sprite-engine.md` | Created | This engineering task report. |

No other files (such as PRDs, Chapter 3 drafts, data formats, or existing reference assets) were modified.

---

## 3. Build Status

The project compiles cleanly in 32-bit Linux x86 assembly using NASM and GNU Binutils `ld`, with zero compiler warnings and zero linker errors:

```bash
make clean
make
```

Output:
```
rm -rf build/
mkdir -p build
nasm -f elf32 -g -F dwarf -Wall src/main.asm -o build/pawmodoro.o
ld -m elf_i386 build/pawmodoro.o -o build/pawmodoro
```

Verification of binary architecture:
```bash
file build/pawmodoro
# build/pawmodoro: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), statically linked
```

---

## 4. Test Instructions

### Running the Application and Accessing the Viewer

1. Launch Pawmodoro in an 80×24 terminal (or tmux):
   ```bash
   ./build/pawmodoro
   ```
2. From the main menu, press **`Ctrl+V`** to enter the hidden Sprite Viewer.
3. Controls inside the Sprite Viewer:

| Key | Action | Description |
|---|---|---|
| `Left` / `Right` | Sprite Selection | Select previous or next sprite in `sprite_table` (safely clamped). |
| `Up` / `Down` | Frame Stepping | Select previous or next animation frame (safely clamped to total frames). |
| `T` | Cycle Theme | Cycle active theme across all 7 built-in themes (0..6), immediately recoloring UI and mapped sprite slots. |
| `C` | Cycle Coat | Cycle cat coat across all 7 presets (0..6), immediately recoloring fur art slots (`SLOT_FUR`, `SLOT_FUR_SHADE`, `SLOT_FUR_STRIPE`). |
| `A` | Toggle ASCII Mode | Toggle between UTF-8 half-block rendering and strict 7-bit ASCII fallback. |
| `+` / `-` | Change Fill Slot | Cycle background fill slot used for transparent sprite pixels (e.g. `SLOT_SURFACE`, `SLOT_SURFACE_ALT`, `SLOT_BG`). |
| `1` – `9` | Edge Clipping Test | Move sprite to Center (`5`), Top (`8`), Bottom (`2`), Left (`4`), Right (`6`), or Corners (`7`=Top-Left, `9`=Top-Right, `1`=Bottom-Left, `3`=Bottom-Right) to verify edge clipping. |
| `Esc` | Exit Viewer | Cleanly exit sprite viewer and return to the main menu without state corruption. |

---

## 5. Converter Instructions (`tools/png2sprite.py`)

### Requirements
- Python 3.8+
- Pillow (`pip install Pillow`)

### Command-Line Interface
```bash
python3 tools/png2sprite.py --help
```

Arguments:
- `image`: Path to input PNG image or horizontal/vertical animation strip.
- `--width`: Target width in terminal cells (columns).
- `--height`: Target height in terminal cells (rows). Pixel height is automatically `2 * height`.
- `--mapping`: Path to JSON file defining slot mappings and reference RGB colors.
- `--name`: Assembly symbol name for the sprite descriptor (e.g., `sprite_logo_cat`).
- `--output`: Output `.asm` file path.
- `--preview`: (Optional) Output path for half-block rendered PNG preview.
- `--frames`: (Optional) Number of animation frames (default: 1).
- `--direction`: (Optional) Frame strip direction (`horizontal` or `vertical`).
- `--test`: Run internal unit test suite (18 unit tests).

### Slot-Mapping JSON Format
```json
{
  "theme_slots": {
    "18": {"name": "SLOT_FUR", "ref_rgb": [214, 150, 90]},
    "19": {"name": "SLOT_FUR_SHADE", "ref_rgb": [180, 110, 60]},
    "20": {"name": "SLOT_FUR_STRIPE", "ref_rgb": [140, 80, 40]},
    "21": {"name": "SLOT_EAR_BLUSH", "ref_rgb": [240, 160, 180]},
    "22": {"name": "SLOT_OUTLINE", "ref_rgb": [40, 30, 30]},
    "23": {"name": "SLOT_EYE_NOSE", "ref_rgb": [255, 215, 0]}
  }
}
```

### Exact Command Used to Generate Test Sprite
```bash
python3 tools/png2sprite.py \
  docs/reference/sprites/logo_cat_crop.png \
  --width 20 \
  --height 10 \
  --mapping tools/logo_cat_map.json \
  --name sprite_logo_cat \
  --output src/sprites.asm \
  --preview preview_logo_cat.png
```

---

## 6. Procedure Contracts & Register Preservation

All procedures adhere strictly to PRD §6.2: every register is preserved (`CLOBBERS none`) unless documented as a return value.

### 6.1 `sprite_draw`
- **Location:** `src/sprite.asm`
- **Purpose:** Decodes RLE pixel stream on the fly and renders a sprite frame using half-block terminal cells, resolving palette indices to theme slots.
- **IN:**
  - `ESI` = pointer to sprite descriptor
  - `EAX` = destination row (1-indexed screen row)
  - `EBX` = destination column (1-indexed screen column)
  - `ECX` = frame index (0-based)
  - `EDX` = transparent-fill background theme-slot ID
- **OUT:** None
- **CLOBBERS:** None (preserves `EAX`, `EBX`, `ECX`, `EDX`, `ESI`, `EDI`, `EBP`, `EFLAGS`)

### 6.2 `sprite_draw_ascii`
- **Location:** `src/sprite.asm`
- **Purpose:** Renders the sprite's readable ASCII-art variant as ordinary text, emitting strictly bytes `< 0x80` with theme-slot coloring and clipping.
- **IN:**
  - `ESI` = pointer to sprite descriptor
  - `EAX` = destination row
  - `EBX` = destination column
  - `ECX` = frame index
  - `EDX` = transparent-fill background theme-slot ID
- **OUT:** None
- **CLOBBERS:** None

### 6.3 `sprite_info`
- **Location:** `src/sprite.asm`
- **Purpose:** Reads metadata from canonical sprite descriptor and computes cell dimensions.
- **IN:**
  - `ESI` = pointer to sprite descriptor
- **OUT:**
  - `EAX` = width in terminal cells
  - `EBX` = height in terminal cells (`pixel_height / 2`)
  - `ECX` = frame count
- **CLOBBERS:** `EAX`, `EBX`, `ECX` (preserves `ESI`, `EDX`, `EDI`, `EBP`, `EFLAGS`)

### 6.4 `sprite_erase`
- **Location:** `src/sprite.asm`
- **Purpose:** Overwrites the sprite's rectangular cell boundary with spaces filled with caller-supplied background slot, respecting frame clipping.
- **IN:**
  - `ESI` = pointer to sprite descriptor
  - `EAX` = destination row
  - `EBX` = destination column
  - `EDX` = background theme slot ID
- **OUT:** None
- **CLOBBERS:** None

### 6.5 Internal Helper Procedures
- `sprite_clip_rect`: Calculates clipped row and column ranges against `ui_w` and `ui_h`.
  - `IN: EAX=row, EBX=col, ECX=w, EDX=h | OUT: clipped ranges | CLOBBERS: none`
- `sprite_locate_frame`: Walks RLE stream using frame sentinel (`0x00`) to locate requested frame index.
  - `IN: ESI=descriptor, ECX=frame_idx | OUT: ESI=frame RLE ptr | CLOBBERS: ESI, ECX`
- `sprite_emit_cell`: Emits one half-block cell (`▀`, `▄`, or space) with resolved foreground/background theme slots.
  - `IN: top_slot, bot_slot, fill_slot | OUT: none | CLOBBERS: none`
- `sprite_viewer_run`: Main event and input-dispatch loop for the hidden sprite viewer.
  - `IN: none | OUT: none | CLOBBERS: none`
- `sprite_viewer_draw`: Full-screen frame composer for the sprite viewer.
  - `IN: none | OUT: none | CLOBBERS: none`

---

## 7. Resource Measurements & Memory Budgets

| Metric | Budget / Limit | Measured Actual | Status |
|---|---|---|---|
| `sprite_logo_cat` RLE Data | < 6,144 bytes (6 KiB) | **423 bytes** | PASS (93.1% under budget) |
| `sprite_logo_cat` Total Descriptor | — | **646 bytes** | PASS |
| Combined `.data` Section | < 24,576 bytes (24 KiB) | **8,505 bytes** | PASS (65.4% under budget) |
| Output Buffer Capacity (`out_buf`) | 16,384 bytes | **16,384 bytes** | PASS |
| Total `.bss` Section | < 81,920 bytes (80 KiB) | **70,616 bytes** | PASS (13.8% under budget) |
| Binary Code Size (`.text`) | — | **35,888 bytes** | PASS |
| Total ELF Binary Size | — | **45,396 bytes** | PASS |

---

## 8. Verification Results

### 8.1 Automated Regression Testing (`tests/smoke.sh`)
All 35 end-to-end integration scenarios passed with zero failures:
```
SMOKE TEST RESULTS: 35 passed, 0 failed
```
Specifically, **Scenario 35** confirmed:
- Entry to hidden viewer via `Ctrl+V` from main menu.
- Verification of viewer title and sprite metadata display.
- Theme cycling (`T` -> Matcha Latte).
- Cat-coat cycling (`C` -> Gray Tabby).
- ASCII fallback toggle (`A` -> ASCII Fallback mode).
- Strict 7-bit ASCII verification (zero bytes $\ge 0x80$).
- Fill slot cycling (`+` -> `SLOT_SURFACE_ALT`).
- Corner clipping verification (`7` -> Top-Left Corner Clipped).
- Clean exit via `Escape` restoring main menu and exit code 0.

### 8.2 Single `sys_write` Per Frame
Verified under `strace -e trace=write`:
- Menu frame: 1 `sys_write` (~1,540 bytes).
- Sprite viewer frame: exactly 1 `sys_write` (~2,400 to 2,600 bytes).
- Zero intermediate writes from individual cells, rows, or glyphs.
- `gfx_frame_bytes` safely within 16,384-byte `out_buf` capacity.

### 8.3 Instruction Set & Purity Inspection
- Disassembly check (`objdump -d build/pawmodoro | grep -E '\bfld|\bfst|\bfadd|\bfsub|\bfmul|\bfdiv|\bxmm|\bymm|\bzmm'`) confirmed **zero** FPU, MMX, SSE, AVX instructions.
- Statically linked, direct Linux syscalls (`int 0x80`), **zero** libc dependencies.

### 8.4 Clipping Verification
Verified across all 8 peripheral positions:
- Top Edge (`8`): Clipped against row 1 without scroll corruption.
- Bottom Edge (`2`): Clipped against `ui_h` without terminal overscroll.
- Left Edge (`4`): Clipped against column 1.
- Right Edge (`6`): Clipped against `ui_w`.
- Top-Left Corner (`7`), Top-Right (`9`), Bottom-Left (`1`), Bottom-Right (`3`): All clip safely on both axes simultaneously.

---

## 9. Captured Terminal Screenshots

Screen captures were recorded at all three target tier dimensions in `scratch/screenshots/`:

1. **Compact Tier (80×24):**
   - Main Menu: `scratch/screenshots/menu_compact_80x24.txt`
   - Sprite Viewer (Half-Block UTF-8): `scratch/screenshots/viewer_compact_80x24.txt`
   - Sprite Viewer (Recolored Theme/Coat): `scratch/screenshots/viewer_recolor_compact_80x24.txt`
   - Sprite Viewer (ASCII Fallback): `scratch/screenshots/viewer_ascii_compact_80x24.txt`
   - Menu Restored on Exit: `scratch/screenshots/menu_restored_compact_80x24.txt`

2. **Standard Tier (100×30):**
   - Main Menu: `scratch/screenshots/menu_standard_100x30.txt`
   - Sprite Viewer (UTF-8): `scratch/screenshots/viewer_standard_100x30.txt`
   - Sprite Viewer (Recolored): `scratch/screenshots/viewer_recolor_standard_100x30.txt`
   - Sprite Viewer (ASCII): `scratch/screenshots/viewer_ascii_standard_100x30.txt`
   - Menu Restored on Exit: `scratch/screenshots/menu_restored_standard_100x30.txt`

3. **Grand Tier (120×36):**
   - Main Menu: `scratch/screenshots/menu_grand_120x36.txt`
   - Sprite Viewer (UTF-8): `scratch/screenshots/viewer_grand_120x36.txt`
   - Sprite Viewer (Recolored): `scratch/screenshots/viewer_recolor_grand_120x36.txt`
   - Sprite Viewer (ASCII): `scratch/screenshots/viewer_ascii_grand_120x36.txt`
   - Menu Restored on Exit: `scratch/screenshots/menu_restored_grand_120x36.txt`

---

## 10. Known Issues & Limitations

1. **Terminal Font Aspect Ratio:** Terminal cells typically have an aspect ratio of approximately 1:2 (width:height). Using half-blocks (`▀` / `▄`) pairs two vertical pixels into one character cell, producing a square 1:1 pixel grid. Depending on the terminal font, vertical proportions may vary slightly compared to graphical bitmapped displays.
2. **Monochrome ASCII Precision:** ASCII fallback mode represents the sprite using printable characters (`#`, `%`, `@`, `=`, `_`, `~`, `.`). While silhouette and features remain recognizable, luminance mapping cannot achieve the color fidelity of 256-color half-block rendering.

---

## 11. Visual Differences from Dashboard Reference

Compared against `docs/reference/target-dashboard.png`:
- The sprite viewer isolates individual sprites for asset inspection, authoring verification, and recoloring testing, whereas the target dashboard composites the cat mascot within the full Pomodoro timer panel.
- Color slots accurately match the dark warm ambiance of Strawberry Milk (Theme 0) and the tabby fur palette (`SLOT_FUR=216`, `SLOT_FUR_SHADE=173`, `SLOT_OUTLINE=233`).

---

## 12. Image Access Disclosure

- **Inspection Status:** The reference dashboard image (`docs/reference/target-dashboard.png`) and existing sprite crops (`docs/reference/sprites/logo_cat.png`, `tomato_mascot.png`) were **directly inspected** using image inspection tools and Pillow.
- **Crop Provenance:** An isolated, transparent crop (`docs/reference/sprites/logo_cat_crop.png`, 472×380 px, even height) was generated directly from the authentic mascot asset to provide clean alpha=0 transparency for accurate background fill testing.

---

## 13. Concise Status Statement

- **Build:** Built cleanly (`make` warning-free, 32-bit ELF, no libc, no FPU/SSE).
- **Test:** Run `bash tests/smoke.sh` (35 passed, 0 failed). Launch `./build/pawmodoro` and press `Ctrl+V` from the menu.
- **Known Issues:** None; terminal font cell proportions govern half-block aspect ratio.
- **Reference Differences:** Viewer is an isolated development inspection surface rather than the composite dashboard panel.
