extends SceneTree
## Quick screenshots of the main UI surfaces for reviewing the pixel UI kit (tools/art/ui_kit.py):
## xvfb-run godot --path . --resolution 1280x720 -s res://tools/ui_kit_shot.gd -- --out /tmp/kit

var out := "user://kit_shots"


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
	await _shot("a_start")
	m._start_game("FRA")
	m.settings.tips = false
	await _shot("b_intro")
	m._close_modal()
	for i in 24:
		m.game.tick()
	m.game.pending_events.clear()
	m.game.pending_peace.clear()
	m._after_tick()
	var g = m.game
	g.nations.FRA.adm = 400.0
	g.nations.FRA.dip = 400.0
	g.nations.FRA.gold = 2000.0
	g.govt.hire(g, "FRA", "fra_coeur")
	g.govt.found_company(g, "FRA", "lombarden")
	m._open_panel("nation")
	await _shot("c_nation")
	m._open_panel("modifiers")
	await _shot("c2_modifiers")
	m._open_panel("government")
	await _shot("d_government")
	m._open_panel("tech")
	await _shot("e_tech")
	m.tech_screen._detail("fra_ordonnance")
	await _shot("f_tech_detail")
	m._close_modal()
	var paris: int = g.key_to_pid["paris"]
	m.prov_tab = "build"
	m._on_province_tapped(paris)
	await _shot("g_province")
	m.prov_tab = "info"
	m._close_panel()
	m._show_event(g.event_defs[3].id)
	await _shot("h_event")
	m._close_modal()
	m._open_panel("economy")
	await _shot("i_economy")
	quit()
