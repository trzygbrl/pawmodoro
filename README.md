# Pawmodoro

Pawmodoro is a lightweight terminal productivity application written entirely in **x86-32 Assembly (NASM)** for Linux (`int 0x80`, no libc), created for **CAO10 (Group 8)**. It integrates a Pomodoro focus timer, a habit tracker with streak tracking, and a timestamped journal into a unified, distraction-free terminal interface.

---

## Setup (Ubuntu / WSL2)

To set up the required 32-bit assembly toolchain and debugging utilities on Ubuntu or WSL2, install the following packages:

```bash
sudo apt install nasm binutils make gdb tmux
```

> **Platform Note:** A 64-bit Linux environment with 32-bit ELF execution support is required. On Windows, running under WSL2 is recommended (and likely required over WSL1) to guarantee proper 32-bit ELF binary support.

---

## Build and Run

All build steps are orchestrated via `make`:

- **Build binary:**
  ```bash
  make
  ```
- **Build and run:**
  ```bash
  make run
  ```
- **Direct execution:**
  ```bash
  ./build/pawmodoro
  ```
- **Debug with GDB:**
  ```bash
  make debug
  ```
- **Clean build artifacts:**
  ```bash
  make clean
  ```

### Expected Output (Task 0 Hello-World)
Running the binary prints:
```text
Pawmodoro boots!
```
with an exit status code of `0`.

---

## Project Layout

Following PRD §6.1, the repository is structured as:

```text
pawmodoro/
  Makefile
  README.md
  .gitignore
  docs/
    PRD.md
    roadmap.md
    notes/          # Implementation explanations per task
  src/
    main.asm        # _start, main loop, state machine; %includes modules
    constants.inc   # syscall numbers, key codes, sizes, durations, TZ_OFFSET
    macros.inc      # syscall + save/restore macros
    data.asm        # .data strings, ASCII art, ANSI strings; .bss buffers
    io.asm          # output buffer + number/string helpers
    term.asm        # termios, keyboard, line input
    time.asm        # sleep, clock, date formatting
    file.asm        # load / save / append
    stats.asm       # stats.dat
    ui.asm          # frames, cat art, progress bar, menu rendering
    timer.asm       # pomodoro
    habits.asm      # habit tracker
    journal.asm     # journal
  tests/
    TEST_PLAN.md
    smoke.sh
  build/            # Generated object and executable binaries (gitignored)
```

---

## Troubleshooting: "Exec format error"

If running `./build/pawmodoro` results in `cannot execute binary file: Exec format error`, it means the Linux kernel refused to execute the ELF binary. Follow this diagnostic checklist:

1. **Verify binary architecture:** Run `file build/pawmodoro`. It must report `ELF 32-bit LSB executable, Intel 80386`. If it reports 64-bit or an unrecognized format, check that `-f elf32` and `-m elf_i386` flags were used.
2. **Verify host CPU architecture:** Run `uname -m`. The host machine must be an x86_64 or i686 processor. ARM architecture (such as Apple Silicon or ARM Linux VMs without x86 translation) cannot natively run x86-32 binaries.
3. **Check WSL version (Windows users):** *(Suggestion)* Run `wsl -l -v` from PowerShell to verify your distro is running under WSL2. WSL1 lacks full system call compatibility for some 32-bit binaries.
4. **No 32-bit libc required:** You do **not** need to install `libc6:i386` or multiarch C libraries because Pawmodoro uses raw Linux `int 0x80` kernel syscalls directly without any libc runtime dependency.
5. **Fallback:** Per PRD §3, if your 64-bit Linux kernel does not have 32-bit ELF execution enabled and cannot run the binary, use an Ubuntu virtual machine.

---

## Documentation

- **Product Requirements Document:** `docs/PRD.md`
- **Task Implementation Notes:** `docs/notes/` (see `docs/notes/task-0-skeleton.md`)
