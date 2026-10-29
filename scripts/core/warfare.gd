extends RefCounted
## Land warfare: marches take time (distance, terrain, sea crossings), armies that meet are pinned,
## and battles last several rounds instead of one instant roll. Static helpers on the game `g`.
##
## Marching: every army builds up march progress each month (speed 1.0, more on own roads). A step
## into the next province costs months by distance and the target's terrain; a sea crossing costs
## extra. Until the step is complete the army stays where it is, so an enemy arriving there catches it.
## An army that leaves a province in the same month a hostile army enters it is caught too (no more
## armies circling past each other). Changing the next step throws the progress away.
##
## Battles: two rounds a month. Round 1 is skirmishing (less loss), then melee. Each round both sides
## lose men and battle morale by the strength ratio; a side whose morale breaks loses and is pursued.
## The side that holds the province gets its terrain's defence, troops fresh off a ship fight worse.
## Armies that march in join the fight; armies in battle cannot march away.

const Economy = preload("res://scripts/core/economy.gd")

const TERRAIN_NAMES := {
	"plains": "🌾 Ebene", "forest": "🌲 Wald", "hills": "⛰️ Hügel", "mountains": "🏔️ Gebirge",
	"desert": "🏜️ Wüste", "marsh": "💧 Sumpf",
}
const PHASES := ["Plänkeln", "Nahkampf"]


class Battle:
	var pid: int
	var war: int  # War.id
	var att: Array = []  # Army, the war's attacker side
	var def: Array = []
	var round: int = 0
	var morale_att: float = 1.0  # battle morale, the side at 0 breaks
	var morale_def: float = 1.0
	var lost_att: float = 0.0  # regiments lost so far
	var lost_def: float = 0.0
	var start: int = 0  # game month


static func setup(g, data: Dictionary) -> void:
	var t: Dictionary = data.get("terrain", {})
	for p in g.provinces:
		p.terrain = str(t.get(p.key, "plains"))
	g.straits = {}
	for s in data.get("straits", []):
		var a: int = g.key_to_pid.get(s[0], -1)
		var b: int = g.key_to_pid.get(s[1], -1)
		if a >= 0 and b >= 0:
			g.straits[strait_key(a, b)] = true


static func strait_key(a: int, b: int) -> int:
	return mini(a, b) * 10000 + maxi(a, b)


static func is_strait(g, a: int, b: int) -> bool:
	return g.straits.has(strait_key(a, b))


static func terrain(g, pid: int) -> Dictionary:
	return g.bal.terrain.get(g.provinces[pid].terrain, g.bal.terrain.plains)


static func terrain_name(g, pid: int) -> String:
	return TERRAIN_NAMES.get(g.provinces[pid].terrain, g.provinces[pid].terrain)


# ---------------------------------------------------------------- marching

## Months of march (at speed 1) from one province into its neighbour.
static func step_cost(g, from: int, to: int) -> float:
	var d: float = g.provinces[from].center.distance_to(g.provinces[to].center)
	var c: float = clampf(d / float(g.bal.march_px_per_month), float(g.bal.march_min_months), float(g.bal.march_max_months))
	c *= float(terrain(g, to).move)
	if is_strait(g, from, to):
		c += float(g.bal.strait_months)
	return c


## March progress per month. Roads on own, held land add speed; modifier "move_speed" scales it.
static func speed(g, a, from: int, to: int) -> float:
	var s: float = maxf(0.3, 1.0 + g.mod(g.nations[a.owner], "move_speed"))
	return s + road_bonus(g, a.owner, from, to)


static func road_bonus(g, tag: String, from: int, to: int) -> float:
	var pa = g.provinces[from]
	var pb = g.provinces[to]
	if pa.owner != tag or pb.owner != tag or pa.controller != tag or pb.controller != tag:
		return 0.0
	return float(g.bal.road_speed) * mini(Economy.level(pa, "road"), Economy.level(pb, "road"))


## Months until the army reaches its target (rounded up, at least 1), 0 when it stands still.
static func eta(g, a) -> int:
	if a.target < 0 or a.path.size() < 2:
		return 0
	var left: float = -a.move
	for i in a.path.size() - 1:
		left += step_cost(g, a.path[i], a.path[i + 1]) / speed(g, a, a.path[i], a.path[i + 1])
	return maxi(1, ceili(left - 0.001))


