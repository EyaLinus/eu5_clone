extends RefCounted
## Core simulation of the game. Has no Node dependencies, so it runs headless
## (balance runs, tests) exactly like in the UI. One tick = one month.

const AI = preload("res://scripts/core/ai.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Tech = preload("res://scripts/core/tech.gd")
const Government = preload("res://scripts/core/government.gd")
const Religion = preload("res://scripts/core/religion.gd")
const Monuments = preload("res://scripts/core/monuments.gd")
const Warfare = preload("res://scripts/core/warfare.gd")
const Naval = preload("res://scripts/core/naval.gd")

const POWERS := ["adm", "dip", "mil"]
const MONTH_NAMES := ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]


class Province:
	var id: int
	var key: String
	var name: String
	var owner: String
	var controller: String
	var dev: int
	var center: Vector2
	var adj: Array = []
	var core_months: int = 0
	var siege: float = 0.0
	var fort: int = 0
	var prev_owner: String = ""  # conquered from; an unruly uncored province may defect back
	var suppress_months: int = 0
	var good: String = "grain"
	var market: int = -1  # pid of the market center this province trades in
	var coastal: bool = false  # touches the sea (data/coastal.json): may build a harbor
	var buildings := {}  # building id -> level
	var constructing := {}  # {"id": building, "months": left}
	var loc := {}  # cached local building effects (Economy.refresh_local)
	var religion: String = "catholic"  # faith of the people (Religion)
	var convert_months: int = 0  # a missionary is at work
	var terrain: String = "plains"  # data/terrain.json: march time and defence (Warfare)


class Nation:
	var tag: String
	var name: String
	var color: Color
	var emoji: String
	var playable: bool = false
	var major: bool = false  # one of the 7 great powers (rules + "major" condition), independent of playable
	var idea: String = ""
	var alive: bool = true
	var capital: int = -1
	var gold: float = 0.0
	var adm: float = 0.0
	var dip: float = 0.0
	var mil: float = 0.0
	var ae: float = 0.0
	var prestige: float = 0.0
	var manpower: float = 0.0
	var aggression: float = 1.0
	var tech := {"adm": 0, "dip": 0, "mil": 0}
	var ruler := {"adm": 2, "dip": 2, "mil": 2, "years": 20}
	var ruler_name: String = ""
	var ruler_names: Array = []
	var name_counts := {}
	var mods := {"income": 0.0, "combat": 0.0, "manpower": 0.0, "adm": 0.0, "dip": 0.0, "mil": 0.0, "ae_decay": 0.0}
	# derived bonuses per system (e.g. "tech", "gov", "goods", "buildings"): source -> {key: value}.
	# Not saved: each system recomputes its entry from game state. Read everything through Game.mod().
	var bonus := {}
	var relations := {}
	var allies: Array = []
	var truces := {}
	var claims := {}
	var flags := {}
	var missions_done := {}
	var coalition: Array = []
	var overlord: String = ""
	var vassal_since: int = 0
	var we: float = 0.0  # war exhaustion 0..we_max
	var techs := {}  # researched tech id -> month (scripts/core/tech.gd)
	var tech_queue: Array = []  # player research plan: tech ids, researched in order when affordable
	var gov := {}  # advisors, companies, laws (scripts/core/government.gd)
	# cached per month
	var dev_total: int = 0
	var income: float = 0.0
	var expenses: float = 0.0
	var max_manpower: float = 0.0
	var tax_income: float = 0.0
	var prod_income: float = 0.0
	var trade_income: float = 0.0
	var merchants: Array = []  # market center pids
	var merchant_auto: bool = true
	var loans: Array = []  # loan amounts (gold) still owed
	var trade_pacts: Array = []  # tags with a trade agreement (+trade income for both)
	var marriages: Array = []  # royal marriages: lasting good relations, a chance of personal union
	var access := {}  # nations whose land our armies may cross (military access)
	var guarantees := {}  # nations whose independence we defend
	var religion: String = "catholic"  # state religion
	var monuments := {}  # finished great works (Monuments)
	var monument_build := {}  # {"id", "months"} while one is being built
	var autobuild: bool = false  # player: build the best building whenever the treasury stays above the reserve
	var autobuild_reserve: float = 100.0
	var ships: float = 0.0  # fleet size (Naval)
	var fleet_sea: String = ""  # player's fleet station: "" = spread over all own coastal seas
	var army_stance: String = ""  # player's default for new armies: "" manual, "attack" or "defend"


class Army:
	var id: int
	var owner: String
	var pid: int
	var regs: float
	var full: float
	var target: int = -1
	var auto: bool = true
	var stance: String = "attack"  # when auto: "attack" (seek battles and sieges) or "defend" (own and allied land)
	var path: Array = []
	var power: float = 1.0  # fighting power 0..power_max: recovers with supply over time, battles drain it
	var general: int = 0  # 0 = none, 1..3 = skill of the commanding general
	var move: float = 0.0  # march progress (months) towards path[1] (Warfare)
	var landing: bool = false  # just came off the ships: fights worse in its next battle


class War:
	var id: int
	var name: String = ""
	var attackers: Array = []
	var defenders: Array = []
	var start: int = 0
	var battle_score: float = 0.0
	var coalition: bool = false
	var goal: int = -1


var bal: Dictionary = {}
var provinces: Array = []
var key_to_pid := {}
var nations := {}
var order: Array = []
var armies: Array = []
var wars: Array = []
var battles: Array = []  # running Warfare.Battle
var straits := {}  # sea crossings, Warfare.strait_key -> true
var seas: Array = []  # Naval: {"id", "name", "center", "provinces"}
var sea_by_id := {}
var province_seas := {}  # pid -> [sea ids] of coastal provinces
var strait_sea := {}  # Warfare.strait_key -> sea id
var _fleet := {}  # tag -> {sea: ships}, Naval.refresh
var sea_blocked := {}  # tag -> {sea: true} where an enemy rules the sea
var blockaded := {}  # pid -> true
var month: int = 0
var rng := RandomNumberGenerator.new()
var player: String = ""
var event_defs: Array = []
var monument_defs := {}
var event_by_id := {}
var mission_defs := {}
var log_lines: Array = []
var pending_events: Array = []
var pending_peace: Array = []
var peace_offer_memo := {}  # war id -> {"month", "ws"} of the last AI offer to the player (anti-spam)
var owned := {}
var next_army_id: int = 1
var next_war_id: int = 1
var game_over: bool = false
var stats := {"wars": 0, "battles": 0, "peace_deals": 0, "provinces_changed": 0, "coalition_wars": 0,
		"events": 0, "missions": 0, "eliminated": 0, "white_peace": 0, "timeouts": 0, "bankrupt_months": 0,
		"revolts": 0, "defections": 0, "independence": 0}
var ai
var tree = Tech.new()  # tech tree definitions + logic
var govt = Government.new()  # government definitions + logic
var hre: Array = []
var emperor: String = ""
var electors: Array = []
var hre_authority: float = 0.0  # imperial authority, spent by the emperor on reforms (govt.empire_*)
var hre_reforms: Array = []  # passed imperial reform ids, in order
var history: Array = []  # player's yearly snapshot: [year, dev, rank, provinces]
# economy (scripts/core/economy.gd)
var goods_def := {}
var buildings_def := {}
var markets: Array = []
var prices := {}
var prev_prices := {}
var base_supply := {}
var goods_leader := {}
var shocks := {}  # good -> {"mult": price factor, "years": left}: harvest failures, gluts
var market_cache := {}


func _init() -> void:
	ai = AI.new()


# ---------------------------------------------------------------- setup

## Difficulty levels (data in balance.json "difficulty"): modifiers for the player and the AI nations
## (n.bonus["difficulty"], derived, not saved) plus how aggressive the AI is, toward the player above all.
const DIFFICULTIES := ["easy", "normal", "hard", "very_hard"]
const DIFFICULTY_NAMES := {"easy": "Leicht", "normal": "Normal", "hard": "Schwer", "very_hard": "Sehr schwer"}
var difficulty := "normal"


func set_difficulty(id: String) -> void:
	difficulty = id if DIFFICULTIES.has(id) else "normal"
	_apply_difficulty()


func _apply_difficulty() -> void:
	var d: Dictionary = bal.get("difficulty", {}).get(difficulty, {})
	for tag in nations:
		nations[tag].bonus["difficulty"] = (d.get("player", {}) if tag == player else d.get("ai", {})).duplicate()


## A difficulty number such as "ai_aggression" (1.0 when the level does not set it).
func diff(key: String) -> float:
	return float(bal.get("difficulty", {}).get(difficulty, {}).get(key, 1.0))


func setup(data: Dictionary, seed_value: int, player_tag: String) -> void:
	bal = data.balance
	tree = Tech.new(data.get("techs", {}))
	govt = Government.new(data.get("government", {}))
	rng.seed = seed_value
	player = player_tag
	for pd in data.map.provinces:
		var p := Province.new()
		p.id = int(pd.id)
		p.key = pd.key
		p.name = pd.name
		p.owner = pd.owner
		p.controller = pd.owner
		p.dev = int(pd.dev)
		p.center = Vector2(pd.center[0], pd.center[1])
		for a in pd.adj:
			p.adj.append(int(a))
		provinces.append(p)
		key_to_pid[p.key] = p.id
	Warfare.setup(self, data)
	Naval.setup(self, data)
	for tag in data.nations:
		var nd: Dictionary = data.nations[tag]
		var n := Nation.new()
		n.tag = tag
		n.name = nd.name
		n.color = Color(nd.color)
		n.emoji = nd.get("emoji", "🏳️")
		n.playable = nd.get("playable", false)
		n.major = nd.get("major", false)
		n.idea = nd.get("idea", "")
		n.aggression = float(nd.get("aggression", 0.6))
		n.ruler_names = nd.get("rulers", [])
		n.capital = key_to_pid[nd.capital]
		var bonus: Dictionary = nd.get("bonus", {})
		for k in bonus:
			n.mods[k] = float(bonus[k])
		n.gold = 40.0
		n.adm = 50.0
		n.dip = 50.0
		n.mil = 50.0
		_new_ruler(n)
		tree.refresh(n)
		govt.init_nation(n)
		govt.ensure_heir(self, n)
		nations[tag] = n
		order.append(tag)
		provinces[n.capital].fort = 1
	_rebuild_owned()
	Religion.setup(self, data)
	monument_defs = data.get("monuments", {})
	Economy.setup(self, data)
	tree.set_unlocks(buildings_def)
	Economy.refresh_goods_leaders(self)
	Economy.update_markets(self)
	Economy.check_pacts(self)
	for tag in order:
		Economy.auto_merchants(self, nations[tag])
	Economy.update_markets(self)
	for tag in order:
		var n: Nation = nations[tag]
		_update_cached(n)
		n.manpower = n.max_manpower
		var regs: float = round(force_limit(tag) * 0.6)
		spawn_army(tag, n.capital, regs)
	Naval.start_fleets(self)
	Progression.refresh(self)
	event_defs = data.get("events", [])
	for e in event_defs:
		event_by_id[e.id] = e
	# estate crises are fired by the government module, not drawn from the yearly event pool
	for e in govt.estate_event_defs():
		event_by_id[e.id] = e
	mission_defs = data.get("missions", {})
	_apply_start_diplomacy(data.get("diplomacy", {}))
	_apply_difficulty()
	# mission targets act as permanent claims (historical expansion goals)
	for tag in mission_defs:
		if not nations.has(tag):
			continue
		for m in mission_defs[tag]:
			for key in m.get("require", {}).get("owns", []):
				var pid: int = key_to_pid.get(key, -1)
				if pid >= 0 and provinces[pid].owner != tag:
					nations[tag].claims[pid] = true


func _apply_start_diplomacy(d: Dictionary) -> void:
	hre = d.get("hre", [])
	emperor = d.get("emperor", "")
	electors = d.get("electors", [])
	hre_authority = float(govt.empire_cfg().get("authority_start", 10))
	hre_reforms = []
	for pair in d.get("alliances", []):
		_ally(pair[0], pair[1])
		add_rel(pair[0], pair[1], 60)
	for pair in d.get("rivals", []):
		add_rel(pair[0], pair[1], -60)
	var cl: Dictionary = d.get("claims", {})
	for tag in cl:
		for key in cl[tag]:
			nations[tag].claims[key_to_pid[key]] = true


func _new_ruler(n: Nation) -> void:
	var r := roll_person(n)
	n.ruler_name = r.name
	r.erase("name")
	n.ruler = r


## A random ruler or heir of `n`: adm/dip/mil, reign years and a numbered name from the nation's list.
func roll_person(n: Nation) -> Dictionary:
	var lo := int(bal.ruler_min)
	var hi := int(bal.ruler_max)
	var r := {"adm": rng.randi_range(lo, hi), "dip": rng.randi_range(lo, hi), "mil": rng.randi_range(lo, hi),
			"years": rng.randi_range(8, 35), "name": ""}
	if not n.ruler_names.is_empty():
		var base: String = n.ruler_names[rng.randi_range(0, n.ruler_names.size() - 1)]
		var num: int = n.name_counts.get(base, 0) + 1
		n.name_counts[base] = num
		r.name = "%s %s" % [base, _roman(num)]
	return r


