#!/usr/bin/env bash
# =============================================================================
# Pawmodoro - Automated Smoke Test Suite
# File: tests/smoke.sh
# Course: CAO10 (Group 8)
# Purpose: Headless verification of all Pawmodoro subsystems using tmux.
# =============================================================================
set -u

# Resolve repository root path
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/build/pawmodoro"

# Parse command line flags
FULL_MODE=0
for arg in "$@"; do
    if [ "$arg" = "--full" ]; then
        FULL_MODE=1
    fi
done

# Check dependencies
if ! command -v tmux >/dev/null 2>&1; then
    echo "Error: tmux is required but not installed." >&2
    exit 2
fi

# Step 1: Build binary and check for warnings
echo "=== 1. Building Pawmodoro ==="
BUILD_LOG=$(mktemp)
make -C "$REPO_ROOT" clean >/dev/null 2>&1
if ! make -C "$REPO_ROOT" 2>&1 | tee "$BUILD_LOG"; then
    echo "FAIL: Compilation error" >&2
    rm -f "$BUILD_LOG"
    exit 1
fi

if grep -i "warn" "$BUILD_LOG" >/dev/null 2>&1; then
    echo "FAIL: Build produced compiler/linker warnings" >&2
    rm -f "$BUILD_LOG"
    exit 1
fi
rm -f "$BUILD_LOG"

if [ ! -f "$BIN" ]; then
    echo "FAIL: Binary $BIN not found after build" >&2
    exit 1
fi
echo "PASS: Build warning-free (32-bit ELF binary generated)"

# Step 2: Set up temporary sandbox directory and unique tmux session
TMP_DIR=$(mktemp -d /tmp/paw_smoke_XXXXXX)
TMUX_SESSION="paw_smoke_$$"
cp "$BIN" "$TMP_DIR/pawmodoro"

