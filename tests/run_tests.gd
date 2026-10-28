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
		"test_economy_goods_and_trade", "test_buildings", "test_autobuild", "test_army_power", "test_road_march", "test_power_actions", "test_building_gain", "test_marriage", "test_generals", "test_peace_offer_cooldown", "test_mercenaries", "test_trade_pacts", "test_loans_and_shocks", "test_harbor", "test_army_stances", "test_progression", "test_coalition_forms", "test_inherit", "test_inherit_never_takes_player", "test_save_roundtrip",
		"test_separate_peace", "test_tired_ai_seeks_peace", "test_ai_marriage_and_generals", "test_ai_access_and_guarantee", "test_income_bonus_and_army_cost",
		"test_difficulty",
		"test_march_time_and_terrain", "test_interception", "test_battle_rounds",
		"test_naval",
		"test_ai_peace_spending",
		"test_ai_war_odds",
		"test_military_access",
		"test_guarantee",
		"test_religion",
		"test_monuments_and_feast", "test_first_steps", "test_score_history",
		"test_missions_complete", "test_tech_data", "test_tech_tree", "test_special_techs", "test_tech_modifiers",
		"test_government_data", "test_advisors", "test_companies", "test_laws", "test_gov_save_roundtrip", "test_company_invest", "test_estates", "test_gov_events", "test_budget", "test_eco_content", "test_rel_content", "test_court_content", "test_monument_events", "test_south_content", "test_morale_modifiers", "test_reforms", "test_tech_spread",
		"test_empire_reforms",
		"test_religion_modifiers",
		"test_age_goals",
		"test_advisor_skill",
		"test_gov_forms",
		"test_tech_ahead",
		"test_tech_queue",
		"test_heir",
		"test_building_tech",
		"test_gov_sources",
		"test_regency",
		"test_form_change",
		"test_old_save_tech_levels", "test_ai_uses_government", "test_long_run_no_softlock", "test_emoji_coverage", "test_event_pictures", "test_ui_kit",
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
	n.adm = 0
	n.dip = 500
	var d2: int = g.provinces[pid].dev
	check(g.develop("FRA", pid, "dip") == "", "develop with diplomacy")
	check(g.provinces[pid].dev == d2 + 1 and n.dip < 500 and n.adm == 0, "diplomacy paid, admin untouched")
	n.mil = 0
	check(g.develop("FRA", pid, "mil") != "", "develop fails without mil")
	# capped power is not lost: the player's overflow goes into the cheapest development
	var g2 = new_game("FRA")
	var n2 = g2.nations.FRA
	var cheap: int = g2.cheapest_develop("FRA")
	var dev_before: int = g2.provinces[cheap].dev
	n2.mil = float(g2.bal.power_cap)
	g2._overflow_develop(n2)
	check(g2.provinces[cheap].dev == dev_before + 1 and n2.mil < float(g2.bal.power_cap), "overflow develops the cheapest province")
	n2.adm = 10.0
	g2._overflow_develop(n2)
	check(n2.adm == 10.0, "no overflow spending below the cap")


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


func test_separate_peace() -> void:
	var g = new_game("FRA")
	for t in g.order:
		g.nations[t].allies.clear()
		g.nations[t].truces.clear()
	g._ally("BRI", "ENG")
	g.declare_war("FRA", "BRI")
	var w = g.war_between("FRA", "BRI")
	check(g.leave_war("BRI", w) != "", "the war leader cannot leave its own war")
	check(g.leave_war("FRA", w) != "", "nor can the attacking leader")
	var york: int = g.key_to_pid["york"]
	g.provinces[york].controller = "FRA"
	var rel_before: float = g.get_rel("BRI", "ENG")
	check(g.leave_war("ENG", w) == "", "an ally may make a separate peace")
	check(not w.defenders.has("ENG") and g.wars.has(w), "the war goes on without the ally")
	check(g.provinces[york].controller == "ENG", "occupations between the two end")
	check(g.has_truce("ENG", "FRA"), "a truce follows")
	check(g.get_rel("BRI", "ENG") < rel_before, "the abandoned leader resents it")


func test_tired_ai_seeks_peace() -> void:
	var g = new_game("ENG")
	for t in g.order:
		g.nations[t].allies.clear()
		g.nations[t].truces.clear()
	g._ally("BRI", "SPA")
	g.declare_war("FRA", "BRI")
	var w = g.war_between("FRA", "BRI")
	w.start = g.month - 24
	g.nations.SPA.we = float(g.bal.we_max)
	g.ai._consider_peace(g, g.nations.SPA)
	check(not w.defenders.has("SPA"), "an exhausted ally leaves a war it is not winning")
	g.nations.FRA.we = float(g.bal.we_max)
	g.nations.BRI.we = float(g.bal.we_max)
	g.ai._consider_peace(g, g.nations.FRA)
	check(not g.wars.has(w), "an exhausted leader settles an even war")


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


func test_road_march() -> void:
	var g = new_game("FRA", 5)
	var W = g.Warfare
	var cap: int = g.nations.FRA.capital
	var path: Array = []
	for pid in g.provinces_of("FRA"):
		var pp: Array = g.find_path("FRA", cap, pid)
		if pp.size() >= 4:
			path = pp
			break
	check(path.size() >= 4, "France has a province three marches from the capital")
	var a = g.spawn_army("FRA", cap, 3.0)
	var slow: float = W.speed(g, a, path[0], path[1])
	for pid in path:
		g.provinces[pid].buildings["road"] = 2
	check(absf(W.speed(g, a, path[0], path[1]) - slow - 2 * float(g.bal.road_speed)) < 0.0001, "two road levels add march speed")
	var e = g.spawn_army("ENG", cap, 3.0)
	check(W.road_bonus(g, "ENG", path[0], path[1]) == 0.0, "roads only help their owner")
	g.armies.erase(e)
	g.move_army(a, path[-1])
	var months := 0
	while a.pid != path[-1] and months < 20:
		g._armies_tick()
		months += 1
	check(a.pid == path[-1] and a.target == -1, "the army arrives and stops")
	check(months <= W.eta(g, a) + 6, "march time is finite")


func test_march_time_and_terrain() -> void:
	var g = new_game("FRA", 5)
	var W = g.Warfare
	var t: Dictionary = {}
	for p in g.provinces:
		t[p.terrain] = true
	check(t.has("mountains") and t.has("plains") and t.has("desert"), "provinces have terrain")
	var mtn: int = g.key_to_pid["tirol"]
	check(g.provinces[mtn].terrain == "mountains", "Tirol is mountains")
	var nb: int = g.provinces[mtn].adj[0]
	var flat_cost: float = g.provinces[nb].center.distance_to(g.provinces[mtn].center) / float(g.bal.march_px_per_month)
	flat_cost = clampf(flat_cost, float(g.bal.march_min_months), float(g.bal.march_max_months))
	check(W.step_cost(g, nb, mtn) > flat_cost * 1.5, "marching into the mountains takes longer")
	var lon: int = g.key_to_pid["london"]
	var cal: int = g.key_to_pid["calais"]
	check(W.is_strait(g, lon, cal) and W.is_strait(g, cal, lon), "the Channel is a sea crossing")
	check(W.step_cost(g, lon, cal) >= float(g.bal.strait_months), "a sea crossing costs extra months")
	# an army stays put until the step is done, then arrives
	var a = g.spawn_army("FRA", g.nations.FRA.capital, 4.0)
	var to: int = -1
	for x in g.provinces[a.pid].adj:
		if g.provinces[x].owner == "FRA" and W.step_cost(g, a.pid, x) > 1.0:
			to = x
	if to >= 0:
		var from: int = a.pid
		g.move_army(a, to)
		g._armies_tick()
		check(a.pid == from and a.move > 0.0, "a long step is not done in one month")
		check(W.eta(g, a) >= 1, "eta counts the remaining months")
		var other: int = -1
		for x in g.provinces[from].adj:
			if x != to and g.can_enter("FRA", x):
				other = x
		if other >= 0:
			g.move_army(a, other)
			check(a.move == 0.0, "turning round throws the march progress away")


func test_interception() -> void:
	var g = new_game("FRA", 5)
	var W = g.Warfare
	g.nations.FRA.truces.erase("ENG")
	g.nations.ENG.truces.erase("FRA")
	g.declare_war("FRA", "ENG")
	g.bal.march_min_months = 0.1
	g.bal.march_max_months = 0.2
	var x: int = g.nations.FRA.capital
	var y: int = -1
	for nb in g.provinces[x].adj:
		if g.provinces[nb].owner == "FRA" and not W.is_strait(g, x, nb):
			y = nb
			break
	var f = g.spawn_army("FRA", x, 5.0)
	var e = g.spawn_army("ENG", y, 5.0)
	g.move_army(f, y)
	e.target = x
	e.path = g.find_path("ENG", y, x)
	W.move_armies(g)
	check(f.pid == e.pid, "armies marching past each other meet instead of swapping places")
	W.gather(g)
	check(W.in_battle(g, f) and W.in_battle(g, e), "the meeting starts a battle")
	check(g.move_army(f, x) != "", "an army in battle cannot march away")


