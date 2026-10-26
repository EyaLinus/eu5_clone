extends SceneTree
## Unit and data tests. Run: godot --headless --path . -s res://tests/run_tests.gd
## Exit code 1 on any failure.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")

var data: Dictionary
var failures := 0
var checks := 0


func _init() -> void:
	data = Data.load_all()
	for t in [
		"test_data_references", "test_map_geometry", "test_map_connected", "test_events_shape",
		"test_develop_and_tech", "test_recruit_limits", "test_war_and_peace", "test_vassal_and_annex", "test_unrest_and_revolt", "test_hre_election", "test_alliance_joins_war", "test_protector_defends_small_state",
		"test_economy_goods_and_trade", "test_buildings", "test_autobuild", "test_army_power", "test_peace_offer_cooldown", "test_mercenaries", "test_trade_pacts", "test_loans_and_shocks", "test_harbor", "test_army_stances", "test_progression", "test_coalition_forms", "test_inherit", "test_inherit_never_takes_player", "test_save_roundtrip",
		"test_missions_complete", "test_tech_data", "test_tech_tree", "test_special_techs", "test_tech_modifiers",
		"test_government_data", "test_advisors", "test_companies", "test_laws", "test_gov_save_roundtrip", "test_company_invest", "test_estates", "test_gov_events", "test_budget",
		"test_old_save_tech_levels", "test_ai_uses_government", "test_long_run_no_softlock", "test_emoji_coverage", "test_event_pictures",
	]:
		var before := failures
		call(t)
		print(("PASS " if failures == before else "FAIL ") + t)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  ✗ " + msg)


func new_game(player := "FRA", seed_value := 7):
	var g = Game.new()
	g.setup(data, seed_value, player)
	return g


# ---------------------------------------------------------------- data

func test_data_references() -> void:
	var keys := {}
	for p in data.map.provinces:
		keys[p.key] = true
	var tags: Dictionary = data.nations
	for tag in tags:
		check(keys.has(tags[tag].capital), "capital of %s exists" % tag)
	var owners := {}
	for p in data.map.provinces:
		check(tags.has(p.owner), "owner %s of %s is a nation" % [p.owner, p.key])
		owners[p.owner] = true
	for tag in tags:
		check(owners.has(tag), "%s owns at least one province" % tag)
	var refs := []
	for e in data.events:
		refs.append([e.id, e.get("trigger", {})])
		for o in e.options:
			refs.append([e.id, o.get("effects", {})])
	for tag in data.missions:
		check(tags.has(tag), "mission tag %s" % tag)
		for m in data.missions[tag]:
			refs.append([m.id, m.get("require", {})])
			refs.append([m.id, m.get("reward", {})])
	for r in refs:
		var d: Dictionary = r[1]
		for k in ["owns", "owns_any", "not_owns", "claim"]:
			for key in d.get(k, []):
				check(keys.has(key), "%s: province key %s exists" % [r[0], key])
		for k in ["alive", "not_alive", "allied", "alliance", "inherit", "war", "vassal"]:
			if d.has(k):
				check(tags.has(d[k]), "%s: tag %s exists" % [r[0], d[k]])
		if d.has("province"):
			check(keys.has(d.province), "%s: province %s exists" % [r[0], d.province])
		for t in d.get("relations", {}):
			check(tags.has(t), "%s: relation tag %s" % [r[0], t])


func test_map_geometry() -> void:
	for p in data.map.provinces:
		for poly in p.polys:
			var arr := PackedVector2Array()
			for pt in poly:
				arr.append(Vector2(pt[0], pt[1]))
			check(arr.size() >= 3 and not Geometry2D.triangulate_polygon(arr).is_empty(), "polygon of %s triangulates" % p.key)


func test_map_connected() -> void:
	var g = new_game()
	var seen := {0: true}
	var q := [0]
	while not q.is_empty():
		var c: int = q.pop_back()
		for a in g.provinces[c].adj:
			check(g.provinces[a].adj.has(c), "adjacency symmetric %d-%d" % [c, a])
			if not seen.has(a):
				seen[a] = true
				q.append(a)
	check(seen.size() == g.provinces.size(), "all provinces connected (%d/%d)" % [seen.size(), g.provinces.size()])


func test_events_shape() -> void:
	var ids := {}
	for e in data.events:
		check(not ids.has(e.id), "unique event id " + e.id)
		ids[e.id] = true
		check(e.options.size() == 3, "event %s has 3 options" % e.id)
	for tag in ["FRA", "ENG", "SPA", "BOH", "HAB", "RUS", "NAP"]:
		var n := 0
		for e in data.events:
			if e.get("tag", "") == tag:
				n += 1
		check(n >= 5, "%s has >= 5 events (%d)" % [tag, n])
		check(data.missions.has(tag) and data.missions[tag].size() >= 5, "%s has missions" % tag)


# ---------------------------------------------------------------- mechanics

func test_develop_and_tech() -> void:
	var g = new_game()
	var n = g.nations.FRA
	var pid: int = n.capital
	var dev: int = g.provinces[pid].dev
	n.adm = 500
	check(g.develop("FRA", pid) == "", "develop succeeds")
	check(g.provinces[pid].dev == dev + 1, "dev increased")
	check(n.adm < 500, "adm spent")
	n.adm = 0
	check(g.develop("FRA", pid) != "", "develop fails without adm")
	n.mil = 1000
	var lvl: int = n.tech.mil
	check(g.buy_tech("FRA", "mil") == "", "tech bought")
	check(n.tech.mil == lvl + 1, "tech level up")
	check(g.develop("FRA", g.key_to_pid["london"]) != "", "cannot develop foreign province")


func test_recruit_limits() -> void:
	var g = new_game()
	var n = g.nations.FRA
	n.gold = 10000
	n.manpower = 1000
	var fl: float = g.force_limit("FRA")
	var have: float = g.army_regs("FRA")
	var room := int(fl - have)
	check(g.recruit("FRA", n.capital, room) == "", "recruit up to force limit")
	check(g.recruit("FRA", n.capital, 1) != "", "force limit enforced")


func test_war_and_peace() -> void:
	var g = new_game("FRA")
	# isolate: drop alliances so only two nations fight
	for t in g.order:
		g.nations[t].allies.clear()
	g.nations.FRA.claims.clear()
	check(g.declare_war("FRA", "BRI") == "", "war declared (no CB)")
	var w = g.war_between("FRA", "BRI")
	check(w != null, "war exists")
	check(g.nations.FRA.ae > 0, "no-CB war adds AE")
	var rennes: int = g.key_to_pid["rennes"]
	g.provinces[rennes].controller = "FRA"
	check(g.warscore(w) > 0, "occupation gives war score")
	check(g.demandable(w, true).has(rennes), "occupied province demandable")
	var ae_before: float = g.nations.FRA.ae
	g.make_peace(w, true, [rennes])
	check(g.provinces[rennes].owner == "FRA", "province transferred")
	check(g.nations.FRA.ae > ae_before, "taking land adds AE")
	check(g.provinces[rennes].core_months > 0, "new province uncored")
	check(not g.at_war("FRA", "BRI"), "war ended")
	check(g.has_truce("FRA", "BRI"), "truce after peace")
	check(g.declare_war("FRA", "BRI") != "", "cannot attack during truce")


func test_vassal_and_annex() -> void:
	var g = new_game("FRA")
	for t in g.order:
		g.nations[t].allies.clear()
	g.nations.FRA.claims.clear()
	g.declare_war("FRA", "BRI")
	var w = g.war_between("FRA", "BRI")
	# keep the war two-sided so the vassal test does not depend on protectors
	w.defenders = ["BRI"]
	check(g.vassal_block_reason(w, true) == "", "Brittany can be vassalized: " + g.vassal_block_reason(w, true))
	check(g.vassal_block_reason(w, false) != "", "player can never become a vassal")
	g.provinces[g.key_to_pid["rennes"]].controller = "FRA"
	check(not g.offer_peace("FRA", w, [], true, true) or g.nations.BRI.overlord == "FRA", "offer consistent")
	if g.wars.has(w):
		g.make_peace(w, true, [], true)
	var bri = g.nations.BRI
	check(bri.overlord == "FRA" and bri.alive, "BRI is a living vassal of FRA")
	check(g.is_allied("FRA", "BRI") and g.vassals_of("FRA") == ["BRI"], "vassal counts as same side")
	check(g.declare_war("BRI", "ENG") != "", "vassal cannot declare war")
	check(g.propose_alliance("BRI", "ENG") != "", "vassal cannot make alliances")
	# vassal joins the overlord's wars and the overlord defends the vassal
	g.nations.ENG.truces.clear()
	g.nations.FRA.truces.clear()
	g.nations.BRI.truces.clear()
	g.declare_war("ENG", "BRI")
	var w2 = g.war_between("ENG", "BRI")
	check(w2 != null and w2.defenders.has("FRA"), "overlord defends its vassal")
	g.wars.erase(w2)
	# tribute flows to the overlord
	var gold_before: float = g.nations.FRA.gold
	g._economy(bri)
	check(g.nations.FRA.gold > gold_before, "vassal pays tribute")
	check(g.tribute_income("FRA") > 0.0, "tribute shown")
	# annexation is gated by time, then moves all land
	check(g.annex_vassal("FRA", "BRI") != "", "annex blocked during waiting period")
	g.month += int(g.bal.vassal_annex_years) * 12
	g.nations.FRA.dip = 999.0
	g.nations.FRA.adm = 999.0
	var bri_provs: Array = g.provinces_of("BRI").duplicate()
	check(g.annex_vassal("FRA", "BRI") == "", "annexation succeeds")
	check(not bri.alive, "annexed vassal is gone")
	for pid in bri_provs:
		check(g.provinces[pid].owner == "FRA" and g.provinces[pid].core_months > 0, "annexed land owned and integrating")
	# save/load keeps vassal links
	var g2 = new_game("FRA")
	var war3 = null
	for t in g2.order:
		g2.nations[t].allies.clear()
	g2.declare_war("FRA", "BRI")
	war3 = g2.war_between("FRA", "BRI")
	g2.make_peace(war3, true, [], true)
	var d: Dictionary = JSON.parse_string(JSON.stringify(g2.to_dict()))
	var g3 = new_game("FRA")
	g3.from_dict(d)
	check(g3.nations.BRI.overlord == "FRA" and g3.nations.BRI.vassal_since == g2.nations.BRI.vassal_since, "vassal survives save/load")
	# overlord death frees the vassal
	for pid in g2.provinces_of("FRA").duplicate():
		g2.provinces[pid].owner = "ENG"
	g2._rebuild_owned()
	g2._check_alive("FRA")
	check(g2.nations.BRI.overlord == "", "vassal freed when overlord dies")


func test_unrest_and_revolt() -> void:
	var g = new_game("FRA")
	var rennes: int = g.key_to_pid["rennes"]
	var p = g.provinces[rennes]
	# conquered, uncored, exhausted: high unrest
	p.owner = "FRA"
	p.controller = "FRA"
	p.prev_owner = "BRI"
	p.core_months = 60
	g._rebuild_owned()
	g.nations.FRA.we = 10.0
	for a in g.armies.duplicate():
		if a.pid == rennes:
			g.armies.erase(a)
	check(g.unrest(rennes) >= float(g.bal.revolt_threshold), "uncored + war exhaustion = unrest %.1f" % g.unrest(rennes))
	g._revolt(p)
	check(p.owner == "BRI", "unruly conquest defects back to its former owner")
	# suppression lowers unrest
	var paris: int = g.key_to_pid["paris"]
	var u0: float = g.unrest(paris)
	g.nations.FRA.mil = 999.0
	check(g.suppress_unrest("FRA", paris) == "", "suppress works")
	check(g.unrest(paris) <= u0, "suppression does not raise unrest")
	# plain revolt without a former owner costs development
	var orl: int = g.key_to_pid["orleans"]
	var dev0: int = g.provinces[orl].dev
	g._revolt(g.provinces[orl])
	check(g.provinces[orl].dev == maxi(1, dev0 - 1) and g.provinces[orl].owner == "FRA", "revolt loots, province stays")
	# war exhaustion makes the AI accept peace more easily and can be reduced
	g.nations.FRA.dip = 999.0
	check(g.reduce_we("FRA") == "" and g.nations.FRA.we < 10.0, "reduce war exhaustion")
	# a strong vassal breaks free
	var g2 = new_game("FRA")
	g2.nations.BRI.overlord = "ENG"
	g2.add_rel("BRI", "ENG", -50.0)
	for a in g2.armies.duplicate():
		if a.owner == "ENG":
			g2.armies.erase(a)
	check(g2.liberty("BRI") >= float(g2.bal.vassal_liberty_threshold), "liberty high when overlord is weak")
	for i in 40:
		g2._liberty_yearly()
	check(g2.nations.BRI.overlord == "", "vassal declares independence")
	# save roundtrip keeps the new fields
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g3 = new_game("FRA")
	g3.from_dict(d)
	check(absf(g3.nations.FRA.we - g.nations.FRA.we) < 0.01 and g3.provinces[paris].suppress_months == 24, "unrest state saved")


func test_hre_election() -> void:
	var g = new_game("BOH")
	check(g.emperor == "HAB", "Habsburg starts as emperor")
	check(g.current_electors().size() == 7, "seven electors")
	var votes: Dictionary = g.election_votes()
	for e in votes:
		check(votes[e] != e, "electors never vote for themselves")
	# win over every elector: the player becomes emperor
	for e in g.current_electors():
		if e != "BOH":
			g.add_rel("BOH", e, 200.0)
	g.nations.BOH.prestige = 200.0
	g.hre_election()
	check(g.emperor == "BOH", "favoured candidate wins the election (got %s)" % g.emperor)
	check(g.monthly_power(g.nations.BOH, "dip") > g.monthly_power(g.nations.BOH, "adm") - 10, "emperor bonus applies")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 = new_game("BOH")
	g2.from_dict(d)
	check(g2.emperor == "BOH", "emperor saved")
	# new content conditions
	g2.nations.BOH.we = 5.0
	check(g2.check_conditions("BOH", {"we_min": 4, "is_vassal": false, "has_vassal": false}), "we_min / is_vassal / has_vassal")
	check(not g2.check_conditions("BOH", {"we_min": 6}), "we_min fails below")
	check(g2.check_conditions("BOH", {"unrest_min": 0}) and not g2.check_conditions("BOH", {"unrest_min": 50}), "unrest_min")
	check(g2.check_conditions("BOH", {"hre": true, "emperor": true}) and g2.check_conditions("FRA", {"hre": false, "emperor": false}), "hre / emperor")
	# a dead emperor triggers a new election at year end
	for pid in g.provinces_of("BOH").duplicate():
		g.provinces[pid].owner = "SAX"
	g._rebuild_owned()
	g._check_alive("BOH")
	g._yearly()
	check(g.emperor != "BOH" and g.emperor != "", "new emperor after the old one died")


func test_alliance_joins_war() -> void:
	var g = new_game("FRA")
	for t in g.order:
		g.nations[t].allies.clear()
	g._ally("BRI", "ENG")
	g.declare_war("FRA", "BRI")
	var w = g.war_between("FRA", "BRI")
	check(w.defenders.has("ENG"), "defensive ally joins")


func test_protector_defends_small_state() -> void:
	var g = new_game("")
	for t in g.order:
		g.nations[t].allies.clear()
	g.declare_war("FRA", "BRI")
	var w = g.war_between("FRA", "BRI")
	check(w.defenders.size() >= 2, "a neighbour protects Brittany (%s)" % str(w.defenders))
	check(not w.defenders.has("FRA"), "attacker is not a protector")


func test_coalition_forms() -> void:
	var g = new_game("")
	var n = g.nations.FRA
	n.ae = 150
	for i in 3:
		g._coalitions_yearly()
	check(n.coalition.size() >= 2, "coalition members joined (%d)" % n.coalition.size())
	var fought := false
	for w in g.wars:
		if w.coalition and w.defenders.has("FRA"):
			fought = true
	# with huge AE and weakened army a coalition war must start
	for a in g.armies_of("FRA"):
		a.regs = 1.0
	g._coalitions_yearly()
	for w in g.wars:
		if w.coalition and w.defenders.has("FRA"):
			fought = true
	check(fought, "coalition declares war")


func test_inherit() -> void:
	var g = new_game("FRA")
	g.apply_effects("SPA", {"inherit": "ARA"})
	check(not g.nations.ARA.alive, "Aragon gone after inheritance")
	check(g.provinces[g.key_to_pid["barcelona"]].owner == "SPA", "Spain owns Barcelona")


func test_inherit_never_takes_player() -> void:
	var g = new_game("BOH")
	g.apply_effects("HAB", {"inherit": "BOH"})
	check(g.nations.BOH.alive, "player nation is never inherited")


func test_economy_goods_and_trade() -> void:
	var g = new_game("FRA", 5)
	for p in g.provinces:
		check(g.goods_def.has(p.good), "%s has a known good" % p.key)
		check(g.markets.has(p.market), "%s trades in a market" % p.key)
	check(g.provinces[g.key_to_pid["venice"]].market == g.key_to_pid["venice"], "market center trades in itself")
	for i in 13:
		g.tick()
	var n = g.nations.FRA
	check(n.tax_income > 0.0 and n.prod_income > 0.0 and n.trade_income > 0.0, "income has tax, production and trade")
	check(absf(n.income - n.tax_income - n.prod_income - n.trade_income) < 0.001, "income is the sum of its parts")
	for k in g.prices:
		var base: float = float(g.goods_def[k].price)
		check(g.prices[k] >= base * 0.59 and g.prices[k] <= base * 1.61, "price of %s stays in bounds" % k)
	# merchants: count, send, recall
	var Eco = g.Economy
	check(n.merchants.size() == Eco.merchant_count(g, n), "AI/auto fills all merchant slots")
	var before: float = Eco.trade_income(g, n)
	var m: int = n.merchants[0]
	Eco.recall_merchant(g, "FRA", m)
	check(not n.merchant_auto and not n.merchants.has(m), "recall removes the merchant and stops auto mode")
	check(Eco.trade_income(g, n) < before, "recalling a merchant lowers trade income")
	check(Eco.send_merchant(g, "FRA", m) == "", "merchant can be sent again")
	check(Eco.send_merchant(g, "FRA", m) != "", "only one merchant per market")
	# goods leader bonus lands in n.bonus["goods"]
	for k in g.goods_leader:
		var t: String = g.goods_leader[k]
		for key in g.goods_def[k].bonus:
			check(g.nations[t].bonus.goods.get(key, 0.0) != 0.0, "%s gets the %s bonus" % [t, k])
	# more development, more of everything
	var p = g.provinces[g.key_to_pid["paris"]]
	var tax0: float = Eco.tax(g, p)
	var prod0: float = Eco.production_value(g, p)
	var tp0: float = Eco.province_trade_power(g, p)
	var mp0: float = Eco.local_manpower(g, p)
	p.dev += 6
	check(Eco.tax(g, p) > tax0 and Eco.production_value(g, p) > prod0 and Eco.province_trade_power(g, p) > tp0 \
			and Eco.local_manpower(g, p) > mp0, "development raises tax, production, trade power and manpower")


func test_harbor() -> void:
	var g = new_game("ENG", 5)
	var Eco = g.Economy
	var n = g.nations.ENG
	n.gold = 10000.0
	var london = g.provinces[g.key_to_pid["london"]]
	check(london.coastal, "London is coastal")
	var inland := -1
	for pid in g.provinces_of("ENG"):
		if not g.provinces[pid].coastal:
			inland = pid
	var coastal_count := 0
	for p in g.provinces:
		if p.coastal:
			coastal_count += 1
	check(coastal_count > 40 and coastal_count < g.provinces.size() - 20, "a plausible share of provinces is coastal")
	if inland >= 0:
		check(Eco.build_block_reason(g, "ENG", inland, "harbor") != "", "no harbor inland")
	var tp0: float = Eco.province_trade_power(g, london)
	london.buildings["harbor"] = 1
	Eco.refresh_local(g, london)
	check(Eco.province_trade_power(g, london) > tp0 + 2.9, "harbor adds trade power")
	g._update_cached(n)
	check(g.mod(n, "trade") >= 0.02, "harbor raises national trade income")


func test_loans_and_shocks() -> void:
	var g = new_game("FRA", 5)
	var Eco = g.Economy
	var n = g.nations.FRA
	n.gold = 0.0
	var size: float = Eco.loan_size(g, n)
	check(size >= float(g.bal.loan_min), "a loan is at least the minimum")
	check(Eco.take_loan(g, "FRA") == "" and n.gold == size, "taking a loan pays out gold")
	check(Eco.interest(g, n) > 0.0, "loans cost interest")
	var r1: float = Eco.loan_rate(g, n)
	Eco.take_loan(g, "FRA")
	check(Eco.loan_rate(g, n) > r1, "every further loan is more expensive")
	for i in 10:
		Eco.take_loan(g, "FRA")
	check(n.loans.size() == int(g.bal.max_loans), "loans are capped")
	n.gold = 0.0
	check(Eco.repay_loan(g, "FRA") != "", "repaying needs gold")
	n.gold = 100000.0
	check(Eco.repay_loan(g, "FRA") == "" and n.loans.size() == int(g.bal.max_loans) - 1, "repaying removes a loan")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.loans.size() == n.loans.size(), "loans are saved")
	# market shocks: price follows the shock, shocks expire
	var k: String = g.goods_def.keys()[0]
	g.shocks = {k: {"mult": 1.4, "years": 2}}
	g.bal.shock_chance = 0.0
	var base: float = g.prices[k]
	Eco.yearly(g)
	check(g.prices[k] > base * 1.2, "a scarcity shock raises the price")
	Eco.yearly(g)
	check(not g.shocks.has(k), "shocks expire")
	g.bal.shock_chance = 1.0
	Eco.yearly(g)
	check(g.shocks.size() == 1, "new shocks appear")