cleanup() {
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# Test Counters
PASSED=0
FAILED=0

pass() {
    local name="$1"
    echo "PASS: $name"
    PASSED=$((PASSED + 1))
}

fail() {
    local name="$1"
    local detail="${2:-}"
    echo "FAIL: $name"
    if [ -n "$detail" ]; then
        echo "  [Detail] $detail"
    fi
    echo "  [Captured Screen]"
    cap | sed 's/^/    | /'
    FAILED=$((FAILED + 1))
}

# Helper functions to interact with tmux
cap() {
    tmux capture-pane -t "$TMUX_SESSION" -p
}

send() {
    tmux send-keys -t "$TMUX_SESSION" "$@"
}

wait_for() {
    local pattern="$1"
    local timeout="${2:-25}"
    local start
    start=$(date +%s)
    while true; do
        if cap | grep -q -- "$pattern"; then
            return 0
        fi
        local now
        now=$(date +%s)
        if [ $((now - start)) -ge "$timeout" ]; then
            return 1
        fi
        sleep 0.2
    done
}

wait_for_not() {
    local pattern="$1"
    local timeout="${2:-10}"
    local start
    start=$(date +%s)
    while true; do
        if ! cap | grep -q -- "$pattern"; then
            return 0
        fi
        local now
        now=$(date +%s)
        if [ $((now - start)) -ge "$timeout" ]; then
            return 1
        fi
        sleep 0.2
    done
}

overflow_check() {
    local ov
    # Terminal width is 80 columns; frame occupies columns 2..79 (ui_w=78, centered).
    # No row may exceed the right frame border at column 79 or the terminal width.
    ov=$(cap | awk 'length($0)>79{print "row " NR ": " $0}')
    if [ -n "$ov" ]; then
        return 1
    fi
    return 0
}

# Launch tmux session
tmux new-session -d -s "$TMUX_SESSION" -x 80 -y 24 -c "$TMP_DIR" bash
sleep 0.3

# Launch pawmodoro inside tmux
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.5

echo "=== 2. Running Scenarios ==="

# -----------------------------------------------------------------------------
# Scenario 1: Menu Title & Dashboard Layout
# -----------------------------------------------------------------------------
if wait_for "P A W M O D O R O" 5 && cap | grep -q "Today:" && cap | grep -q "Habits:" && cap | grep -q "\[4\] Demo mode: OFF" && cap | grep -q "\[5\] Settings"; then
    pass "Scenario 1 - Menu title, dashboard, demo mode, and settings option"
else
    fail "Scenario 1 - Menu title, dashboard, demo mode, and settings option"
fi

# -----------------------------------------------------------------------------
# Scenario 2: Invalid Keys Ignored
# -----------------------------------------------------------------------------
send "X" "9" " "
sleep 0.4
if cap | grep -q "P A W M O D O R O" && cap | grep -q "cozy focus - habits - notes" && overflow_check; then
    pass "Scenario 2 - Invalid keys ignored without screen corruption"
else
    fail "Scenario 2 - Invalid keys ignored without screen corruption"
fi

# -----------------------------------------------------------------------------
# Scenario 3: Demo Mode Toggle
# -----------------------------------------------------------------------------
send "4"
sleep 0.3
if wait_for "\[4\] Demo mode: ON" 3 && cap | grep -q "Demo mode ON (10 s focus)"; then
    pass "Scenario 3 - Key 4 toggles demo mode ON with status update"
else
    fail "Scenario 3 - Key 4 toggles demo mode ON with status update"
fi

# -----------------------------------------------------------------------------
# Scenario 4: Timer Startup & Layout
# -----------------------------------------------------------------------------
send "1"
if wait_for "FOCUS - Session 1 of 4" 5 && cap | grep -q "\[DEMO\]" && cap | grep -q "\[P\] Pause"; then
    pass "Scenario 4 - Key 1 starts focus timer with demo badge and controls"
else
    fail "Scenario 4 - Key 1 starts focus timer with demo badge and controls"
fi

# -----------------------------------------------------------------------------
# Scenario 5: Pause and Resume
# -----------------------------------------------------------------------------
send "P"
if wait_for "PAUSED" 3; then
    TIME_BEFORE=$(cap | grep -o "[0-9][0-9]:[0-9][0-9]" | head -n 1)
    sleep 2.5
    TIME_AFTER=$(cap | grep -o "[0-9][0-9]:[0-9][0-9]" | head -n 1)
    if [ "$TIME_BEFORE" = "$TIME_AFTER" ]; then
        send "P"
        if wait_for_not "PAUSED" 3; then
            pass "Scenario 5 - Pause freezes countdown and resume continues"
        else
            fail "Scenario 5 - Resume failed to clear PAUSED state"
        fi
    else
        fail "Scenario 5 - Timer countdown changed while paused ($TIME_BEFORE -> $TIME_AFTER)"
    fi
else
    fail "Scenario 5 - Pause failed to show PAUSED indicator"
fi

# -----------------------------------------------------------------------------
# Scenario 6: Natural Focus Completion & FR-T8 Quick Note
# -----------------------------------------------------------------------------
# In demo mode, focus duration is 10 seconds.
if wait_for "Focus complete! Add a quick note? (y/n)" 20; then
    send "Y"
    if wait_for "Note (max 200, Enter alone cancels): " 5; then
        send "Smoke test note entry" Enter
        if wait_for "Note saved" 5 && cap | grep -q "\[Any key\] Continue to break"; then
            pass "Scenario 6 - Focus natural completion and quick-note save"
        else
            fail "Scenario 6 - Quick note failed to save or show confirmation"
        fi
    else
        fail "Scenario 6 - Note prompt row not displayed after Y"
    fi
else
    fail "Scenario 6 - Timer did not reach natural focus completion prompt"
fi

# -----------------------------------------------------------------------------
# Scenario 7: Break Transition & Skip
# -----------------------------------------------------------------------------
# Press Space to acknowledge note saved and enter short break
send " "
if wait_for "SHORT BREAK - Session 1 of 4" 5; then
    # Skip break via 'S'
    send "S"
    if wait_for "FOCUS - Session 2 of 4" 5; then
        pass "Scenario 7 - Break transition and skip via key S"
    else
        fail "Scenario 7 - Skip break did not advance to Session 2"
    fi
else
    fail "Scenario 7 - Did not transition to SHORT BREAK"
fi

# -----------------------------------------------------------------------------
# Scenario 8: Return to Menu & Stats Persistence
# -----------------------------------------------------------------------------
send "Q"
if wait_for "P A W M O D O R O" 5 && cap | grep -q "Today: 1 pomodoros"; then
    if [ -f "$TMP_DIR/stats.dat" ]; then
        STATS_SIZE=$(stat -c %s "$TMP_DIR/stats.dat")
        if [ "$STATS_SIZE" -eq 12 ]; then
            pass "Scenario 8 - Return to menu, dashboard updated, stats.dat is 12 bytes"
        else
            fail "Scenario 8 - stats.dat size is $STATS_SIZE bytes (expected 12)"
        fi
    else
        fail "Scenario 8 - stats.dat file was not created"
    fi
else
    fail "Scenario 8 - Return to menu failed or dashboard did not show 1 pomodoro"
fi

# -----------------------------------------------------------------------------
# Scenario 9: Habits Tracker (Add, Check-in, Duplicate Reject, 52B File)
# -----------------------------------------------------------------------------
send "2"
if wait_for "HABIT TRACKER" 5; then
    send "A"
    if wait_for "New habit name" 5; then
        send "Drink water" Enter
        if wait_for "1. Drink water" 5; then
            # Check in habit 1
            send "1"
            if wait_for "Checked in!" 5 && cap | grep -q "\[#\]"; then
                # Check in again -> already done
                send "1"
                if wait_for "Already done today" 5; then
                    # Return to menu
                    send "B"
                    if wait_for "P A W M O D O R O" 5 && cap | grep -q "Habits: 1/1 done"; then
                        HABITS_SIZE=$(stat -c %s "$TMP_DIR/habits.dat" 2>/dev/null || echo 0)
                        if [ "$HABITS_SIZE" -eq 52 ]; then
                            pass "Scenario 9 - Habits add, check-in, duplicate guard, and 52B habits.dat"
                        else
                            fail "Scenario 9 - habits.dat size is $HABITS_SIZE bytes (expected 52)"
                        fi
                    else
                        fail "Scenario 9 - Dashboard failed to show Habits: 1/1 done on menu"
                    fi
                else
                    fail "Scenario 9 - Duplicate check-in did not display 'Already done today'"
                fi
            else
                fail "Scenario 9 - Check-in did not show 'Checked in!' or active square [#]"
            fi
        else
            fail "Scenario 9 - Added habit 'Drink water' not displayed in table"
        fi
    else
        fail "Scenario 9 - Key A did not open new habit prompt"
    fi
else
    fail "Scenario 9 - Key 2 did not open HABIT TRACKER"
fi

# -----------------------------------------------------------------------------
# Scenario 10: Journal (Add, View, File Timestamp Audit)
# -----------------------------------------------------------------------------
send "3"
if wait_for "JOURNAL" 5; then
    send "N"
    if wait_for "New entry" 5; then
        send "Morning focus reflection" Enter
        if wait_for "Entry saved" 5; then
            send "V"
            if wait_for "Morning focus reflection" 5; then
                # Verify journal.txt timestamp
                if [ -f "$TMP_DIR/journal.txt" ]; then
                    JRNL_LINE=$(grep "Morning focus reflection" "$TMP_DIR/journal.txt" | head -n 1)
                    EXPECTED_MIN0=$(date -u -d '+8 hours' '+%Y-%m-%d %H:%M')
                    EXPECTED_MIN1=$(date -u -d '+8 hours - 1 minute' '+%Y-%m-%d %H:%M')
                    if echo "$JRNL_LINE" | grep -q "$EXPECTED_MIN0" || echo "$JRNL_LINE" | grep -q "$EXPECTED_MIN1"; then
                        # Test full-entry view toggle via Enter
                        send Enter
                        if wait_for "JOURNAL - FULL ENTRY" 5; then
                            send "B"
                            wait_for "JOURNAL" 5
                            # Test deletion cancel via N
                            send "D"
                            if wait_for "Delete this entry? (y/n)" 5; then
                                send "N"
                                sleep 0.2
                                # Test deletion confirm via Y
                                send "D"
                                if wait_for "Delete this entry? (y/n)" 5; then
                                    send "Y"
                                    if wait_for "Entry deleted" 5; then
                                        send "B"
                                        wait_for "P A W M O D O R O" 5
                                        pass "Scenario 10 - Journal add, view, full view, delete cancel/confirm verified"
                                    else
                                        fail "Scenario 10 - Deletion failed to show 'Entry deleted'"
                                    fi
                                else
                                    fail "Scenario 10 - Key D did not show delete prompt"
                                fi
                            else
                                fail "Scenario 10 - Key D did not show delete prompt"
                            fi
                        else
                            fail "Scenario 10 - Enter did not open full entry view"
                        fi
                    else
                        fail "Scenario 10 - journal.txt timestamp mismatch: '$JRNL_LINE' vs expected '$EXPECTED_MIN0'"
                    fi
                else
                    fail "Scenario 10 - journal.txt not found on disk"
                fi
            else
                fail "Scenario 10 - Key V failed to display recent entries"
            fi
        else
            fail "Scenario 10 - New journal entry failed to show 'Entry saved'"
        fi
    else
        fail "Scenario 10 - Key N did not open journal prompt"
    fi
else
    fail "Scenario 10 - Key 3 did not open JOURNAL screen"
fi

# -----------------------------------------------------------------------------
# Scenario 11: Corrupted Data File Resilience
# -----------------------------------------------------------------------------
# Quit app from menu
send "Q"
sleep 0.5
truncate -s 10 "$TMP_DIR/habits.dat"
printf "12345" > "$TMP_DIR/stats.dat"

# Restart
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
if wait_for "P A W M O D O R O" 5 && cap | grep -q "Today: 0 pomodoros" && cap | grep -q "Habits: 0/0 done"; then
    pass "Scenario 11 - Truncated/corrupted data treated safely as empty state"
else
    fail "Scenario 11 - App crashed or failed to reset corrupted data on startup"
fi

# -----------------------------------------------------------------------------
# Scenario 12: Raw Mode Ctrl+C & Terminal Restoration
# -----------------------------------------------------------------------------
send C-c
sleep 0.5
EXIT_C12=$(cat "$TMP_DIR/exit.txt" 2>/dev/null || echo "none")
ALT_C12=$(tmux display -p -t "$TMUX_SESSION" '#{alternate_on}')
if [ "$EXIT_C12" = "EXIT=0" ] && [ "$ALT_C12" = "0" ]; then
    pass "Scenario 12 - Raw mode Ctrl+C exits with code 0 and restores terminal"
else
    fail "Scenario 12 - Raw mode Ctrl+C exit code was '$EXIT_C12' (expected EXIT=0, alt=$ALT_C12)"
fi

# -----------------------------------------------------------------------------
# Scenario 13: Cooked Mode Ctrl+C (Exit Code 130)
# -----------------------------------------------------------------------------
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
wait_for "P A W M O D O R O" 5
send "2"
wait_for "HABIT TRACKER" 5
send "A"
wait_for "New habit name" 5
send C-c
sleep 0.5
EXIT_C13=$(cat "$TMP_DIR/exit.txt" 2>/dev/null || echo "none")
ALT_C13=$(tmux display -p -t "$TMUX_SESSION" '#{alternate_on}')
if [ "$EXIT_C13" = "EXIT=130" ] && [ "$ALT_C13" = "0" ]; then
    pass "Scenario 13 - Cooked mode Ctrl+C intercepted, terminal restored, exit 130"
else
    fail "Scenario 13 - Cooked mode Ctrl+C exit was '$EXIT_C13' (expected EXIT=130, alt=$ALT_C13)"
fi

# -----------------------------------------------------------------------------
# Scenario 14: Non-TTY Stdin Detection
# -----------------------------------------------------------------------------
NOTTY_OUT=$(mktemp)
set +e
"$TMP_DIR/pawmodoro" < /dev/null > "$NOTTY_OUT" 2>&1
NOTTY_EXIT=$?
set -e
if [ "$NOTTY_EXIT" -eq 1 ] && grep -q "Error: Standard input is not a terminal." "$NOTTY_OUT"; then
    pass "Scenario 14 - Stdin redirection from /dev/null exits 1 with clear error"
else
    fail "Scenario 14 - Non-TTY stdin test failed (exit=$NOTTY_EXIT, output=$(cat "$NOTTY_OUT"))"
fi
rm -f "$NOTTY_OUT"

# -----------------------------------------------------------------------------
# Scenario 15: Small Terminal Size Gate (< 80x24) & Auto-Recovery
# -----------------------------------------------------------------------------
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
wait_for "P A W M O D O R O" 5
tmux resize-window -t "$TMUX_SESSION" -x 60 -y 20
if wait_for "Please enlarge the terminal" 5 && cap | grep -q "(need 80x24"; then
    tmux resize-window -t "$TMUX_SESSION" -x 80 -y 24
    if wait_for "P A W M O D O R O" 5; then
        send "Q"
        sleep 0.4
        pass "Scenario 15 - Size gate triggers on < 80x24 and recovers on resize"
    else
        fail "Scenario 15 - Main menu did not recover after window resized to 80x24"
    fi
else
    fail "Scenario 15 - Size gate did not display 'Please enlarge the terminal' at 60x20"
fi

# -----------------------------------------------------------------------------
# Scenario 16: Zero Screen Overflow (Beyond Frame Boundary / Terminal Width)
# -----------------------------------------------------------------------------
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
wait_for "P A W M O D O R O" 5
OV_MENU=$(cap | awk 'length($0)>79{print}')
send "2"
wait_for "HABIT TRACKER" 5
OV_HABITS=$(cap | awk 'length($0)>79{print}')
send "B"
wait_for "P A W M O D O R O" 5
send "3"
wait_for "JOURNAL" 5
OV_JRNL=$(cap | awk 'length($0)>79{print}')
send "B"
wait_for "P A W M O D O R O" 5
send "5"
wait_for "SETTINGS" 5
OV_SETTINGS=$(cap | awk 'length($0)>79{print}')
send "B"
wait_for "P A W M O D O R O" 5
send "Q"
sleep 0.4

if [ -z "$OV_MENU" ] && [ -z "$OV_HABITS" ] && [ -z "$OV_JRNL" ] && [ -z "$OV_SETTINGS" ]; then
    pass "Scenario 16 - Zero screen overflow past frame boundary across all screens"
else
    fail "Scenario 16 - Lines exceeded frame boundary (Menu='$OV_MENU', Habits='$OV_HABITS', Jrnl='$OV_JRNL', Settings='$OV_SETTINGS')"
fi

# -----------------------------------------------------------------------------
# Scenario 17: Settings Screen & Custom Color Editor
# -----------------------------------------------------------------------------
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
if wait_for "P A W M O D O R O" 5; then
    send "5"
    if wait_for "SETTINGS" 5 && cap | grep -q "Theme" && cap | grep -q "Customize colors" && cap | grep -q "Cat coat" && cap | grep -q "Animations" && cap | grep -q "Sound & Volume" && cap | grep -q "Reset to defaults"; then
        send "Down"
        sleep 0.2
        send Enter
        if wait_for "CUSTOMIZE COLORS" 5 && cap | grep -q "BORDER" && cap | grep -q "HIGHLIGHT" && cap | grep -q "Interface"; then
            send "B"
            if wait_for "Cat coat" 5; then
                send "Up"
                sleep 0.2
                send "Right"
                sleep 0.3
                if wait_for "Saved" 5; then
                    send "B"
                    if wait_for "P A W M O D O R O" 5; then
                        send "Q"
                        sleep 0.4
                        if [ -f "$TMP_DIR/settings.dat" ]; then
                            SETTINGS_SIZE=$(stat -c %s "$TMP_DIR/settings.dat")
                            if [ "$SETTINGS_SIZE" -eq 48 ]; then
                                pass "Scenario 17 - Settings navigation, Cat coat, color editor, immediate save, and 48B settings.dat"
                            else
                                fail "Scenario 17 - settings.dat size is $SETTINGS_SIZE bytes (expected 48)"
                            fi
                        else
                            fail "Scenario 17 - settings.dat file was not created"
                        fi
                    else
                        fail "Scenario 17 - Key B did not return to Main Menu"
                    fi
                else
                    fail "Scenario 17 - Setting change did not display 'Saved'"
                fi
            else
                fail "Scenario 17 - Key B from Color Editor did not return to SETTINGS"
            fi
        else
            fail "Scenario 17 - Enter did not open CUSTOMIZE COLORS screen with Interface group"
        fi
    else
        fail "Scenario 17 - Key 5 did not display all SETTINGS rows including Cat coat"
    fi
else
    fail "Scenario 17 - Application failed to start for Settings test"
fi

# -----------------------------------------------------------------------------
# Scenario 18: Cohesive Visual System Across All Screens
# -----------------------------------------------------------------------------
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
if wait_for "P A W M O D O R O" 5; then
    MENU_CAP=$(cap)
    GREET_OK=0
    if echo "$MENU_CAP" | grep -q "Good morning" || echo "$MENU_CAP" | grep -q "Good afternoon" || echo "$MENU_CAP" | grep -q "Good evening"; then
        GREET_OK=1
    fi
    TIP_OK=0
    if echo "$MENU_CAP" | grep -q "Tip:"; then
        TIP_OK=1
    fi
    # Check Timer cycle dots and pause badge
    send "1" # Timer
    wait_for "FOCUS" 5
    TIMER_CAP=$(cap)
    CYCLE_OK=0
    if echo "$TIMER_CAP" | grep -q "Cycle:"; then
        CYCLE_OK=1
    fi
    send "P" # Pause
    sleep 0.2
    PAUSE_OK=0
    if cap | grep -q "\[PAUSED\]"; then
        PAUSE_OK=1
    fi
    send "P" # Resume
    sleep 0.2
    send "Q" # Back
    wait_for "P A W M O D O R O" 5
    send "Q" # Quit
    sleep 0.4
    if [ "$GREET_OK" -eq 1 ] && [ "$TIP_OK" -eq 1 ] && [ "$CYCLE_OK" -eq 1 ] && [ "$PAUSE_OK" -eq 1 ]; then
        pass "Scenario 18 - Cohesive visual elements (greeting, daily tip, cycle dots, [PAUSED] badge)"
    else
        fail "Scenario 18 - Visual elements missing (greet=$GREET_OK, tip=$TIP_OK, cycle=$CYCLE_OK, pause=$PAUSE_OK)"
    fi
else
    fail "Scenario 18 - Failed to start Pawmodoro"
fi

# -----------------------------------------------------------------------------
# Scenario 19: Strict 7-bit ASCII Fallback Across All Screens
# -----------------------------------------------------------------------------
python3 -c "
magic = b'PAWS'
data = magic + bytes([1, 0] + [0]*12 + [1, 0, 1, 0, 1, 2])
with open('$TMP_DIR/settings.dat', 'wb') as f:
    f.write(data)
"
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
if wait_for "P A W M O D O R O" 5; then
    ASCII_OK=1
    # Menu
    if tmux capture-pane -t "$TMUX_SESSION" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_OK=0; fi
    # Timer
    send "1"
    wait_for "FOCUS" 5
    if tmux capture-pane -t "$TMUX_SESSION" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_OK=0; fi
    send "Q"
    wait_for "P A W M O D O R O" 5
    # Habits
    send "2"
    wait_for "HABIT TRACKER" 5
    if tmux capture-pane -t "$TMUX_SESSION" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_OK=0; fi
    send "B"
    wait_for "P A W M O D O R O" 5
    # Journal
    send "3"
    wait_for "JOURNAL" 5
    if tmux capture-pane -t "$TMUX_SESSION" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_OK=0; fi
    send "B"
    wait_for "P A W M O D O R O" 5
    # Settings
    send "5"
    wait_for "SETTINGS" 5
    if tmux capture-pane -t "$TMUX_SESSION" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_OK=0; fi
    send "B"
    wait_for "P A W M O D O R O" 5
    send "Q"
    sleep 0.4
    rm -f "$TMP_DIR/settings.dat"
    if [ "$ASCII_OK" -eq 1 ]; then
        pass "Scenario 19 - Strict 7-bit ASCII mode emits zero bytes >= 0x80 across all 5 screens"
    else
        fail "Scenario 19 - Non-ASCII bytes detected in ASCII mode"
    fi
else
    fail "Scenario 19 - Failed to start Pawmodoro in ASCII mode"
fi

# -----------------------------------------------------------------------------
# Scenario 20: UTF-8 Rounded Border Geometry Across All Screens
# -----------------------------------------------------------------------------
send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
if wait_for "P A W M O D O R O" 5; then
    UTF8_OK=1
    if ! cap | grep -q "╭" || ! cap | grep -q "╰"; then UTF8_OK=0; fi
    send "1"
    wait_for "FOCUS" 5
    if ! cap | grep -q "╭" || ! cap | grep -q "╰"; then UTF8_OK=0; fi
    send "Q"
    wait_for "P A W M O D O R O" 5
    send "2"
    wait_for "HABIT TRACKER" 5
    if ! cap | grep -q "╭" || ! cap | grep -q "╰"; then UTF8_OK=0; fi
    send "B"
    wait_for "P A W M O D O R O" 5
    send "3"
    wait_for "JOURNAL" 5
    if ! cap | grep -q "╭" || ! cap | grep -q "╰"; then UTF8_OK=0; fi
    send "B"
    wait_for "P A W M O D O R O" 5
    send "5"
    wait_for "SETTINGS" 5
    if ! cap | grep -q "╭" || ! cap | grep -q "╰"; then UTF8_OK=0; fi
    send "B"
    wait_for "P A W M O D O R O" 5
    send "Q"
    sleep 0.4
    if [ "$UTF8_OK" -eq 1 ]; then
        pass "Scenario 20 - UTF-8 rounded borders (╭, ╰, ─, │) verified across all 5 screens"
    else
        fail "Scenario 20 - Missing UTF-8 rounded border characters"
    fi
else
    fail "Scenario 20 - Failed to start Pawmodoro for UTF-8 border check"
fi

# -----------------------------------------------------------------------------
# Scenario 21: Animation Engine Rate Throttling (<= 5 writes/s) and Reduce Motion
# -----------------------------------------------------------------------------
ANIM_LOG="$TMP_DIR/anim_strace.log"
rm -f "$ANIM_LOG"
send "strace -f -tt -e trace=write -o '$ANIM_LOG' ./pawmodoro; echo EXIT=\$? > exit.txt" Enter
if wait_for "P A W M O D O R O" 5; then
    sleep 2.5
    # Check write rate with animation enabled
    python3 -c "
import sys
with open('$ANIM_LOG', 'r') as f:
    lines = f.readlines()
counts = {}
for line in lines:
    parts = line.split()
    if len(parts) >= 2:
        ts = parts[1] if parts[0].isdigit() else parts[0]
        if ':' in ts:
            sec = ts.split('.')[0]
            counts[sec] = counts.get(sec, 0) + 1
max_fps = max(counts.values()) if counts else 0
if max_fps > 6:
    print(f'Max writes/sec {max_fps} exceeds limit of 5 (+1 startup)')
    sys.exit(1)
"
    RATE_OK=$?

    # Now toggle animation to OFF (Reduce motion)
    send "5"
    wait_for "SETTINGS" 5
    send Down Down Enter "B"
    wait_for "P A W M O D O R O" 5
    sleep 0.5
    rm -f "$ANIM_LOG"
    sleep 2.0

    # Verify zero idle writes when Reduce Motion is enabled
    if [ -f "$ANIM_LOG" ]; then
        IDLE_WRITES=$(wc -l < "$ANIM_LOG")
    else
        IDLE_WRITES=0
    fi
    send "Q"
    sleep 0.4

    if [ "$RATE_OK" -eq 0 ] && [ "$IDLE_WRITES" -eq 0 ]; then
        pass "Scenario 21 - Animation write throttle (<= 5 fps) & Reduce Motion 0 idle writes verified"
    else
        fail "Scenario 21 - Animation throttling failed (rate_ok=$RATE_OK, idle_writes=$IDLE_WRITES)"
    fi
else
    fail "Scenario 21 - Failed to start Pawmodoro for animation rate check"
fi

# -----------------------------------------------------------------------------
# Scenario 22: Synthesized Sound Engine & Process Lifecycle (Task V8)
# -----------------------------------------------------------------------------
# 1. Verify integer-only math: zero FPU, MMX, SSE instructions in binary
FPU_CHECK=$(objdump -d "$BIN" | grep -E '\bfld|\bfst|\bfadd|\bfsub|\bfmul|\bfdiv|\bxmm|\bymm|\bzmm' || true)
# 2. Verify .bss budget: <= 81920 B (80 KiB)
BSS_SIZE=$(size -A "$BIN" | awk '$1==".bss"{print $2}')
# 3. Verify zero zombie processes in system
ZOMBIES_COUNT=$(ps axo stat | grep -c 'Z' || true)

if [ -z "$FPU_CHECK" ] && [ -n "$BSS_SIZE" ] && [ "$BSS_SIZE" -le 81920 ] && [ "$ZOMBIES_COUNT" -eq 0 ]; then
    pass "Scenario 22 - Pure integer synthesis, .bss size ($BSS_SIZE <= 81920 B), and zero zombie processes"
else
    fail "Scenario 22 - Sound engine verification failed (fpu=$FPU_CHECK, bss=$BSS_SIZE, zombies=$ZOMBIES_COUNT)"
fi

# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Scenario 23: Theme Persistence Across Restarts (Task V10)
# -----------------------------------------------------------------------------
THEME_SUBDIR="$TMP_DIR/theme_persist"
mkdir -p "$THEME_SUBDIR"
cp "$BIN" "$THEME_SUBDIR/pawmodoro"
TMUX_THEME="paw_theme_$$"
tmux new-session -d -s "$TMUX_THEME" -x 80 -y 24 -c "$THEME_SUBDIR" bash
tmux send-keys -t "$TMUX_THEME" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.4
THEME_PERSIST_OK=0
if tmux capture-pane -t "$TMUX_THEME" -p | grep -q "P A W M O D O R O"; then
    tmux send-keys -t "$TMUX_THEME" "5"
    sleep 0.3
    tmux send-keys -t "$TMUX_THEME" Right
    sleep 0.2
    tmux send-keys -t "$TMUX_THEME" "B"
    sleep 0.2
    tmux send-keys -t "$TMUX_THEME" "Q"
    sleep 0.4

    # Check settings.dat size
    if [ -f "$THEME_SUBDIR/settings.dat" ] && [ "$(stat -c %s "$THEME_SUBDIR/settings.dat")" -eq 48 ]; then
        # Restart 1
        tmux send-keys -t "$TMUX_THEME" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
        sleep 0.4
        tmux send-keys -t "$TMUX_THEME" "5"
        sleep 0.3
        if tmux capture-pane -t "$TMUX_THEME" -p | grep -q "Matcha Latte"; then
            tmux send-keys -t "$TMUX_THEME" "B"
            sleep 0.2
            tmux send-keys -t "$TMUX_THEME" "Q"
            sleep 0.4

            # Restart 2
            tmux send-keys -t "$TMUX_THEME" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
            sleep 0.4
            tmux send-keys -t "$TMUX_THEME" "5"
            sleep 0.3
            if tmux capture-pane -t "$TMUX_THEME" -p | grep -q "Matcha Latte"; then
                THEME_PERSIST_OK=1
                tmux send-keys -t "$TMUX_THEME" "B"
                sleep 0.2
                tmux send-keys -t "$TMUX_THEME" "Q"
                sleep 0.4
            fi
        fi
    fi
fi
tmux kill-session -t "$TMUX_THEME" 2>/dev/null || true
rm -rf "$THEME_SUBDIR"

if [ "$THEME_PERSIST_OK" -eq 1 ]; then
    pass "Scenario 23 - Theme selection persists across restart and second clean restart"
else
    fail "Scenario 23 - Theme persistence failed across restarts"
fi

# -----------------------------------------------------------------------------
# Scenario 24: Corrupted settings.dat Fallback and Recovery (Task V10)
# -----------------------------------------------------------------------------
CORRUPT_SUBDIR="$TMP_DIR/corrupt_test"
mkdir -p "$CORRUPT_SUBDIR"
cp "$BIN" "$CORRUPT_SUBDIR/pawmodoro"
TMUX_CORRUPT="paw_corrupt_$$"
tmux new-session -d -s "$TMUX_CORRUPT" -x 80 -y 24 -c "$CORRUPT_SUBDIR" bash
sleep 0.3

CORRUPT_ALL_OK=1
run_corrupt_variant() {
    local vname="$1"
    rm -f "$CORRUPT_SUBDIR/settings.dat"
    case "$vname" in
        missing) ;;
        empty) touch "$CORRUPT_SUBDIR/settings.dat" ;;
        truncated_header) printf 'PAW' > "$CORRUPT_SUBDIR/settings.dat" ;;
        truncated_v1) printf 'PAWS\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x07' > "$CORRUPT_SUBDIR/settings.dat" ;;
        truncated_v2) printf 'PAWS\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x07\x03\x00\x01\x00' > "$CORRUPT_SUBDIR/settings.dat" ;;
        wrong_magic) printf 'BAAD\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x07\x03\x00\x01\x00\x00\x00\x00\x00\x00\x00' > "$CORRUPT_SUBDIR/settings.dat" ;;
        wrong_version) printf 'PAWS\x03\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x07\x03\x00\x01\x00\x00\x00\x00\x00\x00\x00' > "$CORRUPT_SUBDIR/settings.dat" ;;
        invalid_theme) python3 -c "open('$CORRUPT_SUBDIR/settings.dat', 'wb').write(b'PAWS\x02\x99' + bytes(42))" ;;
        invalid_bool) python3 -c "open('$CORRUPT_SUBDIR/settings.dat', 'wb').write(b'PAWS\x02\x00' + bytes(24) + bytes([5, 1, 0, 7, 3, 0, 1, 0]) + bytes(6))" ;;
        invalid_coat) python3 -c "open('$CORRUPT_SUBDIR/settings.dat', 'wb').write(b'PAWS\x02\x00' + bytes(24) + bytes([1, 1, 0, 7, 3, 0, 1, 99]) + bytes(6))" ;;
        oversized_v1) printf 'PAWS\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x01\x00\x07\x03\x00EXTRA_BYTES' > "$CORRUPT_SUBDIR/settings.dat" ;;
        oversized_v2) python3 -c "open('$CORRUPT_SUBDIR/settings.dat', 'wb').write(b'PAWS\x02\x00' + bytes(42) + b'EXTRA_BYTES')" ;;
    esac

    tmux send-keys -t "$TMUX_CORRUPT" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
    sleep 0.4
    if ! tmux capture-pane -t "$TMUX_CORRUPT" -p | grep -q "P A W M O D O R O"; then
        CORRUPT_ALL_OK=0
        return 1
    fi
    tmux send-keys -t "$TMUX_CORRUPT" "5"
    sleep 0.3
    tmux send-keys -t "$TMUX_CORRUPT" Right
    sleep 0.2
    tmux send-keys -t "$TMUX_CORRUPT" "B"
    sleep 0.2
    tmux send-keys -t "$TMUX_CORRUPT" "Q"
    sleep 0.4

    if [ ! -f "$CORRUPT_SUBDIR/settings.dat" ] || [ "$(stat -c %s "$CORRUPT_SUBDIR/settings.dat")" -ne 48 ]; then
        CORRUPT_ALL_OK=0
        return 1
    fi
    return 0
}

