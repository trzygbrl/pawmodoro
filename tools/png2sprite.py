#!/usr/bin/env python3
"""
Pawmodoro v3 - PNG to Sprite Converter (tools/png2sprite.py)
Development-only authoring utility to convert PNG pixel art into
canonical NASM sprite definitions per PRD_V3 §4.2 and §sprites.

Zero runtime dependency: This script is only used during development.
Requirements: Python 3.8+, Pillow.
"""

import sys
import os
import json
import argparse
from typing import List, Tuple, Dict, Any, Optional

try:
    from PIL import Image
except ImportError:
    Image = None

# Extended theme slot name to slot ID mapping (PRD_V3 §5.1, §5.2)
SLOT_NAMES: Dict[str, int] = {
    "SLOT_BORDER": 0,
    "SLOT_TITLE": 1,
    "SLOT_ACCENT": 2,
    "SLOT_TEXT": 3,
    "SLOT_DIM": 4,
    "SLOT_OK": 5,
    "SLOT_WARN": 6,
    "SLOT_ERR": 7,
    "SLOT_CAT": 8,
    "SLOT_BAR_FULL": 9,
    "SLOT_BAR_EMPTY": 10,
    "SLOT_HIGHLIGHT": 11,
    "SLOT_BG": 12,
    "SLOT_SURFACE": 13,
    "SLOT_SURFACE_ALT": 14,
    "SLOT_BORDER_FOCUS": 15,
    "SLOT_TITLE_ALT": 16,
    "SLOT_TEXT_INV": 17,
    "SLOT_FUR": 18,
    "SLOT_FUR_SHADE": 19,
    "SLOT_FUR_STRIPE": 20,
    "SLOT_EAR_BLUSH": 21,
    "SLOT_OUTLINE": 22,
    "SLOT_EYE_NOSE": 23,
}

MAX_PALETTE_ENTRIES = 15
MAX_RUN_LENGTH = 255


def parse_slot_mapping(mapping_data: Any) -> Tuple[int, List[int], List[Tuple[int, int, int]]]:
    """
    Parses and validates the slot mapping structure.
    Returns:
        (palette_entries, slot_ids, reference_rgbs)
    """
    if isinstance(mapping_data, str):
        try:
            mapping_data = json.loads(mapping_data)
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON mapping: {e}")

    if not isinstance(mapping_data, dict) or "slots" not in mapping_data:
        raise ValueError("Mapping file must contain a top-level 'slots' list.")

    slots_list = mapping_data["slots"]
    if not isinstance(slots_list, list) or len(slots_list) == 0:
        raise ValueError("'slots' list must contain at least 1 palette entry.")

    if len(slots_list) > MAX_PALETTE_ENTRIES:
        raise ValueError(
            f"Too many palette entries: {len(slots_list)} (maximum {MAX_PALETTE_ENTRIES} allowed)."
        )

    palette_entries = len(slots_list)
    slot_ids = []
    reference_rgbs = []

    for i, entry in enumerate(slots_list):
        if not isinstance(entry, dict):
            raise ValueError(f"Palette entry {i} is not an object.")

        # Resolve slot ID
        if "slot_id" in entry:
            slot_id = int(entry["slot_id"])
        elif "slot" in entry and entry["slot"] in SLOT_NAMES:
            slot_id = SLOT_NAMES[entry["slot"]]
        else:
            raise ValueError(f"Palette entry {i} lacks valid 'slot_id' or recognized 'slot' name.")

        if not (0 <= slot_id <= 23):
            raise ValueError(f"Palette entry {i} has out-of-range slot ID {slot_id} (0..23 allowed).")

        # Resolve reference RGB
        if "rgb" not in entry or not isinstance(entry["rgb"], (list, tuple)) or len(entry["rgb"]) != 3:
            raise ValueError(f"Palette entry {i} must specify 'rgb' as [R, G, B].")

        rgb = tuple(int(c) for c in entry["rgb"])
        for c in rgb:
            if not (0 <= c <= 255):
                raise ValueError(f"Palette entry {i} RGB component {c} out of range (0..255).")

        slot_ids.append(slot_id)
        reference_rgbs.append(rgb)

    return palette_entries, slot_ids, reference_rgbs