func test_trade_pacts() -> void:
	var g = new_game("FRA", 5)
	var Eco = g.Economy
	var n = g.nations.FRA
	n.dip = 500.0
	var other := ""
	for t in g.order:
		if t != "FRA" and g.nations[t].alive and not g.has_claim_on("FRA", t) and not g.has_claim_on(t, "FRA") and not g.at_war("FRA", t):
			other = t
			break
	var trade0: float = g.mod(n, "trade")
	n.relations[other] = 0.0
	g.nations[other].relations["FRA"] = 0.0
	check(Eco.offer_pact(g, "FRA", other) != "" and n.trade_pacts.is_empty(), "low relations: the AI declines a trade pact")
	g.nations[other].relations["FRA"] = 60.0
	n.relations[other] = 60.0
	check(Eco.offer_pact(g, "FRA", other) == "", "friendly nations accept a trade pact")
	check(n.trade_pacts.has(other) and g.nations[other].trade_pacts.has("FRA"), "pact is mutual")
	check(g.mod(n, "trade") > trade0, "pact raises trade income")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.trade_pacts.has(other) and g2.mod(g2.nations.FRA, "trade") > trade0, "pacts are saved")
	Eco.cancel_pact(g, "FRA", other)
	check(n.trade_pacts.is_empty() and absf(g.mod(n, "trade") - trade0) < 0.0001, "cancel removes the bonus")


func test_mercenaries() -> void:
	var g = new_game("FRA", 5)
	var n = g.nations.FRA
	n.gold = 1000.0
	n.manpower = 0.0
	var regs0: float = g.army_regs("FRA")
	check(g.recruit("FRA", n.capital, 1) != "", "no manpower: normal recruiting fails")
	check(g.hire_mercs("FRA", n.capital) == "", "mercenaries need no manpower")
	check(g.army_regs("FRA") > regs0 and n.gold < 1000.0, "mercenaries add regiments for gold")
	check(g.hire_mercs("FRA", n.capital) != "", "mercenaries have a cooldown")
	for i in int(g.bal.merc_cooldown):
		g.tick()
	n.gold = 1000.0
	check(g.merc_ready_in("FRA") == 0, "cooldown ends")


func test_army_power() -> void:
	var g = new_game("FRA", 5)
	var cap: int = g.nations.FRA.capital
	var a = g.spawn_army("FRA", cap, 5.0)
	check(a.power < g.power_max("FRA"), "fresh armies start below full power")
	var p0: float = a.power
	g._recover_power(a)
	check(a.power > p0, "power recovers over time")
	var regen_home: float = g.power_regen(a)
	var prov = g.provinces[cap]
	prov.buildings["road"] = 2
	g.Economy.refresh_local(g, prov)
	check(g.power_regen(a) > regen_home, "roads speed up recovery")
	for i in 40:
		g._recover_power(a)
	check(absf(a.power - g.power_max("FRA")) < 0.0001, "power ticks up to the maximum and stops")
	var full_f: float = g.power_factor(a)
	a.power = 0.0
	check(g.power_factor(a) < full_f and g.power_factor(a) > 0.0, "low power weakens the army in battle")
	# battle: winner loses a little, loser a lot
	var w = g.spawn_army("FRA", cap, 20.0)
	var l = g.spawn_army("ENG", cap, 2.0)
	w.power = 1.0
	l.power = 1.0
	g.nations.FRA.truces.erase("ENG")
	g.nations.ENG.truces.erase("FRA")
	g.declare_war("FRA", "ENG")
	var war = g.war_between("FRA", "ENG")
	g._battle(war, [w], [l], cap)
	check(w.power > 0.75 and w.power < 1.0, "a won battle costs some power")
	check(l.power < 0.6, "a lost battle costs a lot of power")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(absf(g2.army_by_id(w.id).power - w.power) < 0.0001, "army power is saved")


func test_peace_offer_cooldown() -> void:
	var g = new_game("ENG", 5)
	g.nations.FRA.truces.erase("ENG")
	g.nations.ENG.truces.erase("FRA")
	g.declare_war("FRA", "ENG")
	var w = g.war_between("FRA", "ENG")
	g.offer_peace("FRA", w, [], true)
	check(g.pending_peace.size() == 1, "AI offer to the player is queued")
	g.answer_player_peace(g.pending_peace[0], false)
	g.offer_peace("FRA", w, [], true)
	check(g.pending_peace.is_empty(), "no new offer right after a rejection")
	g.month += int(g.bal.peace_offer_cooldown)
	g.offer_peace("FRA", w, [], true)
	check(g.pending_peace.size() == 1, "after the cooldown the AI may offer again")


func test_autobuild() -> void:
	var g = new_game("FRA", 5)
	var n = g.nations.FRA
	n.gold = 150.0
	n.autobuild_reserve = 140.0
	check(g.Economy.autobuild(g, n) == 0, "autobuild off by default")
	n.autobuild = true
	check(g.Economy.autobuild(g, n) == 0, "autobuild never goes below the reserve")
	n.autobuild_reserve = 0.0
	n.gold = 1000.0
	check(g.Economy.autobuild(g, n) >= 1, "autobuild starts buildings above the reserve")
	check(n.gold >= 0.0, "autobuild keeps the treasury at or above the reserve")
	n.autobuild_reserve = 777.0
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.autobuild and g2.nations.FRA.autobuild_reserve == 777.0, "autobuild is saved")


func test_buildings() -> void:
	var g = new_game("FRA", 5)
	var Eco = g.Economy
	var pid: int = g.key_to_pid["paris"]
	var p = g.provinces[pid]
	var n = g.nations.FRA
	n.gold = 10000.0
	check(g.construct("FRA", g.key_to_pid["london"], "workshop") != "", "cannot build in foreign province")
	check(g.construct("FRA", pid, "manufactory") != "", "manufactory needs a workshop")
	var cost: float = Eco.building_cost(g, "FRA", pid, "workshop")
	var dev0: int = p.dev
	var prod0: float = Eco.production_value(g, p)
	check(g.construct("FRA", pid, "workshop") == "", "workshop can be built")
	check(absf(n.gold - (10000.0 - cost)) < 0.01, "building costs gold")
	check(g.construct("FRA", pid, "marketplace") != "", "one construction per province at a time")
	for i in 12:
		g.tick()
	check(Eco.level(p, "workshop") == 1 and p.constructing.is_empty(), "workshop finished after 12 months")
	check(p.dev == dev0 + 1, "a finished building level adds development")
	check(Eco.production_value(g, p) > prod0, "workshop raises production")
	check(Eco.building_cost(g, "FRA", pid, "workshop") > cost, "next level costs more")
	# slots
	p.buildings = {}
	p.dev = 7
	Eco.refresh_local(g, p)
	var free: int = Eco.slots(g, p)
	var ids: Array = ["marketplace", "workshop", "estate", "barracks", "courthouse", "fortress"]
	for i in free:
		p.buildings[ids[i]] = 1
	check(Eco.build_block_reason(g, "FRA", pid, ids[free]) != "", "no new building without a free slot")
	check(Eco.build_block_reason(g, "FRA", pid, ids[0]) == "", "upgrades do not need a slot")
	# barracks raise the force limit, courthouse lowers unrest, fortress counts as fort
	g._update_cached(n)
	var fl0: float = g.force_limit("FRA")
	var q = g.provinces[g.key_to_pid["orleans"]]
	q.buildings = {"barracks": 2, "courthouse": 1, "fortress": 1}
	Eco.refresh_local(g, q)
	g._update_cached(n)
	check(absf(g.force_limit("FRA") - fl0 - 2.0) < 0.01, "barracks level 2 adds 2 force limit")
	check(g.unrest_parts(q.id).buildings < 0.0, "courthouse and fortress lower unrest")
	check(Eco.fort_level(g, q) >= 1, "fortress counts as a fort")
	# save/load keeps buildings, construction and merchants
	n.gold = 10000.0
	g.construct("FRA", g.key_to_pid["lyon"], "estate")
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(text))
	check(JSON.stringify(g2.to_dict()) == text, "economy state survives save/load")
	check(g2.provinces[q.id].loc.get("unrest", 0.0) < 0.0, "building cache is rebuilt on load")


