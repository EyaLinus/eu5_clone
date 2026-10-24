# Art profile reference

The profile turns "make it look good" into rules a future session can check. Every field
exists because its absence causes drift or rework.

## How to choose values during bootstrap

**Style summary + rules.** Derive from genre, audience, platform and what is feasible
without painting. Feasible styles (no image AI): flat vector, outlined cartoon vector,
geometric/minimal, pixel art, paper-cutout, blueprint/schematic, map/atlas style.
Avoid styles that need painterly rendering (realistic, concept-art, watercolor) – you
cannot hit them reliably. Rules must be checkable by looking: stroke width at a stated
size, corner radius, shading model, light direction, outline color, max detail level.

**Palette.** 8–32 colors. Build it from roles, not taste:
- 1 ink (outlines/text), 1–2 neutrals (paper/background), 1 UI accent
- 2–4 semantic colors the game needs (e.g. gold, food, danger, friendly)
- for each material/terrain the game shows: base + darker + lighter (ramps)
Check contrast: ink on paper and text on UI accent should be clearly readable
(WCAG ≥ 4.5:1 as a rough target). For games with many factions/nations, define a
separate `faction_colors` list that is allowed only in flags/territory fills.

**Design grid.** Icons are designed on one viewBox size (commonly 24, 32 or 64) so
stroke widths stay identical across the set. Pick the smallest size at which the
style's details still read; 64 is a safe default.

**Display sizes.** Read the code/UI to find how big things actually appear. On mobile
an icon is ~24–48 dp; design for the smallest one.

**Outputs.** See `export-targets.md`. When unsure, PNG at densities [1, 2, 3] plus the
SVG source is the most portable choice.

**Methods.** Keep defaults unless the style demands otherwise (pixel-art style →
`sprite: pixel`, `icon: pixel`).

## Maintenance

- Any decision taken while producing an asset that the profile did not cover → add it.
- New color needed? Add it to the palette with a role name first, then use it.
  Never use an unlisted hex value.
- Record anchors in `style.references` as soon as they pass review.