static func _roman(v: int) -> String:
	var vals := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var r := ""
	for e in vals:
		while v >= e[0]:
			r += e[1]
			v -= e[0]
	return r


# ---------------------------------------------------------------- queries

func date_string(m: int = -1) -> String:
	if m < 0:
		m = month
	var total: int = int(bal.start_month) - 1 + m
	return "%s %d" % [MONTH_NAMES[total % 12], int(bal.start_year) + total / 12]


func year() -> int:
	return int(bal.start_year) + (int(bal.start_month) - 1 + month) / 12


func _rebuild_owned() -> void:
	owned.clear()
	for tag in nations:
		owned[tag] = []
	for p in provinces:
		owned[p.owner].append(p.id)


func provinces_of(tag: String) -> Array:
	return owned.get(tag, [])


func nation_dev(tag: String) -> int:
	var s := 0
	for pid in provinces_of(tag):
		s += provinces[pid].dev
	return s


func force_limit(tag: String) -> float:
	var n: Nation = nations[tag]
	return float(bal.base_force_limit) + n.dev_total * float(bal.force_limit_per_dev) + n.tech.mil / 2 + mod(n, "force_limit")


func armies_of(tag: String) -> Array:
	var r := []
	for a in armies:
		if a.owner == tag:
			r.append(a)
	return r


func army_regs(tag: String) -> float:
	var s := 0.0
	for a in armies:
		if a.owner == tag:
			s += a.regs
	return s


func combat_mult(tag: String) -> float:
	var n: Nation = nations[tag]
	return 1.0 + n.tech.mil * float(bal.mil_tech_combat) + mod(n, "combat")


func strength(tag: String) -> float:
	return army_regs(tag) * combat_mult(tag)


func get_rel(a: String, b: String) -> float:
	return nations[a].relations.get(b, 0.0)


func add_rel(a: String, b: String, v: float) -> void:
	for pair in [[a, b], [b, a]]:
		var n: Nation = nations[pair[0]]
		n.relations[pair[1]] = clampf(n.relations.get(pair[1], 0.0) + v, -100.0, 100.0)


## Alliance or overlord/vassal link: both mean "same side" (no war, free passage, joint wars).
func is_allied(a: String, b: String) -> bool:
	return nations[a].allies.has(b) or nations[a].overlord == b or nations[b].overlord == a


func vassals_of(tag: String) -> Array:
	var r := []
	for t in order:
		if nations[t].alive and nations[t].overlord == tag:
			r.append(t)
	return r


## The nation and its subjects (or its overlord and fellow subjects) that always fight together.
func _subject_bloc(tag: String) -> Array:
	var top: String = nations[tag].overlord if nations[tag].overlord != "" else tag
	return [top] + vassals_of(top)


func has_truce(a: String, b: String) -> bool:
	return nations[a].truces.get(b, -1) > month


func war_between(a: String, b: String) -> War:
	for w in wars:
		if (w.attackers.has(a) and w.defenders.has(b)) or (w.defenders.has(a) and w.attackers.has(b)):
			return w
	return null


func at_war(a: String, b: String) -> bool:
	return war_between(a, b) != null


func wars_of(tag: String) -> Array:
	var r := []
	for w in wars:
		if w.attackers.has(tag) or w.defenders.has(tag):
			r.append(w)
	return r


func is_at_war(tag: String) -> bool:
	return not wars_of(tag).is_empty()


func enemies_of(tag: String) -> Array:
	var r := []
	for w in wars_of(tag):
		var side: Array = w.defenders if w.attackers.has(tag) else w.attackers
		for t in side:
			if not r.has(t):
				r.append(t)
	return r


func neighbors_of(tag: String) -> Array:
	var r := []
	for pid in provinces_of(tag):
		for a in provinces[pid].adj:
			var o: String = provinces[a].owner
			if o != tag and not r.has(o):
				r.append(o)
	return r


## Nations whose territory is within `hops` provinces of tag's territory.
func nations_in_range(tag: String, hops: int) -> Array:
	var seen := {}
	var frontier: Array = provinces_of(tag).duplicate()
	for pid in frontier:
		seen[pid] = true
	for i in hops:
		var nxt := []
		for pid in frontier:
			for a in provinces[pid].adj:
				if not seen.has(a):
					seen[a] = true
					nxt.append(a)
		frontier = nxt
	var r := []
	for pid in seen:
		var o: String = provinces[pid].owner
		if o != tag and not r.has(o):
			r.append(o)
	return r


func can_enter(tag: String, pid: int) -> bool:
	var p: Province = provinces[pid]
	for t in [p.owner, p.controller]:
		if t == tag or is_allied(tag, t) or at_war(tag, t):
			return true
	return nations[tag].access.has(p.owner) and p.controller == p.owner


func find_path(tag: String, from: int, to: int) -> Array:
	if from == to:
		return [from]
	if not can_enter(tag, to):
		return []
	var prev := {from: -1}
	var queue := [from]
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for a in provinces[cur].adj:
			if prev.has(a) or not can_enter(tag, a) or not Naval.can_cross(self, tag, cur, a):
				continue
			prev[a] = cur
			if a == to:
				var path := [to]
				var c: int = cur
				while c != -1:
					path.push_front(c)
					c = prev[c]
				return path
			queue.append(a)
	return []


## Army step from a to b allowed by the sea (a strait needs the sea not ruled by an enemy fleet).
func can_cross(tag: String, a: int, b: int) -> bool:
	return Naval.can_cross(self, tag, a, b)


## Total modifier `key` of a nation: permanent mods (ideas, events, missions) plus all derived bonus sources.
func mod(n: Nation, key: String) -> float:
	var v: float = float(n.mods.get(key, 0.0))
	for src in n.bonus:
		v += float(n.bonus[src].get(key, 0.0))
	return v


func power_of(n: Nation, kind: String) -> float:
	return n.get(kind)


func monthly_power(n: Nation, kind: String) -> float:
	var v: float = float(bal.base_power) + n.ruler[kind] + mod(n, kind)
	if kind == "adm":
		v += float(bal.base_power_adm_extra)
	if n.tag == emperor and kind == "dip":
		v += float(bal.emperor_dip)
	return v


func tech_cost(tag: String, kind: String) -> float:
	var n: Nation = nations[tag]
	var lvl: int = n.tech[kind] + 1
	var expected: float = (year() - int(bal.start_year)) / float(bal.tech_years_per_level)
	var ahead: float = maxf(0.0, lvl - expected)
	return round((float(bal.tech_base) + float(bal.tech_step) * lvl) * (1.0 + ahead * float(bal.tech_ahead_penalty))
			* maxf(0.5, 1.0 + mod(n, "tech_cost")))


## Multiplier on aggressive expansion `tag` generates (techs, advisors, laws).
func ae_mult(tag: String) -> float:
	return maxf(0.2, 1.0 + mod(nations[tag], "ae_gen"))


## Months until a newly gained province of `tag` becomes a core.
func core_time(tag: String) -> int:
	return int(round(float(bal.core_months) * maxf(0.2, 1.0 + mod(nations[tag], "coring"))))


## Soft cap: above `dev_soft_cap` every further point gets `dev_over_mult` more expensive (hard cap `max_dev`).
func _dev_mult(pid: int) -> float:
	return 1.0 + maxf(0.0, provinces[pid].dev - float(bal.dev_soft_cap)) * float(bal.dev_over_mult)


func develop_cost(pid: int) -> float:
	var m: float = 1.0
	if nations.has(provinces[pid].owner):
		m = maxf(0.3, 1.0 + mod(nations[provinces[pid].owner], "develop_cost"))
	return round((float(bal.develop_base) + float(bal.develop_step) * provinces[pid].dev) * _dev_mult(pid) * m)


func score(tag: String) -> float:
	var n: Nation = nations[tag]
	if not n.alive:
		return 0.0
	return n.dev_total + n.prestige + 3.0 * (n.tech.adm + n.tech.dip + n.tech.mil)


func log_msg(text: String, tags: Array = []) -> void:
	if tags.is_empty() or tags.has(player):
		log_lines.append("%s: %s" % [date_string(), text])
		if log_lines.size() > 60:
			log_lines.pop_front()


# ---------------------------------------------------------------- tick

func tick() -> void:
	if game_over:
		return
	Economy.update_markets(self)
	for tag in order:
		var n: Nation = nations[tag]
		if n.alive:
			_economy(n)
			govt.estates_monthly(self, n)
	Naval.monthly(self)
	_armies_tick()
	_wars_tick()
	for tag in order:
		var n: Nation = nations[tag]
		if n.alive and tag != player:
			ai.think(self, n)
			if (month + tag.hash()) % 6 == 0:
				Naval.ai_build(self, n)
	if player != "" and nations[player].alive:
		ai.control_armies(self, player)
		Economy.autobuild(self, nations[player])
		for t in tree.queue_tick(self, nations[player]):
			log_msg("🔬 Forschungsplan: %s erforscht." % t, [player])
	month += 1
	if month % 12 == 0:
		_yearly()
	if month >= int(bal.total_months):
		game_over = true
		log_msg("Das Zeitalter endet. Das Spiel ist vorbei.")
	elif player != "" and not nations[player].alive:
		game_over = true


func _update_cached(n: Nation) -> void:
	n.dev_total = nation_dev(n.tag)
	Economy.refresh_building_bonus(self, n)
	var mp := 0.0
	for pid in provinces_of(n.tag):
		mp += Economy.local_manpower(self, provinces[pid])
	n.max_manpower = 3.0 + mp * (1.0 + mod(n, "manpower"))


func _economy(n: Nation) -> void:
	_update_cached(n)
	var tax := 0.0
	var prod := 0.0
	var nm: Dictionary = Economy.nation_mods(self, n)
	for pid in provinces_of(n.tag):
		var p: Province = provinces[pid]
		if p.controller != n.tag:
			continue
		var um: float = Economy.uncored_mult(self, p)
		tax += Economy.tax(self, p, nm) * um
		prod += Economy.production_value(self, p, nm) * um
		if p.core_months > 0:
			p.core_months -= 1
			if p.core_months == 0 and n.tag == player:
				log_msg("🤝 %s ist jetzt Kernland: volles Einkommen, weniger Unruhe." % p.name, [n.tag])
	n.tax_income = tax
	n.prod_income = prod
	n.trade_income = Economy.trade_income(self, n)
	n.income = n.tax_income + n.prod_income + n.trade_income
	Economy.construction_tick(self, n)
	var maint: float = army_regs(n.tag) * regiment_upkeep(n.tag) * maxf(0.2, 1.0 + mod(n, "maintenance"))
	var war := is_at_war(n.tag)
	if not war:
		maint *= float(bal.peace_maintenance_mult)
	n.we = clampf(n.we + (float(bal.we_monthly) if war else -float(bal.we_decay)), 0.0, float(bal.we_max))
	_unrest_tick(n)
	Religion.monthly(self, n)
	Monuments.tick(self, n)
	n.expenses = maint + Naval.upkeep(self, n) + Economy.upkeep(self, n.tag) + Economy.interest(self, n) + govt.budget_cost(self, n) \
			+ Economy.realm_cost(self, n)
	if n.overlord != "":
		var tribute: float = maxf(0.0, n.income * float(bal.vassal_tribute))
		n.expenses += tribute
		nations[n.overlord].gold += tribute
	n.gold += n.income - n.expenses
	var cap := float(bal.power_cap)
	n.adm = minf(cap, n.adm + monthly_power(n, "adm"))
	n.dip = minf(cap, n.dip + monthly_power(n, "dip"))
	n.mil = minf(cap, n.mil + monthly_power(n, "mil"))
	n.manpower = minf(n.max_manpower, n.manpower + n.max_manpower / (float(bal.manpower_regen_years) * 12.0))
	var decay: float = float(bal.ae_decay_per_year) * (1.0 + mod(n, "ae_decay") + 0.05 * n.tech.dip) / 12.0
	n.ae = maxf(0.0, n.ae - decay)
	if n.ae < 0.001:
		n.ae = 0.0
	for t in n.relations:
		var r: float = n.relations[t]
		if n.marriages.has(t) and r <= float(bal.marriage_rel_floor):
			n.relations[t] = maxf(r, float(bal.marriage_rel_floor))
			continue
		n.relations[t] = r - signf(r) * minf(absf(r), 0.15)
	for t in n.access.keys():
		if at_war(n.tag, t):
			n.access.erase(t)
		elif get_rel(t, n.tag) < float(bal.access_lost_rel):
			revoke_access(n.tag, t)
			log_msg("🚶 %s entzieht %s das Durchmarschrecht." % [nations[t].name, n.name], [n.tag, t])
	if n.gold < -20.0:
		stats.bankrupt_months += 1
		# bankruptcy: troops desert until the budget recovers
		var arms := armies_of(n.tag)
		if not arms.is_empty():
			arms.sort_custom(func(x, y): return x.regs > y.regs)
			arms[0].regs -= 1.0
			arms[0].full = maxf(arms[0].regs, arms[0].full - 1.0)
			if arms[0].regs < 0.5:
				armies.erase(arms[0])
			if n.tag == player:
				log_msg("💸 Bankrott! Truppen desertieren. Ein Kredit (💰 Wirtschaft) kann die Kasse retten.")
		if n.gold < -100.0:
			n.gold = -100.0