func test_army_stances() -> void:
	var g = new_game("BOH", 11)
	var n = g.nations.BOH
	n.army_stance = "defend"
	var a = g.spawn_army("BOH", n.capital, 6.0)
	check(a.auto and a.stance == "defend", "new armies follow the player's default stance")
	g.nations.BOH.truces.erase("BAV")
	g.nations.BAV.truces.erase("BOH")
	check(g.declare_war("BOH", "BAV") == "", "war declared")
	var ok := true
	for i in 36:
		g.tick()
		for x in g.armies_of("BOH"):
			if not x.auto or x.stance != "defend":
				continue
			var p = g.provinces[x.pid]
			var near: bool = g.ai._friendly(g, "BOH", p.owner)
			for nb in p.adj:
				near = near or g.ai._friendly(g, "BOH", g.provinces[nb].owner)
			ok = ok and near
	check(ok, "defending armies stay in or next to friendly land")
	var b = g.spawn_army("BOH", n.capital, 2.0)
	var t: int = g.ai.nearest_siege(g, b)
	check(t < 0 or g.at_war("BOH", g.provinces[t].controller), "quick order 'siege' points at enemy land")


func test_progression() -> void:
	var g = new_game("FRA", 4)
	var P = g.Progression
	check(P.rank(g, "FRA") == 0, "France (97 dev) starts as a duchy-level realm")
	check(g.nations.FRA.flags.get("rank", -1) == 0, "start rank recorded without news")
	var p = g.provinces[g.key_to_pid["paris"]]
	p.buildings = {"workshop": 1}
	g.Economy.refresh_local(g, p)
	var gold0: float = g.nations.FRA.gold
	var got: Array = P.check_milestones(g, "FRA")
	check(got.any(func(m): return m.id == "first_building"), "first building milestone reached")
	check(g.nations.FRA.gold > gold0, "milestone pays its reward")
	check(P.check_milestones(g, "FRA").is_empty(), "milestones pay only once")
	p.dev += 60
	g._update_cached(g.nations.FRA)
	P.yearly(g)
	check(P.rank(g, "FRA") == 1 and g.nations.FRA.bonus.rank.get("merchants", 0) == 1.0, "150 development makes a kingdom with bonus")


func test_save_roundtrip() -> void:
	var g = new_game("ENG", 3)
	for i in 30:
		g.tick()
	var d: Dictionary = g.to_dict()
	var text := JSON.stringify(d)
	var g2 = new_game("ENG", 99)
	g2.from_dict(JSON.parse_string(text))
	check(JSON.stringify(g2.to_dict()) == text, "save/load round trip is identical")
	for i in 12:
		g.tick()
		g2.tick()
	# JSON keeps ~15 significant digits, so allow tiny float drift
	check(g.month == g2.month and absf(g.nations.ENG.gold - g2.nations.ENG.gold) < 1.0, "game continues identically after load")


func test_missions_complete() -> void:
	var g = new_game("SPA")
	g.apply_effects("SPA", {"province": "pamplona"})
	check(g.provinces[g.key_to_pid["pamplona"]].owner == "SPA", "province effect works")
	check(g.complete_mission("SPA", "spa_navarre") == "", "mission completes")
	check(g.complete_mission("SPA", "spa_navarre") != "", "mission only once")


func test_long_run_no_softlock() -> void:
	var g = new_game("HAB", 11)
	# a shortened game (50 years) keeps the test fast; the end-of-game logic is the same
	g.bal.total_months = 600
	var months := int(g.bal.total_months)
	for i in months + 5:
		# simulate a passive player who always picks the first event option and accepts peace
		while not g.pending_events.is_empty():
			g.choose_event_option("HAB", g.pending_events[0], 0)
		while not g.pending_peace.is_empty():
			g.answer_player_peace(g.pending_peace[0], true)
		g.tick()
	check(g.game_over, "game ends after the last month")
	check(g.month == months or not g.nations.HAB.alive, "ended at the right month (%d)" % g.month)
	var stuck := 0
	for w in g.wars:
		if g.month - w.start > int(g.bal.war_timeout_months):
			stuck += 1
	check(stuck == 0, "no war older than the timeout")


# ---------------------------------------------------------------- tech tree + government

const Tech = preload("res://scripts/core/tech.gd")


func test_tech_data() -> void:
	var td: Dictionary = data.techs
	var ids := {}
	var per_cat := {"adm": 0, "dip": 0, "mil": 0}
	for t in td.techs + td.special:
		check(not ids.has(t.id), "tech id %s unique" % t.id)
		ids[t.id] = true
		check(per_cat.has(t.cat), "tech %s has a valid category" % t.id)
		for k in t.effects:
			check(Tech.LABELS.has(k), "tech %s effect key %s has a label" % [t.id, k])
	for t in td.techs:
		per_cat[t.cat] += 1
	for t in td.techs + td.special:
		for r in t.get("req", []):
			check(ids.has(r), "tech %s requirement %s exists" % [t.id, r])
	for c in per_cat:
		check(per_cat[c] == 27, "27 generic %s techs" % c)
	for tag in data.nations:
		if data.nations[tag].get("playable", false):
			var n := 0
			for t in td.special:
				if t.tag == tag:
					n += 1
			check(n == 3, "%s has 3 special techs" % tag)


func test_tech_tree() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	n.adm = 900.0
	check(g.research("FRA", "adm_landvoegte") != "", "requirement blocks research")
	check(g.research("FRA", "adm_kanzlei") == "", "first adm tech researched")
	check(n.tech.adm == 1 and n.techs.has("adm_kanzlei"), "level and id recorded")
	check(g.research("FRA", "adm_kanzlei") != "", "no double research")
	check(g.research("FRA", "adm_landvoegte") == "", "second tech after its requirement")
	check(g.research("FRA", "adm_kataster") != "", "year lock (1484 tech in 1444)")
	var before: float = n.adm
	var c: float = g.tech_cost("FRA", "adm")
	check(g.research("FRA", "adm_zuenfte") == "", "other branch researched")
	check(absf(before - c - n.adm) < 0.01, "research costs tech_cost")
	n.dip = 0.0
	check(g.research("FRA", "dip_gesandte") != "", "not enough power blocks research")
	n.mil = 900.0
	check(g.buy_tech("FRA", "mil") == "", "buy_tech picks a tech automatically")
	check(n.tech.mil == 1, "buy_tech advanced mil")


