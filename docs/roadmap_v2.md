# Pawmodoro v2 Roadmap — GUI-Like Terminal UI, Themes, Animation, Sound, Journal Delete

**Scope:** post-prototype polish. Everything here is built **after** T0–T11 (the working prototype). The target is not merely colored terminal text: Pawmodoro should feel like a complete, deliberately designed GUI app rendered inside a terminal. Keep the existing product features and their behavior; improve their presentation, navigation, feedback, and consistency. It uses the same method as `docs/roadmap.md`: attach the PRD, paste the Standard Wrapper, paste one Prompt-Builder Paragraph, get one prompt back, give it to the coding agent, run the **Verify** list, commit.

---

## Part 1 — Suggestions and decisions (read first)

**1. Why text is cut off.** The frame is fixed at 56 columns, but an 80-column terminal has 24 more. Journal lines are clipped at 52 characters (entries can be 200), and habit names are clipped at 12 characters (names can be 31). Fix: an *adaptive layout* that uses the real terminal size (78 columns wide at 80×24, up to about 100 on bigger windows, centered), plus word-wrapping and scrolling in the journal. Many UTF-8 glyphs are multi-byte, so clipping must count display columns, not bytes.

**2. Customizable colors.** Stop hard-coding `ansi_fg_bright_cyan` etc. Introduce named **color slots** (border, title, accent, text, dim, ok, warn, error, cat, bar-full, bar-empty, highlight). A **theme** is just 12 palette numbers (256-color mode). Ship about 7 built-in themes (Strawberry Milk, Matcha Latte, Blueberry, Lavender Night, Sunset Peach, Mono Cozy, High Contrast) and let the user edit each slot in a Settings screen. Save to `settings.dat`.

**3. Animation.** You already have a 100 ms tick, so animation is cheap. The only real change: the timer currently redraws once per second, so animated regions need small partial redraws (still **one `sys_write` per frame**). Ideas: blinking and tail-wagging cat, rising "zZ" on breaks, shimmering progress bar, color-wave title, twinkling stars on the menu, confetti when a focus session completes, heart pop on habit check-in. Add a **Reduce motion** toggle.

**4. Sound — what is actually possible.** Plain assembly with no libc has no audio API, and the terminal bell (`0x07`) is a single fixed beep. The practical approach: your program **synthesizes the waveform itself** (square/triangle waves with integer math, no FPU), then pipes raw PCM into a player (`paplay` or `aplay`) launched with `fork` + `execve`. This is real assembly audio synthesis, with one honest caveat: the player is an external program. Document that in Chapter 3. Always keep the bell as the fallback.

- Audio in **WSL2** works through WSLg, which needs Windows 11; on Windows 10 there is usually no sound. I can't see your setup, so test early: `which paplay aplay` and play any sound file.
- Sounds to synthesize: a "mrrp" start chirp, check-in sparkle arpeggio, focus-complete fanfare, soft break chime, error boop, delete blip, and a short meow (pitch glide with vibrato).
- Never block the timer: spawn the player and move on; auto-reap children by ignoring `SIGCHLD`; ignore `SIGPIPE` so a missing player cannot kill the app.

**5. Notifications.** Layered, each optional: bell → screen flash (`ESC[?5h`/`l`) → **window title shows the live countdown** (`ESC]0;…BEL`, so you can see it in the taskbar) → taskbar progress bar (`ESC]9;4;…`, Windows Terminal; ignored elsewhere) → optional desktop toast via `notify-send` or a PowerShell balloon on WSL (experimental, probe and fall back silently). Terminal support varies, so each layer needs a Settings toggle and a test on *your* terminal.

**6. Journal deletion.** `journal.txt` is append-only, so deletion means rewriting it. Safest design: copy everything except the chosen line into `journal.tmp` in small chunks, then `rename()` it over `journal.txt`. On any error the original is untouched. Needs a selectable list (arrow keys) and a confirm prompt.

