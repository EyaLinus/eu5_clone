"""Religion content for v0.8.8+: Reformation, Counter-Reformation and the religious peace, 1517-1620,
plus a few events for the orthodox and sunni realms. Generic events, id prefix "rel_".
Run: python3 tools/content/rel_events.py  (idempotent; see events_io.py for the file layout)

Conditions used: "religion" (state faith, from the feature thread), "province_faith", "faith_share_max", "hre".
Effect "convert_random": n provinces of another faith take up the state religion.

Linus finds the game hard (2026-10-26), so this batch leans towards chances, not extra punishment:
most events offer a way to win provinces back for the state faith or to gain something from the split.
Rules as in eco_events.py: AI-favoured first option never costs gold, gold-costing options get AI weight <= 10,
permanent mods at most 0.03.
"""
import events_io


def _ai(o):
    if o[1].get("gold", 0) < 0:
        return {"ai": min(o[2] if len(o) > 2 else 10, 10)}
    return {"ai": o[2]} if len(o) > 2 else {}


def ev(id, title, text, image, trigger, options, once=True):
    e = {"id": "rel_" + id}
    if not once:
        e["once"] = False
    e.update({"tag": "*", "title": title, "text": text, "image": image, "trigger": trigger,
              "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]})
    return e


R = {"year_min": 1517, "year_max": 1620}


def era(**kw):
    t = dict(R)
    t.update(kw)
    return t


EVENTS = [
    # --- Reformation
    ev("theses_news", "Nachricht aus Wittenberg",
       "Ein Mönch hat Thesen gegen den Ablasshandel angeschlagen. Die Flugblätter erreichen auch deinen Hof.", "reformation",
       era(year_max=1530, religion="catholic", hre=True),
       [("Die Kirche verteidigen.", {"estate": {"klerus": 6}, "prestige": 2}),
        ("Abwarten, was Rom tut.", {"adm": 25}),
        ("Den Ablasshandel im eigenen Land verbieten.", {"estate": {"klerus": -6, "buerger": 6}, "gold": 30})]),
    ev("preachers", "Lutherische Prediger",
       "Wanderprediger verkünden die neue Lehre auf deinen Marktplätzen. Die Bürger hören zu.", "procession",
       era(religion="catholic", province_faith="protestant"),
       [("Die Bischöfe sollen dagegen predigen.", {"convert_random": 1, "estate": {"klerus": 3}, "dip": -15}),
        ("Sie gewähren lassen.", {"estate": {"buerger": 5, "klerus": -5}, "adm": 15}),
        ("Sie ausweisen.", {"convert_random": 2, "estate": {"buerger": -6}, "prestige": -2}, 25)], once=False),
    ev("peasant_war", "Der Bauernkrieg",
       "Bauern berufen sich auf das Evangelium und fordern das Ende der Leibeigenschaft. Erste Klöster brennen.", "revolt",
       era(year_min=1524, year_max=1527, hre=True),
       [("Mit den Bauern verhandeln.", {"estate": {"adel": -6}, "adm": 20, "dev_random": 1}),
        ("Der Adel soll sie niederwerfen.", {"estate": {"adel": 8}, "manpower": -1500, "prestige": 2}),
        ("Zwölf Artikel prüfen lassen.", {"adm": -30, "estate": {"adel": -2, "buerger": 4}})]),
    ev("bible_translation", "Die Bibel in der Landessprache",
       "Ein Gelehrter hat die Heilige Schrift übersetzt. Jeder, der lesen kann, will sie kaufen.", "printing",
       era(religion="protestant"),
       [("Den Druck fördern.", {"adm": 40, "prestige": 3}),
        ("Schulen in jeder Stadt.", {"gold": -50, "mods": {"tech_cost": -0.02}}, 10),
        ("Eine Ausgabe für den Hof.", {"prestige": 5, "dip": 10})]),
    ev("monastery_dissolution", "Die Klöster werden aufgelöst",
       "Nach dem Glaubenswechsel stehen die Klöster leer. Ihre Ländereien sind reich.", "church",
       era(religion="protestant"),
       [("Das Land fällt an die Krone.", {"gold": 90, "estate": {"klerus": -6}}),
        ("An den Adel verkaufen.", {"gold": 60, "estate": {"adel": 8}}),
        ("Schulen und Spitäler daraus machen.", {"dev_random": 2, "estate": {"buerger": 5}})]),
    ev("church_ordinance", "Eine neue Kirchenordnung",
       "Der Landesherr ist nun auch oberster Bischof. Die neue Kirchenordnung soll Predigt, Schule und Armenpflege regeln.", "court",
       era(religion="protestant"),
       [("Die Pfarrer werden Landesbeamte.", {"mods": {"tax": 0.02}, "estate": {"klerus": -3}}),
        ("Eine Synode soll entscheiden.", {"estate": {"klerus": 6}, "adm": 20}),
        ("Armenkassen in jeder Gemeinde.", {"estate": {"buerger": 6}, "gold": 20})]),
    ev("iconoclasm", "Bildersturm",
       "Eiferer stürmen die Kirchen und zerschlagen Heiligenbilder. Die Zünfte wollen die Ordnung wahren.", "town_fire",
       era(year_min=1520, province_faith="protestant"),
       [("Die Stadtwache greift ein.", {"mil": -15, "estate": {"buerger": 4}}),
        ("Die Bilder geordnet entfernen.", {"estate": {"klerus": -4}, "gold": 30}),
        ("Die Eiferer verhaften.", {"convert_random": 1, "estate": {"buerger": -4}}, 25)]),
    # --- Counter-Reformation
    ev("jesuits", "Die Jesuiten kommen",
       "Ein neuer Orden bietet an, Kollegien zu gründen und verlorene Seelen zurückzugewinnen.", "scholar",
       era(year_min=1540, religion="catholic", faith_share_max=0.95),
       [("Willkommen.", {"convert_random": 2, "estate": {"klerus": 4}, "dip": -15}),
        ("Nur als Lehrer.", {"adm": 30, "estate": {"klerus": 3}}),
        ("Wir brauchen keine Römer.", {"estate": {"klerus": -5}, "prestige": 2})]),
    ev("council_trent", "Das Konzil von Trient",
       "Die Kirche reformiert sich selbst. Deine Bischöfe fragen, ob sie die Beschlüsse übernehmen sollen.", "church",
       era(year_min=1545, year_max=1570, religion="catholic"),
       [("Die Beschlüsse umsetzen.", {"estate": {"klerus": 6}, "adm": 20}),
        ("Priesterseminare gründen.", {"convert_random": 1, "gold": -30}, 10),
        ("Die eigenen Rechte wahren.", {"prestige": 3, "estate": {"klerus": -4}})]),
    ev("recatholicize", "Die Gegenreformation",
       "Die Bischöfe drängen: Die abgefallenen Provinzen sollen zum alten Glauben zurück.", "inquisition",
       era(year_min=1550, religion="catholic", faith_share_max=0.8),
       [("Prediger und Schulen.", {"convert_random": 2, "adm": -20}),
        ("Mit harter Hand.", {"convert_random": 3, "estate": {"buerger": -8}, "prestige": -2}, 20),
        ("Lieber Frieden im Land.", {"estate": {"klerus": -4, "buerger": 5}, "dip": 20})]),
    # --- religious peace and tolerance
    ev("augsburg_peace", "Der Augsburger Religionsfriede",
       "Kaiser und Fürsten einigen sich: Wessen das Land, dessen der Glaube. Auch du musst dich entscheiden.", "treaty",
       era(year_min=1555, year_max=1565, hre=True),
       [("Wessen das Land, dessen der Glaube.", {"convert_random": 2, "estate": {"buerger": -3}}),
        ("Duldung für beide Konfessionen.", {"estate": {"buerger": 5, "klerus": -3}, "dip": 25}),
        ("Den Frieden feiern.", {"prestige": 4, "gold": -20})]),
    ev("colloquy", "Ein Religionsgespräch",
       "Theologen beider Seiten wollen an deinem Hof disputieren. Vielleicht findet sich ein Ausgleich.", "scholar",
       era(year_min=1525, faith_share_max=0.85),
       [("Das Gespräch ausrichten.", {"dip": 30, "estate": {"klerus": -2}}),
        ("Die eigenen Theologen sollen siegen.", {"convert_random": 1, "prestige": 2}),
        ("Keine Zeit für Gelehrtenstreit.", {"adm": 15})]),
    ev("divided_realm", "Ein gespaltenes Land",
       "Die Hälfte deiner Untertanen betet anders als ihr Herrscher. Die Unruhe wächst.", "conspiracy",
       era(faith_share_max=0.65),
       [("Ein Toleranzedikt.", {"estate": {"klerus": -6, "buerger": 6}, "dip": 15}),
        ("Missionare in jede Provinz.", {"convert_random": 2, "adm": -30}),
        ("Die Grenzen schließen.", {"mil": 20, "estate": {"buerger": -4}})], once=False),
    ev("protestant_union", "Die Protestantische Union",
       "Die protestantischen Fürsten des Reiches schließen sich zusammen und laden dich ein.", "treaty",
       era(year_min=1600, religion="protestant", hre=True),
       [("Beitreten.", {"dip": 30, "mods": {"combat": 0.01}}),
        ("Nur Geld schicken.", {"gold": -40, "prestige": 3}),
        ("Neutral bleiben.", {"adm": 25})]),
    ev("catholic_league", "Die Katholische Liga",
       "Bayern ruft die katholischen Fürsten zu einem Bund gegen die Union.", "knights",
       era(year_min=1600, religion="catholic", hre=True),
       [("Der Liga beitreten.", {"dip": 30, "mods": {"combat": 0.01}}),
        ("Truppen versprechen, nicht schicken.", {"prestige": -2, "mil": 20}),
        ("Neutral bleiben.", {"adm": 25})]),
    # --- other faiths
    ev("patriarch", "Ein eigener Patriarch",
       "Die orthodoxe Kirche deines Landes will einen eigenen Patriarchen, unabhängig von Konstantinopel.", "coronation",
       {"year_min": 1550, "religion": "orthodox"},
       [("Den Patriarchen ausrufen.", {"prestige": 8, "estate": {"klerus": 6}}),
        ("Konstantinopel nicht verärgern.", {"dip": 30}),
        ("Die Kirche dem Staat unterstellen.", {"mods": {"tax": 0.02}, "estate": {"klerus": -8}})]),
    ev("madrasa", "Eine neue Medrese",
       "Ein reicher Wesir will eine große Medrese stiften, mit Bibliothek, Hospital und Armenküche.", "scholar",
       {"year_min": 1480, "religion": "sunni"},
       [("Die Stiftung annehmen.", {"adm": 30, "estate": {"klerus": 5}}),
        ("Die Krone stiftet mit.", {"gold": -50, "dev_capital": 1, "prestige": 3}),
        ("Lieber Kasernen.", {"mil": 30, "estate": {"klerus": -4}})]),
    ev("pilgrims", "Pilger strömen herbei",
       "Ein Wunder hat sich in einer deiner Kirchen ereignet. Aus allen Ländern kommen Pilger.", "procession",
       {"year_min": 1450, "at_peace": True},
       [("Herbergen bauen.", {"gold": 30, "estate": {"klerus": 4}}),
        ("Eine Wallfahrtskirche stiften.", {"gold": -40, "prestige": 5, "dev_capital": 1}),
        ("Aberglaube, nichts weiter.", {"estate": {"klerus": -5}, "adm": 20})]),
]


def check(e):
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0, e["id"]
    if not e.get("once", True):
        assert "mods" not in first, e["id"]
    for o in e["options"]:
        for v in o["effects"].get("mods", {}).values():
            assert abs(v) <= 0.03, e["id"]


def main():
    for e in EVENTS:
        check(e)
    data = events_io.replace_block("rel_", EVENTS)
    print("events %d (rel %d)" % (len(data), len(EVENTS)))


if __name__ == "__main__":
    main()
