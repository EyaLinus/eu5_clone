extends RefCounted
## Economy: goods produced by every province, dynamic prices, markets with trade power and merchants,
## and buildings (EU5-inspired, simple). Static helpers on the game `g` (untyped to avoid a cyclic preload).
##
## Monthly income of a province = tax + production value; trade income comes from the share of trade power
## a nation holds in each market (merchants raise it). Development raises all of these plus building slots.


static func setup(g, data: Dictionary) -> void:
	var gd: Dictionary = data.get("goods", {})
	g.goods_def = gd.get("goods", {})
	g.buildings_def = data.get("buildings", {})
	var by_key: Dictionary = gd.get("provinces", {})
	var coast: Array = data.get("coastal", [])
	for p in g.provinces:
		p.good = by_key.get(p.key, "grain")
		p.coastal = coast.has(p.key)
	g.markets = []
	for k in gd.get("markets", []):
		g.markets.append(g.key_to_pid[k])
	_assign_markets(g)
	g.prices = {}
	for k in g.goods_def:
		g.prices[k] = float(g.goods_def[k].price)
	g.prev_prices = g.prices.duplicate()
	g.shocks = {}
	g.base_supply = supply(g)


## Every province trades in the market center that is the fewest steps away (ties: earlier market).
static func _assign_markets(g) -> void:
	var dist := {}
	var frontier: Array = []
	for m in g.markets:
		dist[m] = 0
		g.provinces[m].market = m
		frontier.append(m)
	while not frontier.is_empty():
		var nxt: Array = []
		for pid in frontier:
			for a in g.provinces[pid].adj:
				if not dist.has(a):
					dist[a] = dist[pid] + 1
					g.provinces[a].market = g.provinces[pid].market
					nxt.append(a)
		frontier = nxt
	for p in g.provinces:
		if p.market < 0:
			p.market = g.markets[0]


# ---------------------------------------------------------------- buildings

static func level(p, bid: String) -> int:
	return int(p.buildings.get(bid, 0))


## Sum of a local building effect in province `p` (finished buildings, scaled by level). Cached in p.loc.
static func local(_g, p, key: String) -> float:
	return p.loc.get(key, 0.0)


static func refresh_local(g, p) -> void:
	var c := {}
	for b in p.buildings:
		var loc: Dictionary = g.buildings_def[b].get("local", {})
		for k in loc:
			c[k] = c.get(k, 0.0) + float(loc[k]) * int(p.buildings[b])
	p.loc = c


## Extra monthly tax + production income of the next level of `bid` (incl. its +1 development), for the build tab.
static func building_gain(g, p, bid: String) -> float:
	var before := province_income(g, p)
	var old_lv := level(p, bid)
	var old_dev: int = p.dev
	p.buildings[bid] = old_lv + 1
	if not g.buildings_def[bid].get("no_dev", false):
		p.dev = mini(int(g.bal.max_dev), p.dev + int(g.bal.building_dev))
	refresh_local(g, p)
	var after := province_income(g, p)
	if old_lv == 0:
		p.buildings.erase(bid)
	else:
		p.buildings[bid] = old_lv
	p.dev = old_dev
	refresh_local(g, p)
	return after - before


static func slots(g, p) -> int:
	return mini(int(g.bal.building_slots_max), 2 + p.dev / int(g.bal.dev_per_building_slot))


## Cost of the next level of `bid` in `pid` (level 1 = new building).
## `nation_mult` is the realm's build cost factor (build_cost_mult), passed in by loops that price many buildings.
static func building_cost(g, tag: String, pid: int, bid: String, nation_mult: float = -1.0) -> float:
	var p = g.provinces[pid]
	if nation_mult < 0.0:
		nation_mult = build_cost_mult(g, g.nations[tag])
	var dev_mult: float = 1.0 + p.dev * float(g.bal.building_cost_per_dev)
	var lvl: int = level(p, bid) + 1
	return round(float(g.buildings_def[bid].cost) * float(g.bal.building_cost_mult) * pow(lvl, float(g.bal.building_level_exp)) * dev_mult * nation_mult)


static func build_cost_mult(g, n) -> float:
	return maxf(0.3, 1.0 + g.mod(n, "build_cost"))


static func max_level(g, bid: String) -> int:
	return int(g.buildings_def[bid].get("max_level", g.bal.building_max_level))


