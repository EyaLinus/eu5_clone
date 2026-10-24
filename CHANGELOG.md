# Changelog

## v0.3.0 – 2026-10-24
- **Vasallen:** Neue Friedensoption "⛓️ Vasallisieren" gegen den gegnerischen Kriegsführer (kostet 60 % des Preises
  seines gesamten Landes, halbe AE, keine Admin-Kosten). Vasallen zahlen 20 % ihres Einkommens als Tribut,
  kämpfen in deinen Kriegen, werden von dir verteidigt und dürfen weder Krieg erklären noch Bündnisse schließen.
- **Diplomatische Annexion** nach 15 Jahren: kostet 12 🕊️ und 5 📜 pro Entwicklung und etwas AE.
- KI vasallisiert besiegte Kleinstaaten (≤ 2 Provinzen) statt sie aufzuteilen und annektiert sie später.
- Kriegserklärungs-Dialog zeigt jetzt alle Verteidiger (Verbündete, Lehnsherr, Kaiser, Schutzmacht) und deren Stärke.
- Nationenlisten zeigen Pixel-Flaggen; lange Buttontexte werden gekürzt statt das Panel zu sprengen.
- Balance (5 Runden à 32 Partien): Ø 24–25 Nationen ausgelöscht, größte Nation Ø 16 %, Großmächte überleben zu
  ~93 %, Ø 55–70 Kriege (weniger als vorher, weil Vasallen keine Kriege erklären), ~23 Vasallisierungen pro Partie.

## v0.2.0 – 2026-10-24
- Gleichgewicht der Mächte: Greift jemand einen Kleinstaat (≤ 3 Provinzen) an, springt der stärkste nicht befreundete
  Nachbar als Schutzmacht ein. Ausgelöschte Nationen bis 1644 sinken von Ø 29 auf Ø 23 (historisch ~20).
- Balance Runde 4 (64 Partien): Ø 85 Kriege, größte Nation Ø 16 % der Entwicklung, Großmächte überleben zu 94 %.
- UI-Größe einstellbar (85–140 %, Android startet bei 120 %), auch im Startmenü.
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