**7. Things to decide before V0 (my defaults in bold).** Charset: **UTF-8 with an ASCII fallback toggle**. Palette: **256-color, no truecolor**. Emoji: **avoid** (double-width breaks alignment); use `★ ♥ ● ○ ▰ ▱ ╭╮╰╯`. Minimum terminal: **keep 80×24**.

**8. Heads-up (unrelated to v2).** `docs/CHAPTER3_DRAFT.md` disagrees with the code in several places: it says `sys_sigaction` (code uses `sys_signal`, syscall 48), demo timings of 5 s/2 s/3 s (code: 10/5/8), 72-character journal notes (code: 200), `PUSHA/POPA` and `NEG`/`LOOP` in use (they are not), and the README claims duplicate-habit-name detection (no such check exists). V11 fixes this.

---

## Part 2 — How to use

For **each task**: new AI chat → attach `docs/PRD.md` and (after V0) `docs/PRD_V2.md` → paste the **Standard Wrapper** → paste that task's paragraph → copy the returned prompt into the coding agent (opened in the repo) → run **Verify** → `git commit -m "Vn done"`. If it fails, use the **Fix Paragraph**. One task per session; tasks run in order; never let the agent refactor unrelated code.

### Standard Wrapper v2 (paste before every task paragraph)

> You are an expert prompt engineer for AI coding agents. I attached the PRD (and PRD v2 addendum, if it exists) for my university Assembly project, Pawmodoro (NASM, 32-bit Linux, terminal app, no libc). The prototype already works. Write ONE self-contained prompt for a coding agent working inside my repo. It must: (1) start with a 2–3 sentence context and give the agent the role of a senior x86 NASM developer; (2) tell the agent to read `docs/PRD.md`, `docs/PRD_V2.md` and the existing source files it will touch before changing anything; (3) list the exact files it may create or edit and forbid touching any others; (4) list every new or changed procedure with IN / OUT / CLOBBERS, keeping every existing procedure contract unless the task says otherwise; (5) restate PRD §6.2 conventions (register preservation, header per procedure, inline comments, constants instead of magic numbers, no FPU/SSE); (6) require that existing behavior keeps working: `make` stays warning-free, `tests/smoke.sh` passes (updating its expectations only where this task intentionally changes the UI), one `sys_write` per frame is kept unless the task says otherwise, and the terminal is restored on every exit path; (7) include acceptance criteria and exact shell commands to build and verify; (8) end by requiring a short report (built, how to test, known issues) and a plain-language file `docs/notes/<task-id>.md`. Do not write assembly yourself — output only the prompt in one code block. The task is:

### Task overview

| Task | Name | Depends on |
| --- | --- | --- |
| V0 | PRD v2 addendum and decisions (docs only) | — |
| V1 | Extended key input (arrows, PgUp/PgDn, Delete) | V0 |
| V2 | Adaptive layout, full-width screens, no cut text | V1 |
| V3 | Journal v2: wrap, scroll, **delete** | V1, V2 |
| V4 | Theme engine and `settings.dat` | V2 |
| V5 | Settings screen and color customizer | V1, V4 |
| V6 | Maximalist cute visual pass | V2, V4 |
| V7 | Animation engine | V6 |
| V8 | Sound engine (synth + player) | V5 |
| V9 | Notifications and terminal integration | V8 |
| V10 | Integration, regression tests, bug list | V3–V9 |
| V11 | Docs sync and Chapter 3 addendum | V10 |

---

## V0 — PRD v2 addendum and decisions

**Goal:** one source of truth so the agent stops following old limits (56 columns, ASCII-only, 16 colors). **Files:** `docs/PRD_V2.md`, `docs/roadmap_v2.md` (docs only; no `src/` changes).

