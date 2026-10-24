#!/usr/bin/env python3
"""Review sheet: each image large (on checkerboard) plus at real display size
on a light and a dark background, labeled. Read the output PNG to review.

Examples
  contact_sheet.py build/preview/*.png anchors/*.png -o build/review.png --display 24 --label
  contact_sheet.py frames/*.png -o build/anim.png --cell 96 --pixel   # nearest-neighbor scaling
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import die, load_palette, load_profile  # noqa: E402


def checker(w, h, s=8):
    from PIL import Image, ImageDraw
    im = Image.new("RGBA", (w, h), (200, 200, 200, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            if (x // s + y // s) % 2:
                d.rectangle([x, y, x + s - 1, y + s - 1], fill=(235, 235, 235, 255))
    return im


def fit(im, box, pixel):
    from PIL import Image
    scale = min(box / im.width, box / im.height)
    if pixel and scale >= 1:
        scale = max(1, int(scale))
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    return im.resize((w, h), Image.NEAREST if pixel else Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("images", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--cell", type=int, default=128, help="large preview box px")
    ap.add_argument("--display", type=int, default=32, help="real display size px (smallest use)")
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--label", action="store_true")
    ap.add_argument("--pixel", action="store_true", help="nearest-neighbor scaling (pixel art)")
    ap.add_argument("--light", default="#f4f1ea")
    ap.add_argument("--dark", default="#22222a")
    ap.add_argument("--profile", help="use palette 'paper'/'ink' (if present) as backgrounds")
    a = ap.parse_args()

    from PIL import Image, ImageDraw, ImageFont
    light, dark = a.light, a.dark
    if a.profile:
        pal = load_palette(load_profile(a.profile))
        light = "#%02x%02x%02x" % pal["paper"][:3] if "paper" in pal else light
        dark = "#%02x%02x%02x" % pal["ink"][:3] if "ink" in pal else dark
    paths = [Path(p) for p in a.images if Path(p).suffix.lower() in (".png", ".webp", ".jpg", ".jpeg")]
    if not paths:
        die("no images")
    cols = a.cols or min(len(paths), 6)
    rows = (len(paths) + cols - 1) // cols
    small_row = a.display + 8
    label_h = 14 if a.label else 0
    cw, ch = a.cell + 8, a.cell + 8 + small_row + label_h
    sheet = Image.new("RGBA", (cols * cw + 8, rows * ch + 8), (255, 255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.load_default(size=11)
    except TypeError:
        font = ImageFont.load_default()
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA")
        cx, cy = 8 + (i % cols) * cw, 8 + (i // cols) * ch
        bg = checker(a.cell, a.cell)
        big = fit(im, a.cell, a.pixel)
        bg.alpha_composite(big, ((a.cell - big.width) // 2, (a.cell - big.height) // 2))
        sheet.paste(bg, (cx, cy))
        small = fit(im, a.display, a.pixel)
        half = a.cell // 2
        for j, col in enumerate((light, dark)):
            tile = Image.new("RGBA", (half, small_row), col)
            tile.alpha_composite(small, ((half - small.width) // 2, (small_row - small.height) // 2))
            sheet.paste(tile, (cx + j * half, cy + a.cell + 2))
        if a.label:
            name = p.stem if len(p.stem) <= 20 else p.stem[:19] + "…"
            draw.text((cx, cy + a.cell + 2 + small_row), f"{name} {im.width}x{im.height}", fill=(40, 40, 40), font=font)
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(out)
    print(out)


if __name__ == "__main__":
    main()