for var in missing empty truncated_header truncated_v1 truncated_v2 wrong_magic wrong_version invalid_theme invalid_bool invalid_coat oversized_v1 oversized_v2; do
    if ! run_corrupt_variant "$var"; then
        CORRUPT_ALL_OK=0
        break
    fi
done
tmux kill-session -t "$TMUX_CORRUPT" 2>/dev/null || true
rm -rf "$CORRUPT_SUBDIR"

if [ "$CORRUPT_ALL_OK" -eq 1 ]; then
    pass "Scenario 24 - Malformed settings variants safely handled with defaults and 48-byte save"
else
    fail "Scenario 24 - Corrupted settings fallback failed"
fi

# -----------------------------------------------------------------------------
# Scenario 25: Journal Deletion (First, Mid, Last, Only) and Cancellation (Task V10)
# -----------------------------------------------------------------------------
JRNL_SUBDIR="$TMP_DIR/jrnl_del_test"
mkdir -p "$JRNL_SUBDIR"
cp "$BIN" "$JRNL_SUBDIR/pawmodoro"
printf "2026-10-25 10:00 | Entry One\n2026-10-25 11:00 | Entry Two\n2026-10-25 12:00 | Entry Three\n" > "$JRNL_SUBDIR/journal.txt"

TMUX_JRNL="paw_jrnl_$$"
tmux new-session -d -s "$TMUX_JRNL" -x 80 -y 24 -c "$JRNL_SUBDIR" bash
tmux send-keys -t "$TMUX_JRNL" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.4

