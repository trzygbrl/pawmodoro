# Task 4: UI Shell, ASCII Art, Main Menu & State Machine Walkthrough

**Task ID:** `task-4-shell`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the architecture of the application shell implemented in Task 4: the finite state machine (FSM), the single-buffer non-flickering render loop with `need_redraw`, two-phase border and text rendering, ANSI line clearing (`ESC[K` and `ESC[J`), ASCII cat poses, and how future tasks plug into this foundation. It is written in plain language so any group member can confidently explain and defend these components during live demo evaluations.

---

## 1. The Finite State Machine and the `need_redraw` Flag

### State Machine Architecture (PRD §4.1 FR-U3)
Pawmodoro is structured as a classical **Finite State Machine** (FSM). At any given moment, the application exists in exactly one state, tracked by the `.bss` variable `state`:
- `STATE_MENU` (`0`): Main dashboard menu displaying cat art, daily stats, and navigation options.
- `STATE_TIMER` (`1`): Active Pomodoro focus/break countdown timer (currently a stub screen, implemented in T5).
- `STATE_HABITS` (`2`): Habit tracker dashboard and check-in interface (currently a stub screen, implemented in T7).
- `STATE_JOURNAL` (`3`): Journal viewer and entry composer (currently a stub screen, implemented in T8).
- `STATE_QUIT` (`4`): Clean exit state triggering terminal restoration.

Transitions are strictly dispatched using `CMP` and conditional jumps:
```nasm
    mov edx, [state]
    cmp edx, STATE_MENU
    je .handle_menu_key
    cmp edx, STATE_TIMER
    je .handle_stub_key
    ...
```

### The `need_redraw` Flag: Render-On-Demand
Rather than blindly re-drawing the screen on every iteration of the event loop (which would waste CPU and flood the terminal with redundant escape sequences), rendering is **event-driven** via the `need_redraw` flag:
1. **Initial Boot:** `need_redraw` is initialized to `1` so the initial Main Menu is drawn immediately.
2. **On Keypress:**
   - If an accepted key is pressed (such as `1`, `2`, `3` to switch screens, or `4` to toggle demo mode), `need_redraw` is set to `1`.
   - If an invalid or unhandled key is pressed (such as `X`, `5`, Space, Enter, or arrow keys), `need_redraw` remains `0`.
3. **Loop Check:** The top of the loop checks `need_redraw`:
   ```nasm
   cmp dword [need_redraw], 0
   je .wait_for_input
   ; ... render frame ...
   call buf_flush
   mov dword [need_redraw], 0
   ```
   If `need_redraw` is `0`, rendering is completely bypassed!
4. **Sleep on Idle:** The loop calls `key_wait`, which sleeps for 50 ms per tick using `sys_nanosleep`. While sitting idle waiting for a key, Pawmodoro uses **0.0% CPU** and makes zero `sys_write` calls.

---

## 2. Why a Frame is Built in Memory and Flushed Once (FR-U4)

Standard CLI applications often print characters piecemeal using multiple `printf` or `write` calls. When redrawing an entire 80×24 terminal screen, this results in visible flickering, tearing, and stuttering as the user's terminal emulator renders incomplete intermediary frames.

**The Pawmodoro Single-Buffer Architecture:**
- All drawing commands (`buf_goto`, `buf_char`, `buf_str`, `buf_repeat`, `buf_u32`) append bytes into an 8,192-byte contiguous memory buffer (`out_buf` in `.bss`).
- Nothing is sent to the terminal while the frame is under construction.
- Once the entire frame (borders, cat art, titles, text, and ANSI colors) is fully assembled in memory, `buf_flush` issues **exactly one `sys_write` system call**:
  ```nasm
  syscall SYS_WRITE, FD_STDOUT, out_buf, edx
  ```
- The terminal emulator receives the complete frame in a single atomic payload and renders it instantly. The result is a smooth, rock-solid, flicker-free visual experience.

---

## 3. Two-Phase Frame Rendering & Cursor Geometry

A major challenge in terminal UIs is redrawing frames when content changes (e.g., transitioning from a 13-row Main Menu to an 8-row Stub screen, or toggling between `Demo mode: OFF` and `Demo mode: ON`). Naive programs emit `ESC[2J` (clear entire screen), which causes an annoying flash/blink.

Pawmodoro solves this with a **Two-Phase Rendering Model** combined with `buf_goto(1, 1)`:

