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
		"test_coalition_forms", "test_inherit", "test_inherit_never_takes_player", "test_save_roundtrip",
		"test_missions_complete", "test_long_run_no_softlock",
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
	var months := int(g.bal.total_months)
	for i in months + 5:
		# simulate a passive player who always picks the first event option and accepts peace
		while not g.pending_events.is_empty():
			g.choose_event_option("HAB", g.pending_events[0], 0)
		while not g.pending_peace.is_empty():
			g.answer_player_peace(g.pending_peace[0], true)
		g.tick()
	check(g.game_over, "game ends after 200 years")
	check(g.month == months or not g.nations.HAB.alive, "ended at the right month (%d)" % g.month)
	var stuck := 0
	for w in g.wars:
		if g.month - w.start > int(g.bal.war_timeout_months):
			stuck += 1
	check(stuck == 0, "no war older than the timeout")
