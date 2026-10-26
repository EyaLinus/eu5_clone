"""Economy/military content for the systems added since v0.7: goods and market shocks, trade pacts,
buildings, roads, harbours, loans, mercenaries, army morale and budget sliders.

Events: generic, id prefix "eco_", always placed right before the "gov_" block (gov_events.py keeps that
block at the tail). Missions: two per playable nation, ids "<tag>_eco_*". Re-running replaces both.
Run: python3 tools/content/eco_events.py

Rules (see project content lessons): every option is a trade-off; the AI-favoured first option never costs
gold; repeatable events ("once": False, 10-year cooldown) give no permanent mods in their first option;
permanent event mods stay at 0.01-0.03 because generic events fire for all ~50 nations.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def ev(id, title, text, image, trigger, options, once=True):
    e = {"id": "eco_" + id}
    if not once:
        e["once"] = False
    e.update({"tag": "*", "title": title, "text": text, "image": image, "trigger": trigger,
              "options": [dict(text=o[0], effects=o[1], **({"ai": o[2]} if len(o) > 2 else {})) for o in options]})
    return e


EVENTS = [
    # --- goods and markets
    ev("scarcity", "Knappheit treibt die Preise",
       "Eine Ware aus deinem Land ist plötzlich überall gefragt. Die Händler reiben sich die Hände, das Volk murrt.", "market",
       {"shock": "up", "year_min": 1450},
       [("Die Lager räumen und verkaufen.", {"gold": 45, "estate": {"buerger": -4}}),
        ("Den Preis für die eigenen Leute deckeln.", {"estate": {"buerger": 6}, "prestige": 2}),
        ("Vorräte anlegen für schlechte Zeiten.", {"adm": -25, "mods": {"trade": 0.01}}, 20)], once=False),
    ev("glut", "Die Märkte sind überschwemmt",
       "Für deine wichtigste Ware zahlt niemand mehr einen anständigen Preis. Die Händler stehen vor dem Ruin.", "market",
       {"shock": "down", "year_min": 1450},
       [("Sie sollen neue Abnehmer suchen.", {"dip": -20, "estate": {"buerger": -4}}),
        ("Die Ware für die Krone aufkaufen.", {"gold": -40, "estate": {"buerger": 8}}, 25),
        ("Die Ausfuhr verbieten.", {"estate": {"buerger": -8}, "adm": 20}, 25)], once=False),
    ev("monopoly", "Herr über einen Markt",
       "Kein anderes Land liefert so viel von einer Ware wie deines. Ganz Europa muss deine Preise zahlen.", "bank",
       {"goods_leader": True},
       [("Die Preise diktieren.", {"gold": 60, "prestige": -2}),
        ("Als ehrlicher Händler gelten.", {"prestige": 5, "dip": 25}),
        ("Eine Handelsgilde gründen.", {"adm": -30, "mods": {"production": 0.02}}, 25)]),
    ev("trade_fair", "Eine gemeinsame Messe",
       "Kaufleute aus deinem Land und von deinem Handelspartner wollen eine große Messe abhalten.", "market",
       {"trade_pacts_min": 1, "year_min": 1450},
       [("Die Messe unter königlichen Schutz stellen.", {"dip": -25, "mods": {"trade": 0.02}}),
        ("Standgeld kassieren.", {"gold": 40, "estate": {"buerger": -3}}),
        ("Lieber im eigenen Land handeln.", {"adm": 20, "prestige": -2})]),
    ev("pact_quarrel", "Streit unter Handelspartnern",
       "Deine Handelspartner werfen sich gegenseitig Betrug vor und verlangen, dass du schlichtest.", "treaty",
       {"trade_pacts_min": 2},
       [("Einen Schiedsspruch fällen.", {"dip": -30, "prestige": 4}),
        ("Sich heraushalten.", {"prestige": -3, "adm": 15}),
        ("Beide zahlen eine Gebühr.", {"gold": 50, "dip": -15}, 20)]),
    ev("silver_vein", "Eine neue Silberader",
       "Bergleute stoßen auf eine reiche Silberader. Glücksritter strömen in die Berge.", "mine",
       {"produces": "silver"},
       [("Das Bergregal für die Krone.", {"gold": 70, "estate": {"adel": -5}}),
        ("Freie Bergstädte gründen.", {"dev_random": 1, "estate": {"buerger": 5}}),
        ("An Bankiers verpachten.", {"gold": 120, "mods": {"income": -0.01}}, 20)]),
    ev("vintage", "Ein Jahrhundertjahrgang",
       "Die Weinlese war so gut wie seit Menschengedenken nicht. Fürsten aus ganz Europa bestellen Fässer.", "harvest",
       {"produces": "wine", "year_min": 1450},
       [("Den Wein verkaufen.", {"gold": 45}),
        ("An fremde Höfe verschenken.", {"dip": 30, "prestige": 3}),
        ("Ein großes Fest für das Volk.", {"gold": -30, "estate": {"buerger": 5, "adel": 3}}, 20)]),
    ev("herring", "Die Heringe kommen",
       "Riesige Heringsschwärme ziehen an deiner Küste vorbei. Jedes Boot fährt hinaus.", "naval",
       {"produces": "fish", "coastal": True},
       [("Salz für die Fässer bereitstellen.", {"gold": 35, "mil": 10}),
        ("Fischer sollen Seeleute werden.", {"manpower": 1500}),
        ("Eine Fischereiordnung erlassen.", {"adm": -25, "mods": {"production": 0.01}}, 25)]),
    ev("hammer_mills", "Hammerwerke am Fluss",
       "Schmiede wollen am Fluss wassergetriebene Hämmer bauen. Die Müller fürchten um ihr Wasser.", "mine",
       {"produces": "iron", "year_min": 1460},
       [("Die Schmiede bekommen das Recht.", {"mods": {"production": 0.01}, "estate": {"adel": -4}}),
        ("Die Müller haben Vorrang.", {"estate": {"adel": 4}, "mil": -15}),
        ("Waffen für die Krone schmieden lassen.", {"gold": -30, "mods": {"combat": 0.01}}, 20)]),
    ev("weavers_strike", "Die Weber legen die Arbeit nieder",
       "Die Verleger zahlen immer weniger für jedes Stück Tuch. Nun stehen die Webstühle still.", "revolt",
       {"produces": "cloth", "year_min": 1470},
       [("Die Verleger sollen mehr zahlen.", {"estate": {"buerger": -6}, "dip": 15}),
        ("Die Stadtwache schickt sie zurück.", {"mil": -20, "estate": {"buerger": 3}, "prestige": -2}),
        ("Die Krone schießt Lohn zu.", {"gold": -40, "estate": {"buerger": 6}}, 25)]),
    ev("wool_staple", "Streit um den Wollstapel",
       "Ausländische Kaufleute wollen deine Wolle direkt bei den Schäfern kaufen und den Stapelmarkt umgehen.", "market",
       {"produces": "wool", "year_min": 1450},
       [("Nur am Stapel wird gehandelt.", {"mods": {"trade": 0.01}, "dip": -20}),
        ("Freier Verkauf für alle.", {"estate": {"adel": 5, "buerger": -5}, "gold": 30}),
        ("Weber im eigenen Land ansiedeln.", {"adm": -30, "dev_random": 1}, 25)]),
    ev("fur_traders", "Pelzhändler aus dem Osten",
       "Eine Karawane bringt Zobel und Hermelin. Die Händler wollen Zollfreiheit für die Rückreise.", "steppe",
       {"produces": "furs"},
       [("Zollfreiheit gewähren.", {"dip": 25, "mods": {"trade": 0.01}}),
        ("Den vollen Zoll verlangen.", {"gold": 40, "dip": -10}),
        ("Die schönsten Pelze für den Hof.", {"prestige": 5, "gold": -20}, 20)]),
    ev("salt_works", "Die Salzsieder wollen mehr Holz",
       "Die Sudpfannen verbrauchen ganze Wälder. Bauern und Förster beschweren sich bei Hofe.", "mine",
       {"produces": "salt", "year_min": 1460},
       [("Das Salz geht vor.", {"gold": 35, "estate": {"adel": -4}}),
        ("Die Wälder schonen.", {"estate": {"adel": 4}, "dip": 10}),
        ("Gradierwerke bauen.", {"gold": -50, "mods": {"production": 0.02}}, 20)]),
    # --- buildings
    ev("annual_fair", "Der große Jahrmarkt",
       "Deine Marktplätze sind weit und breit bekannt. Gaukler, Händler und Taschendiebe strömen herbei.", "tavern",
       {"building": {"marketplace": 3}},
       [("Den Jahrmarkt fördern.", {"mods": {"trade": 0.01}, "adm": -20}),
        ("Marktgebühren erhöhen.", {"gold": 45, "estate": {"buerger": -5}}),
        ("Strenge Marktaufsicht.", {"estate": {"buerger": 3}, "dip": 15}, 20)]),
    ev("manufactory_hands", "Hände für die Manufaktur",
       "Die neue Manufaktur braucht Arbeiter. Der Unternehmer will Bettler und Waisen zwangsverpflichten.", "city",
       {"building": {"manufactory": 1}},
       [("Nur freie Arbeiter.", {"adm": -20, "estate": {"klerus": 3}}),
        ("Die Armenhäuser leeren.", {"mods": {"production": 0.01}, "estate": {"klerus": -6}}),
        ("Handwerker aus der Fremde holen.", {"gold": -40, "dev_capital": 1}, 25)]),
    ev("inventor", "Ein findiger Kopf",
       "Ein Werkstattmeister hat eine Maschine erdacht, die doppelt so schnell spinnt. Die Zunft will sie verbieten.", "scholar",
       {"building": {"workshop": 3}, "year_min": 1480},
       [("Die Zunft hat recht.", {"estate": {"buerger": 5}, "adm": -10}),
        ("Die Erfindung schützen.", {"mods": {"production": 0.02}, "estate": {"buerger": -6}}),
        ("Ihn an den Hof holen.", {"gold": -30, "adm": 40}, 20)]),
    ev("garrison_bored", "Langeweile in der Garnison",
       "In deinen Festungen sitzen die Soldaten seit Jahren herum. Sie trinken, spielen und prügeln sich.", "tavern",
       {"building": {"fortress": 2}, "at_peace": True},
       [("Harter Drill.", {"mil": 25, "estate": {"adel": -3}}),
        ("Sie beim Straßenbau einsetzen.", {"build": "road", "mil": -20}),
        ("Halbe Besatzung, halber Sold.", {"gold": 40, "mods": {"combat": -0.01}}, 15)]),
    ev("famous_trial", "Ein Prozess erregt das Land",
       "Vor deinem Gerichtshof klagt ein Bauer gegen seinen Grundherrn. Alle Welt wartet auf das Urteil.", "court",
       {"building": {"courthouse": 2}},
       [("Recht für den Bauern.", {"estate": {"adel": -6}, "adm": 30}),
        ("Recht für den Herrn.", {"estate": {"adel": 6}, "prestige": -2}),
        ("Einen Vergleich erzwingen.", {"dip": -20, "estate": {"adel": 2}})]),
    ev("drill_master", "Ein Exerziermeister",
       "Ein Veteran aus den Niederlanden bietet an, deine Kasernen nach neuer Art zu führen.", "camp",
       {"building": {"barracks": 3}, "year_min": 1500},
       [("Er soll die Offiziere schulen.", {"mil": 30, "dip": -15}),
        ("Ihn zum Obersten machen.", {"gold": -50, "mods": {"army_power_regen": 0.05}}, 30),
        ("Wir kennen unser Handwerk.", {"prestige": 2, "mil": -10}, 20)]),
    ev("manor_harvest", "Volle Scheunen auf den Gütern",
       "Deine Gutshöfe haben eine Rekordernte eingefahren. Die Gutsherren wollen das Korn ins Ausland verkaufen.", "harvest",
       {"building": {"estate": 3}},
       [("Ausfuhr erlauben.", {"gold": 40, "estate": {"adel": 4}}),
        ("Kornspeicher für Notzeiten.", {"estate": {"adel": -4}, "manpower": 1500}),
        ("Das Korn an die Armee.", {"mil": 30, "estate": {"adel": -2}}, 25)], once=False),
    # --- coast and harbours
    ev("merchants_want_port", "Die Kaufleute wollen einen Hafen",
       "Deine Küste hat keinen richtigen Hafen. Die Kaufleute bieten an, sich an den Kosten zu beteiligen.", "naval",
       {"coastal": True, "no_building": "harbor", "year_min": 1455},
       [("Angenommen: sie zahlen, sie bestimmen mit.", {"build": "harbor", "estate": {"buerger": 5}, "adm": -40}),
        ("Wir bauen selbst, später.", {"prestige": -2, "adm": 15}),
        ("Ihnen das Hafenrecht verkaufen.", {"gold": 50, "mods": {"trade": -0.01}}, 15)]),
    ev("shipwrights", "Schiffbauer aus Holland",
       "Fremde Schiffbauer wollen sich in deinem Hafen niederlassen. Sie bauen schneller und billiger.", "naval",
       {"building": {"harbor": 1}, "year_min": 1480},
       [("Willkommen.", {"mods": {"trade": 0.01}, "estate": {"buerger": -3}}),
        ("Nur, wenn sie unsere Lehrlinge ausbilden.", {"dip": -20, "dev_random": 1}),
        ("Die heimischen Werften schützen.", {"estate": {"buerger": 5}, "prestige": -2})]),
    ev("pirates", "Piraten vor der Küste",
       "Freibeuter kapern Handelsschiffe direkt vor deinem Hafen. Die Reeder verlangen Schutz.", "naval",
       {"building": {"harbor": 1}, "year_min": 1460},
       [("Bewaffnete Konvois.", {"mil": -25, "estate": {"buerger": 4}}),
        ("Lösegeld zahlen.", {"gold": -40, "dip": 10}, 25),
        ("Die Piraten anheuern.", {"prestige": -4, "regs": 1, "dip": -20}, 25)], once=False),
    ev("harbor_fire", "Feuer im Hafen",
       "Ein Lagerhaus mit Teer und Tauwerk ist in Flammen aufgegangen. Das Feuer greift auf die Kais über.", "town_fire",
       {"building": {"harbor": 2}},
       [("Alle Mann zum Löschen.", {"manpower": -800, "adm": 10}),
        ("Wiederaufbau aus der Staatskasse.", {"gold": -50, "estate": {"buerger": 6}}, 30),
        ("Die Reeder sollen zahlen.", {"estate": {"buerger": -8}, "gold": 20}, 20)]),
    # --- roads
    ev("highwaymen", "Wegelagerer auf der Landstraße",
       "Auf deinen neuen Straßen reisen reiche Kaufleute, und das lockt Räuber an.", "border",
       {"building": {"road": 2}},
       [("Reiterpatrouillen.", {"mil": -20, "estate": {"buerger": 4}}),
        ("Die Dörfer haften für Überfälle.", {"estate": {"buerger": 2, "adel": -4}, "adm": 10}),
        ("Kopfgeld aussetzen.", {"gold": -30, "prestige": 2}, 25)], once=False),
    ev("postal_service", "Ein Postdienst",
       "Ein Unternehmer will auf deinen Straßen reitende Boten einsetzen: Briefe in Tagen statt Wochen.", "treaty",
       {"building": {"road": 4}, "year_min": 1490},
       [("Ein Privileg für ihn.", {"dip": -20, "mods": {"trade": 0.01}}),
        ("Eine königliche Post.", {"gold": -50, "adm": 40}, 30),
        ("Wir brauchen keine Post.", {"prestige": -1, "gold": 15}, 15)]),
    ev("mud_roads", "Im Schlamm stecken geblieben",
       "Nach jedem Regen versinken Wagen und Geschütze im Morast. Deine Feldherren fluchen.", "camp",
       {"no_building": "road", "year_min": 1475, "at_peace": True},
       [("Frondienst für den Straßenbau.", {"build": "road", "estate": {"adel": -5}}),
        ("Die Kaufleute sollen pflastern.", {"estate": {"buerger": -5}, "mods": {"trade": -0.01}, "gold": 20}),
        ("Das war schon immer so.", {"mil": -20}, 25)]),
    ev("toll_barons", "Der Adel sperrt die Straßen",
       "Grundherren errichten Schlagbäume auf deinen Straßen und kassieren Wegzoll für sich selbst.", "knights",
       {"building": {"road": 2}, "estate_max": {"adel": 40}},
       [("Die Schlagbäume einreißen.", {"estate": {"adel": -6}, "mods": {"trade": 0.01}}),
        ("Den Zoll teilen.", {"gold": 30, "estate": {"adel": 5}}),
        ("Ein Gericht soll entscheiden.", {"adm": -25, "estate": {"adel": 2}})]),
    # --- loans
    ev("bankers_press", "Die Bankiers drängen",
       "Die Gläubiger der Krone werden ungeduldig. Sie verlangen Sicherheiten für deine Schulden.", "bank",
       {"loans_min": 2},
       [("Zolleinnahmen verpfänden.", {"loan_forgiven": 1, "estate": {"buerger": -6}, "prestige": -3}),
        ("Um Aufschub bitten.", {"prestige": -4, "dip": -20}),
        ("Die Bankiers enteignen.", {"loan_forgiven": 2, "estate": {"buerger": -15}, "prestige": -8}, 15)], once=False),
    ev("debt_crisis", "Der Staatsbankrott droht",
       "Die Zinsen fressen fast alle Einnahmen. Am Hof wird offen über die Zahlungsunfähigkeit gesprochen.", "bank",
       {"loans_min": 4},
       [("Die Schulden umwandeln, die Gläubiger verlieren.", {"loan_forgiven": 2, "prestige": -10, "estate": {"buerger": -10}}),
        ("Die Krone verkauft Ämter.", {"loan_forgiven": 1, "estate": {"adel": 6}, "adm": -40}),
        ("Weitermachen und hoffen.", {"prestige": -3}, 15)], once=False),
    ev("merchant_lender", "Ein Kaufmann bietet Geld",
       "Die Kasse ist leer. Ein reicher Kaufmann bietet einen Kredit an, will aber einen Sitz im Rat.", "bank",
       {"gold_max": 0, "loans_max": 1, "year_min": 1450},
       [("Annehmen.", {"loan": 1, "estate": {"buerger": 5, "adel": -5}}),
        ("Der Adel soll aushelfen.", {"gold": 40, "estate": {"adel": -8}}),
        ("Wir kommen zurecht.", {"prestige": 2, "adm": -15}, 20)], once=False),
    ev("burghers_buy_debt", "Die Bürger übernehmen die Schulden",
       "Die reichen Städte bieten an, einen Kredit der Krone abzulösen. Dafür wollen sie Mitsprache bei den Steuern.", "diet",
       {"loans_min": 1, "estate_min": {"buerger": 60}},
       [("Einverstanden.", {"loan_forgiven": 1, "estate": {"buerger": -10}}),
        ("Nur gegen ein Handelsprivileg.", {"loan_forgiven": 1, "mods": {"tax": -0.02}}),
        ("Die Krone braucht keine Vormünder.", {"prestige": 3, "estate": {"buerger": -3}}, 20)]),
    # --- mercenaries
    ev("merc_mutiny", "Die Söldner meutern",
       "Deine Söldner wollen mehr Geld, sonst laufen sie zum Feind über. Ihr Hauptmann stellt ein Ultimatum.", "camp",
       {"mercs_recent": 18, "at_war": True},
       [("Mit Beute vertrösten.", {"we": 2, "army_power": -0.1}),
        ("Zahlen.", {"gold": -50, "army_power": 0.1}, 30),
        ("Den Hauptmann hängen.", {"regs": -1, "prestige": 3, "mil": -20}, 20)], once=False),
    ev("merc_plunder", "Söldner auf dem Heimweg",
       "Die abgedankten Söldner ziehen plündernd durch deine Dörfer. Die Bauern verstecken sich in den Wäldern.", "famine",
       {"mercs_recent": 36, "at_peace": True},
       [("Die Miliz aufbieten.", {"mil": -25, "manpower": -500}),
        ("Sie mit Gold aus dem Land schaffen.", {"gold": -35, "estate": {"adel": 3}}, 30),
        ("Sie bleiben, als Siedler.", {"dev_random": -1, "manpower": 1500}, 25)], once=False),
    ev("merc_band", "Ein Haufen Landsknechte",
       "Ein Werber meldet: eine ganze Kompanie Landsknechte sucht gerade einen Kriegsherrn.", "camp",
       {"at_war": True, "year_min": 1470},
       [("Sie sollen warten, bis wir rufen.", {"merc_ready": True, "dip": -10}),
        ("Sie dem Feind wegschnappen.", {"merc_ready": True, "gold": -25, "army_power": 0.05}, 25),
        ("Wir kämpfen mit eigenen Leuten.", {"mil": 20, "prestige": 1}, 25)], once=False),
    # --- morale
    ev("worn_out", "Die Truppen sind erschöpft",
       "Nach den letzten Kämpfen schleppen sich deine Soldaten nur noch dahin. Die Hauptleute melden Fahnenflucht.", "battle",
       {"morale_max": 0.45, "at_war": True},
       [("Eine flammende Rede.", {"army_power": 0.15, "mil": -15}),
        ("Doppelter Sold.", {"gold": -45, "army_power": 0.3}, 30),
        ("Die Fahnenflüchtigen hängen.", {"army_power": 0.1, "manpower": -600, "prestige": -2}, 20)], once=False),
    ev("field_preachers", "Feldprediger im Lager",
       "Mönche ziehen mit dem Heer und predigen vom gerechten Krieg. Die Männer hören ihnen zu.", "procession",
       {"morale_max": 0.6, "at_war": True, "estate_min": {"klerus": 55}},
       [("Sie sollen predigen.", {"army_power": 0.15, "estate": {"klerus": -3}}),
        ("Lieber Wein als Worte.", {"gold": -25, "army_power": 0.2}, 25),
        ("Zurück in die Klöster.", {"estate": {"klerus": -5}, "mil": 15}, 15)], once=False),
    # --- budget sliders
    ev("lavish_feast", "Ein rauschendes Fest",
       "Dein verschwenderischer Hof gibt ein Fest, von dem man noch in Jahren sprechen wird.", "wedding",
       {"budget_min": {"hof": 3}},
       [("Gesandte aus ganz Europa einladen.", {"dip": 30, "estate": {"buerger": -4}}),
        ("Das Volk darf mitfeiern.", {"gold": -30, "estate": {"buerger": 6}}, 25),
        ("Gold verteilen, damit sie es nicht vergessen.", {"gold": -50, "prestige": 6}, 20)], once=False),
    ev("stingy_court", "Der Hof friert",
       "Am Hof gibt es dünne Suppe und kalte Kamine. Fremde Gesandte spotten über deine Knauserei.", "court",
       {"budget_max": {"hof": 1}, "year_min": 1450},
       [("Sparsamkeit ist eine Tugend.", {"prestige": -3, "adm": 15}),
        ("Wenigstens die Gesandten bewirten.", {"gold": -25, "dip": 20}),
        ("Die Spötter ausweisen.", {"dip": -25, "estate": {"adel": -3}}, 20)], once=False),
    ev("tax_revolt", "Die Bauern verweigern die Steuer",
       "Deine Steuereintreiber werden mit Dreschflegeln aus den Dörfern gejagt.", "revolt",
       {"budget_min": {"steuern": 3}, "year_min": 1450},
       [("Soldaten schicken.", {"mil": -25, "estate": {"buerger": -4}}),
        ("Ein Jahr Steuererlass für die Dörfer.", {"gold": -40, "estate": {"buerger": 6}}, 30),
        ("Die Rädelsführer verhandeln lassen.", {"adm": -25, "dev_random": -1}, 20)], once=False),
    ev("mild_tax_blessing", "Die Bauern danken",
       "Deine milden Steuern haben sich herumgesprochen. Siedler aus den Nachbarländern ziehen zu dir.", "harvest",
       {"budget_max": {"steuern": 1}, "at_peace": True},
       [("Sie sollen das Ödland roden.", {"dev_random": 1, "estate": {"adel": -3}}),
        ("Sie in die Städte holen.", {"estate": {"buerger": 4}, "manpower": 1000}),
        ("Mehr Leute, mehr Steuern.", {"gold": 30, "prestige": -1}, 20)]),
    ev("rusty_armor", "Verrostete Rüstungen",
       "Bei der Musterung zeigen sich die Folgen des knappen Militärbudgets: stumpfe Klingen, rostige Harnische.", "camp",
       {"budget_max": {"heer": 1}, "year_min": 1450},
       [("Es muss reichen.", {"army_power": -0.15, "mil": 10}),
        ("Eine Sonderzahlung für die Zeughäuser.", {"gold": -40, "mil": 20}, 30),
        ("Die Bauern sollen eigene Waffen tragen.", {"estate": {"adel": -4}, "manpower": 1000}, 25)], once=False),
    ev("war_footing", "Die Waffenschmieden glühen",
       "Das Heer bekommt alles, was es verlangt. Die Schmiede arbeiten Tag und Nacht, das Eisen wird knapp.", "artillery",
       {"budget_min": {"heer": 3}, "at_war": True},
       [("Sie sollen weiterarbeiten.", {"army_power": 0.1, "estate": {"buerger": -3}}),
        ("Eisen aus dem Ausland kaufen.", {"gold": -35, "mods": {"combat": 0.01}}, 25),
        ("Neue Rekruten ausrüsten.", {"manpower": 1500, "mil": -15}, 25)], once=False),
    ev("academies", "Gelehrte aus aller Welt",
       "Deine Akademien sind berühmt. Gelehrte aus ganz Europa wollen bei dir forschen und lehren.", "scholar",
       {"budget_min": {"bildung": 3}},
       [("Sie sind willkommen.", {"adm": 30, "estate": {"klerus": -4}}),
        ("Nur rechtgläubige Gelehrte.", {"estate": {"klerus": 5}, "dip": 15}),
        ("Eine Hofbibliothek stiften.", {"gold": -50, "prestige": 5}, 20)]),
    ev("university_closes", "Die Universität schließt",
       "Ohne Geld laufen die Professoren davon. Die letzten Studenten ziehen in andere Länder.", "scholar",
       {"budget_max": {"bildung": 1}, "year_min": 1460},
       [("Dann eben ohne Gelehrte.", {"adm": -20, "estate": {"klerus": -3}}),
        ("Die Kirche soll die Lehrer bezahlen.", {"estate": {"klerus": -6}, "adm": 10}),
        ("Eine einmalige Spende.", {"gold": -40, "adm": 30}, 25)]),
]

# Two economic missions per playable nation; the second follows the first.
MISSIONS = {
    "FRA": [
        ("fra_eco_roads", None, "Die Straßen des Königs", "Ein Netz gepflasterter Straßen verbindet Paris mit den Provinzen.",
         {"building": {"road": 4}}, {"adm": 40, "mods": {"army_power_regen": 0.1}}),
        ("fra_eco_wine", "fra_eco_roads", "Der Wein Frankreichs", "Ganz Europa trinkt französischen Wein und zahlt dafür.",
         {"goods_leader": "wine"}, {"prestige": 10, "mods": {"trade": 0.03}}),
    ],
    "ENG": [
        ("eng_eco_cloth", None, "Tuch statt Wolle", "Verarbeite die englische Wolle selbst, statt sie nach Flandern zu verkaufen.",
         {"building": {"workshop": 3, "manufactory": 1}}, {"adm": 40, "mods": {"production": 0.03}}),
        ("eng_eco_ports", "eng_eco_cloth", "Häfen für den Handel", "Starke Häfen machen England zur Handelsmacht.",
         {"building": {"harbor": 4}}, {"dip": 40, "mods": {"trade": 0.03}}),
    ],
    "SPA": [
        ("spa_eco_mesta", None, "Die Mesta", "Die großen Schafherden der Mesta brauchen Weiden und Gutshöfe.",
         {"building": {"estate": 3}}, {"gold": 80, "mods": {"production": 0.02}}),
        ("spa_eco_sevilla", "spa_eco_mesta", "Die Flotte von Sevilla", "Sevilla soll zum großen Hafen des Reiches werden.",
         {"building": {"harbor": 3, "marketplace": 2}}, {"dip": 50, "mods": {"trade": 0.03}}),
    ],
    "BOH": [
        ("boh_eco_silver", None, "Das Silber von Kuttenberg", "Böhmisches Silber soll die Münzen Europas füllen.",
         {"goods_leader": "silver"}, {"gold": 150, "prestige": 5}),
        ("boh_eco_markets", "boh_eco_silver", "Die Märkte von Prag", "Prag als Handelsplatz zwischen Ost und West.",
         {"building": {"marketplace": 3}}, {"dip": 40, "mods": {"trade": 0.03}}),
    ],
    "HAB": [
        ("hab_eco_iron", None, "Der steirische Erzberg", "Eisen aus der Steiermark für Werkstätten und Waffen.",
         {"produces": "iron", "building": {"workshop": 2}}, {"mil": 40, "mods": {"production": 0.02}}),
        ("hab_eco_alps", "hab_eco_iron", "Straßen über die Alpen", "Gute Straßen halten die verstreuten Erblande zusammen.",
         {"building": {"road": 3}}, {"adm": 40, "mods": {"army_power_regen": 0.1}}),
    ],
    "RUS": [
        ("rus_eco_furs", None, "Der Pelzhandel", "Zobel und Hermelin aus den Wäldern des Nordens für ganz Europa.",
         {"goods_leader": "furs"}, {"gold": 100, "mods": {"trade": 0.03}}),
        ("rus_eco_roads", "rus_eco_furs", "Wege durch die Weite", "Ohne Straßen bleibt das Reich ein Flickenteppich.",
         {"building": {"road": 4}}, {"adm": 50, "mods": {"army_power_regen": 0.15}}),
    ],
    "NAP": [
        ("nap_eco_port", None, "Der Hafen von Neapel", "Neapel soll das Tor zum östlichen Mittelmeer sein.",
         {"building": {"harbor": 3}}, {"dip": 40, "mods": {"trade": 0.03}}),
        ("nap_eco_silk", "nap_eco_port", "Seidenmanufaktur", "Neapolitanische Seide für die Höfe Europas.",
         {"building": {"manufactory": 1, "workshop": 2}}, {"adm": 40, "mods": {"production": 0.03}}),
    ],
    "TUR": [
        ("tur_eco_arsenal", None, "Das Arsenal", "Werften und Kasernen für ein Weltreich.",
         {"building": {"harbor": 2, "barracks": 2}}, {"mil": 50, "mods": {"combat": 0.03}}),
        ("tur_eco_bazaar", "tur_eco_arsenal", "Der Große Basar", "Konstantinopel, Markt zwischen Orient und Okzident.",
         {"building": {"marketplace": 3}, "trade_pacts_min": 1}, {"dip": 40, "mods": {"trade": 0.03}}),
    ],
    "POL": [
        ("pol_eco_grain", None, "Kornkammer Europas", "Polnisches Getreide ernährt die Städte des Westens.",
         {"goods_leader": "grain"}, {"gold": 100, "mods": {"income": 0.03}}),
        ("pol_eco_vistula", "pol_eco_grain", "Die Weichselstraße", "Ein Handelsweg vom Landesinneren bis zur Ostsee.",
         {"building": {"road": 3}, "trade_pacts_min": 1}, {"dip": 40, "mods": {"trade": 0.03}}),
    ],
    "BUR": [
        ("bur_eco_cloth", None, "Flandrische Tuche", "Die Tuchmacher Flanderns sollen die besten Europas bleiben.",
         {"building": {"manufactory": 2}}, {"adm": 40, "mods": {"production": 0.03}}),
        ("bur_eco_bruges", "bur_eco_cloth", "Die Messen von Brügge", "Brügge als Treffpunkt der Kaufleute aus Nord und Süd.",
         {"building": {"marketplace": 4}, "trade_pacts_min": 2}, {"dip": 50, "prestige": 10, "mods": {"trade": 0.03}}),
    ],
}


def render_event(e):
    head = {k: e[k] for k in ("id", "once", "tag", "title", "text", "image") if k in e}
    s = "  " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    s += '   "trigger": ' + json.dumps(e["trigger"], ensure_ascii=False) + ",\n"
    s += '   "options": [\n'
    s += ",\n".join("     " + json.dumps(o, ensure_ascii=False) for o in e["options"])
    return s + "]}"


def render_mission(m):
    head = {k: m[k] for k in ("id", "after", "title", "desc") if k in m}
    s = "    " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    return s + '     "require": ' + json.dumps(m["require"], ensure_ascii=False) + ', "reward": ' + json.dumps(m["reward"], ensure_ascii=False) + "}"


def check(e):
    assert len(e["options"]) == 3, e["id"]
    first = e["options"][0]["effects"]
    assert first.get("gold", 0) >= 0, e["id"] + ": AI-favoured first option must not cost gold"
    if not e.get("once", True):
        assert "mods" not in first, e["id"] + ": repeatable first option must not give permanent mods"
    for o in e["options"]:
        for k, v in o["effects"].get("mods", {}).items():
            # morale regen runs on a larger scale (budget step = 0.25)
            assert abs(v) <= (0.05 if k == "army_power_regen" else 0.03), e["id"]


def main():
    path = os.path.join(ROOT, "data/events.json")
    txt = open(path, encoding="utf-8").read().rstrip()
    assert txt.endswith("]")
    for e in EVENTS:
        check(e)
    # drop the old eco_ block, then insert the current one right before the gov_ block (or at the end)
    a = txt.find('  {"id": "eco_')
    gov = txt.find('  {"id": "gov_')
    if a >= 0:
        txt = txt[:a] + (txt[gov:] if gov >= 0 else "]")
        gov = txt.find('  {"id": "gov_')
    block = ",\n".join(render_event(e) for e in EVENTS)
    if gov >= 0:
        txt = txt[:gov] + block + ",\n" + txt[gov:]
    else:
        txt = txt[:-1].rstrip().rstrip(",") + ",\n" + block + "\n]"
    events = json.loads(txt)
    assert len({e["id"] for e in events}) == len(events)
    open(path, "w", encoding="utf-8").write(txt.rstrip() + "\n")

    path = os.path.join(ROOT, "data/missions.json")
    data = json.load(open(path, encoding="utf-8"))
    for tag, ms in MISSIONS.items():
        keep = [m for m in data.setdefault(tag, []) if "_eco_" not in m["id"]]
        new = []
        for (id, after, title, desc, req, rew) in ms:
            m = {"id": id}
            if after:
                m["after"] = after
            m.update({"title": title, "desc": desc, "require": req, "reward": rew})
            new.append(m)
        data[tag] = keep + new
    out = "{\n" + ",\n".join(
        '  "%s": [\n' % tag + ",\n".join(render_mission(m) for m in ms) + "\n  ]" for tag, ms in data.items()) + "\n}\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)
    print("events %d (eco %d), missions %s" % (len(events), len(EVENTS), {t: len(v) for t, v in data.items()}))


if __name__ == "__main__":
    main()
