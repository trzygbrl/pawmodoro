; =============================================================================
; Pawmodoro - Settings Persistence Engine (src/settings.asm)
;
; Purpose: Serialization, deserialization, range validation, and persistence
;          of application configuration and theme palettes to settings.dat.
; Reference: PRD_V2 §4, §5 (24-byte settings.dat layout), §14 (Coding conventions)
; =============================================================================

; =============================================================================
; TEXT SECTION ROUTINES (section .text opened in src/main.asm)
; =============================================================================

;=============================================================================
; Procedure: settings_set_defaults
; Purpose:   Initializes all in-memory settings variables, active palette,
;            and custom palette to normative default values (PRD_V2 §5).
;            Strawberry Milk (Theme 0) is applied as the active palette.
; IN:        None
; OUT:       None (in-memory settings restored to default values)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_set_defaults:
    pushf
    push eax
    push ecx
    push esi
    push edi

    ; Scalar settings default values
    mov byte [setting_theme], THEME_STRAWBERRY
    mov byte [setting_anim], DEFAULT_ANIM
    mov byte [setting_sound], DEFAULT_SOUND
    mov byte [setting_charset], DEFAULT_CHARSET
    mov byte [setting_notify], DEFAULT_NOTIFY
    mov byte [setting_notify_layers], DEFAULT_NOTIFY_LAYERS
    mov byte [setting_volume], DEFAULT_VOLUME
    mov byte [settings_save_err], 0

    ; Copy Theme 0 (Strawberry Milk, 12 bytes = 3 dwords) into custom_palette
    mov esi, themes_table
    mov edi, custom_palette
    mov ecx, 3
    rep movsd

    ; Copy Theme 0 (Strawberry Milk, 12 bytes = 3 dwords) into active_palette
    mov esi, themes_table
    mov edi, active_palette
    mov ecx, 3
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_apply_palette
; Purpose:   Updates the 12-byte active_palette buffer from either a built-in
;            theme (0..6) or the saved custom_palette (7).
;            If index is out-of-range (> 7), defaults safely to Theme 0.
; IN:        AL = Theme index (0..7)
; OUT:       None (active_palette updated with 12 color bytes)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_apply_palette:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; Range check theme index in AL (0..7)
    cmp al, THEME_MAX_INDEX
    ja .apply_default

    cmp al, THEME_CUSTOM_INDEX
    je .apply_custom

    ; Built-in theme 0..6: calculate offset = AL * NUM_SLOTS (12 bytes)
    ; NUM_SLOTS is 12: AL * 12 = AL * 3 * 4
    movzx eax, al
    lea edx, [eax + eax*2]      ; EDX = AL * 3
    shl edx, 2                  ; EDX = AL * 12
    lea esi, [themes_table + edx]
    jmp .do_copy

.apply_custom:
    ; Theme 7: use 12 custom palette bytes
    mov esi, custom_palette
    jmp .do_copy

.apply_default:
    ; Out of range: fall back to Theme 0 (Strawberry Milk)
    mov esi, themes_table

.do_copy:
    mov edi, active_palette
    mov ecx, 3                  ; 3 dwords = 12 bytes
    rep movsd

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_load
; Purpose:   Initializes in-memory settings to defaults first, then attempts
;            to load and validate settings.dat.
;            Enforces exact 24-byte record length, magic dword 'PAWS',
;            version 1, and strict field range boundaries.
;            On missing file, read failure, truncation, detectable oversize,
;            or any field validation error, safely retains complete defaults.
;            Applies the loaded theme palette to active_palette on success.
; IN:        None
; OUT:       None (settings loaded or defaults retained; active_palette valid)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_load:
    pushf
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    ; 1. Always establish valid documented defaults first
    call settings_set_defaults

    ; 2. Attempt to read up to 25 bytes (SETTINGS_FILE_SIZE + 1)
    ; Passing capacity 25 allows detecting oversized files (> 24 bytes)
    ; because sys_read will return 25 if extra bytes exist.
    mov esi, path_settings
    mov edi, settings_buf
    mov ecx, SETTINGS_FILE_SIZE + 1
    call file_load

    ; 3. Check read result: file MUST be exactly 24 bytes
    ; If file is missing or read fails, EAX < 0 (FILE_ERR).
    ; If file is empty or truncated, EAX < 24.
    ; If file is oversized (>= 25 bytes), EAX == 25.
    ; In all invalid cases, safely retain defaults.
    cmp eax, SETTINGS_FILE_SIZE
    jne .load_done

    ; 4. Validate Magic Dword (offset 0, 4 bytes = 0x53574150 'PAWS')
    cmp dword [settings_buf + SETTINGS_OFF_MAGIC], SETTINGS_MAGIC
    jne .load_corrupt

    ; 5. Validate Version Byte (offset 4, 1 byte = 1)
    cmp byte [settings_buf + SETTINGS_OFF_VERSION], SETTINGS_VERSION
    jne .load_corrupt

    ; 6. Validate Theme Index (offset 5, 1 byte = 0..7)
    cmp byte [settings_buf + SETTINGS_OFF_THEME], THEME_MAX_INDEX
    ja .load_corrupt

    ; 7. Custom palette (offset 6..17, 12 bytes):
    ; Since all 8-bit unsigned byte values 0..255 are representable,
    ; individual custom palette bytes are inherently bounds-safe.

    ; 8. Validate Animation Flag (offset 18, 1 byte = 0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_ANIM], 1
    ja .load_corrupt

    ; 9. Validate Sound Flag (offset 19, 1 byte = 0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_SOUND], 1
    ja .load_corrupt

    ; 10. Validate Charset Flag (offset 20, 1 byte = 0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_CHARSET], 1
    ja .load_corrupt

    ; 11. Validate Notification Master Flag (offset 21, 1 byte = 0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_NOTIFY], 1
    ja .load_corrupt

    ; 12. Validate Notification Layers Bitmask (offset 22, only bits 0..4 allowed)
    test byte [settings_buf + SETTINGS_OFF_LAYERS], ~NOTIFY_LAYERS_MASK
    jnz .load_corrupt

    ; 13. Validate Volume (offset 23, 1 byte = 0..3)
    cmp byte [settings_buf + SETTINGS_OFF_VOLUME], MAX_VOLUME
    ja .load_corrupt

    ; -------------------------------------------------------------------------
    ; All structural and range validation passed! Apply settings to state.
    ; -------------------------------------------------------------------------
    mov al, [settings_buf + SETTINGS_OFF_THEME]
    mov [setting_theme], al

    ; Copy 12 custom palette bytes (3 dwords)
    lea esi, [settings_buf + SETTINGS_OFF_CUSTOM]
    mov edi, custom_palette
    mov ecx, 3
    rep movsd

    mov al, [settings_buf + SETTINGS_OFF_ANIM]
    mov [setting_anim], al

    mov al, [settings_buf + SETTINGS_OFF_SOUND]
    mov [setting_sound], al

    mov al, [settings_buf + SETTINGS_OFF_CHARSET]
    mov [setting_charset], al

    mov al, [settings_buf + SETTINGS_OFF_NOTIFY]
    mov [setting_notify], al

    mov al, [settings_buf + SETTINGS_OFF_LAYERS]
    mov [setting_notify_layers], al

    mov al, [settings_buf + SETTINGS_OFF_VOLUME]
    mov [setting_volume], al

    ; Synchronize active palette with loaded theme
    mov al, [setting_theme]
    call settings_apply_palette
    jmp .load_done

