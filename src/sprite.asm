; =============================================================================
; Pawmodoro - Sprite Engine & Hidden Sprite Viewer (src/sprite.asm)
;
; Purpose: On-the-fly RLE sprite decoding, half-block sub-cell rendering,
;          7-bit ASCII fallback rendering, metadata inspection, rectangular
;          erasure, edge clipping, and interactive hidden sprite viewer.
; Reference: PRD_V3 §4.1, §4.2, §4.3, §4.4, §12.2, §sprites
; Register Discipline: PRD §6.2 (all procedures preserve all general registers
;                      and EFLAGS unless explicitly documented).
; =============================================================================

section .text

; =============================================================================
; Public Interface Procedures
; =============================================================================

global sprite_draw
global sprite_draw_ascii
global sprite_info
global sprite_erase
global sprite_viewer_run

;=============================================================================
; Procedure: sprite_draw
; Purpose:   Renders one animation frame of a half-block sprite at designated
;            coordinates, clipping against frame and terminal boundaries.
;            Decodes run-length pixel stream on the fly (two pixel rows per cell row).
;            Translates sprite palette indices to active theme slots via header table.
;            If setting_charset == 1 (ASCII mode), automatically delegates to
;            sprite_draw_ascii.
; IN:        ESI = Pointer to canonical sprite descriptor
;            EAX = Destination cell row (1-based, existing UI coordinate)
;            EBX = Destination column relative to frame (1-based)
;            ECX = Zero-based animation frame index
;            EDX = Transparent-fill background theme-slot ID (0..NUM_SLOTS-1)
; OUT:       None
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
sprite_draw:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; -------------------------------------------------------------------------
    ; 1. Charset Fallback Gate: Dispatch to ASCII if setting_charset == 1
    ; -------------------------------------------------------------------------
    cmp byte [setting_charset], 1
    jne .draw_utf8_path

    ; Delegate to ASCII renderer with identical parameters
    call sprite_draw_ascii
    jmp .draw_exit

.draw_utf8_path:
    ; -------------------------------------------------------------------------
    ; 2. Defensive Validation of Descriptor Header (PRD_V3 §4.3)
    ; -------------------------------------------------------------------------
    test esi, esi
    jz .draw_exit               ; NULL descriptor pointer: abort safely

    movzx edi, byte [esi]        ; EDI = width_cells
    test edi, edi
    jz .draw_exit
    cmp edi, UI_FRAME_MAX_WIDTH
    ja .draw_exit                ; Unreasonable width: abort

    movzx ebp, byte [esi + 1]    ; EBP = height_pixels
    test ebp, ebp
    jz .draw_exit
    test ebp, 1                  ; Height in pixel rows MUST BE EVEN
    jnz .draw_exit

    movzx eax, byte [esi + 2]    ; EAX = frame_count
    cmp ecx, eax                 ; Frame index must be < frame_count
    jae .draw_exit

    movzx eax, byte [esi + 3]    ; EAX = palette_entries
    test eax, eax
    jz .draw_exit
    cmp eax, SPRITE_MAX_PALETTE  ; Must be <= 15
    ja .draw_exit

    ; -------------------------------------------------------------------------
    ; 3. Invalidate Color Cache on Entry (PRD_V3 §8.2)
    ; -------------------------------------------------------------------------
    call gfx_sgr_forget

    ; -------------------------------------------------------------------------
    ; 4. Set up Stack Frame for On-The-Fly Decoding
    ;    Stack Layout:
    ;      [ebp - 4]   = dest_row (EAX)
    ;      [ebp - 8]   = dest_col (EBX)
    ;      [ebp - 12]  = target_frame_idx (ECX)
    ;      [ebp - 16]  = fill_slot (EDX)
    ;      [ebp - 20]  = width_cells
    ;      [ebp - 24]  = height_pixels
    ;      [ebp - 28]  = height_cells (height_pixels / 2)
    ;      [ebp - 32]  = palette_entries
    ;      [ebp - 36]  = slot_map_ptr (ESI + 4)
    ;      [ebp - 40]  = rle_ptr (pointer to active frame RLE stream)
    ;      [ebp - 44]  = run_remaining (count of pixels left in current run)
    ;      [ebp - 48]  = run_val (palette index of current run)
    ;      [ebp - 52]  = cursor_row (last painted row, -1 = unknown)
    ;      [ebp - 56]  = cursor_col (next expected col, -1 = unknown)
    ;      [ebp - 184] = top_row buffer (128 bytes)
    ;      [ebp - 312] = bot_row buffer (128 bytes)
    ; -------------------------------------------------------------------------
    push ebp
    mov ebp, esp
    sub esp, 320                ; Allocate locals + two 128-byte row buffers

    ; Store inputs
    mov eax, [esp + 320 + 28]   ; Saved EAX (dest_row)
    mov ebx, [esp + 320 + 24]   ; Saved EBX (dest_col)
    mov ecx, [esp + 320 + 20]   ; Saved ECX (frame_idx)
    mov edx, [esp + 320 + 16]   ; Saved EDX (fill_slot)

    mov [ebp - 4], eax
    mov [ebp - 8], ebx
    mov [ebp - 12], ecx
    mov [ebp - 16], edx

    movzx eax, byte [esi]
    mov [ebp - 20], eax         ; width_cells
    movzx ebx, byte [esi + 1]
    mov [ebp - 24], ebx         ; height_pixels
    shr ebx, 1
    mov [ebp - 28], ebx         ; height_cells
    movzx ecx, byte [esi + 3]
    mov [ebp - 32], ecx         ; palette_entries

    lea eax, [esi + 4]
    mov [ebp - 36], eax         ; slot_map_ptr

    ; Advance rle_ptr past palette table: ESI + 4 + palette_entries
    add eax, ecx
    mov [ebp - 40], eax         ; rle_ptr for Frame 0

    ; If target_frame_idx > 0, skip preceding frames
    mov ecx, [ebp - 12]
    test ecx, ecx
    jz .frame_located

