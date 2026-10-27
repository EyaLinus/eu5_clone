extends RefCounted
## Government (data/government.json), inspired by the Hearts of Iron politics screen:
## - political advisors (3 slots, hired with power of their type, national ones only in their lifetime)
## - investment companies (2 slots, +1 from tech; bought with gold, then invested into up to level 5:
##   every level raises the benefits by 50 %, the drawbacks stay as they are)
## - laws with buff/nerf trade-offs (changing one costs power and has a cooldown)
## - estates (nobility, clergy, burghers): satisfaction drifts monthly toward 50 + the estate_<id> modifiers
##   of laws, advisors, companies and techs; loyal estates give bonuses, angry ones penalties and crisis events
## State lives in `n.gov`; the summed effects go into n.bonus["gov"], estate tiers into n.bonus["estates"].
## `g` is the game (scripts/core/game.gd); untyped to avoid a cyclic preload.

const Tech = preload("res://scripts/core/tech.gd")
const Religion = preload("res://scripts/core/religion.gd")

var cfg := {}
var advisors: Array = []
var adv_by_id := {}
var companies: Array = []
var comp_by_id := {}
var laws: Array = []
var law_by_id := {}
var forms := {}
var estates: Array = []
var budget: Array = []
var reforms: Array = []
var reform_by_id := {}
var budget_by_id := {}
var empire_by_id := {}


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
	estates = d.get("estates", [])
	budget = d.get("budget", [])
	reforms = d.get("reforms", [])
	for r in reforms:
		reform_by_id[r.id] = r
	for b in budget:
		budget_by_id[b.id] = b
	for r in empire_reforms():
		empire_by_id[r.id] = r


func init_nation(n) -> void:
	var lw := {}
	for l in laws:
		lw[l.id] = l.options[0].id
	var es := {}
	for e in estates:
		es[e.id] = 50.0
	var bu := {}
	for b in budget:
		bu[b.id] = budget_default()
	n.gov = {"advisors": [], "companies": [], "laws": lw, "law_month": {}, "invest": {}, "estates": es, "estate_month": {}, "budget": bu, "reforms": {}, "reform_month": {}, "ages": {}, "adv_skill": {}, "adv_since": {}}
	refresh(n)
	refresh_estates(n)


# ---------------------------------------------------------------- heir
# n.gov.heir = {adm, dip, mil, name, edu}: takes the throne when the ruler's years run out (game._yearly).
# Educating (once a year, power of that kind) raises one of the heir's skills by one up to ruler_max.

func ensure_heir(g, n) -> void:
	if n.gov.get("heir", {}).is_empty():
		var h: Dictionary = g.roll_person(n)
		h.erase("years")
		h["edu"] = 0
		n.gov.heir = h


## "Erbe" for hereditary rule, "Nachfolger" for republics, theocracies, orders and elective monarchies.
func heir_title(tag: String) -> String:
	return "Nachfolger" if cfg.get("elective_forms", []).has(form_name(tag)) else "Erbe"


## The ruler's years are over: the heir takes the throne (fresh reign length), a new heir is named.
func succession(g, n) -> void:
	var h: Dictionary = n.gov.get("heir", {})
	if h.is_empty():
		g._new_ruler(n)
	else:
		n.ruler = {"adm": int(h.adm), "dip": int(h.dip), "mil": int(h.mil), "years": g.rng.randi_range(8, 35)}
		n.ruler_name = str(h.name)
	n.gov.heir = {}
	ensure_heir(g, n)


func educate_cost(g, n, kind: String) -> float:
	var h: Dictionary = n.gov.get("heir", {})
	return round(float(cfg.get("heir_edu_cost", 60)) * (1.0 + float(cfg.get("heir_edu_step", 0.5)) * int(h.get(kind, 0))))


func educate_block(g, tag: String, kind: String) -> String:
	var n = g.nations[tag]
	var h: Dictionary = n.gov.get("heir", {})
	if h.is_empty():
		return "Kein %s." % heir_title(tag)
	if int(h.get(kind, 0)) >= int(g.bal.ruler_max):
		return "Schon voll ausgebildet."
	if int(h.get("edu", 0)) == g.year():
		return "Dieses Jahr schon unterrichtet."
	var c := educate_cost(g, n, kind)
	if n.get(kind) < c:
		return "Zu wenig Punkte (%d benötigt)." % c
	return ""


