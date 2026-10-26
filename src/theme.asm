; =============================================================================
; Pawmodoro - 256-Color Theme Engine (src/theme.asm)
;
; Purpose: Centralized ANSI 256-color escape rendering for theme color slots.
;          Translates slot IDs (0..11) into foreground (ESC[38;5;Nm) and
;          background (ESC[48;5;Nm) escape sequences appended to out_buf.
; Reference: PRD_V2 §4 (Theme and color-slot model), §14 (Coding conventions)
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: ui_color
; Purpose:   Appends the 256-color foreground escape sequence ESC[38;5;Nm for
;            the active palette's slot ID to the frame buffer (out_buf).
;            If the slot ID is invalid (AL >= NUM_SLOTS), appends nothing and
;            returns safely without altering the output buffer.
; IN:        AL = Slot ID (0..NUM_SLOTS-1, SLOT_*)
; OUT:       None (appends foreground escape sequence to out_buf)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
ui_color:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate slot ID in AL (must be strictly < NUM_SLOTS)
    cmp al, NUM_SLOTS
    jae .color_invalid          ; Out-of-bounds slot ID: silently drop

    ; Look up 256-color byte (0..255) from active_palette
    movzx ebx, al
    movzx eax, byte [active_palette + ebx]

    ; 1. Emit foreground sequence prefix: ESC[38;5;
    mov esi, ansi_fg_256_prefix
    call buf_str

    ; 2. Emit unsigned decimal color index (0..255)
    call buf_u32

    ; 3. Emit closing letter 'm'
    mov al, CHAR_LOWER_M
    call buf_char

.color_invalid:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: ui_bgcolor
; Purpose:   Appends the 256-color background escape sequence ESC[48;5;Nm for
;            the active palette's slot ID to the frame buffer (out_buf).
;            Used for highlighted selections and active status backgrounds.
;            If the slot ID is invalid (AL >= NUM_SLOTS), appends nothing and
;            returns safely without altering the output buffer.
; IN:        AL = Slot ID (0..NUM_SLOTS-1, SLOT_*)
; OUT:       None (appends background escape sequence to out_buf)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
ui_bgcolor:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Validate slot ID in AL (must be strictly < NUM_SLOTS)
    cmp al, NUM_SLOTS
    jae .bgcolor_invalid        ; Out-of-bounds slot ID: silently drop

    ; Look up 256-color byte (0..255) from active_palette
    movzx ebx, al
    movzx eax, byte [active_palette + ebx]

    ; 1. Emit background sequence prefix: ESC[48;5;
    mov esi, ansi_bg_256_prefix
    call buf_str

    ; 2. Emit unsigned decimal color index (0..255)
    call buf_u32

    ; 3. Emit closing letter 'm'
    mov al, CHAR_LOWER_M
    call buf_char

.bgcolor_invalid:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret
