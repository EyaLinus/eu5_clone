extends Control
## Root of the game UI. Builds all controls in code (no hand-written scenes),
## drives the monthly tick and shows panels/popups.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const SAVE_PATH := "user://save.json"
const SPEEDS := [0.0, 1.2, 0.6, 0.3, 0.12, 0.04]
const MAJORS := ["FRA", "ENG", "SPA", "BOH", "HAB", "RUS", "NAP"]

var data: Dictionary
var game
var speed := 0
var acc := 0.0
var panel_mode := ""
var panel_arg = null
var selected_army := -1
var peace_selection := {}
var last_log_count := 0
var known_wars := {}
var known_coalition := 0

var map: MapView
var top_labels := {}
var speed_label: Label
var side_panel: PanelContainer
var side_title: Label
var side_box: VBoxContainer
var side_scroll: ScrollContainer
var modal: Control
var modal_box: VBoxContainer
var toast: Label
var toast_time := 0.0
var hud: Control


func _ready() -> void:
	_setup_theme()
	data = Data.load_all()
	map = MapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map)
	map.province_tapped.connect(_on_province_tapped)
	map.army_tapped.connect(_on_army_tapped)
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


func _setup_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 20
	var emoji = load("res://assets/fonts/NotoColorEmoji.ttf")
	if emoji is FontFile:
		emoji.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
		var base: Font = ThemeDB.fallback_font
		var fb: Array[Font] = base.fallbacks
		fb.append(emoji)
		base.fallbacks = fb
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.13, 0.94)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	t.set_stylebox("panel", "PanelContainer", sb)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(8)
		b.set_content_margin_all(8)
		match st:
			"normal":
				b.bg_color = Color("2b3445")
			"hover":
				b.bg_color = Color("38445a")
			"pressed":
				b.bg_color = Color("4a5a78")
			"disabled":
				b.bg_color = Color("1e232c")
			"focus":
				b.bg_color = Color(0, 0, 0, 0)
				b.border_color = Color("8fa7d6")
				b.set_border_width_all(1)
		t.set_stylebox(st, "Button", b)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	theme = t


# ---------------------------------------------------------------- HUD construction

func _build_hud() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 58
	hud.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	for k in ["nation", "gold", "adm", "dip", "mil", "manpower", "army", "ae"]:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_STOP
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

	var left := VBoxContainer.new()
	left.position = Vector2(8, 68)
	left.add_theme_constant_override("separation", 8)
	hud.add_child(left)
	for e in [["🏛️", "nation", "Nation"], ["🤝", "diplomacy", "Diplomatie"], ["⚔️", "wars", "Kriege"],
			["🎯", "missions", "Missionen"], ["📜", "log", "Chronik"]]:
		var b := _btn(e[0], _open_panel.bind(e[1]), e[2])
		b.custom_minimum_size = Vector2(60, 60)
		b.add_theme_font_size_override("font_size", 28)
		left.add_child(b)
	var mm := _btn("🗺️", _cycle_map_mode, "Kartenmodus")
	mm.custom_minimum_size = Vector2(60, 60)
	mm.add_theme_font_size_override("font_size", 28)
	left.add_child(mm)

	var zoom := VBoxContainer.new()
	zoom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zoom.position = Vector2(8, -140)
	zoom.add_theme_constant_override("separation", 8)
	hud.add_child(zoom)
	for e in [["🔍+", 1.3], ["🔍-", 1.0 / 1.3]]:
		var b := _btn(e[0], func(): map.zoom_by(e[1]))
		b.custom_minimum_size = Vector2(60, 56)
		zoom.add_child(b)
	zoom.offset_top = -130

	side_panel = PanelContainer.new()
	side_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side_panel.offset_left = -440
	side_panel.offset_top = 64
	side_panel.offset_right = -6
	side_panel.offset_bottom = -6
	hud.add_child(side_panel)
	var vb := VBoxContainer.new()
	side_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	side_title = Label.new()
	side_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_title.add_theme_font_size_override("font_size", 24)
	side_title.clip_text = true
	head.add_child(side_title)
	head.add_child(_btn("✖", _close_panel))
	side_scroll = ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(side_scroll)
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
	hud.add_child(toast)


func _build_modal() -> void:
	modal = Control.new()
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
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
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
	toast_time = 4.0


func _act(err: String, ok_text: String = "") -> void:
	if err != "":
		_toast("❌ " + err)
	elif ok_text != "":
		_toast(ok_text)
	_refresh()


func nname(tag: String) -> String:
	var n = game.nations[tag]
	return "%s %s" % [n.emoji, n.name]