func test_battle_rounds() -> void:
	var g = new_game("FRA", 5)
	var W = g.Warfare
	g.nations.FRA.truces.erase("ENG")
	g.nations.ENG.truces.erase("FRA")
	g.declare_war("FRA", "ENG")
	var pid: int = g.nations.FRA.capital
	var f = g.spawn_army("FRA", pid, 10.0)
	var e = g.spawn_army("ENG", pid, 10.0)
	f.power = 1.0
	e.power = 1.0
	W.gather(g)
	var b = W.battle_at(g, pid)
	check(b != null, "equal armies start a battle")
	check(W.phase(b) == "Plänkeln", "battles open with skirmishing")
	W.fight_round(g, b)
	check(W.phase(b) == "Nahkampf" and g.battles.has(b), "an even battle is not decided in the first round")
	# reinforcements join the running battle
	var r = g.spawn_army("ENG", pid, 4.0)
	W.gather(g)
	check(b.def.has(r) or b.att.has(r), "an army marching in joins the battle")
	var months := 0
	while g.battles.has(b) and months < 10:
		W.battles_tick(g)
		months += 1
	check(not g.battles.has(b), "the battle ends")
	check(b.round >= 3, "an even battle lasts several rounds (%d)" % b.round)
	check(months >= 1, "an even battle takes at least a month")
	# lopsided battles end fast, the loser bleeds
	var g2 = new_game("FRA", 6)
	g2.nations.FRA.truces.erase("ENG")
	g2.nations.ENG.truces.erase("FRA")
	g2.declare_war("FRA", "ENG")
	var big = g2.spawn_army("FRA", pid, 30.0)
	var small = g2.spawn_army("ENG", pid, 5.0)
	big.power = 1.0
	small.power = 1.0
	var war = g2.war_between("FRA", "ENG")
	var sc0: float = war.battle_score
	g2._battle(war, [big], [small], pid)
	check(big.regs > 26.0, "the big army loses little (%.1f)" % big.regs)
	check(not g2.armies.has(small) or small.regs < 3.5, "the small army loses a lot")
	check(war.battle_score > sc0, "the winner gains war score")
	# terrain defence: holding mountains helps
	var mtn: int = g.key_to_pid["tirol"]
	var hold: String = g.provinces[mtn].controller
	var bb = W.Battle.new()
	bb.pid = mtn
	var h = g.spawn_army(hold, mtn, 5.0)
	bb.att = [h]
	var p_hold: float = W.side_power(g, bb, true)
	h.owner = "FRA" if hold != "FRA" else "ENG"
	check(p_hold > W.side_power(g, bb, true) * 1.2 or h.owner == hold, "holding the mountains is worth a lot")
	h.owner = hold
	# landings fight worse
	h.landing = true
	check(W.side_power(g, bb, true) < p_hold, "troops fresh off the ships fight worse")
	# saved mid-battle
	var g3 = new_game("FRA", 7)
	g3.nations.FRA.truces.erase("ENG")
	g3.nations.ENG.truces.erase("FRA")
	g3.declare_war("FRA", "ENG")
	g3.spawn_army("FRA", pid, 10.0)
	g3.spawn_army("ENG", pid, 10.0)
	W.gather(g3)
	W.fight_round(g3, g3.battles[0])
	var g4 = new_game("FRA", 9)
	g4.from_dict(JSON.parse_string(JSON.stringify(g3.to_dict())))
	check(g4.battles.size() == 1 and g4.battles[0].round == 1, "a running battle is saved")


func test_naval() -> void:
	var g = new_game("FRA", 5)
	var N = g.Naval
	check(g.seas.size() >= 10, "sea regions loaded")
	check(N.limit(g, "ENG") > 0.0 and g.nations.ENG.ships > 0.0, "England starts with a fleet")
	check(N.limit(g, "BOH") == 0.0, "landlocked Bohemia has no fleet")
	var lon: int = g.key_to_pid["london"]
	var cal: int = g.key_to_pid["calais"]
	check(N.sea_of_strait(g, lon, cal) == "channel", "London-Calais crosses the Channel")
	# building ships
	var n = g.nations.FRA
	n.gold = 1000.0
	n.mil = 200.0
	var before: float = n.ships
	check(N.build_ships(g, "FRA", 1) == "", "France builds a ship")
	check(n.ships == before + 1.0, "the ship is there")
	n.ships = N.limit(g, "FRA")
	check(N.build_ships(g, "FRA", 1) != "", "not above the limit")
	# stationing
	var seas: Array = N.coast_weights(g, "FRA").keys()
	check(seas.has("channel"), "France borders the Channel")
	N.station(g, "FRA", "channel")
	check(N.presence(g, "FRA").keys() == ["channel"], "a stationed fleet sits in one sea")
	check(N.station(g, "FRA", "black") != "", "only own coastal seas")
	# war: England rules the Channel -> French armies cannot cross, French coast blockaded
	g.nations.FRA.truces.erase("ENG")
	g.nations.ENG.truces.erase("FRA")
	g.declare_war("ENG", "FRA")
	g.nations.ENG.ships = 30.0
	g.nations.ENG.fleet_sea = "channel"
	g.nations.FRA.ships = 2.0
	N.refresh(g)
	var w = g.war_between("ENG", "FRA")
	check(N.control(g, w, "channel") == "att", "England rules the Channel")
	check(not N.can_cross(g, "FRA", cal, lon), "France cannot cross the Channel")
	check(N.can_cross(g, "ENG", lon, cal), "England can")
	check(g.find_path("FRA", cal, lon).is_empty(), "no French path to London")
	var a = g.spawn_army("FRA", cal, 5.0)
	check(g.move_army(a, lon).contains("Flotte"), "the order says the enemy fleet blocks it")
	var blk := false
	for pid in g.provinces_of("FRA"):
		if N.is_blockaded(g, pid):
			blk = true
	check(blk, "French Channel coast is blockaded")
	check(g.nations.FRA.bonus.get("blockade", {}).get("income", 0.0) < 0.0, "a blockade costs income")
	check(not N.is_blockaded(g, lon), "London, behind the ruling fleet, is not blockaded")
	# a fleet battle: the bigger fleet wins and the loser loses ships
	g.nations.FRA.ships = 10.0
	g.nations.FRA.fleet_sea = "channel"
	N.refresh(g)
	var sc0: float = w.battle_score
	N._fleet_battle(g, w, g.sea_by_id["channel"], 30.0, 10.0)
	check(g.nations.FRA.ships < 10.0 and w.battle_score > sc0, "England wins the sea battle")
	# save
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(absf(g2.nations.FRA.ships - g.nations.FRA.ships) < 0.001 and g2.nations.ENG.fleet_sea == "channel", "fleets are saved")
	check(not g2.can_cross("FRA", cal, lon), "sea control is restored after loading")


func test_power_actions() -> void:
	var g = new_game("FRA", 5)
	var n = g.nations.FRA
	var cap: int = n.capital
	# drill: morale to max for military power, only on friendly land
	var a = g.spawn_army("FRA", cap, 4.0)
	a.power = 0.2
	n.mil = 0.0
	check(g.drill_army("FRA", a.id) != "", "drill needs military power")
	n.mil = 200.0
	var cost: float = g.drill_cost(a)
	check(g.drill_army("FRA", a.id) == "", "drill works at home")
	check(absf(a.power - g.power_max("FRA")) < 0.0001 and absf(n.mil - (200.0 - cost)) < 0.001, "drill fills morale and costs mil")
	check(g.drill_army("FRA", a.id) != "", "no drill at full morale")
	a.power = 0.2
	a.pid = g.nations.ENG.capital
	check(g.drill_army("FRA", a.id) != "", "no drill in foreign land")
	# conscription: manpower now, then a cooldown
	n.manpower = 0.0
	n.mil = 200.0
	check(g.conscript("FRA") == "", "conscription works")
	check(n.manpower > 0.0 and n.manpower <= n.max_manpower, "conscription adds manpower")
	check(g.conscript("FRA") != "" and g.conscript_ready_in("FRA") > 0, "conscription has a cooldown")
	# integration: conquered land becomes core faster
	var pid: int = g.provinces_of("FRA")[1]
	g.provinces[pid].core_months = 30
	n.dip = 200.0
	check(g.integrate("FRA", pid) == "", "integration works")
	check(g.provinces[pid].core_months == 30 - int(g.bal.integrate_months), "integration shortens the wait")
	g.provinces[pid].core_months = 0
	check(g.integrate("FRA", pid) != "", "cored land needs no integration")
	check(g.integrate("FRA", g.nations.ENG.capital) != "", "only own provinces")
	# reputation: less AE
	n.ae = 12.0
	check(g.restore_reputation("FRA") == "", "reputation works")
	check(absf(n.ae - (12.0 - float(g.bal.reputation_ae))) < 0.001, "reputation lowers AE")
	n.ae = 0.0
	check(g.restore_reputation("FRA") != "", "nothing to repair without AE")


func test_building_gain() -> void:
	var g = new_game("FRA", 5)
	var p = g.provinces[g.nations.FRA.capital]
	var before: Dictionary = p.buildings.duplicate()
	var dev: int = p.dev
	var inc: float = g.Economy.province_income(g, p)
	var gain: float = g.Economy.building_gain(g, p, "workshop")
	check(gain > 0.0, "a workshop raises income")
	check(p.buildings == before and p.dev == dev and absf(g.Economy.province_income(g, p) - inc) < 0.0001, "estimate leaves the province untouched")
	check(g.Economy.building_gain(g, p, "road") < gain, "a road brings less income than a workshop")


func test_military_access() -> void:
	var g = new_game("FRA", 5)
	var nb := ""
	for t in g.neighbors_of("FRA"):
		if not g.is_allied("FRA", t) and g.nations[t].overlord != "FRA" and g.nations[t].overlord == "" and not g.at_war("FRA", t):
			nb = t
			break
	check(nb != "", "France has a neutral neighbour")
	if nb == "":
		return
	var pid: int = g.nations[nb].capital
	check(not g.can_enter("FRA", pid), "neutral land is closed")
	g.nations.FRA.dip = 200.0
	g.add_rel(nb, "FRA", -100.0)
	check(g.request_access("FRA", nb) != "", "a hostile neighbour refuses access")
	g.add_rel(nb, "FRA", 200.0)
	check(g.request_access("FRA", nb) == "", "a friendly neighbour grants access")
	check(g.can_enter("FRA", pid), "access opens the land")
	check(not g.find_path("FRA", g.nations.FRA.capital, pid).is_empty(), "armies can path through granted land")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.access.has(nb), "access is saved")
	var a = g.spawn_army("FRA", pid, 2.0)
	g.nations[nb].relations["FRA"] = -100.0
	g.tick()
	check(not g.nations.FRA.access.has(nb), "bad relations end access")
	check(a.pid == g.nations.FRA.capital, "troops in revoked land go home")


