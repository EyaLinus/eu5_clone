extends RefCounted
## AI for every nation the player does not control, plus auto-managed player armies.
## `g` is the game (scripts/core/game.gd); untyped to avoid a cyclic preload.


func think(g, n) -> void:
	g.govt.ai_think(g, n)
	_spend_power(g, n)
	_spend_gold(g, n)
	var slot: int = (g.month + n.capital) % 6
	if slot == 0:
		_diplomacy(g, n)
	elif slot == 3 and not g.is_at_war(n.tag):
		_consider_war(g, n)
	if (g.month + n.capital) % 3 == 0:
		_consider_peace(g, n)
	control_armies(g, n.tag)


# ---------------------------------------------------------------- economy

func _spend_power(g, n) -> void:
	for kind in g.POWERS:
		var c: float = g.tech_cost(n.tag, kind)
		if n.get(kind) >= c:
			g.buy_tech(n.tag, kind)
	# surplus admin goes into development of the cheapest province
	var cap := float(g.bal.power_cap)
	if n.adm > g.tech_cost(n.tag, "adm") * 1.6 or n.adm > cap * 0.8:
		var best := _cheapest_province(g, n.tag)
		if best >= 0:
			g.develop(n.tag, best)
	# keep the realm calm: suppress provinces about to revolt, calm the people when exhausted
	var thr: float = float(g.bal.revolt_threshold)
	for pid in (g.provinces_of(n.tag) if n.mil >= 30.0 else []):
		if g.provinces[pid].suppress_months == 0 and g.unrest(pid) >= thr and n.mil >= g.suppress_cost(pid) + 20.0:
			g.suppress_unrest(n.tag, pid)
	if n.we >= 6.0 and n.dip >= float(g.bal.we_reduce_cost) + 40.0:
		g.reduce_we(n.tag)
	# integrate vassals diplomatically once allowed (peace time only)
	for v in g.vassals_of(n.tag):
		# rare decision (about ai_annex_chance per year) so vassals often outlive their waiting period
		if g.annex_months_left(v) == 0 and n.dip >= g.annex_cost(v) + 20.0 and n.adm >= g.annex_adm_cost(v) + 60.0 \
				and not g.is_at_war(n.tag) and g.rng.randf() < float(g.bal.ai_annex_chance) / 12.0:
			g.annex_vassal(n.tag, v)
	if n.dip > cap * 0.7:
		_fabricate_claim(g, n)
	_power_actions(g, n, cap)


## Surplus diplomatic and military power (tech comes first): reputation, integration, conscription, drill.
func _power_actions(g, n, cap: float) -> void:
	if n.ae > 30.0 and n.dip >= float(g.bal.reputation_cost) + 50.0:
		g.restore_reputation(n.tag)
	if n.dip > cap * 0.6:
		var best := -1
		for pid in g.provinces_of(n.tag):
			if g.provinces[pid].core_months > 0 and (best < 0 or g.provinces[pid].dev > g.provinces[best].dev):
				best = pid
		if best >= 0:
			g.integrate(n.tag, best)
	_hire_general(g, n, cap)
	if not g.is_at_war(n.tag) or n.mil < 50.0:
		return
	if n.manpower < n.max_manpower * 0.2 and n.mil >= float(g.bal.conscript_cost) + 40.0:
		g.conscript(n.tag)
	for a in g.armies_of(n.tag):
		if a.power < 0.5 * g.power_max(n.tag) and n.mil >= g.drill_cost(a) + 50.0:
			if g.drill_army(n.tag, a.id) == "":
				break


## The largest army without a commander gets a general: in war as soon as military power allows,
## in peace only from a large surplus.
func _hire_general(g, n, cap: float) -> void:
	var need: float = float(g.bal.general_cost) + (30.0 if g.is_at_war(n.tag) else cap * 0.3)
	if n.mil < need:
		return
	var best = null
	for a in g.armies_of(n.tag):
		if a.general == 0 and a.regs >= 3.0 and (best == null or a.regs > best.regs):
			best = a
	if best != null:
		g.hire_general(n.tag, best.id)


func _cheapest_province(g, tag: String) -> int:
	var best := -1
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		if p.dev >= int(g.bal.max_dev) or p.controller != tag:
			continue
		if best < 0 or p.dev < g.provinces[best].dev:
			best = pid
	return best


