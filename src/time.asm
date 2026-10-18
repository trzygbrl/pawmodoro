; =============================================================================
; Pawmodoro - Time & Date Utilities (src/time.asm)
;
; Purpose: High-resolution sleeping via sys_nanosleep, clock querying via
;          sys_time, timezone offset adjustments, day number calculation,
;          Howard Hinnant's civil_from_days Gregorian calendar date conversion,
;          and HH:MM time formatting per PRD §3.1, §6.3, and §6.4.
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

; -----------------------------------------------------------------------------
; time_sleep_100ms: Sleep for 100 milliseconds using sys_nanosleep.
;
; Purpose:  Configures the shared timespec buffer with tv_sec = 0 and
;           tv_nsec = 100,000,000 (NANOSLEEP_100MS), then calls sys_nanosleep.
;           Interrupted sleeps (EINTR) are considered acceptable per PRD §6.4.
; IN:       none
; OUT:      none
; CLOBBERS: none (EFLAGS only)
; -----------------------------------------------------------------------------
time_sleep_100ms:
    save_regs
    push eax

    ; Populate timespec structure: tv_sec = 0, tv_nsec = 100,000,000
    mov dword [timespec], 0
    mov dword [timespec + 4], NANOSLEEP_100MS

    ; Call sys_nanosleep(timespec, NULL)
    syscall SYS_NANOSLEEP, timespec, 0

    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; time_now: Get current UTC timestamp in seconds since Unix epoch.
;
; Purpose:  Calls Linux sys_time with tloc = NULL and returns seconds in EAX.
; IN:       none
; OUT:      EAX = UTC seconds since 1970-01-01 00:00:00 UTC
; CLOBBERS: EAX, EFLAGS
; -----------------------------------------------------------------------------
time_now:
    save_regs

    ; sys_time(NULL)
    syscall SYS_TIME, 0

    restore_regs
    ret

; -----------------------------------------------------------------------------
; time_local: Get current local time in seconds adjusted for timezone.
;
; Purpose:  Calls time_now to query UTC timestamp, then adds TZ_OFFSET (28,800
;           seconds for UTC+8, Philippines) to compute local seconds.
; IN:       none
; OUT:      EAX = Local seconds (UTC + TZ_OFFSET)
; CLOBBERS: EAX, EFLAGS
; -----------------------------------------------------------------------------
time_local:
    save_regs

    call time_now
    add eax, TZ_OFFSET          ; Adjust UTC to local time (UTC+8)

    restore_regs
    ret

; -----------------------------------------------------------------------------
; time_today: Compute the current local day number since the Unix epoch.
;
; Purpose:  Calls time_local to get total local seconds, then performs an
;           unsigned integer division by 86,400 (SECONDS_PER_DAY) to obtain the
;           day count since 1970-01-01. Used for daily habit roll-overs.
; IN:       none
; OUT:      EAX = Day number (local seconds / 86400)
; CLOBBERS: EAX, EFLAGS
; -----------------------------------------------------------------------------
time_today:
    save_regs

    call time_local

    ; Unsigned division: day_number = local_seconds / 86400
    xor edx, edx                ; Zero EDX before unsigned DIV (never use CDQ)
    mov ebx, SECONDS_PER_DAY
    div ebx                     ; EAX = quotient (day number)

    restore_regs
    ret

