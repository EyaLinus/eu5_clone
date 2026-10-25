extends RefCounted
## Government screen in the side panel (inspired by the Hearts of Iron politics view):
## ruler and form of government, political advisors, investment companies and laws.
## Picking a new advisor, company or law opens a list popup with costs and buff/nerf effects.
## `m` is the main UI (scripts/ui/main.gd).

const Tech = preload("res://scripts/core/tech.gd")
const TechScreen = preload("res://scripts/ui/tech_screen.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const POWER_NAMES := {"adm": "Verwaltung", "dip": "Diplomatie", "mil": "Militär"}
const CARD := Color("1f2735")
const CARD_NATIONAL := Color("33291a")

var m


func _init(main) -> void:
	m = main


## True when a free advisor or company slot can be filled right now (tab badge).
func can_act(g, tag: String) -> bool:
	var gv = g.govt
	var n = g.nations[tag]
	if n.gov.advisors.size() < gv.advisor_slots(g, n):
		for a in gv.advisor_pool(g, tag):
			if gv.advisor_block(g, tag, a.id) == "":
				return true
	if n.gov.companies.size() < gv.company_slots(g, n):
		for c in gv.company_pool(g, tag):
			if gv.company_block(g, tag, c.id) == "":
				return true
	return false


func build() -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	m.side_title.text = "⚖️ Regierung"
	var head: String = "%s · %s" % [m.nname(me), gv.form_name(me)]
	m.side_box.add_child(m._lbl(head, 20))
	var ruler: String = n.ruler_name if n.ruler_name != "" else "Herrscher"
	m.side_box.add_child(m._lbl("👑 %s  📜%d 🕊️%d ⚔️%d · noch ca. %d Jahre" % [ruler, n.ruler.adm, n.ruler.dip, n.ruler.mil, n.ruler.years], 16))
	if n.idea != "":
		m.side_box.add_child(m._lbl("Nationalgeist: " + n.idea, 15, Color(0.8, 0.85, 0.7)))

	m.side_box.add_child(m._lbl("🎓 Politische Berater (%d/%d)" % [n.gov.advisors.size(), gv.advisor_slots(g, n)], 22))
	for id in n.gov.advisors:
		var a: Dictionary = gv.adv_by_id[id]
		var sub: String = Icons.emoji(a.type) + " " + ("Historische Persönlichkeit, bis %d" % int(a.to) if a.has("to") else "Berater")
		m.side_box.add_child(_card(a.name, sub, a.effects, a.has("tag"), "Entlassen", func():
			gv.dismiss(g, me, id)
			m._act("", "🎓 %s entlassen" % a.name)))
	for i in gv.advisor_slots(g, n) - n.gov.advisors.size():
		m.side_box.add_child(m._btn("➕ Berater ernennen (%d Punkte)" % gv.advisor_cost(g, n, ""), _pick_advisor))

	m.side_box.add_child(m._lbl("🏦 Investitionskompanien (%d/%d)" % [n.gov.companies.size(), gv.company_slots(g, n)], 22))
	for id in n.gov.companies:
		var c: Dictionary = gv.comp_by_id[id]
		var lvl: int = gv.invest_level(n, id)
		m.side_box.add_child(_card(c.name, "Investitionsstufe %d von %d" % [lvl, gv.max_invest()], gv.company_effects(id, lvl),
				c.has("tag"), "Investieren", _invest.bind(id)))
	for i in gv.company_slots(g, n) - n.gov.companies.size():
		m.side_box.add_child(m._btn("➕ Kompanie gründen (%d %s)" % [gv.company_cost(g, n, ""), Icons.emoji("gold")], _pick_company))
	if gv.company_slots(g, n) < 3:
		m.side_box.add_child(m._lbl("Ein dritter Platz kommt mit der Technologie Aktiengesellschaften.", 14, Color(0.65, 0.68, 0.75)))

	m.side_box.add_child(m._lbl("📜 Gesetze", 22))
	for l in gv.laws:
		var o: Dictionary = gv.law_option(l.id, n.gov.laws[l.id])
		var cd: int = gv.law_cooldown_left(g, n, l.id)
		var sub: String = l.name + (" · änderbar in %d Monaten" % cd if cd > 0 else "")
		m.side_box.add_child(_card(o.name, sub, o.effects, false, "Ändern", _pick_law.bind(l.id)))

	m.side_box.add_child(m._lbl("Gesamtwirkung der Regierung", 18))
	m.side_box.add_child(TechScreen.effects_rich(n.bonus.get("gov", {}), 15))


func _card(title: String, sub: String, eff: Dictionary, national: bool, action: String, cb: Callable) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_NATIONAL if national else CARD
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	if national:
		sb.border_color = Color(1.0, 0.8, 0.35)
		sb.set_border_width_all(1)
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(m._lbl(("⭐ " if national else "") + title, 18))
	if sub != "":
		v.add_child(m._lbl(sub, 14, Color(0.72, 0.75, 0.82)))
	v.add_child(TechScreen.effects_rich(eff, 15))
	var b: Button = m._btn(action, cb)
	b.clip_text = false
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 15)
	h.add_child(b)
	return pc


