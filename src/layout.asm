; =============================================================================
; Pawmodoro - v3 Responsive Layout Engine (src/layout.asm)
;
; Purpose: Tier-aware layout engine, named dashboard regions, and generic
;          rectangle splitting primitives.
; Reference: PRD_V3 §3.1, §3.2, §3.3; Task G6 Specifications
; Register Discipline: PRD §6.2 (all procedures preserve all general registers
;                      and EFLAGS unless explicitly documented).
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES
; =============================================================================

;=============================================================================
; Procedure: layout_update
; Purpose:   Calculates responsive layout tier and geometry based on terminal
;            dimensions (term_cols, term_rows) adhering to PRD_V3 §3.1 and §3.2:
;              - TIER_GRAND if term_cols >= 120 AND term_rows >= 36
;              - TIER_STANDARD if term_cols >= 100 AND term_rows >= 30
;              - TIER_COMPACT otherwise
;              - ui_w = min(term_cols - 2, 120)
;              - ui_col0 = floor((term_cols - ui_w) / 2)
;              - ui_h = term_rows
;            Guarantees minimum 80x24 clamp.
;            Detects terminal dimension changes and emits screen clear to remove
;            stale cells outside new geometry.
; IN:        Uses [term_cols] and [term_rows]
; OUT:       Updates [layout_tier], [ui_w], [ui_h], [ui_col0], [ui_seen_cols], [ui_seen_rows]
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
layout_update:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Clamp / fallback to minimum dimensions if dimensions are below 80x24
    mov eax, [term_cols]
    cmp eax, TERM_MIN_COLS      ; 80
    jae .cols_ok
    mov eax, TERM_MIN_COLS
.cols_ok:
    mov edx, [term_rows]
    cmp edx, TERM_MIN_ROWS      ; 24
    jae .rows_ok
    mov edx, TERM_MIN_ROWS
.rows_ok:
    ; ui_h = term_rows
    mov [ui_h], edx

    ; 1. Compute Responsive Tier (PRD_V3 §3.1)
    ; Grand: cols >= 120 AND rows >= 36
    cmp eax, 120
    jb .check_standard
    cmp edx, 36
    jb .check_standard
    mov dword [layout_tier], TIER_GRAND
    jmp .tier_done

.check_standard:
    ; Standard: cols >= 100 AND rows >= 30
    cmp eax, 100
    jb .set_compact
    cmp edx, 30
    jb .set_compact
    mov dword [layout_tier], TIER_STANDARD
    jmp .tier_done

.set_compact:
    mov dword [layout_tier], TIER_COMPACT

.tier_done:
    ; 2. Compute Frame Width: ui_w = min(term_cols - 2, 120)
    sub eax, UI_FRAME_MARGIN_COLS ; term_cols - 2
    cmp eax, UI_FRAME_MAX_WIDTH  ; 120
    jbe .w_ok
    mov eax, UI_FRAME_MAX_WIDTH
.w_ok:
    mov [ui_w], eax

    ; 3. Compute Centering Offset: ui_col0 = floor((term_cols - ui_w) / 2)
    mov edx, [term_cols]
    cmp edx, TERM_MIN_COLS
    jae .term_cols_ok
    mov edx, TERM_MIN_COLS
.term_cols_ok:
    sub edx, eax                ; EDX = term_cols - ui_w
    shr edx, 1                  ; Integer division by 2
    mov [ui_col0], edx

    ; 4. Check for Dimension Changes & Clean Redraw
    mov eax, [term_cols]
    mov edx, [term_rows]
    cmp dword [ui_seen_cols], 0
    jz .record_seen

    cmp eax, [ui_seen_cols]
    jne .dim_changed
    cmp edx, [ui_seen_rows]
    je .record_seen

.dim_changed:
    mov al, SLOT_BG
    call ui_bgcolor
    mov esi, ansi_clear
    call buf_str
    mov esi, ansi_reset
    call buf_str

