; =============================================================================
; Pawmodoro - Statistics Engine & Daily Persistence (src/stats.asm)
;
; Purpose: Pomodoro completion tracking, daily rollover management, and stats.dat
;          file synchronization per PRD §4.5 FR-D2 and §6.4.
; Reference: PRD §4.1 FR-U7, §4.2 FR-T7, §4.5 FR-D1/FR-D2/FR-D4, §6.3, §6.4
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

; -----------------------------------------------------------------------------
; stats_load: Read stats.dat into memory, apply day-rollover, and sync dashboard.
;
; Purpose:  Loads the 12-byte stats.dat record (day, today_count, total_count)
;           into in-memory variables via file_load.
;           - Missing or Short File (< 12 bytes, empty, or corrupted):
;             Initializes empty state per FR-D1: day = time_today, today_count = 0,
;             total_count = 0. Never crashes on missing/invalid files.
;           - Day Rollover (FR-D2):
;             If the stored day number differs from current local day (time_today),
;             resets today_count = 0 and updates day = time_today (total_count kept).
;           - Dashboard Sync (FR-U7):
;             Copies today_count into dash_pomodoros so the main menu displays
;             the real value upon startup.
; IN:       none
; OUT:      none
; CLOBBERS: EFLAGS only (all registers preserved)
; -----------------------------------------------------------------------------
stats_load:
    save_regs
    push eax

    ; Attempt to load 12 bytes from stats.dat into contiguous stats_data buffer
    mov esi, path_stats
    mov edi, stats_data
    mov ecx, STATS_RECORD_SIZE  ; 12 bytes
    call file_load

    ; Validate bytes read: must be at least STATS_RECORD_SIZE (12)
    test eax, eax
    js .load_empty_state        ; Missing file or error (-1): treat as empty state
    cmp eax, STATS_RECORD_SIZE
    jb .load_empty_state        ; Short file (< 12 bytes): treat as empty state (FR-D1)

    ; File read succeeded: check day rollover (FR-D2)
    call time_today             ; EAX = current local day number
    cmp [stats_day], eax
    je .load_sync_dashboard     ; Stored day matches today: keep today_count

    ; Stored day != today: day rollover occurred
    mov [stats_day], eax        ; Update stored day to today
    mov dword [stats_today_count], 0 ; Reset today's count to 0 (total_count preserved)
    jmp .load_sync_dashboard

.load_empty_state:
    ; Initialize empty state: day = today, today_count = 0, total_count = 0
    call time_today             ; EAX = current local day number
    mov [stats_day], eax
    mov dword [stats_today_count], 0
    mov dword [stats_total_count], 0

.load_sync_dashboard:
    ; Sync today's count into dash_pomodoros for main menu display
    mov eax, [stats_today_count]
    mov [dash_pomodoros], eax

    ; Initialize save failure flag to OK
    mov dword [stats_save_failed], STATS_SAVE_OK

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; stats_add_pomodoro: Increment pomodoro counts, persist to disk, and sync UI.
;
; Purpose:  Invoked strictly on natural completion of a FOCUS session.
;           1. Checks day rollover (in case app remained running past midnight).
;           2. Increments today_count and total_count.
;           3. Updates dash_pomodoros immediately for main menu reflection.
;           4. Writes the 12-byte record to stats.dat using file_save.
;           5. Records outcome in stats_save_failed (0 = OK, 1 = Failed) so
;              the timer completion screen can display "Could not save" if needed.
; IN:       none
; OUT:      EAX = 0 (FILE_OK) on success, -1 (FILE_ERR) on save failure
; CLOBBERS: EAX, EFLAGS only (all other registers preserved)
; -----------------------------------------------------------------------------
stats_add_pomodoro:
    save_regs

    ; 1. Check day rollover in case midnight passed while app was running
    call time_today             ; EAX = current local day number
    cmp [stats_day], eax
    je .add_inc_counts

    ; New day rollover: update day and reset today_count before incrementing
    mov [stats_day], eax
    mov dword [stats_today_count], 0

.add_inc_counts:
    ; 2. Increment completed counts
    inc dword [stats_today_count]
    inc dword [stats_total_count]

    ; 3. Sync dashboard counter for main menu
    mov edx, [stats_today_count]
    mov [dash_pomodoros], edx

    ; 4. Persist updated 12-byte record to stats.dat
    mov esi, path_stats
    mov edi, stats_data
    mov ecx, STATS_RECORD_SIZE  ; 12 bytes
    call file_save

    ; 5. Record save outcome in stats_save_failed flag
    test eax, eax
    jz .add_save_success

    ; Save failed: flag error for timer completion screen (FR-D4)
    mov dword [stats_save_failed], STATS_SAVE_FAILED
    mov eax, FILE_ERR           ; Return -1
    jmp .add_done

.add_save_success:
    mov dword [stats_save_failed], STATS_SAVE_OK
    mov eax, FILE_OK            ; Return 0

.add_done:
    restore_regs
    ret

; -----------------------------------------------------------------------------
; stats_today: Query today's completed pomodoro count.
;
; Purpose:  Returns today's completed focus sessions. If the stored day number
;           differs from current day (time_today), returns 0.
; IN:       none
; OUT:      EAX = Today's completed count (0 if day rollover has not yet synced)
; CLOBBERS: EAX, EFLAGS only (all other registers preserved)
; -----------------------------------------------------------------------------
stats_today:
    save_regs

    call time_today             ; EAX = current local day number
    cmp [stats_day], eax
    jne .today_stale

    mov eax, [stats_today_count]
    jmp .today_done

.today_stale:
    xor eax, eax                ; Stored day is not today: count is 0

.today_done:
    restore_regs
    ret
