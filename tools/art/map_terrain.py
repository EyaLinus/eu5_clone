"""Paints the map base texture assets/art/map/terrain.png from data/map.json.

Old-atlas look: deep-to-shallow sea with coastal ripple lines, parchment land with hillshade,
mountain ranges (real lon/lat polylines) as relief plus small peak glyphs, darker wasteland
outside the playable provinces. Colours come from the art_profile palette; noise only blends
between neighbouring ramp colours. Needs numpy, scipy, pillow, pyyaml.

    python3 tools/art/map_terrain.py   # writes assets/art/map/terrain.png and terrain_half.png
"""
import json
import math
import os
import sys

import numpy as np
import yaml
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "art", "map", "terrain.png")

# must match tools/gen_map.py
SCALE = 48.0
LON0, LAT0 = -11.0, 63.0
COSLAT = math.cos(math.radians(50))


def proj(lon, lat):
    return ((lon - LON0) * SCALE * COSLAT, (LAT0 - lat) * SCALE)


# rough ridge lines (lon, lat); height = relative strength
RANGES = [
    (1.0, [(5.6, 44.2), (6.9, 45.6), (7.8, 46.0), (9.0, 46.5), (10.6, 46.7), (12.4, 47.0), (14.0, 47.2), (15.6, 47.4)]),  # Alps
    (0.8, [(-1.8, 43.1), (0.0, 42.8), (1.5, 42.6), (2.8, 42.5)]),  # Pyrenees
    (0.75, [(17.4, 48.8), (19.5, 49.3), (21.5, 49.2), (23.5, 48.5), (24.8, 47.6), (25.6, 46.4), (25.4, 45.5), (24.0, 45.4), (22.6, 45.3), (22.2, 44.7)]),  # Carpathians
    (0.6, [(14.6, 45.4), (16.0, 44.4), (17.6, 43.6), (19.0, 42.8), (20.2, 42.2), (21.0, 41.4), (21.6, 40.2), (22.0, 39.2)]),  # Dinarides, Pindus
    (0.55, [(22.4, 43.3), (24.0, 42.9), (25.6, 42.8), (27.0, 42.7)]),  # Balkan mountains
    (0.55, [(8.4, 44.4), (10.4, 44.2), (12.4, 43.3), (13.6, 42.4), (14.8, 41.4), (15.8, 40.4), (16.2, 39.3)]),  # Apennines
    (0.5, [(-7.2, 43.0), (-5.6, 43.1), (-4.0, 43.1)]),  # Cantabrian
    (0.45, [(-6.4, 40.3), (-5.0, 40.4), (-3.6, 40.9)]),  # Sistema Central
    (0.5, [(-4.2, 37.1), (-3.0, 37.1), (-2.4, 37.2)]),  # Sierra Nevada
    (0.35, [(2.6, 45.6), (3.0, 45.0), (3.6, 44.4)]),  # Massif Central
    (0.4, [(12.3, 50.4), (13.6, 50.7), (15.4, 50.8), (16.6, 50.4), (17.4, 50.1)]),  # Ore, Sudetes
    (0.3, [(12.8, 49.4), (13.6, 48.9)]),  # Bohemian Forest
    (0.6, [(5.8, 58.8), (7.4, 60.4), (9.0, 61.6), (11.6, 62.4), (13.2, 63.0)]),  # Scandes
    (0.4, [(-5.6, 56.6), (-4.6, 57.2), (-3.8, 57.6)]),  # Highlands
    (0.35, [(-3.8, 52.0), (-3.6, 53.0)]),  # Cambrian
    (0.4, [(8.6, 40.0), (9.2, 40.6), (9.0, 42.2)]),  # Sardinia/Corsica
    (0.35, [(14.4, 37.8), (15.0, 37.7)]),  # Etna
]


