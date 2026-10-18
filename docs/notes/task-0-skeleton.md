# Task 0: Project Skeleton & Toolchain Verification

**Task ID:** `task-0-skeleton`  
**Course:** CAO10 — Group 8  
**Project:** Pawmodoro  

This document explains the repository structure, toolchain configuration, hello-world assembly implementation, debugging procedures, and diagnostic steps created in Task 0. It is written in plain language so team members can confidently explain every component during project reviews and live demonstrations.

---

## 1. Repository Structure and Layout

The repository follows the modular layout defined in PRD §6.1. All components are placed directly at the repo root (no nested directory):

- **`Makefile`**: Automation script defining how the assembly source is compiled, linked, executed, debugged, and cleaned.
- **`README.md`**: Project overview, environment setup commands for Ubuntu/WSL2, quickstart guide, layout summary, and troubleshooting notes.
- **`.gitignore`**: Excludes build outputs (`build/`), runtime binary database files (`*.dat`), and user journal logs (`journal.txt`) from Git version control.
- **`docs/`**: Project documentation:
  - `docs/PRD.md`: Complete Product Requirements Document defining technical specifications, system call references, and module contracts.
  - `docs/roadmap.md`: Progressive roadmap detailing tasks and milestones.
  - `docs/notes/`: Task-by-task engineering walkthroughs and demo notes.
- **`src/`**: All assembly source code and include files:
  - `src/main.asm`: Application entry point (`_start`), containing the Task 0 hello-world. In later tasks, it will host the top-level event loop and state machine, and `%include` all other modules.
  - `src/constants.inc`: *(Placeholder)* Centralized definitions for system call numbers, key codes, buffer sizes, durations, and timezone offset (`TZ_OFFSET = 28800`).
  - `src/macros.inc`: *(Placeholder)* Reusable assembly macros for system calls and register push/pop operations.
  - `src/data.asm`: *(Placeholder)* Static data declarations (`.data`), ASCII art assets, ANSI terminal escape sequences, and uninitialized memory buffers (`.bss`).
  - `src/io.asm`: *(Placeholder)* Core terminal I/O routines, buffered output flusher (`buf_flush`), string formatting, and number printers.
  - `src/term.asm`: *(Placeholder)* Raw/cooked mode terminal management (`ioctl` termios), non-blocking keyboard input polling, and line reader.
  - `src/time.asm`: *(Placeholder)* System clock querying (`sys_time`), millisecond sleeps (`sys_nanosleep`), and calendar date calculations.
  - `src/file.asm`: *(Placeholder)* Low-level file I/O operations (open, read, write, close) for data persistence.
  - `src/stats.asm`: *(Placeholder)* Pomodoro statistics tracker and `stats.dat` persistence.
  - `src/ui.asm`: *(Placeholder)* Terminal UI rendering engine: ASCII cat poses, status bars, frames, and menus.
  - `src/timer.asm`: *(Placeholder)* Pomodoro state machine (focus, short break, long break cycles, demo mode).
  - `src/habits.asm`: *(Placeholder)* Habit tracking engine with 7-day visual history and streak calculations.
  - `src/journal.asm`: *(Placeholder)* Timestamped journal note capture and display routines.
- **`tests/`**: Test harness:
  - `tests/TEST_PLAN.md`: Comprehensive test strategy and checklist.
  - `tests/smoke.sh`: Automated bash smoke test script.
- **`build/`**: Ephemeral output directory created during compilation; holds object files (`.o`) and the final executable (`pawmodoro`).

> **Note on Deliberate Task 0 Architecture Decision:**  
> In this initial task, `src/main.asm` does **not** `%include` the placeholder `.asm` and `.inc` files. The placeholder files contain only single-line comments. Including them now would provide no functional utility and could complicate clean standalone hello-world testing. They will be included sequentially in future tasks as real procedures and data are added.

---

## 2. Toolchain and Build System (`Makefile`)

The project uses GNU Make to drive NASM and the GNU Linker (`ld`).

### 2.1 Makefile Targets

