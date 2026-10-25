"""Content batch v0.10: TUR/POL/BUR (now playable) to 10 missions and 11-12 own events each.
No new starting claims: other nations' lands only via owns_any.
Usage: python3 tools/content/batch_v10.py  (idempotent, keeps the one-line-per-entry layout)"""
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



# TUR, POL and BUR are playable since v0.6: bring them to 10 missions and 11-12 events each.
# No new starting claims: none of these missions uses "owns".
MISSIONS = {
"TUR": [
  M("tur_fleet", "Die Flotte des Sultans", "Galeeren aus Gallipoli beherrschen die Ägäis.",
    {"tech": {"mil": 10}, "regs": 30}, {"mods": {"combat": 0.05}, "prestige": 10}),
  M("tur_kanun", "Der Kanun", "Ein Reichsrecht neben der Scharia, für alle Provinzen gleich.",
    {"tech": {"adm": 10}, "min_dev": 150}, {"mods": {"adm": 1}, "prestige": 15}),
  M("tur_adriatic", "An der Adria", "Dalmatien oder Venedig selbst öffnen den Weg nach Italien.",
    {"owns_any": ["dalmatia", "venice", "friuli"]}, {"mods": {"income": 0.05}, "prestige": 15}, after="tur_morea"),
  M("tur_tributaries", "Die Tributstaaten", "Fürsten, die dem Sultan Tribut zahlen, sind billiger als Provinzen.",
    {"has_vassal": True}, {"dip": 50, "prestige": 10}),
],
"POL": [
  M("pol_jagiellon_thrones", "Die Throne der Jagiellonen", "Böhmen oder Ungarn unter einem polnischen Prinzen.",
    {"owns_any": ["buda", "prague", "pressburg"]}, {"prestige": 25, "dip": 40}),
  M("pol_ukraine", "Die Ukraine", "Kiew und Wolhynien, die Kornkammer der Republik.",
    {"owns_any": ["kiev", "volhynia"]}, {"mods": {"manpower": 0.1}}, after="pol_lithuania"),
  M("pol_warsaw", "Warschau", "Die Stadt in der Mitte der Republik wird Sitz von König und Sejm.",
    {"tech": {"adm": 10}, "min_dev": 120}, {"dev_capital": 2, "prestige": 15}),
  M("pol_fiefs", "Lehnsherr des Nordens", "Preußen, Kurland oder Livland als Lehen der Krone.",
    {"has_vassal": True}, {"dip": 50, "mods": {"income": 0.03}}),
],
"BUR": [
  M("bur_cloth", "Das flämische Tuch", "Gent, Brügge und Ypern weben für ganz Europa.",
    {"tech": {"adm": 6}, "min_dev": 60}, {"mods": {"income": 0.05}}),
  M("bur_antwerp", "Antwerpen", "Der größte Hafen nördlich der Alpen.",
    {"tech": {"dip": 8}}, {"mods": {"income": 0.05}, "dev_random": 2}),
  M("bur_frisia", "Friesland", "Die Küste nach Osten bis zur Weser.",
    {"owns_any": ["bremen", "hamburg"]}, {"dip": 40, "mods": {"manpower": 0.05}}),
  M("bur_crown", "König von Burgund", "Ein Reich zwischen Frankreich und dem Reich, so stark wie beide.",
    {"min_dev": 120, "allies": 2}, {"mods": {"dip": 1}, "prestige": 25}, after="bur_kingdom"),
  M("bur_arelat", "Das Königreich Arelat", "Die Provence oder Savoyen, das alte burgundische Königreich im Süden.",
    {"owns_any": ["provence", "savoy"]}, {"prestige": 20, "mods": {"combat": 0.03}}, after="bur_somme"),
],
}

