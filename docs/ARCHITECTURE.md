# Architektur (für Entwickler und spätere Sessions)

## Grundprinzip
Die komplette Spiellogik steckt in `scripts/core/` und hängt an keinem Node. Dieselbe Simulation läuft
in der UI, in den Tests und in der Headless-Balance-Schleife. Jede neue Mechanik bekommt einen Test in
`tests/run_tests.gd` und erscheint, falls messbar, in `tools/metrics.gd`.

Kein `class_name`: alles wird per `preload()` verbunden, damit Headless-Skripte ohne Editor-Import
(globaler Klassen-Cache) funktionieren.

## Dateien
| Pfad | Inhalt |
|---|---|
| `scripts/core/game.gd` | Spielzustand (Province, Nation, Army, War), Monats-Tick, Aktionen, Effekte/Bedingungen, Save/Load |
| `scripts/core/ai.gd` | KI: Wirtschaft, Diplomatie, Kriegserklärung, Frieden, Armeeführung, Event-Wahl |
| `scripts/core/data.gd` | Lädt `data/*.json` |
| `scripts/core/tech.gd` | Technologiebaum: Definitionen, Sperren (Vorgänger, Jahr), Kosten, Erforschen, KI-Wahl, Effekt-Texte |
| `scripts/core/government.gd` | Regierung: Berater, Investitionskompanien, Gesetze, Jahres-Tick, KI |
| `scripts/ui/tech_screen.gd`, `gov_screen.gd` | Technologie- und Regierungs-Screen im Seitenpanel (Popups für Details/Auswahl) |
| `data/techs.json`, `data/government.json` | Generiert von `tools/content/tech_gov.py` (dort editieren) |
| `scripts/ui/main.gd` | Gesamte UI in Code gebaut (HUD, Seitenpanel, Popups), Zeitsteuerung, Autosave |
| `scripts/ui/icons.gd` | Icon-Registry: Emoji-Fallback, PNG aus `assets/art/icons/<key>.png` falls vorhanden |
| `scripts/ui/map_view.gd` | Karte: Zeichnen (Polygone, Schraffur bei Besetzung, Armeen) und Touch/Maus-Eingabe |
| `data/map.json` | Generiert von `tools/gen_map.py`: Polygone, Zentren, Nachbarschaften, Startbesitzer |
| `data/nations.json` | Nationen: Farbe, Emoji, Hauptstadt, Boni (`mods`), Aggressivität, spielbar ja/nein |
| `data/diplomacy.json` | Startbündnisse, Rivalitäten, Ansprüche, HRE-Mitglieder und Kaiser |
| `data/events.json` | Events: `tag` (`*` = alle), `trigger` (Bedingungen), 3 `options` mit `effects` und KI-Gewicht `ai` |
| `data/missions.json` | Missionen je Nation: `require` (Bedingungen), `reward` (Effekte), optional `after` |
| `data/balance.json` | Alle Zahlen. Wird von `tools/balance_loop.py` überschrieben |

## Bedingungen und Effekte (Events/Missionen)
Bedingungen (`Game.check_conditions`): `year_min/max, owns, owns_any, not_owns, at_war, at_peace, flag, not_flag,
min_dev, alive, not_alive, ae_min, gold_min, allied, allies, tech{adm,dip,mil}, has_tech, law{id:option}, regs, major, we_min, is_vassal, has_vassal, unrest_min, hre, emperor`.
Effekte (`Game.apply_effects`): `gold, adm, dip, mil, ae, we, prestige, manpower, regs, dev_capital, dev_random,
relations{TAG:x}, claim[keys], flag, mods{income,combat,manpower,adm,dip,mil,ae_decay}, ruler{adm,dip,mil},
alliance, inherit, vassal, province, war`. Neue Schlüssel immer in beiden UI-Textfunktionen
(`effects_text`, `conditions_text` in `main.gd`) und in `test_data_references` ergänzen.

## Wichtige Regeln
- Monat-Tick-Reihenfolge: Wirtschaft → Armeen (Bewegung, Schlachten, Belagerung, Verstärkung) → Kriege
  (Kapitulation bei ±99, Timeout) → KI → Jahreswechsel (Herrscher, Events, KI-Missionen, Koalitionen).
- Eroberte Provinzen: kosten Admin (`core_cost_per_dev`), bringen AE, sind `core_months` lang halbes Einkommen.
- Provinzen gehen im Frieden an den Besatzer, wenn er angrenzt, sonst an einen angrenzenden Sieger (`receiver_of`).
- Plausibilitätsregel: Die KI annektiert nie die Hauptstadt einer der 7 Großmächte.
- HRE: Greift ein Nicht-Mitglied ein Mitglied an, verteidigt der Kaiser (`defenders_for`).
- Der Spieler wird nie durch Erbschafts-Events geschluckt (`_inherit`).
- Gleichgewicht der Mächte: Bei Angriff auf einen Staat mit ≤ `protect_max_provinces` Provinzen verteidigt der
  stärkste nicht befreundete Nachbar (≥ `protector_min_strength` × Angreiferstärke) mit (`defenders_for`).