.skip_frames_loop:
    ; Skip runs until 0x00 sentinel
    mov esi, [ebp - 40]
.skip_run_loop:
    movzx eax, byte [esi]
    test al, al
    jz .frame_sentinel_reached
    add esi, 2                  ; Skip run_length + palette_index
    jmp .skip_run_loop

.frame_sentinel_reached:
    inc esi                     ; Skip 0x00 sentinel
    mov [ebp - 40], esi
    dec ecx
    jnz .skip_frames_loop

.frame_located:
    ; Initialize run state
    mov dword [ebp - 44], 0     ; run_remaining = 0
    mov dword [ebp - 48], 0     ; run_val = 0
    mov dword [ebp - 52], -1    ; cursor_row = -1
    mov dword [ebp - 56], -1    ; cursor_col = -1

    ; -------------------------------------------------------------------------
    ; 5. Cell Row Loop: cy = 0 .. height_cells - 1
    ; -------------------------------------------------------------------------
    xor edi, edi                ; EDI = cy (cell row index)

.cell_row_loop:
    cmp edi, [ebp - 28]
    jge .all_rows_done

    ; --- Decode Top Pixel Row into top_row [ebp - 184] ---
    mov ecx, [ebp - 20]         ; ECX = width_cells
    lea edx, [ebp - 184]        ; EDX = top_row buffer
.dec_top_loop:
    call .sub_decode_pixel
    mov [edx], al
    inc edx
    dec ecx
    jnz .dec_top_loop

    ; --- Decode Bottom Pixel Row into bot_row [ebp - 312] ---
    mov ecx, [ebp - 20]         ; ECX = width_cells
    lea edx, [ebp - 312]        ; EDX = bot_row buffer
.dec_bot_loop:
    call .sub_decode_pixel
    mov [edx], al
    inc edx
    dec ecx
    jnz .dec_bot_loop

    ; --- Vertical Clipping Check for this Cell Row ---
    mov eax, [ebp - 4]          ; dest_row
    add eax, edi                ; cur_row = dest_row + cy
    cmp eax, 1
    jl .next_cell_row           ; Above top of terminal: skip drawing
    cmp eax, [term_rows]
    jg .next_cell_row           ; Below terminal height: skip drawing
    cmp eax, [ui_h]
    jg .next_cell_row           ; Below active frame height: skip drawing

    ; --- Horizontal Cell Loop: cx = 0 .. width_cells - 1 ---
    push edi                    ; Preserve cell row index cy
    xor esi, esi                ; ESI = cx (column index)

.cell_col_loop:
    cmp esi, [ebp - 20]
    jge .cell_col_done

    ; Calculate target column
    mov ebx, [ebp - 8]          ; dest_col
    add ebx, esi                ; cur_col = dest_col + cx

    ; Horizontal Clipping: 1 <= cur_col <= ui_w
    cmp ebx, 1
    jl .skip_cell
    cmp ebx, [ui_w]
    jg .skip_cell

    ; Absolute Terminal Column Clipping: 1 <= cur_abs_col <= term_cols
    mov ecx, ebx
    add ecx, [ui_col0]
    cmp ecx, 1
    jl .skip_cell
    cmp ecx, [term_cols]
    jg .skip_cell

    ; Position Cursor if not already adjacent on current row
    mov eax, [ebp - 4]
    add eax, edi                ; cur_row
    cmp eax, [ebp - 52]         ; cursor_row == cur_row?
    jne .reposition_cursor
    cmp ebx, [ebp - 56]         ; cursor_col == cur_col?
    je .cursor_ready

.reposition_cursor:
    call ui_goto
    mov [ebp - 52], eax         ; cursor_row = cur_row
.cursor_ready:
    inc ebx
    mov [ebp - 56], ebx         ; cursor_col = cur_col + 1
    dec ebx

    ; Fetch top and bottom pixel palette indices
    movzx ecx, byte [ebp - 184 + esi] ; ECX = top_px
    movzx edx, byte [ebp - 312 + esi] ; EDX = bot_px

    ; Defensive clamp: if index > palette_entries, treat as transparent (0)
    cmp ecx, [ebp - 32]
    jbe .top_idx_ok
    xor ecx, ecx
.top_idx_ok:
    cmp edx, [ebp - 32]
    jbe .bot_idx_ok
    xor edx, edx
.bot_idx_ok:

    ; Resolve theme slot IDs:
    ; top_slot in AL, bot_slot in AH
    ; If index == 0, use fill_slot [ebp - 16]
    test ecx, ecx
    jz .top_is_trans
    mov eax, [ebp - 36]         ; slot_map_ptr
    movzx eax, byte [eax + ecx - 1]
    jmp .check_bot
.top_is_trans:
    mov eax, [ebp - 16]         ; fill_slot
.check_bot:
    push eax                    ; [esp] = top_slot

    test edx, edx
    jz .bot_is_trans
    mov eax, [ebp - 36]         ; slot_map_ptr
    movzx eax, byte [eax + edx - 1]
    jmp .slots_resolved
.bot_is_trans:
    mov eax, [ebp - 16]         ; fill_slot

