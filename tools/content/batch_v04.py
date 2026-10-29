"""Content batch: events (great powers + generic + minor-only) and missions 7-10.
Appended to data/events.json and data/missions.json in the repo's one-line-per-option layout."""
import json
import sys

def O(text, effects, ai=None):
    o = {"text": text, "effects": effects}
    if ai is not None:
        o["ai"] = ai
    return o

def E(id, tag, title, text, trigger, options, once=True):
    e = {"id": id}
    if not once:
        e["once"] = False
    e.update({"tag": tag, "title": title, "text": text, "trigger": trigger, "options": options})
    return e

EVENTS = [
# ------------------------------------------------------------------ France
E("fra_jacques_coeur", "FRA", "Der Fall Jacques Cœur", "Der Schatzmeister des Königs ist reicher als die Krone selbst. Neider werfen ihm Giftmord und Betrug vor.",
  {"year_min": 1450, "year_max": 1460},
  [O("Sein Vermögen beschlagnahmen.", {"gold": 120, "dip": -20, "prestige": -5}, 60),
   O("Ihn schützen, er finanziert unsere Feldzüge.", {"mods": {"income": 0.02}, "adm": -25}),
   O("Ihn ins Exil schicken, die Geschäfte übernehmen.", {"gold": 50, "adm": 20})]),
E("fra_marignano", "FRA", "Marignano", "Der junge König Franz I. will Mailand. Die Schweizer Söldner stehen zwischen ihm und der Lombardei.",
  {"year_min": 1510, "year_max": 1530, "at_peace": True},
  [O("Über die Alpen! Mailand gehört uns.", {"claim": ["milan", "parma"], "mil": 30, "relations": {"SWI": -30}, "flag": "fra_italian_adventure"}, 50),
   O("Ewiger Friede mit den Eidgenossen.", {"relations": {"SWI": 50}, "dip": 30, "gold": -40}),
   O("Die Kassen füllen statt Krieg führen.", {"gold": 80})]),
E("fra_pavia", "FRA", "Alles verloren außer der Ehre", "Bei Pavia ist das französische Heer vernichtet, der König gefangen. Der Kaiser verlangt ein gewaltiges Lösegeld.",
  {"year_min": 1520, "year_max": 1545, "flag": "fra_italian_adventure"},
  [O("Das Lösegeld zahlen.", {"gold": -150, "prestige": -5}, 40),
   O("Die Ansprüche in Italien aufgeben.", {"prestige": -15, "adm": 40}, 30),
   O("Ein unerhörtes Bündnis: mit dem Sultan gegen den Kaiser.", {"alliance": "TUR", "prestige": -10, "relations": {"PAP": -40, "HAB": -40}, "flag": "fra_turk_alliance"}, 30)]),
E("fra_capitulations", "FRA", "Die Kapitulationen", "Der Sultan gewährt französischen Kaufleuten Handelsrechte in der Levante. Die Christenheit ist empört.",
  {"year_min": 1530, "year_max": 1600, "flag": "fra_turk_alliance", "alive": "TUR"},
  [O("Den Handel annehmen.", {"mods": {"income": 0.03}, "relations": {"TUR": 30}}, 60),
   O("Gemeinsame Flotte gegen Habsburg.", {"mil": 40, "relations": {"TUR": 40, "HAB": -30, "SPA": -30}}),
   O("Auf Abstand gehen, um den Papst zu beruhigen.", {"relations": {"PAP": 40, "TUR": -30}, "prestige": 5})]),
E("fra_cloth_of_gold", "FRA", "Das Güldene Feld", "Bei Calais treffen sich zwei Könige in Zelten aus Goldbrokat. Ein Bündnis liegt in der Luft, oder nur Prunk?",
  {"year_min": 1515, "year_max": 1530, "alive": "ENG", "at_peace": True},
  [O("Prunk ohne Grenzen.", {"gold": -80, "prestige": 15, "relations": {"ENG": 40}}, 50),
   O("Ein Bündnis mit England schmieden.", {"alliance": "ENG", "dip": -30}, 30),
   O("Nur ein höflicher Besuch.", {"dip": 20})]),
E("fra_concordat", "FRA", "Das Konkordat von Bologna", "Der Papst bietet an: Der König ernennt die Bischöfe, Rom erhält die Abgaben.",
  {"year_min": 1510, "year_max": 1540},
  [O("Unterzeichnen.", {"adm": 40, "relations": {"PAP": 40}}, 60),
   O("Die gallikanischen Freiheiten verteidigen.", {"prestige": 10, "relations": {"PAP": -30}}),
   O("Mehr verlangen.", {"gold": 60, "dip": -20})]),
E("fra_new_france", "FRA", "Neufrankreich", "Cartier ist den Sankt-Lorenz-Strom hinaufgesegelt. Pelze und Fischgründe locken.",
  {"year_min": 1534, "year_max": 1620},
  [O("Siedler schicken.", {"gold": -60, "mods": {"income": 0.03}, "prestige": 5}, 50),
   O("Nur Pelzhandel.", {"gold": 50}),
   O("Europa geht vor.", {"mil": 30})]),
E("fra_paulette", "FRA", "Die Paulette", "Ämter sollen gegen eine jährliche Gebühr erblich werden. Der Schatz würde sich füllen, der Adel der Robe erstarken.",
  {"year_min": 1600},
  [O("Ämter verkaufen.", {"gold": 130, "adm": -30}, 60),
   O("Nur für die Provinzen.", {"gold": 60}),
   O("Ein Amt ist kein Erbgut.", {"adm": 40, "prestige": -5})]),

# ------------------------------------------------------------------ England
E("eng_cade", "ENG", "Jack Cades Aufstand", "Kentische Bauern ziehen unter Jack Cade gegen London und klagen über korrupte Berater des Königs.",
  {"year_min": 1450, "year_max": 1456},
  [O("Den Aufstand niederschlagen.", {"mil": -30, "manpower": -2, "prestige": 5}, 50),
   O("Die verhassten Berater opfern.", {"adm": -30, "dip": 20}),
   O("Begnadigung für alle.", {"gold": -40, "prestige": -5, "dev_random": 1})]),
E("eng_cabot", "ENG", "John Cabot", "Ein venezianischer Seefahrer will im Auftrag der Krone einen Westweg nach Asien suchen.",
  {"year_min": 1490, "year_max": 1510},
  [O("Ein Schiff aus Bristol ausrüsten.", {"gold": -40, "prestige": 5, "flag": "eng_atlantic"}, 60),
   O("Die Kaufleute sollen zahlen.", {"dip": -20, "flag": "eng_atlantic"}),
   O("Fantasterei.", {"gold": 20})]),
E("eng_bloody_mary", "ENG", "Die katholische Königin", "Maria I. will England zum alten Glauben zurückführen und Philipp von Spanien heiraten.",
  {"year_min": 1550, "year_max": 1565, "alive": "SPA"},
  [O("Die spanische Heirat.", {"relations": {"SPA": 50, "FRA": -30}, "prestige": -5, "dip": 30}, 40),
   O("Ketzer verbrennen.", {"relations": {"PAP": 40}, "dev_random": -2, "mil": 30}),
   O("Ein maßvoller Kurs.", {"adm": 40})]),
E("eng_drake", "ENG", "Seebären", "Francis Drake kehrt von einer Weltumsegelung zurück, die Laderäume voll spanischem Silber.",
  {"year_min": 1565, "year_max": 1595, "alive": "SPA"},
  [O("Die Beute teilen und ihn zum Ritter schlagen.", {"gold": 150, "relations": {"SPA": -60}, "flag": "eng_sea_dogs"}, 60),
   O("Kaperbriefe für alle!", {"gold": 60, "mods": {"combat": 0.02}, "relations": {"SPA": -40}, "flag": "eng_sea_dogs"}),
   O("Das Silber zurückgeben.", {"relations": {"SPA": 40}, "prestige": -10, "dip": 30})]),
E("eng_armada", "ENG", "Die Armada", "Philipp II. schickt die größte Flotte, die Europa je gesehen hat. Ziel: England.",
  {"year_min": 1580, "year_max": 1610, "flag": "eng_sea_dogs", "alive": "SPA"},
  [O("Brander in die Nacht!", {"prestige": 20, "gold": -60, "mods": {"combat": 0.03}}, 60),
   O("Die Küsten mit der Miliz halten.", {"manpower": -3, "mil": 40, "regs": 3}),
   O("Frieden um jeden Preis.", {"relations": {"SPA": 50}, "prestige": -15, "gold": -40})]),
E("eng_east_india", "ENG", "Die Ostindien-Kompanie", "Londoner Kaufleute bitten um ein königliches Monopol für den Handel östlich des Kaps der Guten Hoffnung.",
  {"year_min": 1595, "flag": "eng_atlantic"},
  [O("Den Freibrief gewähren.", {"gold": -80, "mods": {"income": 0.04}}, 60),
   O("Das Monopol versteigern.", {"gold": 120}),
   O("Der Handel bleibt frei.", {"dip": 40, "prestige": 5})]),
E("eng_gunpowder", "ENG", "Die Pulververschwörung", "Im Keller unter dem Parlament wird Guy Fawkes mit 36 Fässern Schießpulver gefasst.",
  {"year_min": 1600, "year_max": 1620},
  [O("Ein Exempel statuieren.", {"prestige": 10, "relations": {"PAP": -30}}, 50),
   O("Den Treueeid für alle Untertanen.", {"adm": 40}),
   O("Ein Dankfest für das Volk.", {"gold": -30, "prestige": 15})]),

# ------------------------------------------------------------------ Spain
E("spa_alhambra", "SPA", "Das Alhambra-Edikt", "Nach dem Fall Granadas drängt die Inquisition auf die Vertreibung aller, die nicht getauft sind.",
  {"year_min": 1490, "year_max": 1510, "owns": ["granada"]},
  [O("Vertreiben und ihr Vermögen einziehen.", {"gold": 100, "dev_random": -3, "prestige": 5}, 50),
   O("Taufe oder Steuer.", {"gold": 40, "adm": -20}),
   O("Toleranz wie unter den Kalifen.", {"dev_random": 1, "relations": {"PAP": -30}, "prestige": -5})]),
E("spa_magellan", "SPA", "Um die Welt", "Von fünf Schiffen kehrt eines zurück: die Victoria, nach drei Jahren, einmal um die Welt.",
  {"year_min": 1519, "year_max": 1540, "flag": "ev_spa_columbus"},
  [O("Ruhm für Kastilien!", {"prestige": 20}, 50),
   O("Die Gewürzinseln beanspruchen.", {"gold": 80, "relations": {"POR": -40}}),
   O("Die Seekarten vermessen lassen.", {"dip": 50})]),
E("spa_bankruptcy", "SPA", "Bancarrota", "Das Silber kommt, aber die Kriege kosten mehr. Die genuesischen Bankiers wollen ihr Geld.",
  {"year_min": 1555, "year_max": 1630, "flag": "ev_spa_silver"},
  [O("Den Staatsbankrott erklären.", {"gold": 150, "prestige": -15, "relations": {"GEN": -50}}, 40),
   O("Neue Kredite aus Genua.", {"gold": 80, "mods": {"income": -0.02}, "relations": {"GEN": 30}}),
   O("Das Heer verkleinern.", {"mil": -40, "manpower": -3, "adm": 40})]),
E("spa_lepanto", "SPA", "Die Heilige Liga", "Papst und Venedig rufen zur Seeschlacht gegen die Osmanen. Don Juan de Austria soll die Flotte führen.",
  {"year_min": 1565, "year_max": 1580, "alive": "TUR"},
  [O("Die Galeeren in See stechen lassen.", {"mil": -40, "prestige": 20, "relations": {"PAP": 40, "VEN": 40, "TUR": -50}}, 60),
   O("Nur Gold schicken.", {"gold": -60, "relations": {"PAP": 30}}),
   O("Die Flandern-Front geht vor.", {"mil": 30, "prestige": -5})]),
E("spa_moriscos", "SPA", "Die Morisken", "Die Nachfahren der Mauren gelten als unzuverlässig. Der Hof diskutiert ihre Vertreibung.",
  {"year_min": 1600, "year_max": 1625, "owns_any": ["granada", "valencia"]},
  [O("Die Vertreibung anordnen.", {"dev_random": -3, "prestige": 5, "mil": 30}, 40),
   O("Sie bleiben, sie zahlen Steuern.", {"gold": 60, "relations": {"PAP": -20}}),
   O("Assimilation durch Schulen.", {"adm": -30, "dev_random": 1})]),
E("spa_olivares", "SPA", "Die Waffenunion", "Der Graf-Herzog Olivares will, dass alle Reiche der Krone Truppen stellen, nicht nur Kastilien.",
  {"year_min": 1618},
  [O("Die Union erzwingen.", {"mods": {"manpower": 0.05}, "dev_random": -2, "prestige": -5}, 50),
   O("Nur freiwillige Beiträge.", {"manpower": 3}),
   O("Olivares entlassen.", {"adm": 40, "prestige": -5})]),

# ------------------------------------------------------------------ Bohemia
E("boh_wagenburg", "BOH", "Die Wagenburg", "Die Hussiten haben gezeigt, was Bauern hinter Kriegswagen und Hakenbüchsen leisten können.",
  {"year_max": 1470},
  [O("Die Taktik weiterführen.", {"mods": {"combat": 0.03}, "mil": -20}, 60),
   O("Die Veteranen ins Heer holen.", {"regs": 3, "gold": -30}),
   O("Die Waffen ruhen lassen.", {"adm": 40})]),
E("boh_ladislaus", "BOH", "Ladislaus Postumus", "Der junge König lebt in Wien, Georg von Podiebrad regiert als Landesverweser. Wem gehört Böhmen?",
  {"year_max": 1460},
  [O("Podiebrad soll regieren.", {"ruler": {"adm": 1}, "relations": {"HAB": -20}}, 50),
   O("Den König aus Wien holen.", {"relations": {"HAB": 40}, "prestige": 5}),
   O("Die Stände entscheiden.", {"dip": 40})]),
E("boh_brethren", "BOH", "Die Brüdergemeine", "Eine stille Glaubensgemeinschaft lehnt Waffen und Eide ab und gründet Schulen.",
  {"year_min": 1460, "year_max": 1530},
  [O("Gewähren lassen.", {"adm": 30, "dev_random": 1}, 50),
   O("Verfolgen.", {"prestige": 5, "relations": {"PAP": 20}, "dev_random": -1}),
   O("Ihre Druckereien nutzen.", {"dip": 30, "gold": -20})]),
E("boh_land_ordinance", "BOH", "Die Wladislawsche Landesordnung", "Die Herren verlangen, dass nur Adlige im Landtag sitzen. Die Städte protestieren.",
  {"year_min": 1495, "year_max": 1530},
  [O("Den Adel stärken.", {"mil": 40, "manpower": 2, "adm": -20}, 50),
   O("Den Städten ihre Rechte sichern.", {"gold": 60, "mods": {"income": 0.02}, "mil": -30}),
   O("Ein Kompromiss nach Jahren.", {"dip": 30})]),
E("boh_winter_king", "BOH", "Der Winterkönig", "Die aufständischen Stände wählen Friedrich von der Pfalz zum König. Der Kaiser rüstet.",
  {"year_min": 1615, "year_max": 1635, "flag": "ev_boh_defenestration"},
  [O("Friedrich krönen, Bündnis mit der Pfalz.", {"alliance": "PAL", "regs": 3, "relations": {"HAB": -40}, "flag": "boh_revolt"}, 50),
   O("Sich dem Kaiser unterwerfen.", {"relations": {"HAB": 60}, "prestige": -15, "adm": 40}),
   O("Söldner unter Mansfeld anwerben.", {"gold": -80, "regs": 4, "flag": "boh_revolt"})]),
E("boh_white_mountain", "BOH", "Am Weißen Berg", "Das kaiserliche Heer steht vor Prag. Eine Schlacht entscheidet über das Königreich.",
  {"year_min": 1618, "year_max": 1640, "flag": "boh_revolt"},
  [O("Bis zum letzten Mann!", {"mil": 50, "manpower": -3, "prestige": 10}, 40),
   O("Prag befestigen.", {"gold": -60, "manpower": 3, "dev_capital": 1}, 40),
   O("Comenius und die Gelehrten in Sicherheit bringen.", {"adm": 40, "prestige": -5}, 20)]),

# ------------------------------------------------------------------ Austria
E("hab_aeiou", "HAB", "A.E.I.O.U.", "Friedrich III. lässt fünf Vokale in jede Mauer meißeln. Austria erit in orbe ultima?",
  {"year_max": 1470},
  [O("Österreich wird ewig bestehen!", {"prestige": 10}, 50),
   O("Alles Erdreich ist Österreich untertan.", {"claim": ["munich", "pressburg"], "dip": -30}),
   O("Lieber Steuern als Sprüche.", {"gold": 50})]),
E("hab_landsknechte", "HAB", "Die Landsknechte", "Maximilian will ein Fußvolk nach Schweizer Art, aber unter kaiserlicher Fahne.",
  {"year_min": 1480, "year_max": 1520},
  [O("Landsknechte anwerben.", {"regs": 4, "gold": -70, "flag": "hab_landsknechte"}, 60),
   O("Die Reichsritter reformieren.", {"mil": 40}),
   O("Schweizer mieten ist billiger.", {"gold": -30, "relations": {"SWI": 30}})]),
E("hab_frundsberg", "HAB", "Der Vater der Landsknechte", "Georg von Frundsberg hat die Landsknechte zu einer gefürchteten Truppe gemacht. Er verlangt Sold und Ehre.",
  {"year_min": 1500, "year_max": 1530, "flag": "hab_landsknechte"},
  [O("Ehre, wem Ehre gebührt.", {"mods": {"combat": 0.03}, "gold": -50}, 60),
   O("Der Sold muss reichen.", {"mil": 30}),
   O("Die Haufen entlassen.", {"gold": 60, "manpower": 2})]),
E("hab_augsburg", "HAB", "Der Reichstag zu Augsburg", "Cuius regio, eius religio: Jeder Fürst bestimmt den Glauben seines Landes.",
  {"year_min": 1550, "year_max": 1565},
  [O("Den Frieden schließen.", {"dip": 40, "prestige": 5}, 60),
   O("Die Einheit des Glaubens erzwingen.", {"relations": {"PAP": 40, "SAX": -40, "PAL": -40}, "mil": 30}),
   O("Die Entscheidung vertagen.", {"adm": 30})]),
E("hab_counter_reformation", "HAB", "Ferdinands Schwur", "Ferdinand von der Steiermark schwört, lieber über eine Wüste als über Ketzer zu herrschen.",
  {"year_min": 1595, "year_max": 1630},
  [O("Jesuiten an die Universitäten.", {"adm": 40, "relations": {"PAP": 40, "BOH": -30}, "flag": "hab_catholic_league"}, 60),
   O("Härte gegen die Stände.", {"mil": 40, "dev_random": -2, "flag": "hab_catholic_league"}),
   O("Den Majestätsbrief achten.", {"dip": 40, "relations": {"BOH": 30}})]),
E("hab_wallenstein", "HAB", "Wallenstein", "Ein böhmischer Edelmann bietet an, ein Heer auf eigene Kosten aufzustellen. Der Krieg soll den Krieg ernähren.",
  {"year_min": 1618, "year_max": 1640, "flag": "hab_catholic_league"},
  [O("Ihn zum Generalissimus ernennen.", {"regs": 5, "gold": 40, "flag": "hab_wallenstein"}, 60),
   O("Ein kleineres Kommando.", {"regs": 2, "gold": -30}),
   O("Einem Kriegsunternehmer trauen wir nicht.", {"prestige": 5})]),
E("hab_eger", "HAB", "Mord in Eger", "Wallenstein verhandelt heimlich mit den Schweden. Seine Offiziere warten nur auf ein Wort aus Wien.",
  {"year_min": 1625, "flag": "hab_wallenstein"},
  [O("Das Wort geben.", {"prestige": -5, "mil": 40, "gold": 60}, 50),
   O("Ihn absetzen, das Heer übernehmen.", {"adm": -30, "mods": {"combat": 0.02}}),
   O("Ihm weiter vertrauen.", {"regs": 3, "prestige": -10})]),

# ------------------------------------------------------------------ Russia
E("rus_sophia", "RUS", "Die Nichte des letzten Kaisers", "Sophia Palaiologa, Erbin Konstantinopels, soll Iwan III. heiraten. Mit ihr kommen der Doppeladler und italienische Baumeister.",
  {"year_min": 1465, "year_max": 1485},
  [O("Die Hochzeit feiern.", {"prestige": 15, "dip": 20}, 50),
   O("Italienische Baumeister für den Kreml.", {"dev_capital": 2, "gold": -60}),
   O("Byzantinisches Hofzeremoniell.", {"adm": 40, "ruler": {"dip": 1}, "dip": -40})]),
E("rus_streltsy", "RUS", "Die Strelizen", "Der Zar will eine stehende Truppe mit Feuerwaffen, bezahlt aus der Staatskasse.",
  {"year_min": 1540, "year_max": 1570},
  [O("Strelizen-Regimenter aufstellen.", {"regs": 4, "gold": -60, "mods": {"combat": 0.02}}, 60),
   O("Der Adel soll die Truppen stellen.", {"manpower": 3, "adm": -20}),
   O("Lieber Kosaken anheuern.", {"mil": 40})]),
E("rus_moscow_burns", "RUS", "Moskau brennt", "Die Krimtataren sind bis vor die Mauern geritten und haben die Vorstädte in Brand gesteckt.",
  {"year_min": 1545, "year_max": 1600, "alive": "CRI"},
  [O("Die Stadt wieder aufbauen.", {"gold": -80, "prestige": 5}, 50),
   O("Die Verhaulinie im Süden ausbauen.", {"mil": -30, "manpower": 3}),
   O("Tribut an den Khan zahlen.", {"gold": -40, "relations": {"CRI": 50}, "prestige": -10})]),
E("rus_livonian_war", "RUS", "Der Livländische Krieg", "Der Orden verweigert den Tribut für Dorpat. Iwan sieht den Weg zur Ostsee offen.",
  {"year_min": 1555, "year_max": 1585, "alive": "LIV", "at_peace": True},
  [O("Nach Livland marschieren!", {"war": "LIV", "mil": 30}, 50),
   O("Den Tribut erzwingen.", {"gold": 60, "relations": {"LIV": -40}}),
   O("Ein Handelsvertrag mit Narva.", {"dip": 40, "relations": {"LIV": 30}})]),
E("rus_cossacks", "RUS", "Die Kosaken", "Entlaufene Bauern und Abenteurer siedeln an Don und Dnjepr. Sie kämpfen gut, aber gehorchen ungern.",
  {"year_min": 1550},
  [O("Sie als Grenzwächter anwerben.", {"manpower": 3, "mods": {"manpower": 0.03}}, 60),
   O("Steuern von ihnen verlangen.", {"gold": 50, "relations": {"CRI": -20}}),
   O("Die Flüchtlinge zurückholen.", {"adm": 30, "dev_random": 1})]),
E("rus_romanov", "RUS", "Michail Romanow", "Der Landtag wählt einen sechzehnjährigen Bojaren zum Zaren. Die Wirren sind vorbei, wenn alle mitspielen.",
  {"year_min": 1610, "flag": "ev_rus_troubles"},
  [O("Den neuen Zaren krönen.", {"prestige": 15, "adm": 30}, 60),
   O("Frieden mit Polen und Schweden um jeden Preis.", {"relations": {"POL": 40, "DAN": 40}, "dip": 40}),
   O("Der Patriarch soll mitregieren.", {"ruler": {"adm": 1}, "prestige": -5})]),

# ------------------------------------------------------------------ Naples
E("nap_aragon_split", "NAP", "Das Testament Alfonsos", "Alfonso der Großmütige stirbt. Aragón geht an seinen Bruder, Neapel an seinen Bastard Ferrante.",
  {"year_max": 1465, "alive": "ARA"},
  [O("Neapel steht allein.", {"prestige": 10, "relations": {"ARA": -20}}, 50),
   O("Die Freundschaft mit Aragón erneuern.", {"relations": {"ARA": 50}, "dip": 20}),
   O("Die katalanischen Höflinge ausweisen.", {"adm": 40, "relations": {"ARA": -30}})]),
E("nap_skanderbeg", "NAP", "Skanderbeg", "Der albanische Fürst landet mit seinen Reitern in Apulien, um Ferrante gegen die Barone zu helfen.",
  {"year_min": 1455, "year_max": 1470, "alive": "ALB"},
  [O("Ein ewiges Bündnis mit Albanien.", {"alliance": "ALB", "mil": 20}, 50),
   O("Ihn mit Land in Apulien belohnen.", {"mods": {"combat": 0.02}, "dev_random": -1}),
   O("Danken und zurückschicken.", {"relations": {"ALB": 20}, "gold": 30})]),
E("nap_pontano", "NAP", "Die Akademie des Pontano", "Humanisten treffen sich in Neapel zu Gedichten, Astronomie und Streit über Cicero.",
  {"year_min": 1465, "year_max": 1510},
  [O("Der König wird Schirmherr.", {"prestige": 10, "gold": -40}, 50),
   O("Pontano als Staatssekretär.", {"adm": 40, "ruler": {"dip": 1}, "dip": -40}),
   O("Gedichte bringen kein Brot.", {"gold": 40})]),
E("nap_borgia", "NAP", "Der Borgia-Papst", "Alexander VI. sucht Fürstentümer für seine Kinder. Eine Heirat mit Neapel käme ihm gelegen.",
  {"year_min": 1490, "year_max": 1505, "alive": "PAP"},
  [O("Eine Borgia-Hochzeit.", {"relations": {"PAP": 50}, "prestige": -5, "dip": 30}, 50),
   O("Den Papst erpressen.", {"gold": 80, "relations": {"PAP": -40}}),
   O("Sich heraushalten.", {"adm": 20})]),
E("nap_corsairs", "NAP", "Barbareskenkorsaren", "Galeeren aus Algier überfallen die kalabrische Küste und verschleppen Fischer in die Sklaverei.",
  {"year_min": 1500},
  [O("Wachtürme an der Küste.", {"gold": -50, "dev_random": 1}, 30),
   O("Galeeren gegen die Korsaren.", {"mil": -30, "prestige": 10}, 45),
   O("Lösegeld zahlen.", {"gold": -30, "dev_random": -1})], once=False),
E("nap_toledo", "NAP", "Via Toledo", "Ein neuer Vizekönig will Neapel zur größten Stadt Italiens machen: breite Straßen, neue Mauern, neue Steuern.",
  {"year_min": 1530, "flag": "ev_nap_viceroy"},
  [O("Bauen!", {"gold": -80, "dev_capital": 2}, 60),
   O("Die Inquisition mitbringen? Niemals.", {"prestige": 10, "relations": {"SPA": -30}}),
   O("Nur die Steuern nehmen.", {"gold": 70, "dev_random": -1})]),

# ------------------------------------------------------------------ generic, all nations
E("gen_comet", "*", "Ein Komet am Himmel", "Ein Schweifstern leuchtet über Europa. Prediger verkünden Unheil, Gelehrte rechnen.",
  {"year_min": 1455, "year_max": 1460},
  [O("Bittgottesdienste anordnen.", {"prestige": 5, "adm": -10}, 50),
   O("Die Astronomen befragen.", {"adm": 20}),
   O("Das Volk beruhigen.", {"dip": 20})]),
E("gen_famine", "*", "Hungersnot", "Nach einer Missernte steigen die Brotpreise, in den Dörfern wird gehungert.",
  {"year_min": 1450},
  [O("Die Kornspeicher öffnen.", {"gold": -30, "prestige": 5}, 25),
   O("Getreide im Ausland kaufen.", {"dip": -30}, 35),
   O("Die Not aussitzen.", {"dev_random": -1, "manpower": -2}, 40)], once=False),
E("gen_fire", "*", "Stadtbrand", "Ein Feuer hat ganze Viertel der Hauptstadt in Asche gelegt.",
  {"year_min": 1450},
  [O("Wiederaufbau in Stein.", {"gold": -40, "adm": 20}, 25),
   O("Die Bürger sollen selbst bauen.", {"dev_capital": -1}, 40),
   O("Eine Brandsteuer erheben.", {"adm": -30}, 35)], once=False),
E("gen_revolt", "*", "Bauernaufstand", "Bauern verweigern Abgaben und Frondienste. Ein Haufen zieht mit Sensen und Dreschflegeln durchs Land.",
  {"year_min": 1460, "at_peace": True},
  [O("Die Aufständischen niederwerfen.", {"mil": -30, "manpower": -1}, 50),
   O("Die Abgaben senken.", {"gold": -30, "adm": 15}, 20),
   O("Mit dem Anführer verhandeln.", {"dip": -25, "prestige": -5})], once=False),
E("gen_war_weariness", "*", "Kriegsmüdigkeit", "Die Felder liegen brach, die Witwen klagen. Das Volk will Frieden.",
  {"at_war": True, "year_min": 1450},
  [O("Durchhalten!", {"prestige": -5, "we": 2}, 50),
   O("Kriegssteuer erlassen.", {"gold": -40, "we": -3}, 20),
   O("Prediger sollen den Krieg rechtfertigen.", {"adm": -20, "we": -2}, 30)], once=False),
E("gen_veterans", "*", "Heimkehrende Veteranen", "Nach dem Frieden ziehen entlassene Soldaten durchs Land. Manche werden Bauern, manche Räuber.",
  {"at_peace": True, "year_min": 1450},
  [O("Als Grenzwacht ansiedeln.", {"manpower": 2}, 50),
   O("Als Ausbilder behalten.", {"mil": 30, "gold": -20}),
   O("Land verteilen.", {"adm": -20, "dev_random": 1})], once=False),
E("gen_university", "*", "Eine Universität", "Gelehrte bitten um ein Privileg, um eine Hohe Schule zu gründen.",
  {"year_min": 1460, "min_dev": 30},
  [O("Die Universität stiften.", {"gold": -70, "mods": {"adm": 1}}, 25),
   O("Eine Lateinschule genügt.", {"adm": 25}, 50),
   O("Kein Geld für Gelehrte.", {"gold": 20})]),
E("gen_fugger", "*", "Ein Angebot der Bankiers", "Ein Augsburger Handelshaus bietet einen großzügigen Kredit an, gegen Bergbaurechte.",
  {"year_min": 1480, "year_max": 1600},
  [O("Den Kredit annehmen.", {"gold": 120, "mods": {"income": -0.02}}, 40),
   O("Nur einen kleinen Kredit.", {"gold": 50, "dip": -20}),
   O("Wir machen keine Schulden.", {"prestige": 5})]),
E("gen_artist", "*", "Ein Künstler am Hof", "Ein Maler aus Italien bietet an, den Palast auszuschmücken. Er ist teuer und launisch.",
  {"year_min": 1470, "year_max": 1620},
  [O("Ihn fürstlich bezahlen.", {"gold": -50, "prestige": 10}, 25),
   O("Ein Porträt des Herrschers genügt.", {"gold": -20, "dip": 20}),
   O("Wir haben eigene Handwerker.", {"adm": 15})]),
E("gen_royal_wedding", "*", "Eine Fürstenhochzeit", "Die Heirat eines Prinzen wird mit Turnieren und Festmählern gefeiert. Die Gäste kommen aus ganz Europa.",
  {"at_peace": True, "year_min": 1450},
  [O("Ein Fest, von dem man noch lange spricht.", {"gold": -50, "prestige": 10, "dip": 20}, 20),
   O("Eine bescheidene Feier.", {"dip": 15}, 50),
   O("Die Mitgift fürs Heer.", {"gold": 40, "prestige": -5})], once=False),
E("gen_spy", "*", "Ein Spion wird gefasst", "In der Kanzlei wurde ein Schreiber erwischt, der Briefe an einen fremden Hof kopiert hat.",
  {"year_min": 1450},
  [O("Öffentlich hinrichten.", {"prestige": 5, "dip": -15}, 50),
   O("Umdrehen: falsche Briefe schicken.", {"dip": 30, "adm": -15}),
   O("Ihn für Gold freilassen.", {"gold": 40, "prestige": -5})], once=False),
E("gen_ruler_ill", "*", "Der Herrscher erkrankt", "Fieber und Aderlass haben den Herrscher geschwächt. Der Hof flüstert über die Nachfolge.",
  {"year_min": 1450},
  [O("Die besten Ärzte holen.", {"gold": -40}, 25),
   O("Die Regierung dem Rat übergeben.", {"ruler": {"adm": -1}, "dip": 20}, 40),
   O("Pilgerfahrt geloben.", {"prestige": 5, "ruler": {"mil": -1}}, 35)], once=False),
E("gen_copernicus", "*", "Die Sonne in der Mitte", "Ein Domherr aus Frauenburg behauptet, die Erde kreise um die Sonne. Die Theologen schäumen.",
  {"year_min": 1543, "year_max": 1600},
  [O("Die Schrift drucken lassen.", {"adm": 30, "relations": {"PAP": -10}}, 40),
   O("Ein Buch für die Gelehrten, nicht fürs Volk.", {"adm": 15, "prestige": 5}),
   O("Verbieten.", {"prestige": 5, "relations": {"PAP": 10}})]),
E("gen_price_revolution", "*", "Preisrevolution", "Silber aus der Neuen Welt treibt die Preise. Was gestern ein Pfund kostete, kostet heute zwei.",
  {"year_min": 1540, "year_max": 1620},
  [O("Die Münzen verschlechtern.", {"gold": 60, "prestige": -10}, 40),
   O("Höchstpreise für Brot.", {"adm": -20, "prestige": 5}),
   O("Die Steuern anpassen.", {"adm": 20, "gold": -30})]),
E("gen_new_crops", "*", "Neue Feldfrüchte", "Mais, Bohnen und eine seltsame Knolle aus Amerika werden in Gärten angebaut.",
  {"year_min": 1570},
  [O("Den Anbau fördern.", {"gold": -40, "dev_random": 1}, 35),
   O("Als Kuriosität im Hofgarten.", {"prestige": 5}),
   O("Teufelszeug.", {"adm": 10})]),
E("gen_little_ice_age", "*", "Ein harter Winter", "Die Flüsse frieren zu, Vieh erfriert im Stall, im Frühjahr fehlt das Saatgut.",
  {"year_min": 1560},
  [O("Saatgut aus den Speichern.", {"gold": -30}, 25),
   O("Die Armen in die Klöster.", {"prestige": -5, "adm": -15}, 40),
   O("Jeder für sich.", {"dev_random": -1})], once=False),
E("gen_witch_trials", "*", "Hexenprozesse", "Nach Missernten und Seuchen suchen die Dörfer Schuldige. Gerichte verbrennen Frauen als Hexen.",
  {"year_min": 1570, "year_max": 1640},
  [O("Die Prozesse verbieten.", {"adm": 20, "prestige": -5}, 50),
   O("Den Gerichten freie Hand lassen.", {"dev_random": -1, "prestige": 5}),
   O("Nur unter Aufsicht der Juristen.", {"adm": -15})]),
E("gen_mercenary_mutiny", "*", "Söldner meutern", "Der Sold ist drei Monate im Rückstand. Die Söldner drohen, das eigene Land zu plündern.",
  {"at_war": True, "year_min": 1450, "regs": 10},
  [O("Den Sold nachzahlen.", {"gold": -40}, 25),
   O("Die Rädelsführer hängen.", {"mil": -30, "prestige": 5}, 50),
   O("Plünderung dulden.", {"dev_random": -1, "we": 2, "prestige": -5})], once=False),
E("gen_jubilee", "*", "Das Heilige Jahr", "Hunderttausende Pilger ziehen nach Rom. Wer mitreist, sieht die mächtigsten Höfe Europas.",
  {"year_min": 1474, "year_max": 1476},
  [O("Eine Gesandtschaft nach Rom.", {"gold": -30, "prestige": 10}, 50),
   O("Pilger über unsere Straßen schicken.", {"gold": 40}),
   O("Zuhause beten.", {"adm": 15})]),
E("gen_jubilee_1500", "*", "Das Heilige Jahr 1500", "Zur Jahrhundertwende öffnet der Papst die Heilige Pforte. Die Pilgerstraßen sind voll.",
  {"year_min": 1499, "year_max": 1501},
  [O("Eine prächtige Gesandtschaft.", {"gold": -40, "prestige": 10}, 50),
   O("Herbergen an den Straßen.", {"gold": 40}),
   O("Ablassgeld behalten.", {"gold": 60, "prestige": -5})]),

# ------------------------------------------------------------------ generic chain: the alchemist
E("gen_alchemist", "*", "Der Alchemist", "Ein Gelehrter verspricht, aus Blei Gold zu machen. Er braucht nur ein Labor und etwas Geduld.",
  {"year_min": 1460, "year_max": 1620},
  [O("Das Labor finanzieren.", {"gold": -40, "flag": "gen_alchemist_funded"}, 35),
   O("Ihn als Arzt einstellen.", {"adm": 20}),
   O("Scharlatan! Hinaus.", {"prestige": 5})]),
E("gen_alchemist_result", "*", "Ergebnisse aus dem Labor", "Der Alchemist präsentiert seine Arbeit. Gold ist es nicht, aber vielleicht etwas anderes.",
  {"flag": "gen_alchemist_funded"},
  [O("Porzellan? Eine Manufaktur gründen!", {"mods": {"income": 0.02}}, 40),
   O("Besseres Schießpulver.", {"mil": 50}),
   O("Er ist mit dem Geld geflohen.", {"prestige": -5, "adm": 20})]),

# ------------------------------------------------------------------ minor nations only
E("gen_minor_neutrality", "*", "Kleine Krone, kluge Krone", "Zwischen den Großmächten überlebt nur, wer niemanden reizt. Der Rat schlägt strikte Neutralität vor.",
  {"major": False, "at_peace": True},
  [O("Neutralität erklären.", {"dip": 40, "prestige": 5}, 50),
   O("Festungen statt Freunde.", {"mil": -30, "manpower": 2}),
   O("Den Schutz eines Mächtigen suchen.", {"dip": 20, "prestige": -5})], once=False),
E("gen_minor_mercenaries", "*", "Söhne für fremde Kriege", "Fremde Werber bieten gutes Geld für unsere jungen Männer.",
  {"major": False, "at_peace": True},
  [O("Reisläufer verkaufen.", {"gold": 70, "manpower": -2}, 50),
   O("Sie sollen nach dem Dienst zurückkehren.", {"mil": 30, "manpower": -1}),
   O("Unsere Männer bleiben hier.", {"manpower": 1})], once=False),
E("gen_minor_fair", "*", "Die große Messe", "Kaufleute aus vielen Ländern kommen zur Messe in unsere Hauptstadt.",
  {"major": False, "year_min": 1450},
  [O("Messeprivilegien vergeben.", {"gold": 50, "dev_capital": 1}, 50),
   O("Zölle erheben.", {"gold": 70}),
   O("Fremde Händler fernhalten.", {"adm": 20})], once=False),
E("gen_minor_militia", "*", "Die Landwehr", "Ein kleiner Staat kann sich kein großes Heer leisten. Aber jeder Mann kann eine Pike tragen.",
  {"major": False},
  [O("Die Landwehr ausbilden.", {"regs": 2, "mil": -20}, 50),
   O("Musterungsrollen anlegen.", {"manpower": 2}),
   O("Bauern gehören aufs Feld.", {"gold": 30})]),
E("gen_minor_court", "*", "Ein Musenhof", "Gelehrte und Künstler, die an großen Höfen keinen Platz finden, kommen gern zu uns.",
  {"major": False, "year_min": 1470},
  [O("Sie willkommen heißen.", {"prestige": 10, "dip": -20}, 50),
   O("Nur die Nützlichen.", {"adm": 30}),
   O("Wir haben andere Sorgen.", {"mil": 20})]),
]

