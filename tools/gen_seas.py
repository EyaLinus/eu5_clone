"""Splits the water of the map into sea regions and lists their coastal provinces: writes data/seas.json.

Each sea grows from a few seed points (lon, lat) over the water pixels (nearest seed wins);
a coastal province (data/coastal.json) borders every sea that touches it. Sea crossings
(data/straits.json) belong to the sea at their midpoint. Run after changing the map:
    python3 tools/gen_seas.py
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
from map_terrain import proj  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "data", "seas.json")

# id, name, label position (lon, lat), seed points (lon, lat) in open water
SEAS = [
    ("north", "Nordsee", (3.0, 56.0), [(3.0, 56.0), (6.0, 54.5), (1.5, 58.5), (4.5, 59.5), (-1.0, 60.0)]),
    ("channel", "Ärmelkanal", (-2.6, 50.0), [(-2.0, 50.0), (0.5, 50.3), (-4.5, 49.6), (1.6, 51.0)]),
    ("irish", "Irische See", (-5.0, 53.8), [(-5.0, 53.8), (-4.8, 52.0), (-5.5, 55.0)]),
    ("atlantic", "Atlantik", (-10.5, 44.0), [(-10.5, 44.0), (-4.0, 45.5), (-11.0, 52.0), (-10.5, 38.0), (-10.0, 33.0), (-8.0, 57.5), (-7.0, 36.3)]),
    ("baltic", "Ostsee", (19.0, 56.5), [(19.0, 56.5), (14.0, 54.8), (20.0, 59.0), (25.0, 59.6), (21.0, 62.0), (11.2, 56.5), (23.0, 57.5)]),
    ("west_med", "Westliches Mittelmeer", (5.5, 39.5), [(5.5, 39.5), (2.0, 37.5), (-2.5, 36.2), (5.0, 42.5), (10.0, 39.5), (12.0, 40.5), (9.5, 43.5), (11.5, 37.5)]),
    ("adriatic", "Adria", (15.5, 42.8), [(15.5, 42.8), (13.0, 44.8), (18.0, 41.5)]),
    ("east_med", "Östliches Mittelmeer", (24.0, 34.0), [(18.5, 37.0), (24.0, 34.0), (30.0, 33.5), (33.5, 34.5), (19.0, 33.0), (15.0, 35.0), (35.0, 36.2)]),
    ("aegean", "Ägäis", (25.0, 38.5), [(25.0, 38.5), (25.5, 40.2), (28.0, 40.7), (26.5, 36.8)]),
    ("caspian", "Kaspisches Meer", (50.5, 42.0), [(50.5, 42.0), (51.0, 39.5), (50.0, 45.0)]),
    ("black", "Schwarzes Meer", (34.0, 43.3), [(34.0, 43.3), (30.5, 43.0), (38.0, 42.5), (35.5, 45.5), (40.5, 42.0), (31.5, 45.5)]),
]


def main():
    m = json.load(open(os.path.join(ROOT, "data", "map.json")))
    coastal = set(json.load(open(os.path.join(ROOT, "data", "coastal.json"))))
    W, H = int(math.ceil(m["size"][0])), int(math.ceil(m["size"][1]))
    land = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(land)
    for p in m["provinces"]:
        for poly in p["polys"]:
            d.polygon([tuple(c) for c in poly], fill=255)
    for poly in m["background"]:
        d.polygon([tuple(c) for c in poly], fill=255)
    water = np.asarray(land) == 0
    # nearest seed over water pixels
    seeds = []
    for i, s in enumerate(SEAS):
        for ll in s[3]:
            seeds.append((i, proj(*ll)))
    yy, xx = np.mgrid[0:H, 0:W]
    best = np.full((H, W), 1e12, np.float32)
    label = np.full((H, W), -1, np.int16)
    for i, (x, y) in seeds:
        dist = (xx - x) ** 2 + (yy - y) ** 2
        upd = dist < best
        best[upd] = dist[upd]
        label[upd] = i
    label[~water] = -1
    out = []
    members = {s[0]: [] for s in SEAS}
    for p in m["provinces"]:
        if p["key"] not in coastal:
            continue
        mask = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(mask)
        for poly in p["polys"]:
            md.polygon([tuple(c) for c in poly], fill=255)
        ring = ndimage.binary_dilation(np.asarray(mask) > 0, iterations=6)
        labs, counts = np.unique(label[ring & water], return_counts=True)
        tot = counts[labs >= 0].sum()
        for lab, c in zip(labs, counts):
            if lab >= 0 and c >= max(8, 0.12 * tot):
                members[SEAS[lab][0]].append(p["key"])
    centers = {p["key"]: p["center"] for p in m["provinces"]}
    straits = json.load(open(os.path.join(ROOT, "data", "straits.json")))
    strait_sea = {}
    for a, b in straits:
        x = (centers[a][0] + centers[b][0]) / 2
        y = (centers[a][1] + centers[b][1]) / 2
        # nearest water pixel's sea
        r = 0
        lab = -1
        while lab < 0 and r < 200:
            r += 4
            win = label[max(0, int(y) - r):int(y) + r, max(0, int(x) - r):int(x) + r]
            vals = win[win >= 0]
            if vals.size:
                lab = int(np.bincount(vals).argmax())
        strait_sea[a + "|" + b] = SEAS[lab][0]
    for sid, name, lbl, _ in SEAS:
        out.append({"id": sid, "name": name, "center": [round(v, 1) for v in proj(*lbl)], "provinces": sorted(members[sid])})
    with open(OUT, "w") as f:
        f.write('{"seas": [\n' + ",\n".join(json.dumps(s, ensure_ascii=False) for s in out) + '\n],\n"straits": '
                + json.dumps(strait_sea, ensure_ascii=False, indent=0) + "}\n")
    for s in out:
        print(s["id"], len(s["provinces"]), s["provinces"][:12])
    print(strait_sea)
    lone = [k for k in coastal if not any(k in s["provinces"] for s in out)]
    print("coastal without sea:", lone)


if __name__ == "__main__":
    main()
