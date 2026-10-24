extends SceneTree
## Headless batch simulation: godot --headless -s res://tools/sim.gd -- --runs 20 --years 200 --seed 1
## Prints one JSON line per run plus an aggregate summary.

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
const Metrics = preload("res://tools/metrics.gd")


func _init() -> void:
	var args := _parse(OS.get_cmdline_user_args())
	var runs := int(args.get("runs", "10"))
	var years := int(args.get("years", "200"))
	var seed0 := int(args.get("seed", "1"))
	var data := Data.load_all()
	var results := []
	var t0 := Time.get_ticks_msec()
	for i in runs:
		var g = Game.new()
		g.setup(data, seed0 + i, "")
		for m in years * 12:
			g.tick()
		var r: Dictionary = Metrics.collect(g)
		results.append(r)
		if args.has("verbose"):
			print(JSON.stringify(r))
	var summary: Dictionary = Metrics.aggregate(results)
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
