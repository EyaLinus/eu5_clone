"""Government events: generic events that react to laws, techs and estates (data/events.json, id prefix "gov_").

Re-running replaces all "gov_" events, so edit here. Run: python3 tools/content/gov_events.py
Rules: every option is a trade-off, the AI-favoured first option never costs gold (repeatable or not),
permanent `mods` stay small (max 0.03 / 1 point) because events fire for all ~50 nations.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def ev(id, title, text, image, trigger, options):
    return {"id": "gov_" + id, "tag": "*", "title": title, "text": text, "image": image,
            "trigger": trigger, "options": [dict(text=o[0], effects=o[1], **({"ai": o[2]} if len(o) > 2 else {}))
                                            for o in options]}


EVENTS = [
    # --- laws
    ev("guild_charter", "Die Zünfte wollen Privilegien",
       "Die Städte blühen unter deinem Schutz. Nun verlangen die Zünfte ein Monopol auf ihr Handwerk.", "city",
       {"law": {"wirtschaft": "staedtefoerderung"}, "year_min": 1450},
       [("Ein Freibrief für die Zünfte.", {"estate": {"buerger": 10}, "mods": {"production": 0.02}, "dip": -30}),
        ("Freie Gewerbe für alle.", {"estate": {"buerger": -10}, "gold": 60}),
        ("Vertrösten und verhandeln.", {"adm": 20, "estate": {"buerger": -3}})]),
    ev("smugglers", "Schmuggler an der Grenze",
       "Hohe Zölle machen das Schmuggeln lohnend. Ganze Dörfer leben vom Schleichhandel.", "border",
       {"law": {"wirtschaft": "merkantilismus"}, "year_min": 1480},
       [("Zollreiter aufstellen.", {"mil": -25, "mods": {"trade": 0.02}}),
        ("Die Zölle senken.", {"estate": {"buerger": 8}, "gold": -40}, 30),
        ("Wegsehen und mitverdienen.", {"gold": 50, "prestige": -5}, 20)]),
    ev("cheap_imports", "Billige Waren aus der Fremde",
       "Fremde Tuche überschwemmen die Märkte. Die heimischen Weber stehen vor dem Ruin.", "market",
       {"law": {"wirtschaft": "freihandel"}, "year_min": 1470},
       [("Der Markt regelt das.", {"gold": 40, "estate": {"buerger": -8}}),
        ("Schutzzölle auf Tuch.", {"estate": {"buerger": 6}, "mods": {"trade": -0.02}}),
        ("Weber umsiedeln und fördern.", {"adm": -40, "dev_capital": 1}, 25)]),
    ev("war_profiteers", "Kriegsgewinnler",
       "Lieferanten der Armee werden reich, während die Bauern hungern. Die Stimmung kippt.", "camp",
       {"law": {"wirtschaft": "kriegswirtschaft"}, "at_war": True},
       [("Die Wucherer hängen.", {"estate": {"buerger": -10}, "prestige": 5, "mil": 20}),
        ("Sie sollen eine Kriegsanleihe zeichnen.", {"gold": 70, "estate": {"buerger": -5}}),
        ("Preise festsetzen.", {"adm": -30, "estate": {"buerger": 5}}, 25)]),
    ev("mercenary_captain", "Ein Condottiere bietet seine Dienste an",
       "Ein berühmter Söldnerführer steht mit seiner Kompanie an der Grenze und wartet auf ein Angebot.", "camp",
       {"law": {"heer": "soeldner"}, "year_min": 1450},
       [("Wir brauchen keine weiteren Söldner.", {"prestige": -2, "mil": 20}),
        ("Anwerben!", {"regs": 3, "gold": -90}, 30),
        ("Ihn als Ausbilder gewinnen.", {"gold": -50, "mods": {"combat": 0.02}}, 20)]),
    ev("militia_harvest", "Das Aufgebot fehlt bei der Ernte",
       "Die Bauern exerzieren, statt die Felder zu bestellen. Das Korn verdirbt auf dem Halm.", "harvest",
       {"law": {"heer": "landesaufgebot"}, "year_min": 1460},
       [("Übungen nach der Ernte.", {"mil": -30, "gold": 30}),
        ("Die Ordnung hat Vorrang.", {"manpower": 1500, "dev_random": -1}),
        ("Den Adel als Ausbilder einsetzen.", {"estate": {"adel": 8}, "dip": -25})]),
    ev("barracks_riot", "Unruhe in den Kasernen",
       "Der Sold ist drei Monate im Rückstand. Die Soldaten des stehenden Heeres murren offen.", "revolt",
       {"law": {"heer": "stehendes_heer"}, "year_min": 1500},
       [("Die Rädelsführer bestrafen.", {"mil": -20, "estate": {"adel": 5}, "prestige": -3}),
        ("Den Sold nachzahlen.", {"gold": -60, "mil": 30}, 35),
        ("Beute versprechen.", {"we": 2, "mods": {"combat": 0.01}}, 15)]),
    ev("diet_demands", "Der Landtag tritt zusammen",
       "Die Stände bewilligen neue Steuern nur, wenn der Fürst ihre Beschwerden anhört.", "diet",
       {"law": {"staat": "staendestaat"}, "year_min": 1460},
       [("Die Beschwerden anhören.", {"gold": 60, "estate": {"adel": 5, "buerger": 5}, "adm": -30}),
        ("Den Landtag vertagen.", {"estate": {"adel": -10, "buerger": -10}, "prestige": 3}),
        ("Nur dem Adel entgegenkommen.", {"estate": {"adel": 10, "buerger": -5}, "gold": 30})]),
    ev("intendants", "Die Intendanten melden sich",
       "Deine Beamten in den Provinzen arbeiten gründlich. Zu gründlich, finden die alten Familien.", "court",
       {"law": {"staat": "zentralisierung"}, "has_tech": "adm_intendanten"},
       [("Weiter so.", {"adm": 40, "estate": {"adel": -8}}),
        ("Die Befugnisse beschneiden.", {"estate": {"adel": 8}, "adm": -20}),
        ("Adlige zu Intendanten machen.", {"estate": {"adel": 12}, "mods": {"income": -0.01}})]),
    ev("lettre_de_cachet", "Ein Haftbefehl ohne Prozess",
       "Ein Höfling hat dich beleidigt. Ein Wort von dir und er verschwindet in der Festung.", "conspiracy",
       {"law": {"staat": "absolutismus"}},
       [("L'État, c'est moi.", {"prestige": 5, "estate": {"adel": -8}}),
        ("Ein ordentliches Gericht.", {"adm": -20, "estate": {"adel": 5, "buerger": 3}}),
        ("Großzügig vergeben.", {"prestige": -3, "dip": 30})]),
    ev("heretics", "Ketzer im Land",
       "Wanderprediger verbreiten verbotene Lehren. Die Bischöfe fordern Scheiterhaufen.", "inquisition",
       {"law": {"kirche": "glaubenseifer"}, "year_min": 1500},
       [("Die Inquisition walten lassen.", {"estate": {"klerus": 8, "buerger": -8}, "prestige": 3}),
        ("Ausweisen statt verbrennen.", {"estate": {"klerus": -3}, "dev_random": -1, "dip": 20}),
        ("Sie in Ruhe lassen.", {"estate": {"klerus": -10, "buerger": 5}, "adm": 20})]),
    ev("refugees", "Glaubensflüchtlinge",
       "Verfolgte aus dem Nachbarland bitten um Aufnahme. Unter ihnen sind fähige Handwerker.", "procession",
       {"law": {"kirche": "toleranz"}, "year_min": 1520},
       [("Willkommen!", {"dev_capital": 1, "estate": {"klerus": -8}}),
        ("Nur die Handwerker.", {"mods": {"production": 0.01}, "estate": {"klerus": -3}, "dip": -20}),
        ("Abweisen.", {"estate": {"klerus": 5}, "prestige": -3})]),
    ev("monastery_lands", "Die Klostergüter",
       "Nach der Säkularisierung stehen die Klöster leer. Was soll mit dem Land geschehen?", "church",
       {"law": {"kirche": "saekularisierung"}},
       [("Krongut daraus machen.", {"gold": 80, "estate": {"klerus": -5}}),
        ("An den Adel verkaufen.", {"gold": 120, "estate": {"adel": 10, "klerus": -8}}, 35),
        ("Schulen und Spitäler stiften.", {"estate": {"buerger": 10, "klerus": 5}, "gold": -40}, 15)]),
    # --- techs
    ev("printing_pamphlets", "Flugschriften gegen die Krone",
       "Die neuen Druckpressen sind schneller als jeder Zensor. Spottschriften über den Hof gehen von Hand zu Hand.", "printing",
       {"has_tech": "dip_flugschriften"},
       [("Gegenschriften drucken lassen.", {"dip": -25, "prestige": 3}),
        ("Die Drucker verhaften.", {"estate": {"buerger": -8}, "adm": 20}),
        ("Die Spötter an den Hof holen.", {"estate": {"buerger": 6}, "prestige": -3})]),
    ev("university_debate", "Streit an der Universität",
       "Die Magister disputieren über die Bewegung der Planeten. Die Theologen sind empört.", "scholar",
       {"has_tech": "adm_naturphil"},
       [("Die Wissenschaft ist frei.", {"adm": 40, "estate": {"klerus": -8}}),
        ("Die Theologen haben das letzte Wort.", {"estate": {"klerus": 8}, "adm": -20}),
        ("Beide Seiten fördern.", {"gold": -50, "adm": 25, "estate": {"klerus": 2}})]),
    ev("fortress_architect", "Ein Festungsbaumeister",
       "Ein Ingenieur aus Italien bietet an, deine Grenzfesten im neuen Stil umzubauen.", "siege",
       {"has_tech": "mil_trace_italienne"},
       [("Er soll Pläne zeichnen.", {"mil": 30, "dip": -20}),
        ("Sofort bauen!", {"gold": -80, "mods": {"combat": 0.02}}, 30),
        ("Zu teuer.", {"prestige": -2, "gold": 20}, 20)]),
    ev("joint_stock", "Fieber an der Börse",
       "Anteile an deinen Handelskompanien werden zu immer höheren Preisen gehandelt. Manche warnen vor einer Blase.", "bank",
       {"has_tech": "dip_aktien", "year_min": 1560},
       [("Die Kurse beruhigen.", {"dip": -30, "estate": {"buerger": -3}}),
        ("Eigene Anteile verkaufen.", {"gold": 100, "estate": {"buerger": -8}}, 30),
        ("Einfach mitspekulieren.", {"gold": 40, "prestige": -3}, 20)]),
    # --- estates
    ev("loyal_nobility", "Der Adel steht zur Krone",
       "Die großen Familien sind zufrieden. Einige bieten an, ihre Söhne in dein Heer zu schicken.", "knights",
       {"estate_min": {"adel": 70}},
       [("Offiziersstellen für Adlige.", {"regs": 2, "estate": {"adel": -5}}),
        ("Sie an den Hof binden.", {"prestige": 5, "gold": -30}, 30),
        ("Ein Turnier zu Ehren des Adels.", {"gold": -40, "estate": {"adel": 5}, "mil": 30}, 20)]),
    ev("burgher_loan", "Die Bürger bieten einen Kredit an",
       "Die Kaufleute sind zufrieden und reich. Sie bieten der Krone eine Anleihe zu günstigen Zinsen.", "bank",
       {"estate_min": {"buerger": 70}},
       [("Dankend annehmen.", {"gold": 100, "estate": {"buerger": -8}}),
        ("In die Städte investieren.", {"dev_capital": 1, "estate": {"buerger": -3}}),
        ("Ablehnen, wir sind nicht arm.", {"prestige": 3}, 20)]),
    ev("clergy_tithe", "Der Zehnte wird verweigert",
       "Die Bauern zahlen den Zehnten nicht mehr, und die Bischöfe geben der Krone die Schuld.", "church",
       {"estate_max": {"klerus": 40}, "year_min": 1450},
       [("Den Zehnten eintreiben lassen.", {"estate": {"klerus": 8}, "dev_random": -1}),
        ("Die Kirche aus der Staatskasse entschädigen.", {"gold": -50, "estate": {"klerus": 10}}, 30),
        ("Soll die Kirche selbst sehen.", {"estate": {"klerus": -5}, "gold": 30}, 20)]),
]


def render_event(e):
    head = {k: e[k] for k in ("id", "tag", "title", "text", "image") if k in e}
    s = "  " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    s += '   "trigger": ' + json.dumps(e["trigger"], ensure_ascii=False) + ",\n"
    s += '   "options": [\n'
    s += ",\n".join("     " + json.dumps(o, ensure_ascii=False) for o in e["options"])
    return s + "]}"


def main():
    path = os.path.join(ROOT, "data/events.json")
    txt = open(path, encoding="utf-8").read().rstrip()
    assert txt.endswith("]")
    # gov_ events are always the tail of the file: cut them and append the current list
    cut = txt.find('  {"id": "gov_')
    body = (txt[:cut].rstrip().rstrip(",") if cut >= 0 else txt[:-1].rstrip())
    for e in EVENTS:
        assert len(e["options"]) == 3, e["id"]
    txt = body + ",\n" + ",\n".join(render_event(e) for e in EVENTS) + "\n]\n"
    events = json.loads(txt)
    assert len({e["id"] for e in events}) == len(events)
    open(path, "w", encoding="utf-8").write(txt)
    print("events", len(events), "gov", len(EVENTS))


if __name__ == "__main__":
    main()
