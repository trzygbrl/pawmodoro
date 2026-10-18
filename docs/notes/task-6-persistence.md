# Task 6: File Persistence & Pomodoro Statistics Walkthrough

**Task ID:** `task-6-persistence`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the architecture and implementation of the file persistence engine and Pomodoro statistics tracking completed in Task 6. It details raw Linux x86 system calls (`int 0x80`), file descriptor lifecycle management, the binary 12-byte `stats.dat` record layout, midnight day-rollover mathematics, graceful degradation across missing or corrupted files, error alerting ("Could not save"), and complete verification evidence. Written in accessible language, this guide enables any team member to confidently explain and defend the persistence subsystem during project evaluations.

---

## 1. Linux x86 System Calls for File I/O (`int 0x80`)

### Syscall Interface and Argument Registers
In 32-bit x86 Linux without standard C library (`libc`) dependencies, all operating system interactions are performed directly via the software interrupt `int 0x80`. The kernel identifies the requested service by the integer placed in register `EAX`, with arguments passed in `EBX`, `ECX`, and `EDX`:

| System Call | `EAX` Number | `EBX` (Arg 1) | `ECX` (Arg 2) | `EDX` (Arg 3) | Return in `EAX` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `sys_read` | `3` (`SYS_READ`) | File Descriptor (`fd`) | Buffer Pointer (`char*`) | Byte Count (`size_t`) | Bytes read (>=0) or `-errno` (<0) |
| `sys_write` | `4` (`SYS_WRITE`) | File Descriptor (`fd`) | Buffer Pointer (`char*`) | Byte Count (`size_t`) | Bytes written (>=0) or `-errno` (<0) |
| `sys_open` | `5` (`SYS_OPEN`) | Path String Pointer (`const char*`) | Access Flags (`int`) | Mode Permissions (`mode_t`) | New `fd` (>=0) or `-errno` (<0) |
| `sys_close` | `6` (`SYS_CLOSE`) | File Descriptor (`fd`) | — | — | `0` on success or `-errno` (<0) |

### Understanding Negative Return Values
In Linux kernel conventions, return values in `EAX` between `-1` and `-4095` (representing `-EPERM` through `-EDQUOT`) denote an error condition. In two's-complement 32-bit arithmetic, all negative integers have their sign bit (bit 31) set:
- After `syscall SYS_OPEN`, we test `EAX` using `test eax, eax` followed by `js .error_label` (Jump if Sign). If negative, `EAX` contains an error code (such as `-ENOENT = -2` when a file does not exist).
- If `EAX` is non-negative (`0`, `1`, `2`, `3`, ...), it represents a valid file descriptor assigned by the kernel.

### The Macro Trap: Register Aliasing in `syscall`
In `src/macros.inc`, the `syscall` macro expands sequentially:
```nasm
mov eax, %1
mov ebx, %2
mov ecx, %3
mov edx, %4
int 0x80
```
If caller parameters pass registers out of order (for instance, writing `syscall SYS_WRITE, ebx, edi, ecx`), NASM expands parameter `%4` into `mov edx, ecx` **after** parameter `%3` has already overwritten `ecx` with `edi`. To eliminate any risk of register clobbering, `src/file.asm` explicitly stages arguments in reverse dependency order:
```nasm
mov edx, ecx            ; EDX = count (length in bytes)
mov ecx, edi            ; ECX = buffer pointer
syscall SYS_WRITE, ebx, ecx, edx
```

---

## 2. File Access Flags and Octal Mode Permissions

### Open Flags Composition (PRD §3.1)
The flags argument to `sys_open` controls file creation, truncation, and access permissions. In Pawmodoro, these are defined symbolically in `src/constants.inc`:

1. **`file_load` (Reading):**
   - Uses `O_RDONLY` (`0x0000`).
   - Opens the file strictly for read operations. Mode is passed as `0` since no file is created.

2. **`file_save` (Writing / Overwriting):**
   - Uses `O_SAVE_FLAGS equ (O_WRONLY | O_CREAT | O_TRUNC)`:
     - `O_WRONLY` (`0x0001` / `1` dec): Open for writing only.
     - `O_CREAT`  (`0x0040` / `64` dec): Create the file if it does not already exist.
     - `O_TRUNC`  (`0x0200` / `512` dec): Truncate existing file size to 0 bytes upon opening.
     - **Combined Value:** `0x0001 | 0x0040 | 0x0200 = 0x0241` (`577` decimal).