func test_guarantee() -> void:
	var g = new_game("ENG", 5)
	g.nations.FRA.dip = 200.0
	var target := ""
	for t in g.nations:
		var n = g.nations[t]
		if t != "FRA" and t != "ENG" and n.overlord == "" and not g.is_allied("ENG", t) and not g.is_allied("FRA", t) and not g.has_truce("ENG", t) and n.allies.is_empty():
			target = t
			break
	check(target != "", "a lone state exists")
	if target == "":
		return
	check(g.guarantee("FRA", target) == "", "France guarantees a small state")
	check(g.guarantee("FRA", target) != "", "no double guarantee")
	check(g.defenders_for("ENG", target).has("FRA"), "the guarantor defends")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.guarantees.has(target), "guarantees are saved")
	g.nations.FRA.truces.erase(target)
	g.nations[target].truces.erase("FRA")
	g.declare_war("FRA", target)
	check(not g.nations.FRA.guarantees.has(target), "attacking the protected state breaks the guarantee")


func test_religion() -> void:
	var F = load("res://scripts/core/religion.gd")
	var g = new_game("TUR", 5)
	check(g.nations.TUR.religion == "sunni" and g.nations.FRA.religion == "catholic" and g.nations.BYZ.religion == "orthodox", "start religions")
	var bp: int = g.nations.BYZ.capital
	check(g.provinces[bp].religion == "orthodox", "provinces follow their owner at start")
	check(g.unrest_parts(bp).religion == 0.0, "own faith gives no unrest")
	g.provinces[bp].owner = "TUR"
	g.provinces[bp].controller = "TUR"
	g._rebuild_owned()
	check(g.unrest_parts(bp).religion > 0.0, "a foreign faith is restless")
	g.nations.TUR.gold = 500.0
	check(F.send_missionary(g, "TUR", bp) == "", "missionary sent")
	check(F.send_missionary(g, "TUR", bp) != "", "one missionary per province")
	for i in int(g.bal.convert_months):
		F.monthly(g, g.nations.TUR)
	check(g.provinces[bp].religion == "sunni", "the missionary converts the province")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.provinces[bp].religion == "sunni" and g2.nations.BYZ.religion == "orthodox", "religion is saved")
	# state religion change needs enough of the realm
	check(F.change_religion(g, "FRA", "orthodox") != "", "no change without believers")
	# the Reformation
	var h = new_game("FRA", 5)
	h.month = (int(h.bal.reformation_year) - 1444) * 12
	F.yearly(h)
	var prot := 0
	for p in h.provinces:
		if p.religion == "protestant":
			prot += 1
	check(prot == 1, "the Reformation starts in one province")
	h.bal.reformation_spread = 1.0
	for i in 3:
		h.month += 12
		F.yearly(h)
	var prot2 := 0
	for p in h.provinces:
		if p.religion == "protestant":
			prot2 += 1
	check(prot2 > prot, "Protestantism spreads")
	check(h.check_conditions("FRA", {"religion": "catholic"}) and not h.check_conditions("FRA", {"religion": "sunni"}), "religion condition")


## Ranking chart data: one entry per year with the top realms and the player, kept by save/load.
func test_score_history() -> void:
	var g = new_game("NAP")
	for i in 25:
		g.tick()
	check(g.score_history.size() == 2, "a score snapshot each new year (%d)" % g.score_history.size())
	var top: Dictionary = g.score_history[-1][1]
	check(top.size() <= g.SCORE_HISTORY_TOP + 1 and top.has("NAP"), "snapshot holds the best realms and the player")
	var g2 = new_game("NAP")
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.score_history.size() == 2 and int(g2.score_history[-1][1]["NAP"]) == int(top["NAP"]), "score history survives save/load")


func test_first_steps() -> void:
	var FS = load("res://scripts/core/first_steps.gd")
	var g = new_game("FRA", 5)
	var n = g.nations.FRA
	check(FS.claimable(g, "FRA") == 0, "no beginner goal is done at the start")
	n.adm = 500.0
	check(g.develop("FRA", n.capital) == "", "develop the capital")
	check(FS.claimable(g, "FRA") == 1, "developing finishes the first goal")
	check(FS.claim(g, "FRA", "build") != "", "an open goal cannot be claimed")
	var gold: float = n.gold
	check(FS.claim(g, "FRA", "develop") == "" and n.gold > gold, "claiming pays gold")
	check(FS.claim(g, "FRA", "develop") != "", "a goal pays once")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	var st: Array = FS.steps(g2, "FRA")
	check(st[0].claimed and not st[1].done, "beginner goals are saved")
	check(not FS.all_claimed(g2, "FRA"), "five goals remain")


func test_monuments_and_feast() -> void:
	var M = load("res://scripts/core/monuments.gd")
	var g = new_game("FRA", 5)
	var n = g.nations.FRA
	n.gold = 100000.0
	check(M.start(g, "FRA", "university") != "", "great works need technology")
	n.tech.adm = 3
	var before: float = n.gold
	check(M.start(g, "FRA", "cathedral") == "", "the cathedral is started")
	check(n.gold < before - 250.0, "great works cost more for developed realms")
	check(M.start(g, "FRA", "cathedral") != "", "one great work at a time")
	var u0: float = g.mod(n, "unrest")
	for i in int(g.monument_defs.cathedral.months):
		M.tick(g, n)
	check(n.monuments.has("cathedral") and n.monument_build.is_empty(), "the cathedral is finished")
	check(g.mod(n, "unrest") < u0, "its bonus applies")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.monuments.has("cathedral") and g2.mod(g2.nations.FRA, "unrest") < u0 + 0.001, "great works are saved")
	var p0: float = n.prestige
	check(g.hold_feast("FRA") == "" and n.prestige > p0, "a feast brings prestige")
	check(g.hold_feast("FRA") != "", "feasts have a cooldown")


func test_marriage() -> void:
	var g = new_game("FRA", 5)
	g.nations.FRA.dip = 200.0
	g.add_rel("FRA", "SAV", -100.0)
	check(g.marry("FRA", "SAV") != "", "a hostile house refuses")
	g.add_rel("FRA", "SAV", 200.0)
	check(g.marry("FRA", "SAV") == "", "marriage with a friendly house")
	check(g.nations.FRA.marriages.has("SAV") and g.nations.SAV.marriages.has("FRA"), "marriage on both sides")
	check(g.marry("FRA", "SAV") != "", "no double marriage")
	g.nations.SAV.relations["FRA"] = 10.0
	g.nations.FRA.relations["SAV"] = 10.0
	for i in 24:
		g.tick()
	check(g.get_rel("SAV", "FRA") >= float(g.bal.marriage_rel_floor) - 0.001, "married relations stay friendly")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.marriages.has("SAV"), "marriages are saved")
	# personal union on succession
	g.bal.marriage_union_chance = 1.0
	g._marriage_succession(g.nations.SAV)
	check(g.nations.SAV.overlord == "" or g.nations.SAV.overlord == "FRA", "union only to the partner")
	var h = new_game("ENG", 5)
	h.nations.FRA.marriages.append("SAV")
	h.nations.SAV.marriages.append("FRA")
	h.bal.marriage_union_chance = 1.0
	h._marriage_succession(h.nations.SAV)
	check(h.nations.SAV.overlord == "FRA", "a small married realm can fall to a strong house")
	h.nations.FRA.truces.erase("SAV")
	h.nations.SAV.truces.erase("FRA")
	h.nations.ENG.marriages.append("BRI")
	h.nations.BRI.marriages.append("ENG")
	h.nations.ENG.truces.erase("BRI")
	h.declare_war("ENG", "BRI")
	check(not h.nations.ENG.marriages.has("BRI"), "war ends a marriage")


func test_generals() -> void:
	var g = new_game("FRA", 5)
	var cap: int = g.nations.FRA.capital
	var a = g.spawn_army("FRA", cap, 6.0)
	var base: float = g._side_power([a], cap)
	g.nations.FRA.mil = 0.0
	check(g.hire_general("FRA", a.id) != "", "a general costs military power")
	g.nations.FRA.mil = 100.0
	check(g.hire_general("FRA", a.id) == "", "hire a general")
	check(a.general >= 1 and a.general <= 3, "general has 1-3 stars")
	check(g._side_power([a], cap) > base, "a general makes the army stronger")
	check(g.hire_general("FRA", a.id) != "", "only one general per army")
	var b = g.spawn_army("FRA", cap, 2.0)
	var stars: int = a.general
	g.merge_armies("FRA", cap)
	var merged = null
	for x in g.armies_in(cap):
		if x.owner == "FRA":
			merged = x
	check(merged != null and merged.general == stars, "merged army keeps the general")
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.army_by_id(merged.id).general == stars, "generals are saved")


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
	var gate: String = Eco.level_tech(g, ids[0], 2)
	if gate != "":
		n.techs[gate] = 0
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
		check(per_cat[c] == 30, "30 generic %s techs" % c)
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


func test_difficulty() -> void:
	var g = new_game("ENG")
	check(g.difficulty == "normal", "default difficulty is normal")
	g.set_difficulty("easy")
	check(absf(float(g.nations.ENG.bonus.difficulty.income) - 0.25) < 0.001, "easy gives player income bonus")
	check(g.nations.FRA.bonus.difficulty.is_empty(), "easy gives AI no bonus")
	g.set_difficulty("very_hard")
	check(g.nations.ENG.bonus.difficulty.is_empty(), "very hard: no player bonus")
	check(float(g.nations.FRA.bonus.difficulty.get("income", 0.0)) >= 0.15 - 0.001, "very hard: AI income bonus")
	check(g.diff("ai_vs_player") > 1.0, "very hard: AI targets player more")
	g.set_difficulty("nonsense")
	check(g.difficulty == "normal", "unknown difficulty falls back to normal")
	g.set_difficulty("hard")
	var g2 = new_game("ENG")
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.difficulty == "hard", "difficulty survives save/load")
	check(g2.nations.ENG.bonus.difficulty.is_empty(), "loaded difficulty replaces the player bonus")