; -----------------------------------------------------------------------------
; time_fmt_date: Convert day number to calendar date string "YYYY-MM-DD\0".
;
; Purpose:  Transforms day count since 1970-01-01 into a human-readable Gregorian
;           calendar date string formatted as "YYYY-MM-DD" with a terminating NUL
;           directly into buffer EDI (requiring at least 11 bytes).
;           Implements Howard Hinnant's "civil_from_days" integer algorithm:
;             1. Shift epoch to March 1, year 0 (z = days + 719468).
;             2. era = z / 146097, doe = z % 146097 (400-year cycle).
;             3. yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365.
;             4. y = yoe + era * 400.
;             5. doy = doe - (365 * yoe + yoe/4 - yoe/100).
;             6. mp = (5 * doy + 2) / 153.
;             7. d = doy - (153 * mp + 2) / 5 + 1.
;             8. m = mp < 10 ? mp + 3 : mp - 9.
;             9. if m <= 2 then y += 1.
;           Writes characters directly to memory without calling buf_* routines.
; IN:       EAX = Day number (non-negative)
;           EDI = Destination buffer pointer (>= 11 bytes)
; OUT:      writes "YYYY-MM-DD\0" at [EDI]
; CLOBBERS: none (EFLAGS only; EAX and EDI are preserved)
; -----------------------------------------------------------------------------
time_fmt_date:
    save_regs
    push eax                    ; Preserve input day number
    push edi                    ; Preserve destination buffer pointer

    ; Allocate 24 bytes of local stack storage for algorithm variables:
    ;   [esp + 0]  = doe (day of era) / doy (day of year)
    ;   [esp + 4]  = era
    ;   [esp + 8]  = yoe (year of era)
    ;   [esp + 12] = y (computed Gregorian year)
    ;   [esp + 16] = m (computed Gregorian month 1..12)
    ;   [esp + 20] = d (computed Gregorian day 1..31)
    sub esp, 24

    ; -------------------------------------------------------------------------
    ; Step 1: Shift epoch from 1970-01-01 to 0000-03-01
    ; Adding 719,468 days aligns the start of the calendar year with March 1st.
    ; This places the variable leap day (Feb 28/29) at the very end of the year,
    ; vastly simplifying leap-year and month-length arithmetic.
    ; -------------------------------------------------------------------------
    mov eax, [esp + 28]          ; Retrieve original input day number
    add eax, CIVIL_EPOCH_SHIFT   ; z = days + 719468

    ; -------------------------------------------------------------------------
    ; Step 2: Compute 400-year Gregorian cycle era and day-of-era (doe)
    ; The Gregorian calendar repeats its leap-year pattern exactly every 400 years,
    ; which consists of 146,097 days (97 leap years + 303 common years).
    ; -------------------------------------------------------------------------
    xor edx, edx
    mov ebx, CIVIL_ERA_DAYS     ; 146097
    div ebx                     ; EAX = era, EDX = day-of-era (doe)
    mov [esp + 4], eax          ; Store era
    mov [esp + 0], edx          ; Store doe

    ; -------------------------------------------------------------------------
    ; Step 3: Compute year-of-era (yoe: 0..399)
    ; Formula: yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
    ; This accounts for:
    ;   - leap years every 4 years (1460 days),
    ;   - common century years every 100 years (36524 days),
    ;   - 400-year leap century boundary (146096 days).
    ; -------------------------------------------------------------------------
    ; Term 1: t1 = doe / 1460
    mov eax, edx
    xor edx, edx
    mov ebx, CIVIL_DAYS_4Y      ; 1460
    div ebx                     ; EAX = doe / 1460
    mov ecx, eax                ; ECX = t1

    ; Term 2: t2 = doe / 36524
    mov eax, [esp + 0]          ; doe
    xor edx, edx
    mov ebx, CIVIL_DAYS_100Y    ; 36524
    div ebx                     ; EAX = doe / 36524
    mov esi, eax                ; ESI = t2

    ; Term 3: t3 = doe / 146096
    mov eax, [esp + 0]          ; doe
    xor edx, edx
    mov ebx, CIVIL_DAYS_400Y_M1 ; 146096
    div ebx                     ; EAX = doe / 146096

    ; Numerator = doe - t1 + t2 - t3
    mov ebx, [esp + 0]          ; doe
    sub ebx, ecx                ; doe - t1
    add ebx, esi                ; doe - t1 + t2
    sub ebx, eax                ; doe - t1 + t2 - t3

    ; Divide numerator by 365
    mov eax, ebx
    xor edx, edx
    mov ebx, CIVIL_DAYS_YEAR    ; 365
    div ebx                     ; EAX = yoe
    mov [esp + 8], eax          ; Store yoe

    ; -------------------------------------------------------------------------
    ; Step 4: Compute preliminary year y = yoe + era * 400
    ; -------------------------------------------------------------------------
    mov eax, [esp + 4]          ; era
    mov ebx, CIVIL_YEARS_ERA    ; 400
    mul ebx                     ; EAX = era * 400
    add eax, [esp + 8]          ; y = era * 400 + yoe
    mov [esp + 12], eax         ; Store preliminary year

    ; -------------------------------------------------------------------------
    ; Step 5: Compute day-of-year (doy: 0..365)
    ; Formula: doy = doe - (365 * yoe + yoe/4 - yoe/100)
    ; Subtracts the number of elapsed days in preceding years of this era.
    ; -------------------------------------------------------------------------
    mov eax, [esp + 8]          ; yoe
    mov ebx, CIVIL_DAYS_YEAR    ; 365
    mul ebx                     ; EAX = 365 * yoe
    mov ecx, eax

    mov eax, [esp + 8]          ; yoe
    shr eax, 2                  ; yoe / 4
    add ecx, eax

    mov eax, [esp + 8]          ; yoe
    xor edx, edx
    mov ebx, CIVIL_YEARS_CENTURY ; 100
    div ebx                     ; EAX = yoe / 100
    sub ecx, eax                ; ECX = 365*yoe + yoe/4 - yoe/100

    mov eax, [esp + 0]          ; doe
    sub eax, ecx                ; EAX = doy
    mov [esp + 0], eax          ; Save doy in [esp + 0]

    ; -------------------------------------------------------------------------
    ; Step 6: Compute month position mp = (5 * doy + 2) / 153
    ; Five-month repeating pattern in the Roman calendar (Mar-Jul and Aug-Dec)
    ; spans exactly 153 days (31+30+31+30+31 = 153).
    ; -------------------------------------------------------------------------
    mov ebx, CIVIL_DAY_SCALE    ; 5
    mul ebx                     ; EAX = 5 * doy
    add eax, CIVIL_MONTH_SHIFT  ; 5 * doy + 2
    xor edx, edx
    mov ebx, CIVIL_MONTH_SCALE  ; 153
    div ebx                     ; EAX = mp (0..11)
    mov ecx, eax                ; ECX = mp

    ; -------------------------------------------------------------------------
    ; Step 7: Compute day of month d = doy - (153 * mp + 2) / 5 + 1
    ; -------------------------------------------------------------------------
    mov eax, ecx                ; mp
    mov ebx, CIVIL_MONTH_SCALE  ; 153
    mul ebx                     ; 153 * mp
    add eax, CIVIL_MONTH_SHIFT  ; 153 * mp + 2
    xor edx, edx
    mov ebx, CIVIL_DAY_SCALE    ; 5
    div ebx                     ; (153 * mp + 2) / 5

    mov ebx, [esp + 0]          ; doy
    sub ebx, eax                ; doy - ((153*mp + 2) / 5)
    inc ebx                     ; + 1 gives 1-based day
    mov [esp + 20], ebx         ; Store d

    ; -------------------------------------------------------------------------
    ; Step 8: Compute month m = mp < 10 ? mp + 3 : mp - 9
    ; Maps Roman months (mp 0 = March) back to civil months (March = 3, Jan = 1).
    ; -------------------------------------------------------------------------
    cmp ecx, CIVIL_MONTH_CUTOFF ; mp < 10?
    jae .month_late
    lea eax, [ecx + CIVIL_MONTH_ADJ_EARLY]  ; m = mp + 3 (March..December)
    jmp .month_done