## Tech needed to build level `lvl` of `bid` ("" when none): buildings.json "level_tech" {"<level>": tech id}.
## Late levels and late buildings wait for their tech, so a rich realm can't build everything at once.
static func level_tech(g, bid: String, lvl: int) -> String:
	return str(g.buildings_def[bid].get("level_tech", {}).get(str(lvl), ""))


## Provinces of `tag` that have `bid` or are building it ("max_count" buildings like universities).
static func count_in_realm(g, tag: String, bid: String) -> int:
	var c := 0
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		if p.buildings.has(bid) or p.constructing.get("id", "") == bid:
			c += 1
	return c


## Development needed for the next level of `bid`.
static func level_dev(g, p, bid: String) -> int:
	var lvl: int = level(p, bid) + 1
	return maxi(int(g.buildings_def[bid].get("min_dev", 0)), (lvl - 1) * int(g.bal.dev_per_building_level))


## "" if `tag` may start building `bid` in `pid`, else the reason.
static func build_block_reason(g, tag: String, pid: int, bid: String) -> String:
	var r := _build_block_no_gold(g, tag, g.provinces[pid], bid)
	if r != "":
		return r
	if g.nations[tag].gold < building_cost(g, tag, pid, bid):
		return "Zu wenig Gold (%d benötigt)." % building_cost(g, tag, pid, bid)
	return ""


## Every rule of build_block_reason except the price.
static func _build_block_no_gold(g, tag: String, p, bid: String) -> String:
	var d: Dictionary = g.buildings_def.get(bid, {})
	if d.is_empty():
		return "Unbekanntes Gebäude."
	if p.owner != tag:
		return "Nicht deine Provinz."
	if p.controller != tag:
		return "Provinz ist besetzt."
	if level(p, bid) >= max_level(g, bid):
		return "Höchste Stufe erreicht."
	if not p.constructing.is_empty():
		return "Hier wird schon gebaut."
	if not p.buildings.has(bid) and p.buildings.size() >= slots(g, p):
		return "Keine freien Bauplätze (mehr Entwicklung = mehr Plätze)."
	if d.get("coastal", false) and not p.coastal:
		return "Nur in Küstenprovinzen."
	if d.has("requires") and not p.buildings.has(d.requires):
		return "Braucht zuerst: %s." % g.buildings_def[d.requires].name
	var tech := level_tech(g, bid, level(p, bid) + 1)
	if tech != "" and not g.nations[tag].techs.has(tech):
		return "Braucht Technologie: %s." % g.tree.by_id[tech].name
	if d.has("max_count") and not p.buildings.has(bid) and count_in_realm(g, tag, bid) >= int(d.max_count):
		return "Höchstens %d im Reich." % int(d.max_count)
	if p.dev < level_dev(g, p, bid):
		return "Braucht Entwicklung %d." % level_dev(g, p, bid)
	return ""


static func construct(g, tag: String, pid: int, bid: String) -> String:
	var r := build_block_reason(g, tag, pid, bid)
	if r != "":
		return r
	g.nations[tag].gold -= building_cost(g, tag, pid, bid)
	g.provinces[pid].constructing = {"id": bid, "months": int(g.buildings_def[bid].months) * (level(g.provinces[pid], bid) + 1)}
	return ""


static func construction_tick(g, n) -> void:
	for pid in g.provinces_of(n.tag):
		var p = g.provinces[pid]
		if p.constructing.is_empty() or p.controller != n.tag:
			continue
		p.constructing.months -= 1
		if p.constructing.months <= 0:
			var bid: String = p.constructing.id
			p.constructing = {}
			p.buildings[bid] = mini(level(p, bid) + 1, max_level(g, bid))
			# every finished level also grows the province (more tax, goods, manpower and slots); roads don't
			if not g.buildings_def[bid].get("no_dev", false):
				p.dev = mini(int(g.bal.max_dev), p.dev + int(g.bal.building_dev))
			refresh_local(g, p)
			if n.tag == g.player:
				g.log_msg("%s %s (Stufe %d) in %s fertig." % [g.buildings_def[bid].emoji, g.buildings_def[bid].name, p.buildings[bid], p.name])
			# context events (once per realm, only where defined): first building of a kind, first one at top level
			g.fire_event(n.tag, "bld_%s_first" % bid)
			if p.buildings[bid] >= max_level(g, bid):
				g.fire_event(n.tag, "bld_max_level")