> **Prompt-Builder Paragraph — V0** Build me a prompt for a coding agent to write `docs/PRD_V2.md`, a short addendum to the PRD that explicitly supersedes the listed PRD sections and touches no source code. It must record: (a) adaptive layout replacing the fixed 56-column frame (FR-U8 and the 56-column wireframes), minimum terminal still 80×24; (b) UTF-8 glyphs allowed with an ASCII fallback setting; (c) a color-slot theme model using 256-color escapes and a `settings.dat` file; (d) new keys and key codes (arrows, PgUp/PgDn, Home, End, Delete) and the new `STATE_SETTINGS`; (e) journal deletion via rewrite-to-temp-then-`rename`; (f) animations driven by the 100 ms tick with partial redraws and a reduce-motion setting; (g) sound via synthesized 8-bit PCM piped to `paplay`/`aplay` through `fork`/`execve`, with the terminal bell as fallback and explicit statement that the player is an external dependency; (h) optional notification layers; (i) new syscall table rows (fork 2, pipe 42, dup2 63, execve 11, access 33, rename 38, unlink 10, lseek 19) and an updated `.bss` budget; (j) new functional requirements numbered FR-V1… with acceptance criteria; (k) a list of `tests/smoke.sh` and `TEST_PLAN.md` checks that will need updating (for example the 56-column overflow check).

**Verify:** ☐ every superseded PRD section is named ☐ every new FR has a testable criterion ☐ no `src/` file changed.

---

## V1 — Extended key input

**Goal:** selection UIs need arrow keys; today `key_poll` swallows them. **Files:** `constants.inc`, `term.asm`, `main.asm` (temporary demo, removed afterward).

> **Prompt-Builder Paragraph — V1** Build me a prompt for a coding agent to extend `key_poll` in `term.asm`. Add constants `KEY_UP`, `KEY_DOWN`, `KEY_RIGHT`, `KEY_LEFT`, `KEY_PGUP`, `KEY_PGDN`, `KEY_HOME`, `KEY_END`, `KEY_DELETE` with values above 255 (for example 0x101…). Parse CSI sequences (`ESC [ A/B/C/D`, `ESC [ 5~`, `6~`, `3~`, `H`, `F`, and the `ESC O` variants), map known ones to these codes, and still drain and ignore unknown sequences (return -1). If ESC arrives with no follow-up byte, wait one short sleep (about 5 ms) and re-check before declaring a lone ESC, so slow connections do not misfire. Letters stay uppercased, every other contract stays the same, and existing screens must keep ignoring the new codes. This is a documented contract change: the agent must list it in its report. Temporary demo in `main.asm` prints each key code; remove it after verifying. Acceptance: arrows, PgUp/PgDn, Delete report distinct codes; mashing arrows on every existing screen changes nothing and produces no stray characters; `smoke.sh` passes.

**Verify:** ☐ codes print correctly ☐ arrows no longer leak letters like `A`/`B` ☐ lone Esc still works ☐ smoke passes.

---

## V2 — Adaptive layout, full-width screens

**Goal:** fix the "text is cut" problem on every screen. **Files:** `constants.inc`, `data.asm`, `io.asm`, `ui.asm`, `timer.asm`, `habits.asm`, `journal.asm`, `main.asm`, `tests/smoke.sh`.

> **Prompt-Builder Paragraph — V2** Build me a prompt for a coding agent to replace the fixed 56-column geometry with a runtime layout. Add variables `ui_w`, `ui_h`, `ui_col0` and a procedure `ui_layout_update` (called at the start of every redraw, after `term_size_ok`) that computes `ui_w = min(term_cols - 2, 100)`, centers the frame horizontally, and exposes spare rows. Add `ui_goto` (row, column relative to the frame) and switch `ui_frame_row`, `ui_frame_hline`, `ui_text_at` and every screen's column constants to it, mechanically and without changing behavior. Add a UTF-8-aware `buf_str_clip` (ESI string, ECX max display columns; count a byte as a column only if it is not a continuation byte `10xxxxxx`; append a marker when clipped). Use it so habit names show their full 31 characters, the habits table reflows to the new width, and journal lines use `ui_w - 6` columns. The 80×24 minimum and size gate stay. Update `smoke.sh`'s overflow check from 56 to the new width. Acceptance: at 80×24 the frame is 78 wide; at 120×40 it is 100 wide and centered; resizing while idle re-lays out; no row exceeds the terminal width; one write per frame still holds (`strace -e write`).

