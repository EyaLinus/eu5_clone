extends RefCounted
## Government (data/government.json), inspired by the Hearts of Iron politics screen:
## - political advisors (3 slots, hired with power of their type, national ones only in their lifetime)
## - investment companies (2 slots, +1 from tech; bought with gold, then invested into up to level 5:
##   every level raises the benefits by 50 %, the drawbacks stay as they are)
## - laws with buff/nerf trade-offs (changing one costs power and has a cooldown)
## State lives in `n.gov`; the summed effects go into n.bonus["gov"].
## `g` is the game (scripts/core/game.gd); untyped to avoid a cyclic preload.

const Tech = preload("res://scripts/core/tech.gd")

var cfg := {}
var advisors: Array = []
var adv_by_id := {}
var companies: Array = []
var comp_by_id := {}
var laws: Array = []
var law_by_id := {}
var forms := {}


func _init(d: Dictionary = {}) -> void:
	cfg = d
	forms = d.get("forms", {})
	for a in d.get("advisors", []):
		advisors.append(a)
		adv_by_id[a.id] = a
	for c in d.get("companies", []):
		companies.append(c)
		comp_by_id[c.id] = c
	for l in d.get("laws", []):
		laws.append(l)
		law_by_id[l.id] = l


func init_nation(n) -> void:
	var lw := {}
	for l in laws:
		lw[l.id] = l.options[0].id
	n.gov = {"advisors": [], "companies": [], "laws": lw, "law_month": {}, "invest": {}}
	refresh(n)


func form_name(tag: String) -> String:
	return forms.get(tag, forms.get("default", "Monarchie"))


# ---------------------------------------------------------------- advisors

func advisor_slots(g, n) -> int:
	return int(cfg.get("advisor_slots", 3)) + int(g.mod(n, "advisor_slots"))


func advisor_cost(_g, _n, _id: String) -> float:
	return float(cfg.get("advisor_cost", 75))


## Advisors `tag` could hire now (generic ones plus its own national figures alive in this year).
func advisor_pool(g, tag: String) -> Array:
	var r := []
	for a in advisors:
		if a.has("tag"):
			if a.tag != tag or g.year() < int(a.from) or g.year() > int(a.to):
				continue
		r.append(a)
	return r