## Progress of the current step 0..1 (for the march arrow on the map).
static func step_progress(g, a) -> float:
	if a.path.size() < 2:
		return 0.0
	return clampf(a.move / maxf(0.01, step_cost(g, a.path[0], a.path[1])), 0.0, 1.0)


static func hostile_here(g, a, pid: int) -> bool:
	for o in g.armies:
		if o.pid == pid and o != a and g.at_war(o.owner, a.owner):
			return true
	return false


static func move_armies(g) -> void:
	var left := {}  # army -> province it left this month
	for a in g.armies.duplicate():
		if a.target < 0 or a.target == a.pid or in_battle(g, a):
			if a.target == a.pid:
				_stop(a)
			continue
		if a.path.size() < 2 or a.path[0] != a.pid or a.path[-1] != a.target or not g.can_enter(a.owner, a.path[1]) \
				or not g.can_cross(a.owner, a.path[0], a.path[1]):
			var old_next: int = a.path[1] if a.path.size() >= 2 else -1
			a.path = g.find_path(a.owner, a.pid, a.target)
			if a.path.size() < 2 or (old_next >= 0 and a.path[1] != old_next):
				a.move = 0.0
		if a.path.size() < 2:
			_stop(a)
			continue
		a.move += speed(g, a, a.path[0], a.path[1])
		var steps := 0
		while a.path.size() >= 2 and steps < 2:
			var cost := step_cost(g, a.path[0], a.path[1])
			if a.move < cost:
				break
			a.move -= cost
			var from: int = a.pid
			a.landing = is_strait(g, from, a.path[1])
			a.path.pop_front()
			a.pid = a.path[0]
			left[a] = from
			steps += 1
			if hostile_here(g, a, a.pid):
				a.move = 0.0  # enemy contact ends the march
				break
		if a.pid == a.target:
			_stop(a)
		else:
			# progress beyond one step does not carry (no stored-up sprints)
			a.move = minf(a.move, step_cost(g, a.path[0], a.path[1]))
	# interception: leaving a province just as a hostile army enters it does not get you away
	for a in left:
		var from: int = left[a]
		for b in left:
			if b.pid == from and left[b] != from and g.at_war(a.owner, b.owner) and a.pid != from:
				a.pid = from
				a.landing = false
				_stop(a)
				if a.owner == g.player or b.owner == g.player:
					g.log_msg("✋ %s wird bei %s von %s abgefangen." % [_army_name(g, a), g.provinces[from].name, g.nations[b.owner].name], [a.owner, b.owner])
				break


static func _stop(a) -> void:
	a.target = -1
	a.path = []
	a.move = 0.0


static func _army_name(g, a) -> String:
	return ("Deine Armee" if a.owner == g.player else "Eine Armee von " + g.nations[a.owner].name)


# ---------------------------------------------------------------- battles

static func in_battle(g, a) -> bool:
	return battle_of(g, a) != null


static func battle_of(g, a) -> Battle:
	for b in g.battles:
		if b.att.has(a) or b.def.has(a):
			return b
	return null


static func battle_at(g, pid: int) -> Battle:
	for b in g.battles:
		if b.pid == pid:
			return b
	return null


## Starts battles where hostile armies stand together and lets newcomers join running ones.
static func gather(g) -> void:
	var seen := {}
	for a in g.armies:
		seen[a.pid] = true
	for pid in seen:
		var b := battle_at(g, pid)
		var here: Array = g.armies_in(pid)
		if b == null:
			var war = null
			for x in here:
				for y in here:
					if war == null and g.at_war(x.owner, y.owner):
						war = g.war_between(x.owner, y.owner)
			if war == null:
				continue
			b = Battle.new()
			b.pid = pid
			b.war = war.id
			b.start = g.month
		var w = g.war_by_id(b.war)
		if w == null:
			continue
		var joined := false
		for x in here:
			if b.att.has(x) or b.def.has(x):
				continue
			if w.attackers.has(x.owner):
				b.att.append(x)
				joined = true
			elif w.defenders.has(x.owner):
				b.def.append(x)
				joined = true
		if b.att.is_empty() or b.def.is_empty():
			continue
		if not g.battles.has(b):
			g.battles.append(b)
			for x in b.att + b.def:
				if x.owner == g.player:
					g.log_msg("⚔️ Die Schlacht bei %s beginnt (%.0f gegen %.0f Regimenter, %s)." % [
							g.provinces[pid].name, side_regs(b.att), side_regs(b.def), terrain_name(g, pid)], [g.player])
					break
		elif joined and b.round > 0:
			for x in here:
				if x.owner == g.player:
					g.log_msg("⚔️ Verstärkung erreicht die Schlacht bei %s." % g.provinces[pid].name, [g.player])
					break


