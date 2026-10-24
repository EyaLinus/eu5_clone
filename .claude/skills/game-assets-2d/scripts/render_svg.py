#!/usr/bin/env python3
"""Render SVG files to PNG at fixed sizes or density scales.

Examples
  # previews at 128 and 32 px wide
  render_svg.py icon.svg -o build/preview --sizes 128 32
  # Android densities for a 24dp icon -> name_1x.png ... name_4x.png
  render_svg.py icon.svg -o out --base 24 --scales 1 1.5 2 3 4 --suffix-pattern "{name}_{scale}x"
  # Android drawable folders
  render_svg.py icon.svg -o res --base 24 --scales 1 1.5 2 3 4 \
      --suffix-pattern "drawable-{android}/{name}"
  # crisp, non-anti-aliased (province ID maps, pixel art prep)
  render_svg.py map.svg -o out --sizes 4096 --crisp

Backend: resvg (resvg-py), falls back to cairosvg.
Pattern fields: {name} {size} {width} {height} {scale} {android}
"""
from __future__ import annotations

import argparse
import io
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import die  # noqa: E402

ANDROID = {1: "mdpi", 1.5: "hdpi", 2: "xhdpi", 3: "xxhdpi", 4: "xxxhdpi", 0.75: "ldpi"}


def svg_aspect(svg_text: str) -> float:
    m = re.search(r'viewBox\s*=\s*["\']\s*([-\d.e]+)[\s,]+([-\d.e]+)[\s,]+([-\d.e]+)[\s,]+([-\d.e]+)', svg_text)
    if m:
        w, h = float(m.group(3)), float(m.group(4))
        if w > 0 and h > 0:
            return h / w
    mw = re.search(r'<svg[^>]*\swidth\s*=\s*["\']([\d.]+)', svg_text)
    mh = re.search(r'<svg[^>]*\sheight\s*=\s*["\']([\d.]+)', svg_text)
    if mw and mh:
        return float(mh.group(1)) / float(mw.group(1))
    return 1.0


def render(svg_text: str, width: int, height: int, crisp: bool, background: str | None,
           fonts: list[str], resources_dir: str | None) -> bytes:
    try:
        import resvg_py
        kw = dict(svg_string=svg_text, width=width, height=height,
                  shape_rendering="crisp_edges" if crisp else "geometric_precision")
        if background:
            kw["background"] = background
        if fonts:
            kw["font_files"] = fonts
        if resources_dir:
            kw["resources_dir"] = resources_dir
        return bytes(resvg_py.svg_to_bytes(**kw))
    except ImportError:
        pass
    try:
        import cairosvg
    except ImportError:
        die("neither resvg-py nor cairosvg installed: pip install resvg-py cairosvg")
    if crisp:
        print("warning: --crisp needs resvg; cairosvg output is anti-aliased", file=sys.stderr)
    return cairosvg.svg2png(bytestring=svg_text.encode(), output_width=width, output_height=height,
                            background_color=background, unsafe=False)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("svgs", nargs="+")
    ap.add_argument("-o", "--out", required=True, help="output directory")
    ap.add_argument("--sizes", nargs="*", type=int, default=[], help="output widths in px")
    ap.add_argument("--base", type=float, help="display width at 1x (for --scales)")
    ap.add_argument("--scales", nargs="*", type=float, default=[], help="density multipliers")
    ap.add_argument("--suffix-pattern", default=None,
                    help="output path pattern relative to --out, without extension")
    ap.add_argument("--crisp", action="store_true", help="no anti-aliasing")
    ap.add_argument("--background", help="CSS color, default transparent")
    ap.add_argument("--font", action="append", default=[], help="font file to load (repeatable)")
    ap.add_argument("--format", choices=["png", "webp"], default="png")
    a = ap.parse_args()

    jobs = []  # (width, scale)
    for s in a.sizes:
        jobs.append((s, None))
    if a.scales:
        if not a.base:
            die("--scales needs --base")
        for sc in a.scales:
            jobs.append((round(a.base * sc), sc))
    if not jobs:
        die("give --sizes and/or --base with --scales")

    pattern = a.suffix_pattern or ("{name}_{scale}x" if a.scales and not a.sizes else "{name}_{size}")
    out = Path(a.out)
    written = []
    for svg in a.svgs:
        p = Path(svg)
        if not p.exists():
            die(f"not found: {svg}")
        text = p.read_text(encoding="utf-8")
        aspect = svg_aspect(text)
        for width, scale in jobs:
            height = max(1, round(width * aspect))
            png = render(text, width, height, a.crisp, a.background, a.font, str(p.parent))
            sc_str = ("%g" % scale) if scale is not None else ""
            rel = pattern.format(name=p.stem, size=width, width=width, height=height,
                                 scale=sc_str, android=ANDROID.get(scale, sc_str or "nodpi"))
            dest = out / f"{rel}.{a.format}"
            dest.parent.mkdir(parents=True, exist_ok=True)
            if a.format == "png":
                dest.write_bytes(png)
            else:
                from PIL import Image
                Image.open(io.BytesIO(png)).save(dest, "WEBP", quality=92, method=6)
            written.append(dest)
    for w in written:
        print(w)


if __name__ == "__main__":
    main()
