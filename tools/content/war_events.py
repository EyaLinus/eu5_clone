"""War and diplomacy context events (v0.9.3+ multi-month battles, sieges, coalitions, vassals).
Two blocks in data/events.json:

- "war_": manual events fired once per realm through Game.fire_event: war_first_win / war_first_loss and
  war_long_battle (Warfare.finish), war_first_fort / war_capital_lost (Game._siege), war_peace_gain /
  war_peace_loss / war_white_peace (Game.make_peace).
- "dip_": dip_coalition / dip_first_vassal / dip_became_vassal (manual, Game.declare_war and make_peace) plus a
  few random diplomacy events using ae_min, allies, has_vassal and is_vassal.

Run: python3 tools/content/war_events.py (idempotent, see events_io.py).
Rules as in the other generators: first option gold-free and no war, gold-costing options AI weight <= 10,
mods <= 0.03, repeatable random events player-only.
"""
import events_io
from ctx_events import check, ev

WAR = [
    ev("war_first_win", "Der erste Sieg im Feld",
       "Nach Wochen des Ringens weicht der Feind. Es ist der erste Sieg deiner Armee in einer offenen Feldschlacht.", "battle", {},
       [("Ein Dankgottesdienst.", {"prestige": 3, "estate": {"klerus": 2}}),
        ("Die Offiziere befördern.", {"mil": 20, "estate": {"adel": 2}}),
        ("Die Beute verteilen.", {"gold": 30, "manpower": -300})], manual=True),
    ev("war_first_loss", "Die erste verlorene Schlacht",
       "Deine Armee hat das Feld räumen müssen. Die Überlebenden sammeln sich, aber im Land fragt man nach dem Schuldigen.", "battle", {},
       [("Aus den Fehlern lernen.", {"mil": 25}),
        ("Den Befehlshaber ablösen.", {"prestige": -1, "mil": 10, "estate": {"adel": -2}}),
        ("Neue Rekruten ausheben.", {"manpower": 1000, "estate": {"buerger": -2}})], manual=True),
    ev("war_long_battle", "Eine Schlacht über Monate",
       "Wochenlang lagen sich die Heere gegenüber, ein Gefecht folgte dem nächsten. Die Soldaten haben gelernt, in Schanzen "
       "und Gräben zu überleben.", "camp", {},
       [("Die Erfahrung festhalten.", {"mil": 25}),
        ("Lazarette einrichten.", {"manpower": 800, "estate": {"klerus": 2}}),
        ("Die Ausdauer der Truppe ehren.", {"prestige": 2, "estate": {"adel": 2}})], manual=True),
    ev("war_first_fort", "Die erste Festung fällt",
       "Nach langer Belagerung hat die Besatzung die Tore geöffnet. Zum ersten Mal hat dein Heer eine befestigte Stadt genommen.", "siege", {},
       [("Die Mauern studieren.", {"mil": 20, "adm": 5}),
        ("Die Besatzung frei abziehen lassen.", {"prestige": 2, "dip": 10}),
        ("Die Stadt muss zahlen.", {"gold": 35, "ae": 2})], manual=True),
    ev("war_capital_lost", "Feinde in der Hauptstadt",
       "Fremde Truppen stehen in deiner Hauptstadt. Der Hof ist geflohen, die Beamten warten ab, wer am Ende siegt.", "siege", {},
       [("Den Widerstand im Land organisieren.", {"manpower": 1500, "estate": {"adel": 2}}),
        ("Die Kanzlei in Sicherheit bringen.", {"adm": 15, "prestige": -1}),
        ("Um Hilfe bitten.", {"dip": 20, "prestige": -2})], manual=True),
    ev("war_peace_gain", "Ein siegreicher Friede",
       "Der Friedensvertrag ist unterzeichnet. Neue Provinzen gehören zu deinem Reich, doch ihre Bewohner sind dir noch fremd.", "treaty", {},
       [("Die alten Rechte der Provinzen bestätigen.", {"adm": 15, "estate": {"adel": 2}}),
        ("Den Sieg feiern.", {"prestige": 3}),
        ("Eigene Beamte schicken.", {"adm": -10, "estate": {"buerger": 3}, "dip": 10})], manual=True),
    ev("war_peace_loss", "Ein bitterer Friede",
       "Du musstest Provinzen abtreten. Die Vertriebenen kommen in deine Städte, und am Hof wird schon von Rache gesprochen.", "mourning", {},
       [("Die Flüchtlinge aufnehmen.", {"estate": {"buerger": 3}, "dev_random": 1}),
        ("Die Schuld den Generälen geben.", {"estate": {"adel": -3}, "mil": 15}),
        ("Die Rückkehr beanspruchen.", {"prestige": 2, "dip": -10})], manual=True),
    ev("war_white_peace", "Ein Friede ohne Sieger",
       "Der Krieg endet, wie er begonnen hat. Kein Fußbreit Land hat den Besitzer gewechselt, aber viele Männer sind tot.", "treaty", {},
       [("Die Heimkehrer versorgen.", {"estate": {"buerger": 2}, "we": -2}),
        ("Die Grenzfestungen stärken.", {"mil": 15}),
        ("Den Frieden als Erfolg verkünden.", {"prestige": 1, "dip": 10})], manual=True),
]