func _choice(title: String, sub: String, eff: Dictionary, national: bool, label: String, err: String, cb: Callable) -> Control:
	var card := _card(title, sub, eff, national, label, cb)
	var b: Button = card.get_child(0).get_child(1)
	b.disabled = err != ""
	if err != "":
		card.get_child(0).get_child(0).add_child(m._lbl(err, 14, Color(0.95, 0.6, 0.55)))
	return card


func _pick_advisor() -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	m._open_modal()
	m.modal_box.add_child(m._lbl("🎓 Berater ernennen", 26))
	m.modal_box.add_child(m._lbl("Kosten: %d Punkte der jeweiligen Art. Historische Persönlichkeiten dienen nur zu ihren Lebzeiten." % gv.advisor_cost(g, n, ""), 16))
	var pool: Array = gv.advisor_pool(g, me).duplicate()
	pool.sort_custom(func(x, y): return x.has("tag") and not y.has("tag"))
	for a in pool:
		if n.gov.advisors.has(a.id):
			continue
		var sub: String = "%s %d %s" % [Icons.emoji(a.type), gv.advisor_cost(g, n, a.id), POWER_NAMES[a.type]] + (" · lebt bis %d" % int(a.to) if a.has("to") else "")
		m.modal_box.add_child(_choice(a.name, sub, a.effects, a.has("tag"), "Ernennen", gv.advisor_block(g, me, a.id), func():
			var err: String = gv.hire(g, me, a.id)
			m._close_modal()
			m._act(err, "🎓 %s tritt in den Rat ein" % a.name)))
	m.modal_box.add_child(m._btn("Schließen", m._close_modal))


func _pick_company() -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	m._open_modal()
	m.modal_box.add_child(m._lbl("🏦 Kompanie gründen", 26))
	m.modal_box.add_child(m._lbl("Kosten: %d %s (etwa %d Monatseinkommen). Kompanien bleiben, bis du sie auflöst." % [
			gv.company_cost(g, n, ""), Icons.emoji("gold"), int(gv.cfg.get("company_months", 18))], 16))
	var pool: Array = gv.company_pool(g, me).duplicate()
	pool.sort_custom(func(x, y): return x.has("tag") and not y.has("tag"))
	for c in pool:
		if n.gov.companies.has(c.id):
			continue
		m.modal_box.add_child(_choice(c.name, c.get("text", ""), c.effects, c.has("tag"), "Gründen", gv.company_block(g, me, c.id), func():
			var err: String = gv.found_company(g, me, c.id)
			m._close_modal()
			m._act(err, "🏦 %s gegründet" % c.name)))
	m.modal_box.add_child(m._btn("Schließen", m._close_modal))


