extends RefCounted
## Naval war, kept abstract and readable: every coastal nation has a number of ships. They patrol the
## nation's coastal seas (spread by coastal development, or all in one sea if the player stations them).
## Seas come from data/seas.json (tools/gen_seas.py).
##
## Rules in a war, per sea and war:
## - Sea control: a side with at least sea_control_ratio times the enemy's ships there rules the sea.
## - Crossings: armies cannot cross a strait of a sea the enemy rules (no landing without a fleet).
## - Blockade: coastal provinces on a sea the enemy rules are blockaded: less income for their owner,
##   sieges there go faster (no supply by sea).
## - Fleet battles: where both sides have ships, the fleets may meet; losses as on land, war score for the winner.
## Static helpers on the game `g`.

const Economy = preload("res://scripts/core/economy.gd")
const Warfare = preload("res://scripts/core/warfare.gd")


static func setup(g, data: Dictionary) -> void:
	g.seas = []
	g.sea_by_id = {}
	g.province_seas = {}
	g.strait_sea = {}
	var sd: Dictionary = data.get("seas", {})
	for e in sd.get("seas", []):
		var s := {"id": str(e.id), "name": str(e.name), "center": Vector2(e.center[0], e.center[1]), "provinces": []}
		for key in e.provinces:
			var pid: int = g.key_to_pid.get(key, -1)
			if pid < 0:
				continue
			s.provinces.append(pid)
			if not g.province_seas.has(pid):
				g.province_seas[pid] = []
			g.province_seas[pid].append(s.id)
		g.seas.append(s)
		g.sea_by_id[s.id] = s
	var st: Dictionary = sd.get("straits", {})
	for k in st:
		var parts: PackedStringArray = str(k).split("|")
		var a: int = g.key_to_pid.get(parts[0], -1)
		var b: int = g.key_to_pid.get(parts[1], -1)
		if a >= 0 and b >= 0:
			g.strait_sea[Warfare.strait_key(a, b)] = str(st[k])


static func start_fleets(g) -> void:
	for tag in g.order:
		var n = g.nations[tag]
		n.ships = roundf(limit(g, tag) * float(g.bal.navy_start_share))
	refresh(g)


## Ship count for display: one decimal below 10 (fleets spread over several seas).
static func fmt(x: float) -> String:
	return ("%.1f" % x) if x < 9.95 else str(int(round(x)))


static func sea_name(g, sea: String) -> String:
	return g.sea_by_id[sea].name if g.sea_by_id.has(sea) else sea


static func sea_of_strait(g, a: int, b: int) -> String:
	return g.strait_sea.get(Warfare.strait_key(a, b), "")


## Own coastal development per sea: where a nation's fleet patrols, and how its ships spread.
static func coast_weights(g, tag: String) -> Dictionary:
	var w := {}
	for pid in g.provinces_of(tag):
		for s in g.province_seas.get(pid, []):
			w[s] = w.get(s, 0.0) + float(g.provinces[pid].dev)
	return w


static func limit(g, tag: String) -> float:
	var coast := 0.0
	var harbors := 0
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		if g.province_seas.has(pid):
			coast += p.dev
			harbors += Economy.level(p, "harbor")
	if coast <= 0.0:
		return 0.0
	var l: float = float(g.bal.navy_base) + coast * float(g.bal.navy_per_dev) + harbors * float(g.bal.navy_per_harbor)
	return floorf(l * maxf(0.2, 1.0 + g.mod(g.nations[tag], "naval_limit")))


static func ship_cost(g, tag: String) -> float:
	return float(g.bal.ship_cost) * maxf(0.3, 1.0 + g.mod(g.nations[tag], "ship_cost"))


static func upkeep(g, n) -> float:
	var u: float = n.ships * float(g.bal.ship_upkeep)
	return u if g.is_at_war(n.tag) else u * float(g.bal.peace_maintenance_mult)


static func build_block_reason(g, tag: String, count: int) -> String:
	var n = g.nations[tag]
	var l := limit(g, tag)
	if l <= 0.0:
		return "Du hast keine Küste."
	if n.ships + count > l + 0.001:
		return "Flottenlimit %d erreicht. Mehr Küstenentwicklung und Häfen erhöhen es." % int(l)
	if n.gold < ship_cost(g, tag) * count:
		return "Zu wenig Gold."
	if n.mil < float(g.bal.ship_mil) * count:
		return "Zu wenig Militär-Macht."
	return ""