# ---------------------------------------------------------------- game flow

func _show_start_menu() -> void:
	hud.visible = false
	_open_modal()
	modal_box.add_child(_lbl("🌍 EU5 Lite", 40))
	modal_box.add_child(_lbl("1444 – 1644 · Wähle deine Nation. Ziel: Am Ende die höchste Punktzahl (Entwicklung + Prestige + Technologie).", 18))
	if FileAccess.file_exists(SAVE_PATH):
		modal_box.add_child(_btn("💾 Weiterspielen", _load_game))
	for tag in MAJORS:
		var nd: Dictionary = data.nations[tag]
		var b := _btn("%s %s" % [nd.emoji, nd.name], _start_game.bind(tag))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		modal_box.add_child(b)
		modal_box.add_child(_lbl(nd.get("idea", ""), 15, Color(0.7, 0.75, 0.8)))


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
	modal_box.add_child(_lbl("%s %s, %s" % [n.emoji, n.name, game.date_string()], 30))
	modal_box.add_child(_lbl(n.idea, 18, Color(0.8, 0.85, 0.7)))
	modal_box.add_child(_lbl("So spielst du:\n• Zeit läuft mit ▶/➕ oben rechts, ⏸ pausiert.\n• Tippe auf eine Provinz für Infos und Aktionen (Entwickeln, Rekrutieren, Krieg).\n• Tippe auf eine Armee (Kreis mit Zahl) und dann auf ein Ziel, um sie zu bewegen. 🤖 lässt sie automatisch kämpfen.\n• 📜 Admin, 🕊️ Diplomatie und ⚔️ Militär sammeln sich monatlich: für Technologie, Entwicklung, Bündnisse und Kriegsgründe.\n• 😠 Aggressive Expansion steigt bei Eroberungen. Ab %d bilden Nachbarn Koalitionen gegen dich." % int(game.bal.ae_coalition_threshold), 17))
	modal_box.add_child(_btn("Los geht's ▶", func(): _close_modal(); _set_speed(2)))


func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast.text = ""
	if game == null or modal.visible or speed == 0 or game.game_over:
		return
	acc += delta
	var spm: float = SPEEDS[speed]
	var steps := 0
	while acc >= spm and steps < 4:
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


func _cycle_map_mode() -> void:
	map.map_mode = (map.map_mode + 1) % map.MODE_NAMES.size()
	map.queue_redraw()
	var legend := ""
	if map.map_mode == 1:
		legend = " (🟩 du, 🟦 Verbündete, 🟥 Feinde, 🟧 Ansprüche, 🟪 Koalition)"
	elif map.map_mode == 2:
		legend = " (dunkel = arm, gelb = reich)"
	_toast("🗺️ Kartenmodus: " + map.MODE_NAMES[map.map_mode] + legend)


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
	return false


func _set_speed(s: int) -> void:
	speed = s
	acc = 0.0
	_update_top()


func _update_top() -> void:
	if game == null:
		return
	var n = game.nations[game.player]
	var net: float = n.income - n.expenses
	top_labels.nation.text = nname(game.player)
	top_labels.gold.text = "💰 %d (%+.1f)" % [n.gold, net]
	top_labels.adm.text = "📜 %d" % n.adm
	top_labels.dip.text = "🕊️ %d" % n.dip
	top_labels.mil.text = "⚔️ %d" % n.mil
	top_labels.manpower.text = "👥 %.0f" % n.manpower
	top_labels.army.text = "🛡️ %.0f/%.0f" % [game.army_regs(game.player), game.force_limit(game.player)]
	top_labels.ae.text = "😠 %d" % n.ae
	top_labels.ae.add_theme_color_override("font_color", Color.TOMATO if n.ae >= game.bal.ae_coalition_threshold * 0.7 else Color.WHITE)
	top_labels.gold.add_theme_color_override("font_color", Color.TOMATO if n.gold < 0 else Color.WHITE)
	top_labels.date.text = "📅 " + game.date_string()
	speed_label.text = "⏸" if speed == 0 else "▶".repeat(speed)


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
			_close_panel()
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
	modal_box.add_child(_btn("🏠 Hauptmenü (speichert)", func(): _save_game(); game = null; _show_start_menu()))
	if OS.get_name() != "Android":
		modal_box.add_child(_btn("🚪 Beenden", func(): _save_game(); get_tree().quit()))