func test_laws() -> void:
	var g = new_game("SPA")
	g.set_difficulty("hard")  # no player bonus from difficulty
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
	# every flag is a glyph of the pixel font, registered before any text is drawn
	var PE = load("res://scripts/ui/pixel_emoji.gd")
	PE.install()
	PE.add_nations(data.nations.keys())
	for tag in data.nations:
		var f: String = PE.nation(tag)
		check(f.length() == 1 and f.unicode_at(0) >= PE.PUA and PE.font.has_char(f.unicode_at(0)), "flag of %s is a pixel glyph" % tag)
	check(PE.nation("XXX") == "🏳" and have.has("1f3f3"), "a nation without flag shows the white flag glyph")
	# a changed global oversampling (window resize, UI size, Windows DPI) must not wipe the glyphs
	var ts := TextServerManager.get_primary_interface()
	var was := ts.font_get_global_oversampling()
	ts.font_set_global_oversampling(was * 1.4 + 0.1)
	var flag: String = PE.nation(data.nations.keys()[0])
	check(PE.font.has_char(0x1F4B0) and PE.font.has_char(flag.unicode_at(0)), "pixel glyphs survive an oversampling change")
	ts.font_set_global_oversampling(was)


## Pixel UI kit (tools/art/ui_kit.py): every slice texture exists and is big enough for its margins;
## modifier rows mark buffs and nerfs by meaning, not by sign (lower build cost is a buff).
func test_ui_kit() -> void:
	for k in UiTheme.SLICES:
		var t := UiTheme.tex(k)
		check(t != null, "ui kit texture %s missing, run tools/art/ui_kit.py" % k)
		if t != null:
			check(t.get_width() > 2 * UiTheme.SLICES[k] and t.get_height() > 2 * UiTheme.SLICES[k] or k == "topbar", "ui kit %s smaller than its slices" % k)
	for k in ["mod_up", "mod_down", "separator", "slider_grabber"]:
		check(UiTheme.tex(k) != null, "ui kit texture %s missing" % k)
	var rows: Array = UiTheme.mod_rows({"build_cost": -0.1, "income": 0.05, "unrest": 1.0, "tax": 0.0})
	check(rows.size() == 3, "zero modifiers are hidden")
	var good := {}
	for r in rows:
		good[r[0]] = r[2]
	check(good.get("Baukosten") == true, "lower build cost is a buff")
	check(good.get("Einkommen") == true, "more income is a buff")
	check(good.get("Unruhe") == false, "more unrest is a nerf")
	check(UiTheme.tone_bb("💰 +5", 1).contains("mod_up.png"), "buffs get the up arrow")


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
	var form_adel: float = g.govt.form_effects("FRA").get("estate_adel", 0.0)
	check(absf(g.govt.estate_target(g, n, "adel") - 65.0 - form_adel) < 0.01, "law shifts the nobility's target to 65 (+ form)")
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
	check(gv.budget_step(ai, "hof") == 1 and gv.budget_step(ai, "bildung") == 1 and gv.budget_step(ai, "heer") <= 2, "poor AI cuts court, research and never raises the army budget")
	ai.gold = 5000.0
	gv._ai_budget(g, ai)
	check(gv.budget_step(ai, "hof") == 3 and gv.budget_step(ai, "bildung") == 3, "rich AI spends on court and research")


## eco_ events/missions (tools/content/eco_events.py): references are valid and the new conditions/effects work.
func test_eco_content() -> void:
	var g = new_game("ENG")
	var n = g.nations.ENG
	var known := ["building", "no_building", "coastal", "produces", "goods_leader", "shock", "loans_min", "loans_max",
		"trade_pacts_min", "mercs_recent", "morale_max", "budget_min", "budget_max", "gold_max", "year_min", "at_war",
		"at_peace", "estate_min", "estate_max"]
	var reqs := []
	for e in data.events:
		if e.id.begins_with("eco_"):
			reqs.append(e.trigger)
			for o in e.options:
				var b = o.effects.get("build", "")
				check(b == "" or g.buildings_def.has(b), "%s builds a known building" % e.id)
	for tag in data.missions:
		for m in data.missions[tag]:
			if "_eco_" in m.id:
				reqs.append(m.require)
	check(reqs.size() >= 60, "eco content present (%d)" % reqs.size())
	for r in reqs:
		for k in r:
			check(known.has(k), "known condition " + k)
		for bid in r.get("building", {}):
			check(g.buildings_def.has(bid), "known building " + bid)
		for key in ["produces", "goods_leader"]:
			check(not r.has(key) or r[key] is bool or g.goods_def.has(r[key]), "known good in " + key)
		for key in ["budget_min", "budget_max"]:
			for id in r.get(key, {}):
				check(g.govt.budget_by_id.has(id), "known budget slider " + id)
		g.check_conditions("ENG", r)  # must not crash
	# conditions
	check(g.check_conditions("ENG", {"coastal": true}) and not g.check_conditions("BOH", {"coastal": true}), "England is coastal, Bohemia is not")
	check(g.check_conditions("ENG", {"produces": "wool"}) and not g.check_conditions("ENG", {"produces": "furs"}), "England produces wool, no furs")
	check(g.check_conditions("ENG", {"no_building": "road"}) and not g.check_conditions("ENG", {"building": {"road": 1}}), "no roads at start")
	# effects: free building level
	var dev0: int = n.dev_total
	g.apply_effects("ENG", {"build": "road"})
	check(g.Economy.building_total(g, "ENG", "road") == 1 and g.check_conditions("ENG", {"building": {"road": 1}}), "build effect adds a road level")
	check(g.nation_dev("ENG") == dev0, "free road gives no development (no_dev)")
	g.apply_effects("ENG", {"build": "marketplace"})
	check(g.nation_dev("ENG") == dev0 + int(g.bal.building_dev), "free marketplace grows the province like a finished building")
	# loans
	g.apply_effects("ENG", {"loan": 2})
	check(n.loans.size() == 2 and g.check_conditions("ENG", {"loans_min": 2}) and not g.check_conditions("ENG", {"loans_max": 1}), "loan effect + loan conditions")
	g.apply_effects("ENG", {"loan_forgiven": 5})
	check(n.loans.is_empty(), "loan_forgiven clears loans and never underflows")
	# mercenaries
	n.flags["merc_month"] = g.month
	check(g.check_conditions("ENG", {"mercs_recent": 12}) and g.merc_ready_in("ENG") > 0, "mercs recently hired")
	g.apply_effects("ENG", {"merc_ready": true})
	check(g.merc_ready_in("ENG") == 0 and not g.check_conditions("ENG", {"mercs_recent": 12}), "merc_ready resets the cooldown")
	# morale
	var a = g.armies_of("ENG")[0]
	a.regs = maxf(a.regs, 3.0)
	a.power = 0.2 * g.power_max("ENG")
	check(g.check_conditions("ENG", {"morale_max": 0.45}), "worn-out army detected")
	g.apply_effects("ENG", {"army_power": 0.3})
	check(absf(a.power - 0.5 * g.power_max("ENG")) < 0.001 and not g.check_conditions("ENG", {"morale_max": 0.35}), "army_power effect raises morale")
	g.apply_effects("ENG", {"army_power": 5.0})
	check(a.power <= g.power_max("ENG") + 0.0001, "morale capped at maximum")
	# budget
	check(g.check_conditions("ENG", {"budget_max": {"hof": 2}}) and not g.check_conditions("ENG", {"budget_min": {"hof": 4}}), "budget at default")
	g.govt.set_budget(g, "ENG", "hof", 4)
	check(g.check_conditions("ENG", {"budget_min": {"hof": 4}}), "budget_min after raising the court")
	# shocks
	g.shocks = {"wool": {"mult": 1.4, "years": 3}}
	check(g.check_conditions("ENG", {"shock": "up"}) and not g.check_conditions("ENG", {"shock": "down"}), "scarcity shock on own good")

## Techs, laws, advisors and the army budget feed the morale system (army_power / army_power_regen).
func test_morale_modifiers() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var base: float = g.power_max("FRA")
	n.techs["mil_stehendes_heer"] = 0
	g.tree.refresh(n)
	check(absf(g.power_max("FRA") - base - 0.1) < 0.001, "standing army tech raises max morale")
	n.gov.laws["heer"] = "stehendes_heer"
	g.govt.refresh(n)
	check(absf(g.power_max("FRA") - base - 0.2) < 0.001, "standing army law raises max morale")
	var r0: float = g.mod(n, "army_power_regen")
	g.govt.set_budget(g, "FRA", "heer", 4)
	check(absf(g.mod(n, "army_power_regen") - r0 - 0.5) < 0.001, "lavish army budget speeds up morale recovery")
	check(g.govt.adv_by_id.has("drillmeister") and g.govt.adv_by_id.drillmeister.effects.has("army_power"), "drill master advisor")


## State reforms: tiers unlock by year, cost administrative power, are trade-offs, survive save/load, AI fills them.
func test_reforms() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var gv = g.govt
	check(gv.reforms.size() == 5, "five reform tiers")
	for t in gv.reforms:
		for o in t.options:
			var good := false
			var bad := false
			for l in Tech.effect_lines(o.effects):
				good = good or l[1]
				bad = bad or not l[1]
			check(good and bad, "reform %s has a buff and a nerf" % o.id)
	n.adm = 1000.0
	check(gv.open_reform_tiers(g, n) == ["grundlage"], "only the first tier is open in 1444")
	check(gv.reform_block(g, "FRA", "verwaltung", "hofrat") != "", "second tier locked in 1444")
	check(gv.enact_reform(g, "FRA", "grundlage", "domaenen") == "", "enact a reform")
	check(absf(n.adm - 900.0) < 0.01, "first tier costs 100 adm")
	var fe: Dictionary = gv.form_effects("FRA")
	check(absf(n.bonus.gov.get("tax", 0.0) - fe.get("tax", 0.0) - 0.1) < 0.001 and n.bonus.gov.get("manpower", 0.0) < fe.get("manpower", 0.0), "reform effects apply")
	check(gv.enact_reform(g, "FRA", "grundlage", "lehnswesen") != "", "reform change has a cooldown")
	g.month = (1530 - 1444) * 12
	check(gv.open_reform_tiers(g, n) == ["verwaltung", "heerwesen"], "tiers unlock over time")
	check(absf(gv.reform_cost(g, n, "heerwesen") - 200.0) < 0.01, "later tiers cost more")
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 3)
	g2.from_dict(JSON.parse_string(text))
	check(g2.nations.FRA.gov.reforms.get("grundlage", "") == "domaenen", "reforms survive save/load")
	var ai = g.nations.ENG
	ai.adm = 1000.0
	gv._ai_reforms(g, ai)
	check(ai.gov.reforms.has("grundlage"), "AI enacts the oldest open tier")


