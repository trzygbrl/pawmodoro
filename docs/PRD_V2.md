# Pawmodoro — PRD v2 Addendum

**Version:** 2.0-draft · **Course:** CAO10 · **Group:** 8 · **Task:** V0 (documentation only)
**Baseline:** `docs/PRD.md` (v1.0) · **Roadmap:** `docs/roadmap_v2.md`

> **Nothing in this document is implemented yet.** It defines *intended* behavior for tasks V1–V11. Statements marked **[Repo fact]** were verified by reading the repository during V0; everything else is a **[v2 requirement]**.

---

## 1. Status and relationship to PRD v1

- `docs/PRD.md` remains the **baseline**. This addendum supplements it and supersedes **only** the items listed in §1.1.
- Anything not listed as superseded **stays in force** (timer durations and rules, habit rules FR-H4/H5, journal line format, `stats.dat`/`habits.dat` formats, time model §6.3, §6.2 conventions, size/CPU limits).
- Existing features, data semantics and procedure contracts MUST stay compatible unless a requirement here says otherwise.
- Requirement IDs: v1 keeps `FR-U/T/H/J/D`; v2 uses only `FR-V<n>` (§13). No v1 ID is reused.
- Normative words: MUST, MUST NOT, SHOULD, MAY.

### 1.1 Superseded / amended items

| PRD v1 item | Status | What changes (v2 source) |
|---|---|---|
| §2 Non-goals ("sound beyond the terminal bell", "external service integration") | **Amended** | Synthesized sound via an *external local player* and optional local notifiers are allowed (§9, §10). Cloud/network/accounts remain non-goals. |
| §3 Platform ("minimum 80×24") | **Unchanged** | Still the minimum (§2). |
| §3.1 Syscall table | **Extended** | Original 8 rows kept verbatim; 8 rows added (§11). `lseek` (19) and `signal` (48) are used by the code but absent from the v1 table — documented here. |
| §3.2 Termios | **Unchanged** | |
| §3.3 ANSI table, "Colors … 16-color palette" | **Superseded (colors)** | 256-color `ESC[38;5;Nm` / `ESC[48;5;Nm` via named slots (§4). Other rows unchanged; OSC/`?5h` sequences added (§10). |
| FR-U1 (startup) | **Extended** | Also loads `settings.dat`, probes players, ignores SIGPIPE/SIGCHLD. |
| FR-U2 (menu keys) | **Amended** | Adds `5` Settings. Invalid keys still ignored. |
| FR-U3 (FSM) | **Extended** | Adds `STATE_SETTINGS` (§6). Existing states keep their values 0–4. |
| FR-U4 (one write/frame) | **Extended** | One write per frame stays; partial redraws allowed (§8). |
| FR-U5 (exit restore) | **Extended** | Also resets title/progress/flash state (§10, FR-V42). |
| FR-U6 ("warm red/yellow/cyan" palette) | **Superseded (palette)** | Colors come from theme slots. Poses idle/work/rest remain; more MAY be added. |
| FR-U7 (dashboard line) | **Unchanged** | |
| FR-U8 (plain ASCII borders) | **Superseded** | UTF-8 borders default, ASCII fallback setting (§3). |
| FR-T3 (progress bar, key help) | **Amended (presentation)** | Glyphs/colors per charset+theme. Bar stays 30 cells + percent. |
| FR-T5 (100 ms loop) | **Unchanged** | Reused as animation tick (§8). |
| FR-T6 (bell on phase end) | **Extended** | Bell becomes layer 1 of §10; stays the fallback. |
| FR-T1/T2/T4/T7/T8 | **Unchanged** | |
| FR-H2 / `HABIT_NAME_DISPLAY = 12` | **Superseded (display)** | Full 31-char names shown at adaptive width. Data unchanged. |
| FR-H3 keys | **Unchanged** | Arrow selection MAY be added without changing existing keys. |
| FR-J1 ("`V` view most recent 10") | **Superseded (view)** | Scrollable selectable list; `N` and `B` unchanged; `V` MAY remain as an alias (§7). |
| FR-J2 (line format) | **Unchanged** | |
| FR-J3 (`journal_add`) | **Unchanged** | |
| FR-J4 (last 4096 B, last 10 lines) | **Superseded** | Chunked backward reads, at most 16 KB window (§7). Missing/empty file still shows "No entries yet." |
| "journal is append-only" (implied §4.4) | **Amended** | Rewrite-and-rename deletion (§7). |
| FR-D1, FR-D4 | **Extended** | Apply to `settings.dat` and journal deletion. |
| FR-D2, FR-D3 | **Unchanged** | |
| §5 Wireframes (56-column) | **Superseded (geometry)** | Content/order remain illustrative; widths are runtime-computed (§2). |
| §6.1 Layout | **Extended** | MAY add `theme.asm`, `settings.asm`, `settings_ui.asm`, `anim.asm`, `sfx.asm`; new runtime files `settings.dat`, `journal.tmp` (add `journal.tmp` to `.gitignore`). |
| §6.2 Conventions | **Unchanged — mandatory** | Restated in §14. |
| §6.4 Contracts | **Preserved**, with one change | `key_poll`/`key_wait` return the new codes (§6). New procedures are *planned* names. |
| §6.5 Budget | **Superseded** | Replaced by §12. |
| §7 NFR | **Unchanged** | "Binary under ~64 KB" refers to the ELF file; `.bss` does not enlarge it. |
| §9 Stretch goals | **Partly promoted** | UTF-8 borders, themes, animation become v2 requirements. |

### 1.2 Repository facts relevant to v2 **[Repo fact]**

- `src/constants.inc`: `UI_FRAME_WIDTH=56`, `UI_FRAME_COL_RIGHT=56`, `HABIT_NAME_DISPLAY=12`, `JOURNAL_DISPLAY_WIDTH=52`, `STATE_MENU..STATE_QUIT = 0..4`, `TERM_MIN_COLS=80`, `TERM_MIN_ROWS=24`, `KEY_*` are ASCII only, `SYS_LSEEK=19`, `SYS_SIGNAL=48`, `NANOSLEEP_100MS`, `TICKS_PER_SECOND=10`.
- `src/data.asm` caches `term_cols`/`term_rows` and already queries `TIOCGWINSZ` at redraw boundaries.
- `tests/smoke.sh` (16 scenarios + `--full`) and `tests/TEST_PLAN.md` (TC-01…TC-49) exist at those paths.
- `docs/ROADMAP.md` named in PRD §6.1 does not exist; the file is `docs/roadmap.md`. Not changed by V0.