func _show_event(event_id: String) -> void:
	var e: Dictionary = game.event_by_id[event_id]
	_open_modal()
	modal_box.add_child(_lbl("📯 " + e.title, 28))
	modal_box.add_child(_lbl(e.text, 18))
	for i in e.options.size():
		var o: Dictionary = e.options[i]
		var txt: String = o.text
		var eff := effects_text(o.get("effects", {}))
		if eff != "":
			txt += "\n" + eff
		var b := _btn(txt, _choose_event.bind(event_id, i))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		modal_box.add_child(b)


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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	modal_box.add_child(_btn("🏠 Hauptmenü", func(): game = null; _show_start_menu()))


# ---------------------------------------------------------------- side panel

func _open_panel(mode: String, arg = null) -> void:
	if game == null:
		return
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


func _close_panel() -> void:
	side_panel.visible = false
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
	side_scroll.set_deferred("scroll_vertical", scroll)


func _on_province_tapped(pid: int) -> void:
	if selected_army >= 0:
		var a = game.army_by_id(selected_army)
		if a != null and a.owner == game.player:
			a.auto = false
			var err: String = game.move_army(a, pid)
			_act(err, "🚶 Marschbefehl nach %s" % game.provinces[pid].name if err == "" else "")
			map.queue_redraw()
			return
	map.selected_pid = pid
	_open_panel("province", pid)
	map.selected_pid = pid


func _on_army_tapped(id: int) -> void:
	if selected_army == id:
		_close_panel()
		return
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
	side_title.text = "📍 " + p.name
	var owner_btn := _btn("Besitzer: " + nname(p.owner), _open_panel.bind("other", p.owner))
	if p.owner == me:
		owner_btn.disabled = true
	side_box.add_child(owner_btn)
	var info := "🏘️ Entwicklung: %d\n💰 Steuer: %.2f/Monat" % [p.dev, p.dev * float(game.bal.income_per_dev)]
	if p.fort > 0:
		info += "\n🏰 Festung (Belagerung dauert länger)"
	if p.core_months > 0:
		info += "\n🔨 Wird integriert: noch %d Monate (halbes Einkommen)" % p.core_months
	if p.controller != p.owner:
		info += "\n🔥 Besetzt von " + nname(p.controller)
	if p.siege > 0:
		info += "\n🔥 Belagerung: %d%%" % int(p.siege)
	if n.claims.has(pid):
		info += "\n📜 Du hast einen Anspruch (Kriegsgrund)"
	side_box.add_child(_lbl(info))
	if p.owner == me:
		side_box.add_child(_btn("📜 Entwickeln (%d Admin)" % game.develop_cost(pid), func(): _act(game.develop(me, pid), "🏘️ Entwicklung erhöht")))
		side_box.add_child(_btn("💰 Bauen (%d Gold)" % game.build_cost(pid), func(): _act(game.build(me, pid), "🏗️ Gebaut")))
		var c := int(game.bal.regiment_cost)
		side_box.add_child(_row([
			_btn("⚔️ +1 Reg. (%d💰)" % c, func(): _act(game.recruit(me, pid, 1), "⚔️ Rekrutiert")),
			_btn("⚔️ +5 (%d💰)" % (c * 5), func(): _act(game.recruit(me, pid, 5), "⚔️ Rekrutiert"))]))
	else:
		var borders := false
		for a in p.adj:
			if game.provinces[a].owner == me:
				borders = true
		if borders and not n.claims.has(pid):
			side_box.add_child(_btn("📜 Anspruch fabrizieren (%d 🕊️)" % int(game.bal.claim_cost), func(): _act(game.fabricate_claim(me, pid), "📜 Anspruch erhoben")))
		if not game.at_war(me, p.owner):
			side_box.add_child(_btn("🔥 Krieg gegen %s…" % game.nations[p.owner].name, _confirm_war.bind(p.owner)))
	var here: Array = game.armies_in(pid)
	if not here.is_empty():
		side_box.add_child(_lbl("Armeen hier:", 18, Color(0.7, 0.8, 0.9)))
		for a in here:
			side_box.add_child(_btn("%s %.1f Reg." % [nname(a.owner), a.regs], _on_army_tapped.bind(a.id)))


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
	if a.owner != game.player:
		return
	side_box.add_child(_lbl("👉 Tippe auf eine Provinz, um die Armee dorthin zu schicken.", 16, Color(0.8, 0.85, 0.6)))
	var auto_btn := _btn("🤖 Automatisch: AN" if a.auto else "🤖 Automatisch: AUS", func(): a.auto = not a.auto; _refresh())
	side_box.add_child(auto_btn)
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
	side_box.add_child(_lbl(n.idea, 16, Color(0.8, 0.85, 0.7)))
	side_box.add_child(_lbl("👑 Herrscher: 📜%d 🕊️%d ⚔️%d" % [n.ruler.adm, n.ruler.dip, n.ruler.mil]))
	side_box.add_child(_lbl("Monatlich: 📜+%.0f 🕊️+%.0f ⚔️+%.0f" % [game.monthly_power(n, "adm"), game.monthly_power(n, "dip"), game.monthly_power(n, "mil")]))
	side_box.add_child(_lbl("💰 Einnahmen %.1f · Ausgaben %.1f\n🏘️ Entwicklung %d · %d Provinzen\n🛡️ Truppenlimit %.0f · 👥 %.0f/%.0f\n⭐ Prestige %d · 🏆 Punkte %d" % [
			n.income, n.expenses, n.dev_total, game.provinces_of(me).size(), game.force_limit(me), n.manpower, n.max_manpower, n.prestige, game.score(me)]))
	side_box.add_child(_lbl("Technologie", 22))
	var names := {"adm": "📜 Verwaltung (+4% Einkommen)", "dip": "🕊️ Diplomatie (schnellerer AE-Abbau)", "mil": "⚔️ Militär (+6% Kampfkraft, +½ Truppenlimit)"}
	for k in game.POWERS:
		side_box.add_child(_lbl("%s – Stufe %d" % [names[k], n.tech[k]], 17))
		side_box.add_child(_btn("Erforschen (%d)" % game.tech_cost(me, k), func(): _act(game.buy_tech(me, k), "🔬 Fortschritt!")))
	side_box.add_child(_lbl("Aggressive Expansion", 22))
	var thr: float = game.bal.ae_coalition_threshold
	var co := []
	for t in n.coalition:
		co.append(game.nations[t].name)
	side_box.add_child(_lbl("😠 %d / %d (Koalitionsgrenze)\nKoalition gegen dich: %s" % [n.ae, thr, ", ".join(co) if not co.is_empty() else "keine"]))