.record_seen:
    mov [ui_seen_cols], eax
    mov [ui_seen_rows], edx

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: layout_rect
; Purpose:   Computes the 1-based absolute terminal rectangle for the requested
;            named dashboard region using the active layout tier and current
;            dimensions. Guaranteed non-overlapping sibling rectangles and
;            strict containment within frame boundaries.
; IN:        EAX = Named region identifier (REGION_HEADER .. REGION_CARD_JOURNAL)
; OUT:       EAX = Absolute starting row (1-based)
;            EBX = Absolute starting column (1-based terminal coordinate)
;            ECX = Rectangle width in terminal cells
;            EDX = Rectangle height in terminal rows
; CLOBBERS:  EAX, EBX, ECX, EDX
;=============================================================================
layout_rect:
    pushf
    push esi
    push edi
    push ebp

    ; Validate region ID
    cmp eax, REGION_COUNT
    jae .invalid_region

    ; Save region ID
    mov esi, eax

    ; Frame coordinates:
    ; frame_c0 (absolute 1-based) = [ui_col0] + 1
    mov edi, [ui_col0]
    inc edi                     ; EDI = frame_c0 (1-based absolute col)
    mov ebp, [ui_w]             ; EBP = frame_w

    ; Header height determination:
    ; Compact: 5 rows (4 inner rows for 8x4 logo)
    ; Standard: 7 rows (6 inner rows for 12x6 logo)
    ; Grand: 8 rows (7 inner rows for 14x7 logo)
    mov ecx, 5                  ; Compact header height
    cmp dword [layout_tier], TIER_GRAND
    je .hdr_grand
    cmp dword [layout_tier], TIER_STANDARD
    je .hdr_std
    jmp .hdr_done
.hdr_grand:
    mov ecx, 8
    jmp .hdr_done
.hdr_std:
    mov ecx, 7
.hdr_done:
    ; ECX now holds header_h

    ; Middle area coordinates:
    ; mid_r0 = header_h + 1
    ; mid_h = [ui_h] - header_h - 2 (footer is 2 rows)
    lea eax, [ecx + 1]          ; EAX = mid_r0
    mov edx, [ui_h]
    sub edx, ecx
    sub edx, 2                  ; EDX = mid_h (guard against underflow below)
    cmp edx, 1
    jge .mid_h_ok
    mov edx, 1
.mid_h_ok:

    ; Sidebar width determination:
    ; Compact: 22 cols; Standard: 26 cols; Grand: 28 cols
    push edx                    ; Save mid_h on stack [esp+4]
    push eax                    ; Save mid_r0 on stack [esp]

    mov ebx, 22                 ; Compact sidebar width
    cmp dword [layout_tier], TIER_GRAND
    je .sb_grand
    cmp dword [layout_tier], TIER_STANDARD
    je .sb_std
    jmp .sb_done
.sb_grand:
    mov ebx, 28
    jmp .sb_done
.sb_std:
    mov ebx, 26
.sb_done:
    ; EBX now holds sidebar_w

    ; Dispatch based on requested region in ESI
    cmp esi, REGION_HEADER
    je .ret_header
    cmp esi, REGION_SIDEBAR
    je .ret_sidebar
    cmp esi, REGION_MAIN
    je .ret_main
    cmp esi, REGION_FOOTER
    je .ret_footer

    ; Regions 4..8 are cards inside MAIN.
    ; Main geometry:
    ; main_col = frame_c0 + sidebar_w
    ; main_w   = frame_w - sidebar_w
    ; main_r0  = mid_r0
    ; main_h   = mid_h
    ; Stack: [esp] = mid_r0, [esp+4] = mid_h
    lea eax, [edi + ebx]        ; EAX = main_col
    mov ecx, ebp
    sub ecx, ebx                ; ECX = main_w

    ; Branch on layout tier for card layout
    cmp dword [layout_tier], TIER_GRAND
    je .cards_grand
    cmp dword [layout_tier], TIER_STANDARD
    je .cards_std
    jmp .cards_compact

; -----------------------------------------------------------------------------
; Top-Level Frame Regions
; -----------------------------------------------------------------------------
.ret_header:
    add esp, 8                  ; Discard mid_r0, mid_h
    mov eax, 1                  ; Row 1
    mov ebx, edi                ; frame_c0
    mov edx, ecx                ; header_h
    mov ecx, ebp                ; frame_w
    jmp .rect_done

.ret_sidebar:
    pop eax                     ; EAX = mid_r0
    pop edx                     ; EDX = mid_h
    mov ecx, ebx                ; ECX = sidebar_w
    mov ebx, edi                ; EBX = frame_c0
    jmp .rect_done