## Province unrest: uncored land and war exhaustion raise it, a garrison or suppression lowers it.
func unrest(pid: int) -> float:
	return unrest_parts(pid).total


## Realm-wide part of a province's unrest (war exhaustion, techs, laws, estates).
func unrest_base(n: Nation) -> float:
	return n.we * float(bal.unrest_per_we) + mod(n, "unrest")


## Cheap upper bound of unrest(p.id) given unrest_base of its owner: garrisons and suppression only lower it.
func unrest_bound(p: Province, base: float) -> float:
	return base + (float(bal.unrest_uncored) if p.core_months > 0 else 0.0) + Religion.unrest(self, p) \
			+ maxf(0.0, Economy.local(self, p, "unrest"))


func unrest_parts(pid: int) -> Dictionary:
	var p: Province = provinces[pid]
	var n: Nation = nations[p.owner]
	var r := {"uncored": 0.0, "war": n.we * float(bal.unrest_per_we), "garrison": 0.0, "suppressed": 0.0,
			"buildings": Economy.local(self, p, "unrest"), "religion": Religion.unrest(self, p)}
	if p.core_months > 0:
		r.uncored = float(bal.unrest_uncored)
	for a in armies:
		if a.pid == pid and a.owner == p.owner:
			r.garrison = -float(bal.unrest_garrison)
			break
	if p.suppress_months > 0:
		r.suppressed = -float(bal.unrest_suppress)
	r.estates = float(n.bonus.get("estates", {}).get("unrest", 0.0))  # angry or loyal estates
	r.policy = mod(n, "unrest") - r.estates  # techs, advisors, laws
	r.total = maxf(0.0, r.uncored + r.war + r.garrison + r.suppressed + r.policy + r.estates + r.buildings + r.religion)
	return r


func _unrest_tick(n: Nation) -> void:
	var thr := float(bal.revolt_threshold)
	var base := unrest_base(n)
	for pid in provinces_of(n.tag).duplicate():
		var p: Province = provinces[pid]
		if p.suppress_months > 0:
			p.suppress_months -= 1
		if p.controller != n.tag or unrest_bound(p, base) < thr:
			continue
		var u := unrest(pid)
		if u < thr or rng.randf() > (u - thr + 1.0) * float(bal.revolt_chance):
			continue
		_revolt(p)


func _revolt(p: Province) -> void:
	var owner: String = p.owner
	var back: String = p.prev_owner
	var can_defect: bool = back != "" and nations.has(back) and nations[back].alive and back != owner \
			and p.core_months > 0 and not at_war(owner, back) and nations[owner].overlord != back
	if can_defect:
		var borders := false
		for a in p.adj:
			if provinces[a].owner == back:
				borders = true
		can_defect = borders
	if can_defect:
		p.owner = back
		p.controller = back
		p.prev_owner = ""
		p.core_months = 0
		p.siege = 0.0
		stats.defections += 1
		_rebuild_owned()
		add_rel(owner, back, -20.0)
		for a in armies:
			if a.owner == owner and a.pid == p.id:
				a.pid = nations[owner].capital
		log_msg("🔥 %s erhebt sich gegen %s und kehrt zu %s zurück!" % [p.name, nations[owner].name, nations[back].name], [owner, back])
		_check_alive(owner)
		if not nations[owner].alive:
			stats.died_revolt = stats.get("died_revolt", 0) + 1
		return
	stats.revolts += 1
	p.dev = maxi(1, p.dev - 1)
	nations[owner].gold -= p.dev * 2.0
	p.suppress_months = 24
	log_msg("🔥 Aufstand in %s! Plünderungen kosten Entwicklung und Gold." % p.name, [owner])


## Player/AI action: troops restore order for two years.
func suppress_cost(pid: int) -> float:
	return 10.0 + provinces[pid].dev * 2.0


func suppress_unrest(tag: String, pid: int) -> String:
	var p: Province = provinces[pid]
	if p.owner != tag:
		return "Nicht deine Provinz."
	if p.suppress_months > 0:
		return "Bereits unterdrückt."
	var c := suppress_cost(pid)
	if nations[tag].mil < c:
		return "Zu wenig Militär (%d)." % int(c)
	nations[tag].mil -= c
	p.suppress_months = 24
	return ""


## Diplomatic effort to calm the people: lowers war exhaustion.
func reduce_we(tag: String) -> String:
	var n: Nation = nations[tag]
	var c := float(bal.we_reduce_cost)
	if n.we < 0.5:
		return "Keine Kriegsmüdigkeit."
	if n.dip < c:
		return "Zu wenig Diplomatie (%d)." % int(c)
	n.dip -= c
	n.we = maxf(0.0, n.we - 2.0)
	return ""


func _yearly() -> void:
	for tag in order:
		var n: Nation = nations[tag]
		if not n.alive:
			continue
		n.ruler.years -= 1
		if n.ruler.years <= 0:
			govt.succession(self, n)
			var who: String = n.ruler_name if n.ruler_name != "" else "Ein neuer Herrscher"
			log_msg("👑 %s besteigt den Thron (📜%d 🕊️%d ⚔️%d)." % [who, n.ruler.adm, n.ruler.dip, n.ruler.mil], [tag])
			_marriage_succession(n)
			if tag == emperor:
				hre_election()
		govt.yearly(self, n)
		_check_events(n)
		if tag != player:
			for m in available_missions(tag):
				if mission_ready(tag, m):
					complete_mission(tag, m.id)
	Economy.yearly(self)
	Progression.yearly(self)
	Religion.yearly(self)
	_coalitions_yearly()
	_liberty_yearly()
	_record_history()
	if emperor == "" or not nations[emperor].alive or nations[emperor].overlord != "":
		hre_election()
	govt.empire_yearly(self)


func rank_of(tag: String) -> int:
	var mine := score(tag)
	var r := 1
	for t in order:
		if t != tag and nations[t].alive and score(t) > mine:
			r += 1
	return r


func _record_history() -> void:
	if player == "" or not nations[player].alive:
		return
	history.append([year(), nations[player].dev_total, rank_of(player), provinces_of(player).size()])


# ---------------------------------------------------------------- Holy Roman Empire

func hre_members() -> Array:
	var r := []
	for t in hre:
		if nations.has(t) and nations[t].alive:
			r.append(t)
	return r


## The seven votes: listed electors while they live, refilled with the largest other members.
func current_electors() -> Array:
	var r := []
	for t in electors:
		if nations.has(t) and nations[t].alive and hre.has(t):
			r.append(t)
	var rest := hre_members().filter(func(t): return not r.has(t))
	rest.sort_custom(func(a, b): return nations[a].dev_total > nations[b].dev_total)
	while r.size() < 7 and not rest.is_empty():
		r.append(rest.pop_front())
	return r


func _vote_score(elector: String, cand: String) -> float:
	var s: float = get_rel(elector, cand) + nations[cand].dev_total * 0.15 + nations[cand].prestige * 0.3
	if is_allied(elector, cand):
		s += 30.0
	if cand == emperor:
		s += float(bal.emperor_incumbency)
	if at_war(elector, cand):
		s -= 200.0
	return s


## Who each elector would vote for right now: {elector: candidate}.
func election_votes() -> Dictionary:
	var cands := hre_members().filter(func(t): return nations[t].overlord == "")
	var votes := {}
	for e in current_electors():
		var best := ""
		var best_s := -1e9
		for c in cands:
			if c == e:
				continue
			var s := _vote_score(e, c)
			if s > best_s:
				best_s = s
				best = c
		if best != "":
			votes[e] = best
	return votes


func hre_election() -> void:
	var votes := election_votes()
	if votes.is_empty():
		return
	var count := {}
	for e in votes:
		count[votes[e]] = count.get(votes[e], 0) + 1
	var winner := ""
	for c in count:
		if winner == "" or count[c] > count[winner] or (count[c] == count[winner] and nations[c].dev_total > nations[winner].dev_total):
			winner = c
	var old := emperor
	emperor = winner
	if winner != old:
		stats.emperor_changes = stats.get("emperor_changes", 0) + 1
		if old != "":
			govt.on_new_emperor(self)
		log_msg("👑 Kaiserwahl: %s wird mit %d von %d Stimmen Kaiser des Heiligen Römischen Reiches!" % [nations[winner].name, count[winner], votes.size()],
				[winner] + ([old] if old != "" else []))
	else:
		log_msg("👑 Kaiserwahl: %s bleibt Kaiser (%d von %d Stimmen)." % [nations[winner].name, count[winner], votes.size()], [winner])


## Vassals that grow strong (or hate their overlord) break free.
func liberty(tag: String) -> float:
	var v: Nation = nations[tag]
	if v.overlord == "":
		return 0.0
	var l := strength(tag) / maxf(strength(v.overlord), 1.0)
	l += float(v.dev_total) / maxf(float(nations[v.overlord].dev_total), 1.0)
	if get_rel(tag, v.overlord) < 0.0:
		l += 0.3
	return l


func _liberty_yearly() -> void:
	for tag in order:
		var v: Nation = nations[tag]
		if not v.alive or v.overlord == "" or is_at_war(tag):
			continue
		if liberty(tag) >= float(bal.vassal_liberty_threshold) and rng.randf() < 0.25:
			var lord: String = v.overlord
			v.overlord = ""
			add_rel(tag, lord, -40.0)
			stats.independence += 1
			log_msg("🗽 %s sagt sich von %s los und ist wieder unabhängig!" % [v.name, nations[lord].name], [tag, lord])


# ---------------------------------------------------------------- armies

func spawn_army(tag: String, pid: int, regs: float) -> Army:
	var a := Army.new()
	a.id = next_army_id
	next_army_id += 1
	a.owner = tag
	a.pid = pid
	a.regs = regs
	a.full = regs
	a.power = float(bal.army_power_start) * power_max(tag)
	a.auto = tag != player or nations[tag].army_stance != ""
	if tag == player and nations[tag].army_stance != "":
		a.stance = nations[tag].army_stance
	armies.append(a)
	return a


func army_by_id(id: int) -> Army:
	for a in armies:
		if a.id == id:
			return a
	return null


func armies_in(pid: int) -> Array:
	var r := []
	for a in armies:
		if a.pid == pid:
			r.append(a)
	return r


func _armies_tick() -> void:
	Warfare.move_armies(self)
	Warfare.battles_tick(self)
	for p in provinces:
		_siege(p)
	for a in armies:
		if Warfare.in_battle(self, a):
			continue
		_reinforce(a)
		_recover_power(a)


func _side_power(arms: Array, pid: int) -> float:
	var s := 0.0
	for a in arms:
		var m := combat_mult(a.owner)
		if provinces[pid].owner == a.owner:
			m += float(bal.home_defense)
		m += float(bal.general_bonus) * a.general
		s += a.regs * m * power_factor(a)
	return s


## Fights a whole battle at once (tests); in play Warfare runs battles round by round.
func _battle(war: War, att: Array, def: Array, pid: int) -> void:
	Warfare.fight_out(self, war, att, def, pid)


func _retreat(a: Army) -> void:
	if a.regs < 0.5:
		armies.erase(a)
		return
	var best := -1
	for nb in provinces[a.pid].adj:
		var p: Province = provinces[nb]
		if p.controller == a.owner or is_allied(a.owner, p.controller):
			var hostile := false
			for o in armies_in(nb):
				if at_war(o.owner, a.owner):
					hostile = true
			if not hostile:
				best = nb
				if p.owner == a.owner:
					break
	a.path = []
	a.move = 0.0
	if best < 0:
		armies.erase(a)
		log_msg("💀 Eine Armee von %s wurde aufgerieben." % nations[a.owner].name, [a.owner])
		return
	a.pid = best
	a.target = -1


func _siege(p: Province) -> void:
	var here := armies_in(p.id)
	if here.is_empty():
		p.siege = maxf(0.0, p.siege - 10.0)
		return
	var besiegers := []
	for a in here:
		if at_war(a.owner, p.controller):
			besiegers.append(a)
	if besiegers.is_empty():
		p.siege = 0.0
		return
	for a in here:
		for b in besiegers:
			if at_war(a.owner, b.owner):
				return  # contested, battle decides first
	var regs := 0.0
	for b in besiegers:
		regs += b.regs
	var prog: float = float(bal.siege_base) * minf(regs, 20.0) / (sqrt(p.dev) + 2.0) / (1.0 + Economy.fort_level(self, p) * float(bal.fort_siege_mult))
	if Naval.is_blockaded(self, p.id):
		prog *= 1.0 + float(bal.blockade_siege)  # no supply by sea
	p.siege += prog * maxf(0.2, 1.0 + mod(nations[besiegers[0].owner], "siege"))
	if p.siege >= 100.0:
		p.siege = 0.0
		var sieger: String = besiegers[0].owner
		var old: String = p.controller
		var w := war_between(sieger, old)
		if w != null and ((w.attackers.has(sieger) and w.attackers.has(p.owner)) or (w.defenders.has(sieger) and w.defenders.has(p.owner))):
			p.controller = p.owner
		else:
			p.controller = sieger
		log_msg("🏳️ %s wurde von %s eingenommen." % [p.name, nations[p.controller].name], [sieger, old, p.owner])


