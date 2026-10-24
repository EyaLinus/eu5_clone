# Changelog

## Unveröffentlicht
- Herrschernamen mit Ordnungszahl für die 7 Großmächte.
- Icon-Registry: Pixel-Art-PNGs ersetzen Emojis automatisch (`assets/art/icons/`).
- `tools/sim.gd --bot TAG`: aggressiver Stand-in-Spieler zum Testen von AE/Koalitionen.
- CI bricht überholte Läufe ab.

## v0.1.0 – 2026-10-24
- Erste spielbare Version: 7 Großmächte, 43 KI-Nationen, 161 Provinzen, 1444–1644.
- Gold + Admin/Dip/Mil, Technologie, Entwickeln/Bauen, Rekrutieren, Bündnisse, Ansprüche.
- Krieg: Armeen, Schlachten, Belagerungen, Kriegspunkte, Friedensverhandlungen, Kriegs-Timeout nach 12 Jahren.
- Aggressive Expansion mit Koalitionen; Heiliges Römisches Reich mit Kaiser als Verteidiger.
- 42 nationale und 12 allgemeine Events mit je 3 Optionen, 42 Missionen.
- Touch-taugliche UI mit Emoji-Platzhaltern, Autosave.
- Kartenmodi (politisch, diplomatisch, Entwicklung), Popups bei Kriegserklärung/Ruf zu den Waffen/Koalition,
  Schalter "alle Armeen KI/manuell".
- Headless-Balance: 3 Runden mit insgesamt ~300 KI-Partien à 200 Jahre. Endstand (16 Partien): Ø 29 von 50 Nationen
  ausgelöscht (meist Kleinstaaten, historisch ~20), größte Nation Ø 16 % der Gesamtentwicklung (max. 22 %),
  Großmächte überleben zu 94 % (Böhmen wird oft historisch von Österreich geerbt), Ø 96 Kriege, 13 Koalitionskriege,
  8 % der Kriege enden per Timeout. Bericht: `tools/balance_report.md`.
- Strukturelle Balance-Fixes: Eroberung kostet Admin, KI plant nur bezahlbare Armeen, Hauptstädte kosten doppelte
  Kriegspunkte/AE, Provinzen gehen nur an angrenzende Sieger, HRE-Kaiser verteidigt Reichsmitglieder,
  KI annektiert keine Großmacht-Hauptstadt.
