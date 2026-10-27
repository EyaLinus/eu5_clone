"""Nation flags (24x16 grid, export x2 = 48x32). Writes assets/src/pixel/flags/flag_<TAG>.txt.

A flag is designed flat in base colours on the 22x14 field; bevel() then applies the shading
rule shared with the anchor flag_FRA: light step on the top row and left column, dark step on
the bottom row and right column, 1-px ink frame around everything.
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import blank, paste, write

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "src", "pixel", "flags")
FW, FH = 22, 14
LIGHT = {"R": "r", "B": "b", "G": "Y", "L": "l", "U": "u", "O": "o", "w": "w", "a": "w", "P": "P", "E": "R", "N": "B", "D": "G", "F": "L", "g": "a", "k": "k", "Y": "Y"}
DARK = {"R": "E", "B": "N", "G": "D", "L": "F", "U": "V", "O": "H", "w": "a", "a": "g", "P": "Q", "E": "E", "N": "N", "D": "D", "F": "F", "g": "d", "k": "k", "Y": "G"}


def field(*bands, vertical=False):
    """Equal stripes of base colours, e.g. field("R", "w", "R")."""
    g = [[""] * FW for _ in range(FH)]
    n = len(bands)
    for y in range(FH):
        for x in range(FW):
            i = (x * n // FW) if vertical else (y * n // FH)
            g[y][x] = bands[i]
    return g


def charge(g, rows, ox, oy):
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c != ".":
                g[oy + y][ox + x] = c
    return g


def centred(g, rows, cy=None):
    w, h = max(len(r) for r in rows), len(rows)
    return charge(g, rows, (FW - w) // 2, (FH - h) // 2 if cy is None else cy)


def bevel(f):
    g = blank(FW + 2, FH + 2)
    for x in range(FW + 2):
        g[0][x] = g[FH + 1][x] = "k"
    for y in range(FH + 2):
        g[y][0] = g[y][FW + 1] = "k"
    for y in range(FH):
        for x in range(FW):
            c = f[y][x]
            top_left = (y == 0 or x == 0) and not (y == FH - 1 or x == FW - 1)
            bottom_right = (y == FH - 1 or x == FW - 1) and not (y == 0 or x == 0)
            if top_left:
                c = LIGHT.get(c, c)
            elif bottom_right:
                c = DARK.get(c, c)
            g[y + 1][x + 1] = c
    return g


FLEUR = ["...Y...", "..YGG..", "Y.YGD.G", "GG.G.GD", ".GGGGD.", "..G.D.."]
LION_RAMPANT = [  # facing the hoist, 10x12, with crown
    "..Y.Y.....",
    "..GYG.....",
    ".www......",
    "wwwwa.w...",
    ".wwwwww...",
    "..wwwa....",
    "..wwwww..w",
    "...wwwwa.w",
    "...wwwwwwa",
    "..www.ww..",
    ".ww....ww.",
    "..........",
]
EAGLE2 = [  # double-headed eagle with raised wings, 16x11
    "Y..............D",
    "YG..YG....GY..GD",
    "YG.YGGD..YGGD.GD",
    "YGG..GD..GD..GGD",
    "YGGG.GGGGGG.GGGD",
    ".YGGGGGGGGGGGGD.",
    "..YGGGGGGGGGGD..",
    "....GGGGGGGG....",
    ".....GGGGGG.....",
    "....GD.GG.GD....",
    "......GGGD......",
]
CASTLE = ["Y.G.G.G", "YGGGGGD", ".GGEGD.", ".GGEGD.", "YGGGGGD"]
LION_SMALL = [".UU..", "UUU.U", ".UUU.", ".UUUU", "U..U."]

FLAGS = {}

f = field("w")
for y in range(FH):
    for x in (9, 10, 11, 12):
        f[y][x] = "R"
for y in (5, 6, 7, 8):
    for x in range(FW):
        f[y][x] = "R"
FLAGS["ENG"] = (f, "England – St George's cross (simplified from the 1444 royal arms)")

f = field("G")
x = 0
for i, w in enumerate([2, 3, 2, 3, 2, 3, 2, 3, 2]):  # 5 gold, 4 red pallets
    for xx in range(x, x + w):
        for y in range(FH):
            f[y][xx] = "R" if i % 2 else "G"
    x += w
FLAGS["NAP"] = (f, "Naples – Aragonese pallets, gold and red (Alfonso V, 1442)")

FLAGS["HAB"] = (field("R", "w", "R"), "Austria – red-white-red")

f = field("R")
centred(f, LION_RAMPANT, cy=1)
FLAGS["BOH"] = (f, "Bohemia – white lion rampant, crowned, on red")

f = field("R")
centred(f, EAGLE2, cy=2)
FLAGS["RUS"] = (f, "Russia/Muscovy – gold double-headed eagle on red (simplified)")

f = [[("R" if (x < 11) == (y < 7) else "w") for x in range(FW)] for y in range(FH)]
charge(f, CASTLE, 2, 1)
charge(f, CASTLE, 13, 8)
charge(f, LION_SMALL, 14, 1)
charge(f, LION_SMALL, 3, 8)
FLAGS["SPA"] = (f, "Spain/Castile – quartered castles and lions (simplified)")


# ---------------------------------------------------------------- minor nations
# Simplified heraldry on the same field and palette. Accuracy is secondary to telling
# neighbours apart on the map panel.

def recolor(rows, m):
    return ["".join(m.get(c, c) for c in r) for r in rows]


TO_WHITE = {"Y": "w", "G": "w", "D": "a", "w": "w", "a": "a"}
TO_INK = {"Y": "k", "G": "k", "D": "k", "w": "k", "a": "k"}
TO_RED = {"Y": "r", "G": "R", "D": "E", "w": "R", "a": "E"}
TO_GOLD = {"w": "G", "a": "D"}
TO_BLUE = {"w": "B", "a": "N", "U": "B"}

CRESCENT = ["..GGG.", ".GD...", "GD....", "GD....", "GD....", ".GD...", "..GGG."]
HARP = ["YGGGGGD.", "YG.w.wGD", "Y..w.w.G", "Y..w.wG.", "Y..wwG..", "Y..wG...", "YG.G....", "YGD....."]
COLUMNS = ["YGGGGGD", "YG...GD", "YGGGGGD", "..YGD..", "..YGD.."]
BULL = ["Y.....D", "YG...GD", ".YGGGD.", ".GkGkG.", "..GGG..", "..DRD.."]
TAMGA = ["G..G..G", "G..G..G", "GGGGGGG", "...G...", "...G...", "..GGG.."]
CROWN = ["Y.G.D", "YGGGD"]
SWORD = ["..w..", "..w..", "..w..", "..w..", "..a..", "GGGGG", "..O..", "..O.."]


def solid(c):
    return field(c)


def cross(f, c, t=4, cx=None, cy=None, couped=0):
    cx = FW // 2 if cx is None else cx
    cy = FH // 2 if cy is None else cy
    for y in range(FH):
        for x in range(FW):
            inx = cx - t // 2 <= x < cx + (t + 1) // 2
            iny = cy - t // 2 <= y < cy + (t + 1) // 2
            if couped and not (couped <= x < FW - couped and couped - 4 <= y < FH - couped + 4):
                continue
            if couped and inx and not (couped - 4 <= y < FH - couped + 4):
                continue
            if (inx and (not couped or 2 <= y < FH - 2)) or (iny and (not couped or couped <= x < FW - couped)):
                f[y][x] = c
    return f


def saltire(f, c):
    for y in range(FH):
        for x in range(FW):
            u = x * FH / FW
            if abs(u - y) < 1.6 or abs(u - (FH - 1 - y)) < 1.6:
                f[y][x] = c
    return f


def bend(f, c, w=2.2):
    for y in range(FH):
        for x in range(FW):
            if abs(x * FH / FW - y) < w:
                f[y][x] = c
    return f


def border(f, c, t=2):
    for y in range(FH):
        for x in range(FW):
            if x < t or y < t or x >= FW - t or y >= FH - t:
                f[y][x] = c
    return f


def per_pale(a, b):
    return [[a if x < FW // 2 else b for x in range(FW)] for y in range(FH)]


def stripes(cols, n, vertical=False):
    return field(*[cols[i % len(cols)] for i in range(n)], vertical=vertical)


def lozenges(a, b):
    return [[a if ((x + y) // 4 + (x - y + 40) // 4) % 2 else b for x in range(FW)] for y in range(FH)]


def ermine(base="w"):
    f = field(base)
    for y in range(1, FH - 1, 4):
        for x in range((y // 4) % 2 * 3 + 1, FW - 1, 6):
            f[y][x] = f[y + 1][x] = "k"
            if x + 1 < FW:
                f[y + 1][x + 1] = "k"
            f[y + 1][x - 1] = "k"
    return f


def nordic(f, c, t=3):
    return cross(f, c, t, cx=8)


M = {}
M["SCO"] = (saltire(solid("B"), "w"), "Scotland – saltire")
M["IRE"] = (centred(solid("L"), HARP, cy=3), "Irish lords – gold harp on green")
M["BRI"] = (ermine(), "Brittany – ermine")
M["BUR"] = (saltire(solid("w"), "R"), "Burgundy – red saltire on white")
f = field("G", "G", "R")
for y in range(5, FH):
    for x in range(FW):
        f[y][x] = "R" if (x // 3) % 2 else "G"
for y in range(5):
    for x in range(FW):
        f[y][x] = "B"
M["PRV"] = (charge(f, ["Y.G.D", ".YGD.", "..D.."], 9, 1), "Provence – Anjou chief over Aragonese pallets")
M["SAV"] = (cross(solid("R"), "w", 4), "Savoy – white cross on red")
f = field("G")
x = 0
for i, w in enumerate([2, 3, 2, 3, 2, 3, 2, 3, 2]):
    for xx in range(x, x + w):
        for y in range(FH):
            f[y][xx] = "R" if i % 2 else "G"
    x += w
M["ARA"] = (f, "Aragón – four red pallets on gold")
M["NAV"] = (border(cross(saltire(solid("R"), "G"), "G", 2), "G", 1), "Navarre – gold chains on red")
f = border(solid("w"), "R", 2)
M["POR"] = (charge(f, ["BBBBBB", "BwBBwB", "BBBBBB", "BwBBwB", ".BBBB.", "..BB.."], 8, 4), "Portugal – blue shield, red border")
M["GRA"] = (bend(solid("R"), "G"), "Granada – Nasrid gold bend on red")
f = solid("R")
for y in range(FH):
    for x in range(FW):
        u = x * FH / FW
        if abs(u - y) < 1.0 and 2 <= y < FH - 2:
            f[y][x] = "G"
        elif abs(u - (FH - 1 - y)) < 1.0 and 2 <= y < FH - 2:
            f[y][x] = "w"
charge(f, ["GG", "G."], 2, 1)
charge(f, ["ww", ".w"], 18, 1)
M["PAP"] = (f, "Papal States – crossed keys, gold and silver, on red")
M["TUS"] = (centred(solid("w"), recolor(FLEUR, TO_RED), cy=4), "Florence – red lily on white")
f = solid("w")
snake = ["YGGGD.", ".BBBB.", "BB..BB", "BB....", ".BBB..", "...BB.", "....BB", "BB..BB", ".BBBB."]
M["MLO"] = (centred(f, snake, cy=2), "Milan – crowned Visconti serpent")
M["GEN"] = (border(cross(solid("w"), "R", 2), "R", 1), "Genoa – cross of St George, bordered")
M["VEN"] = (centred(solid("R"), recolor(LION_RAMPANT, {"w": "G", "a": "D"}), cy=1), "Venice – gold lion of St Mark on red")
M["BAV"] = (lozenges("B", "w"), "Bavaria – blue and white lozenges")
f = stripes(["G", "k"], 7)
M["SAX"] = (bend(f, "L", 1.4), "Saxony – barry gold and black, green crancelin")
M["BRA"] = (centred(solid("w"), recolor(EAGLE2, TO_RED), cy=2), "Brandenburg – red eagle on white")
f = field("w")
for y in range(4):
    for x in range(FW):
        f[y][x] = "R"
for ox in (4, 9, 14):
    charge(f, CROWN, ox, 1)
M["KOL"] = (f, "Cologne – red chief with three crowns")
M["PAL"] = (centred(solid("k"), recolor(LION_RAMPANT, {"w": "G", "a": "D"}), cy=1), "Palatinate – gold lion on black")
f = solid("G")
for y in (3, 7, 11):
    for x in range(4, 18):
        f[y][x] = "k"
    for x in range(5, 18, 3):
        f[y - 1][x] = "k"
M["WUR"] = (f, "Württemberg – three stag antlers")
f = per_pale("G", "R")
for y in range(FH):
    for x in range(FW // 2, FW):
        if (x + y) % 6 < 3:
            f[y][x] = "w"
M["NUR"] = (f, "Nuremberg – gold half and red-white bends")
M["HES"] = (centred(solid("B"), recolor(LION_RAMPANT, {"a": "R"}), cy=1), "Hesse – barred lion on blue")
f = solid("R")
charge(f, recolor(LION_SMALL, {"U": "G"}), 5, 4)
charge(f, recolor(LION_SMALL, {"U": "G"}), 12, 4)
M["LUN"] = (f, "Brunswick-Lüneburg – gold lions on red")
M["HSA"] = (field("w", "R"), "Hanse – white over red")
M["POM"] = (centred(solid("w"), recolor(LION_RAMPANT, TO_RED), cy=1), "Pomerania – red griffin on white")
M["SWI"] = (cross(solid("R"), "w", 4, couped=6), "Swiss Confederation – couped white cross on red")
M["TEU"] = (cross(solid("w"), "k", 4), "Teutonic Order – black cross on white")
M["POL"] = (centred(solid("R"), recolor(EAGLE2, TO_WHITE), cy=2), "Poland – white eagle on red")
M["LIT"] = (centred(solid("R"), COLUMNS, cy=4), "Lithuania – Columns of Gediminas")
M["HUN"] = (stripes(["R", "w"], 7), "Hungary – Árpád stripes")
M["RYA"] = (field("L", "G", "L", vertical=True), "Ryazan – green and gold")
M["NOV"] = (charge(field("w", "B"), ["YGGD", "YGGD", "DDDD"], 9, 5), "Novgorod – white and blue with gold throne")
M["KAZ"] = (centred(solid("L"), recolor(CRESCENT, TO_WHITE), cy=3), "Kazan – white crescent on green")
M["CRI"] = (centred(solid("B"), TAMGA, cy=4), "Crimea – gold tamga on blue")
M["LIV"] = (centred(cross(solid("w"), "R", 2, cx=6), SWORD, cy=3), "Livonian Order – red cross and sword")
M["DAN"] = (nordic(solid("G"), "R"), "Kalmar Union – red Nordic cross on gold")
M["TUR"] = (centred(solid("R"), recolor(CRESCENT, TO_WHITE), cy=3), "Ottomans – white crescent on red")
f = cross(solid("R"), "G", 2)
for ox, oy in ((4, 2), (15, 2), (4, 9), (15, 9)):
    charge(f, ["GG", "G.", "GG"], ox, oy)
M["BYZ"] = (f, "Byzantium – Palaiologos cross with four betas")
M["SER"] = (centred(solid("R"), recolor(EAGLE2, TO_WHITE), cy=2), "Serbia – white double eagle on red")
M["BOS"] = (bend(solid("B"), "w", 1.6), "Bosnia – white bend on blue")
M["WAL"] = (centred(solid("B"), EAGLE2, cy=2), "Wallachia – gold eagle on blue")
M["MOL"] = (centred(per_pale("R", "B"), BULL, cy=4), "Moldavia – aurochs head")
M["ALB"] = (centred(solid("R"), recolor(EAGLE2, TO_INK), cy=2), "Albania – black double eagle on red")
# the south and east (map extension): Anatolia, Caucasus, Levant, Maghreb
M["KAR"] = (centred(solid("L"), recolor(CRESCENT, TO_GOLD), cy=3), "Karaman – gold crescent on green (simplified)")
M["CND"] = (centred(field("O", "G", "O"), recolor(CRESCENT, TO_INK), cy=3), "Candar – black crescent on gold and brown")
M["DUL"] = (centred(solid("O"), recolor(CRESCENT, TO_WHITE), cy=3), "Dulkadir – white crescent on brown")
M["TRE"] = (centred(solid("U"), recolor(EAGLE2, TO_GOLD), cy=2), "Trebizond – gold single eagle on purple (as double eagle)")
M["AKK"] = (field("w", "a", "w"), "Aq Qoyunlu – the White Sheep, plain white")
M["QAR"] = (centred(field("k", "d", "k"), recolor(CRESCENT, TO_WHITE), cy=3), "Qara Qoyunlu – the Black Sheep, white crescent on black")
f = cross(solid("w"), "R", 4)
for ox, oy in ((3, 2), (16, 2), (3, 9), (16, 9)):
    charge(f, ["R.R", ".R.", "R.R"], ox, oy)
M["GEO"] = (f, "Georgia – St George's cross with four small crosses")
M["SHI"] = (field("B", "w", "L"), "Shirvan – blue, white, green (simplified)")
M["CIR"] = (charge(solid("L"), ["G.G.G", "G.G.G", "G.G.G"], 8, 2), "Circassia – gold arrows on green (simplified)")
M["MAM"] = (centred(solid("G"), recolor(CRESCENT, TO_WHITE), cy=3), "Mamluks – white crescent on gold")
M["TUN"] = (stripes(["Y", "R", "Y"], 3), "Hafsids – gold and red bands (simplified)")
M["TLE"] = (centred(field("w", "L"), recolor(CRESCENT, TO_RED), cy=3), "Tlemcen – red crescent on white and green (simplified)")
M["MOR"] = (border(solid("R"), "L", 2), "Morocco – red field with green border (simplified)")
M["CYP"] = (cross(solid("w"), "G", 4), "Cyprus – gold cross of Jerusalem on white (simplified)")
M["KNI"] = (cross(solid("R"), "w", 3), "Knights Hospitaller – white cross on red")
FLAGS.update(M)

# Naples: Aragon pallets impaled with Anjou (blue with gold fleur), to differ from Aragón
f = FLAGS["NAP"][0]
for y in range(FH):
    for x in range(FW // 2, FW):
        f[y][x] = "B"
charge(f, FLEUR, 13, 4)
FLAGS["NAP"] = (f, "Naples – Aragon pallets impaled with Anjou (simplified)")

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for tag, (f, comment) in FLAGS.items():
        write(os.path.join(OUT, "flag_%s.txt" % tag), bevel(f), "flag_%s – %s\n24x16 grid, export x2 = 48x32. Generated by tools/art/flags.py" % (tag, comment))
    print(" ".join(FLAGS))
