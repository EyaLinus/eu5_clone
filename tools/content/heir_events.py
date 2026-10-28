"""Ruler and heir events (v0.9.4): react to the traits and skills of the ruler and the heir (government.gd).
Generic events, id prefix "heir_". Run: python3 tools/content/heir_events.py (idempotent, see events_io.py).

Conditions: ruler_trait / heir_trait (trait id, "any" or "" for none), heir_skill_min / heir_skill_max (sum of the
heir's three skills), heir_age_min / heir_age_max, regency (bool), reign_years_max. Effects: heir {adm/dip/mil: +n}, heir_trait / ruler_trait (id, "" or "random").
Trait events repeat (10-year cooldown) since every new ruler can bring the trait back. Rules as in court_events.py:
three options, the first one gold-free, permanent mods at most 0.03, gold options get AI weight 2.
"""
import events_io


def _ai(o):
    if o[1].get("gold", 0) < 0:
        return {"ai": 2}
    return {"ai": o[2]} if len(o) > 2 else {}


def ev(id, title, text, image, trigger, options, once=False):
    e = {"id": "heir_" + id}
    if not once:
        e["once"] = False
    e.update({"tag": "*", "title": title, "text": text, "image": image, "trigger": trigger,
              "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]})
    return e


EVENTS = [
    # --- the heir
    ev("coming_of_age", "Der Erbe wird volljährig",
       "Mit Glockengeläut feiert die Hauptstadt die Volljährigkeit des Erben. Nun soll er zeigen, was in ihm steckt.",
       "heir", {"year_min": 1446, "heir_age_min": 15, "heir_age_max": 30},
       [("Ein Dankgottesdienst genügt.", {"prestige": 3}),
        ("Ein großes Turnier!", {"gold": -60, "prestige": 8, "estate": {"adel": 5}}),
        ("Ein Sitz im Kronrat.", {"adm": -20, "heir": {"adm": 1}})], once=True),
    ev("famous_tutor", "Ein berühmter Lehrer",
       "Ein weitgereister Gelehrter bietet an, den Erben zu unterrichten, wenn der Preis stimmt.", "scholar",
       {"heir_skill_max": 5, "year_min": 1450, "heir_age_max": 20},
       [("Ein Hofgelehrter aus dem eigenen Land.", {"adm": -30, "heir": {"adm": 1}}),
        ("Den Gelehrten aus Italien holen.", {"gold": -70, "heir": {"adm": 1, "dip": 1}}),
        ("Der Erbe lernt im Feldlager.", {"mil": -25, "heir": {"mil": 1}})]),
    ev("disappointing_heir", "Ein enttäuschender Erbe",
       "Die Lehrer klagen: Der Erbe schläft im Unterricht und versäumt die Ratssitzungen. Am Hof wird getuschelt.",
       "court", {"heir_skill_max": 2, "year_min": 1450, "heir_age_min": 10},
       [("Auf die Zeit vertrauen.", {"prestige": -3}),
        ("Strenge Erziehung.", {"adm": -50, "heir": {"adm": 1, "dip": 1}}),
        ("Eine kluge Braut soll ihn lenken.", {"dip": -40, "heir": {"dip": 1}, "prestige": 2})]),
    ev("promising_heir", "Ein vielversprechender Erbe",
       "Der Erbe glänzt in allen Fächern. Seine Lehrer streiten, wem er nacheifern soll.", "heir",
       {"heir_skill_min": 8, "heir_trait": ""},
       [("Lob vor dem ganzen Hof.", {"prestige": 3}),
        ("Zu den Gelehrten mit ihm.", {"adm": -40, "heir_trait": "gelehrt"}),
        ("In die Kriegsschule.", {"mil": -40, "heir_trait": "feldherr"})]),
    ev("cruel_heir", "Die Launen des Erben",
       "Der Erbe lässt Diener auspeitschen und quält Tiere zum Vergnügen. Das Volk fürchtet den Tag seiner Krönung.",
       "conspiracy", {"heir_trait": "grausam"},
       [("Das wächst sich aus.", {"estate": {"buerger": -5}}),
        ("Ins Kloster zur Besinnung.", {"dip": -40, "heir_trait": "fromm"}),
        ("An die Grenze mit ihm, dort braucht man Härte.", {"mil": -30, "manpower": -800, "heir_trait": "feldherr"})]),
    ev("spendthrift_heir", "Der Erbe verprasst sein Erbe",
       "Spieltische, Pferde, Juwelen: Die Gläubiger des Erben stehen schon vor dem Schatzamt.", "tavern",
       {"heir_trait": "verschwender"},
       [("Die Apanage kürzen.", {"estate": {"adel": -5}, "prestige": -2}),
        ("Seine Schulden bezahlen und ihn ermahnen.", {"gold": -80, "heir_trait": ""}),
        ("Ein Kämmerer soll ihn Sparsamkeit lehren.", {"adm": -45, "heir_trait": "sparsam"})]),
    ev("timid_heir", "Ein zaghafter Erbe",
       "Der Erbe meidet Turniere und Ratssitzungen. Die Gesandten fremder Höfe spotten schon.", "court",
       {"heir_trait": "zaghaft"},
       [("Geduld, er ist noch jung.", {"prestige": -2}),
        ("Ins Feldlager mit ihm.", {"mil": -40, "heir_trait": "", "heir": {"mil": 1}}),
        ("Als Gesandter an einen fremden Hof.", {"dip": -40, "heir_trait": "diplomat"})]),
    ev("suspicious_heir", "Der Erbe wittert Verrat",
       "Der Erbe misstraut jedem Höfling und lässt Briefe öffnen. Der Adel fühlt sich beleidigt.", "conspiracy",
       {"heir_trait": "misstrauisch"},
       [("Er hat vielleicht recht.", {"estate": {"adel": -5}, "adm": 15}),
        ("Ihn mit dem Adel versöhnen.", {"dip": -30, "heir_trait": "leutselig"}),
        ("Ein großes Versöhnungsfest.", {"gold": -60, "estate": {"adel": 8}, "heir_trait": ""})]),
    # --- the ruler
    ev("ruler_ailing", "Der Herrscher kränkelt",
       "Die Leibärzte machen ernste Gesichter. Am Hof beginnt man, sich nach dem Erben zu richten.", "heir",
       {"reign_years_max": 2, "year_min": 1446},
       [("Den Erben auf die Herrschaft vorbereiten.", {"heir": {"adm": 1}, "prestige": -2}),
        ("Die besten Ärzte Europas holen.", {"gold": -60, "prestige": 3}),
        ("Ein Testament, das den Adel bindet.", {"dip": -20, "estate": {"adel": 6}})]),
    ev("cruel_ruler", "Gerüchte über die Grausamkeit des Herrschers",
       "Flugblätter erzählen von Folterkellern und willkürlichen Hinrichtungen. Die Städte murren.", "revolt",
       {"ruler_trait": "grausam"},
       [("Die Drucker verhaften.", {"estate": {"buerger": -8}, "adm": 15}),
        ("Öffentliche Buße tun.", {"prestige": -8, "ruler_trait": ""}),
        ("Ein Gnadenakt für alle Gefangenen.", {"gold": -50, "estate": {"buerger": 8}})]),
    ev("spendthrift_ruler", "Die Schatzkammer leert sich",
       "Bälle, Jagden, Gärten: Der Kämmerer legt dem Herrscher eine bedrückende Rechnung vor.", "court",
       {"ruler_trait": "verschwender"},
       [("Der Glanz der Krone ist es wert.", {"prestige": 3, "estate": {"adel": 4}}),
        ("Ein strenges Sparprogramm.", {"estate": {"adel": -10}, "adm": -20, "ruler_trait": "sparsam"}),
        ("Die Kronjuwelen verpfänden.", {"gold": 70, "prestige": -6})]),
    ev("scholar_ruler", "Die Bibliothek des Herrschers",
       "Der Herrscher sammelt Handschriften aus aller Welt und will sie seinem Volk zugänglich machen.", "printing",
       {"ruler_trait": "gelehrt"},
       [("Eine Hofbibliothek.", {"adm": 30}),
        ("Gelehrte aus ganz Europa einladen.", {"gold": -60, "mods": {"tech_cost": -0.02}}),
        ("Eine Druckerei fördern.", {"dip": -20, "prestige": 4})]),
    ev("general_ruler", "Der Herrscher führt selbst",
       "Gegen den Rat seiner Minister will der Herrscher die Armee persönlich ins Feld führen.", "battle",
       {"ruler_trait": "feldherr", "at_war": True},
       [("An die Front!", {"mil": 40, "prestige": 3}),
        ("Die Regierung braucht ihn daheim.", {"adm": 30, "prestige": -2}),
        ("Eine flammende Rede vor den Truppen.", {"dip": -20, "we": -2})]),
    ev("builder_ruler", "Pläne für einen neuen Palast",
       "Der Herrscher hat Baumeister aus Italien kommen lassen. Die Pläne sind prächtig und teuer.", "city",
       {"ruler_trait": "baumeister", "year_min": 1460},
       [("Die Pläne in die Schublade.", {"adm": 20}),
        ("Bauen!", {"gold": -90, "prestige": 8, "dev_capital": 1}),
        ("Nur ein neuer Flügel.", {"gold": -35, "prestige": 3})]),
    ev("merchant_ruler", "Der Herrscher spekuliert",
       "Der Herrscher hat Geld in eine Handelsfahrt gesteckt. Die Schiffe kehren beladen zurück.", "market",
       {"ruler_trait": "kaufmann"},
       [("Die Gewinne einstreichen.", {"gold": 50, "prestige": -3}),
        ("Ein königliches Handelshaus gründen.", {"dip": -30, "mods": {"trade": 0.02}}),
        ("Den Gewinn den Kaufleuten überlassen.", {"estate": {"buerger": 8}, "prestige": 2})]),
    ev("pious_ruler", "Pilgerfahrt des Herrschers",
       "Der fromme Herrscher will zu den heiligen Stätten pilgern. Der Kanzler warnt vor der langen Abwesenheit.",
       "procession", {"ruler_trait": "fromm"},
       [("Gebet in der Hofkapelle.", {"estate": {"klerus": 5}, "prestige": 1}),
        ("Die Pilgerfahrt antreten.", {"gold": -50, "prestige": 6, "estate": {"klerus": 10}}),
        ("Eine reiche Stiftung statt der Reise.", {"adm": -30, "mods": {"conversion": 0.03}})]),
    ev("friendly_ruler", "Der Herrscher unter dem Volk",
       "Der Herrscher zeigt sich auf Märkten und Kirchweihen. Das Volk liebt ihn, der Adel rümpft die Nase.", "city",
       {"ruler_trait": "leutselig"},
       [("Weiter so.", {"estate": {"buerger": 5, "adel": -3}}),
        ("Auch dem Adel Ehre erweisen.", {"dip": -25, "estate": {"adel": 6}}),
        ("Ein Volksfest auf Staatskosten.", {"gold": -40, "prestige": 4, "estate": {"buerger": 6}})]),
    # --- regency (child ruler, government.gd regency_until; effect end_regency ends it early)
    ev("regency_council", "Streit im Regentschaftsrat",
       "Die Regenten des jungen Herrschers sind sich in nichts einig. Jede Sitzung endet im Geschrei.", "court",
       {"regency": True},
       [("Der Rat soll sich zusammenraufen.", {"prestige": -2}),
        ("Die Mutter des Herrschers führt die Geschäfte.", {"dip": -30, "estate": {"adel": -4, "buerger": 4}}),
        ("Den Adel mit Ämtern beruhigen.", {"gold": -50, "estate": {"adel": 8}})]),
    ev("regency_majority", "Vorzeitig volljährig?",
       "Der junge Herrscher will nicht länger warten. Er verlangt, schon jetzt für mündig erklärt zu werden.",
       "coronation", {"regency": True},
       [("Er muss sich gedulden.", {"prestige": 1}),
        ("Für mündig erklären.", {"adm": -60, "end_regency": True, "estate": {"adel": -6}}),
        ("Die Zustimmung der Räte erkaufen.", {"gold": -80, "end_regency": True})]),
    ev("regency_regent", "Ein ehrgeiziger Regent",
       "Der erste Regent siegelt Urkunden schon mit eigenem Wappen. Manche flüstern, er wolle selbst die Krone.",
       "conspiracy", {"regency": True},
       [("Ihn gewähren lassen.", {"estate": {"adel": 5}, "prestige": -3}),
        ("Ihn als Statthalter an die Grenze schicken.", {"mil": -40, "estate": {"adel": -3}}),
        ("Ihn mit einem reichen Lehen abfinden.", {"gold": -60, "estate": {"adel": 3}})]),
]


def check(e):
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0, e["id"]
    if not e.get("once", True):
        assert "mods" not in first, e["id"]
    for o in e["options"]:
        for k, v in o["effects"].get("mods", {}).items():
            assert abs(v) <= 0.03, e["id"]
        for k in ("heir_trait", "ruler_trait"):
            assert k not in o["effects"] or o["effects"][k] in TRAIT_IDS + ["", "random"], e["id"]


TRAIT_IDS = ["baumeister", "feldherr", "kaufmann", "fromm", "diplomat", "sparsam", "gelehrt", "gerecht", "leutselig",
             "prunk", "grausam", "zaghaft", "verschwender", "misstrauisch"]


def main():
    for e in EVENTS:
        check(e)
        for k in ("heir_trait", "ruler_trait"):
            v = e["trigger"].get(k)
            assert v is None or v in TRAIT_IDS + ["", "any"], e["id"]
    data = events_io.replace_block("heir_", EVENTS)
    print("events %d (heir %d)" % (len(data), len(EVENTS)))


if __name__ == "__main__":
    main()