3. **`file_append` (Appending):**
   - Uses `O_APPEND_FLAGS equ (O_WRONLY | O_CREAT | O_APPEND)`:
     - `O_APPEND` (`0x0400` / `1024` dec): Reposition write offset to end-of-file prior to each write.
     - **Combined Value:** `0x0001 | 0x0040 | 0x0400 = 0x0441` (`1089` decimal).

### What `0644` Mode Means (`FILE_MODE_0644`)
When `O_CREAT` creates a new file, the kernel requires a permissions mode bitmask. In Unix systems:
- Mode `0644` octal breaks down as:
  - User (Owner): `6` octal = `110` binary = Read (`4`) + Write (`2`).
  - Group: `4` octal = `100` binary = Read (`4`).
  - Others: `4` octal = `100` binary = Read (`4`).
- Converted to decimal: `(6 * 8^2) + (4 * 8^1) + (4 * 8^0) = (6 * 64) + (4 * 8) + 4 = 384 + 32 + 4 = 420`.
- In `src/constants.inc`, `FILE_MODE_0644 equ 420` guarantees that newly created files can be read and edited by the current user without exposing arbitrary execute permissions.

---

## 3. Strict File Descriptor Lifecycle & Leak Prevention

A critical operational requirement in long-running system utilities is deterministic resource cleanup. Operating systems enforce a strict per-process limit on open file descriptors (often 1024). Leaking descriptors will eventually exhaust process limits, causing future open calls to fail.

In `src/file.asm`, we follow a strict invariant:
> **Every opened descriptor is closed on every execution path, including errors.**

### Execution Paths in `file_load`
```
Call file_load
      │
      ▼
 sys_open (O_RDONLY)
      │
      ├─► Return < 0 (File missing / open error)
      │         └─► Do NOT call close (no valid fd was issued)
      │         └─► Return EAX = FILE_ERR (-1)
      │
      └─► Return >= 0 (Valid fd)
                │
                ▼
           sys_read (up to ECX bytes)
                │
                ▼
           sys_close (close fd immediately!)
                │
                ├─► Read returned < 0: Return EAX = FILE_ERR (-1)
                └─► Read returned >= 0: Return EAX = bytes_read
```

### Execution Paths in `file_write_common` (`file_save` / `file_append`)
```
Call file_save / file_append
      │
      ▼
 sys_open (O_SAVE_FLAGS / O_APPEND_FLAGS, 0644)
      │
      ├─► Return < 0 (Directory unwritable / open error)
      │         └─► Do NOT call close
      │         └─► Return EAX = FILE_ERR (-1)
      │
      └─► Return >= 0 (Valid fd)
                │
                ▼
           sys_write (write buffer)
                │
                ▼
           sys_close (close fd immediately!)
                │
                ├─► Bytes written != expected length: Return EAX = FILE_ERR (-1)
                └─► Bytes written == expected length: Return EAX = FILE_OK (0)
```
Notice that `sys_close` is executed **before** inspecting whether `sys_read` or `sys_write` succeeded or failed. The descriptor is closed on every branch.

---

## 4. The 12-Byte `stats.dat` Binary Layout

Per PRD §4.5 FR-D2, Pawmodoro persists Pomodoro statistics in a compact, fixed-size binary file of exactly 12 bytes (`STATS_RECORD_SIZE = 12`).

### Byte-by-Byte Memory & File Representation
The record consists of three 32-bit unsigned little-endian integers:
```text
+-------------------+-------------------+-------------------+
|  Day Number (DW)  | Today Count (DW)  | Total Count (DW)  |
|   Offset 0..3     |    Offset 4..7    |   Offset 8..11    |
+-------------------+-------------------+-------------------+
```

- **Offset `0` (4 bytes, `stats_day`):** Julian-style day number calculated via PRD §6.3:
  $$\text{day} = \frac{\text{unix\_time} + \text{TZ\_OFFSET}}{86400}$$
- **Offset `4` (4 bytes, `stats_today_count`):** Number of focus sessions completed naturally today.
- **Offset `8` (4 bytes, `stats_total_count`):** Lifetime completed focus sessions across all time.

### Little-Endian Byte Ordering Explained
x86 architecture is little-endian: the least significant byte (LSB) of a multi-byte word is stored at the lowest memory address.

For example, on October 18, 2026:
- Day number is `20752` decimal = `0x00005110` hex.
- Today count is `2` decimal = `0x00000002` hex.
- Total count is `2` decimal = `0x00000002` hex.

