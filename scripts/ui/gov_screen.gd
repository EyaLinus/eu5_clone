extends RefCounted
## Government screen in the side panel (inspired by the Hearts of Iron politics view):
## ruler and form of government on top, then four sub-tabs (budget, court = advisors and companies,
## law = laws and state reforms, estates) so no tab needs much scrolling; 📈 shows the summed effects.
## Picking a new advisor, company or law opens a list popup with costs and buff/nerf effects.
## `m` is the main UI (scripts/ui/main.gd).

const Tech = preload("res://scripts/core/tech.gd")
const TechScreen = preload("res://scripts/ui/tech_screen.gd")
const Icons = preload("res://scripts/ui/icons.gd")

const POWER_NAMES := {"adm": "Verwaltung", "dip": "Diplomatie", "mil": "Militär"}
## Sub-tabs, so no section needs a long scroll: [id, button text].
const TABS := [["haushalt", "💰 Haushalt"], ["hof", "🎓 Hof"], ["recht", "📜 Recht"], ["staende", "👥 Stände"]]

var m
var tab := "haushalt"


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
	for tier in gv.open_reform_tiers(g, n):
		if n.adm >= gv.reform_cost(g, n, tier):
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
	var ruler: String = n.ruler_name if n.ruler_name != "" else "Herrscher"
	var head: Label = m._lbl("%s · %s\n👑 %s  📜%d 🕊️%d ⚔️%d · noch ca. %d Jahre" % [m.nname(me), gv.form_name(me), ruler,
			n.ruler.adm, n.ruler.dip, n.ruler.mil, n.ruler.years], 16)
	if n.idea != "":
		head.tooltip_text = "Nationalgeist: " + n.idea
		head.mouse_filter = Control.MOUSE_FILTER_STOP
	var sum: Button = m._btn("📈 Gesamt", _overview, "Gesamtwirkung von Regierung, Haushalt, Ständen und Reich")
	sum.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.side_box.add_child(m._row([head, sum]))
	sum.size_flags_horizontal = Control.SIZE_SHRINK_END
	sum.clip_text = false
	sum.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	sum.add_theme_font_size_override("font_size", 15)
	var fe: Dictionary = gv.form_effects(me)
	if not fe.is_empty():
		var fl: Control = TechScreen.effects_rich(fe, 14)
		fl.tooltip_text = "Wirkung der Staatsform %s (dauerhaft)" % gv.form_name(me)
		fl.mouse_filter = Control.MOUSE_FILTER_STOP
		m.side_box.add_child(fl)
	var tabs := []
	for t in TABS:
		var b: Button = m._btn(t[1], _select.bind(t[0]))
		b.clip_text = false
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.add_theme_font_size_override("font_size", 14)
		if t[0] == tab:
			b.add_theme_stylebox_override("normal", UiTheme.box("button_pressed", 10))
		if _tab_has_action(g, n, t[0]):
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		tabs.append(b)
	m.side_box.add_child(m._row(tabs))
	match tab:
		"haushalt":
			_build_budget(g, gv, n)
		"hof":
			_build_court(g, gv, me, n)
		"recht":
			_build_law(g, gv, n)
		_:
			_build_estates(gv)


func _select(t: String) -> void:
	tab = t
	m._refresh()


## Gold text on a tab: something there can be done now (free slot, open reform) or needs care (angry estate).
func _tab_has_action(g, n, t: String) -> bool:
	var gv = g.govt
	match t:
		"hof":
			if n.gov.advisors.size() < gv.advisor_slots(g, n):
				for a in gv.advisor_pool(g, n.tag):
					if gv.advisor_block(g, n.tag, a.id) == "":
						return true
			if n.gov.companies.size() < gv.company_slots(g, n):
				for c in gv.company_pool(g, n.tag):
					if gv.company_block(g, n.tag, c.id) == "":
						return true
		"recht":
			for tier in gv.open_reform_tiers(g, n):
				if n.adm >= gv.reform_cost(g, n, tier):
					return true
		"staende":
			for e in gv.estates:
				if gv.estate_tier(n, e.id) == "angry":
					return true
	return false


