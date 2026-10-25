extends SceneTree
## Rough per-phase timing of the monthly tick (all-AI game):
## godot --headless --path . -s res://tools/perf.gd -- --years 150

const Data = preload("res://scripts/core/data.gd")
const Game = preload("res://scripts/core/game.gd")


func _init() -> void:
	var years := 150
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--years":
		years = int(args[1])
	var g = Game.new()
	g.setup(Data.load_all(), 7, "FRA")
	var t := {"markets": 0, "economy": 0, "armies": 0, "wars": 0, "ai": 0, "player_ai": 0, "yearly": 0}
	var sub := {"gov": 0, "power": 0, "gold": 0, "diplo": 0, "armies": 0}
	for m in years * 12:
		var a := Time.get_ticks_usec()
		g.Economy.update_markets(g)
		g.Economy.check_pacts(g)
		var b := Time.get_ticks_usec()
		for tag in g.order:
			if g.nations[tag].alive:
				g._economy(g.nations[tag])
		var c := Time.get_ticks_usec()
		g._armies_tick()
		var d := Time.get_ticks_usec()
		g._wars_tick()
		var e := Time.get_ticks_usec()
		for tag in g.order:
			var nn = g.nations[tag]
			if not nn.alive or tag == g.player:
				continue
			var q0 := Time.get_ticks_usec()
			g.govt.ai_think(g, nn)
			var q1 := Time.get_ticks_usec()
			g.ai._spend_power(g, nn)
			var q2 := Time.get_ticks_usec()
			g.ai._spend_gold(g, nn)
			var q3 := Time.get_ticks_usec()
			var slot: int = (g.month + nn.capital) % 6
			if slot == 0:
				g.ai._diplomacy(g, nn)
			elif slot == 3 and not g.is_at_war(nn.tag):
				g.ai._consider_war(g, nn)
			if (g.month + nn.capital) % 3 == 0:
				g.ai._consider_peace(g, nn)
			var q4 := Time.get_ticks_usec()
			g.ai.control_armies(g, nn.tag)
			var q5 := Time.get_ticks_usec()
			sub.gov += q1 - q0
			sub.power += q2 - q1
			sub.gold += q3 - q2
			sub.diplo += q4 - q3
			sub.armies += q5 - q4
		var f := Time.get_ticks_usec()
		if g.nations[g.player].alive:
			g.ai.control_armies(g, g.player)
			g.Economy.autobuild(g, g.nations[g.player])
		var h := Time.get_ticks_usec()
		g.month += 1
		if g.month % 12 == 0:
			g._yearly()
		var i := Time.get_ticks_usec()
		t.markets += b - a
		t.economy += c - b
		t.armies += d - c
		t.wars += e - d
		t.ai += f - e
		t.player_ai += h - f
		t.yearly += i - h
	var n := years * 12
	for k in sub:
		print("  ai.%-8s %7.2f ms/tick" % [k, sub[k] / 1000.0 / n])
	var total := 0
	for k in t:
		total += t[k]
	for k in t:
		print("%-10s %7.2f ms/tick" % [k, t[k] / 1000.0 / n])
	print("total      %7.2f ms/tick" % [total / 1000.0 / n])
	quit()