func _panel_diplomacy() -> void:
	var me: String = game.player
	side_title.text = "🤝 Diplomatie"
	var groups := [["Verbündete", []], ["Feinde", []], ["Nachbarn", []], ["Andere", []]]
	var nbs: Array = game.neighbors_of(me)
	for tag in game.order:
		if tag == me or not game.nations[tag].alive:
			continue
		if game.is_allied(me, tag):
			groups[0][1].append(tag)
		elif game.at_war(me, tag):
			groups[1][1].append(tag)
		elif nbs.has(tag):
			groups[2][1].append(tag)
		else:
			groups[3][1].append(tag)
	for g in groups:
		if g[1].is_empty():
			continue
		side_box.add_child(_lbl(g[0], 20, Color(0.7, 0.8, 0.9)))
		for tag in g[1]:
			var o = game.nations[tag]
			var txt := "%s  ❤️%d  🏘️%d" % [nname(tag), int(game.get_rel(me, tag)), o.dev_total]
			if o.ae >= float(game.bal.ae_coalition_threshold):
				txt += "  😠"
			var b := _btn(txt, _open_panel.bind("other", tag))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			side_box.add_child(b)


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
	side_box.add_child(_lbl(info))
	side_box.add_child(_btn("🗺️ Auf Karte zeigen", func(): map.focus(game.provinces[o.capital].center)))
	if not o.alive:
		return
	var b: Dictionary = game.bal
	side_box.add_child(_btn("❤️ Beziehungen verbessern (%d 🕊️)" % int(b.improve_relation_cost), func(): _act(game.improve_relations(me, tag), "❤️ Beziehungen verbessert")))
	if game.is_allied(me, tag):
		side_box.add_child(_btn("💔 Bündnis auflösen", func(): game.break_alliance(me, tag); _act("", "💔 Bündnis aufgelöst")))
	else:
		side_box.add_child(_btn("🤝 Bündnis anbieten (%d 🕊️)" % int(b.alliance_cost), func(): _act(game.propose_alliance(me, tag), "🤝 Bündnis geschlossen!")))
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
	for ally in o.allies:
		if not game.is_allied(me, ally) and not game.has_truce(me, ally):
			joins.append(game.nations[ally].name)
	var cb: bool = game.has_claim_on(me, tag)
	var text := "Gegner: %s\nDeren Stärke: %.0f · Deine Stärke: %.0f" % [", ".join(joins), game.strength(tag), game.strength(me)]
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
	else:
		side_box.add_child(_row([
			_btn("🤖 Alle Armeen: KI", func(): _set_all_auto(true)),
			_btn("✋ Alle: manuell", func(): _set_all_auto(false))]))
	for w in ws_list:
		var att: bool = game.is_attacker(w, me)
		var ws: float = game.warscore(w) * (1.0 if att else -1.0)
		var us := []
		var them := []
		for t in game.side_tags(w, att):
			us.append(game.nations[t].emoji + game.nations[t].name)
		for t in game.side_tags(w, not att):
			them.append(game.nations[t].emoji + game.nations[t].name)
		side_box.add_child(_lbl("🔥 " + w.name, 20, Color(1, 0.8, 0.6)))
		side_box.add_child(_lbl("Wir: %s\nGegner: %s\nKriegspunkte: %+d · Dauer: %d Monate" % [", ".join(us), ", ".join(them), int(ws), game.month - w.start], 16))
		if game.side_tags(w, att)[0] == me:
			side_box.add_child(_btn("🕊️ Friedensverhandlung", _open_panel.bind("peace", w.id)))
		else:
			side_box.add_child(_lbl("Der Kriegsführer %s verhandelt den Frieden." % game.nations[game.side_tags(w, att)[0]].name, 15, Color(0.7, 0.7, 0.7)))
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
	side_box.add_child(_btn("📜 Forderung stellen", func():
		var ok: bool = game.offer_peace(me, w, peace_selection.keys(), true)
		_after_peace(ok)))
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
	for a in game.armies_of(game.player):
		a.auto = on
	_toast("🤖 Alle Armeen werden von der KI geführt." if on else "✋ Du führst alle Armeen selbst.")
	_refresh()


