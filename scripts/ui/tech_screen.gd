extends RefCounted
## Tech tree screen in the side panel: one category at a time as a 3-column tree (one column per
## branch, one row per tier), national special techs on top. Tapping a tech opens a detail popup
## with the research button, so a stray tap on a phone never spends points.
## `m` is the main UI (scripts/ui/main.gd); it owns the side panel, modal and button helpers.

const Tech = preload("res://scripts/core/tech.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const CAT_NAMES := {"adm": "Verwaltung", "dip": "Diplomatie", "mil": "Militär"}

var m
var cat := "adm"


func _init(main) -> void:
	m = main


## True when the player can research something right now (tab badge).
func can_research(g, tag: String) -> bool:
	var n = g.nations[tag]
	for k in g.POWERS:
		if n.get(k) >= g.tech_cost(tag, k) and not g.tree.available(g, tag, k).is_empty():
			return true
	return false


func build() -> void:
	var g = m.game
	var me: String = g.player
	var n = g.nations[me]
	m.side_title.text = "🔬 Technologie"
	var cats := []
	for k in g.POWERS:
		var c: float = g.tech_cost(me, k)
		var b: Button = m._btn("%s%s\n%d / %d" % [Icons.prefix(k), CAT_NAMES[k], n.get(k), c], _select.bind(k))
		b.clip_text = false
		b.add_theme_font_size_override("font_size", 16)
		if k == cat:  # the selected category looks pressed
			b.add_theme_stylebox_override("normal", UiTheme.box("button_pressed", 10))
		if n.get(k) >= c and not g.tree.available(g, me, k).is_empty():
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		cats.append(b)
	m.side_box.add_child(m._row(cats))
	var lvl: int = n.tech[cat]
	var expected: float = (g.year() - int(g.bal.start_year)) / float(g.bal.tech_years_per_level)
	var ahead: float = maxf(0.0, lvl + 1 - expected)
	var info := "Zeitalter der %s · Stufe %d · nächste Technologie %d %s" % [Tech.age_name(g.year()), lvl, g.tech_cost(me, cat), Icons.emoji(cat)]
	if ahead >= 1.0:
		info += "\nDu bist der Zeit voraus: +%d %% Kosten." % roundi(ahead * float(g.bal.tech_ahead_penalty) * 100.0)
	m.side_box.add_child(m._lbl(info, 15, Color(0.8, 0.82, 0.9)))
	m.side_box.add_child(m._lbl("Gold umrandet: jetzt erforschbar · 🔒 Vorgänger fehlt · Antippen zeigt Details", 13, Color(0.65, 0.68, 0.75)))
	var specials: Array = g.tree.specials_of(me)
	if not specials.is_empty():
		m.side_box.add_child(m._lbl("⭐ Nationale Technologien", 20, Color(1.0, 0.85, 0.4)))
		var sg := GridContainer.new()
		sg.columns = 3
		sg.add_theme_constant_override("h_separation", 6)
		sg.add_theme_constant_override("v_separation", 6)
		for t in specials:
			sg.add_child(_cell(g, me, t, true))
		m.side_box.add_child(sg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var cols := []
	for b in g.tree.branches:
		if b.cat == cat:
			cols.append(b)
			var l: Label = m._lbl(b.name, 15, Color(0.75, 0.8, 0.95))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(l)
	var per := {}
	for t in g.tree.techs_for(me, cat):
		if not Tech.is_special(t):
			if not per.has(t.branch):
				per[t.branch] = []
			per[t.branch].append(t)
	var rows := 0
	for b in cols:
		rows = maxi(rows, per.get(b.id, []).size())
	var first := 0
	while first < rows:
		var all_done := true
		for b in cols:
			var lst: Array = per.get(b.id, [])
			if first < lst.size() and not n.techs.has(lst[first].id):
				all_done = false
		if not all_done:
			break
		first += 1
	if first > 0:
		m.side_box.add_child(m._lbl("✓ Die ersten %d Stufen aller drei Zweige sind erforscht (ausgeblendet)." % first, 14, Color(0.7, 0.9, 0.7)))
	for i in range(first, rows):
		for b in cols:
			var lst: Array = per.get(b.id, [])
			if i < lst.size():
				grid.add_child(_cell(g, me, lst[i], false))
			else:
				grid.add_child(Control.new())
	m.side_box.add_child(grid)
	m.side_box.add_child(m._lbl("Gesamtwirkung deiner Technologien", 18))
	m.side_box.add_child(effects_rich(n.bonus.get("tech", {}), 15))
	m.side_box.add_child(m._lbl("Jede Stufe zählt außerdem: Verwaltung +4 % Einkommen, Diplomatie schnellerer AE-Abbau, Militär +6 % Kampfkraft und +½ Truppenlimit.", 14, Color(0.65, 0.68, 0.75)))


func _select(k: String) -> void:
	cat = k
	m._refresh()


func _cell(g, me: String, t: Dictionary, special: bool) -> Button:
	var n = g.nations[me]
	var reason: String = g.tree.block_reason(g, me, t.id)
	var done: bool = n.techs.has(t.id)
	var cost: float = g.tree.cost(g, me, t.id)
	var from: int = int(t.year) - g.tree.early_years
	var ready: bool = reason == "" and n.get(t.cat) >= cost
	var foot := "✓ erforscht" if done else ("ab %d" % from if g.year() < from else "%d %s" % [cost, Icons.emoji(t.cat)])
	if not done and reason != "" and g.year() >= from:
		foot = "🔒 " + foot
	var tip: String = "%s\n%s\n%s" % [t.name, Tech.effects_text(t.effects), "Erforscht" if done else (reason if reason != "" else "Kosten %d" % cost)]
	var b: Button = m._btn("", _detail.bind(t.id), tip)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# height from content: name (1-2 lines), one line per effect, cost line
	var name_lines: int = 1 + int(t.name.length() > 15) + int(t.name.length() > 30)
	b.custom_minimum_size = Vector2(0, 22 + 20 * name_lines + 18 * t.effects.size() + 22 + (8 if m._big() else 0))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var name_col := Color(0.8, 0.95, 0.8) if done else (Color(1.0, 0.92, 0.7) if reason == "" else Color(0.62, 0.64, 0.7))
	var title: Label = m._lbl(t.name, 15, name_col)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.x = 0
	v.add_child(title)
	var eff := effects_rich(t.effects, 13, true)
	eff.custom_minimum_size.x = 0
	v.add_child(eff)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	var f: Label = m._lbl(foot, 13, Color(1.0, 0.85, 0.4) if ready else Color(0.7, 0.72, 0.78))
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.custom_minimum_size.x = 0
	v.add_child(f)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind := ""
	if done:
		kind = "good"
	elif reason == "" and ready:
		kind = "gold"
	if special and not done:
		kind = "gold"
	_style(b, kind, reason != "" and not done)
	return b


## Tech tile frame: green when researched, gold when affordable (or a national tech), dimmed when locked.
func _style(b: Button, kind: String, locked: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var s: StyleBox = UiTheme.card(kind, 6)
		if s is StyleBoxTexture:
			s.modulate_color = Color(0.7, 0.7, 0.75) if locked else (Color(1.25, 1.25, 1.25) if st == "hover" else Color.WHITE)
		b.add_theme_stylebox_override(st, s)


func _detail(id: String) -> void:
	var g = m.game
	var me: String = g.player
	var n = g.nations[me]
	var t: Dictionary = g.tree.by_id[id]
	m._open_modal()
	var box: VBoxContainer = m.modal_box
	box.add_child(m._lbl(("⭐ " if Tech.is_special(t) else "🔬 ") + t.name, 26))
	var where := "%s%s" % [Icons.prefix(t.cat), CAT_NAMES[t.cat]]
	for b in g.tree.branches:
		if not Tech.is_special(t) and b.id == t.get("branch", ""):
			where += " · " + b.name
	where += " · Zeitalter: %s" % Tech.age_name(int(t.year))
	if int(t.year) - g.tree.early_years > g.year():
		where += " (verfügbar ab %d)" % (int(t.year) - g.tree.early_years)
	box.add_child(m._lbl(where, 16, Color(0.8, 0.82, 0.9)))
	if t.has("text"):
		box.add_child(m._lbl(t.text, 17, Color(0.85, 0.85, 0.75)))
	box.add_child(effects_rich(t.effects, 19))
	for k in t.effects:
		if Tech.DESCS.has(k):
			box.add_child(m._lbl("• %s: %s" % [Tech.LABELS[k][0], Tech.DESCS[k]], 14, Color(0.68, 0.7, 0.78)))
	for r in t.get("req", []):
		var ok: bool = n.techs.has(r)
		box.add_child(m._lbl(("✓ " if ok else "✗ ") + "Benötigt: " + g.tree.by_id[r].name, 16, Color(0.7, 0.9, 0.7) if ok else Color(0.95, 0.6, 0.55)))
	var reason: String = g.tree.block_reason(g, me, id)
	var cost: float = g.tree.cost(g, me, id)
	if n.techs.has(id):
		box.add_child(m._lbl("✓ Erforscht", 18, Color(0.7, 0.95, 0.7)))
	elif reason != "" and not reason.begins_with("Benötigt"):
		box.add_child(m._lbl(reason, 17, Color(0.95, 0.6, 0.55)))
	else:
		box.add_child(m._lbl("Kosten: %d %s (du hast %d)" % [cost, Icons.emoji(t.cat), n.get(t.cat)], 18))
		var sd: float = g.tree.spread_discount(g, me, id)
		if sd >= 0.01:
			box.add_child(m._lbl("Davon −%d %% durch Wissensverbreitung: %d %% der anderen Nationen kennen sie schon." % [
					roundi(sd * 100.0), roundi(g.tree.known_share(g, me, id) * 100.0)], 15, Color(0.6, 0.9, 0.6)))
	var go := func():
		var err: String = g.research(me, id)
		m._close_modal()
		m._act(err, "🔬 %s erforscht!" % t.name)
	var research: Button = m._btn("🔬 Erforschen (%d)" % cost, go, "", reason != "" or n.get(t.cat) < cost)
	box.add_child(m._row([research, m._btn("Schließen", m._close_modal)]))


static func effects_rich(eff: Dictionary, fs: int = 16, compact: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size.x = 100
	r.add_theme_font_size_override("normal_font_size", fs)
	var px: int = 0 if compact else clampi(fs - 2, 12, 18)  # narrow tiles: colour only, no arrows
	var txt: String = UiTheme.mods_bb(eff, "\n" if compact else "   ", px)
	r.text = txt if txt != "" else "[color=#999999]keine Wirkung[/color]"
	if compact:
		r.text = "[center]" + r.text + "[/center]"
	return r