.ret_main:
    ; EBX = sidebar_w, EDI = frame_c0, EBP = frame_w
    pop eax                     ; EAX = mid_r0
    pop edx                     ; EDX = mid_h
    add edi, ebx                ; EDI = main_col
    sub ebp, ebx                ; EBP = main_w
    mov ebx, edi
    mov ecx, ebp
    jmp .rect_done

.ret_footer:
    add esp, 8                  ; Discard mid_r0, mid_h
    mov eax, [ui_h]
    dec eax                     ; row = ui_h - 1
    mov ebx, edi                ; frame_c0
    mov ecx, ebp                ; frame_w
    mov edx, 2                  ; height = 2
    jmp .rect_done

; -----------------------------------------------------------------------------
; Card Regions - Grand Tier (Mascot Stat, Habits, Tip, Quick Journal)
; -----------------------------------------------------------------------------
.cards_grand:
    ; EAX = main_col, ECX = main_w
    ; [esp] = mid_r0, [esp+4] = mid_h
    ; Column split: pomo_w = 26, center_w = 34, journal_w = main_w - 60
    cmp esi, REGION_CARD_POMO
    je .grand_pomo
    cmp esi, REGION_CARD_HABITS
    je .grand_habits
    cmp esi, REGION_CARD_TIP
    je .grand_tip
    cmp esi, REGION_CARD_JOURNAL_BTN
    je .grand_journal_btn
    cmp esi, REGION_CARD_JOURNAL
    je .grand_journal

.grand_pomo:
    pop eax                     ; EAX = mid_r0
    pop edx                     ; EDX = mid_h
    mov ebx, edi                ; EBX = main_col
    add ebx, 28                 ; add sidebar_w
    mov ecx, 26                 ; pomo_w
    jmp .rect_done

.grand_habits:
    pop eax                     ; EAX = mid_r0
    pop edx                     ; EDX = mid_h
    shr edx, 1                  ; split_h = mid_h / 2
    mov ebx, edi
    add ebx, 28 + 26            ; main_col + pomo_w
    mov ecx, 34                 ; center_w
    jmp .rect_done

.grand_tip:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    mov ebp, edx
    shr ebp, 1                  ; split_h = mid_h / 2
    add eax, ebp                ; row = mid_r0 + split_h
    sub edx, ebp                ; height = mid_h - split_h
    mov ebx, edi
    add ebx, 28 + 26            ; main_col + pomo_w
    mov ecx, 34                 ; center_w
    jmp .rect_done

.grand_journal_btn:
    pop eax                     ; row = mid_r0
    pop edx                     ; mid_h (unused)
    mov ebx, edi
    add ebx, 28 + 26 + 34       ; main_col + pomo_w + center_w
    sub ecx, 26 + 34            ; journal_w = main_w - 60
    mov edx, 3                  ; height = 3
    jmp .rect_done

.grand_journal:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    add eax, 3                  ; row = mid_r0 + 3
    sub edx, 3                  ; height = mid_h - 3
    mov ebx, edi
    add ebx, 28 + 26 + 34       ; main_col + pomo_w + center_w
    sub ecx, 26 + 34            ; journal_w = main_w - 60
    jmp .rect_done

; -----------------------------------------------------------------------------
; Card Regions - Standard Tier
; -----------------------------------------------------------------------------
.cards_std:
    ; EAX = main_col, ECX = main_w
    ; [esp] = mid_r0, [esp+4] = mid_h
    ; Column split: pomo_w = 22, center_w = 26, journal_w = main_w - 48
    cmp esi, REGION_CARD_POMO
    je .std_pomo
    cmp esi, REGION_CARD_HABITS
    je .std_habits
    cmp esi, REGION_CARD_TIP
    je .std_tip
    cmp esi, REGION_CARD_JOURNAL_BTN
    je .std_journal_btn
    cmp esi, REGION_CARD_JOURNAL
    je .std_journal

.std_pomo:
    pop eax                     ; EAX = mid_r0
    pop edx                     ; EDX = mid_h
    mov ebx, edi
    add ebx, 26                 ; add sidebar_w
    mov ecx, 22                 ; pomo_w
    jmp .rect_done