.month_late:
    sub ecx, CIVIL_MONTH_ADJ_LATE           ; m = mp - 9 (January..February)
    mov eax, ecx
.month_done:
    mov [esp + 16], eax         ; Store m

    ; -------------------------------------------------------------------------
    ; Step 9: Adjust year if m <= 2 then y += 1
    ; In the shifted calendar, January and February belonged to the prior year.
    ; -------------------------------------------------------------------------
    cmp eax, CIVIL_YEAR_ADJ_MONTH           ; m <= 2?
    ja .year_adj_done
    inc dword [esp + 12]        ; y += 1
.year_adj_done:

    ; -------------------------------------------------------------------------
    ; Step 10: Format directly into buffer at EDI as "YYYY-MM-DD\0"
    ; -------------------------------------------------------------------------
    mov edi, [esp + 24]         ; Retrieve destination buffer pointer

    ; Write Year (4 digits, zero-padded)
    mov eax, [esp + 12]         ; Year (e.g. 2024)
    xor edx, edx
    mov ebx, DECIMAL_1000       ; 1000
    div ebx                     ; EAX = thousands, EDX = rem (0..999)
    add al, CHAR_ZERO
    mov [edi], al

    mov eax, edx
    xor edx, edx
    mov ebx, DECIMAL_100        ; 100
    div ebx                     ; EAX = hundreds, EDX = rem (0..99)
    add al, CHAR_ZERO
    mov [edi + 1], al

    mov eax, edx
    xor edx, edx
    mov ebx, DECIMAL_BASE       ; 10
    div ebx                     ; EAX = tens, EDX = units
    add al, CHAR_ZERO
    mov [edi + 2], al
    add dl, CHAR_ZERO
    mov [edi + 3], dl

    ; Write '-' delimiter
    mov byte [edi + 4], CHAR_MINUS

    ; Write Month (2 digits, zero-padded)
    mov eax, [esp + 16]         ; Month (1..12)
    xor edx, edx
    mov ebx, DECIMAL_BASE       ; 10
    div ebx                     ; EAX = tens, EDX = units
    add al, CHAR_ZERO
    mov [edi + 5], al
    add dl, CHAR_ZERO
    mov [edi + 6], dl

    ; Write '-' delimiter
    mov byte [edi + 7], CHAR_MINUS

    ; Write Day (2 digits, zero-padded)
    mov eax, [esp + 20]         ; Day (1..31)
    xor edx, edx
    mov ebx, DECIMAL_BASE       ; 10
    div ebx                     ; EAX = tens, EDX = units
    add al, CHAR_ZERO
    mov [edi + 8], al
    add dl, CHAR_ZERO
    mov [edi + 9], dl

    ; Write terminating NUL
    mov byte [edi + 10], CHAR_NULL

    ; Clean up local stack frame
    add esp, 24
    pop edi
    pop eax
    restore_regs
    ret