func test_special_techs() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	n.mil = 900.0
	check(g.research("FRA", "fra_ordonnance") != "", "special tech needs its requirement")
	check(g.research("FRA", "mil_pikenhaufen") == "", "requirement researched")
	var lvl: int = n.tech.mil
	check(g.research("FRA", "fra_ordonnance") == "", "special tech researched")
	check(n.tech.mil == lvl, "special techs do not count as levels")
	g.nations.ENG.mil = 900.0
	g.research("ENG", "mil_pikenhaufen")
	check(g.research("ENG", "fra_ordonnance") != "", "other nations cannot take French special techs")
	var spec := 0
	for t in g.tree.techs_for("ENG", "mil"):
		if Tech.is_special(t):
			check(t.tag == "ENG", "techs_for only lists own specials")
			spec += 1
	check(spec >= 1, "ENG sees its mil special tech")
	# AI path prefers available special techs
	var g2 = new_game("ENG")
	g2.nations.FRA.mil = 900.0
	g2.research("FRA", "mil_pikenhaufen")
	check(g2.tree.best_choice(g2, "FRA", "mil") == "fra_ordonnance", "AI picks the special tech first")


func test_tech_modifiers() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	n.mil = 2000.0
	n.adm = 2000.0
	g.research("FRA", "mil_lehnsaufgebot")
	var fl: float = g.force_limit("FRA")
	g.research("FRA", "mil_soldwesen")
	check(absf(g.force_limit("FRA") - fl - 2.0) < 0.01, "force limit +1 from tech, +1 from the second mil level")
	g.research("FRA", "adm_universitaet")
	var with_bonus: float = g.tech_cost("FRA", "adm")
	var saved: Dictionary = n.bonus.tech
	n.bonus.tech = {}
	var without: float = g.tech_cost("FRA", "adm")
	n.bonus.tech = saved
	check(absf(with_bonus - round(without * 0.97)) <= 1.0, "tech_cost modifier applies (%d vs %d)" % [with_bonus, without])
	check(absf(g.mod(n, "tech_cost") + 0.03) < 0.001, "bonus tech recorded in mod()")
	check(g.ae_mult("FRA") == 1.0, "no ae modifier yet")
	check(g.core_time("FRA") == int(g.bal.core_months), "default core time")


func test_government_data() -> void:
	var gd: Dictionary = data.government
	var ids := {}
	for a in gd.advisors:
		check(not ids.has(a.id), "advisor %s unique" % a.id)
		ids[a.id] = true
		check(["adm", "dip", "mil"].has(a.type), "advisor %s type" % a.id)
		for k in a.effects:
			check(Tech.LABELS.has(k), "advisor %s key %s has a label" % [a.id, k])
		if a.has("tag"):
			check(data.nations.has(a.tag) and int(a.from) <= int(a.to), "national advisor %s valid" % a.id)
	for c in gd.companies:
		for k in c.effects:
			check(Tech.LABELS.has(k), "company %s key %s has a label" % [c.id, k])
	var tech_ids := {}
	for t in data.techs.techs:
		tech_ids[t.id] = true
	for l in gd.laws:
		check(l.options[0].effects.is_empty(), "law %s default option has no effects" % l.id)
		for o in l.options:
			if o.has("req"):
				check(tech_ids.has(o.req), "law option %s requirement exists" % o.id)
			var good := false
			var bad := false
			for line in Tech.effect_lines(o.effects):
				if line[1]:
					good = true
				else:
					bad = true
			check(o.effects.is_empty() or (good and bad), "law option %s is a trade-off" % o.id)
	for tag in data.nations:
		if data.nations[tag].get("playable", false):
			var na := 0
			var nc := 0
			for a in gd.advisors:
				if a.get("tag", "") == tag:
					na += 1
			for c in gd.companies:
				if c.get("tag", "") == tag:
					nc += 1
			check(na >= 3 and nc >= 1, "%s has national advisors and a company" % tag)


func test_advisors() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	n.adm = 500.0
	n.dip = 500.0
	n.mil = 500.0
	var pool := []
	for a in g.govt.advisor_pool(g, "FRA"):
		pool.append(a.id)
	check(pool.has("fra_coeur"), "Jacques Coeur available in 1444")
	check(not pool.has("fra_richelieu"), "Richelieu not yet born")
	check(not pool.has("eng_cromwell"), "no foreign national advisors")
	var inc: float = g.mod(n, "income")
	check(g.govt.hire(g, "FRA", "kaemmerer") == "", "hire advisor")
	check(absf(g.mod(n, "income") - inc - 0.06) < 0.001, "advisor bonus applies")
	check(absf(n.adm - (500.0 - g.govt.advisor_cost(g, n, "kaemmerer"))) < 0.01, "advisor costs power of its type")
	check(g.govt.hire(g, "FRA", "kaemmerer") != "", "no double hire")
	g.govt.hire(g, "FRA", "fra_coeur")
	g.govt.hire(g, "FRA", "feldhauptmann")
	check(g.govt.hire(g, "FRA", "gesandter") != "", "slot limit of 3")
	g.govt.dismiss(g, "FRA", "kaemmerer")
	check(absf(g.mod(n, "income") - inc - 0.03) < 0.001, "dismissal removes bonus (Coeur keeps +3 %)")
	# national advisors leave after their time
	g.month = (1457 - 1444) * 12
	g.govt.yearly(g, n)
	check(not n.gov.advisors.has("fra_coeur"), "Coeur leaves court after 1456")


func test_companies() -> void:
	var g = new_game("ENG")
	var n = g.nations.ENG
	n.gold = 5000.0
	var cost: float = g.govt.company_cost(g, n, "lombarden")
	check(cost >= float(data.government.company_min_gold), "company has a minimum price")
	check(g.govt.found_company(g, "ENG", "eng_muscovy") != "", "Muscovy Company only from 1555")
	check(g.govt.found_company(g, "ENG", "fra_lyon") != "", "foreign company blocked")
	check(g.govt.found_company(g, "ENG", "lombarden") == "", "found company")
	check(absf(n.gold - (5000.0 - cost)) < 0.01, "company costs gold")
	check(g.govt.found_company(g, "ENG", "kaufmannsgilde") == "", "second company")
	check(g.govt.found_company(g, "ENG", "bergbau") != "", "two company slots")
	n.dip = 5000.0
	for id in ["dip_messen", "dip_wechsel"]:
		check(g.research("ENG", id) == "", "research " + id)
	g.month = (1580 - 1444) * 12
	for id in ["dip_gilden", "dip_karavellen", "dip_boersen", "dip_girobanken", "dip_aktien"]:
		g.research("ENG", id)
	check(g.govt.company_slots(g, n) == 3, "Aktiengesellschaften unlock a third slot")
	check(g.govt.found_company(g, "ENG", "bergbau") == "", "third company")
	g.govt.dissolve_company(g, "ENG", "bergbau")
	check(not n.gov.companies.has("bergbau"), "dissolve company")


