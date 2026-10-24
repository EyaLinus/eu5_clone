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
		"test_develop_and_tech", "test_recruit_limits", "test_war_and_peace", "test_alliance_joins_war",
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
		for k in ["alive", "not_alive", "allied", "alliance", "inherit", "war"]:
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


func test_alliance_joins_war() -> void:
	var g = new_game("FRA")
	for t in g.order:
		g.nations[t].allies.clear()
	g._ally("BRI", "ENG")
	g.declare_war("FRA", "BRI")
	var w = g.war_between("FRA", "BRI")
	check(w.defenders.has("ENG"), "defensive ally joins")


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