func _toggle_peace(on: bool, pid: int) -> void:
	if on:
		peace_selection[pid] = true
	else:
		peace_selection.erase(pid)
	_refresh()


func _after_peace(ok: bool) -> void:
	if ok:
		_toast("🕊️ Frieden geschlossen!")
		_open_panel("wars")
		map.queue_redraw()
	else:
		_toast("❌ Der Gegner lehnt ab.")
		_refresh()


func _panel_missions() -> void:
	var me: String = game.player
	side_title.text = "🎯 Missionen"
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


func _panel_log() -> void:
	side_title.text = "📜 Chronik"
	var lines: Array = game.log_lines.duplicate()
	lines.reverse()
	for l in lines:
		side_box.add_child(_lbl(l, 15))


# ---------------------------------------------------------------- texts

func effects_text(e: Dictionary) -> String:
	var parts := []
	var icons := {"gold": "💰", "adm": "📜", "dip": "🕊️", "mil": "⚔️", "ae": "😠 AE", "prestige": "⭐", "manpower": "👥", "regs": "🛡️ Reg."}
	for k in e:
		var v = e[k]
		if icons.has(k):
			parts.append("%s %+d" % [icons[k], int(v)])
		elif k == "dev_capital":
			parts.append("🏘️ Hauptstadt %+d" % int(v))
		elif k == "dev_random":
			parts.append("🏘️ %+d zufällige Entw." % int(v))
		elif k == "relations":
			for t in v:
				if game.nations.has(t):
					parts.append("❤️ %s %+d" % [game.nations[t].name, int(v[t])])
		elif k == "claim":
			var names := []
			for key in v:
				names.append(game.provinces[game.key_to_pid[key]].name)
			parts.append("📜 Anspruch: " + ", ".join(names))
		elif k == "mods":
			var mn := {"income": "Einkommen", "combat": "Kampfkraft", "manpower": "Mannschaften", "adm": "Admin/Monat", "dip": "Diplomatie/Monat", "mil": "Militär/Monat", "ae_decay": "AE-Abbau"}
			for m in v:
				if m in ["adm", "dip", "mil"]:
					parts.append("%s %+d" % [mn.get(m, m), int(v[m])])
				else:
					parts.append("%s %+d%%" % [mn.get(m, m), int(round(float(v[m]) * 100))])
		elif k == "ruler":
			parts.append("👑 Herrscherwerte verändert")
		elif k == "alliance":
			parts.append("🤝 Bündnis mit " + game.nations[v].name)
		elif k == "inherit":
			parts.append("👑 Erbe: " + game.nations[v].name)
		elif k == "province":
			parts.append("🏘️ Erhalte " + game.provinces[game.key_to_pid[v]].name)
		elif k == "war":
			parts.append("🔥 Krieg gegen " + game.nations[v].name)
	return ", ".join(parts)


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
			_:
				lines.append(mark + k)
	return "\n".join(lines)
