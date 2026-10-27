"""Court content for v0.8.4-v0.8.9: great works (monuments), court feasts and royal marriages.
Generic events, id prefix "court_". Run: python3 tools/content/court_events.py (idempotent, see events_io.py).

Conditions: monument, monuments_min, monument_building, feast_recent, married.
Effects: monument_progress (months), feast_ready, spouse_rel.
The AI builds no great works and holds no feasts, so most of these are player events: they lean towards
rewards for using the new systems. Rules as in eco_events.py (first option gold-free, gold options AI weight 2).
"""
import events_io


def _ai(o):
    # flat gold costs hit poor minors hard (marriage events fire for ~45 realms): the AI almost never pays
    if o[1].get("gold", 0) < 0:
        return {"ai": 2}
    return {"ai": o[2]} if len(o) > 2 else {}


def ev(id, title, text, image, trigger, options, once=True):
    e = {"id": "court_" + id}
    if not once:
        e["once"] = False
    e.update({"tag": "*", "title": title, "text": text, "image": image, "trigger": trigger,
              "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]})
    return e


EVENTS = [
    # --- great works under construction
    ev("master_builder", "Ein berühmter Baumeister",
       "Ein Meister, der schon für Päpste und Kaiser gebaut hat, bietet an, die Leitung deiner Baustelle zu übernehmen.", "artist",
       {"monument_building": True},
       [("Er soll die Leitung übernehmen.", {"monument_progress": 4, "dip": -20}),
        ("Mit doppeltem Lohn locken.", {"monument_progress": 8, "gold": -40}),
        ("Unsere Leute können das selbst.", {"adm": 20, "prestige": 1})], once=False),
    ev("quarry", "Ein neuer Steinbruch",
       "Bauern haben ganz in der Nähe der Hauptstadt einen Bruch mit hellem, festem Stein entdeckt.", "mine",
       {"monument_building": True},
       [("Sofort abbauen.", {"monument_progress": 4, "estate": {"adel": -3}}),
        ("Den Stein auch verkaufen.", {"gold": 40}),
        ("Den Bauern den Fund vergüten.", {"monument_progress": 4, "estate": {"buerger": 3}, "gold": -15})]),
    ev("builders_strike", "Die Bauleute streiken",
       "Die Steinmetze wollen mehr Lohn und kürzere Tage. Seit einer Woche ruht die Baustelle.", "revolt",
       {"monument_building": True, "year_min": 1460},
       [("Kürzere Tage, gleicher Lohn.", {"estate": {"buerger": 5}, "adm": -15}),
        ("Mehr Lohn.", {"gold": -30, "monument_progress": 3}),
        ("Soldaten an die Baustelle.", {"mil": -20, "monument_progress": 2, "estate": {"buerger": -4}})], once=False),
    ev("foundation_find", "Ein Fund im Fundament",
       "Beim Ausheben der Fundamente stoßen die Arbeiter auf alte römische Mauern und einen Schatz aus Münzen.", "exploration",
       {"monument_building": True},
       [("Die Münzen in die Bauhütte.", {"monument_progress": 3, "gold": 30}),
        ("Die Altertümer ausstellen.", {"prestige": 5, "adm": 15}),
        ("Der Kirche überlassen.", {"estate": {"klerus": 8}})]),
    # --- finished great works
    ev("consecration", "Die Weihe des Doms",
       "Der neue Dom ist vollendet. Bischöfe aus dem ganzen Land wollen ihn weihen.", "church",
       {"monument": "cathedral"},
       [("Ein großes Weihefest.", {"prestige": 6, "estate": {"klerus": 6}}),
        ("Eine Wallfahrt stiften.", {"gold": 40, "estate": {"klerus": 3}}),
        ("Schlicht und würdig.", {"adm": 25})]),
    ev("embassy_secrets", "Geheimnisse im Gesandtenhof",
       "Ein fremder Gesandter verrät beim Wein mehr, als er sollte. Deine Diplomaten haben gut zugehört.", "conspiracy",
       {"monument": "embassy"},
       [("Das Wissen nutzen.", {"dip": 40}),
        ("Es dem Betroffenen zuspielen.", {"prestige": 4, "dip": 15}),
        ("Diskret bleiben.", {"adm": 20, "prestige": 1})]),
    ev("arsenal_cannon", "Ein neues Geschütz",
       "Die Gießer im Arsenal haben ein leichteres Geschütz entworfen, das mit dem Heer marschieren kann.", "artillery",
       {"monument": "arsenal"},
       [("In Serie gießen.", {"mods": {"combat": 0.02}, "mil": -20}),
        ("Erst gründlich erproben.", {"mil": 30}),
        ("Die Pläne an Verbündete verkaufen.", {"gold": 60, "dip": 10})]),
    ev("university_scholar", "Ein Gelehrter von Weltruf",
       "Ein berühmter Gelehrter will an deiner Universität lehren, wenn er eigene Räume und Diener bekommt.", "scholar",
       {"monument": "university"},
       [("Er bekommt alles.", {"adm": 50, "estate": {"klerus": -3}}),
        ("Er soll den Thronfolger erziehen.", {"ruler": {"adm": 1}, "prestige": 2}),
        ("Zu teuer.", {"gold": 25})]),
    ev("exchange_rush", "Hochbetrieb an der Börse",
       "An deiner Börse werden Wechsel aus ganz Europa gehandelt. Die Kaufleute wollen ein eigenes Gericht.", "bank",
       {"monument": "exchange"},
       [("Ein Handelsgericht einrichten.", {"mods": {"trade": 0.02}, "adm": -25}),
        ("Gebühren auf jeden Wechsel.", {"gold": 70, "estate": {"buerger": -4}}),
        ("Die Kaufleute regeln es selbst.", {"estate": {"buerger": 6}})]),
    ev("academy_cadets", "Die ersten Kadetten",
       "Der erste Jahrgang der Kriegsakademie ist fertig. Die jungen Offiziere brennen auf ihren Einsatz.", "knights",
       {"monument": "academy"},
       [("Sie führen die Regimenter.", {"army_power": 0.2, "mil": 20}),
        ("Sie lehren an der Akademie.", {"mods": {"army_power_regen": 0.05}}),
        ("Ein Manöver vor dem Hof.", {"prestige": 5, "estate": {"adel": 4}})]),
    ev("palace_envy", "Neid auf deinen Palast",
       "Fremde Fürsten reden nur noch von deinem Palast. Manche bewundern ihn, andere ärgern sich.", "court",
       {"monument": "palace"},
       [("Gesandte herumführen.", {"dip": 40, "prestige": 3}),
        ("Ein Fest für die Neider.", {"gold": -40, "dip": 25, "prestige": 5}),
        ("Sollen sie neidisch sein.", {"prestige": 6, "dip": -15})]),
    ev("wonders", "Reisende bestaunen deine Bauten",
       "Gelehrte und Fürstensöhne reisen in deine Hauptstadt, nur um deine Bauwerke zu sehen.", "city",
       {"monuments_min": 3},
       [("Herbergen und Führer.", {"gold": 50, "estate": {"buerger": 4}}),
        ("Kupferstiche drucken lassen.", {"prestige": 8}),
        ("Die Gäste an den Hof laden.", {"dip": 40})]),
    # --- court feasts
    ev("feast_duel", "Ein Duell nach dem Fest",
       "Zwei Edelleute sind beim Fest aneinandergeraten und wollen sich im Morgengrauen duellieren.", "knights",
       {"feast_recent": 6},
       [("Duelle sind verboten.", {"estate": {"adel": -3}, "adm": 15}),
        ("Der König schlichtet.", {"prestige": 3, "estate": {"adel": 3}}),
        ("Lasst sie fechten.", {"mil": 15, "prestige": -1})], once=False),
    ev("feast_poet", "Ein Dichter preist den Hof",
       "Ein junger Dichter hat beim Fest Verse vorgetragen, die bald im ganzen Land gesungen werden.", "artist",
       {"feast_recent": 6},
       [("Ihn zum Hofdichter machen.", {"prestige": 5, "dip": 10}),
        ("Die Verse drucken lassen.", {"prestige": 3, "estate": {"buerger": 3}}),
        ("Ein Beutel Gold, und er soll ziehen.", {"gold": -10, "adm": 15})], once=False),
    ev("feast_envoys", "Gesandte beim Fest",
       "Unter den Gästen waren Gesandte mehrerer Höfe. Nach dem dritten Becher reden sie offen.", "wedding",
       {"feast_recent": 6, "year_min": 1450},
       [("Gute Beziehungen pflegen.", {"dip": 30}),
        ("Ein neues Fest im Frühjahr ankündigen.", {"feast_ready": True, "prestige": 2}, 5),
        ("Nur zuhören.", {"adm": 20})], once=False),
    # --- royal marriages
    ev("wedding_gifts", "Geschenke der Verschwägerten",
       "Der Hof deiner verschwägerten Familie schickt Geschenke: Pferde, Wandteppiche und einen Brief voller Freundschaft.", "wedding",
       {"married": True},
       [("Mit gleichen Geschenken antworten.", {"spouse_rel": 15, "dip": -10}),
        ("Dankbar annehmen.", {"gold": 30, "prestige": 2}),
        ("Ein Besuch der Familie.", {"spouse_rel": 25, "gold": -25})], once=False),
    ev("heir_born", "Ein Erbe ist geboren",
       "Aus der königlichen Ehe ist ein gesunder Sohn hervorgegangen. Das Volk jubelt.", "heir",
       {"married": True, "at_peace": True},
       [("Glocken läuten im ganzen Land.", {"prestige": 6, "spouse_rel": 10}),
        ("Eine Amnestie zur Taufe.", {"estate": {"buerger": 4, "adel": 2}, "adm": -10}),
        ("Ein Taufgeschenk für die Kirche.", {"estate": {"klerus": 6}})]),
    ev("in_laws_ask", "Die Verschwägerten bitten um Hilfe",
       "Deine verschwägerte Familie steckt in Geldnot und bittet um einen Kredit unter Verwandten.", "treaty",
       {"married": True, "year_min": 1460},
       [("Freundliche Worte, kein Geld.", {"spouse_rel": -5, "dip": 10}),
        ("Einen Kredit gewähren.", {"gold": -50, "spouse_rel": 30, "dip": 20}),
        ("Truppen statt Gold.", {"mil": -20, "spouse_rel": 15})], once=False),
]


def check(e):
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0, e["id"]
    if not e.get("once", True):
        assert "mods" not in first, e["id"]
    for o in e["options"]:
        for k, v in o["effects"].get("mods", {}).items():
            assert abs(v) <= (0.05 if k == "army_power_regen" else 0.03), e["id"]


def main():
    for e in EVENTS:
        check(e)
    data = events_io.replace_block("court_", EVENTS)
    print("events %d (court %d)" % (len(data), len(EVENTS)))


if __name__ == "__main__":
    main()
