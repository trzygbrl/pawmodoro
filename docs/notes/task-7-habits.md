# Task 7: Habit Tracker Engine & Persistence Walkthrough

**Task ID:** `task-7-habits`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the architecture and implementation of the Habit Tracker subsystem completed in Task 7. It details the binary 48-byte habit record structure, the `habits.dat` storage image, the 32-bit history bitmask mathematics (`SHL`, `OR`, `BT`), streak progression rules, interactive additions and deletions via forward memory shifting (`REP MOVSB`), corrupt file validation and resilience, register preservation contracts, and live test evidence. Written in plain, accessible language, this guide equips any team member to confidently explain and defend the habit tracker implementation during project evaluations.

---

## 1. Habit Record Layout & Binary Persistence (`habits.dat`)

### The 48-Byte In-Memory Record (PRD §4.3 FR-H1, §4.5 FR-D3)
Pawmodoro supports tracking up to 8 habits (`MAX_HABITS = 8`), each stored in an individual 48-byte record (`HABIT_RECORD_SIZE = 48`):

```text
+-----------------------+-----------+--------+-------+---------+
|      name[32]         | last_day  | streak | total | history |
|     Offset 0..31      | 32..35    | 36..39 | 40..43| 44..47  |
+-----------------------+-----------+--------+-------+---------+
```

| Field | Size | Offset | Purpose |
| :--- | :--- | :--- | :--- |
| `name` | 32 bytes | `0` | NUL-terminated ASCII string (up to 31 characters, byte 31 is always `0`). |
| `last_day` | 4 bytes (dword) | `32` | Julian-style local day number of most recent check-in (`0` for new habit). |
| `streak` | 4 bytes (dword) | `36` | Consecutive daily check-in streak count. |
| `total` | 4 bytes (dword) | `40` | All-time lifetime check-in total. |
| `history` | 4 bytes (dword) | `44` | 32-bit bitmask recording check-in activity relative to `last_day`. |

### The Contiguous Storage Block in `.bss`
In `src/data.asm`, the entire habit subsystem state is declared contiguously:
```nasm
section .bss
    habit_data:
    habit_count:            resd 1          ; Stored habit count (0..8)
    habit_records:          resb (MAX_HABITS * HABIT_RECORD_SIZE) ; 8 * 48 = 384 bytes
```
- **Total Block Size:** $4 + 384 = 388$ bytes (`HABIT_MAX_FILE_SIZE`).
- **Memory Allocation Justification:** Allocating this dedicated 388-byte buffer in `.bss` enables `file_save` and `file_load` to transfer the active habit database directly to and from `habits.dat` with zero serialization overhead and zero memory fragmentation.

### Exact Byte-for-Byte `habits.dat` Layout
The persistent file `habits.dat` is a direct byte-for-byte image of `habit_count` followed by `habit_count` active records:
$$\text{File Size} = 4 + (\text{habit\_count} \times 48)$$
- For a freshly initialized app with 0 habits: valid file size is **4 bytes** (`habit_count = 0`).
- For 1 habit: valid file size is $4 + 48 = \mathbf{52}$ bytes.
- For 3 habits: valid file size is $4 + 144 = \mathbf{148}$ bytes.
- For 8 habits: valid file size is $4 + 384 = \mathbf{388}$ bytes.

### Worked Hex Example from Live Test
Below is the real `xxd` hex dump from our acceptance test after adding habit `"Test"`, checked in today (`day = 20745 = 0x00005109`), with `streak = 1`, `total = 1`, `history = 1`:

```text
00000000: 0100 0000 5465 7374 0000 0000 0000 0000  ....Test........
00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000020: 0000 0000 0951 0000 0100 0000 0100 0000  .....Q..........
00000030: 0100 0000                                ....
```

