; =============================================================================
; Pawmodoro - Lightweight Event-Driven Animation Engine (src/anim.asm)
;
; Purpose: Event-driven animation engine, 10 Hz non-blocking tick processing,
;          32-bit integer LCG pseudo-random generator, partial-region redraws,
;          particle simulation (confetti, heart-pop, break zZ), cat idle/work
;          animations, and title color wave conforming to PRD_V2 §8, §13.5, §14.
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: anim_init
; Purpose:   Initializes the animation subsystem during application startup:
;            1. Seeds the 32-bit integer LCG PRNG via time_now.
;               If time_now fails (<= 0), uses ANIM_PRNG_FALLBACK_SEED.
;            2. Zeroes frame counter, write-throttle counter, and dirty flags.
;            3. Invokes anim_reset_effects to establish clean initial states.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
anim_init:
    save_regs

    ; Seed PRNG from current Unix timestamp
    call time_now               ; EAX = Unix timestamp or <= 0 on error
    cmp eax, 0
    jle .seed_fallback
    mov [anim_prng_seed], eax
    jmp .init_counters

.seed_fallback:
    mov dword [anim_prng_seed], ANIM_PRNG_FALLBACK_SEED

.init_counters:
    mov dword [anim_frame_count], 0
    mov dword [anim_throttle_count], 0
    mov dword [anim_dirty_flags], 0
    call anim_reset_effects

    restore_regs
    ret

;=============================================================================
; Procedure: anim_rand
; Purpose:   Generates the next 32-bit pseudo-random unsigned integer using an
;            integer-only Linear Congruential Generator (LCG):
;            state = (state * 1664525 + 1013904223) mod 2^32.
;            Uses 32-bit MUL; the high 32 bits in EDX are discarded, preserving
;            low 32-bit overflow behavior. If state becomes zero, it resets to
;            ANIM_PRNG_FALLBACK_SEED to maintain a non-degenerate sequence.
; IN:        None (reads and updates anim_prng_seed in memory)
; OUT:       EAX = Next 32-bit pseudo-random value
; CLOBBERS:  EAX (all other registers preserved)
;=============================================================================
anim_rand:
    push edx

    mov eax, [anim_prng_seed]
    mov edx, ANIM_PRNG_MULT     ; 1664525
    mul edx                     ; EDX:EAX = state * MULT
    add eax, ANIM_PRNG_INC      ; EAX = (state * MULT + INC) mod 2^32
    test eax, eax
    jnz .rand_store
    mov eax, ANIM_PRNG_FALLBACK_SEED

.rand_store:
    mov [anim_prng_seed], eax
    pop edx
    ret

;=============================================================================
; Procedure: anim_reset_effects
; Purpose:   Resets all transient animation effects, deactivates active particles,
;            and zeroes dirty flags without performing I/O. Used on screen transitions,
;            phase skips/stops, and when entering Reduce motion.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_reset_effects:
    save_regs

    mov dword [anim_dirty_flags], 0
    mov dword [anim_cat_blink_state], 0
    mov dword [anim_cat_tail_state], 0
    mov dword [anim_title_wave_offset], 0
    mov dword [anim_star_twinkle_state], 0
    mov dword [anim_shimmer_pos], 0
    mov dword [anim_zz_phase], 0
    mov dword [anim_zz_old_x], 0
    mov dword [anim_zz_old_y], 0
    mov dword [heart_pop_active], 0
    mov dword [heart_pop_old_x], 0
    mov dword [heart_pop_old_y], 0
    mov dword [heart_pop_life], 0

    ; Deactivate all confetti particles
    mov ecx, CONFETTI_MAX
    mov edi, anim_confetti_particles
.clear_confetti_loop:
    mov dword [edi + PARTICLE_OFF_ACTIVE], 0
    mov dword [edi + PARTICLE_OFF_OLD_X], 0
    mov dword [edi + PARTICLE_OFF_OLD_Y], 0
    add edi, PARTICLE_SIZE
    dec ecx
    jnz .clear_confetti_loop

    restore_regs
    ret

;=============================================================================
; Procedure: anim_on_focus_complete
; Purpose:   Initializes the confetti particle burst (~20 particles) upon natural
;            completion of a Pomodoro focus phase. Positions particles within
;            the timer frame (rows 3..5, cols 10..55) with initial upward
;            velocities and pseudo-random colors and glyphs.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_on_focus_complete:
    save_regs

    ; If Reduce motion is active, do not spawn particles
    cmp byte [setting_anim], 1
    jne .confetti_init_done

    mov ecx, CONFETTI_MAX
    mov edi, anim_confetti_particles