def quantize_pixel(
    rgba: Tuple[int, int, int, int],
    reference_rgbs: List[Tuple[int, int, int]],
    alpha_threshold: int = 128,
) -> int:
    """
    Quantizes an RGBA pixel to a palette index (0 = transparent, 1..N = mapped slot).
    Uses Euclidean distance with deterministic tie-breaking.
    """
    r, g, b, a = rgba
    if a < alpha_threshold:
        return 0  # Transparent

    best_idx = 1
    best_dist = float("inf")

    for i, ref_rgb in enumerate(reference_rgbs, start=1):
        rr, rg, rb = ref_rgb
        # Weighted Euclidean distance approximation for perceptual color distance
        dr = r - rr
        dg = g - rg
        db = b - rb
        dist = 2 * dr * dr + 4 * dg * dg + 3 * db * db
        if dist < best_dist:
            best_dist = dist
            best_idx = i

    return best_idx


def run_length_encode(pixels: List[int]) -> List[Tuple[int, int]]:
    """
    Encodes a stream of palette indices into run-length pairs (count, index).
    Splits any run longer than MAX_RUN_LENGTH (255).
    """
    if not pixels:
        return []

    runs: List[Tuple[int, int]] = []
    current_val = pixels[0]
    current_count = 1

    for val in pixels[1:]:
        if val == current_val and current_count < MAX_RUN_LENGTH:
            current_count += 1
        else:
            runs.append((current_count, current_val))
            current_val = val
            current_count = 1

    runs.append((current_count, current_val))
    return runs


def generate_ascii_fallback(
    width_cells: int,
    height_cells: int,
    frames_pixels: List[List[int]],
    slot_ids: List[int],
) -> List[str]:
    """
    Generates a human-readable 7-bit ASCII representation bounded by (width_cells, height_cells).
    Every character is strictly < 0x80.
    """
    # Use frame 0 as primary fallback template
    frame0 = frames_pixels[0]
    ascii_lines: List[str] = []

    # Map slot types to ASCII glyphs
    # Eye/Nose -> '^', '.', 'o', '*'
    # Blush/Ears -> '@', '%'
    # Fur/Body -> '#', '=', ':'
    # Outline -> '/', '\\', '|', '-'
    for cy in range(height_cells):
        row_chars = []
        for cx in range(width_cells):
            top_px = frame0[(2 * cy) * width_cells + cx]
            bot_px = frame0[(2 * cy + 1) * width_cells + cx]

            if top_px == 0 and bot_px == 0:
                row_chars.append(" ")
            elif top_px == 0 and bot_px != 0:
                slot = slot_ids[bot_px - 1] if bot_px <= len(slot_ids) else 0
                if slot == 23:  # EYE_NOSE
                    row_chars.append(".")
                elif slot == 22:  # OUTLINE
                    row_chars.append("_")
                elif slot == 21:  # EAR_BLUSH
                    row_chars.append("~")
                else:
                    row_chars.append(".")
            elif top_px != 0 and bot_px == 0:
                slot = slot_ids[top_px - 1] if top_px <= len(slot_ids) else 0
                if slot == 23:  # EYE_NOSE
                    row_chars.append("^")
                elif slot == 22:  # OUTLINE
                    row_chars.append("~")
                elif slot == 21:  # EAR_BLUSH
                    row_chars.append("*")
                else:
                    row_chars.append("'")
            else:
                # Both opaque
                top_slot = slot_ids[top_px - 1] if top_px <= len(slot_ids) else 0
                bot_slot = slot_ids[bot_px - 1] if bot_px <= len(slot_ids) else 0
                if top_slot == 23 or bot_slot == 23:
                    row_chars.append("o")
                elif top_slot == 21 or bot_slot == 21:
                    row_chars.append("@")
                elif top_slot == 20 or bot_slot == 20:  # STRIPE
                    row_chars.append("=")
                elif top_slot == 19 or bot_slot == 19:  # SHADE
                    row_chars.append("%")
                elif top_slot == 22 or bot_slot == 22:  # OUTLINE
                    row_chars.append("#")
                else:
                    row_chars.append("#")

        line = "".join(row_chars)
        # Verify 7-bit ASCII mandate
        for ch in line:
            if ord(ch) >= 0x80:
                raise ValueError(f"Non-ASCII character {ch!r} in generated ASCII art!")
        ascii_lines.append(line)

    return ascii_lines