## Knowledge spreads: techs known by many other nations get cheaper, specials never.
func test_tech_spread() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var id := ""
	for t in g.tree.techs_for("FRA", "adm"):
		if not n.techs.has(t.id) and not Tech.is_special(t):
			id = t.id
			break
	for o in g.nations.values():
		o.techs.erase(id)
	var full: float = g.tree.cost(g, "FRA", id)
	check(absf(full - g.tech_cost("FRA", "adm")) < 0.01, "nobody knows it: full price")
	var others: Array = g.nations.values().filter(func(o): return o.alive and o.tag != "FRA")
	for i in others.size() / 2:
		others[i].techs[id] = 0
	var share: float = g.tree.known_share(g, "FRA", id)
	check(share > 0.45 and share <= 0.5, "half the world knows it (%.2f)" % share)
	check(absf(g.tree.cost(g, "FRA", id) - full * (1.0 - 0.5 * share)) < 0.01, "spread discount")
	for o in others:
		o.techs[id] = 0
	check(absf(g.tree.cost(g, "FRA", id) - full * 0.7) < 0.01, "discount capped at 30 %")
	var sp: Dictionary = g.tree.specials_of("FRA")[0]
	check(g.tree.spread_discount(g, "FRA", sp.id) == 0.0, "special techs never get cheaper")


## Imperial reforms: authority, elector support, member/emperor effects, Ewiger Landfriede, save/load, AI.
func test_empire_reforms() -> void:
	var g = new_game("FRA")
	var gv = g.govt
	var emp: String = g.emperor
	check(emp != "" and g.hre.has(emp), "there is an emperor")
	check(gv.empire_reforms().size() == 5, "five imperial reforms")
	check(absf(g.hre_authority - 10.0) < 0.01, "authority starts at 10")
	check(gv.authority_gain(g) > 2.0, "authority grows with the members")
	check(gv.empire_reform_block(g, "FRA") != "", "only the emperor passes reforms")
	check(gv.empire_reform_block(g, emp).contains("1450"), "the first reform waits for 1450")
	g.month = (1450 - 1444) * 12
	g.hre_authority = 0.0
	check(gv.empire_reform_block(g, emp).contains("Autorität"), "reforms cost authority")
	for e in g.current_electors():
		if e != emp:
			g.add_rel(e, emp, 200.0)
	g.hre_authority = 50.0
	check(gv.pass_empire_reform(g, emp) == "", "the emperor passes the Reichstag")
	check(g.hre_reforms == ["reichstag"] and absf(g.hre_authority - 10.0) < 0.01, "authority spent, reform recorded")
	var member := ""
	for t in g.hre_members():
		if t != emp:
			member = t
			break
	check(absf(g.nations[emp].bonus.empire.get("prestige", 0.0) - 1.0) < 0.001 and g.nations[emp].bonus.empire.get("unrest", 0.0) < 0.0, "emperor gets both effects")
	check(g.nations[member].bonus.empire.get("unrest", 0.0) < 0.0 and not g.nations[member].bonus.empire.has("prestige"), "members get the member effects")
	check(g.nations.FRA.bonus.get("empire", {}).is_empty(), "outsiders get nothing")
	g.hre_authority = 1000.0
	check(gv.empire_reform_block(g, emp).contains("1470"), "reforms unlock by year")
	g.month = (1600 - 1444) * 12
	for e in g.current_electors():
		if e != emp:
			g.add_rel(e, emp, -400.0)
	check(gv.empire_reform_block(g, emp).contains("Kurfürsten"), "electors must back the emperor")
	for e in g.current_electors():
		if e != emp:
			g.add_rel(e, emp, 400.0)
	while gv.next_empire_reform(g).size() > 0:
		check(gv.pass_empire_reform(g, emp) == "", "pass %s" % gv.next_empire_reform(g).get("id", "?"))
	check(g.hre_reforms.size() == 5, "all reforms passed")
	check(gv.landfriede(g, emp, member) and not gv.landfriede(g, "FRA", member), "Landfriede binds members only")
	for a in g.hre_members():
		for b in g.hre_members():
			if a != b and not g.is_allied(a, b) and not g.has_truce(a, b) and not g.at_war(a, b) and g.nations[a].overlord == "":
				check(g.declare_war(a, b).contains("Landfriede"), "no wars between members")
				break
		break
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 3)
	g2.from_dict(JSON.parse_string(text))
	check(g2.hre_reforms.size() == 5 and absf(g2.hre_authority - g.hre_authority) < 0.01, "reforms survive save/load")
	check(absf(g2.nations[emp].bonus.empire.get("tax", 0.0) - g.nations[emp].bonus.empire.get("tax", 0.0)) < 0.001, "effects restored on load")
	g2.hre_authority = 100.0
	gv.on_new_emperor(g2)
	check(absf(g2.hre_authority - 75.0) < 0.01, "a new house keeps 75 % of the authority")
	var g3 = new_game("FRA")
	g3.month = (1450 - 1444) * 12
	g3.hre_authority = 39.0
	for e in g3.current_electors():
		if e != g3.emperor:
			g3.add_rel(e, g3.emperor, 200.0)
	g3.govt.empire_yearly(g3)
	check(g3.hre_reforms == ["reichstag"], "an AI emperor passes reforms on its own")


## Church laws and advisors change religious unrest and conversion speed.
func test_religion_modifiers() -> void:
	var Religion = Game.Religion
	var g = new_game("FRA")
	var n = g.nations.FRA
	var gv = g.govt
	var pid: int = g.provinces_of("FRA")[0]
	var p = g.provinces[pid]
	p.religion = "orthodox"
	var base: float = Religion.unrest(g, p)
	check(base > 0.0, "another faith causes unrest")
	n.dip = 500.0
	check(gv.set_law(g, "FRA", "kirche", "toleranz") == "", "enact Toleranz")
	check(absf(Religion.unrest(g, p) - base * 0.25) < 0.001, "Toleranz cuts religious unrest by 75 %")
	var months: int = Religion.convert_months(g, n)
	n.gov.law_month.erase("kirche")
	check(gv.set_law(g, "FRA", "kirche", "glaubenseifer") == "", "enact Glaubenseifer")
	check(Religion.unrest(g, p) > base, "zeal angers other faiths")
	check(Religion.convert_months(g, n) < months, "zeal speeds up missionaries")
	check(gv.adv_by_id.has("hofprediger"), "court preacher advisor exists")


## Age goals: count only in their age, give permanent rewards, two of three win the triumph.
func test_gov_sources() -> void:
	var g = new_game("FRA", 5)
	var n = g.nations.FRA
	n.gov.ruler_trait = "kaufmann"
	g.govt.refresh(n)
	var srcs: Array = g.govt.gov_sources(n)
	check(srcs[0][0].begins_with("🏛"), "first source is the state form")
	check(srcs.any(func(s): return s[0].contains("Herrscher") and not s[1].is_empty()), "ruler trait listed as a source")
	var sum := {}
	for s in srcs:
		for k in s[1]:
			sum[k] = sum.get(k, 0.0) + float(s[1][k])
	for k in n.bonus.gov:
		check(absf(sum.get(k, 0.0) - float(n.bonus.gov[k])) < 0.0001, "sources add up to bonus.gov: " + k)


func test_regency() -> void:
	var g = new_game("FRA", 5)
	var gv = g.govt
	var n = g.nations.FRA
	var age: int = gv.heir_age(g, n)
	check(age >= 0 and age <= 12, "new heirs are children or adults up to 12")
	n.gov.heir.born = g.year() - 5
	n.gov.heir.trait = ""
	gv.succession(g, n)
	check(gv.regency_until(n) == g.year() + 10, "child ruler gets a regency until age 15")
	check(n.ruler.years > 10, "reign outlasts the regency")
	check(gv.gov_sources(n).any(func(s): return s[0].contains("Regentschaft")), "regency is a gov source")
	check(gv.court_condition(g, n, "regency", true) and not gv.court_condition(g, n, "regency", false), "regency condition")
	var save: Dictionary = gv.to_save(n).duplicate(true)
	var n2 = g.nations.ENG
	gv.load_save(n2, save)
	check(gv.regency_until(n2) == gv.regency_until(n), "regency survives save/load")
	gv.apply_court_effect(g, n, "end_regency", true)
	check(gv.regency_until(n) == 0 and not gv.gov_sources(n).any(func(s): return s[0].contains("Regentschaft")), "end_regency clears it")
	n.gov.heir.born = g.year() - 5
	n.gov.regency_until = g.year() + 3
	g.month += 36
	gv.regency_tick(g, n)
	check(gv.regency_until(n) == 0, "regency ends when the ruler comes of age")
	n.gov.heir.born = g.year() - 30
	gv.succession(g, n)
	check(gv.regency_until(n) == 0, "adult heir: no regency")
	n.gov.heir.born = g.year() - 8
	check(gv.court_condition(g, n, "heir_age_max", 10) and not gv.court_condition(g, n, "heir_age_min", 15), "heir age conditions")
	n.gov.heir.erase("born")
	check(gv.heir_age(g, n) == 99, "old-save heirs count as adults")