## Sum of all levels of `bid` in `tag`'s provinces (event and mission conditions).
static func building_total(g, tag: String, bid: String) -> int:
	var v := 0
	for pid in g.provinces_of(tag):
		v += level(g.provinces[pid], bid)
	return v


## Event/mission reward: one free level of `bid` in the most developed province that could build it
## (gold ignored, no construction time). Returns false if no province qualifies.
static func free_level(g, tag: String, bid: String) -> bool:
	if not g.buildings_def.has(bid):
		return false
	var best = null
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		var d: Dictionary = g.buildings_def[bid]
		if p.controller != tag or level(p, bid) >= max_level(g, bid) or not p.constructing.is_empty():
			continue
		if not p.buildings.has(bid) and p.buildings.size() >= slots(g, p):
			continue
		if (d.get("coastal", false) and not p.coastal) or (d.has("requires") and not p.buildings.has(d.requires)):
			continue
		if p.dev < level_dev(g, p, bid):
			continue
		if best == null or p.dev > best.dev:
			best = p
	if best == null:
		return false
	best.buildings[bid] = level(best, bid) + 1
	if not g.buildings_def[bid].get("no_dev", false):
		best.dev = mini(int(g.bal.max_dev), best.dev + int(g.bal.building_dev))
	refresh_local(g, best)
	refresh_building_bonus(g, g.nations[tag])
	return true


static func fort_level(g, p) -> int:
	return p.fort + int(local(g, p, "fort"))


## Administration of a large realm: a share of the income that grows with total development
## (none up to realm_cost_free_dev). Keeps great powers from hoarding gold in the late game.
static func realm_cost_share(g, n) -> float:
	var dev: float = float(n.dev_total) - float(g.bal.realm_cost_free_dev)
	return clampf(dev * float(g.bal.realm_cost_per_dev), 0.0, float(g.bal.realm_cost_max))


static func realm_cost(g, n) -> float:
	return maxf(0.0, n.income) * realm_cost_share(g, n)


static func upkeep(g, tag: String) -> float:
	var v := 0.0
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		for b in p.buildings:
			v += float(g.buildings_def[b].get("upkeep", 0.0)) * int(p.buildings[b])
	return v


## Nation-wide effects of buildings (e.g. barracks -> force limit), stored in n.bonus["buildings"].
static func refresh_building_bonus(g, n) -> void:
	var b := {}
	for pid in g.provinces_of(n.tag):
		var p = g.provinces[pid]
		for bid in p.buildings:
			var nat: Dictionary = g.buildings_def[bid].get("nation", {})
			for k in nat:
				b[k] = b.get(k, 0.0) + float(nat[k]) * int(p.buildings[bid])
	n.bonus["buildings"] = b


# ---------------------------------------------------------------- production and tax

static func units(g, p) -> float:
	var n = g.nations[p.owner]
	var m: float = 1.0 + local(g, p, "production") + g.mod(n, "production") + g.mod(n, "goods_" + p.good)
	return p.dev * float(g.bal.production_per_dev) * maxf(0.1, m)


## `nm` (optional, from nation_mods) caches the owner's modifier sums for loops over many provinces.
static func production_value(g, p, nm: Dictionary = {}) -> float:
	if nm.is_empty():
		nm = nation_mods(g, g.nations[p.owner])
	var gk: String = "goods_" + p.good
	if not nm.has(gk):
		nm[gk] = g.mod(g.nations[p.owner], gk)
	var m: float = 1.0 + local(g, p, "production") + nm.production + nm[gk] + nm.income
	return p.dev * float(g.bal.production_per_dev) * maxf(0.1, m) * float(g.prices[p.good])


static func tax(g, p, nm: Dictionary = {}) -> float:
	if nm.is_empty():
		nm = nation_mods(g, g.nations[p.owner])
	return p.dev * float(g.bal.tax_per_dev) * maxf(0.1, 1.0 + local(g, p, "tax") + nm.tax + nm.income)


static func nation_mods(g, n) -> Dictionary:
	return {"tax": g.mod(n, "tax"), "production": g.mod(n, "production"), "income": income_bonus(g, n)}