# ------------------------------------------------------------------ missions 7-10 (owns-keys become starting claims!)
def M(id, title, desc, require, reward, after=None):
    m = {"id": id}
    if after:
        m["after"] = after
    m.update({"title": title, "desc": desc, "require": require, "reward": reward})
    return m

MISSIONS = {
"FRA": [
  M("fra_provence", "Die Provence erben", "Das Erbe des Hauses Anjou: Marseille und das Mittelmeer.",
    {"owns": ["provence"]}, {"dip": 40, "prestige": 10}),
  M("fra_rhine", "Die natürlichen Grenzen", "Der Rhein soll die Grenze Frankreichs sein.",
    {"owns_any": ["luxembourg", "palatinate", "cologne"], "min_dev": 220}, {"prestige": 15, "mods": {"combat": 0.05}}, after="fra_burgundy"),
  M("fra_levant_fleet", "Die Levante-Flotte", "Galeeren in Marseille und Toulon schützen den Handel.",
    {"tech": {"mil": 12}, "regs": 25}, {"mods": {"income": 0.05}, "mil": 40}),
  M("fra_versailles", "Le Roi Soleil", "Ein Palast, der die Welt beeindruckt.",
    {"min_dev": 300, "gold_min": 500}, {"prestige": 30, "dev_capital": 3}, after="fra_absolutism"),
],
"ENG": [
  M("eng_royal_navy", "Die Royal Navy", "Eine stehende Flotte, die keinem Feind die Küste überlässt.",
    {"tech": {"mil": 16}, "regs": 30}, {"mods": {"combat": 0.05}, "prestige": 15}, after="eng_navy"),
  M("eng_plantation", "Die Plantage von Ulster", "Siedler aus England und Schottland sollen Irland an die Krone binden.",
    {"year_min": 1580, "owns": ["munster", "ulster", "pale"]}, {"mods": {"manpower": 0.05}, "adm": 40}, after="eng_ireland"),
  M("eng_companies", "Die Handelskompanien", "Merchant Adventurers und Levante-Kompanie öffnen neue Märkte.",
    {"tech": {"dip": 12}, "min_dev": 180}, {"mods": {"income": 0.05}, "dip": 40}),
],
"SPA": [
  M("spa_indies", "Las Indias", "Die Neue Welt muss verwaltet werden: der Indienrat in Sevilla.",
    {"flag": "ev_spa_columbus", "tech": {"adm": 10}}, {"gold": 200, "mods": {"income": 0.05}}),
  M("spa_netherlands", "Die Spanischen Niederlande", "Das burgundische Erbe am Nordmeer.",
    {"owns_any": ["flanders", "brabant", "holland"]}, {"mods": {"income": 0.05}, "prestige": 10}, after="spa_italy"),
  M("spa_armada", "Die Unbesiegbare Armada", "Eine Flotte, die alle Meere beherrscht.",
    {"tech": {"mil": 14}, "regs": 30}, {"mods": {"combat": 0.05}, "prestige": 15}),
],
"BOH": [
  M("boh_fortresses", "Die böhmischen Pässe", "Böhmen ist von Bergen umgeben. Befestigt die Pässe und das Land ist uneinnehmbar.",
    {"tech": {"mil": 6}, "regs": 15}, {"mods": {"manpower": 0.1}, "mil": 30}),
  M("boh_glass", "Böhmisches Glas", "Die Glashütten des Erzgebirges beliefern ganz Europa.",
    {"tech": {"adm": 8}, "min_dev": 100}, {"mods": {"income": 0.05}, "dev_random": 2}),
  M("boh_jagiellon_union", "Die jagiellonische Union", "Böhmen und Polen unter einem Haus oder zumindest im Bund.",
    {"allied": "POL"}, {"prestige": 15, "dip": 50}),
  M("boh_upper_palatinate", "Die Oberpfalz", "Die alte böhmische Brücke nach Nürnberg.",
    {"owns_any": ["regensburg", "nuremberg"]}, {"gold": 100, "dip": 30}),
],
"HAB": [
  M("hab_emperor", "Der Kaiser", "Die Kaiserkrone bleibt im Haus Habsburg.",
    {"min_dev": 200, "allies": 2}, {"mods": {"dip": 1}, "prestige": 20}),
  M("hab_vienna_walls", "Die Mauern Wiens", "Wien muss jeder Belagerung standhalten.",
    {"owns": ["wien"], "tech": {"mil": 10}, "regs": 30}, {"mods": {"combat": 0.05}}),
  M("hab_silesia", "Die Nebenländer der böhmischen Krone", "Mähren oder Schlesien folgen Prag an Habsburg.",
    {"owns_any": ["moravia", "silesia"], "min_dev": 250}, {"mods": {"manpower": 0.1}, "adm": 40}, after="hab_bohemia"),
  M("hab_italy", "Reichsitalien", "Mailand und Verona, die Pforten zu Italien.",
    {"owns_any": ["milan", "verona"]}, {"mods": {"income": 0.05}, "prestige": 10}),
],
"RUS": [
  M("rus_kiev", "Die Mutter der russischen Städte", "Kiew und Tschernigow kehren zur Rus zurück.",
    {"owns": ["kiev", "chernigov"]}, {"prestige": 25, "mods": {"manpower": 0.05}}, after="rus_smolensk"),
  M("rus_crimea", "Das Ende der Raubzüge", "Erst wenn die Krim fällt, ist der Süden sicher.",
    {"owns": ["crimea"]}, {"mods": {"manpower": 0.1}, "prestige": 15}, after="rus_kazan"),
  M("rus_streltsy", "Das Strelizenheer", "Ein stehendes Heer mit Feuerwaffen.",
    {"tech": {"mil": 8}, "regs": 30}, {"mods": {"combat": 0.05}}),
  M("rus_archangel", "Der Hafen am Weißen Meer", "Englische Kaufleute kommen über das Eismeer nach Russland.",
    {"tech": {"dip": 10}, "min_dev": 160}, {"mods": {"income": 0.05}, "dip": 40}),
],
"NAP": [
  M("nap_coast", "Die Küste befestigen", "Wachtürme von Apulien bis Kalabrien gegen Korsaren und Türken.",
    {"owns": ["apulia", "calabria"], "tech": {"mil": 6}}, {"mods": {"manpower": 0.1}, "mil": 30}),
  M("nap_silk", "Kalabrische Seide", "Maulbeerbäume und Seidenwebereien bringen Wohlstand.",
    {"owns": ["calabria"], "tech": {"adm": 6}}, {"mods": {"income": 0.05}}),
  M("nap_galleys", "Galeeren gegen den Halbmond", "Eine Flotte, die das Tyrrhenische Meer beherrscht.",
    {"tech": {"mil": 10}, "regs": 20}, {"mods": {"combat": 0.05}, "prestige": 10}),
  M("nap_albania", "Jenseits der Adria", "Das Erbe Skanderbegs: ein Brückenkopf in Albanien.",
    {"owns_any": ["albania", "dalmatia"]}, {"prestige": 15, "dip": 40}, after="nap_adriatic"),
],
}

