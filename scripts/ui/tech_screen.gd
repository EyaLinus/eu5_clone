extends RefCounted
## Tech tree screen in the side panel: one category at a time as a 3-column tree (one column per
## branch, one row per tier); the category's national techs sit on top while researchable, else
## below the tree. Tapping a tech opens a detail popup
## with the research button, so a stray tap on a phone never spends points. Only the next WINDOW tiers
## and national techs not yet researched are shown, to keep scrolling short.
## `m` is the main UI (scripts/ui/main.gd); it owns the side panel, modal and button helpers.

const Tech = preload("res://scripts/core/tech.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const CAT_NAMES := {"adm": "Verwaltung", "dip": "Diplomatie", "mil": "Militär"}

## Tiers shown at once (from the first one not fully researched); the rest behind a button.
const WINDOW := 3

var m
var cat := "adm"
var show_all := false


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
	var info := "%s · Stufe %d\nGrundpreis %d %s" % [Tech.age_name(g.year()), lvl, g.tech_cost(me, cat), Icons.emoji(cat)]
	if ahead >= 1.0:
		info += " (+%d %% voraus)" % roundi(ahead * float(g.bal.tech_ahead_penalty) * 100.0)
	var il: Label = m._lbl(info, 15, Color(0.8, 0.82, 0.9))
	il.tooltip_text = "Zeitalter der %s. Gold umrandet: jetzt erforschbar · 🔒 Vorgänger fehlt · ▶ früh (Aufschlag) · 🏗 schaltet Gebäude frei · Antippen zeigt Details" % Tech.age_name(g.year())
	il.mouse_filter = Control.MOUSE_FILTER_STOP
	il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gv = g.govt
	var age: Dictionary = gv.age_of_year(g.year())
	var age_txt := "🏆 %d/%d" % [gv.age_goals_done(n, age), age.goals.size()] if not age.is_empty() else "🏆"
	var goals: Button = m._btn(age_txt, _ages, "Zeitalter-Ziele: erreichte Ziele geben dauerhafte Boni")
	var sum: Button = m._btn("📈 Gesamt", _overview, "Gesamtwirkung deiner Technologien")
	var plan: Button = m._btn("📜 Plan %d" % n.tech_queue.size(), _plan, "Forschungsplan: vorgemerkte Technologien werden automatisch erforscht")
	m.side_box.add_child(m._row([il, goals, plan, sum]))
	for b in [goals, plan, sum]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.clip_text = false
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.add_theme_font_size_override("font_size", 15)
	if not age.is_empty() and _age_goal_ready(g, n, age):
		goals.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	# national techs of this category only: researchable ones above the tree, locked ones below it
	var specials: Array = g.tree.specials_of(me).filter(func(t): return t.cat == cat and not n.techs.has(t.id))
	var open_sp: Array = specials.filter(func(t): return g.tree.block_reason(g, me, t.id) == "")
	_specials(g, me, open_sp)
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
	var last: int = rows if show_all else mini(rows, first + WINDOW)
	for i in range(first, last):
		for b in cols:
			var lst: Array = per.get(b.id, [])
			if i < lst.size():
				grid.add_child(_cell(g, me, lst[i], false))
			else:
				grid.add_child(Control.new())
	m.side_box.add_child(grid)
	_specials(g, me, specials.filter(func(t): return not open_sp.has(t)))
	if rows - first > WINDOW:
		var more: String = "➖ Nur die nächsten %d Stufen zeigen" % WINDOW if show_all else "➕ Alle Stufen zeigen (%d weitere)" % (rows - last)
		m.side_box.add_child(m._btn(more, func():
			show_all = not show_all
			m._refresh()))


## True when a goal of the running age is met but not yet counted (it counts at the turn of the year).
func _age_goal_ready(g, n, age: Dictionary) -> bool:
	for goal in age.goals:
		if not n.gov.ages.has(goal.id) and g.govt.goal_met(g, n, goal.cond):
			return true
	return false


## Popup with the age goals: the running age in full, past ones as results, later ones as a preview.
func _ages() -> void:
	var g = m.game
	var gv = g.govt
	var n = g.nations[g.player]
	var y: int = g.year()
	m._open_modal()
	var box: VBoxContainer = m.modal_box
	box.add_child(m._lbl("🏆 Zeitalter-Ziele", 26))
	box.add_child(m._lbl("Jedes Ziel zählt nur in seinem Zeitalter und gibt dauerhaft seinen Bonus. %d von 3 Zielen bringen zusätzlich den Triumph des Zeitalters. Geprüft wird zum Jahreswechsel." % int(gv.cfg.get("age_triumph_goals", 2)), 15, Color(0.72, 0.75, 0.82)))
	for age in gv.ages():
		var running: bool = y >= int(age.from) and y <= int(age.to)
		var past: bool = y > int(age.to)
		var head := "%s (%d–%d)" % [age.name, int(age.from), mini(int(age.to), int(g.bal.start_year) + 200)]
		if running:
			head = "▶ " + head
		box.add_child(m._lbl(head, 20, Color(1.0, 0.9, 0.6) if running else Color(0.75, 0.78, 0.85)))
		if not running and not past:
			box.add_child(m._lbl(", ".join(age.goals.map(func(x): return x.name)), 14, Color(0.6, 0.62, 0.68)))
			continue
		for goal in age.goals:
			var done: bool = n.gov.ages.has(goal.id)
			var p: Array = gv.goal_progress(g, n, goal.cond)
			var line := "%s %s: %s" % ["✅" if done else ("❌" if past else "·"), goal.name, goal.text]
			if running and not done:
				line += " (%d/%d)" % [mini(p[0], p[1]), p[1]]
			box.add_child(m._lbl(line, 15, Color(0.7, 0.95, 0.7) if done else Color(0.9, 0.9, 0.9)))
			if running or done:
				box.add_child(effects_rich(goal.reward, 14))
		var won: bool = n.gov.ages.has(age.id)
		var tl := "%s Triumph: %s" % ["✅" if won else ("❌" if past else "·"), age.triumph.name]
		box.add_child(m._lbl(tl, 16, Color(1.0, 0.85, 0.4) if won else Color(0.85, 0.85, 0.85)))
		if running or won:
			box.add_child(effects_rich(age.triumph.reward, 14))
	box.add_child(m._btn("Schließen", m._close_modal))


## Popup with the summed effects of all researched techs.
func _overview() -> void:
	var n = m.game.nations[m.game.player]
	m._open_modal()
	m.modal_box.add_child(m._lbl("📈 Gesamtwirkung deiner Technologien", 24))
	m.modal_box.add_child(effects_rich(n.bonus.get("tech", {}), 17))
	m.modal_box.add_child(m._lbl("Jede Stufe zählt außerdem: Verwaltung +4 % Einkommen, Diplomatie schnellerer AE-Abbau, Militär +6 % Kampfkraft und +½ Truppenlimit.", 15, Color(0.65, 0.68, 0.75)))
	m.modal_box.add_child(m._btn("Schließen", m._close_modal))


func _specials(g, me: String, lst: Array) -> void:
	if lst.is_empty():
		return
	m.side_box.add_child(m._lbl("⭐ Nationale Technologie", 17, Color(1.0, 0.85, 0.4)))
	var sg := GridContainer.new()
	sg.columns = 3
	sg.add_theme_constant_override("h_separation", 6)
	sg.add_theme_constant_override("v_separation", 6)
	for t in lst:
		sg.add_child(_cell(g, me, t, true))
	m.side_box.add_child(sg)


func _select(k: String) -> void:
	cat = k
	m._refresh()


func _cell(g, me: String, t: Dictionary, special: bool) -> Button:
	var n = g.nations[me]
	var reason: String = g.tree.block_reason(g, me, t.id)
	var done: bool = n.techs.has(t.id)
	var cost: float = g.tree.cost(g, me, t.id)
	var from: int = int(t.year) - g.tree.early_years - g.tree.ahead_years
	var ready: bool = reason == "" and n.get(t.cat) >= cost
	var foot := "✓ erforscht" if done else ("ab %d" % from if g.year() < from else "%d %s" % [cost, Icons.emoji(t.cat)])
	if not done and g.year() >= from and g.tree.years_ahead(g, t.id) > 0:
		foot = "▶ " + foot
	if not done and reason != "" and g.year() >= from:
		foot = "🔒 " + foot
	if g.tree.unlocks.has(t.id):
		foot += " 🏗"
	var qi: int = g.tree.queue_of(n, t.cat).find(t.id)
	if qi >= 0:
		foot = "📜%d %s" % [qi + 1, foot]
	var tip: String = "%s\n%s\n%s" % [t.name, Tech.effects_text(t.effects), "Erforscht" if done else (reason if reason != "" else "Kosten %d" % cost)]
	if g.tree.unlocks.has(t.id):
		tip += "\n🏗 " + unlock_text(g, t.id)
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
		where += " (regulär ab %d)" % (int(t.year) - g.tree.early_years)
	box.add_child(m._lbl(where, 16, Color(0.8, 0.82, 0.9)))
	if t.has("text"):
		box.add_child(m._lbl(t.text, 17, Color(0.85, 0.85, 0.75)))
	box.add_child(effects_rich(t.effects, 19))
	for k in t.effects:
		if Tech.DESCS.has(k):
			box.add_child(m._lbl("• %s: %s" % [Tech.LABELS[k][0], Tech.DESCS[k]], 14, Color(0.68, 0.7, 0.78)))
	if g.tree.unlocks.has(id):
		box.add_child(m._lbl("🏗 Schaltet frei: " + unlock_text(g, id), 17, Color(0.85, 0.9, 1.0)))
	for r in t.get("req", []):
		var ok: bool = n.techs.has(r)
		box.add_child(m._lbl(("✓ " if ok else "✗ ") + "Benötigt: " + g.tree.by_id[r].name, 16, Color(0.7, 0.9, 0.7) if ok else Color(0.95, 0.6, 0.55)))
	var reason: String = g.tree.block_reason(g, me, id)
	var cost: float = g.tree.cost(g, me, id)
	if n.techs.has(id):
		box.add_child(m._lbl("✓ Erforscht", 18, Color(0.7, 0.95, 0.7)))
	elif reason != "" and not reason.begins_with("Benötigt"):
		box.add_child(m._lbl(reason, 17, Color(0.95, 0.6, 0.55)))
	elif g.year() < int(t.year) - g.tree.early_years - g.tree.ahead_years:  # missing predecessor and still too early
		box.add_child(m._lbl("Verfügbar ab %d." % (int(t.year) - g.tree.early_years - g.tree.ahead_years), 17, Color(0.95, 0.6, 0.55)))
	else:
		box.add_child(m._lbl("Kosten: %d %s (du hast %d)" % [cost, Icons.emoji(t.cat), n.get(t.cat)], 18))
		var ya: int = g.tree.years_ahead(g, id)
		if ya > 0:
			box.add_child(m._lbl("Vor der Zeit: %d Jahre früh, +%d %% Kosten. Ohne Aufschlag ab %d." % [
					ya, roundi(g.tree.ahead_penalty * ya * 100.0), int(t.year) - g.tree.early_years], 15, Color(1.0, 0.75, 0.45)))
		var sd: float = g.tree.spread_discount(g, me, id)
		if sd >= 0.01:
			box.add_child(m._lbl("Davon −%d %% durch Wissensverbreitung: %d %% der anderen Nationen kennen sie schon." % [
					roundi(sd * 100.0), roundi(g.tree.known_share(g, me, id) * 100.0)], 15, Color(0.6, 0.9, 0.6)))
	var go := func():
		var err: String = g.research(me, id)
		m._close_modal()
		m._act(err, "🔬 %s erforscht!" % t.name)
	var research: Button = m._btn("🔬 Erforschen (%d)" % cost, go, "", reason != "" or n.get(t.cat) < cost)
	var row := [research]
	if not n.techs.has(id):
		var planned: bool = n.tech_queue.has(id)
		var toggle := func():
			if planned:
				g.tree.queue_remove(n, id)
			else:
				g.tree.queue_add(g, me, id)
			m._close_modal()
		row.append(m._btn("✖ Aus dem Plan" if planned else "📜 Vormerken", toggle,
				"Aus dem Forschungsplan nehmen (auch was darauf aufbaut)" if planned else
				"In den Forschungsplan: wird automatisch erforscht, sobald die Punkte reichen (fehlende Vorgänger kommen mit)"))
		if planned:
			box.add_child(m._lbl("📜 Im Forschungsplan: %s" % _wait_text(g, me, id), 15, Color(0.8, 0.85, 1.0)))
	row.append(m._btn("Schließen", m._close_modal))
	box.add_child(m._row(row))


func _wait_text(g, me: String, id: String) -> String:
	var n = g.nations[me]
	var lst: Array = g.tree.queue_of(n, g.tree.by_id[id].cat)
	var i: int = lst.find(id)
	if i > 0:
		return "Platz %d, nach %s" % [i + 1, g.tree.by_id[lst[i - 1]].name]
	var w: String = g.tree.queue_wait(g, me, id)
	return w if w != "" else "wird nächsten Monat erforscht"


## Popup with the research plan per category: order, why the first one waits, remove / move up.
func _plan() -> void:
	var g = m.game
	var me: String = g.player
	var n = g.nations[me]
	m._open_modal()
	var box: VBoxContainer = m.modal_box
	box.add_child(m._lbl("📜 Forschungsplan", 26))
	box.add_child(m._lbl("Vorgemerkte Technologien werden der Reihe nach erforscht, sobald die Punkte reichen. Frühe Technologien warten auf ihr reguläres Jahr, außer deine Punkte sind voll. Vormerken im Detailfenster einer Technologie.", 15, Color(0.72, 0.75, 0.82)))
	for k in g.POWERS:
		var lst: Array = g.tree.queue_of(n, k)
		box.add_child(m._lbl("%s%s" % [Icons.prefix(k), CAT_NAMES[k]], 19, Color(1.0, 0.9, 0.6)))
		if lst.is_empty():
			box.add_child(m._lbl("nichts vorgemerkt", 14, Color(0.6, 0.62, 0.68)))
			continue
		for i in lst.size():
			var id: String = lst[i]
			var l: Label = m._lbl("%d. %s · %s" % [i + 1, g.tree.by_id[id].name, _wait_text(g, me, id) if i == 0 else "%d %s" % [g.tree.cost(g, me, id), Icons.emoji(k)]], 15)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var up: Button = m._btn("👆", func():
				g.tree.queue_first(n, id)
				_plan(), "Nach vorne (hinter die eigenen Vorgänger)", i == 0)
			var rm: Button = m._btn("✖", func():
				g.tree.queue_remove(n, id)
				_plan(), "Entfernen (auch was darauf aufbaut)")
			box.add_child(m._row([l, up, rm]))
			for b in [up, rm]:  # after _row, which makes every button expand
				b.size_flags_horizontal = Control.SIZE_SHRINK_END
				b.custom_minimum_size.x = 72
	var clear: Button = m._btn("Plan leeren", func():
		n.tech_queue.clear()
		_plan(), "", n.tech_queue.is_empty())
	box.add_child(m._row([clear, m._btn("Schließen", m._close_modal)]))


## "Universität, Werkstatt Stufe 4": the buildings and building levels tech `id` unlocks.
static func unlock_text(g, id: String) -> String:
	var parts := []
	for u in g.tree.unlocks.get(id, []):
		var d: Dictionary = g.buildings_def[u[0]]
		parts.append("%s %s%s" % [d.get("emoji", "🏠"), d.name, "" if u[1] == 1 else " Stufe %d" % u[1]])
	return ", ".join(parts)


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