.std_habits:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    shr edx, 1                  ; split_h = mid_h / 2
    mov ebx, edi
    add ebx, 26 + 22            ; main_col + pomo_w
    mov ecx, 26                 ; center_w
    jmp .rect_done

.std_tip:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    mov ebp, edx
    shr ebp, 1                  ; split_h
    add eax, ebp                ; row = mid_r0 + split_h
    sub edx, ebp                ; height = mid_h - split_h
    mov ebx, edi
    add ebx, 26 + 22
    mov ecx, 26
    jmp .rect_done

.std_journal_btn:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    mov ebx, edi
    add ebx, 26 + 22 + 26       ; main_col + pomo_w + center_w
    sub ecx, 22 + 26            ; journal_w = main_w - 48
    mov edx, 3                  ; height = 3
    jmp .rect_done

.std_journal:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    add eax, 3                  ; row = mid_r0 + 3
    sub edx, 3                  ; height = mid_h - 3
    mov ebx, edi
    add ebx, 26 + 22 + 26
    sub ecx, 22 + 26
    jmp .rect_done

; -----------------------------------------------------------------------------
; Card Regions - Compact Tier (2x2 Stacked Grid)
; -----------------------------------------------------------------------------
.cards_compact:
    ; EAX = main_col, ECX = main_w
    ; [esp] = mid_r0, [esp+4] = mid_h
    ; Left col: pomo (top), tip (bot)
    ; Right col: habits (top), journal_btn + journal (bot)
    mov ebp, ecx
    shr ebp, 1                  ; EBP = left_w = main_w / 2
    mov ecx, [ui_w]
    sub ecx, 22                 ; main_w
    sub ecx, ebp                ; right_w = main_w - left_w

    cmp esi, REGION_CARD_POMO
    je .cmp_pomo
    cmp esi, REGION_CARD_TIP
    je .cmp_tip
    cmp esi, REGION_CARD_HABITS
    je .cmp_habits
    cmp esi, REGION_CARD_JOURNAL_BTN
    je .cmp_journal_btn
    cmp esi, REGION_CARD_JOURNAL
    je .cmp_journal

.cmp_pomo:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    shr edx, 1                  ; split_h = mid_h / 2
    mov ebx, edi
    add ebx, 22                 ; main_col
    mov ecx, ebp                ; left_w
    jmp .rect_done

.cmp_tip:
    pop eax                     ; EAX = mid_r0
    pop edx                     ; EDX = mid_h
    mov esi, edx
    shr esi, 1                  ; ESI = split_h = mid_h / 2
    add eax, esi                ; row = mid_r0 + split_h
    sub edx, esi                ; height = mid_h - split_h
    mov ebx, edi
    add ebx, 22                 ; main_col
    mov ecx, ebp                ; left_w
    jmp .rect_done

.cmp_habits:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    shr edx, 1                  ; split_h
    mov ebx, edi
    add ebx, 22
    add ebx, ebp                ; main_col + left_w
    ; ECX already holds right_w
    jmp .rect_done

.cmp_journal_btn:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    mov esi, edx
    shr esi, 1                  ; split_h
    add eax, esi                ; row = mid_r0 + split_h
    mov ebx, edi
    add ebx, 22
    add ebx, ebp                ; main_col + 22 + left_w
    mov edx, 2                  ; height = 2
    ; ECX already holds right_w
    jmp .rect_done

.cmp_journal:
    pop eax                     ; mid_r0
    pop edx                     ; mid_h
    mov esi, edx
    shr esi, 1                  ; split_h
    add eax, esi
    add eax, 2                  ; row = mid_r0 + split_h + 2
    sub edx, esi
    sub edx, 2                  ; height = mid_h - split_h - 2
    cmp edx, 1
    jge .cmp_jrn_h_ok
    mov edx, 1
.cmp_jrn_h_ok:
    mov ebx, edi
    add ebx, 22
    add ebx, ebp                ; main_col + 22 + left_w
    ; ECX already holds right_w
    jmp .rect_done

.invalid_region:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx

.rect_done:
    pop ebp
    pop edi
    pop esi
    popf
    ret

