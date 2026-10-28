#!/usr/bin/env python3
"""Generates data/techs.json and data/government.json (tech tree + government screen content).

Run from the repo root: python3 tools/content/tech_gov.py
Modifier keys are the shared Game.mod() keys (see scripts/core/tech.gd for the label table).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Every branch has 10 techs; the n-th tech of a branch becomes available around BRANCH_YEARS[n].
# The last tier (1638, open from 1618) keeps research going until the game ends in 1644.
BRANCH_YEARS = [1444, 1462, 1484, 1506, 1528, 1550, 1572, 1594, 1616, 1638]

# category -> [(branch_id, branch_name, [(id, name, effects), ...10])]
TREE = {
    "adm": [
        ("staat", "Staat & Recht", [
            ("adm_kanzlei", "Königliche Kanzlei", {"income": 0.03}),
            ("adm_landvoegte", "Landvögte", {"unrest": -0.25, "tax": 0.02}),
            ("adm_kataster", "Grundbücher & Kataster", {"tax": 0.05}),
            ("adm_gerichte", "Oberste Gerichtshöfe", {"unrest": -0.25, "coring": -0.1}),
            ("adm_beamte", "Berufsbeamtentum", {"income": 0.04}),
            ("adm_intendanten", "Intendanten", {"coring": -0.15}),
            ("adm_kameral", "Kameralistik", {"tax": 0.08}),
            ("adm_policey", "Policey-Ordnungen", {"unrest": -0.5}),
            ("adm_absolut", "Absolute Verwaltung", {"adm": 1}),
            ("adm_kabinett", "Kabinettsregierung", {"income": 0.03, "unrest": -0.25}),
        ]),
        ("wirtschaft", "Gewerbe & Bau", [
            ("adm_zuenfte", "Zunftordnungen", {"production": 0.05}),
            ("adm_muehlen", "Wassermühlen", {"build_cost": -0.05}),
            ("adm_saigerhuetten", "Saigerhütten", {"production": 0.05}),
            ("adm_baukunst", "Renaissance-Baukunst", {"build_cost": -0.1}),
            ("adm_verlag", "Verlagssystem", {"production": 0.08}),
            ("adm_kanaele", "Kanal- und Schleusenbau", {"develop_cost": -0.1}),
            ("adm_manufaktur", "Manufakturen", {"production": 0.1}),
            ("adm_polder", "Trockenlegung & Polder", {"develop_cost": -0.1}),
            ("adm_merkantil", "Merkantile Wirtschaftslehre", {"production": 0.08, "trade": 0.05}),
            ("adm_colbert", "Colbertismus", {"production": 0.08, "build_cost": -0.05}),
        ]),
        ("wissen", "Wissen & Glaube", [
            ("adm_universitaet", "Universitäten", {"tech_cost": -0.03}),
            ("adm_buchdruck", "Buchdruck", {"tech_cost": -0.05}),
            ("adm_humanismus", "Humanismus", {"prestige": 0.5, "tech_cost": -0.02}),
            ("adm_kirchenreform", "Kirchenreform", {"unrest": -0.25, "prestige": 0.25}),
            ("adm_akademien", "Gelehrte Akademien", {"tech_cost": -0.05}),
            ("adm_vermessung", "Landesvermessung", {"develop_cost": -0.05, "coring": -0.05}),
            ("adm_naturphil", "Naturphilosophie", {"tech_cost": -0.05}),
            ("adm_wissenschaft", "Wissenschaftliche Revolution", {"tech_cost": -0.04, "income": 0.02}),
            ("adm_aufklaerung", "Frühe Aufklärung", {"adm": 1, "unrest": -0.25}),
            ("adm_akademie", "Akademie der Wissenschaften", {"tech_cost": -0.03, "prestige": 0.5}),
        ]),
    ],
    "dip": [
        ("hof", "Hof & Gesandte", [
            ("dip_gesandte", "Ständige Gesandtschaften", {"ae_decay": 0.05}),
            ("dip_heraldik", "Heraldik & Turniere", {"prestige": 0.5}),
            ("dip_vertraege", "Vertragsrecht", {"ae_gen": -0.05}),
            ("dip_zeremoniell", "Hofzeremoniell", {"prestige": 0.5}),
            ("dip_kabinett", "Geheime Kabinette", {"ae_gen": -0.1}),
            ("dip_heiratspolitik", "Heiratspolitik", {"ae_decay": 0.1}),
            ("dip_kongresse", "Friedenskongresse", {"ae_gen": -0.05, "ae_decay": 0.05}),
            ("dip_dienst", "Diplomatischer Dienst", {"dip": 1}),
            ("dip_gleichgewicht", "Gleichgewicht der Mächte", {"ae_decay": 0.15}),
            ("dip_westfalen", "Westfälisches System", {"ae_decay": 0.1, "ae_gen": -0.05}),
        ]),
        ("handel", "Handel & Geld", [
            ("dip_messen", "Handelsmessen", {"trade": 0.05}),
            ("dip_wechsel", "Wechselbriefe", {"income": 0.02, "trade": 0.03}),
            ("dip_gilden", "Kaufmannsgilden", {"trade": 0.05}),
            ("dip_karavellen", "Karavellen", {"trade": 0.05}),
            ("dip_boersen", "Börsen", {"trade": 0.08}),
            ("dip_girobanken", "Girobanken", {"income": 0.04}),
            ("dip_aktien", "Aktiengesellschaften", {"trade": 0.05, "company_slots": 1}),
            ("dip_fernhandel", "Fernhandelsrouten", {"trade": 0.1}),
            ("dip_handelsbilanz", "Handelsbilanzlehre", {"trade": 0.08, "income": 0.02}),
            ("dip_ostindien", "Ostindische Kompanien", {"trade": 0.1}),
        ]),
        ("recht", "Integration & Herrschaft", [
            ("dip_lehnsrecht", "Lehnsrecht", {"coring": -0.05}),
            ("dip_staende", "Ständeversammlungen", {"unrest": -0.25, "tax": 0.02}),
            ("dip_privilegien", "Städtische Privilegien", {"tax": 0.03, "production": 0.03}),
            ("dip_personalunion", "Verwaltung von Personalunionen", {"coring": -0.1}),
            ("dip_statthalter", "Statthalterschaften", {"coring": -0.15}),
            ("dip_religionsfrieden", "Religionsfrieden", {"unrest": -0.25, "ae_decay": 0.05}),
            ("dip_kammergericht", "Reichskammergericht", {"ae_gen": -0.05, "coring": -0.05}),
            ("dip_flugschriften", "Flugschriften & Propaganda", {"unrest": -0.25, "prestige": 0.5}),
            ("dip_staatsraison", "Staatsräson", {"coring": -0.15, "advisor_slots": 1}),
            ("dip_souveraenitaet", "Souveränität", {"coring": -0.1, "unrest": -0.25}),
        ]),
    ],
    "mil": [
        ("taktik", "Taktik", [
            ("mil_pikenhaufen", "Pikenhaufen", {"combat": 0.03}),
            ("mil_ordonnanz", "Ordonnanzkompanien", {"combat": 0.03}),
            ("mil_arkebusiere", "Arkebusiere", {"combat": 0.04}),
            ("mil_gevierthaufen", "Gevierthaufen", {"combat": 0.04}),
            ("mil_pistoliere", "Reiterpistoliere", {"combat": 0.04}),
            ("mil_exerzieren", "Exerzierreglement", {"combat": 0.05, "army_power": 0.05}),
            ("mil_salven", "Salvenfeuer", {"combat": 0.05}),
            ("mil_brigade", "Schwedische Brigade", {"combat": 0.05}),
            ("mil_lineartaktik", "Lineartaktik", {"combat": 0.06}),
            ("mil_bajonett", "Bajonett", {"combat": 0.05}),
        ]),
        ("belagerung", "Artillerie & Festungen", [
            ("mil_bombarden", "Bombarden", {"siege": 0.05}),
            ("mil_feldgeschuetze", "Feldgeschütze", {"siege": 0.05, "combat": 0.01}),
            ("mil_bastionen", "Bastionen", {"siege": 0.05, "combat": 0.01}),
            ("mil_minen", "Minengänge", {"siege": 0.1}),
            ("mil_trace_italienne", "Trace italienne", {"siege": 0.05, "combat": 0.02}),
            ("mil_bronzeguss", "Bronzeguss", {"siege": 0.1}),
            ("mil_moerser", "Mörser", {"siege": 0.1}),
            ("mil_ingenieure", "Ingenieurskorps", {"siege": 0.1}),
            ("mil_sternfestungen", "Sternfestungen", {"siege": 0.1, "combat": 0.02}),
            ("mil_vauban", "Vauban-Festungsbau", {"siege": 0.1}),
        ]),
        ("heerwesen", "Heerwesen", [
            ("mil_lehnsaufgebot", "Lehnsaufgebot", {"manpower": 0.05}),
            ("mil_soldwesen", "Soldwesen", {"force_limit": 1}),
            ("mil_landsknechte", "Landsknechte", {"manpower": 0.1}),
            ("mil_magazine", "Magazinsystem", {"maintenance": -0.05, "army_power_regen": 0.25}),
            ("mil_musterrollen", "Musterungsrollen", {"force_limit": 2}),
            ("mil_kriegskanzlei", "Kriegskanzlei", {"maintenance": -0.05}),
            ("mil_garnisonen", "Stehende Garnisonen", {"unrest": -0.25, "force_limit": 1}),
            ("mil_kasernen", "Kasernen", {"manpower": 0.1, "force_limit": 2}),
            ("mil_stehendes_heer", "Stehendes Heer", {"mil": 1, "army_power": 0.1}),
            ("mil_kommissariat", "Generalkriegskommissariat", {"maintenance": -0.05, "force_limit": 2}),
        ]),
    ],
}

# National special techs for every playable nation: (id, cat, name, year, requires, effects, text)
SPECIAL = {
    "FRA": [
        ("fra_ordonnance", "mil", "Compagnies d'ordonnance", 1445, "mil_pikenhaufen", {"combat": 0.05, "manpower": 0.1},
         "Karl VII. schafft das erste stehende Heer Europas."),
        ("fra_bourges", "adm", "Pragmatische Sanktion von Bourges", 1450, "adm_kanzlei", {"income": 0.05, "prestige": -0.25},
         "Die gallikanische Kirche zahlt an die Krone statt nach Rom, der Papst ist verstimmt."),
        ("fra_intendants", "adm", "Intendants de justice", 1590, "adm_intendanten", {"coring": -0.2, "adm": 1, "unrest": 0.5},
         "Königliche Kommissare regieren die Provinzen, der Adel murrt."),
    ],
    "ENG": [
        ("eng_longbow", "mil", "Yeomen-Langbogner", 1444, "mil_pikenhaufen", {"combat": 0.06, "manpower": -0.05},
         "Jeder freie Mann übt sonntags am Bogen, aber gute Schützen sind rar."),
        ("eng_adventurers", "dip", "Charta der Merchant Adventurers", 1490, "dip_gilden", {"trade": 0.12},
         "Londoner Tuchhändler erhalten das Monopol auf den Export nach Flandern."),
        ("eng_supremacy", "adm", "Suprematsakte", 1530, "adm_kirchenreform", {"income": 0.08, "tech_cost": -0.03, "unrest": 0.5, "estate_klerus": -15},
         "Die Krone wird Oberhaupt der Kirche und zieht die Klostergüter ein."),
    ],
    "SPA": [
        ("spa_hermandad", "adm", "Santa Hermandad", 1476, "adm_landvoegte", {"unrest": -1.0},
         "Eine königliche Landpolizei bringt Ordnung auf die Straßen Kastiliens."),
        ("spa_casa", "dip", "Casa de Contratación", 1503, "dip_karavellen", {"trade": 0.15, "production": -0.05},
         "Sevilla kontrolliert allen Überseehandel, das heimische Gewerbe verkümmert."),
        ("spa_tercios", "mil", "Tercios", 1530, "mil_gevierthaufen", {"combat": 0.08, "maintenance": 0.05},
         "Die gefürchtetste Infanterie Europas ist teuer im Unterhalt."),
    ],
    "BOH": [
        ("boh_wagenburg", "mil", "Hussitische Wagenburg", 1444, "mil_pikenhaufen", {"combat": 0.06},
         "Kampfwagen und Handfeuerwaffen nach dem Vorbild Jan Žižkas."),
        ("boh_kuttenberg", "adm", "Kuttenberger Münzreform", 1470, "adm_saigerhuetten", {"income": 0.06, "production": 0.05},
         "Neue Schmelzverfahren holen mehr Silber aus den alten Gruben."),
        ("boh_majestaetsbrief", "dip", "Majestätsbrief", 1600, "dip_religionsfrieden", {"unrest": -1.0, "prestige": -0.25},
         "Religionsfreiheit für alle Stände, die Krone verliert an Autorität."),
    ],
    "HAB": [
        ("hab_hausmacht", "dip", "Habsburgische Hausmacht", 1477, "dip_vertraege", {"ae_decay": 0.1, "prestige": 0.5},
         "Andere mögen Kriege führen, du, glückliches Österreich, heirate."),
        ("hab_hofkammer", "adm", "Hofkammer", 1498, "adm_kataster", {"income": 0.05, "tech_cost": -0.03},
         "Maximilian I. ordnet die Finanzen der Erblande neu."),
        ("hab_militaergrenze", "mil", "Militärgrenze", 1530, "mil_musterrollen", {"force_limit": 3, "manpower": 0.1, "unrest": 0.25},
         "Wehrbauern sichern die Grenze gegen die Osmanen."),
    ],
    "RUS": [
        ("rus_pomestje", "mil", "Pomestje-System", 1480, "mil_lehnsaufgebot", {"manpower": 0.2, "combat": -0.02},
         "Dienstadel erhält Land gegen Kriegsdienst, viele Reiter, wenig Disziplin."),
        ("rus_prikasy", "adm", "Prikas-Ämter", 1550, "adm_beamte", {"coring": -0.15, "unrest": 0.25},
         "Zentrale Behörden in Moskau verwalten das wachsende Reich."),
        ("rus_strelizen", "mil", "Strelizen", 1550, "mil_exerzieren", {"combat": 0.06, "maintenance": 0.05},
         "Iwan IV. stellt die ersten Musketierregimenter auf."),
    ],
    "NAP": [
        ("nap_dogana", "adm", "Dogana delle pecore", 1447, "adm_kanzlei", {"income": 0.06},
         "Alfons V. besteuert die Wanderherden Apuliens."),
        ("nap_seide", "dip", "Seidenhandel Kalabriens", 1470, "dip_wechsel", {"trade": 0.1},
         "Kalabrische Seide wird in ganz Europa gehandelt."),
        ("nap_vizekoenig", "adm", "Vizekönigliche Verwaltung", 1530, "adm_beamte", {"unrest": -0.5, "tax": 0.05, "prestige": -0.25},
         "Ein straff geführter Verwaltungsstaat, der Hof verliert an Glanz."),
    ],
    "TUR": [
        ("tur_janitscharen", "mil", "Janitscharen-Korps", 1444, "mil_pikenhaufen", {"combat": 0.06, "maintenance": 0.05},
         "Die Elitetruppe des Sultans, besoldet und gefürchtet."),
        ("tur_timar", "mil", "Timar-System", 1460, "mil_lehnsaufgebot", {"manpower": 0.15, "force_limit": 2},
         "Sipahi erhalten Landlehen gegen Reiterdienst."),
        ("tur_kanun", "adm", "Kanun-Gesetzbücher", 1520, "adm_gerichte", {"unrest": -0.75, "coring": -0.1},
         "Süleyman der Gesetzgeber vereinheitlicht das Recht des Reiches."),
    ],
    "POL": [
        ("pol_kornhandel", "dip", "Danziger Kornhandel", 1466, "dip_messen", {"trade": 0.12},
         "Getreide aus Masowien fließt über die Weichsel nach Westen."),
        ("pol_husaren", "mil", "Geflügelte Husaren", 1500, "mil_arkebusiere", {"combat": 0.07},
         "Die schwere Reiterei Polens entscheidet Schlachten mit einem Angriff."),
        ("pol_nihil_novi", "dip", "Nihil novi", 1505, "dip_staende", {"unrest": -1.0, "tech_cost": 0.03, "estate_adel": 20},
         "Nichts Neues ohne Zustimmung des Sejm, Reformen werden zäh."),
    ],
    "BUR": [
        ("bur_tuchstaedte", "adm", "Flämische Tuchstädte", 1444, "adm_zuenfte", {"production": 0.1},
         "Gent, Brügge und Ypern weben das beste Tuch des Nordens."),
        ("bur_hofprunk", "dip", "Prunk des Burgunderhofes", 1454, "dip_heraldik", {"prestige": 1.0, "income": -0.03},
         "Feste wie das Fasanenbankett beeindrucken Europa und leeren die Kasse."),
        ("bur_ordonnanzen", "mil", "Burgundische Ordonnanzen", 1471, "mil_ordonnanz", {"combat": 0.06, "force_limit": 2, "maintenance": 0.05},
         "Karl der Kühne baut ein modernes, teures Berufsheer auf."),
    ],
}

# ---------------------------------------------------------------- government

# Generic political advisors: (id, name, power type, effects)
ADVISORS = [
    ("kaemmerer", "Kämmerer", "adm", {"income": 0.06}),
    ("steuermeister", "Strenger Steuermeister", "adm", {"tax": 0.12, "unrest": 0.5, "estate_buerger": -10}),
    ("baumeister", "Hofbaumeister", "adm", {"build_cost": -0.15}),
    ("gelehrter", "Hofgelehrter", "adm", {"tech_cost": -0.08}),
    ("landvogt", "Oberster Landvogt", "adm", {"unrest": -1.0}),
    ("reformer", "Eifriger Reformer", "adm", {"adm": 1, "unrest": 0.5, "estate_adel": -10}),
    ("zeremonienmeister", "Zeremonienmeister", "dip", {"prestige": 1.0}),
    ("gesandter", "Erster Gesandter", "dip", {"ae_decay": 0.15}),
    ("meisterspion", "Meisterspion", "dip", {"ae_gen": -0.15}),
    ("handelsherr", "Handelsherr", "dip", {"trade": 0.1}),
    ("hofprediger", "Hofprediger", "dip", {"conversion": 0.5, "religious_unrest": -0.25, "estate_klerus": 5}),
    ("eiferer", "Glaubenseiferer", "dip", {"unrest": -1.5, "prestige": 0.5, "tech_cost": 0.05, "estate_klerus": 10}),
    ("feldhauptmann", "Feldhauptmann", "mil", {"combat": 0.05}),
    ("zeugmeister", "Zeugmeister", "mil", {"siege": 0.2}),
    ("werbeoffizier", "Werbeoffizier", "mil", {"manpower": 0.15}),
    ("quartiermeister", "Generalquartiermeister", "mil", {"maintenance": -0.1, "army_power_regen": 0.2}),
    ("drillmeister", "Drillmeister", "mil", {"army_power": 0.1, "army_power_regen": 0.2}),
    ("kriegstreiber", "Kriegstreiber", "mil", {"combat": 0.08, "ae_gen": 0.1}),
]

# National advisors (historical figures), hireable from..to, they leave the court after `to`.
# (id, tag, name, power, from, to, effects)
NATIONAL_ADVISORS = [
    ("fra_coeur", "FRA", "Jacques Cœur", "dip", 1444, 1456, {"trade": 0.15, "income": 0.03}),
    ("fra_bureau", "FRA", "Jean Bureau", "mil", 1444, 1463, {"siege": 0.3, "combat": 0.03}),
    ("fra_sully", "FRA", "Herzog von Sully", "adm", 1597, 1611, {"income": 0.1, "unrest": -0.5}),
    ("fra_richelieu", "FRA", "Kardinal Richelieu", "adm", 1624, 1642, {"adm": 2, "unrest": 0.75}),
    ("eng_suffolk", "ENG", "William de la Pole", "dip", 1444, 1450, {"dip": 1, "prestige": -0.5}),
    ("eng_cromwell", "ENG", "Thomas Cromwell", "adm", 1532, 1540, {"adm": 2, "unrest": 0.5}),
    ("eng_cecil", "ENG", "William Cecil", "dip", 1558, 1598, {"dip": 1, "ae_decay": 0.1}),
    ("eng_walsingham", "ENG", "Francis Walsingham", "dip", 1573, 1590, {"ae_gen": -0.2, "unrest": -0.5}),
    ("spa_luna", "SPA", "Álvaro de Luna", "adm", 1444, 1453, {"adm": 1, "prestige": -0.5}),
    ("spa_cisneros", "SPA", "Kardinal Cisneros", "adm", 1495, 1517, {"tech_cost": -0.1, "unrest": -0.5}),
    ("spa_cordoba", "SPA", "Gonzalo de Córdoba", "mil", 1495, 1515, {"combat": 0.1}),
    ("spa_olivares", "SPA", "Graf-Herzog von Olivares", "adm", 1621, 1643, {"force_limit": 4, "unrest": 0.75}),
    ("boh_podiebrad", "BOH", "Georg von Podiebrad", "adm", 1448, 1471, {"adm": 1, "dip": 1}),
    ("boh_rozmital", "BOH", "Zdeněk Lev von Rožmitál", "adm", 1507, 1523, {"income": 0.08, "unrest": 0.25}),
    ("boh_rosenberg", "BOH", "Wilhelm von Rosenberg", "dip", 1570, 1592, {"dip": 1, "unrest": -0.5}),
    ("hab_piccolomini", "HAB", "Enea Silvio Piccolomini", "dip", 1444, 1455, {"dip": 1, "prestige": 0.5}),
    ("hab_salm", "HAB", "Niklas Graf Salm", "mil", 1520, 1530, {"combat": 0.06, "unrest": -0.5}),
    ("hab_wallenstein", "HAB", "Albrecht von Wallenstein", "mil", 1618, 1634, {"force_limit": 5, "combat": 0.05, "ae_gen": 0.1}),
    ("rus_kholmsky", "RUS", "Daniil Cholmski", "mil", 1460, 1493, {"combat": 0.07}),
    ("rus_adashev", "RUS", "Alexei Adaschew", "adm", 1549, 1560, {"adm": 1, "unrest": -0.5}),
    ("rus_godunov", "RUS", "Boris Godunow", "adm", 1584, 1605, {"adm": 1, "income": 0.05, "prestige": -0.5}),
    ("nap_petrucci", "NAP", "Antonello Petrucci", "adm", 1458, 1487, {"income": 0.08}),
    ("nap_pontano", "NAP", "Giovanni Pontano", "dip", 1486, 1503, {"dip": 1, "tech_cost": -0.05}),
    ("nap_toledo", "NAP", "Pedro de Toledo", "adm", 1532, 1553, {"unrest": -1.0, "tax": 0.05}),
    ("tur_candarli", "TUR", "Çandarlı Halil Pascha", "adm", 1444, 1453, {"adm": 1, "combat": -0.03}),
    ("tur_ibrahim", "TUR", "Pargalı İbrahim Pascha", "dip", 1523, 1536, {"dip": 1, "ae_decay": 0.1}),
    ("tur_sinan", "TUR", "Mimar Sinan", "adm", 1538, 1588, {"build_cost": -0.25, "prestige": 0.5}),
    ("tur_sokollu", "TUR", "Sokollu Mehmed Pascha", "adm", 1565, 1579, {"adm": 1, "dip": 1}),
    ("pol_olesnicki", "POL", "Zbigniew Oleśnicki", "dip", 1444, 1455, {"dip": 1, "unrest": -0.5}),
    ("pol_zamoyski", "POL", "Jan Zamoyski", "adm", 1578, 1605, {"adm": 1, "combat": 0.03}),
    ("pol_zolkiewski", "POL", "Stanisław Żółkiewski", "mil", 1600, 1620, {"combat": 0.08}),
    ("bur_rolin", "BUR", "Nicolas Rolin", "adm", 1444, 1462, {"income": 0.08, "unrest": -0.25}),
    ("bur_croy", "BUR", "Antoine de Croÿ", "dip", 1444, 1465, {"dip": 1, "prestige": -0.25}),
    ("bur_marche", "BUR", "Olivier de la Marche", "dip", 1465, 1500, {"prestige": 1.0, "ae_decay": 0.05}),
]

# Investment companies: (id, name, year, effects, text). Cost = months of income (min. company_min_gold).
COMPANIES = [
    ("lombarden", "Lombardische Bankiers", 1444, {"income": 0.08, "prestige": -0.25, "estate_klerus": -10},
     "Kredit gegen hohe Zinsen. Das Volk hält Wucher für eine Sünde."),
    ("kaufmannsgilde", "Kaufmannsgilde", 1444, {"trade": 0.12, "unrest": 0.25, "estate_buerger": 10},
     "Die Gilde handelt gut, verlangt aber Privilegien, die die Zünfte erzürnen."),
    ("bergbau", "Bergbaugesellschaft", 1444, {"production": 0.1, "manpower": -0.05},
     "Erzgruben und Hütten binden viele Arbeiter."),
    ("tuchverleger", "Tuchverleger", 1460, {"production": 0.08, "trade": 0.04},
     "Verleger liefern Wolle an Landweber und verkaufen das Tuch."),
    ("bauhuette", "Bauhütte", 1460, {"build_cost": -0.15, "develop_cost": -0.05},
     "Steinmetze und Baumeister ziehen von Baustelle zu Baustelle."),
    ("geschuetzgiesserei", "Geschützgießerei", 1480, {"siege": 0.2, "combat": 0.03, "income": -0.02},
     "Bronze ist teuer, aber die Mauern deiner Feinde fallen."),
    ("salzkontor", "Salzkontor", 1480, {"tax": 0.06, "trade": 0.04},
     "Ein Monopol auf das weiße Gold."),
    ("fernhandel", "Fernhandelskompanie", 1550, {"trade": 0.2, "ae_gen": 0.05},
     "Eine Kompanie mit eigenem Heer, die sich wenig um Nachbarn schert."),
    ("wechselbank", "Wechselbank", 1580, {"income": 0.06, "develop_cost": -0.08},
     "Bargeldloser Zahlungsverkehr nach Amsterdamer Vorbild."),
]

# National companies: (id, tag, name, year, effects, text)
NATIONAL_COMPANIES = [
    ("fra_lyon", "FRA", "Seidenmanufaktur von Lyon", 1466, {"production": 0.15, "tax": -0.03}, "Ludwig XI. holt italienische Seidenweber ins Land."),
    ("eng_muscovy", "ENG", "Muscovy Company", 1555, {"trade": 0.2, "prestige": -0.25}, "Händler auf der Nordroute nach Moskau."),
    ("spa_mesta", "SPA", "Honrado Concejo de la Mesta", 1444, {"production": 0.12, "develop_cost": 0.05}, "Die Schafzüchter dürfen das ganze Land beweiden."),
    ("boh_kuttenberger_muenze", "BOH", "Kuttenberger Münze", 1444, {"income": 0.1, "unrest": 0.25}, "Der Prager Groschen ist in ganz Mitteleuropa begehrt."),
    ("hab_fugger", "HAB", "Handelshaus Fugger", 1490, {"income": 0.15, "ae_gen": 0.05}, "Jakob Fugger leiht dem Kaiser Geld, und alle wissen davon."),
    ("rus_stroganow", "RUS", "Handelshaus Stroganow", 1558, {"production": 0.15, "trade": 0.05}, "Salz und Pelze vom Ural."),
    ("nap_monte", "NAP", "Monte di Pietà", 1539, {"unrest": -0.75, "income": 0.05}, "Ein Pfandhaus für die Armen von Neapel."),
    ("tur_bursa", "TUR", "Bedesten von Bursa", 1444, {"trade": 0.15, "tax": 0.03}, "Die gedeckte Seidenhalle am Ende der Karawanenroute."),
    ("pol_danzig", "POL", "Danziger Kornbörse", 1466, {"trade": 0.18, "adm": -1}, "Der Getreidehandel macht die Szlachta reich und eigensinnig."),
    ("bur_beurse", "BUR", "Brügger Beurse", 1444, {"trade": 0.12, "income": 0.05}, "Die erste Börse Europas, im Haus der Familie van der Beurse."),
]

# Laws: (id, name, power type to change, [(option_id, name, requires_tech or "", effects, text)]); first option is the default
LAWS = [
    ("wirtschaft", "Wirtschaftsordnung", "adm", [
        ("grundherrschaft", "Grundherrschaft", "", {}, "Abgaben der Bauern an ihre Herren."),
        ("staedtefoerderung", "Städteförderung", "", {"production": 0.08, "manpower": -0.05, "estate_buerger": 15, "estate_adel": -5}, "Bürger statt Bauern."),
        ("merkantilismus", "Merkantilismus", "adm_verlag", {"production": 0.12, "tax": 0.04, "trade": -0.1, "estate_buerger": 5}, "Eigene Waren schützen, fremde verzollen."),
        ("freihandel", "Freihandel", "dip_boersen", {"trade": 0.15, "tax": -0.05, "estate_buerger": 15}, "Niedrige Zölle locken Kaufleute an."),
        ("kriegswirtschaft", "Kriegswirtschaft", "", {"maintenance": -0.15, "force_limit": 2, "production": -0.1, "unrest": 0.5, "estate_buerger": -15}, "Alles für die Front."),
    ]),
    ("heer", "Heeresverfassung", "mil", [
        ("lehnsheer", "Lehnsheer", "", {}, "Die Vasallen stellen Truppen im Kriegsfall."),
        ("soeldner", "Söldnerheere", "", {"force_limit": 3, "maintenance": 0.1, "manpower": -0.1, "army_power": -0.05}, "Geld statt Blut, solange die Kasse reicht."),
        ("landesaufgebot", "Allgemeines Landesaufgebot", "", {"manpower": 0.25, "combat": -0.04, "unrest": 0.5, "estate_adel": -10, "army_power_regen": 0.2}, "Jeder wehrfähige Mann wird gemustert."),
        ("stehendes_heer", "Stehendes Heer", "mil_kriegskanzlei", {"combat": 0.08, "maintenance": 0.1, "estate_adel": -10, "army_power": 0.1}, "Gedrillte Berufssoldaten, auch im Frieden besoldet."),
    ]),
    ("staat", "Staatsaufbau", "adm", [
        ("feudal", "Feudalordnung", "", {}, "Der König ist Erster unter den Großen."),
        ("staendestaat", "Ständestaat", "", {"unrest": -1.0, "tax": 0.05, "tech_cost": 0.05, "estate_adel": 15, "estate_buerger": 10}, "Die Stände bewilligen Steuern und blockieren Neuerungen."),
        ("zentralisierung", "Zentralisierung", "adm_beamte", {"adm": 1, "coring": -0.15, "unrest": 0.75, "estate_adel": -20}, "Beamte der Krone ersetzen den Landadel."),
        ("absolutismus", "Absolutismus", "adm_absolut", {"adm": 1, "mil": 1, "unrest": 1.0, "prestige": 0.5, "estate_adel": -25, "estate_buerger": -5}, "L'État, c'est moi."),
    ]),
    ("kirche", "Kirchenpolitik", "dip", [
        ("tradition", "Alte Ordnung", "", {}, "Die Kirche lebt nach ihren alten Rechten."),
        ("toleranz", "Toleranz", "", {"unrest": -0.5, "religious_unrest": -0.75, "prestige": -0.5, "estate_klerus": -15, "estate_buerger": 10}, "Andersgläubige bleiben unbehelligt."),
        ("glaubenseifer", "Glaubenseifer", "", {"prestige": 1.0, "combat": 0.03, "ae_gen": 0.1, "conversion": 0.5, "religious_unrest": 0.25, "estate_klerus": 20, "estate_buerger": -5}, "Für den wahren Glauben, gegen die Ketzer."),
        ("saekularisierung", "Säkularisierung", "adm_kirchenreform", {"income": 0.08, "unrest": 1.0, "prestige": -0.5, "estate_klerus": -30}, "Kirchengüter fallen an die Krone."),
    ]),
    ("aussen", "Außenpolitik", "dip", [
        ("zurueckhaltung", "Zurückhaltung", "", {}, "Man hält sich aus fremden Händeln heraus."),
        ("expansion", "Expansionsdrang", "", {"coring": -0.1, "prestige": 0.5, "ae_gen": 0.15, "estate_adel": 10}, "Neue Länder für die Krone, die Nachbarn sehen es mit Sorge."),
        ("heiratspolitik", "Heiratspolitik", "dip_heiratspolitik", {"dip": 0.5, "prestige": 0.5, "manpower": -0.05, "estate_adel": -5}, "Bella gerant alii, tu felix Austria nube."),
        ("gleichgewicht", "Gleichgewichtspolitik", "dip_kongresse", {"ae_decay": 0.15, "ae_gen": -0.05, "force_limit": -1}, "Keine Macht soll übermächtig werden, auch die eigene nicht."),
    ]),
]

# Estates: (id, name, text, loyal effects (>= 60), angry effects (< 30))
ESTATES = [
    ("adel", "Adel", "Grundherren und Ritter. Stellen Truppen und Offiziere.",
     {"manpower": 0.1, "combat": 0.03}, {"unrest": 1.0, "manpower": -0.15}),
    ("klerus", "Klerus", "Bischöfe, Klöster und Orden. Halten das Volk ruhig und lehren an den Universitäten.",
     {"unrest": -0.25, "prestige": 0.5}, {"unrest": 1.0, "tech_cost": 0.05}),
    ("buerger", "Bürger", "Kaufleute und Handwerker der Städte. Zahlen Steuern und treiben Handel.",
     {"tax": 0.05, "production": 0.05}, {"trade": -0.1, "unrest": 0.5}),
]

# Budget sliders (EU5-like, simple): (id, name, text, step names, effects per step away from "normal",
# gold cost per step as share of monthly income). Step 2 is neutral, so default nations are unchanged.
BUDGET = [
    ("steuern", "Steuerdruck", "Wie hart die Steuereintreiber zugreifen.",
     ["sehr mild", "mild", "normal", "hoch", "erdrückend"],
     {"tax": 0.1, "unrest": 0.4, "estate_buerger": -6, "estate_adel": -3}, 0.0),
    ("hof", "Hofhaltung", "Feste, Gesandte und Mäzene. Kostet Gold, bringt Ansehen und einen zufriedenen Adel.",
     ["karg", "sparsam", "normal", "prächtig", "verschwenderisch"],
     {"prestige": 1.0, "dip": 0.5, "estate_adel": 5}, 0.04),
    ("heer", "Militärbudget", "Sold, Ausrüstung und Drill der Armee.",
     ["minimal", "knapp", "normal", "großzügig", "Kriegsfuß"],
     {"maintenance": 0.15, "combat": 0.04, "manpower": 0.05, "army_power_regen": 0.25}, 0.0),
    ("bildung", "Forschung", "Universitäten, Gelehrte und Druckereien.",
     ["keine", "wenig", "normal", "gefördert", "Akademien"],
     {"tech_cost": -0.07, "adm": 0.25, "estate_klerus": 3}, 0.04),
]

# Estate crisis events, fired by government.gd when an estate is angry (id suffix = estate id)
ESTATE_EVENTS = {
    "adel": ("Die Barone murren", "Der Adel klagt über verlorene Rechte und droht, dem Aufgebot fernzubleiben.", "knights", [
        ("Alte Privilegien bestätigen.", {"estate": {"adel": 25}, "adm": -30}),
        ("Ein Turnier und reiche Geschenke.", {"estate": {"adel": 15}, "gold": -40}),
        ("Die Rädelsführer verhaften.", {"estate": {"adel": -10}, "manpower": -2, "prestige": 5}),
    ]),
    "klerus": ("Unmut in den Klöstern", "Die Bischöfe predigen gegen die Krone und verlangen ihre alten Rechte zurück.", "church", [
        ("Kirchengüter zurückgeben.", {"estate": {"klerus": 25}, "gold": -50}),
        ("Eine Stiftung für den Dom.", {"estate": {"klerus": 15}, "dip": -25}),
        ("Die Prediger zum Schweigen bringen.", {"estate": {"klerus": -10}, "prestige": -5, "mil": -20}),
    ]),
    "buerger": ("Die Zünfte begehren auf", "Die Städte verweigern neue Steuern, bis ihre Beschwerden gehört werden.", "city", [
        ("Stadtrechte erweitern.", {"estate": {"buerger": 25}, "adm": -30}),
        ("Steuern für ein Jahr erlassen.", {"estate": {"buerger": 15}, "gold": -50}),
        ("Die Stadttore besetzen.", {"estate": {"buerger": -10}, "we": 2, "prestige": 3}),
    ]),
}

# State reforms (EU4-like tiers): (tier id, name, year, options). One option per tier, bought once with
# administrative power (reform_cost + reform_cost_step x tier index), every option is a trade-off.
REFORMS = [
    ("grundlage", "Herrschaftsgrundlage", 1444, [
        ("lehnswesen", "Lehnswesen", {"manpower": 0.15, "tax": -0.05, "estate_adel": 5}, "Vasallen stellen Truppen statt Steuern."),
        ("domaenen", "Domänenwirtschaft", {"tax": 0.1, "manpower": -0.1}, "Die Krone lebt von ihren eigenen Gütern."),
        ("staedtebund", "Städtische Freiheiten", {"trade": 0.1, "estate_buerger": 10, "force_limit": -2}, "Die Städte regieren sich selbst und zahlen dafür."),
    ]),
    ("verwaltung", "Verwaltung", 1480, [
        ("hofrat", "Hofrat", {"adm": 1, "estate_adel": -5}, "Gelehrte Räte statt Hochadel am Hof."),
        ("landtage", "Landtage", {"estate_adel": 10, "estate_buerger": 10, "adm": -0.5, "tax": 0.05}, "Die Stände bewilligen Steuern und reden mit."),
        ("kreisordnung", "Kreisordnung", {"unrest": -0.5, "build_cost": 0.1}, "Amtleute in jedem Kreis halten Ordnung."),
    ]),
    ("heerwesen", "Heerwesen", 1520, [
        ("kriegsrat", "Hofkriegsrat", {"combat": 0.05, "army_power": 0.05, "maintenance": 0.05}, "Ein ständiger Rat plant die Feldzüge."),
        ("werbewesen", "Werbewesen", {"force_limit": 3, "army_power": -0.05}, "Werber füllen die Reihen, doch nicht jeder will kämpfen."),
        ("miliz", "Landesdefension", {"manpower": 0.2, "army_power_regen": 0.25, "combat": -0.03}, "Jede Gemeinde stellt geübte Männer."),
    ]),
    ("staatsidee", "Staatsidee", 1570, [
        ("gottesgnaden", "Gottesgnadentum", {"prestige": 1.0, "unrest": -0.5, "estate_klerus": 10, "tech_cost": 0.05}, "Der Herrscher regiert von Gottes Gnaden."),
        ("staatsraison", "Staatsräson", {"ae_decay": 0.2, "dip": 1, "estate_klerus": -10}, "Was dem Staat nützt, ist recht."),
        ("gemeinwohl", "Gemeines Bestes", {"production": 0.1, "estate_buerger": 10, "estate_adel": -10}, "Der Fürst als erster Diener des Landes."),
    ]),
    ("herrschaft", "Herrschaftsform", 1610, [
        ("alleinherrschaft", "Alleinherrschaft der Krone", {"adm": 1, "force_limit": 2, "estate_adel": -10, "estate_buerger": -5}, "Der König regiert ohne Stände, die Stände murren."),
        ("parlament", "Parlamentarische Krone", {"tax": 0.1, "unrest": -0.5, "estate_buerger": 15, "adm": -0.5}, "Ein Parlament bewilligt Steuern und redet mit."),
        ("aufgeklaert", "Aufgeklärte Herrschaft", {"tech_cost": -0.05, "production": 0.05, "estate_klerus": -15}, "Vernunft statt Tradition, zum Ärger der Kirche."),
    ]),
]

# Age goals (EU4-like age objectives): every age has three goals that only count while the age lasts.
# Each reached goal gives a permanent reward, two of three also the age's triumph.
# (age id, name, from, to, [(goal id, name, text, condition, reward)], (triumph name, reward))
# Conditions are evaluated in Government.goal_progress.
AGES = [
    ("renaissance", "Renaissance", 1444, 1499, [
        ("humanisten", "Humanisten", "10 Technologien erforschen.", {"techs": 10}, {"tech_cost": -0.03}),
        ("gelehrtenhof", "Hof der Gelehrten", "3 Berater gleichzeitig im Rat.", {"advisors": 3}, {"prestige": 0.5}),
        ("bankhaeuser", "Bankhäuser", "Eine Kompanie auf Stufe 3 ausbauen.", {"company_level": 3}, {"income": 0.03}),
    ], ("Renaissancefürst", {"adm": 0.5})),
    ("entdeckungen", "Entdeckungen", 1500, 1549, [
        ("weltkenntnis", "Weltkenntnis", "8 Diplomatie-Technologien erforschen.", {"tech_cat": ["dip", 8]}, {"trade": 0.05}),
        ("reformer", "Reformer", "2 Staatsreformen einführen.", {"reforms": 2}, {"unrest": -0.25}),
        ("grossmacht", "Großmacht", "250 Entwicklung erreichen.", {"dev": 250}, {"force_limit": 2}),
    ], ("Weltgewandt", {"dip": 0.5})),
    ("reformation", "Reformation", 1550, 1599, [
        ("staendefrieden", "Ständefrieden", "2 Stände gleichzeitig treu.", {"estates_loyal": 2}, {"prestige": 0.5}),
        ("glaubensfest", "Glaubensfest", "90 % deiner Entwicklung teilen deinen Glauben.", {"faith_share": 90}, {"religious_unrest": -0.25}),
        ("kriegskunst", "Kriegskunst", "14 Militär-Technologien erforschen.", {"tech_cat": ["mil", 14]}, {"army_power": 0.05}),
    ], ("Glaubensstreiter", {"mil": 0.5})),
    ("absolutismus", "Absolutismus", 1600, 1821, [
        ("staatsraison", "Vollendeter Staat", "Vier Stufen der Staatsreformen besetzen.", {"reforms": 4}, {"adm": 0.5}),
        ("gelehrtenstaat", "Gelehrtenstaat", "45 Technologien erforschen.", {"techs": 45}, {"tech_cost": -0.05}),
        ("ruhm", "Ewiger Ruhm", "50 Prestige erreichen.", {"prestige": 50}, {"income": 0.03}),
    ], ("Sonnenkönig", {"combat": 0.05})),
]

# Imperial reforms (Holy Roman Empire light): the emperor passes them in order with imperial authority,
# if more than half of the other electors like him. (id, name, year, authority, emperor effects,
# member effects, text). "landfriede" also forbids wars between members (Government.landfriede).
EMPIRE_REFORMS = [
    ("reichstag", "Reichstag", 1450, 40, {"prestige": 1.0, "dip": 0.5}, {"unrest": -0.2},
     "Fürsten und Städte beraten regelmäßig mit dem Kaiser."),
    ("kammergericht", "Reichskammergericht", 1470, 60, {"adm": 0.5}, {"ae_decay": 0.1, "estate_buerger": 3},
     "Streit zwischen Reichsständen wird vor Gericht statt im Feld entschieden."),
    ("pfennig", "Gemeiner Pfennig", 1490, 80, {"tax": 0.1, "income": 0.03}, {"tax": -0.02},
     "Eine Reichssteuer füllt die kaiserliche Kasse, die Fürsten zahlen mit."),
    ("reichskreise", "Reichskreise", 1510, 100, {"manpower": 0.1, "force_limit": 2}, {"manpower": 0.1, "army_power_regen": 0.1},
     "Zehn Kreise stellen gemeinsam Truppen für die Verteidigung des Reiches."),
    ("landfriede", "Ewiger Landfriede", 1530, 120, {"prestige": 1.0, "army_power": 0.05}, {"unrest": -0.25},
     "Fehde ist verboten: Reichsmitglieder dürfen einander nicht mehr den Krieg erklären."),
]

GOV_FORMS = {
    "default": "Feudalmonarchie",
    "POL": "Wahlmonarchie", "VEN": "Kaufmannsrepublik", "GEN": "Kaufmannsrepublik", "PAP": "Theokratie",
    "TUR": "Sultanat", "TEU": "Ordensstaat", "LIV": "Ordensstaat", "HSA": "Städtebund", "NOV": "Stadtrepublik",
    "TUS": "Stadtrepublik", "SWI": "Eidgenossenschaft", "HAB": "Erzherzogtum", "BUR": "Herzogtum", "MLO": "Herzogtum",
    "SAV": "Herzogtum", "RUS": "Großfürstentum", "LIT": "Großfürstentum", "CRI": "Khanat", "KAZ": "Khanat",
    "BYZ": "Kaiserreich", "KOL": "Kurfürstliches Erzstift", "PAL": "Kurfürstentum", "SAX": "Kurfürstentum",
    "BRA": "Kurfürstentum", "NUR": "Freie Reichsstadt", "BRI": "Herzogtum", "BAV": "Herzogtum",
    "MAM": "Sultanat", "TUN": "Sultanat", "TLE": "Sultanat", "MOR": "Sultanat", "KNI": "Ordensstaat", "TRE": "Kaiserreich",
    "KAR": "Beylik", "CND": "Beylik", "DUL": "Beylik", "AKK": "Stammesföderation", "QAR": "Stammesföderation",
    "CIR": "Stammesföderation",
}

# Every form of government has a small, permanent trade-off (part of the "gov" bonus source).
# Ruler and heir traits: (id, name, weight, effects). A ruler has at most one; it counts as a gov source.
TRAITS = [
    ("baumeister", "Baumeister", 3, {"build_cost": -0.1}),
    ("feldherr", "Feldherr", 3, {"combat": 0.05, "army_power": 0.05}),
    ("kaufmann", "Kaufmannsgeist", 3, {"trade": 0.1}),
    ("fromm", "Fromm", 3, {"conversion": 0.25, "estate_klerus": 5}),
    ("diplomat", "Geschickter Diplomat", 3, {"ae_gen": -0.1, "ae_decay": 0.1}),
    ("sparsam", "Sparsam", 3, {"maintenance": -0.05, "income": 0.02}),
    ("gelehrt", "Gelehrt", 3, {"tech_cost": -0.05}),
    ("gerecht", "Gerecht", 3, {"unrest": -0.5}),
    ("leutselig", "Leutselig", 3, {"estate_buerger": 5, "estate_adel": 5}),
    ("prunk", "Prunksüchtig", 2, {"prestige": 1, "income": -0.03}),
    ("grausam", "Grausam", 2, {"unrest": 0.5, "coring": -0.15}),
    ("zaghaft", "Zaghaft", 2, {"combat": -0.03, "ae_gen": -0.05}),
    ("verschwender", "Verschwender", 2, {"income": -0.05, "estate_adel": 5}),
    ("misstrauisch", "Misstrauisch", 2, {"estate_adel": -5, "unrest": -0.25}),
]

FORM_EFFECTS = {
    "Feudalmonarchie": {"manpower": 0.1, "estate_adel": 5},
    "Wahlmonarchie": {"dip": 0.5, "estate_adel": 15, "tax": -0.05},
    "Kaufmannsrepublik": {"trade": 0.15, "estate_buerger": 10, "manpower": -0.1},
    "Stadtrepublik": {"trade": 0.1, "production": 0.05, "force_limit": -1},
    "Städtebund": {"trade": 0.15, "estate_buerger": 10, "force_limit": -2},
    "Eidgenossenschaft": {"combat": 0.05, "manpower": 0.15, "trade": -0.05},
    "Freie Reichsstadt": {"production": 0.1, "estate_buerger": 10, "force_limit": -1},
    "Theokratie": {"conversion": 0.5, "estate_klerus": 10, "manpower": -0.1},
    "Ordensstaat": {"combat": 0.05, "estate_klerus": 5, "tax": -0.05},
    "Kurfürstliches Erzstift": {"conversion": 0.25, "estate_klerus": 10, "force_limit": -1},
    "Sultanat": {"force_limit": 2, "manpower": 0.1, "estate_adel": -5},
    "Beylik": {"manpower": 0.1, "army_power_regen": 0.1, "tax": -0.05},
    "Stammesföderation": {"manpower": 0.15, "army_power_regen": 0.1, "tax": -0.1},
    "Khanat": {"army_power_regen": 0.2, "manpower": 0.1, "tax": -0.1},
    "Kaiserreich": {"prestige": 0.5, "adm": 0.5, "unrest": 0.25},
    "Erzherzogtum": {"dip": 0.5, "estate_adel": 5},
    "Herzogtum": {"tax": 0.05, "estate_adel": 5},
    "Großfürstentum": {"manpower": 0.15, "tech_cost": 0.03},
    "Kurfürstentum": {"prestige": 0.25, "tax": 0.05, "estate_adel": 5},
    "Absolute Monarchie": {"adm": 0.5, "tax": 0.1, "estate_adel": -10, "unrest": 0.25},
}

# Changing the form of government (government.gd form_change_*): families, and which family may switch to what.
FORM_FAMILY = {
    "monarchie": ["Feudalmonarchie", "Wahlmonarchie", "Kaiserreich", "Erzherzogtum", "Herzogtum", "Großfürstentum",
                  "Kurfürstentum", "Sultanat", "Absolute Monarchie"],
    "republik": ["Kaufmannsrepublik", "Stadtrepublik", "Städtebund", "Eidgenossenschaft", "Freie Reichsstadt"],
    "kirche": ["Theokratie", "Ordensstaat", "Kurfürstliches Erzstift"],
    "stamm": ["Beylik", "Stammesföderation", "Khanat"],
}
# (target form, families allowed to switch to it, from year, text[, min provinces])
FORM_CHANGES = [
    ("Feudalmonarchie", ["monarchie", "stamm"], 1444, "Der Adel trägt die Krone, die Krone schützt den Adel."),
    ("Wahlmonarchie", ["monarchie"], 1444, "Die Großen des Reiches wählen den König. Mehr Mitsprache, weniger Steuern."),
    ("Absolute Monarchie", ["monarchie"], 1580, "Der Herrscher regiert ohne Stände: mehr Steuern und Verwaltung, der Adel grollt.", 10),
    ("Kaufmannsrepublik", ["republik"], 1444, "Die reichen Handelshäuser lenken den Staat."),
    ("Stadtrepublik", ["republik"], 1444, "Räte und Zünfte regieren gemeinsam."),
    ("Theokratie", ["kirche"], 1444, "Die Kirche regiert unmittelbar."),
    ("Stammesföderation", ["stamm"], 1444, "Die Stämme regieren sich selbst, vereint im Krieg."),
    ("Khanat", ["stamm"], 1444, "Ein Khan herrscht über die Reiterheere."),
]


def build():
    nations = json.load(open(os.path.join(ROOT, "data/nations.json")))
    techs = []
    branches = []
    ids = set()
    for cat, brs in TREE.items():
        for bid, bname, lst in brs:
            assert len(lst) == len(BRANCH_YEARS), bid
            branches.append({"id": bid, "cat": cat, "name": bname})
            prev = ""
            for i, (tid, name, eff) in enumerate(lst):
                assert tid not in ids, tid
                ids.add(tid)
                t = {"id": tid, "cat": cat, "branch": bid, "name": name, "year": BRANCH_YEARS[i], "effects": eff}
                if prev:
                    t["req"] = [prev]
                techs.append(t)
                prev = tid
    special = []
    for tag, lst in SPECIAL.items():
        assert nations[tag].get("playable"), tag
        for tid, cat, name, year, req, eff, text in lst:
            assert req in ids, req
            assert tid not in ids, tid
            ids.add(tid)
            special.append({"id": tid, "tag": tag, "cat": cat, "name": name, "year": year, "req": [req], "effects": eff, "text": text})
    for tag in nations:
        if nations[tag].get("playable"):
            assert tag in SPECIAL, "special techs missing for " + tag
    out = {"_doc": "Generated by tools/content/tech_gov.py, edit there.", "early_years": 20, "ahead_years": 15, "ahead_penalty": 0.05, "ai_ahead_reserve": 0.5, "spread_max": 0.3, "spread_factor": 0.5,
           "branches": branches, "techs": techs, "special": special}
    json.dump(out, open(os.path.join(ROOT, "data/techs.json"), "w"), ensure_ascii=False, indent=1)

    adv = [{"id": a, "name": n, "type": t, "effects": e} for a, n, t, e in ADVISORS]
    for a, tag, n, t, y0, y1, e in NATIONAL_ADVISORS:
        assert tag in nations, tag
        adv.append({"id": a, "tag": tag, "name": n, "type": t, "from": y0, "to": y1, "effects": e})
    comp = [{"id": c, "name": n, "year": y, "effects": e, "text": tx} for c, n, y, e, tx in COMPANIES]
    for c, tag, n, y, e, tx in NATIONAL_COMPANIES:
        comp.append({"id": c, "tag": tag, "name": n, "year": y, "effects": e, "text": tx})
    laws = []
    for lid, name, power, opts in LAWS:
        lo = []
        for oid, oname, req, eff, tx in opts:
            assert req == "" or req in ids, req
            o = {"id": oid, "name": oname, "effects": eff, "text": tx}
            if req:
                o["req"] = req
            lo.append(o)
        laws.append({"id": lid, "name": name, "power": power, "options": lo})
    for f in ["Kaufmannsrepublik", "Stadtrepublik", "Städtebund", "Theokratie", "Ordensstaat", "Wahlmonarchie"]:
        assert f in FORM_EFFECTS, f
    for t in GOV_FORMS:
        assert t == "default" or t in nations, t
        assert GOV_FORMS[t] in FORM_EFFECTS, GOV_FORMS[t]
    fams = [f for v in FORM_FAMILY.values() for f in v]
    assert sorted(fams) == sorted(FORM_EFFECTS), set(FORM_EFFECTS) ^ set(fams)
    for f, frm, y, tx, *_ in FORM_CHANGES:
        assert f in FORM_EFFECTS and all(x in FORM_FAMILY for x in frm), f
    gov = {"_doc": "Generated by tools/content/tech_gov.py, edit there.",
           "advisor_slots": 3, "advisor_cost": 75, "advisor_max_skill": 3, "advisor_skill_step": 0.5,
           "advisor_promote_mult": 1.5, "advisor_retire_years": 20, "advisor_retire_chance": 0.15,
           "traits": [{"id": i, "name": nm, "weight": w, "effects": e} for i, nm, w, e in TRAITS], "trait_none_chance": 0.2,
           "heir_edu_cost": 60, "heir_edu_step": 0.5, "ai_heir_share": 0.6, "heir_disinherit_prestige": 25, "heir_disinherit_years": 10,
           "heir_start_age_max": 12, "regency_age": 15,
           "regency_effects": {"estate_adel": 10, "unrest": 0.5, "prestige": -1, "ae_gen": 0.1},
           "elective_forms": ["Kaufmannsrepublik", "Stadtrepublik", "Städtebund", "Theokratie", "Ordensstaat", "Wahlmonarchie"],
           "ai_promote_chance": 0.3, "company_slots": 2, "company_months": 18, "company_min_gold": 60,
           "invest_max_level": 5, "invest_step": 0.5, "invest_cost_mult": 0.5,
           "estate_drift": 0.03, "estate_loyal": 65, "estate_angry": 30, "estate_crisis": 25,
           "estate_crisis_chance": 0.35, "estate_crisis_years": 4, "concession_months": 6, "concession_min_gold": 30,
           "concession_amount": 20, "concession_cooldown_years": 5,
           "estates": [{"id": i, "name": nm, "text": tx, "loyal": lo, "angry": an} for i, nm, tx, lo, an in ESTATES],
           "estate_events": [{"id": "estate_crisis_" + k, "title": v[0], "text": v[1], "image": v[2],
                              "options": [{"text": t, "effects": e} for t, e in v[3]]} for k, v in ESTATE_EVENTS.items()],
           "budget": [{"id": i, "name": nm, "text": tx, "steps": st, "per_step": e, "cost": c}
                      for i, nm, tx, st, e, c in BUDGET],
           "budget_default": 2,
           "reforms": [{"id": i, "name": nm, "year": y, "options": [{"id": oi, "name": on, "effects": oe, "text": ot}
                                                                for oi, on, oe, ot in opts]} for i, nm, y, opts in REFORMS],
           "reform_cost": 100, "reform_cost_step": 50, "reform_change_years": 25,
           "empire": {"authority_start": 10, "authority_max": 150, "authority_base": 2.0, "authority_per_member": 0.15,
                      "authority_member_war": 3.0, "authority_new_emperor": 0.75,
                      "reforms": [{"id": i, "name": nm, "year": y, "cost": c, "emperor": ee, "members": me, "text": tx}
                                  for i, nm, y, c, ee, me, tx in EMPIRE_REFORMS]},
           "ages": [{"id": i, "name": nm, "from": y0, "to": y1,
                     "goals": [{"id": gi, "name": gn, "text": gt, "cond": gc, "reward": gr} for gi, gn, gt, gc, gr in goals],
                     "triumph": {"name": tr[0], "reward": tr[1]}} for i, nm, y0, y1, goals, tr in AGES],
           "age_triumph_goals": 2,
           "law_cost": 60, "law_cooldown_years": 10, "forms": GOV_FORMS, "form_effects": FORM_EFFECTS,
           "form_family": FORM_FAMILY, "form_changes": [{"form": c[0], "from": c[1], "year": c[2], "text": c[3], "min_provinces": c[4] if len(c) > 4 else 0}
                            for c in FORM_CHANGES],
           "ai_keep_forms": ["Sultanat", "Kaiserreich", "Kurfürstentum", "Erzherzogtum", "Kurfürstliches Erzstift",
                             "Eidgenossenschaft", "Freie Reichsstadt", "Ordensstaat"], "ai_form_chance": 0.1,
           "form_change_cost": 250, "form_change_prestige": 20, "form_change_years": 40,
           "advisors": adv, "companies": comp, "laws": laws}
    json.dump(gov, open(os.path.join(ROOT, "data/government.json"), "w"), ensure_ascii=False, indent=1)
    print("techs %d + %d special, advisors %d, companies %d, laws %d" % (len(techs), len(special), len(adv), len(comp), len(laws)))


if __name__ == "__main__":
    build()