.confetti_spawn_loop:
    push ecx

    ; Set active flag and zero old coordinates
    mov dword [edi + PARTICLE_OFF_ACTIVE], 1
    mov dword [edi + PARTICLE_OFF_OLD_X], 0
    mov dword [edi + PARTICLE_OFF_OLD_Y], 0

    ; X coordinate: 12 + (anim_rand % 46) -> 12..57
    call anim_rand
    xor edx, edx
    mov ebx, 46
    div ebx                     ; EDX = 0..45
    add edx, 12
    mov [edi + PARTICLE_OFF_X], edx

    ; Y coordinate: 3 + (anim_rand % 3) -> 3..5
    call anim_rand
    xor edx, edx
    mov ebx, 3
    div ebx                     ; EDX = 0..2
    add edx, 3
    mov [edi + PARTICLE_OFF_Y], edx

    ; Horizontal drift VX: (anim_rand % 3) - 1 -> -1, 0, +1
    call anim_rand
    xor edx, edx
    mov ebx, 3
    div ebx
    dec edx                     ; EDX = -1..+1
    mov [edi + PARTICLE_OFF_VX], edx

    ; Vertical initial velocity VY: -1 (upward pop)
    mov dword [edi + PARTICLE_OFF_VY], -1

    ; Lifetime: 14 + (anim_rand % 12) -> 14..25 ticks (1.4..2.5s)
    call anim_rand
    xor edx, edx
    mov ebx, 12
    div ebx
    add edx, 14
    mov [edi + PARTICLE_OFF_LIFE], edx

    ; Glyph ID: GLYPH_STAR, GLYPH_SPARKLE, GLYPH_DOT_FILLED, or GLYPH_HEART
    call anim_rand
    and eax, 3
    cmp eax, 0
    je .g_star
    cmp eax, 1
    je .g_sparkle
    cmp eax, 2
    je .g_dot
    mov edx, GLYPH_HEART
    jmp .store_glyph
.g_star:
    mov edx, GLYPH_STAR
    jmp .store_glyph
.g_sparkle:
    mov edx, GLYPH_SPARKLE
    jmp .store_glyph
.g_dot:
    mov edx, GLYPH_DOT_FILLED
.store_glyph:
    mov [edi + PARTICLE_OFF_GLYPH], edx

    ; Color Slot: SLOT_ACCENT, SLOT_TITLE, SLOT_OK, or SLOT_CAT
    call anim_rand
    and eax, 3
    cmp eax, 0
    je .s_accent
    cmp eax, 1
    je .s_title
    cmp eax, 2
    je .s_ok
    mov edx, SLOT_CAT
    jmp .store_slot
.s_accent:
    mov edx, SLOT_ACCENT
    jmp .store_slot
.s_title:
    mov edx, SLOT_TITLE
    jmp .store_slot
.s_ok:
    mov edx, SLOT_OK
.store_slot:
    mov [edi + PARTICLE_OFF_SLOT], edx

    add edi, PARTICLE_SIZE
    pop ecx
    dec ecx
    jnz .confetti_spawn_loop

    or dword [anim_dirty_flags], ANIM_DIRTY_PARTICLES

.confetti_init_done:
    restore_regs
    ret

;=============================================================================
; Procedure: anim_on_habit_checkin
; Purpose:   Initializes the heart-pop effect upon successful habit check-in.
;            Positions the heart glyph (GLYPH_HEART) adjacent to the checked-in
;            habit row. The heart floats upward and expires cleanly.
; IN:        EAX = 0-based habit index (0..7)
; OUT:       None
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_on_habit_checkin:
    save_regs
    push eax

    ; If Reduce motion is active, do not spawn effect
    cmp byte [setting_anim], 1
    jne .heart_init_done

    pop eax
    push eax

    ; Calculate habit screen row: UI_HAB_ROW_FIRST (5) + habit_index
    add eax, UI_HAB_ROW_FIRST
    mov [heart_pop_y], eax

    ; Calculate safe column: ui_w - 38 (margin before history squares)
    mov edx, [ui_w]
    sub edx, 38
    cmp edx, 30
    jae .col_ok
    mov edx, 30
.col_ok:
    mov [heart_pop_x], edx

    mov dword [heart_pop_old_x], 0
    mov dword [heart_pop_old_y], 0
    mov dword [heart_pop_life], ANIM_HEART_POP_LIFE
    mov dword [heart_pop_active], 1

    or dword [anim_dirty_flags], ANIM_DIRTY_PARTICLES