func _spend_gold(g, n) -> void:
	var tag: String = n.tag
	var fl: float = g.force_limit(tag)
	var regs: float = g.army_regs(tag)
	var war: bool = g.is_at_war(tag)
	var want: float = fl if war else fl * 0.75
	# never plan an army the treasury cannot pay for (small states would go bankrupt and desert)
	var upkeep: float = g.regiment_upkeep(tag) * (1.0 if war else float(g.bal.peace_maintenance_mult))
	var affordable: float = maxf(1.0, n.income * (0.85 if war else 0.7) / maxf(upkeep, 0.001))
	want = minf(want, affordable)
	var Eco = g.Economy
	# loans bridge a war chest gap; pay them back in peace when the treasury allows
	if war and n.gold < 0.0 and n.loans.size() < 2 and n.income > n.expenses * 0.6:
		Eco.take_loan(g, tag)
	elif not war and not n.loans.is_empty() and n.gold > float(n.loans[n.loans.size() - 1]) + 40.0:
		Eco.repay_loan(g, tag)
	if n.gold < -5.0 or (not war and regs > minf(fl, affordable) + 1.0):
		var arms: Array = g.armies_of(tag)
		if not arms.is_empty():
			arms.sort_custom(func(x, y): return x.regs > y.regs)
			g.disband(arms[0], 1.0)
		return
	var cost: float = g.regiment_cost(tag)
	var reserve: float = 10.0 + n.expenses * 4.0
	var k: int = int(minf(minf((n.gold - reserve) / cost, want - regs), n.manpower))
	# out of manpower in a war: hire mercenaries if the chest allows
	if war and n.manpower < 1.0 and regs < want - 2.0 and n.gold >= g.merc_cost(tag) + reserve and g.merc_ready_in(tag) == 0 \
			and g.provinces[n.capital].controller == tag:
		g.hire_mercs(tag, n.capital)
		return
	if k >= 1:
		var where: int = n.capital
		if g.provinces[where].controller != tag:
			where = -1
			for pid in g.provinces_of(tag):
				if g.provinces[pid].controller == tag:
					where = pid
					break
		if where >= 0:
			g.recruit(tag, where, k)
		return
	# surplus gold goes into buildings (best value per gold first)
	if (g.month + n.capital) % 3 != 0:
		return
	var margin: float = 20.0 if (not war and regs >= want - 1.0) else 120.0
	if n.gold > reserve + margin + _cheapest_building_cost(g, n):  # else nothing affordable: skip the expensive search
		for i in 3:
			var best: Array = g.Economy.best_building(g, n, war)
			if best.is_empty() or n.gold <= g.Economy.building_cost(g, tag, best[0], best[1]) + reserve + margin:
				break
			g.construct(tag, best[0], best[1])
	if not war:
		_peace_spending(g, n, reserve + margin)


## Gold left after army and buildings: missionaries for unrest, a feast against war exhaustion,
## then great works (the late-game sink for rich realms).
func _peace_spending(g, n, keep: float) -> void:
	var tag: String = n.tag
	var Rel = g.Religion
	if Rel.missionaries(g, tag) < int(g.bal.max_missionaries):
		var target := -1
		for pid in g.provinces_of(tag):
			var p = g.provinces[pid]
			if p.religion != n.religion and (target < 0 or p.dev > g.provinces[target].dev) \
					and Rel.convert_block_reason(g, tag, pid) == "":
				target = pid
		if target >= 0 and n.gold > Rel.convert_cost(g, g.provinces[target]) + keep:
			Rel.send_missionary(g, tag, target)
	if n.we >= float(g.bal.feast_we) and g.feast_ready_in(tag) == 0 and n.gold > g.feast_cost(tag) + keep:
		g.hold_feast(tag)
	if not n.monument_build.is_empty():
		return
	var M = g.Monuments
	var best := ""
	for id in g.monument_defs:
		if M.block_reason(g, tag, id) == "" and n.gold > M.cost(g, tag, id) * float(g.bal.ai_monument_gold_mult) + keep \
				and (best == "" or M.cost(g, tag, id) < M.cost(g, tag, best)):
			best = id
	if best != "":
		M.start(g, tag, best)


## Lower bound for any building cost of `n` (Economy.building_cost never goes below it).
func _cheapest_building_cost(g, n) -> float:
	var c := 1e9
	for bid in g.buildings_def:
		c = minf(c, float(g.buildings_def[bid].cost))
	return c * float(g.bal.building_cost_mult) * maxf(0.3, 1.0 + g.mod(n, "build_cost")) - 1.0


# ---------------------------------------------------------------- diplomacy

