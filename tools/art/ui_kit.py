"""Pixel-art UI kit: 9-slice frames for panels, buttons, cards, tooltips and bars.

Writes assets/art/ui/<name>.png (x2 nearest, like the icons). scripts/ui/ui_theme.gd turns them into
StyleBoxTextures; the slice margins below must match UiTheme.SLICES. Colours come from art_profile.yaml.

    python3 tools/art/ui_kit.py [--variant eisen|holz|krone] [--out DIR]

Shapes are octagons with chamfered corners; every frame is lit from the top-left (light step on the
top/left edges, dark step on bottom/right), 1-px ink outline, no gradients or dithering.
"""
import argparse, os, sys
import yaml
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SCALE = 2

# frame = metal/wood ramp of the outer frame, trim = corner studs and highlights, bg = panel interior
VARIANTS = {
    "eisen": {"frame": ["grey_dark", "grey", "grey_light"], "trim": ["gold_dark", "gold", "gold_light"],
              "bg": ["ui_bg_dark", "ui_bg", "ui_bg_light"], "btn": ["ui_btn_dark", "slate", "ui_btn_light"]},
    "holz": {"frame": ["wood_dark", "wood", "wood_light"], "trim": ["gold_dark", "gold", "gold_light"],
             "bg": ["ui_warm_dark", "ui_warm", "ui_warm_light"], "btn": ["wood_dark", "ui_warm_btn", "wood"]},
    "krone": {"frame": ["gold_dark", "gold", "gold_light"], "trim": ["red_dark", "red", "red_light"],
              "bg": ["night_dark", "ui_navy", "night"], "btn": ["night_dark", "night", "night_light"]},
}


def load_palette():
    with open(os.path.join(ROOT, "art_profile.yaml")) as f:
        prof = yaml.safe_load(f)
    return prof["palette"]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def save(self, path, pal, alpha=None):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is None:
                    continue
                hx = pal[c].lstrip("#")
                a = 255 if alpha is None or c not in alpha else alpha[c]
                img.putpixel((x, y), (int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16), a))
        img = img.resize((self.w * SCALE, self.h * SCALE), Image.NEAREST)
        img.save(path)


def ring(x, y, w, h, chamfer=2):
    """Distance to the shape edge (0 = outline ring) and which side is nearest; <0 = outside."""
    dx, dy = min(x, w - 1 - x), min(y, h - 1 - y)
    d = min(dx, dy, dx + dy - chamfer)
    # lit side: top/left edges light, bottom/right dark; diagonal corners follow their edges
    lit = (y <= h - 1 - y and dy <= dx) or (x <= w - 1 - x and dx < dy)
    if dx + dy - chamfer == d and d < min(dx, dy):  # on a chamfer
        top, left = y <= h - 1 - y, x <= w - 1 - x
        lit = top and left or (top and not left and dy < dx) or (left and not top and dx < dy)
    return d, lit


def frame(w, h, rings, fill, chamfer=2):
    """rings: list per ring index of (lit_colour, shade_colour); everything inside gets fill."""
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            d, lit = ring(x, y, w, h, chamfer)
            if d < 0:
                continue
            if d < len(rings):
                r = rings[d]
                c.set(x, y, r[0] if lit else r[1])
            else:
                c.set(x, y, fill)
    return c


def stud(c, cx, cy, ramp, r=3):
    """Diamond rivet lit from the top-left, ink outline at radius r+1."""
    dark, base, light = ramp
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            dx, dy = x - cx, y - cy
            m = abs(dx) + abs(dy)
            if m == r + 1:
                c.set(x, y, "ink")
            elif m <= r:
                s = dx + dy
                col = light if s < -1 else dark if s > 1 else base
                if m == 0:
                    col = light
                c.set(x, y, col)


