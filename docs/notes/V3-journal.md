# Pawmodoro V3 Journal Implementation Note (Task V3-journal)

**Course:** CAO10 · **Project:** Pawmodoro (Group 8)  
**Target:** 32-bit x86 NASM Assembly on Linux (`int 0x80`, direct system calls, no libc)

---

## 1. Overview & Objectives

The **V3-journal** update upgrades Pawmodoro's persistent journal from a simple, fixed-width tail viewer into a full-featured, selectable, scrollable, and editable personal log.

Key capabilities introduced in this release:
1. **Adaptive UTF-8 Word Wrapping:** Each journal entry wraps cleanly across up to 4 visual rows calculated from the runtime terminal width (`ui_w - 6` display columns). Full 200-character entries are readable without artificial truncation or border clipping. Valid multibyte UTF-8 characters are never split across line boundaries. Non-printable control characters, ESC bytes, and invalid sequences are sanitized to `?`.
2. **Interactive Navigation & Selection:** The journal list displays entries ordered chronologically from top to bottom. Users navigate using `Up` and `Down` arrow keys. The currently selected entry is highlighted with ANSI reverse video (`\033[7m`), padded with spaces up to the border, and reset with `\033[0m`.
3. **Full-Entry Modal View:** Pressing `Enter` toggles a dedicated full-entry view showing the complete selected entry, allowing unobstructed reading of long reflections.
4. **Bounded Backward Reading (< 16 KB):** A chunked sliding-window reader (`journal_load_window`) reads up to 16 KB (`JRNL_BUF_SIZE = 16384`) using `sys_lseek`. Older and newer pages are navigated via `PgUp` and `PgDn`. Incomplete leading lines at chunk boundaries are discarded cleanly. The viewing subsystem never loads the whole file into memory.
5. **Atomic Entry Deletion (`file_delete_range`):** Pressing `D` or `Delete` prompts for confirmation (`Delete this entry? (y/n)`). When confirmed with `Y`, a generic low-level procedure copies preceding bytes into `journal.tmp` via a dedicated 2 KB buffer (`del_copy_buf`), skips the exact physical byte range of the selected entry (including trailing newline), copies succeeding bytes, closes all descriptors, and atomically replaces `journal.txt` via `sys_rename` (syscall 38).
6. **Failure Safety & Terminal Invariants:** If anything fails (e.g., `journal.tmp` is an existing directory or write fails), `journal.tmp` is unlinked (syscall 10) and `journal.txt` is left 100% byte-for-byte untouched. Cancellation via `N` leaves the disk untouched. Cooked mode signals (Ctrl+C) and raw mode exits cleanly restore terminal modes, alternate screens, and cursor visibility on every path.

---

## 2. Technical Architecture & Algorithms

### 2.1 UTF-8 Safe Word Wrapping & Row Budgeting

In Pawmodoro, each physical entry on disk follows the standard format:
```text
YYYY-MM-DD HH:MM | <user note text>\n
```
The date/time prefix occupies 19 characters (`JOURNAL_PREFIX_LEN = 19`).

When displaying an entry:
- **Visual Row 1:** Positions cursor at `(row, 4)`, outputs the reverse video escape code (if selected), emits the 19-byte timestamp prefix, and wraps the beginning of the user text into the remaining column budget:
  $$\text{Budget}_{\text{row 1}} = (ui\_w - 6) - 19$$
- **Continuation Rows (Rows 2..4):** If the user text exceeds Row 1, continuation rows are emitted on successive screen rows (`row + 1`, `row + 2`, etc.). Each continuation row is indented by 4 spaces (`UI_JRN_INDENT_COLS = 4`), leaving a column budget of:
  $$\text{Budget}_{\text{cont}} = (ui\_w - 6) - 4$$
- **Word Wrapping (`journal_wrap_segment`):** Scans the text character-by-character using `utf8_char_len`. If a space character (`0x20`) is found within the budget, its position is saved. When the column budget is exceeded, the line breaks at the last encountered space. If no space occurred, a hard break is made at the budget limit without splitting any multibyte UTF-8 sequence.
- **Reverse Video Padding:** When highlighted, the entry's line is padded with spaces up to `ui_w - 6` columns before `ansi_reset` (`\033[0m`) is emitted. This produces a sleek, uniform highlight bar anchored against the right border.

### 2.2 Bounded Window Loading & Offset Tracking

To comply with PRD §6.5 and §12 memory budgets, the journal viewer never loads more than 16 KB of file data into memory:
- `journal_load_tail`: Computes file size via `sys_lseek(fd, 0, SEEK_END)`. If size $\le 16384$, seeks to 0 and reads the entire file. If size $> 16384$, seeks to `file_size - 16384` and reads 16 KB, setting `jrnl_tail_partial = 1` and `jrnl_window_offset = file_size - 16384`.
- `journal_find_lines`:
  - When `jrnl_tail_partial == 1`, scans forward to the first newline (`0x0A`) and discards the leading partial line fragment.
  - Scans backwards from the end of the buffer, locating complete lines and recording 4 doublewords (16 bytes) per entry in `jrnl_entries`:
    1. `start_ptr`: Memory pointer in `jrnl_buf`.
    2. `text_len`: Text byte length excluding newline.
    3. `file_off`: Absolute physical byte offset in `journal.txt` (`jrnl_window_offset + local_offset`).
    4. `file_len`: Total byte length in `journal.txt` including newline.
  - Reverses entries into chronological order (oldest at index 0, newest at count - 1).