func advisor_block(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	var a: Dictionary = adv_by_id.get(id, {})
	if a.is_empty():
		return "Unbekannter Berater."
	if n.gov.advisors.has(id):
		return "Bereits im Rat."
	if a.has("tag") and (a.tag != tag or g.year() < int(a.from) or g.year() > int(a.to)):
		return "Nicht verfügbar."
	if n.gov.advisors.size() >= advisor_slots(g, n):
		return "Alle Beraterplätze sind besetzt."
	var c := advisor_cost(g, n, id)
	if n.get(a.type) < c:
		return "Zu wenig Punkte (%d benötigt)." % c
	return ""


func hire(g, tag: String, id: String) -> String:
	var err := advisor_block(g, tag, id)
	if err != "":
		return err
	var n = g.nations[tag]
	var a: Dictionary = adv_by_id[id]
	n.set(a.type, n.get(a.type) - advisor_cost(g, n, id))
	n.gov.advisors.append(id)
	_changed(g, n)
	return ""


func dismiss(g, tag: String, id: String) -> void:
	var n = g.nations[tag]
	n.gov.advisors.erase(id)
	_changed(g, n)


# ---------------------------------------------------------------- companies

func company_slots(g, n) -> int:
	return int(cfg.get("company_slots", 2)) + int(g.mod(n, "company_slots"))


## Price in gold: some months of current income, so it scales with the realm.
func company_cost(_g, n, _id: String) -> float:
	return roundf(maxf(float(cfg.get("company_min_gold", 60)), float(cfg.get("company_months", 18)) * maxf(n.income, 0.0)))


func company_pool(g, tag: String) -> Array:
	var r := []
	for c in companies:
		if c.has("tag") and c.tag != tag:
			continue
		if g.year() < int(c.year):
			continue
		r.append(c)
	return r


func company_block(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	var c: Dictionary = comp_by_id.get(id, {})
	if c.is_empty():
		return "Unbekannte Kompanie."
	if n.gov.companies.has(id):
		return "Bereits gegründet."
	if c.has("tag") and c.tag != tag:
		return "Nicht verfügbar."
	if g.year() < int(c.year):
		return "Verfügbar ab %d." % int(c.year)
	if n.gov.companies.size() >= company_slots(g, n):
		return "Alle Kompanieplätze sind belegt."
	var cost := company_cost(g, n, id)
	if n.gold < cost:
		return "Zu wenig Gold (%d benötigt)." % cost
	return ""


func found_company(g, tag: String, id: String) -> String:
	var err := company_block(g, tag, id)
	if err != "":
		return err
	var n = g.nations[tag]
	n.gold -= company_cost(g, n, id)
	n.gov.companies.append(id)
	n.gov.invest[id] = 1
	_changed(g, n)
	return ""


func dissolve_company(g, tag: String, id: String) -> void:
	var n = g.nations[tag]
	n.gov.companies.erase(id)
	n.gov.invest.erase(id)
	_changed(g, n)


func max_invest() -> int:
	return int(cfg.get("invest_max_level", 5))


func invest_level(n, id: String) -> int:
	return int(n.gov.invest.get(id, 1))


## Effects of company `id` at investment `level`: benefits grow by invest_step per level, drawbacks do not.
func company_effects(id: String, level: int) -> Dictionary:
	var base: Dictionary = comp_by_id.get(id, {}).get("effects", {})
	var mult: float = 1.0 + float(cfg.get("invest_step", 0.5)) * (level - 1)
	var r := {}
	for k in base:
		var v := float(base[k])
		var good: bool = (v > 0.0) == Tech.LABELS.get(k, [k, false, true])[2]
		r[k] = v * mult if good else v
	return r


## Gold needed to raise company `id` from its current level to `to_level`.
func invest_cost(g, n, id: String, to_level: int) -> float:
	var c := 0.0
	for l in range(invest_level(n, id), to_level):
		c += company_cost(g, n, id) * float(cfg.get("invest_cost_mult", 0.5)) * l
	return roundf(c)


func invest_block(g, tag: String, id: String, to_level: int) -> String:
	var n = g.nations[tag]
	if not n.gov.companies.has(id):
		return "Kompanie nicht gegründet."
	if to_level <= invest_level(n, id):
		return "Wähle eine höhere Stufe."
	if to_level > max_invest():
		return "Höchststufe ist %d." % max_invest()
	var c := invest_cost(g, n, id, to_level)
	if n.gold < c:
		return "Zu wenig Gold (%d benötigt)." % c
	return ""


func invest(g, tag: String, id: String, to_level: int) -> String:
	var err := invest_block(g, tag, id, to_level)
	if err != "":
		return err
	var n = g.nations[tag]
	n.gold -= invest_cost(g, n, id, to_level)
	n.gov.invest[id] = to_level
	_changed(g, n)
	return ""


# ---------------------------------------------------------------- laws

func law_option(law_id: String, opt_id: String) -> Dictionary:
	for o in law_by_id[law_id].options:
		if o.id == opt_id:
			return o
	return {}


func law_cost(_g, _n, _law_id: String) -> float:
	return float(cfg.get("law_cost", 60))


func law_cooldown_left(g, n, law_id: String) -> int:
	if not n.gov.law_month.has(law_id):
		return 0
	return maxi(0, int(n.gov.law_month[law_id]) + int(cfg.get("law_cooldown_years", 10)) * 12 - g.month)


func law_block(g, tag: String, law_id: String, opt_id: String) -> String:
	var n = g.nations[tag]
	if not law_by_id.has(law_id):
		return "Unbekanntes Gesetz."
	var o := law_option(law_id, opt_id)
	if o.is_empty():
		return "Unbekannte Option."
	if n.gov.laws.get(law_id, "") == opt_id:
		return "Bereits in Kraft."
	if o.has("req") and not n.techs.has(o.req):
		return "Benötigt Technologie: %s." % g.tree.by_id[o.req].name
	var cd := law_cooldown_left(g, n, law_id)
	if cd > 0:
		return "Erst in %d Monaten wieder änderbar." % cd
	var kind: String = law_by_id[law_id].power
	var c := law_cost(g, n, law_id)
	if n.get(kind) < c:
		return "Zu wenig Punkte (%d benötigt)." % c
	return ""


func set_law(g, tag: String, law_id: String, opt_id: String) -> String:
	var err := law_block(g, tag, law_id, opt_id)
	if err != "":
		return err
	var n = g.nations[tag]
	var kind: String = law_by_id[law_id].power
	n.set(kind, n.get(kind) - law_cost(g, n, law_id))
	n.gov.laws[law_id] = opt_id
	n.gov.law_month[law_id] = g.month
	_changed(g, n)
	return ""


# ---------------------------------------------------------------- effects, ticks, save

func _changed(g, n) -> void:
	refresh(n)
	g._update_cached(n)


func refresh(n) -> void:
	var b := {}
	var effs := []
	for id in n.gov.advisors:
		effs.append(adv_by_id.get(id, {}).get("effects", {}))
	for id in n.gov.companies:
		effs.append(company_effects(id, invest_level(n, id)))
	for law_id in n.gov.laws:
		if law_by_id.has(law_id):
			effs.append(law_option(law_id, n.gov.laws[law_id]).get("effects", {}))
	for e in effs:
		for k in e:
			b[k] = b.get(k, 0.0) + float(e[k])
	n.bonus["gov"] = b


## Yearly: prestige drift from all sources, national advisors leave court after their time.
func yearly(g, n) -> void:
	var p: float = g.mod(n, "prestige")
	if p != 0.0:
		n.prestige = maxf(-50.0, n.prestige + p)
	for id in n.gov.advisors.duplicate():
		var a: Dictionary = adv_by_id.get(id, {})
		if a.has("to") and g.year() > int(a.to):
			n.gov.advisors.erase(id)
			g.log_msg("🎓 %s verlässt den Hof." % a.name, [n.tag])
			_changed(g, n)


func to_save(n) -> Dictionary:
	return n.gov


func load_save(n, d) -> void:
	init_nation(n)
	if d == null:
		return
	for id in d.get("advisors", []):
		if adv_by_id.has(id):
			n.gov.advisors.append(id)
	for id in d.get("companies", []):
		if comp_by_id.has(id):
			n.gov.companies.append(id)
			n.gov.invest[id] = clampi(int(d.get("invest", {}).get(id, 1)), 1, max_invest())
	var lw: Dictionary = d.get("laws", {})
	for law_id in lw:
		if law_by_id.has(law_id) and not law_option(law_id, lw[law_id]).is_empty():
			n.gov.laws[law_id] = lw[law_id]
	var lm: Dictionary = d.get("law_month", {})
	for law_id in lm:
		n.gov.law_month[law_id] = int(lm[law_id])
	refresh(n)


# ---------------------------------------------------------------- AI

## Called monthly for AI nations, before they spend power on tech and gold on troops.
func ai_think(g, n) -> void:
	var tag: String = n.tag
	var slot: int = (g.month + n.capital * 7) % 12
	if slot == 1:
		_ai_laws(g, n)
	elif slot == 5 or slot == 9:
		_ai_advisor(g, n)
	elif slot == 7 and not g.is_at_war(tag):
		_ai_company(g, n)


func _ai_laws(g, n) -> void:
	for l in laws:
		var cur: Dictionary = law_option(l.id, n.gov.laws[l.id])
		var best := ""
		var best_v: float = Tech.effect_value(cur.effects, n.aggression) + 1.5
		for o in l.options:
			if law_block(g, n.tag, l.id, o.id) != "":
				continue
			var v: float = Tech.effect_value(o.effects, n.aggression)
			if v > best_v:
				best_v = v
				best = o.id
		# keep a tech's worth of power in reserve
		if best != "" and n.get(l.power) >= law_cost(g, n, l.id) + g.tech_cost(n.tag, l.power) * 0.5:
			set_law(g, n.tag, l.id, best)
			return


func _ai_advisor(g, n) -> void:
	var full: bool = n.gov.advisors.size() >= advisor_slots(g, n)
	var best := ""
	var best_v := 0.0
	for a in advisor_pool(g, n.tag):
		if n.gov.advisors.has(a.id):
			continue
		var v: float = Tech.effect_value(a.effects, n.aggression) + (3.0 if a.has("tag") else 0.0)
		if v > best_v and n.get(a.type) >= advisor_cost(g, n, a.id):
			best_v = v
			best = a.id
	if best == "":
		return
	if full:
		# replace the weakest advisor only for a clearly better (usually national) one
		var worst := ""
		var worst_v := 1e9
		for id in n.gov.advisors:
			var v: float = Tech.effect_value(adv_by_id[id].effects, n.aggression)
			if v < worst_v:
				worst_v = v
				worst = id
		if worst == "" or best_v < worst_v + 4.0:
			return
		dismiss(g, n.tag, worst)
	hire(g, n.tag, best)


func _ai_company(g, n) -> void:
	if n.gov.companies.size() >= company_slots(g, n):
		_ai_invest(g, n)
		return
	var best := ""
	var best_v := 0.0
	for c in company_pool(g, n.tag):
		if n.gov.companies.has(c.id):
			continue
		var v: float = Tech.effect_value(c.effects, n.aggression) + (3.0 if c.has("tag") else 0.0)
		if v > best_v:
			best_v = v
			best = c.id
	if best == "":
		return
	var reserve: float = 10.0 + n.expenses * 4.0 + 40.0
	if n.gold >= company_cost(g, n, best) + reserve:
		found_company(g, n.tag, best)


## Rich AI states put surplus gold into their companies (one level at a time, the cheapest first).
func _ai_invest(g, n) -> void:
	var reserve: float = 10.0 + n.expenses * 4.0 + 150.0
	var best := ""
	var best_c := 1e18
	for id in n.gov.companies:
		var l := invest_level(n, id)
		if l >= max_invest():
			continue
		var c := invest_cost(g, n, id, l + 1)
		if c < best_c:
			best_c = c
			best = id
	if best != "" and n.gold >= best_c + reserve:
		invest(g, n.tag, best, invest_level(n, best) + 1)
