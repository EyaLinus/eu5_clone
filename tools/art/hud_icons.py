"""HUD resource icons (16x16 grid). Writes assets/src/pixel/icons/<key>.txt. Run tools/build_art.sh after."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import blank, paste, layer, stack, write, outline

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "src", "pixel", "icons")
ICONS = {}

# mil: two crossed swords, steel blades, gold guards, wood grips
def sword(mirror, outlined=True):
    g = blank()
    pts = []
    for i in range(8):
        pts += [(2 + i, 2 + i, "a"), (3 + i, 2 + i, "g")]
    pts += [(8, 11, "G"), (9, 11, "G"), (9, 10, "D"), (10, 10, "G"), (10, 9, "G"), (11, 9, "G"), (11, 8, "G")]
    pts += [(11, 11, "O"), (12, 12, "H"), (13, 13, "D")]
    for x, y, c in pts:
        if mirror:
            x = 15 - x
            c = {"a": "g", "g": "a"}.get(c, c)
        g[y][x] = c
    return outline(g) if outlined else g
ICONS["mil"] = (stack(sword(True), sword(False)), "mil – military power: crossed swords")

# adm: parchment scroll with rolled ends and text lines
ICONS["adm"] = (layer([
    ".QPPPPPPPPQ.",
    "QPPPPPPPPPPQ",
    ".QQQQQQQQQQ.",
    "..PPPPPPPP..",
    "..PQQQQQPP..",
    "..PPPPPPPP..",
    "..PQQQQPPP..",
    "..PPPPPPPP..",
    "..PQQQQQPP..",
    ".QPPPPPPPPQ.",
    "QPPPPPPPPPPQ",
    ".QQQQQQQQQQ.",
], 2, 2), "adm – administrative power: parchment scroll")

# claim: sealed charter, sheet with red wax seal and ribbon
ICONS["claim"] = (stack(layer([
    "PPPPPPPPP.",
    "PQQQQQQPP.",
    "PPPPPPPPP.",
    "PQQQQQPPP.",
    "PPPPPPPPP.",
    "PQQQQQQPP.",
    "PPPPPPPPP.",
    "PQQQPPPPP.",
    "PPPPPPPPP.",
    "PPPPPPPQQ.",
], 2, 2), layer([
    ".rR.",
    "rRRE",
    "RRRE",
    ".EE.",
    ".E.E",
], 9, 9)), "claim – territorial claim: charter with red wax seal")

# dip: white dove with olive twig
ICONS["dip"] = (layer([
    "........aw..",
    ".......aww..",
    "......awww..",
    ".....awwwa..",
    ".ww.awwwa...",
    "Dwwwwwwaw...",
    ".wwwwwwwwwa.",
    "..aawwwwwaaa",
    "L...aaaaa.a.",
    "lL..........",
    ".L..........",
], 2, 2), "dip – diplomatic power: dove")

# manpower: two soldiers, kettle helmets over parchment faces, red tunics
def soldier(ox, oy, t, s):
    return layer([
        "..aaag..",
        ".aaaaggd",
        "..PPPQ..",
        "..PPPQ..",
        "..QPQQ..",
        ".%s%s%s%s%s%s." % (t, t, t, t, t, s),
        "%s%s%s%s%s%s%s%s" % (t, t, t, t, t, t, s, s),
        "%s%s%s%s%s%s%s%s" % (t, t, t, t, t, t, s, s),
    ], ox, oy)
back = soldier(6, 2, "B", "N")
front = soldier(2, 6, "R", "E")
ICONS["manpower"] = (stack(back, front), "manpower – recruits: two helmeted soldiers")

# army: heater shield, steel rim, red field with gold cross (same shape language as army_marker)
ICONS["army"] = (layer([
    "aaaaaaaaaaaa",
    "aRRRRGGRRRRg",
    "arRRRGGRRREg",
    "arRRRGGRRREg",
    "aGGGGGGGGGDg",
    "aGGGGGDDDDDg",
    "arRRRGDRRREg",
    ".arRRGDRREg.",
    ".arRRGDRREg.",
    "..arRGDREg..",
    "...arGDEg...",
    "....aggg....",
], 2, 2), "army – regiments / force limit: heater shield with cross")

# ae: angry red face
ICONS["ae"] = (layer([
    "...rrrrr....",
    ".rrrRRRRRR..",
    ".rRRRRRRRRR.",
    "rRkRRRRRkRRE",
    "rRRkRRRkRRRE",
    "rRkkRRRkkRRE",
    "rRRRRRRRRRRE",
    "rRRRkkkkRRRE",
    ".RRkRRRRkRE.",
    ".RRRRRRRRRE.",
    "...EEEEEE...",
], 2, 2), "ae – aggressive expansion: angry red face")

# prestige: five-point gold star
ICONS["prestige"] = (layer([
    ".....Y......",
    ".....YG.....",
    "....YGGG....",
    "....YGGG....",
    "YYYYGGGGGGGD",
    ".YGGGGGGGGD.",
    "..YGGGGGGD..",
    "...YGGGGD...",
    "...YGGDGD...",
    "..YGGD.DGD..",
    "..YGD...DD..",
    "..YD.....D..",
], 2, 2), "prestige – gold star")

# dev: two houses, parchment walls, red roofs, wood doors
ICONS["dev"] = (stack(layer([
    "...rR...",
    "..rRRE..",
    ".rRRRRE.",
    "rRRRRRRE",
    ".PPPPPQ.",
    ".PQPPPQ.",
    ".PPPPPQ.",
    ".PPPPPQ.",
], 7, 2), layer([
    "...rR...",
    "..rRRE..",
    ".rRRRRE.",
    "rRRRRRRE",
    ".PPPPPQ.",
    ".PPOOPQ.",
    ".PPOOPQ.",
    ".PPOHPQ.",
], 2, 6)), "dev – development: two houses")

# fort: stone tower with crenellations and gate
ICONS["fort"] = (layer([
    "aa.aa.aa.ag",
    "aa.aa.aa.ag",
    "aaaaaaaaagg",
    ".aaagggggd.",
    ".aagggggdd.",
    ".agdgggdgd.",
    ".agggggggd.",
    ".aggHHHggd.",
    ".agHOOOHgd.",
    ".agHOOOHgd.",
    ".agHOOOHdd.",
], 2, 3), "fort – fortification: stone tower")

# date: hourglass, wood frame, sand in paper
ICONS["date"] = (layer([
    "oOOOOOOOH",
    ".oOOOOOH.",
    ".aPPPPPg.",
    "..aPPPg..",
    "...aPg...",
    "....P....",
    "...a.g...",
    "..a.P.g..",
    ".a.PPP.g.",
    ".oOOOOOH.",
    "oOOOOOOOH",
], 3, 2), "date – game date: hourglass")

# siege: flame
ICONS["siege"] = (layer([
    "....r.......",
    "....rr...r..",
    "...rRr...rr.",
    "...rRRr..rR.",
    "..rRRRRr.rR.",
    "..rRGRRRrRRE",
    ".rRRGGRRRRRE",
    ".rRGYGRRGRRE",
    "rRGYYGGRGGRE",
    "rRGYYYGGGRE.",
    ".RRGYYGGRRE.",
    "..EERRRRE...",
], 2, 2), "siege – siege / burning: flame")

if __name__ == "__main__":
  os.makedirs(OUT, exist_ok=True)
  for key, (g, comment) in ICONS.items():
    write(os.path.join(OUT, key + ".txt"), g, comment + "\n16x16 grid, export x2 = 32 px. Generated by tools/art/hud_icons.py")
  print(" ".join(ICONS))