;=============================================================================
; Procedure: layout_split_h
; Purpose:   Horizontally splits a parent rectangle into two side-by-side child
;            rectangles (left and right) with a specified gap. Guarantees safe
;            bounds and zero unsigned underflow on constrained or invalid inputs.
; IN:        ESI = Pointer to parent rectangle struct (16 bytes: row, col, w, h)
;            EDI = Pointer to child 1 rectangle buffer (16 bytes)
;            EDX = Pointer to child 2 rectangle buffer (16 bytes)
;            EAX = Requested child 1 width
;            EBX = Gap between children in cells
; OUT:       EAX = 0 on success, -1 on failure/constrained
;            Populates child 1 and child 2 rect buffers safely.
; CLOBBERS:  EAX, ECX (preserves EBX, EDX, ESI, EDI, EBP, and EFLAGS)
;=============================================================================
layout_split_h:
    pushf
    push ebx
    push edx
    push esi
    push edi
    push ebp

    ; Check for NULL pointers
    test esi, esi
    jz .split_h_fail
    test edi, edi
    jz .split_h_fail
    test edx, edx
    jz .split_h_fail

    ; Read parent dimensions
    mov ecx, [esi + RECT_W]      ; ECX = p_w
    mov ebp, [esi + RECT_H]      ; EBP = p_h

    ; Validate parent dimensions
    cmp ecx, 0
    jle .split_h_fail
    cmp ebp, 0
    jle .split_h_fail

    ; Clamp requested width and gap
    cmp eax, 0
    jge .req_w_ok
    xor eax, eax
.req_w_ok:
    cmp ebx, 0
    jge .gap_ok
    xor ebx, ebx
.gap_ok:

    ; Check if requested width exceeds parent width
    cmp eax, ecx
    jbe .req_fits
    ; Requested width too large: clamp child 1 to p_w, child 2 to 0
    mov eax, ecx
    xor ebx, ebx
.req_fits:

    ; Check if total needed (req_w + gap) exceeds parent width
    push eax
    add eax, ebx
    cmp eax, ecx
    jbe .total_fits

    ; Constrained: child 2 width is 0
    pop eax
    ; Child 1
    push dword [esi + RECT_ROW]
    pop dword [edi + RECT_ROW]
    push dword [esi + RECT_COL]
    pop dword [edi + RECT_COL]
    mov [edi + RECT_W], eax
    mov [edi + RECT_H], ebp

    ; Child 2
    push dword [esi + RECT_ROW]
    pop dword [edx + RECT_ROW]
    mov ecx, [esi + RECT_COL]
    add ecx, eax
    mov [edx + RECT_COL], ecx
    mov dword [edx + RECT_W], 0
    mov [edx + RECT_H], ebp

    mov eax, -1                 ; Status: constrained
    jmp .split_h_done

.total_fits:
    pop eax                     ; Restore req_w
    ; Child 1: (p_row, p_col, req_w, p_h)
    push dword [esi + RECT_ROW]
    pop dword [edi + RECT_ROW]
    push dword [esi + RECT_COL]
    pop dword [edi + RECT_COL]
    mov [edi + RECT_W], eax
    mov [edi + RECT_H], ebp

    ; Child 2: (p_row, p_col + req_w + gap, p_w - req_w - gap, p_h)
    push dword [esi + RECT_ROW]
    pop dword [edx + RECT_ROW]
    mov ecx, [esi + RECT_COL]
    add ecx, eax
    add ecx, ebx
    mov [edx + RECT_COL], ecx

    mov ecx, [esi + RECT_W]
    sub ecx, eax
    sub ecx, ebx
    mov [edx + RECT_W], ecx
    mov [edx + RECT_H], ebp

    xor eax, eax                ; Status: 0 = success
    jmp .split_h_done

.split_h_fail:
    ; Zero out both children on fatal error
    test edi, edi
    jz .zero_ch2
    mov dword [edi + RECT_ROW], 0
    mov dword [edi + RECT_COL], 0
    mov dword [edi + RECT_W], 0
    mov dword [edi + RECT_H], 0
.zero_ch2:
    test edx, edx
    jz .fail_exit
    mov dword [edx + RECT_ROW], 0
    mov dword [edx + RECT_COL], 0
    mov dword [edx + RECT_W], 0
    mov dword [edx + RECT_H], 0
.fail_exit:
    mov eax, -1

.split_h_done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ebx
    popf
    ret