func test_form_change() -> void:
	var g = new_game("FRA", 5)
	var gv = g.govt
	var n = g.nations.FRA
	check(gv.form_name("FRA") == "Feudalmonarchie", "France starts feudal")
	var opts: Array = gv.form_change_options("FRA").map(func(c): return c.form)
	check(opts.has("Wahlmonarchie") and opts.has("Absolute Monarchie") and not opts.has("Kaufmannsrepublik"), "monarchy options only")
	check(gv.form_change_block(g, "FRA", "Absolute Monarchie").begins_with("Verfügbar ab"), "absolutism needs 1580")
	check(gv.form_change_block(g, "FRA", "Kaufmannsrepublik") != "", "no switch across families")
	n.adm = 0.0
	check(gv.form_change_block(g, "FRA", "Wahlmonarchie").contains("Verwaltungspunkte"), "needs admin power")
	n.adm = 900.0
	n.prestige = 50.0
	for w in g.wars.duplicate():
		g.wars.erase(w)
	check(gv.change_form(g, "FRA", "Wahlmonarchie") == "", "switch to elective monarchy")
	check(gv.form_name("FRA") == "Wahlmonarchie" and gv.heir_title("FRA") == "Nachfolger", "new form applies")
	check(float(n.bonus.gov.get("dip", 0.0)) >= 0.5 - 0.001, "new form effects in gov bonus")
	check(n.adm == 650.0 and n.prestige == 30.0, "cost paid")
	check(gv.form_change_block(g, "FRA", "Feudalmonarchie").contains("Jahren"), "cooldown after a change")
	var save: Dictionary = gv.to_save(n).duplicate(true)
	gv.load_save(n, save)
	check(gv.form_name("FRA") == "Wahlmonarchie" and gv.form_cooldown_left(g, n) > 0, "form survives save/load")
	gv.init_nation(n)
	check(gv.form_name("FRA") == "Feudalmonarchie", "fresh nation state drops the override")


func test_building_tech() -> void:
	var g = new_game("FRA", 5)
	var Eco = g.Economy
	var n = g.nations.FRA
	var pid: int = g.key_to_pid["paris"]
	var p = g.provinces[pid]
	n.gold = 100000.0
	p.dev = 30
	p.buildings = {"workshop": 2, "marketplace": 1, "barracks": 1}
	Eco.refresh_local(g, p)
	var tech: String = Eco.level_tech(g, "workshop", 3)
	check(tech != "" and g.tree.by_id.has(tech), "workshop level 3 needs a tech")
	n.techs.erase(tech)
	check(Eco.build_block_reason(g, "FRA", pid, "workshop").begins_with("Braucht Technologie"), "level gated by tech")
	n.techs[tech] = 0
	check(Eco.build_block_reason(g, "FRA", pid, "workshop") == "", "tech unlocks the level")
	check(g.tree.unlocks.has(tech) and g.tree.unlocks[tech].has(["workshop", 3]), "tech knows what it unlocks")
	# late buildings: tech first, at most max_count per realm
	var ut: String = Eco.level_tech(g, "university", 1)
	n.techs.erase(ut)
	check(Eco.build_block_reason(g, "FRA", pid, "university").begins_with("Braucht Technologie"), "university needs its tech")
	n.techs[ut] = 0
	var cap: int = int(g.buildings_def.university.max_count)
	var done := 0
	for q in g.provinces_of("FRA"):
		if done >= cap:
			break
		var pr = g.provinces[q]
		if q == pid:
			continue
		pr.buildings["university"] = 1
		done += 1
	check(done < cap or Eco.build_block_reason(g, "FRA", pid, "university").begins_with("Höchstens"), "max per realm")
	# every gate names a real tech
	for bid in g.buildings_def:
		for lvl in g.buildings_def[bid].get("level_tech", {}):
			check(g.tree.by_id.has(g.buildings_def[bid].level_tech[lvl]), "%s level %s tech exists" % [bid, lvl])


func test_heir() -> void:
	var g = new_game("FRA")
	var gv = g.govt
	var n = g.nations.FRA
	var h: Dictionary = n.gov.heir
	check(not h.is_empty() and h.has("adm") and str(h.name) != "", "every nation starts with a named heir")
	check(gv.heir_title("FRA") == "Erbe" and gv.heir_title("VEN") == "Nachfolger", "heir or successor by form")
	# education: costs power of that kind, +1, once a year, capped at ruler_max
	h.adm = 1
	n.adm = 500.0
	var c: float = gv.educate_cost(g, n, "adm")
	check(gv.educate(g, "FRA", "adm") == "" and int(n.gov.heir.adm) == 2 and is_equal_approx(n.adm, 500.0 - c), "educate raises a skill for power")
	check(gv.educate_block(g, "FRA", "dip") != "", "once a year")
	check(gv.educate_cost(g, n, "adm") > c, "each level costs more")
	g.month += 12
	n.gov.heir.mil = int(g.bal.ruler_max)
	check(gv.educate_block(g, "FRA", "mil") != "", "capped at ruler_max")
	n.adm = 0.0
	check(gv.educate_block(g, "FRA", "adm").begins_with("Zu wenig"), "needs power")
	# saved and loaded
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.gov.heir.adm == n.gov.heir.adm and g2.nations.FRA.gov.heir.name == n.gov.heir.name, "heir saved")
	# succession: the heir becomes ruler, a new heir is named
	var old: Dictionary = n.gov.heir.duplicate()
	n.ruler.years = 1
	g.month = (g.month / 12) * 12 + 11
	g.tick()
	check(n.ruler_name == str(old.name) and int(n.ruler.adm) == int(old.adm) and int(n.ruler.mil) == int(old.mil), "heir takes the throne")
	check(n.ruler.years >= 8 and not n.gov.heir.is_empty() and n.gov.heir.name != old.name, "new reign and a new heir")
	check(n.gov.ruler_trait == str(old.get("trait", "")) and n.gov.heir.has("trait"), "the heir's trait comes to the throne")
	# traits count as a government source
	n.gov.ruler_trait = "baumeister"
	gv.refresh(n)
	var bc: float = g.mod(n, "build_cost")
	n.gov.ruler_trait = ""
	gv.refresh(n)
	check(is_equal_approx(g.mod(n, "build_cost") - bc, 0.1), "ruler trait effects apply")
	# event hooks: conditions and effects on ruler and heir
	n.gov.heir.trait = "grausam"
	check(g.check_conditions("FRA", {"heir_trait": "grausam"}) and g.check_conditions("FRA", {"heir_trait": "any"}), "heir trait condition")
	check(not g.check_conditions("FRA", {"heir_trait": ""}), "heir trait none condition")
	g.apply_effects("FRA", {"heir_trait": "fromm", "heir": {"adm": 1}})
	check(n.gov.heir.trait == "fromm", "event changes the heir's trait")
	g.apply_effects("FRA", {"ruler_trait": "gelehrt"})
	check(g.check_conditions("FRA", {"ruler_trait": "gelehrt"}) and n.bonus.gov.get("tech_cost", 0.0) <= -0.05 + 0.001, "event gives the ruler a trait")
	n.gov.ruler_trait = ""
	gv.refresh(n)
	var seen := {}
	for i in 200:
		seen[gv.roll_trait(g)] = true
	check(seen.has("") and seen.size() >= 8, "traits roll with a chance of none")
	# disinheriting: prestige for a new heir, then a cooldown
	n.prestige = 30.0
	var before: String = n.gov.heir.name
	check(gv.disinherit(g, "FRA") == "" and n.gov.heir.name != before and is_equal_approx(n.prestige, 30.0 - float(gv.cfg.heir_disinherit_prestige)), "disinherit names a new heir for prestige")
	check(gv.disinherit_block(g, "FRA") != "", "disinherit cooldown")
	# old saves without heir get one at the next turn of the year
	n.gov.erase("heir")
	gv.yearly(g, n)
	check(not n.gov.get("heir", {}).is_empty(), "missing heir is named yearly")


func test_tech_queue() -> void:
	var g = new_game("FRA")
	var tr = g.tree
	var n = g.nations.FRA
	g.month = (1470 - 1444) * 12
	# a generic adm tech with an unresearched prerequisite, regular window already open
	var t: Dictionary = {}
	for d in tr.defs:
		if not Tech.is_special(d) and d.cat == "adm" and tr.years_ahead(g, d.id) == 0 and not d.get("req", []).is_empty() \
				and d.req.any(func(r): return not n.techs.has(r)) and not n.techs.has(d.id):
			t = d
			break
	check(not t.is_empty(), "found a tech with a missing prerequisite")
	check(tr.queue_add(g, "FRA", t.id) == "", "plan accepts it")
	var pre: String = tr.queue_of(n, "adm")[0]
	check(t.req.has(pre) or tr.by_id[pre].cat == "adm", "prerequisite planned first")
	check(n.tech_queue.back() == t.id, "target last")
	check(tr.queue_add(g, "FRA", t.id) != "", "no duplicates")
	n.adm = 0.0
	check(tr.queue_tick(g, n).is_empty(), "waits without points")
	check(tr.queue_wait(g, "FRA", pre).begins_with("wartet auf Punkte"), "says why it waits")
	n.adm = float(g.bal.power_cap)
	var done: Array = tr.queue_tick(g, n)
	check(n.techs.has(t.id) and n.techs.has(pre), "plan researched in order")
	check(done.size() >= 2 and not n.tech_queue.has(t.id), "researched techs leave the plan")
	# removing a planned prerequisite drops what builds on it; saves keep the plan
	n.tech_queue.clear()
	var u: Dictionary = {}
	for d in tr.defs:
		if not Tech.is_special(d) and d.cat == "dip" and not n.techs.has(d.id) and d.get("req", []).any(func(r): return not n.techs.has(r)):
			u = d
			break
	tr.queue_add(g, "FRA", u.id)
	var g2 = new_game("FRA", 9)
	g2.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.nations.FRA.tech_queue == n.tech_queue, "plan saved")
	tr.queue_remove(n, n.tech_queue[0])
	check(not n.tech_queue.has(u.id), "dependent dropped with its prerequisite")
	# early techs wait for their regular year unless points are capped
	var e: Dictionary = {}
	for d in tr.defs:
		if not Tech.is_special(d) and tr.years_ahead(g, d.id) > 0 and tr.block_reason(g, "FRA", d.id) == "":
			e = d
			break
	if not e.is_empty():
		n.tech_queue = [e.id]
		n.set(e.cat, float(g.bal.power_cap) - 1.0)
		if n.get(e.cat) >= tr.cost(g, "FRA", e.id):
			check(tr.queue_tick(g, n).is_empty(), "early tech waits below the cap")
		n.set(e.cat, float(g.bal.power_cap))
		if n.get(e.cat) >= tr.cost(g, "FRA", e.id):
			check(tr.queue_tick(g, n).size() == 1, "early tech taken at the cap")


