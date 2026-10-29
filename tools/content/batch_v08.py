"""Content batch v0.8: events for the British Isles, Iberia, Eastern Europe, the Balkans and German minors,
plus missions for SCO, POR, HUN and LIT.
Usage: python3 tools/content/batch_v08.py  (idempotent, keeps the one-line-per-entry layout)"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def O(text, effects, ai=None):
    o = {"text": text, "effects": effects}
    if ai is not None:
        o["ai"] = ai
    return o


def E(id, tag, title, text, trigger, options, once=True):
    e = {"id": id}
    if not once:
        e["once"] = False
    e.update({"tag": tag, "title": title, "text": text, "trigger": trigger, "options": options})
    return e


def M(id, title, desc, require, reward, after=None):
    m = {"id": id}
    if after:
        m["after"] = after
    m.update({"title": title, "desc": desc, "require": require, "reward": reward})
    return m


# owns-keys become starting claims, so "owns" is only used for a nation's own core lands
MISSIONS = {
"SCO": [
  M("sco_highlands", "Die Highlands zähmen", "Die Clans des Nordens sollen dem König gehorchen.",
    {"owns": ["lothian", "highlands"], "tech": {"adm": 4}}, {"mods": {"manpower": 0.05}, "adm": 30}),
  M("sco_auld_alliance", "Die Auld Alliance", "Frankreich als Verbündeter gegen England.",
    {"allied": "FRA"}, {"prestige": 15, "dip": 30}),
  M("sco_border", "Die Grenzmarken", "Northumberland oder York für Schottland.",
    {"owns_any": ["northumberland", "york"]}, {"prestige": 20}, after="sco_highlands"),
],
"POR": [
  M("por_algarve", "Das Königreich Algarve", "Der Süden ist das Sprungbrett nach Afrika.",
    {"year_min": 1450, "owns": ["lisbon", "porto", "algarve"]}, {"mods": {"income": 0.03}, "adm": 30}),
  M("por_navigation", "Die Schule von Sagres", "Kartographen, Astronomen und Schiffbauer für die Entdeckungen.",
    {"tech": {"dip": 6}}, {"mods": {"income": 0.05}, "prestige": 10}),
  M("por_independence", "Gegen Kastilien", "Portugal bleibt frei.",
    {"year_min": 1500, "at_peace": True, "min_dev": 30}, {"prestige": 15, "mods": {"manpower": 0.05}}, after="por_algarve"),
],
"HUN": [
  M("hun_black_army", "Die Schwarze Armee", "Ein stehendes Söldnerheer, bezahlt aus der Krone.",
    {"tech": {"mil": 5}, "regs": 15}, {"mods": {"combat": 0.05}}),
  M("hun_danube", "Die Donaufestungen", "Belgrad und Temesvár halten die Türken auf.",
    {"year_min": 1450, "owns": ["buda", "temes", "croatia"]}, {"mods": {"manpower": 0.05}, "prestige": 10}),
  M("hun_vienna", "Matthias in Wien", "Die Residenz der Habsburger als ungarische Hauptstadt.",
    {"owns_any": ["wien", "steiermark"]}, {"prestige": 25, "dip": 30}, after="hun_black_army"),
],
"LIT": [
  M("lit_rus", "Die Länder der Rus", "Kiew, Smolensk und Tschernigow bleiben litauisch.",
    {"year_min": 1450, "owns": ["kiev", "smolensk", "chernigov"]}, {"mods": {"manpower": 0.05}}),
  M("lit_sea", "Von Meer zu Meer", "Ein Hafen an der Ostsee oder am Schwarzen Meer.",
    {"owns_any": ["riga", "crimea", "zaporozhia"]}, {"mods": {"income": 0.05}, "prestige": 10}),
  M("lit_statute", "Das Litauische Statut", "Ein Gesetzbuch für das ganze Großfürstentum.",
    {"tech": {"adm": 6}}, {"adm": 40, "prestige": 10}),
],
}

EVENTS = [
# ------------------------------------------------------------------ Scotland, Ireland
E("sco_flodden", "SCO", "Die Schlacht bei Flodden", "Frankreich bittet um Hilfe gegen England. Der König will über die Grenze marschieren.",
  {"year_min": 1500, "year_max": 1530, "alive": "ENG", "at_peace": True},
  [O("Für die Auld Alliance!", {"war": "ENG", "relations": {"FRA": 40}}, 30),
   O("Nur Truppen an die Grenze.", {"mil": 30, "relations": {"FRA": 20}}, 40),
   O("Frieden mit England.", {"relations": {"ENG": 40}, "prestige": -5}, 30)]),
E("sco_knox", "SCO", "John Knox", "Ein Prediger aus Genf ruft zum Bildersturm. Die Lords der Kongregation stehen hinter ihm.",
  {"year_min": 1550, "year_max": 1575},
  [O("Die Kirk reformieren.", {"gold": 60, "relations": {"PAP": -40, "ENG": 20}}, 50),
   O("Beim alten Glauben bleiben.", {"relations": {"PAP": 30, "FRA": 30}, "prestige": 5}),
   O("Die Königin soll entscheiden.", {"dip": 20})]),
E("ire_kildare", "IRE", "Die Geraldines von Kildare", "Der mächtigste Lord des Landes bietet an, für die irischen Clans zu sprechen, gegen die englische Krone.",
  {"year_min": 1470, "year_max": 1540},
  [O("Ein Bund der Clans.", {"mods": {"manpower": 0.03}, "relations": {"ENG": -30}}, 50),
   O("Mit Dublin verhandeln.", {"relations": {"ENG": 30}, "dip": 20}),
   O("Gälische Gesetze für alle.", {"adm": 30})]),
# ------------------------------------------------------------------ Iberia
E("por_henry", "POR", "Heinrich der Seefahrer", "Der Infant schickt jedes Jahr Karavellen weiter die afrikanische Küste hinab.",
  {"year_max": 1465},
  [O("Die Fahrten finanzieren.", {"gold": -40, "prestige": 10, "flag": "por_explorers"}, 60),
   O("Lieber Ceuta befestigen.", {"mil": 30}),
   O("Gold aus Guinea genügt.", {"gold": 50})]),
E("por_tordesillas", "POR", "Der Vertrag von Tordesillas", "Der Papst teilt die Welt: Eine Linie im Atlantik trennt Portugal und Kastilien.",
  {"year_min": 1490, "year_max": 1500, "flag": "por_explorers", "alive": "SPA"},
  [O("Die Linie weiter nach Westen!", {"mods": {"income": 0.03}, "relations": {"SPA": -20}}, 60),
   O("Den Vertrag annehmen.", {"relations": {"SPA": 40, "PAP": 20}}),
   O("Die Linie ignorieren.", {"gold": 60, "relations": {"PAP": -30}})]),
E("por_alcacer", "POR", "Alcácer-Quibir", "Der junge König Sebastian will Marokko erobern. Der Adel folgt ihm in die Wüste.",
  {"year_min": 1570, "year_max": 1585},
  [O("Den Kreuzzug wagen.", {"manpower": -3, "prestige": -10, "ruler": {"adm": -1}}, 30),
   O("Den König zurückhalten.", {"dip": 30, "prestige": -5}, 40),
   O("Ein kleiner Feldzug, sorgfältig geplant.", {"mil": 30, "gold": -40}, 30)]),
E("gra_boabdil", "GRA", "Boabdil", "Der junge Emir rebelliert gegen seinen Vater. Kastilien wartet nur auf diesen Streit.",
  {"year_min": 1470, "year_max": 1495},
  [O("Den Vater stützen.", {"mil": 30, "prestige": 5}, 50),
   O("Den Sohn stützen, Frieden mit Kastilien.", {"relations": {"SPA": 40}, "prestige": -10}),
   O("Hilfe aus Nordafrika erbitten.", {"regs": 2, "gold": -40})]),
E("ara_remensa", "ARA", "Die Remença-Bauern", "In Katalonien erheben sich die leibeigenen Bauern gegen die bösen Bräuche ihrer Herren.",
  {"year_min": 1460, "year_max": 1490},
  [O("Die Bauern befreien.", {"dev_random": 1, "relations": {"SPA": 10}, "prestige": 5}, 50),
   O("Mit dem Adel gegen die Bauern.", {"mil": 30, "dev_random": -1}),
   O("Ablösung gegen Geld.", {"gold": 60, "adm": -20})]),
# ------------------------------------------------------------------ Eastern Europe and the Balkans
E("hun_hunyadi", "HUN", "Johann Hunyadi", "Der Reichsverweser will die Türken vor Belgrad schlagen. Ein Franziskaner predigt dazu den Kreuzzug.",
  {"year_max": 1460, "alive": "TUR"},
  [O("Belgrad entsetzen!", {"prestige": 20, "manpower": -2, "relations": {"TUR": -40, "PAP": 30}}, 60),
   O("Die Grenze befestigen.", {"gold": -40, "manpower": 2}),
   O("Waffenstillstand mit dem Sultan.", {"relations": {"TUR": 30}, "prestige": -10})]),
E("hun_dozsa", "HUN", "Der Dózsa-Aufstand", "Ein Kreuzzugsheer aus Bauern wendet sich gegen die eigenen Herren.",
  {"year_min": 1505, "year_max": 1525},
  [O("Den Aufstand niederschlagen.", {"mil": -30, "dev_random": -1}, 50),
   O("Den Bauern Land geben.", {"adm": -30, "mods": {"manpower": 0.03}}),
   O("Die Werbung abbrechen.", {"prestige": -10, "dip": 20})]),
E("lit_grunwald_legacy", "LIT", "Das Erbe Vytautas'", "Die Bojaren der Rus fragen, ob der Großfürst ihre Rechte und ihren Glauben schützt.",
  {"year_max": 1500},
  [O("Gleiche Rechte für die Orthodoxen.", {"dip": 30, "mods": {"manpower": 0.03}, "relations": {"PAP": -10}}, 50),
   O("Nur katholische Herren.", {"relations": {"PAP": 30, "POL": 20}, "prestige": 5}),
   O("Steuerfreiheit für die Grenzfürsten.", {"gold": -40, "manpower": 2})]),
E("nov_marfa", "NOV", "Marfa Boretskaja", "Die Witwe des Bürgermeisters will Nowgorod an Litauen binden, um Moskau zu entgehen.",
  {"year_max": 1480, "alive": "LIT"},
  [O("Ein Bündnis mit Litauen.", {"alliance": "LIT", "relations": {"RUS": -40}}, 50),
   O("Moskau Tribut zahlen.", {"gold": -50, "relations": {"RUS": 40}}),
   O("Die Volksversammlung entscheidet.", {"dip": 30})]),
E("cri_mengli", "CRI", "Mengli Giray", "Der Khan muss wählen: Bündnis mit Moskau gegen die Goldene Horde oder mit Litauen gegen Moskau.",
  {"year_max": 1515},
  [O("Mit Moskau gegen die Horde.", {"relations": {"RUS": 40, "LIT": -30}, "mil": 20}, 40),
   O("Mit Litauen gegen Moskau.", {"relations": {"LIT": 40, "RUS": -30}, "mil": 20}, 30),
   O("Vasall des Sultans werden.", {"relations": {"TUR": 50}, "prestige": -5}, 30)]),
E("wal_dracula", "WAL", "Vlad der Pfähler", "Der Woiwode verweigert den Knabenzins an den Sultan und lässt die Gesandten pfählen.",
  {"year_min": 1455, "year_max": 1480, "alive": "TUR"},
  [O("Krieg dem Sultan!", {"prestige": 15, "relations": {"TUR": -60, "HUN": 30}, "mil": 30}, 40),
   O("Den Tribut zahlen.", {"gold": -40, "relations": {"TUR": 30}}, 40),
   O("Ungarn um Schutz bitten.", {"relations": {"HUN": 50}, "dip": -20})]),
E("mol_stephen", "MOL", "Stephan der Große", "Nach jedem Sieg gegen die Türken lässt der Fürst ein Kloster bauen.",
  {"year_min": 1457, "year_max": 1505},
  [O("Ein neues Kloster.", {"prestige": 10, "gold": -30}, 50),
   O("Die Festungen am Dnjestr.", {"manpower": 2, "gold": -30}),
   O("Beim Papst um Hilfe werben.", {"relations": {"PAP": 40}, "dip": 20})]),
E("alb_skanderbeg_league", "ALB", "Die Liga von Lezha", "Die albanischen Fürsten wählen Skanderbeg zu ihrem Anführer gegen die Osmanen.",
  {"year_max": 1470},
  [O("Die Liga führen.", {"mods": {"combat": 0.03}, "relations": {"TUR": -40}}, 60),
   O("Venedig um Schiffe bitten.", {"relations": {"VEN": 40}, "gold": -30}),
   O("Jeder Fürst für sich.", {"gold": 40, "prestige": -10})]),
E("ser_smederevo", "SER", "Die Festung Smederevo", "Der Despot hat eine gewaltige Festung an der Donau gebaut. Ob sie dem Sultan standhält?",
  {"year_max": 1465, "alive": "TUR"},
  [O("Die Mauern verstärken.", {"gold": -40, "manpower": 2}, 50),
   O("Ungarn als Schutzherr.", {"relations": {"HUN": 50, "TUR": -20}}),
   O("Dem Sultan huldigen.", {"relations": {"TUR": 40}, "prestige": -10})]),
# ------------------------------------------------------------------ German minors and the Hanse
E("sax_luther", "SAX", "Der Mönch von Wittenberg", "Ein Professor der kurfürstlichen Universität hat Thesen gegen den Ablass veröffentlicht. Rom verlangt seine Auslieferung.",
  {"year_min": 1515, "year_max": 1530},
  [O("Ihn auf der Wartburg verstecken.", {"prestige": 10, "relations": {"PAP": -40, "HAB": -20}, "adm": 20}, 60),
   O("Ihn nach Rom ausliefern.", {"relations": {"PAP": 40}, "prestige": -10}),
   O("Ein Reichstag soll entscheiden.", {"dip": 30})]),
E("bra_hohenzollern", "BRA", "Das Haus Hohenzollern", "Die Hohenzollern in Franken und Brandenburg könnten ihre Länder durch Erbverträge verbinden.",
  {"year_min": 1470, "year_max": 1600},
  [O("Ein Erbvertrag mit Preußen.", {"relations": {"TEU": 40}, "dip": 20}, 50),
   O("Die Mark zuerst.", {"adm": 30, "mods": {"manpower": 0.03}}),
   O("Gold für die Kurwürde.", {"gold": -40, "prestige": 10})]),
E("bav_reinheitsgebot", "BAV", "Das Reinheitsgebot", "Das Bier soll nur aus Gerste, Hopfen und Wasser bestehen. Die Brauer murren, die Trinker jubeln.",
  {"year_min": 1500, "year_max": 1530},
  [O("Das Gebot erlassen.", {"prestige": 5, "mods": {"income": 0.02}}, 60),
   O("Lieber eine Biersteuer.", {"gold": 60}),
   O("Die Brauer entscheiden lassen.", {"dip": 20})]),
E("hsa_wars", "HSA", "Der Kampf um die Ostsee", "Holländische Kaufleute dringen in die Ostsee vor. Die Hanse verliert ihr Monopol.",
  {"year_min": 1480},
  [O("Ein Handelskrieg gegen die Holländer.", {"mil": 30, "gold": -30}, 40),
   O("Neue Kontore im Osten.", {"mods": {"income": 0.03}, "gold": -40}, 40),
   O("Mit den Holländern teilen.", {"dip": 30, "prestige": -5}, 20)], once=False),
E("teu_secularize", "TEU", "Der Ordensstaat wird Herzogtum", "Der Hochmeister erwägt, lutherisch zu werden und den Orden in ein weltliches Herzogtum zu verwandeln.",
  {"year_min": 1515, "year_max": 1545},
  [O("Herzogtum Preußen unter polnischer Lehenshoheit.", {"relations": {"POL": 50, "PAP": -40}, "adm": 40}, 50),
   O("Der Orden bleibt.", {"prestige": 10, "relations": {"PAP": 30}}),
   O("Schutz beim Kaiser suchen.", {"relations": {"HAB": 40}, "dip": -20})]),
]


def render_event(e):
    head = {k: e[k] for k in ("id", "once", "tag", "title", "text") if k in e}
    s = "  " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    s += '   "trigger": ' + json.dumps(e["trigger"], ensure_ascii=False) + ",\n"
    s += '   "options": [\n'
    s += ",\n".join("     " + json.dumps(o, ensure_ascii=False) for o in e["options"])
    return s + "]}"


def render_mission(m):
    head = {k: m[k] for k in ("id", "after", "title", "desc") if k in m}
    s = "    " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    return s + '     "require": ' + json.dumps(m["require"], ensure_ascii=False) + ', "reward": ' + json.dumps(m["reward"], ensure_ascii=False) + "}"


def main():
    path = os.path.join(ROOT, "data/events.json")
    txt = open(path, encoding="utf-8").read().rstrip()
    existing = {e["id"] for e in json.loads(txt)}
    new = [e for e in EVENTS if e["id"] not in existing]
    for e in new:
        assert len(e["options"]) == 3, e["id"]
    if new:
        txt = txt[:-1].rstrip() + ",\n" + ",\n".join(render_event(e) for e in new) + "\n]"
    json.loads(txt)
    open(path, "w", encoding="utf-8").write(txt + "\n")

    path = os.path.join(ROOT, "data/missions.json")
    data = json.load(open(path, encoding="utf-8"))
    for tag, ms in MISSIONS.items():
        have = {m["id"] for m in data.setdefault(tag, [])}
        data[tag] += [m for m in ms if m["id"] not in have]
    out = "{\n" + ",\n".join(
        '  "%s": [\n' % tag + ",\n".join(render_mission(m) for m in ms) + "\n  ]" for tag, ms in data.items()) + "\n}\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)
    print("events +%d, missions %s" % (len(new), {t: len(v) for t, v in data.items()}))


if __name__ == "__main__":
    main()