```
Phase 1: Draw Skeleton & Wipe Lines
+------------------------------------------------------+  <-- ui_frame_hline
| ESC[K                                               |  <-- ui_frame_row (clears row, sets right border)
+------------------------------------------------------+
| ESC[K                                               |
+------------------------------------------------------+
ESC[J (erase to bottom of screen)                       <-- wipes any rows below frame

Phase 2: Overlay Content (Absolute Positioning)
|   /\_/\    P A W M O D O R O                         |  <-- ui_draw_cat & ui_text_at
|  ( o.o )   cozy focus - habits - notes               |
```

### Why Borders are Drawn First, Then Text Overlaid
In Phase 1, `ui_draw_menu` and `ui_draw_stub` draw all border lines (`ui_frame_hline`) and blank rows (`ui_frame_row`).
- In `ui_frame_row`, we emit `ESC[K` (`ansi_erase_eol`) immediately after the left border `|`. This erases the entire line across to the right edge of the screen, completely clearing any old text from the previous screen.
- If text were drawn *before* or *during* the border pass, the `ESC[K` would erase the text! By drawing all borders and row clears first, we create a clean slate, and then Phase 2 simply overlays the text and cat art at precise coordinates.

### Why `ESC[K` and `ESC[J` Replace Full Screen Clears
- **`ESC[K` (Erase to End of Line):** Clears character residue within each row. When `Demo mode: OFF` toggles to `Demo mode: ON`, or when switching from a long text row to a short one, no leftover characters linger behind.
- **`ESC[J` (Erase to End of Screen):** Placed at the row immediately below the frame (Row 14 on the menu, Row 9 on stubs). When moving from the 13-row Main Menu to the 8-row Stub screen, `ESC[J` wipes rows 9 through 24 in one stroke. Old rows below the new frame vanish completely without needing a full-screen clear.

### Why the Right Border Uses an Absolute Column (Col 56)
In variable-width terminal layouts, calculating the number of padding spaces needed before the right border `|` is prone to errors—especially with multi-byte UTF-8 characters like the em-dash `—` (3 bytes, but only 1 display column).
- In Pawmodoro, `ui_frame_row` eliminates padding calculations entirely:
  1. Position at column 1: `buf_goto(row, 1)` $\rightarrow$ emit `|`.
  2. Erase line: emit `ESC[K`.
  3. Jump directly to column 56: `buf_goto(row, 56)` $\rightarrow$ emit `|`.
- The right border is pinned to column 56 on every row regardless of text length or character encodings!

---

## 4. How `ui_draw_cat` Renders ASCII Art Poses (PRD §6.4)

The application features a cozy ASCII cat companion rendered in 3 distinct poses:
- **Pose 0 (Idle - Menu):**
  ```text
   /\_/\ 
  ( o.o )
   > ^ < 
  ```
- **Pose 1 (Working - Focus Timer):**
  ```text
   /\_/\ 
  ( -.- )
   > ^ < 
  ```
- **Pose 2 (Resting / Sleeping - Break):**
  ```text
   /\_/\   z
  ( u.u )  Z
   > ^ < 
  ```

### Procedural Mechanics
- `ui_draw_cat` takes `EAX = pose`. If `EAX > 2`, it automatically defaults to `0` (defensive programming).
- It reads implicit coordinates from two `.bss` variables: `[cat_row]` and `[cat_col]`. This decouples the art from fixed screen coordinates, allowing the Timer screen (T5) to center the cat while the Main Menu positions it on the left at `(2, 4)`.
- It sets the warm yellow foreground color (`ansi_fg_bright_yellow`), emits the 3 lines using `buf_goto`, and unconditionally resets styling with `ansi_reset`.

---

## 5. How Later Tasks Plug into the Shell

The Task 4 shell serves as the application backbone that all remaining tasks connect into:
- **Task 5 & 6 (Pomodoro Timer):** The handler for `STATE_TIMER` will replace `ui_draw_stub` with the active countdown loop, timer art, progress bar, and session counter.
- **Task 7 (Habits Tracker):** The handler for `STATE_HABITS` will replace its stub with the 7-day checkbox grid and streak counter. `dash_habits_done` and `dash_habits_total` will be dynamically computed from `habits.dat`.
- **Task 8 (Journal):** The handler for `STATE_JOURNAL` will replace its stub with the 10-entry scrollback viewer and interactive note-taking prompt.

---

## 6. Verification and `strace` Evidence

### Build Verification
```bash
make clean && make
file build/pawmodoro
```
**Output:**
```text
rm -rf build
mkdir -p build
nasm -f elf32 -g -F dwarf -Wall src/main.asm -o build/pawmodoro.o
ld -m elf_i386 build/pawmodoro.o -o build/pawmodoro
build/pawmodoro: ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), statically linked, with debug_info, not stripped
```
*(Zero compiler or linker warnings)*

