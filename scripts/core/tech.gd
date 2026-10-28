extends RefCounted
## Tech tree (data/techs.json): 3 categories x 3 branches x 9 generic techs, plus 3 special techs
## for every playable nation. `n.tech[cat]` stays the number of generic techs researched per category,
## so the older per-level formulas (income per adm tech, combat per mil tech, ...) keep working.
## Researched techs live in `n.techs` (id -> month); their effects are summed into n.bonus["tech"].
## `g` is the game (scripts/core/game.gd); untyped to avoid a cyclic preload.

## Modifier key -> [label, percent?, positive is good?]. Shared by the tech and government screens.
const LABELS := {
	"income": ["Einkommen", true, true], "tax": ["Steuern", true, true], "production": ["Produktion", true, true],
	"trade": ["Handel", true, true], "merchants": ["Händler", false, true],
	"build_cost": ["Baukosten", true, false], "develop_cost": ["Entwicklungskosten", true, false],
	"maintenance": ["Armeeunterhalt", true, false], "manpower": ["Mannschaften", true, true],
	"combat": ["Kampfkraft", true, true], "force_limit": ["Truppenlimit", false, true],
	"naval": ["Flottenstärke", true, true],
	"adm": ["Verwaltung/Monat", false, true], "dip": ["Diplomatie/Monat", false, true], "mil": ["Militär/Monat", false, true],
	"ae_decay": ["AE-Abbau", true, true], "ae_gen": ["Aggressive Expansion", true, false],
	"tech_cost": ["Technologiekosten", true, false], "siege": ["Belagerungstempo", true, true],
	"unrest": ["Unruhe", false, false], "coring": ["Eingliederungszeit", true, false],
	"prestige": ["Prestige/Jahr", false, true], "company_slots": ["Kompanie-Platz", false, true],
	"advisor_slots": ["Berater-Platz", false, true],
	"estate_adel": ["Zufriedenheit Adel", false, true], "estate_klerus": ["Zufriedenheit Klerus", false, true],
	"estate_buerger": ["Zufriedenheit Bürger", false, true],
	"army_power": ["Max. Moral", true, true], "army_power_regen": ["Moral-Erholung", true, true],
	"religious_unrest": ["Unruhe durch Andersgläubige", true, false], "conversion": ["Bekehrung", true, true],
}

## What each modifier does, for tooltips and detail popups.
const DESCS := {
	"income": "alle Einnahmen", "tax": "Steuern aus Provinzen", "production": "Wert der produzierten Güter",
	"trade": "Einnahmen aus Handel", "merchants": "zusätzliche Händler", "build_cost": "Gold für Gebäude",
	"develop_cost": "Verwaltungspunkte für Entwicklung", "maintenance": "Gold für stehende Armeen",
	"manpower": "maximale Mannschaften", "combat": "Stärke in Schlachten", "naval": "Stärke der Flotte in Seeschlachten und um die Seeherrschaft", "force_limit": "Regimenter ohne Strafe",
	"adm": "Verwaltungspunkte pro Monat", "dip": "Diplomatiepunkte pro Monat", "mil": "Militärpunkte pro Monat",
	"ae_decay": "wie schnell Aggressive Expansion abklingt", "ae_gen": "AE bei Eroberungen und Kriegserklärungen",
	"tech_cost": "Punkte für neue Technologien", "siege": "wie schnell Festungen fallen",
	"unrest": "Unruhe in jeder Provinz (Aufstände ab 5)", "coring": "Monate, bis erobertes Land voll zählt",
	"prestige": "Prestige pro Jahr (Ansehen, Kaiserwahl)", "company_slots": "weitere Investitionskompanie",
	"advisor_slots": "weiterer Beraterplatz",
	"estate_adel": "Zielwert der Zufriedenheit des Adels (Grundwert 50)",
	"estate_klerus": "Zielwert der Zufriedenheit des Klerus (Grundwert 50)",
	"estate_buerger": "Zielwert der Zufriedenheit der Bürger (Grundwert 50)",
	"army_power": "höchste Moral der Armeen", "army_power_regen": "wie schnell die Moral nach Kämpfen zurückkehrt",
	"religious_unrest": "Unruhe in Provinzen mit anderem Glauben", "conversion": "wie schnell Andersgläubige deinen Glauben annehmen (Missionare und von selbst)",
}

