# Developer Notes: Task V5 — Settings Screen & Custom Color Editor

## 1. Executive Summary

Task V5 delivers a comprehensive, keyboard-accessible Settings screen and a dedicated 256-color palette editor for Pawmodoro (CAO10 Group 8 project, written in 32-bit x86 NASM assembly for Linux, using direct `int 0x80` kernel system calls and no libc).

Building upon the centralized 12-slot theme engine and persistent storage format established in Task V4, V5 integrates `STATE_SETTINGS` as a first-class application state, exposes `[5] Settings` on the main dashboard, supports adaptive 80×24+ layout rendering, provides real-time theme previews with live color swatches, and incorporates an interactive 16×16 color editor with immediate persistence and honest status feedback.

---

## 2. Architecture & Finite State Machine Integration

### State Machine Transition
- Added `STATE_SETTINGS equ 5` in `src/constants.inc`.
- In `src/main.asm`:
  - When in `STATE_MENU`, key code `5` (`KEY_5 = 53`) transitions `state` to `STATE_SETTINGS` and invokes `settings_run`.
  - Upon return from `settings_run`:
    - If `state == STATE_QUIT`, control transfers to `.handle_exit` for clean terminal teardown.
    - Otherwise, `state` is restored to `STATE_MENU`, `need_redraw = 1` is set, and the main loop redraws the dashboard.

### Sub-View Modes within `STATE_SETTINGS`
To provide a clean, non-destructive modal experience without allocating new processes or nested terminal loops, `settings_run` manages three internal view modes via `settings_view_mode`:
1. `SETTINGS_MODE_MAIN equ 0`: The primary Settings screen listing the 7 configurable rows.
2. `SETTINGS_MODE_COLORS equ 1`: The dedicated 256-color custom palette editor.
3. `SETTINGS_MODE_CONFIRM equ 2`: The reset-to-defaults `(y/n)` confirmation prompt.

---

## 3. Settings Screen Structure (The 7 Selectable Rows)

The Settings screen adheres strictly to Pawmodoro's adaptive layout model (`ui_w`, `ui_h`, `ui_col0`), rendering within an enclosed frame bounded at 80×24 minimum:

| Row Index | Constant | Setting | Navigation & Key Action | Immediate Effect & Persistence |
|---:|---|---|---|---|
| 0 | `SETTINGS_ROW_THEME` | **Theme** | `Left`/`Right` cycles through built-in themes 0..6 and Custom 7 | Swaps `active_palette`, renders live 12-slot swatch strip and sample line, saves immediately via `settings_save`. |
| 1 | `SETTINGS_ROW_CUSTOMIZE` | **Customize colors** | `Enter` or `Right` | Transitions to `SETTINGS_MODE_COLORS` (Color Editor). |
| 2 | `SETTINGS_ROW_ANIM` | **Animations** | `Enter`, `Space`, `Left`, or `Right` | Toggles `setting_anim` between `1` (ON) and `0` (OFF / Reduce motion), saves immediately. |
| 3 | `SETTINGS_ROW_SOUND` | **Sound & Volume** | `Enter`/`Space` toggles sound; `Left`/`Right` adjusts volume (0..3 clamped) | Updates `setting_sound` (0/1) and `setting_volume` (0..3), saves immediately. |
| 4 | `SETTINGS_ROW_CHARSET` | **Charset** | `Enter`, `Space`, `Left`, or `Right` | Toggles `setting_charset` between `0` (UTF-8) and `1` (ASCII), saves immediately. |
| 5 | `SETTINGS_ROW_NOTIFY` | **Terminal integration** | `Enter`, `Space`, `Left`, or `Right` | Toggles `setting_notify` between `0` (OFF) and `1` (ON). Preserves `setting_notify_layers` mask (`0x01`). Saves immediately. |
| 6 | `SETTINGS_ROW_RESET` | **Reset to defaults** | `Enter` or `Space` | Opens `SETTINGS_MODE_CONFIRM` prompt asking `Reset all settings to defaults? (y/n)`. |

---

## 4. Dedicated 256-Color Editor (`SETTINGS_MODE_COLORS`)