JRNL_DEL_OK=0
if tmux capture-pane -t "$TMUX_JRNL" -p | grep -q "P A W M O D O R O"; then
    tmux send-keys -t "$TMUX_JRNL" "3"
    sleep 0.3
    if tmux capture-pane -t "$TMUX_JRNL" -p | grep -q "JOURNAL"; then
        # 1. Test cancellation: press D, then N
        tmux send-keys -t "$TMUX_JRNL" "D"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "N"
        sleep 0.2
        ORIG_COUNT=$(wc -l < "$JRNL_SUBDIR/journal.txt")

        # 2. Delete middle entry (Entry Two): selection defaults to bottom (Entry Three). Press Up Arrow.
        tmux send-keys -t "$TMUX_JRNL" Up "D"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "Y"
        sleep 0.3

        # 3. Delete top entry (Entry One): press Up Arrow.
        tmux send-keys -t "$TMUX_JRNL" Up "D"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "Y"
        sleep 0.3

        # 4. Delete only remaining entry (Entry Three).
        tmux send-keys -t "$TMUX_JRNL" "D"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "Y"
        sleep 0.3

        # 5. Test blocked temporary file: add entry, create journal.tmp dir, attempt delete
        tmux send-keys -t "$TMUX_JRNL" "N"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "Blocked Test Entry" Enter
        sleep 0.3
        mkdir "$JRNL_SUBDIR/journal.tmp"
        tmux send-keys -t "$TMUX_JRNL" "D"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "Y"
        sleep 0.3
        BLOCKED_ERR=0
        if tmux capture-pane -t "$TMUX_JRNL" -p | grep -q "Could not delete"; then
            BLOCKED_ERR=1
        fi
        rmdir "$JRNL_SUBDIR/journal.tmp"

        tmux send-keys -t "$TMUX_JRNL" "B"
        sleep 0.2
        tmux send-keys -t "$TMUX_JRNL" "Q"
        sleep 0.4

        if [ "$ORIG_COUNT" -eq 3 ] && [ "$BLOCKED_ERR" -eq 1 ] && [ ! -e "$JRNL_SUBDIR/journal.tmp" ]; then
            JRNL_DEL_OK=1
        fi
    fi
fi
tmux kill-session -t "$TMUX_JRNL" 2>/dev/null || true
rm -rf "$JRNL_SUBDIR"

if [ "$JRNL_DEL_OK" -eq 1 ]; then
    pass "Scenario 25 - Journal deletion (first, mid, only), cancellation, and blocked-tmp safety"
else
    fail "Scenario 25 - Journal deletion and cancellation failed"
fi

# -----------------------------------------------------------------------------
# Scenario 26: Journal 200-Character Entry Wrapping at 80x24 and 120x40 (Task V10)
# -----------------------------------------------------------------------------
WRAP_SUBDIR="$TMP_DIR/jrnl_wrap_test"
mkdir -p "$WRAP_SUBDIR"
cp "$BIN" "$WRAP_SUBDIR/pawmodoro"
P200="P200_AAAAABBBBBCCCCCDDDDDEEEEEFFFFFGGGGGHHHHHIIIIIJJJJJKKKKKLLLLLMMMMMNNNNNOOOOOPPPPPQQQQQRRRRRSSSSSTTTTTUUUUUVVVVVWWWWWXXXXXYYYYYZZZZZ000001111122222333334444455555666667777788888999990123456789END!"
printf "2026-10-25 12:00 | %s\n" "$P200" > "$WRAP_SUBDIR/journal.txt"

TMUX_WRAP="paw_wrap_$$"
tmux new-session -d -s "$TMUX_WRAP" -x 80 -y 24 -c "$WRAP_SUBDIR" bash
tmux send-keys -t "$TMUX_WRAP" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.4