**Verify:** ☐ 31-char habit name fully visible ☐ 200-char journal text no longer cut at 52 ☐ resize works ☐ no right-border misalignment on any screen ☐ smoke passes.

---

## V3 — Journal v2: wrap, scroll, delete

**Goal:** read full entries and delete any entry (your requested feature). **Files:** `journal.asm`, `file.asm`, `constants.inc`, `data.asm`, `ui.asm`, `.gitignore`.

> **Prompt-Builder Paragraph — V3** Build me a prompt for a coding agent to upgrade the journal. (1) Display: each entry is word-wrapped to `ui_w - 6` columns over up to 4 rows (timestamp on the first row, continuation rows indented), so a 200-character entry is fully readable; sanitizing and UTF-8-safe wrapping must be kept. (2) Navigation: a highlighted selection row (reverse video), Up/Down to move, PgUp/PgDn to page back through older entries using chunked backward reads (no full-file load; buffer at most 16 KB; partial first line discarded as today), `Enter` opens a full-entry view. (3) Delete: `D` or the Delete key on the selected entry asks "Delete this entry? (y/n)"; on `Y` call a new generic `file_delete_range` (IN `ESI` path, `EAX` start offset, `EDX` end offset; OUT `EAX` 0/-1) in `file.asm` that copies bytes outside the range into `journal.tmp` in chunks (a dedicated 2 KB copy buffer, using `open`/`read`/`write`/`close`/`lseek`), then `rename` (syscall 38) over `journal.txt`; on any failure `unlink` (syscall 10) the temp file, leave the original untouched, and show "Could not delete". Add `SYS_RENAME`/`SYS_UNLINK` constants and `journal.tmp` to `.gitignore`. Show "Entry deleted" on success and keep the selection sensible (clamp when the list shrinks; "No entries yet." when empty). Acceptance: delete first, middle, last and only entries; delete in a file larger than 16 KB; cancel with `N`; make `journal.tmp` unwritable (create a directory with that name) and confirm the original file is unchanged; `cat journal.txt` stays readable; Ctrl+C at every prompt still restores the terminal.

**Verify:** ☐ full 200-char entry readable ☐ delete works at each position ☐ failed delete leaves file intact ☐ scrolling reaches old entries ☐ no `journal.tmp` left behind.

---

## V4 — Theme engine and `settings.dat`

**Goal:** replace hard-coded colors with slots, add themes and persistence (no UI yet). **Files:** `constants.inc`, `data.asm`, new `src/theme.asm` and `src/settings.asm` (`%include` from `main.asm`), `ui.asm`, `timer.asm`, `habits.asm`, `journal.asm`, `main.asm`.

> **Prompt-Builder Paragraph — V4** Build me a prompt for a coding agent to add a theme engine. Define slot constants (`SLOT_BORDER, TITLE, TEXT, DIM, ACCENT, OK, WARN, ERR, CAT, BAR_FULL, BAR_EMPTY, HIGHLIGHT`) and a table of 7 built-in themes (Strawberry Milk, Matcha Latte, Blueberry, Lavender Night, Sunset Peach, Mono Cozy, High Contrast), each 12 bytes of 256-color indices. Implement `ui_color` (IN `AL` slot; appends `ESC[38;5;Nm`) and `ui_bgcolor`. Then replace every direct `ansi_fg_*` use in `ui.asm`, `timer.asm`, `habits.asm`, `journal.asm`, `main.asm` with slot calls — a mechanical substitution with no layout change; `ansi_bold` and `ansi_reset` stay. Implement `settings_load` / `settings_save` for a fixed-size `settings.dat` (magic dword, version byte, theme index, 12 custom color bytes, flag bytes for animation, sound, charset, notifications, volume), validating magic/version/ranges and falling back to defaults without crashing; a failed save sets a flag the UI can show. Acceptance: default theme looks close to today; changing the default theme constant recolors every screen; `grep ansi_fg_` shows none outside `theme.asm`/`data.asm`; truncating or corrupting `settings.dat` starts with defaults; `smoke.sh` passes.

