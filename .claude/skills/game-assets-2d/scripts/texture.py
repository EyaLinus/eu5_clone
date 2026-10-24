#!/usr/bin/env python3
"""Seamless procedural textures mapped onto a palette ramp.

Periodic fractal value noise (tileable by construction) -> color ramp
-> optional posterize (flat/graphic look), grain, spots, vignette.

Examples
  # parchment
  texture.py -o paper.png --size 512 --ramp paper_dark paper paper_light \
      --profile art_profile.yaml --freq 4 --octaves 5 --grain 0.04 --spots 12
  # flat stylized grass, 3 hard color bands
  texture.py -o grass.png --size 256 --ramp "#3f6b2a" "#5c8c32" "#86b347" --posterize 3
  # water with stretched noise, checked for seams
  texture.py -o water.png --ramp deep sea shallow --profile p.yaml --stretch 3 1 --tile-preview

Store the exact command next to the output (e.g. paper.png.cmd) so it can be regenerated.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from _common import die, load_palette, load_profile, resolve_color  # noqa: E402


def periodic_value_noise(size, freq_x, freq_y, rng):
    """Value noise on a freq_x x freq_y lattice that wraps -> tileable."""
    lattice = rng.random((freq_y, freq_x))
    ys = np.linspace(0, freq_y, size, endpoint=False)
    xs = np.linspace(0, freq_x, size, endpoint=False)
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    ty = ys - y0
    tx = xs - x0
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    y1 = (y0 + 1) % freq_y
    x1 = (x0 + 1) % freq_x
    a = lattice[np.ix_(y0, x0)]
    b = lattice[np.ix_(y0, x1)]
    c = lattice[np.ix_(y1, x0)]
    d = lattice[np.ix_(y1, x1)]
    top = a + (b - a) * tx[None, :]
    bot = c + (d - c) * tx[None, :]
    return top + (bot - top) * ty[:, None]


def fbm(size, freq, octaves, persistence, stretch, rng):
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    fx, fy = max(1, round(freq * stretch[0])), max(1, round(freq * stretch[1]))
    for _ in range(octaves):
        total += amp * periodic_value_noise(size, fx, fy, rng)
        norm += amp
        amp *= persistence
        fx, fy = fx * 2, fy * 2
        if fx > size or fy > size:
            break
    total /= norm
    lo, hi = total.min(), total.max()
    return (total - lo) / (hi - lo + 1e-9)


def apply_ramp(v, colors, posterize):
    cols = np.array([c[:3] for c in colors], dtype=float)
    if posterize:
        idx = np.clip((v * posterize).astype(int), 0, posterize - 1)
        # map posterize bands onto ramp colors evenly
        ramp_pos = np.linspace(0, len(cols) - 1, posterize)
        band_cols = np.array([cols[int(round(p))] for p in ramp_pos])
        return band_cols[idx]
    pos = v * (len(cols) - 1)
    i0 = np.clip(np.floor(pos).astype(int), 0, len(cols) - 2) if len(cols) > 1 else np.zeros_like(pos, int)
    if len(cols) == 1:
        return np.broadcast_to(cols[0], v.shape + (3,)).copy()
    t = (pos - i0)[..., None]
    return cols[i0] * (1 - t) + cols[i0 + 1] * t


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--size", type=int, default=512)
    ap.add_argument("--ramp", nargs="+", required=True, help="palette names or hex, dark -> light")
    ap.add_argument("--profile")
    ap.add_argument("--freq", type=float, default=4, help="base lattice cells across the tile")
    ap.add_argument("--octaves", type=int, default=5)
    ap.add_argument("--persistence", type=float, default=0.5)
    ap.add_argument("--stretch", nargs=2, type=float, default=[1, 1], help="x y frequency multipliers")
    ap.add_argument("--contrast", type=float, default=1.0, help=">1 more contrast, <1 flatter")
    ap.add_argument("--posterize", type=int, default=0, help="N hard color bands (flat style)")
    ap.add_argument("--grain", type=float, default=0.0, help="per-pixel noise amount 0..0.2")
    ap.add_argument("--spots", type=int, default=0, help="number of soft darker spots (stains)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--tile-preview", action="store_true", help="also write <out>_tile2x2.png")
    a = ap.parse_args()

    from PIL import Image
    palette = load_palette(load_profile(a.profile))
    try:
        colors = [resolve_color(t, palette) for t in a.ramp]
    except ValueError as e:
        die(f"{e} (palette names need --profile)")
    rng = np.random.default_rng(a.seed)
    v = fbm(a.size, a.freq, a.octaves, a.persistence, a.stretch, rng)
    if a.contrast != 1.0:
        v = np.clip((v - 0.5) * a.contrast + 0.5, 0, 1)
    if a.spots:
        yy, xx = np.mgrid[0:a.size, 0:a.size] / a.size
        for _ in range(a.spots):
            cx, cy, r = rng.random(), rng.random(), 0.03 + rng.random() * 0.08
            dx = np.minimum(abs(xx - cx), 1 - abs(xx - cx))  # wrap-around distance -> stays tileable
            dy = np.minimum(abs(yy - cy), 1 - abs(yy - cy))
            d = np.sqrt(dx ** 2 + dy ** 2)
            v = v - 0.18 * np.clip(1 - d / r, 0, 1) ** 2
        v = np.clip(v, 0, 1)
    rgb = apply_ramp(v, colors, a.posterize)
    if a.grain:
        rgb = rgb + rng.normal(0, 255 * a.grain, rgb.shape[:2])[..., None]
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    out = Path(a.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print(out)
    if a.tile_preview:
        t = Image.new("RGB", (a.size * 2, a.size * 2))
        for ox in (0, a.size):
            for oy in (0, a.size):
                t.paste(img, (ox, oy))
        tp = out.with_name(out.stem + "_tile2x2.png")
        t.save(tp)
        print(tp)


if __name__ == "__main__":
    main()