.heart_init_done:
    pop eax
    restore_regs
    ret

;=============================================================================
; Procedure: anim_draw_cat_region
; Purpose:   Appends only the 3-line ASCII cat art region to out_buf at (cat_row,
;            cat_col) reflecting the current animated eye-blink and tail-wag states.
;            Does not flush out_buf.
; IN:        Implicit: cat_row, cat_col, anim_cat_blink_state, anim_cat_tail_state
; OUT:       Appends escape sequences and cat glyphs to out_buf
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_draw_cat_region:
    save_regs

    ; Verify valid cat position
    cmp dword [cat_row], 0
    jle .draw_cat_exit
    cmp dword [cat_col], 0
    jle .draw_cat_exit

    ; Cat color slot
    mov al, SLOT_CAT
    call ui_color

    ; -------------------------------------------------------------------------
    ; Line 1: cat_row, cat_col
    ; -------------------------------------------------------------------------
    mov eax, [cat_row]
    mov ebx, [cat_col]
    call ui_goto

    ; Check if resting cat during break
    cmp dword [state], STATE_TIMER
    jne .line1_normal
    cmp dword [phase], PHASE_FOCUS
    je .line1_normal
    mov esi, cat_p2_l1          ; " /\_/\   z"
    jmp .emit_line1

.line1_normal:
    mov esi, cat_p0_l1          ; " /\_/\ "

.emit_line1:
    call buf_str

    ; -------------------------------------------------------------------------
    ; Line 2: cat_row + 1, cat_col (Blink eyes or sleeping)
    ; -------------------------------------------------------------------------
    mov eax, [cat_row]
    inc eax
    mov ebx, [cat_col]
    call ui_goto

    cmp dword [state], STATE_TIMER
    jne .line2_check_blink
    cmp dword [phase], PHASE_FOCUS
    je .line2_timer_focus
    ; Break resting cat
    mov esi, cat_p2_l2          ; "( u.u )  Z"
    jmp .emit_line2

.line2_timer_focus:
    ; Working cat in timer focus: normally ( -.- ), blinks to ( o.o )
    cmp dword [anim_cat_blink_state], 1
    je .line2_open_eyes
    mov esi, cat_p1_l2          ; "( -.- )"
    jmp .emit_line2
.line2_open_eyes:
    mov esi, cat_p0_l2          ; "( o.o )"
    jmp .emit_line2

.line2_check_blink:
    ; Menu cat: normally ( o.o ), blinks to ( -.- )
    cmp dword [anim_cat_blink_state], 1
    je .line2_closed_eyes
    mov esi, cat_p0_l2          ; "( o.o )"
    jmp .emit_line2
.line2_closed_eyes:
    mov esi, cat_eyes_blink     ; "( -.- )"

.emit_line2:
    call buf_str

    ; -------------------------------------------------------------------------
    ; Line 3: cat_row + 2, cat_col (Tail wag)
    ; -------------------------------------------------------------------------
    mov eax, [cat_row]
    add eax, 2
    mov ebx, [cat_col]
    call ui_goto

    mov edx, [anim_cat_tail_state]
    cmp edx, ANIM_TAIL_POSES
    jb .tail_idx_ok
    xor edx, edx

.tail_idx_ok:
    mov esi, [cat_tail_table + edx*4]
    call buf_str

    mov esi, ansi_reset
    call buf_str

.draw_cat_exit:
    restore_regs
    ret

;=============================================================================
; Procedure: anim_draw_title_region
; Purpose:   Appends only the menu title color wave and twinkling stars to out_buf.
;            Cycles theme slots across "P A W M O D O R O" and animates star
;            twinkles without overwriting surrounding borders or text.
; IN:        Implicit: anim_title_wave_offset, anim_star_twinkle_state
; OUT:       Appends title escape sequences to out_buf
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_draw_title_region:
    save_regs

    cmp dword [state], STATE_MENU
    jne .title_draw_done

    ; -------------------------------------------------------------------------
    ; 1. Title Color Wave: Row 2, Col 14 ("P A W M O D O R O")
    ; -------------------------------------------------------------------------
    mov eax, UI_MENU_ROW_TITLE
    mov ebx, UI_MENU_COL_TITLE
    call ui_goto

    mov esi, ansi_bold
    call buf_str

    xor ecx, ecx                ; ECX = character index (0..16)