**Verify:** ☐ every theme renders on all four screens ☐ no leftover hard-coded colors ☐ corrupted settings handled ☐ file size matches the documented layout.

---

## V5 — Settings screen and color customizer

**Goal:** the user can change themes and individual colors. **Files:** new `src/settings_ui.asm`, `constants.inc`, `data.asm`, `ui.asm`, `main.asm`.

> **Prompt-Builder Paragraph — V5** Build me a prompt for a coding agent to add `STATE_SETTINGS` and a menu item `[5] Settings`, laid out with the adaptive layout. Rows: Theme (Left/Right cycles with a live swatch strip and sample line), Customize colors (opens an editor: Up/Down picks a slot, Left/Right changes its 256-color index by 1, PgUp/PgDn by 16, with a 16×16 palette preview and a sample of the slot in use), Animations on/off, Sound on/off and volume 0–3, Charset UTF-8/ASCII, Terminal integration on/off, Reset to defaults (with a y/n confirm). Every change applies immediately, saves through `settings_save`, and shows "Saved" or "Could not save" on the status row. `Esc` or `B` returns; Ctrl+C exits cleanly. Optional if time allows: custom focus/short/long durations in minutes (PRD stretch goal) kept separate from demo-mode durations. Acceptance: settings survive restart; customizing one slot recolors only what uses that slot; every row is reachable with the keyboard only; mashing keys is safe.

**Verify:** ☐ theme change visible immediately ☐ custom color persists ☐ reset works ☐ corrupted `settings.dat` falls back to defaults.

---

## V6 — Complete GUI-like visual system and cute visual pass

**Goal:** turn the working terminal screens into a cohesive, polished app interface—not a collection of text output—while preserving every feature and its behavior. Establish reusable visual components, then apply them consistently to the menu, timer, habits, journal, and settings. **Files:** `ui.asm`, `data.asm`, `timer.asm`, `habits.asm`, `journal.asm`, `main.asm`, `constants.inc` (and `settings_ui.asm` if it already exists; do not create unrelated files).

> **Prompt-Builder Paragraph — V6** Build me a prompt for a coding agent to implement a cohesive GUI-like terminal UI for Pawmodoro. First inspect all current screens, theme slots, adaptive-layout helpers, keyboard contracts, and smoke tests. Preserve all existing features, controls, data formats, timer behavior, habit rules, journal behavior, and persistence. Use theme slots for every color and provide an ASCII equivalent for every UTF-8 glyph. Implement a shared app shell used by every screen: (1) a brand/header row with Pawmodoro identity and current section; (2) a clear title/subtitle; (3) a consistent content area; (4) aligned cards/panels with reusable borders, padding, dividers, and headings; (5) a fixed status/message row for feedback; and (6) a footer/help bar with context-appropriate key hints. Add reusable rendering helpers for panel/frame start and end, section headings, labels and values, selected/focused rows, badges, separators, empty states, confirmation dialogs, status messages, and progress indicators. Do not duplicate screen-specific border/color logic when a shared helper can be used.

