"""Tab and popup icons (16x16 grid). Writes assets/src/pixel/icons/<key>.txt. Run tools/build_art.sh after."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixlib import blank, paste, layer, stack, outline, write
import hud_icons  # reuses the HUD shapes (mil swords, dip dove)

OUT = hud_icons.OUT
ICONS = {}

# tab_nation: gold crown with gems
ICONS["tab_nation"] = (layer([
    ".Y...YY...D.",
    ".YG..YG..GD.",
    ".YGG.YG.GGD.",
    ".YGGGYGGGGD.",
    ".YGGGGGGGGD.",
    "YYYYYYGGGGGD",
    "YRGGGBBGGGRD",
    "YGGGGGGGGGGD",
    "DDDDDDDDDDDD",
], 2, 4), "tab_nation – nation overview: gold crown")

# tab_diplomacy: sealed letter
ICONS["tab_diplomacy"] = (layer([
    "PPPPPPPPPPPP",
    "QPPPPPPPPPPQ",
    "PQPPPPPPPPQP",
    "PPQPPPPPPQPP",
    "PPPQPrRPQPPP",
    "PPPPQRRQPPPP",
    "PPPPPEEPPPPP",
    "PPPPPPPPPPPP",
    "QQQQQQQQQQQQ",
], 2, 4), "tab_diplomacy – diplomacy: sealed letter")

# tab_missions: archery target with arrow
t = blank()
for y in range(16):
    for x in range(16):
        d = math.hypot(x - 7.5, y - 8.5)
        if d < 6.2:
            t[y][x] = "R" if d >= 4.6 else "w" if d >= 3.1 else "R" if d >= 1.6 else "G"
for y in range(16):
    for x in range(16):  # shading: lower-right ring pixels darker
        if t[y][x] == "R" and x + y > 18:
            t[y][x] = "E"
        elif t[y][x] == "w" and x + y > 18:
            t[y][x] = "a"
target = outline(t)
arrow = blank()
for i in range(4):
    arrow[4 + i][11 - i] = "O"
arrow[2][13] = arrow[3][12] = arrow[2][12] = arrow[3][13] = "w"
ICONS["tab_missions"] = (stack(target, outline(arrow)), "tab_missions – missions: target with arrow")

# tab_log: open chronicle book
ICONS["tab_log"] = (layer([
    "QPPPP..PPPPQ",
    "PQQQPQQPQQQP",
    "PPPPPQQPPPPP",
    "PQQQPQQPQQQP",
    "PPPPPQQPPPPP",
    "PQQPPQQPQQPP",
    "PPPPPQQPPPPP",
    "OOOOPPPPOOOO",
    "HHHHHHHHHHHH",
], 2, 4), "tab_log – chronicle: open book")

# tab_mapmode: folded map, three panels
ICONS["tab_mapmode"] = (layer([
    "PPPPQQQQPPPP",
    "PLLPQQNQPPBP",
    "LLLLFQNNPBBP",
    "PLLLFFQNPBPP",
    "PPLLQFFQLPPP",
    "PPPLQQFFLLPP",
    "PBPPQQQFLLLP",
    "BBPPNQQQPLLP",
    "BBBPNNQQPPRP",
    "PPPPQQQQPPPP",
], 2, 3), "tab_mapmode – map modes: folded map")

# event: gold bell (news / something happened)
ICONS["event"] = (layer([
    ".....YD.....",
    "....Y..D....",
    ".....YG.....",
    "....YGGD....",
    "...YGGGGD...",
    "...YGGGGD...",
    "..YGGGGGGD..",
    "..YGGGGGGD..",
    ".YGGGGGGGGD.",
    "YYGGGGGGGGDD",
    "DDDDDDDDDDDD",
    ".....DD.....",
], 2, 2), "event – event popup: gold bell")

# peace: the dove (same art as dip, like the emoji it replaces)
ICONS["peace"] = (hud_icons.ICONS["dip"][0], "peace – peace treaty: dove (same art as dip)")

# war / tab_wars: crossed swords on a red disc
disc = blank()
for y in range(16):
    for x in range(16):
        d = math.hypot(x - 7.5, y - 7.5)
        if d < 5.4:
            disc[y][x] = "r" if x + y < 11 else "E" if x + y > 19 else "R"
for sw in (hud_icons.sword(True, False), hud_icons.sword(False, False)):
    paste(disc, ["".join(r) for r in sw])  # swords as interior detail: no own outline
war = outline(disc)
ICONS["war"] = (war, "war – war declared: crossed swords on a red disc")
ICONS["tab_wars"] = (war, "tab_wars – wars tab: same art as war")

# coalition: three overlapping shields
def small_shield(c, s, l, ox, oy):
    return layer([l + c * 4 + s, l + c * 4 + s, l + c * 4 + s, l + c * 4 + s, "." + l + c * 2 + s + ".", ".." + c + s + ".."], ox, oy)
ICONS["coalition"] = (stack(small_shield("B", "N", "b", 2, 2), small_shield("L", "F", "l", 8, 2),
                            small_shield("R", "E", "r", 5, 7)), "coalition – coalition formed: three allied shields")

# vassal: small shield under an overlord's gold crown
vcrown = layer([
    "Y..YD..D",
    "YG.YG.GD",
    "YGGGGGGD",
    "YRGBBGRD",
    "DDDDDDDD",
], 4, 1)
vshield = layer([
    "bBBBBBN",
    "bBBBBBN",
    "bBBBBBN",
    "bBBBBBN",
    ".bBBBN.",
    "..bBN..",
], 4, 8)
ICONS["vassal"] = (stack(vshield, vcrown), "vassal – subject state: small shield under a gold crown")

# annex: large shield absorbing a small one (small shield set into the big one)
ICONS["annex"] = (stack(layer([
    "aaaaaaaaaaaa",
    "aRRRRRRRRRRg",
    "arRRRRRRRREg",
    "arRRRRRRRREg",
    "arRRRRRRRREg",
    "arRRRRRRRREg",
    "arRRRRRRRREg",
    ".arRRRRRREg.",
    ".arRRRRRREg.",
    "..arRRRREg..",
    "...arRREg...",
    "....aggg....",
], 2, 2), layer([
    "bBBBBN",
    "bBBBBN",
    "bBBBBN",
    ".bBBN.",
    "..BN..",
], 5, 5)), "annex – annexation: small shield set into a larger one")

# tab_tech: brass astrolabe (ring, cross bars, pointer) on a small stand
ICONS["tab_tech"] = (layer([
    "...YYYYYD...",
    "..YG....GD..",
    ".YG..Y...GD.",
    "YG...YD...GD",
    "YG...YD...GD",
    "YYYYYGGDDDDD",
    "YG...YD.Ow.D",
    "YG...YD.O..D",
    ".YG..YD.O.D.",
    "..YG..OOODD.",
    "...YGGGGDD..",
    ".....OH.....",
], 2, 2), "tab_tech – technology: brass astrolabe")

# tab_government: scales of justice under a small crown
ICONS["tab_government"] = (layer([
    "....Y.Y.Y...",
    "....YGGGD...",
    "YYYYYGGDDDDD",
    "Y....OH....D",
    "Y....OH....D",
    "Y....OH....D",
    "YGD..OH..YGD",
    "DDD..OH..DDD",
    ".....OH.....",
    ".....OH.....",
    "...OOOOHH...",
], 2, 2), "tab_government – government: gold scales under a crown")

# advisor: bust with a purple scholar's cap and robe
ICONS["advisor"] = (layer([
    "...UUUUUU...",
    "..uUUUUUUV..",
    "..UUUUUUUV..",
    "...tSSSSs...",
    "...tkSSks...",
    "...tSSSSs...",
    "....SSss....",
    "..uUUPPUUV..",
    ".uUUUPPUUUV.",
    "uUUUUPPUUUUV",
    "uUUUUPPUUUUV",
], 2, 3), "advisor – advisor: scholar bust with purple cap")

# company: trade company money sack with a red seal
ICONS["company"] = (layer([
    "....HOOH....",
    ".....OH.....",
    "....oOOH....",
    "...oOOOOH...",
    "..oOOOOOOH..",
    ".oOOOrROOOH.",
    ".oOOrRREOOH.",
    ".oOOOREEOOH.",
    ".oOOOOOOOOH.",
    "..HHHHHHHH..",
], 2, 3), "company – trade company: money sack with red seal")

# law: sealed decree, paper sheet with text lines and a hanging wax seal
ICONS["law"] = (layer([
    "PPPPPPPPPPQ.",
    "PQQQQQQQPPQ.",
    "PPPPPPPPPPQ.",
    "PQQQQQQPPPQ.",
    "PPPPPPPPPPQ.",
    "PQQQQQQQPPQ.",
    "PPPPPPPPPPQ.",
    "PQQQQPrRRPQ.",
    "PPPPPrRRREQ.",
    "QQQQQQRREQQ.",
    "......BN....",
    ".....BN.BN..",
], 2, 2), "law – law: decree with wax seal")

# tech_special: gold star inside a green laurel wreath (national technology)
ICONS["tech_special"] = (layer([
    "lL...Y....Ll",
    "lL..YGD...Ll",
    "L.YYYGGDDD.F",
    "lL.YGGGGD.LF",
    "L...YGGD...F",
    "lL.YGD.GD.LF",
    ".L.YD...D.F.",
    ".lL......LF.",
    "..lLL..LLF..",
    "....LLLF....",
], 2, 3), "tech_special – national technology: gold star in a laurel wreath")

for key, (g, comment) in ICONS.items():
    write(os.path.join(OUT, key + ".txt"), g, comment + "\n16x16 grid, export x2 = 32 px. Generated by tools/art/ui_icons.py")
print(" ".join(ICONS))
