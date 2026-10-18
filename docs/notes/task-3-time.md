# Task 3: Time & Date Utilities Walkthrough

**Task ID:** `task-3-time`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the time and date subsystem implemented in Task 3 (`src/time.asm`). It covers Linux time system calls, struct timespec, timezone offsets, day numbers, Howard Hinnant's integer civil calendar conversion algorithm, time formatting, and debugging techniques. It is written in plain language so any group member can explain and demonstrate these components during project defense and live evaluations.

---

## 1. Time Fundamentals: Epoch, Local Time, and Day Numbers

### What is the Unix Timestamp?
The **Unix timestamp** is an integer representing the number of elapsed seconds since **Thursday, January 1, 1970, 00:00:00 UTC** (known as the Unix Epoch).
- System call `sys_time` (syscall number 13) queries the Linux kernel for this value:
  ```nasm
  syscall SYS_TIME, 0    ; EBX = 0 (NULL tloc pointer)
  ```
  The kernel returns the UTC timestamp directly in `EAX`.

### Why Does `TZ_OFFSET` Exist?
Unix timestamps are strictly in Coordinated Universal Time (UTC). The Philippines operates in the **UTC+8** timezone (Philippine Standard Time, PST / PHT), with no daylight saving time (DST).
- 8 hours corresponds to:
  $$8 \times 3600 \text{ seconds} = 28,800 \text{ seconds}$$
- In `src/constants.inc`, we define:
  ```nasm
  TZ_OFFSET equ 28800    ; UTC+8 timezone offset in seconds
  ```
- `time_local` simply calls `time_now` (retrieving UTC seconds in `EAX`) and adds `TZ_OFFSET`. This yields the current local time in seconds without needing floating-point math or timezone database files.

### What is the Day Number?
A **day number** is an integer representing the total count of full days that have elapsed since the Unix epoch (1970-01-01 = Day 0).
- One day consists of exactly:
  $$24 \times 60 \times 60 = 86,400 \text{ seconds}$$
- To determine the current local day number, `time_today` takes the local timestamp and divides it by 86,400:
  $$\text{day\_number} = \frac{\text{local\_seconds}}{86400}$$
- **Why this matters for Pawmodoro:** Daily habits and streaks in Task 7 and Task 8 rely on this number. By comparing the saved day number against `time_today`, the application can instantly detect whether a new calendar day has arrived and reset daily checkboxes or calculate streak continuity!

---

## 2. High-Resolution Sleeping: `sys_nanosleep` & `timespec`

### The `struct timespec` Layout
In Linux 32-bit x86, `struct timespec` is an 8-byte structure allocated in `.bss`:
```
+-----------------------------------+-----------------------------------+
| tv_sec (4 bytes, dword)           | tv_nsec (4 bytes, dword)          |
| Seconds to sleep                  | Nanoseconds to sleep (0..10^9 - 1)|
+-----------------------------------+-----------------------------------+
```
- In `src/constants.inc`:
  ```nasm
  TIMESPEC_SIZE   equ 8
  NANOSLEEP_100MS equ 100000000   ; 100,000,000 nanoseconds = 100 ms
  ```
- In `src/data.asm`:
  ```nasm
  timespec: resb TIMESPEC_SIZE    ; 8 bytes in .bss
  ```

### Why Does the Timer Sleep in 100 ms Steps?
To sleep for 100 milliseconds, `time_sleep_100ms` writes `0` to `timespec.tv_sec` and `100,000,000` to `timespec.tv_nsec`, then invokes `sys_nanosleep` (syscall 162):
```nasm
syscall SYS_NANOSLEEP, timespec, 0
```
Sleeping in **100 ms steps** (10 ticks per second) is the ideal balance for a Pomodoro timer:
1. **Zero Busy-Waiting:** The process sleeps in the kernel wait queue. CPU usage stays at virtually 0.0%.
2. **Instant Responsiveness:** At 100 ms per step, user keystrokes (such as pause, skip, or menu) are detected with maximum 0.1-second latency, feeling completely immediate.
3. **Smooth Countdown:** Tenth-of-a-second ticks allow smooth animation and clock updates without burning CPU cycles.
4. **Interrupted Sleeps (EINTR):** Per PRD §6.4, if a sleep is interrupted by a signal, it does not need to be retried; the event loop simply continues to the next cycle.

