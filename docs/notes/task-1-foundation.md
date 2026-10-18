# Task 1: Foundation Layer & Buffered Output Walkthrough

**Task ID:** `task-1-foundation`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the technical architecture, mathematical calculations, memory management, and calling conventions introduced in Task 1. It is designed to allow any team member to clearly explain and demonstrate the foundation layer during a project presentation.

---

## 1. Why Buffer a Frame and Flush Once? (Eliminating Flicker & Syscall Overhead)

Terminal user interfaces (TUIs) that output character-by-character or line-by-line via multiple individual `sys_write` system calls suffer from two major problems:

1. **Visual Flicker (Tearing):**  
   If a program sends the cursor-home command, clears part of the screen, and draws frames line by line across multiple write syscalls, the terminal emulator renders intermediate partial states between system calls. The human eye perceives this as constant, distracting screen flicker.
2. **Context Switching Overhead:**  
   Every `int 0x80` system call forces the CPU to switch from user mode (Ring 3) to kernel mode (Ring 0). Calling `sys_write` hundreds of times per frame wastes CPU cycles and battery life.

**The Solution:**  
In Pawmodoro, all UI rendering routines (`buf_char`, `buf_str`, `buf_u32`, `buf_goto`, etc.) write bytes strictly into an in-memory staging buffer (`out_buf`). Once the complete 80×24 screen frame is assembled, `buf_flush` outputs the entire buffer to the terminal using **exactly ONE `sys_write` system call**. The terminal renders the finished frame instantaneously, providing crisp, flicker-free animations while keeping CPU utilization well under 1%.

---

## 2. Memory Organization: `out_buf`, `out_len`, and Overflow Protection

In `src/data.asm`, the `.bss` section allocates an 8,192-byte buffer and a 4-byte length counter:

```nasm
section .bss
    out_buf:    resb OUT_BUF_SIZE    ; 8192 bytes
    out_len:    resd 1               ; Current bytes buffered (0..8192)
```

### How `buf_char` Works & Prevents Overruns
`buf_char` is the single gateway through which all other `buf_*` procedures emit bytes. Before writing a byte, it performs a strict bounds check:

```nasm
buf_char:
    push ecx
    mov ecx, [out_len]
    cmp ecx, OUT_BUF_SIZE
    jae .overflow_drop          ; If out_len >= 8192, discard byte silently

    mov [out_buf + ecx], al     ; Safe write within bounds
    inc ecx
    mov [out_len], ecx

.overflow_drop:
    pop ecx
    ret
```

- If an oversized frame is drawn, bytes exceeding 8,192 are silently dropped.
- The program **never crashes**, and out-of-bounds memory is never corrupted.
- When `buf_flush` executes, it transmits `out_buf[0..out_len)` and unconditionally resets `out_len` to `0`, ensuring no stale data is ever replayed.

---

## 3. Unsigned Decimal Number Formatting (`buf_u32`)

Formatting an integer as decimal text requires extracting individual digits from right to left using division by 10 (`DECIMAL_BASE`).

### Why Zeroing EDX is Mandatory
In 32-bit x86 assembly, the instruction `DIV reg32` divides the 64-bit integer formed by the register pair `EDX:EAX` by `reg32`.  
- The quotient is stored in `EAX`.
- The remainder (the digit `0..9`) is stored in `EDX`.

