extends RefCounted
## Pixel-art emoji font: replaces the colour emoji used in UI strings with our own pixel glyphs.
## A bitmap FontFile (16 px grid cells, scaled with the font size) is added to the default font's fallbacks, so every Label/Button
## that shows e.g. "💰" draws assets/art/emoji/<name>.png. There is no colour emoji font any more
## (Godot prefers a colour font over this one whatever the order), so an emoji without a pixel glyph
## shows as a box: tests/run_tests.gd (test_emoji_coverage) fails for it. New glyph: add it to
## tools/art/emoji_icons.py. Glyph map: assets/art/emoji/emoji.json (hex -> name).
## Nation flags get private-use code points (nation()).

const Icons = preload("res://scripts/ui/icons.gd")
const DIR := "res://assets/art/emoji/"
const CELL := 16  # grid size of a glyph
const UP := 4  # glyphs are stored 4x (nearest) so the font can scale them to any size and stay crisp
const SIZE := 52  # font size at which a stored glyph is drawn 1:1, so a glyph is ~1.23x the font size
const PUA := 0xE000

static var font: FontFile
static var _next_tex := 0
static var _nations := {}


## Builds the font and adds it to the default font's fallbacks. Call once, before any UI text.
static func install() -> void:
	if font != null:
		return
	font = FontFile.new()
	font.fixed_size = SIZE
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	# Own oversampling: a font that follows the global one gets its size cache wiped whenever that changes
	# (window resize with canvas stretch, UI-size button, Windows DPI), and with it every glyph added here.
	# All pixel glyphs then showed as hex boxes, and Windows drew its own emoji instead.
	font.oversampling = 1.0
	font.set_cache_ascent(0, SIZE, 50)
	font.set_cache_descent(0, SIZE, 10)
	var f := FileAccess.open(DIR + "emoji.json", FileAccess.READ)
	if f != null:
		var map: Dictionary = JSON.parse_string(f.get_as_text())
		for hex in map:
			var tex: Texture2D = load(DIR + map[hex] + ".png")
			if tex != null:
				_add(hex.hex_to_int(), tex.get_image())
	# variation selector 16 (the "️" in "⚔️") must not show as a box
	font.set_glyph_advance(0, SIZE, 0xFE0F, Vector2.ZERO)
	font.set_glyph_size(0, Vector2i(SIZE, 0), 0xFE0F, Vector2.ZERO)
	var base: Font = ThemeDB.fallback_font
	var fb: Array[Font] = base.fallbacks
	fb.insert(0, font)
	base.fallbacks = fb


## A one-character string showing the nation's pixel flag; a white flag when the nation has none (its own
## animal or symbol emoji has no pixel glyph and would show as a box).
static func nation(tag: String, _fallback: String = "") -> String:
	if _nations.has(tag):
		return _nations[tag]
	var s := "🏳"
	var tex: Texture2D = Icons.flag(tag)
	if font != null and tex != null:
		var img := tex.get_image()
		# flags are 24x16 grids exported x2; shrink back to one grid pixel per screen pixel
		img.resize(img.get_width() * CELL / img.get_height(), CELL, Image.INTERPOLATE_NEAREST)
		var cp := PUA + _nations.size()
		_add(cp, img)
		s = char(cp)
	_nations[tag] = s
	return s


## Adds every flag glyph up front. A glyph added later, while text is being drawn (map hover tip), could
## show as a garbled character on some PCs because the font texture changed mid-frame.
static func add_nations(tags: Array) -> void:
	for t in tags:
		nation(String(t))


static func _add(cp: int, img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	# drop empty columns so "x ▶ y" spaces like text; one grid pixel stays as side bearing
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.x < img.get_width():
		img = img.get_region(Rect2i(used.position.x, 0, used.size.x, img.get_height()))
	img.resize(img.get_width() * UP, img.get_height() * UP, Image.INTERPOLATE_NEAREST)
	var sz := Vector2i(SIZE, 0)
	var w := img.get_width()
	var h := img.get_height()
	font.set_texture_image(0, sz, _next_tex, img)
	font.set_glyph_texture_idx(0, sz, cp, _next_tex)
	font.set_glyph_uv_rect(0, sz, cp, Rect2(0, 0, w, h))
	font.set_glyph_size(0, sz, cp, Vector2(w, h))
	font.set_glyph_offset(0, sz, cp, Vector2(UP, 2 * UP - h))  # bottom two grid rows below the baseline
	font.set_glyph_advance(0, SIZE, cp, Vector2(w + 2 * UP, 0))
	_next_tex += 1
