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
;=============================================================================
; Procedure: settings_set_defaults
; Purpose:   Initializes all in-memory settings variables, active palette,
;            and custom palette to normative default values (PRD_V3 §5, §6).
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
    mov byte [setting_mouse], DEFAULT_MOUSE
    mov byte [setting_coat], DEFAULT_COAT
    xor eax, eax
    mov dword [setting_reserved], eax
    mov word [setting_reserved + 4], ax
    mov byte [settings_save_err], 0

    ; Copy Theme 0 (Strawberry Milk, 24 bytes = 6 dwords) into custom_palette
    mov esi, themes_table
    mov edi, custom_palette
    mov ecx, 6
    rep movsd

    ; Copy Theme 0 (Strawberry Milk, 24 bytes = 6 dwords) into active_palette
    mov esi, themes_table
    mov edi, active_palette
    mov ecx, 6
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    popf
    ret

;=============================================================================
; Procedure: settings_apply_palette
; Purpose:   Updates the 24-byte active_palette buffer from either a built-in
;            theme (0..6) or the saved custom_palette (7).
;            Then applies the selected cat-coat preset override to slots 18..21.
;            Slots 22 (OUTLINE) and 23 (EYE_NOSE) continue to come from the theme.
;            If index is out-of-range (> 7), defaults safely to Theme 0.
; IN:        AL = Theme index (0..7)
; OUT:       None (active_palette updated with 24 color bytes)
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

    ; Built-in theme 0..6: calculate offset = AL * NUM_SLOTS (24 bytes)
    ; NUM_SLOTS is 24: AL * 24 = (AL * 3) * 8
    movzx eax, al
    lea edx, [eax + eax*2]      ; EDX = AL * 3
    shl edx, 3                  ; EDX = AL * 24
    lea esi, [themes_table + edx]
    jmp .do_copy_theme

.apply_custom:
    ; Theme 7: use 24 custom palette bytes
    mov esi, custom_palette
    jmp .do_copy_theme

.apply_default:
    ; Out of range: fall back to Theme 0 (Strawberry Milk)
    mov esi, themes_table

.do_copy_theme:
    mov edi, active_palette
    mov ecx, 6                  ; 6 dwords = 24 bytes
    rep movsd

    ; -------------------------------------------------------------------------
    ; Coat Preset Override for Slots 18..21:
    ; FUR (18), FUR_SHADE (19), FUR_STRIPE (20), EAR_BLUSH (21)
    ; Slots 22 (OUTLINE) and 23 (EYE_NOSE) continue to come from the theme.
    ; -------------------------------------------------------------------------
    movzx edx, byte [setting_coat]
    cmp edx, COAT_CUSTOM
    jae .apply_coat_custom

    ; Coat Preset 0..5: Fetch 4 override bytes from coat_table
    shl edx, 2                  ; 4 bytes per preset in coat_table
    mov eax, dword [coat_table + edx]
    mov dword [active_palette + 18], eax
    jmp .coat_done

.apply_coat_custom:
    ; Coat 6 (Custom): Retain user's custom art colors from custom_palette[18..21]
    mov eax, dword [custom_palette + 18]
    mov dword [active_palette + 18], eax

.coat_done:
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
;            Accepts valid Version 2 files (exactly 48 bytes) and migrates valid
;            Version 1 files (exactly 24 bytes) transparently.
;            Enforces exact length, magic dword 'PAWS', version checks,
;            and strict field range boundaries.
;            On missing file, read failure, truncation, oversize, or any field
;            validation error, safely retains complete defaults.
;            Applies the loaded theme palette and coat to active_palette on success.
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

    ; 2. Attempt to read up to 49 bytes (SETTINGS_FILE_SIZE + 1)
    ; Passing capacity 49 allows detecting oversized files (> 48 bytes)
    mov esi, path_settings
    mov edi, settings_buf
    mov ecx, SETTINGS_FILE_SIZE + 1
    call file_load

    ; 3. Check read result: file MUST be either exactly 48 bytes (v2)
    ; or exactly 24 bytes (legacy v1 migration).
    ; Any other size (truncated, oversized, missing) safely retains defaults.
    cmp eax, SETTINGS_FILE_SIZE     ; 48
    je .load_v2
    cmp eax, SETTINGS_V1_FILE_SIZE  ; 24
    je .load_v1
    jmp .load_done                  ; Missing or invalid size: keep defaults

    ; -------------------------------------------------------------------------
    ; Version 2 Parser & Validator (48 bytes)
    ; -------------------------------------------------------------------------