.slots_resolved:
    mov ah, al                  ; AH = bot_slot
    pop eax                     ; AL = top_slot, AH = bot_slot

    ; -------------------------------------------------------------------------
    ; Half-Block Glyph & Color Selection (PRD_V3 §4.1, prompt §5.1)
    ; -------------------------------------------------------------------------
    test ecx, ecx
    jnz .check_case_2_or_both

    ; Top is transparent (ECX == 0)
    test edx, edx
    jnz .case_3_top_trans_bot_opaque

    ; --- Case 1: Both Pixels Transparent ---
    ; Fill cell with supplied background slot
    mov al, [ebp - 16]          ; fill_slot
    call gfx_set_bg
    mov al, CHAR_SPACE
    call buf_char
    jmp .skip_cell

.case_3_top_trans_bot_opaque:
    ; --- Case 3: Top Transparent, Bottom Opaque ---
    ; Render ▄ (U+2584): foreground = bot_slot, background = fill_slot
    push eax
    mov al, ah                  ; bot_slot
    call gfx_set_fg
    mov al, [ebp - 16]          ; fill_slot
    call gfx_set_bg
    pop eax
    mov al, UTF8_HALF_LOWER_B1
    call buf_char
    mov al, UTF8_HALF_LOWER_B2
    call buf_char
    mov al, UTF8_HALF_LOWER_B3
    call buf_char
    jmp .skip_cell

.check_case_2_or_both:
    ; Top is opaque (ECX != 0)
    test edx, edx
    jnz .both_opaque

    ; --- Case 2: Top Opaque, Bottom Transparent ---
    ; Render ▀ (U+2580): foreground = top_slot, background = fill_slot
    push eax
    call gfx_set_fg             ; AL = top_slot
    mov al, [ebp - 16]          ; fill_slot
    call gfx_set_bg
    pop eax
    mov al, UTF8_HALF_UPPER_B1
    call buf_char
    mov al, UTF8_HALF_UPPER_B2
    call buf_char
    mov al, UTF8_HALF_UPPER_B3
    call buf_char
    jmp .skip_cell

.both_opaque:
    ; Both pixels opaque: compare resolved theme slots (AL vs AH)
    cmp al, ah
    jne .case_5_both_different

    ; --- Case 4: Both Opaque, Same Resolved Slot ---
    ; Render a space with that background color
    call gfx_set_bg             ; AL = top_slot
    mov al, CHAR_SPACE
    call buf_char
    jmp .skip_cell

.case_5_both_different:
    ; --- Case 5: Both Opaque, Different Resolved Slots ---
    ; Render ▀ (U+2580): foreground = top_slot, background = bot_slot
    push eax
    call gfx_set_fg             ; AL = top_slot
    mov al, ah                  ; AH = bot_slot
    call gfx_set_bg
    pop eax
    mov al, UTF8_HALF_UPPER_B1
    call buf_char
    mov al, UTF8_HALF_UPPER_B2
    call buf_char
    mov al, UTF8_HALF_UPPER_B3
    call buf_char

.skip_cell:
    inc esi                     ; cx++
    jmp .cell_col_loop

.cell_col_done:
    pop edi                     ; Restore cell row index cy

.next_cell_row:
    inc edi                     ; cy++
    jmp .cell_row_loop

.all_rows_done:
    mov esp, ebp
    pop ebp

    ; -------------------------------------------------------------------------
    ; 6. Invalidate Color Cache on Exit (PRD_V3 §8.2)
    ; -------------------------------------------------------------------------
    call gfx_sgr_forget

.draw_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

; -----------------------------------------------------------------------------
; Helper: .sub_decode_pixel
; Returns next palette index in AL, advancing rle_ptr on run exhaustion.
; Uses registers EDX, EBX internally, preserves ECX, EDI, ESI.
; -----------------------------------------------------------------------------
.sub_decode_pixel:
    cmp dword [ebp - 44], 0     ; run_remaining == 0?
    jne .have_run_pixel

    ; Fetch next run from rle_ptr
    mov ebx, [ebp - 40]
    movzx eax, byte [ebx]       ; EAX = run_length
    test al, al
    jz .rle_exhausted           ; Sentinel 0x00 reached

    mov [ebp - 44], eax         ; run_remaining = run_length
    movzx eax, byte [ebx + 1]   ; EAX = palette_index
    mov [ebp - 48], eax         ; run_val = palette_index
    add ebx, 2
    mov [ebp - 40], ebx         ; Advance rle_ptr by 2 bytes

.have_run_pixel:
    dec dword [ebp - 44]        ; run_remaining--
    mov eax, [ebp - 48]         ; AL = run_val
    ret

.rle_exhausted:
    ; Malformed or truncated stream fallback: emit transparent pixel (0)
    xor eax, eax
    ret

;=============================================================================
; Procedure: sprite_draw_ascii
; Purpose:   Renders the 7-bit ASCII-art fallback representation of a sprite.
;            Strict ASCII purity mandate: emits zero application-generated bytes >= 0x80.
;            Respects identical clipping and coordinate contracts as sprite_draw.
; IN:        ESI = Pointer to canonical sprite descriptor
;            EAX = Destination cell row (1-based)
;            EBX = Destination column relative to frame (1-based)
;            ECX = Zero-based animation frame index (ignored; format shares 1 ASCII block)
;            EDX = Fill background theme-slot ID
; OUT:       None
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
sprite_draw_ascii:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    test esi, esi
    jz .ascii_exit

    ; Invalidate color cache on entry
    call gfx_sgr_forget

    ; Set up local frame
    push ebp
    mov ebp, esp
    sub esp, 32

    mov [ebp - 4], eax          ; dest_row
    mov [ebp - 8], ebx          ; dest_col
    mov [ebp - 12], edx         ; fill_slot

    ; 1. Locate ASCII Fallback Art Block
    ; Offset = ESI + 4 + palette_entries + skip all frames
    movzx eax, byte [esi + 2]   ; EAX = frame_count
    movzx ecx, byte [esi + 3]   ; ECX = palette_entries
    lea edi, [esi + 4 + ecx]    ; EDI = start of Frame 0 RLE

    ; Skip all frame RLE streams until after the last 0x00 sentinel