- Eroberte Hauptstädte kosten `capital_peace_mult`-fach Kriegspunkte und AE.
- Vasallen (`Nation.overlord`, seit v0.3): Friedensoption für den siegreichen Kriegsführer gegen den unterlegenen
  Kriegsführer (`vassal_block_reason`, Kosten `vassal_cost`). `is_allied` gilt auch für Lehnsherr↔Vasall
  (Durchzug, kein Krieg gegeneinander, keine Koalition). Vasallen erklären keine Kriege, schließen keine Bündnisse,
  zahlen `vassal_tribute` ihres Einkommens, ziehen mit dem Lehnsherrn in Angriffskriege (`_subject_bloc`) und
  werden von ihm verteidigt (`defenders_for`). Nach `vassal_annex_years` diplomatische Annexion
  (`annex_vassal`: Dip + Admin + etwas AE). Stirbt der Lehnsherr, werden Vasallen frei. Der Spieler wird nie Vasall.
  Starke oder verfeindete Vasallen (`liberty` ≥ `vassal_liberty_threshold`) sagen sich jährlich mit 25 % los.
- Kriegsmüdigkeit `Nation.we` (v0.4): steigt im Krieg und bei verlorenen Schlachten, sinkt im Frieden. Sie macht
  KI-Gegner friedensbereiter (`offer_peace`, `we_peace_factor`) und erhöht Unruhe.
- Unruhe (`unrest_parts`): nicht integriert + Kriegsmüdigkeit − Garnison − Unterdrückung. Ab `revolt_threshold`
  monatliche Aufstandschance (`_revolt`): Eine nicht integrierte Provinz fällt an `Province.prev_owner` zurück, wenn
  dieser lebt und angrenzt, sonst Plünderung (−1 Entwicklung, Gold) und 2 Jahre Ruhe.

- Modifier (`Game.mod(n, key)`): permanente `n.mods` (Nationalgeist, Events, Missionen) plus abgeleitete
  `n.bonus[quelle]` (nicht gespeichert, jedes System berechnet seinen Eintrag neu: "tech", "gov", "goods",
  "buildings"). Effekt-Keys und ihre deutschen Namen stehen in `Tech.LABELS`.
- Technologie (v0.7): 3 Kategorien × 3 Zweige × 9 Techs, Tech n eines Zweigs ist ab `year − early_years` (20)
  verfügbar und braucht den Vorgänger. `n.tech[cat]` zählt die erforschten Standard-Techs (alte Formeln:
  Einkommen, Kampfkraft, Truppenlimit, AE-Abbau). Jede spielbare Nation hat 3 Spezial-Techs (zählen nicht als Stufe).
  `buy_tech` (KI) wählt über `Tech.best_choice`: Spezial-Techs zuerst, sonst höchster `effect_value`.
- Regierung (v0.7): 3 Beraterplätze (Kosten 75 Punkte ihrer Art, historische nur in ihren Lebensjahren),
  2 Kompanieplätze (+1 durch "Aktiengesellschaften", Preis = 18 Monatseinkommen, min. 60 Gold), 4 Gesetze mit
  je einer neutralen Grundoption und Optionen mit Buff + Nerf (Wechsel 60 Punkte, 10 Jahre Sperre).
  Investitionsstufen (v0.8): `n.gov.invest` {id: Stufe 1–5}, Vorteile ×(1+0,5·(Stufe−1)), Nachteile bleiben;
  Ausbau kostet Σ 0,5·Preis·Stufe. KI investiert nur mit Rücklage (10 + 4·Ausgaben + 150).
  Stände (v0.8): `n.gov.estates` {adel, klerus, buerger} 0–100, driften 0,03/Monat zum Ziel 50 + mod(`estate_<id>`).
  Ab 65 treu, unter 30 verärgert: Effekte in n.bonus["estates"], Unruhe als eigener Posten in `unrest_parts`.
  Krisen-Events (`estate_crisis_*`) höchstens alle 4 Jahre, Zugeständnis +20 für max(30, 6·Einkommen) Gold, 5 Jahre Sperre.
  Der Test `test_government_data` erzwingt, dass jede Nicht-Grundoption mindestens einen Vor- und einen Nachteil hat.

## Werkzeuge
- `tools/sim.gd` Batch-Simulation, `tools/metrics.gd` Kennzahlen, `tools/trace.gd` 20-Jahres-Verlauf einer Partie.
- `tools/balance_loop.py` Auto-Balance (Zielbereiche oben in der Datei).
- `tools/shot.gd` UI-Screenshots (braucht Display, z. B. `xvfb-run ... --rendering-driver opengl3`).
- `tools/build.sh` lokaler Release-Build (Windows-EXE + signierte APK).