DIP = [
    ev("dip_coalition", "Eine Koalition gegen dich",
       "Deine Nachbarn haben sich gegen dich verbündet. Ihre Gesandten sprechen von Gleichgewicht, ihre Heere marschieren.", "diet", {},
       [("Das Volk zur Verteidigung rufen.", {"manpower": 2000, "estate": {"buerger": -2}}),
        ("Einen Keil zwischen sie treiben.", {"dip": 25}),
        ("Die Festungen rüsten.", {"mil": 20, "gold": -20}, 8)], manual=True),
    ev("dip_first_vassal", "Der erste Vasall",
       "Ein fremder Fürst hat dir den Treueid geleistet. Er herrscht weiter in seinem Land, aber nach deinem Willen.", "coronation", {},
       [("Ihn an den Hof laden.", {"prestige": 3, "dip": 10}),
        ("Tribut verlangen.", {"gold": 30, "dip": -10}),
        ("Seine Söhne erziehen lassen.", {"dip": 20, "estate": {"adel": 2}})], manual=True),
    ev("dip_became_vassal", "Unter fremder Hoheit",
       "Du musstest dich einem fremden Herrscher unterwerfen. Dein Hof ist gedemütigt, aber dein Haus regiert weiter.", "mourning", {},
       [("Geduldig auf die Zeit warten.", {"adm": 20}),
        ("Die Ehre des Hauses retten.", {"prestige": 2, "estate": {"adel": 3}}),
        ("Dem neuen Herrn dienen.", {"dip": 25, "prestige": -2})], manual=True),
    ev("dip_neighbors_fear", "Die Nachbarn sind beunruhigt",
       "Deine Eroberungen machen den Nachbarn Angst. Ihre Gesandten treffen sich, und an den Höfen spricht man von einem Bündnis gegen dich.",
       "diet", {"ae_min": 40, "year_min": 1450},
       [("Beruhigende Briefe schicken.", {"ae": -6, "dip": -15}),
        ("Geschenke an die Höfe.", {"ae": -10, "gold": -40}, 8),
        ("Sie sollen sich fürchten.", {"prestige": 2, "mil": 10})]),
    ev("dip_alliance_web", "Ein Netz von Bündnissen",
       "Deine Verbündeten erwarten Rat und Hilfe, und ihre Gesandten füllen deine Vorzimmer. Deine Kanzlei kommt kaum nach.", "diet",
       {"allies": 3, "year_min": 1460},
       [("Eine eigene Kanzlei für Bündnisse.", {"adm": -15, "dip": 30}),
        ("Die Gesandten mit Festen ehren.", {"prestige": 2, "gold": -25}, 8),
        ("Den Bündnispartnern Kredit geben.", {"dip": 15})]),
    ev("dip_vassal_heir", "Der Erbe des Vasallen",
       "Der Erbe deines Vasallen will an deinem Hof erzogen werden. Seine Mutter fürchtet um ihn, sein Vater hofft auf deine Gunst.", "heir",
       {"has_vassal": True, "year_min": 1450},
       [("Den Jungen aufnehmen.", {"dip": 20, "prestige": 1}),
        ("Ihn mit dem eigenen Sohn erziehen.", {"dip": 10, "estate": {"adel": 2}}),
        ("Er soll zu Hause bleiben.", {"adm": 10})]),
    ev("dip_overlord_summons", "Der Lehnsherr ruft",
       "Dein Lehnsherr verlangt, dass du persönlich an seinem Hof erscheinst. Dein Adel will sich nicht vor ihm verneigen.", "court",
       {"is_vassal": True, "year_min": 1450},
       [("Hinreisen und Treue zeigen.", {"dip": 20, "prestige": -1}),
        ("Einen Gesandten schicken.", {"adm": 10}),
        ("Krankheit vortäuschen.", {"estate": {"adel": 3}, "dip": -10})]),
]


def main():
    for e in WAR + DIP:
        check(e)
        assert "war" not in e["options"][0]["effects"], e["id"]
    events_io.replace_block("war_", WAR)
    data = events_io.replace_block("dip_", DIP)
    print("events %d (war %d, dip %d)" % (len(data), len(WAR), len(DIP)))


if __name__ == "__main__":
    main()