---

## 3. Why Division Uses Unsigned `DIV` with `EDX` Zeroed

In x86 assembly, 32-bit division is performed by the `DIV` (unsigned) or `IDIV` (signed) instruction.

### The 64-bit Dividend `EDX:EAX`
The x86 `DIV r32` instruction divides a **64-bit dividend** across two registers, `EDX:EAX`, by the 32-bit divisor in `r32`:
- High 32 bits = `EDX`
- Low 32 bits = `EAX`
- Quotient is stored in `EAX`, and Remainder is stored in `EDX`.

### Why `XOR EDX, EDX` is Mandatory
When dividing a 32-bit value in `EAX`, whatever garbage happens to be in `EDX` becomes the upper 32 bits of the dividend!
- If `EDX` is not cleared, the dividend is huge ($EAX + EDX \cdot 2^{32}$). Dividing a 64-bit value by a 32-bit divisor will almost certainly produce a quotient exceeding 32 bits, immediately triggering a CPU **Divide Error Exception (`#DE`, SIGFPE crash)**.
- Therefore, we must zero `EDX` before every unsigned division:
  ```nasm
  xor edx, edx        ; Clear high 32 bits of dividend
  div ebx             ; EAX = quotient, EDX = remainder
  ```

### Why `CDQ` Must Never Be Used Here
`CDQ` (Convert Doubleword to Quadword) sign-extends `EAX` into `EDX`:
- If bit 31 of `EAX` is 1 (e.g., timestamps > $2^{31}-1 \approx 2.14 \times 10^9$ seconds), `CDQ` sets `EDX = 0xFFFFFFFF`.
- In an unsigned `DIV`, `0xFFFFFFFF` in `EDX` represents an enormous number, causing an instant `#DE` crash!
- Since timestamps, day counts, hours, and minutes are strictly non-negative, unsigned division with `xor edx, edx` is guaranteed to be safe and overflow-free.

---

## 4. Gregorian Calendar Conversion: Howard Hinnant's Algorithm

Converting a linear day count into a `YYYY-MM-DD` calendar date is notoriously difficult because:
- Month lengths vary (28, 29, 30, 31 days).
- Leap years occur every 4 years, except century years (100, 200, 300) which are common years, except 400-year centuries (1600, 2000, 2400) which are leap years!
- The variable leap day (February 29) is in the middle of the calendar year.

Howard Hinnant designed an exact, purely integer arithmetic algorithm ("civil_from_days") that avoids all branch-heavy loops and lookup tables.

### Step-by-Step Worked Example: Day 10957 (= 2000-01-01)

Let us trace Day `10957` step by step through our assembly code:

#### Step 1: Shift Epoch to March 1, Year 0 (`z = days + 719468`)
- In `constants.inc`: `CIVIL_EPOCH_SHIFT equ 719468`
- $$z = 10957 + 719468 = 730,425$$
- **Why:** March 1st is chosen as the start of the computational year. This places February (and its leap day) as the **12th and final month** of the year. Any extra leap day simply lands at the very end of the year, preventing February from shifting the offsets of the subsequent 10 months!

#### Step 2: Compute 400-Year Era (`era = z / 146097`)
- In the Gregorian calendar, leap rules repeat exactly every 400 years:
  $$400 \times 365 + 97 \text{ leap days} = 146,097 \text{ days}$$
- $$era = \lfloor 730425 / 146097 \rfloor = 4$$
- $$doe = 730425 \pmod{146097} = 146,037 \text{ (day of era)}$$