.wave_loop:
    cmp ecx, 17
    jae .wave_done

    mov al, [menu_title + ecx]
    cmp al, CHAR_SPACE
    je .emit_wave_space

    ; Calculate slot: (ecx / 2 + anim_title_wave_offset) & 3
    mov eax, ecx
    shr eax, 1                  ; EAX = ecx / 2
    add eax, [anim_title_wave_offset]
    and eax, 3                  ; Modulo 4

    mov al, [title_wave_slots + eax]
    call ui_color

    mov al, [menu_title + ecx]
    call buf_char
    inc ecx
    jmp .wave_loop

.emit_wave_space:
    call buf_char
    inc ecx
    jmp .wave_loop

.wave_done:
    mov esi, ansi_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; 2. Twinkling Stars: Star 1 at (Row 2, Col 12), Star 2 at (Row 2, Col 32)
    ; -------------------------------------------------------------------------
    mov edx, [anim_star_twinkle_state]
    and edx, 3

    cmp edx, 0
    je .twinkle_phase_0
    cmp edx, 1
    je .twinkle_phase_1
    cmp edx, 2
    je .twinkle_phase_2
    jmp .twinkle_phase_3

.twinkle_phase_0:
    ; Star 1: Accent sparkle, Star 2: Dim star
    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 12
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str

    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 32
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov eax, GLYPH_STAR
    call ui_glyph_str
    call buf_str
    jmp .twinkle_done

.twinkle_phase_1:
    ; Star 1: Dim star, Star 2: Title sparkle
    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 12
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov eax, GLYPH_STAR
    call ui_glyph_str
    call buf_str

    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 32
    call ui_goto
    mov al, SLOT_TITLE
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str
    jmp .twinkle_done

.twinkle_phase_2:
    ; Star 1: Space, Star 2: Accent sparkle
    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 12
    call ui_goto
    mov al, CHAR_SPACE
    call buf_char

    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 32
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str
    jmp .twinkle_done

.twinkle_phase_3:
    ; Star 1: Title sparkle, Star 2: Space
    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 12
    call ui_goto
    mov al, SLOT_TITLE
    call ui_color
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str

    mov eax, UI_MENU_ROW_TITLE
    mov ebx, 32
    call ui_goto
    mov al, CHAR_SPACE
    call buf_char

.twinkle_done:
    mov esi, ansi_reset
    call buf_str

.title_draw_done:
    restore_regs
    ret

;=============================================================================
; Procedure: anim_draw_progress_region
; Purpose:   Appends only the 30-cell progress bar region with a moving highlight
;            shimmer overlay to out_buf. Does not modify countdown values or
;            stored stats.
; IN:        Implicit: total_secs, remaining_secs, anim_shimmer_pos
; OUT:       Appends progress bar escape sequences to out_buf
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_draw_progress_region:
    save_regs

    cmp dword [state], STATE_TIMER
    jne .prog_draw_exit

    ; Calculate elapsed and total duration
    mov ecx, [total_secs]
    test ecx, ecx
    jnz .calc_elapsed
    mov ebx, PROGRESS_BAR_WIDTH
    mov edi, PERCENT_SCALE
    jmp .prog_render_bar

.calc_elapsed:
    mov eax, ecx
    sub eax, [remaining_secs]
    jnc .elapsed_positive
    xor eax, eax
.elapsed_positive:
    cmp eax, ecx
    jbe .elapsed_clamped
    mov eax, ecx
.elapsed_clamped:
    ; Calculate filled segments: (elapsed * 30) / total
    push eax
    push ecx
    mov edx, PROGRESS_BAR_WIDTH
    mul edx
    xor edx, edx
    pop ecx
    div ecx
    mov ebx, eax                ; EBX = filled segment count (0..30)

    ; Calculate percentage: (elapsed * 100) / total
    pop eax
    push ebx
    mov edx, PERCENT_SCALE
    mul edx
    xor edx, edx
    div ecx
    mov edi, eax                ; EDI = percentage (0..100)
    pop ebx

.prog_render_bar:
    ; Position at progress bar start (Row 7, Col 5)
    mov eax, UI_TIMER_ROW_PROGRESS
    mov ebx, UI_TIMER_COL_PROGRESS
    call ui_goto

    ; Emit '['
    mov al, CHAR_LBRACKET
    call buf_char

    ; Emit 30 segments: filled with shimmer highlight, remainder empty
    xor ecx, ecx                ; ECX = segment index (0..29)