> Make the main menu feel like a dashboard: a prominent welcome/time-of-day greeting, a compact set of cards for pomodoros today and total, habits done/total, and best/current streak where the existing data supports it; a clearly highlighted navigation list with the existing menu options; a small cat illustration and rotating cozy tip as secondary accents. Keep Demo Mode visible as a badge. The timer screen must prioritize a large 5-row countdown, phase badge, session dots for the four-focus cycle, a clearly segmented progress bar, pause state, and a compact control legend; the cat is a companion, not the focal point. The habits screen should present each habit as a readable row/card with its name, seven-day history, streak, total, and visible selected state; never truncate a 31-character name when the adaptive width can display it. The journal should use a readable list with timestamps, selected-row highlighting, scroll/page context, clear empty state, and visually distinct full-entry and delete-confirmation views. Settings should show the active theme and live color preview, aligned setting labels/values, selected rows, and a framed confirmation for reset. Add rounded borders (`╭─╮│╰╯`) where supported, a block progress bar (`▰▱` or `█░`), phase-colored headers, small `✦ ♥ ★` accents, cat poses (idle, working, happy, sleepy, surprised), a tip line chosen deterministically from the day number, and subtle badges for states such as `[DEMO]`, `PAUSED`, and `SAVED`. Do not use emoji or double-width glyphs.

> Enforce a consistent spacing scale, border weight, title treatment, alignment, and status-message location across every screen. Use reverse video or a clear marker as well as color for selection. Ensure text contrast in High Contrast theme and never encode success/error meaning using color alone. At 80×24, show all essential content and controls without overlap; at 120×40, expand cards and whitespace intentionally while keeping the main content visually balanced. No line may exceed terminal width; UTF-8 clipping must use display columns; shorter redraws must clear leftovers. Keep the one-`sys_write`-per-frame rule and preserve terminal restoration on every exit path. Add or update deterministic smoke tests for screen boundaries, selection markers, status row, ASCII mode, and all existing features. Acceptance: the five screens look like one coherent app; every control and selected item is obvious; all essential data is readable; no feature behavior changes; `make` is warning-free and `tests/smoke.sh` passes.

**Verify:** ☐ shared app shell is consistent on menu/timer/habits/journal/settings ☐ clear selected/focused state and keyboard hints on every interactive screen ☐ status messages do not move content ☐ dashboard cards show real existing values only ☐ 31-character habit names remain readable ☐ 200-character journal entries remain readable in full-entry view ☐ ASCII fallback has no stray multibyte glyphs ☐ High Contrast is readable ☐ 80×24 and 120×40 layouts are balanced and overflow-free ☐ no flicker/stale characters ☐ one write per frame ☐ smoke tests pass.

---

## V7 — Animation engine

**Goal:** a living interface that never costs CPU or flicker. **Files:** new `src/anim.asm`, `timer.asm`, `main.asm`, `habits.asm`, `ui.asm`, `data.asm`, `constants.inc`.

> **Prompt-Builder Paragraph — V7** Build me a prompt for a coding agent to add animation. Provide `anim_tick` (called once per 100 ms from the timer loop and the menu wait loop), a frame counter, a small LCG pseudo-random generator using `MUL` seeded from `time_now`, and partial-redraw procedures that draw only a small region (cat, title, progress bar, or particle area) into `out_buf` and flush once. Effects: cat blink every few seconds and tail wag (2–3 frames per pose); rising "zZ" on breaks; progress-bar shimmer; slow color-wave on the menu title using theme colors; twinkling star garnish on the menu; a confetti burst (about 20 particles, integer positions and gravity) after a natural focus completion; heart pop on habit check-in. A Reduce motion setting disables all of it and restores static frames. Limits: at most 5 writes per second while animating, no extra writes while idle with animation off, CPU still under 1%, no effect at all when the size gate is active. Acceptance: `strace -c` write counts match the limits; pausing the timer freezes timer animation but not the app; Ctrl+C mid-animation restores the terminal.

**Verify:** ☐ animations visible on menu and timer ☐ Reduce motion = fully static ☐ `top` \~0–1% ☐ no flicker ☐ confetti does not leave residue after completion.