1. **`all` (default)**: Compiles `src/main.asm` into `build/pawmodoro.o` and links it into `build/pawmodoro`. If the `build/` directory does not exist, it is created automatically.
2. **`run`**: Depends on `all` and immediately runs the binary: `./build/pawmodoro`.
3. **`debug`**: Depends on `all` and launches GDB with the compiled binary: `gdb ./build/pawmodoro`.
4. **`clean`**: Deletes the `build/` directory (`rm -rf build`), resetting the workspace to a pristine state.

### 2.2 Compiler & Linker Flags Explained

- **`nasm -f elf32 -g -F dwarf -Wall src/main.asm -o build/pawmodoro.o`**:
  - `-f elf32`: Emits a 32-bit Executable and Linkable Format (ELF) object file matching the Linux i386 ABI.
  - `-g`: Instructs the assembler to generate debug symbols.
  - `-F dwarf`: Specifies the DWARF debug format (standard on modern Linux systems), enabling source-level debugging, line stepping, and symbol inspection in GDB.
  - `-Wall`: Enables all assembler warnings to ensure strict code cleanliness.
  - `-o build/pawmodoro.o`: Designates the target object file output path.
- **`ld -m elf_i386 build/pawmodoro.o -o build/pawmodoro`**:
  - `-m elf_i386`: Directs the 64-bit GNU linker to target the 32-bit x86 architecture (`i386`), properly resolving 32-bit addresses and symbols without requiring libc.
  - `-o build/pawmodoro`: Sets the final output executable binary name.

### 2.3 The `.note.GNU-stack` Section

Modern versions of the GNU Linker (`binutils 2.39+`) warn if an object file lacks an explicit stack note section:  
`ld: warning: build/pawmodoro.o: missing .note.GNU-stack section implies executable stack`

By default, omitting this section causes the linker to assume the stack must be marked executable (`RWX`), which is a security risk. To maintain a warning-free build without suppressing warnings using linker flags, `main.asm` concludes with:

```nasm
section .note.GNU-stack noalloc noexec nowrite progbits
```

This marks the stack segment as strictly non-executable (`noexec`), satisfying `ld`'s security checks and eliminating warnings cleanly.

---

## 3. How the Hello-World Assembly Code Works

The hello-world program in `src/main.asm` demonstrates direct Linux kernel communication without any C runtime library (`libc`).

```
+-------------------------------------------------------------+
|                      User Space (Ring 3)                    |
|                                                             |
|   1. Populate registers:                                    |
|      EAX = Syscall Number (4 = sys_write, 1 = sys_exit)     |
|      EBX = Argument 1     (fd = 1, exit status = 0)         |
|      ECX = Argument 2     (buffer address)                  |
|      EDX = Argument 3     (byte count)                      |
|                                                             |
|   2. Trigger Software Interrupt: int 0x80                   |
+------------------------------+------------------------------+
                               |
                               v Trap Gate
+-------------------------------------------------------------+
|                     Kernel Space (Ring 0)                   |
|                                                             |
|   - Reads EAX from interrupt frame                          |
|   - Dispatches to sys_write() / sys_exit()                  |
|   - Returns result in EAX (or terminates process)           |
+-------------------------------------------------------------+
```

### 3.1 Understanding `int 0x80`
In 32-bit x86 Linux, user programs invoke kernel system calls via software interrupt `0x80`. Executing `int 0x80` causes the CPU to transition privilege levels from user mode (Ring 3) to supervisor/kernel mode (Ring 0). The kernel examines register `EAX` to determine which system call to execute, unpacks parameters from `EBX`, `ECX`, and `EDX`, carries out the operation, and returns control to user mode with the return code placed in `EAX`.

### 3.2 System Call Breakdown

#### `sys_write` (Syscall 4)
- **`EAX = 4` (`SYS_WRITE`)**: Selects the write system call.
- **`EBX = 1` (`FD_STDOUT`)**: Standard output file descriptor (where the text goes).
- **`ECX = boot_msg`**: Memory address pointing to `"Pawmodoro boots!\n"` in the `.data` segment.
- **`EDX = boot_msg_len`**: Exact number of bytes to transfer (17 bytes).