In memory and in the raw file `stats.dat`, the 12 bytes appear sequentially as:
```text
Offset (hex):   00 01 02 03   04 05 06 07   08 09 0A 0B
Raw Bytes:      10 51 00 00   02 00 00 00   02 00 00 00
Field:         [--- Day ---] [--- Today -] [--- Total -]
```

### Contiguous Storage in `src/data.asm`
In `src/data.asm`, variables are declared contiguously in the `.bss` section:
```nasm
section .bss
    stats_data:
    stats_day:                  resd 1          ; Offset 0 (4 bytes)
    stats_today_count:          resd 1          ; Offset 4 (4 bytes)
    stats_total_count:          resd 1          ; Offset 8 (4 bytes)
```
Because the assembler places `stats_day`, `stats_today_count`, and `stats_total_count` consecutively in memory, passing pointer `stats_data` to `file_save` or `file_load` with length `12` reads and writes all three fields in a single atomic I/O operation.

---

## 5. Day Rollover Mathematics & State Synchronization

### The Day Calculation Model (PRD §6.3)
Pawmodoro uses Unix epoch time (`sys_time`, syscall 13) adjusted by the configured timezone offset (`TZ_OFFSET = 28800` seconds for UTC+8, Philippine Standard Time):
$$\text{local\_seconds} = \text{unix\_time} + 28800$$
$$\text{day\_number} = \lfloor \text{local\_seconds} / 86400 \rfloor$$
This integer arithmetic is implemented in `time_today` (`src/time.asm`). Every unique local calendar day maps to a unique sequential integer.

### The Rollover Rule (PRD §4.5 FR-D2)
When the application starts (`stats_load`) or when a focus session finishes (`stats_add_pomodoro`), the system compares the stored record's `stats_day` against current `time_today`:
- **If `stats_day == current_day`:** The session occurred on the same day. `stats_today_count` is retained and incremented.
- **If `stats_day != current_day`:** Midnight has passed (either while the app was closed or while running continuously).
  - `stats_day` is updated to `current_day`.
  - `stats_today_count` is reset to `0`.
  - `stats_total_count` is **retained untouched** (preserving historical lifetime totals).

### Worked Example: Old Day Rollover
Suppose `stats.dat` contains an old session from a previous day:
- `day = 1` (an ancient day)
- `today_count = 5`
- `total_count = 9`

Hex dump of input file:
```text
01 00 00 00  05 00 00 00  09 00 00 00
```
1. **Startup (`stats_load`):**
   - Calls `time_today`, obtaining `current_day = 20752`.
   - Compares stored `stats_day` (`1`) with `20752`. They differ!
   - Rollover executes: `stats_day = 20752`, `stats_today_count = 0`.
   - `stats_total_count` remains `9`.
   - `dash_pomodoros` is updated to `stats_today_count` (`0`).
   - The main menu displays: `Today: 0 pomodoros`.
2. **Session Completion (`stats_add_pomodoro`):**
   - User completes 1 focus session.
   - Day check confirms `stats_day == 20752`.
   - Increments: `stats_today_count` becomes `0 + 1 = 1`.
   - Increments: `stats_total_count` becomes `9 + 1 = 10`.
   - Synchronizes `dash_pomodoros = 1`.
   - Writes 12 bytes to disk.
   - New `xxd stats.dat`:
     ```text
     10 51 00 00  01 00 00 00  0a 00 00 00
     ```
     `day = 20752`, `today_count = 1`, `total_count = 10`.

---

## 6. Focus Session Completion Hook & Failure Resilience

### Natural Focus Completion Rule (PRD §4.2 FR-T7)
A Pomodoro session must count toward statistics **only if it runs naturally to zero**:
- **Skipped Focus (`S` key):** Transits to break, but does not award completion.
- **Quit / Stopped Session (`Q` key):** Exits to menu immediately without completion.
- **Ctrl+C / Interruption:** Exits immediately without completion.
- **Break Completions:** Short and long breaks do not increment Pomodoro counts.

In `src/timer.asm`, this is enforced at the natural expiration label `.phase_natural_complete`:
```nasm
.phase_natural_complete:
    cmp dword [phase], PHASE_FOCUS
    jne .draw_completion_frame
    mov dword [focus_completed_flag], 1
    call stats_add_pomodoro             ; Task 6 Hook: executed ONLY on natural focus completion
```