func _section(text: String, tip: String = "") -> void:
	var l: Label = m._lbl(text, 20)
	if tip != "":
		l.tooltip_text = tip
		l.mouse_filter = Control.MOUSE_FILTER_STOP
	m.side_box.add_child(l)


func _build_budget(g, gv, n) -> void:
	m.side_box.add_child(m._lbl("Die Mitte ist neutral. Jede Stufe darüber oder darunter bringt Vor- und Nachteile, Hof und Forschung kosten oder sparen Gold. Änderungen wirken sofort.", 14, Color(0.65, 0.68, 0.75)))
	for b in gv.budget:
		m.side_box.add_child(_budget_card(b))
	var c: float = gv.budget_cost(g, n)
	m.side_box.add_child(m._lbl("Haushalt gesamt: %s %+.2f Gold pro Monat" % [Icons.emoji("gold"), -c], 15,
			Color(0.95, 0.6, 0.55) if c > 0.0 else Color(0.6, 0.9, 0.6)))


func _build_court(g, gv, me: String, n) -> void:
	_section("🎓 Berater (%d/%d)" % [n.gov.advisors.size(), gv.advisor_slots(g, n)],
			"Kosten %d Punkte der jeweiligen Art. Historische Persönlichkeiten dienen nur zu ihren Lebzeiten." % gv.advisor_cost(g, n, ""))
	for id in n.gov.advisors:
		var a: Dictionary = gv.adv_by_id[id]
		var lvl: int = gv.advisor_skill(n, id)
		var sub: String = "%s Stufe %d · %s" % [Icons.emoji(a.type), lvl, "historisch, bis %d" % int(a.to) if a.has("to") else "seit %d Jahren" % gv.service_years(g, n, id)]
		var card := _card(a.name, sub, gv.advisor_effects(id, lvl), a.has("tag"), "Fördern", _advisor.bind(id))
		if gv.promote_block(g, me, id) == "":
			card.get_child(0).get_child(1).add_theme_color_override("font_color", UiTheme.GOLD)
		m.side_box.add_child(card)
	var free: int = gv.advisor_slots(g, n) - n.gov.advisors.size()
	if free > 0:
		m.side_box.add_child(m._btn("➕ Berater ernennen (%d frei, %d Punkte)" % [free, gv.advisor_cost(g, n, "")], _pick_advisor))
	_section("🏦 Kompanien (%d/%d)" % [n.gov.companies.size(), gv.company_slots(g, n)],
			"Mit Gold gegründet, danach bis Stufe %d ausbaubar. Ein dritter Platz kommt mit der Technologie Aktiengesellschaften." % gv.max_invest())
	for id in n.gov.companies:
		var c: Dictionary = gv.comp_by_id[id]
		var lvl: int = gv.invest_level(n, id)
		m.side_box.add_child(_card(c.name, "Stufe %d von %d" % [lvl, gv.max_invest()], gv.company_effects(id, lvl),
				c.has("tag"), "Investieren", _invest.bind(id)))
	var cfree: int = gv.company_slots(g, n) - n.gov.companies.size()
	if cfree > 0:
		m.side_box.add_child(m._btn("➕ Kompanie gründen (%d frei, %d %s)" % [cfree, gv.company_cost(g, n, ""), Icons.emoji("gold")], _pick_company))