The custom color editor provides full control over each of the 12 semantic slots defined in PRD_V2 §4:

### Layout Geometry
- **Left Column (Cols 4..30, Rows 4..15):** Lists all 12 slots (`SLOT_BORDER` through `SLOT_HIGHLIGHT`) with selection marker `>` for the active slot, current decimal color index `(N)`, and a live color swatch.
- **Right Column (Cols 34..66, Rows 4..19):** A 16×16 character grid displaying all 256 colors. Each cell is 2 characters wide. The cell matching the active slot's color index is prominently marked with brackets `[]` (e.g. `[ ]`), while all other cells are rendered with solid filled blocks.
- **Bottom Section (Row 20):** An illustrative live sample showing the active slot in actual UI use (e.g., border segment for `BORDER`, bold title for `TITLE`, checked box `[#]` for `OK`, warning text for `WARN`, progress bar block for `BAR_FULL`).
- **Footer Section (Rows 21..22):** Status feedback row (`Saved` / `Could not save`) and keyboard help prompt.

### Navigation and Adjustment Controls
- `Up` / `Down` (or `K` / `J`): Selects previous/next slot (0..11) with wrap-around.
- `Left` / `Right` (or `H` / `L`): Decrements/increments the selected slot's color index by 1 (clamped safely to 0..255).
- `PgUp` / `PgDn`: Adjusts color index by +16 or -16 (clamped safely to 0..255).
- `Home` / `End`: Selects first slot (`SLOT_BORDER`) or last slot (`SLOT_HIGHLIGHT`).
- `Esc` or `B`: Exits Color Editor back to the Main Settings screen.
- `Ctrl+C`: Clean exit restoring cooked terminal mode, cursor visibility, and original screen buffer.

### Custom Palette Semantics & Slot Independence
- When modifying any slot color while a built-in theme (0..6) is active:
  1. The engine copies the current `active_palette` into `custom_palette`.
  2. Sets `setting_theme` to `7` (`THEME_CUSTOM_INDEX`).
  3. Modifies only the selected slot in both `custom_palette` and `active_palette`.
  4. Persists the updated settings to disk immediately.
- Built-in theme palettes are never modified in memory or on disk. Switching back to built-in themes (0..6) does not erase `custom_palette`.

---

## 5. Persistence & Honest Status Reporting

All setting modifications are saved synchronously through `settings_mutate_and_save`:
- Calls `settings_save` to serialize the exact 24-byte little-endian record (`settings.dat`) specified in PRD_V2 §5.
- Inspects `settings_save_err`:
  - If `0`: Sets `settings_status_msg` to point to `"Saved"` and `settings_status_style` to `STATUS_OK`.
  - If `1`: Sets `settings_status_msg` to point to `"Could not save"` and `settings_status_style` to `STATUS_ERR`.
- The current in-memory setting remains applied even if disk saving fails, and save failure is reported honestly without crashing the application.

---

## 6. Reset to Defaults Confirmation Mechanics

When selecting row 6 (`Reset to defaults`):
1. Transitions `settings_view_mode` to `SETTINGS_MODE_CONFIRM`.
2. Screen displays `Reset all settings to defaults? (y/n)`.
3. Keystroke dispatch:
   - `N` / `Esc` / `B`: Cancels reset. Restores `SETTINGS_MODE_MAIN` with all current settings intact.
   - `Y`: Restores PRD_V2 §5 defaults:
     - Theme 0 (`Strawberry Milk`).
     - Default custom palette copy of Theme 0.
     - Animations enabled (`1`).
     - Sound disabled (`0`).
     - Charset UTF-8 (`0`).
     - Terminal integration disabled (`0`).
     - Notification layers bitmask `0x01`.
     - Volume `2`.
     - Immediately persists changes to disk via `settings_save` and displays `Saved`.
     - Restores `SETTINGS_MODE_MAIN`.

---

## 7. Procedures & Register Calling Conventions