.segment_loop:
    cmp ecx, PROGRESS_BAR_WIDTH
    jae .segment_loop_done

    cmp ecx, ebx
    jae .emit_empty_seg

    ; Filled segment: check if shimmer position
    cmp ecx, [anim_shimmer_pos]
    je .emit_shimmer_seg

    ; Normal filled segment
    mov al, SLOT_BAR_FULL
    call ui_color
    cmp byte [setting_charset], 1
    je .fill_ascii
    mov eax, GLYPH_BAR_FULL
    call ui_glyph_str
    call buf_str
    jmp .next_seg

.fill_ascii:
    mov al, CHAR_HASH
    call buf_char
    jmp .next_seg

.emit_shimmer_seg:
    ; Shimmer highlight segment
    mov al, SLOT_ACCENT
    call ui_color
    cmp byte [setting_charset], 1
    je .shimmer_ascii
    mov eax, GLYPH_SPARKLE
    call ui_glyph_str
    call buf_str
    jmp .next_seg

.shimmer_ascii:
    mov al, CHAR_ASTERISK
    call buf_char
    jmp .next_seg

.emit_empty_seg:
    ; Empty segment
    mov al, SLOT_BAR_EMPTY
    call ui_color
    cmp byte [setting_charset], 1
    je .empty_ascii
    mov eax, GLYPH_BAR_EMPTY
    call ui_glyph_str
    call buf_str
    jmp .next_seg

.empty_ascii:
    mov al, CHAR_MINUS
    call buf_char

.next_seg:
    inc ecx
    jmp .segment_loop

.segment_loop_done:
    mov esi, ansi_reset
    call buf_str

    ; Emit ']'
    mov al, CHAR_RBRACKET
    call buf_char

    ; Emit "  " and percentage integer
    mov al, CHAR_SPACE
    call buf_char
    call buf_char

    mov eax, edi
    call buf_u32
    mov al, CHAR_PERCENT
    call buf_char

.prog_draw_exit:
    restore_regs
    ret

;=============================================================================
; Procedure: anim_draw_particles_region
; Purpose:   Appends active particle effects to out_buf:
;            1. Rising break-time "zZ" garnish (during breaks).
;            2. Confetti particles simulation and rendering (natural focus complete).
;            3. Heart-pop particle simulation and rendering (successful check-in).
;            Erases previous particle positions before drawing updated coordinates.
; IN:        Implicit: anim_confetti_particles, heart_pop_*, anim_zz_*
; OUT:       Appends particle escape sequences to out_buf
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_draw_particles_region:
    save_regs

    ; -------------------------------------------------------------------------
    ; 1. Break-time Rising "zZ" Garnish
    ; -------------------------------------------------------------------------
    cmp dword [state], STATE_TIMER
    jne .check_confetti
    cmp dword [phase], PHASE_FOCUS
    je .check_confetti

    ; Erase previous zZ position if non-zero
    cmp dword [anim_zz_old_x], 0
    jle .draw_new_zz
    mov eax, [anim_zz_old_y]
    mov ebx, [anim_zz_old_x]
    call ui_goto
    mov esi, anim_zz_spaces
    call buf_str

.draw_new_zz:
    mov edx, [anim_zz_phase]
    cmp edx, 0
    je .zz_p0
    cmp edx, 1
    je .zz_p1
    cmp edx, 2
    je .zz_p2
    ; Phases 3..4: inactive / rest
    mov dword [anim_zz_old_x], 0
    mov dword [anim_zz_old_y], 0
    jmp .check_confetti

.zz_p0:
    mov dword [anim_zz_old_y], 4
    mov dword [anim_zz_old_x], 17
    mov eax, 4
    mov ebx, 17
    call ui_goto
    mov al, SLOT_DIM
    call ui_color
    mov esi, anim_zz_str_z
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .check_confetti

.zz_p1:
    mov dword [anim_zz_old_y], 3
    mov dword [anim_zz_old_x], 18
    mov eax, 3
    mov ebx, 18
    call ui_goto
    mov al, SLOT_ACCENT
    call ui_color
    mov esi, anim_zz_str_Z
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .check_confetti

.zz_p2:
    mov dword [anim_zz_old_y], 2
    mov dword [anim_zz_old_x], 19
    mov eax, 2
    mov ebx, 19
    call ui_goto
    mov al, SLOT_TITLE
    call ui_color
    mov esi, anim_zz_str_zZ
    call buf_str
    mov esi, ansi_reset
    call buf_str

    ; -------------------------------------------------------------------------
    ; 2. Confetti Particles (Natural Focus Completion)
    ; -------------------------------------------------------------------------