def palette():
    prof = yaml.safe_load(open(os.path.join(ROOT, "art_profile.yaml")))
    return {k: np.array([int(v[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32) for k, v in prof["palette"].items()}


def fbm(h, w, rng, octaves=5, base=6):
    """Fractal value noise in [0,1] (not tileable; the map is one image)."""
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        f = base * 2 ** o
        grid = rng.random((int(h / w * f) + 3, f + 3)).astype(np.float32)
        layer = ndimage.zoom(grid, (h / (grid.shape[0] - 3), w / (grid.shape[1] - 3)), order=3)[:h, :w]
        out += amp * layer
        tot += amp
        amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-6)


def ramp(t, cols):
    """Piecewise-linear blend through palette colours, t in [0,1] (array)."""
    t = np.clip(t, 0, 1)[..., None]
    n = len(cols) - 1
    idx = np.minimum((t * n).astype(int), n - 1)
    f = t * n - idx
    a = np.stack(cols)[idx[..., 0]]
    b = np.stack(cols)[idx[..., 0] + 1]
    return a + (b - a) * f


def raster(polys, w, h, ss=1):
    im = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    for poly in polys:
        if len(poly) >= 3:
            d.polygon([(x * ss, y * ss) for x, y in poly], fill=255)
    if ss > 1:
        im = im.resize((w, h), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


def main():
    m = json.load(open(os.path.join(ROOT, "data", "map.json")))
    W, H = int(math.ceil(m["size"][0])), int(math.ceil(m["size"][1]))
    P = palette()
    rng = np.random.default_rng(1444)

    prov = raster([poly for p in m["provinces"] for poly in p["polys"]], W, H, 2)
    waste = raster(m["background"], W, H, 2)
    # close hairline gaps between neighbouring province polygons
    closed = ndimage.binary_closing(prov > 0.5, iterations=2)
    prov = np.maximum(prov, closed.astype(np.float32))
    land = np.clip(prov + waste, 0, 1)
    land_bin = land > 0.5

    # ---- sea
    # distance from the coast, from a 2x supersampled mask and smoothed so ripple lines stay round
    big = np.asarray(Image.fromarray((land * 255).astype(np.uint8)).resize((W * 2, H * 2), Image.BILINEAR)) > 127
    dist = ndimage.distance_transform_edt(~big).astype(np.float32)
    dist = ndimage.gaussian_filter(dist, 2.0)
    dist = np.asarray(Image.fromarray(dist).resize((W, H), Image.BILINEAR)) / 2.0
    n_sea = fbm(H, W, rng, 4, 5)
    t = np.clip(dist / 90.0, 0, 1) ** 0.6 + (n_sea - 0.5) * 0.25
    sea = ramp(1 - t, [P["sea_deep"], P["sea"], P["sea_shallow"]])
    # coastal ripple lines, fading outwards (classic atlas hatching)
    for k, a in ((5.0, 0.35), (10.0, 0.22), (16.0, 0.12)):
        line = np.clip(1.0 - np.abs(dist - k) / 0.9, 0, 1) * a
        sea = sea + (P["foam"] - sea) * line[..., None]
    foam = np.clip(1.0 - (dist - 0.5) / 2.0, 0, 1) * 0.5
    sea = sea + (P["foam"] - sea) * foam[..., None]

    # ---- relief
    mount = np.zeros((H, W), np.float32)
    ridge = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(ridge)
    peaks = []
    for strength, pts in RANGES:
        xy = [proj(*p) for p in pts]
        rd.line(xy, fill=int(255 * strength), width=int(10 + 14 * strength), joint="curve")
        for (x0, y0), (x1, y1) in zip(xy, xy[1:]):
            seg = math.hypot(x1 - x0, y1 - y0)
            nx, ny = -(y1 - y0) / max(seg, 1), (x1 - x0) / max(seg, 1)
            rows = (-1, 1) if strength >= 0.6 else (0,)
            for i in range(int(seg / 11) + 1):
                f = i * 11 / max(seg, 1)
                for row in rows:
                    jitter = rng.normal(0, 2.5, 2)
                    off = row * 6.0 + (3.0 if i % 2 else 0.0) * row
                    peaks.append((x0 + (x1 - x0) * f + nx * off + jitter[0], y0 + (y1 - y0) * f + ny * off + jitter[1], strength))
    mount = ndimage.gaussian_filter(np.asarray(ridge, np.float32) / 255.0, 6) * 2.2
    hills = fbm(H, W, rng, 6, 8)
    height = hills * 0.9 + np.clip(mount, 0, 1.4) * (0.6 + hills * 0.6)
    gy, gx = np.gradient(ndimage.gaussian_filter(height, 1.2))
    shade = np.clip(0.55 - (gx + gy) * 22.0, 0, 1)  # light from the top-left

    lowland = ramp(shade, [P["land_dark"], P["land"], P["land_light"]])
    rock_t = np.clip(shade * 0.8 + np.clip(mount - 0.9, 0, 1) * 0.6, 0, 1)
    rocky = ramp(rock_t, [P["rock_dark"], P["rock"], P["rock_light"], P["snow"]])
    rock_w = np.clip((mount - 0.25) * 1.4, 0, 1)[..., None]
    landc = lowland + (rocky - lowland) * rock_w
    wastec = ramp(shade, [P["waste_dark"], P["waste"]])
    wastec = wastec + (rocky * 0.7 + wastec * 0.3 - wastec) * rock_w * 0.6

    img = sea
    img = img + (wastec - img) * waste[..., None]
    img = img + (landc - img) * prov[..., None]
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")

    # ---- peak glyphs (stamped, land only)
    d = ImageDraw.Draw(out)
    for x, y, s in sorted(peaks, key=lambda p: p[1]):
        xi, yi = int(x), int(y)
        if not (0 <= xi < W and 0 <= yi < H) or not land_bin[yi, xi]:
            continue
        r = 4.5 + 3.5 * s
        top = (x, y - r * 1.25)
        left, right, mid = (x - r, y + r * 0.45), (x + r, y + r * 0.45), (x + r * 0.15, y + r * 0.45)
        d.polygon([top, left, mid], fill=tuple(int(c) for c in P["rock_light"]))
        d.polygon([top, mid, right], fill=tuple(int(c) for c in P["rock_dark"]))
        if s >= 0.7:  # snow cap
            cap = r * 0.45
            d.polygon([top, (x - cap * 0.8, y - r * 1.25 + cap), (x + cap * 0.8, y - r * 1.25 + cap)], fill=tuple(int(c) for c in P["snow"]))
        d.line([left, top, right], fill=tuple(int(c) for c in P["rock_dark"]), width=1)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT, optimize=True)
    # half size for zoomed-out views (no mipmaps: .import files are not versioned)
    half = OUT.replace("terrain.png", "terrain_half.png")
    out.resize((W // 2, H // 2), Image.LANCZOS).save(half, optimize=True)
    for f in (OUT, half):
        print(f, os.path.getsize(f) // 1024, "KiB")


if __name__ == "__main__":
    main()