; -----------------------------------------------------------------------------
; time_fmt_hhmm: Format local seconds into "HH:MM\0" (6 bytes).
;
; Purpose:  Converts local seconds since epoch into 24-hour time of day "HH:MM\0"
;           written directly to [EDI]. Hours and minutes are zero-padded.
; IN:       EAX = Local seconds
;           EDI = Destination buffer pointer (>= 6 bytes)
; OUT:      writes "HH:MM\0" at [EDI]
; CLOBBERS: none (EFLAGS only; EAX and EDI are preserved)
; -----------------------------------------------------------------------------
time_fmt_hhmm:
    save_regs
    push eax
    push edi

    ; Compute seconds into current day: local_seconds % 86400
    xor edx, edx
    mov ebx, SECONDS_PER_DAY
    div ebx                     ; EDX = seconds into day (0..86399)

    ; Compute hours: seconds_into_day / 3600
    mov eax, edx
    xor edx, edx
    mov ebx, SECONDS_PER_HOUR
    div ebx                     ; EAX = hours (0..23), EDX = remainder seconds (0..3599)
    push edx                    ; Save remainder seconds for minutes calculation

    ; Format hours as 2 digits at [EDI + 0..1]
    xor edx, edx
    mov ebx, DECIMAL_BASE
    div ebx                     ; EAX = tens, EDX = units
    add al, CHAR_ZERO
    mov [edi], al
    add dl, CHAR_ZERO
    mov [edi + 1], dl

    ; Write separator ':'
    mov byte [edi + 2], CHAR_COLON

    ; Compute minutes: remainder_seconds / 60
    pop eax                     ; EAX = remainder seconds
    xor edx, edx
    mov ebx, SECONDS_PER_MINUTE
    div ebx                     ; EAX = minutes (0..59)

    ; Format minutes as 2 digits at [EDI + 3..4]
    xor edx, edx
    mov ebx, DECIMAL_BASE
    div ebx                     ; EAX = tens, EDX = units
    add al, CHAR_ZERO
    mov [edi + 3], al
    add dl, CHAR_ZERO
    mov [edi + 4], dl

    ; Write terminating NUL
    mov byte [edi + 5], CHAR_NULL

    pop edi
    pop eax
    restore_regs
    ret
