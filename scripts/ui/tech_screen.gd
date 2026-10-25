extends RefCounted
## Tech tree screen in the side panel: one category at a time as a 3-column tree (one column per
## branch, one row per tier), national special techs on top. Tapping a tech opens a detail popup
## with the research button, so a stray tap on a phone never spends points.
## `m` is the main UI (scripts/ui/main.gd); it owns the side panel, modal and button helpers.

const Tech = preload("res://scripts/core/tech.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const CAT_NAMES := {"adm": "Verwaltung", "dip": "Diplomatie", "mil": "Militär"}
const COL_DONE := Color("2c4a33")
const COL_READY := Color("6b5520")
const COL_OPEN := Color("383426")
const COL_LOCKED := Color("1c2029")

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
		_style(b, Color("4a5a78") if k == cat else Color("2b3445"), Color("8fa7d6") if k == cat else Color(0, 0, 0, 0))
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
	for i in rows:
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
	var mark := "✓ " if done else ("" if reason == "" else "🔒 ")
	var sub := "" if done else ("ab %d" % from if g.year() < from else "%d %s" % [cost, Icons.emoji(t.cat)])
	var b: Button = m._btn(mark + t.name + ("\n" + sub if sub != "" else ""), _detail.bind(t.id))
	b.clip_text = false
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 74 if m._big() else 64)
	b.add_theme_font_size_override("font_size", 14)
	var bg := COL_LOCKED
	var border := Color(0, 0, 0, 0)
	if done:
		bg = COL_DONE
		b.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	elif reason == "":
		bg = COL_READY if n.get(t.cat) >= cost else COL_OPEN
		border = Color(1.0, 0.8, 0.35) if n.get(t.cat) >= cost else Color(0.55, 0.5, 0.3)
	else:
		b.add_theme_color_override("font_color", Color(0.55, 0.57, 0.62))
	if special:
		border = Color(1.0, 0.85, 0.4)
	_style(b, bg, border)
	return b


func _style(b: Button, bg: Color, border: Color) -> void:
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg.lightened(0.08) if st == "hover" else bg
		s.set_corner_radius_all(8)
		s.set_content_margin_all(6)
		if border.a > 0.0:
			s.border_color = border
			s.set_border_width_all(2)
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
	var go := func():
		var err: String = g.research(me, id)
		m._close_modal()
		m._act(err, "🔬 %s erforscht!" % t.name)
	var research: Button = m._btn("🔬 Erforschen (%d)" % cost, go, "", reason != "" or n.get(t.cat) < cost)
	box.add_child(m._row([research, m._btn("Schließen", m._close_modal)]))


static func effects_rich(eff: Dictionary, fs: int = 16) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size.x = 100
	r.add_theme_font_size_override("normal_font_size", fs)
	var parts := []
	for l in Tech.effect_lines(eff):
		parts.append("[color=%s]%s[/color]" % ["#8fdc8f" if l[1] else "#f08a7a", l[0]])
	r.text = "  ·  ".join(parts) if not parts.is_empty() else "[color=#999999]keine Wirkung[/color]"
	return r
