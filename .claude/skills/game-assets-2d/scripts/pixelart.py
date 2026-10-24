#!/usr/bin/env python3
"""Pixel art from text grids, and palette quantization of existing images.

GRID FORMAT (one file, any number of frames)

    # comment
    legend:
    . = transparent
    k = ink            # palette name from the profile ...
    y = #f2c94c        # ... or a hex color
    ---
    ..kkkk..
    .kyyyyk.
    ..kkkk..
    ===               # frame separator (optional, for animations)
    ..kkkk..
    ...

All frames must have the same size. Rows shorter than the widest are padded
with transparent.

COMMANDS
  render   grid -> PNG (single image, horizontal strip, or one file per frame)
  quantize image -> image snapped to the palette (alpha thresholded)
  grid     image -> text grid with legend (to hand-edit converted art)

Examples
  pixelart.py render hero.txt --profile art_profile.yaml -o hero.png --scale 4
  pixelart.py render walk.txt --profile art_profile.yaml -o out/walk --frames-dir
  pixelart.py quantize rendered.png --profile art_profile.yaml -o snapped.png
  pixelart.py grid snapped.png --profile art_profile.yaml -o hero.txt
"""
from __future__ import annotations

import argparse
import string
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import die, load_palette, load_profile, nearest, resolve_color  # noqa: E402

TRANSPARENT = (0, 0, 0, 0)


def parse_grid(text: str, palette: dict):
    legend, frames, cur = {}, [], []
    mode = "head"
    for raw in text.splitlines():
        line = raw.rstrip("\n")
        stripped = line.strip()
        if mode != "grid":
            if not stripped or stripped.startswith("#"):
                continue
            if stripped.lower() == "legend:":
                mode = "legend"
                continue
            if stripped == "---":
                mode = "grid"
                continue
            if mode == "legend":
                ch, sep, val = stripped.partition("=")
                if not sep or not val.strip():
                    die(f"bad legend line: {stripped!r}")
                ch, val = ch.strip(), val.strip().split()[0]  # first token; rest may be a comment
                if len(ch) != 1:
                    die(f"legend key must be one character: {ch!r}")
                legend[ch] = TRANSPARENT if val.lower() in ("transparent", "none") else resolve_color(val, palette)
            continue
        if stripped == "===":
            frames.append(cur)
            cur = []
            continue
        if stripped == "" and not cur:
            continue
        cur.append(line.rstrip())
    if cur:
        frames.append(cur)
    if not frames:
        die("no grid found (did you put '---' after the legend?)")
    w = max(len(r) for f in frames for r in f)
    h = max(len(f) for f in frames)
    for f in frames:
        for r in f:
            for ch in r:
                if ch not in legend:
                    die(f"character {ch!r} not in legend")
    return legend, frames, w, h


def frame_image(rows, legend, w, h):
    from PIL import Image
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            px[x, y] = legend[ch]
    return img


def cmd_render(a, palette):
    from PIL import Image
    legend, frames, w, h = parse_grid(Path(a.grid).read_text(encoding="utf-8"), palette)
    imgs = [frame_image(f, legend, w, h) for f in frames]
    s = a.scale
    imgs = [im.resize((w * s, h * s), Image.NEAREST) for im in imgs]
    out = Path(a.out)
    if a.frames_dir:
        out.mkdir(parents=True, exist_ok=True)
        for i, im in enumerate(imgs):
            p = out / f"{out.name}_{i:02d}.png"
            im.save(p)
            print(p)
        return
    strip = Image.new("RGBA", (w * s * len(imgs) + a.gap * (len(imgs) - 1), h * s), TRANSPARENT)
    for i, im in enumerate(imgs):
        strip.paste(im, (i * (w * s + a.gap), 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    strip.save(out)
    print(f"{out}  ({len(imgs)} frame(s), {w}x{h} px each, scale {s})")


def quantize_image(img, palette, alpha_threshold):
    pal_rgb = [c[:3] for c in palette.values()]
    img = img.convert("RGBA")
    px = img.load()
    cache = {}
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, al = px[x, y]
            if al < alpha_threshold:
                px[x, y] = TRANSPARENT
                continue
            key = (r, g, b)
            if key not in cache:
                cache[key] = nearest(key, pal_rgb)[0]
            px[x, y] = (*cache[key], 255)
    return img


def cmd_quantize(a, palette):
    from PIL import Image
    if not palette:
        die("quantize needs a palette (--profile)")
    img = Image.open(a.image)
    if a.size:
        img = img.convert("RGBA").resize((a.size[0], a.size[1]), Image.BOX)
    q = quantize_image(img, palette, a.alpha_threshold)
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    q.save(a.out)
    print(a.out)


def cmd_grid(a, palette):
    from PIL import Image
    if not palette:
        die("grid needs a palette (--profile)")
    img = quantize_image(Image.open(a.image), palette, a.alpha_threshold)
    rgb_to_name = {v[:3]: k for k, v in palette.items()}
    chars = iter([c for c in string.ascii_lowercase + string.ascii_uppercase + string.digits if c != "."])
    used = {}
    rows = []
    px = img.load()
    for y in range(img.height):
        row = ""
        for x in range(img.width):
            c = px[x, y]
            if c[3] == 0:
                row += "."
                continue
            name = rgb_to_name[c[:3]]
            if name not in used:
                used[name] = next(chars)
            row += used[name]
        rows.append(row)
    lines = ["legend:", ". = transparent"] + [f"{ch} = {name}" for name, ch in used.items()] + ["---"] + rows
    Path(a.out).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(a.out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("render")
    r.add_argument("grid")
    r.add_argument("-o", "--out", required=True)
    r.add_argument("--scale", type=int, default=1)
    r.add_argument("--gap", type=int, default=0, help="px between frames in a strip")
    r.add_argument("--frames-dir", action="store_true", help="write one PNG per frame into --out dir")
    q = sub.add_parser("quantize")
    q.add_argument("image")
    q.add_argument("-o", "--out", required=True)
    q.add_argument("--size", nargs=2, type=int, help="downscale to W H first (box filter)")
    g = sub.add_parser("grid")
    g.add_argument("image")
    g.add_argument("-o", "--out", required=True)
    for p in (r, q, g):
        p.add_argument("--profile")
    for p in (q, g):
        p.add_argument("--alpha-threshold", type=int, default=128)
    a = ap.parse_args()
    palette = load_palette(load_profile(a.profile))
    {"render": cmd_render, "quantize": cmd_quantize, "grid": cmd_grid}[a.cmd](a, palette)


if __name__ == "__main__":
    main()