static func build_ships(g, tag: String, count: int) -> String:
	var why := build_block_reason(g, tag, count)
	if why != "":
		return why
	var n = g.nations[tag]
	n.gold -= ship_cost(g, tag) * count
	n.mil -= float(g.bal.ship_mil) * count
	n.ships += count
	refresh(g)
	return ""


static func scrap_ships(g, tag: String, count: int) -> void:
	var n = g.nations[tag]
	n.ships = maxf(0.0, n.ships - count)
	refresh(g)


## Player choice: "" spreads the fleet over all own coastal seas, a sea id keeps it all there.
static func station(g, tag: String, sea: String) -> String:
	if sea != "" and not coast_weights(g, tag).has(sea):
		return "Keine eigene Küste an diesem Meer."
	g.nations[tag].fleet_sea = sea
	refresh(g)
	return ""


## Ships of a nation in each sea.
static func presence(g, tag: String) -> Dictionary:
	var n = g.nations[tag]
	var w := coast_weights(g, tag)
	if n.ships <= 0.0 or w.is_empty():
		return {}
	if n.fleet_sea != "" and w.has(n.fleet_sea):
		return {n.fleet_sea: n.ships}
	var tot := 0.0
	for s in w:
		tot += w[s]
	var r := {}
	for s in w:
		r[s] = n.ships * w[s] / tot
	return r


static func power_mult(g, tag: String) -> float:
	var n = g.nations[tag]
	return maxf(0.2, 1.0 + g.mod(n, "naval") + n.tech.dip * float(g.bal.naval_per_dip_tech))


## Naval strength of a war side in a sea.
static func side_power(g, tags: Array, sea: String) -> float:
	var s := 0.0
	for t in tags:
		if g.nations[t].alive:
			s += float(g._fleet.get(t, {}).get(sea, 0.0)) * power_mult(g, t)
	return s


## Who rules the sea in a war: "att", "def" or "" (contested or empty).
static func control(g, w, sea: String) -> String:
	var pa := side_power(g, w.attackers, sea)
	var pd := side_power(g, w.defenders, sea)
	var ratio := float(g.bal.sea_control_ratio)
	if pa > 0.0 and pa >= pd * ratio:
		return "att"
	if pd > 0.0 and pd >= pa * ratio:
		return "def"
	return ""


## Recomputes fleet positions, sea control, blocked seas and blockades. Call after ships change.
static func refresh(g) -> void:
	g._fleet = {}
	for tag in g.order:
		if g.nations[tag].alive:
			g._fleet[tag] = presence(g, tag)
	g.sea_blocked = {}
	g.blockaded = {}
	for w in g.wars:
		for s in g.seas:
			var c := control(g, w, s.id)
			if c == "":
				continue
			var losers: Array = w.defenders if c == "att" else w.attackers
			for t in losers:
				if not g.sea_blocked.has(t):
					g.sea_blocked[t] = {}
				g.sea_blocked[t][s.id] = true
				for pid in s.provinces:
					if g.provinces[pid].owner == t:
						g.blockaded[pid] = true
	for tag in g.order:
		var n = g.nations[tag]
		if not n.alive:
			continue
		var bdev := 0
		for pid in g.provinces_of(tag):
			if g.blockaded.has(pid):
				bdev += g.provinces[pid].dev
		if bdev > 0 and n.dev_total > 0:
			n.bonus["blockade"] = {"income": -float(g.bal.blockade_income) * float(bdev) / float(n.dev_total)}
		else:
			n.bonus.erase("blockade")


## May `tag`'s armies cross from a to b? Land steps always; straits not when the enemy rules that sea.
static func can_cross(g, tag: String, a: int, b: int) -> bool:
	if not Warfare.is_strait(g, a, b):
		return true
	var sea := sea_of_strait(g, a, b)
	return sea == "" or not g.sea_blocked.get(tag, {}).has(sea)