func _pick_law(law_id: String) -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	var l: Dictionary = gv.law_by_id[law_id]
	m._open_modal()
	m.modal_box.add_child(m._lbl("📜 " + l.name, 26))
	m.modal_box.add_child(m._lbl("Ein Wechsel kostet %d %s und ist danach %d Jahre gesperrt." % [
			gv.law_cost(g, n, law_id), Icons.emoji(l.power), int(gv.cfg.get("law_cooldown_years", 10))], 16))
	for o in l.options:
		var current: bool = n.gov.laws[law_id] == o.id
		var sub: String = o.get("text", "")
		if o.has("req"):
			sub += " (benötigt %s)" % g.tree.by_id[o.req].name
		var err: String = "" if current else gv.law_block(g, me, law_id, o.id)
		var card := _choice(o.name, sub, o.effects, false, "In Kraft" if current else "Einführen", err, func():
			var e: String = gv.set_law(g, me, law_id, o.id)
			m._close_modal()
			m._act(e, "📜 %s: %s" % [l.name, o.name]))
		if current:
			card.get_child(0).get_child(1).disabled = true
		m.modal_box.add_child(card)
	m.modal_box.add_child(m._btn("Schließen", m._close_modal))


## Investment popup: a slider picks the target level, the preview shows effects and price live.
func _invest(id: String) -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	var c: Dictionary = gv.comp_by_id[id]
	var cur: int = gv.invest_level(n, id)
	m._open_modal()
	var box: VBoxContainer = m.modal_box
	box.add_child(m._lbl("🏦 " + c.name, 26))
	box.add_child(m._lbl(c.get("text", ""), 16, Color(0.85, 0.85, 0.75)))
	box.add_child(m._lbl("Jede Stufe steigert die Vorteile um %d %%, die Nachteile bleiben gleich. Auflösen gibt kein Gold zurück." % roundi(float(gv.cfg.get("invest_step", 0.5)) * 100.0), 15, Color(0.72, 0.75, 0.82)))
	var preview := VBoxContainer.new()
	var go: Button
	if cur < gv.max_invest():
		var slider := HSlider.new()
		slider.min_value = cur
		slider.max_value = gv.max_invest()
		slider.step = 1
		slider.value = cur + 1
		slider.tick_count = gv.max_invest() - cur + 1
		slider.ticks_on_borders = true
		slider.custom_minimum_size = Vector2(0, 56 if m._big() else 44)
		slider.focus_mode = Control.FOCUS_NONE
		box.add_child(slider)
		box.add_child(preview)
		go = m._btn("", func():
			var err: String = gv.invest(g, me, id, int(slider.value))
			m._close_modal()
			m._act(err, "🏦 %s auf Stufe %d ausgebaut" % [c.name, int(slider.value)]))
		var upd := func(v: float) -> void:
			_invest_preview(preview, go, id, cur, int(v))
		slider.value_changed.connect(upd)
		upd.call(slider.value)
	else:
		box.add_child(m._lbl("Höchste Stufe erreicht.", 18, Color(0.7, 0.95, 0.7)))
		box.add_child(TechScreen.effects_rich(gv.company_effects(id, cur), 18))
	var dissolve: Button = m._btn("Auflösen", func():
		gv.dissolve_company(g, me, id)
		m._close_modal()
		m._act("", "🏦 %s aufgelöst" % c.name))
	var row := [dissolve, m._btn("Schließen", m._close_modal)]
	if go != null:
		row.push_front(go)
	box.add_child(m._row(row))


func _invest_preview(preview: VBoxContainer, go: Button, id: String, cur: int, to: int) -> void:
	var g = m.game
	var gv = g.govt
	var n = g.nations[g.player]
	m._clear(preview)
	preview.add_child(m._lbl("Stufe %d → %d" % [cur, to], 20))
	preview.add_child(TechScreen.effects_rich(gv.company_effects(id, to), 18))
	var err: String = gv.invest_block(g, g.player, id, to)
	var cost: float = gv.invest_cost(g, n, id, to)
	go.text = "Investieren (%d %s)" % [cost, Icons.emoji("gold")]
	go.disabled = err != ""
	if err != "":
		preview.add_child(m._lbl(err, 15, Color(0.95, 0.6, 0.55)))