#### Step 3: Compute Year-of-Era (`yoe`)
- Formula:
  $$yoe = \lfloor (doe - \lfloor doe/1460 \rfloor + \lfloor doe/36524 \rfloor - \lfloor doe/146096 \rfloor) / 365 \rfloor$$
  - $t_1 = \lfloor 146037 / 1460 \rfloor = 100$ (4-year cycles)
  - $t_2 = \lfloor 146037 / 36524 \rfloor = 3$ (100-year non-leap centuries)
  - $t_3 = \lfloor 146037 / 146096 \rfloor = 0$ (400-year boundary adjustment)
  - $\text{Numerator} = 146037 - 100 + 3 - 0 = 145,940$
  - $$yoe = \lfloor 145940 / 365 \rfloor = 399$$

#### Step 4: Compute Preliminary Year (`y`)
- $$y = yoe + era \times 400 = 399 + 4 \times 400 = 1999$$
- **Why:** Because our computational year began on March 1st, January 2000 is still considered part of computational year 1999.

#### Step 5: Compute Day-of-Year (`doy`)
- Subtract days in the preceding 399 years of the era:
  $$\text{elapsed} = 365 \times 399 + \lfloor 399/4 \rfloor - \lfloor 399/100 \rfloor = 145635 + 99 - 3 = 145,731$$
- $$doy = doe - \text{elapsed} = 146037 - 145731 = 306$$
- (Day 0 = March 1; Day 306 = January 1).

#### Step 6: Compute Month Position (`mp`)
- Formula: $mp = \lfloor (5 \times doy + 2) / 153 \rfloor$
- $$5 \times 306 + 2 = 1532$$
- $$mp = \lfloor 1532 / 153 \rfloor = 10$$
- **Why 153?** In the Roman calendar starting in March, the 5-month pattern of days (31, 30, 31, 30, 31) has a sum of exactly **153 days**. Dividing $(5 \times doy + 2)$ by 153 maps the day directly to month index $mp \in [0..11]$!

#### Step 7: Compute Day of Month (`d`)
- Formula: $d = doy - \lfloor (153 \times mp + 2) / 5 \rfloor + 1$
- $$153 \times 10 + 2 = 1532 \implies \lfloor 1532 / 5 \rfloor = 306$$
- $$d = 306 - 306 + 1 = 1$$

#### Step 8: Convert Roman Month to Civil Month (`m`)
- If $mp < 10$: $m = mp + 3$ (March = 3 .. December = 12).
- Else ($mp \ge 10$): $m = mp - 9$ (January = 1, February = 2).
- Since $mp = 10$:
  $$m = 10 - 9 = 1 \text{ (January)}$$

#### Step 9: Adjust Year for January/February
- If $m \le 2$, increment $y$ by 1:
  $$y = 1999 + 1 = 2000$$

#### Step 10: Format String Directly into `[EDI]`
- Year $2000 \rightarrow$ `'2'`, `'0'`, `'0'`, `'0'`
- Delimiter $\rightarrow$ `'-'`
- Month $1 \rightarrow$ `'0'`, `'1'`
- Delimiter $\rightarrow$ `'-'`
- Day $1 \rightarrow$ `'0'`, `'1'`
- Terminator $\rightarrow$ `'\0'`
- **Output:** `"2000-01-01\0"` (exactly 11 bytes).

---

## 5. Time Formatting: Computing `HH:MM` from Local Seconds

To format the 24-hour time of day into `"HH:MM\0"` (6 bytes):
1. **Compute Seconds into Current Day:**
   $$\text{secs\_today} = \text{local\_seconds} \pmod{86400}$$
   (Discarding all previous elapsed days).
2. **Compute Hours:**
   $$\text{hours} = \lfloor \text{secs\_today} / 3600 \rfloor \quad (0..23)$$
   $$\text{rem\_secs} = \text{secs\_today} \pmod{3600} \quad (0..3599)$$
   Format hours as 2 decimal digits with leading zeros at `[EDI + 0..1]`.
