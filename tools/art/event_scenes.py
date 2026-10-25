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

    def moon(self, x, y, r=4):
        self.ellipse(x - r, y - r, x + r, y + r, "paper")
        self.ellipse(x - r + 2, y - r - 1, x + r + 2, y + r - 1, "night_dark")

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


def build(names=None):
    names = names or list(MOTIFS)
    for i, n in enumerate(names):
        sc = Scene(seed=1444 + i)
        MOTIFS[n](sc)
        sc.save(n)
    print("events:", " ".join(names))


if __name__ == "__main__":
    build(sys.argv[1:])