func test_laws() -> void:
	var g = new_game("SPA")
	var n = g.nations.SPA
	n.adm = 500.0
	n.mil = 500.0
	check(n.gov.laws.heer == "lehnsheer", "default law")
	check(g.govt.set_law(g, "SPA", "heer", "stehendes_heer") != "", "law needs its tech")
	var mp: float = g.mod(n, "manpower")
	check(g.govt.set_law(g, "SPA", "heer", "landesaufgebot") == "", "change law")
	check(absf(g.mod(n, "manpower") - mp - 0.25) < 0.001, "law buff applies")
	check(g.mod(n, "combat") < float(data.nations.SPA.bonus.combat), "law nerf applies")
	check(g.govt.set_law(g, "SPA", "heer", "soeldner") != "", "cooldown blocks changes")
	check(g.check_conditions("SPA", {"law": {"heer": "landesaufgebot"}}), "law condition")
	check(not g.check_conditions("SPA", {"has_tech": "adm_kanzlei"}), "has_tech condition (missing)")
	var pid: int = g.provinces_of("SPA")[0]
	check(absf(g.unrest_parts(pid).policy - 0.5) < 0.001, "law unrest shows in province unrest")
	g.month += 121
	check(g.govt.set_law(g, "SPA", "heer", "soeldner") == "", "law change after cooldown")


func test_gov_save_roundtrip() -> void:
	var g = new_game("POL", 5)
	var n = g.nations.POL
	n.adm = 900.0
	n.dip = 900.0
	n.gold = 900.0
	g.govt.hire(g, "POL", "pol_olesnicki")
	g.month = (1470 - 1444) * 12
	g.research("POL", "dip_messen")
	g.research("POL", "pol_kornhandel")
	g.govt.found_company(g, "POL", "pol_danzig")
	g.govt.set_law(g, "POL", "kirche", "toleranz")
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("POL", 9)
	g2.from_dict(JSON.parse_string(text))
	check(JSON.stringify(g2.to_dict()) == text, "tech/government state survives save/load")
	var n2 = g2.nations.POL
	check(n2.techs.has("pol_kornhandel") and n2.gov.advisors.has("pol_olesnicki") and n2.gov.companies.has("pol_danzig"),
			"techs, advisors and companies restored")
	for k in ["trade", "dip", "unrest", "income", "prestige"]:
		check(absf(g.mod(n, k) - g2.mod(n2, k)) < 0.0001, "bonus %s rebuilt after load" % k)


func test_old_save_tech_levels() -> void:
	var g = new_game("FRA", 4)
	g.nations.FRA.tech = {"adm": 4, "dip": 2, "mil": 3}
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	for tag in d.nations:
		d.nations[tag].erase("techs")
		d.nations[tag].erase("gov")
	var g2 = new_game("FRA", 4)
	g2.from_dict(d)
	var n = g2.nations.FRA
	check(n.techs.size() == 9, "old save: levels turn into the oldest techs (%d)" % n.techs.size())
	check(n.gov.laws.size() == data.government.laws.size(), "old save: default laws")
	check(g2.research("FRA", "adm_kanzlei") != "", "old save: granted techs count as researched")


func test_ai_uses_government() -> void:
	var g = new_game("FRA", 21)
	for i in 12 * 40:
		while not g.pending_events.is_empty():
			g.choose_event_option("FRA", g.pending_events[0], 0)
		while not g.pending_peace.is_empty():
			g.answer_player_peace(g.pending_peace[0], true)
		g.tick()
	var adv := 0
	var comp := 0
	var laws := 0
	var spec := 0
	var alive := 0
	for tag in g.order:
		var n = g.nations[tag]
		if not n.alive or tag == "FRA":
			continue
		alive += 1
		adv += n.gov.advisors.size()
		comp += n.gov.companies.size()
		for l in n.gov.laws:
			if n.gov.laws[l] != g.govt.law_by_id[l].options[0].id:
				laws += 1
		for t in g.tree.specials_of(tag):
			if n.techs.has(t.id):
				spec += 1
	print("    AI 1484: %d nations, %d advisors, %d companies, %d laws changed, %d special techs" % [alive, adv, comp, laws, spec])
	check(adv >= alive, "AI hires advisors")
	check(comp >= alive / 2, "AI founds companies")
	check(laws >= alive / 2, "AI changes laws")
	check(spec >= 5, "AI researches special techs")
## Every emoji in UI code and data/*.json needs a pixel glyph (scripts/ui/pixel_emoji.gd); there is no emoji font.
## Nation emoji are exempt (nations show their flag) but every nation needs one.
func test_emoji_coverage() -> void:
	var have: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/emoji/emoji.json"))
	var files := []
	for f in DirAccess.get_files_at("res://data"):
		# nation emoji are replaced by flags; the map has no text
		if f.ends_with(".json") and f != "nations.json" and f != "map.json":
			files.append("res://data/" + f)
	for f in DirAccess.get_files_at("res://scripts/ui"):
		if f.ends_with(".gd"):
			files.append("res://scripts/ui/" + f)
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for i in text.length():
			var c := text.unicode_at(i)
			# emoji blocks; leaves arrows, maths signs, box drawing and the variation selector alone
			if (c >= 0x2300 and c < 0x2500) or (c >= 0x25A0 and c < 0x2C00) or c >= 0x1F000:
				check(have.has("%x" % c), "%s: no pixel glyph for %s (U+%X), add it in tools/art/emoji_icons.py" % [path, char(c), c])
	for tag in data.nations:
		check(ResourceLoader.exists("res://assets/art/icons/flag_%s.png" % tag), "nation %s has no flag" % tag)


## Every event's picture (own "image" or the generated motif map) must exist; tools/art/event_motifs.py.
func test_event_pictures() -> void:
	var motifs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/events/event_motifs.json"))
	for e in data.events:
		var m: String = e.get("image", motifs.get(e.id, "court"))
		check(ResourceLoader.exists("res://assets/art/events/%s.png" % m), "event %s: picture %s missing" % [e.id, m])


func test_company_invest() -> void:
	var g = new_game("HAB")
	var n = g.nations.HAB
	n.gold = 100000.0
	g.month = (1495 - 1444) * 12
	check(g.govt.found_company(g, "HAB", "hab_fugger") == "", "found Fugger")
	check(g.govt.invest_level(n, "hab_fugger") == 1, "new company starts at level 1")
	var inc: float = g.mod(n, "income")
	var ae: float = g.mod(n, "ae_gen")
	check(g.govt.invest(g, "HAB", "hab_fugger", 1) != "", "cannot invest to the same level")
	var c: float = g.govt.invest_cost(g, n, "hab_fugger", 3)
	var gold: float = n.gold
	check(c > g.govt.company_cost(g, n, "hab_fugger") * 0.5, "two levels cost more than half a company")
	check(g.govt.invest(g, "HAB", "hab_fugger", 3) == "", "invest two levels")
	check(absf(gold - c - n.gold) < 0.01, "investment costs gold")
	check(absf(g.mod(n, "income") - inc - 0.15 * 1.0) < 0.001, "benefit +100 % at level 3 (+15 % more income)")
	check(absf(g.mod(n, "ae_gen") - ae) < 0.001, "drawback unchanged")
	check(g.govt.invest(g, "HAB", "hab_fugger", 6) != "", "max level 5")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var g2 = new_game("HAB")
	g2.from_dict(d)
	check(g2.govt.invest_level(g2.nations.HAB, "hab_fugger") == 3, "investment level survives save/load")
	check(absf(g2.mod(g2.nations.HAB, "income") - g.mod(n, "income")) < 0.0001, "scaled bonus rebuilt after load")
	g.govt.dissolve_company(g, "HAB", "hab_fugger")
	check(not n.gov.invest.has("hab_fugger"), "dissolving drops the investment")


