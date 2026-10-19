# Task 8: Journal Subsystem & Persistence Walkthrough

**Task ID:** `task-8-journal`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the architecture, assembly implementation, file persistence, backward line scanning, terminal protection, and verification results of the Journal subsystem completed in Task 8. It covers the line assembly mechanics of `journal_add`, single-sample local time calculations, tail seeking with Linux `sys_lseek` (syscall 19), backward line discovery, display-only truncation, ANSI injection immunity, interactive modal flows, and comprehensive test evidence. Written in clear, plain language, this guide equips any team member to confidently explain and defend the journal subsystem during project demonstrations.

---

## 1. Line Assembly & Single-Sample Timestamping (`journal_add`)

### The Purpose and Contract of `journal_add`
The `journal_add` procedure is designed as a standalone, modular utility reusable by other modules (for instance, the post-focus note prompt in the Pomodoro timer per PRD §4.2 FR-T8).
- **Input:** `ESI` = pointer to a NUL-terminated text string.
- **Output:** `EAX` = `FILE_OK` (`0`) on success, `FILE_ERR` (`-1`) on error or empty input.
- **Calling Convention:** Clobbers `EAX` and `EFLAGS` only. All other general-purpose registers (`EBX`, `ECX`, `EDX`, `ESI`, `EDI`) are strictly preserved.

