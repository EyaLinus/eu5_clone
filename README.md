# Rise of EU

Ein stark vereinfachtes Grand-Strategy-Spiel im Stil von Europa Universalis, 1444 bis 1644 (200 Jahre),
für **Android (APK)** und **Windows (EXE)**. Einzelspieler, Emoji-Grafik als Platzhalter.

Download: siehe [Releases](../../releases) (`RiseOfEU.apk`, `RiseOfEU.exe`, `RiseOfEU-web.zip`).

- **Android:** APK aufs Handy laden, Installation aus unbekannten Quellen erlauben, installieren (Querformat).
- **Browser:** `RiseOfEU-web.zip` entpacken und den Ordner auf einen Webserver legen, dann `index.html` öffnen
  (auch per `<iframe>`). Direkt per `file://` geht es nicht. Spezielle Header (COOP/COEP) sind nicht nötig, der
  Server muss `.wasm` nur als `application/wasm` ausliefern (für Apache liegt eine `.htaccess` bei). Spielstände
  liegen im Browser (IndexedDB) und gelten pro Browser und Domain. Download beim ersten Start ca. 10 MB komprimiert.
- **Windows:** `RiseOfEU.exe` starten. SmartScreen warnt, weil die Datei nicht signiert ist: "Weitere Informationen" → "Trotzdem ausführen".
- Releases baut die CI: Actions → "Test, build and release" → "Run workflow" mit `release_tag` (z. B. `v0.2.0`).

## Spielbare Nationen

| Nation | Bonus |
|---|---|
| ⚜️ Frankreich | +25 % Mannschaften, +1 Admin/Monat |
| 🦁 England | +10 % Einkommen, +5 % Kampfkraft |
| 🏰 Spanien | +10 % Kampfkraft, +5 % Einkommen |
| 👑 Böhmen | +10 % Einkommen, +1 Diplomatie/Monat |
| 🦅 Österreich | +2 Diplomatie/Monat, schnellerer AE-Abbau |
| 🐻 Russland | +30 % Mannschaften, +1 Militär/Monat |
| 🌋 Neapel | +15 % Einkommen, +1 Admin/Monat |
| ☪️ Osmanisches Reich | +30 % Mannschaften, +5 % Kampfkraft |
| 🦅 Polen | +10 % Mannschaften |
| 🍷 Burgund | +5 % Kampfkraft |

Dazu 40 KI-Nationen (Venedig, Mailand, Dänemark, Schottland, …), 161 Provinzen auf einer Europakarte
aus echten Küstenlinien (Natural Earth, Public Domain).

## Mechaniken (bewusst minimal)

- **Zeit:** 1 Tick = 1 Monat, 2400 Ticks. Pause und 5 Geschwindigkeiten.
- **Währungen:** 💰 Gold aus Steuern, Gütern und Handel; 📜 Admin, 🕊️ Diplomatie, ⚔️ Militär
  (2 + Herrscherwert + Boni pro Monat, Obergrenze 999).
- **Wirtschaft:** Jede Provinz stellt eines von 12 Gütern her, Preise folgen jährlich Angebot und Nachfrage, der
  größte Hersteller eines Guts erhält dessen Bonus. 13 Märkte verteilen Handelseinnahmen nach Handelsmacht,
  Händler verstärken sie. Gebäude (Marktplatz, Werkstatt, Manufaktur, Gutshof, Kaserne, Festung, Gerichtshof)
  haben Stufen, jede fertige Stufe bringt +1 Entwicklung. Entwicklung erhöht Steuern, Güter, Handelsmacht,
  Mannschaften und Bauplätze.
- **Fortschritt:** Rang Herzogtum, Königreich, Imperium (nach Entwicklung) mit Boni und 13 Meilensteine.
- **Ausgaben:** Technologie, Berater und Gesetze (Punkte), Entwickeln (Admin), Gebäude (Gold), Rekrutieren (Gold + Mannschaften),
  Beziehungen/Bündnisse/Ansprüche (Diplomatie), Integration eroberter Provinzen (Admin).
- **Krieg:** Armeen ziehen eine Provinz pro Monat, Schlachten bei Kontakt, Belagerung besetzt Provinzen.
  Kriegspunkte aus Besetzung, Schlachten und Hauptstadt. Frieden: besetzte Provinzen fordern, weißer Frieden
  oder Kapitulation. Nach 12 Jahren endet jeder Krieg automatisch (keine Endloskriege).
- **Aggressive Expansion (😠 AE):** Eroberung kostet AE pro Entwicklung (weniger mit Anspruch). Ab der
  Koalitionsgrenze treten Nachbarn einer Koalition bei, die bei ausreichender Stärke den Krieg erklärt.
- **Kriegsmüdigkeit und Unruhe:** Lange Kriege machen das Volk müde, frisch erobertes Land ist unruhig und kann
  zum alten Besitzer zurückfallen. Garnisonen und Unterdrückung helfen.
- **Technologiebaum:** Verwaltung, Diplomatie und Militär mit je 3 Zweigen à 9 Technologien (1444–1640),
  frei wählbare Reihenfolge, dazu 3 nationale Spezial-Technologien für jede spielbare Nation
  (z. B. Tercios, Janitscharen, Geflügelte Husaren).