func test_estates() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	check(n.gov.estates.size() == 3, "three estates")
	for e in g.govt.estates:
		check(g.event_by_id.has("estate_crisis_" + e.id), "crisis event for %s registered" % e.id)
		check(not g.event_defs.has(g.event_by_id["estate_crisis_" + e.id]), "crisis events are not in the random pool")
	n.adm = 500.0
	check(g.govt.set_law(g, "FRA", "staat", "staendestaat") == "", "Ständestaat")
	check(absf(g.govt.estate_target(g, n, "adel") - 65.0) < 0.01, "law shifts the nobility's target to 65")
	for i in 60:
		g.govt.estates_monthly(g, n)
	check(n.gov.estates.adel > 60.0, "nobility drifts towards its target (%.1f)" % n.gov.estates.adel)
	g.govt.change_estate(g, n, "adel", 5.0)
	check(n.gov.estates.adel >= 65.0 and g.govt.estate_tier(n, "adel") == "loyal", "nobility is loyal from 65 (%.1f)" % n.gov.estates.adel)
	check(n.bonus.estates.get("manpower", 0.0) > 0.0, "loyal nobility gives manpower")
	g.govt.change_estate(g, n, "klerus", -40.0)
	check(g.govt.estate_tier(n, "klerus") == "angry", "angry clergy")
	var pid: int = g.provinces_of("FRA")[0]
	check(absf(g.unrest_parts(pid).estates - 1.0) < 0.001, "angry clergy shows as its own unrest item")
	n.gold = 1000.0
	var before: float = n.gov.estates.klerus
	check(g.govt.grant_concession(g, "FRA", "klerus") == "", "concession")
	check(absf(n.gov.estates.klerus - before - 20.0) < 0.01, "concession +20")
	check(g.govt.grant_concession(g, "FRA", "klerus") != "", "concession cooldown")
	n.gov.estates.buerger = 50.0
	g.apply_effects("FRA", {"estate": {"buerger": -30}})
	check(absf(n.gov.estates.buerger - 20.0) < 0.01, "estate effect")
	check(g.check_conditions("FRA", {"estate_max": {"buerger": 25}}) and not g.check_conditions("FRA", {"estate_min": {"buerger": 25}}), "estate conditions")
	# crisis fires for the player at most once per estate_crisis_years
	g.month = 120
	var fired := 0
	for y in 8:
		g.month += 12
		g.pending_events.clear()
		n.gov.estates.buerger = 10.0
		for i in 20:
			g.govt._estate_crisis(g, n)
		fired += g.pending_events.size()
	check(fired >= 1 and fired <= 2, "estate crisis at most every 4 years (%d in 8 years)" % fired)
	g.govt.change_estate(g, n, "adel", 80.0 - n.gov.estates.adel)
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 3)
	g2.from_dict(JSON.parse_string(text))
	check(JSON.stringify(g2.to_dict()) == text, "estates survive save/load")
	check(g2.govt.estate_tier(g2.nations.FRA, "adel") == "loyal" and g2.nations.FRA.bonus.estates.has("manpower"), "estate bonus rebuilt after load")


## Government events (tools/content/gov_events.py) reference real laws, techs and estates and fire once their law is set.
func test_gov_events() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var count := 0
	for e in data.events:
		if not e.id.begins_with("gov_"):
			continue
		count += 1
		var tr: Dictionary = e.trigger
		for l in tr.get("law", {}):
			check(g.govt.law_by_id.has(l) and not g.govt.law_option(l, tr.law[l]).is_empty(), "%s: law %s exists" % [e.id, l])
		if tr.has("has_tech"):
			check(g.tree.by_id.has(tr.has_tech), "%s: tech %s exists" % [e.id, tr.has_tech])
		for k in ["estate_min", "estate_max"]:
			for es in tr.get(k, {}):
				check(n.gov.estates.has(es), "%s: estate %s exists" % [e.id, es])
		for o in e.options:
			for es in o.effects.get("estate", {}):
				check(n.gov.estates.has(es), "%s: effect estate %s exists" % [e.id, es])
	check(count >= 15, "at least 15 government events (%d)" % count)
	var ev: Dictionary = g.event_by_id["gov_heretics"]
	g.month = (1510 - 1444) * 12
	check(not g.check_conditions("FRA", ev.trigger), "heretics need Glaubenseifer")
	n.gov.laws["kirche"] = "glaubenseifer"
	check(g.check_conditions("FRA", ev.trigger), "heretics fire under Glaubenseifer")
	var before: float = n.gov.estates.klerus
	g.choose_event_option("FRA", "gov_heretics", 0)
	check(n.gov.estates.klerus > before, "inquisition pleases the clergy")


## EU5-style budget sliders: neutral by default, effects and gold per step, saved, AI tightens when poor.
func test_budget() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var gv = g.govt
	check(gv.budget.size() == 4, "four budget sliders")
	check(n.bonus.budget.is_empty() and absf(gv.budget_cost(g, n)) < 0.001, "default budget is neutral")
	g.tick()
	var inc: float = n.income
	check(gv.set_budget(g, "FRA", "hof", 4) == "", "set court to max")
	check(absf(gv.budget_cost(g, n) - 0.08 * inc) < 0.001, "lavish court costs 8 % of income")
	check(absf(n.bonus.budget.prestige - 2.0) < 0.001 and n.bonus.budget.estate_adel > 0.0, "court gives prestige and pleases the nobility")
	check(gv.set_budget(g, "FRA", "steuern", 0) == "", "set taxes to minimum")
	check(absf(n.bonus.budget.tax + 0.2) < 0.001 and n.bonus.budget.unrest < 0.0, "mild taxes: less tax, less unrest")
	check(gv.set_budget(g, "FRA", "bildung", 9) == "" and gv.budget_step(n, "bildung") == 4, "slider clamped to max")
	check(gv.budget_slider_cost(n, "bildung", 0) < 0.0, "cutting research saves gold")
	var exp_before: float = n.expenses
	g.tick()
	check(n.expenses > 0.0 and absf(gv.budget_cost(g, n)) > 0.0, "budget cost is part of expenses (%.2f vs %.2f)" % [n.expenses, exp_before])
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 3)
	g2.from_dict(JSON.parse_string(text))
	check(g2.govt.budget_step(g2.nations.FRA, "hof") == 4 and g2.nations.FRA.bonus.budget.has("prestige"), "budget survives save/load")
	var ai = g.nations.ENG
	ai.gold = 0.0
	gv._ai_budget(g, ai)
	check(gv.budget_step(ai, "hof") == 1 and gv.budget_step(ai, "bildung") == 1, "poor AI cuts court and research")
	ai.gold = 5000.0
	gv._ai_budget(g, ai)
	check(gv.budget_step(ai, "hof") == 3 and gv.budget_step(ai, "bildung") == 3, "rich AI spends on court and research")

