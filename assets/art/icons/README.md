# Pixel-Art-Icons

Lege hier PNGs ab, sie ersetzen automatisch das Emoji (siehe `scripts/ui/icons.gd`). Fehlt eine Datei, bleibt das Emoji.

- Format: PNG mit Transparenz, 32×32 oder 64×64 (Flaggen 48×32), wird mit Nearest-Neighbour skaliert.
- Ressourcen/HUD: `gold, adm, dip, mil, manpower, army, ae, prestige, dev, fort, date, siege, claim`
- Tabs links: `tab_nation, tab_diplomacy, tab_wars, tab_missions, tab_log, tab_mapmode`
- Popups: `event, peace, war, coalition`
- Flaggen: `flag_<TAG>.png` (z. B. `flag_FRA.png`, Tags siehe `data/nations.json`)
- Karte: `army_marker.png` (wird in der Nationsfarbe eingefärbt; weiß/hellgrau zeichnen)