#### `sys_exit` (Syscall 1)
- **`EAX = 1` (`SYS_EXIT`)**: Selects the process termination system call.
- **`EBX = 0` (`EXIT_SUCCESS`)**: Exit status returned to the parent shell.

### 3.3 Dynamic Length Calculation (No Magic Numbers)
Rather than hardcoding `17`, the length is calculated automatically by the assembler using label arithmetic:
```nasm
boot_msg:       db "Pawmodoro boots!", CHAR_LF
boot_msg_len:   equ $ - boot_msg
```
In NASM, the token `$` represents the current assembly position (the memory address immediately following the string and newline). Subtracting the starting address `boot_msg` yields the exact byte count at compile time.

### 3.4 Why Exit Code `0` Matters
In Unix/Linux environments, a process exit status of `0` signals clean, successful execution. Any non-zero value indicates an error condition. Parent processes, shell scripts (e.g. `echo $?`), and automated CI pipelines rely on exit code `0` to verify correct completion.

---

## 4. Debugging Primer (`make debug`)

Because the binary is built with DWARF debug symbols (`-g -F dwarf`), developers can inspect execution using GDB.

To start debugging:
```bash
make debug
```

Key GDB commands for 32-bit assembly:

1. **`set disassembly-flavor intel`**: Ensures assembly instructions are displayed in Intel syntax rather than AT&T syntax.
2. **`break _start`**: Places a breakpoint at the entry point.
3. **`run`**: Launches the program and pauses at `_start`.
4. **`stepi`** (or `si`): Steps forward exactly one machine instruction.
5. **`info registers`** (or `i r`): Displays current values across all CPU registers (`eax`, `ebx`, `ecx`, `edx`, `esp`, `ebp`, `esi`, `edi`, `eip`, `eflags`).
6. **`x/17cb $ecx`**: Examines memory at address in `ECX` formatted as 17 character bytes.
7. **`continue`** (or `c`): Resumes execution until termination or the next breakpoint.
8. **`quit`** (or `q`): Exits GDB.

---

## 5. Troubleshooting: "Exec Format Error"

When attempting to run a 32-bit Linux binary on a 64-bit host, the kernel might return:
`cannot execute binary file: Exec format error`

### 5.1 What It Means
The kernel failed to parse the executable file header or refuses to launch it because the processor or kernel lacks support for the 32-bit ELF binary format (`ELFCLASS32`).

### 5.2 PRD §3 Platform Guidance
PRD §3 states:
> 64-bit Linux kernels run 32-bit ELF binaries; if a hello-world fails with "Exec format error", enable 32-bit support / use a VM.

### 5.3 Diagnostic Checklist

Follow this diagnostic sequence to identify and resolve the cause:

1. **Check Binary Format:**
   ```bash
   file build/pawmodoro
   ```
   - **Expected output:** `ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV)...`
   - If it reports 64-bit (`ELF 64-bit`) or an unrecognized file type, verify your build flags in `Makefile` (`-f elf32` for NASM and `-m elf_i386` for `ld`).
2. **Check Host Architecture:**
   ```bash
   uname -m
   ```
   - **Expected output:** `x86_64` or `i686`.
   - If it outputs `aarch64` or `arm64` (e.g., Apple Silicon or an ARM cloud VM), the processor cannot run x86 instructions natively without binary translation.
3. **Check WSL Configuration (Windows Hosts):**
   - *(Suggestion)* Run `wsl -l -v` from Windows PowerShell to ensure your Linux distribution is configured with **WSL2** (`Version 2`). WSL1 uses system call translation and may lack full support for 32-bit execution depending on host Windows build versions.
4. **No 32-bit Libc Required:**
   - Because Pawmodoro issues direct `int 0x80` kernel syscalls without relying on `libc`, packages such as `libc6:i386` or multiarch libraries are **not** needed.
5. **Fallback Environment:**
   - If the host system's kernel has disabled 32-bit binary execution (`CONFIG_IA32_EMULATION=n`), use a standard Ubuntu 64-bit virtual machine (e.g. VirtualBox or VMware) with 32-bit ELF support enabled.
