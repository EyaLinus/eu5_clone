"""Content for the map extension south and east (PR #58): Anatolian beyliks, Trebizond, the Turkmen
confederations, the Caucasus, the Mamluk sultanate, the Maghreb, Cyprus and the Knights of Rhodes.
National events (id prefix "south_") plus missions for TUR, MAM and MOR (ids "<tag>_south_*").
Run: python3 tools/content/south_events.py (idempotent, see events_io.py).

Rules as in the other generators: first option never costs gold, gold options get low AI weight,
war options stay below 50 % AI weight, missions use owns only for lands the nation holds at the start
(require.owns keys become starting claims) and owns_any for other realms' lands.
"""
import json
import os

import events_io

ROOT = events_io.ROOT


def _ai(o):
    if o[1].get("gold", 0) < 0:
        return {"ai": min(o[2] if len(o) > 2 else 10, 10)}
    return {"ai": o[2]} if len(o) > 2 else {}


def ev(id, tag, title, text, image, trigger, options, once=True):
    e = {"id": "south_" + id}
    if not once:
        e["once"] = False
    e.update({"tag": tag, "title": title, "text": text, "image": image, "trigger": trigger,
              "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]})
    return e


EVENTS = [
    # --- Ottomans and the Anatolian beyliks
    ev("tur_karaman", "TUR", "Die Karamaniden",
       "Das Beylik Karaman hält Konya und verbündet sich mit jedem Feind des Sultans. Die Wesire raten zum Feldzug.", "battle",
       {"year_min": 1460, "year_max": 1490, "alive": "KAR", "not_owns": ["konya"], "at_peace": True},
       [("Den Anspruch auf Konya erneuern.", {"claim": ["konya", "larende"], "dip": -20}),
        ("Krieg gegen Karaman!", {"war": "KAR", "mil": 20}, 35),
        ("Die Grenze befestigen.", {"mil": 30, "relations": {"KAR": 10}})]),
    ev("tur_candar", "TUR", "Die Herren von Sinop",
       "Der Bey von Candar besitzt Kupferminen und einen guten Hafen. Er bietet an, dem Sultan zu dienen.", "treaty",
       {"year_min": 1455, "year_max": 1475, "alive": "CND"},
       [("Ihn als Vasallen annehmen.", {"vassal": "CND", "dip": -20}),
        ("Lieber Tribut fordern.", {"gold": 40, "relations": {"CND": -15}}),
        ("Sinop selbst nehmen.", {"claim": ["sinop", "kastamonu"], "mil": 15}, 25)]),
    ev("tur_trebizond", "TUR", "Das Kaiserreich Trapezunt",
       "Das letzte griechische Kaiserreich an der Schwarzmeerküste sucht Hilfe bei den Turkmenen und in Georgien.", "siege",
       {"year_min": 1458, "year_max": 1470, "alive": "TRE"},
       [("Anspruch auf Trapezunt.", {"claim": ["trebizond"], "prestige": 3}),
        ("Die Stadt belagern.", {"war": "TRE", "mil": 15}, 30),
        ("Gegen Tribut in Ruhe lassen.", {"gold": 35, "relations": {"TRE": 15}})]),
    ev("tur_dulkadir", "TUR", "Streit um Dulkadir",
       "Das Grenzfürstentum Dulkadir schwankt zwischen Sultan und Mamluken. Beide Höfe schicken Gesandte.", "court",
       {"year_min": 1480, "year_max": 1520, "alive": "DUL"},
       [("Gold und Versprechen für den Bey.", {"relations": {"DUL": 25, "MAM": -15}, "dip": -15}),
        ("Ihn zum Vasallen machen.", {"vassal": "DUL", "relations": {"MAM": -30}}, 25),
        ("Den Mamluken nicht reizen.", {"relations": {"MAM": 15}, "prestige": -2})]),
    # --- Anatolia and the east
    ev("kar_venice", "KAR", "Gesandte aus Venedig",
       "Venedig sucht Verbündete gegen den Sultan und bietet Geld und Geschütze, wenn Karaman den Osmanen in den Rücken fällt.", "treaty",
       {"year_min": 1460, "year_max": 1480, "alive": "VEN"},
       [("Ein Bündnis mit Venedig.", {"relations": {"VEN": 30, "TUR": -20}, "gold": 30}),
        ("Nur das Gold nehmen.", {"gold": 50, "relations": {"VEN": -10}}),
        ("Wir halten Frieden mit dem Sultan.", {"relations": {"TUR": 20}, "dip": 15})]),
    ev("cnd_copper", "CND", "Die Kupferminen von Kastamonu",
       "Die Bergleute haben eine neue reiche Ader gefunden. Kaufleute aus Genua wollen alles kaufen.", "mine",
       {"year_min": 1450},
       [("An die Genuesen verkaufen.", {"gold": 50, "relations": {"GEN": 15}}),
        ("Eigene Münzen prägen.", {"prestige": 4, "adm": 20}),
        ("Waffen schmieden lassen.", {"mil": 30})]),
    ev("dul_between", "DUL", "Zwischen zwei Sultanen",
       "Der Sultan in Istanbul und der Sultan in Kairo verlangen beide Gefolgschaft. Dulkadir muss wählen.", "border",
       {"year_min": 1470, "year_max": 1520},
       [("Treue zu Kairo.", {"relations": {"MAM": 25, "TUR": -10}}),
        ("Hinwendung zu Istanbul.", {"relations": {"TUR": 25, "MAM": -10}}),
        ("Beide hinhalten.", {"dip": 25, "prestige": -2})]),
    ev("tre_comnenus", "TRE", "Die Komnenen suchen Freunde",
       "Kaiser David Komnenos will seine Nichte an Uzun Hasan verheiraten und Georgien um Hilfe bitten.", "wedding",
       {"year_min": 1455, "year_max": 1470},
       [("Die Heirat mit Uzun Hasan.", {"relations": {"AKK": 35}, "prestige": 3}),
        ("Ein Bund mit Georgien.", {"alliance": "GEO", "dip": -10}),
        ("Mauern statt Bündnisse.", {"mil": 30, "manpower": 1000})]),
    ev("akk_uzun_hasan", "AKK", "Uzun Hasan",
       "Der Lange Hasan hat die Stämme der Weißen Hammel geeint. Er träumt von einem Reich bis nach Persien.", "coronation",
       {"year_min": 1457, "year_max": 1478},
       [("Gegen die Schwarzen Hammel ziehen.", {"claim": ["tabriz"], "mil": 20}),
        ("Gesandte nach Venedig.", {"relations": {"VEN": 30}, "dip": 20}),
        ("Erst die Stämme ordnen.", {"adm": 30, "manpower": 1500})]),
    ev("akk_venice_guns", "AKK", "Geschütze aus Venedig",
       "Venedig hat Kanonen und Büchsenmeister geschickt. Sie wollen dafür, dass du den Sultan angreifst.", "artillery",
       {"year_min": 1465, "year_max": 1480, "alive": "VEN"},
       [("Die Geschütze nehmen und abwarten.", {"mods": {"combat": 0.02}, "relations": {"VEN": -10}}),
        ("Gegen den Sultan ziehen.", {"mods": {"combat": 0.02}, "war": "TUR"}, 10),
        ("Zurückschicken.", {"relations": {"TUR": 20, "VEN": -20}})]),
    ev("qar_jahan_shah", "QAR", "Dschahan Schah",
       "Der Herrscher der Schwarzen Hammel ist ein Dichter und Eroberer. Seine Generäle drängen nach Westen.", "court",
       {"year_min": 1450, "year_max": 1467},
       [("Die Dichter fördern.", {"prestige": 5, "adm": 15}),
        ("Gegen die Weißen Hammel rüsten.", {"mil": 30, "claim": ["diyarbakir"]}),
        ("Frieden mit dem Westen.", {"relations": {"AKK": 20}, "dip": 20})]),
    ev("geo_division", "GEO", "Das Königreich zerfällt",
       "Die Fürsten von Imeretien und Kachetien wollen eigene Könige sein. Der Hof in Tiflis ist machtlos.", "conspiracy",
       {"year_min": 1460, "year_max": 1500},
       [("Den Fürsten Rechte geben.", {"estate": {"adel": 10}, "adm": -20}),
        ("Mit Gewalt zusammenhalten.", {"mil": -25, "prestige": 4}),
        ("Die Kirche soll vermitteln.", {"estate": {"klerus": 8}, "dip": 15})]),
    ev("geo_wine", "GEO", "Wein aus dem Kaukasus",
       "Georgische Mönche keltern Wein in Tonamphoren nach uralter Art. Händler aus Persien wollen ihn kaufen.", "harvest",
       {"year_min": 1450},
       [("Verkaufen.", {"gold": 40}),
        ("Den Klöstern schenken.", {"estate": {"klerus": 8}, "prestige": 2}),
        ("Gesandte damit beschenken.", {"dip": 30})]),
    ev("shi_silk", "SHI", "Seide aus Schirwan",
       "Die Seide aus Schemacha ist in ganz Asien begehrt. Karawanen nach Moskau und Täbris warten.", "market",
       {"year_min": 1450},
       [("Zölle auf die Karawanen.", {"gold": 45}),
        ("Händler aus Moskau anlocken.", {"relations": {"RUS": 20}, "mods": {"trade": 0.02}}),
        ("Seidenweber ansiedeln.", {"dev_capital": 1, "adm": -20})]),
    ev("cir_mamluks", "CIR", "Krieger für Kairo",
       "Sklavenhändler kaufen junge Tscherkessen für die Mamluken. Manche kehren als Emire zurück.", "camp",
       {"year_min": 1450, "alive": "MAM"},
       [("Die Verbindung nach Kairo pflegen.", {"relations": {"MAM": 25}, "manpower": -500}),
        ("Den Handel verbieten.", {"manpower": 1500, "relations": {"MAM": -15}}),
        ("Zurückkehrende Emire anwerben.", {"mods": {"combat": 0.02}, "gold": -30})]),
    # --- the Mamluks
    ev("mam_qaitbay", "MAM", "Sultan Qaitbay baut",
       "Der neue Sultan lässt Moscheen, Festungen und Brunnen bauen, von Alexandria bis Mekka.", "city",
       {"year_min": 1468, "year_max": 1496},
       [("Die Festung in Alexandria.", {"mil": 30, "prestige": 3}),
        ("Moscheen und Schulen.", {"estate": {"klerus": 8}, "dev_capital": 1}),
        ("Lieber den Schatz füllen.", {"gold": 50})]),
    ev("mam_spice", "MAM", "Der Gewürzhandel",
       "Pfeffer und Zimt aus Indien kommen über das Rote Meer nach Alexandria. Venezianer zahlen jeden Preis.", "market",
       {"year_min": 1450, "year_max": 1500},
       [("Die Zölle erhöhen.", {"gold": 60, "relations": {"VEN": -15}}),
        ("Ein Monopol des Sultans.", {"mods": {"trade": 0.02}, "estate": {"buerger": -5}}),
        ("Die Venezianer verwöhnen.", {"relations": {"VEN": 30}, "dip": 15})]),
    ev("mam_portuguese", "MAM", "Die Portugiesen im Indischen Ozean",
       "Portugiesische Schiffe umsegeln Afrika und kapern die Gewürzschiffe. Der Handel über Alexandria bricht ein.", "naval",
       {"year_min": 1500, "year_max": 1515},
       [("Eine Flotte nach Indien schicken.", {"mil": -30, "prestige": 3}),
        ("Venedig um Hilfe bitten.", {"relations": {"VEN": 20}, "dip": -20}),
        ("Neue Handelswege über Syrien.", {"adm": -25, "mods": {"trade": 0.01}})]),
    ev("mam_selim", "MAM", "Der Sultan von Istanbul rüstet",
       "Spione melden: Der osmanische Sultan sammelt Heer und Geschütze. Sein Ziel ist Syrien.", "artillery",
       {"year_min": 1510, "year_max": 1520, "alive": "TUR"},
       [("Die Grenzfesten verstärken.", {"mil": 30, "manpower": 1500}),
        ("Feuerwaffen kaufen.", {"mods": {"combat": 0.03}, "gold": -60}),
        ("Gesandte mit Geschenken.", {"relations": {"TUR": 25}, "prestige": -3})]),
    # --- the Maghreb
    ev("tun_corsairs", "TUN", "Die Korsaren von Tunis",
       "Korsaren laufen mit reicher Beute aus Sizilien und Sardinien in den Hafen ein. Der Sultan bekommt ein Fünftel.", "naval",
       {"year_min": 1450},
       [("Das Fünftel nehmen.", {"gold": 40, "relations": {"ARA": -15}}),
        ("Die Korsaren in die Flotte holen.", {"mil": 25, "prestige": 2}),
        ("Mit Aragon Frieden halten.", {"relations": {"ARA": 20}, "dip": 15})], once=False),
    ev("tle_between", "TLE", "Zwischen Fes und Tunis",
       "Tlemcen liegt zwischen den Meriniden und den Hafsiden. Beide wollen die reiche Karawanenstadt.", "border",
       {"year_min": 1450, "year_max": 1550},
       [("Tunis um Schutz bitten.", {"relations": {"TUN": 25, "MOR": -10}}),
        ("Fes um Schutz bitten.", {"relations": {"MOR": 25, "TUN": -10}}),
        ("Gold aus dem Saharahandel für Söldner.", {"gold": 30, "mil": 15})]),
    ev("mor_wattasid", "MOR", "Die Wattasiden",
       "Die Wesire aus dem Haus der Wattasiden haben die letzten Meriniden entmachtet. Die Stämme warten ab.", "coronation",
       {"year_min": 1465, "year_max": 1480},
       [("Die Stämme mit Geschenken binden.", {"estate": {"adel": 8}, "prestige": 2}),
        ("Die Sufi-Bruderschaften gewinnen.", {"estate": {"klerus": 8}, "adm": 15}),
        ("Mit harter Hand regieren.", {"mil": 25, "estate": {"adel": -5}})]),
    ev("mor_tangier", "MOR", "Die Portugiesen vor Tanger",
       "Portugiesische Schiffe liegen vor Tanger. Ceuta haben sie schon, jetzt wollen sie mehr.", "siege",
       {"year_min": 1460, "year_max": 1480, "alive": "POR", "owns": ["tangier"]},
       [("Die Stadt verteidigen.", {"mil": 30, "manpower": 1500}),
        ("Mit Lissabon verhandeln.", {"relations": {"POR": 25}, "dip": -20}),
        ("Den heiligen Krieg ausrufen.", {"prestige": 5, "estate": {"klerus": 6}, "relations": {"POR": -20}})]),
    ev("mor_saadi", "MOR", "Die Saadier aus dem Süden",
       "Im Sous ruft eine Familie von Scherifen zum Kampf gegen die Portugiesen. Ihr Ansehen wächst.", "procession",
       {"year_min": 1510, "year_max": 1560},
       [("Sie an den Hof holen.", {"estate": {"klerus": 6}, "prestige": 4}),
        ("Ihnen den Kampf überlassen.", {"mil": 25, "relations": {"POR": -15}}),
        ("Ihre Macht beschneiden.", {"adm": 20, "estate": {"klerus": -6}})]),
    # --- Cyprus and Rhodes
    ev("ven_cyprus", "VEN", "Caterina Cornaro",
       "Die Venezianerin Caterina Cornaro ist Königin von Zypern, ihr Mann ist tot. Der Rat der Zehn will die Insel für die Republik.", "wedding",
       {"year_min": 1480, "year_max": 1495, "alive": "CYP", "allied": "CYP"},
       [("Zypern erben.", {"inherit": "CYP", "prestige": 5}, 40),
        ("Die Königin regieren lassen.", {"relations": {"CYP": 30}, "dip": 20}),
        ("Ein Handelsprivileg genügt.", {"mods": {"trade": 0.02}})]),
    ev("kni_rhodes", "KNI", "Die Belagerung von Rhodos",
       "Eine osmanische Flotte liegt vor der Insel. Großmeister d'Aubusson ruft die Ritter auf die Mauern.", "siege",
       {"year_min": 1478, "year_max": 1485, "alive": "TUR"},
       [("Die Mauern verstärken.", {"mil": 30, "manpower": 1000}),
        ("Hilfe aus dem Westen erbitten.", {"relations": {"PAP": 25, "FRA": 15}, "dip": -15}),
        ("Ein Ausfall bei Nacht.", {"prestige": 6, "manpower": -800})]),
]

MISSIONS = {
    "TUR": [
        ("tur_south_anatolia", None, "Herr Anatoliens", "Die Beyliks von Karaman und Candar müssen sich dem Sultan beugen.",
         {"owns_any": ["konya", "kastamonu", "sinop"]}, {"prestige": 10, "adm": 40}),
        ("tur_south_east", "tur_south_anatolia", "Die Ostgrenze", "Trapezunt und die Pässe nach Armenien sichern das Reich gegen die Turkmenen.",
         {"owns_any": ["trebizond", "erzurum", "diyarbakir"]}, {"mods": {"manpower": 0.05}, "mil": 40}),
    ],
    "MAM": [
        ("mam_south_syria", None, "Syrien halten", "Aleppo und Damaskus sind die Bollwerke des Sultanats im Norden.",
         {"owns": ["aleppo", "damascus"], "year_min": 1480}, {"mil": 40, "prestige": 10}),
        ("mam_south_spices", "mam_south_syria", "Der Gewürzweg", "Märkte in Alexandria und Kairo halten den Indienhandel im Land.",
         {"building": {"marketplace": 2}}, {"mods": {"trade": 0.03}, "dip": 30}),
        ("mam_south_dulkadir", None, "Freunde an der Grenze", "Dulkadir soll ein treuer Puffer gegen die Osmanen bleiben.",
         {"allied": "DUL", "year_min": 1470}, {"dip": 40, "prestige": 5}),
    ],
    "MOR": [
        ("mor_south_coast", None, "Die Küste halten", "Tanger und Rabat dürfen nicht an die Portugiesen fallen.",
         {"owns": ["tangier", "rabat"], "year_min": 1490}, {"mil": 40, "prestige": 10}),
        ("mor_south_harbors", "mor_south_coast", "Häfen am Atlantik", "Ausgebaute Häfen bringen Zucker- und Saharahandel ins Land.",
         {"building": {"harbor": 2}}, {"mods": {"trade": 0.03}, "dip": 30}),
    ],
}


def render_mission(m):
    head = {k: m[k] for k in ("id", "after", "title", "desc") if k in m}
    s = "    " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    return s + '     "require": ' + json.dumps(m["require"], ensure_ascii=False) + ', "reward": ' + json.dumps(m["reward"], ensure_ascii=False) + "}"


def check(e, nations):
    assert len(e["options"]) == 3, e["id"]
    assert e["tag"] in nations, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0 and "war" not in first, e["id"]
    for o in e["options"]:
        for v in o["effects"].get("mods", {}).values():
            assert abs(v) <= 0.03, e["id"]
        for k in ("war", "vassal", "alliance", "inherit"):
            assert k not in o["effects"] or o["effects"][k] in nations, e["id"]
        if "war" in o["effects"]:
            assert o.get("ai", 25) < 50, e["id"]


def main():
    nations = json.load(open(os.path.join(ROOT, "data/nations.json"), encoding="utf-8"))
    for e in EVENTS:
        check(e, nations)
    data = events_io.replace_block("south_", EVENTS)
    path = os.path.join(ROOT, "data/missions.json")
    ms = json.load(open(path, encoding="utf-8"))
    for tag, lst in MISSIONS.items():
        keep = [m for m in ms.setdefault(tag, []) if "_south_" not in m["id"]]
        for (id, after, title, desc, req, rew) in lst:
            m = {"id": id}
            if after:
                m["after"] = after
            m.update({"title": title, "desc": desc, "require": req, "reward": rew})
            keep.append(m)
        ms[tag] = keep
    out = "{\n" + ",\n".join('  "%s": [\n' % t + ",\n".join(render_mission(m) for m in v) + "\n  ]" for t, v in ms.items()) + "\n}\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)
    print("events %d (south %d), missions TUR %d MAM %d MOR %d" % (len(data), len(EVENTS), len(ms["TUR"]), len(ms["MAM"]), len(ms["MOR"])))


if __name__ == "__main__":
    main()
