extends Control
## Root of the game UI. Builds all controls in code (no hand-written scenes),
## drives the monthly tick and shows panels/popups.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const Icons = preload("res://scripts/ui/icons.gd")
const TechScreen = preload("res://scripts/ui/tech_screen.gd")
const Tech = preload("res://scripts/core/tech.gd")
const Faith = preload("res://scripts/core/religion.gd")
const Monuments = preload("res://scripts/core/monuments.gd")
const GovScreen = preload("res://scripts/ui/gov_screen.gd")
const PixelEmoji = preload("res://scripts/ui/pixel_emoji.gd")
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const UI_SCALES := [0.85, 1.0, 1.2, 1.4]
const SPEEDS := [0.0, 1.2, 0.6, 0.3, 0.12, 0.04]
const HUD_TIPS := {
	"nation": "Deine Nation (antippen für Details)", "gold": "Gold (Monatsbilanz inkl. Tribut)",
	"adm": "Verwaltung: Technologie, Entwickeln, Integration", "dip": "Diplomatie: Bündnisse, Ansprüche, Annexion",
	"mil": "Militär: Technologie, Unruhe unterdrücken", "manpower": "Mannschaften für neue Regimenter",
	"army": "Regimenter / Truppenlimit", "ae": "Aggressive Expansion: ab der Koalitionsgrenze drohen Koalitionen",
}
const MAJORS := ["FRA", "ENG", "SPA", "BOH", "HAB", "RUS", "NAP"]
const EXTRA_PLAYABLE := ["TUR", "POL", "BUR"]  # playable, but less mission/event content than the majors

var data: Dictionary
var game
var speed := 0
var acc := 0.0
var panel_mode := ""
var panel_arg = null
var econ_tab := "overview"  # sub-tab of the economy panel
var prov_tab := "info"  # sub-tab of an own province: info, build, army
var selected_army := -1
var peace_selection := {}
var last_log_count := 0
var known_wars := {}
var known_coalition := 0
var last_speed := 2
var tab_badges := {}

var map: MapView
var top_labels := {}
var speed_label: Label
var side_panel: PanelContainer
var side_title: Label
var side_back: Button
var panel_history: Array = []
var side_box: VBoxContainer
var side_scroll: ScrollContainer
var modal: Control
var modal_box: VBoxContainer
var toast: Label
var toast_time := 0.0
var hud: Control
var settings := {"ui_scale": 1.0, "tips": true, "tips_seen": [], "sound": true}
var sfx_players: Array = []
# touch layer: drag-to-scroll over buttons and long-press tooltips (see _input)
const DRAG_START := 14.0
const LONG_PRESS := 0.5
var _scrolls: Array = []
var _press_pos := Vector2.ZERO
var _press_time := -1.0
var _press_scroll: ScrollContainer = null
var _press_scroll_start := 0
var _dragging := false
var _suppress_click := false
var _tip_panel: PanelContainer
var _tip_label: Label
var sfx_streams := {}
var last_battles := 0
var tech_screen := TechScreen.new(self)
var gov_screen := GovScreen.new(self)


func _ready() -> void:
	_load_settings()
	_setup_theme()
	for k in ["click", "event", "war", "peace", "battle", "success"]:
		var path := "res://assets/sfx/%s.wav" % k
		if ResourceLoader.exists(path):
			sfx_streams[k] = load(path)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	data = Data.load_all()
	map = MapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map)
	map.province_tapped.connect(_on_province_tapped)
	map.army_tapped.connect(_on_army_tapped)
	map.province_long_pressed.connect(_on_province_info)
	map.label_scale = 1.2 if _big() else 1.0
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_build_hud()
	_build_modal()
	hud.visible = false
	get_tree().set_auto_accept_quit(false)
	var preview = Game.new()
	preview.setup(data, 1, "")
	map.setup(preview, data.map)
	await get_tree().process_frame
	map.focus(Vector2(900, 650), maxf(size.y / map.world_size.y, 0.4))
	_show_start_menu()


## The game was called "EU5 Lite" until v0.7.3. On desktop the user folder follows the project name, so copy
## save and settings over once from the old folder (Android keeps its package id and folder).
func _migrate_old_user_dir() -> void:
	var cur := OS.get_user_data_dir()
	var old := cur.get_base_dir().path_join("EU5 Lite")
	if old == cur or not DirAccess.dir_exists_absolute(old):
		return
	for f in ["save.json", "settings.json"]:
		var src := old.path_join(f)
		var dst := cur.path_join(f)
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(src, dst)


func _load_settings() -> void:
	_migrate_old_user_dir()
	settings.ui_scale = 1.2 if OS.get_name() == "Android" else 1.0
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				settings[k] = d[k]
	_apply_settings()


func _apply_settings() -> void:
	get_window().content_scale_factor = float(settings.ui_scale)


func _save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func _cycle_ui_scale() -> void:
	var i := UI_SCALES.find(float(settings.ui_scale))
	settings.ui_scale = UI_SCALES[(i + 1) % UI_SCALES.size()]
	_apply_settings()
	_save_settings()
	if game == null:
		_show_start_menu()
	else:
		_show_menu()


func _setup_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 20
	PixelEmoji.install()  # all emoji in UI strings are drawn as pixel glyphs
	UiTheme.build(t)  # pixel-art panels and buttons (assets/art/ui, tools/art/ui_kit.py)
	theme = t


# ---------------------------------------------------------------- HUD construction

