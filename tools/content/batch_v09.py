"""Content batch v0.9: events for the remaining minors without content (KAZ, RYA, LIV, BYZ, BOS, SAV, GEN,
PRV, BRI, NAV, small German states), plus missions for SAV, GEN and LIV.
Usage: python3 tools/content/batch_v09.py  (idempotent, keeps the one-line-per-entry layout)"""
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
"SAV": [
  M("sav_alps", "Die Alpenpässe", "Savoyen und Piemont halten die Schlüssel zu Italien.",
    {"year_min": 1450, "at_peace": True, "owns": ["savoy", "piedmont"]}, {"mods": {"manpower": 0.05}, "dip": 30}),
  M("sav_turin", "Turin als Hauptstadt", "Der Hof zieht über die Alpen nach Italien.",
    {"tech": {"adm": 6}, "min_dev": 25}, {"dev_random": 2, "prestige": 10}),
  M("sav_coast", "Ein Hafen am Meer", "Nizza ist zu wenig: Genua oder die Provence.",
    {"owns_any": ["genoa", "provence"]}, {"mods": {"income": 0.05}}, after="sav_alps"),
],
"GEN": [
  M("genoa_corsica", "Korsika halten", "Die Insel ist ständig im Aufruhr, aber unverzichtbar.",
    {"year_min": 1450, "owns": ["genoa", "corsica"]}, {"mods": {"manpower": 0.05}, "mil": 30}),
  M("genoa_bankers", "Die Bankiers Spaniens", "Genuesisches Kapital finanziert die Kriege der Könige.",
    {"tech": {"dip": 6}, "gold_min": 150}, {"mods": {"income": 0.05}, "dip": 30}),
  M("genoa_sardinia", "Sardinien", "Die Nachbarinsel für Genua.",
    {"owns_any": ["sardinia"]}, {"prestige": 15}, after="genoa_corsica"),
],
"LIV": [
  M("liv_order", "Der Orden hält", "Riga und Reval gehören dem Orden, nicht dem Erzbischof oder den Städten.",
    {"year_min": 1450, "owns": ["riga", "reval"]}, {"mods": {"combat": 0.03}, "adm": 30}),
  M("liv_walls", "Mauern gegen Moskau", "Neue Festungen für den Krieg, der kommen wird.",
    {"tech": {"mil": 6}, "regs": 10}, {"mods": {"manpower": 0.05}}),
],
}