def emit_nasm_source(
    symbol_name: str,
    width_cells: int,
    height_pixels: int,
    frame_count: int,
    slot_ids: List[int],
    frames_runs: List[List[Tuple[int, int]]],
    ascii_lines: List[str],
) -> str:
    """
    Formats the sprite definition using canonical NASM macros.
    """
    lines: List[str] = []
    lines.append("; =============================================================================")
    lines.append(f"; Sprite Definition: {symbol_name}")
    lines.append(f"; Dimensions: {width_cells} cells wide x {height_pixels} pixel rows high ({height_pixels // 2} cell rows)")
    lines.append(f"; Frames: {frame_count} | Palette entries: {len(slot_ids)}")
    lines.append("; Generated by tools/png2sprite.py per PRD_V3 §4.2")
    lines.append("; =============================================================================")
    lines.append("")
    lines.append(f"SPRITE_BEGIN {symbol_name}, {width_cells}, {height_pixels}, {frame_count}")
    
    # Palette definition
    slot_str_list = []
    # Invert mapping to find names if available
    inv_slots = {v: k for k, v in SLOT_NAMES.items()}
    for sid in slot_ids:
        slot_str_list.append(inv_slots.get(sid, str(sid)))
    lines.append(f"    SPRITE_PALETTE {', '.join(slot_str_list)}")
    lines.append("")

    # RLE streams
    for f_idx, runs in enumerate(frames_runs):
        lines.append(f"    ; --- Frame {f_idx} RLE Stream ({len(runs)} runs) ---")
        # Group runs nicely (4 pairs per line)
        for i in range(0, len(runs), 4):
            chunk = runs[i:i+4]
            chunk_strs = [f"{cnt}, {val}" for cnt, val in chunk]
            lines.append(f"    SPRITE_RLE {', '.join(chunk_strs)}")
        lines.append("    SPRITE_FRAME_END")
        lines.append("")

    # ASCII fallback art block
    lines.append(f"    ; --- ASCII Fallback Art ({len(ascii_lines)} lines) ---")
    lines.append(f"    SPRITE_ASCII_BEGIN {len(ascii_lines)}")
    for line in ascii_lines:
        # Escape double quotes inside string if any
        escaped = line.replace('"', '", 34, "')
        lines.append(f'    SPRITE_ASCII_LINE "{escaped}"')
    lines.append("")
    lines.append("SPRITE_END")
    lines.append("")

    return "\n".join(lines)


def render_png_preview(
    width_cells: int,
    height_pixels: int,
    frames_pixels: List[List[int]],
    reference_rgbs: List[Tuple[int, int, int]],
    bg_rgb: Tuple[int, int, int] = (26, 26, 26),
    scale: int = 16,
) -> Any:
    """
    Renders a PNG preview image using the exact half-block rendering rule.
    Each terminal cell represents two vertically stacked pixels.
    """
    if Image is None:
        raise RuntimeError("Pillow is required for PNG preview generation.")

    frame0 = frames_pixels[0]
    height_cells = height_pixels // 2
    img_w = width_cells * scale
    img_h = height_cells * (2 * scale)

    img = Image.new("RGBA", (img_w, img_h), (*bg_rgb, 255))
    pixels = img.load()

    for cy in range(height_cells):
        for cx in range(width_cells):
            top_idx = frame0[(2 * cy) * width_cells + cx]
            bot_idx = frame0[(2 * cy + 1) * width_cells + cx]

            top_color = reference_rgbs[top_idx - 1] if top_idx > 0 else bg_rgb
            bot_color = reference_rgbs[bot_idx - 1] if bot_idx > 0 else bg_rgb

            # Paint top half
            for y in range(cy * 2 * scale, (cy * 2 + 1) * scale):
                for x in range(cx * scale, (cx + 1) * scale):
                    pixels[x, y] = (*top_color, 255)

            # Paint bottom half
            for y in range((cy * 2 + 1) * scale, (cy * 2 + 2) * scale):
                for x in range(cx * scale, (cx + 1) * scale):
                    pixels[x, y] = (*bot_color, 255)

    return img