Breaking down every byte:
- `01 00 00 00` (Bytes 0..3): `habit_count = 1` (little-endian 32-bit dword).
- `54 65 73 74 00 ...` (Bytes 4..35): ASCII `"Test"` followed by NUL padding.
- `09 51 00 00` (Bytes 36..39 / Record offset 32): `last_day = 0x00005109 = 20745`.
- `01 00 00 00` (Bytes 40..43 / Record offset 36): `streak = 1`.
- `01 00 00 00` (Bytes 44..47 / Record offset 40): `total = 1`.
- `01 00 00 00` (Bytes 48..51 / Record offset 44): `history = 1` (Bit 0 set).

---

## 2. History Bitmask Mathematics & The 7-Day Squares

### History Bit Interpretation
The 32-bit dword `history` represents a relative timeline anchored at `last_day`:
- **Bit 0:** Checked in on `last_day` itself (always 1 for any active habit that has been checked in).
- **Bit 1:** Checked in 1 day prior to `last_day`.
- **Bit $i$:** Checked in $i$ days prior to `last_day` ($0 \le i \le 31$).

### Daily Check-In Bitmask Update (FR-H4)
When the user checks in on calendar day `today`, we calculate the unsigned elapsed days since the previous check-in:
$$\Delta = \text{today} - \text{last\_day}$$

1. **If $\Delta == 0$:**
   The habit was already completed today. The program displays `"Already done today"`, modifies no memory, and skips saving.
2. **If $\Delta > 0$:**
   Elapsed days represent days that have slipped into the past. Every historical check-in shifts left by $\Delta$ positions:
   $$\text{history}_{\text{new}} = (\text{history}_{\text{old}} \ll \Delta) \mid 1$$
   - `SHL` (Shift Left): Shifts bits left, automatically inserting $\Delta$ zeroes in the low bits (representing the missed days).
   - `OR 1`: Sets bit 0 to `1`, marking today as checked in.

### The 32-Bit Shift Guard Requirement
On x86 processors, the `SHL r32, CL` instruction masks the shift count to 5 bits:
$$\text{Effective Shift Count} = \text{CL} \ \& \ 31 = \text{CL} \pmod{32}$$
If $\Delta \ge 32$ (for instance, when a new habit has `last_day = 0`, yielding $\Delta = 20745$), an unguarded `shl eax, cl` would shift by $20745 \pmod{32} = 9$ instead of clearing the 32-bit register!
In `src/habits.asm`, we explicitly guard against this hardware trap:
```nasm
    cmp ecx, BITS_PER_DWORD     ; 32
    jae .chk_hist_zero          ; If delta >= 32, history is completely wiped
    shl eax, cl                 ; Safe shift for delta in 1..31
    jmp .chk_hist_set_bit0
.chk_hist_zero:
    xor eax, eax                ; Zero out old history
.chk_hist_set_bit0:
    or eax, 1                   ; Bit 0 = checked in today
```

### Visual 7-Day Squares Display (FR-H5)
During rendering, the screen shows the 7 most recent calendar days ending *today*, oldest on the left and newest on the right:
$$\text{Col 20..40:} \quad [d-6][d-5][d-4][d-3][d-2][d-1][d_0]$$
Because the stored `history` bitmask is anchored at `last_day` (which might be in the past), the display routine computes a temporary shifted bitmask without modifying the stored record:
$$\text{shifted} = \begin{cases} 
0 & \text{if } \text{last\_day} == 0 \text{ or } \Delta \ge 32 \\
\text{history} \ll \Delta & \text{otherwise}
\end{cases}$$

To render each square from oldest (6 days ago) to newest (today):
```nasm
    mov ecx, 6                  ; Bit 6 down to 0
.row_squares_loop:
    bt edi, ecx                 ; Test bit ECX of shifted history
    jc .row_square_done         ; If Carry Flag = 1, bit was set
    ; Bit is 0: render dim "[.]"
    ...
.row_square_done:
    ; Bit is 1: render bold green "[#]"
    ...
    dec ecx
    jns .row_squares_loop
```
- Bit 6 corresponds to 6 days ago (leftmost square).
- Bit 0 corresponds to today (rightmost square).