.load_corrupt:
    ; Reject entire record on any structural/range error: restore all defaults
    call settings_set_defaults

.load_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_save
; Purpose:   Serializes in-memory settings into the 24-byte binary format
;            and writes them to settings.dat via file_save.
;            Validates in-memory settings values before persisting;
;            never writes an invalid or corrupt record.
;            Updates settings_save_err: 0 on success, 1 on validation or
;            file I/O failure.
; IN:        None
; OUT:       None (writes settings.dat; sets or clears settings_save_err)
; CLOBBERS:  None (preserves all general-purpose registers and EFLAGS)
;=============================================================================
settings_save:
    pushf
    push eax
    push ecx
    push esi
    push edi

    ; 1. Pre-save validation: ensure in-memory settings are strictly valid
    cmp byte [setting_theme], THEME_MAX_INDEX
    ja .save_invalid

    cmp byte [setting_anim], 1
    ja .save_invalid

    cmp byte [setting_sound], 1
    ja .save_invalid

    cmp byte [setting_charset], 1
    ja .save_invalid

    cmp byte [setting_notify], 1
    ja .save_invalid

    test byte [setting_notify_layers], ~NOTIFY_LAYERS_MASK
    jnz .save_invalid

    cmp byte [setting_volume], MAX_VOLUME
    ja .save_invalid

    ; 2. Serialize in-memory settings into settings_buf (24 bytes)
    ; Offset 0 (4 bytes): Magic 'PAWS' (0x53574150)
    mov dword [settings_buf + SETTINGS_OFF_MAGIC], SETTINGS_MAGIC

    ; Offset 4 (1 byte): Version 1
    mov byte [settings_buf + SETTINGS_OFF_VERSION], SETTINGS_VERSION

    ; Offset 5 (1 byte): Theme index
    mov al, [setting_theme]
    mov [settings_buf + SETTINGS_OFF_THEME], al

    ; Offset 6..17 (12 bytes = 3 dwords): Custom palette
    mov esi, custom_palette
    lea edi, [settings_buf + SETTINGS_OFF_CUSTOM]
    mov ecx, 3
    rep movsd

    ; Scalar configuration flags
    mov al, [setting_anim]
    mov [settings_buf + SETTINGS_OFF_ANIM], al

    mov al, [setting_sound]
    mov [settings_buf + SETTINGS_OFF_SOUND], al

    mov al, [setting_charset]
    mov [settings_buf + SETTINGS_OFF_CHARSET], al

    mov al, [setting_notify]
    mov [settings_buf + SETTINGS_OFF_NOTIFY], al

    mov al, [setting_notify_layers]
    mov [settings_buf + SETTINGS_OFF_LAYERS], al

    mov al, [setting_volume]
    mov [settings_buf + SETTINGS_OFF_VOLUME], al

    ; 3. Write exactly 24 bytes to settings.dat via file_save
    mov esi, path_settings
    mov edi, settings_buf
    mov ecx, SETTINGS_FILE_SIZE
    call file_save

    ; 4. Check file_save result (0 = FILE_OK, -1 = FILE_ERR)
    cmp eax, FILE_OK
    jne .save_io_err

    ; Save succeeded: clear failure flag
    mov byte [settings_save_err], 0
    jmp .save_done

.save_invalid:
.save_io_err:
    ; Validation failed or disk write failed: set save failure flag
    mov byte [settings_save_err], 1

.save_done:
    pop edi
    pop esi
    pop ecx
    pop eax
    popf
    ret
