"""Context events for the great works (data/monuments.json): one when building starts, one at half time and
one on completion, for every work. Id prefix "mon_", ids "mon_<work>_start|half|done".
Run: python3 tools/content/monument_events.py (idempotent, see events_io.py).

These carry "manual": true: Game._check_events never draws them; Monuments.start/tick fire them through
Game.fire_event at the right moment (once per realm). Linus asked for them after the 2026-10-28 playtest.
The AI builds great works too, so the rules of the other generators hold: first option gold-free,
gold-costing options AI weight <= 10, permanent mods at most 0.03.
"""
import json
import os

import events_io


def _ai(o):
    if o[1].get("gold", 0) < 0:
        return {"ai": min(o[2] if len(o) > 2 else 10, 10)}
    return {"ai": o[2]} if len(o) > 2 else {}


def ev(work, stage, title, text, image, options):
    return {"id": "mon_%s_%s" % (work, stage), "manual": True, "tag": "*", "title": title, "text": text,
            "image": image, "trigger": {},
            "options": [dict(text=o[0], effects=o[1], **_ai(o)) for o in options]}


EVENTS = [
    # --- cathedral
    ev("cathedral", "start", "Der Grundstein des Doms",
       "Der Bischof segnet den Grundstein. Die Baumeister fragen, wie prächtig der Dom werden soll.", "church",
       [("Nach den alten Plänen bauen.", {"adm": 20}),
        ("Die Kirche soll mitbezahlen.", {"estate": {"klerus": -4}, "gold": 40}),
        ("Spenden in allen Pfarreien sammeln.", {"monument_progress": 4, "estate": {"buerger": -3}})]),
    ev("cathedral", "half", "Das Gewölbe steht",
       "Das Mittelschiff ist eingewölbt. Ein Glasmaler bietet Fenster an, wie man sie noch nie gesehen hat.", "artist",
       [("Schlichtes Glas genügt.", {"monument_progress": 3}),
        ("Die bunten Fenster bestellen.", {"gold": -40, "prestige": 4}),
        ("Die Zünfte stiften je ein Fenster.", {"estate": {"buerger": 4}, "adm": -10})]),
    ev("cathedral", "done", "Die Weihe des Doms",
       "Der neue Dom ist vollendet. Bischöfe aus dem ganzen Land kommen zur Weihe.", "procession",
       [("Ein großes Weihefest.", {"prestige": 5, "estate": {"klerus": 5}}),
        ("Eine Wallfahrt stiften.", {"gold": 40, "estate": {"klerus": 3}}),
        ("Den Bauleuten danken.", {"estate": {"buerger": 5}, "adm": 15})]),
    # --- embassy
    ev("embassy", "start", "Ein Hof für Gesandte",
       "Für den neuen Gesandtenhof braucht es Gästezimmer, Ställe und einen Saal für Empfänge.", "treaty",
       [("Bescheiden bauen.", {"dip": 20}),
        ("Fremde Höfe um Rat fragen.", {"dip": 10, "prestige": 1}),
        ("Den Adel als Gastgeber gewinnen.", {"estate": {"adel": 4}, "monument_progress": 3, "dip": -10})]),
    ev("embassy", "half", "Der erste Empfang",
       "Noch ist nicht alles fertig, doch die ersten Gesandten wollen schon im neuen Saal empfangen werden.", "court",
       [("Im halbfertigen Saal empfangen.", {"dip": 25, "prestige": -1}),
        ("Ein Festmahl im Garten.", {"gold": -30, "dip": 30, "prestige": 2}),
        ("Sie sollen warten, bis alles fertig ist.", {"monument_progress": 3})]),
    ev("embassy", "done", "Der Gesandtenhof öffnet",
       "Der Gesandtenhof ist vollendet. Aus allen Hauptstädten treffen Glückwünsche ein.", "treaty",
       [("Alle Gesandten zum Fest laden.", {"dip": 40, "prestige": 2}),
        ("Ein Amt für Verträge einrichten.", {"mods": {"ae_decay": 0.02}, "adm": -20}),
        ("Die Spione unter ihnen beobachten.", {"mil": 15, "dip": 15})]),
    # --- arsenal
    ev("arsenal", "start", "Das Arsenal wird abgesteckt",
       "Am Fluss werden Gießhütten, Lager und Werkstätten abgesteckt. Die Schmiede der Stadt sorgen sich um ihr Geschäft.", "artillery",
       [("Die Schmiede einstellen.", {"estate": {"buerger": 3}, "mil": 10}),
        ("Meister aus der Fremde holen.", {"gold": -30, "monument_progress": 5}),
        ("Soldaten als Bauleute.", {"monument_progress": 3, "army_power": -0.1})]),
    ev("arsenal", "half", "Die ersten Geschütze",
       "Die Gießhütte ist fertig. Die ersten Rohre kühlen im Sand ab, aber eines ist beim Probeschuss geplatzt.", "camp",
       [("Mehr Proben, weniger Eile.", {"mil": 25}),
        ("Weiter wie bisher.", {"monument_progress": 4, "manpower": -500}),
        ("Den Gießmeister bestrafen.", {"prestige": -1, "estate": {"buerger": -3}, "mil": 15})]),
    ev("arsenal", "done", "Das Arsenal ist fertig",
       "Lager voller Pulver, Spieße und Geschütze. Die Hauptleute können das neue Arsenal kaum erwarten.", "artillery",
       [("Die Regimenter neu ausrüsten.", {"army_power": 0.2, "mil": 15}),
        ("Eine Parade vor dem Volk.", {"prestige": 4, "estate": {"adel": 3}}),
        ("Überschüssige Waffen verkaufen.", {"gold": 60})]),
    # --- university
    ev("university", "start", "Die Universität wird gegründet",
       "Die Stiftungsurkunde ist gesiegelt. Nun streiten Kirche und Bürger darum, wer die Lehrer stellt.", "scholar",
       [("Die Kirche stellt die Lehrer.", {"estate": {"klerus": 5, "buerger": -2}}),
        ("Freie Gelehrte berufen.", {"estate": {"buerger": 4, "klerus": -3}, "adm": 15}),
        ("Der Herrscher entscheidet selbst.", {"adm": 25, "prestige": 1})]),
    ev("university", "half", "Die ersten Studenten",
       "Die Hörsäle sind halb fertig, doch Studenten aus aller Welt füllen schon die Gassen. Es gibt Händel mit den Bürgern.", "tavern",
       [("Eigene Gerichtsbarkeit für die Studenten.", {"adm": 20, "estate": {"buerger": -3}}),
        ("Die Stadtwache soll sie zähmen.", {"estate": {"buerger": 3}, "mil": -10}),
        ("Wohnhäuser für die Studenten bauen.", {"gold": -40, "dev_capital": 1})]),
    ev("university", "done", "Die Universität ist eröffnet",
       "Die Universität ist vollendet. Zur Eröffnung halten die Gelehrten eine Disputation vor dem Hof.", "scholar",
       [("Die Bibliothek füllen.", {"adm": 40}),
        ("Juristen für die Verwaltung ausbilden.", {"mods": {"tax": 0.02}, "adm": -15}),
        ("Ehrendoktor für den Herrscher.", {"prestige": 5})]),
    # --- exchange
    ev("exchange", "start", "Die Börse wird geplant",
       "Die Kaufleute wollen eine Börse wie in Antwerpen. Sie bieten an, einen Teil der Kosten zu tragen, wenn sie mitbestimmen.", "bank",
       [("Die Krone baut allein.", {"prestige": 2, "adm": 10}),
        ("Die Kaufleute zahlen mit.", {"gold": 60, "estate": {"buerger": 5}, "prestige": -1}),
        ("Die Bank leiht uns das Geld.", {"loan": 1, "prestige": -1}, 5)]),
    ev("exchange", "half", "Händel um die Börsenordnung",
       "Noch ist die Halle nicht fertig, doch die Kaufleute streiten schon um Regeln für Wechsel und Kredite.", "market",
       [("Eine strenge Ordnung.", {"adm": 20, "estate": {"buerger": -3}}),
        ("Die Kaufleute regeln es selbst.", {"estate": {"buerger": 5}}),
        ("Ein königlicher Aufseher.", {"gold": -25, "dip": 20, "monument_progress": 3})]),
    ev("exchange", "done", "Die Börse öffnet",
       "Am ersten Handelstag drängen sich Kaufleute aus halb Europa in der neuen Halle.", "bank",
       [("Gebühren auf jeden Wechsel.", {"gold": 70, "estate": {"buerger": -3}}),
        ("Fremde Kaufleute willkommen heißen.", {"dip": 30, "mods": {"trade": 0.02}}),
        ("Der Krone eigene Handelshäuser.", {"estate": {"buerger": -4}, "adm": 25, "gold": 30})]),
    # --- academy
    ev("academy", "start", "Eine Schule für Offiziere",
       "Die Kriegsakademie wird gegründet. Der Adel fürchtet, dass bald Bürgersöhne die Regimenter führen.", "knights",
       [("Nur Söhne des Adels.", {"estate": {"adel": 5}, "mil": 10}),
        ("Wer begabt ist, wird aufgenommen.", {"estate": {"adel": -4, "buerger": 4}, "mil": 20}),
        ("Veteranen als Lehrer.", {"mil": 25, "manpower": -500})]),
    ev("academy", "half", "Manöver der Kadetten",
       "Die ersten Kadetten üben schon, obwohl die Gebäude noch nicht stehen. Ein Manöver vor dem Hof wird gewünscht.", "camp",
       [("Ein kleines Manöver.", {"mil": 20}),
        ("Ein großes Manöver mit Gästen.", {"gold": -30, "prestige": 4, "dip": 10}),
        ("Die Kadetten helfen beim Bau.", {"monument_progress": 4, "estate": {"adel": -2}})]),
    ev("academy", "done", "Der erste Jahrgang",
       "Die Kriegsakademie ist vollendet. Der erste Jahrgang junger Offiziere legt den Eid ab.", "knights",
       [("Sie führen die Regimenter.", {"army_power": 0.2, "mil": 20}),
        ("Sie lehren selbst an der Akademie.", {"mods": {"army_power_regen": 0.03}}),
        ("Ein Fest für die Familien.", {"prestige": 4, "estate": {"adel": 4}})]),
    # --- palace
    ev("palace", "start", "Pläne für einen Palast",
       "Die Baumeister legen drei Entwürfe vor: einen nach italienischer Art, einen nach französischer und einen ganz eigenen.", "court",
       [("Nach italienischer Art.", {"prestige": 2, "dip": 15}),
        ("Nach französischer Art.", {"prestige": 3, "estate": {"adel": 3}}),
        ("Ein ganz eigener Stil.", {"prestige": 4, "adm": -10})]),
    ev("palace", "half", "Der Garten des Palastes",
       "Der Rohbau steht. Nun soll ein Garten mit Brunnen, Labyrinth und seltenen Pflanzen angelegt werden.", "harvest",
       [("Ein schlichter Garten.", {"monument_progress": 3}),
        ("Pflanzen aus fernen Ländern.", {"gold": -40, "prestige": 4, "dip": 10}),
        ("Die Bauern sollen helfen.", {"monument_progress": 5, "estate": {"buerger": -4}})]),
    ev("palace", "done", "Der Palast ist vollendet",
       "Der Prunkpalast ist fertig. Ganz Europa spricht von seinen Sälen, Spiegeln und Gärten.", "coronation",
       [("Den Hof in den Palast holen.", {"prestige": 5, "estate": {"adel": -3}, "adm": 20}),
        ("Ein Fest für alle Fürsten.", {"dip": 40, "prestige": 3}),
        ("Den Palast dem Volk zeigen.", {"estate": {"buerger": 5}, "prestige": 2})]),
]


def check(e, works):
    work, stage = e["id"][4:].rsplit("_", 1)
    assert work in works and stage in ("start", "half", "done"), e["id"]
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0, e["id"]
    for o in e["options"]:
        for k, v in o["effects"].get("mods", {}).items():
            assert abs(v) <= 0.03, e["id"]
        if o["effects"].get("gold", 0) < 0:
            assert o.get("ai", 25) <= 10, e["id"]


def main():
    works = json.load(open(os.path.join(events_io.ROOT, "data/monuments.json"), encoding="utf-8"))
    for e in EVENTS:
        check(e, works)
    assert len(EVENTS) == 3 * len(works)
    data = events_io.replace_block("mon_", EVENTS)
    print("events %d (mon %d)" % (len(data), len(EVENTS)))


if __name__ == "__main__":
    main()