def convert_image(
    input_path: str,
    width_cells: int,
    height_cells: int,
    mapping_data: Any,
    symbol_name: str,
    frames: int = 1,
    direction: str = "horizontal",
    ascii_custom: Optional[str] = None,
) -> Tuple[str, List[List[int]], List[Tuple[int, int, int]], List[str]]:
    """
    Core conversion pipeline.
    """
    if Image is None:
        raise RuntimeError("Pillow is required for image conversion.")

    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    palette_entries, slot_ids, reference_rgbs = parse_slot_mapping(mapping_data)

    if width_cells <= 0 or height_cells <= 0:
        raise ValueError(f"Invalid dimensions: {width_cells}x{height_cells} (must be > 0).")

    height_pixels = height_cells * 2
    if height_pixels % 2 != 0:
        raise ValueError("Height in pixel rows must be even.")

    src_img = Image.open(input_path).convert("RGBA")
    src_w, src_h = src_img.size

    # Slice frames
    frame_crops: List[Any] = []
    if frames <= 1:
        frame_crops.append(src_img)
    else:
        if direction == "horizontal":
            if src_w % frames != 0:
                # Still allow non-exact by integer division
                fw = src_w // frames
            else:
                fw = src_w // frames
            fh = src_h
            for f in range(frames):
                frame_crops.append(src_img.crop((f * fw, 0, (f + 1) * fw, fh)))
        else:
            fw = src_w
            fh = src_h // frames
            for f in range(frames):
                frame_crops.append(src_img.crop((0, f * fh, fw, (f + 1) * fh)))

    frames_pixels: List[List[int]] = []
    frames_runs: List[List[Tuple[int, int]]] = []

    for frame_idx, crop in enumerate(frame_crops):
        # Downsample to target (width_cells, height_pixels)
        resized = crop.resize((width_cells, height_pixels), Image.Resampling.LANCZOS)
        frame_px = []
        for y in range(height_pixels):
            for x in range(width_cells):
                rgba = resized.getpixel((x, y))
                idx = quantize_pixel(rgba, reference_rgbs)
                frame_px.append(idx)

        frames_pixels.append(frame_px)
        runs = run_length_encode(frame_px)
        frames_runs.append(runs)

    # ASCII art fallback
    if ascii_custom:
        ascii_lines = [line.strip("\r") for line in ascii_custom.split("\n")]
        # Pad or clamp to height_cells and width_cells
        while len(ascii_lines) < height_cells:
            ascii_lines.append(" " * width_cells)
        ascii_lines = ascii_lines[:height_cells]
        for i in range(len(ascii_lines)):
            l = ascii_lines[i]
            if len(l) < width_cells:
                ascii_lines[i] = l + " " * (width_cells - len(l))
            elif len(l) > width_cells:
                ascii_lines[i] = l[:width_cells]
    else:
        ascii_lines = generate_ascii_fallback(width_cells, height_cells, frames_pixels, slot_ids)

    nasm_code = emit_nasm_source(
        symbol_name=symbol_name,
        width_cells=width_cells,
        height_pixels=height_pixels,
        frame_count=len(frame_crops),
        slot_ids=slot_ids,
        frames_runs=frames_runs,
        ascii_lines=ascii_lines,
    )

    return nasm_code, frames_pixels, reference_rgbs, ascii_lines