func _build_hud() -> void:
	hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel frames
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.add_theme_stylebox_override("panel", UiTheme.topbar())
	hud.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	for k in ["nation", "gold", "adm", "dip", "mil", "manpower", "army", "ae"]:
		var tex := Icons.texture(k)
		if tex != null:
			hb.add_child(_icon_rect(tex, 32))
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = HUD_TIPS.get(k, "")
		hb.add_child(l)
		top_labels[k] = l
	top_labels.nation.gui_input.connect(func(e): if _is_click(e): _open_panel("nation"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	top_labels["date"] = Label.new()
	hb.add_child(top_labels.date)
	hb.add_child(_btn("⏸", func(): _set_speed(0), "Pause"))
	hb.add_child(_btn("➖", func(): _set_speed(maxi(1, speed - 1)), "Langsamer"))
	speed_label = Label.new()
	hb.add_child(speed_label)
	hb.add_child(_btn("➕", func(): _set_speed(mini(SPEEDS.size() - 1, speed + 1)), "Schneller"))
	hb.add_child(_btn("☰", func(): _show_menu(), "Menü"))
	# the top bar has a fixed height: keep its buttons compact even with large touch targets
	for c in hb.get_children():
		if c is Button:
			c.custom_minimum_size = Vector2(60, 56) if _big() else Vector2(52, 52)
	if _big():
		hb.add_theme_constant_override("separation", 10)

	# 8 tabs: one column on desktop, two columns with large touch targets so they fit 720 px height
	var left := GridContainer.new()
	left.columns = 2  # 9 tabs do not fit one column above the zoom buttons on a 720 px screen
	left.position = Vector2(8, 72)
	left.add_theme_constant_override("v_separation", 8)
	left.add_theme_constant_override("h_separation", 8)
	hud.add_child(left)
	for e in [["nation", "Nation"], ["economy", "Wirtschaft"], ["tech", "Technologie"], ["government", "Regierung"], ["diplomacy", "Diplomatie"], ["wars", "Kriege"],
			["missions", "Missionen"], ["log", "Chronik"], ["mapmode", "Kartenmodus"]]:
		var cb: Callable = _open_panel.bind("mapmodes") if e[0] == "mapmode" else _open_panel.bind(e[0])
		var tb := _tab_button("tab_" + e[0], cb, e[1])
		var badge := Label.new()
		badge.text = "●"
		badge.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		badge.add_theme_font_size_override("font_size", 18)
		badge.position = Vector2(42, -6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		tb.add_child(badge)
		tab_badges[e[0]] = badge
		left.add_child(tb)

	var zoom := HBoxContainer.new()
	zoom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zoom.add_theme_constant_override("separation", 8)
	hud.add_child(zoom)
	for e in [["🔍+", 1.3], ["🔍-", 1.0 / 1.3]]:
		var b := _btn(e[0], func(): map.zoom_by(e[1]))
		b.custom_minimum_size = Vector2(60, 56)
		zoom.add_child(b)
	zoom.offset_left = 8
	zoom.offset_top = -64

	side_panel = PanelContainer.new()
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -500 if _big() else -440
	side_panel.offset_top = 68
	side_panel.offset_right = -6
	side_panel.offset_bottom = -6
	hud.add_child(side_panel)
	var vb := VBoxContainer.new()
	side_panel.add_child(vb)
	var head_box := PanelContainer.new()
	head_box.add_theme_stylebox_override("panel", UiTheme.header())
	vb.add_child(head_box)
	var head := HBoxContainer.new()
	head_box.add_child(head)
	side_back = _btn("◀", _panel_back, "Zurück")
	side_back.visible = false
	head.add_child(side_back)
	side_title = Label.new()
	side_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_title.add_theme_font_size_override("font_size", 24)
	side_title.clip_text = true
	side_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(side_title)
	head.add_child(_btn("✖", _close_panel))
	side_scroll = ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(side_scroll)
	register_scroll(side_scroll)
	side_box = VBoxContainer.new()
	side_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_theme_constant_override("separation", 8)
	side_scroll.add_child(side_box)
	side_panel.visible = false

	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.offset_top = -60
	toast.offset_bottom = -16
	toast.offset_left = -420
	toast.offset_right = 420
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 6)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := UiTheme.box("tooltip", 6)
	tsb.content_margin_left = 16
	tsb.content_margin_right = 16
	toast.add_theme_stylebox_override("normal", tsb)
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.visible = false
	hud.add_child(toast)


func _build_modal() -> void:
	modal = Control.new()
	modal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(640, 0)
	center.add_child(pc)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	register_scroll(sc)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation", 10)
	sc.add_child(modal_box)
	modal.visible = false
	modal_box.resized.connect(func(): sc.custom_minimum_size.y = minf(modal_box.size.y, size.y - 60))


# ---------------------------------------------------------------- helpers

func _btn(text: String, cb: Callable, tip: String = "", disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.disabled = disabled
	b.custom_minimum_size = Vector2(64, 66) if _big() else Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	# long labels are trimmed instead of widening the side panel past the screen edge
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# a press that turned into a scroll or a long-press tooltip is not a click
	b.pressed.connect(func():
		if _suppress_click:
			return
		_sfx("click", -14.0)
		cb.call())
	return b


## Button with a title line and a BBCode line below (event options: green buffs, red nerfs).
## A PanelContainer stacks the button (background, clicks) and the text on the same rect, so the
## button gets the height of its wrapped text, which a plain Button cannot do with child controls.
func _rich_btn(title: String, bb: String, cb: Callable, fs: int = 18) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var b := _btn("", cb)
	pc.add_child(b)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var mc := MarginContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 12)
	mc.add_child(v)
	pc.add_child(mc)
	v.add_child(_lbl(title, fs))
	if bb != "":
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.add_theme_font_size_override("normal_font_size", fs - 2)
		r.text = bb
		v.add_child(r)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


func _icon_rect(tex: Texture2D, px: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(px, px)
	return r


func _tab_button(key: String, cb: Callable, tip: String) -> Button:
	var tex := Icons.texture(key)
	var b := _btn("" if tex != null else Icons.emoji(key), cb, tip)
	if tex != null:
		b.icon = tex
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.custom_minimum_size = Vector2(76, 76) if _big() else Vector2(60, 60)
	b.add_theme_font_size_override("font_size", 28)
	return b


func _lbl(text: String, fs: int = 0, color: Color = Color(0.92, 0.92, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	if fs > 0:
		l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	return l


## Wrapping BBCode label (coloured buffs / nerfs) that sizes to its text.
func _bb(text: String, fs: int = 16) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size.x = 100
	r.add_theme_font_size_override("normal_font_size", fs)
	r.text = text
	return r


func _is_click(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _row(children: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for c in children:
		if c is Button or c is Label:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(c)
	return h


func _toast(text: String) -> void:
	toast.text = text
	toast.visible = text != ""
	_place_toast()
	toast_time = 4.0


## Plays a short procedural sound (assets/sfx, generated by tools/gen_sfx.py) unless sound is off.
func _sfx(key: String, db: float = -6.0) -> void:
	if not settings.get("sound", true) or not sfx_streams.has(key):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_streams[key]
			p.volume_db = db
			p.play()
			return


func _act(err: String, ok_text: String = "") -> void:
	if err != "":
		_toast("❌ " + err)
	elif ok_text != "":
		_toast(ok_text)
		_sfx("success")
	map.check_dev_changes()
	_refresh()


func nname(tag: String) -> String:
	var n = game.nations[tag]
	return "%s %s" % [PixelEmoji.nation(tag, n.emoji), n.name]


## Button for a nation: pixel flag as icon when available, emoji otherwise.
func _nation_btn(tag: String, extra: String, cb: Callable, pre: String = "") -> Button:
	var flag := Icons.flag(tag)
	var b := _btn(pre + (game.nations[tag].name if flag != null else nname(tag)) + extra, cb)
	if flag != null:
		b.icon = flag
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


# ---------------------------------------------------------------- game flow

func _show_start_menu() -> void:
	hud.visible = false
	_open_modal()
	modal_box.add_child(_lbl("🌍 Rise of EU", 40))
	modal_box.add_child(_lbl("1444 – 1644 · Wähle deine Nation. Ziel: Am Ende die höchste Punktzahl (Entwicklung + Prestige + Technologie).", 18))
	if FileAccess.file_exists(SAVE_PATH):
		modal_box.add_child(_btn("💾 Weiterspielen", _load_game))
	modal_box.add_child(_btn("🔠 UI-Größe: %d%%" % int(round(float(settings.ui_scale) * 100)), _cycle_ui_scale))
	for tag in MAJORS + EXTRA_PLAYABLE:
		if tag == EXTRA_PLAYABLE[0]:
			modal_box.add_child(_lbl("Weitere Nationen (weniger Missionen und Events):", 16, Color(0.85, 0.75, 0.5)))
		var nd: Dictionary = data.nations[tag]
		modal_box.add_child(_rich_btn("%s %s" % [PixelEmoji.nation(tag, nd.emoji), nd.name], _idea_bb(nd.get("idea", ""), nd.get("bonus", {})), _start_game.bind(tag), 20))


## National idea as "Name: buffs" with the buffs green (data/nations.json "idea" text before the colon + "bonus").
func _idea_bb(idea: String, bonus: Dictionary) -> String:
	var title := idea.get_slice(":", 0).strip_edges()
	var mods := UiTheme.mods_bb(bonus)
	if mods == "":
		return "[color=#%s]%s[/color]" % [UiTheme.MUTED.to_html(false), idea]
	return "[color=#%s]%s[/color]   %s" % [UiTheme.GOLD.to_html(false), title, mods]


func _start_game(tag: String) -> void:
	game = Game.new()
	game.setup(data, int(Time.get_unix_time_from_system()) % 100000, tag)
	_after_game_loaded()
	_show_intro()


func _load_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_toast("❌ Kein Spielstand gefunden.")
		return
	var d = JSON.parse_string(f.get_as_text())
	if d == null:
		_toast("❌ Spielstand beschädigt.")
		return
	game = Game.new()
	game.setup(data, 1, d.player)
	game.from_dict(d)
	_after_game_loaded()
	_close_modal()


func _save_game() -> void:
	if game == null or game.game_over:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(game.to_dict()))


func _after_game_loaded() -> void:
	map.setup(game, data.map)
	map.reset_dev_seen()
	map.check_dev_changes()
	hud.visible = true
	speed = 0
	selected_army = -1
	map.selected_army = -1
	map.selected_pid = -1
	last_log_count = game.log_lines.size()
	known_wars = {}
	for w in game.wars_of(game.player):
		known_wars[w.id] = true
	known_coalition = game.nations[game.player].coalition.size()
	map.focus(game.provinces[game.nations[game.player].capital].center, 1.3)
	_close_panel()
	_update_top()


func _show_intro() -> void:
	var n = game.nations[game.player]
	_open_modal()
	modal_box.add_child(_lbl("%s, %s" % [nname(game.player), game.date_string()], 30))
	modal_box.add_child(_lbl(n.idea, 18, Color(0.8, 0.85, 0.7)))
	modal_box.add_child(_lbl("So spielst du:\n• Zeit läuft mit ▶/➕ oben rechts, ⏸ pausiert.\n• Tippe auf eine Provinz für Infos und Aktionen (Entwickeln, Rekrutieren, Krieg).\n• Tippe auf eine Armee (Kreis mit Zahl) und dann auf ein Ziel, um sie zu bewegen. 🤖 lässt sie automatisch kämpfen.\n• 📜 Admin, 🕊️ Diplomatie und ⚔️ Militär sammeln sich monatlich: für Technologie, Entwicklung, Bündnisse und Kriegsgründe.\n• 😠 Aggressive Expansion steigt bei Eroberungen. Ab %d bilden Nachbarn Koalitionen gegen dich.\n• ✊ Frisch eroberte Provinzen sind unruhig, Kriegsmüdigkeit verstärkt das. Garnisonen und Unterdrückung helfen.\n• Am PC: Leertaste = Pause, 1–5 = Tempo, Esc = Panel schließen." % int(game.bal.ae_coalition_threshold), 17))
	modal_box.add_child(_btn("Los geht's ▶", func(): _close_modal(); _set_speed(2)))


## ScrollContainers that scroll by dragging anywhere on them, also when the finger starts on a button.
func register_scroll(sc: ScrollContainer) -> void:
	_scrolls.append(sc)


func _scroll_at(pos: Vector2) -> ScrollContainer:
	for i in range(_scrolls.size() - 1, -1, -1):
		var sc: ScrollContainer = _scrolls[i]
		if is_instance_valid(sc) and sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos):
			return sc
	return null


## True if a visible Range control (slider, scroll bar, spin box) lies under `pos`.
func _range_at(node: Node, pos: Vector2) -> bool:
	if node is CanvasItem and not node.visible:
		return false
	if node is Range and node.get_global_rect().has_point(pos):
		return true
	for c in node.get_children():
		if _range_at(c, pos):
			return true
	return false


## Deepest visible control under `pos` that carries a tooltip.
func _tooltip_at(node: Node, pos: Vector2) -> Control:
	if node is CanvasItem and not node.visible:
		return null
	for i in range(node.get_child_count() - 1, -1, -1):
		var hit := _tooltip_at(node.get_child(i), pos)
		if hit != null:
			return hit
	if node is Control and node.tooltip_text != "" and node.mouse_filter != Control.MOUSE_FILTER_IGNORE \
			and node.get_global_rect().has_point(pos):
		return node
	return null


func _show_tip(text: String, pos: Vector2) -> void:
	if _tip_panel == null:
		_tip_panel = PanelContainer.new()
		_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_tip_panel.add_theme_stylebox_override("panel", UiTheme.box("tooltip", 12))
		_tip_label = Label.new()
		_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tip_label.add_theme_font_size_override("font_size", 20 if _big() else 17)
		_tip_panel.add_child(_tip_label)
		add_child(_tip_panel)
	var w: float = minf(520.0, size.x - 32.0)
	_tip_label.text = text
	_tip_label.custom_minimum_size = Vector2(w - 20, 0)
	_tip_panel.reset_size()
	_tip_panel.size = Vector2(w, 0)
	_tip_panel.position = Vector2(clampf(pos.x - w / 2, 16, size.x - w - 16), maxf(16, pos.y - 140))
	_tip_panel.visible = true
	_sfx("click", -18.0)


func _input(event: InputEvent) -> void:
	var down := false
	var up := false
	var moved := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		down = event.pressed
		up = not event.pressed
		pos = event.position
	elif event is InputEventScreenDrag:
		if event.index != 0:
			return
		moved = true
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_echo():
		if DisplayServer.is_touchscreen_available():
			return  # emulated from touch: the screen events above already handled it
		down = event.pressed
		up = not event.pressed
		pos = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if DisplayServer.is_touchscreen_available():
			return
		moved = true
		pos = event.position
	else:
		return
	if down:
		if _tip_panel != null:
			_tip_panel.visible = false
		_suppress_click = false
		_dragging = false
		_press_pos = pos
		_press_time = Time.get_ticks_msec() / 1000.0
		# sliders and scroll bars keep their own drag
		_press_scroll = null if _range_at(self, pos) else _scroll_at(pos)
		_press_scroll_start = _press_scroll.scroll_vertical if _press_scroll != null else 0
	elif moved and _press_time >= 0.0:
		if not _dragging and _press_scroll != null and pos.distance_to(_press_pos) > DRAG_START:
			_dragging = true
			_suppress_click = true
		if _dragging:
			_press_scroll.scroll_vertical = _press_scroll_start - int(pos.y - _press_pos.y)
			get_viewport().set_input_as_handled()
	elif up:
		_press_time = -1.0
		_press_scroll = null


func _check_long_press() -> void:
	if _press_time < 0.0 or _dragging or _suppress_click:
		return
	if Time.get_ticks_msec() / 1000.0 - _press_time < LONG_PRESS:
		return
	var c := _tooltip_at(self, _press_pos)
	if c != null:
		_suppress_click = true
		_show_tip(c.tooltip_text, _press_pos)


## Box hugs the text (max 840 px, wraps beyond), centered over the free map area
## (left of an open side panel, right of the tab column).
func _place_toast() -> void:
	var f: Font = toast.get_theme_font("font")
	var panel_w: float = -side_panel.offset_left if side_panel.visible else 0.0
	var room: float = get_viewport_rect().size.x - panel_w - 200.0
	var w: float = minf(minf(840.0, room), f.get_string_size(toast.text, HORIZONTAL_ALIGNMENT_LEFT, -1, toast.get_theme_font_size("font_size")).x + 40.0)
	var shift: float = (200.0 - panel_w) / 2.0
	toast.offset_left = shift - w / 2.0
	toast.offset_right = shift + w / 2.0


func _process(delta: float) -> void:
	_check_long_press()
	if toast_time > 0.0:
		_place_toast()
		toast_time -= delta
		if toast_time <= 0.0:
			toast.text = ""
			toast.visible = false
	if game == null or modal.visible or speed == 0 or game.game_over:
		return
	acc += delta
	var spm: float = SPEEDS[speed]
	var steps := 0
	# frame budget: slow devices run fewer months per second instead of stuttering, and never try to catch up
	var t0 := Time.get_ticks_msec()
	acc = minf(acc, spm * 2.0)
	while acc >= spm and steps < 4 and (steps == 0 or Time.get_ticks_msec() - t0 < 12):
		acc -= spm
		game.tick()
		steps += 1
		if game.month % 12 == 0:
			_save_game()
		if not game.pending_events.is_empty() or not game.pending_peace.is_empty() or game.game_over:
			break
	if steps > 0:
		_after_tick()


func _after_tick() -> void:
	_update_top()
	map.check_dev_changes()
	var battles: int = game.stats.get("player_battles_won", 0) + game.stats.get("player_battles_lost", 0)
	if battles > last_battles:
		_sfx("battle", -10.0)
	last_battles = battles
	map.queue_redraw()
	if game.log_lines.size() != last_log_count:
		if not game.log_lines.is_empty():
			_toast(game.log_lines[-1])
		last_log_count = game.log_lines.size()
	if game.game_over:
		_show_game_over()
		return
	if _check_alerts():
		return
	if not game.pending_events.is_empty():
		_show_event(game.pending_events[0])
		return
	if not game.pending_peace.is_empty():
		_show_peace_offer(game.pending_peace[0])
		return
	if side_panel.visible and panel_mode != "peace":
		_refresh()


const MODE_LEGENDS := [
	"Jede Nation in ihrer Farbe.",
	"Deine Beziehungen zu allen Nationen.",
	"Dunkel = arm, gelb = reich.",
	"Eigene Provinzen: grün = ruhig, rot = Aufstand droht.",
	"Deine Kriege auf einen Blick. Streifen = besetzt.",
	"Welches Gut jede Provinz herstellt (eigene Provinzen hell).",
	"Einzugsgebiete der Märkte, das Zentrum leuchtet hell (eigene Provinzen hell).",
	"Gebäudestufen je Provinz: dunkel = nichts gebaut, gold = gut ausgebaut, bläulich = Baustelle. Fremde Provinzen dunkler.",
	"Glaube der Bevölkerung. Gestreift: anderer Glaube als der Herrscher (+Unruhe).",
]
## Color keys per map mode: [color, text]
const MODE_KEYS := {
	1: [["3a9d4a", "du"], ["7fc98a", "deine Vasallen"], ["4a7fd0", "Verbündete"], ["c0392b", "Feinde"],
		["e0a030", "Ansprüche"], ["8e3a8e", "Koalition gegen dich"], ["3fae9e", "Garantie"],
		["c08ab8", "verheiratet"], ["b09a62", "Durchmarschrecht"], ["9aa7b0", "Waffenstillstand"]],
	4: [["3a9d4a", "du"], ["4a7fd0", "Mitkämpfer"], ["c0392b", "Feinde"], ["5a5a52", "unbeteiligt"]],
	8: [["e8d27a", "katholisch"], ["9a5ac8", "protestantisch"], ["6a9ae0", "orthodox"], ["3fa860", "sunnitisch"]],
}


func _cycle_map_mode() -> void:
	_set_map_mode((map.map_mode + 1) % map.MODE_NAMES.size())


func _set_map_mode(i: int) -> void:
	map.map_mode = i
	map.queue_redraw()
	_toast("🗺️ Kartenmodus: " + map.MODE_NAMES[i])
	if panel_mode == "mapmodes":
		_refresh()


## Pops up things that directly affect the player. Returns true if a popup was shown.
func _check_alerts() -> bool:
	var me: String = game.player
	for w in game.wars_of(me):
		if known_wars.has(w.id):
			continue
		known_wars[w.id] = true
		if game.is_attacker(w, me) and w.attackers[0] == me:
			continue
		var att: bool = game.is_attacker(w, me)
		var them := []
		for t in game.side_tags(w, not att):
			them.append(nname(t))
		_set_speed(0)
		_open_modal()
		if att:
			modal_box.add_child(_lbl("📯 Ruf zu den Waffen", 28))
			modal_box.add_child(_lbl("Unser Verbündeter %s zieht in den Krieg (%s). Wir kämpfen an seiner Seite gegen: %s" % [nname(w.attackers[0]), w.name, ", ".join(them)]))
		else:
			_sfx("war")
			modal_box.add_child(_lbl("🔥 Krieg!", 28))
			modal_box.add_child(_lbl("%s hat uns den Krieg erklärt (%s).\nGegner: %s" % [nname(w.attackers[0]), w.name, ", ".join(them)]))
		modal_box.add_child(_btn("⚔️ Zu den Waffen", func(): _close_modal(); _open_panel("wars")))
		return true
	var co: int = game.nations[me].coalition.size()
	if co > known_coalition and co >= 2:
		known_coalition = co
		_set_speed(0)
		_open_modal()
		modal_box.add_child(_lbl("⚠️ Koalition gegen uns!", 28))
		modal_box.add_child(_lbl("%d Nationen haben sich wegen unserer aggressiven Expansion (😠 %d) gegen uns verbündet. Senke die AE (Zeit, Diplomatie-Technologie), sonst greifen sie an." % [co, int(game.nations[me].ae)]))
		modal_box.add_child(_btn("Verstanden", _close_modal))
		return true
	known_coalition = mini(known_coalition, co)
	return _check_tips()


const TIPS := {
	"war": ["⚔️ Krieg", "Armeen ziehen per Antippen: Armee wählen, dann Zielprovinz. Mit 🤖 kämpft eine Armee selbst. Besetze feindliche Provinzen, um Kriegspunkte zu sammeln, und verhandle unter ⚔️ Kriege den Frieden."],
	"occupied": ["🏳️ Besetzt", "Du hältst feindliche Provinzen. Unter ⚔️ Kriege → Friedensverhandlung kannst du sie fordern oder den Gegner zum Vasallen machen. Ein orangefarbener Punkt am Tab zeigt, wann sich Frieden lohnt."],
	"unrest": ["✊ Unruhe", "Frisch erobertes Land ist unruhig, Kriegsmüdigkeit macht es schlimmer. Ab 5 droht ein Aufstand, und die Provinz kann zum alten Besitzer zurückfallen. Hilfe: Armee in der Provinz lassen oder ✊ Unruhe unterdrücken. Der Kartenmodus 'Unruhe' zeigt die Lage."],
	"ae": ["😠 Aggressive Expansion", "Deine Eroberungen machen die Nachbarn nervös. Ab %d bilden sie Koalitionen und greifen gemeinsam an. Mach Pausen, vasallisiere statt zu annektieren und nutze Ansprüche (weniger AE)."],
	"tech": ["🔬 Technologie", "Du kannst eine Technologie erforschen (🔬 Technologie). Der Punkt am Tab zeigt das an. Jede Kategorie hat drei Zweige, die du in beliebiger Reihenfolge ausbaust, dazu kommen nationale Spezial-Technologien. Unter ⚖️ Regierung ernennst du Berater, gründest Kompanien und wählst Gesetze."],
	"mission": ["🎯 Mission erfüllt", "Eine Mission ist erfüllt. Hole dir die Belohnung unter 🎯 Missionen."],
	"debt": ["💸 Schulden", "Deine Kasse ist leer. Unter −20 Gold desertieren Truppen. Nimm unter 💰 Wirtschaft einen Kredit auf, entlasse Regimenter oder schließe Frieden: Im Frieden kosten Armeen weniger."],
	"build": ["🏗️ Gebäude", "Gold investierst du in Gebäude: Provinz antippen → Gebäude. Jede fertige Stufe bringt +1 Entwicklung (außer Straßen). Unter 💰 Wirtschaft kannst du den Autobau einschalten und eine Mindestkasse festlegen."],
	"manpower": ["👥 Keine Mannschaften", "Dir gehen die Mannschaften aus. Söldner (Provinzfenster) kosten mehr Gold, brauchen aber keine Mannschaften. Gutshöfe und Kasernen erhöhen das Maximum."],
	"trade": ["🏬 Handel", "Unter 💰 Wirtschaft → Handel schickst du Händler in reiche Märkte. Handelsabkommen mit befreundeten Reichen (Länderfenster) bringen je +6 % Handelseinnahmen."],
}


## One-time beginner hints, shown when they become relevant. Returns true if one was shown.
func _check_tips() -> bool:
	if not settings.get("tips", true):
		return false
	var me: String = game.player
	var n = game.nations[me]
	var seen: Array = settings.tips_seen
	var cand := []
	if game.is_at_war(me):
		cand.append("war")
		for w in game.wars_of(me):
			if not game.demandable(w, game.is_attacker(w, me)).is_empty():
				cand.append("occupied")
				break
	for pid in game.provinces_of(me):
		if game.unrest(pid) >= 3.0:
			cand.append("unrest")
			break
	if n.ae >= float(game.bal.ae_coalition_threshold) * 0.5:
		cand.append("ae")
	if game.month >= 6 and tab_badges.tech.visible:
		cand.append("tech")
	if tab_badges.missions.visible:
		cand.append("mission")
	if n.gold < 0.0:
		cand.append("debt")
	if game.is_at_war(me) and n.manpower < 1.0:
		cand.append("manpower")
	if game.month >= 12 and n.gold >= 120.0 and not n.autobuild:
		cand.append("build")
	if game.month >= 48:
		cand.append("trade")
	var due := ""
	for c in cand:
		if not seen.has(c):
			due = c
			break
	if due == "":
		return false
	seen.append(due)
	_save_settings()
	_set_speed(0)
	_open_modal()
	var tip: Array = TIPS[due]
	var body: String = tip[1] % int(game.bal.ae_coalition_threshold) if due == "ae" else tip[1]
	modal_box.add_child(_lbl("💡 " + tip[0], 26))
	modal_box.add_child(_lbl(body, 18))
	modal_box.add_child(_row([_btn("Verstanden", _close_modal), _btn("Keine Tipps mehr", func():
		settings.tips = false
		_save_settings()
		_close_modal())]))
	return true


func _set_speed(s: int) -> void:
	speed = s
	acc = 0.0
	_update_top()


func _update_top() -> void:
	if game == null:
		return
	var n = game.nations[game.player]
	var net: float = n.income - n.expenses + game.tribute_income(game.player)
	top_labels.nation.text = nname(game.player)
	top_labels.gold.text = Icons.prefix("gold") + "%d (%+.1f)" % [n.gold, net]
	top_labels.adm.text = Icons.prefix("adm") + "%d" % n.adm
	top_labels.dip.text = Icons.prefix("dip") + "%d" % n.dip
	top_labels.mil.text = Icons.prefix("mil") + "%d" % n.mil
	top_labels.manpower.text = Icons.prefix("manpower") + "%.0f" % n.manpower
	top_labels.army.text = Icons.prefix("army") + "%.0f/%.0f" % [game.army_regs(game.player), game.force_limit(game.player)]
	top_labels.ae.text = Icons.prefix("ae") + "%d" % n.ae
	top_labels.ae.add_theme_color_override("font_color", Color.TOMATO if n.ae >= game.bal.ae_coalition_threshold * 0.7 else Color.WHITE)
	top_labels.gold.add_theme_color_override("font_color", Color.TOMATO if n.gold < 0 else Color.WHITE)
	top_labels.date.text = Icons.prefix("date") + game.date_string()
	# live tooltips (long press on mobile)
	var trib: float = game.tribute_income(game.player)
	top_labels.gold.tooltip_text = "Gold %d · Bilanz %+.2f/Monat\nEinnahmen %.2f (Steuern %.2f, Güter %.2f, Handel %.2f)\nAusgaben %.2f%s" % [
			n.gold, net, n.income, n.tax_income, n.prod_income, n.trade_income, n.expenses, ("\nTribut %+.2f" % trib) if trib != 0.0 else ""]
	var cap := int(game.bal.power_cap)
	for k in ["adm", "dip", "mil"]:
		top_labels[k].tooltip_text = "%s\n%+.1f pro Monat, Obergrenze %d" % [HUD_TIPS[k], game.monthly_power(n, k), cap]
	top_labels.manpower.tooltip_text = "Mannschaften %.0f / %.0f\nFüllen sich jeden Monat auf; Gutshöfe und Kasernen erhöhen das Maximum." % [n.manpower, n.max_manpower]
	top_labels.army.tooltip_text = "Regimenter / Truppenlimit\nMehr Regimenter als das Limit kannst du nicht ausheben. Kasernen, Technik und Ränge erhöhen es."
	top_labels.ae.tooltip_text = "Aggressive Expansion %d (Koalitionsgrenze %d)\nSinkt langsam; hohe Werte machen Nachbarn feindlich." % [n.ae, int(game.bal.ae_coalition_threshold)]
	speed_label.text = "⏸" if speed == 0 else "▶".repeat(speed)
	_update_badges()


## Small dots on the left tabs when something can be done there.
func _update_badges() -> void:
	if tab_badges.is_empty():
		return
	var me: String = game.player
	var n = game.nations[me]
	tab_badges.tech.visible = tech_screen.can_research(game, me)
	tab_badges.government.visible = gov_screen.can_act(game, me)
	var unrest := false
	for pid in game.provinces_of(me):
		if game.unrest(pid) >= float(game.bal.revolt_threshold) and game.provinces[pid].suppress_months == 0:
			unrest = true
			break
	tab_badges.nation.visible = unrest
	var mission := false
	for m in game.available_missions(me):
		if game.mission_ready(me, m):
			mission = true
	tab_badges.missions.visible = mission
	var annex := false
	for v in game.vassals_of(me):
		if game.annex_months_left(v) == 0:
			annex = true
	tab_badges.diplomacy.visible = annex
	var peace := false
	for w in game.wars_of(me):
		var att: bool = game.is_attacker(w, me)
		if game.side_tags(w, att)[0] == me and game.warscore(w) * (1.0 if att else -1.0) >= 25.0:
			peace = true
	tab_badges.wars.visible = peace
	# economy: something to do with the money
	var Eco = game.Economy
	var why := ""
	if n.gold < 0.0:
		why = "Die Kasse ist im Minus: Kredit aufnehmen oder Armeen verkleinern."
	elif n.income - n.expenses < 0.0:
		why = "Die Monatsbilanz ist negativ."
	elif not n.merchant_auto and n.merchants.size() < Eco.merchant_count(game, n):
		why = "Ein Händler ist frei."
	elif not n.loans.is_empty() and n.gold >= float(n.loans[n.loans.size() - 1]) + 100.0 and not game.is_at_war(me):
		why = "Ein Kredit kann getilgt werden."
	elif not n.autobuild and not game.is_at_war(me):
		var best: Array = Eco.best_building(game, n, false)
		if not best.is_empty() and n.gold >= Eco.building_cost(game, me, best[0], best[1]) + 50.0:
			why = "Genug Gold für ein neues Gebäude (oder Autobau einschalten)."
	tab_badges.economy.visible = why != ""
	tab_badges.economy.get_parent().tooltip_text = "Wirtschaft" + (("\n● " + why) if why != "" else "")


## Desktop shortcuts: Space pauses/resumes, 1-5 set the speed, Esc closes panels.
func _unhandled_input(event: InputEvent) -> void:
	if game == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_SPACE and not modal.visible:
		if speed == 0:
			_set_speed(last_speed)
		else:
			last_speed = speed
			_set_speed(0)
	elif k >= KEY_1 and k <= KEY_5 and not modal.visible:
		_set_speed(k - KEY_0)
	elif k == KEY_ESCAPE:
		if side_panel.visible:
			_close_panel()
		elif not modal.visible:
			_show_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal.visible and game != null and game.pending_events.is_empty() and game.pending_peace.is_empty():
			_close_modal()
		elif side_panel.visible:
			_panel_back()
		else:
			_show_menu()


# ---------------------------------------------------------------- modal popups

func _open_modal() -> void:
	_clear(modal_box)
	modal.visible = true


func _close_modal() -> void:
	modal.visible = false
	_refresh()


func _show_menu() -> void:
	if game == null:
		return
	_set_speed(0)
	_open_modal()
	modal_box.add_child(_lbl("☰ Menü", 30))
	modal_box.add_child(_btn("▶ Weiter", _close_modal))
	modal_box.add_child(_btn("💾 Speichern", func(): _save_game(); _toast("💾 Gespeichert."); _close_modal()))
	modal_box.add_child(_btn("📂 Laden", _load_game))
	modal_box.add_child(_btn("🔠 UI-Größe: %d%%" % int(round(float(settings.ui_scale) * 100)), _cycle_ui_scale))
	if not OS.has_feature("mobile"):
		modal_box.add_child(_btn("👆 Große Bedienelemente: %s (Leisten nach Neustart)" % ("an" if settings.get("big_ui", false) else "aus"), func():
			settings.big_ui = not settings.get("big_ui", false)
			_save_settings()
			_show_menu()))
	modal_box.add_child(_btn("🔊 Ton: %s" % ("an" if settings.get("sound", true) else "aus"), func():
		settings.sound = not settings.get("sound", true)
		_save_settings()
		_show_menu()))
	modal_box.add_child(_btn("💡 Tipps: %s" % ("an" if settings.tips else "aus"), func():
		settings.tips = not settings.tips
		if settings.tips:
			settings.tips_seen = []
		_save_settings()
		_show_menu()))
	modal_box.add_child(_btn("🏠 Hauptmenü (speichert)", func(): _save_game(); game = null; _show_start_menu()))
	if OS.get_name() != "Android":
		modal_box.add_child(_btn("🚪 Beenden", func(): _save_game(); get_tree().quit()))


func _show_event(event_id: String) -> void:
	var e: Dictionary = game.event_by_id[event_id]
	_sfx("event")
	_open_modal()
	var pic := _event_picture(e)
	if pic != null:
		modal_box.add_child(pic)
	modal_box.add_child(_lbl("📯 " + e.title, 28))
	modal_box.add_child(_lbl(e.text, 18))
	for i in e.options.size():
		var o: Dictionary = e.options[i]
		modal_box.add_child(_rich_btn(o.text, effects_bb(o.get("effects", {})), _choose_event.bind(event_id, i)))


var _event_motifs = null


## Framed pixel-art scene for an event: its "image" field, else assets/art/events/event_motifs.json
## (tools/art/event_motifs.py), else the court scene. Several events share one motif.
func _event_picture(e: Dictionary) -> TextureRect:
	if _event_motifs == null:
		var f := FileAccess.open("res://assets/art/events/event_motifs.json", FileAccess.READ)
		_event_motifs = JSON.parse_string(f.get_as_text()) if f != null else {}
	var motif: String = e.get("image", _event_motifs.get(e.id, "court"))
	var path := "res://assets/art/events/%s.png" % motif
	if not ResourceLoader.exists(path):
		return null
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(0, 200)
	return r


func _choose_event(event_id: String, idx: int) -> void:
	game.choose_event_option(game.player, event_id, idx)
	_close_modal()
	_update_top()
	map.queue_redraw()
	if not game.pending_events.is_empty():
		_show_event(game.pending_events[0])


func _show_peace_offer(offer: Dictionary) -> void:
	var w = game.war_by_id(int(offer.war))
	if w == null:
		game.pending_peace.erase(offer)
		return
	_open_modal()
	modal_box.add_child(_lbl("🕊️ Friedensangebot", 28))
	var names := []
	for pid in offer.pids:
		names.append("%s (%d)" % [game.provinces[pid].name, game.provinces[pid].dev])
	var ws: float = game.warscore(w) * (1.0 if game.is_attacker(w, game.player) else -1.0)
	var who: String = nname(offer.from)
	var txt := ""
	if offer.pids.is_empty():
		txt = "%s bietet einen weißen Frieden an (keine Gebietsänderungen)." % who
	elif offer.get("from_receives", true):
		txt = "%s fordert: %s" % [who, ", ".join(names)]
	else:
		txt = "%s bietet uns an: %s" % [who, ", ".join(names)]
	modal_box.add_child(_lbl(txt + "\nKriegspunktestand (unsere Sicht): %+d" % int(ws), 18))
	modal_box.add_child(_btn("✅ Annehmen", func(): game.answer_player_peace(offer, true); _close_modal(); map.queue_redraw(); _update_top()))
	modal_box.add_child(_btn("❌ Ablehnen", func(): game.answer_player_peace(offer, false); _close_modal()))


func _show_game_over() -> void:
	_set_speed(0)
	_open_modal()
	var alive: bool = game.nations[game.player].alive
	modal_box.add_child(_lbl("🏁 Spielende" if alive else "☠️ Deine Nation wurde vernichtet", 32))
	var ranking := []
	for tag in game.order:
		if game.nations[tag].alive:
			ranking.append([game.score(tag), tag])
	ranking.sort_custom(func(a, b): return a[0] > b[0])
	var text := ""
	for i in mini(10, ranking.size()):
		var tag: String = ranking[i][1]
		var mark := "  ⬅️" if tag == game.player else ""
		text += "%d. %s – %d Punkte%s\n" % [i + 1, nname(tag), int(ranking[i][0]), mark]
	for i in ranking.size():
		if ranking[i][1] == game.player and i >= 10:
			text += "…\n%d. %s – %d Punkte\n" % [i + 1, nname(game.player), int(ranking[i][0])]
	modal_box.add_child(_lbl(text, 18))
	modal_box.add_child(_lbl(_summary_text(), 16, Color(0.85, 0.85, 0.75)))
	if game.history.size() >= 2:
		modal_box.add_child(_history_chart(260))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	modal_box.add_child(_btn("🏠 Hauptmenü", func(): game = null; _show_start_menu()))


# ---------------------------------------------------------------- side panel

func _summary_text() -> String:
	var s: Dictionary = game.stats
	var h: Array = game.history
	var t := "Deine Bilanz:\n"
	if not h.is_empty():
		var best := 999
		var peak := 0
		for e in h:
			best = mini(best, e[2])
			peak = maxi(peak, e[1])
		t += "🏘️ Entwicklung %d → %d (Höchststand %d) · Bester Rang: %d\n" % [h[0][1], h[-1][1], peak, best]
	t += "⚔️ Schlachten %d gewonnen / %d verloren · 🕊️ Kriege %d gewonnen / %d verloren\n" % [
			s.get("player_battles_won", 0), s.get("player_battles_lost", 0), s.get("player_wins", 0), s.get("player_losses", 0)]
	t += "🎯 Missionen erfüllt: %d" % game.nations[game.player].missions_done.size()
	return t


## Line chart of the player's development (gold) and rank (blue, top = 1st) over the years.
func _history_chart(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(300, height)
	var h: Array = game.history
	c.draw.connect(func():
		var sz: Vector2 = c.size
		c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.1, 0.11, 0.14))
		if h.size() < 2:
			return
		var max_dev := 1.0
		var min_dev := 1e9
		for e in h:
			max_dev = maxf(max_dev, e[1])
			min_dev = minf(min_dev, e[1])
		# show the change, not the absolute size: axis from just below the minimum to just above the maximum
		var lo: float = maxf(0.0, min_dev - maxf(5.0, (max_dev - min_dev) * 0.15))
		var hi: float = max_dev + maxf(5.0, (max_dev - min_dev) * 0.15)
		var dev_pts := PackedVector2Array()
		var rank_pts := PackedVector2Array()
		var n: int = game.order.size()
		for i in h.size():
			var x: float = 8.0 + (sz.x - 16.0) * i / (h.size() - 1)
			dev_pts.append(Vector2(x, sz.y - 24.0 - (sz.y - 72.0) * (h[i][1] - lo) / (hi - lo)))
			rank_pts.append(Vector2(x, 48.0 + (sz.y - 72.0) * (h[i][2] - 1) / maxf(1.0, n - 1)))
		c.draw_polyline(rank_pts, Color(0.35, 0.6, 1.0, 0.8), 2.0)
		c.draw_polyline(dev_pts, Color(1.0, 0.8, 0.3), 3.0)
		var font := c.get_theme_default_font()
		c.draw_string(font, Vector2(10, 22), "🏘️ Entwicklung %d–%d" % [int(min_dev), int(max_dev)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.8, 0.3))
		c.draw_string(font, Vector2(10, 42), "🏆 Rang (oben = 1.)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.35, 0.6, 1.0))
		c.draw_string(font, Vector2(10, sz.y - 12), str(h[0][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.7))
		c.draw_string(font, Vector2(sz.x - 50, sz.y - 12), str(h[-1][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.7)))
	return c


## Large touch targets: always on phones, optional on desktop (menu).
func _big() -> bool:
	return OS.has_feature("mobile") or settings.get("big_ui", false)


func _open_panel(mode: String, arg = null, remember: bool = true) -> void:
	if game == null:
		return
	if remember and side_panel.visible and panel_mode != "" and (panel_mode != mode or panel_arg != arg):
		panel_history.append([panel_mode, panel_arg])
		if panel_history.size() > 12:
			panel_history.pop_front()
	side_back.visible = not panel_history.is_empty()
	panel_mode = mode
	panel_arg = arg
	side_panel.visible = true
	if mode != "army":
		selected_army = -1
		map.selected_army = -1
	if mode != "province":
		map.selected_pid = -1
	if mode == "peace":
		peace_selection = {}
	_refresh()
	side_scroll.scroll_vertical = 0
	map.queue_redraw()


func _panel_back() -> void:
	if panel_history.is_empty():
		_close_panel()
		return
	var prev: Array = panel_history.pop_back()
	if prev[0] == "army":
		_on_army_tapped(prev[1])
		side_back.visible = not panel_history.is_empty()
		return
	_open_panel(prev[0], prev[1], false)


func _close_panel() -> void:
	side_panel.visible = false
	panel_history.clear()
	side_back.visible = false
	panel_mode = ""
	selected_army = -1
	map.selected_army = -1
	map.selected_pid = -1
	map.queue_redraw()


func _refresh() -> void:
	_update_top()
	if not side_panel.visible or game == null:
		return
	var scroll := side_scroll.scroll_vertical
	_clear(side_box)
	match panel_mode:
		"province":
			_panel_province(panel_arg)
		"army":
			_panel_army(panel_arg)
		"nation":
			_panel_nation()
		"diplomacy":
			_panel_diplomacy()
		"other":
			_panel_other(panel_arg)
		"wars":
			_panel_wars()
		"peace":
			_panel_peace(panel_arg)
		"missions":
			_panel_missions()
		"log":
			_panel_log()
		"ranking":
			_panel_ranking()
		"hre":
			_panel_hre()
		"economy":
			_panel_economy()
		"mapmodes":
			_panel_mapmodes()
		"tech":
			tech_screen.build()
		"government":
			gov_screen.build()
		"modifiers":
			_panel_modifiers()
	side_scroll.set_deferred("scroll_vertical", scroll)


func _on_province_tapped(pid: int) -> void:
	if selected_army >= 0:
		var a = game.army_by_id(selected_army)
		if a != null and a.owner == game.player:
			a.auto = false
			var err: String = game.move_army(a, pid)
			if err == "":
				# one order per selection: the next tap on the map looks around instead of moving again
				selected_army = -1
				map.selected_army = -1
			_act(err, "🚶 Marschbefehl nach %s" % game.provinces[pid].name if err == "" else "")
			map.queue_redraw()
			return
	map.selected_pid = pid
	_open_panel("province", pid)
	map.selected_pid = pid


## Long press: province info without giving a march order.
func _on_province_info(pid: int) -> void:
	selected_army = -1
	map.selected_army = -1
	map.selected_pid = pid
	_open_panel("province", pid)
	map.selected_pid = pid


func _on_army_tapped(id: int) -> void:
	if selected_army == id:
		_close_panel()
		return
	# with an own army selected, tapping a foreign army means: march there (attack)
	var tapped = game.army_by_id(id)
	if selected_army >= 0 and tapped != null and tapped.owner != game.player:
		var mine = game.army_by_id(selected_army)
		if mine != null and mine.owner == game.player:
			_on_province_tapped(tapped.pid)
			return
	if side_panel.visible and panel_mode != "" and panel_mode != "army":
		panel_history.append([panel_mode, panel_arg])
	side_back.visible = not panel_history.is_empty()
	selected_army = id
	map.selected_army = id
	map.selected_pid = -1
	panel_mode = "army"
	panel_arg = id
	side_panel.visible = true
	_refresh()
	map.queue_redraw()


func _panel_province(pid: int) -> void:
	var p = game.provinces[pid]
	var me: String = game.player
	var n = game.nations[me]
	var Eco = game.Economy
	side_title.text = "📍 " + p.name
	var owner_btn := _nation_btn(p.owner, "", _open_panel.bind("other", p.owner), "Besitzer: ")
	if p.owner == me:
		owner_btn.disabled = true
	side_box.add_child(owner_btn)
	var own: bool = p.owner == me
	var tab: String = prov_tab if own else "info"
	if own:
		var tabs := []
		for e in [["info", "📍 Provinz"], ["build", "🏗️ Bauen"], ["army", "⚔️ Militär"]]:
			var key: String = e[0]
			var b := _btn(e[1], func(): prov_tab = key; _refresh())
			if tab == key:
				b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
				b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
			tabs.append(b)
		side_box.add_child(_row(tabs))
	if tab == "build":
		_province_buildings(p)
		return
	if tab == "army":
		_province_army(p)
		return
	var gd: Dictionary = game.goods_def[p.good]
	var price: float = game.prices[p.good]
	# one line per fact, each with an explanation (hover / long press)
	var rows: Array = []
	rows.append(["🏘️ Entwicklung: %d · %d Bauplätze" % [p.dev, Eco.slots(game, p)],
			"Entwicklung erhöht Steuern, Güterproduktion, Handelsmacht und Mannschaften. Alle %d Stufen gibt es einen Bauplatz mehr (höchstens %d)." % [int(game.bal.dev_per_building_slot), int(game.bal.building_slots_max)]])
	rows.append(["%s %s: %.1f × %.2f 💰 = %.2f/Monat" % [gd.emoji, gd.name, Eco.units(game, p), price, Eco.production_value(game, p)],
			"Produktion × Marktpreis. Die Menge wächst mit Entwicklung, Werkstatt, Manufaktur und Hafen; der Preis ändert sich jährlich mit Angebot und Nachfrage. Marktführer bei %s erhält: %s." % [gd.name, gd.bonus_text]])
	rows.append(["💰 Steuer: %.2f/Monat" % Eco.tax(game, p), "Steuern steigen mit Entwicklung und Marktplatz, Gesetze und Techs geben weitere Prozente."])
	rows.append(["🏬 Markt %s · Handelsmacht %.0f" % [game.provinces[p.market].name, Eco.province_trade_power(game, p)],
			"Die Handelsmacht zählt im Markt %s. Dein Anteil an allen Handelsmächten dort ergibt deinen Anteil am Marktwert. Marktplatz und Hafen steigern sie, Händler im Markt noch mehr." % game.provinces[p.market].name])
	var faith_txt := "⛪ Glaube: " + Faith.faith_name(p.religion)
	if p.religion != game.nations[p.owner].religion:
		faith_txt += " (fremd für %s)" % game.nations[p.owner].name
	if p.convert_months > 0:
		faith_txt += " · Missionar: noch %d Monate" % p.convert_months
	rows.append([faith_txt, "Provinzen mit anderem Glauben als ihr Herrscher haben +%.0f Unruhe. Sie nehmen den Glauben des Herrschers langsam von selbst an (etwa %d %% pro Jahr), ein Missionar schafft es in %d Monaten." % [
			float(game.bal.religion_unrest), int(float(game.bal.religion_drift) * 100), int(game.bal.convert_months)]])
	if p.coastal:
		rows.append(["⚓ Küstenprovinz", "Hier kann ein Hafen gebaut werden."])
	if Eco.fort_level(game, p) > 0:
		rows.append(["🏰 Festung Stufe %d" % Eco.fort_level(game, p), "Belagerungen dauern deutlich länger."])
	if p.core_months > 0:
		rows.append(["🔨 Wird integriert: noch %d Monate (%d %% Einkommen)" % [p.core_months, int(Eco.uncored_mult(game, p) * 100)],
				"Frisch erobertes Land bringt weniger Einkommen und mehr Unruhe, bis es integriert ist. Ein Gerichtshof hilft."])
	if p.controller != p.owner:
		rows.append(["🔥 Besetzt von " + game.nations[p.controller].name, "Besetzte Provinzen bringen ihrem Besitzer nichts ein."])
	if p.siege > 0:
		rows.append(["🔥 Belagerung: %d%%" % int(p.siege), "Bei 100 % fällt die Provinz an den Belagerer (bis zum Frieden)."])
	if n.claims.has(pid):
		rows.append(["📜 Du hast einen Anspruch", "Ein Anspruch ist ein Kriegsgrund und macht die Provinz im Frieden billiger."])
	if p.owner == me:
		var u: Dictionary = game.unrest_parts(pid)
		var why := []
		if u.uncored > 0:
			why.append("nicht integriert +%.0f" % u.uncored)
		if u.war > 0.05:
			why.append("Kriegsmüdigkeit +%.1f" % u.war)
		if u.garrison < 0:
			why.append("Garnison %.0f" % u.garrison)
		if u.suppressed < 0:
			why.append("unterdrückt %.0f (%d Mon.)" % [u.suppressed, p.suppress_months])
		if u.buildings < 0:
			why.append("Gebäude %.1f" % u.buildings)
		if absf(u.policy) >= 0.05:
			why.append("Regierung & Technik %+.1f" % u.policy)
		if absf(u.estates) >= 0.05:
			why.append("Stände %+.1f" % u.estates)
		if u.religion > 0:
			why.append("fremder Glaube +%.0f" % u.religion)
		rows.append(["✊ Unruhe %.1f / %d%s" % [u.total, int(game.bal.revolt_threshold), (" (" + ", ".join(why) + ")") if not why.is_empty() else ""],
				"Ab %d Unruhe drohen Aufstände. Senken: Truppen in der Provinz, Unterdrücken, Gerichtshof, Festung, Gesetze, zufriedene Stände." % int(game.bal.revolt_threshold)])
		if p.prev_owner != "" and p.core_months > 0 and game.nations[p.prev_owner].alive:
			rows.append(["⚠️ Bei einem Aufstand fällt die Provinz an %s zurück." % game.nations[p.prev_owner].name, ""])
	for r in rows:
		var l := _lbl(r[0])
		if r[1] != "":
			l.tooltip_text = r[1]
			l.mouse_filter = Control.MOUSE_FILTER_STOP
		side_box.add_child(l)
	if p.owner == me:
		if game.unrest(pid) > 0.0 and p.suppress_months == 0:
			side_box.add_child(_btn("✊ Unruhe unterdrücken (%d ⚔️)" % int(game.suppress_cost(pid)), func(): _act(game.suppress_unrest(me, pid), "✊ Ruhe wiederhergestellt")))
		if p.religion != game.nations[me].religion and p.convert_months == 0:
			var cv: String = Faith.convert_block_reason(game, me, pid)
			side_box.add_child(_btn("⛪ Missionar entsenden (%d 💰)" % int(Faith.convert_cost(game, p)), func(): _act(Faith.send_missionary(game, me, pid), "⛪ Der Missionar ist unterwegs"),
					"In %d Monaten nimmt die Provinz deinen Glauben (%s) an: −%.0f Unruhe. Höchstens %d Missionare gleichzeitig.%s" % [
					int(game.bal.convert_months), Faith.faith_name(game.nations[me].religion), float(game.bal.religion_unrest), int(game.bal.max_missionaries), ("\n❌ " + cv) if cv != "" else ""], cv != ""))
		if p.core_months > 0:
			side_box.add_child(_btn("🤝 Integrieren: −%d Monate (%d 🕊️)" % [int(game.bal.integrate_months), int(game.bal.integrate_cost)],
					func(): _act(game.integrate(me, pid), "🤝 Die Provinz rückt näher"),
					"Diplo-Macht einsetzen: Gesandte gewinnen die Bevölkerung, die Provinz wird schneller zum Kernland (volles Einkommen, weniger Unruhe)."))
		side_box.add_child(_btn("📜 Entwickeln (%d Admin)" % game.develop_cost(pid), func(): _act(game.develop(me, pid), "🏘️ Entwicklung erhöht"),
				"+1 Entwicklung: mehr Steuer, Güter, Handelsmacht und Mannschaften. Alle %d Stufen ein Bauplatz mehr." % int(game.bal.dev_per_building_slot)))
		var free: int = Eco.slots(game, p) - p.buildings.size()
		if p.constructing.is_empty():
			side_box.add_child(_lbl("🏗️ %d Gebäude, %d freie Plätze → Reiter 🏗️ Bauen" % [p.buildings.size(), maxi(0, free)], 16, Color(0.75, 0.8, 0.85)))
		else:
			var cd: Dictionary = game.buildings_def[p.constructing.id]
			side_box.add_child(_lbl("🏗️ Im Bau: %s %s, noch %d Monate" % [cd.emoji, cd.name, p.constructing.months], 16, Color(0.95, 0.8, 0.4)))
	else:
		if not p.buildings.is_empty():
			var bl := []
			for b in p.buildings:
				bl.append("%s %s %d" % [game.buildings_def[b].emoji, game.buildings_def[b].name, p.buildings[b]])
			side_box.add_child(_lbl("Gebäude: " + ", ".join(bl), 16, Color(0.75, 0.8, 0.85)))
		var borders := false
		for a in p.adj:
			if game.provinces[a].owner == me:
				borders = true
		if borders and not n.claims.has(pid):
			side_box.add_child(_btn("📜 Anspruch fabrizieren (%d 🕊️)" % int(game.bal.claim_cost), func(): _act(game.fabricate_claim(me, pid), "📜 Anspruch erhoben")))
		if not game.at_war(me, p.owner):
			side_box.add_child(_btn("🔥 Krieg gegen %s…" % game.nations[p.owner].name, _confirm_war.bind(p.owner)))
	_province_armies(pid)


## Military tab of an own province: recruiting, mercenaries and the armies here.
func _province_army(p) -> void:
	var me: String = game.player
	var pid: int = p.id
	var c := int(game.bal.regiment_cost)
	var n = game.nations[me]
	side_box.add_child(_lbl("👥 Mannschaften %.0f · 🛡️ %.0f / %.0f Regimenter" % [n.manpower, game.army_regs(me), game.force_limit(me)], 16, Color(0.75, 0.8, 0.85)))
	side_box.add_child(_row([
		_btn("⚔️ +1 Reg. (%d💰)" % c, func(): _act(game.recruit(me, pid, 1), "⚔️ Rekrutiert")),
		_btn("⚔️ +5 (%d💰)" % (c * 5), func(): _act(game.recruit(me, pid, 5), "⚔️ Rekrutiert"))]))
	var wait: int = game.merc_ready_in(me)
	side_box.add_child(_btn("💰 Söldner: %d Reg. (%d💰)%s" % [int(game.bal.merc_regs), int(game.merc_cost(me)), (" · in %d Mon." % wait) if wait > 0 else ""],
			func(): _act(game.hire_mercs(me, pid), "💰 Söldner angeworben"),
			"Sofort %d Regimenter ohne Mannschaften, kostet aber das %d-fache Gold. Einmal alle %d Monate." % [int(game.bal.merc_regs), int(game.bal.merc_cost_mult), int(game.bal.merc_cooldown)], wait > 0))
	_province_armies(pid)


func _province_armies(pid: int) -> void:
	var me: String = game.player
	if not game.armies_of(me).is_empty():
		side_box.add_child(_btn("🏁 Alle meine Armeen hierher", _all_armies_to.bind(pid), "Schickt jede eigene Armee in diese Provinz (danach manuell)."))
	var here: Array = game.armies_in(pid)
	if not here.is_empty():
		side_box.add_child(_lbl("Armeen hier:", 18, Color(0.7, 0.8, 0.9)))
		for a in here:
			side_box.add_child(_nation_btn(a.owner, "  %.1f Reg." % a.regs, _on_army_tapped.bind(a.id)))


## Building list of an own province: one row per building with level and a build/upgrade button.
func _province_buildings(p) -> void:
	var me: String = game.player
	var Eco = game.Economy
	side_box.add_child(_lbl("🏗️ Gebäude (%d / %d Plätze)" % [p.buildings.size(), Eco.slots(game, p)], 20))
	if not p.constructing.is_empty():
		var cd: Dictionary = game.buildings_def[p.constructing.id]
		side_box.add_child(_lbl("🏗️ Im Bau: %s %s Stufe %d, noch %d Monate" % [cd.emoji, cd.name, Eco.level(p, p.constructing.id) + 1, p.constructing.months], 16, Color(0.95, 0.8, 0.4)))
	for bid in game.buildings_def:
		var d: Dictionary = game.buildings_def[bid]
		var lvl: int = Eco.level(p, bid)
		var maxl: int = Eco.max_level(game, bid)
		var reason: String = Eco.build_block_reason(game, me, p.id, bid)
		# hide what cannot matter right now: unbuilt buildings without a free slot
		if lvl == 0 and (reason.begins_with("Keine freien") or (d.get("coastal", false) and not p.coastal)):
			continue
		var label := "%s %s %d/%d" % [d.emoji, d.name, lvl, maxl]
		var txt: String
		if lvl >= maxl:
			txt = label + "  (max.)"
		else:
			txt = "%s  %s %d💰" % [label, "➕" if lvl > 0 else "+", int(Eco.building_cost(game, me, p.id, bid))]
			var gain: float = Eco.building_gain(game, p, bid)
			if gain >= 0.05:
				txt += "  ≈ +%.1f/Monat" % gain
		var b := _btn(txt, func(): _act(game.construct(me, p.id, bid), "🏗️ Bau begonnen: " + d.name), d.text + (("\n❌ " + reason) if reason != "" else ""), reason != "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		side_box.add_child(b)
		if reason != "" and lvl < maxl and not reason.begins_with("Hier wird") and not reason.begins_with("Höchste"):
			side_box.add_child(_lbl("   " + reason, 14, Color(0.75, 0.6, 0.5)))
	side_box.add_child(_lbl("Jede fertige Stufe: +1 Entwicklung (außer Straßen). \"+X/Monat\" = mehr Steuer und Produktion hier, ohne Handel.", 14, Color(0.7, 0.75, 0.8)))


func _panel_economy() -> void:
	var me: String = game.player
	var n = game.nations[me]
	var Eco = game.Economy
	side_title.text = "💰 Wirtschaft"
	var tabs := []
	for e in [["overview", "💰 Kasse"], ["trade", "🏬 Handel"], ["goods", "🏭 Güter"]]:
		var key: String = e[0]
		var b := _btn(e[1], func(): econ_tab = key; _refresh())
		if econ_tab == key:
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
		tabs.append(b)
	side_box.add_child(_row(tabs))
	match econ_tab:
		"trade":
			_economy_trade()
		"goods":
			_economy_goods()
		_:
			_economy_overview()


func _economy_overview() -> void:
	var me: String = game.player
	var n = game.nations[me]
	var Eco = game.Economy
	var trib: float = game.tribute_income(me)
	var intr: float = Eco.interest(game, n)
	var budget: float = game.govt.budget_cost(game, n)
	var army_cost: float = n.expenses - Eco.upkeep(game, me) - intr - budget
	var lines := "Einnahmen %.2f/Monat\n  💰 Steuern %.2f\n  🏭 Güter %.2f\n  🏬 Handel %.2f" % [n.income, n.tax_income, n.prod_income, n.trade_income]
	if trib != 0.0:
		lines += "\n  ⛓️ Tribut %+.2f" % trib
	lines += "\nAusgaben %.2f/Monat\n  🛡️ Armee %.2f\n  🏰 Gebäude %.2f" % [n.expenses, army_cost, Eco.upkeep(game, me)]
	if intr > 0.0:
		lines += "\n  🏦 Zinsen %.2f" % intr
	if absf(budget) >= 0.01:
		lines += "\n  ⚖️ Haushalt %+.2f" % budget
	side_box.add_child(_lbl(lines))
	side_box.add_child(_btn("⚖️ Haushalt: Steuern, Hof, Heer, Forschung", func(): _open_panel("government"),
		"Schieberegler im Regierungs-Screen: Steuerdruck, Hofhaltung, Militärbudget und Forschung."))
	# loans
	var lrow := HBoxContainer.new()
	var lsize: float = Eco.loan_size(game, n)
	lrow.add_child(_btn("🏦 Kredit +%d💰 (%d%%)" % [int(lsize), int(round(Eco.loan_rate(game, n) * 100))], func():
		_act(Eco.take_loan(game, me), "🏦 Kredit aufgenommen"),
		"Sofort %d Gold. Zinsen %.1f%% pro Jahr, jeder weitere Kredit wird teurer. Höchstens %d Kredite." % [int(lsize), Eco.loan_rate(game, n) * 100, int(game.bal.max_loans)],
		n.loans.size() >= int(game.bal.max_loans)))
	if not n.loans.is_empty():
		var last: float = n.loans[n.loans.size() - 1]
		lrow.add_child(_btn("↩ Tilgen %d💰" % int(last), func(): _act(Eco.repay_loan(game, me), "🏦 Kredit getilgt"),
				"Zahlt den teuersten Kredit zurück.", n.gold < last))
	for c in lrow.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_box.add_child(lrow)
	if not n.loans.is_empty():
		side_box.add_child(_lbl("🏦 %d Kredite · Schulden %d💰 · Zinsen %.2f/Monat" % [n.loans.size(), int(Eco.debt(n)), intr], 16, Color(0.95, 0.75, 0.5)))
	var best: Array = Eco.best_building(game, n, game.is_at_war(me))
	if not best.is_empty():
		var bd: Dictionary = game.buildings_def[best[1]]
		var bp = game.provinces[best[0]]
		side_box.add_child(_btn("✨ Bauvorschlag: %s %s in %s (%d💰)" % [bd.emoji, bd.name, bp.name, int(Eco.building_cost(game, me, best[0], best[1]))],
				func(): _act(game.construct(me, best[0], best[1]), "🏗️ Bau begonnen: " + bd.name), "Das Gebäude mit dem besten Ertrag pro Gold."))
	side_box.add_child(_btn("🤖 Autobau: " + ("AN" if n.autobuild else "AUS"), func():
		n.autobuild = not n.autobuild
		if n.autobuild:
			Eco.autobuild(game, n)
		_refresh(), "Baut automatisch das lohnendste Gebäude, solange die Kasse danach nicht unter die Mindestkasse fällt."))
	if n.autobuild:
		var row := HBoxContainer.new()
		row.add_child(_lbl("Mindestkasse %d💰" % int(n.autobuild_reserve)))
		for step in [-100, -25, 25, 100]:
			var st: int = step
			var b := _btn("%+d" % st, func():
				n.autobuild_reserve = clampf(n.autobuild_reserve + st, 0.0, 5000.0)
				_refresh(), "Mindestkasse ändern: Autobau gibt nur Gold darüber aus.")
			row.add_child(b)
		side_box.add_child(row)
	var building := 0
	for pid in game.provinces_of(me):
		if not game.provinces[pid].constructing.is_empty():
			building += 1
	if building > 0:
		side_box.add_child(_lbl("🏗️ %d Bauprojekte laufen." % building, 16, Color(0.95, 0.8, 0.4)))


func _economy_trade() -> void:
	var me: String = game.player
	var n = game.nations[me]
	var Eco = game.Economy
	side_box.add_child(_lbl("🏬 Handel · Händler %d / %d" % [n.merchants.size(), Eco.merchant_count(game, n)], 22))
	side_box.add_child(_btn("🤖 Händler automatisch: " + ("AN" if n.merchant_auto else "AUS"), func():
		n.merchant_auto = not n.merchant_auto
		if n.merchant_auto:
			Eco.auto_merchants(game, n)
			Eco.update_markets(game)
		_refresh(), "Automatisch schickt die Händler jedes Jahr in die lohnendsten Märkte."))
	var rows: Array = []
	for m in game.markets:
		rows.append([m, Eco.trade_share(game, me, m), game.market_cache[m].value])
	rows.sort_custom(func(a, b): return a[1] * a[2] > b[1] * b[2] or (a[1] * a[2] == b[1] * b[2] and a[2] > b[2]))
	for r in rows:
		var m: int = r[0]
		var has: bool = n.merchants.has(m)
		var txt := "%s %s  %.1f💰 · Anteil %d%%" % ["🛒" if has else "🏬", game.provinces[m].name, r[2], int(r[1] * 100)]
		var gain: float = Eco.merchant_gain(game, me, m)
		var tip := "Marktwert %.2f/Monat. Ein Händler hier brächte etwa +%.2f/Monat." % [r[2], gain]
		var b: Button
		if has:
			b = _btn(txt + "  ↩", func(): Eco.recall_merchant(game, me, m); _refresh(), tip + " Antippen: Händler zurückrufen.")
		else:
			b = _btn(txt + "  +%.2f" % gain, func(): _act(Eco.send_merchant(game, me, m), "🛒 Händler entsandt"), tip + " Antippen: Händler schicken.")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		side_box.add_child(b)


func _economy_goods() -> void:
	var me: String = game.player
	var n = game.nations[me]
	var Eco = game.Economy
	side_box.add_child(_lbl("🏭 Güter und Preise", 22))
	var out: Dictionary = Eco.goods_output(game, me)
	var world: Dictionary = Eco.supply(game)
	for k in game.goods_def:
		var gd: Dictionary = game.goods_def[k]
		var pr: float = game.prices[k]
		var trend := "📈" if pr > game.prev_prices.get(k, pr) + 0.0005 else ("📉" if pr < game.prev_prices.get(k, pr) - 0.0005 else "")
		var share: float = out.get(k, 0.0) / maxf(0.01, world[k])
		var leader: String = game.goods_leader.get(k, "")
		var txt := "%s %s %.2f💰%s · du: %d%%" % [gd.emoji, gd.name, pr, trend, int(share * 100)]
		if leader != "":
			txt += " · 👑 " + game.nations[leader].name
		var why := "%s %s: Marktführer (meiste Produktion, mind. %d %% der Welt) erhält %s." % [gd.emoji, gd.name, int(float(game.bal.goods_leader_share) * 100), gd.bonus_text]
		if game.shocks.has(k):
			var sh: Dictionary = game.shocks[k]
			txt += " · ⚠️"
			why += "\n%s noch %d Jahre: Preis ×%.1f." % ["Knappheit" if float(sh.mult) > 1.0 else "Überangebot", int(sh.years), float(sh.mult)]
		var b := _btn(txt, _toast.bind(why), why)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if leader == me:
			b.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
		side_box.add_child(b)
	side_box.add_child(_lbl("Antippen zeigt den Bonus des Marktführers. Preise ändern sich jährlich mit Angebot und Nachfrage.", 14, Color(0.7, 0.75, 0.8)))


func _panel_mapmodes() -> void:
	side_title.text = "🗺️ Kartenmodus"
	for i in map.MODE_NAMES.size():
		var b := _btn(("▶ " if map.map_mode == i else "") + map.MODE_NAMES[i], _set_map_mode.bind(i), MODE_LEGENDS[i])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		side_box.add_child(b)
	side_box.add_child(_lbl(MODE_LEGENDS[map.map_mode], 16, Color(0.8, 0.85, 0.7)))
	for k in MODE_KEYS.get(map.map_mode, []):
		side_box.add_child(_lbl("● " + k[1], 16, Color(k[0])))
	if map.map_mode == map.MODE_GOODS:
		for k in game.goods_def:
			var gd: Dictionary = game.goods_def[k]
			var l := _lbl("● %s %s" % [gd.emoji, gd.name], 16, Color(gd.color))
			side_box.add_child(l)


func _panel_army(id: int) -> void:
	var a = game.army_by_id(id)
	if a == null:
		_close_panel()
		return
	side_title.text = "🛡️ Armee von " + game.nations[a.owner].name
	var info := "Stärke: %.1f / %.1f Regimenter\nOrt: %s" % [a.regs, a.full, game.provinces[a.pid].name]
	if a.target >= 0:
		info += "\nZiel: %s (%d Monate)" % [game.provinces[a.target].name, maxi(1, a.path.size() - 1)]
	side_box.add_child(_lbl(info))
	var pm: float = game.power_max(a.owner)
	var ml := _lbl("🔥 Moral %d %% (max. %d %%, +%.1f %%/Monat)" % [int(round(a.power * 100)), int(round(pm * 100)), game.power_regen(a) * 100],
			17, Color(0.55, 0.95, 0.45) if a.power >= pm * 0.7 else (Color(0.95, 0.8, 0.3) if a.power >= pm * 0.35 else Color(1.0, 0.45, 0.35)))
	ml.tooltip_text = "Moral bestimmt, wie gut die Armee kämpft (bei 0 %% nur noch mit %d %% Kraft). Sie steigt jeden Monat, im eigenen und verbündeten Land schneller, mit Straßen noch schneller. Eine gewonnene Schlacht kostet %d %%, eine verlorene %d %%. Der Balken unter der Armee auf der Karte zeigt sie." % [
			int(float(game.bal.army_power_floor) * 100), int(float(game.bal.army_power_loss_win) * 100), int(float(game.bal.army_power_loss_lose) * 100)]
	ml.mouse_filter = Control.MOUSE_FILTER_STOP
	side_box.add_child(ml)
	var gen_txt := ("⭐ General: %d von 3 Sternen (+%d %% Kampfkraft)" % [a.general, int(a.general * float(game.bal.general_bonus) * 100)]) if a.general > 0 else "⭐ Kein General"
	side_box.add_child(_lbl(gen_txt, 16, Color(1, 0.85, 0.5) if a.general > 0 else Color(0.7, 0.7, 0.7)))
	if a.owner != game.player:
		return
	if a.general == 0:
		side_box.add_child(_btn("⭐ General anwerben (%d ⚔️)" % int(game.bal.general_cost), func(): _act(game.hire_general(a.owner, a.id), "⭐ Ein General übernimmt das Kommando"),
				"Militär-Macht einsetzen: ein General mit 1 bis 3 Sternen (bessere Militärtechnik, bessere Offiziere). Jeder Stern +%d %% Kampfkraft. Generäle können in Schlachten fallen, nach Niederlagen eher." % int(float(game.bal.general_bonus) * 100)))
	if a.power < pm - 0.001:
		side_box.add_child(_btn("🔥 Drill: Moral auf %d %% (%d ⚔️)" % [int(round(pm * 100)), int(game.drill_cost(a))],
				func(): _act(game.drill_army(a.owner, a.id), "🔥 Die Truppen sind gedrillt"),
				"Militär-Macht einsetzen: die Moral der Armee sofort auf das Maximum bringen. Nur auf eigenem oder verbündetem Gebiet."))
	if selected_army == a.id:
		side_box.add_child(_lbl("👉 Tippe auf eine Provinz, um die Armee dorthin zu schicken. Lange drücken zeigt nur Infos.", 16, Color(0.8, 0.85, 0.6)))
	else:
		side_box.add_child(_btn("🎯 Neues Ziel wählen", func(): selected_army = a.id; map.selected_army = a.id; _refresh(); map.queue_redraw()))
	side_box.add_child(_lbl("Modus: " + _stance_name(a), 17, Color(0.8, 0.85, 0.7)))
	side_box.add_child(_row([
		_btn("⚔️ Angriff", func(): _set_stance(a, "attack"), "KI führt die Armee: sucht Schlachten und belagert."),
		_btn("🛡️ Verteidigen", func(): _set_stance(a, "defend"), "KI führt die Armee nur im eigenen und verbündeten Land."),
		_btn("✋ Manuell", func(): _set_stance(a, ""), "Du gibst die Befehle.")]))
	var orders := []
	var ai = game.ai
	for o in [["🎯 Belagern", ai.nearest_siege(game, a), "Nächste feindliche Provinz belagern"],
			["⚔️ Angreifen", ai.nearest_enemy_army(game, a), "Nächste schlagbare feindliche Armee angreifen"],
			["🏳️ Befreien", ai.nearest_lost_province(game, a), "Nächste eigene besetzte Provinz befreien"]]:
		if o[1] >= 0:
			var target: int = o[1]
			orders.append(_btn(o[0], func(): _quick_order(a, target), "%s: %s" % [o[2], game.provinces[target].name]))
	if not orders.is_empty():
		side_box.add_child(_row(orders))
	if a.pid != game.nations[a.owner].capital:
		side_box.add_child(_btn("🏰 Zur Hauptstadt", func(): _quick_order(a, game.nations[a.owner].capital)))
	side_box.add_child(_row([
		_btn("✂️ Teilen", func(): var b = game.split_army(a); _act("" if b != null else "Zu klein zum Teilen.")),
		_btn("🔗 Vereinen", func(): game.merge_armies(a.owner, a.pid); _act(""); map.queue_redraw())]))
	side_box.add_child(_row([
		_btn("🛑 Halt", func(): a.target = -1; a.path = []; _act("")),
		_btn("➖ 1 Reg. entlassen", func(): game.disband(a, 1.0); _act(""); map.queue_redraw())]))


func _panel_nation() -> void:
	var me: String = game.player
	var n = game.nations[me]
	side_title.text = nname(me)
	side_box.add_child(_lbl("👑 " + game.Progression.rank_name(game, me), 18, Color(1, 0.85, 0.5)))
	side_box.add_child(_bb(_idea_bb(n.idea, data.nations[me].get("bonus", {})), 16))
	side_box.add_child(_lbl("👑 %s: 📜%d 🕊️%d ⚔️%d" % [n.ruler_name if n.ruler_name != "" else "Herrscher", n.ruler.adm, n.ruler.dip, n.ruler.mil]))
	side_box.add_child(_lbl("Monatlich: 📜+%.0f 🕊️+%.0f ⚔️+%.0f" % [game.monthly_power(n, "adm"), game.monthly_power(n, "dip"), game.monthly_power(n, "mil")]))
	side_box.add_child(_lbl("💰 Einnahmen %.1f · Ausgaben %.1f\n🏘️ Entwicklung %d · %d Provinzen\n🛡️ Truppenlimit %.0f · 👥 %.0f/%.0f\n⭐ Prestige %d · 🏆 Punkte %d" % [
			n.income, n.expenses, n.dev_total, game.provinces_of(me).size(), game.force_limit(me), n.manpower, n.max_manpower, n.prestige, game.score(me)]))
	side_box.add_child(_lbl("😩 Kriegsmüdigkeit %.1f / %d (erhöht Unruhe, Gegner nehmen Frieden leichter an)" % [n.we, int(game.bal.we_max)], 16))
	side_box.add_child(_lbl("⛪ Staatsglaube: %s (%d %% deines Landes)" % [Faith.faith_name(n.religion), int(Faith.share(game, me, n.religion) * 100)], 16))
	for r in Faith.FAITHS:
		if r != n.religion and Faith.share(game, me, r) > 0.0:
			var fr: String = Faith.change_block_reason(game, me, r)
			side_box.add_child(_btn("⛪ Glauben wechseln: %s (%d ⭐)" % [Faith.faith_name(r), int(game.bal.religion_change_prestige)], func(): _act(Faith.change_religion(game, me, r), "⛪ Neuer Staatsglaube: " + Faith.faith_name(r)),
					"Ab %d %% Anteil möglich. Provinzen dieses Glaubens werden ruhig, die übrigen unruhig. +%d Beziehung zu Ländern dieses Glaubens, −%d zu denen deines alten.%s" % [
					int(float(game.bal.religion_change_share) * 100), int(game.bal.religion_change_rel), int(game.bal.religion_change_rel), ("\n❌ " + fr) if fr != "" else ""], fr != ""))
	side_box.add_child(_lbl("👑 Macht einsetzen", 22))
	side_box.add_child(_btn("🕊️ Volk beruhigen: −2 Müdigkeit (%d 🕊️)" % int(game.bal.we_reduce_cost), func(): _act(game.reduce_we(me), "🕊️ Das Volk ist beruhigt"),
			"Senkt die Kriegsmüdigkeit, die Unruhe in allen Provinzen erzeugt."))
	side_box.add_child(_btn("😠 Ruf verbessern: −%d AE (%d 🕊️)" % [int(game.bal.reputation_ae), int(game.bal.reputation_cost)], func(): _act(game.restore_reputation(me), "😠 Dein Ruf bessert sich"),
			"Gesandte beruhigen die Nachbarn: weniger aggressive Expansion, Koalitionen werden unwahrscheinlicher."))
	var cr: int = game.conscript_ready_in(me)
	side_box.add_child(_btn(("👥 Rekrutierung: +%d Mannschaften (%d ⚔️)" % [int(game.conscript_gain(me)), int(game.bal.conscript_cost)]) if cr == 0 else ("👥 Rekrutierung (wieder in %d Monaten)" % cr),
			func(): _act(game.conscript(me), "👥 Neue Rekruten ausgehoben"),
			"Füllt sofort bis zu %d %% deiner maximalen Mannschaften auf. Danach %d Monate Pause." % [int(float(game.bal.conscript_share) * 100), int(game.bal.conscript_cooldown)]))
	side_box.add_child(_lbl("Außerdem: 📜 Entwickeln, ✊ Unruhe unterdrücken (⚔️) und 🤝 Integrieren (🕊️) im Provinzfenster, 🔥 Drill (⚔️) im Armeefenster, ❤️ Beziehungen, Bündnisse, Ansprüche und Handelsabkommen (🕊️) bei anderen Nationen, Technologie mit allen drei.", 14, Color(0.7, 0.75, 0.8)))
	_nation_monuments(me)
	if game.history.size() >= 2:
		side_box.add_child(_lbl("📈 Verlauf (Platz %d)" % game.rank_of(me), 22))
		side_box.add_child(_history_chart(180))
	var vs: Array = game.vassals_of(me)
	if not vs.is_empty():
		side_box.add_child(_lbl(Icons.prefix("vassal") + "Vasallen (Tribut %+.1f 💰/Monat)" % game.tribute_income(me), 22))
		for v in vs:
			side_box.add_child(_nation_btn(v, "  🏘️%d" % game.nations[v].dev_total, _open_panel.bind("other", v)))
	side_box.add_child(_lbl("Technologie: 📜%d 🕊️%d ⚔️%d · Regierung: %s" % [n.tech.adm, n.tech.dip, n.tech.mil, game.govt.form_name(me)], 17))
	side_box.add_child(_row([_btn("🔬 Technologie", _open_panel.bind("tech")), _btn("⚖️ Regierung", _open_panel.bind("government"))]))
	side_box.add_child(_btn("📈 Alle Boni und Mali", _open_panel.bind("modifiers"), "Jeder Modifikator mit Gesamtwert und woher er kommt"))
	side_box.add_child(_lbl("Aggressive Expansion", 22))
	var thr: float = game.bal.ae_coalition_threshold
	var co := []
	for t in n.coalition:
		co.append(game.nations[t].name)
	side_box.add_child(_lbl("😠 %d / %d (Koalitionsgrenze)\nKoalition gegen dich: %s" % [n.ae, thr, ", ".join(co) if not co.is_empty() else "keine"]))


const MOD_SOURCES := {"": "Nationalgeist & Ereignisse", "goods": "Handelsgüter", "buildings": "Gebäude", "rank": "Rang",
		"tech": "Technologie", "gov": "Regierung", "estates": "Stände", "pacts": "Handelspakte", "monuments": "Großprojekte"}
const MOD_GROUPS := [
	["💰 Wirtschaft", ["income", "tax", "production", "trade", "merchants", "build_cost", "develop_cost"]],
	["⚔️ Militär", ["combat", "army_power", "army_power_regen", "manpower", "force_limit", "maintenance", "siege"]],
	["📜 Staat", ["adm", "dip", "mil", "tech_cost", "coring", "unrest", "ae_gen", "ae_decay", "prestige", "advisor_slots", "company_slots"]],
	["⚖️ Stände", ["estate_adel", "estate_klerus", "estate_buerger"]],
]


## Gold sinks for rich realms: a court feast and one great work at a time in the capital.
func _nation_monuments(me: String) -> void:
	var n = game.nations[me]
	side_box.add_child(_lbl("🏛️ Prunk und Großprojekte", 22))
	var fr: int = game.feast_ready_in(me)
	side_box.add_child(_btn(("👑 Hoffest ausrichten (%d 💰)" % int(game.feast_cost(me))) if fr == 0 else ("👑 Hoffest (wieder in %d Monaten)" % fr),
			func(): _act(game.hold_feast(me), "👑 Ein prächtiges Fest!"),
			"+%d ⭐ Prestige, −%d Kriegsmüdigkeit. Kostet %d Monatseinnahmen, höchstens alle %d Jahre." % [
			int(game.bal.feast_prestige), int(game.bal.feast_we), int(game.bal.feast_income_months), int(game.bal.feast_cooldown) / 12]))
	if not n.monument_build.is_empty():
		var bm: Dictionary = game.monument_defs[n.monument_build.id]
		side_box.add_child(_lbl("🔨 %s %s: noch %d Monate" % [bm.emoji, bm.name, int(n.monument_build.months)], 16, Color(0.6, 0.8, 1.0)))
	for id in game.monument_defs:
		var m: Dictionary = game.monument_defs[id]
		var parts := []
		for r in UiTheme.mod_rows(m.bonus):
			parts.append("%s %s" % [r[0], r[1]])
		var tip: String = "%s\n%s" % [m.text, ", ".join(parts)]
		if n.monuments.has(id):
			var l := _lbl("✓ %s %s" % [m.emoji, m.name], 16, Color(0.6, 0.9, 0.6))
			l.tooltip_text = tip
			l.mouse_filter = Control.MOUSE_FILTER_STOP
			side_box.add_child(l)
			continue
		if n.monument_build.get("id", "") == id:
			continue
		var br: String = Monuments.block_reason(game, me, id)
		side_box.add_child(_btn("%s %s bauen (%d 💰, %d Mon.)" % [m.emoji, m.name, int(Monuments.cost(game, me, id)), int(m.months)],
				func(): _act(Monuments.start(game, me, id), "🔨 Bau begonnen: " + m.name),
				tip + ("\n❌ " + br if br != "" else ""), br != ""))


## Every modifier of the player: total (green buff / red nerf) and the sources it is summed from (Game.mod).
func _panel_modifiers() -> void:
	var n = game.nations[game.player]
	side_title.text = "📈 Boni und Mali"
	var srcs := {"": n.mods}
	for k in n.bonus:
		srcs[k] = n.bonus[k]
	var keys := {}
	for k in srcs:
		for key in srcs[k]:
			if absf(float(srcs[k][key])) > 0.0005:
				keys[key] = true
	var groups: Array = MOD_GROUPS.duplicate(true)
	var known := []
	for gr in groups:
		known.append_array(gr[1])
	var other := []
	for key in keys:
		if not key in known:
			other.append(key)
	if not other.is_empty():
		groups.append(["✨ Sonstiges", other])
	var good := 0
	var bad := 0
	for key in keys:
		var row: Array = UiTheme.mod_rows({key: game.mod(n, key)})
		if not row.is_empty():
			if row[0][2]:
				good += 1
			else:
				bad += 1
	var head := RichTextLabel.new()
	head.bbcode_enabled = true
	head.fit_content = true
	head.scroll_active = false
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.text = "%s     %s" % [UiTheme.tone_bb("%d Boni" % good, 1, 16), UiTheme.tone_bb("%d Mali" % bad, -1, 16)]
	side_box.add_child(head)
	if keys.is_empty():
		side_box.add_child(_lbl("Noch keine Modifikatoren.", 16, UiTheme.MUTED))
	for gr in groups:
		var present: Array = gr[1].filter(func(k): return keys.has(k))
		if present.is_empty():
			continue
		side_box.add_child(_lbl(gr[0], 20, UiTheme.GOLD))
		for key in present:
			var total: Array = UiTheme.mod_rows({key: game.mod(n, key)})
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiTheme.card("" if total.is_empty() else ("good" if total[0][2] else "bad"), 8))
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 0)
			card.add_child(v)
			if total.is_empty():  # sources cancel out
				v.add_child(_lbl("%s: ±0" % UiTheme.label(key)[0], 17, UiTheme.NEUTRAL))
			else:
				v.add_child(UiTheme.mod_row(total[0][0], total[0][1], total[0][2], 18))
			if Tech.DESCS.has(key):
				v.add_child(_lbl(Tech.DESCS[key], 13, UiTheme.MUTED))
			for src in srcs:
				var part: Array = UiTheme.mod_rows({key: srcs[src].get(key, 0.0)})
				if part.is_empty():
					continue
				var l := _lbl("   %s  %s" % [part[0][1], MOD_SOURCES.get(src, src)], 14, UiTheme.GOOD.darkened(0.15) if part[0][2] else UiTheme.BAD.darkened(0.15))
				v.add_child(l)
			side_box.add_child(card)


func _panel_diplomacy() -> void:
	var me: String = game.player
	side_title.text = "🤝 Diplomatie"
	side_box.add_child(_row([_btn("🏆 Rangliste", _open_panel.bind("ranking")), _btn("👑 Reich", _open_panel.bind("hre"))]))
	var groups := [["Vasallen", []], ["Verbündete", []], ["Feinde", []], ["Nachbarn", []], ["Andere", []]]
	var nbs: Array = game.neighbors_of(me)
	for tag in game.order:
		if tag == me or not game.nations[tag].alive:
			continue
		if game.nations[tag].overlord == me:
			groups[0][1].append(tag)
		elif game.is_allied(me, tag):
			groups[1][1].append(tag)
		elif game.at_war(me, tag):
			groups[2][1].append(tag)
		elif nbs.has(tag):
			groups[3][1].append(tag)
		else:
			groups[4][1].append(tag)
	for g in groups:
		if g[1].is_empty():
			continue
		side_box.add_child(_lbl(g[0], 20, Color(0.7, 0.8, 0.9)))
		for tag in g[1]:
			var o = game.nations[tag]
			var txt := "  ❤️%d  🏘️%d" % [int(game.get_rel(me, tag)), o.dev_total]
			if o.ae >= float(game.bal.ae_coalition_threshold):
				txt += "  😠"
			if o.overlord != "" and o.overlord != me:
				txt += "  ⛓️"
			if game.nations[me].trade_pacts.has(tag):
				txt += "  🔗"
			if game.nations[me].marriages.has(tag):
				txt += "  👑"
			if game.nations[me].access.has(tag):
				txt += "  🚶"
			if game.nations[me].guarantees.has(tag) or o.guarantees.has(me):
				txt += "  🛡️"
			side_box.add_child(_nation_btn(tag, txt, _open_panel.bind("other", tag)))


func _panel_other(tag: String) -> void:
	var me: String = game.player
	var o = game.nations[tag]
	side_title.text = nname(tag)
	var allies := []
	for t in o.allies:
		allies.append(game.nations[t].name)
	var info := "❤️ Beziehung: %d\n🏘️ Entwicklung %d · %d Provinzen\n🛡️ Armee %.0f Reg. (Stärke %.0f)\n🤝 Verbündete: %s\n😠 AE: %d" % [
			int(game.get_rel(me, tag)), o.dev_total, game.provinces_of(tag).size(), game.army_regs(tag),
			game.strength(tag), ", ".join(allies) if not allies.is_empty() else "keine", o.ae]
	if game.has_truce(me, tag):
		info += "\n🕊️ Waffenstillstand bis %s" % game.date_string(o.truces.get(me, 0))
	if game.has_claim_on(me, tag):
		info += "\n📜 Du hast Ansprüche (Kriegsgrund)"
	if o.overlord != "":
		info += "\n⛓️ Vasall von %s" % game.nations[o.overlord].name
	if o.guarantees.has(me):
		info += "\n🛡️ Garantiert deine Unabhängigkeit"
	var ovs := []
	for v in game.vassals_of(tag):
		ovs.append(game.nations[v].name)
	if not ovs.is_empty():
		info += "\n⛓️ Vasallen: %s" % ", ".join(ovs)
	side_box.add_child(_lbl(info))
	side_box.add_child(_btn("🗺️ Auf Karte zeigen", func(): map.focus(game.provinces[o.capital].center)))
	if not o.alive:
		return
	var b: Dictionary = game.bal
	side_box.add_child(_btn("❤️ Beziehungen verbessern (%d 🕊️)" % int(b.improve_relation_cost), func(): _act(game.improve_relations(me, tag), "❤️ Beziehungen verbessert")))
	if game.nations[me].marriages.has(tag):
		side_box.add_child(_lbl("👑 Eure Häuser sind verheiratet: Beziehung bleibt mindestens bei %d." % int(b.marriage_rel_floor), 15, Color(1, 0.85, 0.5)))
	else:
		var mr: String = game.marriage_block_reason(me, tag)
		side_box.add_child(_btn("👑 Königliche Heirat (%d 🕊️)" % int(b.marriage_cost), func(): _act(game.marry(me, tag), "👑 Hochzeit gefeiert!"),
				"+%d Beziehung, die nie unter %d fällt. Ist %s klein (höchstens %d Provinzen) und du viel stärker, kann es beim Thronwechsel per Personalunion dein Vasall werden. Ein Krieg gegen den Partner beendet die Ehe.%s" % [
				int(b.marriage_rel), int(b.marriage_rel_floor), o.name, int(b.marriage_union_max_provinces), ("\n❌ " + mr) if mr != "" else ""], mr != ""))
	if game.nations[me].access.has(tag):
		side_box.add_child(_lbl("🚶 Durchmarschrecht: Deine Armeen dürfen durch %s ziehen." % o.name, 15, Color(0.7, 0.9, 0.7)))
		side_box.add_child(_btn("🚶 Durchmarschrecht aufgeben", func(): game.revoke_access(me, tag); _act("", "🚶 Durchmarschrecht aufgegeben")))
	elif not game.is_allied(me, tag) and o.overlord != me:
		var ar: String = game.access_block_reason(me, tag)
		side_box.add_child(_btn("🚶 Durchmarschrecht erbitten (%d 🕊️)" % int(b.access_cost), func(): _act(game.request_access(me, tag), "🚶 Durchmarschrecht erhalten"),
				"Deine Armeen dürfen durch das Land von %s ziehen, etwa um einen Feind dahinter zu erreichen. Braucht Beziehung ab %d; wer mit deinem Kriegsgegner verbündet ist, lehnt ab. Fällt die Beziehung unter %d, wird das Recht entzogen und deine Truppen dort kehren heim.%s" % [
				o.name, int(b.access_min_rel), int(b.access_lost_rel), ("\n❌ " + ar) if ar != "" else ""], ar != ""))
	if game.nations[me].guarantees.has(tag):
		side_box.add_child(_btn("🛡️ Garantie zurückziehen", func(): game.end_guarantee(me, tag); _act("", "🛡️ Garantie zurückgezogen"),
				"Du musst %s dann nicht mehr verteidigen. Kostet %d Beziehung." % [o.name, int(b.guarantee_rel)]))
	elif o.overlord == "":
		var gr: String = game.guarantee_block_reason(me, tag)
		side_box.add_child(_btn("🛡️ Unabhängigkeit garantieren (%d 🕊️)" % int(b.guarantee_cost), func(): _act(game.guarantee(me, tag), "🛡️ Garantie ausgesprochen"),
				"+%d Beziehung. Wer %s den Krieg erklärt, hat dich automatisch als Gegner. So schützt du kleine Nachbarn vor deinen Rivalen. Höchstens %d Garantien.%s" % [
				int(b.guarantee_rel), o.name, int(b.max_guarantees), ("\n❌ " + gr) if gr != "" else ""], gr != ""))
	if o.overlord == me:
		var left: int = game.annex_months_left(tag)
		var t := "📜 Annektieren (%d 🕊️, %d 📜)" % [int(game.annex_cost(tag)), int(game.annex_adm_cost(tag))]
		if left > 0:
			side_box.add_child(_lbl("Annexion möglich ab %s." % game.date_string(game.month + left), 15, Color(0.7, 0.7, 0.7)))
		side_box.add_child(_btn(t, func(): _act(game.annex_vassal(me, tag), "📜 %s annektiert!" % o.name), "", left > 0))
		side_box.add_child(_lbl("Vasallen zahlen %d%% ihres Einkommens als Tribut und kämpfen in deinen Kriegen." % int(float(b.vassal_tribute) * 100), 15, Color(0.7, 0.7, 0.7)))
		return
	if game.is_allied(me, tag):
		side_box.add_child(_btn("💔 Bündnis auflösen", func(): game.break_alliance(me, tag); _act("", "💔 Bündnis aufgelöst")))
	else:
		side_box.add_child(_btn("🤝 Bündnis anbieten (%d 🕊️)" % int(b.alliance_cost), func(): _act(game.propose_alliance(me, tag), "🤝 Bündnis geschlossen!")))
	var Eco = game.Economy
	if game.nations[me].trade_pacts.has(tag):
		side_box.add_child(_btn("✂️ Handelsabkommen kündigen", func(): Eco.cancel_pact(game, me, tag); _act("", "✂️ Handelsabkommen gekündigt"),
				"Beide verlieren +%d %% Handelseinnahmen." % int(float(b.trade_pact_bonus) * 100)))
	else:
		var why: String = Eco.pact_block_reason(game, me, tag)
		var acc: bool = Eco.accepts_pact(game, tag, me)
		side_box.add_child(_btn("🔗 Handelsabkommen (%d 🕊️)%s" % [int(b.trade_pact_cost), "" if acc else " ❌"], func(): _act(Eco.offer_pact(game, me, tag), "🔗 Handelsabkommen geschlossen!"),
				"Beide Reiche erhalten +%d %% Handelseinnahmen, höchstens %d Abkommen. Nimmt an ab Beziehung %d oder als Verbündeter, ohne gegenseitige Ansprüche. Krieg beendet es.%s" % [
					int(float(b.trade_pact_bonus) * 100), int(b.max_trade_pacts), int(b.trade_pact_min_rel), ("\n❌ " + why) if why != "" else ("" if acc else "\n❌ Würde derzeit ablehnen.")],
				why != ""))
	if not game.at_war(me, tag):
		side_box.add_child(_btn("🔥 Krieg erklären…", _confirm_war.bind(tag)))
	if o.ae >= float(b.ae_coalition_threshold) and not o.coalition.has(me):
		side_box.add_child(_btn("⚠️ Koalition gegen %s beitreten" % o.name, func(): _act(game.join_coalition(me, tag), "⚠️ Koalition beigetreten")))


func _confirm_war(tag: String) -> void:
	var me: String = game.player
	var o = game.nations[tag]
	_open_modal()
	modal_box.add_child(_lbl("🔥 Krieg gegen %s?" % nname(tag), 28))
	var joins := [o.name]
	var their_str: float = game.strength(tag)
	for t in game.defenders_for(me, tag):
		joins.append(game.nations[t].name)
		their_str += game.strength(t)
	var cb: bool = game.has_claim_on(me, tag)
	var text := "Gegner: %s\nDeren Stärke: %.0f · Deine Stärke: %.0f" % [", ".join(joins), their_str, game.strength(me)]
	if cb:
		text += "\n✅ Kriegsgrund vorhanden (Anspruch)."
	else:
		text += "\n⚠️ Kein Kriegsgrund: kostet %d 🕊️ und +%d 😠 AE." % [int(game.bal.nocb_war_dip), int(game.bal.ae_no_cb)]
	modal_box.add_child(_lbl(text))
	modal_box.add_child(_btn("🔥 Krieg erklären", func():
		var err: String = game.declare_war(me, tag)
		_close_modal()
		_act(err, "🔥 Der Krieg hat begonnen!")
		map.queue_redraw()))
	modal_box.add_child(_btn("Abbrechen", _close_modal))


func _panel_wars() -> void:
	var me: String = game.player
	side_title.text = "⚔️ Kriege"
	var ws_list: Array = game.wars_of(me)
	if ws_list.is_empty():
		side_box.add_child(_lbl("Du bist im Frieden. 🕊️"))
	var st: String = game.nations[me].army_stance
	side_box.add_child(_lbl("🛡️ Armeeführung (gilt auch für neue Armeen): " + {"attack": "⚔️ Angriff", "defend": "🛡️ Verteidigen", "": "✋ Manuell"}[st], 17))
	side_box.add_child(_row([
		_btn("⚔️ Angriff", func(): _set_all_stance("attack"), "Alle Armeen kämpfen selbstständig: Schlachten suchen, belagern."),
		_btn("🛡️ Verteidigen", func(): _set_all_stance("defend"), "Alle Armeen schützen selbstständig dein und verbündetes Land."),
		_btn("✋ Manuell", func(): _set_all_stance(""), "Du gibst alle Befehle selbst.")]))
	var arms: Array = game.armies_of(me)
	if not arms.is_empty():
		side_box.add_child(_lbl("Deine Armeen (antippen = auswählen)", 17, Color(0.7, 0.8, 0.9)))
		for a in arms:
			var where: String = game.provinces[a.pid].name
			if a.target >= 0:
				where += " → " + game.provinces[a.target].name
			var b := _btn("%s %.1f Reg. · %s · %s" % [Icons.prefix("army"), a.regs, where, _stance_name(a)], _select_army.bind(a.id))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			side_box.add_child(b)
	for w in ws_list:
		var att: bool = game.is_attacker(w, me)
		var ws: float = game.warscore(w) * (1.0 if att else -1.0)
		var us := []
		var them := []
		for t in game.side_tags(w, att):
			us.append(nname(t))
		for t in game.side_tags(w, not att):
			them.append(nname(t))
		side_box.add_child(_lbl("🔥 " + w.name, 20, Color(1, 0.8, 0.6)))
		side_box.add_child(_lbl("Wir: %s\nGegner: %s\nKriegspunkte: %+d · Dauer: %d Monate" % [", ".join(us), ", ".join(them), int(ws), game.month - w.start], 16))
		var pw := [0.0, 0.0]
		for a in game.armies:
			var side := 0 if game.side_tags(w, att).has(a.owner) else (1 if game.side_tags(w, not att).has(a.owner) else -1)
			if side >= 0:
				pw[side] += a.regs * game.combat_mult(a.owner) * game.power_factor(a)
		var sl := _lbl("⚔️ Kampfkraft der Armeen: wir %d · Gegner %d" % [int(round(pw[0])), int(round(pw[1]))], 16,
				Color(0.55, 0.95, 0.45) if pw[0] >= pw[1] else Color(1.0, 0.55, 0.45))
		sl.tooltip_text = "Regimenter × Kampfwert × Moral aller Armeen beider Seiten (ohne Heimvorteil, Generäle und Zufall)."
		sl.mouse_filter = Control.MOUSE_FILTER_STOP
		side_box.add_child(sl)
		if game.side_tags(w, att)[0] == me:
			side_box.add_child(_btn("🕊️ Friedensverhandlung", _open_panel.bind("peace", w.id)))
		else:
			side_box.add_child(_lbl("Der Kriegsführer %s verhandelt den Frieden." % game.nations[game.side_tags(w, att)[0]].name, 15, Color(0.7, 0.7, 0.7)))
			var why: String = game.leave_war_block_reason(me, w)
			var wid: int = w.id
			side_box.add_child(_btn("🏳️ Separatfrieden (Krieg verlassen)", func(): _act(game.leave_war(me, game.war_by_id(wid)), "🏳️ Du hast den Krieg verlassen"),
					"Du steigst aus dem Krieg aus: Waffenstillstand mit allen Gegnern, besetzte Provinzen gehen an ihre Besitzer zurück. Der Kriegsführer %s ist verärgert (−%d Beziehung).%s" % [
					game.nations[game.side_tags(w, att)[0]].name, int(game.bal.separate_peace_rel), ("\n❌ " + why) if why != "" else ""], why != ""))
	var n = game.nations[me]
	if not n.claims.is_empty():
		side_box.add_child(_lbl("📜 Deine Ansprüche", 20, Color(0.7, 0.8, 0.9)))
		var names := []
		for pid in n.claims:
			names.append("%s (%s)" % [game.provinces[pid].name, game.nations[game.provinces[pid].owner].name])
		side_box.add_child(_lbl(", ".join(names), 15))


func _panel_peace(war_id: int) -> void:
	var me: String = game.player
	var w = game.war_by_id(war_id)
	if w == null:
		_open_panel("wars")
		return
	var att: bool = game.is_attacker(w, me)
	var ws: float = game.warscore(w) * (1.0 if att else -1.0)
	side_title.text = "🕊️ Frieden: " + w.name
	var cost: float = game.peace_cost(peace_selection.keys())
	var dev_sel := 0
	for pid in peace_selection:
		dev_sel += game.provinces[pid].dev
	side_box.add_child(_lbl("Kriegspunkte: %+d · Forderung kostet: %d\nIntegration kostet %d 📜 Admin (du hast %d)" % [
			int(ws), int(cost), int(dev_sel * float(game.bal.core_cost_per_dev)), int(game.nations[me].adm)], 18))
	var cands: Array = game.demandable(w, att)
	if cands.is_empty():
		side_box.add_child(_lbl("Keine besetzten Feindprovinzen. Besetze Provinzen, um sie fordern zu können.", 16))
	for pid in cands:
		var p = game.provinces[pid]
		var cb := CheckBox.new()
		cb.text = "%s (%s) – %d Punkte" % [p.name, game.nations[p.owner].name, int(game.peace_cost([pid]))]
		cb.button_pressed = peace_selection.has(pid)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(_toggle_peace.bind(pid))
		side_box.add_child(cb)
	if not cands.is_empty() and ws > 0:
		side_box.add_child(_btn("✨ Beste Auswahl (für %d Punkte)" % int(ws), func():
			peace_selection = {}
			for pid in game.ai.pick_demands(game, w, att, ws):
				peace_selection[pid] = true
			_refresh()))
	side_box.add_child(_btn("📜 Forderung stellen", func():
		var ok: bool = game.offer_peace(me, w, peace_selection.keys(), true)
		_after_peace(ok)))
	var target: String = game.side_tags(w, not att)[0]
	var why: String = game.vassal_block_reason(w, att)
	if why == "":
		side_box.add_child(_btn("⛓️ Vasallisieren (%d Punkte)" % int(game.vassal_cost(w, att)), func():
			var ok: bool = game.offer_peace(me, w, [], true, true)
			_after_peace(ok)))
	elif target != me:
		side_box.add_child(_lbl("⛓️ Vasallisieren nicht möglich: " + why, 15, Color(0.7, 0.7, 0.7)))
	side_box.add_child(_btn("🏳️ Weißer Frieden anbieten", func():
		var ok: bool = game.offer_peace(me, w, [], true)
		_after_peace(ok)))
	if ws < 0:
		side_box.add_child(_btn("🙇 Provinzen abtreten (Kapitulation)", func():
			var give: Array = game.ai.pick_demands(game, w, not att, -ws * 0.9)
			var ok: bool = game.offer_peace(me, w, give, false)
			if not ok:
				ok = game.offer_peace(me, w, [], true)
			_after_peace(ok)))


func _set_all_auto(on: bool) -> void:
	_set_all_stance("attack" if on else "")


func _stance_name(a) -> String:
	if not a.auto:
		return "✋ Manuell"
	return "🛡️ Verteidigen (KI)" if a.stance == "defend" else "⚔️ Angriff (KI)"


func _set_stance(a, stance: String) -> void:
	a.auto = stance != ""
	if stance != "":
		a.stance = stance
	_refresh()


## Every army of the player, and new armies from now on.
func _set_all_stance(stance: String) -> void:
	game.nations[game.player].army_stance = stance
	for a in game.armies_of(game.player):
		a.auto = stance != ""
		if stance != "":
			a.stance = stance
	_toast({"attack": "⚔️ Alle Armeen greifen selbstständig an.", "defend": "🛡️ Alle Armeen verteidigen selbstständig.",
			"": "✋ Du führst alle Armeen selbst."}[stance])
	_refresh()


func _quick_order(a, pid: int) -> void:
	a.auto = false
	var err: String = game.move_army(a, pid)
	_act(err, "🚶 Marschbefehl nach %s" % game.provinces[pid].name if err == "" else "")
	map.queue_redraw()


## Province panel: send every own army here (they switch to manual).
func _all_armies_to(pid: int) -> void:
	var sent := 0
	for a in game.armies_of(game.player):
		if a.pid != pid:
			a.auto = false
			if game.move_army(a, pid) == "":
				sent += 1
	_toast("🏁 %d Armeen marschieren nach %s." % [sent, game.provinces[pid].name] if sent > 0 else "Keine Armee kann dorthin.")
	map.queue_redraw()


## Select an army from a list and center the map on it.
func _select_army(id: int) -> void:
	var a = game.army_by_id(id)
	if a == null:
		return
	map.focus(game.provinces[a.pid].center)
	_on_army_tapped(id)


func _toggle_peace(on: bool, pid: int) -> void:
	if on:
		peace_selection[pid] = true
	else:
		peace_selection.erase(pid)
	_refresh()


func _after_peace(ok: bool) -> void:
	if ok:
		_sfx("peace")
		_toast("🕊️ Frieden geschlossen!")
		_open_panel("wars")
		map.queue_redraw()
	else:
		_toast("❌ Der Gegner lehnt ab.")
		_refresh()


func _panel_missions() -> void:
	var me: String = game.player
	side_title.text = "🎯 Missionen"
	var Prog = game.Progression
	var r: int = Prog.rank(game, me)
	var rk: String = "👑 Rang: %s" % Prog.RANKS[r].name
	if r + 1 < Prog.RANKS.size():
		rk += " · nächster Rang %s ab %d Entwicklung (du: %d)" % [Prog.RANKS[r + 1].name, int(Prog.RANKS[r + 1].dev), game.nations[me].dev_total]
	side_box.add_child(_lbl(rk, 18, Color(1, 0.85, 0.5)))
	var ms_done := 0
	for m in Prog.MILESTONES:
		if Prog.done(game, me, m.id):
			ms_done += 1
	side_box.add_child(_lbl("🏆 Meilensteine %d / %d" % [ms_done, Prog.MILESTONES.size()], 20))
	for m in Prog.MILESTONES:
		var ok: bool = Prog.done(game, me, m.id)
		var l := _lbl("%s %s: %s → %s" % ["✅" if ok else "🎯", m.title, m.text, effects_text(m.reward)], 15,
				Color(0.6, 0.9, 0.6) if ok else Color(0.85, 0.85, 0.88))
		side_box.add_child(l)
	side_box.add_child(_lbl("🎯 Missionen", 20))
	var avail: Array = game.available_missions(me)
	var done: int = game.nations[me].missions_done.size()
	side_box.add_child(_lbl("Erfüllt: %d" % done, 16, Color(0.7, 0.8, 0.9)))
	if avail.is_empty():
		side_box.add_child(_lbl("Keine offenen Missionen."))
	for m in avail:
		var ready: bool = game.mission_ready(me, m)
		side_box.add_child(_lbl(("✅ " if ready else "🎯 ") + m.title, 20, Color(1, 0.9, 0.6)))
		side_box.add_child(_lbl(m.get("desc", ""), 15))
		side_box.add_child(_lbl("Bedingungen:\n" + conditions_text(m.get("require", {})), 15, Color(0.8, 0.8, 0.85)))
		side_box.add_child(_lbl("Belohnung: " + effects_text(m.get("reward", {})), 15, Color(0.7, 0.9, 0.7)))
		side_box.add_child(_btn("🎯 Abschließen", func(): _act(game.complete_mission(me, m.id), "🎯 Mission erfüllt!"), "", not ready))


func _panel_hre() -> void:
	var me: String = game.player
	side_title.text = "👑 Heiliges Römisches Reich"
	var emp: String = game.emperor
	if emp == "":
		side_box.add_child(_lbl("Der Kaiserthron ist leer."))
	else:
		side_box.add_child(_lbl("Kaiser:", 18, Color(0.7, 0.8, 0.9)))
		side_box.add_child(_nation_btn(emp, "", _open_panel.bind("other", emp) if emp != me else _open_panel.bind("nation")))
	side_box.add_child(_lbl("Der Kaiser erhält +%d 🕊️/Monat und verteidigt Reichsmitglieder gegen Angreifer von außen. Gewählt wird, wenn der Herrscher des Kaisers stirbt." % int(game.bal.emperor_dip), 15, Color(0.75, 0.75, 0.75)))
	var votes: Dictionary = game.election_votes()
	var count := {}
	for e in votes:
		count[votes[e]] = count.get(votes[e], 0) + 1
	side_box.add_child(_lbl("Kurfürsten (Stimme, wenn jetzt gewählt würde):", 18, Color(0.7, 0.8, 0.9)))
	for e in game.current_electors():
		var v: String = votes.get(e, "")
		var txt := "  → %s  ❤️%d" % [game.nations[v].name if v != "" else "–", int(game.get_rel(me, e)) if e != me else 0]
		side_box.add_child(_nation_btn(e, txt, _open_panel.bind("other", e) if e != me else _open_panel.bind("nation")))
	if game.hre.has(me):
		var mine: int = count.get(me, 0)
		side_box.add_child(_lbl("Du hättest %d von %d Stimmen. Bessere Beziehungen, Bündnisse und Prestige bringen Stimmen." % [mine, votes.size()], 16, Color(1, 0.9, 0.6)))
	else:
		side_box.add_child(_lbl("Du bist kein Reichsmitglied und kannst nicht gewählt werden.", 16))
	side_box.add_child(_lbl("Mitglieder: %d" % game.hre_members().size(), 15, Color(0.75, 0.75, 0.75)))


func _panel_ranking() -> void:
	side_title.text = "🏆 Rangliste"
	var tags := []
	for t in game.order:
		if game.nations[t].alive:
			tags.append(t)
	tags.sort_custom(func(a, b): return game.score(a) > game.score(b))
	for i in mini(20, tags.size()):
		var t: String = tags[i]
		var o = game.nations[t]
		var txt := "  🏘️%d  🛡️%.0f" % [o.dev_total, game.army_regs(t)]
		if o.overlord != "":
			txt += "  ⛓️"
		var b := _nation_btn(t, txt, _open_panel.bind("other", t) if t != game.player else _open_panel.bind("nation"), "%d. " % (i + 1))
		if t == game.player:
			b.modulate = Color(1.0, 0.95, 0.6)
		side_box.add_child(b)
	var mine: int = tags.find(game.player)
	if mine >= 20:
		side_box.add_child(_lbl("Du: Platz %d" % (mine + 1), 16))


func _panel_log() -> void:
	side_title.text = "📜 Chronik"
	var lines: Array = game.log_lines.duplicate()
	lines.reverse()
	for l in lines:
		side_box.add_child(_lbl(l, 15))


# ---------------------------------------------------------------- texts

func effects_text(e: Dictionary) -> String:
	var parts := []
	for p in effect_parts(e):
		parts.append(p[0])
	return ", ".join(parts)


## Effects as BBCode: buffs green with an up arrow, nerfs red with a down arrow, neutral grey.
func effects_bb(e: Dictionary, sep: String = "   ") -> String:
	var parts := []
	for p in effect_parts(e):
		parts.append(UiTheme.tone_bb(p[0], p[1]))
	return sep.join(parts)


## [text, tone] per effect; tone 1 = good for the player, -1 = bad, 0 = neutral.
func effect_parts(e: Dictionary) -> Array:
	var parts := []
	var icons := {"gold": "💰", "adm": "📜", "dip": "🕊️", "mil": "⚔️", "ae": "😠 AE", "prestige": "⭐", "manpower": "👥", "regs": "🛡️ Reg."}
	var sgn := func(v: float, good_if_up: bool = true) -> int:
		return 0 if is_zero_approx(v) else (1 if (v > 0) == good_if_up else -1)
	for k in e:
		var v = e[k]
		if icons.has(k):
			parts.append(["%s %+d" % [icons[k], int(v)], sgn.call(float(v), k != "ae")])
		elif k == "dev_capital":
			parts.append(["🏘️ Hauptstadt %+d" % int(v), sgn.call(float(v))])
		elif k == "dev_random":
			parts.append(["🏘️ %+d zufällige Entw." % int(v), sgn.call(float(v))])
		elif k == "relations":
			for t in v:
				if game.nations.has(t):
					parts.append(["❤️ %s %+d" % [game.nations[t].name, int(v[t])], sgn.call(float(v[t]))])
		elif k == "claim":
			var names := []
			for key in v:
				names.append(game.provinces[game.key_to_pid[key]].name)
			parts.append(["📜 Anspruch: " + ", ".join(names), 1])
		elif k == "mods":
			for m in v:
				var lab: Array = UiTheme.label(m)
				if m in ["adm", "dip", "mil"]:
					parts.append(["%s %+d" % [lab[0], int(v[m])], sgn.call(float(v[m]))])
				else:
					parts.append(["%s %+d%%" % [lab[0], int(round(float(v[m]) * 100))], sgn.call(float(v[m]), lab[2])])
		elif k == "ruler":
			parts.append(["👑 Herrscherwerte verändert", 0])
		elif k == "estate":
			for es in v:
				parts.append(["⚖️ %s %+d" % [game.govt.estate_name(es), int(v[es])], sgn.call(float(v[es]))])
		elif k == "alliance":
			parts.append(["🤝 Bündnis mit " + game.nations[v].name, 1])
		elif k == "inherit":
			parts.append(["👑 Erbe: " + game.nations[v].name, 1])
		elif k == "we":
			parts.append(["😩 Kriegsmüdigkeit %+.0f" % float(v), sgn.call(float(v), false)])
		elif k == "vassal":
			parts.append(["⛓️ Vasall: " + game.nations[v].name, 1])
		elif k == "province":
			parts.append(["🏘️ Erhalte " + game.provinces[game.key_to_pid[v]].name, 1])
		elif k == "war":
			parts.append(["🔥 Krieg gegen " + game.nations[v].name, 0])
		elif k == "build":
			var bd: Dictionary = game.buildings_def[v]
			parts.append(["%s %s +1 Stufe (gratis)" % [bd.emoji, bd.name], 1])
		elif k == "army_power":
			parts.append(["🔥 Moral der Armeen %+d%%" % int(round(float(v) * 100)), sgn.call(float(v))])
		elif k == "loan":
			parts.append(["🏦 Neuer Kredit (%d)" % int(v), 0])
		elif k == "loan_forgiven":
			parts.append(["🏦 Kredit erlassen", 1])
		elif k == "merc_ready":
			parts.append(["⚔️ Söldner sofort verfügbar", 1])
	return parts


func conditions_text(c: Dictionary) -> String:
	var me: String = game.player
	var lines := []
	for k in c:
		var v = c[k]
		var ok: bool = game.check_conditions(me, {k: v})
		var mark := "✅ " if ok else "❌ "
		match k:
			"owns":
				var names := []
				for key in v:
					var p = game.provinces[game.key_to_pid[key]]
					names.append(("" if p.owner == me else "✗") + p.name)
				lines.append(mark + "Besitze: " + ", ".join(names))
			"owns_any":
				var names := []
				for key in v:
					names.append(game.provinces[game.key_to_pid[key]].name)
				lines.append(mark + "Besitze eine von: " + ", ".join(names))
			"min_dev":
				lines.append(mark + "Gesamtentwicklung ≥ %d (jetzt %d)" % [int(v), game.nations[me].dev_total])
			"tech":
				for t in v:
					lines.append(mark + "%s-Technologie ≥ %d" % [{"adm": "Verwaltungs", "dip": "Diplomatie", "mil": "Militär"}[t], int(v[t])])
			"has_tech":
				lines.append(mark + "Technologie: " + game.tree.by_id[v].name)
			"estate_min":
				for e in v:
					lines.append(mark + "Zufriedenheit %s ≥ %d" % [game.govt.estate_name(e), int(v[e])])
			"estate_max":
				for e in v:
					lines.append(mark + "Zufriedenheit %s ≤ %d" % [game.govt.estate_name(e), int(v[e])])
			"law":
				for l in v:
					lines.append(mark + "%s: %s" % [game.govt.law_by_id[l].name, game.govt.law_option(l, v[l]).name])
			"allies":
				lines.append(mark + "Mindestens %d Verbündete" % int(v))
			"allied":
				lines.append(mark + "Verbündet mit " + game.nations[v].name)
			"regs":
				lines.append(mark + "Armee ≥ %d Regimenter" % int(v))
			"not_alive":
				lines.append(mark + "%s existiert nicht mehr" % game.nations[v].name)
			"at_peace":
				lines.append(mark + "Im Frieden")
			"gold_min":
				lines.append(mark + "Gold ≥ %d" % int(v))
			"year_min":
				lines.append(mark + "Ab dem Jahr %d" % int(v))
			"we_min":
				lines.append(mark + "Kriegsmüdigkeit ≥ %d" % int(v))
			"hre":
				lines.append(mark + ("Mitglied des Reiches" if v else "Nicht im Reich"))
			"emperor":
				lines.append(mark + ("Ist Kaiser" if v else "Ist nicht Kaiser"))
			"is_vassal":
				lines.append(mark + ("Ist ein Vasall" if v else "Ist unabhängig"))
			"has_vassal":
				lines.append(mark + ("Hat Vasallen" if v else "Hat keine Vasallen"))
			"unrest_min":
				lines.append(mark + "Unruhe in einer Provinz ≥ %d" % int(v))
			"building":
				for bid in v:
					var bd: Dictionary = game.buildings_def[bid]
					lines.append(mark + "%s %s: %d Stufen (jetzt %d)" % [bd.emoji, bd.name, int(v[bid]), game.Economy.building_total(game, me, bid)])
			"no_building":
				lines.append(mark + "Noch kein %s" % game.buildings_def[v].name)
			"coastal":
				lines.append(mark + ("Besitzt eine Küstenprovinz" if v else "Keine Küste"))
			"produces":
				lines.append(mark + "Stellt %s %s her" % [game.goods_def[v].emoji, game.goods_def[v].name])
			"goods_leader":
				lines.append(mark + ("Marktführer bei einer Ware" if v is bool else "Marktführer bei %s" % game.goods_def[v].name))
			"loans_min":
				lines.append(mark + "Mindestens %d offene Kredite" % int(v))
			"loans_max":
				lines.append(mark + "Höchstens %d offene Kredite" % int(v))
			"trade_pacts_min":
				lines.append(mark + "Mindestens %d Handelsabkommen" % int(v))
			"budget_min":
				for id in v:
					lines.append(mark + "%s mindestens „%s“" % [game.govt.budget_by_id[id].name, game.govt.budget_by_id[id].steps[int(v[id])]])
			"budget_max":
				for id in v:
					lines.append(mark + "%s höchstens „%s“" % [game.govt.budget_by_id[id].name, game.govt.budget_by_id[id].steps[int(v[id])]])
			_:
				lines.append(mark + k)
	return "\n".join(lines)
