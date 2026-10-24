extends SceneTree
## Renders UI screenshots for visual checks (needs a display, e.g. xvfb-run):
## godot --path . -s res://tools/shot.gd -- --out /tmp/shots

var out := "user://shots"


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
	await _shot("01_start")
	m._start_game("FRA")
	await _shot("02_intro")
	m._close_modal()
	for i in 60:
		m.game.tick()
	m.game.pending_events.clear()
	m.game.pending_peace.clear()
	m._after_tick()
	await _shot("03_map")
	m._open_panel("nation")
	await _shot("04_nation")
	m._on_province_tapped(m.game.key_to_pid["paris"])
	await _shot("05_province")
	m._open_panel("diplomacy")
	await _shot("06_diplomacy")
	m._close_panel()
	m.map.zoom_by(0.45)
	await _shot("07_zoomed_out")
	quit()
