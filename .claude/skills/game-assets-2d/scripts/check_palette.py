#!/usr/bin/env python3
"""Check that assets only use palette colors.

SVG: every color literal (#hex, rgb(), common named colors) must be in the palette.
PNG: opaque pixels are compared to the palette. Blends between two palette colors
     (anti-aliased edges) count as on-palette; up to --max-off percent of the rest may
     be off (tolerance --tol in RGB distance). Use --strict for pixel art (exact, 0%).

Exit code 1 if any file fails – usable in CI.

Examples
  check_palette.py assets/src/**/*.svg --profile art_profile.yaml
  check_palette.py out/sprites/*.png --profile art_profile.yaml --strict
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import die, hex_to_rgba, load_palette, load_profile, nearest, rgba_to_hex  # noqa: E402

HEX = re.compile(r"#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")
RGB = re.compile(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)")
NAMED = re.compile(r'(?:fill|stroke|stop-color|color)\s*[:=]\s*["\']?\s*(red|green|blue|black|white|gray|grey|'
                   r'yellow|orange|purple|brown|pink|cyan|magenta)\b', re.I)
ALLOWED_KEYWORDS = {"none", "transparent", "currentcolor", "inherit"}


def check_svg(path, pal_rgb, tol):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    bad = {}
    for m in HEX.finditer(text):
        c = hex_to_rgba(m.group(0))[:3]
        _, d = nearest(c, pal_rgb)
        if d > tol:
            bad[m.group(0).lower()] = bad.get(m.group(0).lower(), 0) + 1
    for m in RGB.finditer(text):
        c = tuple(int(g) for g in m.groups())
        _, d = nearest(c, pal_rgb)
        if d > tol:
            k = rgba_to_hex(c)
            bad[k] = bad.get(k, 0) + 1
    named = sorted({m.group(1).lower() for m in NAMED.finditer(text)})
    return bad, named


def blend_distance(c, pal_rgb):
    """Distance from c to the nearest straight blend between two palette colors
    (anti-aliased edges are such blends)."""
    best = 1e18
    for i, p in enumerate(pal_rgb):
        for q in pal_rgb[i + 1:]:
            d = [q[k] - p[k] for k in range(3)]
            dd = sum(x * x for x in d)
            if dd == 0:
                continue
            t = max(0.0, min(1.0, sum((c[k] - p[k]) * d[k] for k in range(3)) / dd))
            proj = [p[k] + t * d[k] for k in range(3)]
            best = min(best, sum((c[k] - proj[k]) ** 2 for k in range(3)))
    return best ** 0.5


def check_png(path, pal_rgb, tol, strict, blends=True):
    from PIL import Image
    im = Image.open(path).convert("RGBA")
    colors = im.getcolors(maxcolors=im.width * im.height)
    total = off = 0
    bad = {}
    cache = {}
    for count, (r, g, b, a) in colors:
        if a < (255 if strict else 250):
            if strict and a not in (0, 255):
                bad["semi-transparent"] = bad.get("semi-transparent", 0) + count
            continue
        total += count
        key = (r, g, b)
        if key not in cache:
            d = nearest(key, pal_rgb)[1]
            if not strict and blends and d > tol:
                d = blend_distance(key, pal_rgb)
            cache[key] = d
        if cache[key] > (0 if strict else tol):
            off += count
            k = rgba_to_hex(key)
            bad[k] = bad.get(k, 0) + count
    return total, off, bad


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+")
    ap.add_argument("--profile", required=True)
    ap.add_argument("--tol", type=float, default=3.0, help="RGB distance counted as same color")
    ap.add_argument("--max-off", type=float, default=2.0, help="PNG: allowed %% off-palette opaque pixels")
    ap.add_argument("--strict", action="store_true", help="exact palette colors only, no AA (pixel art)")
    ap.add_argument("--no-blends", action="store_true",
                    help="PNG: don't accept blends between two palette colors (anti-aliasing)")
    ap.add_argument("--show", type=int, default=6, help="list up to N offending colors per file")
    a = ap.parse_args()

    pal = load_palette(load_profile(a.profile))
    if not pal:
        die("profile has no palette")
    pal_rgb = [c[:3] for c in pal.values()]
    failed = 0
    for f in a.files:
        p = Path(f)
        ext = p.suffix.lower()
        if ext == ".svg":
            bad, named = check_svg(p, pal_rgb, a.tol)
            ok = not bad and not named
            msg = "ok" if ok else "FAIL"
            if bad:
                top = sorted(bad.items(), key=lambda kv: -kv[1])[: a.show]
                msg += "  off-palette: " + ", ".join(
                    f"{k}(×{n}, nearest {rgba_to_hex(nearest(hex_to_rgba(k)[:3], pal_rgb)[0])})" for k, n in top)
            if named:
                msg += "  named colors: " + ", ".join(named)
        elif ext in (".png", ".webp"):
            from PIL import Image
            if not a.strict and max(Image.open(p).size) < 64:
                print(f"{p}: skipped  (<64 px: anti-aliasing mixes 3+ colors; check the source or a >=128 px render)")
                continue
            total, off, bad = check_png(p, pal_rgb, a.tol, a.strict, not a.no_blends)
            pct = 100 * off / total if total else 0
            ok = (pct == 0 and "semi-transparent" not in bad) if a.strict else pct <= a.max_off
            msg = f"{'ok' if ok else 'FAIL'}  {pct:.1f}% off-palette opaque px"
            if not ok:
                top = sorted(bad.items(), key=lambda kv: -kv[1])[: a.show]
                msg += "  e.g. " + ", ".join(f"{k}({n}px)" for k, n in top)
        else:
            continue
        failed += 0 if ok else 1
        print(f"{p}: {msg}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