func educate(g, tag: String, kind: String) -> String:
	var err := educate_block(g, tag, kind)
	if err != "":
		return err
	var n = g.nations[tag]
	n.set(kind, n.get(kind) - educate_cost(g, n, kind))
	n.gov.heir[kind] = int(n.gov.heir[kind]) + 1
	n.gov.heir.edu = g.year()
	return ""


## Disinheriting names a new random heir for prestige, at most every heir_disinherit_years.
func disinherit_block(g, tag: String) -> String:
	var n = g.nations[tag]
	if n.gov.get("heir", {}).is_empty():
		return "Kein %s." % heir_title(tag)
	var since: int = g.month - int(n.gov.get("disinherit_month", -100000))
	var wait: int = int(cfg.get("heir_disinherit_years", 10)) * 12 - since
	if wait > 0:
		return "Erst wieder in %d Jahren." % ceili(wait / 12.0)
	if n.prestige - float(cfg.get("heir_disinherit_prestige", 25)) < -50.0:
		return "Zu wenig Prestige."
	return ""


func disinherit(g, tag: String) -> String:
	var err := disinherit_block(g, tag)
	if err != "":
		return err
	var n = g.nations[tag]
	n.prestige -= float(cfg.get("heir_disinherit_prestige", 25))
	n.gov.heir = {}
	ensure_heir(g, n)
	n.gov.disinherit_month = g.month
	return ""


func form_name(tag: String) -> String:
	return forms.get(tag, forms.get("default", "Monarchie"))


## Effects of `tag`'s form of government (part of the gov bonus source).
func form_effects(tag: String) -> Dictionary:
	return cfg.get("form_effects", {}).get(form_name(tag), {})


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
	n.gov.adv_skill[id] = 1
	n.gov.adv_since[id] = g.month
	_changed(g, n)
	return ""


func dismiss(g, tag: String, id: String) -> void:
	var n = g.nations[tag]
	n.gov.advisors.erase(id)
	n.gov.adv_skill.erase(id)
	n.gov.adv_since.erase(id)
	_changed(g, n)


func max_skill() -> int:
	return int(cfg.get("advisor_max_skill", 3))


func advisor_skill(n, id: String) -> int:
	return int(n.gov.get("adv_skill", {}).get(id, 1))


## Effects of advisor `id` at `skill`: benefits grow by advisor_skill_step per level, drawbacks do not.
func advisor_effects(id: String, skill: int) -> Dictionary:
	return scaled_effects(adv_by_id.get(id, {}).get("effects", {}), 1.0 + float(cfg.get("advisor_skill_step", 0.5)) * (skill - 1))


## Promoting to the next skill level costs advisor_cost × promote_mult × current level (75 → 113 → 225 at defaults).
func promote_cost(_g, n, id: String) -> float:
	return advisor_cost(null, n, id) * float(cfg.get("advisor_promote_mult", 1.5)) * advisor_skill(n, id)