### 2.3 Atomic Byte-Range File Deletion (`file_delete_range`)

The generic deletion procedure in `src/file.asm` removes a byte range $[start, end)$ from any file:
1. **Validation:** Checks $0 \le start \le end \le file\_size$. If $start == end$, it exits immediately as a successful no-op ($0$).
2. **Temporary File:** Opens/creates `journal.tmp` with `O_WRONLY | O_CREAT | O_TRUNC` and mode `0644`.
3. **Pre-Range Copy:** Reads from the source file and writes to `journal.tmp` in 2 KB chunks using `del_copy_buf` until `start` bytes have been copied. Handles short reads and short writes cleanly.
4. **Range Skip:** Seeks the source file forward to `end` via `sys_lseek(src_fd, end, SEEK_SET)`.
5. **Post-Range Copy:** Copies the remainder of the file (`file_size - end` bytes) in 2 KB chunks.
6. **Closing Descriptors:** Both source and temporary descriptors are closed.
7. **Atomic Replacement:** Calls Linux `sys_rename(38)` with `oldpath = journal.tmp` and `newpath = original_file`.
8. **Error Clean-up:** On any failure prior to rename completion, both descriptors are closed, `sys_unlink(10)` is invoked on `journal.tmp`, and the original file remains byte-for-byte untouched.

---

## 3. Documented Procedure Contracts

### 3.1 New Procedure: `file_delete_range` (`src/file.asm`)

```nasm
;=============================================================================
; Procedure: file_delete_range
; Purpose:   Deletes the byte range [start_offset, end_offset) from the file
;            at path ESI by streaming unaffected data into a temporary file
;            ("journal.tmp") via a dedicated 2 KB copy buffer (del_copy_buf),
;            then atomically replacing the original file via sys_rename (38).
;            If any error occurs, unlinks journal.tmp and leaves original untouched.
; IN:        ESI = Pointer to NUL-terminated original file path,
;            EAX = Inclusive start byte offset of range to delete,
;            EDX = Exclusive end byte offset of range to delete
; OUT:       EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on failure / invalid offsets
; CLOBBERS:  EAX
; PRESERVES: EBX, ECX, EDX, ESI, EDI
;=============================================================================
```

### 3.2 New and Changed Journal Procedures (`src/journal.asm`)

#### `journal_load_window`
```nasm
;=============================================================================
; Procedure: journal_load_window
; Purpose:   Loads a bounded viewing window (up to JRNL_BUF_SIZE = 16384 bytes)
;            from journal.txt ending at target_end offset using sys_lseek & sys_read.
; IN:        EAX = Target end byte offset (0 = file tail / EOF)
; OUT:       None (writes jrnl_bytes_loaded, jrnl_window_offset, jrnl_tail_partial, jrnl_file_size)
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_load_tail`
```nasm
;=============================================================================
; Procedure: journal_load_tail
; Purpose:   Loads the newest 16 KB window from the end of journal.txt.
; IN:        None
; OUT:       None (calls journal_load_window with target_end = 0)
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_find_lines`
```nasm
;=============================================================================
; Procedure: journal_find_lines
; Purpose:   Scans jrnl_buf[0..jrnl_bytes_loaded) for complete physical lines
;            (up to JRNL_MAX_ENTRIES = 32 entries). Discards leading partial line
;            if jrnl_tail_partial == 1. Reverses chronological order into jrnl_entries.
; IN:        None (reads jrnl_bytes_loaded, jrnl_tail_partial, jrnl_window_offset, jrnl_buf)
; OUT:       None (writes jrnl_line_count, jrnl_entries, jrnl_lines)
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_wrap_segment`
```nasm
;=============================================================================
; Procedure: journal_wrap_segment
; Purpose:   Scans text at ESI (length ECX bytes) to find the wrap break point
;            that fits within EDX display columns. Breaks at last space or hard limit.
; IN:        ESI = Pointer to text segment in memory,
;            ECX = Remaining byte length of text,
;            EDX = Display column budget for current visual row
; OUT:       EAX = Byte length of text to emit on this row,
;            EDX = Byte count to advance text pointer for next row (skips space),
;            EBX = Display columns occupied by emitted segment
; CLOBBERS:  EAX, EBX, EDX
;=============================================================================
```