---

## 2. Adaptive layout and terminal constraints

Supersedes: FR-U8 width assumptions, §5 56-column wireframes, `UI_FRAME_*`, `UI_*_COL_*` fixed columns.

- Minimum terminal stays **80×24**. Smaller → the existing "Please enlarge the terminal" gate (no malformed UI).
- `ui_w = min(term_cols - 2, 100)`; `margin = (term_cols - ui_w) / 2` (integer floor); the frame occupies absolute columns `margin+1 … margin+ui_w`; `ui_h = term_rows`.

| Terminal | `ui_w` | `margin` | Frame columns |
|---|---:|---:|---|
| 80×24 | **78** | 1 | 2–79 |
| 100×30 | 98 | 1 | 2–99 |
| 120×40 | **100** | 10 | 11–110 (centered) |

- Layout MUST be recomputed whenever `(term_cols, term_rows)` differ from the cached values, **before** drawing the next affected frame (redraw-boundary polling is acceptable; no signal handler required).
- Every frame MUST stay within the terminal, clear stale cells (erase-to-EOL / erase-below), and remain one `sys_write`.
- Clipping/wrapping MUST count **display columns**, not bytes (§3).
- Later tasks MUST replace old 56-column assumptions in code, `tests/smoke.sh` and `tests/TEST_PLAN.md` (§15).

## 3. Character encoding and glyph fallback

- **UTF-8 is the preferred mode**; **ASCII fallback** is a persistent setting.
- Approved single-column glyph set (and mandatory ASCII equivalent):

| UTF-8 | ASCII | UTF-8 | ASCII | UTF-8 | ASCII |
|---|---|---|---|---|---|
| `─` | `-` | `│` | `\|` | `╭ ╮ ╰ ╯ ├ ┤ ┬ ┴ ┼` | `+` |
| `★` | `*` | `♥` | `v` (single column) | `●` / `○` | `@` / `o` |
| `▰` / `▱` | `#` / `-` | `█` / `░` | `#` / `.` | `✦` | `*` |

- Emoji and known double-width glyphs MUST NOT be used in layout-critical elements.
- ASCII mode MUST emit **no byte ≥ 0x80** from application-generated output; non-ASCII code points in *displayed user text* render as one `?` each (files are never altered).
- **Limitation:** counting non-continuation bytes (`10xxxxxx` excluded) is **not** a Unicode width algorithm. It is valid only for the approved glyph set and ASCII/Latin text. East-Asian-ambiguous glyphs (`★ ♥ ● ○`) may render 2 columns in CJK-locale terminals; ASCII mode is the remedy. Wide/combining characters in user text are best-effort and MUST NOT cause out-of-bounds writes; the right border may misalign.
- Control bytes (incl. ESC) and invalid/truncated UTF-8 in displayed text MUST render as `?` (preserves existing TC-43 behavior) and MUST NOT write past any destination buffer.

## 4. Theme and color-slot model

Exactly **12 slots**, ids 0–11 (order is normative; the V4 roadmap text lists them in a different order — this table governs):

| Id | Slot | Typical use |
|---:|---|---|
| 0 | `SLOT_BORDER` | frames, dividers |
| 1 | `SLOT_TITLE` | headings, brand |
| 2 | `SLOT_ACCENT` | key hints, badges |
| 3 | `SLOT_TEXT` | body text |
| 4 | `SLOT_DIM` | secondary text |
| 5 | `SLOT_OK` | success |
| 6 | `SLOT_WARN` | warning, paused |
| 7 | `SLOT_ERR` | errors |
| 8 | `SLOT_CAT` | cat art |
| 9 | `SLOT_BAR_FULL` | filled progress |
| 10 | `SLOT_BAR_EMPTY` | empty progress |
| 11 | `SLOT_HIGHLIGHT` | selected-row **background** |

- All colors MUST go through slots; no hard-coded color escapes in screen code. `ansi_bold` / `ansi_reset` MAY stay.
- 256-color only: `ESC[38;5;Nm` (fg), `ESC[48;5;Nm` (bg), `N` ∈ 0–255. Truecolor (`38;2`) MUST NOT be used.
- Planned (not existing): `ui_color` (IN `AL`=slot; appends fg escape from the active palette; invalid slot → no output) and `ui_bgcolor` (same, background). Both follow §6.2 (preserve registers, append to `out_buf`).
- Seven built-in themes, values per slot `0..11` (normative defaults; changes need an addendum edit):

| # | Theme | BORD | TITL | ACNT | TEXT | DIM | OK | WARN | ERR | CAT | BARF | BARE | HILT |
|--:|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| 0 | Strawberry Milk | 211 | 204 | 218 | 254 | 244 | 114 | 221 | 203 | 223 | 204 | 238 | 53 |
| 1 | Matcha Latte | 108 | 150 | 114 | 255 | 243 | 114 | 221 | 203 | 180 | 114 | 238 | 22 |
| 2 | Blueberry | 69 | 111 | 75 | 255 | 244 | 114 | 221 | 203 | 117 | 75 | 238 | 17 |
| 3 | Lavender Night | 141 | 183 | 147 | 253 | 243 | 114 | 221 | 203 | 225 | 141 | 237 | 54 |
| 4 | Sunset Peach | 215 | 209 | 216 | 255 | 244 | 114 | 221 | 203 | 223 | 209 | 238 | 94 |
| 5 | Mono Cozy | 245 | 255 | 250 | 252 | 240 | 250 | 255 | 255 | 252 | 255 | 238 | 240 |
| 6 | High Contrast | 231 | 231 | 226 | 231 | 250 | 46 | 226 | 196 | 231 | 231 | 240 | 21 |

- **Built-in vs custom:** `theme` byte 0–6 selects a built-in theme (custom bytes ignored). `theme = 7` (CUSTOM) uses the 12 custom bytes. Editing any slot copies the current palette into the custom bytes and sets `theme = 7`. Selecting a built-in theme does not erase custom bytes.
- **Reset to defaults** restores every settings field to §5 defaults (after a y/n confirm) and saves.
- **Invalid settings** fall back per §5.
- Every theme (esp. Mono Cozy, High Contrast) MUST NOT convey success/warning/error by color alone: status rows MUST carry a text/glyph marker (`OK`, `!`, `ERR` or equivalent). Selection MUST use a marker or reverse video in addition to `SLOT_HIGHLIGHT`.
- The default theme (0) SHOULD look close to the v1 warm look.

