# Changelog-Schnipsel

Jeder PR legt seinen Changelog-Eintrag als **eigene Datei** hier ab, statt `CHANGELOG.md` zu bearbeiten.
So gibt es keine Merge-Konflikte mehr, wenn mehrere PRs gleichzeitig offen sind.

- Dateiname: kurzes Thema oder Branch, z. B. `changelog.d/staatsformen.md` (nur `.md`).
- Inhalt: ein oder mehrere Stichpunkte im bisherigen Stil, beginnend mit `- `:

  ```
  - **Staatsformen wirken:** Jede Staatsform bringt jetzt einen kleinen Vor- und Nachteil ...
  ```

- Beim Release fügt `python3 tools/changelog_collect.py --version vX.Y.Z` alle Schnipsel (neueste zuerst)
  als neuen Abschnitt `## vX.Y.Z – Datum` oben in `CHANGELOG.md` ein und löscht sie.
  `--dry-run` zeigt den Abschnitt nur an.
