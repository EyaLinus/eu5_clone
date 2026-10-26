#!/usr/bin/env bash
# Regenerates every pixel-art PNG in assets/art/{icons,emoji} from its text-grid source (assets/src/pixel).
# Needs: pip install pillow pyyaml. Style rules: art_profile.yaml, workflow: .claude/skills/game-assets-2d
set -euo pipefail
cd "$(dirname "$0")/.."
S=.claude/skills/game-assets-2d/scripts
for src in assets/src/pixel/icons/*.txt assets/src/pixel/flags/*.txt; do
	[ -e "$src" ] || continue
	python3 "$S/pixelart.py" render "$src" --profile art_profile.yaml -o "assets/art/icons/$(basename "${src%.txt}").png" --scale 2
done
# pixel emoji glyphs (scripts/ui/pixel_emoji.gd), one grid pixel per screen pixel; written by tools/art/emoji_icons.py
for src in assets/src/pixel/emoji/*.txt; do
	[ -e "$src" ] || continue
	python3 "$S/pixelart.py" render "$src" --profile art_profile.yaml -o "assets/art/emoji/$(basename "${src%.txt}").png" --scale 1
done
# pixel UI kit (9-slice frames for scripts/ui/ui_theme.gd)
python3 tools/art/ui_kit.py
# map base texture (needs numpy, scipy): python3 tools/art/map_terrain.py
python3 "$S/check_palette.py" assets/art/icons/*.png assets/art/emoji/*.png --profile art_profile.yaml --strict