### System Call Trace (`strace`)
We traced execution across the key sequence: `4` (demo on), `4` (demo off), `1` (timer stub), `B` (back), `X` (invalid key), `2` (habits stub), `B` (back), `Q` (quit):
```bash
strace -e trace=write,read,ioctl,nanosleep ./build/pawmodoro
```
**Actual trace excerpt:**
```text
ioctl(0, TCGETS, {c_lflag=ISIG|ICANON|ECHO...}) = 0
write(1, "\33[?1049h\33[?25l", 14)      = 14             <-- alternate screen, hide cursor
ioctl(0, TCSETS, {c_lflag=ECHOE|ECHOK...}) = 0          <-- enter raw mode
write(1, "\33[1;1H\33[1;1H+-----------"..., 721) = 721  <-- Frame 1: initial main menu

read(0, "4", 1)                         = 1              <-- Key '4' (demo toggle on)
write(1, "\33[1;1H\33[1;1H+-----------"..., 724) = 724  <-- Frame 2: redraw menu (Demo: ON)

read(0, "4", 1)                         = 1              <-- Key '4' (demo toggle off)
write(1, "\33[1;1H\33[1;1H+-----------"..., 721) = 721  <-- Frame 3: redraw menu (Demo: OFF)

read(0, "1", 1)                         = 1              <-- Key '1' (enter timer stub)
write(1, "\33[1;1H\33[1;1H+-----------"..., 375) = 375  <-- Frame 4: render timer stub

read(0, "B", 1)                         = 1              <-- Key 'B' (return to menu)
write(1, "\33[1;1H\33[1;1H+-----------"..., 721) = 721  <-- Frame 5: redraw main menu

read(0, "X", 1)                         = 1              <-- Key 'X' (invalid key)
nanosleep({tv_sec=0, tv_nsec=50000000}, NULL) = 0       <-- NO write! System sleeps

read(0, "2", 1)                         = 1              <-- Key '2' (enter habits stub)
write(1, "\33[1;1H\33[1;1H+-----------"..., 377) = 377  <-- Frame 6: render habits stub

read(0, "B", 1)                         = 1              <-- Key 'B' (return to menu)
write(1, "\33[1;1H\33[1;1H+-----------"..., 721) = 721  <-- Frame 7: redraw main menu

read(0, "Q", 1)                         = 1              <-- Key 'Q' (quit application)
ioctl(0, TCSETS, {c_lflag=ISIG|ICANON|ECHO...}) = 0     <-- restore cooked mode
write(1, "\33[0m\33[?25h\33[?1049l", 18) = 18           <-- reset colors, show cursor, main screen
+++ exited with 0 +++
```

**Key takeaways from the trace:**
1. **Exactly one `sys_write` per redraw.**
2. **Invalid key `X` produces ZERO `sys_write` calls.**
3. **Idle intervals consist purely of 50 ms `nanosleep` calls with zero CPU consumption.**
4. **Terminal settings (`termios`, cursor, screen buffer) are 100% restored upon exit.**

---

## 7. Questions a Grader Might Ask

**Q1: Why did you use an output buffer instead of writing directly to stdout?**  
*Answer:* Writing byte-by-byte or line-by-line causes visible flickering and tearing in the terminal. Assembling the full frame in an 8 KB buffer and flushing it with a single `sys_write` guarantees smooth, flicker-free rendering and minimizes expensive context switches into the kernel.

**Q2: What happens if the user presses an unknown key like 'Z' or F1?**  
*Answer:* The finite state machine checks for recognized keys (`1`, `2`, `3`, `4`, `Q`, `Ctrl+C` on the menu; `B`, `Ctrl+C` on stubs). Any unrecognized key falls through to the loop without setting `need_redraw`. No screen update occurs and no syscall is issued.

**Q3: How does the application avoid leaving the user's terminal broken after quitting?**  
*Answer:* Every exit path routes to `.handle_exit`, which calls `term_restore`. This executes `ioctl TCSETS` to restore cooked canonical mode, unhides the cursor (`ESC[?25h`), exits the alternate screen buffer (`ESC[?1049l`), and resets all color styling (`ESC[0m`).

**Q4: Why does `ui_frame_row` jump directly to column 56 instead of calculating spaces?**  
*Answer:* Calculating padding is complex and fragile when lines contain multi-byte UTF-8 sequences (like the em-dash `—`). By using `ESC[K` to wipe the row and jumping directly to column 56 with `buf_goto`, the right border is mathematically guaranteed to stay aligned on every row.