func test_tech_ahead() -> void:
	var g = new_game("FRA")
	var tr = g.tree
	var n = g.nations.FRA
	g.month = (1455 - 1444) * 12
	# a generic tech whose regular window opens 10 years from now
	var t: Dictionary = {}
	for d in tr.defs:
		if not Tech.is_special(d) and int(d.year) - tr.early_years == g.year() + 10 and d.get("req", []).all(func(r): return n.techs.has(r)):
			t = d
			break
	if t.is_empty():
		for d in tr.defs:
			if not Tech.is_special(d) and int(d.year) - tr.early_years > g.year() and int(d.year) - tr.early_years - tr.ahead_years <= g.year():
				t = d
				break
	check(not t.is_empty(), "found a tech ahead of time")
	var ya: int = tr.years_ahead(g, t.id)
	check(ya > 0 and ya <= tr.ahead_years, "years ahead within the window")
	var base: float = g.tech_cost("FRA", t.cat) * (1.0 - tr.spread_discount(g, "FRA", t.id))
	check(is_equal_approx(tr.cost(g, "FRA", t.id), base * (1.0 + tr.ahead_penalty * ya)), "ahead-of-time premium")
	for r in t.get("req", []):
		n.techs[r] = 0
	check(tr.block_reason(g, "FRA", t.id) == "", "researchable ahead of time")
	var far: Dictionary = {}
	for d in tr.defs:
		if not Tech.is_special(d) and int(d.year) - tr.early_years - tr.ahead_years > g.year():
			far = d
			break
	check(far.is_empty() or tr.block_reason(g, "FRA", far.id).begins_with("Verfügbar ab") or tr.block_reason(g, "FRA", far.id).begins_with("Benötigt"), "too far ahead stays locked")
	# the AI only goes ahead with power to spare
	n.set(t.cat, tr.cost(g, "FRA", t.id) * 1.2)
	var avail_now: Array = tr.available(g, "FRA", t.cat).filter(func(x): return tr.years_ahead(g, x.id) == 0)
	if avail_now.is_empty():
		check(tr.best_choice(g, "FRA", t.cat) == "", "AI keeps a reserve before researching ahead")


func test_gov_forms() -> void:
	var g = new_game("FRA")
	var gv = g.govt
	for form in gv.cfg.form_effects:
		for k in gv.cfg.form_effects[form]:
			check(Tech.LABELS.has(k), "%s effect %s has a label" % [form, k])
	for t in g.order:
		check(not gv.form_effects(t).is_empty(), "%s (%s) has form effects" % [t, gv.form_name(t)])
	var ven = g.nations.get("VEN")
	if ven != null:
		check(gv.form_name("VEN") == "Kaufmannsrepublik", "Venice is a merchant republic")
		check(ven.bonus.gov.get("trade", 0.0) >= 0.15 - 0.001, "merchant republic trade bonus applies")
	check(g.nations.FRA.bonus.gov.get("manpower", 0.0) >= 0.1 - 0.001, "feudal monarchy manpower bonus applies")


func test_advisor_skill() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var gv = g.govt
	n.gov.advisors.clear()
	var a: Dictionary = gv.advisors[0]
	n.set(a.type, 1000.0)
	check(gv.hire(g, "FRA", a.id) == "", "hire advisor")
	check(gv.advisor_skill(n, a.id) == 1, "hired at skill 1")
	var k: String = ""
	for key in a.effects:
		if (float(a.effects[key]) > 0.0) == Tech.LABELS.get(key, [key, false, true])[2]:
			k = key
	check(k != "", "advisor has a benefit")
	var base: float = n.bonus.gov.get(k, 0.0)
	var before: float = n.get(a.type)
	check(gv.promote(g, "FRA", a.id) == "", "promote to 2")
	check(is_equal_approx(before - n.get(a.type), gv.advisor_cost(g, n, a.id) * 1.5), "promotion cost")
	check(gv.advisor_skill(n, a.id) == 2, "skill 2")
	check(is_equal_approx(n.bonus.gov.get(k, 0.0) - base, float(a.effects[k]) * 0.5), "benefit +50 % at skill 2")
	gv.promote(g, "FRA", a.id)
	check(gv.promote_block(g, "FRA", a.id) != "", "skill 3 is the maximum")
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 3)
	g2.from_dict(JSON.parse_string(text))
	check(g2.govt.advisor_skill(g2.nations.FRA, a.id) == 3, "skill survives save/load")
	# retirement: after 20+ years a pupil takes over one level lower
	g.month += 12 * 25
	var cfg: Dictionary = gv.cfg
	var old_chance = cfg.get("advisor_retire_chance")
	cfg["advisor_retire_chance"] = 1.0
	gv._advisor_careers(g, n)
	cfg["advisor_retire_chance"] = old_chance
	check(n.gov.advisors.has(a.id) and gv.advisor_skill(n, a.id) == 2, "retired advisor replaced one level lower")
	check(gv.service_years(g, n, a.id) == 0, "successor starts fresh")
	gv.dismiss(g, "FRA", a.id)
	check(not n.gov.adv_skill.has(a.id), "dismiss clears skill")
	# AI promotes with spare power once the council is full
	var g3 = new_game("FRA")
	var promoted := 0
	for y in 10:
		for mo in 12:
			g3.tick()
	for t in g3.order:
		for id in g3.nations[t].gov.advisors:
			if g3.govt.advisor_skill(g3.nations[t], id) > 1:
				promoted += 1
	print("  AI promoted advisors after 10 years: %d" % promoted)
	check(promoted > 0, "AI promotes advisors")


func test_age_goals() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var gv = g.govt
	check(gv.ages().size() == 4, "four ages")
	for a in gv.ages():
		check(a.goals.size() == 3, "%s has three goals" % a.id)
	check(gv.age_of_year(1444).id == "renaissance" and gv.age_of_year(1555).id == "reformation", "ages by year")
	var p: Array = gv.goal_progress(g, n, {"techs": 10})
	check(p[0] == n.techs.size() and p[1] == 10, "tech goal progress")
	n.gov.advisors.clear()
	for a in gv.advisors.slice(0, 3):
		n.gov.advisors.append(a.id)
	gv.ages_yearly(g, n)
	check(n.gov.ages.has("gelehrtenhof"), "three advisors reach Hof der Gelehrten")
	check(not n.gov.ages.has("renaissance"), "one goal is no triumph")
	check(n.bonus.gov.get("prestige", 0.0) >= 0.5 - 0.001, "goal reward applies")
	for t in g.tree.defs:
		if n.techs.size() >= 10:
			break
		if not Tech.is_special(t):
			n.techs[t.id] = 0
	gv.ages_yearly(g, n)
	check(n.gov.ages.has("humanisten") and n.gov.ages.has("renaissance"), "two goals win the triumph")
	check(n.bonus.gov.get("adm", 0.0) >= 0.5 - 0.001, "triumph reward applies")
	g.month = (1500 - 1444) * 12
	n.gov.companies = ["lombarden"]
	n.gov.invest["lombarden"] = 3
	gv.ages_yearly(g, n)
	check(not n.gov.ages.has("bankhaeuser"), "Renaissance goals no longer count in 1500")
	var text := JSON.stringify(g.to_dict())
	var g2 = new_game("FRA", 3)
	g2.from_dict(JSON.parse_string(text))
	check(g2.nations.FRA.gov.ages.has("renaissance"), "age goals survive save/load")
	check(g2.nations.FRA.bonus.gov.get("tech_cost", 0.0) < 0.0, "rewards restored on load")
	var ai_hits := 0
	var g3 = new_game("FRA")
	for i in 12 * 10:
		g3.tick()
	for t in g3.order:
		ai_hits += g3.nations[t].gov.ages.size()
	check(ai_hits > 0, "AI nations reach age goals too (%d)" % ai_hits)


func test_ai_marriage_and_generals() -> void:
	var g = new_game("ENG")
	var fra = g.nations.FRA
	g.bal.ai_marriage_chance = 1.0
	fra.dip = 500.0
	for t in g.order:
		g.add_rel("FRA", t, 60.0)
	g.ai._marriage(g, fra)
	check(fra.marriages.size() == 1, "the AI marries a friendly house")
	fra.mil = 999.0
	var arms: Array = g.armies_of("FRA")
	check(not arms.is_empty(), "France starts with an army")
	g.ai._hire_general(g, fra, float(g.bal.power_cap))
	var led := 0
	for a in g.armies_of("FRA"):
		if a.general > 0:
			led += 1
	check(led == 1, "the largest army gets a general from a power surplus")


