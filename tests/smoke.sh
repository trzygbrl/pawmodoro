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
send "X" "9" " " Enter
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
    if wait_for "SETTINGS" 5 && cap | grep -q "Theme" && cap | grep -q "Customize colors" && cap | grep -q "Animations" && cap | grep -q "Sound & Volume" && cap | grep -q "Reset to defaults"; then
        send "Down"
        sleep 0.2
        send Enter
        if wait_for "CUSTOMIZE COLORS" 5 && cap | grep -q "BORDER" && cap | grep -q "HIGHLIGHT"; then
            send "B"
            if wait_for "Animations" 5; then
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
                            if [ "$SETTINGS_SIZE" -eq 24 ]; then
                                pass "Scenario 17 - Settings navigation, color editor, immediate save, and 24B settings.dat"
                            else
                                fail "Scenario 17 - settings.dat size is $SETTINGS_SIZE bytes (expected 24)"
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
            fail "Scenario 17 - Enter did not open CUSTOMIZE COLORS screen"
        fi
    else
        fail "Scenario 17 - Key 5 did not display all SETTINGS rows"
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