---

## V8 — Sound engine

**Goal:** cute synthesized sounds plus a reliable fallback. **Files:** new `src/sfx.asm`, `constants.inc`, `data.asm`, `timer.asm`, `habits.asm`, `journal.asm`, `main.asm`.

> **Prompt-Builder Paragraph — V8** Build me a prompt for a coding agent to implement sound without libc. `sfx_init`: ignore `SIGPIPE` (13) and `SIGCHLD` (17) with `sys_signal` handler value 1, and probe with `access` (syscall 33, X\_OK) for `/usr/bin/paplay` then `/usr/bin/aplay`, storing the choice (or none). `synth_note` (IN `EAX` frequency Hz, `ECX` duration ms, `EDX` waveform square/triangle): integer phase accumulator, linear decay envelope, volume scaling from the setting, writing unsigned 8-bit samples at 11025 Hz into a new `sfx_buf` (32 KB, budget it in `.bss`); a rest note for silence. `sfx_play` (IN `EAX` sound id): builds the sound from a `.data` table of (frequency, ms) steps and, if sound is enabled and a player exists, spawns it: `pipe` (42), `fork` (2); in the child close the write end, `dup2` (63) the read end to fd 0, open `/dev/null` and `dup2` it over fds 1 and 2, `execve` (11) the player with raw U8 mono 11025 Hz arguments (`paplay --raw --format=u8 --rate=11025 --channels=1` or `aplay -q -t raw -f U8 -r 11025 -c 1`), and on failure `sys_exit(127)` directly without touching terminal code; the parent closes the read end, writes the buffer in one `write`, closes the write end, and returns immediately. If sound is disabled or no player exists, fall back to the bell byte for important events only. Sounds: start chirp, click, check-in sparkle (C–E–G–C), focus-complete fanfare, break chime, error boop, delete blip, short meow (pitch glide with vibrato). Hook one-line `sfx_play` calls at timer start/completion, check-in, journal save/delete, and errors. Acceptance: the timer never stalls while a sound plays; missing player does not crash or print; no zombie processes (`ps`); sound off is silent; volume 0 is silent; overlapping sounds are safe; Ctrl+C during playback exits cleanly.

**Verify:** ☐ each sound audible and distinct ☐ works with `paplay` absent but `aplay` present ☐ with neither: bell only ☐ no screen garbage from the child ☐ `strace -f` shows `fork`/`execve` only when sound is on.

---

## V9 — Notifications and terminal integration

**Goal:** a timer-finished alert you cannot miss, even from another window. **Files:** `timer.asm`, `sfx.asm` (reuse the spawn helper), `settings_ui.asm`, `data.asm`, `constants.inc`.

> **Prompt-Builder Paragraph — V9** Build me a prompt for a coding agent to add layered notifications, each gated by the settings flags. (1) On phase completion: bell plus a brief screen flash (`ESC[?5h`, about 150 ms later `ESC[?5l`; this is the one allowed extra write). (2) Window title kept current inside the normal frame buffer (`ESC]0;Pawmodoro - FOCUS 12:34 BEL`, "Time's up!" on completion), and a sensible title restored on exit. (3) Taskbar progress via `ESC]9;4;1;<percent> BEL`, cleared with `ESC]9;4;0;0 BEL` on phase end, pause handling (state 4 or 2), and every exit path. (4) Optional desktop toast: generalize the V8 spawn helper into `proc_spawn` (path, argv) and, if `/usr/bin/notify-send` exists, run it with a short title and body; on WSL optionally try `powershell.exe` with a minimal balloon-tip command, marked experimental, silent on failure. (5) Optional repeat reminder every 60 s while a completion screen waits for a key. Document which terminals support which layer; report what the agent could and could not verify.

**Verify:** ☐ title shows countdown in the taskbar ☐ toggles disable each layer ☐ unsupported terminal shows no garbage ☐ exit always clears title/progress.

