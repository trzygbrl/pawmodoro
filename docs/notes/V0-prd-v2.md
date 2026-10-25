# V0 — PRD v2 addendum (explanation note)

**Task type:** documentation only. No assembly, tests, roadmaps or other docs were changed. Nothing in v2 is implemented yet.

## What was done
I wrote `docs/PRD_V2.md`, a short addendum to `docs/PRD.md`. It records the decisions for tasks V1–V11 in one place, so a coding agent stops following the old limits (56 columns, ASCII-only borders, 16 colors, ignored arrow keys, append-only journal).

## Why an addendum
The prototype works and is tested against PRD v1, so v1 stays the baseline. PRD v2 lists exactly which v1 items it replaces (§1.1 of the addendum), for example §3.3 colors, FR-U3/U4/U8, the §5 wireframes, FR-J1/J4 and the §6.5 memory budget. Everything else keeps working as before: timer rules, habit streak rules, journal line format, `stats.dat`/`habits.dat`, §6.2 coding conventions, and the existing procedure contracts.

## The decisions, in plain words
- **Layout:** the frame width follows the terminal: `min(columns − 2, 100)`, centered. That is 78 wide at 80×24 and 100 wide (centered) at 120×40. Below 80×24 the app still shows the "please enlarge" message.
- **UTF-8 / ASCII:** nice box and star glyphs by default, with a setting that swaps everything for plain ASCII. Emoji are avoided because they are two columns wide. Counting display columns by skipping UTF-8 continuation bytes only works for our approved glyphs; this is documented as a limitation.
- **Themes:** 12 named color slots (border, title, accent, …). A theme is just 12 numbers from the 256-color palette. Seven built-in themes, plus a custom one the user edits.
- **Settings file:** `settings.dat` is a fixed 24-byte file (magic, version, theme, 12 custom colors, flags, volume). A missing or damaged file means "use defaults", never a crash.
- **Keys:** arrows, PgUp/PgDn, Home, End and Delete get codes `0x101`–`0x109`. Unknown escape sequences are swallowed. A new state, `STATE_SETTINGS`, is opened from menu option `[5]`.
- **Journal delete:** copy every byte except the chosen entry into `journal.tmp` (2 KB at a time), then `rename` it over `journal.txt`. If anything fails before the rename, the original file is untouched and the temp file is removed. Deletion needs a `y` confirmation.
- **Animation:** it rides on the existing 100 ms tick, redraws only small regions, and still uses one `sys_write` per frame. A "Reduce motion" setting turns it off.
- **Sound:** Pawmodoro builds the 8-bit audio itself with integer math and pipes it to `paplay` or `aplay`. Assembly has no audio API, so that player is an **external dependency**, not part of our program. If it is missing, the terminal bell is used.
- **Notifications:** bell, screen flash, window title, taskbar progress and desktop toast are optional layers. Unsupported ones are skipped silently.
- **Syscalls and memory:** the syscall table gains `fork`, `pipe`, `dup2`, `execve`, `access`, `rename`, `unlink`, `lseek`. The memory budget grows to about 79 KB, mostly from the 32 KB sound buffer.
- **Requirements:** FR-V1 to FR-V44, each with an acceptance criterion and a way to check it.

## Findings from inspecting the repo
- `tests/smoke.sh` and `tests/TEST_PLAN.md` both exist. The 56-column assumption lives in `overflow_check()`, Scenario 16, and test cases TC-01, TC-42 and TC-46. Others (TC-39/40/41 and the 10-entry view) will also change.
- The v1 §6.5 budget totals 13,176 bytes, but the real `.bss` in `data.asm` totals 13,769 bytes. I used the real figure as the baseline and flagged the gap.
- `SYS_LSEEK` (19) and `SYS_SIGNAL` (48) are already in `constants.inc` but missing from the PRD syscall table.
- `docs/ROADMAP.md`, named in PRD §6.1, does not exist. The file is `docs/roadmap.md`. I did not touch it.
- The roadmap's slot list order differs from the addendum's slot-id order. The addendum's table is the one to follow.
- The roadmap lets screen-flash-off be an extra write. The addendum drops that exception so one write per frame is never broken.

## Still unimplemented
All of it. This task adds no code. Tests will be updated in V10, and `README.md` and Chapter 3 in V11. Palette values and the `.bss` numbers marked as assumptions are proposals that later tasks may refine by amending the addendum.