.skip_ascii_frames:
    test eax, eax
    jz .at_ascii_block
.skip_ascii_run:
    movzx edx, byte [edi]
    test dl, dl
    jz .frame_sentinel_found
    add edi, 2
    jmp .skip_ascii_run
.frame_sentinel_found:
    inc edi                     ; Skip 0x00 sentinel
    dec eax
    jmp .skip_ascii_frames

.at_ascii_block:
    ; EDI points to ascii_lines count byte
    movzx ecx, byte [edi]       ; ECX = ascii_lines
    inc edi
    mov [ebp - 20], ecx         ; total_lines = ascii_lines
    test ecx, ecx
    jz .ascii_cleanup

    mov dword [ebp - 16], 0     ; line_idx = 0

.ascii_line_loop:
    mov eax, [ebp - 16]
    cmp eax, [ebp - 20]
    jge .ascii_cleanup

    movzx edx, byte [edi]       ; EDX = line_length
    inc edi                     ; EDI points to string bytes

    ; Vertical Clipping Check: cur_row = dest_row + line_idx
    mov eax, [ebp - 4]          ; dest_row
    add eax, [ebp - 16]         ; cur_row
    cmp eax, 1
    jl .skip_ascii_line
    cmp eax, [term_rows]
    jg .skip_ascii_line
    cmp eax, [ui_h]
    jg .skip_ascii_line

    ; Column loop: char_idx = 0 .. line_length - 1
    xor esi, esi                ; ESI = char_idx

.ascii_char_loop:
    cmp esi, edx
    jge .ascii_char_done

    mov ebx, [ebp - 8]          ; dest_col
    add ebx, esi                ; cur_col = dest_col + cx

    ; Horizontal Clipping: 1 <= cur_col <= ui_w
    cmp ebx, 1
    jl .next_ascii_char
    cmp ebx, [ui_w]
    jg .next_ascii_char

    mov eax, ebx
    add eax, [ui_col0]
    cmp eax, 1
    jl .next_ascii_char
    cmp eax, [term_cols]
    jg .next_ascii_char

    ; Position Cursor at (cur_row, cur_col)
    push edx
    mov eax, [ebp - 4]
    add eax, [ebp - 16]         ; cur_row
    call ui_goto

    ; Fetch character byte
    movzx eax, byte [edi + esi]

    ; Enforce 7-bit ASCII invariant: clamp any byte >= 0x80 to '?'
    cmp al, 0x80
    jb .char_is_pure_ascii
    mov al, CHAR_QUESTION
.char_is_pure_ascii:

    ; Color formatting for ASCII characters
    cmp al, CHAR_SPACE
    je .char_is_space

    ; Non-space artwork character: foreground = SLOT_FUR, background = fill_slot
    push eax
    mov al, SLOT_FUR
    call gfx_set_fg
    mov al, [ebp - 12]          ; fill_slot
    call gfx_set_bg
    pop eax
    call buf_char
    pop edx
    jmp .next_ascii_char

.char_is_space:
    ; Space character: fill background
    push eax
    mov al, [ebp - 12]          ; fill_slot
    call gfx_set_bg
    pop eax
    call buf_char
    pop edx

.next_ascii_char:
    inc esi
    jmp .ascii_char_loop

.ascii_char_done:
.skip_ascii_line:
    add edi, edx                ; Advance EDI past line string bytes
    inc dword [ebp - 16]        ; line_idx++
    jmp .ascii_line_loop

.ascii_cleanup:
    mov esp, ebp
    pop ebp

    ; Invalidate color cache on exit
    call gfx_sgr_forget

.ascii_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: sprite_info
; Purpose:   Queries metadata and terminal cell dimensions of a sprite descriptor.
;            Converts pixel-row height to integer terminal cell height (h / 2).
; IN:        ESI = Pointer to sprite descriptor
; OUT:       EAX = Width in terminal cells
;            EBX = Height in terminal cells (height_pixels / 2)
;            ECX = Number of animation frames
; CLOBBERS:  EAX, EBX, ECX (preserves EDX, ESI, EDI, EBP, ESP)
;=============================================================================
sprite_info:
    test esi, esi
    jz .info_invalid

    movzx eax, byte [esi]       ; width_cells
    movzx ebx, byte [esi + 1]   ; height_pixels
    shr ebx, 1                  ; height_cells = height_pixels / 2
    movzx ecx, byte [esi + 2]   ; frame_count
    ret

.info_invalid:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    ret

;=============================================================================
; Procedure: sprite_erase
; Purpose:   Fills the sprite's declared cell rectangle with the caller-supplied
;            background theme slot, respecting clipping. Used before moving a
;            sprite or swapping animation frames.
; IN:        ESI = Pointer to sprite descriptor
;            EAX = Destination cell row (1-based)
;            EBX = Destination column relative to frame (1-based)
;            EDX = Background theme-slot ID (0..NUM_SLOTS-1)
; OUT:       None
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
sprite_erase:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    test esi, esi
    jz .erase_done

    call gfx_sgr_forget

    ; Query sprite dimensions
    push eax                    ; Save start_row
    push ebx                    ; Save start_col
    push edx                    ; Save bg_slot
    call sprite_info            ; EAX = width_cells, EBX = height_cells
    mov ecx, eax                ; ECX = width_cells
    mov edi, ebx                ; EDI = height_cells
    pop edx                     ; EDX = bg_slot
    pop ebx                     ; EBX = start_col
    pop eax                     ; EAX = start_row

    test ecx, ecx
    jz .erase_cleanup
    test edi, edi
    jz .erase_cleanup

    ; Set background theme slot
    push eax
    mov al, dl
    call gfx_set_bg
    pop eax

    ; Row loop: r = 0 .. height_cells - 1
    xor ebp, ebp                ; EBP = r