.load_v2:
    ; Magic Dword ('PAWS' = 0x53574150)
    cmp dword [settings_buf + SETTINGS_OFF_MAGIC], SETTINGS_MAGIC
    jne .load_corrupt

    ; Version (MUST be exactly 2)
    cmp byte [settings_buf + SETTINGS_OFF_VERSION], SETTINGS_VERSION
    jne .load_corrupt

    ; Theme Index (0..7)
    cmp byte [settings_buf + SETTINGS_OFF_THEME], THEME_MAX_INDEX
    ja .load_corrupt

    ; Anim flag (0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_ANIM], 1
    ja .load_corrupt

    ; Sound flag (0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_SOUND], 1
    ja .load_corrupt

    ; Charset flag (0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_CHARSET], 1
    ja .load_corrupt

    ; Notify master flag (0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_NOTIFY], 1
    ja .load_corrupt

    ; Notify layers bitmask (only bits 0..4 allowed)
    test byte [settings_buf + SETTINGS_OFF_LAYERS], ~NOTIFY_LAYERS_MASK
    jnz .load_corrupt

    ; Volume (0..3)
    cmp byte [settings_buf + SETTINGS_OFF_VOLUME], MAX_VOLUME
    ja .load_corrupt

    ; Mouse flag (0 or 1)
    cmp byte [settings_buf + SETTINGS_OFF_MOUSE], 1
    ja .load_corrupt

    ; Coat index (0..6)
    cmp byte [settings_buf + SETTINGS_OFF_COAT], COAT_MAX_INDEX
    ja .load_corrupt

    ; Reserved 6 bytes (MUST all be 0)
    cmp dword [settings_buf + SETTINGS_OFF_RESERVED], 0
    jne .load_corrupt
    cmp word [settings_buf + SETTINGS_OFF_RESERVED + 4], 0
    jne .load_corrupt

    ; All v2 validation passed! Apply settings to state:
    mov al, [settings_buf + SETTINGS_OFF_THEME]
    mov [setting_theme], al

    ; Copy 24 custom palette bytes (6 dwords)
    lea esi, [settings_buf + SETTINGS_OFF_CUSTOM]
    mov edi, custom_palette
    mov ecx, 6
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

    mov al, [settings_buf + SETTINGS_OFF_MOUSE]
    mov [setting_mouse], al

    mov al, [settings_buf + SETTINGS_OFF_COAT]
    mov [setting_coat], al

    ; Clear reserved bytes
    xor eax, eax
    mov dword [setting_reserved], eax
    mov word [setting_reserved + 4], ax

    ; Synchronize active palette with loaded theme and coat
    mov al, [setting_theme]
    call settings_apply_palette
    jmp .load_done

    ; -------------------------------------------------------------------------
    ; Version 1 Migration Parser & Validator (24 bytes)
    ; -------------------------------------------------------------------------