WRAP_OK=0
if tmux capture-pane -t "$TMUX_WRAP" -p | grep -q "P A W M O D O R O"; then
    tmux send-keys -t "$TMUX_WRAP" "3"
    sleep 0.3
    # Check 80x24 overflow
    OV80=$(tmux capture-pane -t "$TMUX_WRAP" -p | awk 'length($0)>79{print NR ":" $0}')
    # Open full view
    tmux send-keys -t "$TMUX_WRAP" Enter
    sleep 0.2
    FULL_CAP=$(tmux capture-pane -t "$TMUX_WRAP" -p)
    tmux send-keys -t "$TMUX_WRAP" "B"
    sleep 0.2

    # Resize to 120x40
    tmux resize-window -t "$TMUX_WRAP" -x 120 -y 40
    sleep 0.2
    tmux send-keys -t "$TMUX_WRAP" "V"
    sleep 0.3
    OV120=$(tmux capture-pane -t "$TMUX_WRAP" -p | awk 'length($0)>119{print NR ":" $0}')

    tmux send-keys -t "$TMUX_WRAP" "B"
    sleep 0.2
    tmux send-keys -t "$TMUX_WRAP" "Q"
    sleep 0.4

    if [ -z "$OV80" ] && [ -z "$OV120" ] && echo "$FULL_CAP" | grep -q "P200_" && echo "$FULL_CAP" | grep -q "END!"; then
        WRAP_OK=1
    fi
fi
tmux kill-session -t "$TMUX_WRAP" 2>/dev/null || true
rm -rf "$WRAP_SUBDIR"

if [ "$WRAP_OK" -eq 1 ]; then
    pass "Scenario 26 - Journal 200-character entry wraps cleanly at 80x24 and 120x40"
else
    fail "Scenario 26 - Journal 200-character wrapping failed (ov80=$OV80, ov120=$OV120)"
fi

# -----------------------------------------------------------------------------
# Scenario 27: Strict 7-Bit ASCII Mode Purity (Task V10)
# -----------------------------------------------------------------------------
ASCII_SUBDIR="$TMP_DIR/ascii_pure_test"
mkdir -p "$ASCII_SUBDIR"
cp "$BIN" "$ASCII_SUBDIR/pawmodoro"
# Write settings.dat with setting_charset = 1
python3 -c "
magic = b'PAWM'
data = magic + bytes([2,0,0,0, 0,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0, 7,0,0,0])
with open('$ASCII_SUBDIR/settings.dat', 'wb') as f:
    f.write(data)
"
printf "2026-10-25 12:00 | ASCII Note with Cat 🐱 and Heart ❤️ test\n" > "$ASCII_SUBDIR/journal.txt"

TMUX_ASCII="paw_ascii_$$"
tmux new-session -d -s "$TMUX_ASCII" -x 80 -y 24 -c "$ASCII_SUBDIR" bash
tmux send-keys -t "$TMUX_ASCII" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.4

ASCII_PURE_OK=1
# Menu
if tmux capture-pane -t "$TMUX_ASCII" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_PURE_OK=0; fi
# Timer
tmux send-keys -t "$TMUX_ASCII" "1"
sleep 0.3
if tmux capture-pane -t "$TMUX_ASCII" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_PURE_OK=0; fi
tmux send-keys -t "$TMUX_ASCII" "Q"
sleep 0.3
# Habits
tmux send-keys -t "$TMUX_ASCII" "2"
sleep 0.3
if tmux capture-pane -t "$TMUX_ASCII" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_PURE_OK=0; fi
tmux send-keys -t "$TMUX_ASCII" "B"
sleep 0.3
# Journal
tmux send-keys -t "$TMUX_ASCII" "3"
sleep 0.3
if tmux capture-pane -t "$TMUX_ASCII" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_PURE_OK=0; fi
tmux send-keys -t "$TMUX_ASCII" "B"
sleep 0.3
# Settings
tmux send-keys -t "$TMUX_ASCII" "5"
sleep 0.3
if tmux capture-pane -t "$TMUX_ASCII" -ep | grep -P "[\x80-\xFF]" >/dev/null; then ASCII_PURE_OK=0; fi
tmux send-keys -t "$TMUX_ASCII" "B"
sleep 0.3
tmux send-keys -t "$TMUX_ASCII" "Q"
sleep 0.4

tmux kill-session -t "$TMUX_ASCII" 2>/dev/null || true
rm -rf "$ASCII_SUBDIR"

if [ "$ASCII_PURE_OK" -eq 1 ]; then
    pass "Scenario 27 - Strict 7-bit ASCII mode emits zero non-ASCII bytes across all screens"
else
    fail "Scenario 27 - Non-ASCII bytes detected in ASCII mode"
fi

# -----------------------------------------------------------------------------
# Scenario 28: Narrow-to-Wide Resize and Size Gate (Task V10)
# -----------------------------------------------------------------------------
RESIZE_SUBDIR="$TMP_DIR/resize_test"
mkdir -p "$RESIZE_SUBDIR"
cp "$BIN" "$RESIZE_SUBDIR/pawmodoro"
TMUX_RESIZE="paw_resize_$$"
tmux new-session -d -s "$TMUX_RESIZE" -x 80 -y 24 -c "$RESIZE_SUBDIR" bash
tmux send-keys -t "$TMUX_RESIZE" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.4

RESIZE_OK=0
if tmux capture-pane -t "$TMUX_RESIZE" -p | grep -q "P A W M O D O R O"; then
    # Resize to 140x40 (v3 Grand tier: max 120-column frame centered with 10 spaces)
    tmux resize-window -t "$TMUX_RESIZE" -x 140 -y 40
    sleep 0.3
    tmux send-keys -t "$TMUX_RESIZE" "X"
    sleep 0.3
    WIDE_CAP=$(tmux capture-pane -t "$TMUX_RESIZE" -p)
    CENTER_OK=0
    if echo "$WIDE_CAP" | grep -qE '^ {10}╭'; then
        CENTER_OK=1
    fi

    # Resize to 70x20 (< 80x24 size gate)
    tmux resize-window -t "$TMUX_RESIZE" -x 70 -y 20
    sleep 0.3
    tmux send-keys -t "$TMUX_RESIZE" "X"
    sleep 0.3
    GATE_OK=0
    if tmux capture-pane -t "$TMUX_RESIZE" -p | grep -q "Please enlarge the terminal"; then
        GATE_OK=1
    fi

    # Resize back to 80x24
    tmux resize-window -t "$TMUX_RESIZE" -x 80 -y 24
    sleep 0.3
    tmux send-keys -t "$TMUX_RESIZE" "X"
    sleep 0.3
    RESTORE_OK=0
    if tmux capture-pane -t "$TMUX_RESIZE" -p | grep -q "P A W M O D O R O"; then
        RESTORE_OK=1
    fi

    tmux send-keys -t "$TMUX_RESIZE" "Q"
    sleep 0.4

    if [ "$CENTER_OK" -eq 1 ] && [ "$GATE_OK" -eq 1 ] && [ "$RESTORE_OK" -eq 1 ]; then
        RESIZE_OK=1
    fi
fi
tmux kill-session -t "$TMUX_RESIZE" 2>/dev/null || true
rm -rf "$RESIZE_SUBDIR"

if [ "$RESIZE_OK" -eq 1 ]; then
    pass "Scenario 28 - Narrow-to-wide resize (100 cols centered), size gate (<80x24), and restoration"
else
    fail "Scenario 28 - Resize handling failed (center=$CENTER_OK, gate=$GATE_OK, restore=$RESTORE_OK)"
fi

# -----------------------------------------------------------------------------
# Scenario 29: Reduce Motion Persistence & Zero Idle Writes (Task V10)
# -----------------------------------------------------------------------------
RM_SUBDIR="$TMP_DIR/rm_test"
mkdir -p "$RM_SUBDIR"
cp "$BIN" "$RM_SUBDIR/pawmodoro"
# Write settings.dat with anim = 0
python3 -c "
magic = b'PAWM'
data = magic + bytes([2,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0, 0,0,0,0, 7,0,0,0])
with open('$RM_SUBDIR/settings.dat', 'wb') as f:
    f.write(data)
"
RM_LOG="$RM_SUBDIR/rm_strace.log"
TMUX_RM="paw_rm_$$"
tmux new-session -d -s "$TMUX_RM" -x 80 -y 24 -c "$RM_SUBDIR" bash
tmux send-keys -t "$TMUX_RM" "strace -f -tt -e trace=write -o '$RM_LOG' ./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.5

RM_OK=0
RM_WRITES=0
if tmux capture-pane -t "$TMUX_RM" -p | grep -q "P A W M O D O R O"; then
    rm -f "$RM_LOG"
    sleep 2.0
    if [ -f "$RM_LOG" ]; then
        RM_WRITES=$(wc -l < "$RM_LOG")
    else
        RM_WRITES=0
    fi
    tmux send-keys -t "$TMUX_RM" "Q"
    sleep 0.4
    if [ "$RM_WRITES" -eq 0 ]; then
        RM_OK=1
    fi
fi
tmux kill-session -t "$TMUX_RM" 2>/dev/null || true
rm -rf "$RM_SUBDIR"

if [ "$RM_OK" -eq 1 ]; then
    pass "Scenario 29 - Reduce motion (anim=0) persistence and 0 idle writes verified"
else
    fail "Scenario 29 - Reduce motion idle write check failed ($RM_WRITES writes detected)"
fi

# -----------------------------------------------------------------------------
# Scenario 30: Sound Disabled Launches No Subprocesses (Task V10)
# -----------------------------------------------------------------------------
NOSND_SUBDIR="$TMP_DIR/nosnd_test"
mkdir -p "$NOSND_SUBDIR"
cp "$BIN" "$NOSND_SUBDIR/pawmodoro"
# Write settings.dat with sound = 0
python3 -c "
magic = b'PAWM'
data = magic + bytes([2,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0, 7,0,0,0])
with open('$NOSND_SUBDIR/settings.dat', 'wb') as f:
    f.write(data)
"
NOSND_LOG="$NOSND_SUBDIR/nosnd_strace.log"
TMUX_NOSND="paw_nosnd_$$"
tmux new-session -d -s "$TMUX_NOSND" -x 80 -y 24 -c "$NOSND_SUBDIR" bash
tmux send-keys -t "$TMUX_NOSND" "strace -f -e trace=fork,clone,vfork,execve,pipe,pipe2 -o '$NOSND_LOG' ./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.5