All newly introduced procedures in `src/settings_ui.asm` adhere strictly to PRD §6.2:
- Zero FPU/SSE/MMX instructions used.
- Zero libc dependencies; pure Linux `int 0x80` syscalls.
- Register preservation via `save_regs` / `restore_regs` or explicit stack save/restore.
- Procedure header contracts:

```nasm
; settings_draw:
; IN:       None
; OUT:      Appends complete Settings screen frame to out_buf
; CLOBBERS: None (preserves all)

; settings_draw_row_label:
; IN:       EAX = Screen row coordinate (1-based)
;           EDX = Setting row index (0..6)
;           ESI = Pointer to row label string
; OUT:      Appends formatted label and cursor to out_buf
; CLOBBERS: None (preserves all)

; settings_handle_key:
; IN:       EAX = Key code (ASCII or KEY_*)
; OUT:      None (updates settings state, requests redraw)
; CLOBBERS: None (preserves all)

; settings_colors_draw:
; IN:       None
; OUT:      Appends complete Color Editor frame to out_buf
; CLOBBERS: None (preserves all)

; settings_colors_handle_key:
; IN:       EAX = Key code (ASCII or KEY_*)
; OUT:      None (updates palette, requests redraw and save)
; CLOBBERS: None (preserves all)

; settings_apply_slot_color:
; IN:       AL = New 256-color byte (0..255)
; OUT:      None (updates active and custom palettes, saves)
; CLOBBERS: None (preserves all)

; settings_confirm_draw:
; IN:       None
; OUT:      Appends confirmation prompt overlay to out_buf
; CLOBBERS: None (preserves all)

; settings_confirm_handle_key:
; IN:       EAX = Key code
; OUT:      None (handles Y/N/Esc/B, executes reset on Y)
; CLOBBERS: None (preserves all)

; settings_mutate_and_save:
; IN:       None
; OUT:      None (calls settings_save, updates status row)
; CLOBBERS: None (preserves all)

; settings_run:
; IN:       None
; OUT:      None (runs STATE_SETTINGS event loop until return to STATE_MENU)
; CLOBBERS: None (preserves all)
```

---

## 8. Verification & Test Outcomes

### Automated Smoke Tests (`tests/smoke.sh`)
- Executed `bash tests/smoke.sh`: **17/17 passed, 0 failed**.
- Verified all baseline scenarios (Timer, Habits, Journal, Demo mode, Persistence, Terminal restoration).
- Added Scenario 17 covering Settings menu entry, full row listing, Color Editor navigation, theme switching, immediate persistence, 24-byte binary file validation, and clean return to dashboard.

### Comprehensive Headless Integration Tests (`test_v5.py`)
- Executed all 17 dedicated live scenarios in tmux across various window configurations:
  1. Main menu displays `[5] Settings` and `[1-5]` prompt.
  2. Key `5` enters SETTINGS and renders all 7 rows.
  3. Up/Down navigates rows with circular wrapping.
  4. Left/Right cycles themes and renders live swatches.
  5. Enter opens 256-Color Editor.
  6. Slot color adjustments switch theme to Custom and recolor active slots.
  7. PgUp/PgDn adjustments (+/- 16) clamped safely at 0 and 255.
  8. Escape/B returns to Settings preserving custom palette.
  9. Animations toggle between ON and OFF (Reduce motion).
  10. Sound toggles ON/OFF and Volume adjusts 0..3 clamped.
  11. Charset toggles between UTF-8 and ASCII.
  12. Integration toggles master setting while preserving layer mask `0x01`.
  13. Reset confirmation cancel (`N`) preserves settings.
  14. Reset confirmation confirm (`Y`) restores defaults and saves.
  15. Key `B` returns from Settings to Main Menu.
  16. Persisted `settings.dat` loads cleanly upon fresh application startup.
  17. `Ctrl+C` exits cleanly from Settings sub-states restoring terminal.

### Quality and Constraint Checks
- `git diff --check src/ tests/`: Clean, zero whitespace issues.
- `grep -nE '\b(fld|fst|...)\b' src/*.asm`: Zero FPU/SSE/MMX instructions used.
- Single `sys_write` per frame preserved across all redraws via `buf_flush`.
- Zero files outside the allowlist modified.