## Highest fighting power of `tag`'s armies (1.0 base; techs, laws and advisors may add "army_power").
func power_max(tag: String) -> float:
	return maxf(0.5, 1.0 + mod(nations[tag], "army_power"))


## Battle multiplier from fighting power: full power x1, exhausted troops fight at army_power_floor.
func power_factor(a: Army) -> float:
	var fl := float(bal.army_power_floor)
	return fl + (1.0 - fl) * a.power


## Monthly recovery towards the maximum: full speed with supply (own or allied land, more with roads),
## slowly abroad. Modifier "army_power_regen" scales it.
func power_regen(a: Army) -> float:
	var p: Province = provinces[a.pid]
	var supplied: bool = p.controller == a.owner or is_allied(a.owner, p.controller)
	var r: float = float(bal.army_power_regen) * (1.0 if supplied else float(bal.army_power_regen_foreign))
	if supplied:
		r *= 1.0 + Economy.local(self, p, "supply") * float(bal.army_power_regen_road)
	return r * maxf(0.2, 1.0 + mod(nations[a.owner], "army_power_regen"))


func _recover_power(a: Army) -> void:
	a.power = minf(power_max(a.owner), a.power + power_regen(a))


func _reinforce(a: Army) -> void:
	if a.regs >= a.full:
		return
	var p: Province = provinces[a.pid]
	if p.controller != a.owner and not is_allied(a.owner, p.controller):
		return
	var n: Nation = nations[a.owner]
	var amt: float = minf(a.full - a.regs, minf(a.full * float(bal.reinforce_rate), n.manpower))
	if amt <= 0.0 or n.gold < 0.0:
		return
	a.regs += amt
	n.manpower -= amt
	n.gold -= amt * regiment_cost(a.owner) * 0.5


# ---------------------------------------------------------------- wars

func side_tags(w: War, attackers: bool) -> Array:
	return w.attackers if attackers else w.defenders


func is_attacker(w: War, tag: String) -> bool:
	return w.attackers.has(tag)


## War score from the attackers' point of view, -100..100.
func warscore(w: War) -> float:
	var occ_att := _occupation_pct(w.defenders, w.attackers)
	var occ_def := _occupation_pct(w.attackers, w.defenders)
	var cap_bonus := 0.0
	if w.attackers.has(provinces[nations[w.defenders[0]].capital].controller):
		cap_bonus += 10.0
	if w.defenders.has(provinces[nations[w.attackers[0]].capital].controller):
		cap_bonus -= 10.0
	return clampf(occ_att - occ_def + w.battle_score + cap_bonus, -100.0, 100.0)


func _occupation_pct(owners: Array, occupiers: Array) -> float:
	var total := 0
	var occ := 0
	for t in owners:
		for pid in provinces_of(t):
			var p: Province = provinces[pid]
			total += p.dev
			if occupiers.has(p.controller):
				occ += p.dev
	if total == 0:
		return 100.0
	return 100.0 * occ / total


func peace_cost(pids: Array) -> float:
	var s := 0.0
	for pid in pids:
		var c: float = provinces[pid].dev * float(bal.peace_cost_per_dev)
		if _is_capital(pid):
			c *= float(bal.capital_peace_mult)
		s += c
	return s


## Turning the losing war leader into a vassal costs part of the price of all its land.
func vassal_cost(w: War, for_attackers: bool) -> float:
	var target: String = side_tags(w, not for_attackers)[0]
	return peace_cost(provinces_of(target)) * float(bal.vassal_peace_mult)


## Empty string if the winning side's leader may vassalize the losing leader, otherwise the reason.
func vassal_block_reason(w: War, for_attackers: bool) -> String:
	var lead: String = side_tags(w, for_attackers)[0]
	var target: String = side_tags(w, not for_attackers)[0]
	var t: Nation = nations[target]
	if target == player:
		return "Der Spieler kann kein Vasall werden."
	if t.overlord != "":
		return "%s ist bereits Vasall." % t.name
	if nations[lead].overlord != "":
		return "Vasallen können keine Vasallen haben."
	if t.dev_total * 1.0 > nations[lead].dev_total * float(bal.vassal_max_dev_ratio):
		return "%s ist zu groß, um Vasall zu werden." % t.name
	if t.major and lead != player:
		return "Großmächte werden nicht zu KI-Vasallen."
	return ""


func _is_capital(pid: int) -> bool:
	return nations[provinces[pid].owner].capital == pid


## Provinces the given side could demand: owned by the other side, occupied by this side.
func demandable(w: War, for_attackers: bool) -> Array:
	var mine: Array = side_tags(w, for_attackers)
	var theirs: Array = side_tags(w, not for_attackers)
	var r := []
	for t in theirs:
		for pid in provinces_of(t):
			if mine.has(provinces[pid].controller):
				r.append(pid)
	return r


func _wars_tick() -> void:
	for w in wars.duplicate():
		if not wars.has(w):
			continue
		var ws := warscore(w)
		if absf(ws) >= 99.0:
			var winner_att := ws > 0
			if ai.wants_vassal(self, w, winner_att, 100.0):
				make_peace(w, winner_att, [], true)
				continue
			var pick: Array = ai.pick_demands(self, w, winner_att, 100.0)
			make_peace(w, winner_att, pick)
			continue
		if month - w.start >= int(bal.war_timeout_months):
			stats.timeouts += 1
			make_peace(w, true, [])


func declare_war(att: String, def: String, coalition_members: Array = []) -> String:
	if att == def:
		return "Ungültiges Ziel."
	if at_war(att, def):
		return "Ihr seid bereits im Krieg."
	if is_allied(att, def):
		return "Ihr seid verbündet."
	if has_truce(att, def):
		return "Es besteht ein Waffenstillstand."
	if nations[att].overlord != "" and coalition_members.is_empty():
		return "Vasallen dürfen keine Kriege erklären."
	if coalition_members.is_empty() and govt.landfriede(self, att, def):
		return "Der Ewige Landfriede verbietet Kriege zwischen Reichsmitgliedern."
	var n: Nation = nations[att]
	if n.marriages.has(def):
		end_marriage(att, def)
		log_msg("💔 %s bricht die Ehe mit %s und erklärt den Krieg." % [n.name, nations[def].name], [att, def])
	n.access.erase(def)
	nations[def].access.erase(att)
	if n.guarantees.has(def):
		n.guarantees.erase(def)
		log_msg("🛡️ %s bricht die Garantie für %s." % [n.name, nations[def].name], [att, def])
	var has_cb := coalition_members.size() > 0 or has_claim_on(att, def)
	if not has_cb:
		if n.dip < float(bal.nocb_war_dip):
			return "Zu wenig Diplomatie für einen Krieg ohne Kriegsgrund."
		n.dip -= float(bal.nocb_war_dip)
		n.ae += float(bal.ae_no_cb) * ae_mult(att)
	var w := War.new()
	w.id = next_war_id
	next_war_id += 1
	w.start = month
	w.coalition = coalition_members.size() > 0
	if w.coalition:
		w.attackers = coalition_members.duplicate()
		w.name = "Koalition gegen %s" % nations[def].name
	else:
		w.attackers = [att]
		w.name = "%s-%s-Krieg" % [nations[att].name, nations[def].name]
	w.defenders = [def]
	for ally in defenders_for(att, def):
		if not w.attackers.has(ally) and not w.defenders.has(ally):
			w.defenders.append(ally)
	if not w.coalition:
		for t in _subject_bloc(att):
			if not w.attackers.has(t) and not w.defenders.has(t):
				w.attackers.append(t)
		for ally in nations[att].allies:
			if not w.defenders.has(ally) and not is_allied(ally, def) and get_rel(att, ally) >= 20.0 and nations[ally].alive:
				w.attackers.append(ally)
	for a in w.attackers:
		for d in w.defenders:
			add_rel(a, d, -40.0)
	wars.append(w)
	stats.wars += 1
	if w.coalition:
		stats.coalition_wars += 1
	log_msg("🔥 %s: %s erklärt %s den Krieg!" % [w.name, nations[w.attackers[0]].name, nations[def].name],
			w.attackers + w.defenders)
	if def == player or w.defenders.has(player) or w.attackers.has(player):
		pass
	return ""


## Nations that would join `def` against `att`: allies, and the emperor for Holy Roman Empire members.
func defenders_for(att: String, def: String) -> Array:
	var r := []
	for t in _subject_bloc(def):
		if t != def and t != att and nations[att].overlord != t and not r.has(t):
			r.append(t)
	for ally in nations[def].allies:
		if not is_allied(ally, att) and nations[ally].alive and not has_truce(ally, att) and not r.has(ally):
			r.append(ally)
	for t in nations:
		var gn: Nation = nations[t]
		if gn.alive and gn.guarantees.has(def) and t != att and not r.has(t) and not is_allied(t, att) \
				and not has_truce(t, att) and nations[att].overlord != t:
			r.append(t)
	if emperor != "" and nations[emperor].alive and hre.has(def) and not hre.has(att) and emperor != def \
			and emperor != att and not r.has(emperor) and not is_allied(emperor, att) and not has_truce(emperor, att):
		r.append(emperor)
	# balance of power: a strong rival of the attacker protects small states next to it
	if provinces_of(def).size() <= int(bal.protect_max_provinces):
		var best := ""
		var best_str := strength(att) * float(bal.protector_min_strength)
		for t in nations_in_range(def, 1):
			if t == att or t == player or r.has(t) or not nations[t].alive or is_allied(t, att) or has_truce(t, att):
				continue
			if get_rel(t, att) > float(bal.protector_max_relation) or at_war(t, def):
				continue
			var st := strength(t)
			if st > best_str:
				best_str = st
				best = t
		if best != "":
			r.append(best)
	return r


## Who receives a ceded province: the occupier if it borders the province, otherwise a bordering winner.
func receiver_of(pid: int, winners: Array) -> String:
	var p: Province = provinces[pid]
	var bordering := []
	for t in winners:
		if not nations[t].alive:
			continue
		for a in p.adj:
			if provinces[a].owner == t:
				bordering.append(t)
				break
	if bordering.has(p.controller):
		return p.controller
	if not bordering.is_empty():
		return bordering[0]
	return p.controller if winners.has(p.controller) and nations[p.controller].alive else winners[0]


func has_claim_on(tag: String, target: String) -> bool:
	for pid in nations[tag].claims:
		if provinces[pid].owner == target:
			return true
	return false


## Ends the war. `winner_att` tells which side receives `pids`.
func make_peace(w: War, winner_att: bool, pids: Array, vassalize: bool = false) -> void:
	peace_offer_memo.erase(w.id)
	var winners: Array = side_tags(w, winner_att)
	var losers: Array = side_tags(w, not winner_att)
	var lead: String = winners[0]
	var new_vassal: String = losers[0] if vassalize else ""
	for pid in pids:
		var p: Province = provinces[pid]
		var to: String = receiver_of(pid, winners)
		var n: Nation = nations[to]
		var ae: float = p.dev * float(bal.ae_per_dev)
		if n.claims.has(pid):
			ae *= 0.6
		if _is_capital(pid):
			ae *= float(bal.capital_peace_mult)
		if w.coalition:
			ae *= 0.3
		n.ae += ae * ae_mult(to)
		n.adm -= p.dev * float(bal.core_cost_per_dev)
		n.prestige += p.dev * float(bal.prestige_per_dev_taken)
		n.claims.erase(pid)
		var old := p.owner
		p.owner = to
		p.controller = to
		p.prev_owner = old
		p.core_months = core_time(to)
		p.siege = 0.0
		if nations[old].capital == pid:
			p.fort = 0
		stats.provinces_changed += 1
	if pids.is_empty() and new_vassal == "":
		stats.white_peace += 1
	elif player != "":
		if winners.has(player):
			stats.player_wins = stats.get("player_wins", 0) + 1
		elif losers.has(player):
			stats.player_losses = stats.get("player_losses", 0) + 1
	stats.peace_deals += 1
	wars.erase(w)
	if new_vassal != "":
		_vassalize(lead, new_vassal, w.coalition)
	for a in w.attackers:
		for d in w.defenders:
			nations[a].truces[d] = month + int(bal.truce_months)
			nations[d].truces[a] = month + int(bal.truce_months)
	if w.coalition:
		for t in w.defenders:
			nations[t].ae *= 0.5
	_rebuild_owned()
	var everyone: Array = w.attackers + w.defenders
	for p in provinces:
		if everyone.has(p.owner) and p.controller != p.owner and not at_war(p.owner, p.controller):
			p.controller = p.owner
	for a in armies:
		if everyone.has(a.owner) and not can_enter(a.owner, a.pid):
			a.pid = nations[a.owner].capital
			a.target = -1
	var names := []
	for pid in pids:
		names.append(provinces[pid].name)
	if new_vassal != "":
		log_msg("⛓️ Frieden in %s: %s wird Vasall von %s." % [w.name, nations[new_vassal].name, nations[lead].name], everyone)
	elif pids.is_empty():
		log_msg("🕊️ Frieden: %s endet ohne Gebietsänderungen." % w.name, everyone)
	else:
		log_msg("🕊️ Frieden in %s: %s erhält %s." % [w.name, nations[lead].name, ", ".join(names)], everyone)
	for t in losers + winners:
		var was_alive: bool = nations[t].alive
		_check_alive(t)
		if was_alive and not nations[t].alive:
			var key := "died_primary" if (t == w.defenders[0] or t == w.attackers[0]) else "died_ally"
			if w.coalition:
				key = "died_coalition"
			stats[key] = stats.get(key, 0) + 1