---

## V10 — Integration, regression tests, bug list

**Goal:** make sure v2 did not break v1, and capture screenshots. **Files:** `tests/TEST_PLAN.md`, `tests/smoke.sh`.

> **Prompt-Builder Paragraph — V10** Build me a prompt for a coding agent to test and stabilize v2. Update `smoke.sh` for the new layout and add scenarios for: Settings theme change persisting across restart, corrupted `settings.dat`, journal delete (and cancel), journal wrap of a 200-character entry, ASCII charset mode, narrow-to-wide resize, Reduce motion, and sound disabled and no-player paths (use a temporary `PATH`-independent probe or a test flag; do not require audio hardware). Extend `TEST_PLAN.md` with at least 25 new cases (ID, Feature, Objective, Preconditions, Steps, Expected, Actual blank, Pass/Fail blank). Run `strace -c` and `strace -f` audits (writes per second while animating, zero writes idle, `fork`/`execve` counts), a CPU check, 200-key mashing on every screen including Settings, Ctrl+C at every prompt, and a zombie check. Debug failures with gdb or strace, fix root causes minimally, and report each bug as symptom, cause, fix. List the screenshots to capture (Settings, theme variants, big-digit timer, journal wrap with selection, delete confirm, confetti frame).

**Verify:** ☐ smoke passes ☐ every new test executed by a human ☐ bug list saved ☐ screenshots captured.

---

## V11 — Docs sync and Chapter 3 addendum

**Goal:** documentation that matches the code. **Files:** `README.md`, `docs/CHAPTER3_DRAFT.md`, `docs/notes/*`, comments only in `src/`.

> **Prompt-Builder Paragraph — V11** Build me a prompt for a coding agent to synchronize documentation with the actual source, changing no behavior. Part A: audit new and changed procedures for PRD §6.2 headers and inline comments. Part B: update `README.md` (new controls, settings, themes, sound requirements and the `paplay`/`aplay` dependency, WSL audio notes, new data files `settings.dat` and temporary `journal.tmp`, limitations). Part C: correct `docs/CHAPTER3_DRAFT.md` against the code — at minimum the `sys_signal` (not `sys_sigaction`) claim, demo durations 10/5/8 s, 200-character journal limit, instructions listed but not actually used (`PUSHA/POPA`, `NEG`, `LOOP`: verify each with grep), wireframes and the `.bss` budget — and add a new section for the v2 features (layout engine, theme model, animation loop, sound synthesis and the external-player caveat, journal rewrite-and-rename) with code excerpts under 15 lines and an updated instruction-set table. Mark anything it cannot verify as TODO. Output Markdown.

**Verify:** ☐ no claim in Chapter 3 contradicts the source ☐ README works on a clean clone ☐ instruction table matches `grep`.

---

## Fix Paragraph (any time a task fails)

> **Prompt-Builder Paragraph — Fix** Build me a prompt for a coding agent to fix a bug in Pawmodoro v2. The task I just finished is **\[Vn — name\]**. Symptom: **\[what I did, expected, got\]**. Exact messages and any `strace`/`gdb` output: **\[paste\]**. The agent must read `docs/PRD.md`, `docs/PRD_V2.md` and only the files involved, reproduce first, explain the root cause in plain language, make the smallest fix, avoid renaming procedures or touching unrelated code, rebuild warning-free, re-run the task's Verify list and `tests/smoke.sh`, and report what changed. If the fix needs an interface change, it must stop and ask first.

---

## Suggested order if time is short

**Must:** V1 → V2 → V3 (fixes cut text, adds delete). **Biggest visual win:** V2 → V4 → V6 (layout first, color system second, complete GUI-like visual pass third). **Then:** V5, V7. **Sound:** V8 (test your audio path first), V9 optional. Always finish with V10 and V11 so the report matches the code.