## 5. Persistent settings — `settings.dat`

Fixed-size, little-endian, **24 bytes**, written in the current working directory with `file_save`, read with `file_load` (existing contracts).

| Off | Size | Field | Valid | Default |
|---:|---:|---|---|---|
| 0 | 4 | `magic` (bytes `50 41 57 53` = "PAWS", dword `0x53574150`) | exact | `0x53574150` |
| 4 | 1 | `version` | `1` | 1 |
| 5 | 1 | `theme` (0–6 built-in, 7 custom) | 0–7 | 0 |
| 6 | 12 | `custom[0..11]` palette index per slot id | each 0–255 | copy of theme 0 |
| 18 | 1 | `anim` (1 = animations on, 0 = Reduce motion) | 0/1 | 1 |
| 19 | 1 | `sound` | 0/1 | 0 |
| 20 | 1 | `charset` (0 = UTF-8, 1 = ASCII) | 0/1 | 0 |
| 21 | 1 | `notify` (master for layers 2–5, §10) | 0/1 | 0 |
| 22 | 1 | `notify_layers` bitmask: b0 bell, b1 flash, b2 title, b3 progress, b4 desktop | `& ~0x1F == 0` | `0x01` |
| 23 | 1 | `volume` | 0–3 | 2 |
| | **24** | **total** = 4+1+1+12+1+1+1+1+1+1 | | |

Rules:
- **Missing** file → defaults, no message, file created on first save (FR-D1).
- **Truncated** (`size < 24`), **bad magic**, **version ≠ 1** (unsupported/future) → load **all defaults**; the bad file is left untouched until the next save. Extra bytes beyond 24 → treated as corrupted.
- **Field range errors** → the whole file is rejected (defaults), never partially applied, so state is always self-consistent.
- Any combination of `charset`, `anim`, `sound`, `notify` MUST be usable (e.g. ASCII + no animation + no sound).
- **Save error** (open/write failure, e.g. `settings.dat` is a directory): in-memory settings stay applied, a flag is set, the UI shows "Could not save" on the status row (FR-D4 style), the app keeps running; "Saved" is shown on success.
- Because bell is also required by FR-T6, `notify_layers` b0 defaults to on and `notify` gates only layers 2–5.

## 6. Keyboard, escape sequences, and states

New constants (MUST be added to `constants.inc`; existing codes untouched; all >255):

| Constant | Value | Constant | Value |
|---|---:|---|---:|
| `KEY_UP` | `0x101` | `KEY_PGUP` | `0x105` |
| `KEY_DOWN` | `0x102` | `KEY_PGDN` | `0x106` |
| `KEY_RIGHT` | `0x103` | `KEY_HOME` | `0x107` |
| `KEY_LEFT` | `0x104` | `KEY_END` | `0x108` |
| | | `KEY_DELETE` | `0x109` |

