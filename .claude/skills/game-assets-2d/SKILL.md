---
name: game-assets-2d
description: Create, iterate and export 2D game assets (icons, UI, sprites, tiles, pixel art, textures, decals, maps) for any game project and any tech stack, with style consistency enforced by a project art profile and a visual self-review loop. Use whenever a game project needs new or changed graphics, an asset placeholder should become real art, or the art style or asset pipeline of a game is being set up. Works autonomously without a GPU or external services.
---

# Game Assets 2D

You produce game-ready 2D assets for the project you are working in. The skill is
deliberately stack-agnostic: **you** decide the production method and output format
from the project's needs. The skill gives you the workflow, the tools and the quality bar.

Everything runs locally with Python. No image-generation AI, no GPU, no external
services. Your tools are: hand-written SVG, procedural code, pixel grids, and geodata.

## Core rules

1. **The art profile is the single source of truth.** Palette, style, sizes and output
   formats live in `art_profile.yaml` in the project. Never hardcode style values in
   asset sources that the profile defines. If the profile has no answer, decide, then
   write the decision into the profile so the next session follows it.
2. **Sources are versioned, outputs are reproducible.** Keep the editable source
   (`.svg`, pixel grid `.txt`, generator `.py`) in the repo. Rendered files must be
   regenerable from source with one command.
3. **Never ship without looking.** Every new or changed asset is rendered and viewed by
   you (Read the PNG) before it is registered as done. See `references/review.md`.
4. **Consistency beats beauty.** A plain asset that matches the set is better than a
   striking one that doesn't. Reuse shared building blocks (`assets/src/_lib/`).
5. **Register every asset** in `assets/manifest.yaml` so later sessions reuse instead of
   duplicating.

## Setup (once per session)

```bash
pip install --break-system-packages -q pillow pyyaml resvg-py cairosvg 2>/dev/null || \
pip install -q pillow pyyaml resvg-py cairosvg
```

Scripts live in this skill's `scripts/` folder (referred to as `$SKILL/scripts` below).
All accept `--help`.

## Workflow

### 0. Bootstrap (only if the project has no `art_profile.yaml`)

Read the project's README, design docs and code to learn genre, platform, camera and
tech stack. Then create `art_profile.yaml` from `templates/art_profile.template.yaml`.
`references/profile.md` explains every field and how to choose values. Decide:

- **Art style** – one sentence plus concrete rules (outline yes/no, stroke width, corner
  radius, shading model, light direction). Vague styles drift; concrete rules don't.
- **Palette** – 8–32 named colors. Every asset uses only these.
- **Methods per asset kind** – see the decision table below.
- **Output targets** – formats, sizes, densities, atlas yes/no, derived from the stack.
  `references/export-targets.md` lists what common stacks expect.

Then create 2–3 **anchor assets** (e.g. one icon, one UI panel, one sprite) and review
them hard. They become `style.references` in the profile – every later asset is
compared against them. If a human is available, this is the one moment to ask for
approval; afterwards proceed autonomously.

### 1. Define the asset

Write a short spec before drawing (in the manifest entry or as a comment in the source):
name, kind, purpose in the game, display size on screen, states/variants (hover,
disabled, frames), and which anchor it must match.

### 2. Choose the method

| Asset kind | Default method | Why |
|---|---|---|
| Icons, symbols, flags, heraldry, UI frames/buttons | Vector SVG | Crisp at every size, easy to vary |
| Pixel-art sprites, tiles, animations | Pixel grid → `pixelart.py` | Exact pixel control, palette-locked |
| Seamless textures (paper, stone, water, terrain, noise) | Procedural → `texture.py` | Tileable, infinite variants |
| Maps (real geography) | Geodata → SVG/raster | Accurate shapes; see `references/methods.md` |
| Maps (fictional), province/region layouts | Procedural (Voronoi/noise) | |
| Backgrounds, illustrations | Layered SVG shapes or procedural | No painting available – keep the style graphic |
| Characters / portraits | Modular SVG parts (face shapes, hair, clothes) | Variety through combination |

The profile may override these defaults. Method details and pitfalls:
`references/methods.md`.

### 3. Produce the source

- SVG: one `viewBox` per asset matching the profile's design grid (e.g. `0 0 64 64`),
  colors via the palette hex values only, no embedded raster images, no external fonts
  unless the profile ships the font file. Put reusable `<symbol>`/`<defs>` in
  `assets/src/_lib/` and copy them in.
- Pixel art: a text grid with one character per palette entry (format in
  `scripts/pixelart.py --help`).
- Procedural: a small generator script or a `texture.py` command line stored next to the
  output so it can be regenerated.

### 4. Render and self-review

```bash
python3 $SKILL/scripts/render_svg.py assets/src/icons/gold.svg -o build/preview --sizes 128 32
python3 $SKILL/scripts/check_palette.py assets/src/icons/gold.svg --profile art_profile.yaml
python3 $SKILL/scripts/contact_sheet.py build/preview/*.png <anchor pngs> -o build/review.png --label
```

Read `build/review.png` and go through `references/review.md`. Always look at the
**smallest real display size** – most 2D asset failures only show there (unreadable
detail, mushy silhouettes). Fix and re-render until it passes. Limit yourself to 3
iterations per asset; if it still fails, simplify the design instead of polishing.

### 5. Export to the project's targets

Generate the final files in the format the profile's `outputs` section demands:

```bash
# Raster at multiple densities (e.g. Android mdpi..xxxhdpi, or @1x/@2x/@3x)
python3 $SKILL/scripts/render_svg.py src.svg -o out/ --scales 1 1.5 2 3 4 --base 24 --suffix-pattern "{name}_{scale}x"
# Sprite atlas + metadata
python3 $SKILL/scripts/atlas.py out/sprites/*.png -o out/atlas --format json-hash
# Pixel art at integer scale
python3 $SKILL/scripts/pixelart.py render src.txt --profile art_profile.yaml -o out/hero.png --scale 4
```

If the stack consumes SVG directly (web, Flutter with flutter_svg, Godot imports SVG),
export the cleaned SVG instead of rasterizing. Wire the export into the project's build
(script, Gradle task, CI step) when the profile says `build_integration: true`, so
outputs never go stale.

### 6. Register

```bash
python3 $SKILL/scripts/manifest.py add gold_icon --kind icon --source assets/src/icons/gold.svg \
  --outputs out/icons/gold_*.png --status done --note "resource icon, matches anchor coin_icon"
```

Before creating any asset, run `manifest.py list` (or `find <name>`) to check whether it
or a reusable variant already exists.

## Changing the style later

Change the profile, then regenerate everything from source (`manifest.py list --paths`
gives the sources). Because colors come from the palette, a palette change is a find &
replace on hex values in sources – `check_palette.py` reports anything left behind.

## Reference files

- `references/profile.md` – every profile field and how to choose it
- `references/methods.md` – SVG, pixel art, procedural, geodata maps: techniques and pitfalls
- `references/export-targets.md` – what common stacks expect (Android, Flutter, Godot, web, Unity, libGDX …)
- `references/review.md` – the self-review checklist