.erase_row_loop:
    cmp ebp, edi
    jge .erase_cleanup

    push eax                    ; Save current start_row
    add eax, ebp                ; target_row = start_row + r

    ; Vertical Clipping
    cmp eax, 1
    jl .skip_erase_row
    cmp eax, [term_rows]
    jg .skip_erase_row
    cmp eax, [ui_h]
    jg .skip_erase_row

    ; Column loop: c = 0 .. width_cells - 1
    push ecx
    xor esi, esi                ; ESI = c

.erase_col_loop:
    cmp esi, ecx
    jge .erase_col_done

    push ebx
    add ebx, esi                ; target_col = start_col + c

    ; Horizontal Clipping
    cmp ebx, 1
    jl .skip_erase_cell
    cmp ebx, [ui_w]
    jg .skip_erase_cell

    push eax
    mov eax, ebx
    add eax, [ui_col0]
    cmp eax, 1
    jl .skip_erase_cell_pop
    cmp eax, [term_cols]
    jg .skip_erase_cell_pop
    pop eax

    call ui_goto
    mov al, CHAR_SPACE
    call buf_char
    jmp .skip_erase_cell

.skip_erase_cell_pop:
    pop eax
.skip_erase_cell:
    pop ebx
    inc esi
    jmp .erase_col_loop

.erase_col_done:
    pop ecx

.skip_erase_row:
    pop eax
    inc ebp
    jmp .erase_row_loop

.erase_cleanup:
    call gfx_sgr_forget

.erase_done:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

; =============================================================================
; Hidden Sprite Viewer Subsystem (PRD_V3 §sprites, Prompt §9)
; =============================================================================

%ifdef SPRITE_VIEWER_ENABLED

section .data
    viewer_sprite_idx:      dd 0        ; Active sprite index in sprite_table
    viewer_frame_idx:       dd 0        ; Active animation frame index
    viewer_fill_slot:       dd SLOT_SURFACE ; Transparent fill background slot (default: 13)
    viewer_edge_mode:       dd 0        ; 0=Center, 1..8=Edge clipping presets
    viewer_pos_x:           dd 0        ; Manual horizontal cell offset
    viewer_pos_y:           dd 0        ; Manual vertical cell offset

    viewer_saved_theme:     db 0        ; Original theme index on viewer entry
    viewer_saved_coat:      db 0        ; Original cat coat preset on viewer entry
    viewer_saved_charset:   db 0        ; Original charset mode on viewer entry

    ; Labels & Text Strings for Sprite Viewer UI
    str_viewer_title:       db "PAWMODORO SPRITE VIEWER", CHAR_NULL
    str_viewer_sprite:      db "Sprite: ", CHAR_NULL
    str_viewer_frame:       db " | Frame: ", CHAR_NULL
    str_viewer_size:        db "Size: ", CHAR_NULL
    str_viewer_cells:       db " cells (", CHAR_NULL
    str_viewer_px:          db " px) | Charset: ", CHAR_NULL
    str_viewer_utf8:        db "UTF-8 (Half-Block)", CHAR_NULL
    str_viewer_ascii:       db "ASCII Fallback", CHAR_NULL
    str_viewer_theme:       db "Theme: ", CHAR_NULL
    str_viewer_coat:        db " | Coat: ", CHAR_NULL
    str_viewer_fill:        db "Fill Slot: ", CHAR_NULL
    str_viewer_pos:         db " | Pos: ", CHAR_NULL
    str_viewer_glyphs:      db "Approved Glyphs: ", CHAR_NULL
    str_viewer_help:        db "[< / >] Sprite   [^ / v] Frame   [T] Theme   [C] Coat   [A] ASCII   [+/-] Fill   [1-9] Edges   [Esc] Back", CHAR_NULL

    str_pos_center:         db "Center (Normal)", CHAR_NULL
    str_pos_top:            db "Top Edge (Clipped)", CHAR_NULL
    str_pos_bot:            db "Bottom Edge (Clipped)", CHAR_NULL
    str_pos_left:           db "Left Edge (Clipped)", CHAR_NULL
    str_pos_right:          db "Right Edge (Clipped)", CHAR_NULL
    str_pos_tl:             db "Top-Left (Corner Clipped)", CHAR_NULL
    str_pos_tr:             db "Top-Right (Corner Clipped)", CHAR_NULL
    str_pos_bl:             db "Bottom-Left (Corner Clipped)", CHAR_NULL
    str_pos_br:             db "Bottom-Right (Corner Clipped)", CHAR_NULL

    pos_names:
        dd str_pos_center
        dd str_pos_top
        dd str_pos_bot
        dd str_pos_left
        dd str_pos_right
        dd str_pos_tl
        dd str_pos_tr
        dd str_pos_bl
        dd str_pos_br

section .text

