; =============================================================================
; Pawmodoro - Sprite Asset Definitions & Macros (src/sprites.asm)
;
; Purpose: Canonical NASM sprite definition macros, precompiled cat-and-mascot
;          art pack, and sprite registry table for Pawmodoro v3 per PRD_V3 §4.2,
;          §sprites, and Task G4 (Cats & Mascots).
; =============================================================================

section .data

; =============================================================================
; Canonical Sprite Data Macros (PRD_V3 §4.2)
; =============================================================================

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

%macro SPRITE_RLE 1-*
    db %{1:-1}
%endmacro

%macro SPRITE_FRAME_END 0
    db 0x00
%endmacro

%macro SPRITE_ASCII_BEGIN 1
    db %1
%endmacro

%macro SPRITE_ASCII_LINE 1
    db (%%line_end - %%line_start)
%%line_start:
    db %1
%%line_end:
%endmacro

%macro SPRITE_END 0
%endmacro

; =============================================================================
; Precompiled Sprite Assets (Task G4 Cat & Mascot Art Pack)
; =============================================================================

; -----------------------------------------------------------------------------
; Sprite: sprite_logo_cat
; Name: Logo Cat (Grand 14x7)
; Dimensions: 14 cells wide x 14 pixel rows high (7 cell rows)
; Frames: 3 | Payload: 645 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_logo_cat, 14, 14, 3
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (89 runs) ---
    SPRITE_RLE 1, 0, 2, 1, 8, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 6, 0, 1, 1, 2, 5, 2, 1
    SPRITE_RLE 3, 5, 6, 1, 3, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 5, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 2, 4, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 1, 5, 1, 2, 2, 1
    SPRITE_RLE 2, 2, 1, 4, 2, 2, 2, 4
    SPRITE_RLE 2, 2, 1, 4, 2, 2, 2, 1
    SPRITE_RLE 1, 3, 10, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 3, 1, 6, 1, 8, 6, 2
    SPRITE_RLE 1, 6, 1, 8, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 2, 2, 2, 6
    SPRITE_RLE 2, 2, 2, 6, 1, 2, 2, 1
    SPRITE_RLE 1, 2, 2, 5, 2, 7, 2, 6
    SPRITE_RLE 2, 7, 2, 5, 1, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 2, 3, 7
    SPRITE_RLE 2, 6, 3, 7, 1, 2, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 10, 7, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 1, 2, 8, 7
    SPRITE_RLE 1, 2, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 8, 2, 1, 1, 5, 0, 8, 1
    SPRITE_RLE 3, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (85 runs) ---
    SPRITE_RLE 1, 0, 2, 1, 8, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 6, 0, 1, 1, 2, 5, 2, 1
    SPRITE_RLE 3, 5, 6, 1, 3, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 5, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 2, 4, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 1, 5, 1, 2, 2, 1
    SPRITE_RLE 2, 2, 1, 4, 2, 2, 2, 4
    SPRITE_RLE 2, 2, 1, 4, 2, 2, 2, 1
    SPRITE_RLE 1, 3, 10, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 3, 10, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 2, 2, 2, 6
    SPRITE_RLE 2, 2, 2, 6, 1, 2, 2, 1
    SPRITE_RLE 1, 2, 2, 5, 2, 7, 2, 6
    SPRITE_RLE 2, 7, 2, 5, 1, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 2, 3, 7
    SPRITE_RLE 2, 6, 3, 7, 1, 2, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 10, 7, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 1, 2, 8, 7
    SPRITE_RLE 1, 2, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 8, 2, 1, 1, 5, 0, 8, 1
    SPRITE_RLE 3, 0
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (88 runs) ---
    SPRITE_RLE 2, 1, 9, 0, 2, 1, 2, 0
    SPRITE_RLE 1, 1, 1, 5, 1, 1, 6, 0
    SPRITE_RLE 1, 1, 2, 5, 2, 1, 3, 5
    SPRITE_RLE 6, 1, 3, 5, 2, 1, 1, 2
    SPRITE_RLE 1, 5, 1, 2, 1, 4, 1, 2
    SPRITE_RLE 2, 4, 1, 2, 1, 4, 1, 2
    SPRITE_RLE 1, 5, 1, 2, 2, 1, 2, 2
    SPRITE_RLE 1, 4, 2, 2, 2, 4, 2, 2
    SPRITE_RLE 1, 4, 2, 2, 2, 1, 1, 3
    SPRITE_RLE 10, 2, 1, 3, 2, 1, 1, 3
    SPRITE_RLE 1, 6, 1, 8, 6, 2, 1, 6
    SPRITE_RLE 1, 8, 1, 3, 2, 1, 1, 2
    SPRITE_RLE 2, 6, 2, 2, 2, 6, 2, 2
    SPRITE_RLE 2, 6, 1, 2, 2, 1, 1, 2
    SPRITE_RLE 2, 5, 2, 7, 2, 6, 2, 7
    SPRITE_RLE 2, 5, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 2, 3, 7, 2, 6
    SPRITE_RLE 3, 7, 1, 2, 1, 1, 2, 0
    SPRITE_RLE 1, 1, 10, 7, 1, 1, 2, 0
    SPRITE_RLE 1, 1, 1, 2, 8, 7, 1, 2
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 8, 2
    SPRITE_RLE 1, 1, 5, 0, 8, 1, 3, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (7 lines) ---
    SPRITE_ASCII_BEGIN 7
    SPRITE_ASCII_LINE " /\_\    /_/\ "
    SPRITE_ASCII_LINE "( o.o    o.o )"
    SPRITE_ASCII_LINE " >  ^    ^  < "
    SPRITE_ASCII_LINE "   (=^..^=)   "
    SPRITE_ASCII_LINE "  (   ~~   )  "
    SPRITE_ASCII_LINE "   \      /   "
    SPRITE_ASCII_LINE "    '----'    "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_logo_cat_std