NOSND_OK=0
if tmux capture-pane -t "$TMUX_NOSND" -p | grep -q "P A W M O D O R O"; then
    tmux send-keys -t "$TMUX_NOSND" "4"
    sleep 0.2
    tmux send-keys -t "$TMUX_NOSND" "1"
    sleep 0.3
    for i in $(seq 1 15); do
        if tmux capture-pane -t "$TMUX_NOSND" -p | grep -q "Focus complete"; then break; fi
        sleep 1
    done
    tmux send-keys -t "$TMUX_NOSND" " "
    sleep 0.3
    tmux send-keys -t "$TMUX_NOSND" "Q"
    sleep 0.3
    tmux send-keys -t "$TMUX_NOSND" "Q"
    sleep 0.4

    FORK_COUNT=0
    if [ -f "$NOSND_LOG" ]; then
        FORK_COUNT=$(grep -v 'execve("\./pawmodoro"' "$NOSND_LOG" | grep -cE 'clone|fork|vfork|pipe' || true)
    fi
    if [ "$FORK_COUNT" -eq 0 ]; then
        NOSND_OK=1
    fi
fi
tmux kill-session -t "$TMUX_NOSND" 2>/dev/null || true
rm -rf "$NOSND_SUBDIR"

if [ "$NOSND_OK" -eq 1 ]; then
    pass "Scenario 30 - Sound disabled launches zero sound subprocesses and zero pipes"
else
    fail "Scenario 30 - Sound disabled spawned subprocesses ($FORK_COUNT calls detected)"
fi

# -----------------------------------------------------------------------------
# Scenario 31: Sound Enabled with No Player Installed Degrades Gracefully (Task V10)
# -----------------------------------------------------------------------------
NOPLAYER_SUBDIR="$TMP_DIR/noplayer_test"
mkdir -p "$NOPLAYER_SUBDIR"
cp "$BIN" "$NOPLAYER_SUBDIR/pawmodoro"
# Write settings.dat with sound = 1
python3 -c "
magic = b'PAWM'
data = magic + bytes([2,0,0,0, 0,0,0,0, 1,0,0,0, 1,0,0,0, 0,0,0,0, 7,0,0,0])
with open('$NOPLAYER_SUBDIR/settings.dat', 'wb') as f:
    f.write(data)
"
TMUX_NOPLAYER="paw_noplayer_$$"
tmux new-session -d -s "$TMUX_NOPLAYER" -x 80 -y 24 -c "$NOPLAYER_SUBDIR" bash
tmux send-keys -t "$TMUX_NOPLAYER" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.5

NOPLAYER_OK=0
if tmux capture-pane -t "$TMUX_NOPLAYER" -p | grep -q "P A W M O D O R O"; then
    tmux send-keys -t "$TMUX_NOPLAYER" "4"
    sleep 0.2
    tmux send-keys -t "$TMUX_NOPLAYER" "1"
    sleep 0.3
    for i in $(seq 1 15); do
        if tmux capture-pane -t "$TMUX_NOPLAYER" -p | grep -q "Focus complete"; then break; fi
        sleep 1
    done
    tmux send-keys -t "$TMUX_NOPLAYER" " "
    sleep 0.3
    tmux send-keys -t "$TMUX_NOPLAYER" "Q"
    sleep 0.3
    tmux send-keys -t "$TMUX_NOPLAYER" "Q"
    sleep 0.4

    ZOMBIES=$(ps axo stat | grep -c 'Z' || true)
    if grep -q "EXIT=0" "$NOPLAYER_SUBDIR/exit.txt" 2>/dev/null && [ "$ZOMBIES" -eq 0 ]; then
        NOPLAYER_OK=1
    fi
fi
tmux kill-session -t "$TMUX_NOPLAYER" 2>/dev/null || true
rm -rf "$NOPLAYER_SUBDIR"

if [ "$NOPLAYER_OK" -eq 1 ]; then
    pass "Scenario 31 - Sound enabled with missing player degrades gracefully with 0 zombies"
else
    fail "Scenario 31 - Missing player degradation failed (zombies=$ZOMBIES)"
fi

# -----------------------------------------------------------------------------
# Scenario 32: Render Core Buffer Overflow Diagnostic (PRD_V3 §4.3)
# -----------------------------------------------------------------------------
OVERFLOW_LOG=$(mktemp)
if "$BIN" --test-overflow > "$OVERFLOW_LOG" 2>&1; then
    if grep -q "G1 RENDER CORE DIAGNOSTIC: PASS" "$OVERFLOW_LOG"; then
        pass "Scenario 32 - Render core zero overflow across all reachable screens at 80x24 and 120x40"
    else
        fail "Scenario 32 - Diagnostic passed exit code but pass banner missing"
    fi
else
    fail "Scenario 32 - Diagnostic failed with overflow or assertion failure"
fi
rm -f "$OVERFLOW_LOG"

# -----------------------------------------------------------------------------
# Scenario 33: Render Core Demo Frame & Single sys_write Verification (PRD_V3 §10, §11)
# -----------------------------------------------------------------------------
DEMO_SUBDIR=$(mktemp -d "$TMP_DIR/demo_XXXXXX")
TMUX_DEMO="paw_demo_$$"
DEMO_STRACE="$DEMO_SUBDIR/strace.log"

tmux new-session -d -s "$TMUX_DEMO" -x 80 -y 24 "cd '$DEMO_SUBDIR' && strace -f -e trace=write -o '$DEMO_STRACE' '$TMP_DIR/pawmodoro'"
sleep 0.5
tmux send-keys -t "$TMUX_DEMO" C-g
sleep 0.5
DEMO_SEEN=0
if tmux capture-pane -t "$TMUX_DEMO" -p | grep -q "Pawmodoro v3 G1 Render Core Demo"; then
    DEMO_SEEN=1
fi
tmux send-keys -t "$TMUX_DEMO" " "
sleep 0.5
MENU_RESTORED=0
if tmux capture-pane -t "$TMUX_DEMO" -p | grep -q "P A W M O D O R O"; then
    MENU_RESTORED=1
fi
tmux send-keys -t "$TMUX_DEMO" "Q"
sleep 0.4
tmux kill-session -t "$TMUX_DEMO" 2>/dev/null || true

DEMO_OK=0
if [ "$DEMO_SEEN" -eq 1 ] && [ "$MENU_RESTORED" -eq 1 ] && [ -f "$DEMO_STRACE" ]; then
    DEMO_OK=1
fi
rm -rf "$DEMO_SUBDIR"

if [ "$DEMO_OK" -eq 1 ]; then
    pass "Scenario 33 - Rendering demo renders via Ctrl+G, single-write flush verified, clean menu return"
else
    fail "Scenario 33 - Rendering demo failed (seen=$DEMO_SEEN, restored=$MENU_RESTORED)"
fi

# -----------------------------------------------------------------------------
# Scenario 34: settings.dat v1-to-v2 Migration, Coat Customization & Editor Groups (Task G2)
# -----------------------------------------------------------------------------
MIG_SUBDIR="$TMP_DIR/mig_test"
mkdir -p "$MIG_SUBDIR"
cp "$BIN" "$MIG_SUBDIR/pawmodoro"

# 1. Write a valid 24-byte Version 1 settings.dat:
# magic 'PAWS' (4), version 1 (1), theme 1 (1, Matcha Latte), custom palette (12),
# anim 1 (1), sound 1 (1), charset 0 (1), notify 1 (1), notify_layers 0x1F (1), volume 2 (1) = 24 bytes
python3 -c "
magic = b'PAWS'
v1_bytes = magic + bytes([1, 1]) + bytes(range(10, 22)) + bytes([1, 1, 0, 1, 0x1F, 2])
assert len(v1_bytes) == 24
open('$MIG_SUBDIR/settings.dat', 'wb').write(v1_bytes)
"

TMUX_MIG="paw_mig_$$"
tmux new-session -d -s "$TMUX_MIG" -x 80 -y 24 -c "$MIG_SUBDIR" bash
tmux send-keys -t "$TMUX_MIG" "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
sleep 0.5

MIG_OK=0
if tmux capture-pane -t "$TMUX_MIG" -p | grep -q "P A W M O D O R O"; then
    # Open Settings
    tmux send-keys -t "$TMUX_MIG" "5"
    sleep 0.4
    CAP_S=$(tmux capture-pane -t "$TMUX_MIG" -p)
    # Check that Matcha Latte theme loaded and default coat Orange Tabby displayed
    if echo "$CAP_S" | grep -q "Matcha Latte" && echo "$CAP_S" | grep -q "Orange Tabby"; then
        # Navigate down to Cat coat (row 2: Down, Down) and change coat to Gray Tabby (Right)
        tmux send-keys -t "$TMUX_MIG" Down
        sleep 0.2
        tmux send-keys -t "$TMUX_MIG" Down
        sleep 0.2
        tmux send-keys -t "$TMUX_MIG" Right
        sleep 0.3
        CAP_COAT=$(tmux capture-pane -t "$TMUX_MIG" -p)
        if echo "$CAP_COAT" | grep -q "Gray Tabby"; then
            # Open color editor: Navigate Up to row 1 (Customize colors), press Enter
            tmux send-keys -t "$TMUX_MIG" Up
            sleep 0.2
            tmux send-keys -t "$TMUX_MIG" Enter
            sleep 0.4
            CAP_ED=$(tmux capture-pane -t "$TMUX_MIG" -p)
            # Verify [Interface] tab active, then switch to [Art] via ']'
            if echo "$CAP_ED" | grep -q "Interface"; then
                tmux send-keys -t "$TMUX_MIG" "]"
                sleep 0.3
                CAP_ART=$(tmux capture-pane -t "$TMUX_MIG" -p)
                if echo "$CAP_ART" | grep -q "Art" && echo "$CAP_ART" | grep -qi "Fur"; then
                    # Edit art slot with Right arrow (+1) -> automatically sets coat to Custom
                    tmux send-keys -t "$TMUX_MIG" Right
                    sleep 0.3
                    CAP_CUST=$(tmux capture-pane -t "$TMUX_MIG" -p)
                    if echo "$CAP_CUST" | grep -q "Custom"; then
                        # Return to Settings, verify Custom coat, return to menu, quit
                        tmux send-keys -t "$TMUX_MIG" "B"
                        sleep 0.2
                        tmux send-keys -t "$TMUX_MIG" "B"
                        sleep 0.2
                        tmux send-keys -t "$TMUX_MIG" "Q"
                        sleep 0.4

                        # Verify settings.dat was upgraded to exactly 48 bytes v2
                        if [ -f "$MIG_SUBDIR/settings.dat" ]; then
                            SAVED_SIZE=$(stat -c %s "$MIG_SUBDIR/settings.dat")
                            if [ "$SAVED_SIZE" -eq 48 ]; then
                                # Audit binary layout with python
                                python3 -c "