def run_unit_tests():
    """
    Comprehensive self-test suite validating all requirements of PRD_V3 §7.3.
    """
    print("=== Running tools/png2sprite.py Unit Tests ===")
    passed = 0
    total = 0

    def check(name: str, cond: bool, msg: str = ""):
        nonlocal passed, total
        total += 1
        if cond:
            print(f"PASS: {name}")
            passed += 1
        else:
            print(f"FAIL: {name} - {msg}")

    # 1. Test parsing slot mapping
    sample_mapping = {
        "slots": [
            {"slot": "SLOT_OUTLINE", "rgb": [92, 40, 40]},
            {"slot": "SLOT_FUR", "rgb": [248, 195, 158]},
            {"slot": "SLOT_EYE_NOSE", "rgb": [64, 27, 27]},
        ]
    }
    entries, sids, rgbs = parse_slot_mapping(sample_mapping)
    check("Mapping parser basic", entries == 3 and sids == [22, 18, 23])

    # 2. Test mapping bounds (> 15 slots rejected)
    try:
        too_many = {"slots": [{"slot_id": 1, "rgb": [0,0,0]} for _ in range(16)]}
        parse_slot_mapping(too_many)
        check("Mapping >15 slots rejected", False, "Expected ValueError")
    except ValueError:
        check("Mapping >15 slots rejected", True)

    # 3. Test transparent and opaque pixels
    px_trans = quantize_pixel((255, 255, 255, 0), rgbs)
    px_opaque = quantize_pixel((248, 195, 158, 255), rgbs)
    check("Transparent pixel maps to 0", px_trans == 0)
    check("Opaque pixel maps to nearest (FUR)", px_opaque == 2)

    # 4. Test RLE: length 1, max 255, and > 255 split
    stream = [1] + [2] * 255 + [3] * 300
    runs = run_length_encode(stream)
    check("RLE run count", len(runs) == 4)  # (1, 1), (255, 2), (255, 3), (45, 3)
    check("RLE run 1", runs[0] == (1, 1))
    check("RLE run 2 (max 255)", runs[1] == (255, 2))
    check("RLE run 3 (split 255)", runs[2] == (255, 3))
    check("RLE run 4 (remainder 45)", runs[3] == (45, 3))

    # 5. Test all 5 half-block cell combinations in ASCII fallback
    test_frame = [
        0, 0,    # cell 0: both trans
        2, 0,    # cell 1: top opaque, bot trans
        0, 2,    # cell 2: top trans, bot opaque
        2, 2,    # cell 3: same color both
        2, 3,    # cell 4: different colors both
    ]
    # width=5 cells, height_cells=1 (2 pixel rows)
    ascii_out = generate_ascii_fallback(5, 1, [test_frame], sids)
    check("ASCII fallback line count", len(ascii_out) == 1)
    check("ASCII fallback length", len(ascii_out[0]) == 5)
    # Check that all chars are < 0x80
    all_ascii = all(ord(c) < 0x80 for c in ascii_out[0])
    check("ASCII fallback purity (< 0x80)", all_ascii)

    # 6. Test round-trip NASM macro generation
    nasm_code = emit_nasm_source("test_spr", 5, 2, 1, sids, [runs[:2]], ascii_out)
    check("NASM code includes SPRITE_BEGIN", "SPRITE_BEGIN test_spr, 5, 2, 1" in nasm_code)
    check("NASM code includes SPRITE_PALETTE", "SPRITE_PALETTE SLOT_OUTLINE, SLOT_FUR, SLOT_EYE_NOSE" in nasm_code)
    check("NASM code includes SPRITE_FRAME_END", "SPRITE_FRAME_END" in nasm_code)
    check("NASM code includes SPRITE_END", "SPRITE_END" in nasm_code)

    # 7. Test Image-based pipeline if Pillow is available
    if Image is not None:
        # Create a synthetic 10x10 image with odd dimensions test
        test_img = Image.new("RGBA", (21, 17), (248, 195, 158, 255))
        # Top half transparent
        for x in range(21):
            for y in range(8):
                test_img.putpixel((x, y), (0, 0, 0, 0))
        tmp_png = "/tmp/test_synth.png" if os.name != "nt" else "test_synth.png"
        test_img.save(tmp_png)

        code, fpx, r_rgbs, asc = convert_image(
            input_path=tmp_png,
            width_cells=10,
            height_cells=5,  # 10 pixel rows
            mapping_data=sample_mapping,
            symbol_name="sprite_synth",
        )
        if os.path.exists(tmp_png):
            os.remove(tmp_png)

        check("Synthetic image conversion", "SPRITE_BEGIN sprite_synth, 10, 10, 1" in code)
        check("Synthetic frame pixels count", len(fpx[0]) == 100)
    else:
        print("SKIP: Pillow-dependent image tests (Pillow not installed in this environment)")

    print(f"\nUnit Test Results: {passed}/{total} passed.")
    if passed == total:
        print("ALL CONVERTER TESTS PASSED!")
        return 0
    else:
        print("SOME CONVERTER TESTS FAILED!")
        return 1


