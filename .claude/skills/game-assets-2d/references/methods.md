# Production methods

## Vector SVG

**Good for:** icons, UI, flags, heraldry, symbols, simple sprites, modular characters.

Technique:
- Fixed `viewBox="0 0 S S"` with S = profile `grid.design_size_px`. Keep a 1–2 unit
  safe margin so outlines aren't clipped.
- Snap coordinates to whole or half units; odd stroke widths on half coordinates stay
  crisp when rasterized at 1×.
- Build from few primitives (`rect`, `circle`, `path` with simple curves). Every extra
  shape is detail that disappears at 24 px.
- Outline style: draw fills first, then one outline path on top with
  `stroke-linejoin="round"` – or use a dark backing shape offset by the stroke width
  (cheaper, consistent).
- Shading: one shadow shape in the darker ramp color, one highlight in the lighter one.
  No filters (`feGaussianBlur` etc.): renderers differ and they bloat files.
- Gradients only if the profile allows them; define them in `<defs>` with palette stops.
- Text in art: avoid. If unavoidable, use the profile font file and convert to paths
  (resvg renders with the font via `--font`), or render text in-engine instead.
- Variants (states, factions): keep one master SVG with CSS classes or `{{color}}`
  placeholders and generate variants with a small script instead of copying files.

Pitfalls: overly thin strokes (< 1/24 of the design size vanish), too many colors,
inconsistent stroke widths across the set, shapes touching the viewBox edge.

## Pixel art

**Good for:** sprites, tiles, animations in a retro style.

Technique (`scripts/pixelart.py`):
- One text grid per frame; each character maps to a palette name in a legend block.
- Design at the target tile size (8/16/32 px). Never draw big and downscale – it blurs.
- Upscale only by integers with nearest-neighbor.
- Readability: strong silhouette first (one color), then 2–3 shade levels, then a
  1-pixel outline (or selective outlines).
- Animations: keep the silhouette's volume constant between frames; 2–4 frames for
  idle, 4–8 for walk.
- Converting a vector asset to pixel art: render at tile size with
  `--shape-rendering crisp`, then `pixelart.py quantize` to lock to the palette, then
  clean by hand in the grid.

## Procedural textures

**Good for:** paper/parchment, stone, terrain, water, cloth, noise maps, masks.

`scripts/texture.py` makes tileable fractal noise mapped onto a palette ramp, plus
optional grain/spots. For anything beyond it, write a small Pillow/numpy script and
keep it next to the output. Tileability: generate on a torus (periodic noise) – the
script does this; check by rendering a 2×2 tiled preview (`--tile-preview`).

## Maps from real geography (e.g. Europe)

Source data: **Natural Earth** (public domain). Get it from GitHub
(`nvkelso/natural-earth-vector`, e.g. `geojson/ne_10m_admin_1_states_provinces.geojson`
for sub-national regions, `ne_50m_admin_0_countries` for countries, `ne_10m_land`,
`ne_10m_rivers_lake_centerlines`, `ne_10m_lakes`). Plain HTTP downloads may be blocked
by sandbox network rules while `git clone`/GitHub raw usually works.

Pipeline:
1. Load GeoJSON with `shapely` (`pip install shapely pyproj`), clip to the map's
   bounding box.
2. Project (e.g. Lambert Azimuthal Equal Area or Mercator for gameplay maps) with
   `pyproj`, then scale to pixel space.
3. Simplify (`shape.simplify(tol)`) – game maps need far fewer vertices than GIS data,
   and simplified borders read better on a phone.
4. Gameplay provinces rarely equal real admin regions. Options: use admin-1 regions,
   merge small ones (`unary_union`), or subdivide large ones with Voronoi
   (`shapely.voronoi_polygons` on random/Poisson points inside the land polygon,
   then intersect with the land).
5. Output whatever the game needs:
   - **SVG** with one `<path id="prov_123">` per province (vector maps, Compose/Flutter
     path rendering),
   - **province ID bitmap**: each province filled with a unique RGB color, no
     anti-aliasing (`resvg` with `--shape-rendering crisp`) – the classic Paradox-style
     lookup map for picking and shader coloring,
   - **adjacency list** (provinces whose polygons `touches()` each other) as JSON,
   - province **centroids/label points** (`representative_point()`) as JSON.
6. Store the generator script; the map is regenerated, never hand-edited.

Fictional maps: noise height-field → threshold to land → Voronoi provinces → same
outputs as above.

## Modular characters / portraits

Split into layers (base head, eyes, nose, mouth, hair, beard, headwear, clothing) as
separate SVG fragments on one shared viewBox, all colored via palette placeholders
(skin, hair, cloth). A script combines random or seeded layers. This gives hundreds of
consistent rulers/NPCs without drawing each one.
