# Roadmap

> Stand 2026-10-25: v0.7.0 (Wirtschaft mit Gütern, Handel und Gebäuden, Technologiebaum, Regierung, Armeeführung, Progression, Pixel-Art).

Priorisiert nach Nutzen für den Spieler pro Aufwand. Status: ✅ fertig, 🔨 in Arbeit, ⏳ geplant.

## v0.1 – spielbarer Kern ✅
Karte, 50 Nationen, Monats-Tick über 200 Jahre, Gold + Admin/Dip/Mil, Technologie, Entwickeln/Bauen,
Armeen/Schlachten/Belagerungen, Kriegspunkte und Frieden, Bündnisse, Ansprüche, AE + Koalitionen, HRE-Schutz,
Events und Missionen für 7 Nationen, Save/Load, Tests, Headless-Balance, APK + EXE.

## v0.2 – Spielgefühl (nächster Schritt)
1. ✅ Kartenmodi: politisch / diplomatisch (Verbündete, Feinde, Ansprüche, Koalition) / Entwicklung.
2. ✅ (teilweise) Benachrichtigungen als Popups für Dinge, die den Spieler direkt betreffen (Kriegserklärung gegen uns,
   Koalition gegen uns, Verbündeter ruft zu den Waffen, Mission erfüllbar).
3. ✅ (teilweise) Armee-Komfort: "alle Armeen automatisch" im Krieg, Belagerungsfortschritt im Armeepanel, Ziel-Vorschau.
4. ⏳ Herrschernamen und Dynastien pro Großmacht (Flavor, kaum Aufwand).
5. ⏳ Einstellungen: UI-Skalierung für kleine Handys, Autosave-Intervall.
6. ⏳ Balance für den Spieler: Testläufe mit "Spieler-Bot", der aggressiv expandiert, um AE/Koalitionen zu prüfen.

## v0.3 – Tiefe
- ✅ Vasallen / diplomatische Annexion (Friedensoption, Tribut, gemeinsame Kriege, Annexion nach 15 Jahren).
- ✅ Unabhängigkeitsstreben von Vasallen (v0.4).
- ✅ Kaiserwahl im HRE (v0.5). ⏳ Reichsreformen light.
- ⏳ Mehr Events (Ziel: 10 pro Großmacht), Ketten-Events.
- ✅ Unruhen light + Kriegsmüdigkeit (v0.4).
- ⏳ Echte Rebellenarmeen (bewusst noch nicht: Aufstände wirken direkt).

## v0.4 – Präsentation
- 🔨 Pixel-Art: Icons, Armee-Marker und 51 Flaggen fertig (PR #1), Sounds offen.
- ⏳ Release-Keystore für Android (stabile Updates), signierte Windows-EXE (kostenpflichtiges Zertifikat nötig).

## v0.7 – Technologie und Regierung
- ✅ Technologiebaum: 81 Techs in 9 Zweigen, 30 nationale Spezial-Techs, Detail-Popup statt Ein-Tipp-Kauf.
- ✅ Regierungs-Screen: Berater (16 generische, 34 historische), 19 Investitionskompanien, 4 Gesetze mit Trade-offs.
- ⏳ Events, die Gesetze/Techs voraussetzen (`has_tech`, `law` sind als Bedingungen schon da).
- ⏳ Grafischer Baum mit Verbindungslinien, falls die Liste im Playtest zu unübersichtlich ist.

## Bewusst gestrichen
Seefahrt/Flotten, Handelsknoten, Religion als System, Kolonisation, Mehrspieler.
