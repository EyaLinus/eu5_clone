#!/usr/bin/env python3
"""Pack PNG sprites into a texture atlas plus metadata.

Formats
  json-hash   TexturePacker JSON (hash)  – Phaser, PixiJS, Flame, many loaders
  json-array  TexturePacker JSON (array)
  libgdx      libGDX .atlas text file
  css         CSS sprite classes (web UI)
  all         every format above

Packing: MaxRects-lite shelf packing, largest height first. If everything
doesn't fit into --max-size, additional pages are created (name_0, name_1 ...).

Examples
  atlas.py out/sprites/*.png -o out/atlas/units --format json-hash
  atlas.py frames/*.png -o out/ui --padding 2 --pot --extrude 1 --format all
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import die  # noqa: E402


def next_pot(n):
    p = 1
    while p < n:
        p *= 2
    return p


def shelf_pack(items, max_size, pad):
    """items: list of (name, w, h). Returns list of pages: [(page_w, page_h, [(name,x,y,w,h)])]."""
    remaining = sorted(items, key=lambda i: (-i[2], -i[1]))
    pages = []
    while remaining:
        placed, rest = [], []
        x = y = shelf_h = 0
        used_w = 0
        for name, w, h in remaining:
            W, H = w + pad, h + pad
            if W > max_size or H > max_size:
                die(f"sprite {name} ({w}x{h}) larger than --max-size {max_size}")
            if x + W > max_size:
                x, y, shelf_h = 0, y + shelf_h, 0
            if y + H > max_size:
                rest.append((name, w, h))
                continue
            placed.append((name, x, y, w, h))
            x += W
            shelf_h = max(shelf_h, H)
            used_w = max(used_w, x)
        if not placed:
            die("could not place any sprite")
        used_h = max(py + ph + pad for _, _, py, _, ph in placed)
        pages.append((used_w, used_h, placed))
        remaining = rest
    return pages


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("images", nargs="+")
    ap.add_argument("-o", "--out", required=True, help="output path without extension")
    ap.add_argument("--format", default="json-hash", choices=["json-hash", "json-array", "libgdx", "css", "all"])
    ap.add_argument("--max-size", type=int, default=2048)
    ap.add_argument("--padding", type=int, default=2)
    ap.add_argument("--extrude", type=int, default=0, help="repeat edge pixels N px (prevents bleeding)")
    ap.add_argument("--pot", action="store_true", help="power-of-two page size")
    ap.add_argument("--trim-ext", action="store_true", help="frame names without .png")
    a = ap.parse_args()

    from PIL import Image
    imgs = {}
    for p in a.images:
        path = Path(p)
        if path.suffix.lower() != ".png":
            continue
        name = path.stem if a.trim_ext else path.name
        if name in imgs:
            die(f"duplicate sprite name {name}")
        imgs[name] = Image.open(path).convert("RGBA")
    if not imgs:
        die("no PNG inputs")

    ex = a.extrude
    pad = a.padding + 2 * ex
    items = [(n, im.width, im.height) for n, im in imgs.items()]
    pages = shelf_pack(items, a.max_size, pad)

    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    formats = ["json-hash", "json-array", "libgdx", "css"] if a.format == "all" else [a.format]
    libgdx_lines = []
    css_lines = []
    for pi, (pw, ph, placed) in enumerate(pages):
        if a.pot:
            pw, ph = next_pot(pw), next_pot(ph)
        page_name = out.name if len(pages) == 1 else f"{out.name}_{pi}"
        sheet = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        frames = {}
        for name, x, y, w, h in placed:
            im = imgs[name]
            fx, fy = x + ex, y + ex
            if ex:
                big = im.resize((w + 2 * ex, h + 2 * ex), Image.NEAREST)
                big.paste(im, (ex, ex))
                # edge extrusion: stretch border rows/cols
                for i in range(ex):
                    big.paste(im.crop((0, 0, w, 1)), (ex, i))
                    big.paste(im.crop((0, h - 1, w, h)), (ex, ex + h + i))
                    big.paste(big.crop((ex, 0, ex + 1, h + 2 * ex)), (i, 0))
                    big.paste(big.crop((ex + w - 1, 0, ex + w, h + 2 * ex)), (ex + w + i, 0))
                sheet.paste(big, (x, y))
            else:
                sheet.paste(im, (fx, fy))
            frames[name] = {"frame": {"x": fx, "y": fy, "w": w, "h": h}, "rotated": False, "trimmed": False,
                            "spriteSourceSize": {"x": 0, "y": 0, "w": w, "h": h},
                            "sourceSize": {"w": w, "h": h}}
        png = out.parent / f"{page_name}.png"
        sheet.save(png)
        print(png)
        meta = {"app": "game-assets-2d/atlas.py", "image": png.name, "format": "RGBA8888",
                "size": {"w": pw, "h": ph}, "scale": "1"}
        if "json-hash" in formats:
            p = out.parent / f"{page_name}.json"
            p.write_text(json.dumps({"frames": frames, "meta": meta}, indent=1))
            print(p)
        if "json-array" in formats:
            p = out.parent / (f"{page_name}.array.json" if "json-hash" in formats else f"{page_name}.json")
            arr = [{"filename": n, **f} for n, f in frames.items()]
            p.write_text(json.dumps({"frames": arr, "meta": meta}, indent=1))
            print(p)
        if "libgdx" in formats:
            libgdx_lines += ["", png.name, f"size: {pw},{ph}", "format: RGBA8888",
                             "filter: Linear,Linear", "repeat: none"]
            for n, f in frames.items():
                fr = f["frame"]
                libgdx_lines += [Path(n).stem, "  rotate: false", f"  xy: {fr['x']}, {fr['y']}",
                                 f"  size: {fr['w']}, {fr['h']}", f"  orig: {fr['w']}, {fr['h']}",
                                 "  offset: 0, 0", "  index: -1"]
        if "css" in formats:
            for n, f in frames.items():
                fr = f["frame"]
                css_lines.append(f".sprite-{Path(n).stem} {{ background: url({png.name}) -{fr['x']}px -{fr['y']}px; "
                                 f"width: {fr['w']}px; height: {fr['h']}px; }}")
    if libgdx_lines:
        p = out.parent / f"{out.name}.atlas"
        p.write_text("\n".join(libgdx_lines).lstrip() + "\n")
        print(p)
    if css_lines:
        p = out.parent / f"{out.name}.css"
        p.write_text("\n".join(css_lines) + "\n")
        print(p)
    print(f"{len(imgs)} sprites on {len(pages)} page(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
