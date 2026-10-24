# Export targets by stack

Use this to fill `outputs` in the profile. When the stack isn't listed, find out how
it loads images (read its asset-loading code) and pick the closest row.

| Stack | Preferred format | Densities / sizes | Notes |
|---|---|---|---|
| Native Android (Views/Compose) | VectorDrawable for simple icons; PNG/WebP otherwise | `drawable-mdpi` 1×, `hdpi` 1.5×, `xhdpi` 2×, `xxhdpi` 3×, `xxxhdpi` 4× | VectorDrawable can't do filters/text/complex gradients. Convert SVG→VD with `svg2vectordrawable` (npm) or Android Studio's tool. Game textures go in `assets/` as single-res PNG. |
| Compose / Android Canvas game | PNG in `assets/` or `res/drawable-nodpi`; or SVG path data drawn in code | design for xxhdpi (3×), let the code scale | For maps: store province paths as SVG path strings and draw with `PathParser`. |
| Flutter (+Flame) | PNG with `2.0x/`, `3.0x/` folders; or SVG via `flutter_svg` | 1×, 2×, 3× | Flame sprite sheets: atlas PNG + JSON. Declare folders in `pubspec.yaml`. |
| Godot 4 | SVG (imported and rasterized at import scale) or PNG | single-res, high quality; set import scale | Texture filter "Nearest" for pixel art. Atlases: `AtlasTexture` or SpriteFrames. |
| Web (Phaser, PixiJS, canvas) | PNG/WebP atlases with JSON-hash; SVG for UI | @1x/@2x | Phaser/PixiJS load TexturePacker JSON-hash directly (`atlas.py --format json-hash`). |
| libGDX | PNG atlas + `.atlas` text file | single-res | `atlas.py --format libgdx`. |
| Unity | PNG (Sprite import) or SVG via Vector Graphics package | single-res, set PPU | Atlases: Unity SpriteAtlas – export single sprites and let Unity pack. |
| React Native / Capacitor | PNG @1x/@2x/@3x or SVG (react-native-svg) | 1×, 2×, 3× | |

## General rules

- Pixel art: export at integer scales only, no smoothing; tell the engine to use
  nearest-neighbor filtering.
- Mobile memory: keep atlases ≤ 2048×2048, power-of-two if the engine needs it.
- Transparent PNGs: render on transparent background; check edges for dark fringes
  (premultiplied alpha issues) when the engine scales sprites.
- Prefer WebP for large backgrounds on Android/web when the stack supports it
  (`convert in.png -quality 90 out.webp` or Pillow `save(..., "WEBP")`).
- Keep file naming lowercase snake_case for Android (`res/` rejects uppercase and dashes).