;=============================================================================
; Procedure: sprite_viewer_run
; Purpose:   Top-level runner and interactive loop for the hidden sprite viewer.
;            Reuses the existing UI frame, theme system, coat preset, and buffer.
;            Restores original application settings upon clean exit via Esc.
; IN:        None
; OUT:       None (returns to caller when Esc is pressed)
; CLOBBERS:  None (preserves all)
;=============================================================================
sprite_viewer_run:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp

    ; Step 1: Save current application settings to preserve state
    mov al, [setting_theme]
    mov [viewer_saved_theme], al
    mov al, [setting_coat]
    mov [viewer_saved_coat], al
    mov al, [setting_charset]
    mov [viewer_saved_charset], al

    ; Step 2: Initialize viewer state
    mov dword [viewer_sprite_idx], 0
    mov dword [viewer_frame_idx], 0
    mov dword [viewer_fill_slot], SLOT_SURFACE
    mov dword [viewer_edge_mode], 0
    mov dword [viewer_pos_x], 0
    mov dword [viewer_pos_y], 0

.viewer_loop:
    ; Update geometry and clear screen in SLOT_BG
    call ui_layout_update
    call sprite_viewer_draw

    ; Single write flush per frame (PRD_V3 invariant!)
    call buf_flush

.viewer_key_loop:
    call key_wait
    cmp eax, KEY_NONE
    je .viewer_key_loop

    ; --- Key Handling ---
    ; Escape -> Leave viewer cleanly
    cmp eax, KEY_ESC
    je .viewer_exit_clean

    ; 'q' / 'Q' -> Also leave viewer cleanly
    cmp eax, 'q'
    je .viewer_exit_clean
    cmp eax, 'Q'
    je .viewer_exit_clean

    ; Ctrl+C -> Signal application termination
    cmp eax, KEY_CTRL_C
    jne .check_nav_keys
    mov dword [state], STATE_QUIT
    jmp .viewer_exit_clean

.check_nav_keys:
    ; Left Arrow -> Previous Sprite
    cmp eax, KEY_LEFT
    jne .check_right
    mov eax, [viewer_sprite_idx]
    test eax, eax
    jz .wrap_sprite_prev
    dec eax
    jmp .set_sprite_idx
.wrap_sprite_prev:
    mov eax, [sprite_count]
    dec eax
.set_sprite_idx:
    mov [viewer_sprite_idx], eax
    mov dword [viewer_frame_idx], 0
    jmp .viewer_loop

.check_right:
    ; Right Arrow -> Next Sprite
    cmp eax, KEY_RIGHT
    jne .check_up
    mov eax, [viewer_sprite_idx]
    inc eax
    cmp eax, [sprite_count]
    jb .set_sprite_next
    xor eax, eax
.set_sprite_next:
    mov [viewer_sprite_idx], eax
    mov dword [viewer_frame_idx], 0
    jmp .viewer_loop

.check_up:
    ; Up Arrow -> Previous Animation Frame
    cmp eax, KEY_UP
    jne .check_down
    mov eax, [viewer_frame_idx]
    test eax, eax
    jz .viewer_loop
    dec eax
    mov [viewer_frame_idx], eax
    jmp .viewer_loop

.check_down:
    ; Down Arrow -> Next Animation Frame
    cmp eax, KEY_DOWN
    jne .check_theme_key
    ; Fetch active sprite's frame count
    mov edx, [viewer_sprite_idx]
    mov esi, [sprite_table + edx*4]
    call sprite_info            ; ECX = frame_count
    mov eax, [viewer_frame_idx]
    inc eax
    cmp eax, ecx
    jae .viewer_loop            ; Clamp safely to frame_count - 1
    mov [viewer_frame_idx], eax
    jmp .viewer_loop

.check_theme_key:
    ; 'T' / 't' -> Cycle Theme (0..NUM_BUILTIN_THEMES-1)
    cmp eax, 't'
    je .cycle_theme
    cmp eax, 'T'
    jne .check_coat_key
.cycle_theme:
    movzx eax, byte [setting_theme]
    inc eax
    cmp eax, NUM_BUILTIN_THEMES
    jb .theme_in_range
    xor eax, eax
.theme_in_range:
    mov [setting_theme], al
    call settings_apply_palette
    jmp .viewer_loop

.check_coat_key:
    ; 'C' / 'c' -> Cycle Cat Coat Preset (0..COAT_MAX_INDEX)
    cmp eax, 'c'
    je .cycle_coat
    cmp eax, 'C'
    jne .check_charset_key
.cycle_coat:
    movzx eax, byte [setting_coat]
    inc eax
    cmp eax, COAT_MAX_INDEX
    jbe .coat_in_range
    xor eax, eax
.coat_in_range:
    mov [setting_coat], al
    movzx eax, byte [setting_theme]
    call settings_apply_palette
    jmp .viewer_loop

.check_charset_key:
    ; 'A' / 'a' -> Toggle UTF-8 / ASCII mode
    cmp eax, 'a'
    je .toggle_charset
    cmp eax, 'A'
    jne .check_fill_keys
.toggle_charset:
    xor byte [setting_charset], 1
    jmp .viewer_loop

.check_fill_keys:
    ; '+' / '=' -> Next Fill Slot ID
    cmp eax, '+'
    je .inc_fill_slot
    cmp eax, '='
    jne .check_dec_fill
.inc_fill_slot:
    mov eax, [viewer_fill_slot]
    inc eax
    cmp eax, NUM_SLOTS
    jb .set_fill_slot
    xor eax, eax
    jmp .set_fill_slot

.check_dec_fill:
    ; '-' / '_' -> Previous Fill Slot ID
    cmp eax, '-'
    je .dec_fill_slot
    cmp eax, '_'
    jne .check_edge_keys
.dec_fill_slot:
    mov eax, [viewer_fill_slot]
    test eax, eax
    jz .wrap_fill_slot
    dec eax
    jmp .set_fill_slot
.wrap_fill_slot:
    mov eax, NUM_SLOTS - 1
.set_fill_slot:
    mov [viewer_fill_slot], eax
    jmp .viewer_loop