.load_v1:
    ; Magic Dword ('PAWS' = 0x53574150)
    cmp dword [settings_buf + SETTINGS_OFF_MAGIC], SETTINGS_MAGIC
    jne .load_corrupt

    ; Version (MUST be exactly 1)
    cmp byte [settings_buf + SETTINGS_OFF_VERSION], SETTINGS_V1_VERSION
    jne .load_corrupt

    ; Theme Index (0..7)
    cmp byte [settings_buf + SETTINGS_OFF_THEME], THEME_MAX_INDEX
    ja .load_corrupt

    ; Anim flag (0 or 1) at v1 offset 18
    cmp byte [settings_buf + SETTINGS_V1_OFF_ANIM], 1
    ja .load_corrupt

    ; Sound flag (0 or 1) at v1 offset 19
    cmp byte [settings_buf + SETTINGS_V1_OFF_SOUND], 1
    ja .load_corrupt

    ; Charset flag (0 or 1) at v1 offset 20
    cmp byte [settings_buf + SETTINGS_V1_OFF_CHARSET], 1
    ja .load_corrupt

    ; Notify master flag (0 or 1) at v1 offset 21
    cmp byte [settings_buf + SETTINGS_V1_OFF_NOTIFY], 1
    ja .load_corrupt

    ; Notify layers bitmask at v1 offset 22
    test byte [settings_buf + SETTINGS_V1_OFF_LAYERS], ~NOTIFY_LAYERS_MASK
    jnz .load_corrupt

    ; Volume (0..3) at v1 offset 23
    cmp byte [settings_buf + SETTINGS_V1_OFF_VOLUME], MAX_VOLUME
    ja .load_corrupt

    ; All v1 validation passed! Populate state and fill v2 defaults:
    mov al, [settings_buf + SETTINGS_OFF_THEME]
    mov [setting_theme], al

    ; Copy 12 v1 custom palette bytes (3 dwords) into custom_palette[0..11]
    lea esi, [settings_buf + SETTINGS_OFF_CUSTOM]
    mov edi, custom_palette
    mov ecx, 3
    rep movsd

    ; Populate new slots 12..23 from Theme 0 default palette (3 dwords = 12 bytes)
    lea esi, [themes_table + 12]
    mov edi, custom_palette + 12
    mov ecx, 3
    rep movsd

    mov al, [settings_buf + SETTINGS_V1_OFF_ANIM]
    mov [setting_anim], al

    mov al, [settings_buf + SETTINGS_V1_OFF_SOUND]
    mov [setting_sound], al

    mov al, [settings_buf + SETTINGS_V1_OFF_CHARSET]
    mov [setting_charset], al

    mov al, [settings_buf + SETTINGS_V1_OFF_NOTIFY]
    mov [setting_notify], al

    mov al, [settings_buf + SETTINGS_V1_OFF_LAYERS]
    mov [setting_notify_layers], al

    mov al, [settings_buf + SETTINGS_V1_OFF_VOLUME]
    mov [setting_volume], al

    ; New v2 defaults
    mov byte [setting_mouse], DEFAULT_MOUSE ; 1
    mov byte [setting_coat], DEFAULT_COAT   ; 0 (Orange Tabby)

    xor eax, eax
    mov dword [setting_reserved], eax
    mov word [setting_reserved + 4], ax

    ; Synchronize active palette
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
; Purpose:   Serializes in-memory settings into the 48-byte Version 2 binary
;            format and writes them to settings.dat via file_save.
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

    cmp byte [setting_mouse], 1
    ja .save_invalid

    cmp byte [setting_coat], COAT_MAX_INDEX
    ja .save_invalid

    ; 2. Serialize in-memory settings into settings_buf (48 bytes)
    ; Offset 0 (4 bytes): Magic 'PAWS' (0x53574150)
    mov dword [settings_buf + SETTINGS_OFF_MAGIC], SETTINGS_MAGIC

    ; Offset 4 (1 byte): Version 2
    mov byte [settings_buf + SETTINGS_OFF_VERSION], SETTINGS_VERSION

    ; Offset 5 (1 byte): Theme index
    mov al, [setting_theme]
    mov [settings_buf + SETTINGS_OFF_THEME], al

    ; Offset 6..29 (24 bytes = 6 dwords): Custom palette
    mov esi, custom_palette
    lea edi, [settings_buf + SETTINGS_OFF_CUSTOM]
    mov ecx, 6
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

    mov al, [setting_mouse]
    mov [settings_buf + SETTINGS_OFF_MOUSE], al

    mov al, [setting_coat]
    mov [settings_buf + SETTINGS_OFF_COAT], al

    ; Offset 38..43 (6 bytes): Reserved = 0
    xor eax, eax
    mov dword [settings_buf + SETTINGS_OFF_RESERVED], eax
    mov word [settings_buf + SETTINGS_OFF_RESERVED + 4], ax

    ; 3. Write exactly 48 bytes to settings.dat via file_save
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
