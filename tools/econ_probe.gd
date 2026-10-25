extends SceneTree
## Prints economy numbers of one all-AI game (income split, prices, buildings, trade) every 50 years.
## godot --headless --path . -s res://tools/econ_probe.gd -- [seed]

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var g := Game.new()
	g.setup(Data.load_all(), seed_value, "")
	var t0 := Time.get_ticks_msec()
	for y in 201:
		if y % 50 == 0:
			_report(g)
		for m in 12:
			if g.game_over:
				break
			g.tick()
	print("ms: ", Time.get_ticks_msec() - t0)
	quit()


func _report(g) -> void:
	print("== ", g.year(), " prices ", g.prices, " leaders ", g.goods_leader)
	var nb := 0
	var nl := 0
	var dev := 0
	for p in g.provinces:
		nb += p.buildings.size()
		dev += p.dev
		for b in p.buildings:
			nl += p.buildings[b]
	print("buildings ", nb, " levels ", nl, " world dev ", dev)
	for tag in ["FRA", "ENG", "BOH", "VEN", "TUR", "MLO"]:
		var n = g.nations[tag]
		if not n.alive:
			continue
		print("%s dev %d inc %.2f (tax %.2f prod %.2f trade %.2f) exp %.2f gold %.0f merchants %s fl %.1f" % [tag, n.dev_total, n.income,
				n.tax_income, n.prod_income, n.trade_income, n.expenses, n.gold, n.merchants, g.force_limit(tag)])
