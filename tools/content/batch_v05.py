"""Content batch v0.5: flavor (idea, small bonus, ruler names) for the 43 minor nations,
historical AI events for key minors, events on war exhaustion, unrest, vassals and HRE electors.
Usage: python3 tools/content/batch_v05.py  (idempotent, keeps the one-line-per-entry layout)"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# tag: (idea text, bonus, rulers). Bonuses stay small: one key, 0.05-0.1, no monthly power.
MINORS = {
    "SCO": ("Auld Alliance: +10 % Mannschaften", {"manpower": 0.1}, ["Jakob", "Maria", "Robert"]),
    "IRE": ("Gälische Clans: +10 % Mannschaften", {"manpower": 0.1}, ["Conn", "Aodh", "Donal", "Brian"]),
    "BRI": ("Bretonische Seefahrer: +5 % Einkommen", {"income": 0.05}, ["Franz", "Anne", "Peter"]),
    "BUR": ("Die Ordonnanz von Burgund: +5 % Kampfkraft", {"combat": 0.05}, ["Philipp", "Karl", "Maria"]),
    "PRV": ("Das Erbe Renés von Anjou: +5 % Einkommen", {"income": 0.05}, ["René", "Karl", "Johann"]),
    "SAV": ("Pförtner der Alpen: +5 % Kampfkraft", {"combat": 0.05}, ["Amadeus", "Ludwig", "Philibert", "Karl Emanuel"]),
    "ARA": ("Katalanischer Mittelmeerhandel: +10 % Einkommen", {"income": 0.1}, ["Johann", "Ferdinand", "Alfons"]),
    "NAV": ("Fueros der Pyrenäen: +10 % Mannschaften", {"manpower": 0.1}, ["Johann", "Franz Phoebus", "Katharina", "Heinrich"]),
    "POR": ("Heinrich der Seefahrer: +10 % Einkommen", {"income": 0.1}, ["Alfons", "Johann", "Manuel", "Sebastian"]),
    "GRA": ("Letzte Bastion von al-Andalus: +5 % Kampfkraft", {"combat": 0.05}, ["Muhammad", "Abu l-Hasan", "Boabdil"]),
    "PAP": ("Der Heilige Stuhl: schnellerer AE-Abbau", {"ae_decay": 0.1}, ["Nikolaus", "Pius", "Sixtus", "Alexander", "Julius", "Leo", "Paul", "Gregor"]),
    "TUS": ("Bank der Medici: +10 % Einkommen", {"income": 0.1}, ["Cosimo", "Piero", "Lorenzo", "Ferdinando"]),
    "MLO": ("Mailänder Rüstungsschmieden: +5 % Kampfkraft", {"combat": 0.05}, ["Francesco", "Galeazzo Maria", "Ludovico", "Gian Galeazzo"]),
    "GEN": ("Casa di San Giorgio: +10 % Einkommen", {"income": 0.1}, ["Pietro", "Paolo", "Andrea", "Giovanni"]),
    "VEN": ("Die Serenissima: +10 % Einkommen", {"income": 0.1}, ["Francesco", "Cristoforo", "Agostino", "Leonardo", "Andrea"]),
    "BAV": ("Bayerisches Reinheitsgebot: +5 % Einkommen", {"income": 0.05}, ["Albrecht", "Wilhelm", "Ludwig", "Maximilian"]),
    "SAX": ("Silber aus dem Erzgebirge: +5 % Einkommen", {"income": 0.05}, ["Friedrich", "Ernst", "Albrecht", "Moritz", "August"]),
    "BRA": ("Märkische Junker: +10 % Mannschaften", {"manpower": 0.1}, ["Friedrich", "Albrecht", "Johann", "Joachim", "Georg Wilhelm"]),
    "KOL": ("Heiliges Köln: schnellerer AE-Abbau", {"ae_decay": 0.1}, ["Dietrich", "Ruprecht", "Hermann", "Ernst"]),
    "PAL": ("Kurfürstliche Würde: schnellerer AE-Abbau", {"ae_decay": 0.1}, ["Friedrich", "Philipp", "Ludwig", "Ottheinrich"]),
    "WUR": ("Tübinger Vertrag: +5 % Einkommen", {"income": 0.05}, ["Eberhard", "Ulrich", "Christoph", "Friedrich"]),
    "NUR": ("Reichsstadt der Handwerker: +10 % Einkommen", {"income": 0.1}, ["Hans", "Martin", "Willibald", "Lazarus"]),
    "HES": ("Hessische Söldner: +10 % Mannschaften", {"manpower": 0.1}, ["Ludwig", "Wilhelm", "Philipp", "Moritz"]),
    "LUN": ("Welfisches Erbe: +5 % Mannschaften", {"manpower": 0.05}, ["Otto", "Heinrich", "Ernst", "Wilhelm"]),
    "HSA": ("Kontore von Brügge bis Nowgorod: +10 % Einkommen", {"income": 0.1}, ["Hinrich", "Johann", "Jürgen", "Detlev"]),
    "POM": ("Greifenherzöge: +5 % Mannschaften", {"manpower": 0.05}, ["Erich", "Bogislaw", "Georg", "Barnim"]),
    "SWI": ("Reisläufer und Pikenhaufen: +10 % Kampfkraft", {"combat": 0.1}, ["Hans", "Rudolf", "Niklaus", "Adrian"]),
    "TEU": ("Ordensritter: +5 % Kampfkraft", {"combat": 0.05}, ["Konrad", "Ludwig", "Heinrich", "Albrecht"]),
    "POL": ("Goldene Freiheit der Szlachta: +10 % Mannschaften", {"manpower": 0.1}, ["Kasimir", "Johann Albrecht", "Alexander", "Sigismund", "Stephan", "Wladislaw"]),
    "LIT": ("Weite der Rus: +10 % Mannschaften", {"manpower": 0.1}, ["Kasimir", "Alexander", "Sigismund"]),
    "HUN": ("Die Schwarze Armee: +5 % Kampfkraft", {"combat": 0.05}, ["Ladislaus", "Matthias", "Wladislaw", "Ludwig", "Johann"]),
    "RYA": ("Grenzwacht an der Oka: +5 % Mannschaften", {"manpower": 0.05}, ["Iwan", "Wassili", "Fjodor"]),
    "NOV": ("Herr Groß-Nowgorod: +10 % Einkommen", {"income": 0.1}, ["Marfa", "Isaak", "Wassili", "Dmitri"]),
    "KAZ": ("Steppenreiter: +10 % Mannschaften", {"manpower": 0.1}, ["Mahmud", "Ibrahim", "Muhammad Amin", "Safa Giray"]),
    "CRI": ("Raubzüge in die Steppe: +5 % Kampfkraft", {"combat": 0.05}, ["Hacı Giray", "Mengli Giray", "Mehmed Giray", "Devlet Giray"]),
    "LIV": ("Schwertbrüder: +5 % Kampfkraft", {"combat": 0.05}, ["Johann", "Wolter", "Hermann", "Gotthard"]),
    "DAN": ("Sundzoll: +10 % Einkommen", {"income": 0.1}, ["Christoph", "Christian", "Johann", "Friedrich"]),
    "TUR": ("Janitscharen und Sipahi: +30 % Mannschaften, +5 % Kampfkraft", None, ["Murad", "Mehmed", "Bayezid", "Selim", "Süleyman", "Ahmed"]),
    "BYZ": ("Die Theodosianischen Mauern: +5 % Kampfkraft", {"combat": 0.05}, ["Konstantin", "Thomas", "Demetrios"]),
    "SER": ("Die Despoten von Smederevo: +5 % Mannschaften", {"manpower": 0.05}, ["Đurađ", "Lazar", "Stefan"]),
    "BOS": ("Bosnische Silberminen: +5 % Einkommen", {"income": 0.05}, ["Tvrtko", "Stjepan", "Tomaš"]),
    "WAL": ("Die Pfähler: +5 % Kampfkraft", {"combat": 0.05}, ["Vlad", "Radu", "Mircea", "Mihai"]),
    "MOL": ("Stephan der Große: +5 % Kampfkraft", {"combat": 0.05}, ["Stephan", "Bogdan", "Petru", "Alexandru"]),
    "ALB": ("Skanderbegs Bergkrieg: +10 % Mannschaften", {"manpower": 0.1}, ["Georg", "Johann", "Lekë"]),
}


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
# ------------------------------------------------------------------ key minors (AI-driven world history)
E("tur_constantinople", "TUR", "Der Rote Apfel", "Mehmed II. lässt Riesenkanonen gießen. Konstantinopel, die Stadt der Kaiser, liegt in Reichweite.",
  {"year_min": 1450, "year_max": 1465, "alive": "BYZ", "at_peace": True},
  [O("Die Stadt belagern!", {"war": "BYZ", "mil": 30}, 70),
   O("Tribut fordern.", {"gold": 60, "relations": {"BYZ": -30}}),
   O("Erst die Balkanfürsten unterwerfen.", {"claim": ["serbia", "bosnia"], "mil": 20})]),
E("tur_janissaries", "TUR", "Die Janitscharen murren", "Die Elitetruppe des Sultans verlangt nach jedem Thronwechsel ein Geschenk. Sonst kippen sie die Kessel um.",
  {"year_min": 1450},
  [O("Das Thronbesteigungsgeschenk zahlen.", {"gold": -50, "mods": {"combat": 0.02}}, 50),
   O("Neue Rekruten aus der Knabenlese.", {"manpower": 3, "dev_random": -1}),
   O("Die Rädelsführer köpfen.", {"prestige": 5, "mil": -30})], once=False),
E("tur_suleiman", "TUR", "Der Prächtige", "Süleyman will Gesetze für das ganze Reich und Feldzüge bis vor Wien.",
  {"year_min": 1520, "year_max": 1566},
  [O("Gesetzgeber: der Kanun.", {"adm": 50, "prestige": 10}, 40),
   O("Nach Ungarn!", {"claim": ["buda", "temes"], "mil": 30}, 40),
   O("Die Flotte des Barbarossa.", {"mods": {"combat": 0.03}, "gold": -60})]),
E("pol_lublin", "POL", "Die Union von Lublin", "Der letzte Jagiellone hat keine Erben. Polen und Litauen sollen ein gemeinsamer Staat werden.",
  {"year_min": 1560, "year_max": 1580, "alive": "LIT", "at_peace": True},
  [O("Die Realunion beschließen.", {"inherit": "LIT", "prestige": 10}, 45),
   O("Nur ein Bündnis.", {"alliance": "LIT", "dip": 30}),
   O("Litauen soll eigene Wege gehen.", {"adm": 40})]),
E("pol_grunwald", "POL", "Der Dreizehnjährige Krieg", "Die preußischen Städte erheben sich gegen den Deutschen Orden und bitten den König um Schutz.",
  {"year_min": 1450, "year_max": 1470, "alive": "TEU", "at_peace": True},
  [O("Krieg gegen den Orden!", {"war": "TEU", "claim": ["marienburg"]}, 60),
   O("Die Städte mit Geld unterstützen.", {"gold": -40, "relations": {"TEU": -40}, "claim": ["marienburg"]}),
   O("Frieden mit dem Orden.", {"relations": {"TEU": 40}, "dip": 30})]),
E("bur_charles_bold", "BUR", "Karl der Kühne", "Der Herzog träumt von einem Königreich zwischen Frankreich und dem Reich, und die Schweizer stehen im Weg.",
  {"year_min": 1465, "year_max": 1477, "alive": "SWI", "at_peace": True},
  [O("Gegen die Eidgenossen!", {"war": "SWI", "mil": 20}, 40),
   O("Eine Königskrone vom Kaiser kaufen.", {"gold": -80, "prestige": 15, "relations": {"HAB": 30}}),
   O("Das Erreichte sichern.", {"adm": 40}, 30)]),
E("ven_stato_da_mar", "VEN", "Der Stato da Mar", "Die osmanische Flotte bedroht Venedigs Inseln und Häfen in der Ägäis.",
  {"year_min": 1460, "year_max": 1580, "alive": "TUR"},
  [O("Galeeren aus dem Arsenal.", {"gold": -60, "mods": {"combat": 0.03}}, 40),
   O("Einen teuren Frieden kaufen.", {"gold": -40, "relations": {"TUR": 50}}, 40),
   O("Die Kreuzzugsliga anrufen.", {"relations": {"PAP": 30, "TUR": -30}, "dip": 20})]),
E("hun_matthias", "HUN", "Matthias Corvinus", "Der junge König baut ein Söldnerheer auf, die Schwarze Armee, und eine Bibliothek, die ganz Europa bestaunt.",
  {"year_min": 1458, "year_max": 1490},
  [O("Die Schwarze Armee.", {"regs": 4, "gold": -60}, 50),
   O("Die Bibliotheca Corviniana.", {"prestige": 10, "adm": 30}),
   O("Gegen die Türken an der Donau.", {"relations": {"TUR": -30, "PAP": 30}, "mil": 30})]),
E("dan_stockholm", "DAN", "Das Stockholmer Blutbad", "Der schwedische Adel will sich von der Kalmarer Union lösen. Der König lädt die Rebellen zum Fest nach Stockholm.",
  {"year_min": 1500, "year_max": 1530},
  [O("Ein Blutbad als Warnung.", {"prestige": -10, "mil": 40, "dev_random": -2}, 40),
   O("Den Schweden ihre Rechte bestätigen.", {"dip": 40, "gold": -30}, 40),
   O("Ein Reichstag für alle drei Kronen.", {"adm": 40})]),
E("por_india", "POR", "Der Seeweg nach Indien", "Vasco da Gama ist um das Kap gesegelt und mit Pfeffer aus Calicut zurückgekehrt.",
  {"year_min": 1495, "year_max": 1520},
  [O("Jedes Jahr eine Indienflotte.", {"mods": {"income": 0.05}, "gold": -50}, 60),
   O("Pfefferhandel als Krongut.", {"gold": 100}),
   O("Lieber Marokko erobern.", {"mil": 40})]),
E("pap_borgia", "PAP", "Cesare Borgia", "Der Sohn des Papstes will die Romagna mit Feuer und Schwert für den Kirchenstaat zurückerobern.",
  {"year_min": 1495, "year_max": 1510},
  [O("Ihm Truppen und Gold geben.", {"regs": 3, "gold": -40}, 50),
   O("Seine Gegner exkommunizieren.", {"prestige": 10, "dip": -20}),
   O("Nepotismus beschädigt das Amt.", {"adm": 30})]),
E("swi_reislaufen", "SWI", "Die Tagsatzung", "Fremde Könige werben um Schweizer Söldner. Die Orte streiten, ob das Reislaufen verboten werden soll.",
  {"year_min": 1470, "year_max": 1620},
  [O("Söldnerverträge mit Frankreich.", {"gold": 80, "relations": {"FRA": 30}, "manpower": -2}, 50),
   O("Söldnerverträge mit dem Papst.", {"gold": 60, "relations": {"PAP": 40}}),
   O("Ewige Neutralität.", {"dip": 40, "prestige": 5})]),

# ------------------------------------------------------------------ war exhaustion and the cost of war
E("gen_peace_party", "*", "Die Friedenspartei", "Kaufleute und Geistliche drängen bei Hofe auf ein Ende des Krieges. Sie bieten Geld für Verhandlungen.",
  {"at_war": True, "year_min": 1450},
  [O("Ihr Geld nehmen, weiterkämpfen.", {"gold": 40, "we": 2, "prestige": -5}, 40),
   O("Zuhören und Steuern senken.", {"we": -3, "adm": -20}, 40),
   O("Die Wortführer verhaften.", {"mil": 20, "we": 1})], once=False),
E("gen_deserters", "*", "Deserteure", "Nach Monaten ohne Sold laufen ganze Fähnlein davon und plündern auf dem Heimweg.",
  {"at_war": True, "year_min": 1450, "regs": 8},
  [O("Den Rückstand mit Gold begleichen.", {"gold": -40, "we": -1}, 30),
   O("Galgen am Wegesrand.", {"prestige": -5, "mil": -20}, 40),
   O("Laufen lassen.", {"manpower": -2, "we": 1}, 30)], once=False),
E("gen_victory_te_deum", "*", "Te Deum", "Ein Sieg im Feld! In allen Kirchen läuten die Glocken.",
  {"at_war": True, "year_min": 1450},
  [O("Ein Dankgottesdienst.", {"we": -2, "prestige": 5}, 50),
   O("Die Beute verteilen.", {"gold": 30, "we": -1}),
   O("Neue Rekruten strömen herbei.", {"manpower": 2})], once=False),
E("gen_war_widows", "*", "Witwen und Waisen", "Der Krieg hat viele Familien um ihre Ernährer gebracht. Die Gemeinden bitten um Hilfe.",
  {"at_peace": True, "year_min": 1460},
  [O("Eine Kriegerkasse einrichten.", {"gold": -30, "prestige": 5}, 30),
   O("Die Klöster sollen helfen.", {"adm": -15}, 40),
   O("Land für die Waisen.", {"dev_random": 1, "adm": -20}, 30)], once=False),
]

EVENTS += [
# ------------------------------------------------------------------ new v0.5 conditions: war exhaustion, unrest, vassals
E("gen_exhausted_land", "*", "Ein ausgeblutetes Land", "Dörfer stehen leer, die Steuereintreiber kehren mit leeren Händen zurück. Das Land kann nicht mehr.",
  {"we_min": 8},
  [O("Einen Bußtag ausrufen.", {"we": -3, "prestige": -5}, 40),
   O("Steuern erlassen.", {"we": -4, "gold": -40}, 30),
   O("Weiter so.", {"dev_random": -1, "mil": 20}, 30)], once=False),
E("gen_unrest_agitators", "*", "Aufwiegler im Land", "In den neu gewonnenen Provinzen predigen Wanderprediger gegen die fremde Herrschaft.",
  {"unrest_min": 4},
  [O("Truppen in die Unruheherde.", {"mil": -25}, 40),
   O("Die örtlichen Eliten bestechen.", {"gold": -40, "we": -1}, 30),
   O("Die alten Privilegien bestätigen.", {"adm": -25, "prestige": -5}, 30)], once=False),
E("gen_unrest_amnesty", "*", "Eine Amnestie?", "Die Rebellen bieten an, die Waffen niederzulegen, wenn ihre Anführer verschont bleiben.",
  {"unrest_min": 6, "at_peace": True},
  [O("Amnestie gewähren.", {"prestige": -5, "we": -2}, 50),
   O("Kein Pardon.", {"mil": -20, "prestige": 5}),
   O("Die Anführer in unsere Dienste nehmen.", {"regs": 2, "gold": -30})], once=False),
E("gen_vassal_tribute", "*", "Der Tribut des Vasallen", "Der Gesandte unseres Lehnsherrn verlangt mehr Tribut als vereinbart.",
  {"is_vassal": True},
  [O("Zahlen und schweigen.", {"gold": -30, "dip": 20}, 50),
   O("Um Aufschub bitten.", {"prestige": -5}),
   O("Heimlich aufrüsten.", {"mil": 30, "gold": -20})], once=False),
E("gen_vassal_court", "*", "Am Hof des Lehnsherrn", "Unser Thronfolger soll am Hof des Lehnsherrn erzogen werden. Ein Ehrenplatz oder eine Geisel?",
  {"is_vassal": True, "year_min": 1450},
  [O("Ihn schicken.", {"dip": 30, "ruler": {"dip": 1}}, 50),
   O("Er bleibt hier.", {"prestige": 5, "dip": -20}),
   O("Einen Vetter schicken.", {"adm": 20})]),
E("gen_overlord_vassal_loyalty", "*", "Unruhige Vasallen", "Unsere Vasallen murren über den Tribut. Ein Fest am Hof könnte die Wogen glätten.",
  {"has_vassal": True},
  [O("Ein Lehnstag mit Festmahl.", {"gold": -40, "prestige": 5}, 40),
   O("Den Tribut für ein Jahr erlassen.", {"gold": -20, "dip": 20}, 40),
   O("Sie sollen gehorchen.", {"mil": 20, "prestige": -5}, 20)], once=False),
# ------------------------------------------------------------------ Golden Bull: electors of the HRE
E("sax_electoral_vote", "SAX", "Die sächsische Kurstimme", "Gesandte bieten Gold für die sächsische Stimme bei der nächsten Kaiserwahl.",
  {"year_min": 1450},
  [O("An Habsburg verkaufen.", {"gold": 60, "relations": {"HAB": 40}}, 50),
   O("Für Böhmen stimmen.", {"relations": {"BOH": 40}, "dip": 20}),
   O("Die Stimme ist nicht käuflich.", {"prestige": 10})], once=False),
E("pal_electoral_vote", "PAL", "Die Pfälzer Kurstimme", "Der Kurfürst von der Pfalz wird von allen Seiten umworben.",
  {"year_min": 1450},
  [O("Habsburg die Stimme versprechen.", {"gold": 50, "relations": {"HAB": 40}}, 50),
   O("Mit Frankreich gegen den Kaiser.", {"relations": {"FRA": 40, "HAB": -30}, "dip": 20}),
   O("Die Goldene Bulle achten.", {"prestige": 10})], once=False),
E("bra_electoral_vote", "BRA", "Die brandenburgische Kurstimme", "Der Kurfürst von Brandenburg hat Schulden. Die Kandidaten wissen das.",
  {"year_min": 1450},
  [O("Den Meistbietenden wählen.", {"gold": 80, "prestige": -5}, 50),
   O("Mit dem Kaiserhaus gehen.", {"relations": {"HAB": 40}, "dip": 20}),
   O("Mit Polen gegen den Orden verhandeln.", {"relations": {"POL": 30, "TEU": -20}})], once=False),
E("boh_golden_bull", "BOH", "Die Goldene Bulle", "Karl IV. hat dem König von Böhmen die erste weltliche Kurstimme gegeben. Die anderen Kurfürsten werben um uns.",
  {"year_max": 1620},
  [O("Für Habsburg stimmen.", {"relations": {"HAB": 40}, "gold": 50}, 40),
   O("Die eigene Kandidatur betreiben.", {"prestige": 10, "dip": -30, "relations": {"HAB": -20}}, 30),
   O("Mit den Kurfürsten verhandeln.", {"relations": {"SAX": 30, "PAL": 30, "BRA": 30}}, 30)], once=False),
]


def render_event(e):
    head = {k: e[k] for k in ("id", "once", "tag", "title", "text") if k in e}
    s = "  " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    s += '   "trigger": ' + json.dumps(e["trigger"], ensure_ascii=False) + ",\n"
    s += '   "options": [\n'
    s += ",\n".join("     " + json.dumps(o, ensure_ascii=False) for o in e["options"])
    return s + "]}"


def main():
    path = os.path.join(ROOT, "data/nations.json")
    lines = open(path, encoding="utf-8").read().splitlines()
    out = []
    for ln in lines:
        m = re.match(r'^  "([A-Z]{3})": (\{.*\})(,?)$', ln)
        if m and m.group(1) in MINORS:
            d = json.loads(m.group(2))
            idea, bonus, rulers = MINORS[m.group(1)]
            if bonus is not None and "bonus" not in d:
                d["bonus"] = bonus
            d.setdefault("idea", idea)
            d.setdefault("rulers", rulers)
            ln = '  "%s": %s%s' % (m.group(1), json.dumps(d, ensure_ascii=False), m.group(3))
        out.append(ln)
    txt = "\n".join(out) + "\n"
    json.loads(txt)
    open(path, "w", encoding="utf-8").write(txt)

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
    print("minors flavored: %d, events +%d" % (len(MINORS), len(new)))


if __name__ == "__main__":
    main()