.check_confetti:
    cmp dword [state], STATE_TIMER
    jne .check_heart_pop

    mov ecx, CONFETTI_MAX
    mov edi, anim_confetti_particles

.confetti_render_loop:
    cmp dword [edi + PARTICLE_OFF_ACTIVE], 1
    jne .next_confetti_particle

    ; Erase previous position
    mov eax, [edi + PARTICLE_OFF_OLD_Y]
    test eax, eax
    jz .advance_particle
    mov ebx, [edi + PARTICLE_OFF_OLD_X]
    test ebx, ebx
    jz .advance_particle
    call ui_goto
    mov al, CHAR_SPACE
    call buf_char

.advance_particle:
    ; Decrement lifetime
    dec dword [edi + PARTICLE_OFF_LIFE]
    jle .retire_particle

    ; Store old coordinates
    mov eax, [edi + PARTICLE_OFF_X]
    mov [edi + PARTICLE_OFF_OLD_X], eax
    mov eax, [edi + PARTICLE_OFF_Y]
    mov [edi + PARTICLE_OFF_OLD_Y], eax

    ; Apply horizontal drift
    mov eax, [edi + PARTICLE_OFF_VX]
    add [edi + PARTICLE_OFF_X], eax

    ; Apply vertical velocity
    mov eax, [edi + PARTICLE_OFF_VY]
    add [edi + PARTICLE_OFF_Y], eax

    ; Gravity: every 2 ticks, increment vy (downward acceleration)
    test dword [anim_frame_count], 1
    jnz .check_bounds
    cmp dword [edi + PARTICLE_OFF_VY], 2
    jge .check_bounds
    inc dword [edi + PARTICLE_OFF_VY]

.check_bounds:
    ; Bounded coordinates check: rows 2..9, cols 4..(ui_w - 4)
    mov eax, [edi + PARTICLE_OFF_Y]
    cmp eax, 2
    jl .retire_particle
    cmp eax, UI_TIMER_ROW_BOTTOM
    jge .retire_particle

    mov ebx, [edi + PARTICLE_OFF_X]
    cmp ebx, 4
    jl .retire_particle
    mov edx, [ui_w]
    sub edx, 4
    cmp ebx, edx
    jg .retire_particle

    ; Draw particle at updated coordinate
    call ui_goto
    mov eax, [edi + PARTICLE_OFF_SLOT]
    call ui_color

    mov eax, [edi + PARTICLE_OFF_GLYPH]
    call ui_glyph_str
    call buf_str

    mov esi, ansi_reset
    call buf_str
    jmp .next_confetti_particle

.retire_particle:
    mov dword [edi + PARTICLE_OFF_ACTIVE], 0
    mov dword [edi + PARTICLE_OFF_OLD_X], 0
    mov dword [edi + PARTICLE_OFF_OLD_Y], 0

.next_confetti_particle:
    add edi, PARTICLE_SIZE
    dec ecx
    jnz .confetti_render_loop

    ; -------------------------------------------------------------------------
    ; 3. Heart-Pop Particle (Successful Habit Check-In)
    ; -------------------------------------------------------------------------
.check_heart_pop:
    cmp dword [heart_pop_active], 1
    jne .particles_done

    ; Erase previous position
    mov eax, [heart_pop_old_y]
    test eax, eax
    jz .advance_heart
    mov ebx, [heart_pop_old_x]
    test ebx, ebx
    jz .advance_heart
    call ui_goto
    mov al, CHAR_SPACE
    call buf_char

.advance_heart:
    dec dword [heart_pop_life]
    jle .retire_heart

    ; Store old coordinate
    mov eax, [heart_pop_x]
    mov [heart_pop_old_x], eax
    mov eax, [heart_pop_y]
    mov [heart_pop_old_y], eax

    ; Float upward every 2 ticks
    test dword [heart_pop_life], 1
    jnz .draw_heart
    cmp dword [heart_pop_y], 2
    jbe .draw_heart
    dec dword [heart_pop_y]

.draw_heart:
    mov eax, [heart_pop_y]
    mov ebx, [heart_pop_x]
    call ui_goto

    mov al, SLOT_OK
    call ui_color
    mov eax, GLYPH_HEART
    call ui_glyph_str
    call buf_str
    mov esi, ansi_reset
    call buf_str
    jmp .particles_done

.retire_heart:
    mov dword [heart_pop_active], 0
    mov dword [heart_pop_old_x], 0
    mov dword [heart_pop_old_y], 0

.particles_done:
    restore_regs
    ret

