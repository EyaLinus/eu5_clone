"""Classifies every province's terrain for movement and battles: writes data/terrain.json.

Mountains and hills come from the same ridge lines that paint the map (tools/art/map_terrain.py),
so what the player sees matches the rules. Run after changing the map or the ridges:
    python3 tools/gen_terrain.py
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
from map_terrain import RANGES, SCALE, LAT0, LON0, COSLAT, proj  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "data", "terrain.json")

# dry lands; everything else south of DESERT_LAT is desert too
DESERT_KEYS = {"barqa", "marmarica", "sous", "damascus", "aleppo", "gabes", "tripoli"}
DESERT_LAT = 31.2
FOREST_LAT = 57.0  # northern taiga and Baltic woods
MARSH_KEYS = {"holland"}
# river plains next to big ridges: the ridge glow overstates them
HILL_KEYS = {"milan", "barcelona", "florence"}


def lonlat(x, y):
    return x / (SCALE * COSLAT) + LON0, LAT0 - y / SCALE


def main():
    m = json.load(open(os.path.join(ROOT, "data", "map.json")))
    W, H = int(math.ceil(m["size"][0])), int(math.ceil(m["size"][1]))
    ridge = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(ridge)
    for strength, pts in RANGES:
        rd.line([proj(*p) for p in pts], fill=int(255 * strength), width=int(10 + 14 * strength), joint="curve")
    mount = ndimage.gaussian_filter(np.asarray(ridge, np.float32) / 255.0, 6) * 2.2
    out = {}
    for p in m["provinces"]:
        mask = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(mask)
        for poly in p["polys"]:
            d.polygon([tuple(c) for c in poly], fill=255)
        sel = np.asarray(mask) > 0
        relief = float(mount[sel].mean()) if sel.any() else 0.0
        peak = float(np.percentile(mount[sel], 90)) if sel.any() else 0.0
        lon, lat = lonlat(*p["center"])
        if (relief > 0.55 or peak > 1.1) and p["key"] not in HILL_KEYS:
            t = "mountains"
        elif relief > 0.2 or peak > 0.6 or p["key"] in HILL_KEYS:
            t = "hills"
        elif p["key"] in DESERT_KEYS or lat < DESERT_LAT:
            t = "desert"
        elif p["key"] in MARSH_KEYS:
            t = "marsh"
        elif lat > FOREST_LAT:
            t = "forest"
        else:
            t = "plains"
        out[p["key"]] = t
    with open(OUT, "w") as f:
        f.write("{\n" + ",\n".join('"%s": "%s"' % (k, v) for k, v in out.items()) + "\n}\n")
    counts = {}
    for v in out.values():
        counts[v] = counts.get(v, 0) + 1
    print(OUT, counts)


if __name__ == "__main__":
    main()