## Why no path exists although one would without enemy fleets ("" when the sea is not the reason).
static func crossing_block_reason(g, tag: String, from: int, to: int) -> String:
	var blocked: Dictionary = g.sea_blocked.get(tag, {})
	if blocked.is_empty() or not g.can_enter(tag, to):
		return ""
	var prev := {from: -1}
	var queue := [from]
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for a in g.provinces[cur].adj:
			if prev.has(a) or not g.can_enter(tag, a):
				continue
			prev[a] = cur
			if a == to:
				# walk back and name the first ruled sea on the way
				var c: int = a
				while prev[c] != -1:
					var sea := sea_of_strait(g, prev[c], c)
					if sea != "" and blocked.has(sea):
						return "⚓ Die feindliche Flotte beherrscht %s: keine Überfahrt. Baue Schiffe oder stationiere deine Flotte dort." % sea_name(g, sea)
					c = prev[c]
				return ""
			queue.append(a)
	return ""


static func is_blockaded(g, pid: int) -> bool:
	return g.blockaded.has(pid)


static func monthly(g) -> void:
	refresh(g)
	for w in g.wars.duplicate():
		for s in g.seas:
			var pa := side_power(g, w.attackers, s.id)
			var pd := side_power(g, w.defenders, s.id)
			if pa <= 0.0 or pd <= 0.0 or g.rng.randf() >= float(g.bal.naval_battle_chance):
				continue
			_fleet_battle(g, w, s, pa * g.rng.randf_range(0.8, 1.2), pd * g.rng.randf_range(0.8, 1.2))
	refresh(g)


static func _fleet_battle(g, w, s: Dictionary, pa: float, pd: float) -> void:
	var att_wins := pa >= pd
	var ratio: float = clampf(minf(pa, pd) / maxf(maxf(pa, pd), 0.01), 0.1, 1.0)
	var lose_frac: float = clampf(float(g.bal.naval_loss_lose) / sqrt(ratio), 0.1, 0.7)
	var win_frac: float = float(g.bal.naval_loss_win) * sqrt(ratio)
	var lost := 0.0
	var win_tags: Array = w.attackers if att_wins else w.defenders
	var lose_tags: Array = w.defenders if att_wins else w.attackers
	for t in win_tags + lose_tags:
		var here: float = g._fleet.get(t, {}).get(s.id, 0.0)
		if here <= 0.0:
			continue
		var gone: float = here * (lose_frac if lose_tags.has(t) else win_frac)
		g.nations[t].ships = maxf(0.0, g.nations[t].ships - gone)
		if lose_tags.has(t):
			lost += gone
		g.fire_event(t, "nav_first_loss" if lose_tags.has(t) else "nav_first_win")  # once per realm
	var ws: float = lost * float(g.bal.naval_ws_per_ship)
	var cap := float(g.bal.battle_ws_cap)
	w.battle_score = clampf(w.battle_score + (ws if att_wins else -ws), -cap, cap)
	g.stats.naval_battles = g.stats.get("naval_battles", 0) + 1
	var involved := win_tags + lose_tags
	if involved.has(g.player):
		g.log_msg("⚓ Seeschlacht %s: %s siegt (%.1f Schiffe des Verlierers versenkt)." % [s.name, g.nations[win_tags[0]].name, lost], [g.player])
	g._fleet = {}
	for tag in g.order:
		if g.nations[tag].alive:
			g._fleet[tag] = presence(g, tag)


## AI: keep a fleet of a share of the limit, more in war on contested seas. Cheap, every few months.
static func ai_build(g, n) -> void:
	var l := limit(g, n.tag)
	if l <= 0.0:
		return
	var want: float = l * float(g.bal.ai_navy_share_war if g.is_at_war(n.tag) else g.bal.ai_navy_share)
	var gap: int = int(floor(want - n.ships))
	if gap <= 0:
		return
	var afford: int = int(floor((n.gold - float(g.bal.ai_navy_gold_reserve)) / ship_cost(g, n.tag)))
	var count: int = mini(gap, mini(afford, int(floor(n.mil / maxf(1.0, float(g.bal.ship_mil))))))
	# only what the budget carries: the monthly surplus must cover twice the new upkeep
	var surplus: float = n.income - n.expenses
	count = mini(count, int(floor(surplus / maxf(0.01, 2.0 * float(g.bal.ship_upkeep)))))
	if count > 0:
		build_ships(g, n.tag, count)
