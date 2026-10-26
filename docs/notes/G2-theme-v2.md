# G2: Extended Theme Engine, Cat-Coat Presets, and Settings v2 Migration

**Task Identifier:** `G2-theme-v2`  
**Date:** October 26, 2026  
**Audience:** University Course Evaluator & Senior Engineering Reviewer  

---

## 1. Executive Summary

Task G2 extends Pawmodoro's customization and persistence architecture from a 12-color, single-version settings model to an extensible 24-slot theme engine with dedicated art slots, 7 persistent cat-coat presets, and a robust 48-byte `settings.dat` Version 2 format with transparent backward compatibility for legacy 24-byte Version 1 files.

All changes were implemented in 32-bit x86 NASM assembly (`int 0x80` Linux syscalls) adhering strictly to the PRD v3 specification without libc dependencies, without FPU/SSE, and preserving the single-`sys_write`-per-frame rendering pipeline.

---

## 2. 24-Slot Theme Architecture

### 2.1 Slot Model Expansion
The palette slot count (`NUM_SLOTS`) was expanded from 12 to 24 slots. Existing slots 0–11 retain their exact identities and legacy UI semantics. Slots 12–17 provide structured UI surface and accent tones, while slots 18–23 provide dedicated sprite/art colors.

| Slot ID | Constant Name | Category | Role & Purpose |
|:---:|:---|:---|:---|
| 0 | `SLOT_BORDER` | Interface | Main border color |
| 1 | `SLOT_TITLE` | Interface | Active title / header accent |
| 2 | `SLOT_TIMER_WORK` | Interface | Pomodoro work session timer accent |
| 3 | `SLOT_TIMER_BREAK` | Interface | Break session timer accent |
| 4 | `SLOT_TEXT_MAIN` | Interface | Primary body text |
| 5 | `SLOT_TEXT_MUTED` | Interface | Secondary / hint / dimmed text |
| 6 | `SLOT_FOCUS` | Interface | Cursor / focused row highlight |
| 7 | `SLOT_PROGRESS_FILL` | Interface | Progress bar filled cells |
| 8 | `SLOT_PROGRESS_EMPTY` | Interface | Progress bar unfilled background track |
| 9 | `SLOT_CAT_REST` | Interface | Legacy idle cat color (maintained for compatibility) |
| 10 | `SLOT_CAT_FOCUS` | Interface | Legacy working cat color |
| 11 | `SLOT_CAT_CELEBRATE` | Interface | Legacy celebration cat color |
| 12 | `SLOT_BG` | Interface | Root screen background fill |
| 13 | `SLOT_SURFACE` | Interface | Primary panel / card surface fill |
| 14 | `SLOT_SURFACE_ALT` | Interface | Alternate / nested panel surface |
| 15 | `SLOT_BORDER_FOCUS` | Interface | Focused container border highlight |
| 16 | `SLOT_TITLE_ALT` | Interface | Secondary section heading accent |
| 17 | `SLOT_TEXT_INV` | Interface | Inverted / badge text on high-contrast surfaces |
| 18 | `SLOT_FUR` | Art | Cat coat base fur tone |
| 19 | `SLOT_FUR_SHADE` | Art | Cat coat shading / underbelly tone |
| 20 | `SLOT_FUR_STRIPE` | Art | Cat coat stripe / pattern tone |
| 21 | `SLOT_EAR_BLUSH` | Art | Inner ear and cheek blush tone |
| 22 | `SLOT_OUTLINE` | Art | Cat sprite outline / contour tone |
| 23 | `SLOT_EYE_NOSE` | Art | Cat eyes, nose, and facial detail tone |

### 2.2 Built-In Themes Extension
Each of the 7 built-in themes in `themes_table` now defines all 24 ANSI 256-color palette indices (24 bytes per theme, stride 24, total 168 bytes). Every theme features dark surfaces (`SLOT_BG`, `SLOT_SURFACE`, `SLOT_SURFACE_ALT`) to ensure low eye strain:

