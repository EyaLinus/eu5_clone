"""Content batch v0.6: missions and short event chains for the Ottomans, Poland and Burgundy.
Usage: python3 tools/content/batch_v06.py  (idempotent, keeps the one-line-per-entry layout)"""
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


# owns-keys become starting claims, so only historically core targets use "owns"
MISSIONS = {
"TUR": [
  M("tur_constantinople", "Die Stadt der Kaiser", "Konstantinopel wird die Hauptstadt eines neuen Weltreichs.",
    {"owns": ["constantinople"]}, {"prestige": 25, "mods": {"income": 0.05}}),
  M("tur_balkans", "Herr des Balkans", "Serbien und Bosnien unter dem Halbmond.",
    {"owns_any": ["serbia", "bosnia"]}, {"mods": {"manpower": 0.05}, "mil": 40}),
  M("tur_morea", "Morea und Albanien", "Die letzten Bastionen der Griechen und Skanderbegs.",
    {"owns_any": ["morea", "albania"]}, {"dip": 40, "prestige": 10}, after="tur_constantinople"),
  M("tur_black_sea", "Das Schwarze Meer, ein türkischer See", "Die Krim, die Moldau oder die Walachei unter osmanischer Hoheit.",
    {"owns_any": ["crimea", "moldavia", "wallachia"]}, {"mods": {"income": 0.05}}),
  M("tur_hungary", "Die Pforte nach Europa", "Buda oder das Banat sichern den Weg nach Westen.",
    {"owns_any": ["buda", "temes"]}, {"mods": {"combat": 0.05}, "prestige": 15}, after="tur_balkans"),
  M("tur_vienna", "Der Goldene Apfel", "Wien, die Hauptstadt der Habsburger.",
    {"owns_any": ["wien"]}, {"prestige": 30, "mil": 50}, after="tur_hungary"),
],
"POL": [
  M("pol_prussia", "Königlich Preußen", "Die Städte an der Weichsel gehören zur Krone.",
    {"owns_any": ["marienburg", "prussia"]}, {"mods": {"income": 0.05}, "dip": 30}),
  M("pol_lithuania", "Die Republik beider Völker", "Polen und Litauen unter einer Krone.",
    {"owns_any": ["vilnius"]}, {"prestige": 20, "mods": {"manpower": 0.05}}),
  M("pol_baltic", "Dominium Maris Baltici", "Ein Hafen an der Ostsee für das Getreide Polens.",
    {"owns_any": ["riga", "pomerania", "reval"]}, {"mods": {"income": 0.05}}, after="pol_prussia"),
  M("pol_hussars", "Die Flügelhusaren", "Die beste Reiterei Europas.",
    {"tech": {"mil": 8}, "regs": 20}, {"mods": {"combat": 0.05}}),
  M("pol_sejm", "Der Sejm", "Ein Reichstag, der das Land zusammenhält statt es zu lähmen.",
    {"tech": {"adm": 8}, "min_dev": 80}, {"adm": 50, "prestige": 10}),
  M("pol_moscow", "Der Weg nach Osten", "Smolensk oder gar Moskau für die Jagiellonen.",
    {"owns_any": ["smolensk", "moscow"]}, {"prestige": 25}, after="pol_lithuania"),
],
"BUR": [
  M("bur_lowlands", "Die Niederlande halten", "Flandern, Brabant, Holland und Luxemburg bleiben burgundisch.",
    {"year_min": 1460, "at_peace": True, "owns": ["flanders", "brabant", "holland", "luxembourg"]}, {"mods": {"income": 0.05}}),
  M("bur_ordonnance", "Die Ordonnanzkompanien", "Ein stehendes Heer nach französischem Vorbild.",
    {"tech": {"mil": 6}, "regs": 15}, {"mods": {"combat": 0.05}}),
  M("bur_kingdom", "Eine Königskrone", "Der Kaiser soll Burgund zum Königreich erheben.",
    {"tech": {"dip": 6}, "allies": 1}, {"prestige": 20, "dip": 40}),
  M("bur_somme", "Die Somme-Städte", "Die Picardie und die Champagne verbinden Flandern mit dem Herzogtum.",
    {"owns_any": ["picardy", "champagne"]}, {"prestige": 15, "mods": {"manpower": 0.05}}, after="bur_ordonnance"),
  M("bur_rhine", "Zwischen Rhein und Maas", "Köln oder die Pfalz als Brücke zum Reich.",
    {"owns_any": ["cologne", "palatinate"]}, {"mods": {"manpower": 0.05}, "dip": 30}),
],
}

