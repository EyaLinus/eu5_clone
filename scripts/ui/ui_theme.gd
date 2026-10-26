class_name UiTheme
## Pixel-art UI theme: 9-slice StyleBoxTextures from assets/art/ui (generator tools/art/ui_kit.py).
## Falls back to flat colours when a texture is missing, so the game still runs without the kit.
## Controls that draw these boxes need TEXTURE_FILTER_NEAREST (main.gd sets it on hud, modal and tooltip).

const Tech = preload("res://scripts/core/tech.gd")
const DIR := "res://assets/art/ui/"
## texture slice margin per kit image, in texture pixels (x2 of the 1x grid in ui_kit.py)
const SLICES := {
	"panel": 20, "header": 10, "topbar": 0, "button": 10, "button_hover": 10, "button_pressed": 10,
	"button_disabled": 10, "button_accent": 10, "card": 8, "card_gold": 8, "card_good": 8, "card_bad": 8,
	"tooltip": 10, "inset": 6, "bar_fill": 6, "grabber": 4, "scroll_track": 4,
}

## text colours for buffs and nerfs, shared by every modifier list
const GOOD := Color("8fdc8f")
const BAD := Color("f08a7a")
const NEUTRAL := Color("c9ccd1")
const GOLD := Color("f8de7e")
const MUTED := Color("8d929b")

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := DIR + name + ".png"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


## A 9-slice box from the kit; content margins default to the slice plus a little air.
static func box(name: String, content: float = -1.0) -> StyleBox:
	var t := tex(name)
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.09, 0.1, 0.13, 0.94)
		f.set_corner_radius_all(8)
		f.set_content_margin_all(content if content >= 0.0 else 8.0)
		return f
	var s := StyleBoxTexture.new()
	s.texture = t
	var m: float = SLICES.get(name, 8)
	s.texture_margin_left = m
	s.texture_margin_right = m
	s.texture_margin_top = m
	s.texture_margin_bottom = m
	s.set_content_margin_all(content if content >= 0.0 else m + 4.0)
	if name in ["panel", "topbar"]:
		s.modulate_color = Color(1, 1, 1, 0.96)  # the map shows through faintly
	return s


static func topbar() -> StyleBox:
	var s := box("topbar", 6)
	if s is StyleBoxTexture:
		s.texture_margin_bottom = 12
		s.texture_margin_top = 0
		s.texture_margin_left = 0
		s.texture_margin_right = 0
		s.content_margin_bottom = 12
		s.content_margin_left = 10
		s.content_margin_right = 10
	return s


## Framed card inside a panel. kind: "" (plain), "gold" (national / highlighted), "good", "bad".
static func card(kind: String = "", content: float = 10.0) -> StyleBox:
	return box("card" if kind == "" else "card_" + kind, content)