## Separate peace: a war participant that does not lead its side (and is not a subject on it) leaves
## the war without territorial changes. Occupations between it and the other side end, a truce follows,
## and the side's leader resents being abandoned.
func leave_war_block_reason(tag: String, w: War) -> String:
	var att := is_attacker(w, tag)
	var side: Array = side_tags(w, att)
	if not side.has(tag):
		return "Nicht an diesem Krieg beteiligt."
	if side[0] == tag:
		return "Der Kriegsführer muss Frieden schließen."
	if side.has(nations[tag].overlord):
		return "Der Oberherr führt den Krieg."
	return ""


func leave_war(tag: String, w: War) -> String:
	var why := leave_war_block_reason(tag, w)
	if why != "":
		return why
	var att := is_attacker(w, tag)
	var leader: String = side_tags(w, att)[0]
	var others: Array = side_tags(w, not att)
	side_tags(w, att).erase(tag)
	add_rel(leader, tag, -float(bal.separate_peace_rel))
	for t in others:
		nations[tag].truces[t] = month + int(bal.truce_months)
		nations[t].truces[tag] = month + int(bal.truce_months)
	for p in provinces:
		if (p.owner == tag and others.has(p.controller)) or (others.has(p.owner) and p.controller == tag):
			p.controller = p.owner
			p.siege = 0.0
	for a in armies:
		if (a.owner == tag or others.has(a.owner)) and not can_enter(a.owner, a.pid):
			a.pid = nations[a.owner].capital
			a.target = -1
	stats.separate_peace = stats.get("separate_peace", 0) + 1
	log_msg("🕊️ %s schließt einen Separatfrieden und verlässt %s." % [nations[tag].name, w.name], [tag, leader] + others)
	return ""


func _vassalize(lord: String, tag: String, reduced_ae: bool) -> void:
	var v: Nation = nations[tag]
	var l: Nation = nations[lord]
	var ae: float = v.dev_total * float(bal.ae_per_dev) * float(bal.vassal_ae_mult)
	if reduced_ae:
		ae *= 0.3
	l.ae += ae * ae_mult(lord)
	l.prestige += v.dev_total * float(bal.prestige_per_dev_taken) * 0.5
	v.overlord = lord
	v.vassal_since = month
	v.coalition.clear()
	for ally in v.allies.duplicate():
		break_alliance(tag, ally)
	# subjects of the new vassal now serve the new overlord
	for t in order:
		if nations[t].overlord == tag:
			nations[t].overlord = lord
			nations[t].vassal_since = month
	for t in order:
		nations[t].coalition.erase(tag)
	add_rel(lord, tag, 30.0)
	stats.vassalized = stats.get("vassalized", 0) + 1


## Monthly gold the overlord receives from its vassals (display; paid in the vassals' _economy).
func tribute_income(tag: String) -> float:
	var s := 0.0
	for v in vassals_of(tag):
		s += maxf(0.0, nations[v].income * float(bal.vassal_tribute))
	return s


func annex_cost(tag: String) -> float:
	return nations[tag].dev_total * float(bal.annex_dip_per_dev)


## Annexed land must be integrated like conquered land (admin power).
func annex_adm_cost(tag: String) -> float:
	return nations[tag].dev_total * float(bal.core_cost_per_dev) * float(bal.annex_adm_mult)


func annex_months_left(tag: String) -> int:
	return maxi(0, nations[tag].vassal_since + int(bal.vassal_annex_years) * 12 - month)


## Diplomatic annexation of a vassal after `vassal_annex_years`: all land moves to the overlord.
func annex_vassal(lord: String, tag: String) -> String:
	var v: Nation = nations[tag]
	var l: Nation = nations[lord]
	if v.overlord != lord or not v.alive:
		return "%s ist nicht dein Vasall." % v.name
	if annex_months_left(tag) > 0:
		return "Erst in %d Monaten möglich." % annex_months_left(tag)
	if is_at_war(lord) or is_at_war(tag):
		return "Nicht während eines Krieges."
	var c := annex_cost(tag)
	if l.dip < c:
		return "Zu wenig Diplomatie (%d)." % int(c)
	var ac := annex_adm_cost(tag)
	if l.adm < ac:
		return "Zu wenig Verwaltung (%d)." % int(ac)
	l.dip -= c
	l.adm -= ac
	l.ae += v.dev_total * float(bal.ae_per_dev) * float(bal.annex_ae_mult) * ae_mult(lord)
	for pid in provinces_of(tag).duplicate():
		var p: Province = provinces[pid]
		p.owner = lord
		p.controller = lord
		p.prev_owner = ""
		p.core_months = core_time(lord)
		l.claims.erase(pid)
	_rebuild_owned()
	for a in armies:
		if a.owner == tag:
			a.owner = lord
			a.auto = true
	log_msg("📜 %s wird diplomatisch von %s annektiert." % [v.name, l.name], [lord, tag])
	stats.annexed = stats.get("annexed", 0) + 1
	_check_alive(tag)
	stats.died_annexed = stats.get("died_annexed", 0) + 1
	return ""


func _check_alive(tag: String) -> void:
	var n: Nation = nations[tag]
	if not n.alive or not provinces_of(tag).is_empty():
		if n.alive and provinces[n.capital].owner != tag:
			_move_capital(n)
		return
	n.alive = false
	stats.eliminated += 1
	for a in armies.duplicate():
		if a.owner == tag:
			armies.erase(a)
	for t in n.marriages:
		nations[t].marriages.erase(tag)
	n.marriages.clear()
	n.access.clear()
	n.guarantees.clear()
	for o in nations.values():
		o.access.erase(tag)
		o.guarantees.erase(tag)
	for ally in n.allies:
		nations[ally].allies.erase(tag)
	n.allies.clear()
	for w in wars.duplicate():
		w.attackers.erase(tag)
		w.defenders.erase(tag)
		if w.attackers.is_empty() or w.defenders.is_empty():
			wars.erase(w)
	for t in order:
		nations[t].coalition.erase(tag)
		if nations[t].overlord == tag:
			nations[t].overlord = ""
			log_msg("🗽 %s ist wieder unabhängig." % nations[t].name, [t])
	n.overlord = ""
	log_msg("☠️ %s hat aufgehört zu existieren." % n.name)


func _move_capital(n: Nation) -> void:
	var best := -1
	for pid in provinces_of(n.tag):
		if best < 0 or provinces[pid].dev > provinces[best].dev:
			best = pid
	if best >= 0:
		n.capital = best
		provinces[best].fort = maxi(provinces[best].fort, 1)


## Peace offer by `from` (a war leader). With `from_receives` the proposer takes `pids`,
## otherwise it hands them over. Returns true if accepted; offers to the player are queued.
func offer_peace(from: String, w: War, pids: Array, from_receives: bool = true, vassalize: bool = false) -> bool:
	var from_att := is_attacker(w, from)
	var other: String = side_tags(w, not from_att)[0]
	var ws := warscore(w) * (1.0 if from_att else -1.0)
	if vassalize:
		if not from_receives or vassal_block_reason(w, from_att) != "":
			return false
		pids = []
	if other == player:
		for o in pending_peace:
			if o.war == w.id:
				return false
		# no spam: a new offer only after the cooldown, or when the war has clearly turned further
		var memo: Dictionary = peace_offer_memo.get(w.id, {})
		if not memo.is_empty() and month - int(memo.month) < int(bal.peace_offer_cooldown) \
				and ws < float(memo.ws) + float(bal.peace_offer_ws_step):
			return false
		peace_offer_memo[w.id] = {"month": month, "ws": ws}
		pending_peace.append({"war": w.id, "from": from, "pids": pids, "from_receives": from_receives, "vassal": vassalize})
		return false
	# an exhausted receiver gives in sooner
	var ws_eff: float = ws + nations[other].we * float(bal.we_peace_factor) * (1.0 if from_receives else -1.0)
	if ai.accepts_peace(self, w, pids, ws_eff, from_receives, vassal_cost(w, from_att) if vassalize else 0.0):
		make_peace(w, from_att == from_receives, pids, vassalize)
		return true
	return false


func answer_player_peace(offer: Dictionary, accept: bool) -> void:
	pending_peace.erase(offer)
	var w := war_by_id(int(offer.war))
	if w == null:
		return
	if accept:
		make_peace(w, is_attacker(w, offer.from) == bool(offer.get("from_receives", true)), offer.pids, bool(offer.get("vassal", false)))


func war_by_id(id: int) -> War:
	for w in wars:
		if w.id == id:
			return w
	return null


# ---------------------------------------------------------------- coalitions

func _coalitions_yearly() -> void:
	var thr := float(bal.ae_coalition_threshold)
	for tag in order:
		var n: Nation = nations[tag]
		if not n.alive:
			continue
		if n.ae < thr * 0.6:
			if not n.coalition.is_empty():
				log_msg("🤝 Die Koalition gegen %s löst sich auf." % n.name, n.coalition + [tag])
			n.coalition.clear()
			continue
		if n.ae >= thr:
			for t in nations_in_range(tag, int(bal.coalition_range)):
				var o: Nation = nations[t]
				if not o.alive or n.coalition.has(t) or is_allied(t, tag) or t == player or o.overlord != "":
					continue
				if rng.randf() < 0.3 + (n.ae - thr) / thr:
					n.coalition.append(t)
					add_rel(t, tag, -30.0)
					log_msg("⚠️ %s tritt der Koalition gegen %s bei!" % [o.name, n.name], [tag, t])
		if n.coalition.size() >= 2:
			var members := []
			var cs := 0.0
			for t in n.coalition:
				if nations[t].alive and not has_truce(t, tag) and not at_war(t, tag):
					members.append(t)
					cs += strength(t)
			var mine := strength(tag)
			for ally in n.allies + vassals_of(tag):
				if not members.has(ally):
					mine += strength(ally)
			if members.size() >= 2 and cs >= mine * float(bal.coalition_strength_ratio):
				members.sort_custom(func(x, y): return strength(x) > strength(y))
				declare_war(members[0], tag, members)


## Player may join an existing coalition against a nation with high AE.
func join_coalition(tag: String, target: String) -> String:
	var t: Nation = nations[target]
	if nations[tag].overlord != "":
		return "Vasallen treten keinen Koalitionen bei."

	if t.ae < float(bal.ae_coalition_threshold):
		return "%s ist nicht bedrohlich genug (AE < %d)." % [t.name, int(bal.ae_coalition_threshold)]
	if is_allied(tag, target):
		return "Ihr seid verbündet."
	if not t.coalition.has(tag):
		t.coalition.append(tag)
		add_rel(tag, target, -30.0)
	return ""


# ---------------------------------------------------------------- actions

## Development can be paid with any of the three powers (same price), so diplomatic and
## military surplus has a use too.
func develop(tag: String, pid: int, kind: String = "adm") -> String:
	var n: Nation = nations[tag]
	var p: Province = provinces[pid]
	if p.owner != tag:
		return "Nicht deine Provinz."
	if p.dev >= int(bal.max_dev):
		return "Maximale Entwicklung erreicht."
	if not POWERS.has(kind):
		return "Unbekannte Macht."
	var c := develop_cost(pid)
	if n.get(kind) < c:
		return "Zu wenig %s (%d benötigt)." % [{"adm": "Verwaltung", "dip": "Diplomatie", "mil": "Militär"}[kind], c]
	n.set(kind, n.get(kind) - c)
	p.dev += 1
	_update_cached(n)
	return ""


## Starts a building (gold, takes months). See scripts/core/economy.gd.
func construct(tag: String, pid: int, bid: String) -> String:
	return Economy.construct(self, tag, pid, bid)


## Researches the best available tech of `kind` (AI path; the player picks in the tech screen).
func buy_tech(tag: String, kind: String) -> String:
	var n: Nation = nations[tag]
	var c := tech_cost(tag, kind)
	if n.get(kind) < c:
		return "Zu wenig Punkte (%d benötigt)." % c
	return tree.research_best(self, tag, kind)


func research(tag: String, id: String) -> String:
	return tree.research(self, tag, id)


## Armies get dearer as they modernise: recruiting and upkeep rise with military tech.
func army_cost_mult(tag: String) -> float:
	return 1.0 + nations[tag].tech.mil * float(bal.army_cost_per_mil_tech)


func regiment_cost(tag: String) -> float:
	return float(bal.regiment_cost) * army_cost_mult(tag)


func regiment_upkeep(tag: String) -> float:
	return float(bal.regiment_maintenance) * army_cost_mult(tag)


func recruit(tag: String, pid: int, count: int) -> String:
	var n: Nation = nations[tag]
	if provinces[pid].owner != tag or provinces[pid].controller != tag:
		return "Rekrutierung nur in eigenen, unbesetzten Provinzen."
	var cost: float = count * regiment_cost(tag)
	if n.gold < cost:
		return "Zu wenig Gold (%d benötigt)." % cost
	if n.manpower < count:
		return "Zu wenig Mannschaften."
	if army_regs(tag) + count > force_limit(tag) + 0.01:
		return "Truppenlimit erreicht (%d)." % int(force_limit(tag))
	n.gold -= cost
	n.manpower -= count
	for a in armies_in(pid):
		if a.owner == tag:
			# fresh troops dilute the army's fighting power
			a.power = (a.power * a.regs + float(bal.army_power_start) * power_max(tag) * count) / maxf(0.01, a.regs + count)
			a.regs += count
			a.full += count
			return ""
	spawn_army(tag, pid, count)
	return ""