## AI weight per modifier unit (combat scales with aggression).
const AI_WEIGHTS := {
	"income": 100.0, "tax": 60.0, "production": 60.0, "trade": 50.0, "merchants": 5.0, "build_cost": -30.0,
	"develop_cost": -30.0, "maintenance": -50.0, "manpower": 30.0, "combat": 100.0, "force_limit": 1.5,
	"adm": 6.0, "dip": 5.0, "mil": 5.0, "ae_decay": 15.0, "ae_gen": -20.0, "tech_cost": -60.0, "siege": 12.0,
	"unrest": -2.5, "coring": -12.0, "prestige": 2.0, "company_slots": 8.0, "advisor_slots": 8.0,
	"estate_adel": 0.03, "estate_klerus": 0.03, "estate_buerger": 0.03, "army_power": 60.0, "army_power_regen": 15.0,
	"religious_unrest": -3.0, "conversion": 3.0,
}

const AGES := [[1444, "Renaissance"], [1500, "Entdeckungen"], [1550, "Reformation"], [1600, "Absolutismus"]]

var defs: Array = []
var by_id := {}
var branches: Array = []
var early_years: int = 20
var ahead_years: int = 0
var ahead_penalty: float = 0.0
var ai_ahead_reserve: float = 0.5
var spread_max: float = 0.3
var spread_factor: float = 0.5
var _for_cache := {}  # tag+cat -> techs_for result (defs never change after load); read-only for callers
var unlocks := {}  # tech id -> [[building id, level], ...] it unlocks (data/buildings.json "level_tech")


func _init(d: Dictionary = {}) -> void:
	early_years = int(d.get("early_years", 20))
	ahead_years = int(d.get("ahead_years", 0))
	ahead_penalty = float(d.get("ahead_penalty", 0.0))
	ai_ahead_reserve = float(d.get("ai_ahead_reserve", 0.5))
	spread_max = float(d.get("spread_max", 0.3))
	spread_factor = float(d.get("spread_factor", 0.5))
	branches = d.get("branches", [])
	for t in d.get("techs", []):
		defs.append(t)
		by_id[t.id] = t
	for t in d.get("special", []):
		defs.append(t)
		by_id[t.id] = t


func set_unlocks(buildings: Dictionary) -> void:
	unlocks = {}
	for bid in buildings:
		var lt: Dictionary = buildings[bid].get("level_tech", {})
		for lvl in lt:
			if not unlocks.has(lt[lvl]):
				unlocks[lt[lvl]] = []
			unlocks[lt[lvl]].append([bid, int(lvl)])


static func is_special(t: Dictionary) -> bool:
	return t.has("tag")


static func age_name(y: int) -> String:
	var name: String = AGES[0][1]
	for a in AGES:
		if y >= a[0]:
			name = a[1]
	return name


## Generic techs of `cat` (tree order) followed by the nation's own special techs.
func techs_for(tag: String, cat: String) -> Array:
	var key := tag + "/" + cat
	if _for_cache.has(key):
		return _for_cache[key]
	var r := []
	for t in defs:
		if t.cat == cat and (not is_special(t) or t.tag == tag):
			r.append(t)
	_for_cache[key] = r
	return r


func specials_of(tag: String) -> Array:
	var r := []
	for t in defs:
		if is_special(t) and t.tag == tag:
			r.append(t)
	return r


func has(n, id: String) -> bool:
	return n.techs.has(id)