def main():
    parser = argparse.ArgumentParser(
        description="Pawmodoro v3 PNG-to-Sprite Converter (PRD_V3 §4.2, §sprites)"
    )
    parser.add_argument("image", nargs="?", help="Input PNG image crop path")
    parser.add_argument("--input", "-i", dest="input_opt", help="Input PNG image path (alias)")
    parser.add_argument("--width", "-w", type=int, default=14, help="Target width in terminal cells")
    parser.add_argument("--height", type=int, default=7, help="Target height in terminal cells (height_pixels = 2 * height)")
    parser.add_argument("--height-pixels", type=int, default=None, help="Explicit height in pixel rows (must be even)")
    parser.add_argument("--mapping", "-m", help="Path to slot mapping JSON file")
    parser.add_argument("--name", "-n", default="sprite_test", help="NASM symbol name")
    parser.add_argument("--output", "-o", help="Output NASM file path (default: stdout)")
    parser.add_argument("--preview", "-p", help="Output PNG preview file path")
    parser.add_argument("--frames", "-f", type=int, default=1, help="Number of animation frames in strip")
    parser.add_argument("--direction", "-d", choices=["horizontal", "vertical"], default="horizontal", help="Strip slicing direction")
    parser.add_argument("--bg", default="#1A1A1A", help="Preview background hex color (#RRGGBB)")
    parser.add_argument("--ascii-fallback", help="Explicit ASCII art fallback string")
    parser.add_argument("--preview-ascii", action="store_true", help="Print ASCII preview to stdout")
    parser.add_argument("--test", action="store_true", help="Run converter unit test suite")

    args = parser.parse_args()

    if args.test:
        sys.exit(run_unit_tests())

    input_path = args.input_opt or args.image
    if not input_path:
        parser.print_help()
        sys.exit(1)

    if not args.mapping:
        sys.stderr.write("Error: --mapping <file.json> is required.\n")
        sys.exit(1)

    height_cells = args.height
    if args.height_pixels is not None:
        if args.height_pixels % 2 != 0:
            sys.stderr.write("Error: --height-pixels must be an even integer.\n")
            sys.exit(1)
        height_cells = args.height_pixels // 2

    with open(args.mapping, "r", encoding="utf-8") as f:
        mapping_data = json.load(f)

    try:
        nasm_code, frames_px, ref_rgbs, ascii_lines = convert_image(
            input_path=input_path,
            width_cells=args.width,
            height_cells=height_cells,
            mapping_data=mapping_data,
            symbol_name=args.name,
            frames=args.frames,
            direction=args.direction,
            ascii_custom=args.ascii_fallback,
        )
    except Exception as e:
        sys.stderr.write(f"Conversion Error: {e}\n")
        sys.exit(1)

    # Output NASM code
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(nasm_code)
        print(f"Generated NASM sprite: {args.output}")
    else:
        print(nasm_code)

    # ASCII Preview
    if args.preview_ascii or not args.output:
        print("\n--- ASCII Fallback Preview ---")
        for line in ascii_lines:
            print(f"|{line}|")
        print("------------------------------\n")

    # PNG Preview
    if args.preview:
        # Parse hex bg
        bg_hex = args.bg.lstrip("#")
        bg_rgb = tuple(int(bg_hex[i:i+2], 16) for i in (0, 2, 4))
        img = render_png_preview(
            width_cells=args.width,
            height_pixels=height_cells * 2,
            frames_pixels=frames_px,
            reference_rgbs=ref_rgbs,
            bg_rgb=bg_rgb,
        )
        img.save(args.preview)
        print(f"Saved PNG preview: {args.preview}")


if __name__ == "__main__":
    main()
