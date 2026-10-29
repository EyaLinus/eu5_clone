"""Context events for buildings and the navy (v0.9.3 systems). Two blocks in data/events.json:

- "bld_": manual events fired by Economy.construction_tick through Game.fire_event, once per realm:
  bld_<building>_first when the first building of that kind is finished, bld_max_level when a building
  first reaches its top level.
- "nav_": nav_first_win / nav_first_loss (manual, fired by Naval._fleet_battle) plus a few random naval
  events using the conditions ships_min, blockaded, coastal and the effect "ships".

Run: python3 tools/content/ctx_events.py (idempotent, see events_io.py).
Rules as in the other generators: first option gold-free, gold-costing options AI weight <= 10, mods <= 0.03.
Repeatable random events are player-only (is_player): always-eligible repeatables for many AI realms dilute
the AI event pool (lesson from the court batch).
"""
import json
import os

import events_io


def _ai(o):
    if o[1].get("gold", 0) < 0:
        return {"ai": min(o[2] if len(o) > 2 else 10, 10)}
    return {"ai": o[2]} if len(o) > 2 else {}


def ev(id, title, text, image, trigger, options, once=True, manual=False):
    e = {"id": id}
    if not once:
        e["once"] = False
    if manual:
        e["manual"] = True
    e.update({"tag": "*", "title": title, "text": text, "image": image, "trigger": trigger,
              "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]})
    return e


def first(bid, title, text, image, options):
    return ev("bld_%s_first" % bid, title, text, image, {}, options, manual=True)


BUILDINGS = [
    first("manufactory", "Die erste Manufaktur",
          "In deiner ersten Manufaktur arbeiten hundert Leute unter einem Dach. Die Zünfte sehen das mit Sorge.", "market",
          [("Die Zünfte beruhigen.", {"estate": {"buerger": 4}, "adm": 10}),
           ("Arbeiter vom Land anwerben.", {"dev_random": 1, "estate": {"adel": -3}}),
           ("Privilegien für den Unternehmer.", {"gold": 40, "estate": {"buerger": -2}})]),
    first("fortress", "Die erste Festung",
          "Die neue Festung mit Bastionen nach italienischer Art ist fertig. Fremde Offiziere kommen, um sie zu studieren.", "siege",
          [("Die eigenen Offiziere lernen daraus.", {"mil": 30}),
           ("Den Fremden alles zeigen.", {"dip": 20, "prestige": 2}),
           ("Eine Garnison aus dem Adel.", {"estate": {"adel": 4}, "manpower": 500})]),
    first("courthouse", "Der erste Gerichtshof",
          "Im neuen Gerichtshof wird nach geschriebenem Recht geurteilt. Die Grundherren verlieren ihre Gerichte.", "court",
          [("Das Landrecht aufschreiben.", {"adm": 25}),
           ("Den Grundherren Sitze geben.", {"estate": {"adel": 4}, "adm": 10}),
           ("Gelehrte Richter berufen.", {"estate": {"buerger": 3, "klerus": 2}, "adm": -10, "prestige": 2})]),
    first("harbor", "Der erste große Hafen",
          "Kaianlagen, Kräne und ein Leuchtturm: Der neue Hafen zieht Schiffe aus fernen Ländern an.", "naval",
          [("Hafenzoll erheben.", {"gold": 40}),
           ("Fremde Kaufleute anlocken.", {"dip": 20, "estate": {"buerger": 3}}),
           ("Eine Werft dazubauen.", {"ships": 2, "mil": -10})]),
    first("university", "Die erste Landesuniversität",
          "Die neue Universität in der Provinz nimmt den ersten Jahrgang auf. Die Professoren wollen eigene Rechte.", "scholar",
          [("Freiheit der Lehre.", {"adm": 30, "estate": {"klerus": -3}}),
           ("Die Kirche führt die Aufsicht.", {"estate": {"klerus": 5}, "adm": 10}),
           ("Stipendien für arme Studenten.", {"gold": -40, "dev_random": 1, "prestige": 2})]),
    first("exchange", "Die erste Wechselbank",
          "In der neuen Wechselbank tauschen Kaufleute Münzen aus ganz Europa. Die Bankiers bieten der Krone Kredit an.", "bank",
          [("Freundlich ablehnen.", {"dip": 15, "estate": {"buerger": 2}}),
           ("Die Gebühren besteuern.", {"gold": 50, "estate": {"buerger": -3}}),
           ("Eine Staatsbank gründen.", {"adm": -25, "mods": {"income": 0.02}}, 10)]),
    first("arsenal", "Das erste Zeughaus",
          "Das neue Zeughaus lagert Waffen für tausende Soldaten. Die Hauptleute wollen sofort neu ausrüsten.", "artillery",
          [("Die Regimenter ausrüsten.", {"army_power": 0.15, "mil": 10}),
           ("Ein Teil für die Landwehr.", {"manpower": 1500}),
           ("Alte Waffen verkaufen.", {"gold": 45})]),
    ev("bld_max_level", "Ein Musterbau", "Zum ersten Mal hat ein Gebäude in deinem Reich die höchste Ausbaustufe erreicht. Baumeister aus "
       "den Nachbarländern kommen, um es zu sehen.", "city", {},
       [("Die Baumeister führen herum.", {"prestige": 3, "dip": 10}),
        ("Die Baupläne verkaufen.", {"gold": 40}),
        ("Die Bauleute belohnen.", {"estate": {"buerger": 4}, "adm": 10})], manual=True),
]

NAVAL = [
    ev("nav_first_win", "Der erste Seesieg", "Deine Flotte hat zum ersten Mal eine Seeschlacht gewonnen. Die Matrosen feiern in den Häfen.", "naval",
       {},
       [("Den Admiral ehren.", {"prestige": 4}),
        ("Die Prisen verkaufen.", {"gold": 40}),
        ("Die erbeuteten Schiffe behalten.", {"ships": 2, "dip": -10})], manual=True),
    ev("nav_first_loss", "Die erste Niederlage zur See", "Deine Flotte ist geschlagen. In den Häfen fragt man, wer schuld ist.", "naval",
       {},
       [("Aus den Fehlern lernen.", {"mil": 25}),
        ("Den Admiral absetzen.", {"prestige": -1, "estate": {"adel": -3}, "mil": 15}),
        ("Sofort neue Schiffe bauen.", {"gold": -40, "ships": 3}, 5)], manual=True),
    ev("nav_shipwrights", "Die Fleute", "In Holland baut man ein neues Frachtschiff: billig, geräumig und mit kleiner Mannschaft. "
       "Deine Reeder wollen es nachbauen.", "naval",
       {"year_min": 1590, "coastal": True, "ships_min": 4},
       [("Die Bauweise studieren.", {"mil": 25, "dip": 10}),
        ("Holländische Meister anstellen.", {"gold": -40, "ships": 3}, 5),
        ("Wir bauen wie immer.", {"adm": 15})]),
    ev("nav_privateers", "Kaperbriefe", "Kapitäne bitten um Kaperbriefe gegen die Handelsschiffe deiner Feinde.", "naval",
       {"at_war": True, "coastal": True, "ships_min": 3},
       [("Kaperbriefe ausstellen.", {"gold": 30, "dip": -15}),
        ("Nur gegen Feinde auf See.", {"mil": 20}),
        ("Seeräuberei bleibt verboten.", {"prestige": 2})]),
    ev("nav_blockade", "Die Häfen sind blockiert", "Feindliche Schiffe sperren deine Häfen. Die Kaufleute klagen, das Brot wird teurer.", "naval",
       {"blockaded": True, "is_player": True},
       [("Durchhalten.", {"estate": {"buerger": -3}, "mil": 10}),
        ("Schmuggler belohnen.", {"gold": -20, "estate": {"buerger": 3}}),
        ("Die Flotte muss ausbrechen.", {"ships": -1, "prestige": 2})], once=False),
    ev("nav_storm", "Sturm über der Flotte", "Ein schwerer Sturm hat mehrere Schiffe beschädigt. Die Werften können nicht alle sofort reparieren.", "naval",
       {"ships_min": 8, "coastal": True},
       [("Die Schäden in Ruhe ausbessern.", {"ships": -1, "mil": 10}),
        ("Tag und Nacht reparieren.", {"gold": -30}),
        ("Die Wracks aufgeben.", {"ships": -2, "gold": 15})]),
    ev("nav_cartographer", "Ein Kartenzeichner", "Ein Seemann hat die Küsten und Untiefen deiner Meere genauer gezeichnet als je zuvor.", "exploration",
       {"year_min": 1480, "coastal": True, "ships_min": 2},
       [("Die Karten der Flotte geben.", {"mil": 20}),
        ("Die Karten an Kaufleute verkaufen.", {"gold": 35}),
        ("Ihn an den Hof holen.", {"prestige": 3, "adm": 10})]),
    ev("nav_sailors", "Matrosen fehlen", "Die Kriegsflotte findet kaum noch Matrosen. Die Fischer wollen nicht zur See für den König.", "naval",
       {"at_war": True, "ships_min": 6, "is_player": True},
       [("Bessere Heuer versprechen.", {"estate": {"buerger": 3}, "dip": -10}),
        ("Pressgangs in den Häfen.", {"manpower": -800, "estate": {"buerger": -4}, "mil": 15}),
        ("Weniger Schiffe bemannen.", {"ships": -2, "adm": 10})], once=False),
]


def check(e):
    assert len(e["options"]) == 3, e["id"]
    first_eff = e["options"][0]["effects"]
    assert first_eff.get("gold", 0) >= 0, e["id"]
    if not e.get("once", True):
        assert "mods" not in first_eff and e["trigger"].get("is_player"), e["id"]
    for o in e["options"]:
        for v in o["effects"].get("mods", {}).values():
            assert abs(v) <= 0.03, e["id"]
        if o["effects"].get("gold", 0) < 0:
            assert o.get("ai", 25) <= 10, e["id"]


def main():
    bdefs = json.load(open(os.path.join(events_io.ROOT, "data/buildings.json"), encoding="utf-8"))
    for e in BUILDINGS + NAVAL:
        check(e)
    for e in BUILDINGS:
        assert e["id"] == "bld_max_level" or e["id"][4:-6] in bdefs, e["id"]
    events_io.replace_block("bld_", BUILDINGS)
    data = events_io.replace_block("nav_", NAVAL)
    print("events %d (bld %d, nav %d)" % (len(data), len(BUILDINGS), len(NAVAL)))


if __name__ == "__main__":
    main()