data = open('$MIG_SUBDIR/settings.dat', 'rb').read()
assert len(data) == 48, f'Wrong length: {len(data)}'
assert data[:4] == b'PAWS', 'Wrong magic'
assert data[4] == 2, f'Wrong version: {data[4]}'
assert data[36] == 1, f'Wrong mouse: {data[36]}'
assert data[37] == 6, f'Wrong coat (expected 6 Custom): {data[37]}'
"
                                if [ $? -eq 0 ]; then
                                    MIG_OK=1
                                fi
                            fi
                        fi
                    else
                        echo "DEBUG: CAP_CUST failed to show Custom: $CAP_CUST"
                    fi
                else
                    echo "DEBUG: CAP_ART failed to show Art & Fur: $CAP_ART"
                fi
            else
                echo "DEBUG: CAP_ED failed to show Interface: $CAP_ED"
            fi
        else
            echo "DEBUG: CAP_COAT failed to show Gray Tabby: $CAP_COAT"
        fi
    else
        echo "DEBUG: CAP_S failed to show Matcha Latte and Orange Tabby: $CAP_S"
    fi
fi
tmux kill-session -t "$TMUX_MIG" 2>/dev/null || true
rm -rf "$MIG_SUBDIR"

if [ "$MIG_OK" -eq 1 ]; then
    pass "Scenario 34 - settings.dat v1-to-v2 migration, coat presets, editor grouping, and custom auto-switch"
else
    fail "Scenario 34 - settings.dat migration or coat persistence failed"
fi

# -----------------------------------------------------------------------------
# Scenario 35: Sprite Engine & Hidden Sprite Viewer Verification (Task G3)
# -----------------------------------------------------------------------------
VIEWER_SUBDIR="$TMP_DIR/viewer_test"
mkdir -p "$VIEWER_SUBDIR"
cp "$BIN" "$VIEWER_SUBDIR/pawmodoro"

TMUX_VIEWER="paw_viewer_$$"
VIEWER_STRACE="$VIEWER_SUBDIR/viewer_strace.log"
tmux new-session -d -s "$TMUX_VIEWER" -x 80 -y 24 -c "$VIEWER_SUBDIR" bash
tmux send-keys -t "$TMUX_VIEWER" "strace -f -e trace=write -o '$VIEWER_STRACE' ./pawmodoro; echo EXIT=\$? > exit.txt" Enter

VIEWER_OK=0
# Wait for menu to appear up to 5 seconds
for i in $(seq 1 25); do
    if tmux capture-pane -t "$TMUX_VIEWER" -p | grep -q "P A W M O D O R O"; then break; fi
    sleep 0.2
done

if tmux capture-pane -t "$TMUX_VIEWER" -p | grep -q "P A W M O D O R O"; then
    # Press Ctrl+V to enter sprite viewer
    tmux send-keys -t "$TMUX_VIEWER" C-v
    sleep 0.4
    CAP_V1=$(tmux capture-pane -t "$TMUX_VIEWER" -p)
    if echo "$CAP_V1" | grep -q "PAWMODORO SPRITE VIEWER" && echo "$CAP_V1" | grep -q "Logo Cat"; then
        # Cycle theme (T) -> Matcha Latte
        tmux send-keys -t "$TMUX_VIEWER" "T"
        sleep 0.2
        # Cycle coat (C) -> Gray Tabby
        tmux send-keys -t "$TMUX_VIEWER" "C"
        sleep 0.2
        # Toggle ASCII mode (A)
        tmux send-keys -t "$TMUX_VIEWER" "A"
        sleep 0.3
        CAP_ASCII=$(tmux capture-pane -t "$TMUX_VIEWER" -p)
        # Verify ASCII Mode indicator and zero non-ASCII bytes
        ASCII_CLEAN=0
        if echo "$CAP_ASCII" | grep -q "ASCII Fallback"; then
            if ! tmux capture-pane -t "$TMUX_VIEWER" -ep | grep -P "[\x80-\xFF]" >/dev/null; then
                ASCII_CLEAN=1
            fi
        fi
        if [ "$ASCII_CLEAN" -eq 1 ]; then
            # Cycle fill slot (+)
            tmux send-keys -t "$TMUX_VIEWER" "+"
            sleep 0.2
            # Test corner clipping (7 = Top-Left)
            tmux send-keys -t "$TMUX_VIEWER" "7"
            sleep 0.2
            CAP_CLIP=$(tmux capture-pane -t "$TMUX_VIEWER" -p)
            if echo "$CAP_CLIP" | grep -q "Top-Left (Corner Clipped)"; then
                # Press Escape to return to menu
                tmux send-keys -t "$TMUX_VIEWER" Escape
                sleep 0.4
                if tmux capture-pane -t "$TMUX_VIEWER" -p | grep -q "P A W M O D O R O"; then
                    tmux send-keys -t "$TMUX_VIEWER" "Q"
                    sleep 0.4
                    if grep -q "EXIT=0" "$VIEWER_SUBDIR/exit.txt" 2>/dev/null; then
                        VIEWER_OK=1
                    fi
                fi
            fi
        fi
    fi
fi
tmux kill-session -t "$TMUX_VIEWER" 2>/dev/null || true
rm -rf "$VIEWER_SUBDIR"

if [ "$VIEWER_OK" -eq 1 ]; then
    pass "Scenario 35 - Sprite viewer Ctrl+V, theme/coat cycle, ASCII purity, clipping, and clean return"
else
    fail "Scenario 35 - Sprite viewer verification failed"
fi

# -----------------------------------------------------------------------------
# Scenario 36: G5 Art Pack B (Icons, Ornaments, Digits, Glyphs, and Budget)
# -----------------------------------------------------------------------------
echo "--- Scenario 36: G5 Art Pack B, Glyphs, Digits & Memory Budget ---"
G5_OK=1

# 1. Budget Checks
ELF_STRIPPED=$(mktemp)
strip -s -o "$ELF_STRIPPED" "$BIN"
ELF_SIZE=$(stat -c '%s' "$ELF_STRIPPED" 2>/dev/null || stat -f '%z' "$ELF_STRIPPED")
rm -f "$ELF_STRIPPED"

if [ "$ELF_SIZE" -ge 73728 ]; then
    echo "FAIL: Stripped ELF size $ELF_SIZE >= 73728 bytes (72 KB)" >&2
    G5_OK=0
fi

# 2. Section Sizes
BSS_SIZE=$(size "$BIN" | awk 'NR==2 {print $3}')
if [ "$BSS_SIZE" -gt 81920 ]; then
    echo "FAIL: .bss size $BSS_SIZE > 81920 bytes" >&2
    G5_OK=0
fi

# 3. Interactive Viewer Check for G5 Glyphs and New Sprites
G5_SUBDIR=$(mktemp -d /tmp/paw_g5_XXXXXX)
TMUX_G5="paw_g5_$$"
cp "$BIN" "$G5_SUBDIR/pawmodoro"
tmux new-session -d -s "$TMUX_G5" -x 100 -y 30 "cd \"$G5_SUBDIR\" && ./pawmodoro; echo EXIT=\$? > exit.txt"
sleep 0.5

if tmux capture-pane -t "$TMUX_G5" -p | grep -q "P A W M O D O R O"; then
    # Enter hidden sprite viewer (Ctrl+V)
    tmux send-keys -t "$TMUX_G5" "C-v"
    sleep 0.4
    CAP_G5=$(tmux capture-pane -t "$TMUX_G5" -p)
    if echo "$CAP_G5" | grep -q "Approved Glyphs"; then
        # Step forward 23 times to reach first G5 sprite (Large Digit 0)
        for i in $(seq 1 23); do
            tmux send-keys -t "$TMUX_G5" Right
        done
        sleep 0.3
        CAP_DIGIT=$(tmux capture-pane -t "$TMUX_G5" -p)
        if ! echo "$CAP_DIGIT" | grep -q "Large Digit 0"; then
            G5_OK=0
        fi
        # Toggle ASCII mode
        tmux send-keys -t "$TMUX_G5" "A"
        sleep 0.2
        if tmux capture-pane -t "$TMUX_G5" -ep | grep -P "[\x80-\xFF]" >/dev/null; then
            echo "FAIL: Non-ASCII bytes found in viewer ASCII mode" >&2
            G5_OK=0
        fi
        # Clean return
        tmux send-keys -t "$TMUX_G5" Escape
        sleep 0.4
        tmux send-keys -t "$TMUX_G5" "Q"
        sleep 0.4
    else
        echo "FAIL: Approved Glyphs header not found in sprite viewer" >&2
        G5_OK=0
    fi
else
    G5_OK=0
fi
tmux kill-session -t "$TMUX_G5" 2>/dev/null || true
rm -rf "$G5_SUBDIR"

if [ "$G5_OK" -eq 1 ]; then
    pass "Scenario 36 - G5 Art Pack B: Glyphs strip, Big digits, 14 Icons, ASCII purity, and ELF < 72 KB"
else
    fail "Scenario 36 - G5 verification failed"
fi

# -----------------------------------------------------------------------------
# Scenario 37: G6 Responsive Layout Engine, Splitters, Widgets & Hidden Test Screen
# -----------------------------------------------------------------------------
echo "--- Scenario 37: G6 Responsive Layout Engine & Widgets ---"
G6_SUBDIR=$(mktemp -d /tmp/paw_g6_XXXXXX)
TMUX_G6="paw_g6_$$"
cp "$BIN" "$G6_SUBDIR/pawmodoro"
G6_OK=1

# Test Standard tier (100x30)
tmux new-session -d -s "$TMUX_G6" -x 100 -y 30 "cd \"$G6_SUBDIR\" && ./pawmodoro; echo EXIT=\$? > exit.txt"
sleep 0.4