;=============================================================================
; Procedure: anim_render_dirty
; Purpose:   Coordinates and renders all dirty animation regions, enforcing:
;            1. Reduce motion check: exits immediately if setting_anim == 0.
;            2. Size gate check: exits immediately if term_size_ok == 0.
;            3. Dirty flags check: exits if no region is marked dirty.
;            4. Write throttle ceiling: at most 5 writes per second (flushes
;               only when anim_throttle_count >= ANIM_THROTTLE_TICKS).
;            Assembles all active partial regions into out_buf and performs
;            exactly ONE sys_write via buf_flush.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_render_dirty:
    save_regs

    ; Gate 1: Reduce motion check
    cmp byte [setting_anim], 1
    jne .render_done

    ; Gate 2: Terminal minimum size gate
    call term_size_ok
    test eax, eax
    jz .render_done

    ; Gate 3: Dirty flags check
    mov eax, [anim_dirty_flags]
    test eax, eax
    jz .render_done

    ; Gate 4: Write throttle ceiling (at least 2 ticks = 200ms elapsed)
    cmp dword [anim_throttle_count], ANIM_THROTTLE_TICKS
    jb .render_done

    ; Reset buffer pointer to assemble partial frame
    mov dword [out_len], 0

    ; Partial Region 1: Cat Art
    test dword [anim_dirty_flags], ANIM_DIRTY_CAT
    jz .check_dirty_title
    call anim_draw_cat_region

.check_dirty_title:
    ; Partial Region 2: Menu Title & Stars
    test dword [anim_dirty_flags], ANIM_DIRTY_TITLE
    jz .check_dirty_progress
    call anim_draw_title_region

.check_dirty_progress:
    ; Partial Region 3: Timer Progress Bar Shimmer
    test dword [anim_dirty_flags], ANIM_DIRTY_PROGRESS
    jz .check_dirty_particles
    call anim_draw_progress_region

.check_dirty_particles:
    ; Partial Region 4: Confetti, Heart Pop, Break zZ
    test dword [anim_dirty_flags], ANIM_DIRTY_PARTICLES
    jz .do_frame_flush
    call anim_draw_particles_region

.do_frame_flush:
    ; Single sys_write per composed animation frame (PRD_V2 §8, FR-V30)
    call buf_flush

    ; Clear dirty flags and reset write throttle counter
    mov dword [anim_dirty_flags], 0
    mov dword [anim_throttle_count], 0

.render_done:
    restore_regs
    ret

;=============================================================================
; Procedure: anim_tick
; Purpose:   Non-blocking animation tick procedure, invoked once per 100ms
;            iteration from the active timer loop and the menu wait loop.
;            Advances frame counters and schedules dirty partial redraws:
;            - Menu: cat blink, tail wag, title color wave, star twinkles.
;            - Timer (running): cat blink/tail, progress shimmer, break zZ, confetti.
;            - Timer (paused): freezes timer animations.
;            - Habits: heart-pop simulation.
;            Enforces <= 5 writes/sec via anim_render_dirty.
; IN:        None
; OUT:       None
; CLOBBERS:  None (preserves all registers)
;=============================================================================
anim_tick:
    save_regs

    ; Gate 1: Reduce motion check (FR-V31)
    cmp byte [setting_anim], 1
    jne .tick_done

    ; Gate 2: Terminal size check (FR-V3)
    call term_size_ok
    test eax, eax
    jz .tick_done

    ; Advance write throttle counter and 100ms frame counter
    inc dword [anim_throttle_count]
    inc dword [anim_frame_count]

    ; -------------------------------------------------------------------------
    ; State 1: STATE_MENU
    ; -------------------------------------------------------------------------
    cmp dword [state], STATE_MENU
    jne .check_state_timer

    ; Cat Eye Blink: every 30 ticks (3.0s), blink for 2 ticks (200ms)
    mov eax, [anim_frame_count]
    xor edx, edx
    mov ecx, ANIM_BLINK_INTERVAL
    div ecx                     ; EDX = frame % 30
    cmp edx, 0
    jne .menu_check_blink_end
    mov dword [anim_cat_blink_state], 1
    or dword [anim_dirty_flags], ANIM_DIRTY_CAT
    jmp .menu_tick_tail
.menu_check_blink_end:
    cmp edx, ANIM_BLINK_DURATION
    jne .menu_tick_tail
    mov dword [anim_cat_blink_state], 0
    or dword [anim_dirty_flags], ANIM_DIRTY_CAT