## Nation-wide income bonus (admin tech + income modifiers). It adds to the bonus of each income
## category (tax, production, trade) instead of multiplying it, so late-game modifiers do not stack
## into a twentyfold economy.
static func income_bonus(g, n) -> float:
	return n.tech.adm * float(g.bal.adm_tech_income) + g.mod(n, "income")


static func uncored_mult(g, p) -> float:
	if p.core_months <= 0:
		return 1.0
	return minf(1.0, float(g.bal.uncored_income_mult) + local(g, p, "uncored_income"))


## Local income (tax + production) before nation-wide income modifiers.
static func province_income(g, p) -> float:
	return (tax(g, p) + production_value(g, p)) * uncored_mult(g, p)


static func local_manpower(g, p) -> float:
	return p.dev * float(g.bal.manpower_per_dev) * (1.0 + local(g, p, "manpower"))


# ---------------------------------------------------------------- goods and prices

static func supply(g) -> Dictionary:
	var s := {}
	for k in g.goods_def:
		s[k] = 0.0
	for p in g.provinces:
		s[p.good] = s.get(p.good, 0.0) + units(g, p)
	return s


## Yearly: prices follow world supply against slowly growing demand; the biggest producer of a good
## (at least `goods_leader_share` of world output) gets that good's bonus.
static func yearly(g) -> void:
	_shocks_yearly(g)
	var s := supply(g)
	var years: float = g.year() - int(g.bal.start_year)
	g.prev_prices = g.prices.duplicate()
	for k in g.goods_def:
		var demand: float = float(g.base_supply.get(k, 1.0)) * (1.0 + float(g.bal.demand_growth) * years)
		var ratio: float = sqrt(demand / maxf(0.01, s[k]))
		var shock: float = float(g.shocks[k].mult) if g.shocks.has(k) else 1.0
		g.prices[k] = snappedf(float(g.goods_def[k].price) * clampf(ratio, float(g.bal.price_min), float(g.bal.price_max)) * shock, 0.001)
	refresh_goods_leaders(g)
	for tag in g.order:
		var n = g.nations[tag]
		if n.alive and (n.merchant_auto or tag != g.player):
			auto_merchants(g, n)


## Market shocks: now and then a good gets scarce (harvest failure, war, plague) or floods the market
## for a few years. Ages existing shocks; at most one new shock per year.
static func _shocks_yearly(g) -> void:
	for k in g.shocks.keys():
		g.shocks[k].years -= 1
		if g.shocks[k].years <= 0:
			g.shocks.erase(k)
			if g.player != "" and goods_output(g, g.player).has(k):
				g.log_msg("⚖️ Der Markt für %s %s hat sich beruhigt." % [g.goods_def[k].emoji, g.goods_def[k].name])
	if g.rng.randf() >= float(g.bal.shock_chance):
		return
	var free: Array = []
	for k in g.goods_def:
		if not g.shocks.has(k):
			free.append(k)
	if free.is_empty():
		return
	var k: String = free[g.rng.randi() % free.size()]
	var up: bool = g.rng.randf() < 0.5
	var years: int = g.rng.randi_range(int(g.bal.shock_years_min), int(g.bal.shock_years_max))
	g.shocks[k] = {"mult": float(g.bal.shock_up) if up else float(g.bal.shock_down), "years": years}
	var gd: Dictionary = g.goods_def[k]
	if up:
		g.log_msg("📈 Knappheit: %s %s wird für %d Jahre deutlich teurer. Wer es herstellt, verdient mehr." % [gd.emoji, gd.name, years])
	else:
		g.log_msg("📉 Überangebot: %s %s wird für %d Jahre billiger." % [gd.emoji, gd.name, years])


static func goods_output(g, tag: String) -> Dictionary:
	var r := {}
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		r[p.good] = r.get(p.good, 0.0) + units(g, p)
	return r