static func header() -> StyleBox:
	var s := box("header", 6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


## Progress bar fill in a colour (the kit fill is grey and gets tinted).
static func bar_fill(col: Color) -> StyleBox:
	var s := box("bar_fill", 0)
	if s is StyleBoxTexture:
		s.modulate_color = col
	else:
		s.bg_color = col
	return s


static func build(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", box("panel", 16))
	t.set_stylebox("panel", "TooltipPanel", box("tooltip", 12))
	t.set_color("font_color", "TooltipLabel", Color("f4f1e8"))
	var states := {"normal": "button", "hover": "button_hover", "pressed": "button_pressed", "disabled": "button_disabled"}
	for st in states:
		t.set_stylebox(st, "Button", box(states[st], 10))
	t.set_stylebox("hover_pressed", "Button", box("button_pressed", 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("f4f1e8"))
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_stylebox("background", "ProgressBar", box("inset", 2))
	t.set_stylebox("fill", "ProgressBar", bar_fill(Color("7cc46a")))
	t.set_stylebox("slider", "HSlider", box("inset", 4))
	var g := tex("slider_grabber")
	if g != null:
		t.set_icon("grabber", "HSlider", g)
		t.set_icon("grabber_highlight", "HSlider", g)
	for sb in ["VScrollBar", "HScrollBar"]:
		# content margins set the bar thickness (12 px)
		t.set_stylebox("scroll", sb, box("scroll_track", 6))
		t.set_stylebox("grabber", sb, box("grabber", 6))
		t.set_stylebox("grabber_highlight", sb, box("grabber", 6))
		t.set_stylebox("grabber_pressed", sb, box("grabber", 6))
	var sep := tex("separator")
	if sep != null:
		var s := StyleBoxTexture.new()
		s.texture = sep
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		t.set_stylebox("separator", "HSeparator", s)
		t.set_constant("separation", "HSeparator", 12)


# ---------------------------------------------------------------- modifier lists (buffs / nerfs)

## One effect as BBCode: tone 1 = buff (green, up arrow), -1 = nerf (red, down arrow), 0 = neutral.
static func tone_bb(text: String, tone: int, px: int = 14) -> String:
	if tone == 0:
		return "[color=#%s]%s[/color]" % [NEUTRAL.to_html(false), text]
	var arrow := "[img=%dx%d]%smod_%s.png[/img] " % [px, px, DIR, "up" if tone > 0 else "down"] if px > 0 and tex("mod_up") != null else ""
	# a leading emoji stays untinted (pixel emoji are a bitmap font and would take the text colour)
	var icon := ""
	var sp := text.find(" ")
	if sp > 0 and text.unicode_at(0) > 0x2000:
		icon = text.substr(0, sp + 1)
		text = text.substr(sp + 1)
	return "%s%s[color=#%s]%s[/color]" % [arrow, icon, (GOOD if tone > 0 else BAD).to_html(false), text]


## Modifier dictionary as one BBCode line or block (Tech.LABELS wording), buffs and nerfs marked.
static func mods_bb(eff: Dictionary, sep: String = "   ", px: int = 14) -> String:
	var parts := []
	for r in mod_rows(eff):
		parts.append(tone_bb("%s %s" % [r[1], r[0]], 1 if r[2] else -1, px))
	return sep.join(parts)


## [label, value, good] rows for a modifier dictionary (keys and wording from Tech.LABELS).
static func mod_rows(eff: Dictionary) -> Array:
	var r := []
	for k in eff:
		var v: float = float(eff[k])
		if absf(v) < 0.0005:
			continue
		var lab: Array = Tech.LABELS.get(k, [k, false, true])
		var num: String
		if lab[1]:
			num = "%+d %%" % roundi(v * 100.0) if absf(v) >= 0.005 else "%+.1f %%" % (v * 100.0)
		elif absf(v - roundf(v)) < 0.01:
			num = "%+d" % roundi(v)
		else:
			num = ("%+.2f" % v).rstrip("0")
		r.append([lab[0], num.replace("-", "−"), (v > 0) == lab[2]])
	return r


## One row per modifier: arrow icon, name, value right-aligned; green when it helps, red when it hurts.
## lines: Array of [label, value_text, good: bool] (Tech.effect_lines format).
static func mod_list(lines: Array, fs: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in lines:
		v.add_child(mod_row(str(l[0]), str(l[1]), bool(l[2]), fs))
	return v


static func mod_row(label: String, value: String, good: bool, fs: int = 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arrow := TextureRect.new()
	arrow.texture = tex("mod_up" if good else "mod_down")
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arrow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arrow.custom_minimum_size = Vector2(16, 16)
	h.add_child(arrow)
	var a := Label.new()
	a.text = label
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	a.custom_minimum_size.x = 60
	a.add_theme_font_size_override("font_size", fs)
	a.add_theme_color_override("font_color", NEUTRAL)
	h.add_child(a)
	var b := Label.new()
	b.text = value
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", GOOD if good else BAD)
	h.add_child(b)
	return h