### Single Clock Sampling to Prevent Midnight Divergence (PRD §6.3)
If a program calls `time_today` (to obtain the day number) and `time_local` (to obtain the time of day) as two separate system calls, an execution happening across midnight (e.g. 23:59:59.999 to 00:00:00.001) could produce a mismatched date and time (such as yesterday's date paired with 00:00).

In `journal_add`, we eliminate this race condition by querying the local clock exactly **once**:
```nasm
    ; Sample local clock exactly ONCE to prevent midnight divergence (PRD §6.3)
    call time_local             ; EAX = current local time in seconds (UTC + 28800)
    mov ebx, eax                ; EBX = local seconds

    ; Derive local day number: day_number = local_seconds / SECONDS_PER_DAY
    xor edx, edx                ; Zero EDX before unsigned division (never use cdq)
    mov ecx, SECONDS_PER_DAY    ; 86400
    div ecx                     ; EAX = quotient (day number)
```
The resulting day number in `EAX` is formatted into `date_buf` via `time_fmt_date`, and the sampled seconds in `EBX` are formatted into `time_buf` via `time_fmt_hhmm`. Both values are derived from the identical clock tick.

### Persistent String Assembly in `file_buf`
Rather than building into `line_buf` (which may hold the caller's text string), `journal_add` constructs the formatted line in `file_buf` (512-byte capacity):
$$\text{Line Layout} = \underbrace{\text{Date}}_{10\text{ B}} + \underbrace{\text{" "}}_{1\text{ B}} + \underbrace{\text{Time}}_{5\text{ B}} + \underbrace{\text{" | "}}_{3\text{ B}} + \underbrace{\text{Text}}_{\le 200\text{ B}} + \underbrace{\text{LF}}_{1\text{ B}}$$

```nasm
    ; Copy Date (10 bytes) from date_buf
    mov esi, date_buf
    mov ecx, JOURNAL_DATE_LEN   ; 10
    cld
    rep movsb

    ; Insert single space delimiter
    mov al, CHAR_SPACE
    stosb

    ; Copy Time (5 bytes) from time_buf
    mov esi, time_buf
    mov ecx, JOURNAL_TIME_LEN   ; 5
    rep movsb

    ; Copy Separator string " | " (3 bytes)
    mov esi, jrnl_sep
    mov ecx, JOURNAL_SEP_LEN    ; 3
    rep movsb
```

### Text Sanitizing, 200-Character Clamping, and Empty Rejection
1. **Empty Rejection:** If the string at `ESI` starts with `CHAR_NULL` (length 0), `journal_add` immediately returns `FILE_ERR` (`-1`) without opening or appending to `journal.txt`.
2. **Length Clamping:** At most `JOURNAL_ENTRY_MAX` (`200`) characters are transferred.
3. **Byte Sanitizing:** Any byte below `0x20` (ASCII control bytes like CR, LF, ESC, TAB) or equal to `0x7F` (DEL) is substituted with `'?'`. This guarantees the entry stays strictly on a single physical line and cannot inject ANSI escape codes.
4. **Line Termination:** A single `CHAR_LF` (`10` / `0x0A`) is appended. No carriage returns or NUL bytes are written to disk.
5. **Persistence:** The line is written via `file_append` with `O_WRONLY | O_CREAT | O_APPEND` (flag `0x441`) and mode `0644`.

Maximum line length: $19 + 200 + 1 = \mathbf{220}$ bytes (`JOURNAL_MAX_LINE`), easily fitting in `file_buf`.

---

## 2. File Format & Byte Layout of `journal.txt`

The persistent file `journal.txt` is an append-only, human-readable UTF-8/ASCII log file located in the current working directory.

### Visual Byte Breakdown
Each entry follows the strict specification:
$$\texttt{YYYY-MM-DD HH:MM | <text>\textbackslash n}$$

Below is an actual hex dump (`xxd`) from our test suite showing three recorded entries:
```text
00000000: 3230 3236 2d31 302d 3139 2031 373a 3038  2026-10-19 17:08
00000010: 207c 2066 6972 7374 206e 6f74 650a 3230   | first note.20
00000020: 3236 2d31 302d 3139 2031 373a 3038 207c  26-10-19 17:08 |
00000030: 2073 6563 6f6e 6420 6e6f 7465 0a32 3032   second note.202
00000040: 362d 3130 2d31 3920 3137 3a30 3820 7c20  6-10-19 17:08 | 
00000050: 7468 6972 6420 6e6f 7465 0a              third note.
```

Breaking down entry 1:
- `32 30 32 36 2d 31 30 2d 31 39` (Bytes 0..9): `"2026-10-19"` (10 ASCII bytes)
- `20` (Byte 10): Space delimiter
- `31 37 3a 30 38` (Bytes 11..15): `"17:08"` (5 ASCII bytes)
- `20 7c 20` (Bytes 16..18): `" | "` (3 ASCII bytes)
- `66 69 72 73 74 20 6e 6f 74 65` (Bytes 19..28): `"first note"` (10 ASCII bytes)
- `0a` (Byte 29): `\n` line feed (1 byte). Notice: zero carriage returns (`0x0D`) and zero NUL bytes (`0x00`).

---

## 3. Tail Loading (`sys_lseek`) & Backward Line Scanning

### Why `file_load` Cannot Be Reused Here
The generic persistence helper `file_load` in `src/file.asm` reads strictly from offset 0. If `journal.txt` grows to several megabytes, loading from offset 0 would read ancient entries and waste memory. To read the *most recent* entries in constant memory, `journal_load_tail` uses raw Linux `sys_lseek` (syscall 19) directly.

### The Tail Loading Routine (`journal_load_tail`)
1. **Open:** Calls `sys_open(path_journal, O_RDONLY, 0)`. If missing, returns safely with `jrnl_bytes_loaded = 0` (FR-D1: missing files are not errors).
2. **File Size via `SEEK_END`:**
   ```nasm
   mov ebx, [esp]              ; fd
   xor ecx, ecx                ; offset = 0
   mov edx, SEEK_END           ; 2 (SEEK_END)
   syscall SYS_LSEEK, ebx, ecx, edx
   ```
   The kernel returns the total file size in `EAX`. If `EAX <= 0`, the file is empty; it closes the descriptor and returns.
3. **Seek Offset Calculation:**
   - If `size > JRNL_BUF_SIZE` (4096): Seek to `(size - 4096)` with `SEEK_SET` (`0`), and set flag `jrnl_tail_partial = 1`.
   - If `size <= JRNL_BUF_SIZE` (4096): Seek to `0` with `SEEK_SET` (`0`), and set flag `jrnl_tail_partial = 0`.
4. **Tail Read:** Calls `sys_read(fd, jrnl_buf, 4096)` and stores the number of bytes read in `jrnl_bytes_loaded`.
5. **No Descriptor Leaks:** `sys_close` is executed unconditionally on every exit path where open succeeded.

### Discarding Partial Lines & Backward Discovery (`journal_find_lines`)
When a file exceeds 4096 bytes, seeking to `size - 4096` drops the read pointer into the middle of an arbitrary line. If displayed, this chopped line would look corrupted.

To guarantee only complete lines appear:
1. **Discarding the Partial Head:**
   If `jrnl_tail_partial == 1`, `journal_find_lines` scans forward from index 0 until it finds the first `CHAR_LF`. The valid line boundary `valid_start` is set to the byte immediately following that first LF. Everything prior is discarded.
2. **Scanning Backwards for Up to 10 Lines:**
   Starting at cursor $C = \text{bytes\_loaded} - 1$:
   - Skips any trailing newlines or empty lines.
   - Marks the last non-LF byte as `line_end`.
   - Scans backwards until encountering the preceding `CHAR_LF` or reaching `valid_start`.
   - Records the line's start pointer and length into a temporary stack array.
   - Repeats until 10 lines are found or the search boundary is passed.
3. **Reversal to Oldest-to-Newest Order:**
   Because backward scanning discovers lines newest-first (bottom of file to top), the collected pairs are reversed into `jrnl_lines`:
   $$\text{jrnl\_lines}[0] = \text{Oldest of the 10}, \quad \dots, \quad \text{jrnl\_lines}[K-1] = \text{Newest of the 10}$$
   The screen displays them sequentially from top to bottom (Rows 4 through 13).

---

## 4. Display Truncation & Terminal Escape Sanitizing

### Display-Only Truncation (52 Columns)
The terminal frame is 56 columns wide, with left border at Col 1 and right border at Col 56. The entry text starts at Col 4.
$$\text{Available Inner Columns} = 55 - 4 + 1 = \mathbf{52} \text{ characters}$$

To ensure a long entry never crosses Col 55 or collides with the right border `'|'`:
```nasm
    ; Clamp display length to JOURNAL_DISPLAY_WIDTH (52 columns)
    cmp ecx, JOURNAL_DISPLAY_WIDTH
    jbe .row_len_clamped
    mov ecx, JOURNAL_DISPLAY_WIDTH
.row_len_clamped:
```
The file retains the full 200 characters; only the visual presentation is clamped.

### Character Sanitization During Row Drawing
If a corrupted file or hand-edited note contains terminal escape codes (e.g. `\033[2J`), printing it directly would erase the screen or corrupt cursor positions. In `journal_draw_row`:
```nasm
    cmp al, CHAR_SPACE          ; Byte < 0x20 (control codes, LF, ESC, CR)?
    jb .row_sanitize
    cmp al, 127                 ; Byte == 0x7F (DEL)?
    je .row_sanitize
    jmp .row_emit_char
.row_sanitize:
    mov al, CHAR_QUESTION       ; Replace with '?'
```
Any escape or control character is rendered safely as `'?'`.

### Screen Repair After Cooked-Mode Wrapping
When typing a 200-character entry in cooked mode (`read_line`), terminal line-wrapping echoes text across multiple rows down to row 18.
During the subsequent frame redraw in `journal_draw`:
- Borders on Rows 1, 3, and 17 emit `ui_frame_hline` followed immediately by `ansi_erase_eol` (`ESC[K`), wiping any characters that wrapped into columns 57..80.
- Inner rows 2..16 are cleared with `ui_frame_row`.
- Row 18 emits `ansi_erase_eos` (`ESC[J`), clearing all wrapped lines down to the bottom of the 24-row terminal.
The entire display is restored with zero visual artifacts.

---

## 5. Interactive Workflows: New Entry (`N`) and View (`V`)

### Frame Geometry & Two-Phase Rendering (PRD §5)
```text
Row  1: +------------------------------------------------------+  (ui_frame_hline + ESC[K)
Row  2: |  JOURNAL                                             |  (Bold bright cyan)
Row  3: +------------------------------------------------------+  (ui_frame_hline + ESC[K)
Row  4: |  <Entry 1 / Hint / "No entries yet.">                |  (Col 4..55)
Row  5: |  <Entry 2>                                           |
...     |  ...                                                 |
Row 13: |  <Entry 10>                                          |
Row 14: |                                                      |  (Blank spacer)
Row 15: |  <Prompt / "Entry saved" / "Could not save">         |  (Message row)
Row 16: |  [N] New entry   [V] View recent   [B] Back          |  (Key help)
Row 17: +------------------------------------------------------+  (ui_frame_hline + ESC[K)
Row 18: (ESC[J clears remainder of 80x24 terminal)
```

### The New Entry Flow (`N`, Key `KEY_N`)
1. Sets `jrnl_msg` to `"New entry (max 200, Enter alone cancels): "` and draws frame.
2. Dynamically computes cursor column from prompt length with `str_len` (`UI_JRN_COL_MSG + str_len(prompt)`), placing cursor at Col 48 on Row 15.
3. Invokes `read_line` in cooked mode with `line_buf` and limit `JOURNAL_ENTRY_MAX` (`200`).
4. If length is 0 (Enter alone), cancels cleanly and clears prompt.
5. If non-empty, calls `journal_add`.
   - On success: sets message `"Entry saved"` (green). If the view was active (`jrnl_view_active == 1`), automatically reloads tail and refreshes lines so the new entry immediately displays!
   - On failure: sets message `"Could not save"` (red).
6. Sets `need_redraw = 1` for a single-syscall atomic redraw.

### The View Recent Flow (`V`, Key `KEY_V`)
1. Sets `jrnl_view_active = 1`.
2. Calls `journal_load_tail` and `journal_find_lines`.
3. If no entries exist or file is missing/empty, shows `"No entries yet."` in dim text.
4. Sets `need_redraw = 1`.

---

## 6. Verification & Test Evidence

All verification tests were executed inside an 80×24 `tmux` virtual terminal on Linux.

### A. Clean Warning-Free Build
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
*(Zero compiler warnings, zero linker warnings)*

### B. Live Terminal Screen Captures (80×24)

**1. Initial Journal Screen (Before pressing V):**
```text
+------------------------------------------------------+
|  JOURNAL                                             |
+------------------------------------------------------+
|  Press V to view recent entries.                     |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

**2. Journal Screen After Viewing Recent Entries (`V`):**
```text
+------------------------------------------------------+
|  JOURNAL                                             |
+------------------------------------------------------+
|  2026-10-19 17:08 | first note                       |
|  2026-10-19 17:08 | second note                      |
|  2026-10-19 17:08 | third note                       |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

**3. Confirmation Message & Auto-Refresh After 300-Char Entry:**
```text
+------------------------------------------------------+
|  JOURNAL                                             |
+------------------------------------------------------+
|  2026-10-19 17:08 | first note                       |
|  2026-10-19 17:08 | second note                      |
|  2026-10-19 17:08 | third note                       |
|  2026-10-19 17:09 | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  Entry saved                                         |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

**4. Large File Test (18,000 bytes, 100 entries — displays 091 to 100):**
```text
+------------------------------------------------------+
|  JOURNAL                                             |
+------------------------------------------------------+
|  2026-10-19 09:12 | entry 091 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 092 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 093 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 094 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 095 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 096 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 097 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 098 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 099 yyyyyyyyyyyyyyyyyyyyyyy|
|  2026-10-19 09:12 | entry 100 yyyyyyyyyyyyyyyyyyyyyyy|
|                                                      |
|                                                      |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

**5. Corrupted File Test (Escape sequences sanitized to `?`):**
```text
+------------------------------------------------------+
|  JOURNAL                                             |
+------------------------------------------------------+
|  2026-10-19 09:12 | bad ?[2J? bytes                  |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

**6. Missing or Empty File Test ("No entries yet.", no crash):**
```text
+------------------------------------------------------+
|  JOURNAL                                             |
+------------------------------------------------------+
|  No entries yet.                                     |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|                                                      |
|  [N] New entry   [V] View recent   [B] Back          |
+------------------------------------------------------+
```

### C. 220-Byte Line Length Audit
```bash
tail -n 1 /tmp/jtest/journal.txt | wc -c
```
**Result:** Exactly **220** bytes ($19\text{ prefix} + 200\text{ characters} + 1\text{ LF}$).

### D. System Call Audit (`strace`)
```bash
strace -e trace=open,openat,lseek,_llseek,read,write,close -o /tmp/jtest/strace.txt ./build/pawmodoro
```
**Captured Excerpts:**
1. **Append Mode Flags & Permissions:**
   ```text
   open("journal.txt", O_WRONLY|O_CREAT|O_APPEND, 0644) = 3
   ```
2. **Tail Read Flags & Lseek Invocations:**
   ```text
   open("journal.txt", O_RDONLY)           = 3
   lseek(3, 0, SEEK_END)                   = 36
   lseek(3, 0, SEEK_SET)                   = 0
   read(3, "2026-10-19 17:08 | first note\n...", 4096) = 36
   close(3)                                = 0
   ```
3. **Unhandled Key Test:**
   - Write count before pressing `'Z'`: `3`
   - Write count after pressing `'Z'`: `3`
   - Unhandled keys trigger zero system calls.
4. **Clean Exit:**
   ```text
   write(1, "\33[0m\33[?25h\33[?1049l", 18) = 18
   ```

---

## 7. Questions a Grader Might Ask

**Q1: Why must `time_local` be called only once inside `journal_add` instead of calling `time_today` and `time_local` separately?**  
*Answer:* If `time_today` and `time_local` were called in sequence, an execution occurring at the boundary of midnight could sample `time_today` at 23:59:59.999 (returning day $D$) and `time_local` at 00:00:00.001 (returning time 00:00). This would log yesterday's calendar date paired with today's midnight time. By calling `time_local` once and computing the day number via `div SECONDS_PER_DAY` on that exact timestamp, both the calendar date and the time of day are mathematically guaranteed to represent the same instant.

**Q2: How does `journal_load_tail` handle files larger than 4096 bytes, and why is the first partial line discarded?**  
*Answer:* When `sys_lseek(fd, 0, SEEK_END)` indicates a file size greater than 4096 bytes, `journal_load_tail` seeks to `size - 4096` before reading. Because this offset can fall into the middle of a line, the initial characters in `jrnl_buf` represent a truncated line fragment. To prevent displaying garbled text, `journal_find_lines` sets the `valid_start` boundary to the byte immediately following the first `\n` in the buffer, discarding the partial line completely.

**Q3: Why is line truncation performed only on display rather than when writing to `journal.txt`?**  
*Answer:* A journal entry can hold up to 200 characters, which provides significant expressive value for users taking detailed notes. Truncating the entry upon storage would permanently destroy data. Truncating at 52 characters strictly during screen rendering ensures the 56-column visual frame and borders remain pixel-perfect on an 80×24 terminal while keeping the full user note safely intact on disk.

**Q4: How does Pawmodoro prevent ANSI escape injection and cooked-mode terminal corruption?**  
*Answer:* Protection occurs at two levels:
1. **Input & Display Sanitization:** Both `journal_add` (before persisting) and `journal_draw_row` (before rendering) inspect every character byte. Any byte with value $< 0x20$ (e.g. `ESC = 27`, `LF = 10`, `CR = 13`) or $== 0x7F$ is converted to `'?'`. This neutralizes ANSI escape injection from hand-edited or corrupted files.
2. **Post-Echo Screen Repair:** Entering a 200-character line in cooked mode causes the terminal emulator to wrap text across lower rows. After input completion, `journal_draw` executes a full two-phase redraw: `ui_frame_hline` followed by `ansi_erase_eol` (`ESC[K`) clears all trailing wrapped text on rows 1, 3, and 17, while row 18 emits `ansi_erase_eos` (`ESC[J`) to wipe any remaining lines below the frame.

**Q5: Why does `journal_add` preserve `ESI` and `EDI` even though C calling conventions classify them as caller-saved or callee-saved scratch registers?**  
*Answer:* Under the project's strict calling convention (PRD §6.2 rule 1 and §6.4), procedures clobber `EAX` and `EFLAGS` only, preserving every other register. Reusable procedures like `journal_add` may be called from complex interactive routines (such as the timer engine or menu loops) that maintain active string pointers in `ESI` or buffer destinations in `EDI`. Guaranteeing total register preservation eliminates subtle clobber bugs across module boundaries.