func _build_law(g, gv, n) -> void:
	_section("📜 Gesetze", "Ein Wechsel kostet Punkte und ist danach %d Jahre gesperrt." % int(gv.cfg.get("law_cooldown_years", 10)))
	for l in gv.laws:
		var o: Dictionary = gv.law_option(l.id, n.gov.laws[l.id])
		var cd: int = gv.law_cooldown_left(g, n, l.id)
		var sub: String = l.name + (" · änderbar in " + _wait(cd) if cd > 0 else _alternatives(l.options.filter(
				func(x): return x.id != o.id and gv.law_block(g, n.tag, l.id, x.id) == "").size()))
		m.side_box.add_child(_card(o.name, sub, o.effects, false, "Ändern", _pick_law.bind(l.id), true))
	_section("🏛️ Staatsreformen", "Dauerhafte Reformen in vier Stufen, jede ab einem bestimmten Jahr. Pro Stufe gilt eine Reform, bezahlt mit Verwaltungspunkten. Ein späterer Wechsel kostet erneut und ist nur alle %d Jahre möglich." % int(gv.cfg.get("reform_change_years", 25)))
	var locked := []
	for t in gv.reforms:
		if n.gov.reforms.has(t.id):
			var o: Dictionary = gv.reform_option(t.id, n.gov.reforms[t.id])
			var cd: int = gv.reform_cooldown_left(g, n, t.id)
			var sub: String = t.name + (" · änderbar in " + _wait(cd) if cd > 0 else "")
			m.side_box.add_child(_card(o.name, sub, o.effects, false, "Ändern", _pick_reform.bind(t.id), true))
		elif g.year() >= int(t.year):
			m.side_box.add_child(m._btn("➕ %s: Reform wählen (%d %s)" % [t.name, gv.reform_cost(g, n, t.id), Icons.emoji("adm")], _pick_reform.bind(t.id)))
		else:
			locked.append("%s ab %d" % [t.name, int(t.year)])
	if not locked.is_empty():
		m.side_box.add_child(m._lbl("🔒 " + ", ".join(locked), 14, Color(0.65, 0.68, 0.75)))


func _build_estates(gv) -> void:
	var est_tip := "Die Zufriedenheit wandert langsam zum Zielwert (50 plus Wirkung von Gesetzen, Beratern, Kompanien und Technologien). Ab %d ist ein Stand treu und gibt Boni, unter %d ist er zornig und schadet, unter %d drohen Forderungen." % [
			int(gv.cfg.get("estate_loyal", 60)), int(gv.cfg.get("estate_angry", 30)), int(gv.cfg.get("estate_crisis", 25))]
	m.side_box.add_child(m._lbl("Gesetze, Berater und Kompanien verschieben den Zielwert. Langes Drücken erklärt mehr.", 14, Color(0.65, 0.68, 0.75)))
	for e in gv.estates:
		m.side_box.add_child(_estate_card(e, est_tip))


## Popup with everything the government side adds up to, split by source.
func _overview() -> void:
	var g = m.game
	var n = g.nations[g.player]
	m._open_modal()
	m.modal_box.add_child(m._lbl("📈 Gesamtwirkung", 26))
	for src in [["gov", "⚖️ Berater, Kompanien, Gesetze, Reformen"], ["budget", "💰 Haushalt"], ["estates", "👥 Stände"], ["empire", "👑 Reichsreformen"]]:
		var e: Dictionary = n.bonus.get(src[0], {})
		if e.is_empty() and src[0] != "gov":
			continue
		m.modal_box.add_child(m._lbl(src[1], 18))
		m.modal_box.add_child(TechScreen.effects_rich(e, 16))
	m.modal_box.add_child(m._btn("Schließen", m._close_modal))


## Cooldown as "8 Monaten" or, from two years on, "10 Jahren".
func _wait(months: int) -> String:
	return "%d Jahren" % ceili(months / 12.0) if months >= 24 else "%d Monaten" % months


## " · n weitere möglich" for a law card, so open choices show without opening the popup.
func _alternatives(k: int) -> String:
	return " · %d weitere möglich" % k if k > 0 else ""


## `compact`: smaller title and button, for the long law and reform lists.
func _card(title: String, sub: String, eff: Dictionary, national: bool, action: String, cb: Callable, compact: bool = false) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.card("gold" if national else ""))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(m._lbl(("⭐ " if national else "") + title, 16 if compact else 18))
	if sub != "":
		v.add_child(m._lbl(sub, 13 if compact else 14, Color(0.72, 0.75, 0.82)))
	# a default option without effects needs no "keine Wirkung" line
	if not eff.is_empty():
		v.add_child(TechScreen.effects_rich(eff, 15))
	var b: Button = m._btn(action, cb)
	b.clip_text = false
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 15)
	if compact:
		b.custom_minimum_size.y = 40
	h.add_child(b)
	return pc