static func refresh_goods_leaders(g) -> void:
	var s := supply(g)
	var best := {}
	var best_v := {}
	for tag in g.order:
		if not g.nations[tag].alive:
			continue
		var out := goods_output(g, tag)
		for k in out:
			if out[k] > best_v.get(k, 0.0):
				best_v[k] = out[k]
				best[k] = tag
	g.goods_leader = {}
	for k in best:
		if best_v[k] >= float(g.bal.goods_leader_share) * maxf(0.01, s[k]):
			g.goods_leader[k] = best[k]
	for tag in g.order:
		var b := {}
		for k in g.goods_leader:
			if g.goods_leader[k] == tag:
				var gb: Dictionary = g.goods_def[k].get("bonus", {})
				for m in gb:
					b[m] = b.get(m, 0.0) + float(gb[m])
		g.nations[tag].bonus["goods"] = b


# ---------------------------------------------------------------- trade

static func merchant_count(g, n) -> int:
	return mini(int(g.bal.max_merchants), 1 + int(n.tech.dip / int(g.bal.dip_tech_per_merchant)) + int(g.mod(n, "merchants")))


static func province_trade_power(g, p) -> float:
	var v: float = p.dev * (1.0 + local(g, p, "trade_power")) + local(g, p, "trade_flat")
	if p.market == p.id:
		v *= float(g.bal.market_center_power)
	return v


## Recomputed every month: value and trade power per nation in every market.
static func update_markets(g) -> void:
	var c := {}
	for m in g.markets:
		c[m] = {"value": 0.0, "power": {}, "total": 0.0}
	for p in g.provinces:
		var e: Dictionary = c[p.market]
		e.value += production_value(g, p) * float(g.bal.trade_value_mult)
		if p.controller == p.owner:
			e.power[p.owner] = e.power.get(p.owner, 0.0) + province_trade_power(g, p)
	for tag in g.order:
		var n = g.nations[tag]
		if not n.alive:
			continue
		for m in n.merchants:
			if c.has(m):
				var own: float = c[m].power.get(tag, 0.0)
				c[m].power[tag] = own * (1.0 + float(g.bal.merchant_mult)) + float(g.bal.merchant_flat)
	for m in c:
		var t := 0.0
		for tag in c[m].power:
			t += c[m].power[tag]
		c[m].total = t
	g.market_cache = c


static func trade_share(g, tag: String, m: int) -> float:
	var e: Dictionary = g.market_cache.get(m, {})
	if e.is_empty() or e.total <= 0.0:
		return 0.0
	return e.power.get(tag, 0.0) / e.total


static func trade_income(g, n) -> float:
	var v := 0.0
	for m in g.market_cache:
		var e: Dictionary = g.market_cache[m]
		if e.total > 0.0 and e.power.has(n.tag):
			v += e.value * e.power[n.tag] / e.total
	return v * maxf(0.0, 1.0 + g.mod(n, "trade") + income_bonus(g, n))


## Gain in monthly trade income if `tag` sent one (more) merchant to market `m`.
static func merchant_gain(g, tag: String, m: int) -> float:
	var e: Dictionary = g.market_cache.get(m, {})
	if e.is_empty():
		return 0.0
	var own: float = e.power.get(tag, 0.0)
	var boosted: float = own * (1.0 + float(g.bal.merchant_mult)) + float(g.bal.merchant_flat)
	var before: float = own / maxf(0.001, e.total)
	var after: float = boosted / maxf(0.001, e.total - own + boosted)
	return (after - before) * e.value


static func auto_merchants(g, n) -> void:
	n.merchants = []
	if g.market_cache.is_empty():
		update_markets(g)
	var options: Array = []
	for m in g.markets:
		options.append([merchant_gain(g, n.tag, m), m])
	options.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(merchant_count(g, n), options.size()):
		n.merchants.append(options[i][1])


static func send_merchant(g, tag: String, m: int) -> String:
	var n = g.nations[tag]
	if not g.markets.has(m):
		return "Kein Markt."
	if n.merchants.has(m):
		return "Dort ist schon ein Händler."
	if n.merchants.size() >= merchant_count(g, n):
		return "Alle Händler sind unterwegs. Rufe zuerst einen zurück."
	n.merchant_auto = false
	n.merchants.append(m)
	update_markets(g)
	return ""


static func recall_merchant(g, tag: String, m: int) -> void:
	var n = g.nations[tag]
	n.merchant_auto = false
	n.merchants.erase(m)
	update_markets(g)


# ---------------------------------------------------------------- trade agreements

