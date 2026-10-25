"""Event picture scenes (128x64 pixel art, exported x4 = 512x256) for the event popup.

Every scene is composed from small palette-locked building blocks (sky bands, hills, buildings,
figures, banners, props) so ~35 motifs share one look. Run:

    python3 tools/art/event_scenes.py [motif ...]   # all motifs if none given

Output: assets/art/events/<motif>.png. Mapping events -> motifs: tools/art/event_motifs.py.
"""
import math
import os
import random
import sys

import yaml
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "art", "events")
W, H, SCALE = 128, 64, 4

PAL = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in yaml.safe_load(open(os.path.join(ROOT, "art_profile.yaml")))["palette"].items()}


class Scene:
    def __init__(self, seed=0):
        self.im = Image.new("RGB", (W, H), PAL["night"])
        self.d = ImageDraw.Draw(self.im)
        self.rng = random.Random(seed)

    # -- primitives (all aliased, palette names only)
    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((int(x), int(y)), PAL[c])

    def rect(self, x0, y0, x1, y1, c):
        self.d.rectangle([x0, y0, x1, y1], fill=PAL[c])

    def poly(self, pts, c):
        self.d.polygon(pts, fill=PAL[c])

    def line(self, pts, c, w=1):
        self.d.line(pts, fill=PAL[c], width=w)

    def ellipse(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0, y0, x1, y1], fill=PAL[c])

    # -- backgrounds
    def sky(self, bands):
        """bands: list of (colour, rows) from the top."""
        y = 0
        for c, n in bands:
            self.rect(0, y, W, y + n - 1, c)
            y += n
        if y < H:
            self.rect(0, y, W, H, bands[-1][0])

    def day(self):
        self.sky([("sky_dark", 6), ("sky", 10), ("sky_light", 30)])

    def dusk(self):
        self.sky([("night_light", 5), ("dusk_dark", 7), ("dusk", 8), ("dusk_light", 30)])

    def night(self):
        self.sky([("night_dark", 10), ("night", 14), ("night_light", 40)])
        for _ in range(26):
            x, y = self.rng.randrange(W), self.rng.randrange(22)
            self.px(x, y, "white" if self.rng.random() < 0.3 else "grey_light")

    def sun(self, x, y, r=5, c="gold_light"):
        self.ellipse(x - r, y - r, x + r, y + r, c)

    def moon(self, x, y, r=4, bg="night_dark"):
        self.ellipse(x - r, y - r, x + r, y + r, "paper")
        self.ellipse(x - r + 2, y - r - 1, x + r + 2, y + r - 1, bg)

    def clouds(self, n, y0, y1, c="white"):
        for _ in range(n):
            x, y = self.rng.randrange(-10, W), self.rng.randrange(y0, y1)
            w = self.rng.randrange(10, 22)
            self.rect(x, y, x + w, y + 1, c)
            self.rect(x + 3, y - 1, x + w - 4, y - 1, c)

    def hills(self, base, amp, c, light=None, freq=0.05, phase=0.0):
        pts = [(0, H)]
        for x in range(0, W + 1, 2):
            y = base - amp * (0.6 * math.sin(x * freq + phase) + 0.4 * math.sin(x * freq * 2.3 + phase * 1.7))
            pts.append((x, int(y)))
        pts.append((W, H))
        self.poly(pts, c)
        if light:  # sunlit rim on the top edge
            for (x0, y0), (x1, y1) in zip(pts[1:-2], pts[2:-1]):
                if y1 <= y0:
                    self.line([(x0, y0), (x1, y1)], light)

    def ground(self, y, c, c2=None):
        self.rect(0, y, W, H, c)
        if c2:
            for _ in range(40):
                x, yy = self.rng.randrange(W), self.rng.randrange(y + 1, H)
                self.rect(x, yy, x + self.rng.randrange(1, 4), yy, c2)

    def mountains(self, base, peaks, c="rock", light="rock_light", snow="snow"):
        for x, h, w in peaks:
            top = base - h
            self.poly([(x - w, base), (x, top), (x + w, base)], c)
            self.poly([(x, top), (x - w, base), (x - w // 3, base)], light)
            if snow and h > 14:
                self.poly([(x, top), (x - 3, top + 4), (x + 3, top + 4)], snow)

    def sea(self, y, c="sea", c2="sea_shallow", foam="foam"):
        self.rect(0, y, W, H, c)
        for _ in range(30):
            x, yy = self.rng.randrange(W), self.rng.randrange(y + 1, H)
            self.rect(x, yy, x + self.rng.randrange(2, 7), yy, c2 if self.rng.random() < 0.7 else foam)

    # -- buildings
    def house(self, x, base, w=7, h=6, wall="paper", roof="red", door="wood_dark", shade="paper_dark"):
        self.rect(x, base - h, x + w - 1, base - 1, wall)
        self.rect(x + w - 1, base - h, x + w - 1, base - 1, shade)
        self.poly([(x - 1, base - h), (x + w // 2, base - h - w // 2 - 1), (x + w, base - h)], roof)
        self.line([(x + w // 2, base - h - w // 2 - 1), (x + w, base - h)], roof + "_dark" if roof + "_dark" in PAL else "ink")
        self.rect(x + w // 2 - 1, base - 3, x + w // 2, base - 1, door)

    def town(self, base, x0=0, x1=W, roofs=("red", "red", "wood"), lit=False, wall="paper", shade="paper_dark"):
        x = x0
        while x < x1:
            w = self.rng.randrange(6, 10)
            h = self.rng.randrange(5, 9)
            self.house(x, base, w, h, roof=self.rng.choice(roofs), wall=wall, shade=shade)
            if lit:
                self.px(x + 1, base - h + 2, "gold_light")
            x += w + self.rng.randrange(1, 3)

    def tower(self, x, base, w=8, h=20, c="grey", light="grey_light", dark="grey_dark", roof=None):
        self.rect(x, base - h, x + w - 1, base - 1, c)
        self.rect(x, base - h, x, base - 1, light)
        self.rect(x + w - 1, base - h, x + w - 1, base - 1, dark)
        if roof:
            self.poly([(x - 1, base - h), (x + w // 2, base - h - w), (x + w, base - h)], roof)
        else:
            for i in range(0, w, 2):
                self.rect(x + i, base - h - 2, x + i, base - h - 1, c)
        self.rect(x + w // 2 - 1, base - h + 5, x + w // 2, base - h + 7, "ink")

    def castle(self, x, base, scale=1.0, flag="red"):
        tw, th = int(7 * scale), int(22 * scale)
        ww, wh = int(26 * scale), int(13 * scale)
        self.rect(x + tw - 1, base - wh, x + tw + ww, base - 1, "grey")
        for i in range(0, ww, 3):
            self.rect(x + tw + i, base - wh - 2, x + tw + i + 1, base - wh - 1, "grey")
        self.rect(x + tw - 1, base - wh, x + tw + ww, base - wh, "grey_light")
        self.tower(x, base, tw, th)
        self.tower(x + tw + ww, base, tw, th)
        keep_x = x + tw + ww // 2 - int(5 * scale)
        self.tower(keep_x, base, int(10 * scale), int(30 * scale), roof="blue_dark")
        gx = x + tw + ww // 2 + int(5 * scale)
        self.rect(gx, base - int(6 * scale), gx + int(4 * scale), base - 1, "wood_dark")
        self.banner(keep_x + int(5 * scale), base - int(30 * scale) - int(10 * scale), flag)

    def cathedral(self, x, base, w=30, h=18):
        self.rect(x, base - h, x + w, base - 1, "paper_dark")
        self.rect(x, base - h, x + w, base - h, "paper")
        self.poly([(x - 1, base - h), (x + w // 2, base - h - 8), (x + w + 1, base - h)], "grey_dark")
        self.tower(x - 6, base, 8, h + 14, c="paper_dark", light="paper", dark="wood", roof="grey_dark")
        self.tower(x + w - 1, base, 8, h + 14, c="paper_dark", light="paper", dark="wood", roof="grey_dark")
        self.ellipse(x + w // 2 - 3, base - h + 2, x + w // 2 + 3, base - h + 8, "blue_light")
        self.px(x + w // 2, base - h + 5, "red")
        self.rect(x + w // 2 - 2, base - 7, x + w // 2 + 2, base - 1, "wood_dark")
        self.line([(x + w // 2, base - h - 13), (x + w // 2, base - h - 8)], "gold")
        self.line([(x + w // 2 - 2, base - h - 11), (x + w // 2 + 2, base - h - 11)], "gold")

    # -- figures (feet at y)
    def person(self, x, y, tunic="red", head="skin", hat=None, legs="wood_dark", weapon=None, facing=1):
        self.rect(x, y - 1, x, y, legs)
        self.rect(x + 2, y - 1, x + 2, y, legs)
        self.rect(x, y - 5, x + 2, y - 2, tunic)
        self.rect(x + 2, y - 5, x + 2, y - 2, tunic + "_dark" if tunic + "_dark" in PAL else tunic)
        self.rect(x, y - 7, x + 1, y - 6, head)
        self.px(x + 2, y - 7, head)
        if hat:
            self.rect(x, y - 8, x + 2, y - 8, hat)
            if hat in ("grey", "grey_light"):  # kettle helmet brim
                self.px(x - 1, y - 7, hat)
                self.px(x + 3, y - 7, hat)
        if weapon == "pike":
            px_ = x + 3 if facing > 0 else x - 1
            self.line([(px_, y - 1), (px_ + facing * 2, y - 14)], "wood_light")
            self.px(px_ + facing * 2, y - 15, "grey_light")
        elif weapon == "sword":
            self.line([(x + 3, y - 4), (x + 5, y - 8)], "grey_light")

    def crowd(self, x0, x1, y, tunics, **kw):
        x = x0
        while x < x1:
            self.person(x, y + self.rng.randrange(0, 2), tunic=self.rng.choice(tunics), **kw)
            x += self.rng.randrange(4, 6)

    def rider(self, x, y, tunic="red", horse="wood", facing=1):
        f = facing
        self.rect(x, y - 6, x + 8, y - 3, horse)
        self.rect(x + (8 if f > 0 else -2), y - 9, x + (10 if f > 0 else 0), y - 5, horse)
        for lx in (x, x + 2, x + 6, x + 8):
            self.rect(lx, y - 2, lx, y, horse + "_dark" if horse + "_dark" in PAL else horse)
        self.person(x + 3, y - 5, tunic=tunic, hat="grey")
        self.line([(x + 6, y - 9), (x + 6 + f * 8, y - 16)], "wood_light")
        self.px(x + 6 + f * 8, y - 17, "grey_light")

    def banner(self, x, y, c="red", h=10, emblem="gold"):
        self.line([(x, y), (x, y + h + 6)], "wood_dark")
        self.rect(x + 1, y, x + 6, y + 4, c)
        self.poly([(x + 1, y + 5), (x + 6, y + 5), (x + 6, y + 7)], c)
        self.px(x + 3, y + 2, emblem)
        self.px(x + 4, y + 2, emblem)

    def tent(self, x, base, c="paper", stripe="red"):
        self.poly([(x, base), (x + 6, base - 9), (x + 12, base)], c)
        self.line([(x + 6, base - 9), (x + 6, base)], stripe)
        self.poly([(x + 5, base), (x + 6, base - 4), (x + 7, base)], "wood_dark")
        self.line([(x + 6, base - 12), (x + 6, base - 9)], "wood_dark")
        self.px(x + 7, base - 12, stripe)

    def smoke(self, x, y, n=5, c="grey_light", c2="grey"):
        for i in range(n):
            r = 2 + i
            self.ellipse(x - r + i, y - i * 4 - r, x + r + i, y - i * 4 + r, c if i % 2 else c2)

    def fire(self, x, y, w=6):
        self.poly([(x, y), (x + w // 2, y - w - 2), (x + w, y)], "red")
        self.poly([(x + 1, y), (x + w // 2, y - w + 1), (x + w - 1, y)], "gold")
        self.poly([(x + 2, y), (x + w // 2, y - 2), (x + w - 2, y)], "gold_light")

    def ship(self, x, y, sail="paper", flag="red"):
        self.poly([(x, y - 4), (x + 22, y - 4), (x + 18, y), (x + 4, y)], "wood")
        self.rect(x + 2, y - 5, x + 20, y - 5, "wood_dark")
        self.line([(x + 11, y - 5), (x + 11, y - 24)], "wood_dark")
        self.line([(x + 5, y - 5), (x + 5, y - 17)], "wood_dark")
        self.poly([(x + 12, y - 22), (x + 20, y - 15), (x + 12, y - 7)], sail)
        self.rect(x + 6, y - 15, x + 10, y - 8, sail)
        self.rect(x + 12, y - 25, x + 15, y - 24, flag)

    # -- larger props and figures for close-up motifs
    def interior(self, wall="wood_dark", panel="wood", floor="grey", floor2="grey_dark", fy=50):
        self.sky([(wall, H)])
        for x in range(6, W, 24):
            self.rect(x, 4, x + 15, fy - 10, panel)
            self.rect(x, 4, x, fy - 10, panel + "_light" if panel + "_light" in PAL else panel)
        for y in range(fy, H):
            for x in range(0, W, 4):
                self.rect(x, y, x + 3, y, floor2 if ((x // 4) + (y // 2)) % 2 else floor)

    def window(self, x, y, w=8, h=18, c="sky_light"):
        self.rect(x - w // 2, y, x + w // 2, y + h, c)
        self.poly([(x - w // 2, y), (x, y - 4), (x + w // 2, y)], c)
        self.line([(x, y - 2), (x, y + h)], "wood_dark")
        self.line([(x - w // 2, y + h // 2), (x + w // 2, y + h // 2)], "wood_dark")

    def table(self, x0, x1, y, c="wood", cloth=None):
        self.rect(x0, y, x1, y + 2, c)
        self.rect(x0, y, x1, y, c + "_light" if c + "_light" in PAL else c)
        if cloth:
            self.rect(x0 + 1, y + 3, x1 - 1, y + 6, cloth)
        self.rect(x0 + 1, y + 3, x0 + 2, y + 12, c + "_dark" if c + "_dark" in PAL else c)
        self.rect(x1 - 2, y + 3, x1 - 1, y + 12, c + "_dark" if c + "_dark" in PAL else c)

    def candle(self, x, y):
        self.rect(x, y - 4, x + 1, y, "paper")
        self.px(x, y - 5, "gold")
        self.px(x, y - 6, "gold_light")

    def books(self, x, y, n=4):
        cols = ["red", "blue", "green", "wood", "purple"]
        for i in range(n):
            c = cols[(i + x) % len(cols)]
            h = 5 + (i * 3 + x) % 3
            self.rect(x + i * 2, y - h, x + i * 2 + 1, y, c)
            self.px(x + i * 2, y - h + 1, "gold")

    def scroll(self, x, y, w=14, h=9):
        self.rect(x, y, x + w, y + h, "paper")
        self.rect(x, y + h, x + w, y + h, "paper_dark")
        for i in range(2, h - 1, 2):
            self.line([(x + 2, y + i), (x + w - 3 - (i % 3), y + i)], "paper_dark")
        self.rect(x - 1, y - 1, x + w + 1, y, "wood_light")
        self.rect(x - 1, y + h + 1, x + w + 1, y + h + 2, "wood_light")

    def seal(self, x, y):
        self.ellipse(x - 2, y - 2, x + 2, y + 2, "red")
        self.px(x - 1, y - 1, "red_light")

    def cannon(self, x, y, facing=1):
        f = facing
        self.line([(x, y - 4), (x + f * 12, y - 7)], "grey_dark", 3)
        self.line([(x, y - 5), (x + f * 12, y - 8)], "grey")
        self.ellipse(x - 3, y - 4, x + 3, y + 2, "wood_dark")
        self.px(x, y - 1, "wood_light")

    def tree(self, x, base, h=12, c="green", dark="green_dark", trunk="wood_dark", bare=False):
        self.rect(x, base - h // 2, x + 1, base - 1, trunk)
        if bare:
            for dx, dy in ((-3, -h), (3, -h + 1), (-2, -h + 3), (4, -h + 4)):
                self.line([(x, base - h // 2), (x + dx, base + dy)], trunk)
            return
        self.ellipse(x - 4, base - h, x + 5, base - h // 2 + 1, c)
        self.ellipse(x - 1, base - h + 3, x + 5, base - h // 2 + 1, dark)

    def snowfall(self, n=60):
        for _ in range(n):
            self.px(self.rng.randrange(W), self.rng.randrange(H), "white")

    def figure(self, x, y, robe="purple", hat=None, beard=False, arm=None):
        """Large close-up figure (about 8 x 22 px), feet at y. arm: None, 'up', 'out'."""
        dark = robe + "_dark" if robe + "_dark" in PAL else robe
        light = robe + "_light" if robe + "_light" in PAL else robe
        self.poly([(x - 1, y), (x + 1, y - 14), (x + 7, y - 14), (x + 9, y)], robe)
        self.poly([(x + 5, y - 14), (x + 7, y - 14), (x + 9, y), (x + 6, y)], dark)
        self.line([(x + 1, y - 13), (x - 1, y)], light)
        self.rect(x + 2, y - 20, x + 6, y - 15, "skin")
        self.rect(x + 2, y - 20, x + 2, y - 15, "skin_light")
        self.rect(x + 6, y - 20, x + 6, y - 15, "skin_dark")
        self.px(x + 5, y - 18, "ink")
        if beard:
            self.rect(x + 2, y - 16, x + 6, y - 14, "grey_light")
        if hat == "crown":
            self.rect(x + 1, y - 22, x + 7, y - 21, "gold")
            for hx in (x + 1, x + 4, x + 7):
                self.px(hx, y - 23, "gold_light")
        elif hat == "mitre":
            self.poly([(x + 1, y - 21), (x + 4, y - 28), (x + 7, y - 21)], "paper")
            self.line([(x + 4, y - 27), (x + 4, y - 21)], "gold")
        elif hat == "cap":
            self.rect(x + 1, y - 23, x + 7, y - 21, robe)
        elif hat == "helmet":
            self.rect(x + 1, y - 22, x + 7, y - 20, "grey")
            self.rect(x, y - 20, x + 8, y - 20, "grey_light")
        elif hat:
            self.rect(x + 1, y - 22, x + 7, y - 21, hat)
        if arm == "up":
            self.line([(x + 7, y - 12), (x + 10, y - 20)], robe)
            self.px(x + 10, y - 21, "skin")
        elif arm == "out":
            self.line([(x + 7, y - 11), (x + 12, y - 11)], robe)
            self.px(x + 13, y - 11, "skin")

    def coins(self, x, y, n=6):
        for i in range(n):
            cx, cy = x + (i % 3) * 3, y - (i // 3) * 2
            self.rect(cx, cy, cx + 2, cy, "gold")
            self.px(cx, cy, "gold_light")
            self.rect(cx, cy + 1, cx + 2, cy + 1, "gold_dark")

    def sack(self, x, y, c="wood"):
        self.ellipse(x, y - 8, x + 8, y, c)
        self.rect(x + 3, y - 10, x + 5, y - 8, c + "_dark" if c + "_dark" in PAL else c)
        self.px(x + 2, y - 6, c + "_light" if c + "_light" in PAL else c)

    def comet(self, x, y, length=36):
        for i in range(length):
            c = "white" if i < 4 else ("sky_light" if i < 14 else "night_light")
            self.px(x + i, y - i // 3, c)
            if i < 20:
                self.px(x + i, y - i // 3 + 1, "sky_light" if i < 10 else "night_light")
        self.ellipse(x - 2, y - 1, x + 2, y + 2, "white")

    def grave(self, x, base, c="grey"):
        self.rect(x + 2, base - 9, x + 3, base, c)
        self.rect(x, base - 7, x + 5, base - 6, c)
        self.px(x + 2, base - 9, "grey_light")

    def yurt(self, x, base, c="paper_dark"):
        self.rect(x, base - 5, x + 12, base - 1, c)
        self.poly([(x - 1, base - 5), (x + 6, base - 10), (x + 13, base - 5)], "paper")
        self.rect(x + 5, base - 4, x + 7, base - 1, "red_dark")

    def frame(self):
        g = "gold"
        self.rect(0, 0, W - 1, 0, "ink")
        self.rect(0, H - 1, W - 1, H - 1, "ink")
        self.rect(0, 0, 0, H - 1, "ink")
        self.rect(W - 1, 0, W - 1, H - 1, "ink")
        self.rect(1, 1, W - 2, 1, "gold_light")
        self.rect(1, 1, 1, H - 2, "gold_light")
        self.rect(1, H - 2, W - 2, H - 2, "gold_dark")
        self.rect(W - 2, 1, W - 2, H - 2, "gold_dark")
        self.rect(2, 2, W - 3, 2, "ink")
        self.rect(2, H - 3, W - 3, H - 3, "ink")
        self.rect(2, 2, 2, H - 3, "ink")
        self.rect(W - 3, 2, W - 3, H - 3, "ink")
        for x, y in ((1, 1), (W - 2, 1), (1, H - 2), (W - 2, H - 2)):
            self.px(x, y, g)

    def save(self, name):
        self.frame()
        os.makedirs(OUT, exist_ok=True)
        self.im.resize((W * SCALE, H * SCALE), Image.NEAREST).save(os.path.join(OUT, name + ".png"), optimize=True)


# ---------------------------------------------------------------- motifs
MOTIFS = {}


def motif(fn):
    MOTIFS[fn.__name__] = fn
    return fn


@motif
def battle(s):
    s.dusk()
    s.sun(96, 20, 6, "dusk_light")
    s.clouds(4, 8, 18, "dusk")
    s.hills(40, 4, "green_dark", phase=1.0)
    s.ground(44, "green", "green_dark")
    s.smoke(60, 36, 5)
    s.smoke(78, 34, 4)
    for i, x in enumerate(range(8, 52, 5)):  # left host advancing
        s.person(x, 52 + (i % 2), tunic="blue", hat="grey", weapon="pike", facing=1)
    for i, x in enumerate(range(80, 122, 5)):  # right host
        s.person(x, 52 + (i % 2), tunic="red", hat="grey", weapon="pike", facing=-1)
    s.rider(50, 58, tunic="blue", facing=1)
    s.rider(68, 59, tunic="red", horse="wood_dark", facing=-1)
    s.banner(20, 22, "blue", emblem="gold")
    s.banner(104, 22, "red", emblem="gold")
    s.fire(64, 46, 5)


@motif
def plague(s):
    s.night()
    s.moon(100, 12)
    s.hills(38, 2, "night_dark")
    s.town(48, 4, 124, roofs=("wood_dark", "night_dark", "red_dark"), lit=True, wall="grey_dark", shade="night")
    s.ground(48, "wood_dark", "wood")
    for x in (20, 47, 80):  # painted crosses on doors
        s.line([(x, 41), (x, 46)], "red")
        s.line([(x - 2, 43), (x + 2, 43)], "red")
    # mist band over the street
    s.rect(0, 47, W, 48, "night_light")
    # cart with shrouded bodies
    s.rect(62, 50, 86, 54, "wood")
    s.rect(62, 50, 86, 50, "wood_light")
    s.rect(64, 46, 84, 49, "paper_dark")
    s.rect(66, 45, 74, 45, "paper")
    s.rect(76, 45, 82, 45, "paper")
    for cx in (66, 82):
        s.ellipse(cx - 3, 52, cx + 3, 58, "wood_dark")
        s.px(cx, 55, "wood_light")
    s.line([(86, 51), (96, 56)], "wood")
    # plague doctor (foreground, large): hat, white beak mask, long coat, staff and lantern
    x, y = 30, 61
    s.rect(x - 1, y - 18, x + 7, y - 1, "night_dark")       # coat
    s.rect(x - 1, y - 18, x - 1, y - 1, "night_light")
    s.poly([(x - 3, y), (x - 1, y - 8), (x + 7, y - 8), (x + 9, y)], "night_dark")
    s.rect(x, y - 23, x + 5, y - 19, "ink")                  # head
    s.poly([(x + 5, y - 22), (x + 11, y - 19), (x + 5, y - 19)], "paper")  # beak
    s.line([(x + 5, y - 19), (x + 10, y - 19)], "paper_dark")
    s.px(x + 3, y - 21, "red_light")                           # glass eye
    s.rect(x - 3, y - 24, x + 8, y - 24, "ink")               # hat brim
    s.rect(x, y - 28, x + 5, y - 25, "ink")
    s.line([(x - 4, y - 20), (x - 4, y)], "wood")              # staff
    s.line([(x + 8, y - 14), (x + 11, y - 9)], "wood_dark")    # lantern arm
    s.ellipse(x + 7, y - 11, x + 16, y - 2, "night_light")    # glow
    s.rect(x + 10, y - 9, x + 13, y - 5, "gold")
    s.rect(x + 11, y - 8, x + 12, y - 6, "gold_light")
    s.smoke(104, 40, 4, "night_light", "night")


@motif
def court(s):
    # throne room interior
    s.sky([("wood_dark", 64)])
    for x in range(6, W, 24):  # wall panels
        s.rect(x, 4, x + 15, 40, "wood")
        s.rect(x, 4, x, 40, "wood_light")
    for x in (18, 46, 82, 110):  # pillars
        s.rect(x - 3, 4, x + 3, 50, "paper_dark")
        s.rect(x - 3, 4, x - 2, 50, "paper")
        s.rect(x + 3, 4, x + 3, 50, "wood")
        s.rect(x - 4, 4, x + 4, 6, "paper")
        s.rect(x - 4, 48, x + 4, 50, "paper")
    # windows with light
    for x in (30, 94):
        s.rect(x - 4, 10, x + 4, 30, "sky_light")
        s.poly([(x - 4, 10), (x, 6), (x + 4, 10)], "sky_light")
        s.line([(x, 8), (x, 30)], "wood_dark")
        s.line([(x - 4, 20), (x + 4, 20)], "wood_dark")
    # floor checker
    for y in range(50, H):
        for x in range(0, W, 4):
            s.rect(x, y, x + 3, y, "grey_dark" if ((x // 4) + (y // 2)) % 2 else "grey")
    # carpet and dais
    s.poly([(52, 64), (76, 64), (70, 44), (58, 44)], "red")
    s.poly([(53, 64), (55, 64), (59, 44), (58, 44)], "red_light")
    s.rect(50, 40, 78, 44, "paper_dark")
    s.rect(50, 40, 78, 40, "paper")
    # throne + king
    s.rect(58, 22, 70, 39, "gold_dark")
    s.rect(59, 20, 69, 37, "gold")
    s.rect(61, 24, 67, 37, "red_dark")
    s.poly([(59, 20), (64, 15), (69, 20)], "gold")
    s.rect(61, 30, 67, 38, "purple")
    s.rect(66, 30, 67, 38, "purple_dark")
    s.rect(62, 25, 66, 29, "skin")
    s.rect(61, 23, 67, 24, "gold_light")
    s.px(61, 22, "gold_light")
    s.px(64, 22, "gold_light")
    s.px(67, 22, "gold_light")
    s.rect(60, 30, 61, 38, "red")
    # courtiers
    for x, t in ((34, "blue"), (40, "green"), (88, "purple"), (94, "blue")):
        s.person(x, 57, tunic=t, hat="ink")
    s.banner(10, 8, "blue", emblem="gold")
    s.banner(116, 8, "red", emblem="gold")


@motif
def siege(s):
    s.dusk()
    s.clouds(3, 6, 14, "dusk")
    s.hills(42, 3, "green_dark")
    s.ground(46, "land_dark", "wood")
    s.castle(64, 46, 1.25, flag="blue")
    s.smoke(70, 20, 4)
    s.fire(98, 34, 6)
    s.smoke(102, 26, 3, "grey", "grey_dark")
    for x in (10, 30):
        s.cannon(x, 58, 1)
    s.person(4, 60, tunic="red", hat="grey")
    s.person(24, 60, tunic="red", hat="grey")
    s.crowd(36, 58, 61, ["red", "red_dark"], hat="grey", weapon="pike")
    s.tent(2, 50, stripe="red")
    s.banner(48, 38, "red")
    s.line([(22, 52), (70, 30)], "grey_light")  # ladder of a shot arc
    s.px(70, 30, "ink")


@motif
def naval(s):
    s.day()
    s.clouds(5, 6, 20)
    s.sea(40)
    s.ship(14, 54, flag="red")
    s.ship(80, 50, sail="paper_dark", flag="blue")
    s.ship(50, 46, flag="red")
    s.smoke(42, 38, 3)
    s.smoke(76, 36, 3)
    for x in (37, 74):
        s.px(x, 44, "gold_light")
        s.px(x + 1, 44, "gold")
    s.rect(100, 56, 108, 57, "wood_dark")  # wreckage
    s.line([(104, 56), (110, 48)], "wood_dark")


@motif
def exploration(s):
    s.sky([("dusk_dark", 6), ("dusk", 8), ("dusk_light", 12), ("sky_light", 40)])
    s.sun(100, 30, 8, "gold_light")
    s.sea(32, "sea", "sea_shallow", "gold_light")
    s.poly([(96, 34), (106, 30), (118, 31), (127, 34)], "green_dark")  # unknown coast
    s.tree(110, 32, 6, "green", "green_dark")
    s.ship(30, 52, flag="red")
    s.line([(4, 40), (24, 40)], "foam")
    s.line([(60, 58), (90, 58)], "sea_shallow")
    for x in (14, 22, 70):  # gulls
        s.px(x, 18, "ink")
        s.px(x - 1, 17, "ink")
        s.px(x + 1, 17, "ink")


@motif
def harvest(s):
    s.day()
    s.sun(104, 12, 6)
    s.clouds(3, 6, 16)
    s.hills(32, 4, "green", "green_light", phase=0.5)
    s.ground(38, "gold", "gold_dark")
    for y in range(40, 62, 4):
        s.line([(0, y), (W, y)], "gold_light")
    for x in (16, 40, 88):  # sheaves
        s.poly([(x, 50), (x + 3, 42), (x + 6, 50)], "gold_dark")
        s.line([(x + 1, 46), (x + 5, 46)], "wood")
    s.person(56, 56, tunic="green", hat="paper")
    s.person(66, 57, tunic="blue", hat="paper")
    s.line([(70, 50), (74, 48)], "grey_light")  # sickle
    s.rect(96, 52, 116, 56, "wood")
    s.rect(98, 48, 114, 51, "gold")
    s.ellipse(96, 55, 102, 61, "wood_dark")
    s.ellipse(110, 55, 116, 61, "wood_dark")
    s.house(4, 38, 9, 7, roof="wood")


@motif
def famine(s):
    s.sky([("grey", 10), ("grey_light", 24), ("paper_dark", 40)])
    s.snowfall(50)
    s.hills(34, 3, "grey_light", "white")
    s.ground(40, "snow", "grey_light")
    s.tree(20, 44, 18, bare=True)
    s.tree(108, 42, 14, bare=True)
    s.house(70, 44, 10, 7, roof="grey_dark", wall="paper_dark", shade="grey")
    s.rect(70, 37, 80, 37, "white")
    s.person(44, 56, tunic="grey", hat="grey_dark")
    s.person(49, 57, tunic="wood", hat="grey_dark")
    s.person(53, 57, tunic="grey_dark")
    s.rect(40, 57, 58, 57, "grey")
    s.ellipse(84, 50, 92, 54, "wood_dark")  # empty bowl
    s.ellipse(85, 50, 91, 52, "grey_dark")


@motif
def town_fire(s):
    s.night()
    s.sky([("night_dark", 8), ("dusk_dark", 14), ("dusk", 20), ("night_light", 30)])
    s.town(50, 0, W, roofs=("wood_dark", "red_dark"), lit=True, wall="wood", shade="wood_dark")
    for x in (14, 40, 62, 90, 112):
        s.fire(x, 42 - (x % 3), 10)
        s.smoke(x + 5, 26, 4, "grey_dark", "night")
    s.ground(50, "wood_dark", "dusk_dark")
    s.crowd(20, 60, 60, ["blue", "wood", "grey"])
    s.rect(70, 54, 72, 59, "wood")  # bucket chain
    s.person(74, 60, tunic="red")
    s.rect(77, 54, 78, 55, "blue_light")


@motif
def revolt(s):
    s.dusk()
    s.hills(38, 3, "green_dark")
    s.castle(90, 42, 0.8, flag="purple")
    s.ground(42, "land_dark", "wood")
    for i, x in enumerate(range(6, 80, 5)):
        s.person(x, 58 + (i % 3), tunic=["wood", "green", "grey", "paper_dark"][i % 4], hat="wood_dark" if i % 2 else None)
        if i % 3 == 0:
            s.line([(x + 3, 58 + (i % 3)), (x + 4, 44 + (i % 3))], "wood_light")  # pitchfork
            s.px(x + 3, 43 + (i % 3), "grey_light")
            s.px(x + 5, 43 + (i % 3), "grey_light")
        elif i % 3 == 1:
            s.line([(x + 3, 58 + (i % 3)), (x + 4, 47 + (i % 3))], "wood")  # torch
            s.px(x + 4, 46 + (i % 3), "gold_light")
            s.px(x + 4, 45 + (i % 3), "red")
    s.banner(40, 26, "paper_dark", emblem="red")


@motif
def church(s):
    s.day()
    s.clouds(4, 6, 18)
    s.hills(44, 3, "green", "green_light")
    s.ground(50, "land", "land_light")
    s.cathedral(48, 52, 32, 20)
    s.crowd(8, 40, 60, ["blue", "red", "paper_dark"])
    s.crowd(92, 124, 60, ["purple", "green", "wood"])
    s.figure(60, 62, "red", hat="mitre", arm="up")


@motif
def reformation(s):
    s.day()
    s.ground(48, "grey", "grey_dark")
    s.rect(30, 6, 98, 48, "paper_dark")  # church facade
    s.rect(30, 6, 32, 48, "paper")
    s.poly([(28, 8), (64, 0), (100, 8)], "grey_dark")
    s.rect(54, 20, 74, 48, "wood_dark")  # big door
    s.ellipse(54, 12, 74, 28, "wood_dark")
    s.line([(64, 16), (64, 48)], "wood")
    s.rect(58, 28, 66, 38, "paper")  # nailed theses
    for y in range(30, 37, 2):
        s.line([(59, y), (65, y)], "paper_dark")
    s.px(62, 28, "grey")
    s.figure(76, 60, "wood_dark", hat="cap", arm="out")
    s.line([(89, 49), (91, 47)], "grey")  # hammer
    s.crowd(6, 50, 61, ["blue", "red", "green"])
    s.crowd(96, 124, 61, ["wood", "grey"])


@motif
def inquisition(s):
    s.interior("night_dark", "night", "grey_dark", "night", 52)
    s.window(64, 10, 10, 20, "night_light")
    s.table(24, 104, 34, "wood_dark", cloth="red_dark")
    for x in (34, 58, 82):
        s.poly([(x, 34), (x + 2, 18), (x + 8, 18), (x + 10, 34)], "ink")  # hooded judges
        s.poly([(x + 3, 18), (x + 5, 13), (x + 7, 18)], "ink")
        s.px(x + 4, 22, "red_light")
        s.px(x + 6, 22, "red_light")
    s.candle(30, 34)
    s.candle(96, 34)
    s.scroll(56, 28, 16, 5)
    s.figure(60, 63, "paper_dark")
    s.line([(57, 52), (73, 52)], "grey")  # chains


@motif
def printing(s):
    s.interior("wood_dark", "wood", "wood", "wood_dark", 50)
    s.window(104, 8, 10, 22)
    # press: two posts, beam, screw, platen, bed
    s.rect(40, 8, 43, 52, "wood")
    s.rect(70, 8, 73, 52, "wood")
    s.rect(38, 6, 75, 10, "wood_dark")
    s.rect(55, 10, 58, 22, "grey")
    s.line([(48, 18), (66, 14)], "wood_light")
    s.rect(46, 22, 67, 25, "wood_dark")
    s.rect(44, 34, 69, 37, "wood_light")
    s.rect(47, 31, 66, 33, "paper")
    s.figure(80, 60, "blue", hat="cap", arm="out")
    for y in (16, 22, 28):  # drying sheets
        s.line([(8, y - 2), (30, y - 2)], "wood_light")
        s.rect(10, y - 1, 15, y + 4, "paper")
        s.rect(20, y - 1, 26, y + 4, "paper")
    s.books(14, 50, 5)


@motif
def scholar(s):
    s.interior("wood_dark", "wood", "grey", "grey_dark", 52)
    for x0 in (6, 102):  # bookshelves
        s.rect(x0, 6, x0 + 20, 50, "wood")
        for y in (14, 24, 34, 44):
            s.books(x0 + 1, y, 9)
            s.rect(x0, y + 1, x0 + 20, y + 1, "wood_dark")
    s.window(64, 6, 14, 22, "night_light")
    s.px(60, 10, "white")
    s.px(67, 14, "white")
    s.table(36, 90, 40, "wood_dark")
    s.scroll(42, 34, 14, 5)
    s.candle(84, 40)
    # astrolabe / globe on the desk
    s.ellipse(62, 28, 74, 40, "gold")
    s.ellipse(64, 30, 72, 38, "wood_dark")
    s.line([(62, 34), (74, 34)], "gold_light")
    s.line([(68, 28), (68, 40)], "gold_light")
    s.figure(30, 62, "purple", hat="cap", beard=True, arm="out")


@motif
def market(s):
    s.day()
    s.clouds(3, 4, 12)
    s.town(30, 0, W, roofs=("red", "wood", "blue_dark"))
    s.ground(30, "grey", "grey_dark")
    for x, c in ((6, "red"), (46, "blue"), (88, "green")):  # stalls with awnings
        for i in range(0, 32, 4):
            s.rect(x + i, 32, x + i + 1, 35, c)
            s.rect(x + i + 2, 32, x + i + 3, 35, "paper")
        s.rect(x + 1, 36, x + 2, 48, "wood_dark")
        s.rect(x + 29, 36, x + 30, 48, "wood_dark")
        s.rect(x, 44, x + 31, 46, "wood")
        s.sack(x + 4, 44, "wood_light")
        s.coins(x + 16, 43, 3)
        s.ellipse(x + 22, 40, x + 27, 44, "red_light")
    s.crowd(4, 124, 60, ["blue", "red", "green", "purple", "wood"], hat=None)
    s.crowd(20, 100, 55, ["paper_dark", "wood", "grey"])


@motif
def bank(s):
    s.interior("wood_dark", "wood", "paper_dark", "wood", 50)
    s.window(20, 8, 10, 22)
    s.window(108, 8, 10, 22)
    s.table(30, 98, 36, "green_dark", cloth="green")
    s.coins(38, 35, 9)
    s.coins(50, 35, 6)
    s.coins(82, 35, 9)
    s.rect(60, 30, 74, 35, "paper")  # ledger
    s.line([(67, 30), (67, 35)], "paper_dark")
    for y in (31, 33):
        s.line([(61, y), (65, y)], "ink")
        s.line([(69, y), (73, y)], "ink")
    # scales
    s.line([(90, 22), (90, 35)], "gold_dark")
    s.line([(84, 22), (96, 22)], "gold")
    s.rect(83, 26, 87, 27, "gold")
    s.rect(93, 27, 97, 28, "gold")
    s.figure(54, 62, "red_dark", hat="ink", arm="out")
    s.figure(76, 62, "blue_dark", hat="cap")
    s.sack(10, 50, "wood")
    s.sack(112, 50, "wood")


@motif
def mine(s):
    s.sky([("rock_dark", H)])
    s.poly([(0, 0), (128, 0), (128, 10), (90, 16), (40, 12), (0, 18)], "rock")
    s.poly([(0, 64), (128, 64), (128, 52), (60, 56), (0, 50)], "rock")
    for x in range(0, W, 26):  # timber frames
        s.rect(x + 4, 10, x + 6, 56, "wood")
        s.rect(x + 2, 10, x + 24, 12, "wood_dark")
    for x, y in ((18, 30), (68, 24), (102, 36), (48, 40), (30, 20), (90, 28)):  # silver ore glints
        s.rect(x, y, x + 2, y + 1, "grey")
        s.px(x + 1, y, "white")
        s.px(x + 3, y + 2, "grey_light")
    s.rect(40, 50, 60, 55, "wood")
    s.rect(42, 46, 58, 49, "grey_light")
    s.ellipse(41, 54, 46, 59, "wood_dark")
    s.ellipse(54, 54, 59, 59, "wood_dark")
    s.figure(76, 58, "wood_dark", hat="helmet", arm="up")
    s.line([(86, 38), (90, 34), (94, 38)], "grey")
    s.candle(100, 46)


@motif
def wedding(s):
    s.interior("paper_dark", "paper", "red_dark", "red", 52)
    s.window(32, 8, 12, 24)
    s.window(96, 8, 12, 24)
    s.rect(54, 10, 74, 44, "gold_dark")  # altar piece
    s.rect(56, 12, 72, 42, "gold")
    s.line([(64, 16), (64, 32)], "paper")
    s.line([(60, 21), (68, 21)], "paper")
    s.rect(50, 44, 78, 48, "paper")
    s.figure(48, 62, "blue", hat="crown")
    s.figure(70, 62, "paper", hat="crown")
    for x, y in ((16, 50), (110, 50)):  # flowers
        s.rect(x, y, x + 1, y + 8, "green")
        s.ellipse(x - 2, y - 4, x + 3, y, "red_light")
    s.crowd(4, 36, 63, ["purple", "green", "blue"], hat="ink")
    s.crowd(92, 124, 63, ["red", "gold", "wood"], hat="ink")


@motif
def coronation(s):
    s.interior("purple_dark", "purple", "grey", "grey_dark", 52)
    for x in (16, 112):
        s.rect(x - 3, 2, x + 3, 52, "paper_dark")
        s.rect(x - 3, 2, x - 2, 52, "paper")
    s.window(64, 4, 16, 18, "gold_light")
    s.figure(58, 58, "red", arm=None)
    s.rect(58, 48, 68, 58, "red")  # kneeling cloak
    s.figure(76, 60, "paper", hat="mitre", arm="up")
    s.rect(84, 32, 92, 34, "gold")  # crown held aloft
    for hx in (84, 88, 92):
        s.px(hx, 31, "gold_light")
    s.px(88, 33, "red")
    s.crowd(24, 50, 62, ["blue", "green", "wood"], hat="ink")
    s.crowd(96, 108, 62, ["blue", "purple"], hat="ink")
    s.banner(30, 10, "red")
    s.banner(96, 10, "blue")


@motif
def treaty(s):
    s.interior("wood_dark", "wood", "grey", "grey_dark", 52)
    s.window(64, 6, 16, 20)
    s.table(28, 100, 38, "wood", cloth="green_dark")
    s.scroll(52, 30, 24, 7)
    s.seal(70, 38)
    s.line([(60, 34), (64, 32)], "ink")  # quill
    s.line([(64, 32), (66, 26)], "paper")
    s.figure(20, 62, "blue", hat="ink", arm="out")
    s.figure(98, 62, "red", hat="ink")
    s.line([(97, 51), (92, 51)], "red")
    s.banner(6, 6, "blue")
    s.banner(116, 6, "red")
    s.candle(36, 38)
    s.candle(90, 38)


@motif
def diet(s):
    s.interior("wood_dark", "wood", "red_dark", "red", 50)
    s.window(32, 6, 10, 18)
    s.window(96, 6, 10, 18)
    s.rect(54, 20, 74, 40, "gold_dark")  # presiding seat
    s.rect(56, 22, 72, 38, "red")
    s.figure(60, 42, "purple", hat="crown")
    for row, y in enumerate((48, 54, 60)):  # benches of delegates
        s.rect(2, y, 50, y + 1, "wood")
        s.rect(78, y, 126, y + 1, "wood")
        for x in range(4 + row * 2, 48, 6):
            s.person(x, y - 1, tunic=["red", "blue", "green", "purple"][(x // 6 + row) % 4], hat="ink")
        for x in range(80 + row * 2, 124, 6):
            s.person(x, y - 1, tunic=["blue", "wood", "red", "green"][(x // 6 + row) % 4], hat="ink")
    s.banner(4, 2, "gold", emblem="ink")
    s.banner(118, 2, "gold", emblem="ink")


@motif
def camp(s):
    s.dusk()
    s.hills(36, 4, "green_dark")
    s.ground(42, "land_dark", "green_dark")
    for x in (4, 22, 92, 110):
        s.tent(x, 46, stripe="red" if x < 50 else "blue")
    s.fire(60, 54, 8)
    s.smoke(64, 42, 4)
    for x in (44, 50, 76, 82):
        s.person(x, 58, tunic=["red", "blue"][x % 2], hat="grey", weapon="pike" if x in (44, 82) else None)
    s.rider(30, 62, "red")
    s.coins(90, 60, 6)
    s.figure(100, 63, "gold", hat="ink", arm="out")
    s.banner(64, 16, "red")


@motif
def artillery(s):
    s.day()
    s.clouds(3, 6, 14)
    s.hills(38, 3, "green", "green_light")
    s.ground(44, "land", "land_dark")
    for i, x in enumerate((10, 46, 82)):
        s.cannon(x + 10, 58 - i, 1)
        s.smoke(x + 28, 46 - i, 3)
        s.person(x, 60 - i, tunic="blue", hat="grey")
    s.rect(104, 50, 120, 56, "wood")
    for x in (106, 110, 114):  # powder kegs
        s.ellipse(x, 44, x + 4, 50, "wood_dark")
    s.rect(110, 30, 112, 50, "wood_dark")  # wagon fort
    s.banner(110, 22, "blue")


@motif
def conspiracy(s):
    s.night()
    s.moon(20, 10, 4)
    s.rect(0, 10, 30, 64, "night")  # alley walls
    s.rect(98, 6, 128, 64, "night")
    s.rect(30, 10, 31, 64, "night_light")
    for y in (18, 34):
        s.rect(10, y, 16, y + 6, "gold_dark")
        s.rect(108, y + 4, 114, y + 10, "night_dark")
    s.ground(54, "night_dark", "night")
    s.figure(48, 60, "ink", hat="ink")
    s.figure(66, 61, "night_dark", hat="ink", arm="out")
    s.line([(79, 50), (84, 47)], "grey_light")  # dagger
    s.rect(52, 44, 56, 45, "paper")  # letter
    s.px(54, 44, "red")
    s.candle(18, 54)


@motif
def sickbed(s):
    s.interior("night", "night_dark", "wood_dark", "wood", 52)
    s.window(104, 8, 10, 20, "night_light")
    s.rect(14, 34, 76, 46, "red_dark")  # bed
    s.rect(14, 32, 76, 34, "paper")
    s.rect(12, 18, 16, 52, "wood_dark")
    s.rect(74, 26, 78, 52, "wood_dark")
    s.poly([(10, 16), (40, 10), (40, 30), (14, 30)], "red")  # curtain
    s.ellipse(18, 27, 26, 34, "skin")
    s.rect(18, 26, 26, 27, "gold")
    s.figure(86, 62, "ink", hat="ink", arm="out")
    s.rect(94, 46, 98, 50, "blue_light")  # vial
    s.candle(60, 32)


@motif
def heir(s):
    s.interior("wood_dark", "wood", "grey", "grey_dark", 52)
    s.window(40, 6, 12, 22)
    s.window(88, 6, 12, 22)
    s.figure(36, 62, "purple", hat="crown")
    s.person(60, 60, tunic="blue", hat="gold")  # young prince
    s.rect(64, 54, 66, 54, "grey_light")  # wooden sword
    s.figure(80, 62, "ink", hat="cap", beard=True, arm="out")
    s.books(100, 52, 6)
    s.banner(14, 8, "blue")


@motif
def artist(s):
    s.interior("paper_dark", "paper", "wood", "wood_dark", 52)
    s.window(20, 6, 12, 24)
    # easel with a framed painting
    s.line([(66, 60), (74, 20), (82, 60)], "wood_dark")
    s.rect(60, 18, 90, 40, "gold_dark")
    s.rect(62, 20, 88, 38, "sky_light")
    s.poly([(62, 38), (70, 28), (78, 34), (88, 26), (88, 38)], "green")
    s.ellipse(80, 22, 84, 26, "gold_light")
    s.figure(44, 62, "blue", hat="ink", arm="out")
    s.ellipse(52, 46, 60, 52, "wood_light")  # palette
    for x, c in ((53, "red"), (55, "blue"), (57, "gold")):
        s.px(x, 48, c)
    s.rect(100, 34, 108, 52, "paper_dark")  # bust on a plinth
    s.ellipse(100, 24, 108, 34, "paper")


@motif
def comet(s):
    s.night()
    s.comet(50, 22, 50)
    s.hills(44, 4, "night_dark")
    s.town(52, 0, W, roofs=("night_dark", "wood_dark"), lit=True, wall="grey_dark", shade="night")
    s.ground(52, "night_dark", "night")
    for x in (30, 36, 42, 90, 96):
        s.person(x, 60, tunic="night_light", hat="grey_dark")
        s.px(x + 3, 51, "skin")
    s.figure(64, 63, "purple", hat="cap", arm="up")


@motif
def volcano(s):
    s.sky([("night_dark", 6), ("dusk_dark", 10), ("dusk", 14), ("dusk_light", 40)])
    s.poly([(24, 50), (56, 14), (72, 14), (108, 50)], "rock_dark")
    s.poly([(56, 14), (40, 32), (52, 30)], "rock")
    s.fire(57, 16, 14)
    for i in range(5):
        s.smoke(62 + i * 3, 10 - i, 3, "grey_dark", "grey")
    s.line([(64, 16), (60, 30), (62, 40)], "red")  # lava
    s.line([(66, 18), (72, 32)], "gold")
    s.sea(52, "sea_deep", "sea", "dusk_light")
    s.town(54, 0, 40, roofs=("red", "wood"))
    s.ship(90, 62, flag="red")


@motif
def alchemy(s):
    s.interior("night", "night_dark", "grey_dark", "night", 52)
    s.table(20, 96, 38, "wood_dark")
    for x, c in ((26, "green"), (36, "blue"), (46, "purple"), (82, "red")):
        s.ellipse(x, 30, x + 6, 38, c)  # flasks
        s.rect(x + 2, 26, x + 4, 30, "grey_light")
        s.px(x + 1, 32, "white")
    s.fire(100, 52, 10)
    s.rect(98, 42, 114, 44, "grey_dark")
    s.ellipse(100, 34, 112, 44, "grey")
    s.smoke(106, 26, 3, "green_light", "green")
    s.figure(58, 62, "purple", hat="cap", beard=True, arm="up")
    s.books(6, 50, 5)
    s.scroll(70, 24, 10, 6)


@motif
def border(s):
    s.day()
    s.clouds(4, 6, 16)
    s.hills(34, 5, "green", "green_light")
    s.ground(42, "land", "land_dark")
    s.line([(64, 42), (64, 64)], "wood_dark")  # boundary line / stream
    s.line([(65, 42), (66, 64)], "sea_shallow")
    s.rect(60, 34, 68, 46, "grey")  # boundary stone
    s.rect(60, 34, 61, 46, "grey_light")
    s.line([(62, 38), (66, 38)], "grey_dark")
    s.rider(34, 60, "blue", facing=1)
    s.rider(84, 60, "red", "wood_dark", facing=-1)
    s.banner(20, 30, "blue")
    s.banner(104, 30, "red")
    s.tower(4, 42, 8, 16)
    s.tower(116, 42, 8, 16)


@motif
def steppe(s):
    s.sky([("sky", 8), ("sky_light", 16), ("paper_dark", 40)])
    s.sun(20, 14, 5)
    s.hills(36, 2, "land_dark", freq=0.03)
    s.ground(40, "land", "land_dark")
    for x in (70, 88, 106):
        s.yurt(x, 44)
    s.smoke(82, 34, 3)
    for i, x in enumerate((8, 22, 36, 50)):
        s.rider(x, 60 - i % 2, ["red", "blue", "green", "red"][i], facing=1)
    s.banner(60, 26, "gold", emblem="red")
    s.line([(0, 52), (128, 50)], "land_light")


@motif
def city(s):
    s.dusk()
    s.sun(98, 22, 7, "gold_light")
    s.sea(46, "sea", "sea_shallow", "dusk_light")
    s.hills(40, 2, "land_dark")
    s.town(46, 0, W, roofs=("red", "wood", "red_dark"))
    s.cathedral(46, 44, 30, 16)  # dome-and-tower skyline
    s.ellipse(52, 18, 72, 34, "gold_dark")
    s.rect(61, 12, 63, 18, "gold")
    s.tower(14, 44, 6, 28, c="paper_dark", light="paper", dark="wood", roof="red")
    s.tower(104, 44, 6, 24, c="paper_dark", light="paper", dark="wood", roof="blue_dark")
    s.ship(14, 62, flag="red")
    s.ship(86, 60, sail="paper_dark", flag="gold")


@motif
def mourning(s):
    s.sky([("grey_dark", 10), ("grey", 20), ("grey_light", 40)])
    s.hills(36, 3, "green_dark")
    s.ground(42, "green_dark", "land_dark")
    for x, y in ((14, 52), (30, 50), (46, 53), (82, 51), (98, 53), (112, 50)):
        s.grave(x, y)
    s.tree(64, 44, 18, bare=True)
    s.figure(54, 62, "ink", hat="ink")
    s.figure(68, 62, "ink")
    s.person(80, 61, tunic="grey_dark")
    s.rect(58, 49, 60, 52, "paper")  # flowers
    s.px(59, 48, "red_light")


@motif
def procession(s):
    s.day()
    s.clouds(3, 4, 12)
    s.cathedral(84, 44, 30, 16)
    s.town(44, 0, 70, roofs=("red", "wood"))
    s.ground(44, "grey", "grey_light")
    for i, x in enumerate(range(4, 80, 6)):
        s.person(x, 58 + (i % 2), tunic=["blue", "red", "gold", "purple"][i % 4], hat="grey" if i % 2 else None, weapon="pike" if i % 3 == 0 else None)
    for x in (12, 36, 60):
        s.banner(x, 34, ["blue", "red", "gold"][x % 3])
    s.rider(64, 62, "gold", facing=1)
    for _ in range(20):  # flower petals
        s.px(s.rng.randrange(W), s.rng.randrange(20, 40), "red_light")


@motif
def tavern(s):
    s.interior("wood_dark", "wood", "wood", "wood_dark", 52)
    s.rect(6, 10, 30, 48, "wood_dark")  # barrels on the wall
    for y in (16, 30):
        for x in (8, 18):
            s.ellipse(x, y, x + 9, y + 12, "wood")
            s.line([(x, y + 6), (x + 9, y + 6)], "grey_dark")
    s.table(40, 110, 40, "wood")
    for x in (48, 62, 90):
        s.rect(x, 34, x + 3, 39, "gold")  # tankards / cups
        s.rect(x, 34, x + 3, 34, "white")
    s.rect(74, 30, 86, 39, "paper")  # newspaper / bill
    for y in (32, 34, 36):
        s.line([(75, y), (85, y)], "paper_dark")
    for x, c in ((44, "red"), (66, "blue"), (98, "green")):
        s.figure(x, 63, c, hat="ink")
    s.candle(70, 40)


@motif
def knights(s):
    s.interior("blue_dark", "blue", "grey", "grey_dark", 52)
    for x in (20, 108):
        s.banner(x - 3, 4, "red", h=20)
    s.rect(54, 8, 74, 30, "gold_dark")  # golden fleece emblem
    s.rect(56, 10, 72, 28, "red_dark")
    s.ellipse(58, 14, 70, 22, "gold")
    s.poly([(62, 22), (64, 27), (66, 22)], "gold_light")
    for x in (24, 40, 80, 96):
        s.figure(x, 62, "grey", hat="helmet")
        s.line([(x + 9, 60), (x + 9, 44)], "grey_light")
    s.figure(60, 62, "red", hat="crown", arm="out")


@motif
def ottoman(s):
    s.sky([("dusk_dark", 6), ("dusk", 10), ("dusk_light", 40)])
    s.sea(44, "sea", "sea_shallow", "dusk_light")
    s.hills(40, 2, "land_dark")
    # mosque silhouette: big dome, half domes, minarets
    s.ellipse(44, 14, 84, 40, "paper_dark")
    s.ellipse(46, 16, 70, 36, "paper")
    s.rect(42, 30, 86, 42, "paper_dark")
    s.ellipse(34, 28, 50, 40, "paper_dark")
    s.ellipse(78, 28, 94, 40, "paper_dark")
    for x in (28, 98):
        s.rect(x, 6, x + 2, 42, "paper")
        s.poly([(x - 1, 6), (x + 1, 0), (x + 3, 6)], "grey_dark")
        s.rect(x - 1, 16, x + 3, 17, "paper_dark")
    s.line([(64, 8), (64, 14)], "gold")
    s.px(65, 8, "gold_light")
    s.town(44, 0, 26, roofs=("red", "red_dark"))
    s.town(44, 100, W, roofs=("red", "wood"))
    s.ship(54, 60, flag="red")
    s.moon(110, 12, 3, bg="dusk_dark")


def build(names=None):
    names = names or list(MOTIFS)
    for i, n in enumerate(names):
        sc = Scene(seed=1444 + i)
        MOTIFS[n](sc)
        sc.save(n)
    print("events:", " ".join(names))


if __name__ == "__main__":
    build(sys.argv[1:])