func _fabricate_claim(g, n) -> void:
	var best := -1
	var best_score := -1e9
	for pid in g.provinces_of(n.tag):
		for a in g.provinces[pid].adj:
			var p = g.provinces[a]
			if p.owner == n.tag or n.claims.has(a) or g.is_allied(n.tag, p.owner):
				continue
			var s: float = p.dev - g.strength(p.owner) * 0.2
			if s > best_score:
				best_score = s
				best = a
	if best >= 0:
		g.fabricate_claim(n.tag, best)


func _diplomacy(g, n) -> void:
	var tag: String = n.tag
	if n.overlord != "":
		if n.dip >= float(g.bal.improve_relation_cost) + 30.0 and g.get_rel(tag, n.overlord) < 50.0:
			g.improve_relations(tag, n.overlord)
		return
	for ally in n.allies.duplicate():
		if g.get_rel(tag, ally) < -30.0:
			g.break_alliance(tag, ally)
	_trade_pact(g, n)
	_marriage(g, n)
	_war_access(g, n)
	_guarantee(g, n)
	if n.allies.size() >= 2:
		return
	var best := ""
	var best_score := -1e9
	for t in g.nations_in_range(tag, 4):
		var o = g.nations[t]
		if not o.alive or g.is_allied(tag, t) or g.at_war(tag, t) or t == g.player or o.overlord != "":
			continue
		if g.has_claim_on(tag, t) or g.has_claim_on(t, tag):
			continue
		var s: float = g.get_rel(tag, t) + g.strength(t) * 0.5
		if s > best_score:
			best_score = s
			best = t
	if best == "":
		return
	if n.dip >= float(g.bal.alliance_cost) and accepts_alliance(g, best, tag):
		g.propose_alliance(tag, best)
	elif n.dip >= float(g.bal.improve_relation_cost) + 30.0:
		g.improve_relations(tag, best)


## Now and then a trade agreement with the friendliest neighbor that accepts.
func _trade_pact(g, n) -> void:
	if n.trade_pacts.size() >= 2 or n.dip < float(g.bal.trade_pact_cost) + 60.0 or g.rng.randf() > 0.1:
		return
	var best := ""
	var best_rel := -1e9
	for t in g.nations_in_range(n.tag, 4):
		if t == g.player or g.Economy.pact_block_reason(g, n.tag, t) != "" or not g.Economy.accepts_pact(g, t, n.tag):
			continue
		var r: float = g.get_rel(n.tag, t)
		if r > best_rel:
			best_rel = r
			best = t
	if best != "":
		g.Economy.offer_pact(g, n.tag, best)


## Now and then a royal marriage with a friendly house nearby, allies first.
func _marriage(g, n) -> void:
	if n.marriages.size() >= int(g.bal.ai_max_marriages) or n.dip < float(g.bal.marriage_cost) + 60.0 \
			or g.rng.randf() > float(g.bal.ai_marriage_chance):
		return
	var best := ""
	var best_score := -1e9
	for t in g.nations_in_range(n.tag, 4):
		if t == g.player or g.marriage_block_reason(n.tag, t) != "":
			continue
		var s: float = g.get_rel(t, n.tag) + (30.0 if n.allies.has(t) else 0.0)
		if s > best_score:
			best_score = s
			best = t
	if best != "":
		g.marry(n.tag, best)


## In war, ask a neutral neighbour for military access when an enemy can only be reached through its land.
func _war_access(g, n) -> void:
	if not g.is_at_war(n.tag) or n.dip < float(g.bal.access_cost) + 20.0:
		return
	var mine: Array = g.neighbors_of(n.tag)
	for e in g.enemies_of(n.tag):
		if mine.has(e):
			continue
		for t in mine:
			if g.neighbors_of(t).has(e) and g.access_block_reason(n.tag, t) == "":
				g.request_access(n.tag, t)
				return


## A great power now and then guarantees a small friendly neighbour (keeps minors alive, buys influence).
func _guarantee(g, n) -> void:
	if not n.major or n.guarantees.size() >= int(g.bal.ai_max_guarantees) \
			or n.dip < float(g.bal.guarantee_cost) + 80.0 or g.rng.randf() > float(g.bal.ai_guarantee_chance):
		return
	var best := ""
	var best_score := -1e9
	for t in g.nations_in_range(n.tag, 2):
		if t == g.player or g.nations[t].major or g.provinces_of(t).size() > int(g.bal.protect_max_provinces):
			continue
		if g.has_claim_on(n.tag, t) or g.guarantee_block_reason(n.tag, t) != "":
			continue
		var rel: float = g.get_rel(n.tag, t)
		if rel < 10.0:
			continue
		var s: float = rel
		for nb in g.neighbors_of(t):
			if nb != n.tag and g.strength(nb) > g.strength(t) * 3.0:
				s += 20.0  # threatened by a strong neighbour
				break
		if s > best_score:
			best_score = s
			best = t
	if best != "":
		g.guarantee(n.tag, best)