; Name: Logo Cat (Std 12x6)
; Dimensions: 12 cells wide x 12 pixel rows high (6 cell rows)
; Frames: 3 | Payload: 494 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_logo_cat_std, 12, 12, 3
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (69 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 8, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 6, 0, 1, 1, 1, 5, 2, 1
    SPRITE_RLE 2, 5, 6, 1, 2, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 5, 1, 4, 1, 2
    SPRITE_RLE 2, 4, 1, 2, 1, 4, 1, 5
    SPRITE_RLE 1, 2, 2, 1, 3, 2, 1, 4
    SPRITE_RLE 2, 2, 1, 4, 3, 2, 2, 1
    SPRITE_RLE 1, 3, 1, 6, 1, 8, 4, 2
    SPRITE_RLE 1, 6, 1, 8, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 2, 6
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 2, 1
    SPRITE_RLE 2, 5, 2, 7, 2, 6, 2, 7
    SPRITE_RLE 2, 5, 2, 1, 1, 2, 8, 7
    SPRITE_RLE 1, 2, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 8, 7, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 6, 2, 1, 1, 5, 0, 6, 1
    SPRITE_RLE 3, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (65 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 8, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 6, 0, 1, 1, 1, 5, 2, 1
    SPRITE_RLE 2, 5, 6, 1, 2, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 5, 1, 4, 1, 2
    SPRITE_RLE 2, 4, 1, 2, 1, 4, 1, 5
    SPRITE_RLE 1, 2, 2, 1, 3, 2, 1, 4
    SPRITE_RLE 2, 2, 1, 4, 3, 2, 2, 1
    SPRITE_RLE 1, 3, 8, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 2, 6
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 2, 1
    SPRITE_RLE 2, 5, 2, 7, 2, 6, 2, 7
    SPRITE_RLE 2, 5, 2, 1, 1, 2, 8, 7
    SPRITE_RLE 1, 2, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 8, 7, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 6, 2, 1, 1, 5, 0, 6, 1
    SPRITE_RLE 3, 0
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (66 runs) ---
    SPRITE_RLE 1, 1, 10, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 5, 1, 1, 6, 0
    SPRITE_RLE 3, 1, 2, 5, 6, 1, 2, 5
    SPRITE_RLE 2, 1, 1, 2, 1, 5, 1, 4
    SPRITE_RLE 1, 2, 2, 4, 1, 2, 1, 4
    SPRITE_RLE 1, 5, 1, 2, 2, 1, 3, 2
    SPRITE_RLE 1, 4, 2, 2, 1, 4, 3, 2
    SPRITE_RLE 2, 1, 1, 3, 1, 6, 1, 8
    SPRITE_RLE 4, 2, 1, 6, 1, 8, 1, 3
    SPRITE_RLE 2, 1, 1, 2, 2, 6, 1, 2
    SPRITE_RLE 2, 6, 1, 2, 2, 6, 1, 2
    SPRITE_RLE 2, 1, 2, 5, 2, 7, 2, 6
    SPRITE_RLE 2, 7, 2, 5, 2, 1, 1, 2
    SPRITE_RLE 8, 7, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 8, 7, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 6, 2, 1, 1, 5, 0
    SPRITE_RLE 6, 1, 3, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (6 lines) ---
    SPRITE_ASCII_BEGIN 6
    SPRITE_ASCII_LINE " /\      /\ "
    SPRITE_ASCII_LINE "( o.    .o )"
    SPRITE_ASCII_LINE " >   ^    < "
    SPRITE_ASCII_LINE "  (=^..^=)  "
    SPRITE_ASCII_LINE "   ( ~~ )   "
    SPRITE_ASCII_LINE "    '--'    "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_logo_cat_compact
; Name: Logo Cat (Compact 8x4)
; Dimensions: 8 cells wide x 8 pixel rows high (4 cell rows)
; Frames: 3 | Payload: 272 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_logo_cat_compact, 8, 8, 3
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (38 runs) ---
    SPRITE_RLE 1, 1, 6, 0, 2, 1, 1, 5
    SPRITE_RLE 1, 1, 2, 0, 1, 1, 1, 5
    SPRITE_RLE 2, 1, 1, 2, 1, 4, 2, 2
    SPRITE_RLE 1, 4, 1, 2, 2, 1, 1, 6
    SPRITE_RLE 1, 8, 2, 2, 1, 6, 1, 8
    SPRITE_RLE 2, 1, 1, 5, 1, 7, 2, 6
    SPRITE_RLE 1, 7, 1, 5, 2, 1, 1, 2
    SPRITE_RLE 4, 7, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 4, 2, 1, 1, 3, 0
    SPRITE_RLE 4, 1, 2, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (34 runs) ---
    SPRITE_RLE 1, 1, 6, 0, 2, 1, 1, 5
    SPRITE_RLE 1, 1, 2, 0, 1, 1, 1, 5
    SPRITE_RLE 2, 1, 1, 2, 1, 4, 2, 2
    SPRITE_RLE 1, 4, 1, 2, 2, 1, 6, 2
    SPRITE_RLE 2, 1, 1, 5, 1, 7, 2, 6
    SPRITE_RLE 1, 7, 1, 5, 2, 1, 1, 2
    SPRITE_RLE 4, 7, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 4, 2, 1, 1, 3, 0
    SPRITE_RLE 4, 1, 2, 0
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (38 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 5, 0, 2, 1
    SPRITE_RLE 1, 5, 3, 0, 1, 1, 1, 5
    SPRITE_RLE 2, 1, 1, 2, 1, 4, 2, 2
    SPRITE_RLE 1, 4, 1, 2, 2, 1, 1, 6
    SPRITE_RLE 1, 8, 2, 2, 1, 6, 1, 8
    SPRITE_RLE 2, 1, 1, 5, 1, 7, 2, 6
    SPRITE_RLE 1, 7, 1, 5, 2, 1, 1, 2
    SPRITE_RLE 4, 7, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 4, 2, 1, 1, 3, 0
    SPRITE_RLE 4, 1, 2, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "/\    /\"
    SPRITE_ASCII_LINE "(o .. o)"
    SPRITE_ASCII_LINE " > ^^ < "
    SPRITE_ASCII_LINE "  '--'  "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_tomato_mascot
; Name: Tomato Mascot (Grand 14x7)
; Dimensions: 14 cells wide x 14 pixel rows high (7 cell rows)
; Frames: 5 | Payload: 776 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_tomato_mascot, 14, 14, 5
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_TITLE, SLOT_TITLE_ALT, SLOT_EAR_BLUSH, SLOT_OK, SLOT_ACCENT, SLOT_EYE_NOSE, SLOT_FUR, SLOT_FUR_SHADE

    ; --- Frame 0 RLE Stream (67 runs) ---
    SPRITE_RLE 6, 0, 2, 5, 7, 0, 2, 1
    SPRITE_RLE 2, 0, 4, 5, 2, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 1, 9
    SPRITE_RLE 1, 1, 6, 5, 1, 1, 1, 8
    SPRITE_RLE 1, 9, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 4, 2, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 3, 2, 2, 6, 7, 2, 2, 1
    SPRITE_RLE 2, 2, 2, 6, 8, 2, 2, 1
    SPRITE_RLE 12, 2, 2, 1, 1, 2, 2, 7
    SPRITE_RLE 6, 2, 2, 7, 1, 2, 2, 1
    SPRITE_RLE 2, 4, 1, 7, 2, 2, 2, 7
    SPRITE_RLE 2, 2, 1, 7, 2, 4, 2, 1
    SPRITE_RLE 2, 4, 2, 2, 4, 7, 2, 2
    SPRITE_RLE 2, 4, 2, 1, 12, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 10, 2, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 8, 3, 1, 1
    SPRITE_RLE 5, 0, 8, 1, 3, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (61 runs) ---
    SPRITE_RLE 20, 0, 2, 5, 7, 0, 2, 1
    SPRITE_RLE 2, 0, 4, 5, 2, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 1, 9
    SPRITE_RLE 1, 1, 6, 5, 1, 1, 1, 8
    SPRITE_RLE 1, 9, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 4, 2, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 2, 2, 2, 6, 8, 2, 2, 1
    SPRITE_RLE 12, 2, 2, 1, 1, 2, 2, 7
    SPRITE_RLE 6, 2, 2, 7, 1, 2, 2, 1
    SPRITE_RLE 2, 4, 1, 7, 2, 2, 2, 7
    SPRITE_RLE 2, 2, 1, 7, 2, 4, 2, 1
    SPRITE_RLE 2, 4, 2, 2, 4, 7, 2, 2
    SPRITE_RLE 2, 4, 2, 1, 12, 2, 2, 1
    SPRITE_RLE 12, 2, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 10, 3, 1, 1, 3, 0, 10, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (67 runs) ---
    SPRITE_RLE 6, 0, 2, 5, 7, 0, 2, 1
    SPRITE_RLE 2, 0, 4, 5, 2, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 1, 9
    SPRITE_RLE 1, 1, 6, 5, 1, 1, 1, 8
    SPRITE_RLE 1, 9, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 4, 2, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 3, 2, 2, 6, 7, 2, 2, 1
    SPRITE_RLE 2, 2, 2, 6, 8, 2, 2, 1
    SPRITE_RLE 12, 2, 2, 1, 1, 2, 1, 7
    SPRITE_RLE 8, 2, 1, 7, 1, 2, 2, 1
    SPRITE_RLE 1, 4, 2, 7, 2, 2, 2, 7
    SPRITE_RLE 2, 2, 2, 7, 1, 4, 2, 1
    SPRITE_RLE 2, 4, 2, 2, 4, 7, 2, 2
    SPRITE_RLE 2, 4, 2, 1, 12, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 10, 2, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 8, 3, 1, 1
    SPRITE_RLE 5, 0, 8, 1, 3, 0
    SPRITE_FRAME_END

    ; --- Frame 3 RLE Stream (57 runs) ---
    SPRITE_RLE 6, 0, 2, 5, 7, 0, 2, 1
    SPRITE_RLE 2, 0, 4, 5, 2, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 1, 9
    SPRITE_RLE 1, 1, 6, 5, 1, 1, 1, 8
    SPRITE_RLE 1, 9, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 4, 2, 2, 1, 2, 8, 2, 1
    SPRITE_RLE 12, 2, 2, 1, 12, 2, 2, 1
    SPRITE_RLE 12, 2, 2, 1, 12, 2, 2, 1
    SPRITE_RLE 1, 4, 3, 7, 1, 2, 2, 7
    SPRITE_RLE 1, 2, 3, 7, 1, 4, 2, 1
    SPRITE_RLE 2, 4, 8, 2, 2, 4, 2, 1
    SPRITE_RLE 12, 2, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 10, 2, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 8, 3, 1, 1, 5, 0, 8, 1
    SPRITE_RLE 3, 0
    SPRITE_FRAME_END

    ; --- Frame 4 RLE Stream (74 runs) ---
    SPRITE_RLE 1, 6, 5, 0, 2, 5, 5, 0
    SPRITE_RLE 1, 6, 1, 0, 2, 1, 2, 0
    SPRITE_RLE 4, 5, 2, 0, 2, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 8, 1, 9, 1, 1
    SPRITE_RLE 6, 5, 1, 1, 1, 8, 1, 9
    SPRITE_RLE 2, 1, 2, 8, 2, 1, 4, 2
    SPRITE_RLE 2, 1, 2, 8, 2, 1, 3, 2
    SPRITE_RLE 2, 6, 7, 2, 2, 1, 2, 2
    SPRITE_RLE 2, 6, 8, 2, 2, 1, 12, 2
    SPRITE_RLE 2, 1, 1, 2, 2, 7, 6, 2
    SPRITE_RLE 2, 7, 1, 2, 2, 1, 2, 4
    SPRITE_RLE 1, 7, 2, 2, 2, 7, 2, 2
    SPRITE_RLE 1, 7, 2, 4, 2, 1, 2, 4
    SPRITE_RLE 2, 2, 4, 7, 2, 2, 2, 4
    SPRITE_RLE 2, 1, 12, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 10, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 6, 1, 0, 1, 1, 8, 3
    SPRITE_RLE 1, 1, 1, 0, 1, 6, 3, 0
    SPRITE_RLE 8, 1, 3, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (7 lines) ---
    SPRITE_ASCII_BEGIN 7
    SPRITE_ASCII_LINE "  /\  ||  /\  "
    SPRITE_ASCII_LINE " /  \_||_/  \ "
    SPRITE_ASCII_LINE "(  *      *  )"
    SPRITE_ASCII_LINE "(  (o)  (o)  )"
    SPRITE_ASCII_LINE " \    ..    / "
    SPRITE_ASCII_LINE "  \  '=='  /  "
    SPRITE_ASCII_LINE "   '------'   "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_tomato_mascot_std
; Name: Tomato Mascot (Std 10x5)
; Dimensions: 10 cells wide x 10 pixel rows high (5 cell rows)
; Frames: 5 | Payload: 540 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_tomato_mascot_std, 10, 10, 5
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_TITLE, SLOT_TITLE_ALT, SLOT_EAR_BLUSH, SLOT_OK, SLOT_ACCENT, SLOT_EYE_NOSE, SLOT_FUR, SLOT_FUR_SHADE

    ; --- Frame 0 RLE Stream (49 runs) ---
    SPRITE_RLE 4, 0, 2, 5, 5, 0, 1, 1
    SPRITE_RLE 1, 0, 4, 5, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 2, 1
    SPRITE_RLE 2, 2, 2, 1, 1, 8, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 5, 2, 2, 1
    SPRITE_RLE 8, 2, 2, 1, 1, 2, 1, 7
    SPRITE_RLE 4, 2, 1, 7, 1, 2, 2, 1
    SPRITE_RLE 1, 4, 1, 7, 1, 2, 2, 7
    SPRITE_RLE 1, 2, 1, 7, 1, 4, 2, 1
    SPRITE_RLE 1, 4, 2, 2, 2, 7, 2, 2
    SPRITE_RLE 1, 4, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 6, 2, 1, 1, 3, 0, 6, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (45 runs) ---
    SPRITE_RLE 14, 0, 2, 5, 5, 0, 1, 1
    SPRITE_RLE 1, 0, 4, 5, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 2, 1
    SPRITE_RLE 2, 2, 2, 1, 1, 8, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 5, 2, 2, 1
    SPRITE_RLE 1, 2, 1, 7, 4, 2, 1, 7
    SPRITE_RLE 1, 2, 2, 1, 1, 4, 1, 7
    SPRITE_RLE 1, 2, 2, 7, 1, 2, 1, 7
    SPRITE_RLE 1, 4, 2, 1, 1, 4, 2, 2
    SPRITE_RLE 2, 7, 2, 2, 1, 4, 2, 1
    SPRITE_RLE 8, 2, 1, 1, 1, 0, 8, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (45 runs) ---
    SPRITE_RLE 4, 0, 2, 5, 5, 0, 1, 1
    SPRITE_RLE 1, 0, 4, 5, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 2, 1
    SPRITE_RLE 2, 2, 2, 1, 1, 8, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 5, 2, 2, 1
    SPRITE_RLE 8, 2, 2, 1, 1, 2, 1, 7
    SPRITE_RLE 4, 2, 1, 7, 1, 2, 2, 1
    SPRITE_RLE 1, 4, 6, 7, 1, 4, 2, 1
    SPRITE_RLE 1, 4, 2, 2, 2, 7, 2, 2
    SPRITE_RLE 1, 4, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 6, 2, 1, 1, 3, 0, 6, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END

    ; --- Frame 3 RLE Stream (39 runs) ---
    SPRITE_RLE 4, 0, 2, 5, 5, 0, 1, 1
    SPRITE_RLE 1, 0, 4, 5, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 8, 2, 1
    SPRITE_RLE 2, 2, 2, 1, 1, 8, 2, 1
    SPRITE_RLE 8, 2, 2, 1, 8, 2, 2, 1
    SPRITE_RLE 8, 2, 2, 1, 1, 4, 2, 7
    SPRITE_RLE 2, 2, 2, 7, 1, 4, 2, 1
    SPRITE_RLE 1, 4, 6, 2, 1, 4, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 6, 2, 1, 1
    SPRITE_RLE 3, 0, 6, 1, 2, 0
    SPRITE_FRAME_END

    ; --- Frame 4 RLE Stream (55 runs) ---
    SPRITE_RLE 1, 6, 3, 0, 2, 5, 3, 0
    SPRITE_RLE 1, 6, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 4, 5, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 8, 2, 1, 2, 2
    SPRITE_RLE 2, 1, 1, 8, 2, 1, 1, 2
    SPRITE_RLE 2, 6, 5, 2, 2, 1, 8, 2
    SPRITE_RLE 2, 1, 1, 2, 1, 7, 4, 2
    SPRITE_RLE 1, 7, 1, 2, 2, 1, 1, 4
    SPRITE_RLE 1, 7, 1, 2, 2, 7, 1, 2
    SPRITE_RLE 1, 7, 1, 4, 2, 1, 1, 4
    SPRITE_RLE 2, 2, 2, 7, 2, 2, 1, 4
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 6, 2
    SPRITE_RLE 1, 1, 1, 0, 1, 6, 1, 0
    SPRITE_RLE 6, 1, 1, 0, 1, 6
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (5 lines) ---
    SPRITE_ASCII_BEGIN 5
    SPRITE_ASCII_LINE " /\ || /\ "
    SPRITE_ASCII_LINE "( *    * )"
    SPRITE_ASCII_LINE "( (o) (o))"
    SPRITE_ASCII_LINE " \  ..  / "
    SPRITE_ASCII_LINE "  '----'  "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_tomato_mascot_compact
; Name: Tomato Mascot (Compact 6x3)
; Dimensions: 6 cells wide x 6 pixel rows high (3 cell rows)
; Frames: 5 | Payload: 254 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_tomato_mascot_compact, 6, 6, 5
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_TITLE, SLOT_TITLE_ALT, SLOT_EAR_BLUSH, SLOT_OK, SLOT_ACCENT, SLOT_EYE_NOSE, SLOT_FUR, SLOT_FUR_SHADE

    ; --- Frame 0 RLE Stream (23 runs) ---
    SPRITE_RLE 2, 0, 2, 5, 2, 0, 1, 1
    SPRITE_RLE 1, 8, 2, 5, 1, 8, 2, 1
    SPRITE_RLE 1, 2, 1, 6, 2, 2, 2, 1
    SPRITE_RLE 1, 7, 2, 2, 1, 7, 2, 1
    SPRITE_RLE 1, 4, 2, 7, 1, 4, 1, 1
    SPRITE_RLE 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (17 runs) ---
    SPRITE_RLE 8, 0, 2, 5, 2, 0, 1, 1
    SPRITE_RLE 1, 8, 2, 5, 1, 8, 2, 1
    SPRITE_RLE 1, 7, 1, 6, 1, 2, 1, 7
    SPRITE_RLE 2, 1, 1, 4, 2, 7, 1, 4
    SPRITE_RLE 7, 1
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (23 runs) ---
    SPRITE_RLE 2, 0, 2, 5, 2, 0, 1, 1
    SPRITE_RLE 1, 8, 2, 5, 1, 8, 2, 1
    SPRITE_RLE 1, 2, 1, 6, 2, 2, 2, 1
    SPRITE_RLE 1, 7, 2, 2, 1, 7, 2, 1
    SPRITE_RLE 1, 4, 2, 7, 1, 4, 1, 1
    SPRITE_RLE 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 3 RLE Stream (19 runs) ---
    SPRITE_RLE 2, 0, 2, 5, 2, 0, 1, 1
    SPRITE_RLE 1, 8, 2, 5, 1, 8, 2, 1
    SPRITE_RLE 4, 2, 2, 1, 4, 2, 2, 1
    SPRITE_RLE 1, 4, 2, 7, 1, 4, 1, 1
    SPRITE_RLE 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 4 RLE Stream (25 runs) ---
    SPRITE_RLE 1, 6, 1, 0, 2, 5, 1, 0
    SPRITE_RLE 1, 6, 1, 1, 1, 8, 2, 5
    SPRITE_RLE 1, 8, 2, 1, 1, 2, 1, 6
    SPRITE_RLE 2, 2, 2, 1, 1, 7, 2, 2
    SPRITE_RLE 1, 7, 2, 1, 1, 4, 2, 7
    SPRITE_RLE 1, 4, 1, 1, 1, 6, 4, 1
    SPRITE_RLE 1, 6
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "/\||/\"
    SPRITE_ASCII_LINE "(o  o)"
    SPRITE_ASCII_LINE " '--' "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_sleeping_cat
; Name: Sleeping Cat (Grand 8x4)
; Dimensions: 8 cells wide x 8 pixel rows high (4 cell rows)
; Frames: 2 | Payload: 199 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_sleeping_cat, 8, 8, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (37 runs) ---
    SPRITE_RLE 2, 0, 5, 1, 2, 0, 1, 1
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 2, 1, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 1, 4, 2, 2, 2, 1
    SPRITE_RLE 1, 5, 4, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 2, 3
    SPRITE_RLE 2, 1, 1, 5, 3, 7, 2, 2
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 2, 7
    SPRITE_RLE 2, 2, 1, 1, 3, 0, 4, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (37 runs) ---
    SPRITE_RLE 1, 0, 6, 1, 1, 0, 1, 1
    SPRITE_RLE 2, 2, 1, 4, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 2, 1, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 1, 4, 2, 2, 2, 1
    SPRITE_RLE 1, 5, 4, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 2, 3
    SPRITE_RLE 2, 1, 1, 5, 3, 7, 2, 2
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 2, 7
    SPRITE_RLE 2, 2, 1, 1, 3, 0, 4, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  .----."
    SPRITE_ASCII_LINE " / u  u "
    SPRITE_ASCII_LINE "(  z Z  "
    SPRITE_ASCII_LINE " '------"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_sleeping_cat_std
; Name: Sleeping Cat (Std 6x3)
; Dimensions: 6 cells wide x 6 pixel rows high (3 cell rows)
; Frames: 2 | Payload: 130 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_sleeping_cat_std, 6, 6, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (24 runs) ---
    SPRITE_RLE 1, 0, 4, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 1, 4
    SPRITE_RLE 2, 1, 1, 5, 2, 2, 1, 3
    SPRITE_RLE 2, 1, 2, 6, 1, 2, 1, 3
    SPRITE_RLE 2, 1, 1, 5, 2, 7, 1, 2
    SPRITE_RLE 1, 1, 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (23 runs) ---
    SPRITE_RLE 5, 1, 1, 0, 1, 1, 1, 2
    SPRITE_RLE 1, 4, 1, 2, 1, 4, 2, 1
    SPRITE_RLE 1, 5, 2, 2, 1, 3, 2, 1
    SPRITE_RLE 2, 6, 1, 2, 1, 3, 2, 1
    SPRITE_RLE 1, 5, 2, 7, 1, 2, 1, 1
    SPRITE_RLE 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE ".----."
    SPRITE_ASCII_LINE "(u.u)z"
    SPRITE_ASCII_LINE "'----'"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_habits_cat_head
; Name: Habits Cat Head (Std 4x2)
; Dimensions: 4 cells wide x 4 pixel rows high (2 cell rows)
; Frames: 2 | Payload: 57 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_habits_cat_head, 4, 4, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (9 runs) ---
    SPRITE_RLE 1, 1, 2, 5, 2, 1, 2, 2
    SPRITE_RLE 2, 1, 2, 6, 2, 1, 2, 7
    SPRITE_RLE 1, 1
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (7 runs) ---
    SPRITE_RLE 1, 1, 2, 5, 2, 1, 2, 2
    SPRITE_RLE 6, 1, 2, 7, 1, 1
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "/\/\"
    SPRITE_ASCII_LINE "(o.o"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_habits_cat_head_compact
; Name: Habits Cat Head (Compact 3x2)
; Dimensions: 3 cells wide x 4 pixel rows high (2 cell rows)
; Frames: 2 | Payload: 65 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_habits_cat_head_compact, 3, 4, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (11 runs) ---
    SPRITE_RLE 1, 1, 1, 5, 2, 1, 1, 2
    SPRITE_RLE 1, 1, 1, 6, 1, 7, 1, 6
    SPRITE_RLE 1, 0, 1, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (10 runs) ---
    SPRITE_RLE 1, 1, 1, 5, 2, 1, 1, 2
    SPRITE_RLE 2, 1, 1, 7, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "^^^"
    SPRITE_ASCII_LINE "o.o"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_working
; Name: Working Cat (Grand 14x7)
; Dimensions: 14 cells wide x 14 pixel rows high (7 cell rows)
; Frames: 2 | Payload: 452 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_working, 14, 14, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (81 runs) ---
    SPRITE_RLE 2, 0, 2, 1, 6, 0, 2, 1
    SPRITE_RLE 3, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 4, 5, 4, 1
    SPRITE_RLE 4, 5, 2, 1, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 2, 1, 2, 2, 1, 4
    SPRITE_RLE 2, 2, 2, 4, 2, 2, 1, 4
    SPRITE_RLE 2, 2, 2, 1, 1, 3, 2, 6
    SPRITE_RLE 6, 2, 2, 6, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 5, 2, 7, 2, 6
    SPRITE_RLE 2, 7, 2, 5, 1, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 2, 3, 7
    SPRITE_RLE 2, 6, 3, 7, 1, 2, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 10, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 12, 8, 2, 1
    SPRITE_RLE 1, 8, 10, 7, 1, 8, 2, 1
    SPRITE_RLE 1, 8, 10, 7, 1, 8, 2, 1
    SPRITE_RLE 12, 8, 1, 1, 1, 0, 12, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (85 runs) ---
    SPRITE_RLE 2, 0, 2, 1, 6, 0, 2, 1
    SPRITE_RLE 3, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 4, 5, 4, 1
    SPRITE_RLE 4, 5, 2, 1, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 2, 1, 2, 2, 1, 4
    SPRITE_RLE 2, 2, 2, 4, 2, 2, 1, 4
    SPRITE_RLE 2, 2, 2, 1, 1, 3, 2, 6
    SPRITE_RLE 6, 2, 2, 6, 1, 3, 2, 1
    SPRITE_RLE 1, 2, 2, 5, 2, 7, 2, 6
    SPRITE_RLE 2, 7, 2, 5, 1, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 2, 3, 7
    SPRITE_RLE 2, 6, 3, 7, 1, 2, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 3, 2, 1, 7
    SPRITE_RLE 2, 2, 1, 7, 3, 2, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 12, 8, 2, 1
    SPRITE_RLE 1, 8, 10, 7, 1, 8, 2, 1
    SPRITE_RLE 1, 8, 10, 7, 1, 8, 2, 1
    SPRITE_RLE 12, 8, 1, 1, 1, 0, 12, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (7 lines) ---
    SPRITE_ASCII_BEGIN 7
    SPRITE_ASCII_LINE " /\_\    /_/\ "
    SPRITE_ASCII_LINE "( -.-    -.- )"
    SPRITE_ASCII_LINE " >  ^    ^  < "
    SPRITE_ASCII_LINE "   (=^..^=)   "
    SPRITE_ASCII_LINE "  .----------."
    SPRITE_ASCII_LINE "  | [PAW_OS] |"
    SPRITE_ASCII_LINE "  '----------'"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_working_std
; Name: Working Cat (Std 10x5)
; Dimensions: 10 cells wide x 10 pixel rows high (5 cell rows)
; Frames: 2 | Payload: 274 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_working_std, 10, 10, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (49 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 6, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 1, 5, 2, 1
    SPRITE_RLE 2, 5, 4, 1, 2, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 1
    SPRITE_RLE 2, 6, 4, 2, 2, 6, 2, 1
    SPRITE_RLE 1, 5, 2, 7, 2, 6, 2, 7
    SPRITE_RLE 1, 5, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 6, 7, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 8, 8, 2, 1, 1, 8, 6, 7
    SPRITE_RLE 1, 8, 1, 1, 1, 0, 8, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (53 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 6, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 1, 5, 2, 1
    SPRITE_RLE 2, 5, 4, 1, 2, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 1
    SPRITE_RLE 2, 6, 4, 2, 2, 6, 2, 1
    SPRITE_RLE 1, 5, 2, 7, 2, 6, 2, 7
    SPRITE_RLE 1, 5, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 7, 1, 2, 2, 7, 1, 2
    SPRITE_RLE 1, 7, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 8, 8, 2, 1, 1, 8, 6, 7
    SPRITE_RLE 1, 8, 1, 1, 1, 0, 8, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (5 lines) ---
    SPRITE_ASCII_BEGIN 5
    SPRITE_ASCII_LINE " /\    /\ "
    SPRITE_ASCII_LINE "( -....- )"
    SPRITE_ASCII_LINE " (=^..^=) "
    SPRITE_ASCII_LINE ".--------."
    SPRITE_ASCII_LINE "| [__]   |"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_working_compact
; Name: Working Cat (Compact 6x3)
; Dimensions: 6 cells wide x 6 pixel rows high (3 cell rows)
; Frames: 2 | Payload: 116 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_working_compact, 6, 6, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (20 runs) ---
    SPRITE_RLE 1, 1, 4, 0, 2, 1, 1, 5
    SPRITE_RLE 2, 0, 1, 5, 2, 1, 1, 6
    SPRITE_RLE 2, 2, 1, 6, 2, 1, 1, 5
    SPRITE_RLE 2, 7, 1, 5, 2, 1, 4, 8
    SPRITE_RLE 1, 1, 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (20 runs) ---
    SPRITE_RLE 1, 1, 4, 0, 2, 1, 1, 5
    SPRITE_RLE 2, 0, 1, 5, 2, 1, 1, 6
    SPRITE_RLE 2, 2, 1, 6, 2, 1, 1, 7
    SPRITE_RLE 2, 2, 1, 7, 2, 1, 4, 8
    SPRITE_RLE 1, 1, 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "/\  /\"
    SPRITE_ASCII_LINE "(-..-)"
    SPRITE_ASCII_LINE "[====]"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_resting
; Name: Resting Cat (Grand 14x7)
; Dimensions: 14 cells wide x 14 pixel rows high (7 cell rows)
; Frames: 2 | Payload: 332 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_resting, 14, 14, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (52 runs) ---
    SPRITE_RLE 8, 0, 2, 8, 11, 0, 4, 8
    SPRITE_RLE 5, 0, 2, 1, 4, 0, 2, 8
    SPRITE_RLE 5, 0, 1, 1, 2, 5, 1, 1
    SPRITE_RLE 9, 0, 1, 1, 4, 5, 8, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 2, 1, 5
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 1, 4, 3, 2, 2, 1
    SPRITE_RLE 2, 2, 1, 4, 2, 2, 2, 4
    SPRITE_RLE 5, 2, 2, 1, 1, 3, 2, 6
    SPRITE_RLE 6, 2, 3, 3, 2, 1, 1, 2
    SPRITE_RLE 2, 5, 2, 7, 2, 6, 2, 7
    SPRITE_RLE 3, 2, 16, 1, 12, 3, 2, 1
    SPRITE_RLE 12, 2, 2, 1, 12, 3, 15, 1
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (54 runs) ---
    SPRITE_RLE 8, 0, 2, 8, 11, 0, 4, 8
    SPRITE_RLE 5, 0, 2, 1, 4, 0, 2, 8
    SPRITE_RLE 1, 0, 1, 8, 3, 0, 1, 1
    SPRITE_RLE 2, 5, 1, 1, 9, 0, 1, 1
    SPRITE_RLE 4, 5, 8, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 2, 1, 5, 1, 2, 1, 4
    SPRITE_RLE 1, 2, 2, 4, 1, 2, 1, 4
    SPRITE_RLE 3, 2, 2, 1, 2, 2, 1, 4
    SPRITE_RLE 2, 2, 2, 4, 5, 2, 2, 1
    SPRITE_RLE 1, 3, 2, 6, 6, 2, 3, 3
    SPRITE_RLE 2, 1, 1, 2, 2, 5, 2, 7
    SPRITE_RLE 2, 6, 2, 7, 3, 2, 16, 1
    SPRITE_RLE 12, 3, 2, 1, 12, 2, 2, 1
    SPRITE_RLE 12, 3, 15, 1
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (7 lines) ---
    SPRITE_ASCII_BEGIN 7
    SPRITE_ASCII_LINE "        ( )   "
    SPRITE_ASCII_LINE " /\_\    |    "
    SPRITE_ASCII_LINE "( u.u    u.u )"
    SPRITE_ASCII_LINE " >  ^    ^  < "
    SPRITE_ASCII_LINE ".------------."
    SPRITE_ASCII_LINE "| ~~~~~~~~~~ |"
    SPRITE_ASCII_LINE "'------------'"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_resting_std
; Name: Resting Cat (Std 10x5)
; Dimensions: 10 cells wide x 10 pixel rows high (5 cell rows)
; Frames: 2 | Payload: 212 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_resting_std, 10, 10, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (35 runs) ---
    SPRITE_RLE 6, 0, 2, 8, 3, 0, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 1, 8
    SPRITE_RLE 2, 0, 1, 1, 1, 5, 2, 1
    SPRITE_RLE 1, 5, 1, 1, 4, 0, 1, 1
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 1, 4
    SPRITE_RLE 4, 2, 2, 1, 2, 6, 6, 2
    SPRITE_RLE 2, 1, 1, 5, 1, 7, 2, 6
    SPRITE_RLE 1, 7, 3, 2, 12, 1, 8, 3
    SPRITE_RLE 2, 1, 8, 2, 11, 1
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (36 runs) ---
    SPRITE_RLE 6, 0, 2, 8, 3, 0, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 1, 8
    SPRITE_RLE 1, 0, 1, 8, 1, 1, 1, 5
    SPRITE_RLE 2, 1, 1, 5, 1, 1, 4, 0
    SPRITE_RLE 1, 1, 1, 2, 1, 4, 1, 2
    SPRITE_RLE 1, 4, 4, 2, 2, 1, 2, 6
    SPRITE_RLE 6, 2, 2, 1, 1, 5, 1, 7
    SPRITE_RLE 2, 6, 1, 7, 3, 2, 12, 1
    SPRITE_RLE 8, 3, 2, 1, 8, 2, 11, 1
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (5 lines) ---
    SPRITE_ASCII_BEGIN 5
    SPRITE_ASCII_LINE "      ( ) "
    SPRITE_ASCII_LINE " /\ /\    "
    SPRITE_ASCII_LINE "( u.u ) zZ"
    SPRITE_ASCII_LINE ".--------."
    SPRITE_ASCII_LINE "| ~~~~~~ |"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_resting_compact
; Name: Resting Cat (Compact 6x3)
; Dimensions: 6 cells wide x 6 pixel rows high (3 cell rows)
; Frames: 2 | Payload: 132 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_resting_compact, 6, 6, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (24 runs) ---
    SPRITE_RLE 1, 1, 2, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 8, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 1, 5, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 6, 1, 2, 1, 6, 1, 2
    SPRITE_RLE 2, 1, 1, 5, 1, 7, 1, 5
    SPRITE_RLE 1, 2, 2, 1, 4, 3, 7, 1
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (24 runs) ---
    SPRITE_RLE 1, 1, 2, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 8, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 1, 5, 1, 1, 1, 8, 1, 1
    SPRITE_RLE 1, 6, 1, 2, 1, 6, 1, 2
    SPRITE_RLE 2, 1, 1, 5, 1, 7, 1, 5
    SPRITE_RLE 1, 2, 2, 1, 4, 3, 7, 1
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "/\/\ ("
    SPRITE_ASCII_LINE "(u.u)z"
    SPRITE_ASCII_LINE "[====]"
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_cheering
; Name: Cheering Cat (Grand 14x7)
; Dimensions: 14 cells wide x 14 pixel rows high (7 cell rows)
; Frames: 2 | Payload: 474 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_cheering, 14, 14, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (88 runs) ---
    SPRITE_RLE 1, 1, 1, 7, 1, 1, 8, 0
    SPRITE_RLE 1, 1, 1, 7, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 7, 1, 1, 6, 0
    SPRITE_RLE 1, 1, 1, 7, 1, 1, 3, 0
    SPRITE_RLE 10, 1, 3, 0, 1, 1, 2, 5
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 2, 5, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 2, 5, 2, 2, 1, 4
    SPRITE_RLE 2, 2, 1, 4, 2, 2, 2, 5
    SPRITE_RLE 2, 1, 12, 2, 2, 1, 1, 2
    SPRITE_RLE 1, 7, 8, 2, 1, 7, 1, 2
    SPRITE_RLE 2, 1, 1, 4, 2, 7, 2, 2
    SPRITE_RLE 2, 7, 2, 2, 2, 7, 1, 4
    SPRITE_RLE 2, 1, 2, 4, 2, 2, 4, 7
    SPRITE_RLE 2, 2, 2, 4, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 3, 2, 4, 7, 3, 2
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 8, 2
    SPRITE_RLE 1, 1, 4, 0, 1, 1, 8, 2
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 7
    SPRITE_RLE 2, 1, 4, 2, 2, 1, 1, 7
    SPRITE_RLE 1, 1, 2, 0, 2, 1, 2, 0
    SPRITE_RLE 4, 1, 2, 0, 2, 1, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (89 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 6, 0, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 8, 0, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 2, 0, 10, 1, 3, 0, 1, 1
    SPRITE_RLE 2, 5, 1, 2, 1, 4, 1, 2
    SPRITE_RLE 2, 4, 1, 2, 2, 5, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 2, 5, 2, 2
    SPRITE_RLE 1, 4, 2, 2, 1, 4, 2, 2
    SPRITE_RLE 2, 5, 2, 1, 12, 2, 2, 1
    SPRITE_RLE 1, 2, 1, 7, 8, 2, 1, 7
    SPRITE_RLE 1, 2, 2, 1, 1, 4, 2, 7
    SPRITE_RLE 2, 2, 2, 7, 2, 2, 2, 7
    SPRITE_RLE 1, 4, 2, 1, 2, 4, 2, 2
    SPRITE_RLE 4, 7, 2, 2, 2, 4, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 3, 2, 4, 7
    SPRITE_RLE 3, 2, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 8, 2, 1, 1, 4, 0, 1, 1
    SPRITE_RLE 8, 2, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 1, 7, 2, 1, 4, 2, 2, 1
    SPRITE_RLE 1, 7, 1, 1, 2, 0, 2, 1
    SPRITE_RLE 2, 0, 4, 1, 2, 0, 2, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (7 lines) ---
    SPRITE_ASCII_BEGIN 7
    SPRITE_ASCII_LINE " \          / "
    SPRITE_ASCII_LINE "  \_      _/  "
    SPRITE_ASCII_LINE "  /\_    _/\  "
    SPRITE_ASCII_LINE " ( ^.    .^ ) "
    SPRITE_ASCII_LINE "  >   ..   <  "
    SPRITE_ASCII_LINE "   \ '==' /   "
    SPRITE_ASCII_LINE "    '----'    "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_cheering_std
; Name: Cheering Cat (Std 10x5)
; Dimensions: 10 cells wide x 10 pixel rows high (5 cell rows)
; Frames: 2 | Payload: 284 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_cheering_std, 10, 10, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (54 runs) ---
    SPRITE_RLE 1, 1, 1, 7, 6, 0, 1, 7
    SPRITE_RLE 1, 1, 1, 0, 8, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 5, 1, 2, 1, 4
    SPRITE_RLE 2, 2, 1, 4, 1, 2, 1, 5
    SPRITE_RLE 2, 1, 8, 2, 2, 1, 1, 2
    SPRITE_RLE 1, 7, 4, 2, 1, 7, 1, 2
    SPRITE_RLE 2, 1, 1, 4, 2, 7, 2, 2
    SPRITE_RLE 2, 7, 1, 4, 2, 1, 1, 4
    SPRITE_RLE 2, 2, 2, 7, 2, 2, 1, 4
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 6, 2
    SPRITE_RLE 1, 1, 2, 0, 1, 1, 1, 7
    SPRITE_RLE 1, 1, 2, 2, 1, 1, 1, 7
    SPRITE_RLE 1, 1, 3, 0, 2, 1, 2, 0
    SPRITE_RLE 2, 1, 2, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (53 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 1, 7, 4, 0
    SPRITE_RLE 1, 7, 1, 1, 1, 0, 11, 1
    SPRITE_RLE 1, 5, 1, 2, 1, 4, 2, 2
    SPRITE_RLE 1, 4, 1, 2, 1, 5, 2, 1
    SPRITE_RLE 8, 2, 2, 1, 1, 2, 1, 7
    SPRITE_RLE 4, 2, 1, 7, 1, 2, 2, 1
    SPRITE_RLE 1, 4, 2, 7, 2, 2, 2, 7
    SPRITE_RLE 1, 4, 2, 1, 1, 4, 2, 2
    SPRITE_RLE 2, 7, 2, 2, 1, 4, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 6, 2, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 2, 2, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 3, 0, 2, 1, 2, 0, 2, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (5 lines) ---
    SPRITE_ASCII_BEGIN 5
    SPRITE_ASCII_LINE "\        /"
    SPRITE_ASCII_LINE " /\    /\ "
    SPRITE_ASCII_LINE "( ^.  .^ )"
    SPRITE_ASCII_LINE " > '==' < "
    SPRITE_ASCII_LINE "  '----'  "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_cheering_compact
; Name: Cheering Cat (Compact 6x3)
; Dimensions: 6 cells wide x 6 pixel rows high (3 cell rows)
; Frames: 2 | Payload: 140 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_cheering_compact, 6, 6, 2
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (25 runs) ---
    SPRITE_RLE 1, 7, 4, 0, 1, 7, 1, 1
    SPRITE_RLE 1, 5, 2, 0, 1, 5, 2, 1
    SPRITE_RLE 1, 7, 2, 2, 1, 7, 2, 1
    SPRITE_RLE 1, 4, 2, 7, 1, 4, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 2, 2, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 1, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (27 runs) ---
    SPRITE_RLE 1, 0, 1, 7, 2, 0, 1, 7
    SPRITE_RLE 1, 0, 1, 1, 1, 5, 2, 0
    SPRITE_RLE 1, 5, 2, 1, 1, 7, 2, 2
    SPRITE_RLE 1, 7, 2, 1, 1, 4, 2, 7
    SPRITE_RLE 1, 4, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 2, 2, 1, 1, 2, 0, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 1, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "\    /"
    SPRITE_ASCII_LINE " \^^/ "
    SPRITE_ASCII_LINE "  ''  "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_surprised
; Name: Surprised Cat (Grand 10x5)
; Dimensions: 10 cells wide x 10 pixel rows high (5 cell rows)
; Frames: 1 | Payload: 183 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_surprised, 10, 10, 1
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (57 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 6, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 5, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 1, 5, 2, 1
    SPRITE_RLE 2, 5, 4, 1, 2, 5, 2, 1
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 4
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 1
    SPRITE_RLE 2, 6, 4, 2, 2, 6, 2, 1
    SPRITE_RLE 1, 6, 1, 8, 4, 2, 1, 6
    SPRITE_RLE 1, 8, 2, 1, 1, 5, 1, 7
    SPRITE_RLE 1, 2, 2, 6, 1, 2, 1, 7
    SPRITE_RLE 1, 5, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 7, 1, 2, 2, 6, 1, 2
    SPRITE_RLE 1, 7, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 4, 2, 1, 1, 5, 0, 4, 1
    SPRITE_RLE 3, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (5 lines) ---
    SPRITE_ASCII_BEGIN 5
    SPRITE_ASCII_LINE " /\    /\ "
    SPRITE_ASCII_LINE "(  O  O  )"
    SPRITE_ASCII_LINE " >   o  < "
    SPRITE_ASCII_LINE "  (=  =)  "
    SPRITE_ASCII_LINE "   '--'   "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_surprised_std
; Name: Surprised Cat (Std 8x4)
; Dimensions: 8 cells wide x 8 pixel rows high (4 cell rows)
; Frames: 1 | Payload: 126 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_surprised_std, 8, 8, 1
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (38 runs) ---
    SPRITE_RLE 1, 1, 6, 0, 2, 1, 1, 5
    SPRITE_RLE 1, 1, 2, 0, 1, 1, 1, 5
    SPRITE_RLE 2, 1, 1, 2, 1, 4, 2, 2
    SPRITE_RLE 1, 4, 1, 2, 2, 1, 2, 6
    SPRITE_RLE 2, 2, 2, 6, 2, 1, 1, 5
    SPRITE_RLE 1, 7, 2, 6, 1, 7, 1, 5
    SPRITE_RLE 2, 1, 1, 2, 1, 7, 2, 6
    SPRITE_RLE 1, 7, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 4, 2, 1, 1, 3, 0
    SPRITE_RLE 4, 1, 2, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "/\    /\"
    SPRITE_ASCII_LINE "( O  O )"
    SPRITE_ASCII_LINE " > oo < "
    SPRITE_ASCII_LINE "  '--'  "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_surprised_compact
; Name: Surprised Cat (Compact 6x3)
; Dimensions: 6 cells wide x 6 pixel rows high (3 cell rows)
; Frames: 1 | Payload: 79 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_surprised_compact, 6, 6, 1
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (22 runs) ---
    SPRITE_RLE 1, 1, 4, 0, 2, 1, 1, 5
    SPRITE_RLE 2, 0, 1, 5, 2, 1, 1, 6
    SPRITE_RLE 2, 2, 1, 6, 2, 1, 1, 5
    SPRITE_RLE 2, 6, 1, 5, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 2, 2, 1, 1, 3, 0
    SPRITE_RLE 2, 1, 2, 0
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "/\  /\"
    SPRITE_ASCII_LINE "(O..O)"
    SPRITE_ASCII_LINE " '--' "
SPRITE_END

; -----------------------------------------------------------------------------
; Sprite: sprite_cat_strolling
; Name: Walking Cat (Std 6x2)
; Dimensions: 6 cells wide x 4 pixel rows high (2 cell rows)
; Frames: 3 | Payload: 138 bytes
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_cat_strolling, 6, 4, 3
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_FUR_SHADE, SLOT_FUR_STRIPE, SLOT_EAR_BLUSH, SLOT_EYE_NOSE, SLOT_TEXT, SLOT_ACCENT

    ; --- Frame 0 RLE Stream (17 runs) ---
    SPRITE_RLE 1, 1, 4, 0, 3, 1, 2, 2
    SPRITE_RLE 1, 1, 1, 5, 1, 0, 1, 1
    SPRITE_RLE 2, 2, 1, 1, 1, 7, 1, 1
    SPRITE_RLE 1, 7, 1, 0, 1, 1, 1, 7
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END

    ; --- Frame 1 RLE Stream (19 runs) ---
    SPRITE_RLE 1, 0, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 2, 2, 1, 1
    SPRITE_RLE 1, 5, 2, 1, 2, 2, 1, 1
    SPRITE_RLE 1, 7, 1, 0, 1, 1, 1, 7
    SPRITE_RLE 1, 1, 1, 7, 1, 0
    SPRITE_FRAME_END

    ; --- Frame 2 RLE Stream (18 runs) ---
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 4, 1
    SPRITE_RLE 1, 2, 1, 1, 1, 5, 1, 0
    SPRITE_RLE 1, 1, 2, 2, 1, 1, 1, 7
    SPRITE_RLE 1, 0, 1, 1, 1, 7, 1, 0
    SPRITE_RLE 1, 1, 1, 7
    SPRITE_FRAME_END

    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "~(=^.."
    SPRITE_ASCII_LINE "  dbdb"
SPRITE_END


; -----------------------------------------------------------------------------
; sprite_digit_large_0 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_0, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 1, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 1, 0, 3, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE " _ _ "
    SPRITE_ASCII_LINE "|   |"
    SPRITE_ASCII_LINE "|   |"
    SPRITE_ASCII_LINE "|_ _|"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_1 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_1, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 1, 0
    SPRITE_RLE 2, 1, 2, 0, 2, 0, 1, 1
    SPRITE_RLE 2, 0, 2, 0, 1, 1, 2, 0
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 2, 0
    SPRITE_RLE 1, 1, 2, 0, 2, 0, 1, 1
    SPRITE_RLE 2, 0, 1, 0, 3, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_2 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_2, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 1, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 4, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 0, 2, 0
    SPRITE_RLE 1, 1, 2, 0, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 4, 0, 5, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_3 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_3, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 1, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 4, 0, 1, 1
    SPRITE_RLE 2, 0, 2, 1, 1, 0, 4, 0
    SPRITE_RLE 1, 1, 4, 0, 1, 1, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 0, 3, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_4 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_4, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 5, 1, 4, 0, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 4, 0, 1, 1
    SPRITE_RLE 4, 0, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_5 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_5, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 5, 1, 1, 1, 4, 0, 1, 1
    SPRITE_RLE 4, 0, 4, 1, 1, 0, 4, 0
    SPRITE_RLE 1, 1, 4, 0, 1, 1, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 0, 3, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_6 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_6, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 1, 1, 0, 1, 1
    SPRITE_RLE 4, 0, 1, 1, 4, 0, 4, 1
    SPRITE_RLE 1, 0, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 0, 3, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_7 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_7, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 5, 1, 4, 0, 1, 1, 4, 0
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 0
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 2, 0
    SPRITE_RLE 1, 1, 2, 0, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 0, 1, 1, 3, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_8 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_8, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 1, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 1, 0, 3, 1, 1, 0
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 1, 0, 3, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_9 (5x4 cells, 5x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_9, 5, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 1, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 1, 0, 4, 1, 4, 0
    SPRITE_RLE 1, 1, 4, 0, 1, 1, 4, 0
    SPRITE_RLE 1, 1, 1, 0, 3, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "  _  "
    SPRITE_ASCII_LINE " / | "
    SPRITE_ASCII_LINE "   | "
    SPRITE_ASCII_LINE "  _|_"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_large_colon (3x4 cells, 3x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_large_colon, 3, 8, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 0, 3, 0, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 3, 0, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 0, 1, 1, 1, 0, 3, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "   "
    SPRITE_ASCII_LINE "  o"
    SPRITE_ASCII_LINE "   "
    SPRITE_ASCII_LINE "  o"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_0 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_0, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_1 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_1, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 1, 1, 0, 2, 1
    SPRITE_RLE 1, 0, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_2 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_2, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 2, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 0, 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_3 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_3, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 1, 0, 2, 1, 2, 0
    SPRITE_RLE 1, 1, 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_4 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_4, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 3, 1
    SPRITE_RLE 2, 0, 1, 1, 2, 0, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_5 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_5, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 2, 1, 1, 0, 2, 0
    SPRITE_RLE 1, 1, 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_6 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_6, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 1, 1, 2, 0, 3, 1
    SPRITE_RLE 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_7 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_7, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 2, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 0, 1, 0, 1, 1
    SPRITE_RLE 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_8 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_8, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 3, 1, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_9 (3x2 cells, 3x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_9, 3, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 3, 1, 2, 0, 1, 1
    SPRITE_RLE 3, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "111"
    SPRITE_ASCII_LINE "111"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_digit_compact_colon (2x2 cells, 2x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_digit_compact_colon, 2, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 1, 1, 1, 0, 2, 0
    SPRITE_RLE 1, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE ": "
    SPRITE_ASCII_LINE ": "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_timer (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_timer, 6, 6, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_OK, SLOT_ACCENT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 2, 2, 2, 0, 1, 0
    SPRITE_RLE 4, 1, 1, 0, 1, 1, 4, 3
    SPRITE_RLE 1, 1, 1, 1, 1, 3, 2, 1
    SPRITE_RLE 1, 3, 1, 1, 1, 1, 4, 3
    SPRITE_RLE 1, 1, 1, 0, 4, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[TIMER"
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_timer_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_timer_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_OK, SLOT_ACCENT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 2, 1, 0, 4, 1
    SPRITE_RLE 1, 1, 2, 3, 1, 1, 1, 0
    SPRITE_RLE 2, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[TM]"
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_habits (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_habits, 6, 6, 1
    SPRITE_PALETTE SLOT_SURFACE_ALT, SLOT_OK, SLOT_EAR_BLUSH, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 3, 4, 2, 0, 1, 0
    SPRITE_RLE 3, 1, 2, 0, 1, 0, 1, 2
    SPRITE_RLE 2, 1, 1, 3, 1, 0, 1, 0
    SPRITE_RLE 1, 2, 1, 1, 3, 3, 1, 0
    SPRITE_RLE 2, 1, 3, 3, 1, 0, 3, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[LIST]"
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_habits_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_habits_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_SURFACE_ALT, SLOT_OK, SLOT_EAR_BLUSH, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 1, 0, 1, 2, 2, 1
    SPRITE_RLE 1, 0, 1, 2, 1, 1, 2, 3
    SPRITE_RLE 2, 1, 2, 3
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[HB]"
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_journal (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_journal, 6, 6, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_SURFACE_ALT, SLOT_ACCENT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 1, 0, 2, 1, 1, 3
    SPRITE_RLE 1, 1, 1, 2, 1, 0, 1, 2
    SPRITE_RLE 1, 1, 1, 3, 1, 1, 1, 2
    SPRITE_RLE 1, 0, 1, 2, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 1, 2, 1, 0, 1, 2
    SPRITE_RLE 1, 1, 1, 0, 2, 1, 1, 0
    SPRITE_RLE 2, 1, 1, 0, 1, 0, 3, 4
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[BOOK]"
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_journal_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_journal_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_SURFACE_ALT, SLOT_ACCENT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 1, 3
    SPRITE_RLE 1, 2, 1, 0, 1, 2, 1, 3
    SPRITE_RLE 1, 2, 1, 0, 1, 2, 1, 0
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[JN]"
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_settings (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_settings, 6, 6, 1
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_EAR_BLUSH, SLOT_EYE_NOSE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 2, 0, 1, 1, 1, 2, 1, 0
    SPRITE_RLE 1, 2, 1, 1, 1, 0, 1, 0
    SPRITE_RLE 1, 2, 1, 4, 1, 2, 2, 0
    SPRITE_RLE 1, 1, 1, 2, 1, 3, 1, 2
    SPRITE_RLE 1, 1, 1, 0, 1, 0, 3, 2
    SPRITE_RLE 2, 0, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[GEAR]"
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_settings_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_settings_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_EAR_BLUSH, SLOT_EYE_NOSE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 1, 2, 2, 1, 1, 1, 2
    SPRITE_RLE 2, 4, 1, 2, 1, 2, 2, 3
    SPRITE_RLE 1, 2, 1, 1, 2, 2, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[ST]"
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_quit (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_quit, 6, 6, 1
    SPRITE_PALETTE SLOT_TITLE_ALT, SLOT_EAR_BLUSH, SLOT_TEXT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 1, 3, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 2, 2, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 1, 0, 1, 2
    SPRITE_RLE 1, 0, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 2, 2, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 3, 3, 3, 1, 1, 0
    SPRITE_RLE 2, 3
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[EXIT]"
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_quit_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_quit_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_TITLE_ALT, SLOT_EAR_BLUSH, SLOT_TEXT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 2, 0, 2, 1, 1, 2
    SPRITE_RLE 1, 0, 2, 1, 2, 2, 2, 1
    SPRITE_RLE 2, 3
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[QT]"
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_paw (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_paw, 6, 6, 1
    SPRITE_PALETTE SLOT_FUR, SLOT_EAR_BLUSH, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 2, 1, 0, 1, 2
    SPRITE_RLE 2, 0, 1, 2, 1, 0, 1, 2
    SPRITE_RLE 1, 0, 1, 2, 1, 0, 2, 0
    SPRITE_RLE 2, 1, 2, 0, 1, 0, 4, 1
    SPRITE_RLE 1, 0, 1, 0, 4, 1, 1, 0
    SPRITE_RLE 2, 0, 2, 1, 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "( ^ ) "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_paw_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_paw_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_FUR, SLOT_EAR_BLUSH, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 2, 1, 0, 1, 2, 1, 0
    SPRITE_RLE 1, 0, 2, 2, 1, 0, 4, 1
    SPRITE_RLE 1, 0, 2, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "(^) "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_star (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_star, 6, 6, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_WARN
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 2, 1, 2, 0, 2, 0
    SPRITE_RLE 2, 1, 2, 0, 6, 1, 1, 0
    SPRITE_RLE 4, 1, 1, 0, 2, 1, 2, 0
    SPRITE_RLE 2, 1, 1, 1, 4, 0, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[ * ] "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_star_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_star_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_WARN
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 4, 1
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 1, 1
    SPRITE_RLE 2, 0, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[*] "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_sparkle (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_sparkle, 6, 6, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 1, 1, 3, 0, 1, 0
    SPRITE_RLE 3, 1, 1, 0, 1, 2, 5, 1
    SPRITE_RLE 1, 0, 1, 0, 3, 1, 2, 0
    SPRITE_RLE 2, 0, 1, 1, 1, 0, 1, 2
    SPRITE_RLE 1, 0, 4, 0, 1, 2, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "+ * + "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_sparkle_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_sparkle_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 1, 2, 0, 3, 1
    SPRITE_RLE 1, 0, 1, 0, 1, 1, 1, 0
    SPRITE_RLE 1, 2, 3, 0, 1, 2
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "+*  "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_check (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_check, 6, 6, 1
    SPRITE_PALETTE SLOT_OK, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 5, 0, 1, 1, 4, 0, 2, 1
    SPRITE_RLE 3, 0, 2, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 0, 2, 1, 2, 0, 3, 1
    SPRITE_RLE 3, 0, 1, 0, 1, 1, 4, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[ V ] "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_check_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_check_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_OK, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 3, 0, 1, 1, 2, 0, 2, 1
    SPRITE_RLE 3, 1, 1, 0, 1, 0, 1, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[V] "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_heart (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_heart, 6, 6, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_EAR_BLUSH
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 2, 1
    SPRITE_RLE 1, 1, 1, 2, 4, 1, 6, 1
    SPRITE_RLE 1, 0, 4, 1, 1, 0, 2, 0
    SPRITE_RLE 2, 1, 2, 0, 3, 0, 1, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "< 3 > "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_heart_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_heart_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_EAR_BLUSH
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 4, 1, 1, 1, 1, 2, 2, 1
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 2, 0
    SPRITE_RLE 1, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "<3  "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_flame (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_flame, 6, 6, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_WARN, SLOT_ACCENT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 1, 1, 3, 0, 1, 0
    SPRITE_RLE 3, 1, 2, 0, 2, 1, 1, 3
    SPRITE_RLE 2, 1, 1, 0, 1, 1, 3, 3
    SPRITE_RLE 1, 1, 1, 0, 2, 1, 1, 3
    SPRITE_RLE 2, 1, 1, 0, 1, 0, 3, 1
    SPRITE_RLE 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "( ^ ) "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_flame_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_flame_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_WARN, SLOT_ACCENT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 1, 2, 0, 1, 1
    SPRITE_RLE 1, 3, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 1, 3, 1, 1, 1, 0, 1, 0
    SPRITE_RLE 1, 1, 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "(^) "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_moon (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_moon, 6, 6, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 3, 1, 1, 0, 1, 0
    SPRITE_RLE 2, 1, 3, 0, 2, 1, 4, 0
    SPRITE_RLE 2, 1, 4, 0, 1, 0, 2, 1
    SPRITE_RLE 3, 0, 2, 0, 3, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "( ) ) "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_moon_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_moon_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_TITLE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 2, 1
    SPRITE_RLE 2, 0, 2, 1, 2, 0, 1, 0
    SPRITE_RLE 2, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "()) "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_bell (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_bell, 6, 6, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_WARN
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 2, 1, 2, 0, 1, 0
    SPRITE_RLE 4, 1, 1, 0, 1, 0, 4, 1
    SPRITE_RLE 1, 0, 6, 1, 6, 1, 2, 0
    SPRITE_RLE 2, 2, 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "( o ) "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_bell_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_bell_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_WARN
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 1, 0
    SPRITE_RLE 2, 1, 1, 0, 4, 1, 1, 0
    SPRITE_RLE 2, 2, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "(o) "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_plus (6x3 cells, 6x6 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_plus, 6, 6, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 2, 1, 2, 0, 2, 0
    SPRITE_RLE 2, 1, 2, 0, 6, 1, 6, 1
    SPRITE_RLE 2, 0, 2, 1, 2, 0, 2, 0
    SPRITE_RLE 2, 1, 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (3 lines) ---
    SPRITE_ASCII_BEGIN 3
    SPRITE_ASCII_LINE "[ + ] "
    SPRITE_ASCII_LINE "      "
    SPRITE_ASCII_LINE "      "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_icon_plus_compact (4x2 cells, 4x4 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_icon_plus_compact, 4, 4, 1
    SPRITE_PALETTE SLOT_ACCENT, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 1, 1, 0, 4, 1
    SPRITE_RLE 4, 1, 1, 0, 2, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[+] "
    SPRITE_ASCII_LINE "    "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_vine_corner_tl (8x4 cells, 8x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_vine_corner_tl, 8, 8, 1
    SPRITE_PALETTE SLOT_OK, SLOT_EAR_BLUSH, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 7, 1, 1, 1, 1, 1, 1, 0
    SPRITE_RLE 1, 1, 3, 0, 1, 2, 1, 0
    SPRITE_RLE 1, 1, 3, 0, 2, 1, 2, 0
    SPRITE_RLE 1, 1, 1, 0, 1, 2, 3, 0
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 3, 0
    SPRITE_RLE 1, 1, 3, 0, 1, 1, 1, 0
    SPRITE_RLE 2, 1, 4, 0, 1, 1, 7, 0
    SPRITE_RLE 1, 1, 7, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "+-------"
    SPRITE_ASCII_LINE "| *   * "
    SPRITE_ASCII_LINE "|  * *  "
    SPRITE_ASCII_LINE "| *     "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_vine_corner_br (8x4 cells, 8x8 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_vine_corner_br, 8, 8, 1
    SPRITE_PALETTE SLOT_OK, SLOT_EAR_BLUSH, SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 7, 0, 1, 1, 7, 0, 1, 1
    SPRITE_RLE 4, 0, 2, 1, 1, 0, 1, 1
    SPRITE_RLE 3, 0, 1, 1, 3, 0, 1, 1
    SPRITE_RLE 1, 0, 1, 1, 3, 0, 1, 2
    SPRITE_RLE 1, 0, 1, 1, 2, 0, 2, 1
    SPRITE_RLE 3, 0, 1, 1, 1, 0, 1, 2
    SPRITE_RLE 3, 0, 1, 1, 1, 0, 1, 1
    SPRITE_RLE 7, 1, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (4 lines) ---
    SPRITE_ASCII_BEGIN 4
    SPRITE_ASCII_LINE "     * |"
    SPRITE_ASCII_LINE "  * *  |"
    SPRITE_ASCII_LINE " *   * |"
    SPRITE_ASCII_LINE "-------+"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_scattered_star (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_scattered_star, 2, 2, 1
    SPRITE_PALETTE SLOT_ACCENT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 1, 1, 0, 1, 0, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "*."
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_scattered_paw (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_scattered_paw, 2, 2, 1
    SPRITE_PALETTE SLOT_FUR, SLOT_EAR_BLUSH
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 2, 2, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "**"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_widget_toggle (6x2 cells, 6x4 px, 2 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_widget_toggle, 6, 4, 2
    SPRITE_PALETTE SLOT_DIM, SLOT_OK, SLOT_TEXT, SLOT_SURFACE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 3, 2, 1, 1, 0
    SPRITE_RLE 1, 3, 2, 4, 1, 3, 2, 1
    SPRITE_RLE 1, 3, 2, 4, 1, 3, 2, 1
    SPRITE_RLE 1, 0, 2, 3, 2, 1, 1, 0
    SPRITE_FRAME_END
    ; --- Frame 1 RLE Stream ---
    SPRITE_RLE 1, 0, 2, 2, 2, 3, 1, 0
    SPRITE_RLE 2, 2, 1, 3, 2, 4, 1, 3
    SPRITE_RLE 2, 2, 1, 3, 2, 4, 1, 3
    SPRITE_RLE 1, 0, 2, 2, 2, 3, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (2 lines) ---
    SPRITE_ASCII_BEGIN 2
    SPRITE_ASCII_LINE "[ OFF]"
    SPRITE_ASCII_LINE "[ OFF]"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_btn_cap_l (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_btn_cap_l, 2, 2, 1
    SPRITE_PALETTE SLOT_TITLE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 1, 1, 0, 1, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "( "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_btn_cap_r (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_btn_cap_r, 2, 2, 1
    SPRITE_PALETTE SLOT_TITLE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 1, 1, 0, 1, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE ") "
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_prog_track_empty (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_prog_track_empty, 2, 2, 1
    SPRITE_PALETTE SLOT_SURFACE_ALT
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 2, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "--"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_prog_track_fill (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_prog_track_fill, 2, 2, 1
    SPRITE_PALETTE SLOT_OK
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 2, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "=="
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_prog_marker_socket (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_prog_marker_socket, 2, 2, 1
    SPRITE_PALETTE SLOT_DIM
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 0, 2, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "__"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_panel_corner_tl (1x1 cells, 1x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_panel_corner_tl, 1, 2, 1
    SPRITE_PALETTE SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 1, 0, 1, 1, 2, 1
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "/"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_panel_corner_br (1x1 cells, 1x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_panel_corner_br, 1, 2, 1
    SPRITE_PALETTE SLOT_OUTLINE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 1, 1, 1, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "/"
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_tab_active (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_tab_active, 2, 2, 1
    SPRITE_PALETTE SLOT_TITLE, SLOT_SURFACE
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 2, 2
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "=="
SPRITE_END

; -----------------------------------------------------------------------------
; sprite_tab_inactive (2x1 cells, 2x2 px, 1 frames)
; -----------------------------------------------------------------------------
SPRITE_BEGIN sprite_tab_inactive, 2, 2, 1
    SPRITE_PALETTE SLOT_DIM
    ; --- Frame 0 RLE Stream ---
    SPRITE_RLE 2, 1, 2, 0
    SPRITE_FRAME_END
    ; --- ASCII Fallback Art (1 lines) ---
    SPRITE_ASCII_BEGIN 1
    SPRITE_ASCII_LINE "--"
SPRITE_END


; =============================================================================
; Big Digit Sprite Pointer Tables (for bigdigit_draw)
; =============================================================================
global digit_large_sprites
digit_large_sprites:
    dd sprite_digit_large_0
    dd sprite_digit_large_1
    dd sprite_digit_large_2
    dd sprite_digit_large_3
    dd sprite_digit_large_4
    dd sprite_digit_large_5
    dd sprite_digit_large_6
    dd sprite_digit_large_7
    dd sprite_digit_large_8
    dd sprite_digit_large_9
    dd sprite_digit_large_colon

global digit_compact_sprites
digit_compact_sprites:
    dd sprite_digit_compact_0
    dd sprite_digit_compact_1
    dd sprite_digit_compact_2
    dd sprite_digit_compact_3
    dd sprite_digit_compact_4
    dd sprite_digit_compact_5
    dd sprite_digit_compact_6
    dd sprite_digit_compact_7
    dd sprite_digit_compact_8
    dd sprite_digit_compact_9
    dd sprite_digit_compact_colon

; =============================================================================
; Sprite Registry Table (for Hidden Sprite Viewer & Runtime Dispatch)
; =============================================================================
global sprite_count
global sprite_table
global sprite_names

sprite_count:           dd 87

sprite_table:
    dd sprite_logo_cat
    dd sprite_logo_cat_std
    dd sprite_logo_cat_compact
    dd sprite_tomato_mascot
    dd sprite_tomato_mascot_std
    dd sprite_tomato_mascot_compact
    dd sprite_sleeping_cat
    dd sprite_sleeping_cat_std
    dd sprite_habits_cat_head
    dd sprite_habits_cat_head_compact
    dd sprite_cat_working
    dd sprite_cat_working_std
    dd sprite_cat_working_compact
    dd sprite_cat_resting
    dd sprite_cat_resting_std
    dd sprite_cat_resting_compact
    dd sprite_cat_cheering
    dd sprite_cat_cheering_std
    dd sprite_cat_cheering_compact
    dd sprite_cat_surprised
    dd sprite_cat_surprised_std
    dd sprite_cat_surprised_compact
    dd sprite_cat_strolling
    dd sprite_digit_large_0
    dd sprite_digit_large_1
    dd sprite_digit_large_2
    dd sprite_digit_large_3
    dd sprite_digit_large_4
    dd sprite_digit_large_5
    dd sprite_digit_large_6
    dd sprite_digit_large_7
    dd sprite_digit_large_8
    dd sprite_digit_large_9
    dd sprite_digit_large_colon
    dd sprite_digit_compact_0
    dd sprite_digit_compact_1
    dd sprite_digit_compact_2
    dd sprite_digit_compact_3
    dd sprite_digit_compact_4
    dd sprite_digit_compact_5
    dd sprite_digit_compact_6
    dd sprite_digit_compact_7
    dd sprite_digit_compact_8
    dd sprite_digit_compact_9
    dd sprite_digit_compact_colon
    dd sprite_icon_timer
    dd sprite_icon_timer_compact
    dd sprite_icon_habits
    dd sprite_icon_habits_compact
    dd sprite_icon_journal
    dd sprite_icon_journal_compact
    dd sprite_icon_settings
    dd sprite_icon_settings_compact
    dd sprite_icon_quit
    dd sprite_icon_quit_compact
    dd sprite_icon_paw
    dd sprite_icon_paw_compact
    dd sprite_icon_star
    dd sprite_icon_star_compact
    dd sprite_icon_sparkle
    dd sprite_icon_sparkle_compact
    dd sprite_icon_check
    dd sprite_icon_check_compact
    dd sprite_icon_heart
    dd sprite_icon_heart_compact
    dd sprite_icon_flame
    dd sprite_icon_flame_compact
    dd sprite_icon_moon
    dd sprite_icon_moon_compact
    dd sprite_icon_bell
    dd sprite_icon_bell_compact
    dd sprite_icon_plus
    dd sprite_icon_plus_compact
    dd sprite_vine_corner_tl
    dd sprite_vine_corner_br
    dd sprite_scattered_star
    dd sprite_scattered_paw
    dd sprite_widget_toggle
    dd sprite_btn_cap_l
    dd sprite_btn_cap_r
    dd sprite_prog_track_empty
    dd sprite_prog_track_fill
    dd sprite_prog_marker_socket
    dd sprite_panel_corner_tl
    dd sprite_panel_corner_br
    dd sprite_tab_active
    dd sprite_tab_inactive

sprite_names:
    dd str_sname_sprite_logo_cat
    dd str_sname_sprite_logo_cat_std
    dd str_sname_sprite_logo_cat_compact
    dd str_sname_sprite_tomato_mascot
    dd str_sname_sprite_tomato_mascot_std
    dd str_sname_sprite_tomato_mascot_compact
    dd str_sname_sprite_sleeping_cat
    dd str_sname_sprite_sleeping_cat_std
    dd str_sname_sprite_habits_cat_head
    dd str_sname_sprite_habits_cat_head_compact
    dd str_sname_sprite_cat_working
    dd str_sname_sprite_cat_working_std
    dd str_sname_sprite_cat_working_compact
    dd str_sname_sprite_cat_resting
    dd str_sname_sprite_cat_resting_std
    dd str_sname_sprite_cat_resting_compact
    dd str_sname_sprite_cat_cheering
    dd str_sname_sprite_cat_cheering_std
    dd str_sname_sprite_cat_cheering_compact
    dd str_sname_sprite_cat_surprised
    dd str_sname_sprite_cat_surprised_std
    dd str_sname_sprite_cat_surprised_compact
    dd str_sname_sprite_cat_strolling
    dd str_sname_sprite_digit_large_0
    dd str_sname_sprite_digit_large_1
    dd str_sname_sprite_digit_large_2
    dd str_sname_sprite_digit_large_3
    dd str_sname_sprite_digit_large_4
    dd str_sname_sprite_digit_large_5
    dd str_sname_sprite_digit_large_6
    dd str_sname_sprite_digit_large_7
    dd str_sname_sprite_digit_large_8
    dd str_sname_sprite_digit_large_9
    dd str_sname_sprite_digit_large_colon
    dd str_sname_sprite_digit_compact_0
    dd str_sname_sprite_digit_compact_1
    dd str_sname_sprite_digit_compact_2
    dd str_sname_sprite_digit_compact_3
    dd str_sname_sprite_digit_compact_4
    dd str_sname_sprite_digit_compact_5
    dd str_sname_sprite_digit_compact_6
    dd str_sname_sprite_digit_compact_7
    dd str_sname_sprite_digit_compact_8
    dd str_sname_sprite_digit_compact_9
    dd str_sname_sprite_digit_compact_colon
    dd str_sname_sprite_icon_timer
    dd str_sname_sprite_icon_timer_compact
    dd str_sname_sprite_icon_habits
    dd str_sname_sprite_icon_habits_compact
    dd str_sname_sprite_icon_journal
    dd str_sname_sprite_icon_journal_compact
    dd str_sname_sprite_icon_settings
    dd str_sname_sprite_icon_settings_compact
    dd str_sname_sprite_icon_quit
    dd str_sname_sprite_icon_quit_compact
    dd str_sname_sprite_icon_paw
    dd str_sname_sprite_icon_paw_compact
    dd str_sname_sprite_icon_star
    dd str_sname_sprite_icon_star_compact
    dd str_sname_sprite_icon_sparkle
    dd str_sname_sprite_icon_sparkle_compact
    dd str_sname_sprite_icon_check
    dd str_sname_sprite_icon_check_compact
    dd str_sname_sprite_icon_heart
    dd str_sname_sprite_icon_heart_compact
    dd str_sname_sprite_icon_flame
    dd str_sname_sprite_icon_flame_compact
    dd str_sname_sprite_icon_moon
    dd str_sname_sprite_icon_moon_compact
    dd str_sname_sprite_icon_bell
    dd str_sname_sprite_icon_bell_compact
    dd str_sname_sprite_icon_plus
    dd str_sname_sprite_icon_plus_compact
    dd str_sname_sprite_vine_corner_tl
    dd str_sname_sprite_vine_corner_br
    dd str_sname_sprite_scattered_star
    dd str_sname_sprite_scattered_paw
    dd str_sname_sprite_widget_toggle
    dd str_sname_sprite_btn_cap_l
    dd str_sname_sprite_btn_cap_r
    dd str_sname_sprite_prog_track_empty
    dd str_sname_sprite_prog_track_fill
    dd str_sname_sprite_prog_marker_socket
    dd str_sname_sprite_panel_corner_tl
    dd str_sname_sprite_panel_corner_br
    dd str_sname_sprite_tab_active
    dd str_sname_sprite_tab_inactive

str_sname_sprite_logo_cat: db "Logo Cat (Grand 14x7)", CHAR_NULL
str_sname_sprite_logo_cat_std: db "Logo Cat (Std 12x6)", CHAR_NULL
str_sname_sprite_logo_cat_compact: db "Logo Cat (Compact 8x4)", CHAR_NULL
str_sname_sprite_tomato_mascot: db "Tomato Mascot (Grand 14x7)", CHAR_NULL
str_sname_sprite_tomato_mascot_std: db "Tomato Mascot (Std 10x5)", CHAR_NULL
str_sname_sprite_tomato_mascot_compact: db "Tomato Mascot (Compact 6x3)", CHAR_NULL
str_sname_sprite_sleeping_cat: db "Sleeping Cat (Grand 8x4)", CHAR_NULL
str_sname_sprite_sleeping_cat_std: db "Sleeping Cat (Std 6x3)", CHAR_NULL
str_sname_sprite_habits_cat_head: db "Habits Cat Head (Std 4x2)", CHAR_NULL
str_sname_sprite_habits_cat_head_compact: db "Habits Cat Head (Compact 3x2)", CHAR_NULL
str_sname_sprite_cat_working: db "Working Cat (Grand 14x7)", CHAR_NULL
str_sname_sprite_cat_working_std: db "Working Cat (Std 10x5)", CHAR_NULL
str_sname_sprite_cat_working_compact: db "Working Cat (Compact 6x3)", CHAR_NULL
str_sname_sprite_cat_resting: db "Resting Cat (Grand 14x7)", CHAR_NULL
str_sname_sprite_cat_resting_std: db "Resting Cat (Std 10x5)", CHAR_NULL
str_sname_sprite_cat_resting_compact: db "Resting Cat (Compact 6x3)", CHAR_NULL
str_sname_sprite_cat_cheering: db "Cheering Cat (Grand 14x7)", CHAR_NULL
str_sname_sprite_cat_cheering_std: db "Cheering Cat (Std 10x5)", CHAR_NULL
str_sname_sprite_cat_cheering_compact: db "Cheering Cat (Compact 6x3)", CHAR_NULL
str_sname_sprite_cat_surprised: db "Surprised Cat (Grand 10x5)", CHAR_NULL
str_sname_sprite_cat_surprised_std: db "Surprised Cat (Std 8x4)", CHAR_NULL
str_sname_sprite_cat_surprised_compact: db "Surprised Cat (Compact 6x3)", CHAR_NULL
str_sname_sprite_cat_strolling: db "Walking Cat (Std 6x2)", CHAR_NULL
str_sname_sprite_digit_large_0: db "Large Digit 0 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_1: db "Large Digit 1 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_2: db "Large Digit 2 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_3: db "Large Digit 3 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_4: db "Large Digit 4 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_5: db "Large Digit 5 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_6: db "Large Digit 6 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_7: db "Large Digit 7 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_8: db "Large Digit 8 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_9: db "Large Digit 9 (5x4)", CHAR_NULL
str_sname_sprite_digit_large_colon: db "Large Colon (3x4)", CHAR_NULL
str_sname_sprite_digit_compact_0: db "Compact Digit 0 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_1: db "Compact Digit 1 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_2: db "Compact Digit 2 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_3: db "Compact Digit 3 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_4: db "Compact Digit 4 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_5: db "Compact Digit 5 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_6: db "Compact Digit 6 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_7: db "Compact Digit 7 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_8: db "Compact Digit 8 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_9: db "Compact Digit 9 (3x2)", CHAR_NULL
str_sname_sprite_digit_compact_colon: db "Compact Colon (2x2)", CHAR_NULL
str_sname_sprite_icon_timer: db "Icon Timer (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_timer_compact: db "Icon Timer (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_habits: db "Icon Habits (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_habits_compact: db "Icon Habits (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_journal: db "Icon Journal (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_journal_compact: db "Icon Journal (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_settings: db "Icon Settings (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_settings_compact: db "Icon Settings (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_quit: db "Icon Quit (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_quit_compact: db "Icon Quit (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_paw: db "Icon Paw (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_paw_compact: db "Icon Paw (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_star: db "Icon Star (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_star_compact: db "Icon Star (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_sparkle: db "Icon Sparkle (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_sparkle_compact: db "Icon Sparkle (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_check: db "Icon Check (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_check_compact: db "Icon Check (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_heart: db "Icon Heart (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_heart_compact: db "Icon Heart (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_flame: db "Icon Flame (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_flame_compact: db "Icon Flame (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_moon: db "Icon Moon (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_moon_compact: db "Icon Moon (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_bell: db "Icon Bell (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_bell_compact: db "Icon Bell (Compact 4x2)", CHAR_NULL
str_sname_sprite_icon_plus: db "Icon Plus (Std 6x3)", CHAR_NULL
str_sname_sprite_icon_plus_compact: db "Icon Plus (Compact 4x2)", CHAR_NULL
str_sname_sprite_vine_corner_tl: db "Ornament Vine TL (8x4)", CHAR_NULL
str_sname_sprite_vine_corner_br: db "Ornament Vine BR (8x4)", CHAR_NULL
str_sname_sprite_scattered_star: db "Ornament Star (2x1)", CHAR_NULL
str_sname_sprite_scattered_paw: db "Ornament Paw (2x1)", CHAR_NULL
str_sname_sprite_widget_toggle: db "Widget Toggle Switch (6x2)", CHAR_NULL
str_sname_sprite_btn_cap_l: db "Widget Button Cap L (2x1)", CHAR_NULL
str_sname_sprite_btn_cap_r: db "Widget Button Cap R (2x1)", CHAR_NULL
str_sname_sprite_prog_track_empty: db "Widget Track Empty (2x1)", CHAR_NULL
str_sname_sprite_prog_track_fill: db "Widget Track Fill (2x1)", CHAR_NULL
str_sname_sprite_prog_marker_socket: db "Widget Marker Socket (2x1)", CHAR_NULL
str_sname_sprite_panel_corner_tl: db "Widget Panel Corner TL (1x1)", CHAR_NULL
str_sname_sprite_panel_corner_br: db "Widget Panel Corner BR (1x1)", CHAR_NULL
str_sname_sprite_tab_active: db "Widget Tab Active (2x1)", CHAR_NULL
str_sname_sprite_tab_inactive: db "Widget Tab Inactive (2x1)", CHAR_NULL