---

## 3. Streak Progression & Display Rules

### Stored Streak vs. Displayed Streak
A common flaw in productivity apps is showing an unbroken streak when a user hasn't checked in yet today. Pawmodoro cleanly distinguishes between **stored streak** (the streak achieved at `last_day`) and **displayed streak** (the live streak as of today).

1. **Stored Streak Update on Check-In:**
   - If $\Delta == 1$: User checked in yesterday! The streak continues:
     $$\text{streak} = \text{streak} + 1$$
   - If $\Delta > 1$: A day was skipped (gap in check-ins). The streak breaks and resets to 1:
     $$\text{streak} = 1$$

2. **Displayed Streak Rule (FR-H5):**
   When drawing the screen *before* checking in today:
   - If user checked in today ($\Delta == 0$): display stored `streak`.
   - If user checked in yesterday ($\Delta == 1$): display stored `streak` (the streak is still alive and awaiting today's check-in).
   - If user missed yesterday ($\Delta > 1$): the streak is officially broken. Display **`0`**.

### Worked Example: Gap Reset
1. User checked in yesterday: `last_day = TODAY - 1` ($\Delta = 1$), `streak = 1`.
   - Display shows: `[.][.][.][.][.][#][.]`, streak = `1`.
2. User checks in: $\Delta = 1 \implies$ `streak` becomes `1 + 1 = 2`.
   - Display shows: `[.][.][.][.][.][#][#]`, streak = `2`.
3. Three days pass without checking in: `last_day = TODAY - 3` ($\Delta = 3$).
   - Live display: $\Delta = 3 > 1 \implies$ streak is shown as **`0`**.
   - Squares: `[.][.][#][#][.][.][.]`.
4. User checks in: $\Delta = 3 > 1 \implies$ streak resets to **`1`**, total becomes `3`.
   - Display shows: `[.][.][#][#][.][.][#]`, streak = `1`, total = `3`.

---

## 4. Interactive Additions, Deletions, and Memory Shifting

### Adding a Habit (Key `A`, FR-H3)
1. **Capacity Guard:** Checks `cmp dword [habit_count], MAX_HABITS` (8). If 8 habits already exist, displays `"Habit list full (max 8)"` and skips input.
2. **Terminal Transition:** Positions cursor at Row 14, Col 50, and calls `read_line` with `line_buf` and capacity `HABIT_NAME_MAX = 31`. `read_line` flushes output, switches terminal to cooked mode, displays the cursor, accepts input with backspace editing, truncates over-long input, NUL-terminates, hides the cursor, and restores raw mode.
3. **Empty Input Cancellation:** If the user presses Enter without typing, `read_line` returns length `0`, which cancels the addition with zero memory modification.
4. **Initialization:** Clears the 48-byte record using `CLD` and `REP STOSB` with `AL = 0`, copies the name using `str_copy`, forces byte 31 to NUL, increments `habit_count`, syncs the dashboard, and saves.

### Deleting a Habit (Key `D`, FR-H3)
1. Prompts `"Delete which habit? (1-N, other key cancels): "` on Row 14 and blocks on `key_wait`.
2. If the user presses `1`..`N` (`KEY_1` to `KEY_1 + habit_count - 1`), index $k = \text{key} - \text{KEY\_1}$ is deleted.
3. **Forward Record Shift with `REP MOVSB`:**
   To delete habit $k$, subsequent records from $k+1$ up to `habit_count - 1` must move up by 1 record slot (48 bytes):
   ```nasm
   mov edi, dest_record_ptr      ; habit_records + k * 48
   mov esi, src_record_ptr       ; habit_records + (k + 1) * 48
   mov ecx, num_records_to_shift ; (habit_count - 1) - k
   lea ecx, [ecx + ecx*2]        ; records * 3
   shl ecx, 4                    ; records * 48 bytes
   cld
   rep movsb                     ; Forward copy is safe because dest < src
   ```
4. **Vacated Slot Zeroing:** The vacated slot at `habit_records + (habit_count - 1) * 48` is zeroed with `REP STOSB`.
5. Decrements `habit_count`, updates the dashboard, and saves.

---

## 5. Corrupt File Resilience & Validation (PRD §4.5, §7)

Pawmodoro enforces bulletproof resilience against damaged, truncated, or malicious files. In `habits_load`, three strict validation barriers protect system memory:

```nasm
    ; Barrier 1: Minimum file size (at least 4 bytes for count header)
    test eax, eax
    js .load_empty              ; Missing file (-1)
    cmp eax, HABIT_MIN_FILE_SIZE ; 4 bytes
    jb .load_empty

    ; Barrier 2: Count bounds check
    mov edx, [habit_count]
    cmp edx, MAX_HABITS         ; Must be <= 8
    ja .load_empty

    ; Barrier 3: Byte count sufficiency check
    lea ecx, [edx + edx*2]      ; count * 3
    shl ecx, 4                  ; count * 48
    add ecx, HABIT_HEADER_SIZE  ; 4 + count * 48
    cmp eax, ecx                ; Bytes read must be >= required bytes
    jb .load_empty
```

- **Missing file:** `file_load` returns `-1`. Caught by `js .load_empty`.
- **Empty file (0 bytes):** Caught by `cmp eax, 4 / jb .load_empty`.
- **Truncated file (e.g. 10 bytes with count 1):** Requires $4 + 48 = 52$ bytes. $10 < 52 \implies$ caught by Barrier 3.
- **Corrupted count (e.g. count = 9 or 0xFFFFFFFF):** Caught by Barrier 2.
- **Trailing byte safety:** On any valid load, byte 31 of every habit name is explicitly overwritten with `CHAR_NULL` to guarantee display routines never read past buffer boundaries.

---

## 6. Calling Conventions: Why `habits_done_today` Skips `save_regs`

Under PRD §6.4, `habits_done_today` returns two separate values simultaneously:
- **`EAX`:** Habits completed today.
- **`EBX`:** Total number of habits.

In `src/macros.inc`, the project macro `save_regs` pushes EBX, ECX, EDX, ESI, and EDI, and `restore_regs` pops them in reverse order. If `habits_done_today` used `restore_regs`, EBX would be overwritten with its pre-call value, destroying the documented output!

Therefore, `habits_done_today` uses explicit stack management:
```nasm
habits_done_today:
    push ecx
    push edx
    push esi
    push edi
    ...
    ; EAX = done count, EBX = total count
    pop edi
    pop esi
    pop edx
    pop ecx
    ret
```
Only the non-output registers (ECX, EDX, ESI, EDI) are preserved, leaving EAX and EBX as clean procedure outputs.

---

## 7. Verification & Test Evidence

### A. Clean Build
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
*(Zero warnings, zero errors)*

### B. Live Terminal Capture (80×24)

**1. Habit Tracker View with Active Check-Ins:**
```text
+------------------------------------------------------+
|  HABIT TRACKER                                       |
|  #  HABIT        LAST 7 DAYS         STREAK TOTAL    |
+------------------------------------------------------+
|  1. Drink water  [.][.][.][.][.][.][#]  1      1     |
|  2. Read 10 pgs  [.][.][.][.][.][#][#]  2      2     |
|  3. Stretch      [.][.][#][#][.][.][#]  1      3     |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  Checked in!                                         |
|  [A] Add  [1-8] Check in today  [D] Delete  [B] Back |
+------------------------------------------------------+
```

**2. Main Menu Live Dashboard Sync:**
```text
+------------------------------------------------------+
|   /\_/\    P A W M O D O R O                         |
|  ( o.o )   cozy focus - habits - notes               |
|   > ^ <                                              |
+------------------------------------------------------+
|  Today: 1 pomodoros      Habits: 3/3 done            |
|                                                      |
|  [1] Start focus session                             |
|  [2] Habit tracker                                   |
|  [3] Journal                                         |
|  [4] Demo mode: OFF                                  |
|  [Q] Quit                                            |
+------------------------------------------------------+
```

**3. Failed Save Banner (Row 14 in Bold Bright Red):**
```text
+------------------------------------------------------+
|  HABIT TRACKER                                       |
|  #  HABIT        LAST 7 DAYS         STREAK TOTAL    |
+------------------------------------------------------+
|  1. Fail test    [.][.][.][.][.][.][.]  0      0     |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  Could not save                                      |
|  [A] Add  [1-8] Check in today  [D] Delete  [B] Back |
+------------------------------------------------------+
```

### C. System Call Audit (`strace`)
```bash
strace -o /tmp/paw.strace -e trace=read,write ./build/pawmodoro
```
**Results:**
- Redraw on accepted action: **Exactly one `write(1, ...)` call**.
- Invalid keys pressed (e.g. `Z`, `9`, Space, arrow keys): **Zero writes**.
- Terminal exit: Single atomic write `\033[0m\033[?25h\033[?1049l` restores terminal attributes.

### D. GDB Register Verification
Inside GDB, we inspected `habits_done_today`:
```text
=== BEFORE CALL habits_done_today ===
ecx = 0x184 (388), edx = 0x0, esi = 0x804b34a, edi = 0x804e85d, ebx = 0x0
=== AFTER RETURN FROM habits_done_today ===
ecx = 0x184 (388), edx = 0x0, esi = 0x804b34a, edi = 0x804e85d, ebx = 0x0, eax = 0x0
```
Registers ECX, EDX, ESI, and EDI remained completely identical across the invocation.

---

## 8. Questions a Grader Might Ask

**Q1: How does Pawmodoro compute `index * 48` without using `IMUL`?**  
*Answer:* In 32-bit x86 assembly, multiplying by 48 can be decomposed into $(1 + 2) \times 16$:
```nasm
lea eax, [eax + eax*2]      ; EAX = index * 3
shl eax, 4                  ; EAX = (index * 3) * 16 = index * 48
```
This executes in two single-cycle instructions with zero multiplication hardware latency and zero register clobbering.

**Q2: What happens if `today - last_day >= 32`? Why is a manual comparison necessary?**  
*Answer:* On x86 processors, the `SHL` instruction masks the shift count to 5 bits (`count mod 32`). A shift count of 32 or larger would wrap around to `0..31` instead of clearing the register. We explicitly compare against 32 first (`cmp ecx, 32 / jae .hist_zero`); if $\Delta \ge 32$, we zero the history register before setting bit 0.

**Q3: How does the application prevent ANSI escape injection if a habit name contains control characters?**  
*Answer:* During row rendering in `habits_draw_row`, every character byte of the habit name is inspected before writing to the output buffer. If a byte is less than `0x20` (ASCII control characters like ESC, LF, CR) or equal to `0x7F` (DEL), the character is substituted with `'?'`. This prevents untrusted input from injecting terminal formatting sequences.

**Q4: Why does deleting a habit use `REP MOVSB` with `CLD` instead of a backward copy?**  
*Answer:* When habit $k$ is deleted, records $k+1$ through $N-1$ are moved to destination $k$. Because the destination memory address is lower than the source memory address ($\text{dest} < \text{src}$), the forward copy `CLD` + `REP MOVSB` reads source bytes before they are overwritten by destination writes, making forward copying completely safe.

**Q5: What happens if the system clock is set backwards or `last_day` is in the future?**  
*Answer:* If `last_day > today`, unsigned subtraction would wrap around to a huge integer. We guard against this with `cmp last_day, today / ja .already_done`. If `last_day` is in the future, it is safely treated as $\Delta = 0$ ("Already done today"), preventing streak resets and history bit corruption.
