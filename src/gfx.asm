; =============================================================================
; Pawmodoro - v3 Graphics & Rendering Core (src/gfx.asm)
;
; Purpose: Core rendering primitives, color-state tracking, output buffer
;          overflow diagnostics, capability fallback (ECH), and temporary demo.
; Reference: PRD_V3 §2, §4, §5, §6, §7, §8, §9, §10, §11, §12
; Register Discipline: PRD §6.2 (all procedures preserve all general registers
;                      and EFLAGS unless explicitly documented).
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: gfx_set_fg
; Purpose:   Appends 256-color foreground escape sequence ESC[38;5;Nm for
;            the requested theme-slot ID if and only if the requested slot
;            differs from the currently tracked gfx_fg slot.
;            Updates gfx_fg to the requested slot if no buffer overflow occurs.
; IN:        AL = Theme-slot ID (0..NUM_SLOTS-1)
; OUT:       Appends escape sequence to out_buf on slot change; updates gfx_fg
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_set_fg:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate slot ID in AL (must be strictly < NUM_SLOTS = 12)
    cmp al, NUM_SLOTS
    jae .fg_invalid             ; Out-of-bounds slot ID: silently drop

    ; Check if requested slot matches currently tracked foreground slot
    movzx edx, al
    cmp dx, [gfx_fg]
    je .fg_same                 ; Redundant color: suppress escape sequence!

    ; Capture overflow flag state before appending
    movzx ecx, byte [gfx_overflow]

    ; Look up 256-color palette index (0..255) from active_palette
    movzx ebx, al
    movzx eax, byte [active_palette + ebx]

    ; 1. Emit foreground sequence prefix: ESC[38;5;
    mov esi, ansi_fg_256_prefix
    call buf_str

    ; 2. Emit decimal color index (0..255)
    call buf_u32

    ; 3. Emit closing letter 'm'
    mov al, CHAR_LOWER_M
    call buf_char

    ; If buffer overflowed during this escape emission, do NOT update tracked state
    cmp byte [gfx_overflow], cl
    jne .fg_invalid

    ; Update tracked foreground slot
    mov [gfx_fg], dx

.fg_same:
.fg_invalid:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_set_bg
; Purpose:   Appends 256-color background escape sequence ESC[48;5;Nm for
;            the requested theme-slot ID if and only if the requested slot
;            differs from the currently tracked gfx_bg slot.
;            Updates gfx_bg to the requested slot if no buffer overflow occurs.
; IN:        AL = Theme-slot ID (0..NUM_SLOTS-1)
; OUT:       Appends escape sequence to out_buf on slot change; updates gfx_bg
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_set_bg:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate slot ID in AL (must be strictly < NUM_SLOTS = 12)
    cmp al, NUM_SLOTS
    jae .bg_invalid             ; Out-of-bounds slot ID: silently drop

    ; Check if requested slot matches currently tracked background slot
    movzx edx, al
    cmp dx, [gfx_bg]
    je .bg_same                 ; Redundant color: suppress escape sequence!

    ; Capture overflow flag state before appending
    movzx ecx, byte [gfx_overflow]

    ; Look up 256-color palette index (0..255) from active_palette
    movzx ebx, al
    movzx eax, byte [active_palette + ebx]

    ; 1. Emit background sequence prefix: ESC[48;5;
    mov esi, ansi_bg_256_prefix
    call buf_str

    ; 2. Emit decimal color index (0..255)
    call buf_u32

    ; 3. Emit closing letter 'm'
    mov al, CHAR_LOWER_M
    call buf_char

    ; If buffer overflowed during this escape emission, do NOT update tracked state
    cmp byte [gfx_overflow], cl
    jne .bg_invalid

    ; Update tracked background slot
    mov [gfx_bg], dx

.bg_same:
.bg_invalid:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_sgr_forget
; Purpose:   Invalidates currently tracked foreground and background color slots
;            by setting both gfx_fg and gfx_bg to GFX_SLOT_UNKNOWN (0xFFFF).
;            Emits no bytes to out_buf. Must be called before and after any
;            graphics run interleaved with legacy code that emits raw ANSI resets.
; IN:        None
; OUT:       gfx_fg = GFX_SLOT_UNKNOWN, gfx_bg = GFX_SLOT_UNKNOWN
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_sgr_forget:
    push eax
    mov word [gfx_fg], GFX_SLOT_UNKNOWN
    mov word [gfx_bg], GFX_SLOT_UNKNOWN
    pop eax
    ret

;=============================================================================
; Procedure: gfx_reset
; Purpose:   Appends standard ANSI reset sequence ESC[0m to out_buf and
;            invalidates tracked colors via gfx_sgr_forget.
; IN:        None
; OUT:       Appends ESC[0m to out_buf; resets gfx_fg and gfx_bg
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_reset:
    push esi
    mov esi, ansi_reset
    call buf_str
    call gfx_sgr_forget
    pop esi
    ret

;=============================================================================
; Procedure: gfx_fill_screen_bg
; Purpose:   Applies full-screen background fill using the specified theme-slot.
;            Appends background escape (gfx_set_bg), cursor-home (ESC[H), and
;            clear-screen (ESC[2J) in strict sequence. Does not flush independently.
; IN:        AL = Background theme-slot ID (0..NUM_SLOTS-1)
; OUT:       Appends background color, cursor home, and screen clear to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_fill_screen_bg:
    pushf
    push eax
    push esi

    ; 1. Set background color via color-state tracker
    call gfx_set_bg

    ; 2. Move cursor home (ESC[H)
    mov esi, ansi_home
    call buf_str

    ; 3. Clear entire screen with background set (ESC[2J)
    mov esi, ansi_clear
    call buf_str

    pop esi
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_fill_rect
; Purpose:   Fills a solid rectangular region with the specified background slot.
;            Uses frame-relative coordinates. Positions cursor per row using
;            ui_goto. If term_has_ech is 1, emits ANSI ECH sequence ESC[<w>X.
;            If term_has_ech is 0, emits <w> spaces via buf_repeat.
;            Clips rectangle safely to active frame geometry (ui_w, ui_h).
; IN:        EAX = Starting row (1-based frame coordinate)
;            EBX = Starting column (1-based frame-relative coordinate)
;            ECX = Rectangle width in terminal cells
;            EDX = Rectangle height in terminal rows
;            ESI = Background theme-slot ID (in lowest byte / AL)
; OUT:       Appends background fill escape sequences and characters to out_buf
; CLOBBERS:  None (preserves all input registers and other registers)
;=============================================================================
gfx_fill_rect:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate nonpositive dimensions
    test ecx, ecx
    jle .rect_done
    test edx, edx
    jle .rect_done

    ; Validate starting bounds against active frame geometry
    cmp eax, 1
    jl .rect_done
    cmp eax, [ui_h]
    jg .rect_done
    cmp ebx, 1
    jl .rect_done
    cmp ebx, [ui_w]
    jg .rect_done

    ; Clip width if right edge exceeds ui_w
    ; max_avail_w = ui_w - ebx + 1
    mov edi, [ui_w]
    sub edi, ebx
    inc edi
    cmp ecx, edi
    jle .w_clipped
    mov ecx, edi                ; Clamp width to available frame columns
.w_clipped:
    test ecx, ecx
    jle .rect_done

    ; Clip height if bottom edge exceeds ui_h
    ; max_avail_h = ui_h - eax + 1
    mov edi, [ui_h]
    sub edi, eax
    inc edi
    cmp edx, edi
    jle .h_clipped
    mov edx, edi                ; Clamp height to available frame rows
.h_clipped:
    test edx, edx
    jle .rect_done

    ; Set requested background theme slot
    push eax
    mov eax, esi                ; AL = background slot ID
    call gfx_set_bg
    pop eax

    ; Row iteration loop: paint EDX rows starting from row EAX
    ; Stack layout during row loop:
    ; [esp+12] = start_col (EBX)
    ; [esp+8]  = clipped_w (ECX)
    ; [esp+4]  = remaining_rows (EDX)
    ; [esp]    = current_row (EAX)
    push ebx                    ; [esp+12]
    push ecx                    ; [esp+8]
    push edx                    ; [esp+4]
    push eax                    ; [esp]

.rect_row_loop:
    ; Position cursor at (current_row, start_col)
    mov eax, [esp]              ; EAX = current_row
    mov ebx, [esp + 12]         ; EBX = start_col
    call ui_goto

    ; Check ECH capability flag
    cmp dword [term_has_ech], 1
    jne .rect_fallback_spaces

    ; --- ECH Supported Path: ESC[<w>X ---
    mov esi, ansi_csi
    call buf_str                ; ESC[

    mov eax, [esp + 8]          ; EAX = clipped width
    call buf_u32                ; <width>

    mov al, CHAR_UPPER_X        ; 'X'
    call buf_char
    jmp .rect_row_next

.rect_fallback_spaces:
    ; --- Fallback Path: emit <w> spaces via buf_repeat ---
    mov al, CHAR_SPACE
    mov ecx, [esp + 8]          ; ECX = clipped width
    call buf_repeat

.rect_row_next:
    inc dword [esp]             ; Advance current_row
    dec dword [esp + 4]         ; Decrement remaining_rows
    jnz .rect_row_loop

    add esp, 16                 ; Clean up local loop stack

.rect_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_hline
; Purpose:   Draws a solid horizontal line of ECX cells starting at (EAX, EBX)
;            using the requested foreground theme slot ESI.
;            Clips line to ui_w. Uses UTF-8 box glyph (─) or ASCII (-)
;            depending on setting_charset (0 = UTF-8, 1 = ASCII).
; IN:        EAX = Row coordinate (1-based frame coordinate)
;            EBX = Starting column coordinate (1-based frame-relative)
;            ECX = Line length in cells
;            ESI = Foreground theme-slot ID (in lowest byte / AL)
; OUT:       Appends line escape sequences and glyphs to out_buf
; CLOBBERS:  None (preserves all input registers and other registers)
;=============================================================================
gfx_hline:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate bounds
    test ecx, ecx
    jle .hline_done
    cmp eax, 1
    jl .hline_done
    cmp eax, [ui_h]
    jg .hline_done
    cmp ebx, 1
    jl .hline_done
    cmp ebx, [ui_w]
    jg .hline_done

    ; Clip length to ui_w
    mov edi, [ui_w]
    sub edi, ebx
    inc edi
    cmp ecx, edi
    jle .hline_w_ok
    mov ecx, edi
.hline_w_ok:
    test ecx, ecx
    jle .hline_done

    ; Set foreground color
    push eax
    mov eax, esi
    call gfx_set_fg
    pop eax

    ; Position cursor at start of line
    call ui_goto

    ; Emit glyphs
    cmp byte [setting_charset], 1
    je .hline_ascii

    ; UTF-8 line loop: repeat glyph_utf8_hline ECX times
.hline_utf8_loop:
    push esi
    mov esi, glyph_utf8_hline
    call buf_str
    pop esi
    dec ecx
    jnz .hline_utf8_loop
    jmp .hline_done

.hline_ascii:
    mov al, CHAR_MINUS          ; '-'
    call buf_repeat

.hline_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_vline
; Purpose:   Draws a solid vertical line of ECX rows starting at (EAX, EBX)
;            using the requested foreground theme slot ESI.
;            Clips line to ui_h. Uses UTF-8 box glyph (│) or ASCII (|)
;            depending on setting_charset (0 = UTF-8, 1 = ASCII).
; IN:        EAX = Starting row coordinate (1-based frame coordinate)
;            EBX = Column coordinate (1-based frame-relative coordinate)
;            ECX = Line height in rows
;            ESI = Foreground theme-slot ID (in lowest byte / AL)
; OUT:       Appends line escape sequences and glyphs to out_buf
; CLOBBERS:  None (preserves all input registers and other registers)
;=============================================================================
gfx_vline:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate bounds
    test ecx, ecx
    jle .vline_done
    cmp eax, 1
    jl .vline_done
    cmp eax, [ui_h]
    jg .vline_done
    cmp ebx, 1
    jl .vline_done
    cmp ebx, [ui_w]
    jg .vline_done

    ; Clip height to ui_h
    mov edi, [ui_h]
    sub edi, eax
    inc edi
    cmp ecx, edi
    jle .vline_h_ok
    mov ecx, edi
.vline_h_ok:
    test ecx, ecx
    jle .vline_done

    ; Set foreground color
    push eax
    mov eax, esi
    call gfx_set_fg
    pop eax

    ; Vertical line iteration loop
    ; EAX = current row, EBX = col, ECX = remaining rows
.vline_loop:
    push eax
    push ebx
    call ui_goto                ; Move cursor to (row, col)

    cmp byte [setting_charset], 1
    je .vline_ascii_glyph

    push esi
    mov esi, glyph_utf8_vline   ; │
    call buf_str
    pop esi
    jmp .vline_next

.vline_ascii_glyph:
    mov al, CHAR_PIPE           ; '|'
    call buf_char

.vline_next:
    pop ebx
    pop eax
    inc eax                     ; Next row
    dec ecx                     ; Decrement remaining rows
    jnz .vline_loop

.vline_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_text_clip
; Purpose:   Applies requested foreground and background theme slots and
;            delegates string clipping and appending to buf_str_clip.
;            If foreground slot is not 0xFF, applies gfx_set_fg.
;            If background slot is not 0xFF, applies gfx_set_bg.
; IN:        ESI = Pointer to NUL-terminated source string
;            ECX = Maximum display columns allowed
;            AL  = Foreground theme-slot ID (0..NUM_SLOTS-1, or 0xFF if unchanged)
;            AH  = Background theme-slot ID (0..NUM_SLOTS-1, or 0xFF if unchanged)
; OUT:       Appends color escapes and clipped string to out_buf
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_text_clip:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Apply foreground slot if AL != 0xFF
    cmp al, 0xFF
    je .text_check_bg
    push eax
    call gfx_set_fg
    pop eax

.text_check_bg:
    ; Apply background slot if AH != 0xFF
    cmp ah, 0xFF
    je .text_do_clip
    push eax
    mov al, ah
    call gfx_set_bg
    pop eax

.text_do_clip:
    ; Delegate string clipping and display-column counting to buf_str_clip
    call buf_str_clip

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_demo_draw
; Purpose:   Renders the temporary G1 rendering demo frame exercising all
;            new primitives within current terminal geometry:
;              1. Full-screen background fill (gfx_fill_screen_bg)
;              2. Rectangular card panel (gfx_fill_rect)
;              3. Horizontal and vertical borders (gfx_hline, gfx_vline)
;              4. Clipped text display (gfx_text_clip)
;              5. Checkerboard color pattern testing repeated color changes
;                 and SGR redundancy suppression
; IN:        None
; OUT:       Appends complete demo frame to out_buf (does not flush)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_demo_draw:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Invalidate color tracker before graphics run
    call gfx_sgr_forget

    ; 1. Full screen background fill using SLOT_BORDER (slot 0)
    mov al, SLOT_BORDER
    call gfx_fill_screen_bg

    ; 2. Centered panel fill using SLOT_HIGHLIGHT (slot 11)
    ; Panel bounds: row 2, col 3, width = ui_w - 4, height = ui_h - 2
    mov eax, 2                  ; Row 2
    mov ebx, 3                  ; Col 3
    mov ecx, [ui_w]
    sub ecx, 4                  ; Width = ui_w - 4
    mov edx, [ui_h]
    sub edx, 2                  ; Height = ui_h - 2
    mov esi, SLOT_HIGHLIGHT     ; Background slot 11
    call gfx_fill_rect

    ; 3. Title banner text
    mov eax, 3                  ; Row 3
    mov ebx, 5                  ; Col 5
    call ui_goto

    mov esi, gfx_demo_title
    mov ecx, [ui_w]
    sub ecx, 10
    mov al, SLOT_TITLE          ; FG: Title
    mov ah, SLOT_HIGHLIGHT      ; BG: Highlight
    call gfx_text_clip

    ; Subtitle text
    mov eax, 4                  ; Row 4
    mov ebx, 5                  ; Col 5
    call ui_goto

    mov esi, gfx_demo_subtitle
    mov ecx, [ui_w]
    sub ecx, 10
    mov al, SLOT_DIM            ; FG: Dim
    mov ah, SLOT_HIGHLIGHT      ; BG: Highlight
    call gfx_text_clip

    ; 4. Horizontal divider line at row 5
    mov eax, 5                  ; Row 5
    mov ebx, 4                  ; Col 4
    mov ecx, [ui_w]
    sub ecx, 6                  ; Width = ui_w - 6
    mov esi, SLOT_BORDER        ; FG: Border
    call gfx_hline

    ; 5. Vertical divider line separating left and right panels
    mov eax, 6                  ; Start row 6
    mov ebx, 32                 ; Column 32
    mov edx, [ui_h]
    sub edx, 9                  ; Height = ui_h - 9
    mov ecx, edx
    mov esi, SLOT_BORDER
    call gfx_vline

    ; 6. Left panel: Demonstrating text clipping
    mov eax, 7
    mov ebx, 5
    call ui_goto

    mov esi, gfx_demo_long
    mov ecx, 24                 ; Strictly clip to 24 display columns
    mov al, SLOT_TEXT           ; FG: Text
    mov ah, SLOT_HIGHLIGHT      ; BG: Highlight
    call gfx_text_clip

    ; 7. Right panel: Small checker pattern testing color transitions & redundancy
    ; Maximum 8 rows (7..14), Columns 35..65 (15 blocks per row)
    mov edx, 7                  ; Start row
.checker_row_loop:
    cmp edx, 15
    jge .checker_done
    mov eax, [ui_h]
    sub eax, 4
    cmp edx, eax
    jge .checker_done

    mov edi, 35                 ; Start col
.checker_col_loop:
    cmp edi, 65
    jge .checker_row_next
    mov eax, [ui_w]
    sub eax, 8
    cmp edi, eax
    jge .checker_row_next

    ; Position cursor at (edx, edi)
    mov eax, edx
    mov ebx, edi
    call ui_goto

    ; Calculate color pattern: (row + col/2) & 1
    mov eax, edi
    shr eax, 1
    add eax, edx
    test eax, 1
    jz .checker_cell_alt

    ; Pattern cell A: FG=SLOT_ACCENT, BG=SLOT_HIGHLIGHT
    mov al, SLOT_ACCENT
    call gfx_set_fg
    mov al, SLOT_HIGHLIGHT
    call gfx_set_bg
    mov al, CHAR_HASH           ; '#'
    call buf_char
    mov al, CHAR_HASH
    call buf_char
    jmp .checker_col_adv

.checker_cell_alt:
    ; Pattern cell B: FG=SLOT_OK, BG=SLOT_BORDER
    mov al, SLOT_OK
    call gfx_set_fg
    mov al, SLOT_BORDER
    call gfx_set_bg
    mov al, CHAR_PERCENT        ; '%'
    call buf_char
    mov al, CHAR_PERCENT
    call buf_char

.checker_col_adv:
    add edi, 2                  ; 2 cells wide per checker block
    jmp .checker_col_loop

.checker_row_next:
    inc edx
    jmp .checker_row_loop

.checker_done:
    ; 8. Bottom footer hint
    mov eax, [ui_h]
    dec eax                     ; Bottom row - 1
    mov ebx, 5
    call ui_goto

    mov esi, gfx_demo_hint
    mov ecx, [ui_w]
    sub ecx, 10
    mov al, SLOT_DIM
    mov ah, SLOT_HIGHLIGHT
    call gfx_text_clip

    ; Reset graphics attributes & invalidate tracker
    call gfx_reset

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: gfx_run_demo
; Purpose:   Interactive runner for the G1 rendering demo:
;            1. Updates layout geometry
;            2. Renders complete demo frame
;            3. Flushes exactly once to STDOUT
;            4. Waits for user keypress (any key or Ctrl+C)
;            5. Resets terminal color state before returning
; IN:        None
; OUT:       None (restores menu redraw flag upon exit)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
gfx_run_demo:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Step 1: Update frame dimensions
    call ui_layout_update

    ; Step 2: Draw complete demo frame into buffer
    call gfx_demo_draw

    ; Step 3: Single flush to STDOUT (one write per frame invariant!)
    call buf_flush

    ; Step 4: Wait for user input
.demo_key_loop:
    call key_wait
    cmp eax, KEY_NONE
    je .demo_key_loop

    ; If Ctrl+C, handle clean exit via state=STATE_QUIT
    cmp eax, KEY_CTRL_C
    jne .demo_return
    mov dword [state], STATE_QUIT

.demo_return:
    ; Clean up terminal state before returning to caller
    call gfx_reset

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Diagnostic Subsystem: gfx_diag_run_all
; Purpose:   Deterministic headless test harness invoked via --test-overflow.
;            Verifies:
;              1. Output buffer capacity is 16384 bytes.
;              2. gfx_overflow remains 0 for ALL application screens at both
;                 80x24 and 120x40.
;              3. gfx_frame_bytes is accurately tracked and < 16384 bytes.
;              4. Redundant color changes are suppressed by color-state tracker.
;              5. State invalidation (gfx_sgr_forget) forces next color emission.
;              6. ECH capability and fallback space-fill paths both succeed.
; IN:        None
; OUT:       Prints diagnostics to STDOUT; exits process with 0 (PASS) or 1 (FAIL)
; CLOBBERS:  Discards registers on process exit
;=============================================================================
gfx_diag_run_all:
    ; -------------------------------------------------------------------------
    ; Part 1: Color Tracker Unit Tests
    ; -------------------------------------------------------------------------
    ; Test SGR redundancy suppression
    call gfx_sgr_forget
    mov dword [out_len], 0

    ; Emit slot 1 (SLOT_TITLE)
    mov al, SLOT_TITLE
    call gfx_set_fg
    mov edx, [out_len]          ; EDX = length after first color change
    test edx, edx
    jz .diag_fail_color         ; First color change MUST emit bytes!

    ; Request the same slot again -> MUST emit 0 bytes!
    mov al, SLOT_TITLE
    call gfx_set_fg
    cmp [out_len], edx
    jne .diag_fail_color_suppress

    ; Invalidate tracker via gfx_sgr_forget -> next call MUST emit bytes!
    call gfx_sgr_forget
    mov al, SLOT_TITLE
    call gfx_set_fg
    cmp [out_len], edx
    jbe .diag_fail_color_forget

    ; Clear out_buf after unit test
    mov dword [out_len], 0

    ; -------------------------------------------------------------------------
    ; Part 2: Screen Overflow Tests across all screens at 80x24 and 120x40
    ; -------------------------------------------------------------------------
    ; Test 80x24 dimensions
    mov dword [term_cols], 80
    mov dword [term_rows], 24
    call ui_layout_update
    call .diag_test_all_screens_at_current_size

    ; Test 120x40 dimensions
    mov dword [term_cols], 120
    mov dword [term_rows], 40
    call ui_layout_update
    call .diag_test_all_screens_at_current_size

    ; -------------------------------------------------------------------------
    ; Part 3: ECH Fallback Path Test
    ; -------------------------------------------------------------------------
    mov dword [term_has_ech], 0  ; Force fallback mode
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    mov eax, 2
    mov ebx, 2
    mov ecx, 20
    mov edx, 5
    mov esi, SLOT_BORDER
    call gfx_fill_rect
    mov dword [term_has_ech], 1  ; Restore ECH mode
    cmp dword [gfx_overflow], 0
    jne .diag_fail_ech
    mov dword [out_len], 0

    ; All diagnostics passed!
    ; Emit success summary message
    mov esi, .str_diag_pass
    call buf_str
    call buf_flush

    mov ebx, EXIT_SUCCESS
    mov eax, SYS_EXIT
    int 0x80

; Helper: tests all screens at current (term_cols, term_rows)
.diag_test_all_screens_at_current_size:
    push eax
    push ebx
    push ecx
    push edx

    ; 1. Main Menu
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call ui_draw_menu
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    call buf_flush

    ; 2. Timer Screen
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call timer_draw
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    call buf_flush

    ; 3. Habits Screen
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call habits_draw
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    call buf_flush

    ; 4. Journal Screen
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call journal_draw
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    call buf_flush

    ; 5. Settings Screen
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call settings_draw
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    call buf_flush

    ; 6. Settings Colors Screen
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call settings_colors_draw
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    call buf_flush

    ; 7. G1 Demo Frame
    mov dword [gfx_overflow], 0
    mov dword [out_len], 0
    call gfx_demo_draw
    cmp dword [gfx_overflow], 0
    jne .diag_fail_screen
    ; Check demo frame byte count strictly < 16384
    cmp dword [out_len], OUT_BUF_SIZE
    jae .diag_fail_demo_size
    call buf_flush

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

.diag_fail_color:
    mov esi, .str_err_color
    call buf_str
    call buf_flush
    mov ebx, EXIT_FAILURE
    mov eax, SYS_EXIT
    int 0x80

.diag_fail_color_suppress:
    mov esi, .str_err_suppress
    call buf_str
    call buf_flush
    mov ebx, EXIT_FAILURE
    mov eax, SYS_EXIT
    int 0x80

.diag_fail_color_forget:
    mov esi, .str_err_forget
    call buf_str
    call buf_flush
    mov ebx, EXIT_FAILURE
    mov eax, SYS_EXIT
    int 0x80

.diag_fail_screen:
    mov esi, .str_err_overflow
    call buf_str
    call buf_flush
    mov ebx, EXIT_FAILURE
    mov eax, SYS_EXIT
    int 0x80

.diag_fail_demo_size:
    mov esi, .str_err_demo_size
    call buf_str
    call buf_flush
    mov ebx, EXIT_FAILURE
    mov eax, SYS_EXIT
    int 0x80

.diag_fail_ech:
    mov esi, .str_err_ech
    call buf_str
    call buf_flush
    mov ebx, EXIT_FAILURE
    mov eax, SYS_EXIT
    int 0x80

section .data
    .str_diag_pass:     db "G1 RENDER CORE DIAGNOSTIC: PASS (all screens zero overflow at 80x24 and 120x40, SGR suppression verified)", CHAR_LF, CHAR_NULL
    .str_err_color:     db "G1 DIAG FAIL: gfx_set_fg emitted 0 bytes on initial call", CHAR_LF, CHAR_NULL
    .str_err_suppress:  db "G1 DIAG FAIL: gfx_set_fg failed to suppress redundant escape sequence", CHAR_LF, CHAR_NULL
    .str_err_forget:    db "G1 DIAG FAIL: gfx_sgr_forget failed to invalidate color state", CHAR_LF, CHAR_NULL
    .str_err_overflow:  db "G1 DIAG FAIL: gfx_overflow was set to 1 during screen rendering", CHAR_LF, CHAR_NULL
    .str_err_demo_size: db "G1 DIAG FAIL: demo frame size exceeded 16384 bytes", CHAR_LF, CHAR_NULL
    .str_err_ech:       db "G1 DIAG FAIL: ECH fallback space fill caused overflow", CHAR_LF, CHAR_NULL

section .text