### The "Could Not Save" Warning Banner (PRD §4.5 FR-D4)
If disk persistence fails (e.g. disk full, permission denied, or read-only filesystem):
1. `file_save` catches the negative return from `sys_open` or `sys_write` and returns `-1`.
2. `stats_add_pomodoro` sets `[stats_save_failed] = STATS_SAVE_FAILED` (`1`), but retains the incremented count in memory so the in-memory dashboard stays accurate.
3. The program **never crashes** and never terminates abruptly.
4. During completion frame assembly in `timer_draw`, the UI inspects `stats_save_failed`:
```nasm
    cmp dword [phase], PHASE_FOCUS
    jne .skip_msg
    cmp dword [stats_save_failed], STATS_SAVE_FAILED
    jne .skip_msg

    mov eax, UI_TIMER_ROW_BLANK1        ; Row 3
    mov ebx, UI_TIMER_COL_MSG           ; Column 4
    call buf_goto
    mov esi, ansi_bold
    call buf_str
    mov esi, ansi_fg_bright_red
    call buf_str
    mov esi, err_could_not_save         ; "Could not save"
    call buf_str
    mov esi, ansi_reset
    call buf_str
.skip_msg:
```
5. The warning message is rendered in bold bright red on Row 3 directly within the completion frame and flushed in the exact same single `sys_write(1, ...)` call.

---

## 7. Edge Cases: Missing, Empty, and Corrupted Files

Per PRD §4.5 FR-D1:
> *"Missing, empty, or corrupted data files must be treated as empty state without crashing or printing an error to stderr."*

In `stats_load` (`src/stats.asm`):
```nasm
    mov esi, path_stats
    mov edi, stats_data
    mov ecx, STATS_RECORD_SIZE          ; 12 bytes
    call file_load

    cmp eax, STATS_RECORD_SIZE
    jb .load_empty_state                ; Negative (-1) or < 12 bytes -> fallback
```

We evaluate three potential edge cases:
1. **Missing File (`stats.dat` absent):**
   - `sys_open` returns `-ENOENT` (`-2`).
   - `file_load` detects negative return and returns `FILE_ERR` (`-1`).
   - Unsigned comparison `cmp eax, 12 / jb .load_empty_state` branches to `.load_empty_state` because `-1` (`0xFFFFFFFF` unsigned) is handled cleanly.
   - Populates `day = today`, `today_count = 0`, `total_count = 0`.
2. **Empty File (`0` bytes):**
   - `sys_read` returns `0`.
   - `cmp eax, 12` triggers `jb .load_empty_state` (`0 < 12`).
   - Treats as empty state without crash.
3. **Corrupted / Truncated File (e.g. `5` bytes):**
   - `sys_read` returns `5`.
   - `cmp eax, 12` triggers `jb .load_empty_state` (`5 < 12`).
   - Partial or corrupted data is discarded, preventing invalid garbage values from leaking into counters.

---

## 8. Verification & Test Evidence

All acceptance criteria from the specification were validated inside a Linux environment.

### A. Clean Build & Executable Format
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

### B & C. Persistence Across Restarts & Hex Layout (`xxd`)
We completed two consecutive demo focus sessions (10 seconds each) and inspected the resulting `stats.dat`:
```bash
xxd stats.dat
```
**Output:**
```text
00000000: 1051 0000 0200 0000 0200 0000           .Q..........
```
- Bytes 0..3: `10 51 00 00` = `0x00005110` = `20752` (Current Day Number).
- Bytes 4..7: `02 00 00 00` = `0x00000002` = `2` (`today_count`).
- Bytes 8..11: `02 00 00 00` = `0x00000002` = `2` (`total_count`).
- File size is **exactly 12 bytes**.
- Upon restarting Pawmodoro, the main menu displayed:
```text
+------------------------------------------------------+
|  PAWMODORO                                           |
|                                                      |
|   Today: 2 pomodoros                                 |
|   Habits: 2/4 done                                   |
```

### D. Skipped and Stopped Sessions
- Pressed `S` mid-focus: session skipped to break, menu counter remained `0`.
- Pressed `Q` mid-focus: session stopped, returned to menu, counter remained `0`.

### E. Missing, Empty, and Truncated Files
- `rm stats.dat`: Startup succeeded without crash; dashboard showed `Today: 0 pomodoros`.
- `: > stats.dat` (0 bytes): Startup succeeded without crash; dashboard showed `Today: 0 pomodoros`.
- `printf 'abcde' > stats.dat` (5 bytes): Startup succeeded without crash; dashboard showed `Today: 0 pomodoros`.