EVENTS = [
# ------------------------------------------------------------------ Ottomans
E("tur_istanbul", "TUR", "Istanbul", "Die eroberte Stadt ist halb leer. Der Sultan will sie wieder zur größten Stadt der Welt machen.",
  {"year_min": 1453, "year_max": 1490, "owns": ["constantinople"]},
  [O("Siedler aus ganz Anatolien.", {"dev_random": 2, "gold": -40}, 40),
   O("Griechen, Armenier und Juden einladen.", {"mods": {"income": 0.03}, "prestige": -5}, 40),
   O("Eine große Moschee und ein Basar.", {"prestige": 15, "gold": -50}, 20)]),
E("tur_cem", "TUR", "Prinz Cem", "Der Bruder des Sultans beansprucht den Thron und ist zu den Johannitern geflohen. Rom bietet an, ihn gegen Geld festzuhalten.",
  {"year_min": 1481, "year_max": 1500},
  [O("Dem Papst jährlich zahlen.", {"gold": -60, "relations": {"PAP": 40}}, 30),
   O("Seine Anhänger in Anatolien zerschlagen.", {"manpower": -2, "ruler": {"mil": 1}}, 30),
   O("Ihn zurückholen und versöhnen.", {"dip": -30, "prestige": 10}, 40)]),
E("tur_selim", "TUR", "Selim der Gestrenge", "Der neue Sultan will zuerst nach Osten: gegen die Safawiden in Persien und die Mamluken in Ägypten.",
  {"year_min": 1510, "year_max": 1525},
  [O("Ägypten erobern: das Gold des Nils.", {"gold": 150, "mods": {"income": 0.03}, "prestige": 10}, 50),
   O("Persien schlagen: Tschaldiran.", {"mods": {"combat": 0.03}, "mil": 40}),
   O("Der Westen geht vor.", {"claim": ["buda"], "mil": 20})]),
E("tur_barbarossa", "TUR", "Hayreddin Barbarossa", "Der Korsar aus Algier bietet dem Sultan seine Flotte an, wenn er Großadmiral wird.",
  {"year_min": 1525, "year_max": 1560},
  [O("Ihn zum Kapudan Pascha ernennen.", {"mods": {"combat": 0.03}, "relations": {"SPA": -30, "FRA": 30}}, 60),
   O("Seine Beute teilen.", {"gold": 100, "prestige": -5}),
   O("Ein Korsar bleibt ein Korsar.", {"prestige": 5})]),
E("tur_hurrem", "TUR", "Hürrem Sultan", "Die Frau des Sultans hat großen Einfluss. Am Hof wird geflüstert, sie wolle den Thronfolger beseitigen.",
  {"year_min": 1530, "year_max": 1570},
  [O("Ihr vertrauen.", {"dip": 40, "ruler": {"dip": 1}, "prestige": -5}, 40),
   O("Den Thronfolger schützen.", {"mil": 30, "dip": -20}, 30),
   O("Wohltätige Stiftungen in ihrem Namen.", {"gold": -40, "prestige": 10, "dev_random": 1}, 30)]),
E("tur_sokollu", "TUR", "Sokollu Mehmed Pascha", "Der Großwesir plant einen Kanal zwischen Don und Wolga, um Astrachan zu erreichen.",
  {"year_min": 1565, "year_max": 1580},
  [O("Den Kanal bauen.", {"gold": -80, "relations": {"RUS": -30, "CRI": 30}, "prestige": 10}, 40),
   O("Er soll lieber verwalten.", {"adm": 50}, 40),
   O("Lieber Zypern erobern.", {"mil": 30, "relations": {"VEN": -40}})]),
E("tur_osman2", "TUR", "Der junge Osman", "Der Sultan will die Janitscharen durch ein neues Heer aus Anatolien ersetzen. Die Kessel klappern schon.",
  {"year_min": 1600, "flag": "ev_tur_janissaries"},
  [O("Die Reform durchsetzen.", {"mods": {"combat": 0.03}, "ruler": {"adm": -1}, "manpower": -2}, 30),
   O("Die Janitscharen mit Gold beruhigen.", {"gold": -60}, 40),
   O("Die Reform aufschieben.", {"prestige": -5, "adm": 20}, 30)]),
# ------------------------------------------------------------------ Poland
E("pol_nieszawa", "POL", "Die Statuten von Nieszawa", "Der Adel verlangt für den Krieg gegen den Orden neue Rechte: kein Gesetz und keine Steuer ohne die Landtage.",
  {"year_max": 1470},
  [O("Die Statuten gewähren.", {"manpower": 3, "adm": -20, "flag": "pol_szlachta"}, 60),
   O("Nur dem hohen Adel nachgeben.", {"gold": 40, "mil": -20}),
   O("Ablehnen, der König regiert.", {"prestige": 10, "manpower": -2})]),
E("pol_nihil_novi", "POL", "Nihil novi", "Der Sejm beschließt: Nichts Neues ohne gemeinsame Zustimmung. Polen wird zur Adelsrepublik.",
  {"year_min": 1500, "year_max": 1515, "flag": "pol_szlachta"},
  [O("Die Verfassung annehmen.", {"dip": 40, "mods": {"manpower": 0.03}, "ruler": {"adm": -1}}, 50),
   O("Ein starkes Königtum verteidigen.", {"prestige": 10, "mil": -30}),
   O("Ein Kompromiss mit dem Senat.", {"adm": 40})]),
E("pol_wawel", "POL", "Die Renaissance auf dem Wawel", "Königin Bona Sforza bringt italienische Baumeister, Gärtner und Gemüse nach Krakau.",
  {"year_min": 1505, "year_max": 1550},
  [O("Den Wawel umbauen.", {"dev_capital": 1, "prestige": 10, "gold": -50}, 50),
   O("Die Krongüter reformieren.", {"gold": 70, "dip": -20}),
   O("Die Jagiellonen-Universität fördern.", {"adm": 40})]),
E("pol_prussian_homage", "POL", "Die Preußische Huldigung", "Der letzte Hochmeister will als lutherischer Herzog dem König von Polen huldigen.",
  {"year_min": 1520, "year_max": 1540, "alive": "TEU", "at_peace": True},
  [O("Die Huldigung annehmen.", {"vassal": "TEU", "prestige": 15}, 60),
   O("Das Land direkt fordern.", {"claim": ["prussia", "marienburg"], "relations": {"TEU": -40}}),
   O("Der Papst wäre empört.", {"relations": {"PAP": 30}, "prestige": 5})]),
E("pol_livonia", "POL", "Livland bittet um Schutz", "Der Livländische Orden wird von Moskau bedroht und bietet sich der polnischen Krone an.",
  {"year_min": 1555, "year_max": 1585, "alive": "LIV", "at_peace": True},
  [O("Livland unter unseren Schutz.", {"vassal": "LIV", "relations": {"RUS": -40}}, 50),
   O("Nur ein Bündnis.", {"alliance": "LIV", "dip": 20}),
   O("Nicht unser Krieg.", {"adm": 30})]),
E("pol_warsaw_confederation", "POL", "Die Warschauer Konföderation", "Der Adel schwört, dass niemand wegen seines Glaubens verfolgt werden darf.",
  {"year_min": 1570, "year_max": 1580},
  [O("Religionsfrieden für alle.", {"dip": 40, "dev_random": 1, "relations": {"PAP": -20}}, 60),
   O("Nur für den Adel.", {"prestige": 5, "adm": 20}),
   O("Die Jesuiten holen.", {"relations": {"PAP": 40}, "dip": -20})]),
E("pol_zamoyski", "POL", "Jan Zamoyski", "Der Kanzler und Hetman baut eine Idealstadt und will die Macht des Königs stärken.",
  {"year_min": 1575, "year_max": 1605},
  [O("Ihn zum Kronhetman machen.", {"mods": {"combat": 0.03}, "mil": 30}, 50),
   O("Die Stadt Zamość fördern.", {"dev_random": 1, "gold": -30, "prestige": 5}),
   O("Seine Macht beschneiden.", {"adm": 30, "dip": -20})]),
E("pol_dymitriad", "POL", "Der falsche Dmitri", "Ein Mann, der sich als Sohn Iwans des Schrecklichen ausgibt, sucht polnische Hilfe für den Zarenthron.",
  {"year_min": 1600, "year_max": 1615, "alive": "RUS"},
  [O("Ihn mit Magnaten unterstützen.", {"claim": ["smolensk"], "relations": {"RUS": -50}, "gold": -40}, 40),
   O("Den Prinzen Władysław als Zaren vorschlagen.", {"prestige": 10, "relations": {"RUS": -30}, "dip": -20}, 30),
   O("Ein Abenteuer, das wir nicht brauchen.", {"adm": 30}, 30)]),
# ------------------------------------------------------------------ Burgundy
E("bur_philip_good", "BUR", "Philipp der Gute", "Der Herzog hält den prächtigsten Hof Europas. Jan van Eyck malt für ihn, Gelehrte schreiben für ihn.",
  {"year_max": 1467},
  [O("Den Hof noch prächtiger machen.", {"prestige": 15, "gold": -60}, 50),
   O("Die Kassen der Städte füllen.", {"gold": 70, "dip": -20}),
   O("Einen Kreuzzug geloben.", {"relations": {"PAP": 40}, "mil": 20})]),
E("bur_ghent", "BUR", "Der Genter Aufstand", "Gent weigert sich, die neue Salzsteuer zu zahlen. Die Stadtmilizen marschieren.",
  {"year_max": 1460},
  [O("Bei Gavere schlagen.", {"mil": -30, "prestige": 10, "dev_random": -1}, 50),
   O("Die Steuer zurücknehmen.", {"gold": -40, "dip": 20}),
   O("Der Stadt Privilegien nehmen.", {"adm": 30, "prestige": -5})]),
E("bur_liege", "BUR", "Lüttich", "Die Bürger von Lüttich haben sich gegen ihren Fürstbischof erhoben, einen Verwandten des Herzogs.",
  {"year_min": 1460, "year_max": 1475},
  [O("Lüttich strafen, wie Dinant.", {"prestige": 10, "relations": {"FRA": -20}, "dev_random": -1}, 50),
   O("Vermitteln.", {"dip": 30}),
   O("Lüttich der Grafschaft einverleiben.", {"mods": {"income": 0.02}, "relations": {"PAP": -30}})]),
E("bur_neuss", "BUR", "Die Belagerung von Neuss", "Karl will den Erzbischof von Köln einsetzen. Die kleine Stadt Neuss hält seit Monaten stand.",
  {"year_min": 1470, "year_max": 1480, "alive": "KOL"},
  [O("Weiter belagern.", {"claim": ["cologne"], "manpower": -2, "relations": {"HAB": -20}}, 40),
   O("Abziehen und mit dem Kaiser verhandeln.", {"relations": {"HAB": 40}, "prestige": -10}, 40),
   O("Söldner aus Italien.", {"regs": 2, "gold": -50}, 20)]),
E("bur_trier", "BUR", "Das Treffen in Trier", "Der Kaiser und der Herzog verhandeln über eine Königskrone für Burgund und die Heirat Marias mit Maximilian.",
  {"year_min": 1470, "year_max": 1480},
  [O("Krone und Heirat!", {"prestige": 15, "relations": {"HAB": 50}, "flag": "bur_trier_deal"}, 50),
   O("Nur die Heirat.", {"relations": {"HAB": 30}, "dip": 20}),
   O("Dem Kaiser misstrauen.", {"mil": 30})]),
E("bur_great_privilege", "BUR", "Das Große Privileg", "Nach dem Tod Karls verlangen die Generalstaaten Rechte von der jungen Herzogin.",
  {"year_min": 1475, "year_max": 1495, "flag": "ev_bur_nancy"},
  [O("Das Privileg gewähren.", {"dip": 40, "adm": -20, "manpower": 2}, 50),
   O("Hart bleiben.", {"prestige": 5, "mil": -30}),
   O("Die Hilfe Habsburgs erbitten.", {"relations": {"HAB": 40}, "prestige": -5})]),
E("bur_antwerp_bourse", "BUR", "Die Börse von Antwerpen", "Kaufleute aus Genua, Portugal und der Hanse gründen eine Börse. Antwerpen wird das Zentrum des Welthandels.",
  {"year_min": 1480, "year_max": 1580},
  [O("Den Handel fördern.", {"mods": {"income": 0.04}, "gold": -40}, 60),
   O("Die Börse besteuern.", {"gold": 80}),
   O("Brügge bevorzugen.", {"prestige": 5, "dip": 20})]),
E("bur_iconoclasm", "BUR", "Der Bildersturm", "In den Niederlanden zerschlagen Calvinisten Heiligenbilder in den Kirchen.",
  {"year_min": 1560, "year_max": 1580},
  [O("Toleranz für die Calvinisten.", {"dev_random": 1, "relations": {"PAP": -30}}, 40),
   O("Ein Blutrat wie in Spanien.", {"mil": 30, "dev_random": -2, "prestige": -5}, 30),
   O("Die Generalstaaten entscheiden.", {"dip": 30}, 30)]),
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