func accepts_alliance(g, target: String, from: String) -> bool:
	var t = g.nations[target]
	if t.allies.size() >= int(g.bal.max_allies):
		return false
	if g.has_claim_on(from, target) or g.has_claim_on(target, from):
		return false
	var s: float = g.get_rel(target, from)
	var my_str: float = g.strength(target)
	for nb in g.neighbors_of(target):
		if nb != from and g.strength(nb) > my_str and g.neighbors_of(from).has(nb):
			s += 25.0
			break
	if g.strength(from) > my_str * 1.5:
		s += 10.0
	if g.nations[from].ae > float(g.bal.ae_coalition_threshold):
		s -= 40.0
	return s >= 25.0


func _consider_war(g, n) -> void:
	var tag: String = n.tag
	var ae_cap: float = float(g.bal.ae_coalition_threshold) * float(g.bal.ai_ae_limit)
	if (n.ae > ae_cap and not n.flags.has("bot_ignore_ae")) or n.gold < 0.0 or n.overlord != "":
		return
	if n.we > float(g.bal.we_max) * 0.4:
		return
	if n.adm < float(g.bal.core_cost_per_dev) * 8.0:
		return
	var aggression: float = n.aggression * g.diff("ai_aggression")
	if g.rng.randf() > float(g.bal.ai_war_chance) * aggression:
		return
	var best := ""
	var best_score := 0.0
	for t in g.neighbors_of(tag):
		var o = g.nations[t]
		if not o.alive or g.is_allied(tag, t) or g.has_truce(tag, t) or g.at_war(tag, t) or g.govt.landfriede(g, tag, t):
			continue
		var claim: bool = g.has_claim_on(tag, t)
		if not claim and n.dip < float(g.bal.nocb_war_dip) + 10.0:
			continue
		var ratio := war_odds(g, tag, t)
		var need: float = float(g.bal.ai_war_ratio) / aggression * (0.85 if claim else 1.0)
		if t == g.player:
			need /= g.diff("ai_vs_player")
		if ratio < need:
			continue
		var s: float = ratio + (1.0 if claim else 0.0)
		if s > best_score:
			best_score = s
			best = t
	if best != "":
		g.declare_war(tag, best)


## Expected strength ratio of a war `tag` declares on `t`, with the same sides declare_war builds:
## only allies that will really join count (not those allied to or defending `t`), at 70 %.
func war_odds(g, tag: String, t: String) -> float:
	var defs: Array = g.defenders_for(tag, t)
	var theirs: float = g.strength(t)
	for d in defs:
		theirs += g.strength(d)
	var mine: float = 0.0
	for v in g.vassals_of(tag):
		if not defs.has(v):
			mine += g.strength(v)
	mine += g.strength(tag)
	for ally in g.nations[tag].allies:
		if not defs.has(ally) and not g.is_allied(ally, t) and g.get_rel(tag, ally) >= 20.0 and g.nations[ally].alive:
			mine += g.strength(ally) * 0.7
	return mine / maxf(theirs, 0.5)


# ---------------------------------------------------------------- peace

func _consider_peace(g, n) -> void:
	# war-weary nations look for a way out: exhaustion turns into revolts at home
	var tired: bool = n.we >= float(g.bal.we_max) * float(g.bal.ai_tired_we)
	for w in g.wars_of(n.tag).duplicate():
		if not g.wars.has(w):
			continue
		var att: bool = g.is_attacker(w, n.tag)
		var ws: float = g.warscore(w) * (1.0 if att else -1.0)
		var dur: int = g.month - w.start
		if g.side_tags(w, att)[0] != n.tag:
			# an exhausted ally bails out of a war that is not going its way
			if tired and dur > 12 and ws < 10.0 and g.leave_war_block_reason(n.tag, w) == "":
				g.leave_war(n.tag, w)
			continue
		if ws >= 25.0 or (ws >= 8.0 and (dur > 36 or tired)):
			if wants_vassal(g, w, att, ws):
				g.offer_peace(n.tag, w, [], true, true)
				continue
			var pids := pick_demands(g, w, att, ws)
			if not pids.is_empty():
				g.offer_peace(n.tag, w, pids, true)
				continue
		if ws <= (-15.0 if tired else -30.0) and dur > 12:
			var give := pick_demands(g, w, not att, -ws * 0.8)
			if not give.is_empty():
				g.offer_peace(n.tag, w, give, false)
				continue
		if (dur > 48 and absf(ws) < 15.0) or (tired and dur > 12 and ws > -15.0 and ws < 25.0):
			g.offer_peace(n.tag, w, [], true)