If `EDX` contains leftover data from earlier calculations, the CPU treats `EDX:EAX` as a massive 64-bit number. If the resulting quotient cannot fit in 32-bit `EAX`, the CPU triggers a hardware **Divide Error Exception (#DE)**, immediately crashing the program (`Floating point exception / Core dumped`).  
Therefore, `xor edx, edx` must precede every `div` instruction. (Note: Never use `cdq` here, because `cdq` sign-extends `EAX` into `EDX`, which corrupts unsigned numbers $\ge 2^{31}$).

### Worked Example: Converting `4294967295` (0xFFFFFFFF) Step by Step

```
Initial value: EAX = 4294967295

Iteration 1:  4294967295 / 10 = 429496729 rem 5  --> push '5'
Iteration 2:   429496729 / 10 =  42949672 rem 9  --> push '9'
Iteration 3:    42949672 / 10 =   4294967 rem 2  --> push '2'
Iteration 4:     4294967 / 10 =    429496 rem 7  --> push '7'
Iteration 5:      429496 / 10 =     42949 rem 6  --> push '6'
Iteration 6:       42949 / 10 =      4294 rem 9  --> push '9'
Iteration 7:        4294 / 10 =       429 rem 4  --> push '4'
Iteration 8:         429 / 10 =        42 rem 9  --> push '9'
Iteration 9:          42 / 10 =         4 rem 2  --> push '2'
Iteration 10:          4 / 10 =         0 rem 4  --> push '4' (EAX becomes 0, loop terminates)
```

The stack now holds the digits in reverse: `['5', '9', '2', '7', '6', '9', '4', '9', '2', '4']`.  
The emission loop pops each value off the stack in LIFO (Last-In, First-Out) order:
`'4'`, `'2'`, `'9'`, `'4'`, `'9'`, `'6'`, `'7'`, `'2'`, `'9'`, `'5'`.  
Result: `"4294967295"` is emitted in correct left-to-right order.

---

## 4. Time Formatting: `buf_mmss` and `buf_u32_2`

`buf_mmss` formats raw elapsed/remaining seconds into human-readable `MM:SS`:

1. **Division by 60:**  
   `EAX` (total seconds) is divided by 60 (`SECONDS_PER_MINUTE`).  
   - `EAX` = minutes quotient.
   - `EDX` = remaining seconds (`0..59`).
2. **Clamping:**  
   Minutes are compared against 99 (`MAX_MM_CLAMP`). If greater, minutes are clamped to 99 and seconds to 59, preventing buffer overflow or display misalignment (maximum display `99:59`).
3. **Two-Digit Padding (`buf_u32_2`):**  
   Both the minutes and seconds are passed to `buf_u32_2`. It divides by 10:
   - Tens digit = `EAX / 10` + `'0'`
   - Units digit = `EAX % 10` + `'0'`
   For example, `4` becomes `"04"`, and `7` becomes `"07"`, yielding `"04:07"`.

---

## 5. Assembling ANSI Cursor Moves: `buf_goto`

To position text anywhere on the 80×24 terminal grid, `buf_goto` emits standard ANSI escape sequences: `ESC [ <row> ; <col> H`.

For row 4, column 12:
1. Emits `ESC` (`27`) and `'['` (`91`).
2. Calls `buf_u32` on row (`4`).
3. Emits `';'` (`59`).
4. Calls `buf_u32` on column (`12`).
5. Emits `'H'` (`72`).

The resulting byte stream `\x1b[4;12H` instructs the terminal emulator to position the cursor at row 4, column 12 before drawing subsequent characters.

---

## 6. Register Preservation & The `save_regs` / `restore_regs` Macros

### PRD §6.2 Rule 1: Clean Calling Convention
Any procedure must preserve all registers it modifies, except documented output registers. In x86 assembly, unexpected register corruption across procedure calls is the #1 source of subtle bugs.

### Why Exclude `EAX`?
We defined `save_regs` and `restore_regs` in `src/macros.inc`:
```nasm
%macro save_regs 0
    push ebx
    push ecx
    push edx
    push esi
    push edi
%endmacro

%macro restore_regs 0
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
%endmacro
```

- **Why NOT use `PUSHA` / `POPA`?**  
  `POPA` pops 8 dwords, unconditionally restoring `EAX` along with everything else. If a function calculates a return value in `EAX` (like `str_len` returning string length), `POPA` would overwrite `EAX` with whatever value it had before the call, destroying the return value!
- `save_regs` and `restore_regs` protect all general scratch registers while leaving `EAX` free to return computed results.

---

## 7. Section Layout and File Inclusion Strategy

The project follows the standard ELF section layout mandated in PRD §6.1:

```
[ .data section ]  --> Initialized static strings (ANSI sequences, labels, assets)
[ .bss section  ]  --> Uninitialized read/write memory (out_buf, line_buf, states)
[ .text section ]  --> Executable machine code instructions (_start, procedures)
[ .note.GNU-stack] --> Security note marking stack as non-executable
```

### Why `main.asm` `%include`s Everything
Rather than linking a dozen separate object files with complex cross-module `extern` and `global` symbol exports, `src/main.asm` `%include`s the other modules directly:
- `constants.inc` defines symbolic values for compilation.
- `macros.inc` defines preprocessing macros.
- `data.asm` declares `.data` and `.bss`.
- `main.asm` opens `section .text` and `%include`s `io.asm`.

NASM compiles this into **one unified object file** (`build/pawmodoro.o`), which the linker binds into a lightweight, self-contained binary under 10 KB with zero external dependencies.

---

## 8. Verifying with `strace`: What It Proves

The Linux `strace` utility intercepts and logs all system calls invoked by a process:

```bash
strace -e trace=write ./build/pawmodoro
```

- **Proves Single-Write Guarantee:**  
  Running this command shows exactly **ONE** `write(1, ...)` call during the entire program run, passing the complete frame in one contiguous block of bytes.
- **Proves Zero Libc:**  
  Tracing reveals only kernel system calls (`write`, `exit_group`), proving the application runs purely on raw Linux x86 kernel interrupts.

---

## 9. Looking Ahead: What Task 2 (Terminal Control) Builds On

Task 1 established the foundation for outputting data without flicker. In Task 2 (`task-2-terminal`), the team will build the input side:
- Using `SYS_IOCTL` (`TCGETS` and `TCSETS`) to configure the Linux terminal into **Raw Mode** (disabling canonical line buffering and echo).
- Reading non-blocking single keystrokes (`key_poll` and `key_wait`).
- Handling clean terminal restoration (`term_restore`) on quit and Ctrl+C.
