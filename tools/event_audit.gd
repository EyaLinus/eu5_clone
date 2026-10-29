extends SceneTree
## Event audit: plays full games headless and counts how many realms saw each event (and finished each mission).
## godot --headless -s res://tools/event_audit.gd -- --runs 2 --seed 1 [--years 200]
## All realms are AI-run, as in tools/sim.gd (a player realm would sit idle and skew the counts), so player-only
## events ("is_player") are never counted; tools/event_audit.py lists them separately. Prints one "AUDIT {json}" line:
## {"runs": n, "events": {id: realms}, "missions": {id: realms}}. Merge several outputs with tools/event_audit.py.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")


func _init() -> void:
	var args := {}
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size() - 1, 2):
		args[a[i].trim_prefix("--")] = a[i + 1]
	var runs := int(args.get("runs", "2"))
	var years := int(args.get("years", "200"))
	var seed0 := int(args.get("seed", "1"))
	var data := Data.load_all()
	var ev := {}
	var ms := {}
	for i in runs:
		var g = Game.new()
		g.setup(data, seed0 + i, "")
		for m in years * 12:
			g.tick()
			if g.game_over:
				break
		for tag in g.nations:
			var n = g.nations[tag]
			for f in n.flags:
				if str(f).begins_with("ev_"):
					var id := str(f).substr(3)
					ev[id] = ev.get(id, 0) + 1
			for mid in n.missions_done:
				ms[mid] = ms.get(mid, 0) + 1
	print("AUDIT " + JSON.stringify({"runs": runs, "events": ev, "missions": ms}))
	quit()
