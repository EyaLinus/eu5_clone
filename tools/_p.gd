extends SceneTree
const Data = preload("res://scripts/core/data.gd")
const Game = preload("res://scripts/core/game.gd")
func _init():
	var g = Game.new()
	g.setup(Data.load_all(), 7, "FRA")
	for dec in 20:
		var tot := 0
		var mx := 0
		for m in 120:
			var a := Time.get_ticks_usec()
			g.tick()
			g.pending_events.clear()
			g.pending_peace.clear()
			var d := Time.get_ticks_usec() - a
			tot += d
			mx = maxi(mx, d)
		var s := JSON.stringify(g.to_dict())
		print("Y%d avg %.1f ms max %.1f ms save %d KB armies %d log %d mem %d MB" % [g.year(), tot / 120000.0, mx / 1000.0, s.length() / 1024, g.armies.size(), g.log_lines.size(), OS.get_static_memory_usage() / 1048576])
	quit()