- **Regierung (wie in Hearts of Iron):** 3 politische Berater (darunter 34 historische Persönlichkeiten wie
  Jacques Cœur, Thomas Cromwell oder Mimar Sinan), 2–3 Investitionskompanien (Fugger, Muscovy Company, …) und
  4 Gesetze (Wirtschaft, Heer, Staat, Kirche), deren Optionen immer Vor- und Nachteile haben.
  Kompanien lassen sich per Schieberegler bis Stufe 5 ausbauen (stärkere Vorteile, gleiche Nachteile).
- **Stände:** Adel, Klerus und Bürger haben eine Zufriedenheit (0–100), die zu einem Zielwert driftet.
  Gesetze, Berater und Kompanien verschieben das Ziel; treue Stände geben Boni, verärgerte bringen Unruhe
  und Krisen-Events. Zugeständnisse kosten Gold (alle 5 Jahre pro Stand).
- **Vasallen:** Statt Land zu fordern, kannst du den besiegten Kriegsführer zum Vasallen machen. Vasallen zahlen
  Tribut, kämpfen mit dir und lassen sich nach 15 Jahren diplomatisch annektieren.
- **Inhalte:** 281 Events mit je 3 Entscheidungen (jede Nation hat eigene) und 135 Missionen
  (10 je spielbarer Nation, 9 bei England und Spanien),
  plus allgemeine Events (Pest, Buchdruck, Reformation, …).

## Steuerung (Ein-Daumen-tauglich)

- Karte ziehen = verschieben, zwei Finger / Mausrad = Zoom, 🔍+/🔍- als Knöpfe.
- Provinz antippen → Infos und Aktionen.
- Armee (Kreis mit Zahl) antippen, dann Zielprovinz antippen → Marschbefehl. 🤖 = KI steuert die Armee.
- Links: 🏛️ Nation, 🤝 Diplomatie, ⚔️ Kriege/Frieden, 🎯 Missionen, 📜 Chronik.
- Am PC: Leertaste = Pause/Weiter, 1–5 = Tempo, Esc = Panel schließen.
- Ein orangefarbener Punkt an einem Tab zeigt, dass dort etwas zu tun ist.
- Automatisches Speichern jedes Jahr und beim Verlassen der App.

## Entwicklung

Siehe [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/ROADMAP.md](docs/ROADMAP.md) und [CHANGELOG.md](CHANGELOG.md).

- Engine: **Godot 4.3**, nur GDScript. Die Simulation (`scripts/core/`) hat keine Node-Abhängigkeiten
  und läuft headless identisch zur UI.
- `tools/gen_map.py` erzeugt `data/map.json` (Voronoi-Zellen auf Natural-Earth-Landmasse, Nachbarschaften).
- Tests: `godot --headless --path . -s res://tests/run_tests.gd`
- UI-Rauchtest (alle 10 spielbaren Nationen, alle Panels, 40 Jahre): `godot --headless --path . -s res://tools/ui_smoke.gd`
- Headless-Simulation: `godot --headless --path . -s res://tools/sim.gd -- --runs 10 --years 200`
- **Auto-Balance:** `python3 tools/balance_loop.py --godot <godot-binary> --runs 16 --iters 10`
  spielt parallele KI-Partien über 200 Jahre, misst Auslöschungen, Größe der stärksten Nation,
  Überleben der Großmächte, Koalitionskriege, Kriegs-Timeouts und Bankrotte und passt
  `data/balance.json` an. Ergebnis: `tools/balance_report.md`.
- **Changelog:** Jeder PR legt seinen Eintrag als eigene Datei in `changelog.d/` ab (nicht in `CHANGELOG.md`),
  beim Release fügt `python3 tools/changelog_collect.py --version vX.Y.Z` sie zusammen. Details: [changelog.d/README.md](changelog.d/README.md).
- Build: `tools/build.sh` (lokal) oder GitHub Actions (`.github/workflows/build.yml`: Tests → EXE/APK →
  Release bei Tag `v*`).

## Ehrliche Grenzen dieser Version

- Platzhaltergrafik (Emoji), keine Musik/Sounds, keine Seefahrt/Flotten, keine Religion, kein Handel,
  Nur eine einzige AE-Zahl statt Meinung pro Land.
- Die APK ist mit einem Debug-Schlüssel signiert (Installation per Sideload, nicht Play-Store-tauglich).
- Die Windows-EXE ist nicht code-signiert: Windows SmartScreen warnt beim ersten Start.
- Die KI ist regelbasiert und einfach; Balance ist auf KI-gegen-KI-Partien abgestimmt, nicht auf Spieler.
- Getestet: Simulation, Tests und Desktop-Rendering (Linux). Auf echten Android-Geräten und unter Windows
  wurde der Build vor dem Release nicht ausgeführt.

## Lizenzen

Code: siehe Repository. Kartendaten: Natural Earth (Public Domain). Alle Icons, Flaggen und Emoji-Glyphen: eigene Pixel-Art (`tools/art/`).