EVENTS = [
# ------------------------------------------------------------------ the east
E("kaz_khanate", "KAZ", "Der Thron von Kasan", "Moskau und die Krim streiten darüber, wer den nächsten Khan von Kasan bestimmt.",
  {"year_min": 1480, "year_max": 1552},
  [O("Ein Khan aus der Krim.", {"relations": {"CRI": 50, "RUS": -40}, "mil": 20}, 50),
   O("Ein Khan von Moskaus Gnaden.", {"relations": {"RUS": 50}, "prestige": -10}),
   O("Die Begs wählen selbst.", {"adm": 30})]),
E("kaz_volga_trade", "KAZ", "Der Wolgahandel", "Persische Seide und russische Pelze werden auf dem Markt von Kasan gehandelt.",
  {"year_min": 1450},
  [O("Zölle erheben.", {"gold": 60}, 50),
   O("Den Händlern Schutz geben.", {"mods": {"income": 0.02}, "mil": -20}),
   O("Russische Kaufleute ausschließen.", {"relations": {"RUS": -30}, "prestige": 5})]),
E("rya_last_prince", "RYA", "Der letzte Fürst von Rjasan", "Moskau verlangt immer mehr. Der Fürst überlegt, zu Litauen überzulaufen.",
  {"year_min": 1480, "year_max": 1525, "alive": "RUS"},
  [O("Treu zu Moskau.", {"relations": {"RUS": 40}, "prestige": -5}, 50),
   O("Geheime Briefe nach Vilnius.", {"relations": {"LIT": 40, "RUS": -40}, "dip": 20}),
   O("Die Festung an der Oka verstärken.", {"manpower": 2, "gold": -30})]),
E("liv_plettenberg", "LIV", "Wolter von Plettenberg", "Der Landmeister will Moskau an der Smolina mit einem kleinen Heer entgegentreten.",
  {"year_min": 1495, "year_max": 1525, "alive": "RUS"},
  [O("Die Schlacht wagen.", {"prestige": 15, "manpower": -2, "relations": {"RUS": -30}}, 50),
   O("Ein Waffenstillstand für 50 Jahre.", {"relations": {"RUS": 40}, "dip": 20}),
   O("Söldner aus dem Reich.", {"regs": 2, "gold": -40})]),
E("byz_last_emperor", "BYZ", "Der letzte Kaiser", "Konstantin XI. bittet den Westen um Hilfe. Der Preis ist die Union mit Rom.",
  {"year_max": 1460, "alive": "TUR"},
  [O("Die Kirchenunion verkünden.", {"relations": {"PAP": 50, "VEN": 30}, "prestige": -10, "regs": 2}, 50),
   O("Lieber den Turban als die Tiara.", {"prestige": 10, "mil": 30}),
   O("Genuesische Söldner unter Giustiniani.", {"regs": 3, "gold": -50, "relations": {"GEN": 30}})]),
E("byz_morea", "BYZ", "Die Despoten von Morea", "Die Brüder des Kaisers streiten um die Halbinsel, während die Türken einmarschieren.",
  {"year_max": 1470},
  [O("Die Brüder versöhnen.", {"dip": 30, "prestige": 5}, 50),
   O("Den Hexamilion-Wall reparieren.", {"manpower": 2, "gold": -40}),
   O("Nach Italien fliehen, mit den Reliquien.", {"gold": 60, "prestige": -15})]),
E("bos_church", "BOS", "Die Bosnische Kirche", "Der König soll den Katholizismus annehmen, um Hilfe aus Ungarn und Rom zu bekommen. Viele seiner Adligen folgen der eigenen Kirche.",
  {"year_max": 1470},
  [O("Katholisch werden.", {"relations": {"PAP": 40, "HUN": 30}, "prestige": -5}, 50),
   O("Die alte Kirche schützen.", {"prestige": 10, "dip": -20}),
   O("Die Adligen selbst entscheiden lassen.", {"adm": 20})]),
# ------------------------------------------------------------------ the west
E("sav_shroud", "SAV", "Das Grabtuch", "Das Haus Savoyen besitzt ein Tuch, das als Grabtuch Christi verehrt wird. Pilger strömen nach Chambéry.",
  {"year_min": 1450, "year_max": 1600},
  [O("Eine Kapelle für das Tuch.", {"prestige": 10, "gold": -30}, 50),
   O("Pilgerzölle erheben.", {"gold": 50}),
   O("Das Tuch nach Turin bringen.", {"dev_capital": 1, "prestige": 5})]),
E("sav_emmanuel_philibert", "SAV", "Eisenkopf", "Emmanuel Philibert, ein Feldherr Spaniens, erhält sein Herzogtum zurück und will einen modernen Staat aufbauen.",
  {"year_min": 1555, "year_max": 1580},
  [O("Ein stehendes Heer.", {"mods": {"combat": 0.03}, "gold": -40}, 50),
   O("Italienisch als Amtssprache.", {"adm": 40}),
   O("Neutral zwischen Frankreich und Spanien.", {"dip": 40})]),
E("genoa_doria", "GEN", "Andrea Doria", "Der Admiral der Republik wechselt die Seiten: von Frankreich zu Spanien, gegen Freiheit für Genua.",
  {"year_min": 1515, "year_max": 1560},
  [O("Mit Spanien gegen Frankreich.", {"relations": {"SPA": 50, "FRA": -40}, "mods": {"income": 0.02}}, 60),
   O("Treu zu Frankreich.", {"relations": {"FRA": 40}, "mil": 20}),
   O("Neutral bleiben.", {"dip": 30})]),
E("prv_good_king_rene", "PRV", "Der gute König René", "Der alte König liebt Dichtung, Malerei und Turniere mehr als die Politik. Sein Erbe ist ungewiss.",
  {"year_max": 1485},
  [O("Ein Fest der Troubadoure.", {"prestige": 10, "gold": -30}, 50),
   O("Das Erbe Frankreich vermachen.", {"relations": {"FRA": 50}, "prestige": -5}),
   O("Ein Neffe aus Lothringen soll erben.", {"dip": 20})]),
E("bri_francis2", "BRI", "Herzog Franz II.", "Der Herzog will die Unabhängigkeit der Bretagne gegen Frankreich verteidigen und sucht Verbündete.",
  {"year_max": 1490, "alive": "FRA"},
  [O("Bündnis mit England.", {"relations": {"ENG": 50, "FRA": -30}, "dip": 20}, 40),
   O("Bündnis mit Habsburg.", {"relations": {"HAB": 50, "FRA": -30}}, 30),
   O("Frankreich nicht reizen.", {"relations": {"FRA": 30}, "prestige": -5}, 30)]),
E("nav_albret", "NAV", "Das Haus Albret", "Navarra liegt zwischen Frankreich und Kastilien. Die Königin muss sich entscheiden.",
  {"year_min": 1480, "year_max": 1520},
  [O("Anschluss an Frankreich.", {"relations": {"FRA": 50, "SPA": -30}}, 50),
   O("Anschluss an Kastilien.", {"relations": {"SPA": 50, "FRA": -30}}),
   O("Die Pässe befestigen.", {"manpower": 2, "gold": -30})]),
# ------------------------------------------------------------------ small German states
E("kol_soest", "KOL", "Die Soester Fehde", "Die reiche Stadt Soest sagt sich vom Erzbischof los und unterstellt sich dem Herzog von Kleve.",
  {"year_max": 1470},
  [O("Die Stadt belagern.", {"mil": -30, "prestige": 5}, 50),
   O("Einen Vergleich schließen.", {"gold": -30, "dip": 20}),
   O("Die Stadt aufgeben.", {"prestige": -10, "gold": 40})]),
E("wur_poor_conrad", "WUR", "Der Arme Konrad", "Neue Steuern auf Fleisch und Wein treiben die Bauern im Remstal zum Aufstand.",
  {"year_min": 1505, "year_max": 1525},
  [O("Den Tübinger Vertrag schließen.", {"adm": 30, "gold": -20}, 50),
   O("Den Aufstand niederschlagen.", {"mil": -20, "dev_random": -1}),
   O("Die Steuern zurücknehmen.", {"gold": -40, "prestige": 5})]),
E("nur_duerer", "NUR", "Albrecht Dürer", "Ein Maler aus der Stadt ist in ganz Europa berühmt. Der Rat könnte ihn mit Aufträgen halten.",
  {"year_min": 1490, "year_max": 1530},
  [O("Das Rathaus ausmalen lassen.", {"prestige": 10, "gold": -30}, 50),
   O("Seine Kupferstiche drucken und verkaufen.", {"gold": 50}),
   O("Ihn dem Kaiser empfehlen.", {"relations": {"HAB": 30}, "dip": 20})]),
E("hes_philip", "HES", "Philipp der Großmütige", "Der Landgraf gründet eine evangelische Universität und den Schmalkaldischen Bund.",
  {"year_min": 1520, "year_max": 1560},
  [O("Den Bund anführen.", {"relations": {"SAX": 40, "HAB": -30}, "prestige": 10}, 50),
   O("Die Universität Marburg stiften.", {"adm": 40, "gold": -30}),
   O("Beim Kaiser bleiben.", {"relations": {"HAB": 40}})]),
E("lun_salt", "LUN", "Das Lüneburger Salz", "Die Saline von Lüneburg versorgt den ganzen Ostseeraum. Die Stadt will weniger Abgaben zahlen.",
  {"year_min": 1450},
  [O("Abgaben senken, Handel fördern.", {"mods": {"income": 0.02}}, 50),
   O("Die Abgaben erhöhen.", {"gold": 60, "dip": -20}),
   O("Die Saline unter fürstliche Verwaltung.", {"adm": 25})]),
E("pom_bogislaw", "POM", "Bogislaw der Große", "Der Herzog vereinigt alle pommerschen Teilherzogtümer und reformiert die Verwaltung.",
  {"year_max": 1525},
  [O("Ein einheitliches Pommern.", {"adm": 40, "prestige": 5}, 50),
   O("Pilgerfahrt nach Jerusalem.", {"prestige": 15, "gold": -40}),
   O("Ein Erbvertrag mit Brandenburg.", {"relations": {"BRA": 50}, "prestige": -5})]),
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
