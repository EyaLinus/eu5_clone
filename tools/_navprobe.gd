extends SceneTree
const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
func _init():
	var g = Game.new()
	g.setup(Data.load_all(), 3, "")
	for y in [0, 30, 80]:
		while g.month < y * 12:
			g.tick()
		var line := "Y%d " % y
		for t in ["ENG","FRA","SPA","TUR","VEN","GEN","DAN","SWE","POR","NAP","HAB","RUS","MAM"]:
			if g.nations.has(t) and g.nations[t].alive:
				line += "%s %.0f/%.0f inc%.1f | " % [t, g.nations[t].ships, g.Naval.limit(g, t), g.nations[t].income]
		print(line)
		print("blockaded ", g.blockaded.size(), " blocked ", g.sea_blocked.keys(), " naval ", g.stats.get("naval_battles",0))
	quit()