## "" when `tag` may research `id` now (ignoring the cost), otherwise the reason.
func block_reason(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	var t: Dictionary = by_id.get(id, {})
	if t.is_empty():
		return "Unbekannte Technologie."
	if n.techs.has(id):
		return "Bereits erforscht."
	if is_special(t) and t.tag != tag:
		return "Nur für %s." % g.nations[t.tag].name if g.nations.has(t.tag) else "Nicht verfügbar."
	for r in t.get("req", []):
		if not n.techs.has(r):
			return "Benötigt: %s." % by_id[r].name
	var from: int = int(t.year) - early_years - ahead_years
	if g.year() < from:
		return "Verfügbar ab %d." % from
	return ""


## Years `id` is researched before its regular window (year - early_years); each costs ahead_penalty extra.
func years_ahead(g, id: String) -> int:
	return maxi(0, int(by_id[id].year) - early_years - g.year())


func cost(g, tag: String, id: String) -> float:
	return g.tech_cost(tag, by_id[id].cat) * (1.0 - spread_discount(g, tag, id)) * (1.0 + ahead_penalty * years_ahead(g, id))


## Knowledge spreads: the share of other living nations that already know a generic tech makes it cheaper
## (spread_factor x share, at most spread_max). Pioneers pay full price, laggards catch up.
func spread_discount(g, tag: String, id: String) -> float:
	var t: Dictionary = by_id.get(id, {})
	if t.is_empty() or is_special(t):
		return 0.0
	return minf(spread_max, spread_factor * known_share(g, tag, id))


func known_share(g, tag: String, id: String) -> float:
	var know := 0
	var others := 0
	for o in g.nations.values():
		if o.alive and o.tag != tag:
			others += 1
			if o.techs.has(id):
				know += 1
	return float(know) / others if others > 0 else 0.0


func research(g, tag: String, id: String) -> String:
	var err := block_reason(g, tag, id)
	if err != "":
		return err
	var n = g.nations[tag]
	var t: Dictionary = by_id[id]
	var c := cost(g, tag, id)
	if n.get(t.cat) < c:
		return "Zu wenig Punkte (%d benötigt)." % c
	n.set(t.cat, n.get(t.cat) - c)
	n.techs[id] = g.month
	if not is_special(t):
		n.tech[t.cat] += 1
	refresh(n)
	g._update_cached(n)
	return ""


func available(g, tag: String, cat: String) -> Array:
	var r := []
	var n = g.nations[tag]
	var y: int = g.year()
	for t in techs_for(tag, cat):
		if _open(n, t, y):
			r.append(t)
	return r


## Same rule as block_reason() == "" for a tech of techs_for(), without building the message strings
## (the AI asks this for every tech every time it researches).
func _open(n, t: Dictionary, y: int) -> bool:
	if n.techs.has(t.id):
		return false
	for r in t.get("req", []):
		if not n.techs.has(r):
			return false
	return y >= int(t.year) - early_years - ahead_years


## The tech the AI (or the old one-button path) researches next in `cat`: special techs first,
## then the most valuable generic tech, preferring older ones so no branch falls far behind.
func best_choice(g, tag: String, cat: String) -> String:
	var n = g.nations[tag]
	var best := ""
	var best_v := -1e9
	for t in available(g, tag, cat):
		# research ahead of time only with power to spare
		if years_ahead(g, t.id) > 0 and n.get(cat) < cost(g, tag, t.id) * (1.0 + ai_ahead_reserve):
			continue
		var v: float = effect_value(t.effects, n.aggression) - 0.15 * (int(t.year) - g.year()) + 2.0 * unlocks.get(t.id, []).size()
		if is_special(t):
			v += 1000.0
		if v > best_v:
			best_v = v
			best = t.id
	return best


func research_best(g, tag: String, cat: String) -> String:
	var id := best_choice(g, tag, cat)
	if id == "":
		return "Keine Technologie verfügbar."
	return research(g, tag, id)


# ---------------------------------------------------------------- research plan (player)
# n.tech_queue lists tech ids in the order the player wants them. Every month the first planned tech
# of each category is researched once it is open and affordable, without the early surcharge unless
# the points sit at the cap (they would be wasted otherwise).

## Adds `id` and its missing prerequisites (first) to the plan. "" on success, else the reason.
func queue_add(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	var t: Dictionary = by_id.get(id, {})
	if t.is_empty():
		return "Unbekannte Technologie."
	if n.techs.has(id):
		return "Bereits erforscht."
	if is_special(t) and t.tag != tag:
		return "Nicht verfügbar."
	if n.tech_queue.has(id):
		return "Schon im Forschungsplan."
	for r in t.get("req", []):
		if not n.techs.has(r) and not n.tech_queue.has(r):
			queue_add(g, tag, r)
	n.tech_queue.append(id)
	return ""


## Removes `id` and every planned tech that needs it.
func queue_remove(n, id: String) -> void:
	n.tech_queue.erase(id)
	for q in n.tech_queue.duplicate():
		if by_id[q].get("req", []).has(id):
			queue_remove(n, q)


## Moves `id` to the front of its category (after its own planned prerequisites).
func queue_first(n, id: String) -> void:
	var i: int = n.tech_queue.find(id)
	if i <= 0:
		return
	var reqs: Array = by_id[id].get("req", [])
	var to := 0
	for j in i:
		if reqs.has(n.tech_queue[j]):
			to = j + 1
	n.tech_queue.remove_at(i)
	n.tech_queue.insert(to, id)


## Planned techs of `cat` in plan order.
func queue_of(n, cat: String) -> Array:
	return n.tech_queue.filter(func(q): return by_id[q].cat == cat)


## Why the first planned tech of `cat` waits ("" when there is none or it is due now).
func queue_wait(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	var t: Dictionary = by_id[id]
	var err := block_reason(g, tag, id)
	if err != "":
		return err
	var c := cost(g, tag, id)
	if n.get(t.cat) < c:
		return "wartet auf Punkte (%d/%d)" % [n.get(t.cat), c]
	if years_ahead(g, id) > 0 and n.get(t.cat) < float(g.bal.power_cap):
		return "wartet bis %d (ohne Frühaufschlag)" % (int(t.year) - early_years)
	return ""


## Monthly: researches what the plan allows. Returns the names researched.
func queue_tick(g, n) -> Array:
	var done := []
	for q in n.tech_queue.duplicate():
		if n.techs.has(q) or (is_special(by_id[q]) and by_id[q].tag != n.tag):
			n.tech_queue.erase(q)
	for cat in g.POWERS:
		while true:
			var lst := queue_of(n, cat)
			if lst.is_empty() or queue_wait(g, n.tag, lst[0]) != "":
				break
			if research(g, n.tag, lst[0]) != "":
				break
			n.tech_queue.erase(lst[0])
			done.append(by_id[lst[0]].name)
	return done


## Recompute n.bonus["tech"] from the researched techs.
func refresh(n) -> void:
	var b := {}
	for id in n.techs:
		var t: Dictionary = by_id.get(id, {})
		for k in t.get("effects", {}):
			b[k] = b.get(k, 0.0) + float(t.effects[k])
	n.bonus["tech"] = b


func to_save(n) -> Dictionary:
	return n.techs


func load_save(n, d) -> void:
	n.techs = {}
	for id in d:
		if by_id.has(id):
			n.techs[id] = int(d[id])
	if n.techs.is_empty():
		_fill_from_levels(n)
	refresh(n)


## Saves from before the tech tree only have levels: grant the oldest generic techs per category.
func _fill_from_levels(n) -> void:
	for cat in n.tech:
		var lst := []
		for t in defs:
			if t.cat == cat and not is_special(t):
				lst.append(t)
		lst.sort_custom(func(x, y): return int(x.year) < int(y.year))
		for i in mini(int(n.tech[cat]), lst.size()):
			n.techs[lst[i].id] = 0


# ---------------------------------------------------------------- shared helpers (also used by government.gd)

static func effect_value(eff: Dictionary, aggression: float = 1.0) -> float:
	var v := 0.0
	for k in eff:
		var w: float = AI_WEIGHTS.get(k, 0.0)
		if k == "combat" or k == "siege" or k == "force_limit":
			w *= 0.6 + 0.4 * aggression
		v += w * float(eff[k])
	return v


## [[text, good], ...] for every effect, e.g. ["+5 % Einkommen", true].
static func effect_lines(eff: Dictionary) -> Array:
	var r := []
	for k in eff:
		var v: float = float(eff[k])
		var lab: Array = LABELS.get(k, [k, false, true])
		var num: String
		if lab[1]:
			num = "%+d %%" % roundi(v * 100.0)
		elif absf(v - roundf(v)) < 0.01:
			num = "%+d" % roundi(v)
		else:
			num = "%+.2f" % v
			num = num.rstrip("0")
		r.append([num.replace("-", "−") + " " + lab[0], (v > 0) == lab[2]])
	return r


static func effects_text(eff: Dictionary) -> String:
	var parts := []
	for l in effect_lines(eff):
		parts.append(l[0])
	return ", ".join(parts) if not parts.is_empty() else "keine Wirkung"