## Small beaten states become vassals instead of being carved up (keeps the map alive, less AE).
func wants_vassal(g, w, for_att: bool, budget: float) -> bool:
	if g.side_tags(w, for_att)[0] == g.player or g.vassal_block_reason(w, for_att) != "":
		return false
	var target: String = g.side_tags(w, not for_att)[0]
	if g.provinces_of(target).size() > int(g.bal.ai_vassal_max_provinces):
		return false
	return g.vassal_cost(w, for_att) <= budget


func pick_demands(g, w, for_att: bool, budget: float) -> Array:
	var winners: Array = g.side_tags(w, for_att)
	var lead: String = winners[0]
	var cands: Array = g.demandable(w, for_att)
	var scored := []
	for pid in cands:
		var p = g.provinces[pid]
		# plausibility rule: the AI never annexes the capital of a playable great power
		var owner_n = g.nations[p.owner]
		if owner_n.major and owner_n.capital == pid and lead != g.player:
			continue
		var s: float = p.dev
		var to: String = g.receiver_of(pid, winners)
		if g.nations[to].claims.has(pid):
			s += 15.0
		for a in p.adj:
			if g.provinces[a].owner == to:
				s += 10.0
				break
		scored.append([s, pid])
	scored.sort_custom(func(x, y): return x[0] > y[0])
	# taking land costs admin power (integration); never demand more than the receiver can digest
	var adm_left := {}
	var core_cost := float(g.bal.core_cost_per_dev)
	var r := []
	var spent := 0.0
	for e in scored:
		var p = g.provinces[e[1]]
		var to: String = g.receiver_of(e[1], winners)
		if not adm_left.has(to):
			adm_left[to] = g.nations[to].adm + 60.0
		var c: float = g.peace_cost([e[1]])
		var ac: float = p.dev * core_cost
		if spent + c <= budget and (ac <= adm_left[to] or to == g.player):
			r.append(e[1])
			spent += c
			adm_left[to] -= ac
	return r


## ws_from: war score from the proposer's point of view.
func accepts_peace(g, w, pids: Array, ws_from: float, from_receives: bool, vassal_cost: float = 0.0) -> bool:
	var dur: int = g.month - w.start
	var cost: float = g.peace_cost(pids) + vassal_cost
	if from_receives:
		if pids.is_empty() and vassal_cost <= 0.0:
			return ws_from >= -10.0 or (dur > 72 and ws_from >= -25.0)
		return cost <= ws_from + 5.0
	# proposer concedes provinces; receiver's war score is -ws_from
	return cost + 5.0 >= -ws_from * 0.7


# ---------------------------------------------------------------- armies

func control_armies(g, tag: String) -> void:
	var n = g.nations[tag]
	var enemies: Array = g.enemies_of(tag)
	var mine: Array = []
	for a in g.armies:
		if a.owner == tag and a.auto:
			mine.append(a)
	if mine.is_empty():
		return
	if enemies.is_empty():
		for a in mine:
			if a.pid != n.capital and a.target != n.capital:
				g.move_army(a, n.capital)
		g.merge_armies(tag, n.capital)
		return
	if (g.month + tag.hash()) % 2 != 0:
		return
	var enemy_power := {}
	for e in g.armies:
		if enemies.has(e.owner):
			enemy_power[e.pid] = enemy_power.get(e.pid, 0.0) + e.regs * g.combat_mult(e.owner) * g.power_factor(e)
	for a in mine:
		_command(g, a, enemies, enemy_power)


## Provinces an army in "defend" stance may fight in: own, allied and vassal land.
func _friendly(g, tag: String, owner: String) -> bool:
	return owner == tag or g.is_allied(tag, owner) or g.nations[owner].overlord == tag or g.nations[tag].overlord == owner