EVENTS = [
E("tur_mohacs", "TUR", "Mohács", "Der junge König von Ungarn hat das Bündnis mit dem Sultan verschmäht. Die Ebene von Mohács wartet.",
  {"year_min": 1515, "year_max": 1545, "alive": "HUN", "at_peace": True},
  [O("Nach Ungarn!", {"war": "HUN", "mil": 30}, 60),
   O("Einen Vasallen auf den Thron setzen.", {"claim": ["buda"], "dip": -30}),
   O("Erst Persien.", {"mil": 40})]),
E("tur_lepanto", "TUR", "Lepanto", "Die Flotte der Heiligen Liga hat die osmanische Flotte vernichtet. Europa feiert.",
  {"year_min": 1565, "year_max": 1585, "alive": "SPA"},
  [O("Eine neue Flotte in einem Winter.", {"gold": -80, "prestige": 10}, 50),
   O("Venedig einen Separatfrieden anbieten.", {"relations": {"VEN": 50}, "prestige": -10}),
   O("Der Bart wächst nach.", {"prestige": -5, "mil": 30})]),
E("pol_henrician", "POL", "Die Henricianischen Artikel", "Der Adel wählt einen französischen Prinzen zum König, aber nur gegen weitreichende Zugeständnisse.",
  {"year_min": 1570, "year_max": 1590},
  [O("Die Artikel annehmen.", {"dip": 40, "prestige": -5}, 50),
   O("Einen starken König wählen.", {"ruler": {"mil": 1}, "relations": {"FRA": -20}}),
   O("Den Habsburger Kandidaten nehmen.", {"relations": {"HAB": 40}, "gold": 40})]),
E("pol_vienna_relief", "POL", "Entsatz für Wien", "Der Kaiser bittet um Hilfe: Die Türken stehen vor Wien.",
  {"year_min": 1520, "alive": "TUR", "at_peace": True},
  [O("Die Husaren reiten!", {"prestige": 20, "manpower": -2, "relations": {"HAB": 40, "TUR": -40}}, 50),
   O("Gold statt Reiter.", {"gold": -50, "relations": {"HAB": 30}}),
   O("Das ist nicht unser Krieg.", {"mil": 30})]),
E("bur_nancy", "BUR", "Vor Nancy", "Im Schnee vor Nancy liegt Karl der Kühne tot. Seine Tochter Maria erbt ein Reich ohne Heer.",
  {"year_min": 1470, "year_max": 1490, "flag": "ev_bur_charles_bold"},
  [O("Maria heiratet Maximilian von Habsburg.", {"alliance": "HAB", "prestige": -5}, 50),
   O("Die Stände retten das Erbe.", {"adm": 40, "dip": -20}),
   O("Ein französischer Dauphin.", {"relations": {"FRA": 50}, "prestige": -10})]),
E("bur_golden_fleece", "BUR", "Der Orden vom Goldenen Vlies", "Der glänzendste Ritterorden Europas tagt in Brügge. Fürsten aus ganz Europa wollen aufgenommen werden.",
  {"year_max": 1500},
  [O("Ein prächtiges Ordenskapitel.", {"prestige": 10, "gold": -40}, 50),
   O("Ausländische Fürsten aufnehmen.", {"dip": 40}),
   O("Die Ritter sollen kämpfen, nicht feiern.", {"mil": 30})]),
# ------------------------------------------------------------------ Holy Roman Empire (conditions "hre", "emperor")
E("gen_hre_reichstag", "*", "Der Reichstag", "Die Reichsstände versammeln sich. Der Kaiser will Geld für den Türkenkrieg, die Fürsten wollen Rechte.",
  {"hre": True, "emperor": False, "year_min": 1450},
  [O("Die Türkenhilfe bewilligen.", {"gold": -30, "prestige": 5}, 30),
   O("Gegen den Kaiser stimmen.", {"dip": 20, "relations": {"HAB": -10}}, 40),
   O("Einen Gesandten schicken und schweigen.", {"adm": 15}, 30)], once=False),
E("gen_hre_landfriede", "*", "Der Ewige Landfriede", "Fehden sind im Reich verboten. Streit soll vor das Reichskammergericht.",
  {"hre": True, "year_min": 1495, "year_max": 1530},
  [O("Den Landfrieden achten.", {"prestige": 5, "dip": 15}, 50),
   O("Einen Prozess am Kammergericht führen.", {"adm": 25, "gold": -20}),
   O("Fehde ist Fürstenrecht.", {"mil": 30, "ae": 2})]),
E("gen_hre_reichskreis", "*", "Der Reichskreis", "Die Stände des Kreises sollen gemeinsam Truppen gegen Landfriedensbrecher stellen.",
  {"hre": True, "year_min": 1512, "at_peace": True},
  [O("Ein Kontingent stellen.", {"regs": 2, "mil": -20}, 50),
   O("Geld statt Soldaten.", {"gold": -30, "dip": 20}),
   O("Die Kreisordnung ignorieren.", {"prestige": -5, "mil": 20})]),
E("gen_emperor_coronation", "*", "Die Kaiserkrönung", "Der neue Kaiser soll gekrönt werden. Eine Romfahrt ist teuer, Aachen ist nah.",
  {"emperor": True},
  [O("In Rom, aus der Hand des Papstes.", {"gold": -60, "prestige": 15, "relations": {"PAP": 30}}, 40),
   O("In Aachen, wie Karl der Große.", {"prestige": 10, "gold": -20}, 40),
   O("Ein erwählter Kaiser braucht keine Krönung.", {"adm": 30, "prestige": -5}, 20)], once=False),
E("gen_emperor_reform", "*", "Reichsreform", "Als Kaiser könnten wir das Reich stärken, auf Kosten der Fürsten und unserer Hausmacht.",
  {"emperor": True, "year_min": 1480},
  [O("Ein Reichsregiment mit den Fürsten.", {"dip": 40, "prestige": 5}, 40),
   O("Die Hausmacht zuerst.", {"adm": 30, "gold": 40}, 40),
   O("Den Gemeinen Pfennig erheben.", {"gold": 70, "dip": -30}, 20)]),
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
