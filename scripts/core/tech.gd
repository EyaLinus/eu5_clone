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
	"adm": ["Verwaltung/Monat", false, true], "dip": ["Diplomatie/Monat", false, true], "mil": ["Militär/Monat", false, true],
	"ae_decay": ["AE-Abbau", true, true], "ae_gen": ["Aggressive Expansion", true, false],
	"tech_cost": ["Technologiekosten", true, false], "siege": ["Belagerungstempo", true, true],
	"unrest": ["Unruhe", false, false], "coring": ["Eingliederungszeit", true, false],
	"prestige": ["Prestige/Jahr", false, true], "company_slots": ["Kompanie-Platz", false, true],
	"advisor_slots": ["Berater-Platz", false, true],
}

## AI weight per modifier unit (combat scales with aggression).
const AI_WEIGHTS := {
	"income": 100.0, "tax": 60.0, "production": 60.0, "trade": 50.0, "merchants": 5.0, "build_cost": -30.0,
	"develop_cost": -30.0, "maintenance": -50.0, "manpower": 30.0, "combat": 100.0, "force_limit": 1.5,
	"adm": 6.0, "dip": 5.0, "mil": 5.0, "ae_decay": 15.0, "ae_gen": -20.0, "tech_cost": -60.0, "siege": 12.0,
	"unrest": -2.5, "coring": -12.0, "prestige": 2.0, "company_slots": 8.0, "advisor_slots": 8.0,
}

const AGES := [[1444, "Renaissance"], [1500, "Entdeckungen"], [1550, "Reformation"], [1600, "Absolutismus"]]

var defs: Array = []
var by_id := {}
var branches: Array = []
var early_years: int = 20


func _init(d: Dictionary = {}) -> void:
	early_years = int(d.get("early_years", 20))
	branches = d.get("branches", [])
	for t in d.get("techs", []):
		defs.append(t)
		by_id[t.id] = t
	for t in d.get("special", []):
		defs.append(t)
		by_id[t.id] = t


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
	var r := []
	for t in defs:
		if t.cat == cat and (not is_special(t) or t.tag == tag):
			r.append(t)
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
	var from: int = int(t.year) - early_years
	if g.year() < from:
		return "Verfügbar ab %d." % from
	return ""


func cost(g, tag: String, id: String) -> float:
	return g.tech_cost(tag, by_id[id].cat)


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
	for t in techs_for(tag, cat):
		if block_reason(g, tag, t.id) == "":
			r.append(t)
	return r


## The tech the AI (or the old one-button path) researches next in `cat`: special techs first,
## then the most valuable generic tech, preferring older ones so no branch falls far behind.
func best_choice(g, tag: String, cat: String) -> String:
	var n = g.nations[tag]
	var best := ""
	var best_v := -1e9
	for t in available(g, tag, cat):
		var v: float = effect_value(t.effects, n.aggression) - 0.15 * (int(t.year) - g.year())
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