static func side_regs(arms: Array) -> float:
	var s := 0.0
	for a in arms:
		s += a.regs
	return s


## The side holding the province defends with its terrain.
static func holds(g, arms: Array, pid: int) -> bool:
	var c: String = g.provinces[pid].controller
	for a in arms:
		if a.owner == c or g.is_allied(a.owner, c):
			return true
	return false


static func side_power(g, b: Battle, attackers: bool) -> float:
	var arms: Array = b.att if attackers else b.def
	var s: float = g._side_power(arms, b.pid)
	if holds(g, arms, b.pid):
		s *= 1.0 + float(terrain(g, b.pid).defense)
	var landing := 0.0
	for a in arms:
		if a.landing:
			landing += a.regs
	var tot := side_regs(arms)
	if tot > 0.0 and b.round < int(g.bal.landing_rounds):
		s *= 1.0 - float(g.bal.landing_malus) * landing / tot
	return s


static func phase(b: Battle) -> String:
	return PHASES[mini(b.round, PHASES.size() - 1)]


## One battle round. Returns true when the battle is over.
static func fight_round(g, b: Battle) -> bool:
	var w = g.war_by_id(b.war)
	if w != null:
		b.att = b.att.filter(func(a): return g.armies.has(a) and a.pid == b.pid and w.attackers.has(a.owner))
		b.def = b.def.filter(func(a): return g.armies.has(a) and a.pid == b.pid and w.defenders.has(a.owner))
	if w == null or b.att.is_empty() or b.def.is_empty():
		return true
	var pa: float = side_power(g, b, true) * g.rng.randf_range(0.85, 1.15)
	var pd: float = side_power(g, b, false) * g.rng.randf_range(0.85, 1.15)
	var r: float = clampf(pa / maxf(pd, 0.01), 0.25, 4.0)
	var hit_def: float = pow(r, 0.75)
	var hit_att: float = pow(1.0 / r, 0.75)
	var cas: float = float(g.bal.battle_round_loss) * (float(g.bal.battle_skirmish_mult) if b.round == 0 else 1.0)
	b.lost_def += _bleed(b.def, cas * hit_def)
	b.lost_att += _bleed(b.att, cas * hit_att)
	var mor := float(g.bal.battle_round_morale)
	b.morale_def -= mor * hit_def * g.rng.randf_range(0.85, 1.15)
	b.morale_att -= mor * hit_att * g.rng.randf_range(0.85, 1.15)
	b.round += 1
	if b.morale_att > 0.0 and b.morale_def > 0.0 and b.round < int(g.bal.battle_max_rounds):
		return false
	finish(g, b, w, b.morale_att >= b.morale_def)
	return true


static func _bleed(arms: Array, frac: float) -> float:
	var lost := 0.0
	for a in arms:
		lost += a.regs * frac
		a.regs *= 1.0 - frac
	return lost