.check_edge_keys:
    ; Edge Clipping Preset Keys '1'..'9' (PRD_V3 §12.6 Edge Clipping Tests)
    cmp eax, '5'
    je .set_pos_center
    cmp eax, '8'
    je .set_pos_top
    cmp eax, '2'
    je .set_pos_bot
    cmp eax, '4'
    je .set_pos_left
    cmp eax, '6'
    je .set_pos_right
    cmp eax, '7'
    je .set_pos_tl
    cmp eax, '9'
    je .set_pos_tr
    cmp eax, '1'
    je .set_pos_bl
    cmp eax, '3'
    je .set_pos_br
    jmp .check_nudge_keys

.set_pos_center:
    mov dword [viewer_edge_mode], 0
    mov dword [viewer_pos_x], 0
    mov dword [viewer_pos_y], 0
    jmp .viewer_loop
.set_pos_top:
    mov dword [viewer_edge_mode], 1
    jmp .viewer_loop
.set_pos_bot:
    mov dword [viewer_edge_mode], 2
    jmp .viewer_loop
.set_pos_left:
    mov dword [viewer_edge_mode], 3
    jmp .viewer_loop
.set_pos_right:
    mov dword [viewer_edge_mode], 4
    jmp .viewer_loop
.set_pos_tl:
    mov dword [viewer_edge_mode], 5
    jmp .viewer_loop
.set_pos_tr:
    mov dword [viewer_edge_mode], 6
    jmp .viewer_loop
.set_pos_bl:
    mov dword [viewer_edge_mode], 7
    jmp .viewer_loop
.set_pos_br:
    mov dword [viewer_edge_mode], 8
    jmp .viewer_loop

.check_nudge_keys:
    ; Nudge keys: h (left), l (right), k (up), j (down)
    cmp eax, 'h'
    jne .chk_l
    dec dword [viewer_pos_x]
    jmp .viewer_loop
.chk_l:
    cmp eax, 'l'
    jne .chk_k
    inc dword [viewer_pos_x]
    jmp .viewer_loop
.chk_k:
    cmp eax, 'k'
    jne .chk_j
    dec dword [viewer_pos_y]
    jmp .viewer_loop
.chk_j:
    cmp eax, 'j'
    jne .viewer_key_loop
    inc dword [viewer_pos_y]
    jmp .viewer_loop

.viewer_exit_clean:
    ; Step 3: Restore initial settings to avoid persistent changes
    mov al, [viewer_saved_theme]
    mov [setting_theme], al
    mov al, [viewer_saved_coat]
    mov [setting_coat], al
    mov al, [viewer_saved_charset]
    mov [setting_charset], al
    movzx eax, byte [setting_theme]
    call settings_apply_palette

    call gfx_reset

    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: sprite_viewer_draw
; Purpose:   Renders the complete viewer frame, metadata labels, active sprite,
;            and footer controls into out_buf without independent syscalls.
; IN:        None
; OUT:       Appends rendered frame to out_buf
; CLOBBERS:  None (preserves all)
;=============================================================================
sprite_viewer_draw:
    save_regs
    push eax

    ; 1. Full Screen Background Fill (SLOT_BG)
    mov al, SLOT_BG
    call gfx_fill_screen_bg

    ; 2. Title Header
    mov eax, 2
    mov ebx, 3
    call ui_goto
    mov al, SLOT_TITLE
    call gfx_set_fg
    mov al, SLOT_BG
    call gfx_set_bg
    mov esi, str_viewer_title
    call buf_str

    ; 3. Metadata Row 1: Sprite Name & Frame
    mov eax, 4
    mov ebx, 3
    call ui_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_sprite
    call buf_str

    mov al, SLOT_TEXT
    call gfx_set_fg
    mov edx, [viewer_sprite_idx]
    mov esi, [sprite_names + edx*4]
    call buf_str

    mov al, CHAR_SPACE
    call buf_char
    mov al, CHAR_LBRACKET
    call buf_char
    mov eax, [viewer_sprite_idx]
    inc eax
    call buf_u32
    mov al, CHAR_SLASH
    call buf_char
    mov eax, [sprite_count]
    call buf_u32
    mov al, CHAR_RBRACKET
    call buf_char

    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_frame
    call buf_str

    mov al, SLOT_TEXT
    call gfx_set_fg
    mov eax, [viewer_frame_idx]
    inc eax
    call buf_u32
    mov al, CHAR_SLASH
    call buf_char
    ; Get total frames
    mov edx, [viewer_sprite_idx]
    mov esi, [sprite_table + edx*4]
    call sprite_info            ; ECX = frame_count
    mov eax, ecx
    call buf_u32

    ; 4. Metadata Row 2: Dimensions & Charset
    mov eax, 5
    mov ebx, 3
    call ui_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_size
    call buf_str

    mov al, SLOT_ACCENT
    call gfx_set_fg
    mov edx, [viewer_sprite_idx]
    mov esi, [sprite_table + edx*4]
    call sprite_info            ; EAX = w, EBX = h
    push ebx
    push eax
    call buf_u32                ; w
    mov al, 'x'
    call buf_char
    pop eax
    pop ebx
    push ebx
    push eax
    mov eax, ebx
    call buf_u32                ; h cells
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_cells
    call buf_str

    mov al, SLOT_ACCENT
    call gfx_set_fg
    pop eax                     ; w
    call buf_u32
    mov al, 'x'
    call buf_char
    pop ebx                     ; h cells
    mov eax, ebx
    shl eax, 1                  ; 2*h pixels
    call buf_u32

    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_px
    call buf_str

    mov al, SLOT_TEXT
    call gfx_set_fg
    cmp byte [setting_charset], 1
    je .show_mode_ascii
    mov esi, str_viewer_utf8
    call buf_str
    jmp .show_theme_row
