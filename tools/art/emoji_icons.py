"""Pixel-art replacements for every emoji the UI uses (16x16 grid, rendered 1:1 into a bitmap font).

Writes assets/src/pixel/emoji/<name>.txt and assets/art/emoji/emoji.json (codepoint -> name).
tools/build_art.sh renders the grids to assets/art/emoji/<name>.png at scale 1; at runtime
scripts/ui/pixel_emoji.gd turns them into a FontFile that sits in front of Noto Color Emoji, so
every Label, Button and draw_string shows pixel art without touching the strings.
Emojis that already have an icon reuse its grid (REUSE).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import blank, layer, stack, outline, write  # noqa: E402
import hud_icons  # noqa: E402
import ui_icons  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SRC = os.path.join(ROOT, "assets", "src", "pixel", "emoji")
OUT = os.path.join(ROOT, "assets", "art", "emoji")
ICON_SRC = os.path.join(ROOT, "assets", "src", "pixel", "icons")

# emoji -> existing icon grid in assets/src/pixel/icons
REUSE = {
    "💰": "gold", "📜": "adm", "🕊": "dip", "⚔": "mil", "👥": "manpower", "🛡": "army", "😠": "ae",
    "⭐": "prestige", "🏘": "dev", "🏰": "fort", "📅": "date", "🔥": "siege", "🎯": "tab_missions",
    "📯": "event", "👑": "tab_nation", "🤝": "tab_diplomacy", "🗺": "tab_mapmode", "⛓": "vassal",
    "⚠": "coalition", "📂": "tab_log", "🔬": "tab_tech", "⚖": "tab_government",
    "🎓": "advisor", "🏦": "company",
}

E = {}  # emoji -> (name, grid)


def add(ch, name, g):
    E[ch] = (name, g)


# ---- plain UI glyphs
add("➖", "minus", layer(["wwwwwwwwww", "aaaaaaaaaa"], 3, 7))
add("➕", "plus", layer(["....ww....", "....ww....", "....ww....", "....ww....", "wwwwwwwwww", "wwwwwwwwww", "....ww....", "....ww....", "....ww....", "....ww...."], 3, 3))
add("☰", "menu", layer(["wwwwwwwwww", "aaaaaaaaaa", "..........", "..........", "wwwwwwwwww", "aaaaaaaaaa",
                        "..........", "..........", "wwwwwwwwww", "aaaaaaaaaa"], 3, 3))
X = ["ww......ww", "www....www", ".www..www.", "..wwwwww..", "...wwww...", "...wwww...",
     "..wwwwww..", ".www..www.", "www....www", "ww......ww"]
add("✖", "close", layer(X, 3, 3))
add("❌", "cross_red", layer([r.replace("w", "R") for r in X], 3, 3))
add("✗", "cross_small", layer([r.replace("w", "R") for r in X[2:8]], 5, 5))
add("✅", "check", layer(["LLLLLLLLLLLL", "LLLLLLLLLwLL", "LLLLLLLLwwLF", "LLLLLLLwwLLF", "LwLLLLwwLLLF",
                          "LwwLLwwLLLLF", "LLwwwwLLLLLF", "LLLwwLLLLLLF", "LLLLLLLLLLLF", "LLLLLLLLLLLF",
                          "FFFFFFFFFFFF"], 2, 2))
add("▶", "play", layer(["ww......", "wwww....", "wwwwww..", "wwwwwwww", "wwwwwwww", "wwwwwwa.", "wwwwa...", "wwa....."], 5, 4))
add("▼", "down", layer(["wwwwwwww", "wwwwwwww", "awwwwwwa", ".wwwwww.", ".awwwwa.", "..wwww..", "..awwa..", "...ww..."], 4, 5))
add("◀", "back", layer(["......ww", "....wwww", "..wwwwww", "wwwwwwww", "wwwwwwww", ".awwwwww", "...awwww", ".....aww"], 3, 4))
add("⬅", "arrow_left", layer(["...Y......", "..YG......", ".YGGGGGGGG", "YGGGGGGGGG", ".DGDDDDDDD", "..DD......", "...D......"], 3, 4))
add("⏸", "pause", layer(["www..www", "wwa..wwa", "wwa..wwa", "wwa..wwa", "wwa..wwa", "wwa..wwa", "wwa..wwa", "aaa..aaa"], 4, 4))
add("●", "dot", layer([".rR.", "rRRE", "RRRE", ".EE."], 6, 6))
for ch, name, c, s in (("🟩", "sq_green", "L", "F"), ("🟦", "sq_blue", "B", "N"), ("🟥", "sq_red", "R", "E"),
                       ("🟧", "sq_orange", "G", "D"), ("🟪", "sq_purple", "U", "V")):
    add(ch, name, layer([c * 9 + s] * 9 + [s * 10], 3, 3))

# ---- objects
add("🔍", "magnifier", layer([".aaaa.....", "abbbba....", "abBbBba...", "abbBbBa...", "abBbBba...",
                              ".agggd....", "....ddO...", ".....OOH..", "......OOH.", ".......HH."], 3, 3))
add("🔠", "letters", layer(["...PP.......", "..PPPQ......", ".PPQPPQ.....", ".PPQPPQ.....", ".PPPPPQ.GGG.", ".PPQPPQGD..G", ".PPQPPQGD..G", "......GGGGG.", "......GD...G", "......GGGGG."], 2, 3))
add("🌍", "globe", layer(["...BBBBB...", ".BBLLBBBBB.", ".BLLLLBBLB.", "BBLLLBBLLLB", "BBBLLBBLLLN",
                          "BBBBLBBBLBN", "BBBBBBBLLBN", ".BBBBBBLLN.", ".NBBBBBBNN.", "...NNNNN..."], 2, 3))
add("💾", "save_book", layer(["HOOOOOOOOH", "HOooooooOH", "HOoGGGGoOH", "HOoGDDGoOH", "HOoGGGGoOH",
                              "HOooooooOH", "HOOOOOOOOH", "HPPPPPPPPH", "HQQQQQQQQH", "HHHHHHHHHH"], 3, 3))
add("🤖", "gear", layer(["...aa.aa...", "...aaaag...", ".aaaaaaagg.", "aaaa...aggd", ".aa.....gd.",
                         ".aa.....gd.", "aagg...gggd", ".agggggggd.", "...ggggd...", "...dd.dd..."], 3, 3))
add("✊", "fist", layer(["..SSSSSS..", ".SSsSsSsS.", ".SSSSSSSSs", ".SSsSsSsSs", "SSSSSSSSSs",
                         "SSSSSSSSs.", ".SSSSSSSs.", "..ssssss..", "..RRRRRE..", "..RRRRRE.."], 3, 3))
add("🏳", "white_flag", layer(["Owwwwwwa..", "Owwwwwwwa.", "Owwwwwwwwa", "Owwwwwwwa.", "Owwwwwwa..",
                               "Oaaaaaa...", "O.........", "O.........", "O.........", "H........."], 3, 3))
add("🏛", "palace", layer(["....PP....", "..PPPPQQ..", "PPPPPPPPQQ", "QQQQQQQQQQ", ".P.P..P.P.",
                           ".PQPQ.PQPQ", ".PQPQ.PQPQ", ".PQPQ.PQPQ", "PPPPPPPPPQ", "QQQQQQQQQQ"], 3, 3))
add("💸", "debt", stack(layer([".GGGG.", "GYGGGD", "GYDDGD", "GYGGGD", ".DDDD."], 2, 3), layer(
    ["..R..", "..R..", "..R..", "RRRRR", ".RRR.", "..R.."], 9, 6)))
add("💡", "candle", layer(["...Y..", "..YGY.", "..GRG.", "...D..", ".PPPP.", ".PPPQ.", ".PPPQ.", ".PPPQ.", ".PPPQ.", "OOOOOH"], 5, 2))
add("👆", "hand_up", layer(["...SS...", "...Ss...", "...Ss...", "...SsSS.", ".SSSsSsS", "SSSSSSSs", "SSSSSSSs", ".SSSSSs.", "..SSSs..", "..RRRE.."], 4, 3))
add("👉", "hand_right", layer(["..........", "..SSSSSSSS", "SSSSSSssss", "SSSSSS....", "SSSSSs....", "SSSSs.....", "RRSs......", "RE........"], 3, 4))
add("✋", "hand_stop", layer([".S.S.S.S.", ".S.S.S.S.", ".SsSsSsS.", ".SSSSSSS.", "SSSSSSSSs", ".SSSSSSSs", ".SSSSSSs.", "..SSSSs..", "..RRRRE..", "..RRRRE.."], 3, 3))
add("🔊", "horn", layer(["........w.", "......w..w", "GG...Gw.w.", "GYGGGGD.w.", "GYGGGGD.w.", "GG...Gw.w.", "......w..w", "........w."], 3, 4))
add("🏠", "home", layer(["....rR....", "...rRRE...", "..rRRRRE..", ".rRRRRRRE.", "rRRRRRRRRE", ".PPPPPPPQ.", ".PbbPOOPQ.", ".PbbPOOPQ.", ".PPPPOOPQ.", ".PPPPOHPQ."], 3, 3))
add("🚪", "door", layer(["..OOOOO...", ".OOoOoOO..", ".OoOoOoH..", ".OoOoOoH..", ".OoOoOoH..", ".OoOoGoH..", ".OoOoOoH..", ".OoOoOoH..", ".OoOoOoH..", "HHHHHHHHH."], 3, 3))
add("🏁", "finish", layer(["Owkwkwkw..", "Okwkwkwk..", "Owkwkwkw..", "Okwkwkwk..", "O.........", "O.........", "O.........", "O.........", "O.........", "H........."], 3, 3))
SKULL = ["..wwwwww..", ".wwwwwwwa.", "wwwwwwwwwa", "wwkkwwkkwa", "wwkkwwkkwa", ".wwwkkwwa.", "..wwwwwa..", "..wawawa..", "..aaaaaa.."]
add("💀", "skull", layer(SKULL, 3, 3))
add("☠", "skull_bones", stack(layer(["w........w", ".w......w.", "..........", ".w......w.", "w........w"], 3, 9), layer(SKULL[:7], 3, 2)))
add("🏆", "trophy", layer(["YGGGGGGGGD", "YGGGGGGGGD", "GYGGGGGGDG", "G.YGGGGD.G", ".GYGGGGDG.", "...YGGD...", "....GD....", "....GD....", "..YGGGGD..", "..DDDDDD.."], 3, 3))
add("🚶", "boots", layer(["..HHHH....", "..HOOH....", "..HOOH....", "..HOOH....", "..HOOH....", "..HOOOH...", "..HOOOOHH.", ".HOOOOOOOH", ".HHHHHHHHH", ".dd....dd."], 3, 3))
add("📍", "pin", layer(["..rRRR..", ".rRRRRE.", "rRwwRRRE", "rRwRRRRE", "rRRRRRRE", ".RRRRRE.", "..RRRE..", "...RE...", "...E....", "...E...."], 4, 3))
add("🔨", "hammer", layer(["aaaaaag...", "awwwaagd..", "aaaaaggd..", "....OH....", "....OH....", "....OH....", "....OH....", "....OH....", "....OH....", "....HH...."], 3, 3))
add("🏗", "bricks", layer(["RRRERRRERR", "EEEEEEEEEE", "RERRRERRRE", "EEEEEEEEEE", "RRRERRRERR", "EEEEEEEEEE", "RERRRERRRE", "EEEEEEEEEE"], 3, 5))
add("✂", "shears", layer(["aa......aa", ".aa....aa.", "..aa..aa..", "...aaaa...", "....gg....", "...gggg...", "..RR..RR..", ".R..R.R..R", ".R..R.R..R", "..RR...RR."], 3, 3))
add("🔗", "link", layer(["..GGGG....", ".G....G...", "G...GGGGD.", "G..G.G..D.", ".G.G.G..D.", "..GD..D.D.", "....DDDD..", "....DD...."], 3, 4))
add("🛑", "stop", layer(["..RRRRRR..", ".RRRRRRRR.", "RRRRRRRRRE", "RRRRRRRRRE", "RwwwwwwwwE", "RaaaaaaaaE", "RRRRRRRRRE", "RRRRRRRRRE", ".EEEEEEEE.", "..EEEEEE.."], 3, 3))
add("😩", "tired", layer(["...PPPPP....", ".PPPPPPPPQ..", ".PPPPPPPPPQ.", "PPkkPPPkkPPQ", "PPPPPPPPPPPQ", "PPPPPPPPPPPQ", "PPPPkkkkPPPQ", "PPPkPPPPkPPQ", ".PPPPPPPPPQ.", ".PbPPPPPPQ..", "..bQQQQQQ..."], 2, 2))
add("📈", "chart", layer(["PPPPPPPPPP", "PQPPPPPPLP", "PQPPPPPLLP", "PQPPPPLPPP", "PQPPPLPPPP", "PQLPLPPPPP", "PQPLPPPPPP", "PQPPPPPPPP", "PQQQQQQQQP", "PPPPPPPPPP"], 3, 3))
HEART = [".rR...rR.", "rRRR.RRRE", "rRRRRRRRE", "RRRRRRRRE", ".RRRRRRE.", "..RRRRE..", "...RRE...", "....E...."]
add("❤", "heart", layer(HEART, 3, 4))
add("💔", "heart_broken", layer([".rR...rR.", "rRRR.RRRE", "rRR.RRRRE", "RRRR.RRRE", ".RR.RRRE.", "..RR.RE..", "...R.E...", "....E...."], 3, 4))
add("✨", "sparkle", layer(["....Y.....", "...YGD....", "YYYGGGDDD.", "...YGD....", "....D...Y.", ".......YGD", "..Y.....D.", ".YGD......", "..D......."], 3, 3))
add("🙇", "broken_sword", layer([".........a", "........ag", ".......ag.", "......ag..", "..........", "..........", "...ag.....", "..ag......", "GGGG......", ".OG.......", "O.G......."], 3, 2))
add("🗽", "torch", layer(["...Y....", "..YGr...", ".rGYGR..", ".RGGGR..", "..RRR...", "..aag...", "...OH...", "...OH...", "...OH...", "...HH..."], 4, 3))

# ---- economy: goods, buildings, trade (requested by the economy update)
add("🌾", "grain", layer(["..Y..Y..Y...", ".YGDYGDYGD..", "..YD.YD.YD..", ".YGDYGDYGD..", "..GD.GD.GD..", "...GDGDGD...", "....GGGD....", "....OHOH....", "...OOHHOH...", "...O.OH.H...", "....OOHH...."], 2, 2))
add("🍷", "wine", layer(["..aaaaaa..", ".a......g.", ".aRRRRRRg.", ".arRRRREg.", "..aRRREg..", "...agg....", "....ag....", "....ag....", "..aaaggg..", "..dddddd.."], 3, 3))
add("🐑", "sheep", layer(["....wwwwww..", "..wwwwwwwwwa", "ddwwwwwwwwwa", "dkdwwwwwwwwa", "dddwwwwwwwwa", ".d.aaaaaaaa.", "...d.d..d.d.", "...d.d..d.d."], 2, 4))
add("🧵", "spool", layer(["OOOOOOOOOO", ".HOOOOOOH.", "..rRRRRE..", "..RRRRRE..", "..rRRRRE..", "..RRRRRE..", "..rRRRRE..", ".OOOOOOOH.", "OHHHHHHHHH", ".........R", "........R."], 3, 2))
add("🐟", "fish", layer(["....bbbb....", "..bBBBBBBN.b", ".bBwkBBBBNBN", "bBBBBBBBBNN.", ".NBBBBBBNNBN", "..NNNNNNN..N"], 2, 5))
add("🧂", "salt", layer(["...aaaa...", "..awwwwg..", "...wwww...", "..wwwwwa..", ".wwwwwwwa.", "wwwwwwwwwa", "wwwwwwwwwa", "awwwwwwwad", ".dddddddd."], 3, 4))
add("⛏", "pickaxe", layer(["..aaaaaa....", ".aag..gaad..", "ag...OH..gd.", "a....OH...d.", ".....OH.....", ".....OH.....", ".....OH.....", ".....OH.....", ".....OH.....", ".....HH....."], 2, 3))
add("🟠", "copper_ingot", layer(["...rrrrrr...", "..rorrrrrR..", ".rrrrrrrrRE.", "rRRRRRRRRREE", "RRRRRRRRRRE.", "EEEEEEEEEE.."], 2, 6))
add("🪙", "silver_coin", layer(["..aaaaaa..", ".awwwwwwg.", "awwaaaawwg", "awaaggawgd", "awaggggwgd", "awaggggwgd", "awwaggwwgd", ".agwwwwgd.", "..dddddd.."], 3, 3))
add("🪵", "log", layer(["...OOOOOOOOH", "..oOOOOOOOOH", ".oHOooOOOOOH", "oHoHoOOOOOH.", "oHooHOOOOOH.", ".oHHOHHHHH..", "..ooH......."], 2, 5))
add("🦊", "fox", layer(["O.......O...", "OO.....OO...", "OoOOOOOoO...", "OOkOOOkOO...", ".OwOOOwO..OO", "..wwkww..OOO", "...OOOOOOOwO", "...OOOOOOww.", "...H.H.H.H.."], 2, 3))
add("🐄", "cow", layer(["a..a........", "OOOOwwOOwwwO", "OkOOwOOOwwwO", "OOOOwwwwwOOO", ".rrwwOOwwwwO", "....wwwwwwO.", "....d.d..d.d", "....d.d..d.d"], 2, 4))
add("🏪", "market_stall", layer(["rwrwrwrwrwrw", "RwRwRwRwRwRw", "EaEaEaEaEaEa", "O..........O", "O..........O", "O.GD.lL.oO.O", "OOOOOOOOOOOO", "OH........HO", "OH........HO"], 2, 4))
add("🏭", "manufactory", layer([".........dd.", ".........dd.", "....RR...ad.", "...RRRE..ad.", "..RRRRRE.ad.", ".RRRRRRRRad.", "PPPPPPPPPPPP", "PoPPoPPoPPPQ", "PoPPoPPoPPPQ", "PPPPPHHPPPPQ", "QQQQQHHQQQQQ"], 2, 3))
add("🏬", "trade_hall", layer(["....YGGD....", "...RRRRRR...", "..RRRRRRRR..", ".RRRRRRRRRRE", "PPPPPPPPPPPP", "PGDPPGDPPGDQ", "PPPPPPPPPPPQ", "PPGDPHHPGDPQ", "PPPPPHHPPPPQ", "QQQQQHHQQQQQ"], 2, 3))
add("🛒", "handcart", layer(["..lL.GD.ww..", ".lLLGGDwwwa.", "OOOOOOOOOOOH", "OHHHHHHHHHHH", ".O........O.", "HOH......HOH", ".H........H."], 2, 5))
add("📉", "chart_down", layer(["PPPPPPPPPP", "PQRPPPPPPP", "PQPRPPPPPP", "PQPPRPPPPP", "PQPPPRPRPP", "PQPPPPRPRP", "PQPPPPPPPR", "PQPPPPPPPP", "PQQQQQQQQP", "PPPPPPPPPP"], 3, 3))

add("⚓", "anchor", layer(["....aaa.....", "...a.d.g....", "....aad.....", "..ggaagdd...", ".....ad.....", ".....ad.....", "a....ad....g", "ag...ad...gd", ".ag..ad..gd.", "..aggadggd..", "....dddd...."], 2, 3))

add("🛤", "road", layer(["lLlL.HH.lLlL", "LlL.HOOH.LlL", "lLl.HOwOH.lL", "Ll.HOOOOH.Ll", "lL.HOOwOOH.l", "L.HOOOOOOH.L", "l.HOOOwOOOH.", ".HOOOOOOOOH.", ".HOOOOwOOOOH", "HOOOOOOOOOOH", "HOOOOOwOOOOH"], 2, 3))

add("⛪", "church", layer([".....YY.....", "....YYYY....", ".....YD.....", "....RRRE....", "...RRRRRE...", "...PPkPPQ...", ".RRRRRRRRRE.", "RRRRRRRRRRRE", "PPPPPPPPPPPQ", "PPkPPHHPPkPQ", "PPPPPHHPPPPQ", "QQQQQHHQQQQQ"], 2, 2))

# ---- tech tree states
add("🔒", "lock", layer(["...aaaa...", "..ag..ga..", "..a....g..", "..a....g..", "YYYYYYYYYD", "YGGGGGGGGD", "YGGGkkGGGD", "YGGGkkGGGD", "YGGGGkGGGD", "DDDDDDDDDD"], 3, 3))
add("✓", "tick", layer([".........ll", "........lLF", ".......lLF.", "ll....lLF..", "lLl..lLF...", ".lLllLF....", "..lLLF.....", "...LF......"], 2, 4))

# ---- terrain (march time and defence, scripts/core/warfare.gd)
add("🌲", "forest", layer(["....L.....", "...LLF....", "..LLLLF...", "...LLF....", "..LLLLF...", ".LLLLLLF..", "..LLLLF...", ".LLLLLLF..", "LLLLLLLLF.", "....OH....", "....OH...."], 3, 2))
add("⛰", "hills", layer([".....a......", "....aag.....", "...aaggd....", "..aaggggd...", ".aagggggdd..", "aaggggggggdd", "LLLLLLLLLLLF"], 2, 5))
add("🏔", "mountains", layer([".....w......", "....wwa.....", "...wwaag....", "..aaggggd...", ".aaggggddd..", ".aggggggdd..", "aagggggggddd", "agggggggggdd"], 2, 4))
add("🏜", "desert", layer(["........YY..", ".......YGGD.", "........DD..", "............", "......GGGD..", "...GGGGGGGD.", ".GGGGGGGGGGD", "GGGGGGGGGGGG", "DDDDDDDDDDDD"], 2, 4))
add("💧", "marsh", layer(["....B.....", "...BBN....", "..BBBBN...", ".BwBBBBN..", ".BwBBBBN..", ".BBBBBBN..", "..BBBBN...", "...NNN...."], 3, 4))

if __name__ == "__main__":
    os.makedirs(SRC, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    mapping = {}
    for ch, key in REUSE.items():
        src = open(os.path.join(ICON_SRC, key + ".txt")).read()
        name = "icon_" + key
        open(os.path.join(SRC, name + ".txt"), "w").write(src)
        mapping["%x" % ord(ch)] = name
    for ch, (name, g) in E.items():
        write(os.path.join(SRC, name + ".txt"), g, "emoji %s (U+%04X) – %s\n16x16, rendered 1:1 into the pixel emoji font. Generated by tools/art/emoji_icons.py" % (ch, ord(ch), name))
        mapping["%x" % ord(ch)] = name
    json.dump(mapping, open(os.path.join(OUT, "emoji.json"), "w"), indent=1, sort_keys=True)
    print(len(mapping), "emoji glyphs")