func _choice(title: String, sub: String, eff: Dictionary, national: bool, label: String, err: String, cb: Callable) -> Control:
	var card := _card(title, sub, eff, national, label, cb)
	var b: Button = card.get_child(0).get_child(1)
	b.disabled = err != ""
	if err != "":
		card.get_child(0).get_child(0).add_child(m._lbl(err, 14, Color(0.95, 0.6, 0.55)))
	return card


## Advisor popup: current and next skill level, promote and dismiss.
func _advisor(id: String) -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	var a: Dictionary = gv.adv_by_id[id]
	var lvl: int = gv.advisor_skill(n, id)
	m._open_modal()
	var box: VBoxContainer = m.modal_box
	box.add_child(m._lbl("🎓 " + a.name, 26))
	var life: String = "Historische Persönlichkeit, dient bis %d." % int(a.to) if a.has("to") else \
			"Dient seit %d Jahren. Ab %d Dienstjahren kann er in den Ruhestand gehen; ein Schüler übernimmt dann eine Stufe tiefer." % [gv.service_years(g, n, id), int(gv.cfg.get("advisor_retire_years", 20))]
	box.add_child(m._lbl(life, 15, Color(0.72, 0.75, 0.82)))
	box.add_child(m._lbl("Stufe %d von %d" % [lvl, gv.max_skill()], 20))
	box.add_child(TechScreen.effects_rich(gv.advisor_effects(id, lvl), 18))
	var go: Button
	var err := ""
	if lvl < gv.max_skill():
		box.add_child(m._lbl("Stufe %d für %d %s: Vorteile +%d %%, Nachteile bleiben" % [lvl + 1, gv.promote_cost(g, n, id), Icons.emoji(a.type), roundi(float(gv.cfg.get("advisor_skill_step", 0.5)) * 100.0)], 20))
		box.add_child(TechScreen.effects_rich(gv.advisor_effects(id, lvl + 1), 18))
		err = gv.promote_block(g, me, id)
		go = m._btn("⭐ Fördern", func():
			var e: String = gv.promote(g, me, id)
			m._close_modal()
			m._act(e, "⭐ %s auf Stufe %d gefördert" % [a.name, lvl + 1]))
		go.disabled = err != ""
	if err != "":
		box.add_child(m._lbl(err, 14, Color(0.95, 0.6, 0.55)))
	var row := [m._btn("Entlassen", func():
		gv.dismiss(g, me, id)
		m._close_modal()
		m._act("", "🎓 %s entlassen" % a.name)), m._btn("Schließen", m._close_modal)]
	if go != null:
		row.push_front(go)
	box.add_child(m._row(row))


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


func _pick_reform(tier: String) -> void:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	var t: Dictionary = gv.reform_by_id[tier]
	m._open_modal()
	m.modal_box.add_child(m._lbl("🏛️ " + t.name, 26))
	m.modal_box.add_child(m._lbl("Kostet %d %s. Ein späterer Wechsel kostet erneut und ist nur alle %d Jahre möglich." % [
			gv.reform_cost(g, n, tier), Icons.emoji("adm"), int(gv.cfg.get("reform_change_years", 25))], 16))
	for o in t.options:
		var current: bool = n.gov.reforms.get(tier, "") == o.id
		var err: String = "" if current else gv.reform_block(g, me, tier, o.id)
		var card := _choice(o.name, o.get("text", ""), o.effects, false, "Eingeführt" if current else "Einführen", err, func():
			var e: String = gv.enact_reform(g, me, tier, o.id)
			m._close_modal()
			m._act(e, "🏛️ %s: %s" % [t.name, o.name]))
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