## Mercenaries: up to merc_regs regiments without manpower, for merc_cost_mult × the gold, once per merc_cooldown months.
func merc_cost(tag: String) -> float:
	return float(bal.merc_regs) * regiment_cost(tag) * float(bal.merc_cost_mult)


func merc_ready_in(tag: String) -> int:
	return maxi(0, int(nations[tag].flags.get("merc_month", -9999)) + int(bal.merc_cooldown) - month)


func hire_mercs(tag: String, pid: int) -> String:
	var n: Nation = nations[tag]
	if provinces[pid].owner != tag or provinces[pid].controller != tag:
		return "Nur in eigenen, unbesetzten Provinzen."
	if merc_ready_in(tag) > 0:
		return "Neue Söldner erst in %d Monaten." % merc_ready_in(tag)
	var room: int = int(force_limit(tag) + 0.01 - army_regs(tag))
	var count: int = mini(int(bal.merc_regs), room)
	if count < 1:
		return "Truppenlimit erreicht (%d)." % int(force_limit(tag))
	var cost: float = merc_cost(tag) * count / float(bal.merc_regs)
	if n.gold < cost:
		return "Zu wenig Gold (%d benötigt)." % int(cost)
	n.gold -= cost
	n.flags["merc_month"] = month
	for a in armies_in(pid):
		if a.owner == tag:
			# fresh troops dilute the army's fighting power
			a.power = (a.power * a.regs + float(bal.army_power_start) * power_max(tag) * count) / maxf(0.01, a.regs + count)
			a.regs += count
			a.full += count
			return ""
	spawn_army(tag, pid, count)
	return ""


# ---- military and diplomatic power actions (besides tech)

## Military power: a general leads the army (+general_bonus combat strength per skill point).
func hire_general(tag: String, id: int) -> String:
	var a := army_by_id(id)
	if a == null or a.owner != tag:
		return "Keine eigene Armee."
	if a.general > 0:
		return "Die Armee hat schon einen General."
	if nations[tag].mil < float(bal.general_cost):
		return "Zu wenig Militär (%d)." % int(bal.general_cost)
	nations[tag].mil -= float(bal.general_cost)
	# better military tech, better officers
	var roll := rng.randi_range(1, 3) + (1 if rng.randf() < 0.05 * nations[tag].tech.mil else 0)
	a.general = mini(3, roll)
	return ""


## Military power: drill an army back to full morale (only on own or allied land).
func drill_cost(a: Army) -> float:
	return float(bal.drill_cost_base) + float(bal.drill_cost_per_reg) * a.regs


func drill_army(tag: String, id: int) -> String:
	var a := army_by_id(id)
	if a == null or a.owner != tag:
		return "Keine eigene Armee."
	var c: String = provinces[a.pid].controller
	if not (c == tag or is_allied(tag, c) or nations[c].overlord == tag or nations[tag].overlord == c):
		return "Drill nur auf eigenem oder verbündetem Gebiet."
	if a.power >= power_max(tag) - 0.001:
		return "Moral ist schon voll."
	var cost := drill_cost(a)
	if nations[tag].mil < cost:
		return "Zu wenig Militär (%d)." % int(cost)
	nations[tag].mil -= cost
	a.power = power_max(tag)
	return ""


## Military power: conscription fills up manpower at once (once per cooldown).
func conscript_ready_in(tag: String) -> int:
	return maxi(0, int(nations[tag].flags.get("conscript_month", -9999)) + int(bal.conscript_cooldown) - month)


func conscript_gain(tag: String) -> float:
	var n: Nation = nations[tag]
	return minf(n.max_manpower - n.manpower, n.max_manpower * float(bal.conscript_share))


func conscript(tag: String) -> String:
	var n: Nation = nations[tag]
	if conscript_ready_in(tag) > 0:
		return "Erst in %d Monaten wieder." % conscript_ready_in(tag)
	if conscript_gain(tag) < 0.5:
		return "Mannschaften sind schon voll."
	if n.mil < float(bal.conscript_cost):
		return "Zu wenig Militär (%d)." % int(bal.conscript_cost)
	n.mil -= float(bal.conscript_cost)
	n.manpower += conscript_gain(tag)
	n.flags["conscript_month"] = month
	return ""


func feast_ready_in(tag: String) -> int:
	return maxi(0, int(nations[tag].flags.get("feast_month", -9999)) + int(bal.feast_cooldown) - month)


## A court festival costs a few months of income (so it stays a real price for rich realms).
func feast_cost(tag: String) -> float:
	return maxf(float(bal.feast_min_cost), nations[tag].income * float(bal.feast_income_months))


func hold_feast(tag: String) -> String:
	var n: Nation = nations[tag]
	if feast_ready_in(tag) > 0:
		return "Erst in %d Monaten wieder." % feast_ready_in(tag)
	var c := feast_cost(tag)
	if n.gold < c:
		return "Zu wenig Gold (%d)." % int(c)
	n.gold -= c
	n.prestige += float(bal.feast_prestige)
	n.we = maxf(0.0, n.we - float(bal.feast_we))
	n.flags["feast_month"] = month
	return ""


## Diplomatic power: win over a conquered province, two years less until it becomes a core.
func integrate(tag: String, pid: int) -> String:
	var p: Province = provinces[pid]
	if p.owner != tag:
		return "Nicht deine Provinz."
	if p.core_months <= 0:
		return "Provinz ist schon eingegliedert."
	if nations[tag].dip < float(bal.integrate_cost):
		return "Zu wenig Diplomatie (%d)." % int(bal.integrate_cost)
	nations[tag].dip -= float(bal.integrate_cost)
	p.core_months = maxi(0, p.core_months - int(bal.integrate_months))
	if p.core_months == 0 and tag == player:
		log_msg("🤝 %s ist jetzt Kernland: volles Einkommen, weniger Unruhe." % p.name, [tag])
	return ""


## Diplomatic power: envoys repair the realm's reputation (less aggressive expansion).
func restore_reputation(tag: String) -> String:
	var n: Nation = nations[tag]
	if n.ae < 0.5:
		return "Kein schlechter Ruf."
	if n.dip < float(bal.reputation_cost):
		return "Zu wenig Diplomatie (%d)." % int(bal.reputation_cost)
	n.dip -= float(bal.reputation_cost)
	n.ae = maxf(0.0, n.ae - float(bal.reputation_ae))
	if n.ae < 0.001:
		n.ae = 0.0
	return ""


func disband(army: Army, count: float) -> void:
	army.regs -= count
	army.full = maxf(army.regs, army.full - count)
	if army.regs < 0.5:
		armies.erase(army)


func merge_armies(tag: String, pid: int) -> void:
	var here := []
	for a in armies_in(pid):
		if a.owner == tag and not Warfare.in_battle(self, a):
			here.append(a)
	for i in range(1, here.size()):
		var tot: float = here[0].regs + here[i].regs
		if tot > 0.0:
			here[0].power = (here[0].power * here[0].regs + here[i].power * here[i].regs) / tot
		here[0].regs += here[i].regs
		here[0].full += here[i].full
		here[0].general = maxi(here[0].general, here[i].general)
		armies.erase(here[i])


func split_army(army: Army) -> Army:
	if army.regs < 2.0:
		return null
	var half: float = floor(army.regs / 2.0)
	army.regs -= half
	army.full = maxf(army.regs, army.full - half)
	var b := spawn_army(army.owner, army.pid, half)
	b.auto = army.auto
	b.stance = army.stance
	b.power = army.power
	return b


func move_army(army: Army, pid: int) -> String:
	var b = Warfare.battle_of(self, army)
	if b != null:
		return "Die Armee steckt in der Schlacht bei %s." % provinces[b.pid].name
	var path := find_path(army.owner, army.pid, pid)
	if path.is_empty():
		var sea_why: String = Naval.crossing_block_reason(self, army.owner, army.pid, pid)
		if sea_why != "":
			return sea_why
		return "Kein Weg dorthin. Fremdes Land braucht 🚶 Durchmarschrecht (Diplomatie-Fenster des Landes)."
	if army.path.size() < 2 or path.size() < 2 or army.path[1] != path[1]:
		army.move = 0.0  # a new direction starts the step over
	army.target = pid
	army.path = path
	return ""


func improve_relations(tag: String, target: String) -> String:
	var n: Nation = nations[tag]
	var c := float(bal.improve_relation_cost)
	if n.dip < c:
		return "Zu wenig Diplomatie."
	n.dip -= c
	add_rel(tag, target, float(bal.improve_relation_amount))
	return ""


# ---- military access

func access_block_reason(tag: String, target: String) -> String:
	var n: Nation = nations[tag]
	if tag == target or not nations.has(target) or not nations[target].alive:
		return "Ungültiges Ziel."
	if n.access.has(target):
		return "Durchmarschrecht besteht schon."
	if is_allied(tag, target) or nations[target].overlord == tag:
		return "Verbündete und Vasallen lassen dich ohnehin durch."
	if at_war(tag, target):
		return "Ihr seid im Krieg."
	if n.dip < float(bal.access_cost):
		return "Zu wenig Diplomatie (%d)." % int(bal.access_cost)
	if target != player:
		if get_rel(target, tag) < float(bal.access_min_rel):
			return "%s lehnt ab (Beziehung %d, braucht %d)." % [nations[target].name, int(get_rel(target, tag)), int(bal.access_min_rel)]
		for e in enemies_of(tag):
			if is_allied(target, e) or nations[target].overlord == e:
				return "%s steht auf der Seite von %s." % [nations[target].name, nations[e].name]
	return ""


func request_access(tag: String, target: String) -> String:
	var r := access_block_reason(tag, target)
	if r != "":
		return r
	nations[tag].dip -= float(bal.access_cost)
	nations[tag].access[target] = true
	log_msg("🚶 %s gewährt %s Durchmarschrecht." % [nations[target].name, nations[tag].name], [tag, target])
	return ""


## Ends tag's right to cross target's land; its armies standing there are sent home.
func revoke_access(tag: String, target: String) -> void:
	nations[tag].access.erase(target)
	for a in armies:
		if a.owner == tag and not can_enter(tag, a.pid):
			a.pid = nations[tag].capital
			a.target = -1
			a.path = []


# ---- guarantees

func guarantee_block_reason(tag: String, target: String) -> String:
	var n: Nation = nations[tag]
	if tag == target or not nations.has(target) or not nations[target].alive:
		return "Ungültiges Ziel."
	if n.guarantees.has(target):
		return "Garantie besteht schon."
	if nations[target].overlord != "":
		return "Vasallen schützt ihr Lehnsherr."
	if at_war(tag, target):
		return "Ihr seid im Krieg."
	if n.guarantees.size() >= int(bal.max_guarantees):
		return "Höchstens %d Garantien." % int(bal.max_guarantees)
	if n.dip < float(bal.guarantee_cost):
		return "Zu wenig Diplomatie (%d)." % int(bal.guarantee_cost)
	return ""


## Tag promises to join any war declared on target. The protected state is grateful.
func guarantee(tag: String, target: String) -> String:
	var r := guarantee_block_reason(tag, target)
	if r != "":
		return r
	nations[tag].dip -= float(bal.guarantee_cost)
	nations[tag].guarantees[target] = true
	add_rel(target, tag, float(bal.guarantee_rel))
	log_msg("🛡️ %s garantiert die Unabhängigkeit von %s." % [nations[tag].name, nations[target].name], [tag, target])
	return ""


func end_guarantee(tag: String, target: String) -> void:
	if nations[tag].guarantees.erase(target):
		add_rel(target, tag, -float(bal.guarantee_rel))


# ---- royal marriages

func marriage_block_reason(tag: String, target: String) -> String:
	var n: Nation = nations[tag]
	if tag == target or not nations.has(target) or not nations[target].alive:
		return "Ungültiges Ziel."
	if n.marriages.has(target):
		return "Die Häuser sind schon verheiratet."
	if at_war(tag, target):
		return "Ihr seid im Krieg."
	if n.marriages.size() >= int(bal.max_marriages) or nations[target].marriages.size() >= int(bal.max_marriages):
		return "Höchstens %d Ehen je Haus." % int(bal.max_marriages)
	if n.dip < float(bal.marriage_cost):
		return "Zu wenig Diplomatie (%d)." % int(bal.marriage_cost)
	if target != player and get_rel(target, tag) < float(bal.marriage_min_rel):
		return "%s lehnt ab (Beziehung %d, braucht %d)." % [nations[target].name, int(get_rel(target, tag)), int(bal.marriage_min_rel)]
	return ""


func marry(tag: String, target: String) -> String:
	var r := marriage_block_reason(tag, target)
	if r != "":
		return r
	nations[tag].dip -= float(bal.marriage_cost)
	nations[tag].marriages.append(target)
	nations[target].marriages.append(tag)
	add_rel(tag, target, float(bal.marriage_rel))
	log_msg("👑 Königliche Heirat zwischen %s und %s." % [nations[tag].name, nations[target].name], [tag, target])
	return ""