3. **Write Separator:**
   Store `':'` at `[EDI + 2]`.
4. **Compute Minutes:**
   $$\text{mins} = \lfloor \text{rem\_secs} / 60 \rfloor \quad (0..59)$$
   Format minutes as 2 decimal digits with leading zeros at `[EDI + 3..4]`.
5. **Write Null Terminator:**
   Store `'\0'` at `[EDI + 5]`.

Both `time_fmt_date` and `time_fmt_hhmm` write directly to memory buffers without calling `buf_*`, ensuring they can be reused by file serializers and the journal subsystem (T8).

---

## 6. Verification and Testing

### 1. Build Verification
```bash
make clean && make
```
Builds cleanly with zero warnings (`nasm -f elf32 -g -F dwarf -Wall` and `ld -m elf_i386`).

### 2. Execution and Accuracy Check
```bash
./build/pawmodoro
```
Sample verified output:
```text
Today's day number: 20744
Today's date: 2026-10-18
Current local time (HH:MM): 19:37
Day 0: 1970-01-01
Day 10957: 2000-01-01
Day 19723: 2024-01-01
Slept 10 x 100 ms
```
- Compare with system clock:
  ```bash
  TZ=Asia/Manila date '+%Y-%m-%d %H:%M'
  echo $(( ($(date +%s) + 28800) / 86400 ))
  ```
  Both match the binary's output identically.

### 3. Timing and Sleep Verification
```bash
time ./build/pawmodoro
```
Reports:
- **Real:** ~1.008s (10 sleeps of 100 ms)
- **User CPU:** 0.001s (virtually zero)
- **Sys CPU:** 0.000s

### 4. System Call Tracing with `strace`
```bash
strace -e trace=nanosleep,time ./build/pawmodoro
```
Shows:
- 3 calls to `time(NULL)` to retrieve current timestamp.
- Exactly 10 calls to `nanosleep({tv_sec=0, tv_nsec=100000000}, NULL) = 0`.
- Exit status code `0`.

### 5. Register Preservation Verification in GDB
Both `time_fmt_date` and `time_fmt_hhmm` strictly preserve all general-purpose registers (including `EAX` and `EDI`):
```gdb
break time_fmt_date
run
info registers eax ebx ecx edx esi edi ebp esp
# check after procedure return
info registers eax ebx ecx edx esi edi ebp esp
```
All register values are confirmed 100% identical before and after invocation.

### 6. Edge Cases Tested
| Case | Input Value | Expected Output | Actual Output | Result |
|---|---|---|---|---|
| Day 59 | 59 | `1970-03-01` | `1970-03-01` | PASS |
| Day 11016 (Leap Day) | 11016 | `2000-02-29` | `2000-02-29` | PASS |
| Day 11017 | 11017 | `2000-03-01` | `2000-03-01` | PASS |
| Day 47482 (Century) | 47482 | `2100-01-01` | `2100-01-01` | PASS |
| Seconds 0 | 0 | `00:00` | `00:00` | PASS |
| Seconds 59 | 59 | `00:00` | `00:00` | PASS |
| Seconds 3599 | 3599 | `00:59` | `00:59` | PASS |
| Seconds 86399 | 86399 | `23:59` | `23:59` | PASS |

---

## 7. Looking Ahead

The procedures created in Task 3 form the temporal backbone of Pawmodoro:
- **Task 4 (UI & Menu):** Displays today's date and the current local time in the application header banner.
- **Task 5 (Timer FSM):** Runs the main Pomodoro tick loop using `time_sleep_100ms` for smooth 100 ms countdown intervals.
- **Task 7 (Habits):** Uses `time_today` to detect midnight roll-overs and evaluate streak maintenance.
- **Task 8 (Journal):** Uses `time_fmt_date` and `time_fmt_hhmm` to timestamp journal entries written to `journal.txt`.