## "" if `tag` may offer a trade agreement to `other`, else the reason.
static func pact_block_reason(g, tag: String, other: String) -> String:
	var n = g.nations[tag]
	var o = g.nations[other]
	if tag == other or not o.alive:
		return "Nicht möglich."
	if n.trade_pacts.has(other):
		return "Abkommen besteht bereits."
	if g.at_war(tag, other):
		return "Ihr seid im Krieg."
	if n.trade_pacts.size() >= int(g.bal.max_trade_pacts) or o.trade_pacts.size() >= int(g.bal.max_trade_pacts):
		return "Höchstens %d Handelsabkommen je Reich." % int(g.bal.max_trade_pacts)
	if n.dip < float(g.bal.trade_pact_cost):
		return "Zu wenig Diplomatie (%d)." % int(g.bal.trade_pact_cost)
	return ""


## AI answer: friendly enough and no claims between the two.
static func accepts_pact(g, target: String, from: String) -> bool:
	if g.has_claim_on(from, target) or g.has_claim_on(target, from):
		return false
	return g.get_rel(target, from) >= float(g.bal.trade_pact_min_rel) or g.is_allied(target, from)


static func offer_pact(g, tag: String, other: String) -> String:
	var why := pact_block_reason(g, tag, other)
	if why != "":
		return why
	g.nations[tag].dip -= float(g.bal.trade_pact_cost)
	if other != g.player and not accepts_pact(g, other, tag):
		return "%s lehnt ab (Beziehung %d, nötig %d)." % [g.nations[other].name, int(g.get_rel(other, tag)), int(g.bal.trade_pact_min_rel)]
	g.nations[tag].trade_pacts.append(other)
	g.nations[other].trade_pacts.append(tag)
	refresh_pact_bonus(g, g.nations[tag])
	refresh_pact_bonus(g, g.nations[other])
	g.log_msg("🔗 Handelsabkommen zwischen %s und %s." % [g.nations[tag].name, g.nations[other].name], [tag, other])
	return ""


static func cancel_pact(g, tag: String, other: String) -> void:
	g.nations[tag].trade_pacts.erase(other)
	g.nations[other].trade_pacts.erase(tag)
	refresh_pact_bonus(g, g.nations[tag])
	refresh_pact_bonus(g, g.nations[other])


static func refresh_pact_bonus(g, n) -> void:
	n.bonus["pacts"] = {"trade": float(g.bal.trade_pact_bonus) * n.trade_pacts.size()}


## Monthly: war or death ends agreements.
static func check_pacts(g) -> void:
	for tag in g.order:
		var n = g.nations[tag]
		for o in n.trade_pacts.duplicate():
			if not n.alive or not g.nations[o].alive or g.at_war(tag, o):
				cancel_pact(g, tag, o)
				if tag == g.player or o == g.player:
					g.log_msg("🔗 Das Handelsabkommen zwischen %s und %s ist beendet." % [n.name, g.nations[o].name], [tag, o])


# ---------------------------------------------------------------- loans

## Size of one loan: a year of income, at least loan_min.
static func loan_size(g, n) -> float:
	return maxf(float(g.bal.loan_min), roundf(n.income * float(g.bal.loan_months_income)))


## Yearly interest rate of the next loan: base plus a step for every loan already taken.
static func loan_rate(g, n) -> float:
	return float(g.bal.loan_interest) + float(g.bal.loan_interest_step) * n.loans.size()


## Monthly interest on all open loans (later loans cost more).
static func interest(g, n) -> float:
	var v := 0.0
	for i in n.loans.size():
		v += float(n.loans[i]) * (float(g.bal.loan_interest) + float(g.bal.loan_interest_step) * i) / 12.0
	return v


static func debt(n) -> float:
	var v := 0.0
	for l in n.loans:
		v += float(l)
	return v


static func take_loan(g, tag: String) -> String:
	var n = g.nations[tag]
	if n.loans.size() >= int(g.bal.max_loans):
		return "Keine Bank leiht dir mehr (höchstens %d Kredite)." % int(g.bal.max_loans)
	var amt := loan_size(g, n)
	n.loans.append(amt)
	n.gold += amt
	return ""


## Pays back the most expensive (last) loan.
static func repay_loan(g, tag: String) -> String:
	var n = g.nations[tag]
	if n.loans.is_empty():
		return "Keine offenen Kredite."
	var amt: float = n.loans[n.loans.size() - 1]
	if n.gold < amt:
		return "Zu wenig Gold (%d benötigt)." % int(amt)
	n.gold -= amt
	n.loans.pop_back()
	return ""


