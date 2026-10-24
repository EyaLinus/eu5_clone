extends SceneTree
## Prints a 20-year trace of one all-AI game (alive nations, wars, key majors).
## godot --headless --path . -s res://tools/trace.gd
const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")
func _init():
	var data = Data.load_all()
	var g = Game.new(); g.setup(data, 5, "")
	var prev = {}
	for m in 2400:
		g.tick()
		if m % 240 == 239:
			var alive = 0
			for t in g.order: if g.nations[t].alive: alive += 1
			var s = "year %d alive %d wars %d changed %d peace %d white %d |" % [g.year(), alive, g.wars.size(), g.stats.provinces_changed, g.stats.peace_deals, g.stats.white_peace]
			for t in ["ENG","FRA","SPA","HAB","RUS","TUR","POL"]:
				var n = g.nations[t]
				s += " %s d%d ae%d adm%d g%d c%d" % [t, n.dev_total, n.ae, n.adm, n.gold, n.coalition.size()]
			print(s)
	quit()
