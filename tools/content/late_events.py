"""Later-era national events (1480-1700) for the three "extra" playables Burgundy, Poland and the Ottomans,
whose own events were thinner or mostly early. Id prefixes "bur_late_", "pol_late_", "tur_late_".
Run: python3 tools/content/late_events.py (idempotent, see events_io.py).

Burgundy rarely survives 1477 historically; its late events assume it did (alternate history, gated by
owning its core provinces). Rules as in the other generators: first option gold-free and never a war,
war options AI weight < 50, gold options AI weight <= 10, mods <= 0.03.
"""
import json
import os

import events_io


def _ai(o):
    ai = o[2] if len(o) > 2 else None
    if o[1].get("gold", 0) < 0:
        ai = min(ai if ai is not None else 10, 10)
    return {"ai": ai} if ai is not None else {}


def ev(id, tag, title, text, image, trigger, options):
    return {"id": tag.lower() + "_late_" + id, "tag": tag, "title": title, "text": text, "image": image,
            "trigger": trigger, "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]}


EVENTS = [
    # --- Burgundy (if it survives the 1470s)
    ev("estates_general", "BUR", "Die Generalstände",
       "Die Stände aller burgundischen Länder sollen zum ersten Mal gemeinsam tagen. Jede Provinz fürchtet um ihre Rechte.", "diet",
       {"year_min": 1480, "year_max": 1530, "owns": ["flanders", "brabant"]},
       [("Gemeinsame Steuern beschließen.", {"mods": {"tax": 0.02}, "estate": {"buerger": -4}}),
        ("Die alten Rechte bestätigen.", {"estate": {"buerger": 6, "adel": 2}}),
        ("Jede Provinz einzeln verhandeln.", {"adm": 30})]),
    ev("erasmus", "BUR", "Erasmus von Rotterdam",
       "Der berühmteste Gelehrte Europas stammt aus deinen Landen. Er schreibt über Frieden, Bildung und die Fehler der Kirche.", "scholar",
       {"year_min": 1500, "year_max": 1536, "owns": ["holland"]},
       [("Ihn an den Hof holen.", {"prestige": 4, "adm": 20}),
        ("Seine Schriften drucken lassen.", {"estate": {"buerger": 4, "klerus": -3}, "dip": 15}),
        ("Die Kirche will ihn zum Schweigen bringen.", {"estate": {"klerus": 5}, "prestige": -1})]),
    ev("bruegel", "BUR", "Die flämischen Meister",
       "Maler aus Antwerpen und Brügge sind in ganz Europa begehrt. Fürsten bestellen Bilder zu jedem Preis.", "artist",
       {"year_min": 1520, "year_max": 1600, "owns": ["flanders"]},
       [("Bilder als Geschenke für fremde Höfe.", {"dip": 30, "prestige": 2}),
        ("Eine Gilde der Maler fördern.", {"estate": {"buerger": 5}, "gold": 20}),
        ("Ein großes Altarbild für die Hauptstadt.", {"gold": -40, "prestige": 6})]),
    ev("dykes", "BUR", "Die Deiche brechen",
       "Eine Sturmflut hat die Deiche in Holland durchbrochen. Ganze Dörfer stehen unter Wasser.", "famine",
       {"year_min": 1480, "owns": ["holland"]},
       [("Die Dörfer müssen sich selbst helfen.", {"estate": {"buerger": -4}, "adm": 10}),
        ("Ein Deichverband für das ganze Land.", {"adm": -30, "dev_random": 1}),
        ("Die Krone bezahlt den Wiederaufbau.", {"gold": -50, "estate": {"buerger": 6}})]),
    ev("admiralty", "BUR", "Eine Admiralität für die Niederlande",
       "Die Seestädte wollen eine eigene Admiralität, um ihre Handelsschiffe gegen Freibeuter zu schützen.", "naval",
       {"year_min": 1490, "owns": ["holland", "flanders"]},
       [("Die Städte sollen sie bezahlen.", {"ships": 2, "estate": {"buerger": -3}}),
        ("Eine Admiralität der Krone.", {"mil": -20, "ships": 3, "prestige": 2}),
        ("Der Handel schützt sich selbst.", {"estate": {"buerger": 4}})]),
    ev("crown_question", "BUR", "Die Frage der Krone",
       "Der Kaiser bietet erneut an, Burgund zum Königreich zu erheben. Dafür will er Hilfe gegen Frankreich.", "coronation",
       {"year_min": 1480, "year_max": 1560, "alive": "FRA"},
       [("Die Bedingungen prüfen.", {"dip": 25, "relations": {"HAB": 15}}),
        ("Annehmen, auch gegen Frankreich.", {"prestige": 8, "relations": {"FRA": -40, "HAB": 30}}, 20),
        ("Burgund braucht keine fremde Krone.", {"prestige": 3, "relations": {"HAB": -10}})]),
    # --- Poland
    ev("khmelnytsky", "POL", "Der Aufstand Chmelnyzkyjs",
       "Die Kosaken am Dnjepr haben sich unter Bohdan Chmelnyzkyj erhoben. Die Bauern der Ukraine schließen sich an.", "revolt",
       {"year_min": 1640, "year_max": 1660, "owns_any": ["kiev", "zaporozhia", "volhynia"]},
       [("Mit den Kosaken verhandeln.", {"estate": {"adel": -5}, "dip": 20}),
        ("Das Heer gegen die Rebellen.", {"manpower": -2500, "mil": 25, "estate": {"adel": 4}}),
        ("Mehr Kosaken ins Register aufnehmen.", {"gold": -40, "manpower": 2000}, 8)]),
    ev("liberum_veto", "POL", "Liberum veto",
       "Zum ersten Mal hat ein einziger Abgeordneter den ganzen Sejm gesprengt. Der Adel nennt es Freiheit.", "diet",
       {"year_min": 1640, "year_max": 1700},
       [("Die goldene Freiheit achten.", {"estate": {"adel": 6}, "adm": -15}),
        ("Mehrheitsbeschlüsse fordern.", {"adm": 30, "estate": {"adel": -6}}),
        ("Die Abgeordneten bestechen.", {"gold": -40, "adm": 20}, 8)]),
    ev("gustav_prussia", "POL", "Gustav Adolf in Preußen",
       "Der Schwedenkönig landet an der preußischen Küste und sperrt die Weichselmündung. Der Zoll von Danzig fließt nach Stockholm.", "siege",
       {"year_min": 1620, "year_max": 1640, "at_war": True},
       [("Das Volk zum Widerstand rufen.", {"manpower": 3000, "estate": {"klerus": 4}}),
        ("Die Magnaten mit Ämtern halten.", {"estate": {"adel": 6}, "dip": -15}),
        ("Einen Waffenstillstand suchen.", {"dip": 30, "prestige": -3})]),
    ev("chotyn", "POL", "Das Lager von Chotyn",
       "Hetman Chodkiewicz hält mit Kosaken und Husaren das Lager von Chotyn gegen das Heer des Sultans. Der Adel will die Helden belohnen.", "knights",
       {"year_min": 1615, "year_max": 1640},
       [("Die Hetmane ehren.", {"ruler": {"mil": 1}, "prestige": 4}),
        ("Ein Fest für die Husaren.", {"mil": 30, "estate": {"adel": 4}}),
        ("Den Kosaken Sold zahlen.", {"adm": 20, "estate": {"adel": 2}})]),
    ev("danzig", "POL", "Danzig und das Korn",
       "Das Korn aus Polen ernährt halb Europa. Die Danziger Kaufleute verdienen daran mehr als die Krone.", "harvest",
       {"year_min": 1500, "owns": ["prussia"]},
       [("Ein königlicher Zoll an der Weichsel.", {"gold": 50, "estate": {"buerger": -4}}),
        ("Den Adel am Handel beteiligen.", {"estate": {"adel": 5}, "dip": 10}),
        ("Danzig seine Rechte lassen.", {"estate": {"buerger": 5}, "mods": {"trade": 0.02}})]),
    ev("cossack_register", "POL", "Das Kosakenregister",
       "Die Kosaken am Dnjepr wollen als freie Krieger in den Dienst der Krone treten, mit Sold und eigenen Rechten.", "steppe",
       {"year_min": 1570, "year_max": 1640},
       [("Ein kleines Register.", {"manpower": 1000, "estate": {"adel": 2}}),
        ("Alle aufnehmen.", {"manpower": 3000, "estate": {"adel": -5}}),
        ("Die Kosaken bleiben Bauern.", {"estate": {"adel": 5}, "mil": -10})]),
    # --- Ottomans
    ev("koprulu", "TUR", "Die Köprülü-Wesire",
       "Ein alter Pascha verlangt für das Amt des Großwesirs freie Hand. Er will Korruption und Aufruhr mit eiserner Hand beenden.", "court",
       {"year_min": 1640, "year_max": 1700},
       [("Ihm freie Hand lassen.", {"adm": 40, "estate": {"adel": -5}}),
        ("Nur auf Probe.", {"adm": 20}),
        ("Der Sultan regiert selbst.", {"prestige": 3, "estate": {"adel": 3}})]),
    ev("celali", "TUR", "Die Celali-Aufstände",
       "In Anatolien ziehen entlassene Söldner und verarmte Bauern plündernd durchs Land. Ihre Anführer nennen sich Paschas.", "revolt",
       {"year_min": 1590, "year_max": 1620, "owns": ["konya"]},
       [("Die Anführer mit Ämtern kaufen.", {"estate": {"adel": 4}, "adm": -15}),
        ("Das Heer nach Anatolien.", {"manpower": -2000, "mil": 25}),
        ("Steuern in Anatolien senken.", {"gold": -30, "estate": {"buerger": 5}}, 8)]),
    ev("candia", "TUR", "Die Belagerung von Candia",
       "Kreta ist venezianisch. Die Festung Candia könnte Jahre der Belagerung kosten, aber sie öffnet das Mittelmeer.", "siege",
       {"year_min": 1640, "year_max": 1670, "not_owns": ["crete"], "alive": "VEN"},
       [("Erst die Flotte stärken.", {"ships": 3, "mil": -15}),
        ("Kreta beanspruchen.", {"claim": ["crete"], "prestige": 3}),
        ("Venedig angreifen.", {"war": "VEN", "claim": ["crete"]}, 20)]),
    ev("osman_janissaries", "TUR", "Der junge Sultan und die Janitscharen",
       "Nach dem Feldzug gegen Polen will der junge Sultan die Janitscharen durch ein neues Heer ersetzen. Die Janitscharen murren in den Kasernen.", "ottoman",
       {"year_min": 1615, "year_max": 1640},
       [("Die Janitscharen besänftigen.", {"mil": 20, "estate": {"adel": 3}}),
        ("Langsam neue Truppen ausheben.", {"manpower": 1500, "estate": {"adel": -3}}),
        ("Die Kasernen auflösen.", {"mil": 30, "prestige": -2, "estate": {"adel": -6}}, 15)]),
    ev("kadizadeli", "TUR", "Die Kadızadeliler",
       "Strenge Prediger wettern gegen Kaffeehäuser, Tabak und die Derwischorden. Ihre Anhänger stürmen Tekken.", "procession",
       {"year_min": 1620, "year_max": 1690},
       [("Die Prediger gewähren lassen.", {"estate": {"klerus": 5}, "prestige": 1}),
        ("Die Kaffeehäuser schützen.", {"estate": {"buerger": 5, "klerus": -4}}),
        ("Die Wortführer verbannen.", {"adm": 20, "estate": {"klerus": -5}})]),
    ev("baghdad", "TUR", "Murad IV. zieht nach Osten",
       "Der Sultan führt das Heer selbst gegen die Perser. Er verbietet Tabak und Wein und lässt Säumige hart bestrafen.", "ottoman",
       {"year_min": 1625, "at_peace": True},
       [("Mit dem Sultan ins Feld.", {"prestige": 4, "mil": 15}),
        ("Die Verbote durchsetzen.", {"adm": 25, "estate": {"klerus": 3, "buerger": -3}}),
        ("Die Beute für den Schatz.", {"gold": 40, "prestige": -1})]),
]

def check(e, nations):
    assert e["tag"] in nations, e["id"]
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0 and "war" not in first, e["id"]
    for o in e["options"]:
        for v in o["effects"].get("mods", {}).values():
            assert abs(v) <= 0.03, e["id"]
        if "war" in o["effects"]:
            assert o["effects"]["war"] in nations and o.get("ai", 25) < 50, e["id"]
        if o["effects"].get("gold", 0) < 0:
            assert o.get("ai", 25) <= 10, e["id"]


def main():
    nations = json.load(open(os.path.join(events_io.ROOT, "data/nations.json"), encoding="utf-8"))
    for e in EVENTS:
        check(e, nations)
    data = None
    for prefix in ("bur_late_", "pol_late_", "tur_late_"):
        data = events_io.replace_block(prefix, [e for e in EVENTS if e["id"].startswith(prefix)])
    print("events %d (late %d)" % (len(data), len(EVENTS)))


if __name__ == "__main__":
    main()