0. **Strawberry Milk (Theme 0 - Reference Look):** Warm dark charcoal/pink ambiance matching `docs/reference/sprites/target-dashboard.png` (`SLOT_BG=234`, `SLOT_SURFACE=235`, `SLOT_SURFACE_ALT=236`, `SLOT_BORDER_FOCUS=211`, `SLOT_TITLE_ALT=218`, `SLOT_TEXT_INV=233`). Art slots configured for warm orange/cream tabby fur (216/173/137), blush (217), outline (233), eyes/nose (220).
1. **Matcha Latte (Theme 1):** Dark forest/tea background (234/235) with sage green borders (108/114/151) and cream text.
2. **Blueberry (Theme 2):** Deep midnight slate background (234/235) with icy periwinkle borders (68/75/111).
3. **Lavender Night (Theme 3):** Dark plum background (234/235) with soft violet borders (139/140/176).
4. **Sunset Peach (Theme 4):** Dark espresso background (234/235) with coral and peach accents (209/216/223).
5. **Mono Cozy (Theme 5):** Neutral warm dark gray background (234/235) with chalk white borders (246/250/252).
6. **High Contrast (Theme 6):** Pitch black background (16) with bright white, yellow, and cyan accents (15/11/14).

Both `active_palette` and `custom_palette` in `.data` were expanded from 12 bytes to 24 bytes each.

---

## 3. Cat Coat Customization & Precedence

### 3.1 Coat Presets
Pawmodoro supports 7 cat-coat configurations via the persistent `setting_coat` byte (`0..6`):

| Value | Coat Name | Fur (`18`) | Fur Shade (`19`) | Fur Stripe (`20`) | Ear Blush (`21`) |
|:---:|:---|:---:|:---:|:---:|:---:|
| 0 | Orange Tabby | 216 | 173 | 137 | 217 |
| 1 | Gray Tabby | 250 | 245 | 240 | 218 |
| 2 | Black | 237 | 234 | 232 | 240 |
| 3 | White | 255 | 252 | 248 | 218 |
| 4 | Cream | 224 | 216 | 181 | 218 |
| 5 | Tuxedo | 235 | 255 | 233 | 218 |
| 6 | Custom | User-edited values preserved in `custom_palette[18..21]` |

