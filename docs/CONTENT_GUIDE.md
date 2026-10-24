# Content-Leitfaden (Events, Missionen, Flavor)

Für alle, die `data/events.json` und `data/missions.json` erweitern. Code-Änderungen gehören nicht in Content-PRs;
fehlt ein Effekt oder eine Bedingung, bitte im Feature-Thread anfragen.

## Ablauf
1. Branch von `main`, nur `data/events.json`, `data/missions.json` (und ggf. `data/nations.json` für Herrschernamen/Ideen).
2. Format beibehalten: ein Event = Kopfzeile, `trigger`-Zeile, je Option eine Zeile (siehe bestehende Einträge).
3. Lokal prüfen: `godot --headless --path . -s res://tests/run_tests.gd` muss `0 failures` melden
   (prüft Provinz-Keys, Tags, Event-Form). CI macht das auch auf jedem PR.
4. PR gegen `main`. Der Feature-Thread reviewt, prüft die Balance per Headless-Lauf und merged.

## Event
```json
{"id": "fra_example", "tag": "FRA", "title": "Titel", "text": "1–2 Sätze, historisch, Deutsch.",
 "trigger": {"year_min": 1480, "year_max": 1520, "alive": "BUR"},
 "options": [
   {"text": "Option A", "effects": {"gold": 60}, "ai": 50},
   {"text": "Option B", "effects": {"adm": 30}},
   {"text": "Option C", "effects": {"prestige": 5}}]}
```
- `id`: eindeutig, Präfix = Tag in Kleinbuchstaben (`gen_` für allgemeine Events ohne `tag`).
- Genau **3 Optionen**. `ai` = Gewicht für die KI (Standard: 50 für Option 1, sonst 25).
- `"once": false` = wiederholbar (frühestens nach 10 Jahren erneut). Standard: einmalig.
- Ketten: Jedes ausgelöste Event setzt das Flag `ev_<id>`. Folge-Event mit `"flag": "ev_<vorgänger>"` im Trigger.
- Pro Jahr wird höchstens ein Event pro Nation ausgelöst (Chance `event_chance`); zu viele gleichzeitig gültige
  Events verwässern sich also. Lieber enge Zeitfenster.

## Mission
```json
{"id": "fra_example", "after": "fra_vorgaenger", "title": "Titel", "desc": "Kurzbeschreibung.",
 "require": {"owns": ["dijon"]}, "reward": {"prestige": 10}}
```
- Provinzen in `require.owns` gelten ab Spielstart als Ansprüche der Nation (Kriegsgrund). Sparsam einsetzen.

## Bedingungen (`trigger`, `require`)
`year_min`, `year_max`, `owns` [keys], `owns_any` [keys], `not_owns` [keys], `at_war`, `at_peace`, `flag`, `not_flag`,
`min_dev`, `alive` TAG, `not_alive` TAG, `ae_min`, `gold_min`, `allied` TAG, `allies` (Anzahl), `tech` {adm,dip,mil},
`regs`, `major` (nur die 7 Großmächte).

## Effekte (`effects`, `reward`)
`gold`, `adm`, `dip`, `mil`, `ae`, `we` (Kriegsmüdigkeit ±, 0–20), `prestige`, `manpower`, `regs`, `dev_capital`, `dev_random` (±n),
`relations` {TAG: x}, `claim` [keys], `flag` "name", `mods` {income, combat, manpower, adm, dip, mil, ae_decay},
`ruler` {adm, dip, mil}, `alliance` TAG, `inherit` TAG (schluckt TAG komplett, nie den Spieler), `vassal` TAG
(macht einen freien Kleinstaat zum Vasallen), `province` key, `war` TAG.

## Größenordnungen (Balance)
| Effekt | typisch | stark |
|---|---|---|
| gold | 40–80 | 100–150 |
| adm/dip/mil | 20–40 | 50–60 |
| prestige | 5 | 10–20 |
| mods.income/combat/manpower | 0.03 | 0.05–0.1 (nur Missionen) |
| mods.adm/dip/mil | – | 1 (selten) |
| regs | 2–3 | 4 |
| dev_random / dev_capital | 1–2 | 3 |

Jede Option sollte einen Preis oder eine Alternative haben; keine Option, die immer die beste ist.
`inherit`, `vassal` und `war` verändern die Karte stark: nur mit engem Zeitfenster und `alive`/`at_peace`.

Provinz-Keys und Tags: `data/map.json` (`key`) und `data/nations.json`.
