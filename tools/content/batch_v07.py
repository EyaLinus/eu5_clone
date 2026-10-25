"""Content batch v0.7: event chains and missions for Italy (VEN, MLO, PAP, TUS) and Scandinavia (DAN),
plus generic late-era events (1550+).
Usage: python3 tools/content/batch_v07.py  (idempotent, keeps the one-line-per-entry layout)"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


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


def M(id, title, desc, require, reward, after=None):
    m = {"id": id}
    if after:
        m["after"] = after
    m.update({"title": title, "desc": desc, "require": require, "reward": reward})
    return m


# owns-keys become starting claims, so "owns" is only used for a nation's own core lands
MISSIONS = {
"VEN": [
  M("ven_terraferma", "Die Terraferma", "Verona und Friaul schützen die Lagune vom Festland her.",
    {"year_min": 1450, "at_peace": True, "owns": ["verona", "friuli"]}, {"mods": {"manpower": 0.05}, "adm": 30}),
  M("ven_dalmatia", "Der Golf von Venedig", "Dalmatien bleibt venezianisch, die Adria ist unser Meer.",
    {"owns": ["dalmatia"], "tech": {"dip": 6}}, {"mods": {"income": 0.05}, "prestige": 10}),
  M("ven_lombardy", "Gegen Mailand", "Bergamo, Brescia und vielleicht Mailand selbst.",
    {"owns_any": ["milan", "parma"]}, {"prestige": 15, "dip": 30}, after="ven_terraferma"),
  M("ven_arsenal", "Das Arsenal", "Eine Galeere pro Tag, die größte Werft der Welt.",
    {"tech": {"mil": 8}, "regs": 15}, {"mods": {"combat": 0.05}}),
],
"MLO": [
  M("mlo_sforza", "Das Haus Sforza", "Das Herzogtum sichern, Parma inklusive.",
    {"year_min": 1450, "at_peace": True, "owns": ["milan", "parma"]}, {"prestige": 10, "adm": 30}),
  M("mlo_genoa", "Ein Hafen für Mailand", "Genua öffnet die Lombardei zum Meer.",
    {"owns_any": ["genoa"]}, {"mods": {"income": 0.05}}, after="mlo_sforza"),
  M("mlo_leonardo", "Der Hof des Moro", "Künstler und Ingenieure am Mailänder Hof.",
    {"tech": {"adm": 6}, "min_dev": 30}, {"prestige": 15, "dev_capital": 2}),
],
"PAP": [
  M("pap_romagna", "Die Romagna", "Bologna und Ancona bleiben beim Heiligen Stuhl.",
    {"year_min": 1450, "owns": ["rome", "bologna", "ancona"]}, {"prestige": 15, "mods": {"manpower": 0.05}}),
  M("pap_st_peter", "Der neue Petersdom", "Die größte Kirche der Christenheit.",
    {"tech": {"adm": 8}, "gold_min": 200}, {"prestige": 25, "dev_capital": 2}),
  M("pap_legations", "Die Legationen", "Ferrara, Parma oder Siena für den Kirchenstaat.",
    {"owns_any": ["parma", "siena"]}, {"dip": 40}, after="pap_romagna"),
],
"TUS": [
  M("tus_siena", "Siena unterwerfen", "Die alte Rivalin muss sich Florenz beugen.",
    {"owns": ["siena"], "year_min": 1450}, {"prestige": 10, "mods": {"income": 0.03}}),
  M("tus_medici_bank", "Die Bank der Medici", "Filialen in Brügge, London, Rom und Genf.",
    {"tech": {"dip": 6}, "gold_min": 150}, {"mods": {"income": 0.05}, "dip": 30}),
  M("tus_grand_duchy", "Das Großherzogtum", "Florenz wird zur Toskana.",
    {"owns_any": ["genoa", "corsica", "bologna"]}, {"prestige": 20}, after="tus_siena"),
],
"DAN": [
  M("dan_kalmar", "Die Union erhalten", "Dänemark, Norwegen und Schweden unter einer Krone.",
    {"year_min": 1460, "owns": ["copenhagen", "oslo", "stockholm"]}, {"prestige": 20, "mods": {"manpower": 0.05}}),
  M("dan_sound", "Der Sundzoll", "Helsingør und Schonen kontrollieren den Weg in die Ostsee.",
    {"owns": ["copenhagen", "scania"], "tech": {"dip": 6}}, {"mods": {"income": 0.05}}),
  M("dan_dithmarschen", "Holstein und Dithmarschen", "Die Bauernrepublik im Süden.",
    {"owns_any": ["hamburg", "bremen"]}, {"dip": 30, "prestige": 10}, after="dan_sound"),
  M("dan_baltic", "Dominium maris Baltici", "Ein Brückenkopf an der Ostseeküste.",
    {"owns_any": ["riga", "reval", "pomerania", "prussia"]}, {"mods": {"combat": 0.03}, "prestige": 10}, after="dan_kalmar"),
],
}

EVENTS = [
# ------------------------------------------------------------------ Venice
E("ven_lodi", "VEN", "Der Friede von Lodi", "Mailand, Florenz, Neapel, der Papst und Venedig sollen sich auf ein Gleichgewicht in Italien einigen.",
  {"year_max": 1460},
  [O("Der Italischen Liga beitreten.", {"relations": {"MLO": 30, "TUS": 30, "NAP": 30, "PAP": 30}, "dip": 20}, 60),
   O("Weiter Krieg um die Lombardei.", {"claim": ["milan"], "mil": 30, "flag": "ven_lombard_war"}),
   O("Nur mit Mailand verhandeln.", {"relations": {"MLO": 50}})]),
E("ven_cambrai", "VEN", "Die Liga von Cambrai", "Papst, Kaiser, Frankreich und Spanien haben sich gegen Venedig verbündet. Die Terraferma ist in Gefahr.",
  {"year_min": 1500, "year_max": 1520},
  [O("Bis zum Letzten verteidigen.", {"regs": 3, "gold": -60, "flag": "ven_cambrai_war"}, 50),
   O("Die Liga mit Diplomatie spalten.", {"dip": -40, "relations": {"PAP": 40, "SPA": 30}}),
   O("Die Festlandsstädte vorerst aufgeben.", {"dev_random": -2, "gold": 60})]),
E("ven_agnadello", "VEN", "Nach Agnadello", "Die Niederlage ist bitter, aber Padua hat sich erhoben und die Venezianer zurückgerufen.",
  {"year_min": 1505, "year_max": 1530, "flag": "ven_cambrai_war"},
  [O("Padua um jeden Preis halten.", {"prestige": 15, "manpower": -2}, 50),
   O("Den Papst umwerben.", {"relations": {"PAP": 50}, "gold": -40}),
   O("Neue Söldner aus Albanien.", {"mil": 40, "gold": -30})]),
E("ven_cyprus", "VEN", "Zypern", "Die Witwe des letzten Königs von Zypern ist Venezianerin. Die Insel könnte an die Republik fallen.",
  {"year_min": 1470, "year_max": 1500},
  [O("Die Königin zur Abdankung bewegen.", {"mods": {"income": 0.03}, "prestige": 10, "relations": {"TUR": -20}}, 60),
   O("Nur Handelsrechte sichern.", {"gold": 60}),
   O("Zu nah an den Türken.", {"relations": {"TUR": 20}, "dip": 20})]),
# ------------------------------------------------------------------ Milan
E("mlo_sforza_coup", "MLO", "Die Ambrosianische Republik", "Die Mailänder haben eine Republik ausgerufen. Der Condottiere Francesco Sforza steht mit seinem Heer vor der Stadt.",
  {"year_max": 1455},
  [O("Sforza wird Herzog.", {"ruler": {"mil": 1}, "prestige": 5}, 60),
   O("Die Republik verhandelt.", {"adm": 30, "dip": 20}),
   O("Venedig um Hilfe bitten.", {"relations": {"VEN": 40}, "prestige": -10})]),
E("mlo_ludovico", "MLO", "Ludovico il Moro", "Der Onkel des jungen Herzogs reißt die Macht an sich und holt Leonardo da Vinci an den Hof.",
  {"year_min": 1475, "year_max": 1500},
  [O("Leonardo soll Kanäle und Kanonen bauen.", {"dev_capital": 1, "mil": 30}, 50),
   O("Ein Fest, das ganz Italien bestaunt.", {"prestige": 15, "gold": -50}),
   O("Die Franzosen gegen Neapel rufen.", {"relations": {"FRA": 40, "NAP": -40}, "flag": "mlo_french_call"})]),
E("mlo_french_betrayal", "MLO", "Der Verrat der Verbündeten", "Die Franzosen, die Ludovico ins Land rief, wollen nun Mailand selbst.",
  {"year_min": 1495, "year_max": 1520, "flag": "mlo_french_call", "alive": "FRA"},
  [O("Schweizer Söldner gegen Frankreich.", {"gold": -60, "regs": 3, "relations": {"FRA": -40, "SWI": 30}}, 50),
   O("Den Kaiser um Schutz bitten.", {"relations": {"HAB": 50}, "prestige": -10}),
   O("Mit Frankreich verhandeln.", {"relations": {"FRA": 30}, "gold": -40})]),
# ------------------------------------------------------------------ Papal States
E("pap_julius", "PAP", "Der kriegerische Papst", "Julius II. legt die Tiara ab und zieht in Rüstung gegen Bologna.",
  {"year_min": 1500, "year_max": 1515},
  [O("Selbst ins Feld ziehen.", {"mil": 40, "prestige": 10, "regs": 2}, 50),
   O("Die Schweizergarde gründen.", {"mods": {"combat": 0.03}, "gold": -40}),
   O("Michelangelo die Decke bemalen lassen.", {"prestige": 15, "gold": -50})]),
E("pap_indulgences", "PAP", "Der Petersablass", "Für den Bau des Petersdoms sollen Ablassbriefe im ganzen Reich verkauft werden.",
  {"year_min": 1505, "year_max": 1530},
  [O("Die Ablassprediger losschicken.", {"gold": 120, "prestige": -10, "flag": "pap_indulgence_sold"}, 60),
   O("Spenden der Fürsten erbitten.", {"gold": 50, "dip": -20}),
   O("Nur mit eigenem Geld bauen.", {"gold": -40, "prestige": 10})]),
E("pap_trent", "PAP", "Das Konzil von Trient", "Ein deutscher Mönch stellt die Kirche in Frage. Ein Konzil soll antworten.",
  {"year_min": 1540, "year_max": 1565},
  [O("Reformen und eine klare Lehre.", {"adm": 50, "prestige": 15}, 50),
   O("Die Inquisition stärken.", {"mil": 20, "prestige": 5, "dev_random": -1}),
   O("Ausgleich mit den Protestanten suchen.", {"dip": 40, "prestige": -10})]),
E("pap_sack_of_rome", "PAP", "Der Sacco di Roma", "Meuternde Landsknechte des Kaisers plündern Rom. Der Papst flieht in die Engelsburg.",
  {"year_min": 1520, "year_max": 1535, "alive": "HAB"},
  [O("Den Kaiser krönen, um Frieden zu haben.", {"relations": {"HAB": 40}, "prestige": -15}, 50),
   O("Frankreich um Hilfe rufen.", {"relations": {"FRA": 40, "HAB": -30}, "dev_capital": -1}),
   O("Lösegeld zahlen.", {"gold": -80})]),
# ------------------------------------------------------------------ Florence
E("tus_pazzi", "TUS", "Die Pazzi-Verschwörung", "Im Dom wurde Giuliano de' Medici erstochen. Lorenzo hat schwer verwundet überlebt.",
  {"year_min": 1470, "year_max": 1485},
  [O("Blutige Rache an den Pazzi.", {"prestige": 5, "relations": {"PAP": -40}, "flag": "tus_pazzi_revenge"}, 50),
   O("Milde zeigen.", {"dip": 40}),
   O("Die Signoria stärken.", {"adm": 40, "prestige": -5})]),
E("tus_lorenzo_naples", "TUS", "Lorenzo reist nach Neapel", "Papst und Neapel führen Krieg gegen Florenz. Lorenzo fährt allein nach Neapel, um Frieden zu schließen.",
  {"year_min": 1478, "year_max": 1495, "flag": "tus_pazzi_revenge"},
  [O("Frieden mit Neapel!", {"relations": {"NAP": 50}, "prestige": 15}, 60),
   O("Venedig zu Hilfe rufen.", {"relations": {"VEN": 40}, "gold": -40}),
   O("Durchhalten.", {"mil": 30, "manpower": -2})]),
E("tus_savonarola", "TUS", "Das Fegefeuer der Eitelkeiten", "Der Dominikaner Savonarola predigt gegen Luxus und Medici. Bücher und Bilder brennen auf der Piazza.",
  {"year_min": 1490, "year_max": 1500},
  [O("Ihm folgen: eine Republik der Tugend.", {"prestige": -5, "adm": 40, "dev_random": -1}, 40),
   O("Ihn verbrennen lassen.", {"relations": {"PAP": 30}, "prestige": 5}, 40),
   O("Ihn nach Rom schicken.", {"dip": 20})]),
E("tus_galileo", "TUS", "Galileo Galilei", "Der Hofmathematiker der Medici hat Monde um den Jupiter entdeckt und sie nach seinem Herrn benannt.",
  {"year_min": 1605},
  [O("Ihn schützen.", {"adm": 40, "relations": {"PAP": -30}}, 50),
   O("Ihn nach Rom ausliefern.", {"relations": {"PAP": 40}, "prestige": -5}),
   O("Fernrohre für die Flotte.", {"mods": {"combat": 0.02}})]),
# ------------------------------------------------------------------ Denmark / Kalmar Union
E("dan_engelbrekt", "DAN", "Die schwedischen Stände", "Schwedische Bergleute und Adlige verlangen einen eigenen Reichsverweser.",
  {"year_max": 1480},
  [O("Einen Reichsverweser dulden.", {"dip": 30, "prestige": -5}, 50),
   O("Truppen nach Stockholm.", {"mil": -30, "regs": 2, "flag": "dan_swedish_revolt"}),
   O("Steuern für Schweden senken.", {"gold": -40, "adm": 20})]),
E("dan_brunkeberg", "DAN", "Die Schlacht am Brunkeberg", "Vor Stockholm schlagen die Schweden das Unionsheer. Der König entkommt mit Mühe.",
  {"year_min": 1465, "year_max": 1520, "flag": "dan_swedish_revolt"},
  [O("Ein neues Heer aufstellen.", {"gold": -60, "regs": 3}, 50),
   O("Frieden mit den Schweden.", {"prestige": -10, "dip": 40}),
   O("Die Hanse um Hilfe bitten.", {"relations": {"HSA": 40}, "gold": -30})]),
E("dan_count_feud", "DAN", "Die Grafenfehde", "Lübeck und dänische Bauern erheben sich für den gefangenen Christian II.",
  {"year_min": 1530, "year_max": 1540},
  [O("Den Aufstand niederwerfen.", {"mil": -30, "prestige": 10}, 50),
   O("Lübeck mit Zollrechten kaufen.", {"gold": -50, "relations": {"HSA": 40}}),
   O("Die lutherische Reform durchsetzen.", {"gold": 100, "relations": {"PAP": -40}})]),
E("dan_christian4", "DAN", "Christian IV.", "Der junge König baut Städte, Festungen und eine Flotte. Er will auch im Reich mitreden.",
  {"year_min": 1590, "year_max": 1640},
  [O("Neue Städte gründen.", {"dev_random": 2, "gold": -60}, 50),
   O("Eine Flotte für die Ostsee.", {"mods": {"combat": 0.03}, "gold": -50}),
   O("In den deutschen Krieg eingreifen.", {"mil": 40, "relations": {"HAB": -40}, "prestige": 5})]),
E("dan_tycho", "DAN", "Tycho Brahe", "Der Astronom bittet um eine Insel im Öresund für seine Sternwarte Uraniborg.",
  {"year_min": 1570, "year_max": 1600},
  [O("Die Insel Hven schenken.", {"adm": 30, "prestige": 10, "gold": -30}, 50),
   O("Nur eine Pension.", {"adm": 20}),
   O("Sterne zählen bringt keine Steuern.", {"gold": 30})]),
# ------------------------------------------------------------------ generic, late era (1550+)
E("gen_newspapers", "*", "Die erste Zeitung", "In der Hauptstadt erscheint ein wöchentliches Blatt mit Neuigkeiten aus aller Welt.",
  {"year_min": 1605, "min_dev": 20},
  [O("Ein Privileg erteilen.", {"dip": 30, "prestige": 5}, 50),
   O("Unter Zensur stellen.", {"adm": 20}),
   O("Verbieten.", {"prestige": -5})]),
E("gen_coffee_house", "*", "Das Kaffeehaus", "Ein Händler aus der Levante schenkt ein schwarzes Getränk aus. Kaufleute und Gelehrte streiten dort bis in die Nacht.",
  {"year_min": 1600},
  [O("Besteuern.", {"gold": 40}, 50),
   O("Treffpunkt der Gelehrten.", {"adm": 25}),
   O("Ein Ort der Verschwörer: schließen!", {"prestige": 5})]),
E("gen_mercantilism", "*", "Merkantilismus", "Die Räte des Herrschers raten: Mehr ausführen, weniger einführen, eigene Manufakturen gründen.",
  {"year_min": 1580, "min_dev": 30},
  [O("Manufakturen fördern.", {"gold": -60, "mods": {"income": 0.03}}, 40),
   O("Schutzzölle.", {"gold": 50, "dip": -20}, 40),
   O("Freihandel bleibt.", {"dip": 25})]),
E("gen_standing_army", "*", "Ein stehendes Heer", "Söldner sind teuer und unzuverlässig. Ein eigenes, ganzjähriges Heer würde den Staat verändern.",
  {"year_min": 1600},
  [O("Das Heer aufstellen.", {"regs": 3, "mods": {"manpower": 0.03}, "adm": -30}, 40),
   O("Eine Miliz ausbilden.", {"manpower": 2}),
   O("Weiter Söldner mieten.", {"gold": 30})]),
E("gen_baroque", "*", "Barock", "Säulen, Kuppeln und Engel aus Gold: Der neue Stil soll Macht und Glauben zeigen.",
  {"year_min": 1600},
  [O("Ein barockes Schloss bauen.", {"gold": -70, "prestige": 15, "dev_capital": 1}, 40),
   O("Eine Kirche im neuen Stil.", {"gold": -30, "prestige": 5}),
   O("Schlicht bleiben.", {"adm": 20})]),
E("gen_bureaucracy", "*", "Die neuen Kanzleien", "Studierte Juristen statt Adlige sollen die Verwaltung führen.",
  {"year_min": 1560, "tech": {"adm": 6}},
  [O("Juristen einstellen.", {"adm": 40, "prestige": -5}, 50),
   O("Ämter an den Adel vergeben.", {"gold": 40, "adm": -10}),
   O("Alles bleibt beim Alten.", {"dip": 15})]),
E("gen_thirty_years", "*", "Der Große Krieg im Reich", "Seit dem Prager Fenstersturz brennt das Reich. Armeen ziehen plündernd von Land zu Land.",
  {"year_min": 1618, "hre": True},
  [O("Bewaffnete Neutralität.", {"mil": -20, "regs": 2}, 40),
   O("Mit den Schweden gehen.", {"relations": {"DAN": 30, "HAB": -30}, "prestige": 5}, 30),
   O("Kaisertreu bleiben.", {"relations": {"HAB": 40}, "dev_random": -1}, 30)]),
E("gen_plague_1630", "*", "Die große Pest von 1630", "Mit den Armeen kommt die Seuche. In manchen Städten stirbt jeder Dritte.",
  {"year_min": 1625, "year_max": 1640},
  [O("Lazarette außerhalb der Stadt.", {"gold": -40, "dev_random": -1}, 30),
   O("Die Tore schließen.", {"dip": -20, "dev_random": -1}, 40),
   O("Prozessionen und Gebete.", {"prestige": 5, "dev_random": -2}, 30)]),
]

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


def main():
    path = os.path.join(ROOT, "data/events.json")
    txt = open(path, encoding="utf-8").read().rstrip()
    existing = {e["id"] for e in json.loads(txt)}
    new = [e for e in EVENTS if e["id"] not in existing]
    for e in new:
        assert len(e["options"]) == 3, e["id"]
    if new:
        txt = txt[:-1].rstrip() + ",\n" + ",\n".join(render_event(e) for e in new) + "\n]"
    json.loads(txt)
    open(path, "w", encoding="utf-8").write(txt + "\n")

    path = os.path.join(ROOT, "data/missions.json")
    data = json.load(open(path, encoding="utf-8"))
    for tag, ms in MISSIONS.items():
        have = {m["id"] for m in data.setdefault(tag, [])}
        data[tag] += [m for m in ms if m["id"] not in have]
    out = "{\n" + ",\n".join(
        '  "%s": [\n' % tag + ",\n".join(render_mission(m) for m in ms) + "\n  ]" for tag, ms in data.items()) + "\n}\n"
    json.loads(out)
    open(path, "w", encoding="utf-8").write(out)
    print("events +%d, missions %s" % (len(new), {t: len(v) for t, v in data.items()}))


if __name__ == "__main__":
    main()
