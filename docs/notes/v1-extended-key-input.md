# Task V1 — Extended Key Input (Explanation Note)

**Course:** CAO10 · **Group:** 8 · **Task:** V1 (Extended Key Input)
**Specification:** `docs/PRD.md` §3.2, §6.2, §6.4; `docs/PRD_V2.md` §6, §13.3 (FR-V19..FR-V21), §14

---

## 1. Summary of Changes

In the original v1 prototype, `key_poll` swallowed and discarded all multi-byte terminal escape sequences (including arrow keys). For v2 features such as interactive journal scrolling and deletion, habit list selection, and the settings menu, the application requires navigation keys.

In this task, `key_poll` in `src/term.asm` was extended to parse and recognize standard CSI (`ESC [`) and SS3 (`ESC O`) escape sequences while preserving all existing single-byte input behavior, uppercase normalization, and non-blocking polling performance.

### Key Sequences Supported

| Key Description | Sequence Form(s) | Named Constant | Numeric Value |
|---|---|---|---|
| Up Arrow | `ESC [ A`, `ESC O A` | `KEY_UP` | `0x101` (257) |
| Down Arrow | `ESC [ B`, `ESC O B` | `KEY_DOWN` | `0x102` (258) |
| Right Arrow | `ESC [ C`, `ESC O C` | `KEY_RIGHT` | `0x103` (259) |
| Left Arrow | `ESC [ D`, `ESC O D` | `KEY_LEFT` | `0x104` (260) |
| Page Up | `ESC [ 5 ~` | `KEY_PGUP` | `0x105` (261) |
| Page Down | `ESC [ 6 ~` | `KEY_PGDN` | `0x106` (262) |
| Home | `ESC [ H`, `ESC O H`, `ESC [ 1 ~` | `KEY_HOME` | `0x107` (263) |
| End | `ESC [ F`, `ESC O F`, `ESC [ 4 ~` | `KEY_END` | `0x108` (264) |
| Delete | `ESC [ 3 ~` | `KEY_DELETE` | `0x109` (265) |

All numeric values are unique integers strictly greater than 255 so they never collide with standard ASCII characters (0–127) or byte values (128–255).

---

## 2. Technical Decisions & Implementation Details

### Distinguishing a Lone Escape from an Escape Sequence
When an escape byte (`0x1B` / `CHAR_ESC`) is read:
1. `key_poll` immediately attempts a non-blocking read of the next byte.
2. If no follow-up byte is immediately ready, it executes a short 5-millisecond sleep using `sys_nanosleep` (`NANOSLEEP_5MS = 5000000` ns).
3. It then re-checks for a follow-up byte once.
4. If still no byte is available, it concludes that the user pressed a lone Escape key and returns `KEY_ESC` (27).
5. If a follow-up byte is present (either immediately or within the 5 ms grace period), it continues parsing as an escape sequence.

This 5 ms grace window prevents packet fragmentation (common across remote SSH links, terminal emulator buffers, or slow serial lines) from misclassifying navigation keys as lone Escape presses.

### Draining Unknown and Malformed Sequences
- For CSI sequences (`ESC [`), if the sequence is unknown or modified (such as `ESC [ 1 ; 5 A` for Ctrl+Up or function keys like `ESC [ 1 5 ~`):
  - The parser enters a bounded drain loop (capped at 16 bytes).
  - It consumes bytes until it encounters a standard CSI final terminator byte in the range `0x40` through `0x7E` (`@` through `~`).
  - It returns `KEY_NONE` (-1).
  - Crucially, no intermediate sequence bytes (such as `1`, `5`, `;`, `A`, or `~`) leak to application input as independent keystrokes.
- For SS3 sequences (`ESC O`), any non-matching suffix is non-blockingly consumed (bounded to 8 bytes) and `KEY_NONE` (-1) is returned.

### Register Safety Across System Calls
Under Linux 32-bit x86 `int 0x80`, the `syscall` macro clobbers `EAX`, `EBX`, `ECX`, and `EDX` with system call parameters and return status. The parser uses `ESI` to preserve sequence bytes (such as byte 3 in numbered CSI sequences) and `EDI` for loop iteration counters across subsequent `sys_read` calls. The procedure saves and restores `EBX`, `ECX`, `EDX`, `ESI`, and `EDI` via `save_regs` and `restore_regs`, clobbering only `EAX` (which holds the return code).