## Ends a battle: the loser is pursued (extra losses), war score, exhaustion, morale, retreat.
static func finish(g, b: Battle, war, att_wins: bool) -> void:
	g.stats.battles += 1
	var win: Array = b.att if att_wins else b.def
	var lose: Array = b.def if att_wins else b.att
	var ratio: float = clampf(side_regs(win) / maxf(side_regs(lose), 0.01), 0.5, 2.0)
	var lost: float = (b.lost_def if att_wins else b.lost_att) + _bleed(lose, float(g.bal.battle_pursuit_loss) * ratio)
	for a in win:
		a.power = maxf(0.0, a.power - g.power_max(a.owner) * float(g.bal.army_power_loss_win))
	for a in lose:
		a.power = maxf(0.0, a.power - g.power_max(a.owner) * float(g.bal.army_power_loss_lose))
	for a in win + lose:
		a.landing = false
		if a.general > 0 and g.rng.randf() < float(g.bal.general_death_chance) * (2.0 if lose.has(a) else 1.0):
			a.general = 0
			if a.owner == g.player:
				g.log_msg("⭐ Dein General bei %s ist in der Schlacht gefallen." % g.provinces[b.pid].name, [g.player])
		if a.owner == g.player and a.power < 0.3 * g.power_max(a.owner):
			g.log_msg("🔥 Deine Armee bei %s ist erschöpft (Moral %d %%). Drill (⚔️) oder Rückzug auf eigenes Land hilft." % [g.provinces[b.pid].name, int(a.power * 100)], [g.player])
	for a in lose:
		var ln = g.nations[a.owner]
		ln.we = minf(float(g.bal.we_max), ln.we + lost * float(g.bal.we_per_reg_lost) / lose.size())
	var ws: float = lost * float(g.bal.battle_ws_per_reg)
	var cap := float(g.bal.battle_ws_cap)
	war.battle_score = clampf(war.battle_score + (ws if att_wins else -ws), -cap, cap)
	if g.player != "":
		for a in win:
			if a.owner == g.player:
				g.stats.player_battles_won = g.stats.get("player_battles_won", 0) + 1
				break
		for a in lose:
			if a.owner == g.player:
				g.stats.player_battles_lost = g.stats.get("player_battles_lost", 0) + 1
				break
	var involved := []
	for a in b.att + b.def:
		involved.append(a.owner)
	var won_lost: float = b.lost_att if att_wins else b.lost_def
	g.log_msg("⚔️ Schlacht bei %s: %s siegt über %s nach %d Runden (%.1f gegen %.1f Regimenter verloren)." % [
			g.provinces[b.pid].name, g.nations[win[0].owner].name, g.nations[lose[0].owner].name, b.round, won_lost, lost], involved)
	g.battles.erase(b)
	for a in win:
		g.fire_event(a.owner, "war_first_win")
	for a in lose:
		g.fire_event(a.owner, "war_first_loss")
	if b.round >= 6:  # three months or more at 2 rounds per month
		for t in involved:
			g.fire_event(t, "war_long_battle")
	for a in lose:
		g._retreat(a)


## Fights all running battles for this month.
static func battles_tick(g) -> void:
	gather(g)
	for b in g.battles.duplicate():
		for _r in int(g.bal.battle_rounds_per_month):
			if fight_round(g, b):
				g.battles.erase(b)
				break
	# a landing only counts for the first fight after it
	for a in g.armies:
		if a.landing and not in_battle(g, a):
			a.landing = false


## Fights a battle to the end at once (tests, quick resolution).
static func fight_out(g, war, att: Array, def: Array, pid: int) -> void:
	var b := Battle.new()
	b.pid = pid
	b.war = war.id
	b.att = att.duplicate()
	b.def = def.duplicate()
	b.start = g.month
	g.battles.append(b)
	while g.battles.has(b):
		if fight_round(g, b):
			g.battles.erase(b)


static func to_save(g) -> Array:
	var r := []
	for b in g.battles:
		r.append({"pid": b.pid, "war": b.war, "att": b.att.map(func(a): return a.id), "def": b.def.map(func(a): return a.id),
				"round": b.round, "morale_att": b.morale_att, "morale_def": b.morale_def,
				"lost_att": b.lost_att, "lost_def": b.lost_def, "start": b.start})
	return r


static func load_save(g, arr: Array) -> void:
	g.battles = []
	for e in arr:
		var b := Battle.new()
		b.pid = int(e.pid)
		b.war = int(e.war)
		for id in e.att:
			var a = g.army_by_id(int(id))
			if a != null:
				b.att.append(a)
		for id in e.def:
			var a = g.army_by_id(int(id))
			if a != null:
				b.def.append(a)
		b.round = int(e.round)
		b.morale_att = float(e.morale_att)
		b.morale_def = float(e.morale_def)
		b.lost_att = float(e.lost_att)
		b.lost_def = float(e.lost_def)
		b.start = int(e.get("start", g.month))
		if not b.att.is_empty() and not b.def.is_empty():
			g.battles.append(b)