func end_marriage(a: String, b: String) -> void:
	nations[a].marriages.erase(b)
	nations[b].marriages.erase(a)


## A small realm whose new ruler is related by marriage to a much stronger house may fall to it in personal union.
func _marriage_succession(n: Nation) -> void:
	if n.tag == player or n.overlord != "" or provinces_of(n.tag).size() > int(bal.marriage_union_max_provinces):
		return
	for t in n.marriages:
		var o: Nation = nations[t]
		if not o.alive or o.overlord != "" or at_war(t, n.tag) or is_at_war(n.tag):
			continue
		if strength(t) < strength(n.tag) * 2.0 or rng.randf() >= float(bal.marriage_union_chance):
			continue
		_vassalize(t, n.tag, true)
		log_msg("👑 Personalunion: Durch Erbfolge fällt %s an das Haus %s." % [n.name, o.name], [t, n.tag])
		return


func propose_alliance(tag: String, target: String) -> String:
	var n: Nation = nations[tag]
	if is_allied(tag, target):
		return "Bereits verbündet."
	if at_war(tag, target):
		return "Ihr seid im Krieg."
	if n.overlord != "" or nations[target].overlord != "":
		return "Vasallen schließen keine eigenen Bündnisse."
	if n.allies.size() >= int(bal.max_allies):
		return "Maximal %d Bündnisse." % int(bal.max_allies)
	if n.dip < float(bal.alliance_cost):
		return "Zu wenig Diplomatie."
	n.dip -= float(bal.alliance_cost)
	if target != player and not ai.accepts_alliance(self, target, tag):
		return "%s lehnt ab (Beziehung %d)." % [nations[target].name, int(get_rel(tag, target))]
	_ally(tag, target)
	log_msg("🤝 Bündnis zwischen %s und %s." % [n.name, nations[target].name], [tag, target])
	return ""


func _ally(a: String, b: String) -> void:
	if not nations[a].allies.has(b):
		nations[a].allies.append(b)
	if not nations[b].allies.has(a):
		nations[b].allies.append(a)


func break_alliance(tag: String, target: String) -> void:
	nations[tag].allies.erase(target)
	nations[target].allies.erase(tag)
	add_rel(tag, target, -30.0)


func fabricate_claim(tag: String, pid: int) -> String:
	var n: Nation = nations[tag]
	var p: Province = provinces[pid]
	if p.owner == tag:
		return "Bereits deine Provinz."
	if n.claims.has(pid):
		return "Anspruch besteht bereits."
	var borders := false
	for a in p.adj:
		if provinces[a].owner == tag:
			borders = true
	if not borders:
		return "Nur auf angrenzende Provinzen."
	if n.dip < float(bal.claim_cost):
		return "Zu wenig Diplomatie (%d)." % int(bal.claim_cost)
	n.dip -= float(bal.claim_cost)
	n.claims[pid] = true
	add_rel(tag, p.owner, -10.0)
	return ""


# ---------------------------------------------------------------- effects, events, missions

func apply_effects(tag: String, eff: Dictionary) -> void:
	var n: Nation = nations[tag]
	for k in eff:
		var v = eff[k]
		match k:
			"gold":
				n.gold += float(v)
			"adm", "dip", "mil":
				n.set(k, clampf(n.get(k) + float(v), 0.0, float(bal.power_cap)))
			"ae":
				n.ae = maxf(0.0, n.ae + float(v))
			"we":
				n.we = clampf(n.we + float(v), 0.0, float(bal.we_max))
			"prestige":
				n.prestige += float(v)
			"manpower":
				n.manpower = maxf(0.0, n.manpower + float(v))
			"regs":
				if float(v) > 0:
					var placed := false
					for a in armies_in(n.capital):
						if a.owner == tag and not placed:
							a.regs += float(v)
							a.full += float(v)
							placed = true
					if not placed:
						spawn_army(tag, n.capital, float(v))
			"dev_capital":
				var p: Province = provinces[n.capital]
				p.dev = clampi(p.dev + int(v), 1, int(bal.max_dev))
			"dev_random":
				var own := provinces_of(tag)
				for i in absi(int(v)):
					if own.is_empty():
						break
					var p: Province = provinces[own[rng.randi_range(0, own.size() - 1)]]
					p.dev = clampi(p.dev + signi(int(v)), 1, int(bal.max_dev))
			"relations":
				for t in v:
					if nations.has(t):
						add_rel(tag, t, float(v[t]))
			"claim":
				for key in v:
					var pid: int = key_to_pid.get(key, -1)
					if pid >= 0 and provinces[pid].owner != tag:
						n.claims[pid] = true
			"flag":
				n.flags[v] = true
			"mods":
				for m in v:
					n.mods[m] = n.mods.get(m, 0.0) + float(v[m])
			"ruler":
				for m in v:
					n.ruler[m] = clampi(int(n.ruler[m]) + int(v[m]), 0, 6)
			"alliance":
				if nations.has(v) and nations[v].alive and not at_war(tag, v):
					_ally(tag, v)
					add_rel(tag, v, 30.0)
			"inherit":
				_inherit(tag, v)
			"province":
				var pid: int = key_to_pid.get(v, -1)
				if pid >= 0 and provinces[pid].owner != tag and not is_at_war(provinces[pid].owner):
					var old: String = provinces[pid].owner
					provinces[pid].prev_owner = ""
					provinces[pid].owner = tag
					provinces[pid].controller = tag
					provinces[pid].core_months = int(bal.core_months)
					_rebuild_owned()
					_check_alive(old)
			"war":
				if nations.has(v) and nations[v].alive:
					n.claims[nations[v].capital] = true
					declare_war(tag, v)
			"estate":
				for es in v:
					govt.change_estate(self, n, es, float(v[es]))
			"build":
				Economy.free_level(self, tag, v)
			"army_power":
				for a in armies_of(tag):
					a.power = clampf(a.power + float(v) * power_max(tag), 0.0, power_max(tag))
			"loan":
				for i in int(v):
					Economy.take_loan(self, tag)
			"loan_forgiven":
				for i in int(v):
					if not n.loans.is_empty():
						n.loans.pop_back()
			"merc_ready":
				n.flags.erase("merc_month")
			"monument_progress":
				# months the current great work is brought forward (never finishes it outright)
				if not n.monument_build.is_empty():
					n.monument_build.months = maxi(1, int(n.monument_build.months) - int(v))
			"feast_ready":
				n.flags.erase("feast_month")
			"ships":
				# never above the fleet limit (or the current fleet, if that is already larger)
				n.ships = clampf(n.ships + float(v), 0.0, maxf(Naval.limit(self, tag), n.ships))
			"spouse_rel":
				for t in n.marriages:
					if nations.has(t):
						add_rel(tag, t, float(v))
			"convert_random":
				# provinces of another faith take up the state religion (largest first)
				var other := []
				for pid in provinces_of(tag):
					if provinces[pid].religion != n.religion:
						other.append(pid)
				other.sort_custom(func(x, y): return provinces[x].dev > provinces[y].dev)
				for i in mini(int(v), other.size()):
					provinces[other[i]].religion = n.religion
					provinces[other[i]].convert_months = 0
			"vassal":
				# event-driven vassalization (dynastic deals), only for free, independent minors
				if nations.has(v) and v != tag and v != player and nations[v].alive and nations[v].overlord == "" \
						and n.overlord == "" and not nations[v].major and not at_war(tag, v):
					_vassalize(tag, v, true)
					log_msg("⛓️ %s wird Vasall von %s." % [nations[v].name, n.name], [tag, v])
	_update_cached(n)


## Personal-union style inheritance: `heir` takes over all of `tag`'s lands.
func _inherit(heir: String, tag: String) -> void:
	if tag == player or not nations.has(tag) or not nations[tag].alive or at_war(heir, tag) or is_at_war(tag):
		return
	for pid in provinces_of(tag).duplicate():
		var p: Province = provinces[pid]
		p.owner = heir
		p.controller = heir
		p.core_months = int(bal.core_months) / 2
	for a in armies:
		if a.owner == tag:
			a.owner = heir
			a.auto = heir != player
	_rebuild_owned()
	log_msg("👑 %s erbt die Länder von %s!" % [nations[heir].name, nations[tag].name])
	stats["died_inherit"] = stats.get("died_inherit", 0) + 1
	_check_alive(tag)


func check_conditions(tag: String, c: Dictionary) -> bool:
	var n: Nation = nations[tag]
	var y := year()
	for k in c:
		var v = c[k]
		match k:
			"year_min":
				if y < int(v):
					return false
			"year_max":
				if y > int(v):
					return false
			"owns":
				for key in v:
					if provinces[key_to_pid[key]].owner != tag:
						return false
			"owns_any":
				var any := false
				for key in v:
					if provinces[key_to_pid[key]].owner == tag:
						any = true
				if not any:
					return false
			"not_owns":
				for key in v:
					if provinces[key_to_pid[key]].owner == tag:
						return false
			"at_war":
				if is_at_war(tag) != bool(v):
					return false
			"flag":
				if not n.flags.has(v):
					return false
			"not_flag":
				if n.flags.has(v):
					return false
			"min_dev":
				if n.dev_total < int(v):
					return false
			"alive":
				if not nations.has(v) or not nations[v].alive:
					return false
			"not_alive":
				if nations.has(v) and nations[v].alive:
					return false
			"ae_min":
				if n.ae < float(v):
					return false
			"gold_min":
				if n.gold < float(v):
					return false
			"allied":
				if not is_allied(tag, v):
					return false
			"tech":
				for t in v:
					if n.tech[t] < int(v[t]):
						return false
			"has_tech":
				if not n.techs.has(v):
					return false
			"estate_min":
				for es in v:
					if n.gov.estates.get(es, 50.0) < float(v[es]):
						return false
			"estate_max":
				for es in v:
					if n.gov.estates.get(es, 50.0) > float(v[es]):
						return false
			"law":
				for l in v:
					if n.gov.laws.get(l, "") != v[l]:
						return false
			"regs":
				if army_regs(tag) < float(v):
					return false
			"allies":
				if n.allies.size() < int(v):
					return false
			"at_peace":
				if is_at_war(tag):
					return false
			"major":
				if n.major != bool(v):
					return false
			"we_min":
				if n.we < float(v):
					return false
			"hre":
				if hre.has(tag) != bool(v):
					return false
			"emperor":
				if (emperor == tag) != bool(v):
					return false
			"is_vassal":
				if (n.overlord != "") != bool(v):
					return false
			"has_vassal":
				if vassals_of(tag).is_empty() == bool(v):
					return false
			"building":
				for bid in v:
					if Economy.building_total(self, tag, bid) < int(v[bid]):
						return false
			"no_building":
				if Economy.building_total(self, tag, v) > 0:
					return false
			"coastal":
				var any_coast := false
				for pid in provinces_of(tag):
					if provinces[pid].coastal:
						any_coast = true
						break
				if any_coast != bool(v):
					return false
			"produces":
				if not Economy.goods_output(self, tag).has(v):
					return false
			"goods_leader":
				var leads := false
				for k2 in goods_leader:
					if goods_leader[k2] == tag and (v is bool or k2 == v):
						leads = true
				if leads != (bool(v) if v is bool else true):
					return false
			"shock":
				# a market shock ("up" = scarce, "down" = glut) on a good this nation produces
				var hit := false
				var out := Economy.goods_output(self, tag)
				for k2 in shocks:
					if out.has(k2) and (float(shocks[k2].mult) > 1.0) == (v == "up"):
						hit = true
				if not hit:
					return false
			"loans_min":
				if n.loans.size() < int(v):
					return false
			"loans_max":
				if n.loans.size() > int(v):
					return false
			"trade_pacts_min":
				if n.trade_pacts.size() < int(v):
					return false
			"mercs_recent":
				if month - int(n.flags.get("merc_month", -9999)) > int(v):
					return false
			"morale_max":
				# some army of at least 3 regiments is worn down below this share of its maximum
				var low := false
				for a in armies_of(tag):
					if a.regs >= 3.0 and a.power < float(v) * power_max(tag):
						low = true
				if not low:
					return false
			"budget_min":
				for id in v:
					if govt.budget_step(n, id) < int(v[id]):
						return false
			"budget_max":
				for id in v:
					if govt.budget_step(n, id) > int(v[id]):
						return false
			"gold_max":
				if n.gold > float(v):
					return false
			"monument":
				if not n.monuments.has(v):
					return false
			"monuments_min":
				if n.monuments.size() < int(v):
					return false
			"monument_building":
				if n.monument_build.is_empty() == bool(v):
					return false
			"ships_min":
				if n.ships < float(v):
					return false
			"blockaded":
				var any := false
				for pid in provinces_of(tag):
					if Naval.is_blockaded(self, pid):
						any = true
						break
				if any != bool(v):
					return false
			"feast_recent":
				if month - int(n.flags.get("feast_month", -9999)) > int(v):
					return false
			"is_player":
				# flavor that would only dilute the AI's event pool (and cost it gold, see court_events.py)
				if (tag == player) != bool(v):
					return false
			"married":
				if n.marriages.is_empty() == bool(v):
					return false
			"faith_share_max":
				# at most this share of the realm's development follows the state religion
				if Religion.share(self, tag, n.religion) > float(v):
					return false
			"province_faith":
				var found := false
				for pid in provinces_of(tag):
					if provinces[pid].religion == v:
						found = true
						break
				if not found:
					return false
			"religion":
				if n.religion != str(v):
					return false
			"unrest_min":
				var top := 0.0
				for pid in provinces_of(tag):
					top = maxf(top, unrest(pid))
				if top < float(v):
					return false
	return true


