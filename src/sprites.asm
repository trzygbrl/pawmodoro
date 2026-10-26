; =============================================================================
; Pawmodoro - Sprite Asset Definitions & Macros (src/sprites.asm)
;
; Purpose: Canonical NASM sprite definition macros and precompiled sprite assets
;          for Pawmodoro v3 per PRD_V3 §4.2 and §sprites.
; =============================================================================

section .data

; =============================================================================
; Canonical Sprite Data Macros (PRD_V3 §4.2)
; =============================================================================

; -----------------------------------------------------------------------------
; Macro: SPRITE_BEGIN
; Purpose: Starts a new sprite descriptor and defines its exported symbol.
; Parameters:
;   %1 = Symbol name (e.g. sprite_logo_cat)
;   %2 = Width in terminal cells (1..120)
;   %3 = Height in pixel rows (MUST BE EVEN, 2..80)
;   %4 = Number of animation frames (>= 1)
; Binary Layout:
;   Offset 0x00: width_cells     (1 byte)
;   Offset 0x01: height_pixels   (1 byte)
;   Offset 0x02: frame_count     (1 byte)
; -----------------------------------------------------------------------------
%macro SPRITE_BEGIN 4
    global %1
    %1:
    %if (%3 % 2) != 0
        %error "SPRITE_BEGIN: height_pixels must be an even integer."
    %endif
    db %2       ; width_cells
    db %3       ; height_pixels
    db %4       ; frame_count
%endmacro

; -----------------------------------------------------------------------------
; Macro: SPRITE_PALETTE
; Purpose: Defines the palette-to-theme-slot mapping table.
; Parameters:
;   1 to 15 theme slot IDs (SLOT_*)
; Binary Layout:
;   Offset 0x03: palette_entries (1 byte, 1..15)
;   Offset 0x04: slot_map[N]     (N bytes)
; -----------------------------------------------------------------------------
%macro SPRITE_PALETTE 1-*
    %if %0 > 15
        %error "SPRITE_PALETTE: maximum 15 palette entries allowed."
    %endif
    db %0       ; palette_entries count
    %rep %0
        db %1
        %rotate 1
    %endrep
%endmacro

; -----------------------------------------------------------------------------
; Macro: SPRITE_RLE
; Purpose: Emits run-length encoded pairs (count, palette_index).
; Parameters:
;   Comma-separated list of run_length, palette_index bytes.
; -----------------------------------------------------------------------------
%macro SPRITE_RLE 1-*
    db %{1:-1}
%endmacro

; -----------------------------------------------------------------------------
; Macro: SPRITE_FRAME_END
; Purpose: Emits the 0x00 sentinel marking the end of an RLE frame stream.
; -----------------------------------------------------------------------------
%macro SPRITE_FRAME_END 0
    db 0x00
%endmacro

; -----------------------------------------------------------------------------
; Macro: SPRITE_ASCII_BEGIN
; Purpose: Emits the ASCII line count byte.
; Parameters:
;   %1 = Number of ASCII lines (equal to height_cells = height_pixels / 2)
; -----------------------------------------------------------------------------
%macro SPRITE_ASCII_BEGIN 1
    db %1
%endmacro

; -----------------------------------------------------------------------------
; Macro: SPRITE_ASCII_LINE
; Purpose: Emits a length-prefixed 7-bit ASCII line for fallback rendering.
; Parameters:
;   %1 = ASCII string literal (all bytes must be < 0x80)
; -----------------------------------------------------------------------------
%macro SPRITE_ASCII_LINE 1
    db (%%line_end - %%line_start)
%%line_start:
    db %1
%%line_end:
%endmacro

; -----------------------------------------------------------------------------
; Macro: SPRITE_END
; Purpose: Marks the logical end of a sprite descriptor.
; -----------------------------------------------------------------------------
%macro SPRITE_END 0
%endmacro

; =============================================================================
; Precompiled Sprite Assets
; =============================================================================

