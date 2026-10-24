extends SceneTree
## Headless batch simulation: godot --headless -s res://tools/sim.gd -- --runs 20 --years 200 --seed 1
## Prints one line per run (RUN + json) plus an aggregate summary.
## --balance file.json overrides values from data/balance.json.
## --bot TAG makes TAG an aggressive, AE-ignoring stand-in player to test coalitions.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Metrics = preload("res://tools/metrics.gd")


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var runs := int(args.get("runs", "10"))
	var years := int(args.get("years", "200"))
	var seed0 := int(args.get("seed", "1"))
	var data := Data.load_all()
	if args.has("balance"):
		var override = Data.load_json(args.balance)
		for k in override:
			data.balance[k] = override[k]
	var results := []
	var t0 := Time.get_ticks_msec()
	for i in runs:
		var g = Game.new()
		g.setup(data, seed0 + i, "")
		var bot: String = args.get("bot", "")
		var bot_info := {"tag": bot, "peak_ae": 0.0, "coalition_wars": 0, "start_dev": 0}
		var seen_wars := {}
		if bot != "":
			# "aggressive player" stand-in: ignores AE when declaring wars, very warlike
			g.nations[bot].flags["bot_ignore_ae"] = true
			g.nations[bot].aggression = 2.5
			bot_info.start_dev = g.nation_dev(bot)
		for m in years * 12:
			g.tick()
			if bot != "":
				bot_info.peak_ae = maxf(bot_info.peak_ae, g.nations[bot].ae)
				for w in g.wars:
					if not seen_wars.has(w.id):
						seen_wars[w.id] = true
						if w.coalition and w.defenders.has(bot):
							bot_info.coalition_wars += 1
		var r: Dictionary = Metrics.collect(g)
		if bot != "":
			bot_info["end_dev"] = g.nation_dev(bot)
			bot_info["alive"] = g.nations[bot].alive
			r["bot"] = bot_info
		results.append(r)
		print("RUN " + JSON.stringify(r))
	var summary: Dictionary = Metrics.aggregate(results)
	if args.has("bot"):
		var b := {"peak_ae": 0.0, "coalition_wars": 0.0, "end_dev": 0.0, "alive": 0.0}
		for r in results:
			for k in b:
				b[k] += float(r.bot[k]) / results.size()
		summary["bot"] = b
	summary["ms_per_run"] = (Time.get_ticks_msec() - t0) / maxi(runs, 1)
	print("SUMMARY " + JSON.stringify(summary, "  "))
	quit()


func _parse(a: PackedStringArray) -> Dictionary:
	var d := {}
	var i := 0
	while i < a.size():
		var k := a[i].trim_prefix("--")
		if i + 1 < a.size() and not a[i + 1].begins_with("--"):
			d[k] = a[i + 1]
			i += 2
		else:
			d[k] = "1"
			i += 1
	return d