### F. Day Rollover Keeps Total
We seeded `stats.dat` with an old day (`day = 1`), `today_count = 5`, and `total_count = 9`:
```bash
printf '\x01\x00\x00\x00\x05\x00\x00\x00\x09\x00\x00\x00' > stats.dat
```
- On startup, the main menu showed `Today: 0 pomodoros`.
- Completed 1 demo focus session.
- Inspected `stats.dat` with `xxd`:
```text
00000000: 1051 0000 0100 0000 0a00 0000           .Q..........
```
- Stored values: `day = 20752`, `today_count = 1`, `total_count = 10` (`0x0a`). Lifetime total was preserved!

### G. Failed Save Handling
We simulated a write failure by making `stats.dat` a directory (`rm -f stats.dat && mkdir stats.dat`):
- Completed 1 demo focus session.
- The app continued running normally without crashing.
- Terminal screen capture on completion frame:
```text
+------------------------------------------------------+
|  FOCUS - Session 1 of 4                    [DEMO]    |
|                                                      |
|   Could not save                                     |
|     /\_/\                                            |
|    ( -.- )       00:00                               |
|     > ^ <                                            |
|   [##############################]  100%             |
|  Focus complete! Press any key for a break.          |
|  [P] Pause    [S] Skip    [Q] Stop and go back       |
+------------------------------------------------------+
```
`Could not save` was displayed on Row 3 in bright red.

### H. System Call Trace (`strace`)
We traced system calls using `strace -e trace=open,read,write,close`:
```text
open("stats.dat", O_RDONLY)             = -1 ENOENT (No such file or directory)
...
open("stats.dat", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 3
write(3, "\10Q\0\0\1\0\0\0\1\0\0\0", 12) = 12
close(3)                                = 0
write(1, "\33[1;1H\33[1;1H+-------------------"..., 591) = 591
```
- Open uses exact flags `O_WRONLY|O_CREAT|O_TRUNC` and permissions `0644`.
- Exactly 1 write of 12 bytes to file descriptor 3.
- Descriptor 3 is immediately closed.
- Every screen frame is rendered with exactly one `sys_write` to `fd 1`.

---

## 9. Questions a Grader Might Ask

**Q1: Why did you declare `stats_day`, `stats_today_count`, and `stats_total_count` contiguously in `.bss`?**  
*Answer:* Declaring them consecutively in `.bss` guarantees that the linker allocates their 12 bytes contiguously in memory. Because the memory layout matches the binary file layout byte-for-byte, `file_save` can write all 12 bytes directly from pointer `stats_data` in a single `sys_write` call, and `file_load` can read them directly into memory in a single `sys_read` call.

**Q2: What happens if `stats.dat` is only 5 bytes long?**  
*Answer:* In `stats_load`, we call `file_load` with maximum bytes 12. `file_load` returns the number of bytes read (5) in `EAX`. `stats_load` then executes `cmp eax, STATS_RECORD_SIZE` (12) followed by `jb .load_empty_state`. Because 5 is less than 12, the file is identified as truncated/corrupted and safely treated as an empty state (`today_count = 0`, `total_count = 0`), preventing memory corruption.

**Q3: Why do you close the file descriptor even if `sys_write` or `sys_read` fails?**  
*Answer:* Once `sys_open` succeeds, the Linux kernel assigns an active file descriptor table entry to the process. If a subsequent read or write fails, that descriptor remains allocated until closed. If we failed to close it on error paths, repeated failures would leak descriptors until the process hit `RLIMIT_NOFILE` and could no longer open any files.

**Q4: How does Pawmodoro differentiate between a user skipping a session and completing a session?**  
*Answer:* The timer engine marks `focus_completed_flag = 1` and calls `stats_add_pomodoro` strictly at label `.phase_natural_complete`, which is reached only when the countdown timer decrements naturally to 0. If the user presses `S` (Skip) or `Q` (Stop), execution jumps directly to `.advance_skip` or `.exit_to_menu`, bypassing the hook entirely.

**Q5: Why did you pass mode `420` decimal to `sys_open`?**  
*Answer:* In standard Unix file permissions, `0644` is written in octal. NASM evaluates numbers with a leading zero as decimal unless specified with an octal prefix (`0o644` or `420`). To avoid any assembler syntax ambiguities or accidental base-10 interpretation, we explicitly defined `FILE_MODE_0644 equ 420` in `src/constants.inc`. In binary, `420 = (110 100 100)_2`, which assigns read/write permissions to the owner and read-only permissions to group and others.