func promote_block(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	if not n.gov.advisors.has(id):
		return "Nicht im Rat."
	if advisor_skill(n, id) >= max_skill():
		return "Höchste Stufe erreicht."
	var c := promote_cost(g, n, id)
	if n.get(adv_by_id[id].type) < c:
		return "Zu wenig Punkte (%d benötigt)." % c
	return ""


func promote(g, tag: String, id: String) -> String:
	var err := promote_block(g, tag, id)
	if err != "":
		return err
	var n = g.nations[tag]
	var t: String = adv_by_id[id].type
	n.set(t, n.get(t) - promote_cost(g, n, id))
	n.gov.adv_skill[id] = advisor_skill(n, id) + 1
	_changed(g, n)
	return ""


## Years generic advisor `id` has served (national figures leave by date instead).
func service_years(g, n, id: String) -> int:
	return int((g.month - int(n.gov.get("adv_since", {}).get(id, g.month))) / 12)


## Yearly: a generic advisor past retire_years retires with retire_chance; a pupil takes over one level lower.
func _advisor_careers(g, n) -> void:
	for id in n.gov.advisors:
		var a: Dictionary = adv_by_id.get(id, {})
		if a.has("to") or service_years(g, n, id) < int(cfg.get("advisor_retire_years", 20)):
			continue
		if g.rng.randf() > float(cfg.get("advisor_retire_chance", 0.15)):
			continue
		var lvl := advisor_skill(n, id)
		n.gov.adv_skill[id] = maxi(1, lvl - 1)
		n.gov.adv_since[id] = g.month
		if lvl > 1:
			g.log_msg("🎓 %s geht in den Ruhestand, ein Schüler folgt auf Stufe %d." % [a.name, lvl - 1], [n.tag])
		else:
			g.log_msg("🎓 %s geht in den Ruhestand, ein Nachfolger übernimmt." % a.name, [n.tag])
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
	return scaled_effects(base, 1.0 + float(cfg.get("invest_step", 0.5)) * (level - 1))


## `base` with its benefits multiplied by `mult`; drawbacks stay as they are.
func scaled_effects(base: Dictionary, mult: float) -> Dictionary:
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
	var effs := [form_effects(n.tag)]
	for id in n.gov.advisors:
		effs.append(advisor_effects(id, advisor_skill(n, id)))
	for id in n.gov.companies:
		effs.append(company_effects(id, invest_level(n, id)))
	for law_id in n.gov.laws:
		if law_by_id.has(law_id):
			effs.append(law_option(law_id, n.gov.laws[law_id]).get("effects", {}))
	for tier in n.gov.get("reforms", {}):
		effs.append(reform_option(tier, n.gov.reforms[tier]).get("effects", {}))
	var done: Dictionary = n.gov.get("ages", {})
	for age in ages():
		for goal in age.goals:
			if done.has(goal.id):
				effs.append(goal.reward)
		if done.has(age.id):
			effs.append(age.triumph.reward)
	for e in effs:
		for k in e:
			b[k] = b.get(k, 0.0) + float(e[k])
	n.bonus["gov"] = b
	var bb := {}
	for id in n.gov.get("budget", {}):
		var e := budget_effects(id, int(n.gov.budget[id]))
		for k in e:
			bb[k] = bb.get(k, 0.0) + float(e[k])
	n.bonus["budget"] = bb


# ---------------------------------------------------------------- state reforms (EU4-like tiers)
# One option per tier, unlocked by year, bought with administrative power. Changing an enacted tier costs
# again and is possible only every reform_change_years.

func reform_option(tier: String, opt_id: String) -> Dictionary:
	if not reform_by_id.has(tier):
		return {}
	for o in reform_by_id[tier].options:
		if o.id == opt_id:
			return o
	return {}


func reform_cost(_g, _n, tier: String) -> float:
	return float(cfg.get("reform_cost", 100)) + float(cfg.get("reform_cost_step", 50)) * reforms.find(reform_by_id.get(tier))


func reform_cooldown_left(g, n, tier: String) -> int:
	if not n.gov.reform_month.has(tier):
		return 0
	return maxi(0, int(n.gov.reform_month[tier]) + int(cfg.get("reform_change_years", 25)) * 12 - g.month)


func reform_block(g, tag: String, tier: String, opt_id: String) -> String:
	var n = g.nations[tag]
	if reform_option(tier, opt_id).is_empty():
		return "Unbekannte Reform."
	if n.gov.reforms.get(tier, "") == opt_id:
		return "Bereits eingeführt."
	if g.year() < int(reform_by_id[tier].year):
		return "Verfügbar ab %d." % int(reform_by_id[tier].year)
	var cd := reform_cooldown_left(g, n, tier)
	if cd > 0:
		return "Erst in %d Monaten wieder änderbar." % cd
	var c := reform_cost(g, n, tier)
	if n.adm < c:
		return "Zu wenig Verwaltungspunkte (%d benötigt)." % c
	return ""


func enact_reform(g, tag: String, tier: String, opt_id: String) -> String:
	var err := reform_block(g, tag, tier, opt_id)
	if err != "":
		return err
	var n = g.nations[tag]
	n.adm -= reform_cost(g, n, tier)
	n.gov.reforms[tier] = opt_id
	n.gov.reform_month[tier] = g.month
	_changed(g, n)
	return ""


## Tiers the nation may fill right now (unlocked by year, still empty).
func open_reform_tiers(g, n) -> Array:
	var r := []
	for t in reforms:
		if not n.gov.reforms.has(t.id) and g.year() >= int(t.year):
			r.append(t.id)
	return r


# ---------------------------------------------------------------- budget sliders (EU5-like)
# Every slider has steps 0..4; the middle step is neutral (no effect, no cost). Each step away from it
# adds `per_step` effects and costs (or saves) `cost` x monthly income in gold.

func budget_default() -> int:
	return int(cfg.get("budget_default", 2))


func budget_max() -> int:
	return budget[0].steps.size() - 1 if not budget.is_empty() else 0


func budget_step(n, id: String) -> int:
	return int(n.gov.get("budget", {}).get(id, budget_default()))


func budget_effects(id: String, step: int) -> Dictionary:
	var r := {}
	var d: int = step - budget_default()
	if d == 0 or not budget_by_id.has(id):
		return r
	var ps: Dictionary = budget_by_id[id].per_step
	for k in ps:
		r[k] = float(ps[k]) * d
	return r


## Gold per month of one slider at `step` (negative = savings).
func budget_slider_cost(n, id: String, step: int) -> float:
	return float(budget_by_id[id].get("cost", 0.0)) * (step - budget_default()) * maxf(0.0, n.income)


## Monthly gold of all sliders together; part of n.expenses (game._economy).
func budget_cost(_g, n) -> float:
	var c := 0.0
	for id in n.gov.get("budget", {}):
		c += budget_slider_cost(n, id, int(n.gov.budget[id]))
	return c


func set_budget(g, tag: String, id: String, step: int) -> String:
	var n = g.nations[tag]
	if not budget_by_id.has(id):
		return "Unbekannter Haushaltsposten."
	n.gov.budget[id] = clampi(step, 0, budget_max())
	_changed(g, n)
	return ""


# ---------------------------------------------------------------- imperial reforms (Holy Roman Empire light)
# Global state on the game: g.hre_authority and g.hre_reforms (passed ids, in order). Authority grows every
# year with the size of the empire and shrinks with wars between members. The emperor passes the next reform
# with authority if more than half of the other electors back him. Members get the member effects, the
# emperor also his own, all in n.bonus["empire"].

func empire_cfg() -> Dictionary:
	return cfg.get("empire", {})


func empire_reforms() -> Array:
	return empire_cfg().get("reforms", [])


## The next reform in line, or {} when all are passed.
func next_empire_reform(g) -> Dictionary:
	for r in empire_reforms():
		if not g.hre_reforms.has(r.id):
			return r
	return {}


## [electors backing the emperor, electors asked]: the emperor himself does not vote.
func reform_support(g) -> Array:
	var yes := 0
	var total := 0
	for e in g.current_electors():
		if e == g.emperor:
			continue
		total += 1
		if g.get_rel(e, g.emperor) >= 0.0 or g.is_allied(e, g.emperor):
			yes += 1
	return [yes, total]


func empire_reform_block(g, tag: String) -> String:
	if g.emperor == "" or tag != g.emperor:
		return "Nur der Kaiser kann Reichsreformen verabschieden."
	var r := next_empire_reform(g)
	if r.is_empty():
		return "Alle Reichsreformen sind verabschiedet."
	if g.year() < int(r.year):
		return "Verfügbar ab %d." % int(r.year)
	if g.hre_authority < float(r.cost):
		return "Zu wenig kaiserliche Autorität (%d benötigt)." % int(r.cost)
	var s := reform_support(g)
	if s[0] * 2 <= s[1]:
		return "Zu wenige Kurfürsten stehen hinter dir (%d von %d, mehr als die Hälfte nötig)." % [s[0], s[1]]
	return ""


func pass_empire_reform(g, tag: String) -> String:
	var err := empire_reform_block(g, tag)
	if err != "":
		return err
	var r := next_empire_reform(g)
	g.hre_authority -= float(r.cost)
	g.hre_reforms.append(r.id)
	g.log_msg("👑 Reichsreform: %s. %s" % [r.name, r.text], g.hre_members())
	refresh_empire(g)
	return ""


## Wars between two members are forbidden once the Ewiger Landfriede is passed.
func landfriede(g, a: String, b: String) -> bool:
	return g.hre_reforms.has("landfriede") and g.hre.has(a) and g.hre.has(b)


## Effects of the passed reforms for `tag` (member effects, plus the emperor's own for the emperor).
func empire_effects(g, tag: String) -> Dictionary:
	var b := {}
	if not g.hre.has(tag):
		return b
	for id in g.hre_reforms:
		var r: Dictionary = empire_by_id.get(id, {})
		var effs: Array = [r.get("members", {})]
		if tag == g.emperor:
			effs.append(r.get("emperor", {}))
		for e in effs:
			for k in e:
				b[k] = b.get(k, 0.0) + float(e[k])
	return b


func refresh_empire(g) -> void:
	for tag in g.order:
		var n = g.nations[tag]
		var b := empire_effects(g, tag) if n.alive else {}
		if b != n.bonus.get("empire", {}):
			n.bonus["empire"] = b
			g._update_cached(n)


## Authority per year: base plus per member, minus every war between members.
func authority_gain(g) -> float:
	var c := empire_cfg()
	var members: Array = g.hre_members()
	var v: float = float(c.get("authority_base", 2.0)) + float(c.get("authority_per_member", 0.15)) * members.size()
	for w in g.wars:
		if w.attackers.any(func(t): return members.has(t)) and w.defenders.any(func(t): return members.has(t)):
			v -= float(c.get("authority_member_war", 3.0))
	return v


## A new emperor from another house starts with part of the old authority.
func on_new_emperor(g) -> void:
	g.hre_authority = snappedf(g.hre_authority * float(empire_cfg().get("authority_new_emperor", 0.75)), 0.01)
	refresh_empire(g)


## Yearly, after the election check: authority grows, an AI emperor passes the next reform when it can.
func empire_yearly(g) -> void:
	if g.emperor == "" or empire_reforms().is_empty():
		return
	var mx: float = float(empire_cfg().get("authority_max", 100))
	g.hre_authority = snappedf(clampf(g.hre_authority + authority_gain(g), 0.0, mx), 0.01)
	if g.emperor != g.player and empire_reform_block(g, g.emperor) == "":
		pass_empire_reform(g, g.emperor)
	refresh_empire(g)


## Yearly: prestige drift from all sources, national advisors leave court after their time.
func yearly(g, n) -> void:
	var p: float = g.mod(n, "prestige")
	if p != 0.0:
		n.prestige = maxf(-50.0, n.prestige + p)
	for id in n.gov.advisors.duplicate():
		var a: Dictionary = adv_by_id.get(id, {})
		if a.has("to") and g.year() > int(a.to):
			n.gov.advisors.erase(id)
			n.gov.adv_skill.erase(id)
			n.gov.adv_since.erase(id)
			g.log_msg("🎓 %s verlässt den Hof." % a.name, [n.tag])
			_changed(g, n)
	_advisor_careers(g, n)
	ensure_heir(g, n)
	_estate_crisis(g, n)
	ages_yearly(g, n)


# ---------------------------------------------------------------- age goals (EU4-like age objectives)
# Every age has three goals that count only while the age lasts. A reached goal gives its reward for good,
# age_triumph_goals of them also the age's triumph. Reached ids (goal ids and age ids) -> year in n.gov.ages.

func ages() -> Array:
	return cfg.get("ages", [])


func age_of_year(y: int) -> Dictionary:
	for a in ages():
		if y >= int(a.from) and y <= int(a.to):
			return a
	return {}


## [have, need] for a goal condition.
func goal_progress(g, n, cond: Dictionary) -> Array:
	var k: String = cond.keys()[0]
	var v = cond[k]
	match k:
		"techs":
			return [n.techs.size(), int(v)]
		"tech_cat":
			var c := 0
			for id in n.techs:
				if g.tree.by_id.has(id) and g.tree.by_id[id].cat == v[0]:
					c += 1
			return [c, int(v[1])]
		"advisors":
			return [n.gov.advisors.size(), int(v)]
		"company_level":
			var best := 0
			for id in n.gov.companies:
				best = maxi(best, invest_level(n, id))
			return [best, int(v)]
		"reforms":
			return [n.gov.reforms.size(), int(v)]
		"dev":
			return [n.dev_total, int(v)]
		"estates_loyal":
			var c := 0
			for e in estates:
				if estate_tier(n, e.id) == "loyal":
					c += 1
			return [c, int(v)]
		"faith_share":
			return [roundi(Religion.share(g, n.tag, n.religion) * 100.0), int(v)]
		"prestige":
			return [int(n.prestige), int(v)]
	return [0, 1]


func goal_met(g, n, cond: Dictionary) -> bool:
	var p := goal_progress(g, n, cond)
	return p[0] >= p[1]


func age_goals_done(n, age: Dictionary) -> int:
	var c := 0
	for goal in age.goals:
		if n.gov.ages.has(goal.id):
			c += 1
	return c


## Yearly: goals of the running age that are met now are reached for good; enough of them win the triumph.
func ages_yearly(g, n) -> void:
	var age := age_of_year(g.year())
	if age.is_empty():
		return
	var changed := false
	for goal in age.goals:
		if not n.gov.ages.has(goal.id) and goal_met(g, n, goal.cond):
			n.gov.ages[goal.id] = g.year()
			changed = true
			if n.tag == g.player:
				g.log_msg("🏆 Zeitalter-Ziel erreicht: %s (%s)." % [goal.name, Tech.effects_text(goal.reward)], [n.tag])
	if not n.gov.ages.has(age.id) and age_goals_done(n, age) >= int(cfg.get("age_triumph_goals", 2)):
		n.gov.ages[age.id] = g.year()
		changed = true
		if n.tag == g.player:
			g.log_msg("🏆 Triumph der %s: %s (%s)." % [age.name, age.triumph.name, Tech.effects_text(age.triumph.reward)], [n.tag])
	if changed:
		_changed(g, n)


# ---------------------------------------------------------------- estates

## Satisfaction an estate drifts toward: 50 plus all estate_<id> modifiers, 0..100.
func estate_target(g, n, id: String) -> float:
	return clampf(50.0 + g.mod(n, "estate_" + id), 0.0, 100.0)


## "loyal", "neutral" or "angry".
func estate_tier(n, id: String) -> String:
	var v: float = n.gov.estates.get(id, 50.0)
	if v >= float(cfg.get("estate_loyal", 60)):
		return "loyal"
	if v < float(cfg.get("estate_angry", 30)):
		return "angry"
	return "neutral"


func refresh_estates(n) -> void:
	var b := {}
	for e in estates:
		var t := estate_tier(n, e.id)
		if t == "neutral":
			continue
		var eff: Dictionary = e[t]
		for k in eff:
			b[k] = b.get(k, 0.0) + float(eff[k])
	n.bonus["estates"] = b


## Monthly drift toward the target (snapped to 0.01 so saves stay exact).
func estates_monthly(g, n) -> void:
	var before := {}
	for e in estates:
		before[e.id] = estate_tier(n, e.id)
		var v: float = n.gov.estates[e.id]
		v += (estate_target(g, n, e.id) - v) * float(cfg.get("estate_drift", 0.03))
		n.gov.estates[e.id] = snappedf(clampf(v, 0.0, 100.0), 0.01)
	for e in estates:
		if estate_tier(n, e.id) != before[e.id]:
			refresh_estates(n)
			g._update_cached(n)
			if n.tag == g.player:
				var word: String = {"loyal": "ist dir treu ergeben", "neutral": "ist wieder ruhig", "angry": "ist zornig"}[estate_tier(n, e.id)]
				g.log_msg("⚖️ Der Stand %s %s." % [e.name, word], [n.tag])
			break


func change_estate(g, n, id: String, amount: float) -> void:
	if not n.gov.estates.has(id):
		return
	n.gov.estates[id] = snappedf(clampf(n.gov.estates[id] + amount, 0.0, 100.0), 0.01)
	refresh_estates(n)
	g._update_cached(n)


func concession_cost(_g, n) -> float:
	return roundf(maxf(float(cfg.get("concession_min_gold", 30)), float(cfg.get("concession_months", 6)) * maxf(n.income, 0.0)))


func concession_cooldown_left(g, n, id: String) -> int:
	if not n.gov.estate_month.has(id):
		return 0
	return maxi(0, int(n.gov.estate_month[id]) + int(cfg.get("concession_cooldown_years", 5)) * 12 - g.month)


func concession_block(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	if not n.gov.estates.has(id):
		return "Unbekannter Stand."
	var cd := concession_cooldown_left(g, n, id)
	if cd > 0:
		return "Erst in %d Monaten wieder möglich." % cd
	var c := concession_cost(g, n)
	if n.gold < c:
		return "Zu wenig Gold (%d benötigt)." % c
	return ""


## Buy goodwill: gold for an immediate satisfaction boost (it still drifts back toward the target).
func grant_concession(g, tag: String, id: String) -> String:
	var err := concession_block(g, tag, id)
	if err != "":
		return err
	var n = g.nations[tag]
	n.gold -= concession_cost(g, n)
	n.gov.estate_month[id] = g.month
	change_estate(g, n, id, float(cfg.get("concession_amount", 20)))
	return ""


func estate_name(id: String) -> String:
	for e in estates:
		if e.id == id:
			return e.name
	return id


func estate_event_defs() -> Array:
	return cfg.get("estate_events", [])


## Yearly: an estate below estate_crisis may raise demands (at most one crisis per estate_crisis_years).
func _estate_crisis(g, n) -> void:
	var last: int = int(n.gov.estate_month.get("crisis", -1000))
	if g.month - last < int(cfg.get("estate_crisis_years", 4)) * 12:
		return
	for e in estates:
		if n.gov.estates[e.id] >= float(cfg.get("estate_crisis", 25)):
			continue
		if g.rng.randf() > float(cfg.get("estate_crisis_chance", 0.35)):
			continue
		n.gov.estate_month["crisis"] = g.month
		var ev_id: String = "estate_crisis_" + e.id
		g.stats.events += 1
		if n.tag == g.player:
			if not g.pending_events.has(ev_id):
				g.pending_events.append(ev_id)
		else:
			var ev: Dictionary = g.event_by_id[ev_id]
			g.apply_effects(n.tag, ev.options[g.ai.pick_event_option(g, n, ev)].get("effects", {}))
		return


func to_save(n) -> Dictionary:
	return n.gov


func load_save(n, d) -> void:
	init_nation(n)
	if d == null:
		return
	for id in d.get("advisors", []):
		if adv_by_id.has(id):
			n.gov.advisors.append(id)
			n.gov.adv_skill[id] = clampi(int(d.get("adv_skill", {}).get(id, 1)), 1, max_skill())
			n.gov.adv_since[id] = int(d.get("adv_since", {}).get(id, 0))
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
	var es: Dictionary = d.get("estates", {})
	for e in es:
		if n.gov.estates.has(e):
			n.gov.estates[e] = float(es[e])
	var em: Dictionary = d.get("estate_month", {})
	for k in em:
		n.gov.estate_month[k] = int(em[k])
	var rf: Dictionary = d.get("reforms", {})
	for k in rf:
		if not reform_option(k, rf[k]).is_empty():
			n.gov.reforms[k] = rf[k]
	var rm: Dictionary = d.get("reform_month", {})
	for k in rm:
		n.gov.reform_month[k] = int(rm[k])
	var ag: Dictionary = d.get("ages", {})
	for k in ag:
		n.gov.ages[k] = int(ag[k])
	var bu: Dictionary = d.get("budget", {})
	for k in bu:
		if budget_by_id.has(k):
			n.gov.budget[k] = clampi(int(bu[k]), 0, budget_max())
	if d.has("disinherit_month"):
		n.gov.disinherit_month = int(d.disinherit_month)
	var h: Dictionary = d.get("heir", {})
	if not h.is_empty():
		n.gov.heir = {"adm": int(h.get("adm", 0)), "dip": int(h.get("dip", 0)), "mil": int(h.get("mil", 0)),
				"name": str(h.get("name", "")), "edu": int(h.get("edu", 0))}
	refresh(n)
	refresh_estates(n)


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
	elif slot == 3:
		_ai_estates(g, n)
	elif slot == 11:
		_ai_budget(g, n)
	elif slot == 6:
		_ai_reforms(g, n)
	elif slot == 10:
		_ai_heir(g, n)


## AI educates its heir only with power to spare (ai_heir_share of the cap), in the kind it has most of.
func _ai_heir(g, n) -> void:
	var best := ""
	var best_left := float(g.bal.power_cap) * float(cfg.get("ai_heir_share", 0.6))
	for k in g.POWERS:
		if educate_block(g, n.tag, k) == "" and n.get(k) - educate_cost(g, n, k) > best_left:
			best_left = n.get(k) - educate_cost(g, n, k)
			best = k
	if best != "":
		educate(g, n.tag, best)


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
	if (full and _ai_promote(g, n)) or best == "":
		return
	if full:
		# replace the weakest advisor only for a clearly better (usually national) one
		var worst := ""
		var worst_v := 1e9
		for id in n.gov.advisors:
			var v: float = Tech.effect_value(advisor_effects(id, advisor_skill(n, id)), n.aggression)
			if v < worst_v:
				worst_v = v
				worst = id
		if worst == "" or best_v < worst_v + 4.0:
			return
		dismiss(g, n.tag, worst)
	hire(g, n.tag, best)


## Now and then (power competes with tech) promote the most valuable affordable advisor. True if promoted.
func _ai_promote(g, n) -> bool:
	if g.rng.randf() > float(cfg.get("ai_promote_chance", 0.3)):
		return false
	var best := ""
	var best_v := 0.0
	for id in n.gov.advisors:
		if promote_block(g, n.tag, id) != "":
			continue
		var v: float = Tech.effect_value(adv_by_id[id].effects, n.aggression)
		if v > best_v:
			best_v = v
			best = id
	return best != "" and promote(g, n.tag, best) == ""


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


func _ai_estates(g, n) -> void:
	var reserve: float = 10.0 + n.expenses * 4.0 + 30.0
	for e in estates:
		if n.gov.estates[e.id] < float(cfg.get("estate_angry", 30)) + 5.0 \
				and n.gold >= concession_cost(g, n) + reserve and concession_block(g, n.tag, e.id) == "":
			grant_concession(g, n.tag, e.id)
			return


## AI budget: tighten the purse when poor, spend on court and research when rich, pay the army in war.
func _ai_budget(g, n) -> void:
	var war: bool = g.is_at_war(n.tag)
	var poor: bool = n.gold < 20.0 + n.expenses * 3.0 or n.income - n.expenses < 0.0
	var rich: bool = n.gold > 300.0 + n.expenses * 12.0
	var want := {"steuern": 2, "hof": 2, "heer": 3 if war else 2, "bildung": 2}
	if poor:
		want.hof = 1
		want.bildung = 1
		want.heer = 2 if war else 1
		if n.gov.estates.get("buerger", 50.0) > 40.0:
			want.steuern = 3
	elif rich:
		want.hof = 3
		want.bildung = 3
	var changed := false
	for id in want:
		if budget_by_id.has(id) and budget_step(n, id) != want[id]:
			n.gov.budget[id] = want[id]
			changed = true
	if changed:
		_changed(g, n)


## AI: fill the oldest open reform tier with its most valuable option, keeping half a tech in reserve.
func _ai_reforms(g, n) -> void:
	var open := open_reform_tiers(g, n)
	if open.is_empty():
		return
	var tier: String = open[0]
	if n.adm < reform_cost(g, n, tier) + g.tech_cost(n.tag, "adm") * 0.5:
		return
	var best := ""
	var best_v := -1e9
	for o in reform_by_id[tier].options:
		var v: float = Tech.effect_value(o.effects, n.aggression) + g.rng.randf() * 2.0
		if v > best_v:
			best_v = v
			best = o.id
	enact_reform(g, n.tag, tier, best)

