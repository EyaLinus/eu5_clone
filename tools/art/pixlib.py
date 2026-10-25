"""Helpers for writing pixel-art text grids (assets/src/pixel) for the game-assets-2d pipeline.

Shapes are drawn as fill masks without outline; outline() adds the 1-px ink outline from
art_profile.yaml. Characters map to palette names via LEGEND, so every grid stays palette-locked.
"""

LEGEND = {
    ".": "transparent", "k": "ink", "w": "white", "P": "paper", "Q": "paper_dark",
    "a": "grey_light", "g": "grey", "d": "grey_dark",
    "Y": "gold_light", "G": "gold", "D": "gold_dark",
    "r": "red_light", "R": "red", "E": "red_dark",
    "b": "blue_light", "B": "blue", "N": "blue_dark",
    "l": "green_light", "L": "green", "F": "green_dark",
    "o": "wood_light", "O": "wood", "H": "wood_dark",
    "u": "purple_light", "U": "purple", "V": "purple_dark",
    "t": "skin_light", "S": "skin", "s": "skin_dark",
}


def blank(w=16, h=16):
    return [["."] * w for _ in range(h)]


def paste(g, rows, ox=0, oy=0):
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                g[oy + y][ox + x] = c
    return g


def outline(g, diagonal=False):
    """Ink outline on every transparent pixel touching a filled one (4-neighbour, optional 8)."""
    h, w = len(g), len(g[0])
    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nb += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    out = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] != ".":
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and g[y + dy][x + dx] not in (".", "k") for dx, dy in nb):
                out[y][x] = "k"
    return out


def layer(rows, ox=0, oy=0, w=16, h=16, diagonal=False):
    """One outlined object on its own canvas; compose layers back to front with stack()."""
    return outline(paste(blank(w, h), rows, ox, oy), diagonal)


def stack(*layers):
    g = blank(len(layers[0][0]), len(layers[0]))
    for l in layers:
        paste(g, ["".join(r) for r in l])
    return g


def write(path, g, comment):
    used = sorted({c for r in g for c in r} | {"."})
    lines = ["# " + l for l in comment.strip().splitlines()]
    lines.append("legend:")
    lines += ["%s = %s" % (c, LEGEND[c]) for c in used]
    lines.append("---")
    lines += ["".join(r) for r in g]
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