### 3.2 Palette Composition Precedence
In `settings_apply_palette`:
1. If the current theme is built-in (`0..6`), copy all 24 bytes from `themes_table[theme_idx * 24]` to `active_palette`. If theme is Custom (`7`), copy all 24 bytes from `custom_palette` to `active_palette`.
2. Inspect `setting_coat`:
   - If `setting_coat < COAT_CUSTOM` (0..5), override slots 18–21 (`SLOT_FUR`, `SLOT_FUR_SHADE`, `SLOT_FUR_STRIPE`, `SLOT_EAR_BLUSH`) with the corresponding 4-byte values from `coat_table[setting_coat * 4]`.
   - If `setting_coat == COAT_CUSTOM` (6), leave slots 18–21 untouched (they retain the user's customized colors from `custom_palette` or theme).
3. Slots 22 (`SLOT_OUTLINE`) and 23 (`SLOT_EYE_NOSE`) always originate from the active theme/palette and are never mutated by coat presets.
4. Changing interface slots (`0..17`) preserves `setting_coat`. Editing any art slot (`18..23`) automatically transitions `setting_coat` to 6 (`COAT_CUSTOM`).

---

## 4. Binary Persistence & Migration Architecture

### 4.1 Specification & Binary Layout
`settings.dat` Version 2 strictly adheres to PRD v3 §6. Total size is exactly 48 bytes (fixed-width binary format).

```
Offset  Size  Field                Valid Values
--------------------------------------------------------------------------------
0x00    4     Magic                ASCII 'PAWS' (0x53574150 in little-endian)
0x04    1     Version              2 (0x02)
0x05    1     Theme Index          0..7 (0..6 built-in, 7 custom)
0x06    24    Custom Palette       24 bytes (slots 0..23, each 0..255)
0x1E    1     Anim Enabled         0 or 1
0x1F    1     Sound Enabled        0 or 1
0x20    1     Charset              0 or 1
0x21    1     Notify Enabled       0 or 1
0x22    1     Notify Layers        Bitmask 0..0x1F (bits 0..4)
0x23    1     Volume               0..3 (0=Mute, 1=Low, 2=Med, 3=High)
0x24    1     Mouse Reporting      0 or 1 (default: 1)
0x25    1     Cat Coat             0..6 (default: 0 = Orange Tabby)
0x26    6     Reserved             Zeroes (must be 0)
0x2C    4     Padding              Zeroes to pad total record to 48 bytes
--------------------------------------------------------------------------------
Total: 48 bytes
```

### 4.2 Migration from Version 1
Legacy Pawmodoro installations created 24-byte Version 1 files with the following layout:
- `0x00..0x03`: Magic `'PAWS'`
- `0x04`: Version `1`
- `0x05`: Theme index (`0..7`)
- `0x06..0x11`: Custom palette (12 bytes for slots 0..11)
- `0x12`: Animation flag (`0/1`)
- `0x13`: Sound flag (`0/1`)
- `0x14`: Charset flag (`0/1`)
- `0x15`: Notification flag (`0/1`)
- `0x16`: Notification layers bitmask (`0..0x1F`)
- `0x17`: Volume level (`0..3`)

When `settings_load` reads a file of exactly 24 bytes:
1. It validates magic (`PAWS`), version (`1`), theme index (`0..7`), flags, layers, and volume.
2. It transfers the legacy theme, flags, and the 12 custom palette bytes into `custom_palette[0..11]`.
3. It initializes the remaining 12 slots (`custom_palette[12..23]`) from Theme 0 defaults.
4. It initializes `setting_mouse = 1`, `setting_coat = 0`, and clears the 6 reserved bytes.
5. It applies the active palette and coat preset deterministically.
6. The file is not immediately overwritten; on the next user-initiated settings modification, it is written out as a pristine 48-byte Version 2 file.

### 4.3 Atomic Validation & Corrupt-File Rejection
If any of the following failure conditions occur:
- File missing or unreadable (`sys_open` fails)
- File size is not exactly 24 bytes (v1) and not exactly 48 bytes (v2) (rejects truncated or oversized files)
- Magic is not `'PAWS'`
- Version is unsupported (e.g. version 0, 3, or higher)
- Theme index > 7
- Boolean flags (anim, sound, charset, notify, mouse) > 1
- Notify layers > 0x1F
- Volume > 3
- Coat index > 6
- Reserved bytes in v2 are non-zero

The file is rejected **atomically**. `settings_load` discards all partial file data, executes `settings_set_defaults`, applies default palette values, and immediately persists a clean 48-byte v2 file to restore filesystem health.

---

## 5. UI Enhancements

### 5.1 Settings Screen (`src/settings_ui.asm`)
1. **Cat Coat Selection Row:** Added at row index 2 (between `Customize colors` and `Animations`).
   - Displays label `Cat coat`.
   - Displays current coat formatted as `< Coat Name >` (e.g., `< Orange Tabby >`, `< Tuxedo >`).
   - Pressing Left/Right cycles through all 7 coat options with full wrap-around (`0 -> 6`, `6 -> 0`) and applies colors immediately.
2. **Live Placeholder Cat Sample:**
   - Displayed to the right of the Cat coat row at columns 51–56:
     ```text
     Row 7:  /\_/\
     Row 8: ( o.o )
     ```
   - Rendered using the active coat's fur color (`SLOT_FUR`) and eye color (`SLOT_EYE_NOSE`), providing immediate visual feedback without requiring complex sprite conversion.
   - Fully ASCII-compatible, strictly avoiding emojis.
3. **80x24 Dimension Safety:** The Settings menu accommodates all 8 configurable rows (Theme, Colors, Coat, Anim, Sound, Charset, Notify, Reset) without clipping or overlapping navigation hints, status bars, or border rows.

### 5.2 Color Editor Partitioning (`settings_colors_draw` & `settings_colors_handle_key`)
The 24 color slots are divided into two dedicated functional tabs:
- **Interface Group (slots 0–17):** Configures application chrome, borders, surfaces, timer states, and text. Uses a 15-row scrolling viewport to remain fully legible on 24-row terminals.
- **Art Group (slots 18–23):** Configures cat fur, shading, stripes, blush, outlines, and eyes. Displays all 6 art slots with an explanatory note and live placeholder cat sample.

**Controls:**
- `Tab`: Toggles between Interface and Art groups.
- `[`: Selects Interface group.
- `]`: Selects Art group.
- `Up` / `Down`: Navigates slots strictly clamped within the active group boundaries (Interface: 0–17; Art: 18–23).
- `Left` / `Right`: Decrements/increments selected slot's 256-color palette index by 1.
- `PgUp` / `PgDn`: Adjusts color index in steps of 16 (stepping across ANSI color cube bands).
- Modifying slots 18–23 automatically switches `setting_coat` to `Custom`.

---

## 6. Background Clearing via `SLOT_BG`

All screen-clearing and line-erasing routines in `src/ui.asm` and `src/settings_ui.asm` were audited:
- Line background fills before `ansi_erase_eol` emit `ui_bgcolor(SLOT_BG)`.
- Full-screen clearing during resize recovery (`ui_layout_update`, `ui_draw_menu`, `ui_size_gate`) emits `ui_bgcolor(SLOT_BG)` prior to `ansi_clear` / `ansi_erase_eos`.
- Below-frame terminal areas are filled with `SLOT_BG`.
- Clean terminal reset sequence (`\x1b[0m\x1b[2J\x1b[H\x1b[?25h`) remains intact on normal exit, error exits, and Ctrl+C interrupts.

---

## 7. Procedure Contracts (IN / OUT / CLOBBERS)

All modified and newly introduced procedures maintain rigorous calling conventions:

### `settings_load` (`src/settings.asm`)
- **IN:** None (reads `settings.dat` from current working directory via Linux `int 0x80` `sys_open`).
- **OUT:** EAX = 0 on success, EAX = -1 on file error/fallback; settings state in `.data` fully initialized to file contents or defaults.
- **CLOBBERS:** EAX, EBX, ECX, EDX, ESI, EDI.

### `settings_save` (`src/settings.asm`)
- **IN:** None (reads settings state from `.data`).
- **OUT:** EAX = 0 on success, EAX = -1 on write error; writes exactly 48 bytes via `file_save`.
- **CLOBBERS:** EAX, EBX, ECX, EDX, ESI, EDI.

### `settings_set_defaults` (`src/settings.asm`)
- **IN:** None.
- **OUT:** Restores default settings state (theme 0, anim 1, sound 1, charset 1, notify 1, volume 2, mouse 1, coat 0, reserved 0) and copies 24 bytes of Theme 0 to `custom_palette` and `active_palette`.
- **CLOBBERS:** EAX, ECX, ESI, EDI.

### `settings_apply_palette` (`src/settings.asm`)
- **IN:** Active theme index and `setting_coat` in memory.
- **OUT:** Populates 24-byte `active_palette` with active theme colors, applying coat preset overrides (slots 18–21) if coat < 6.
- **CLOBBERS:** EAX, EBX, ECX, EDX, ESI, EDI.

### `settings_apply_slot_color` (`src/settings_ui.asm`)
- **IN:** Current slot selection in `settings_color_slot`, new color value in DL.
- **OUT:** Updates `custom_palette[slot]`, sets theme to Custom (7), sets coat to Custom (6) if slot >= 18, reapplies palette.
- **CLOBBERS:** EAX, EBX, ECX, EDX, ESI, EDI.

### `settings_draw` (`src/settings_ui.asm`)
- **IN:** `term_cols`, `term_rows`, active settings in memory.
- **OUT:** Formats entire 8-row Settings screen and live cat sample into single-frame output buffer.
- **CLOBBERS:** EAX, EBX, ECX, EDX, ESI, EDI.

### `settings_colors_draw` (`src/settings_ui.asm`)
- **IN:** `term_cols`, `term_rows`, `settings_color_group`, `settings_color_slot`.
- **OUT:** Formats 2-group color editor, 16x16 swatch grid, and slot list into output buffer.
- **CLOBBERS:** EAX, EBX, ECX, EDX, ESI, EDI.

---

## 8. Test Execution & Verification Results

### 8.1 Automated Suite
The test suite was run inside the target Linux x86 environment:

```sh
wsl make clean && wsl make
wsl bash tests/smoke.sh --full
```

**Result:**
- `make`: Clean build, 0 warnings, 0 errors.
- `tests/smoke.sh --full`: **35 of 35 passed, 0 failed.**

### 8.2 Specific Verifications Performed
1. **Scenario 17 (Settings UI & Navigation):** Verified row index 2 `Cat coat`, row navigation, color editor tabs, and 48-byte persistence.
2. **Scenario 23 (Color Editor Operations):** Verified slot navigation, color modification, custom theme setting, and 48-byte file write.
3. **Scenario 24 (12 Corrupt-File Recovery Scenarios):** Tested corrupt fixtures (`missing`, `empty`, `truncated_header`, `truncated_v1`, `truncated_v2`, `wrong_magic`, `wrong_version` (`PAWS\x03`), `invalid_theme`, `invalid_bool`, `invalid_coat`, `oversized_v1`, `oversized_v2`). In every case, Pawmodoro caught the error, loaded default settings, and regenerated a pristine 48-byte v2 file.
4. **Scenario 34 (G2 Comprehensive Verification):**
   - Synthesized valid 24-byte v1 file with Theme 1 (Matcha Latte) and non-default flags.
   - Verified clean migration into v2: theme preserved, new coat initialized to default 0 (Orange Tabby).
   - Cycled coat to Gray Tabby (1) via Left/Right keys; verified immediate persistence.
   - Opened color editor, switched from Interface to Art group using `Tab` and `]`.
   - Edited slot 18 (`SLOT_FUR`); verified automatic transition of coat to 6 (`Custom`).
   - Verified resulting `settings.dat` is exactly 48 bytes with correct magic, version 2, coat 6, and custom palette data.
5. **Palette Consistency Audit:** Verified `NUM_SLOTS = 24` across all source modules; verified absence of truecolor (`38;2` or `48;2`) escape codes.

---

## 9. Visual Comparison with Reference Image

- **Visual Direction:** Manual review of `docs/reference/sprites/target-dashboard.png` (warm dark charcoal background #1A1A1E, slate panels #222228, soft pink borders and title accents, warm orange tabby fur) guided the 256-color palette indices selected for Theme 0 (Strawberry Milk).
- **Distinction from Future Milestones:** Task G2 specifically implements the 24-color theme engine, cat-coat presets, and settings v2 persistence. In accordance with the project roadmap, future milestones (G3, G4, etc.) own sprite conversion, multi-layered sprite blitting, and dashboard layout redesign.

---

## 10. Known Issues & Environmental Limitations

- **Headless Environment Screenshot Capture:** In the headless WSL2 container environment, graphical rendering tools (`magick`, `convert`, and Python `PIL`/`Pillow`) were unavailable. Automated PTY session terminal dumps and ANSI stream captures in test Scenarios 17, 23, 24, and 34 were used to verify layout geometry, escape sequence generation, and buffer safety.

---
*End of G2-theme-v2 documentation.*