### Preservation of Existing Application Screens
Existing screens (Menu, Timer, Habits, Journal) compare input against specific supported key constants (`KEY_Q`, `KEY_CTRL_C`, digits `1`..`8`, `P`, `S`, `A`, `D`, `N`, `V`, `B`) and ignore any other values. Because extended key codes are greater than 255 and do not match any single-byte ASCII command, passing them to existing screen handlers results in harmless no-op handling without redraws, transitions, or state changes.

---

## 3. Files Modified

1. `src/constants.inc`:
   - Added character constants `CHAR_TILDE` (126) and `CHAR_UPPER_O` (79).
   - Added `NANOSLEEP_5MS` (5,000,000 ns).
   - Added extended key constants `KEY_UP` (0x101), `KEY_DOWN` (0x102), `KEY_RIGHT` (0x103), `KEY_LEFT` (0x104), `KEY_PGUP` (0x105), `KEY_PGDN` (0x106), `KEY_HOME` (0x107), `KEY_END` (0x108), `KEY_DELETE` (0x109).

2. `src/term.asm`:
   - Updated `key_poll` procedure header with the extended return contract.
   - Replaced multi-byte escape swallow loop with the CSI/SS3 parser and terminator drain loop.
   - Retained non-blocking polling, uppercase letter conversion, and error handling.

3. `src/main.asm`:
   - Temporarily adapted to print received key codes during testing.
   - Completely restored to original production state after verification.

---

## 4. Verification and Testing

### Automated Regression Suite
Ran `make clean && make` and executed the automated regression test suite `tests/smoke.sh` under WSL2 Ubuntu:
- **Result:** Build was warning-free.
- **Result:** All 16 smoke scenarios passed (16 passed, 0 failed).

### Diagnostic Key Code Verification
Using a tmux test harness running the temporary diagnostic build, all key sequences were sent and verified:
- `a` returned `65` (ASCII 'A')
- `ESC [ A` returned `257` (`KEY_UP`)
- `ESC [ B` returned `258` (`KEY_DOWN`)
- `ESC [ C` returned `259` (`KEY_RIGHT`)
- `ESC [ D` returned `260` (`KEY_LEFT`)
- `ESC [ 5 ~` returned `261` (`KEY_PGUP`)
- `ESC [ 6 ~` returned `262` (`KEY_PGDN`)
- `ESC [ H` returned `263` (`KEY_HOME`)
- `ESC [ F` returned `264` (`KEY_END`)
- `ESC [ 3 ~` returned `265` (`KEY_DELETE`)
- `ESC O A` returned `257` (`KEY_UP`)
- `ESC O B` returned `258` (`KEY_DOWN`)
- `ESC O C` returned `259` (`KEY_RIGHT`)
- `ESC O D` returned `260` (`KEY_LEFT`)
- `ESC O H` returned `263` (`KEY_HOME`)
- `ESC O F` returned `264` (`KEY_END`)
- `ESC [ 1 ~` returned `263` (`KEY_HOME`)
- `ESC [ 4 ~` returned `264` (`KEY_END`)
- `Escape` (lone) returned `27` (`KEY_ESC`)
- `ESC [ 1 ; 5 A` (modified key) was drained without leaking stray characters.
- `ESC [ Z` (Backtab) was drained without leaking stray characters.

### Key Mashing on All Application Screens
Mashed bursts of arrow and navigation keys across all four application states (Main Menu, Pomodoro Timer, Habit Tracker, and Journal):
- No screen corruption occurred.
- No stray characters were emitted.
- No unintended actions, state transitions, or timer pauses were triggered.

---

## 5. Limitations & Future Work

- Navigation keys are now recognized by `key_poll`, but existing v1 screens do not yet use them for cursor navigation; integration into Journal scrolling/deletion (V3) and Settings (V5) will follow in subsequent tasks.
- Only Linux x86 32-bit `int 0x80` ABI is supported (by specification).