## One budget slider: name, current step, live effects and monthly gold. Changes apply at once; the card
## updates itself in place so the slider is not rebuilt while it is dragged.
func _budget_card(b: Dictionary) -> Control:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.card(""))
	pc.tooltip_text = b.get("text", "")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	var title: Label = m._lbl("", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gold: Label = m._lbl("", 15)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var top := HBoxContainer.new()
	top.add_child(title)
	top.add_child(gold)
	v.add_child(top)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = gv.budget_max()
	slider.step = 1
	slider.tick_count = gv.budget_max() + 1
	slider.ticks_on_borders = true
	slider.value = gv.budget_step(g.nations[me], b.id)
	slider.custom_minimum_size = Vector2(0, 44 if m._big() else 30)
	slider.focus_mode = Control.FOCUS_NONE
	v.add_child(slider)
	var info := VBoxContainer.new()
	v.add_child(info)
	var upd := func(val: float) -> void:
		var step := int(val)
		var n = g.nations[me]
		if step != gv.budget_step(n, b.id):
			gv.set_budget(g, me, b.id, step)
		var eff: Dictionary = gv.budget_effects(b.id, step)
		var cost: float = gv.budget_slider_cost(n, b.id, step)
		title.text = "%s: %s" % [b.name, b.steps[step]]
		gold.text = "%s %+.2f/Monat" % [Icons.emoji("gold"), -cost] if absf(cost) >= 0.01 else ""
		gold.add_theme_color_override("font_color", Color(0.95, 0.6, 0.55) if cost > 0.0 else Color(0.6, 0.9, 0.6))
		m._clear(info)
		info.visible = not eff.is_empty()
		if not eff.is_empty():
			info.add_child(TechScreen.effects_rich(eff, 15))
	slider.value_changed.connect(upd)
	upd.call(slider.value)
	return pc


func _estate_card(e: Dictionary, tip: String) -> Control:
	var g = m.game
	var gv = g.govt
	var me: String = g.player
	var n = g.nations[me]
	var v: float = n.gov.estates[e.id]
	var target: float = gv.estate_target(g, n, e.id)
	var tier: String = gv.estate_tier(n, e.id)
	var tier_name: String = {"loyal": "treu", "neutral": "ruhig", "angry": "zornig"}[tier]
	var col: Color = {"loyal": Color(0.55, 0.85, 0.55), "neutral": Color(0.85, 0.8, 0.55), "angry": Color(0.95, 0.5, 0.45)}[tier]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.card({"loyal": "good", "angry": "bad"}.get(tier, "")))
	pc.tooltip_text = "%s: %s\n%s" % [e.name, e.text, tip]
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	pc.add_child(vb)
	var trend: String = "steigt auf" if target > v + 1.0 else ("sinkt auf" if target < v - 1.0 else "bleibt bei")
	vb.add_child(m._lbl("%s · %s" % [e.name, tier_name], 18, col))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = v
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(col))
	vb.add_child(bar)
	vb.add_child(m._lbl("Zufriedenheit %d, %s %d" % [roundi(v), trend, roundi(target)], 14, Color(0.75, 0.78, 0.85)))
	var cur: Dictionary = e.get(tier, {}) if tier != "neutral" else {}
	if not cur.is_empty():
		vb.add_child(TechScreen.effects_rich(cur, 14))
	else:
		vb.add_child(m._lbl("Treu: %s\nZornig: %s" % [Tech.effects_text(e.loyal), Tech.effects_text(e.angry)], 13, Color(0.65, 0.68, 0.75)))
	var err: String = gv.concession_block(g, me, e.id)
	var b: Button = m._btn("Zugeständnis: +%d (%d %s)" % [int(gv.cfg.get("concession_amount", 20)), gv.concession_cost(g, n), Icons.emoji("gold")],
			func(): m._act(gv.grant_concession(g, me, e.id), "⚖️ Der Stand %s ist besänftigt" % e.name), err, err != "")
	b.add_theme_font_size_override("font_size", 15)
	vb.add_child(b)
	return pc