# ---------------------------------------------------------------- AI

## Player autobuild: starts the best building (value per gold) while the treasury stays at or above
## the reserve after paying. At most 2 new projects per month. Returns the number started.
static func autobuild(g, n) -> int:
	if not n.autobuild:
		return 0
	var started := 0
	for i in 2:
		var best: Array = best_building(g, n, g.is_at_war(n.tag))
		if best.is_empty() or n.gold - building_cost(g, n.tag, best[0], best[1]) < n.autobuild_reserve:
			break
		if g.construct(n.tag, best[0], best[1]) != "":
			break
		started += 1
		var d: Dictionary = g.buildings_def[best[1]]
		g.log_msg("🤖 Autobau: %s %s in %s" % [d.emoji, d.name, g.provinces[best[0]].name])
	return started


## Best building for the AI: highest extra monthly value per gold. Returns [pid, bid] or [].
static func best_building(g, n, war: bool) -> Array:
	var best: Array = []
	var best_score := 0.0
	var mult := build_cost_mult(g, n)
	for pid in g.provinces_of(n.tag):
		var p = g.provinces[pid]
		if p.controller != n.tag or not p.constructing.is_empty():
			continue
		var ctx := {}  # per-province values shared by all building types (unrest, exposed border)
		for bid in g.buildings_def:
			if _build_block_no_gold(g, n.tag, p, bid) != "":
				continue
			var cost := building_cost(g, n.tag, pid, bid, mult)
			if n.gold < cost:
				continue
			var s := _building_value(g, n, p, bid, war, ctx) / cost
			if not p.buildings.has(bid):
				s *= 0.8  # a new building uses up a slot
			if s > best_score:
				best_score = s
				best = [pid, bid]
	return best


static func _ctx_unrest(g, p, ctx: Dictionary) -> float:
	if not ctx.has("unrest"):
		ctx.unrest = g.unrest(p.id)
	return ctx.unrest


static func _building_value(g, n, p, bid: String, war: bool, ctx: Dictionary = {}) -> float:
	var d: Dictionary = g.buildings_def[bid]
	var loc: Dictionary = d.get("local", {})
	var v := 0.0
	var prod: float = p.dev * float(g.bal.production_per_dev) * float(g.prices[p.good])
	v += float(loc.get("production", 0.0)) * prod
	v += float(loc.get("tax", 0.0)) * p.dev * float(g.bal.tax_per_dev)
	v += (float(loc.get("trade_power", 0.0)) * p.dev + float(loc.get("trade_flat", 0.0))) * 0.01
	v += float(d.get("nation", {}).get("trade", 0.0)) * n.trade_income
	v += float(loc.get("manpower", 0.0)) * p.dev * 0.01
	if p.core_months > 0:
		v += float(loc.get("uncored_income", 0.0)) * prod + absf(float(loc.get("unrest", 0.0))) * 0.03
	elif _ctx_unrest(g, p, ctx) > 1.0:
		v += absf(float(loc.get("unrest", 0.0))) * 0.03
	v += float(d.get("nation", {}).get("force_limit", 0.0)) * (0.08 if war else 0.03)
	var nat: Dictionary = d.get("nation", {})
	v += float(nat.get("income", 0.0)) * n.income
	v -= float(nat.get("maintenance", 0.0)) * n.expenses * 0.5
	v -= float(nat.get("tech_cost", 0.0)) * 3.0
	if p.core_months == 0:  # roads in fresh conquests would crowd out courthouses
		v += float(loc.get("supply", 0.0)) * (0.012 if war else 0.004)
	if loc.has("fort"):
		# forts only where it matters: the capital or a border province next to a strong neighbor
		if not ctx.has("exposed"):
			var exposed: bool = p.id == n.capital
			var mine: float = g.strength(n.tag) * 1.2
			for a in p.adj:
				var o: String = g.provinces[a].owner
				if not exposed and o != n.tag and g.strength(o) > mine:
					exposed = true
			ctx.exposed = exposed
		v += 0.05 if ctx.exposed else 0.0
		v -= float(d.get("upkeep", 0.0))
	return v