func _check_events(n: Nation) -> void:
	if n.tag == player and pending_events.size() > 2:
		return
	var eligible := []
	for e in event_defs:
		var t: String = e.get("tag", "*")
		if (t != "*" and t != n.tag) or e.get("manual", false):
			continue
		if n.flags.has("ev_" + e.id):
			if e.get("once", true) or month - int(n.flags["ev_" + e.id]) < 120:
				continue
		if not check_conditions(n.tag, e.get("trigger", {})):
			continue
		eligible.append(e)
	if eligible.is_empty():
		return
	# nation specific events take priority over generic ones
	var specific := eligible.filter(func(e): return e.get("tag", "*") != "*")
	var chance := float(bal.event_chance)
	var pool: Array = eligible
	if not specific.is_empty() and rng.randf() < 0.75:
		pool = specific
		chance = minf(1.0, chance * 1.6)
	if rng.randf() > chance:
		return
	var e: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	n.flags["ev_" + e.id] = month
	stats.events += 1
	if n.tag == player:
		pending_events.append(e.id)
	else:
		apply_effects(n.tag, e.options[ai.pick_event_option(self, n, e)].get("effects", {}))


## Context events fired by game code at a fixed moment (e.g. great works), once per realm.
## They carry "manual": true and are never drawn at random.
func fire_event(tag: String, event_id: String) -> void:
	if not event_by_id.has(event_id) or not nations.has(tag) or nations[tag].flags.has("ev_" + event_id):
		return
	var n: Nation = nations[tag]
	var e: Dictionary = event_by_id[event_id]
	n.flags["ev_" + event_id] = month
	stats.events += 1
	if tag == player:
		pending_events.append(event_id)
	else:
		apply_effects(tag, e.options[ai.pick_event_option(self, n, e)].get("effects", {}))


func choose_event_option(tag: String, event_id: String, idx: int) -> void:
	pending_events.erase(event_id)
	var e: Dictionary = event_by_id[event_id]
	var opt: Dictionary = e.options[clampi(idx, 0, e.options.size() - 1)]
	apply_effects(tag, opt.get("effects", {}))


func available_missions(tag: String) -> Array:
	var r := []
	for m in mission_defs.get(tag, []):
		if nations[tag].missions_done.has(m.id):
			continue
		var pre: String = m.get("after", "")
		if pre != "" and not nations[tag].missions_done.has(pre):
			continue
		r.append(m)
	return r


func mission_ready(tag: String, m: Dictionary) -> bool:
	return check_conditions(tag, m.get("require", {}))


func complete_mission(tag: String, mission_id: String) -> String:
	for m in available_missions(tag):
		if m.id == mission_id:
			if not mission_ready(tag, m):
				return "Bedingungen nicht erfüllt."
			nations[tag].missions_done[m.id] = true
			apply_effects(tag, m.get("reward", {}))
			stats.missions += 1
			log_msg("🎯 Mission erfüllt: %s" % m.title, [tag])
			return ""
	return "Mission nicht verfügbar."


# ---------------------------------------------------------------- save / load

func to_dict() -> Dictionary:
	var d := {"month": month, "player": player, "difficulty": difficulty, "rng_state": str(rng.state), "rng_seed": str(rng.seed),
			"next_army_id": next_army_id, "next_war_id": next_war_id, "pending_events": pending_events,
			"pending_peace": pending_peace, "peace_offer_memo": peace_offer_memo, "log": log_lines, "stats": stats, "game_over": game_over, "emperor": emperor,
			"hre_authority": hre_authority, "hre_reforms": hre_reforms,
			"history": history, "prices": prices, "prev_prices": prev_prices, "shocks": shocks}
	var ps := []
	for p in provinces:
		ps.append([p.owner, p.controller, p.dev, p.core_months, p.siege, p.fort, p.prev_owner, p.suppress_months,
				p.buildings, p.constructing, p.religion, p.convert_months])
	d.provinces = ps
	var ns := {}
	for tag in order:
		var n: Nation = nations[tag]
		var cl := []
		for pid in n.claims:
			cl.append(pid)
		ns[tag] = {"alive": n.alive, "capital": n.capital, "gold": n.gold, "adm": n.adm, "dip": n.dip,
				"mil": n.mil, "ae": n.ae, "prestige": n.prestige, "manpower": n.manpower, "tech": n.tech,
				"ruler": n.ruler, "ruler_name": n.ruler_name, "name_counts": n.name_counts, "mods": n.mods, "relations": n.relations, "allies": n.allies,
				"truces": n.truces, "claims": cl, "flags": n.flags, "missions_done": n.missions_done,
				"coalition": n.coalition, "overlord": n.overlord, "vassal_since": n.vassal_since, "we": n.we,
				"merchants": n.merchants, "merchant_auto": n.merchant_auto, "army_stance": n.army_stance,
				"autobuild": n.autobuild, "autobuild_reserve": n.autobuild_reserve, "loans": n.loans, "trade_pacts": n.trade_pacts, "marriages": n.marriages, "access": n.access.keys(), "guarantees": n.guarantees.keys(), "religion": n.religion, "ships": n.ships, "fleet_sea": n.fleet_sea, "monuments": n.monuments.keys(), "monument_build": n.monument_build,
				"techs": tree.to_save(n), "tech_queue": n.tech_queue, "gov": govt.to_save(n)}
	d.nations = ns
	var ar := []
	for a in armies:
		ar.append({"id": a.id, "owner": a.owner, "pid": a.pid, "regs": a.regs, "full": a.full,
				"target": a.target, "auto": a.auto, "stance": a.stance, "power": a.power, "general": a.general,
				"move": a.move, "landing": a.landing, "path": a.path})
	d.armies = ar
	d.battles = Warfare.to_save(self)
	var ws := []
	for w in wars:
		ws.append({"id": w.id, "name": w.name, "attackers": w.attackers, "defenders": w.defenders,
				"start": w.start, "battle_score": w.battle_score, "coalition": w.coalition, "goal": w.goal})
	d.wars = ws
	return d


func from_dict(d: Dictionary) -> void:
	month = int(d.month)
	player = d.player
	set_difficulty(d.get("difficulty", "hard"))  # saves from before difficulty levels played like "hard"
	rng.seed = int(d.rng_seed)
	rng.state = int(d.rng_state)
	next_army_id = int(d.next_army_id)
	next_war_id = int(d.next_war_id)
	pending_events = d.pending_events
	peace_offer_memo = {}
	var pm: Dictionary = d.get("peace_offer_memo", {})
	for k in pm:
		peace_offer_memo[int(k)] = {"month": int(pm[k].month), "ws": float(pm[k].ws)}
	pending_peace = []
	for o in d.pending_peace:
		var pids := []
		for x in o.pids:
			pids.append(int(x))
		pending_peace.append({"war": int(o.war), "from": o.from, "pids": pids, "from_receives": o.get("from_receives", true),
				"vassal": o.get("vassal", false)})
	log_lines = d.log
	game_over = d.get("game_over", false)
	emperor = d.get("emperor", emperor)
	hre_authority = float(d.get("hre_authority", hre_authority))
	hre_reforms = []
	for id in d.get("hre_reforms", []):
		if govt.empire_by_id.has(id):
			hre_reforms.append(id)
	history = []
	for h in d.get("history", []):
		history.append([int(h[0]), int(h[1]), int(h[2]), int(h[3])])
	for k in d.stats:
		stats[k] = d.stats[k]
	for k in d.get("prices", {}):
		prices[k] = float(d.prices[k])
	for k in d.get("prev_prices", {}):
		prev_prices[k] = float(d.prev_prices[k])
	shocks = {}
	for k in d.get("shocks", {}):
		shocks[k] = {"mult": float(d.shocks[k].mult), "years": int(d.shocks[k].years)}
	for i in provinces.size():
		var e: Array = d.provinces[i]
		var p: Province = provinces[i]
		p.owner = e[0]
		p.controller = e[1]
		p.dev = int(e[2])
		p.core_months = int(e[3])
		p.siege = float(e[4])
		p.fort = int(e[5])
		p.prev_owner = e[6] if e.size() > 6 else ""
		p.suppress_months = int(e[7]) if e.size() > 7 else 0
		p.buildings = {}
		if e.size() > 8:
			for b in e[8]:
				p.buildings[b] = int(e[8][b])
		Economy.refresh_local(self, p)
		p.constructing = {}
		if e.size() > 9 and not e[9].is_empty():
			p.constructing = {"id": e[9].id, "months": int(e[9].months)}
		p.religion = str(e[10]) if e.size() > 10 else nations[p.owner].religion
		p.convert_months = int(e[11]) if e.size() > 11 else 0
	for tag in d.nations:
		var e: Dictionary = d.nations[tag]
		var n: Nation = nations[tag]
		n.alive = e.alive
		n.capital = int(e.capital)
		for k in ["gold", "adm", "dip", "mil", "ae", "prestige", "manpower"]:
			n.set(k, float(e[k]))
		for k in e.tech:
			n.tech[k] = int(e.tech[k])
		n.ruler = {}
		for k in e.ruler:
			n.ruler[k] = int(e.ruler[k])
		n.ruler_name = e.get("ruler_name", "")
		n.name_counts = {}
		for k in e.get("name_counts", {}):
			n.name_counts[k] = int(e.name_counts[k])
		n.mods = e.mods
		n.relations = e.relations
		n.allies = e.allies
		n.truces = {}
		for k in e.truces:
			n.truces[k] = int(e.truces[k])
		n.claims = {}
		for pid in e.claims:
			n.claims[int(pid)] = true
		n.flags = e.flags
		n.missions_done = e.missions_done
		n.coalition = e.coalition
		n.overlord = e.get("overlord", "")
		n.vassal_since = int(e.get("vassal_since", 0))
		n.we = float(e.get("we", 0.0))
		n.merchants = []
		for m in e.get("merchants", []):
			n.merchants.append(int(m))
		n.merchant_auto = e.get("merchant_auto", true)
		n.army_stance = e.get("army_stance", "")
		n.autobuild = bool(e.get("autobuild", false))
		n.trade_pacts = []
		for t in e.get("trade_pacts", []):
			n.trade_pacts.append(str(t))
		n.marriages = []
		for t in e.get("marriages", []):
			n.marriages.append(str(t))
		n.access = {}
		for t in e.get("access", []):
			n.access[str(t)] = true
		n.religion = str(e.get("religion", n.religion))
		n.monuments = {}
		for id in e.get("monuments", []):
			n.monuments[str(id)] = true
		var mb: Dictionary = e.get("monument_build", {})
		n.monument_build = {} if mb.is_empty() else {"id": str(mb.id), "months": int(mb.months)}
		Monuments.refresh(self, n)
		n.guarantees = {}
		for t in e.get("guarantees", []):
			n.guarantees[str(t)] = true
		n.loans = []
		for l in e.get("loans", []):
			n.loans.append(float(l))
		n.autobuild_reserve = float(e.get("autobuild_reserve", 100.0))
		n.ships = float(e.get("ships", -1.0))
		n.fleet_sea = str(e.get("fleet_sea", ""))
		tree.load_save(n, e.get("techs", {}))
		n.tech_queue = Array(e.get("tech_queue", [])).filter(func(q): return tree.by_id.has(q))
		govt.load_save(n, e.get("gov", {}))
	armies.clear()
	for e in d.armies:
		var a := Army.new()
		a.id = int(e.id)
		a.owner = e.owner
		a.pid = int(e.pid)
		a.regs = float(e.regs)
		a.full = float(e.full)
		a.target = int(e.target)
		a.auto = e.auto
		a.stance = e.get("stance", "attack")
		a.power = float(e.get("power", 1.0))
		a.general = int(e.get("general", 0))
		a.move = float(e.get("move", 0.0))
		for x in e.get("path", []):
			a.path.append(int(x))
		a.landing = e.get("landing", false)
		armies.append(a)
	wars.clear()
	for e in d.wars:
		var w := War.new()
		w.id = int(e.id)
		w.name = e.name
		w.attackers = e.attackers
		w.defenders = e.defenders
		w.start = int(e.start)
		w.battle_score = float(e.battle_score)
		w.coalition = e.coalition
		w.goal = int(e.goal)
		wars.append(w)
	Warfare.load_save(self, d.get("battles", []))
	_rebuild_owned()
	for tag in order:
		if nations[tag].ships < 0.0:  # saves from before fleets: start fleets
			nations[tag].ships = roundf(Naval.limit(self, tag) * float(bal.navy_start_share))
	Naval.refresh(self)
	for tag in order:
		nations[tag].bonus["empire"] = govt.empire_effects(self, tag) if nations[tag].alive else {}
		_update_cached(nations[tag])
	Economy.refresh_goods_leaders(self)
	Economy.update_markets(self)
	Progression.refresh(self)
	for t in order:
		Economy.refresh_pact_bonus(self, nations[t])