func _command(g, a, enemies: Array, enemy_power: Dictionary) -> void:
	var tag: String = a.owner
	var defend: bool = a.stance == "defend"
	var my_power: float = a.regs * g.combat_mult(tag) * g.power_factor(a)
	# exhausted armies fall back to friendly land to recover before fighting again
	if a.power < 0.3 * g.power_max(tag) and not _friendly(g, tag, g.provinces[a.pid].controller):
		var back: int = _nearest(g, a, func(pid): return _friendly(g, tag, g.provinces[pid].controller) and enemy_power.get(pid, 0.0) == 0.0)
		if back >= 0:
			g.move_army(a, back)
			return
	# flee if a much stronger enemy stands next to us
	for nb in g.provinces[a.pid].adj:
		if enemy_power.get(nb, 0.0) > my_power * 1.4 and enemy_power.get(a.pid, 0.0) == 0.0:
			var home: int = g.nations[tag].capital
			if a.pid != home and enemy_power.get(home, 0.0) < my_power:
				g.move_army(a, home)
				return
	# BFS over reachable provinces, pick the best target
	var dist := {a.pid: 0}
	var queue := [a.pid]
	var head := 0
	var best := -1
	var best_score := -1e9
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var d: int = dist[cur]
		var p = g.provinces[cur]
		var ep: float = enemy_power.get(cur, 0.0)
		var s := -1e9
		var allowed: bool = not defend or _friendly(g, tag, p.owner)
		if not allowed:
			# defenders still strike enemy armies standing right at the border
			for nb in p.adj:
				if _friendly(g, tag, g.provinces[nb].owner):
					allowed = ep > 0.0
					break
		if not allowed:
			s = -1e9
		elif ep > 0.0:
			if ep < my_power * 0.9:
				s = 80.0 + ep - d * 6.0
		elif enemies.has(p.controller):
			s = 40.0 + p.dev - d * 5.0
			if p.owner == tag:
				s += 30.0
			if g.nations[tag].claims.has(cur):
				s += 15.0
			if g.nations[p.owner].capital == cur:
				s += 10.0
		if s > best_score:
			best_score = s
			best = cur
		if d >= 10:
			continue
		for nb in p.adj:
			if dist.has(nb) or not g.can_enter(tag, nb):
				continue
			if enemy_power.get(nb, 0.0) > my_power * 1.1:
				continue
			dist[nb] = d + 1
			queue.append(nb)
	if best >= 0 and best != a.pid and best_score > -1e8:
		if a.target != best:
			g.move_army(a, best)
	elif best == a.pid:
		a.target = -1
	elif defend and a.target < 0:
		# nothing to do: wait in the capital (or the nearest own province) for the enemy
		var home: int = g.nations[tag].capital
		if a.pid != home and g.provinces[home].controller == tag:
			g.move_army(a, home)


## Quick orders for the player's army panel. Each returns a province id or -1.
func nearest_siege(g, a) -> int:
	var enemies: Array = g.enemies_of(a.owner)
	return _nearest(g, a, func(pid): return enemies.has(g.provinces[pid].controller))


func nearest_enemy_army(g, a) -> int:
	var enemies: Array = g.enemies_of(a.owner)
	var where := {}
	for e in g.armies:
		if enemies.has(e.owner):
			where[e.pid] = where.get(e.pid, 0.0) + e.regs
	return _nearest(g, a, func(pid): return where.has(pid) and where[pid] < a.regs * 1.2)


func nearest_lost_province(g, a) -> int:
	var tag: String = a.owner
	return _nearest(g, a, func(pid): return g.provinces[pid].owner == tag and g.provinces[pid].controller != tag)


func _nearest(g, a, ok: Callable) -> int:
	var dist := {a.pid: 0}
	var queue := [a.pid]
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		if cur != a.pid and ok.call(cur):
			return cur
		for nb in g.provinces[cur].adj:
			if not dist.has(nb) and g.can_enter(a.owner, nb):
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return -1


func pick_event_option(g, n, e: Dictionary) -> int:
	var total := 0.0
	var weights := []
	for i in e.options.size():
		var w := float(e.options[i].get("ai", 50.0 if i == 0 else 25.0))
		# historic war events: only march when the war looks winnable
		var foe = e.options[i].get("effects", {}).get("war", "")
		if foe != "" and g.nations.has(foe) and g.nations[foe].alive and foe != n.tag \
				and war_odds(g, n.tag, foe) < float(g.bal.ai_event_war_ratio):
			w *= 0.05
		weights.append(w)
		total += w
	var r: float = g.rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0