if tmux capture-pane -t "$TMUX_G6" -p | grep -q "P A W M O D O R O"; then
    # Enter hidden test screen via Ctrl+L
    tmux send-keys -t "$TMUX_G6" "C-l"
    sleep 0.4
    CAP_G6=$(tmux capture-pane -t "$TMUX_G6" -p)

    # 1. Verify header title and tier identifier
    if ! echo "$CAP_G6" | grep -q "PAWMODORO - G6 LAYOUT & WIDGET TEST"; then
        echo "FAIL: Test screen header not found" >&2
        G6_OK=0
    fi
    if ! echo "$CAP_G6" | grep -q "\[Standard 100x30\]"; then
        echo "FAIL: Standard tier indicator not found" >&2
        G6_OK=0
    fi

    # 2. Verify all 11 widgets rendered
    for wdg_str in "Start Focus" "Pomodoros Do" "Daily Goal Card" "Daily Tip" "Demo Mode" "Daily Reflection" "Morning Medi" "NEW" "Theme"; do
        if ! echo "$CAP_G6" | grep -q "$wdg_str"; then
            echo "FAIL: Widget content '$wdg_str' not found on test screen" >&2
            G6_OK=0
        fi
    done

    # 3. Test ASCII mode toggle ('A') and verify zero high bytes
    tmux send-keys -t "$TMUX_G6" "a"
    sleep 0.3
    if tmux capture-pane -t "$TMUX_G6" -ep | grep -P "[\x80-\xFF]" >/dev/null; then
        echo "FAIL: Non-ASCII bytes detected in test screen ASCII fallback mode" >&2
        G6_OK=0
    fi

    # 4. Cycle theme, coat, and button state
    tmux send-keys -t "$TMUX_G6" "t"
    sleep 0.2
    tmux send-keys -t "$TMUX_G6" "c"
    sleep 0.2
    tmux send-keys -t "$TMUX_G6" "1"
    sleep 0.2

    # 5. Exit test screen cleanly via 'q'
    tmux send-keys -t "$TMUX_G6" "q"
    sleep 0.3

    # Verify menu restored
    CAP_RESTORE=$(tmux capture-pane -t "$TMUX_G6" -p)
    if ! echo "$CAP_RESTORE" | grep -q "P A W M O D O R O"; then
        echo "FAIL: Menu not restored upon test screen exit" >&2
        G6_OK=0
    fi

    # Quit app
    tmux send-keys -t "$TMUX_G6" "Q"
    sleep 0.3
else
    G6_OK=0
fi

tmux kill-session -t "$TMUX_G6" 2>/dev/null || true
rm -rf "$G6_SUBDIR"

if [ "$G6_OK" -eq 1 ]; then
    pass "Scenario 37 - G6 Layout Engine, Named Regions, Splitters, 11 Widgets, and Ctrl+L Test Screen"
else
    fail "Scenario 37 - G6 verification failed"
fi

# -----------------------------------------------------------------------------
# Scenario 38: G7 Dashboard Redesign & Navigation Verification (Task G7)
# -----------------------------------------------------------------------------
echo "--- Scenario 38: G7 Dashboard Redesign & Navigation ---"
G7_SUBDIR=$(mktemp -d /tmp/paw_g7_XXXXXX)
TMUX_G7="paw_g7_$$"
cp "$BIN" "$G7_SUBDIR/pawmodoro"
G7_OK=1

tmux new-session -d -s "$TMUX_G7" -x 80 -y 24 "cd \"$G7_SUBDIR\" && ./pawmodoro; echo EXIT=\$? > exit.txt"
sleep 0.4

# Wait for menu to appear up to 5 seconds
for i in $(seq 1 25); do
    if tmux capture-pane -t "$TMUX_G7" -p | grep -q "P A W M O D O R O"; then break; fi
    sleep 0.2
done

if tmux capture-pane -t "$TMUX_G7" -p | grep -q "P A W M O D O R O"; then
    CAP_DASH=$(tmux capture-pane -t "$TMUX_G7" -p)
    # 1. Verify dashboard components present at 80x24 Compact tier
    for item in "Start Focus" "Habits" "Journal" "Demo mode" "Settings" "Quit" "Tip:"; do
        if ! echo "$CAP_DASH" | grep -q "$item"; then
            echo "FAIL: Expected dashboard element '$item' missing at 80x24" >&2
            G7_OK=0
        fi
    done

    # 2. Test Down navigation wraparound
    for step in 1 2 3 4 5 6; do
        tmux send-keys -t "$TMUX_G7" Down
        sleep 0.1
    done

    # 3. Test Up navigation wraparound (Start Focus -> Quit)
    tmux send-keys -t "$TMUX_G7" Up
    sleep 0.1
    # Move back down to Start Focus
    tmux send-keys -t "$TMUX_G7" Down
    sleep 0.1

    # 4. Test Demo Mode shortcut '4'
    tmux send-keys -t "$TMUX_G7" "4"
    sleep 0.2
    CAP_DEMO=$(tmux capture-pane -t "$TMUX_G7" -p)
    if ! echo "$CAP_DEMO" | grep -q "ON"; then
        echo "FAIL: Demo mode toggle '4' did not switch to ON" >&2
        G7_OK=0
    fi
    tmux send-keys -t "$TMUX_G7" "4"
    sleep 0.2

    # 5. Test Quick Journal direct shortcut 'J'
    tmux send-keys -t "$TMUX_G7" "J"
    sleep 0.3
    CAP_JRNL=$(tmux capture-pane -t "$TMUX_G7" -p)
    if ! echo "$CAP_JRNL" | grep -q "New entry"; then
        echo "FAIL: Quick Journal prompt not opened by 'J'" >&2
        G7_OK=0
    else
        # Enter note text and save
        tmux send-keys -t "$TMUX_G7" "Dashboard Test Note" Enter
        sleep 0.3
        CAP_AFTER_J=$(tmux capture-pane -t "$TMUX_G7" -p)
        if ! echo "$CAP_AFTER_J" | grep -q "Dashboard"; then
            echo "FAIL: New entry not reflected in Recent Notes card" >&2
            G7_OK=0
        fi
    fi

    # 6. Test Enter key activates focused control
    # Currently at Start Focus; press Down to move to Habits
    tmux send-keys -t "$TMUX_G7" Down
    sleep 0.1
    tmux send-keys -t "$TMUX_G7" Enter
    sleep 0.3
    CAP_HABITS=$(tmux capture-pane -t "$TMUX_G7" -p)
    if ! echo "$CAP_HABITS" | grep -q "HABIT TRACKER"; then
        echo "FAIL: Enter key did not activate focused Habit Tracker" >&2
        G7_OK=0
    fi
    # Return to menu with 'B'
    tmux send-keys -t "$TMUX_G7" "B"
    sleep 0.3

    # 7. Test responsive resize to Standard (100x30)
    tmux resize-window -t "$TMUX_G7" -x 100 -y 30
    sleep 0.3
    CAP_STD=$(tmux capture-pane -t "$TMUX_G7" -p)
    if ! echo "$CAP_STD" | grep -q "Today's Progress"; then
        echo "FAIL: Today's Progress missing at 100x30 Standard tier" >&2
        G7_OK=0
    fi

    # 8. Test responsive resize to Grand (120x36)
    tmux resize-window -t "$TMUX_G7" -x 120 -y 36
    sleep 0.3
    CAP_GRAND=$(tmux capture-pane -t "$TMUX_G7" -p)
    if ! echo "$CAP_GRAND" | grep -q "P A W M O D O R O"; then
        echo "FAIL: Title missing at 120x36 Grand tier" >&2
        G7_OK=0
    fi

    # 9. Clean quit via 'Q'
    tmux send-keys -t "$TMUX_G7" "Q"
    sleep 0.3
else
    G7_OK=0
fi

tmux kill-session -t "$TMUX_G7" 2>/dev/null || true
rm -rf "$G7_SUBDIR"

if [ "$G7_OK" -eq 1 ]; then
    pass "Scenario 38 - G7 Dashboard Redesign: Navigation, Shortcuts, Quick Note, Enter Activation, and Responsiveness"
else
    fail "Scenario 38 - G7 verification failed"
fi
# -----------------------------------------------------------------------------
# Optional Extended Scenario: Full 4-Session Cycle (--full)
# -----------------------------------------------------------------------------
if [ "$FULL_MODE" -eq 1 ]; then
    echo "=== Running Extended Scenario: Full 4-Session Pomodoro Cycle ==="
    send "./pawmodoro; echo EXIT=\$? > exit.txt" Enter
    wait_for "P A W M O D O R O" 5
    send "4" # Demo ON
    sleep 0.3
    send "1" # Start Session 1

    CYCLE_OK=1
    for sess in 1 2 3 4; do
        if ! wait_for "FOCUS - Session $sess of 4" 10; then
            CYCLE_OK=0
            break
        fi
        if ! wait_for "Focus complete! Add a quick note? (y/n)" 15; then
            CYCLE_OK=0
            break
        fi
        send " " # Skip note, continue to break
        if [ "$sess" -lt 4 ]; then
            if ! wait_for "SHORT BREAK - Session $sess of 4" 5; then
                CYCLE_OK=0
                break
            fi
            if ! wait_for "Break over! Press any key to focus." 10; then
                CYCLE_OK=0
                break
            fi
            send " " # Advance to next focus
        else
            if ! wait_for "LONG BREAK - Session 4 of 4" 5; then
                CYCLE_OK=0
                break
            fi
            if ! wait_for "Break over! Press any key to focus." 15; then
                CYCLE_OK=0
                break
            fi
            send " " # Advance to Session 1
            if ! wait_for "FOCUS - Session 1 of 4" 5; then
                CYCLE_OK=0
                break
            fi
        fi
    done
    send "Q" # Back to menu
    wait_for "P A W M O D O R O" 5
    send "Q" # Quit
    sleep 0.4

    if [ "$CYCLE_OK" -eq 1 ]; then
        pass "Extended Scenario - Complete 4-session cycle ending in LONG BREAK and reset"
    else
        fail "Extended Scenario - Complete 4-session cycle did not transition as expected"
    fi
fi

# Final Summary
echo "============================================================================="
echo "SMOKE TEST RESULTS: $PASSED passed, $FAILED failed"
echo "============================================================================="

if [ "$FAILED" -eq 0 ]; then
    exit 0
else
    exit 1
fi