; -----------------------------------------------------------------------------
; Sprite: sprite_logo_cat
; Source Crop: docs/reference/sprites/logo_cat_crop.png (from reference dashboard)
; Dimensions: 20 cells wide x 20 pixel rows high (10 cell rows)
; Frames: 1 (Idle brand avatar)
; Palette: 8 mapped slots (OUTLINE, FUR, FUR_SHADE, FUR_STRIPE, EAR_BLUSH, EYE_NOSE, TEXT, ACCENT)
; Total binary payload: 646 bytes (well within the 6 KiB per-sprite budget)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_logo_cat, 20, 20, 1
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (211 runs) ---
    SPRITE_RLE 3, 0, 1, 4, 1, 1, 10, 0
    SPRITE_RLE 1, 1, 1, 4, 5, 0, 1, 1
    SPRITE_RLE 2, 3, 1, 1, 8, 0, 1, 4
    SPRITE_RLE 2, 3, 1, 1, 4, 0, 1, 4
    SPRITE_RLE 3, 3, 1, 1, 1, 0, 4, 1
    SPRITE_RLE 1, 0, 1, 4, 1, 2, 2, 5
    SPRITE_RLE 1, 4, 4, 0, 1, 4, 1, 5
    SPRITE_RLE 1, 4, 1, 3, 1, 4, 1, 1
    SPRITE_RLE 4, 4, 1, 1, 2, 3, 1, 4
    SPRITE_RLE 1, 2, 1, 4, 3, 0, 1, 1
    SPRITE_RLE 1, 3, 1, 5, 2, 4, 1, 3
    SPRITE_RLE 2, 4, 4, 3, 1, 2, 2, 3
    SPRITE_RLE 1, 2, 1, 3, 3, 0, 1, 1
    SPRITE_RLE 1, 4, 1, 5, 3, 3, 2, 4
    SPRITE_RLE 4, 3, 2, 2, 1, 3, 1, 5
    SPRITE_RLE 1, 4, 3, 0, 1, 1, 2, 4
    SPRITE_RLE 1, 3, 1, 2, 1, 3, 1, 4
    SPRITE_RLE 4, 3, 2, 2, 1, 8, 1, 5
    SPRITE_RLE 1, 3, 1, 4, 4, 0, 1, 4
    SPRITE_RLE 2, 3, 1, 2, 2, 3, 1, 2
    SPRITE_RLE 2, 5, 5, 2, 1, 5, 1, 4
    SPRITE_RLE 4, 0, 1, 4, 5, 3, 9, 2
    SPRITE_RLE 1, 4, 3, 0, 1, 1, 1, 4
    SPRITE_RLE 4, 3, 2, 2, 2, 8, 6, 2
    SPRITE_RLE 1, 3, 1, 1, 2, 0, 2, 4
    SPRITE_RLE 2, 3, 1, 1, 1, 4, 2, 2
    SPRITE_RLE 2, 8, 2, 2, 2, 4, 1, 5
    SPRITE_RLE 2, 2, 1, 4, 2, 0, 1, 1
    SPRITE_RLE 1, 4, 1, 3, 1, 4, 1, 1
    SPRITE_RLE 1, 4, 1, 3, 1, 8, 2, 7
    SPRITE_RLE 1, 8, 1, 3, 1, 4, 1, 1
    SPRITE_RLE 1, 3, 1, 2, 1, 3, 1, 4
    SPRITE_RLE 1, 0, 2, 1, 1, 4, 1, 3
    SPRITE_RLE 1, 2, 1, 4, 1, 1, 1, 2
    SPRITE_RLE 1, 7, 2, 2, 1, 7, 1, 2
    SPRITE_RLE 1, 1, 1, 4, 1, 8, 1, 2
    SPRITE_RLE 1, 4, 4, 1, 1, 4, 2, 2
    SPRITE_RLE 2, 3, 1, 8, 1, 7, 2, 5
    SPRITE_RLE 1, 7, 1, 8, 1, 3, 1, 5
    SPRITE_RLE 2, 2, 1, 4, 2, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 4, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 2, 7, 1, 2, 2, 3
    SPRITE_RLE 1, 5, 2, 7, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 1, 4, 1, 1, 1, 0
    SPRITE_RLE 2, 1, 1, 4, 13, 8, 1, 2
    SPRITE_RLE 1, 4, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 1, 2, 5, 8, 3, 7, 4, 8
    SPRITE_RLE 1, 2, 1, 1, 5, 0, 1, 4
    SPRITE_RLE 1, 5, 3, 8, 4, 7, 3, 8
    SPRITE_RLE 1, 3, 1, 4, 7, 0, 1, 1
    SPRITE_RLE 1, 4, 1, 3, 1, 5, 3, 2
    SPRITE_RLE 2, 5, 1, 3, 1, 4, 1, 1
    SPRITE_RLE 10, 0, 9, 1, 5, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (10 lines) ---
    SPRITE_ASCII_BEGIN 10
    SPRITE_ASCII_LINE "  _=%_        .%=_  "
    SPRITE_ASCII_LINE "  =@=%=_====_=%@@=  "
    SPRITE_ASCII_LINE " #=@==%==%%%%#%%@=  "
    SPRITE_ASCII_LINE " ~==%#%=%@@%###@@=  "
    SPRITE_ASCII_LINE " _=%%%%%#########=_ "
    SPRITE_ASCII_LINE " ==%=#=%####%==@#%= "
    SPRITE_ASCII_LINE "##=%#=%##@@##%@##=##"
    SPRITE_ASCII_LINE "_#=#@####%%@###@#=# "
    SPRITE_ASCII_LINE "  ~=@##########%=~  "
    SPRITE_ASCII_LINE "    ~'%@###@@%=~    "
SPRITE_END

; =============================================================================
; Sprite Registry Table (for Hidden Sprite Viewer & Runtime Dispatch)
; =============================================================================

global sprite_count
global sprite_table
global sprite_names

sprite_count:           dd 1
sprite_table:           dd sprite_logo_cat
sprite_names:           dd sprite_name_logo_cat

sprite_name_logo_cat:   db "Logo Cat (Brand)", CHAR_NULL