func test_ai_war_odds() -> void:
	var g = new_game("ENG")
	for t in g.order:
		g.nations[t].allies.clear()
	var base: float = g.ai.war_odds(g, "TUR", "BYZ")
	# a friend of both sides stays out, so it must not count for the attacker
	g._ally("TUR", "HUN")
	g._ally("BYZ", "HUN")
	g.add_rel("TUR", "HUN", 100.0)
	check(g.ai.war_odds(g, "TUR", "BYZ") <= base + 0.001, "an ally that defends the target does not count for the attacker")
	g.nations.BYZ.allies.erase("HUN")
	g.nations.HUN.allies.erase("BYZ")
	check(g.ai.war_odds(g, "TUR", "BYZ") > base, "an ally that joins counts")
	# a historic war event is (almost) never chosen when the war is hopeless
	for a in g.armies_of("TUR"):
		a.regs = 0.1
	g.nations.TUR.allies.clear()
	g.nations.HUN.allies.clear()
	var e := {"options": [{"effects": {"war": "BYZ"}, "ai": 70}, {"effects": {"adm": 10}}]}
	var wars := 0
	for i in 200:
		if g.ai.pick_event_option(g, g.nations.TUR, e) == 0:
			wars += 1
	check(wars < 40, "the AI avoids a hopeless event war (%d/200)" % wars)


func test_ai_peace_spending() -> void:
	var g = new_game("ENG")
	var fra = g.nations.FRA
	fra.tech.adm = 3
	fra.gold = 5000.0
	fra.we = 5.0
	var other: int = -1
	for pid in g.provinces_of("FRA"):
		if pid != fra.capital:
			other = pid
			break
	g.provinces[other].religion = "protestant" if fra.religion != "protestant" else "catholic"
	g.ai._peace_spending(g, fra, 100.0)
	check(g.provinces[other].convert_months > 0, "the AI sends a missionary to a province of another faith")
	check(fra.we < 5.0 and g.feast_ready_in("FRA") > 0, "the AI holds a feast against war exhaustion")
	check(not fra.monument_build.is_empty(), "a rich AI starts a great work")
	var gold: float = fra.gold
	g.ai._peace_spending(g, fra, 100.0)
	check(fra.gold == gold, "only one great work at a time, no second feast")


func test_ai_access_and_guarantee() -> void:
	var g = new_game("ENG")
	var fra = g.nations.FRA
	for t in g.order:
		g.nations[t].allies.clear()
		g.nations[t].truces.clear()
		g.add_rel("FRA", t, 50.0)
	var mine: Array = g.neighbors_of("FRA")
	var target := ""
	for t in mine:
		for e in g.neighbors_of(t):
			if e != "FRA" and not mine.has(e) and e != "ENG" and target == "":
				target = e
	check(target != "", "some nation lies behind a French neighbour")
	g.declare_war("FRA", target)
	for e in g.enemies_of("FRA"):
		for t in mine:
			g.add_rel(t, e, -100.0)
	fra.dip = 500.0
	g.ai._war_access(g, fra)
	check(not fra.access.is_empty(), "the AI asks a neutral neighbour for passage to its enemy")
	g.wars.clear()
	g.bal.ai_guarantee_chance = 1.0
	g.ai._guarantee(g, fra)
	check(fra.guarantees.size() == 1, "a great power guarantees a small friendly neighbour")


## rel_ events (tools/content/rel_events.py): faith conditions and the convert_random effect.
func test_rel_content() -> void:
	var g = new_game("BOH")
	var n = g.nations.BOH
	var cnt := 0
	for e in data.events:
		if e.id.begins_with("rel_"):
			cnt += 1
			g.check_conditions("BOH", e.trigger)  # must not crash
	check(cnt >= 15, "religion events present (%d)" % cnt)
	check(not g.check_conditions("BOH", {"province_faith": "protestant"}) and not g.check_conditions("BOH", {"faith_share_max": 0.9}), "united catholic realm at start")
	var own: Array = g.provinces_of("BOH")
	for pid in own:
		g.provinces[pid].religion = "protestant"
	check(g.check_conditions("BOH", {"province_faith": "protestant", "faith_share_max": 0.1}), "protestant provinces detected")
	g.apply_effects("BOH", {"convert_random": 2})
	var back := 0
	for pid in own:
		if g.provinces[pid].religion == n.religion:
			back += 1
	check(back == mini(2, own.size()), "convert_random returns two provinces to the state faith (%d)" % back)
	g.apply_effects("BOH", {"convert_random": 99})
	check(g.check_conditions("BOH", {"faith_share_max": 1.0}) and not g.check_conditions("BOH", {"province_faith": "protestant"}), "convert_random never overshoots")


func test_income_bonus_and_army_cost() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var p = g.provinces[n.capital]
	var base_tax: float = g.Economy.tax(g, p)
	n.tech.adm = 10
	var ib: float = g.Economy.income_bonus(g, n)
	check(absf(g.Economy.tax(g, p) - base_tax * (1.0 + ib + g.mod(n, "tax")) / (1.0 + ib - 10 * float(g.bal.adm_tech_income) + g.mod(n, "tax"))) < 0.001,
			"admin tech adds to the tax bonus instead of multiplying it")
	var c0: float = g.regiment_cost("FRA")
	n.tech.mil += 5
	check(absf(g.regiment_cost("FRA") - c0 - 5 * float(g.bal.army_cost_per_mil_tech) * float(g.bal.regiment_cost)) < 0.001,
			"regiments get dearer with military tech")
	check(g.regiment_upkeep("FRA") > float(g.bal.regiment_maintenance), "and so does their upkeep")


## court_ events (tools/content/court_events.py): great works, feasts and marriages as conditions and effects.
func test_south_content() -> void:
	var g = new_game("FRA")
	var cnt := 0
	for e in data.events:
		if e.id.begins_with("south_"):
			cnt += 1
			check(g.nations.has(e.tag), "%s belongs to a known nation" % e.id)
			if g.nations.has(e.tag):
				g.check_conditions(e.tag, e.trigger)  # must not crash (province keys resolve)
	check(cnt >= 20, "south events present (%d)" % cnt)
	for tag in ["TUR", "MAM", "MOR"]:
		var found := 0
		for m in data.missions.get(tag, []):
			if "_south_" in m.id:
				found += 1
				g.check_conditions(tag, m.require)
		check(found >= 2, "%s has south missions" % tag)
	check(g.check_conditions("MAM", {"owns": ["aleppo", "damascus"]}), "Mamluks start with Syria")


func test_monument_events() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	for id in g.monument_defs:
		for stage in ["start", "half", "done"]:
			var eid := "mon_%s_%s" % [id, stage]
			check(g.event_by_id.has(eid) and g.event_by_id[eid].get("manual", false), "%s exists and is manual" % eid)
	# manual events are never drawn at random
	g.bal.event_chance = 1.0
	for i in 30:
		g._check_events(n)
	for eid in g.pending_events:
		check(not eid.begins_with("mon_"), "random draw picked manual event %s" % eid)
	g.pending_events.clear()
	var id := "cathedral"
	n.tech[g.monument_defs[id].tech[0]] = 20
	n.gold = 1e6
	check(g.Monuments.start(g, "FRA", id) == "", "great work starts")
	check(g.pending_events.has("mon_cathedral_start"), "start event fires on start")
	var total := int(g.monument_defs[id].months)
	for i in total / 2 - 1:
		g.Monuments.tick(g, n)
	check(not g.pending_events.has("mon_cathedral_half"), "no half event before half time")
	g.Monuments.tick(g, n)
	check(g.pending_events.has("mon_cathedral_half"), "half event at half time")
	for i in total:
		g.Monuments.tick(g, n)
	check(n.monuments.has(id) and g.pending_events.has("mon_cathedral_done"), "done event on completion")
	var cnt: int = g.pending_events.size()
	g.fire_event("FRA", "mon_cathedral_done")
	check(g.pending_events.size() == cnt, "context events fire once per realm")
	# the AI decides at once
	var ai = g.nations.ENG
	ai.tech[g.monument_defs.embassy.tech[0]] = 20
	ai.gold = 1e6
	g.Monuments.start(g, "ENG", "embassy")
	check(ai.flags.has("ev_mon_embassy_start") and not g.pending_events.has("mon_embassy_start"), "AI resolves its start event")


func test_court_content() -> void:
	var g = new_game("FRA")
	var n = g.nations.FRA
	var cnt := 0
	for e in data.events:
		if e.id.begins_with("court_"):
			cnt += 1
			g.check_conditions("FRA", e.trigger)  # must not crash
			for key in ["monument"]:
				check(not e.trigger.has(key) or g.monument_defs.has(e.trigger[key]), "%s names a known great work" % e.id)
	check(cnt >= 15, "court events present (%d)" % cnt)
	check(not g.check_conditions("FRA", {"monument_building": true}) and g.check_conditions("FRA", {"monument_building": false}), "nothing under construction at start")
	n.monument_build = {"id": "cathedral", "months": 10}
	g.apply_effects("FRA", {"monument_progress": 6})
	check(int(n.monument_build.months) == 4 and g.check_conditions("FRA", {"monument_building": true}), "monument_progress brings the work forward")
	g.apply_effects("FRA", {"monument_progress": 99})
	check(int(n.monument_build.months) == 1, "monument_progress never finishes the work outright")
	n.monuments["cathedral"] = true
	check(g.check_conditions("FRA", {"monument": "cathedral", "monuments_min": 1}) and not g.check_conditions("FRA", {"monuments_min": 2}), "finished great works")
	n.flags["feast_month"] = g.month
	check(g.check_conditions("FRA", {"feast_recent": 6}) and g.feast_ready_in("FRA") > 0, "feast held recently")
	g.apply_effects("FRA", {"feast_ready": true})
	check(g.feast_ready_in("FRA") == 0, "feast_ready resets the cooldown")
	check(not g.check_conditions("FRA", {"married": true}), "not married at start")
	check(g.check_conditions("FRA", {"is_player": true}) and not g.check_conditions("ENG", {"is_player": true}), "is_player only for the player")
	n.marriages.append("ENG")
	g.nations.ENG.marriages.append("FRA")
	var r0: float = g.get_rel("FRA", "ENG")
	g.apply_effects("FRA", {"spouse_rel": 20})
	check(g.check_conditions("FRA", {"married": true}) and g.get_rel("FRA", "ENG") > r0, "spouse_rel improves relations with in-laws")