#### `journal_entry_row_count`
```nasm
;=============================================================================
; Procedure: journal_entry_row_count
; Purpose:   Calculates how many visual rows (1..4) an entry will occupy.
; IN:        ESI = Pointer to line text in memory,
;            ECX = Byte length of text
; OUT:       EAX = Visual row count (1..4)
; CLOBBERS:  EAX
;=============================================================================
```

#### `journal_draw_entry`
```nasm
;=============================================================================
; Procedure: journal_draw_entry
; Purpose:   Renders entry at index EAX starting at screen row EBX.
;            Wraps text across up to 4 visual rows; applies reverse video if EDX == 1.
; IN:        EAX = Entry index (0..jrnl_line_count - 1),
;            EBX = Screen row coordinate,
;            EDX = 1 if highlighted (selected), 0 otherwise
; OUT:       EAX = Number of visual rows rendered (1..4)
; CLOBBERS:  EAX
;=============================================================================
```

#### `journal_ensure_visible`
```nasm
;=============================================================================
; Procedure: journal_ensure_visible
; Purpose:   Adjusts jrnl_top_idx so that selected entry jrnl_sel_idx is visible
;            within available display rows (Rows 4..13).
; IN:        None (reads jrnl_sel_idx, jrnl_top_idx, jrnl_line_count)
; OUT:       None (updates jrnl_top_idx in memory)
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_draw`
```nasm
;=============================================================================
; Procedure: journal_draw
; Purpose:   Constructs the Journal screen in out_buf. Supports selectable list
;            view and modal full-entry view.
; IN:        None
; OUT:       Appends escape sequences and text to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_delete_prompt`
```nasm
;=============================================================================
; Procedure: journal_delete_prompt
; Purpose:   Handles deletion confirmation and execution for selected entry:
;            Prompts 'Delete this entry? (y/n)', calls file_delete_range on 'Y',
;            refreshes entries from disk, clamps selection, displays feedback.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_new_entry`
```nasm
;=============================================================================
; Procedure: journal_new_entry
; Purpose:   Interactive addition of a new journal entry via read_line and journal_add.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all)
;=============================================================================
```

#### `journal_run`
```nasm
;=============================================================================
; Procedure: journal_run
; Purpose:   Modal event loop for the Journal screen. Dispatches Up, Down, PgUp,
;            PgDn, Enter, D, Delete, N, V, B, Ctrl+C.
; IN:        None
; OUT:       None (returns to menu on exit)
; CLOBBERS:  None (preserves all)
;=============================================================================
```

---

## 4. Verification and Test Results

The implementation was rigorously verified using both headless automated suites and custom integration scripts:

1. **Compilation & Warning Check:**
   `make clean && make` produced `build/pawmodoro` with zero NASM compiler or linker warnings.
2. **Automated Smoke Suite (`tests/smoke.sh`):**
   Passed all 16 scenarios, including:
   - Scenario 6: Focus completion & quick note save.
   - Scenario 10: Journal entry creation, tail reload, full-entry modal view, deletion cancellation, and deletion confirmation.
   - Scenarios 12–13: Raw and cooked mode Ctrl+C terminal restorations.
   - Scenario 15: Adaptive terminal resizing and size gate recovery.
   - Scenario 16: Zero horizontal line overflow past the frame borders.
3. **200-Character Entry Word Wrapping:**
   Verified that a 200-character test reflection wraps across multiple visual rows, displays the date/time prefix on Row 1, indents continuation rows by 4 spaces, and does not corrupt the frame border.
4. **Entry Deletion Scenarios:**
   - **First entry deletion:** Deleted entry 1 of 3; remaining 2 entries verified on disk.
   - **Middle entry deletion:** Deleted entry 2 of 3; remaining 2 entries verified on disk.
   - **Last entry deletion:** Deleted entry 3 of 3; remaining 2 entries verified on disk.
   - **Only entry deletion:** Deleted the sole entry in `journal.txt`; file truncated to 0 bytes and UI displays `No entries yet.`.
   - **Cancellation:** Pressing `N` at the delete prompt left `journal.txt` byte-for-byte identical (`cmp` matched 100%).
5. **Failure Safety (Directory Block):**
   Created a directory named `journal.tmp` in the working directory and attempted an entry deletion. The operation failed cleanly with UI message `Could not delete`, leaving `journal.txt` untouched and `journal.tmp` intact as a directory.
6. **Large File Paging (> 16 KB):**
   Generated a 24.4 KB journal file with 400 entries. Navigated backwards using `PgUp` to load an older chunk, selected an entry from the older chunk, and deleted it. Confirmed that only the targeted physical line was removed from disk, leaving 399 valid lines.
7. **System Call Tracing (`strace`):**
   Verified with `strace -e trace=open,read,write,close,lseek,rename,unlink` that:
   - Chunk copying used 2048-byte chunks via `del_copy_buf`.
   - Temporary file `journal.tmp` was atomically renamed over `journal.txt` via `rename(38)`.
   - All opened file descriptors were cleanly closed on all code paths.
   - Zero temporary files remained in the directory upon completion.