def build(variant, out):
    pal = load_palette()
    v = VARIANTS[variant]
    fd, fb, fl = v["frame"]
    td, tb, tl = v["trim"]
    bd, bb, bl = v["bg"]
    kd, kb, kl = v["btn"]
    os.makedirs(out, exist_ok=True)
    A = None  # opaque PNGs (palette check is strict); UiTheme makes panels slightly see-through

    # panel: 32x32, slice 10. ink | frame bevel | frame | ink | inner shadow | bg + four corner studs
    p = frame(32, 32, [("ink", "ink"), (fl, fd), (fb, fb), ("ink", "ink"), (bd, bl)], bb)
    # gold corner brackets along the frame (8 px each way), then a rivet on the corner
    for y in range(32):
        for x in range(32):
            d, lit = ring(x, y, 32, 32)
            near = min(x, 31 - x) < 9 and min(y, 31 - y) < 9
            if near and d in (1, 2):
                p.set(x, y, (tl if lit else td) if d == 1 else tb)
    for cx, cy in [(4, 4), (27, 4), (4, 27), (27, 27)]:
        stud(p, cx, cy, (td, tb, tl))
    p.save(os.path.join(out, "panel.png"), pal, A)

    # header plate under titles: 24x14, slice 5
    h = frame(24, 14, [("ink", "ink"), (tl, td), (bl, bd)], bl if variant != "krone" else "night")
    for y in (5, 8):  # small trim notches at both ends
        h.set(3, y, tb)
        h.set(20, y, tb)
    h.save(os.path.join(out, "header.png"), pal)

    # top bar: frame only along the bottom edge (flush with the screen top), slice 6 at the bottom
    t = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            t.set(x, y, bb)
    for x in range(16):
        t.set(x, 10, bl)
        t.set(x, 11, "ink")
        t.set(x, 12, fl)
        t.set(x, 13, fb)
        t.set(x, 14, fd)
        t.set(x, 15, "ink")
    t.save(os.path.join(out, "topbar.png"), pal, A)

    # buttons 16x16, slice 5: ink | bevel | base; bottom gets a 2-px shadow (depth)
    def button(name, outline, lit, shade, base, sink=False):
        b = frame(16, 16, [(outline, outline), (lit, shade)], base)
        if not sink:
            for x in range(2, 14):
                b.set(x, 13, shade)
        else:
            for x in range(2, 14):
                b.set(x, 2, shade)
        b.save(os.path.join(out, name + ".png"), pal)

    button("button", "ink", kl, kd, kb)
    button("button_hover", "ink", tl, td, kl)
    button("button_pressed", "ink", kd, kl, kd, sink=True)
    button("button_disabled", "ink", bb, bb, bd)
    # accent button: important actions (Bestätigen, Erforschen)
    button("button_accent", "ink", tb, "wood_dark", td)

    # card: a framed box inside panels, 12x12 slice 4
    frame(12, 12, [(fd, fd), (bl, bd)], bl if variant != "krone" else "night").save(os.path.join(out, "card.png"), pal)
    frame(12, 12, [(tb, td), (tl, td)], bl if variant != "krone" else "night").save(os.path.join(out, "card_gold.png"), pal)
    frame(12, 12, [("green", "green_dark"), (bl, bd)], bl if variant != "krone" else "night").save(os.path.join(out, "card_good.png"), pal)
    frame(12, 12, [("red", "red_dark"), (bl, bd)], bl if variant != "krone" else "night").save(os.path.join(out, "card_bad.png"), pal)

    # tooltip: 14x14 slice 5, ink | trim | ink | bg
    frame(14, 14, [("ink", "ink"), (tl, td), ("ink", "ink")], bd).save(os.path.join(out, "tooltip.png"), pal)

    # inset (progress bar background, slider track): 8x8 slice 3, recessed = dark top/left
    frame(8, 8, [("ink", "ink"), (bd, bl)], bd, chamfer=1).save(os.path.join(out, "inset.png"), pal)
    # bar fill: neutral grey ramp, tinted in code with modulate (green/red/gold bars)
    frame(8, 8, [("ink", "ink"), ("white", "grey")], "grey_light", chamfer=1).save(os.path.join(out, "bar_fill.png"), pal)

    # scrollbar grabber 6x12 slice 3 and track 6x12 slice 3
    frame(6, 12, [("ink", "ink"), (tl, td)], tb, chamfer=1).save(os.path.join(out, "grabber.png"), pal)
    frame(6, 12, [(bd, bd)], bd, chamfer=1).save(os.path.join(out, "scroll_track.png"), pal)

    # separator: 8x4 tile, a gold rule with a dark underline
    s = Canvas(8, 4)
    for x in range(8):
        s.set(x, 1, td)
        s.set(x, 2, tb if x % 4 else tl)
    s.save(os.path.join(out, "separator.png"), pal)

    # slider handle 10x14 (investment slider etc.)
    hd = frame(10, 14, [("ink", "ink"), (tl, td)], tb)
    for y in range(4, 10):
        hd.set(5, y, td)
    hd.save(os.path.join(out, "slider_grabber.png"), pal)

    # buff / nerf arrows 8x8 for modifier rows (green up, red down)
    up = Canvas(8, 8)
    dn = Canvas(8, 8)
    shape = ["...kk...", "..kllk..", ".kllLLk.", "klLLLLFk", "kkkLFkkk", "..kLFk..", "..kLFk..", "..kkkk.."]
    cmap = {"k": "ink", "l": "green_light", "L": "green", "F": "green_dark"}
    rmap = {"k": "ink", "l": "red_light", "L": "red", "F": "red_dark"}
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch != ".":
                up.set(x, y, cmap[ch])
                dn.set(x, 7 - y, rmap[ch])
    up.save(os.path.join(out, "mod_up.png"), pal)
    dn.save(os.path.join(out, "mod_down.png"), pal)
    print("ui kit '%s' -> %s" % (variant, out))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", default="holz", choices=sorted(VARIANTS))
    ap.add_argument("--out", default=os.path.join(ROOT, "assets", "art", "ui"))
    a = ap.parse_args()
    build(a.variant, a.out)
