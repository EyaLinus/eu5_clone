"""Late-game content for 1600-1644: by then most techs are done and the player had little left to decide.
Generic events (prefix "era_") plus one late mission per playable nation ("<tag>_era_*").
Run: python3 tools/content/late_era.py (idempotent, see events_io.py).

The score at the end is development + prestige + 3 x tech levels, so the late choices mostly trade gold, mana
and estates for prestige or development. Rules as in the other generators: first option gold-free,
gold options AI weight <= 10, mods <= 0.03; repeatable or always-eligible flavour is player-only.
Mission requirements avoid "owns" on foreign land (owns keys become starting claims).
"""
import json
import os

import events_io

ROOT = events_io.ROOT


def _ai(o):
    ai = o[2] if len(o) > 2 else None
    if o[1].get("gold", 0) < 0:
        ai = min(ai if ai is not None else 10, 10)
    return {"ai": ai} if ai is not None else {}


def ev(id, title, text, image, trigger, options):
    return {"id": "era_" + id, "tag": "*", "title": title, "text": text, "image": image, "trigger": trigger,
            "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]}


EVENTS = [
    ev("company_shares", "Anteile an einer Handelskompanie",
       "Kaufleute gründen eine Kompanie für den Fernhandel und verkaufen Anteile an jeden, der Geld hat. Auch die Krone soll zeichnen.",
       "bank", {"year_min": 1602, "building": {"marketplace": 3}},
       [("Den Kaufleuten ein Privileg geben.", {"estate": {"buerger": 5}, "dip": 15}),
        ("Die Krone zeichnet Anteile.", {"gold": -60, "mods": {"trade": 0.03}}, 8),
        ("Den Gewinn besteuern.", {"gold": 40, "estate": {"buerger": -4}})]),
    ev("telescope", "Das Fernrohr",
       "Ein Gelehrter richtet ein neues Fernrohr auf den Himmel. Er sieht Monde, Flecken auf der Sonne und Berge auf dem Mond.",
       "scholar", {"year_min": 1610},
       [("Ihn an den Hof holen.", {"prestige": 4, "estate": {"klerus": -2}}),
        ("Fernrohre für die Flotte und das Heer.", {"mil": 25}),
        ("Die Kirche prüfen lassen.", {"estate": {"klerus": 4}, "adm": 10})]),
    ev("court_painter", "Ein Hofmaler",
       "Ein Maler aus Antwerpen, der schon Könige und Päpste gemalt hat, bietet ein großes Bildnis des Herrschers an.",
       "artist", {"year_min": 1605},
       [("Ein Bildnis zu Pferde.", {"prestige": 4, "dip": -10}),
        ("Ein Deckengemälde für den Palast.", {"gold": -50, "prestige": 8}, 8),
        ("Bilder als Geschenke für fremde Höfe.", {"dip": 30})]),
    ev("opera", "Die erste Oper",
       "Am Hof wird ein Drama ganz in Musik aufgeführt. Die Gäste sind begeistert, die Kämmerer entsetzt über die Kosten.",
       "court", {"year_min": 1620},
       [("Einmal im Jahr, nicht öfter.", {"prestige": 3}),
        ("Ein eigenes Opernhaus.", {"gold": -50, "prestige": 6, "dev_capital": 1}, 8),
        ("Für die Bürger öffnen.", {"estate": {"buerger": 5}, "prestige": 1})]),
    ev("postal", "Eine Post für das ganze Land",
       "Ein Unternehmer will feste Postlinien durch das ganze Land einrichten, mit Pferdewechsel alle paar Meilen.",
       "treaty", {"year_min": 1610},
       [("Eine Post der Krone.", {"adm": 25, "dip": 15}),
        ("Ihm ein Monopol verkaufen.", {"gold": 50, "estate": {"buerger": -2}}),
        ("Die Städte sollen das regeln.", {"estate": {"buerger": 4}})]),
    ev("fortress_cities", "Festungsstädte",
       "Die neuen Geschütze zerschlagen jede alte Mauer. Die Baumeister schlagen sternförmige Festungen mit tiefen Gräben vor.",
       "siege", {"year_min": 1610, "tech": {"mil": 12}},
       [("Nur die Hauptstadt befestigen.", {"mil": 20, "adm": -10}),
        ("Eine Festung an der Grenze bauen.", {"build": "fortress", "mil": -25}),
        ("Lieber ein stehendes Heer.", {"manpower": 1500})]),
    ev("absolutism", "Der Fürst über dem Gesetz",
       "Die Hofjuristen erklären, dass der Herrscher an kein Gesetz gebunden ist, nur an Gott. Die Stände sind empört.",
       "coronation", {"year_min": 1620},
       [("Die Stände nicht mehr einberufen.", {"adm": 30, "estate": {"adel": -5, "buerger": -3}}),
        ("Die alten Rechte bestätigen.", {"estate": {"adel": 5, "buerger": 3}, "prestige": -1}),
        ("Nur den Adel an den Hof binden.", {"estate": {"adel": 4}, "prestige": 3, "adm": -15})]),
    ev("witch_trials", "Die große Hexenangst",
       "In mehreren Dörfern werden Frauen der Hexerei angeklagt. Prediger schüren die Angst, die Gerichte sind überfordert.",
       "inquisition", {"year_min": 1600, "year_max": 1640, "not_flag": "ev_gen_witch_trials"},
       [("Die Prozesse an die Landesgerichte ziehen.", {"adm": 20, "estate": {"klerus": -3}}),
        ("Die Folter verbieten.", {"estate": {"buerger": 4, "klerus": -4}, "prestige": 2}),
        ("Die Prediger gewähren lassen.", {"estate": {"klerus": 4}, "adm": -10})]),
    ev("veterans", "Abgedankte Söldner",
       "Nach dem letzten Krieg ziehen entlassene Söldner durchs Land. Sie wollen Sold, Land oder einen neuen Krieg.",
       "camp", {"year_min": 1620, "at_peace": True},
       [("Ihnen Land an der Grenze geben.", {"manpower": 2000, "estate": {"adel": -3}}),
        ("Sie in die Garnisonen aufnehmen.", {"mil": 25, "adm": -10}),
        ("Sie mit Gold heimschicken.", {"gold": -40, "estate": {"buerger": 4}}, 8)]),
    ev("little_ice_age", "Kalte Jahre",
       "Die Winter sind länger als je zuvor, Flüsse frieren zu, das Korn reift nicht. Die Bauern hungern.",
       "famine", {"year_min": 1620},
       [("Die Kornspeicher öffnen.", {"estate": {"buerger": 4}, "adm": -15}),
        ("Korn aus dem Ausland kaufen.", {"gold": -40, "estate": {"buerger": 5}, "prestige": 1}, 8),
        ("Neue Feldfrüchte anbauen lassen.", {"adm": -25, "dev_random": 1})]),
    ev("tulip_mania", "Das Tulpenfieber",
       "Auf den Märkten werden Tulpenzwiebeln zu Preisen gehandelt, für die man ein Haus kaufen könnte. Auch Höflinge spekulieren.",
       "market", {"year_min": 1630, "year_max": 1640, "building": {"marketplace": 2}},
       [("Die Finger davon lassen.", {"adm": 15}),
        ("Den Handel besteuern, solange er läuft.", {"gold": 45, "estate": {"buerger": -3}}),
        ("Die Krone kauft Zwiebeln.", {"gold": -40, "prestige": -1, "estate": {"buerger": 3}}, 3)]),
    ev("westphalia", "Ein Friedenskongress",
       "In zwei Städten verhandeln Gesandte aus ganz Europa über einen allgemeinen Frieden. Wer nicht dabei ist, wird übergangen.",
       "treaty", {"year_min": 1640, "hre": True},
       [("Einen klugen Gesandten schicken.", {"dip": 30, "prestige": 3}),
        ("Mit großem Gefolge auftreten.", {"gold": -50, "prestige": 7}, 8),
        ("Die Ergebnisse abwarten.", {"adm": 20})]),
    ev("academy_sciences", "Eine Akademie der Wissenschaften",
       "Gelehrte schlagen eine Akademie vor, in der Mathematiker, Ärzte und Naturforscher gemeinsam arbeiten.",
       "scholar", {"year_min": 1625, "building": {"university": 1}},
       [("Die Akademie gründen.", {"prestige": 5, "adm": -20}),
        ("Preisfragen ausschreiben.", {"adm": 25, "dip": 10}),
        ("Ein eigenes Gebäude stiften.", {"gold": -60, "prestige": 6, "dev_capital": 1}, 8)]),
    ev("chronicle", "Die Chronik des Zeitalters",
       "Der Hofhistoriograph schreibt die Geschichte deines Reiches seit 1444. Er fragt, was die Nachwelt vor allem erinnern soll.",
       "printing", {"year_min": 1636, "is_player": True},
       [("Die Siege und den Ruhm.", {"prestige": 6}),
        ("Die Städte und den Wohlstand.", {"dev_capital": 2}),
        ("Die Gelehrsamkeit.", {"adm": 40, "prestige": 2})]),
]

# (id, title, desc, require, reward)
MISSIONS = {
    "ENG": ("eng_era_empire", "Herrin der Meere", "Eine Flotte, die jede Küste erreicht, und Häfen im ganzen Reich.",
            {"year_min": 1600, "ships_min": 20, "building": {"harbor": 6}}, {"prestige": 25, "mods": {"naval": 0.03}}),
    "FRA": ("fra_era_grand_siecle", "Das Große Jahrhundert", "Drei Großprojekte zeigen Europa, wer den Ton angibt.",
            {"year_min": 1600, "monuments_min": 3, "min_dev": 350}, {"prestige": 25, "dip": 50}),
    "SPA": ("spa_era_siglo_de_oro", "Das Goldene Zeitalter", "Ein Palast und eine Universität für die Dichter und Maler Spaniens.",
            {"year_min": 1600, "monument": "palace", "building": {"university": 1}}, {"prestige": 25, "dev_capital": 2}),
    "BOH": ("boh_era_rudolfine", "Das Prag Rudolfs", "Gelehrte, Künstler und Alchemisten am Hof der goldenen Stadt.",
            {"year_min": 1600, "building": {"university": 1}, "monuments_min": 1}, {"prestige": 20, "adm": 60}),
    "HAB": ("hab_era_danube", "Die Donaumonarchie", "Österreich, Böhmen und Ungarn unter einer Krone.",
            {"year_min": 1600, "owns": ["wien"], "owns_any": ["prague", "buda"], "min_dev": 300}, {"prestige": 25, "mil": 50}),
    "RUS": ("rus_era_romanov", "Das Haus Romanow", "Nach der Zeit der Wirren ein starker Staat mit eigenem Zeughaus.",
            {"year_min": 1613, "min_dev": 250, "building": {"arsenal": 1}}, {"prestige": 25, "manpower": 3000}),
    "NAP": ("nap_era_baroque", "Neapel, die größte Stadt Italiens", "Märkte, Paläste und Kirchen für eine Stadt mit einer Viertelmillion Menschen.",
            {"year_min": 1600, "building": {"marketplace": 4}, "monuments_min": 2}, {"prestige": 20, "dev_capital": 2}),
    "BUR": ("bur_era_low_countries", "Die Kammer Europas", "Die reichsten Städte der Welt und eine Börse, auf die alle schauen.",
            {"year_min": 1600, "owns": ["flanders", "brabant", "holland"], "building": {"exchange": 1}}, {"prestige": 25, "mods": {"trade": 0.03}}),
    "POL": ("pol_era_bulwark", "Vormauer der Christenheit", "Festungen an allen Grenzen gegen Türken, Tataren und Moskowiter.",
            {"year_min": 1600, "building": {"fortress": 4}, "min_dev": 250}, {"prestige": 25, "mil": 50}),
    "TUR": ("tur_era_order", "Die alte Ordnung", "Ein Reich, so groß, dass nur noch Ordnung und Pracht es zusammenhalten.",
            {"year_min": 1600, "min_dev": 600, "monuments_min": 2}, {"prestige": 25, "adm": 60}),
}


def render_mission(m):
    head = {k: m[k] for k in ("id", "after", "title", "desc") if k in m}
    s = "    " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    return s + '     "require": ' + json.dumps(m["require"], ensure_ascii=False) + ', "reward": ' + json.dumps(m["reward"], ensure_ascii=False) + "}"


def check(e):
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0, e["id"]
    for o in e["options"]:
        for v in o["effects"].get("mods", {}).values():
            assert abs(v) <= 0.03, e["id"]
        if o["effects"].get("gold", 0) < 0:
            assert o.get("ai", 25) <= 10, e["id"]


def main():
    nations = json.load(open(os.path.join(ROOT, "data/nations.json"), encoding="utf-8"))
    for e in EVENTS:
        check(e)
    data = events_io.replace_block("era_", EVENTS)
    path = os.path.join(ROOT, "data/missions.json")
    ms = json.load(open(path, encoding="utf-8"))
    for tag, (id, title, desc, req, rew) in MISSIONS.items():
        assert tag in nations and id.startswith(tag.lower() + "_era_"), id
        ms[tag] = [m for m in ms[tag] if "_era_" not in m["id"]] + [
            {"id": id, "title": title, "desc": desc, "require": req, "reward": rew}]
    out = "{\n" + ",\n".join('  "%s": [\n' % t + ",\n".join(render_mission(m) for m in v) + "\n  ]" for t, v in ms.items()) + "\n}\n"
    assert json.loads(out) == ms
    open(path, "w", encoding="utf-8").write(out)
    print("events %d (era %d), era missions %d" % (len(data), len(EVENTS), len(MISSIONS)))


if __name__ == "__main__":
    main()