;=============================================================================
; Procedure: layout_split_v
; Purpose:   Vertically splits a parent rectangle into two stacked child
;            rectangles (top and bottom) with a specified gap. Guarantees safe
;            bounds and zero unsigned underflow on constrained or invalid inputs.
; IN:        ESI = Pointer to parent rectangle struct (16 bytes: row, col, w, h)
;            EDI = Pointer to child 1 rectangle buffer (16 bytes)
;            EDX = Pointer to child 2 rectangle buffer (16 bytes)
;            EAX = Requested child 1 height
;            EBX = Gap between children in rows
; OUT:       EAX = 0 on success, -1 on failure/constrained
;            Populates child 1 and child 2 rect buffers safely.
; CLOBBERS:  EAX, ECX (preserves EBX, EDX, ESI, EDI, EBP, and EFLAGS)
;=============================================================================
layout_split_v:
    pushf
    push ebx
    push edx
    push esi
    push edi
    push ebp

    ; Check for NULL pointers
    test esi, esi
    jz .split_v_fail
    test edi, edi
    jz .split_v_fail
    test edx, edx
    jz .split_v_fail

    ; Read parent dimensions
    mov ecx, [esi + RECT_W]      ; ECX = p_w
    mov ebp, [esi + RECT_H]      ; EBP = p_h

    ; Validate parent dimensions
    cmp ecx, 0
    jle .split_v_fail
    cmp ebp, 0
    jle .split_v_fail

    ; Clamp requested height and gap
    cmp eax, 0
    jge .req_h_ok
    xor eax, eax
.req_h_ok:
    cmp ebx, 0
    jge .gap_v_ok
    xor ebx, ebx
.gap_v_ok:

    ; Check if requested height exceeds parent height
    cmp eax, ebp
    jbe .req_h_fits
    mov eax, ebp
    xor ebx, ebx
.req_h_fits:

    ; Check if total needed (req_h + gap) exceeds parent height
    push eax
    add eax, ebx
    cmp eax, ebp
    jbe .total_v_fits

    ; Constrained: child 2 height is 0
    pop eax
    ; Child 1
    push dword [esi + RECT_ROW]
    pop dword [edi + RECT_ROW]
    push dword [esi + RECT_COL]
    pop dword [edi + RECT_COL]
    mov [edi + RECT_W], ecx
    mov [edi + RECT_H], eax

    ; Child 2
    mov ebp, [esi + RECT_ROW]
    add ebp, eax
    mov [edx + RECT_ROW], ebp
    push dword [esi + RECT_COL]
    pop dword [edx + RECT_COL]
    mov [edx + RECT_W], ecx
    mov dword [edx + RECT_H], 0

    mov eax, -1                 ; Status: constrained
    jmp .split_v_done

.total_v_fits:
    pop eax                     ; Restore req_h
    ; Child 1: (p_row, p_col, p_w, req_h)
    push dword [esi + RECT_ROW]
    pop dword [edi + RECT_ROW]
    push dword [esi + RECT_COL]
    pop dword [edi + RECT_COL]
    mov [edi + RECT_W], ecx
    mov [edi + RECT_H], eax

    ; Child 2: (p_row + req_h + gap, p_col, p_w, p_h - req_h - gap)
    mov ebp, [esi + RECT_ROW]
    add ebp, eax
    add ebp, ebx
    mov [edx + RECT_ROW], ebp
    push dword [esi + RECT_COL]
    pop dword [edx + RECT_COL]
    mov [edx + RECT_W], ecx

    mov ebp, [esi + RECT_H]
    sub ebp, eax
    sub ebp, ebx
    mov [edx + RECT_H], ebp

    xor eax, eax                ; Status: 0 = success
    jmp .split_v_done

.split_v_fail:
    ; Zero out both children on fatal error
    test edi, edi
    jz .zero_v_ch2
    mov dword [edi + RECT_ROW], 0
    mov dword [edi + RECT_COL], 0
    mov dword [edi + RECT_W], 0
    mov dword [edi + RECT_H], 0
.zero_v_ch2:
    test edx, edx
    jz .fail_v_exit
    mov dword [edx + RECT_ROW], 0
    mov dword [edx + RECT_COL], 0
    mov dword [edx + RECT_W], 0
    mov dword [edx + RECT_H], 0
.fail_v_exit:
    mov eax, -1

.split_v_done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ebx
    popf
    ret