def render_event(e):
    head = {k: e[k] for k in ("id", "once", "tag", "title", "text") if k in e}
    s = "  " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    s += '   "trigger": ' + json.dumps(e["trigger"], ensure_ascii=False) + ",\n"
    s += '   "options": [\n'
    s += ",\n".join("     " + json.dumps(o, ensure_ascii=False) for o in e["options"])
    return s + "]}"

def render_mission(m):
    head = {k: m[k] for k in ("id", "after", "title", "desc") if k in m}
    s = "    " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    return s + '     "require": ' + json.dumps(m["require"], ensure_ascii=False) + ', "reward": ' + json.dumps(m["reward"], ensure_ascii=False) + "}"

def main(root):
    path = root + "/data/events.json"
    txt = open(path, encoding="utf-8").read().rstrip()
    assert txt.endswith("]")
    existing = {e["id"] for e in json.loads(txt)}
    new = [e for e in EVENTS if e["id"] not in existing]
    for e in new:
        assert len(e["options"]) == 3, e["id"]
    txt = txt[:-1].rstrip() + ",\n" + ",\n".join(render_event(e) for e in new) + "\n]\n"
    json.loads(txt)
    # existing event: Habsburg swallowed AI Bohemia in ~all sims (no year cap, 70 % AI weight)
    old_trig = '"trigger": {"year_min": 1520, "alive": "BOH", "at_peace": true},'
    assert txt.count(old_trig) == 1
    txt = txt.replace(old_trig, '"trigger": {"year_min": 1520, "year_max": 1540, "alive": "BOH", "at_peace": true},')
    old_opt = '{"text": "Den Thron beanspruchen!", "effects": {"inherit": "BOH", "ae": 10}, "ai": 70}'
    assert txt.count(old_opt) == 1
    txt = txt.replace(old_opt, '{"text": "Den Thron beanspruchen!", "effects": {"inherit": "BOH", "ae": 10}, "ai": 35}')
    txt = txt.replace('{"text": "Bündnis statt Krone.", "effects": {"alliance": "BOH"}}', '{"text": "Bündnis statt Krone.", "effects": {"alliance": "BOH"}, "ai": 40}')
    json.loads(txt)
    open(path, "w", encoding="utf-8").write(txt)

    path = root + "/data/missions.json"
    data = json.load(open(path, encoding="utf-8"))
    for tag, ms in MISSIONS.items():
        have = {m["id"] for m in data[tag]}
        data[tag] += [m for m in ms if m["id"] not in have]
    out = "{\n" + ",\n".join(
        '  "%s": [\n' % tag + ",\n".join(render_mission(m) for m in ms) + "\n  ]" for tag, ms in data.items()) + "\n}\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)
    print("events +%d, missions now %s" % (len(new), {t: len(v) for t, v in data.items()}))

if __name__ == "__main__":
    main(sys.argv[1])