.show_mode_ascii:
    mov esi, str_viewer_ascii
    call buf_str

.show_theme_row:
    ; 5. Metadata Row 3: Active Theme & Coat
    mov eax, 6
    mov ebx, 3
    call ui_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_theme
    call buf_str

    mov al, SLOT_TEXT
    call gfx_set_fg
    movzx edx, byte [setting_theme]
    mov esi, [theme_names + edx*4]
    call buf_str

    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_coat
    call buf_str

    mov al, SLOT_TEXT
    call gfx_set_fg
    movzx edx, byte [setting_coat]
    mov esi, [coat_names + edx*4]
    call buf_str

    ; 6. Metadata Row 4: Fill Background Slot & Position / Clipping Mode
    mov eax, 7
    mov ebx, 3
    call ui_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_fill
    call buf_str

    mov al, SLOT_TEXT
    call gfx_set_fg
    mov edx, [viewer_fill_slot]
    mov esi, [slot_names + edx*4]
    call buf_str

    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_pos
    call buf_str

    mov al, SLOT_ACCENT
    call gfx_set_fg
    mov edx, [viewer_edge_mode]
    mov esi, [pos_names + edx*4]
    call buf_str

    ; 6b. Metadata Row 5: Approved Glyphs Preview Strip
    mov eax, 8
    mov ebx, 3
    call ui_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov esi, str_viewer_glyphs
    call buf_str

    mov al, SLOT_ACCENT
    call gfx_set_fg
    xor ecx, ecx
.viewer_glyph_loop:
    cmp ecx, GLYPH_COUNT
    jae .viewer_glyph_done
    push ecx
    mov eax, ecx
    call ui_glyph_str
    call buf_str
    mov al, CHAR_SPACE
    call buf_char
    pop ecx
    inc ecx
    jmp .viewer_glyph_loop
.viewer_glyph_done:

    ; -------------------------------------------------------------------------
    ; 7. Calculate Sprite Destination Coordinates Based on Edge Mode & Nudge
    ; -------------------------------------------------------------------------
    mov edx, [viewer_sprite_idx]
    mov esi, [sprite_table + edx*4]
    call sprite_info            ; EAX = w_cells, EBX = h_cells

    ; Default: centered within usable space (rows 10..ui_h-2)
    ; center_row = (ui_h - h_cells) / 2 + 4
    mov ecx, [ui_h]
    sub ecx, ebx
    shr ecx, 1
    add ecx, 4                  ; ECX = default center_row
    cmp ecx, 10
    jge .row_min_ok
    mov ecx, 10
.row_min_ok:

    ; center_col = (ui_w - w_cells) / 2 + 1
    mov edx, [ui_w]
    sub edx, eax
    shr edx, 1
    inc edx                     ; EDX = default center_col
    cmp edx, 1
    jge .col_min_ok
    mov edx, 1
.col_min_ok:

    ; Check edge mode preset
    mov edi, [viewer_edge_mode]
    test edi, edi
    jz .apply_nudge             ; Mode 0: Center

    cmp edi, 1
    je .edge_top
    cmp edi, 2
    je .edge_bot
    cmp edi, 3
    je .edge_left
    cmp edi, 4
    je .edge_right
    cmp edi, 5
    je .edge_tl
    cmp edi, 6
    je .edge_tr
    cmp edi, 7
    je .edge_bl
    cmp edi, 8
    je .edge_br
    jmp .apply_nudge

.edge_top:
    mov ecx, -3                 ; Partially clipped top edge (starts above top)
    jmp .apply_nudge
.edge_bot:
    mov ecx, [ui_h]             ; Partially clipped bottom edge
    sub ecx, 3
    jmp .apply_nudge
.edge_left:
    mov edx, -5                 ; Partially clipped left edge
    jmp .apply_nudge
.edge_right:
    mov edx, [ui_w]             ; Partially clipped right edge
    sub edx, 6
    jmp .apply_nudge
.edge_tl:
    mov ecx, -3
    mov edx, -5
    jmp .apply_nudge
.edge_tr:
    mov ecx, -3
    mov edx, [ui_w]
    sub edx, 6
    jmp .apply_nudge
.edge_bl:
    mov ecx, [ui_h]
    sub ecx, 3
    mov edx, -5
    jmp .apply_nudge
.edge_br:
    mov ecx, [ui_h]
    sub ecx, 3
    mov edx, [ui_w]
    sub edx, 6

.apply_nudge:
    add ecx, [viewer_pos_y]     ; Add manual nudge offset Y
    add edx, [viewer_pos_x]     ; Add manual nudge offset X

    ; -------------------------------------------------------------------------
    ; 8. Render the Active Sprite
    ; -------------------------------------------------------------------------
    mov eax, ecx                ; EAX = destination row
    mov ebx, edx                ; EBX = destination column
    mov edx, [viewer_sprite_idx]
    mov esi, [sprite_table + edx*4] ; ESI = sprite descriptor
    mov ecx, [viewer_frame_idx]     ; ECX = frame index
    mov edx, [viewer_fill_slot]     ; EDX = fill background slot
    call sprite_draw

    ; -------------------------------------------------------------------------
    ; 9. Footer Key Help
    ; -------------------------------------------------------------------------
    mov eax, [ui_h]
    dec eax
    mov ebx, 2
    call ui_goto
    mov al, SLOT_DIM
    call gfx_set_fg
    mov al, SLOT_BG
    call gfx_set_bg
    mov esi, str_viewer_help
    call buf_str

    pop eax
    restore_regs
    ret

%endif ; SPRITE_VIEWER_ENABLED
