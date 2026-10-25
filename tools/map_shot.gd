extends SceneTree
## Map-only screenshots for before/after art reviews (needs a display, e.g. xvfb-run):
## godot --path . -s res://tools/map_shot.gd -- --out /tmp/map_shots

var out := "user://map_shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--out":
		out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	_run(m)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out + "/" + name + ".png")


func _run(m) -> void:
	await create_timer(0.5).timeout
	m._start_game("FRA")
	m.settings.tips = false
	m._close_modal()
	var g = m.game
	for i in 30:
		g.tick()
	# a war so armies move and sieges show
	g.nations.FRA.truces.erase("BRI")
	g.nations.BRI.truces.erase("FRA")
	g.declare_war("FRA", "BRI")
	for i in 8:
		g.tick()
	g.pending_events.clear()
	g.pending_peace.clear()
	m._after_tick()
	m._close_modal()
	m._close_panel()
	var paris: Vector2 = g.provinces[g.key_to_pid["paris"]].center
	m.map.focus(paris, 1.6)
	await _shot("map_default")
	m.map.focus(paris, 3.0)
	await _shot("map_zoomed_in")
	m.map.focus(Vector2(1000, 700), 0.45)
	await _shot("map_europe")
	m.map.focus(Vector2(1100, 950), 1.2)
	await _shot("map_mediterranean")
	quit()