`KEY_DELETE` (ESC[3~) is distinct from existing `KEY_BACKSPACE` (127).

| Key | Accepted sequences |
|---|---|
| Up/Down/Right/Left | `ESC [ A/B/C/D`, `ESC O A/B/C/D` |
| PgUp / PgDn | `ESC [ 5 ~` / `ESC [ 6 ~` |
| Home / End | `ESC [ H` / `ESC [ F`, `ESC O H` / `ESC O F`; MAY also `ESC [ 1 ~` / `ESC [ 4 ~` |
| Delete | `ESC [ 3 ~` |

- Unknown/modified sequences (e.g. `ESC [ 1 ; 5 A`, F-keys) MUST be drained (up to a final byte `0x40–0x7E`, bounded to 8 bytes) and ignored (`-1`). No byte of a partial/unknown sequence may reach application input.
- A lone `ESC` (no follow-up after a short ~5 ms re-check) returns `KEY_ESC` (27). Existing screens ignore it as an invalid key.
- `key_poll`/`key_wait` otherwise keep their v1 contracts (letters uppercased, `-1` = none, `key_wait` blocking). Documented change: they may return values >255. Screens where a special key is irrelevant MUST ignore it (v1 behavior preserved).
- **`STATE_SETTINGS = 5`** is added; `STATE_MENU..STATE_QUIT` keep 0–4. Menu gains `[5] Settings` (key `5`) and help `[1-5]`. `STATE_SETTINGS` returns to `STATE_MENU` on `Esc`/`B`.
- Navigation conventions (new screens; existing controls unchanged): Up/Down move selection; Left/Right change a value; PgUp/PgDn page or step by 16; Home/End jump to first/last; Enter activates/toggles; `Esc` or `B` goes back; Ctrl+C quits cleanly.

## 7. Journal v2: navigation and deletion

- Selectable entry list; Up/Down move; PgUp/PgDn page toward older/newer entries via **chunked backward reads** (window ≤ 16 KB, partial first line discarded as in v1); Enter opens a full-entry view; `N`, `B` unchanged.
- **Logical record** = the byte range `[start, end)` of one `journal.txt` line **including its LF**; **display rows** = wrapped screen rows (≤ 4 per entry, wrapped at `ui_w - 6` columns, UTF-8-safe). Selection and deletion use only the logical range; wrapping MUST NOT affect which bytes are deleted. A partial (unloaded) first line cannot be selected.
- Delete: `D` or `Delete` key → prompt "Delete this entry? (y/n)"; only `Y` confirms; any other key cancels with the file untouched.
- Safe replacement, using `journal.tmp` in the same directory as `journal.txt`:
  1. `open(journal.txt, O_RDONLY)`; `open(journal.tmp, O_WRONLY|O_CREAT|O_TRUNC, 0644)`.
  2. Copy bytes `[0,start)` then `[end,EOF)` using `read`/`write`/`lseek` in chunks through a **dedicated 2 KB buffer** (handle short reads/writes; never load the whole journal).
  3. `close` both descriptors (on every path).
  4. `rename("journal.tmp","journal.txt")` (atomic on one filesystem).
- **On any failure** before a successful `rename`: close open descriptors, `unlink("journal.tmp")` if possible, leave `journal.txt` byte-identical, show "Could not delete".
- **On success:** show "Entry deleted", clamp selection to the new list, show "No entries yet." if empty (deleting the only entry leaves a valid empty file).
- Timestamps, encoding, append behavior and line format are unchanged.
- **Limitation:** `rename` protects against process failure; without `fsync` durability across power loss is not guaranteed.
- Planned generic helper `file_delete_range` (IN `ESI` path, `EAX` start, `EDX` end; OUT `EAX` 0 / -1) per roadmap V3; the signature is provisional until V3.

## 8. Animation and redraw model

- The **100 ms tick** (FR-T5, `time_sleep_100ms`) is unchanged and is the only animation clock; it is **not** the screen redraw rate. Timer countdown text still changes once per second; animated regions MAY redraw on selected ticks.
- Keyboard polling stays on every tick (≤ ~100 ms response).
- Animation MUST NOT alter durations, `focus_completed_flag`, `stats.dat`, `habits.dat`, or journal content, and MUST be frozen while the timer is paused or the size gate is active.
- Partial redraws (cat, title, bar, particles) are appended to `out_buf` and flushed with **one** `sys_write` per frame, regardless of the number of regions.
- Rate limits: ≤ **5** animation frames/s; with animation off, **no** writes beyond v1's (no idle writes); CPU < 1%; no busy-wait.
- `anim = 0` (**Reduce motion**) disables nonessential effects and restores static frames; all information and navigation remain.
- Effects MAY include cat blink/tail, shimmering bar, title color wave, menu twinkles, break "zZ", completion confetti (bounded particle count), heart pop. Pseudo-random effects use an integer LCG; a fixed-seed build constant SHOULD allow reproducible tests.

## 9. Sound architecture (external dependency)

- Pawmodoro **synthesizes unsigned 8-bit mono PCM at 11025 Hz** using integer arithmetic (phase accumulator, square/triangle waves, optional glide/vibrato, linear decay). No FPU/SSE.
- The sample buffer is bounded (32,768 B ≈ 2.97 s). Volume 0–3; **0 = no synthesis** (silent).
- **The player is an EXTERNAL DEPENDENCY** (not a syscall, not part of Pawmodoro): preferred `/usr/bin/paplay`, else `/usr/bin/aplay`. Sound is **not guaranteed** where neither exists or no audio environment is available (WSL2 audio needs WSLg/Windows 11).
- Pipeline:
  1. Generate samples into `sfx_buf`.
  2. `pipe(fds)` (42).
  3. `fork` (2). Child: close write end; `dup2(read_fd, 0)` (63); open `/dev/null` and `dup2` over fds 1 and 2; close spare fds; `execve` (11) player with args `paplay --raw --format=u8 --rate=11025 --channels=1` or `aplay -q -t raw -f U8 -r 11025 -c 1`; on any failure `sys_exit(127)` **directly** (no terminal code).
  4. Parent: close read end; write PCM to the pipe; close write end; return without waiting.
- **Environment:** `execve` MUST receive the parent's `envp` (captured from the initial stack at `_start`), because PulseAudio/WSLg depend on `XDG_RUNTIME_DIR`/`PULSE_SERVER`.
- Non-blocking: PCM (≤ 32 KB) is smaller than the default Linux pipe capacity (64 KB), so one `write` completes without waiting for the player; on a short/failed write the rest is dropped.
- **Probe:** `access(path, X_OK)` (33) once at startup; the result is cached. `access` only checks presence/permission, not that audio works.
- **Signals** (via existing `SYS_SIGNAL`=48, handler `1` = SIG_IGN): `SIGPIPE`(13) ignored so a dead player yields `-EPIPE` instead of killing the app; `SIGCHLD`(17) ignored so the kernel reaps players (no zombies, no `wait4`). Ignored dispositions are inherited by the player, which is acceptable.
- **Fallback:** if sound is off, volume 0, no player, or `pipe`/`fork`/`execve` fails → terminal bell (`0x07`) for *important* events only; never a crash, never skipped terminal restore.
- Sound events: start chirp, habit check-in sparkle, focus-complete fanfare, break chime, error, delete, short meow. Each `sfx_play` is non-blocking; at most one spawn per tick; after the single pipe write `sfx_buf` may be reused immediately.
- Fallback test: run with the players unavailable (e.g. test flag or unreadable path in a sandbox) and confirm bell only, no stderr/garbage, no crash, `ps` shows no zombies. Audio hardware MUST NOT be required by tests.

## 10. Optional notification layers

All layers are optional and environment-dependent; unsupported sequences/programs MUST fail harmlessly and MUST NOT change timer accounting or state.

| # | Layer | Mechanism | Gate |
|--:|---|---|---|
| 1 | Bell | `0x07` (also the universal fallback) | `notify_layers` b0 |
| 2 | Screen flash | `ESC[?5h`, then `ESC[?5l` ≥ 1 tick (100–200 ms) later, each inside a normal single-write frame | `notify` && b1 |
| 3 | Window title | `ESC]0;Pawmodoro - FOCUS 12:34 BEL`; "Time's up!" on completion | `notify` && b2 |
| 4 | Taskbar progress | `ESC]9;4;<state>;<pct> BEL` (Windows Terminal convention; ignored elsewhere); state 1 normal, 4 paused, 0 clear | `notify` && b3 |
| 5 | Desktop toast | `/usr/bin/notify-send` (probed with `access`); on WSL an **experimental** `powershell.exe` balloon; silent skip when absent | `notify` && b4 |

- A missing `notify-send`/`powershell.exe` is **not an error**.
- The v1 roadmap V9 calls the flash-off an "allowed extra write"; this addendum requires it to travel in a later normal frame, so **no exception** to one-write-per-frame exists.
- On every exit path: clear taskbar progress (`ESC]9;4;0;0 BEL`), end flash (`ESC[?5l`), and restore the title (preferred `ESC[22;0t` on start / `ESC[23;0t` on exit where supported; otherwise reset with an empty title `ESC]0;BEL`). Only sequences that were enabled/emitted need undoing. Title restoration is best-effort.
- Support differs by terminal (WSL/Windows Terminal, GNOME Terminal, tmux may swallow OSC); each layer needs a manual test on the target terminal.

## 11. Updated syscall reference (i386, `int 0x80`, result in EAX, `-4095..-1` = `-errno`)

Original 8 rows (exit 1, read 3, write 4, open 5, close 6, time 13, ioctl 54, nanosleep 162) are **preserved unchanged**. Added:

| Name | EAX | Purpose |
|---|---:|---|
| `fork` | 2 | Create a child process for audio playback |
| `pipe` | 42 | Create a pipe for PCM streaming |
| `dup2` | 63 | Redirect the child's standard input |
| `execve` | 11 | Launch an external audio player |
| `access` | 33 | Check whether a player path is available |
| `rename` | 38 | Replace the journal file with its rewritten temporary file |
| `unlink` | 10 | Remove a temporary file on failure |
| `lseek` | 19 | Seek through journal data and perform bounded file operations |

| Name | Inputs | Result / errors | Lifecycle |
|---|---|---|---|
| `fork` | none | child pid in parent, `0` in child, `<0` error | Child MUST only `dup2`/`close`/`open`/`execve`/`exit`; on error the parent falls back to bell. |
| `pipe` | `EBX` = `int[2]` ptr | `0` / `<0`; `fds[0]` read, `fds[1]` write | Every fd closed in parent and child on all paths. |
| `dup2` | `EBX` old fd, `ECX` new fd | new fd / `<0` | Closes old fd after redirect. |
| `execve` | `EBX` path, `ECX` argv (NULL-terminated), `EDX` envp (captured) | does not return on success; `<0` → child `exit(127)` | Strings in `.data`; argv array in `.bss`. |
| `access` | `EBX` path, `ECX` mode (`X_OK=1`) | `0` ok / `<0` | No descriptor. |
| `rename` | `EBX` old, `ECX` new | `0` / `<0` | Both files closed first; same directory. |
| `unlink` | `EBX` path | `0` / `<0` | Called only for the temp file on failure; error ignored. |
| `lseek` | `EBX` fd, `ECX` offset, `EDX` whence | new offset / `<0` | Whence `SEEK_SET=0`, `SEEK_END=2` (already in code). |

A later task MUST add `SYS_FORK`, `SYS_PIPE`, `SYS_DUP2`, `SYS_EXECVE`, `SYS_ACCESS`, `SYS_RENAME`, `SYS_UNLINK` to `constants.inc` (`SYS_LSEEK` and `SYS_SIGNAL` already exist). Raw syscall numbers MUST NOT appear elsewhere in source.

## 12. Updated `.bss` budget

**Baseline.** PRD §6.5 lists 13,176 B (`out_buf` 8192 + `in_buf` 16 + `line_buf` 256 + `file_buf` 512 + `jrnl_buf` 4096 + 2×36 termios + 8 timespec + 6×4 state = 13,176). The real `src/data.asm` also reserves other variables (`out_len`, `term_active`, `date_buf`, `time_buf`, cat/redraw vars, timer/stats vars, habits, journal view state, `jrnl_lines`, `app_exiting`, `winsize`, terminal size, message pointers). Summed from the source: **13,769 B** (arithmetic: 8192+4+16+256+512+4096+72+8+24 = 13,180; +4+11+6 = 13,201; +12 = 13,213; +12 = 13,225; +16 = 13,241; +4+384+4 = 13,633; +20+80 = 13,733; +4+8+8+8+8 = 13,769). The §6.5 gap of 593 B is an **ambiguity in v1**; v2 uses the 13,769 B figure as baseline (conservative).

**New allocations** (all assumptions labelled **[A]**):

| # | Allocation | Bytes | Count | Total |
|--:|---|---:|---:|---:|
| 1 | `out_buf` growth 8192 → 24576 **[A]** worst-case 100×40 frame with UTF-8 + SGR | 16,384 | 1 | 16,384 |
| 2 | `jrnl_buf` growth 4096 → 16384 (V3 window) | 12,288 | 1 | 12,288 |
| 3 | `sfx_buf` (8-bit PCM, 11025 Hz × 2.97 s) | 32,768 | 1 | 32,768 |
| 4 | `del_copy_buf` (journal delete chunks) | 2,048 | 1 | 2,048 |
| 5 | `jrnl_entries` (ptr, len, file offset) × 64 **[A]** (v1 `jrnl_lines` kept) | 12 | 64 | 768 |
| 6 | `clip_buf` UTF-8 clip/wrap scratch (≥ 100 cols × 3 B) | 320 | 1 | 320 |
| 7 | `settings_file_buf` | 24 | 1 | 24 |
| 8 | `settings_cur` (live settings copy) | 24 | 1 | 24 |
| 9 | `settings_state` (loaded/save_failed/dirty/msg) | 4 | 4 | 16 |
| 10 | `active_palette` (12 slots) | 12 | 1 | 12 |
| 11 | layout vars (`ui_w`,`ui_h`,`ui_col0`,margin,last cols/rows) | 4 | 6 | 24 |
| 12 | `key_seq_buf` 8 + `key_seq_len` 4 | 12 | 1 | 12 |
| 13 | journal selection/delete state (sel, top, count, start, end, size, mode, confirm, tmp fds, msg…) | 4 | 12 | 48 |
| 14 | `anim_state` (frame, seed, per-effect counters) | 4 | 16 | 64 |
| 15 | `anim_particles` (x,y,vx,vy dwords) × 20 | 16 | 20 | 320 |
| 16 | `anim_dirty` region flags | 4 | 8 | 32 |
| 17 | `sfx_state`: pipe fds 8, pid 4, player 4, id 4, len 4, active 4, argv 8×4 = 32, `envp_ptr` 4 | 64 | 1 | 64 |
| 18 | `notify_state` | 4 | 8 | 32 |
| 19 | `notify_argv` 8 ptrs | 4 | 8 | 32 |
| 20 | `notify_title` scratch | 64 | 1 | 64 |
| 21 | Safety reserve **[A]** | 256 | 1 | 256 |
| | **New total** | | | **65,600** |

Check: 16384+12288 = 28,672; +32768 = 61,440; +2048 = 63,488; +768 = 64,256; +320 = 64,576; +24+24+16+12+24 = 64,676; +12+48 = 64,736; +64+320+32 = 65,152; +64+32+32+64 = 65,344; +256 = **65,600**.

**Final v2 `.bss` = 13,769 + 65,600 = 79,369 B (≈ 77.5 KiB).** Hard cap: **81,920 B (80 KiB)**. All v2 buffers are fixed-size; no journal, animation or audio storage is unbounded. Read-only `.data` (theme table 7×12 = 84 B, strings, sound step tables) is outside `.bss`. `.bss` does not increase the ELF file size.

## 13. Functional requirements FR-V

Verification uses the tooling in `tests/TEST_PLAN.md` §1 (tmux, strace, xxd). "Gate" = cannot pass until the named task is implemented.

### 13.1 Layout and encoding

| ID | Requirement | Acceptance criterion | Verification |
|---|---|---|---|
| **FR-V1** | `ui_w = min(term_cols-2,100)`, `margin=(term_cols-ui_w)/2`, frame at columns `margin+1…margin+ui_w` on every screen. | At 80×24 top border spans columns 2–79 (78 wide); at 120×40 columns 11–110 (100 wide); at 100×30 98 wide. | tmux sized per case; `cap` first row → check leading spaces and `length`. (Gate V2) |
| **FR-V2** | Screens use `ui_h = term_rows` and never draw past the last row/column. | No captured row longer than `term_cols`; no content below row `term_rows`. | `tmux capture-pane -p \| awk -v w=$COLS 'length>w'` prints nothing, on all screens at 80×24 and 120×40. (Gate V2) |
| **FR-V3** | Terminals below 80×24 show the enlargement message instead of the UI (v1 gate retained). | At 79×24 and 80×23 the text "Please enlarge the terminal" and "(need 80x24" appear and no frame glyphs. | Existing smoke Scenario 15 plus 79×24 / 80×23 cases. (V0-baseline: existing) |
| **FR-V4** | Resizing updates layout before the next affected frame. | After `tmux resize-window` 80×24 → 120×40 the next capture (≤ 1 s) shows a 100-wide centered frame with no stale cells outside it; and back. | tmux resize + capture diff. (Gate V2) |
| **FR-V5** | Every frame (all screens, gate, partial redraws) is exactly one `sys_write` to fd 1. | `strace -e trace=write` shows exactly one `write(1,…)` per redraw in a scripted menu→timer→habits→journal→settings run (no splits). | `strace -f -e trace=write -o w.log ./build/pawmodoro`, count writes vs redraws. (Gate V2+) |
| **FR-V6** | Clipping/wrapping use display columns; clipped text ends with a visible marker. | A 200-char journal entry and a 31-char habit name render fully at `ui_w-6`/available columns; a string with 3-byte glyphs clipped to N columns shows exactly N columns. | Seed `journal.txt`/`habits.dat`; tmux capture; `awk` width check. (Gate V2) |
| **FR-V7** | UTF-8 mode uses only the approved glyph set (§3) for structural elements; no emoji/wide glyphs. | Raw output contains only ASCII plus the approved code points. | `tmux capture-pane -p \| grep -oP '[^\x00-\x7F]' \| sort -u` ⊆ approved set. (Gate V6) |
| **FR-V8** | ASCII mode emits no byte ≥ 0x80 from application output; non-ASCII user text shows `?`. | With `charset=1` captures of all screens match `^[\x00-\x7F]*$`; alignment unchanged vs UTF-8 mode. | `LC_ALL=C grep -P '[^\x00-\x7F]'` on captures prints nothing. (Gate V4/V6) |
| **FR-V9** | Control bytes (ESC) and invalid/truncated UTF-8 in displayed text become `?` and never overflow a buffer. | Journal seeded with `\x1b[31m`, a lone `0xC3`, and an overlong sequence renders `?`, colors/cursor unaffected, no crash. | Extends TC-43; seeded-file run under tmux. (Gate V2) |
| **FR-V10** | The charset setting persists across restarts. | Set ASCII, quit, relaunch: still ASCII; `settings.dat` byte 20 = `01`. | `xxd -s20 -l1 settings.dat`. (Gate V5) |

### 13.2 Themes and settings

| ID | Requirement | Acceptance criterion | Verification |
|---|---|---|---|
| **FR-V11** | Exactly 12 named slots with ids 0–11 per §4; all colors go through slots. | `constants.inc` defines the 12 names with those values; `grep -rn 'ansi_fg_' src/` shows matches only in `theme.asm`/`data.asm`. | grep. (Gate V4) |
| **FR-V12** | Colors use 256-color escapes only. | Output contains `ESC[38;5;` / `ESC[48;5;` and never `38;2` / `48;2`. | `strace -e write` output or `script` log + `grep -c '38;2'` = 0. (Gate V4) |
| **FR-V13** | Seven built-in themes with the §4 palettes; each renders all 12 slots. | For each theme 0–6, on all screens, the emitted fg indices for slot uses equal the §4 table values. | Set theme via `settings.dat` bytes; strace/`script` capture; compare indices. (Gate V4) |
| **FR-V14** | Custom slot values are editable, persisted, and reset restores defaults. | Edit slot 7 to 9 → byte 13 = `09`, byte 5 = `07`; restart keeps it; Reset (y) → file equals the 24-byte default image. | `xxd settings.dat`; `cmp` with golden default. (Gate V5) |
| **FR-V15** | No meaning by color alone; High Contrast readable. | In Mono Cozy and High Contrast every status row contains a marker word/glyph and selected rows a marker/reverse video. | Capture with `tmux capture-pane -p` (no colors) and grep markers. (Gate V6) |
| **FR-V16** | `settings.dat` is exactly the §5 layout, 24 bytes, defaults per table. | After first save `stat -c %s` = 24; bytes 0–3 `50 41 57 53`; byte 4 = `01`; defaults match. | `stat`, `xxd`. (Gate V4) |
| **FR-V17** | Missing/truncated/bad-magic/bad-version/out-of-range/oversize files load full defaults without crash. | Each of: absent, 10 bytes, wrong magic, version 2, theme 9, volume 4, 25 bytes → app starts with defaults, exit code 0 on Q. | `truncate`/`printf` crafted files + smoke-style run. (Gate V4) |
| **FR-V18** | A failed settings save shows "Could not save" and the app continues. | With `mkdir settings.dat`, changing a setting shows "Could not save"; app still responds and exits 0. | tmux scenario. (Gate V5) |

### 13.3 Keyboard and states

| ID | Requirement | Acceptance criterion | Verification |
|---|---|---|---|
| **FR-V19** | Nine special-key constants exist with values `0x101…0x109` (§6). | `grep -E 'KEY_(UP\|DOWN\|RIGHT\|LEFT\|PGUP\|PGDN\|HOME\|END\|DELETE)' src/constants.inc` shows the nine unique values > 255. | grep + uniqueness check. (Gate V1) |
| **FR-V20** | Known sequences map to codes; unknown ones are drained and ignored with no leaked bytes. | Each §6 sequence returns its distinct code; `ESC[1;5A`, `ESC[15~`, `ESC[Z` return `-1` and menu shows no stray `A`,`~`,`5`,`Z` actions. | `tmux send-keys` / `printf` sequences against the V1 demo; capture. (Gate V1) |
| **FR-V21** | Existing key behavior unchanged: letters uppercased, `-1` none, `key_wait` blocks; lone ESC returns 27 after ≈5 ms. | v1 smoke scenarios 2–13 pass unchanged; lone Esc on Settings returns to menu. | `bash tests/smoke.sh`; manual Esc. (Gate V1) |
| **FR-V22** | `STATE_SETTINGS = 5` and menu `[5] Settings`; other states keep 0–4. | Pressing `5` on menu opens Settings; `Esc`/`B` returns; `STATE_QUIT` still 4. | grep constants; tmux. (Gate V5) |
| **FR-V23** | Settings navigation follows §6 conventions; every row reachable by keyboard only; mashing is safe. | All rows reachable with Up/Down/Left/Right/Enter; 200 random keys produce no crash/overflow. | tmux key-mash loop + `awk` width check. (Gate V5) |

### 13.4 Journal

| ID | Requirement | Acceptance criterion | Verification |
|---|---|---|---|
| **FR-V24** | Journal shows a selectable list navigable with Up/Down/PgUp/PgDn (and Enter for the full entry). | Selection marker moves; PgUp reaches entries older than the last 10 in a 300-entry file. | Seed file; tmux keys; capture. (Gate V3) |
| **FR-V25** | Wrapping is UTF-8-safe, ≤ 4 rows/entry; selection/deletion use logical byte ranges. | A 200-char entry shows fully; deleting a wrapped (multi-row) entry removes exactly its one line. | `diff` of file before/after equals that line. (Gate V3) |
| **FR-V26** | Delete requires "Delete this entry? (y/n)"; only `Y` deletes via bounded 2 KB copy to `journal.tmp` then `rename`. | `N` leaves the file `cmp`-identical; `Y` removes exactly one line; works on first/middle/last/only entry and on a >16 KB file. | `cmp`, `wc -l`, `strace -e trace=read,write,rename`. (Gate V3) |
| **FR-V27** | Failure leaves the original intact, removes `journal.tmp`, closes fds, shows "Could not delete". | With `mkdir journal.tmp`, delete → message shown, `journal.txt` `cmp`-identical, no extra open fds. | `ls -l /proc/<pid>/fd`; `cmp`. (Gate V3) |
| **FR-V28** | Success shows "Entry deleted" and keeps a valid clamped selection; deleting the only entry shows "No entries yet.". | After deleting the last list item selection moves up; after the only entry `journal.txt` is 0 bytes and "No entries yet." appears; `ls` shows no `journal.tmp`. | tmux + `ls`/`stat`. (Gate V3) |

### 13.5 Animation, sound, notifications

| ID | Requirement | Acceptance criterion | Verification |
|---|---|---|---|
| **FR-V29** | Animation uses the 100 ms tick and never changes timer/habit/journal data. | A demo-mode focus session with animation on yields the same `stats.dat` and 10 s ±1 s duration as with animation off. | Compare `stats.dat` + timing. (Gate V7) |
| **FR-V30** | Partial redraws are buffered and flushed with one write per frame. | During animation `strace -e write` shows one write per frame even when ≥ 2 regions animate. | strace. (Gate V7) |
| **FR-V31** | Reduce motion (`anim=0`) yields static frames with all info/navigation intact. | With `anim=0`, two captures 1 s apart on the menu are identical, `strace -c` write count over 10 s idle = 0, all keys still work. | `strace -c -e trace=write`; capture diff. (Gate V7) |
| **FR-V32** | Animation is rate-limited and cheap. | ≤ 5 writes/s while animating; CPU < 1% (`ps -o %cpu`) in menu and timer over 30 s. | `strace -c`, `ps`. (Gate V7) |
| **FR-V33** | Sound is synthesized 8-bit PCM (integer math, ≤ 32 KB, 11025 Hz); volume 0 and sound off are silent. | Source has no FPU/SSE opcodes; with `sound=0` or `volume=0` `strace -f` shows no `fork`/`execve`. | `grep`/`objdump -d \| grep -E 'fld\|xmm'` empty; `strace -f`. (Gate V8) |
| **FR-V34** | Playback uses `pipe`→`fork`→(child `dup2`,`execve`) with parent closing unused fds and passing `envp`; the timer never stalls. | `strace -f` shows `pipe`, `fork`, `dup2(…,0)`, `execve("/usr/bin/paplay"\|"/usr/bin/aplay")`; focus timer tick spacing stays ≈100 ms during playback. | `strace -f -tt`; fd list check. (Gate V8) |
| **FR-V35** | With no player/audio, the bell is used and nothing crashes or prints. | With both players unavailable, completion emits `0x07` only; exit code 0; no stderr; `ps` shows no zombies. | Sandbox without players; `strace`; `ps axo stat \| grep Z`. (Gate V8) |
| **FR-V36** | `SIGPIPE` and `SIGCHLD` are ignored via `signal` (48, handler 1). | `strace` shows `signal(SIGPIPE, SIG_IGN)` and `signal(SIGCHLD, SIG_IGN)` at startup; killing the player mid-playback does not kill Pawmodoro. | `strace`; `pkill paplay` during play. (Gate V8) |
| **FR-V37** | Layers 1–4 (bell, flash, title, progress) are individually gated, harmless when unsupported, and flash-off is a later frame. | Each layer's bytes appear only when enabled; `ESC[?5h` and `ESC[?5l` occur in different writes; unsupported terminals show no garbage. | strace write contents; tmux capture. (Gate V9) |
| **FR-V38** | Desktop notification runs only if enabled and the program exists; absence is silent. | With `notify-send` absent, completion succeeds with no message; with it present one process is spawned per completion. | `strace -f`; sandbox. (Gate V9) |
| **FR-V39** | Notifications never change timer accounting; on exit title/progress/flash are cleared. | After quit, output ends with `ESC]9;4;0;0` and `ESC[?5l` (when used) and the title is restored/reset; `stats.dat` identical with notifications on/off. | strace tail of writes; `cmp`. (Gate V9) |

### 13.6 Cross-cutting

| ID | Requirement | Acceptance criterion | Verification |
|---|---|---|---|
| **FR-V40** | New syscalls use named constants (§11) and the i386 `int 0x80` convention; errors checked. | No literal syscall numbers outside `constants.inc`; each new call site tests `EAX` for negative. | grep + code review. (Gate V3/V8) |
| **FR-V41** | All v2 buffers are fixed-size; `.bss` ≤ 81,920 B and matches §12. | `size build/pawmodoro` / `nm -S` shows `.bss` ≤ 81,920 B and listed buffers sized per §12. | `size`, `nm -S --size-sort`. (Gate V10) |
| **FR-V42** | Every exit path (Q, Ctrl+C, SIGTERM/HUP, errors, `/dev/full`) restores termios, cursor, colors, alt screen, and any title/progress/flash change. | After each exit, `tmux display -p '#{alternate_on}'` = 0, cursor visible, echo on, exit codes as v1 (0/130/1). | Extend smoke Scenarios 12–14; TC-47/48. (Gate V10) |
| **FR-V43** | v1 behavior and procedure contracts are preserved; build is warning-free. | `make` prints no "warn"; `bash tests/smoke.sh` passes except scenarios intentionally updated per §15. | `make`; `bash tests/smoke.sh`. (V0-baseline) |
| **FR-V44** | All future code obeys §14 conventions. | Every new procedure has a header with Purpose/IN/OUT/CLOBBERS; `nasm -Wall` clean; no FPU/SSE/libc. | Review + `nasm -f elf32 -g -F dwarf -Wall`. (Gate V1–V11) |

## 14. Compatibility, security, and conventions (apply to all later tasks)

PRD §6.2 stays **mandatory**; this list restates it and is **not** permission to edit source during V0:

1. Register inputs/outputs documented per procedure; a procedure preserves every register it modifies except documented outputs.
2. Every procedure starts with a header comment: purpose, `IN:`, `OUT:`, `CLOBBERS:`.
3. Logical instruction groups carry inline comments explaining *why*.
4. `snake_case` procedures/labels with the existing module prefixes (new: `theme_`, `settings_`, `anim_`, `sfx_` MAY be added); local labels start with `.`; constants are uppercase `equ`.
5. Constants (syscalls, keys, sizes, slots, offsets) live in `constants.inc`; no magic numbers.
6. Plain x86-32 integer instructions only (allowed set per §6.2.6); **no FPU, SSE, libc or C runtime**; 32-bit Linux ABI, `int 0x80` only.
7. Build warning-free (`nasm -f elf32 -g -F dwarf -Wall`); existing smoke tests keep passing except explicitly updated expectations.
8. Existing procedure contracts (§6.4) remain unless a task documents a change (`key_poll`/`key_wait` return range is the only one planned here).

Cross-cutting rules: no unbounded journal/audio/animation buffers; no unsafe buffer writes or malformed ANSI sequences; no journal loss on failed deletion; no fatal error from a missing optional external program; every terminal-exit path restores all terminal state (FR-V42).

## 15. Regression and test-plan impact

### 15.1 Existing checks inventoried **[Repo fact]**

`tests/smoke.sh` runs in tmux at 80×24 (scenario = existing check):

| Existing check | Fixed-size / v1 assumption | Future action |
|---|---|---|
| `overflow_check()` helper: `awk 'length($0)>56'` | 56-column limit; used by Scenario 2 | Replace with `term_cols`-based check; frame-width check = `ui_w` |
| Scenario 16 "Zero Screen Overflow (> 56 Columns)" (menu, habits, journal) | 56 columns | Update to ≤ 80 at 80×24 and ≤ 120 at 120×40; add frame-width asserts |
| Scenario 15 size gate (60×20 → "Please enlarge the terminal" / "(need 80x24") | Unchanged | Keep; add 79×24, 80×23 |
| Scenarios 1–14 (menu, demo, timer, pause, completion + note, habits 52-byte file, journal timestamp, corrupted data, Ctrl+C 0/130, non-TTY) | Text/layout strings; `Today:`, `[4] Demo mode`, journal `V` flow | Keep; update only where UI text changes (menu `[1-5]`, journal `V` flow) |
| `--full` 4-session cycle | none | Keep |

`tests/TEST_PLAN.md` (TC-01…TC-49; section 4 maps smoke → TC): items to review/update later:

| TC | Assumption | Future action |
|---|---|---|
| TC-01 | "56-col box frame", footer `[1-4]` | Runtime width; `[1-5]`, Settings row |
| TC-02 | Up Arrow ignored | Still ignored on menu (new key code ignored) |
| TC-42 | Journal truncated at column 52, border at 56 | Replace with wrap/scroll at `ui_w-6` |
| TC-39, TC-40, TC-41 | "most recent 10", 4096-byte tail | Update to scrollable list, 16 KB window |
| TC-46 | `awk 'length>56'` | `term_cols`-based |
| TC-27 | Habit name rendered within old bounds | Full 31 characters visible |
| TC-08/09 | Colors named (bright yellow) | Slot/theme-based |
| §1.A, §4 | "exactly 80 by 24" only; smoke mapping table | Add 120×40 and mapping rows |
| §2 limitation 3 | Resize detected at redraw boundary | Still valid for FR-V4 |

### 15.2 Checks V0 can verify now vs later

| Group | Executable in V0? |
|---|---|
| Document exists, FR-V ids unique, syscall rows/numbers present, settings size sum = 24, `.bss` arithmetic, no source/test/PRD change (`git diff --exit-code`) | **Yes (V0)** |
| Existing `make` and `bash tests/smoke.sh` as **regression only** (need nasm, ld, tmux) | **Yes if tools installed**; they do not test v2 features |
| 78/100-column frames, minimum-size at 79×24/80×23 (v1 gate exists, but new widths do not), no line over terminal width, UTF-8/ASCII, 7 themes × 12 slots, settings persistence/corruption, special keys, journal wrap/scroll/delete (first/middle/last/only, failure cleanup), animation + reduce motion, one-write-per-frame with partial redraws, sound off/no player/bell, notifications, terminal restore with new state | **No — after V1–V9** (see Gate column); V10 turns them into automated/manual tests |

V0 MUST NOT modify tests; it records expected updates only.

## 16. Known limitations and assumptions

- UTF-8 width handling is limited to the approved glyph set (§3); no full Unicode width tables.
- Sound requires an external player and an audio environment; not guaranteed (WSL2 needs WSLg/Windows 11).
- Notification support is terminal/OS dependent (OSC 9;4 is Windows Terminal; PowerShell toast is experimental).
- `rename` gives atomic replacement against process failure only (no `fsync`).
- Theme palette values and sizes in §4/§12 marked **[A]** are chosen proposals; later tasks may tighten them only by amending this file.
- `TZ_OFFSET = 28800` (UTC+8) remains a documented limitation (unchanged).