.menu_tick_tail:
    ; Cat Tail Wag: cycle pose every 3 ticks (300ms)
    mov eax, [anim_frame_count]
    xor edx, edx
    mov ecx, ANIM_TAIL_PERIOD
    div ecx                     ; EDX = frame % 3
    test edx, edx
    jnz .menu_tick_title
    inc dword [anim_cat_tail_state]
    cmp dword [anim_cat_tail_state], ANIM_TAIL_POSES
    jb .tail_ok
    mov dword [anim_cat_tail_state], 0
.tail_ok:
    or dword [anim_dirty_flags], ANIM_DIRTY_CAT

.menu_tick_title:
    ; Title Color Wave: advance slot offset every 2 ticks (200ms)
    test dword [anim_frame_count], 1
    jnz .menu_tick_stars
    inc dword [anim_title_wave_offset]
    and dword [anim_title_wave_offset], 3
    or dword [anim_dirty_flags], ANIM_DIRTY_TITLE

.menu_tick_stars:
    ; Twinkling Stars: advance phase every 4 ticks (400ms)
    mov eax, [anim_frame_count]
    and eax, 3
    jnz .tick_dispatch_render
    inc dword [anim_star_twinkle_state]
    and dword [anim_star_twinkle_state], 3
    or dword [anim_dirty_flags], ANIM_DIRTY_TITLE
    jmp .tick_dispatch_render

    ; -------------------------------------------------------------------------
    ; State 2: STATE_TIMER
    ; -------------------------------------------------------------------------
.check_state_timer:
    cmp dword [state], STATE_TIMER
    jne .check_state_habits

    ; Check if timer is paused: frozen countdown means frozen animation!
    cmp dword [paused], 1
    je .tick_dispatch_render

    ; Cat Tail Wag: cycle pose every 3 ticks
    mov eax, [anim_frame_count]
    xor edx, edx
    mov ecx, ANIM_TAIL_PERIOD
    div ecx
    test edx, edx
    jnz .timer_check_break_zz
    inc dword [anim_cat_tail_state]
    cmp dword [anim_cat_tail_state], ANIM_TAIL_POSES
    jb .timer_tail_ok
    mov dword [anim_cat_tail_state], 0
.timer_tail_ok:
    or dword [anim_dirty_flags], ANIM_DIRTY_CAT

.timer_check_break_zz:
    ; Break "zZ" garnish (during Short/Long Break)
    cmp dword [phase], PHASE_FOCUS
    je .timer_tick_shimmer
    mov eax, [anim_frame_count]
    xor edx, edx
    mov ecx, ANIM_ZZ_PERIOD
    div ecx
    test edx, edx
    jnz .timer_tick_shimmer
    inc dword [anim_zz_phase]
    cmp dword [anim_zz_phase], 5
    jb .zz_phase_ok
    mov dword [anim_zz_phase], 0
.zz_phase_ok:
    or dword [anim_dirty_flags], ANIM_DIRTY_PARTICLES

.timer_tick_shimmer:
    ; Progress Bar Shimmer: advance position every 2 ticks
    test dword [anim_frame_count], 1
    jnz .timer_check_particles
    inc dword [anim_shimmer_pos]
    cmp dword [anim_shimmer_pos], PROGRESS_BAR_WIDTH
    jb .shimmer_ok
    mov dword [anim_shimmer_pos], 0
.shimmer_ok:
    or dword [anim_dirty_flags], ANIM_DIRTY_PROGRESS

.timer_check_particles:
    ; Check if confetti has active particles
    mov ecx, CONFETTI_MAX
    mov edi, anim_confetti_particles
.check_confetti_active_loop:
    cmp dword [edi + PARTICLE_OFF_ACTIVE], 1
    je .found_active_confetti
    add edi, PARTICLE_SIZE
    dec ecx
    jnz .check_confetti_active_loop
    jmp .tick_dispatch_render

.found_active_confetti:
    or dword [anim_dirty_flags], ANIM_DIRTY_PARTICLES
    jmp .tick_dispatch_render

    ; -------------------------------------------------------------------------
    ; State 3: STATE_HABITS
    ; -------------------------------------------------------------------------
.check_state_habits:
    cmp dword [state], STATE_HABITS
    jne .tick_dispatch_render
    cmp dword [heart_pop_active], 1
    jne .tick_dispatch_render
    or dword [anim_dirty_flags], ANIM_DIRTY_PARTICLES

.tick_dispatch_render:
    ; Flush dirty regions if throttled
    call anim_render_dirty

.tick_done:
    restore_regs
    ret
