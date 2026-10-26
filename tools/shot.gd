extends SceneTree
## Renders UI screenshots for visual checks (needs a display, e.g. xvfb-run):
## godot --path . -s res://tools/shot.gd -- --out /tmp/shots

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--out":
		out = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	if "--big" in args:
		var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"big_ui": true, "tips": false, "ui_scale": 1.0}))
		f.close()
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
	m.settings.tips = false
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
	m.game.nations.FRA.adm = 400.0
	m.game.nations.FRA.dip = 400.0
	m._open_panel("tech")
	await _shot("04a_tech")
	m.tech_screen._detail("fra_ordonnance")
	await _shot("04b_tech_detail")
	m._close_modal()
	m.tech_screen._select("mil")
	await _shot("04c_tech_mil")
	m.game.govt.hire(m.game, "FRA", "fra_coeur")
	m.game.govt.set_law(m.game, "FRA", "kirche", "toleranz")
	m.game.nations.FRA.gold = 2000.0
	m.game.govt.found_company(m.game, "FRA", "lombarden")
	m._open_panel("government")
	await _shot("04d_government")
	m.game.nations.FRA.gov.estates.klerus = 22.0
	m.game.nations.FRA.gov.estates.adel = 68.0
	m.game.govt.refresh_estates(m.game.nations.FRA)
	m._open_panel("government")
	await process_frame
	m.side_scroll.scroll_vertical = 100000
	await _shot("04h_estates")
	m.gov_screen._invest("lombarden")
	await _shot("04g_invest")
	m._close_modal()
	m.gov_screen._pick_advisor()
	await _shot("04e_pick_advisor")
	m._close_modal()
	m.gov_screen._pick_law("heer")
	await _shot("04f_pick_law")
	m._close_modal()
	m._on_province_tapped(m.game.key_to_pid["paris"])
	await _shot("05_province")
	m._open_panel("diplomacy")
	await _shot("06_diplomacy")
	m._close_panel()
	m.map.zoom_by(0.45)
	await _shot("07_zoomed_out")
	m.map.map_mode = 1
	m.map.queue_redraw()
	await _shot("08_diplomatic")
	# vassal UI: make Brittany a vassal of the player
	var g = m.game
	g.nations.FRA.truces.erase("BRI")
	g.nations.BRI.truces.erase("FRA")
	if g.declare_war("FRA", "BRI") == "":
		var w = g.war_between("FRA", "BRI")
		m._open_panel("peace", w.id)
		await _shot("09_peace_vassal")
		g.make_peace(w, true, [], true)
	m.map.map_mode = 0
	m._open_panel("other", "BRI")
	await _shot("10_vassal_panel")
	m._open_panel("diplomacy")
	await _shot("11_diplomacy_vassal")
	m._open_panel("ranking")
	await _shot("12_ranking")
	var rennes: int = g.key_to_pid["rennes"]
	g.provinces[rennes].owner = "FRA"
	g.provinces[rennes].prev_owner = "BRI"
	g.provinces[rennes].core_months = 40
	g._rebuild_owned()
	g.nations.FRA.we = 6.0
	m.map.map_mode = 3
	m._on_province_tapped(rennes)
	await _shot("13_unrest")
	m.map.map_mode = 0
	m._open_panel("hre")
	await _shot("14_hre")
	# economy: a few buildings in Paris, the economy panel, goods / trade / war map modes
	var paris: int = g.key_to_pid["paris"]
	g.nations.FRA.gold = 2000.0
	g.provinces[paris].buildings = {"workshop": 2, "marketplace": 1}
	g.Economy.refresh_local(g, g.provinces[paris])
	g.construct("FRA", paris, "manufactory")
	m._on_province_tapped(paris)
	await _shot("16_province_buildings")
	m._open_panel("economy")
	await _shot("17_economy")
	m._open_panel("mapmodes")
	m._set_map_mode(5)
	await _shot("18_goods_map")
	m._set_map_mode(6)
	await _shot("19_trade_map")
	g.nations.FRA.truces.erase("ENG")
	g.nations.ENG.truces.erase("FRA")
	g.declare_war("FRA", "ENG")
	m._set_map_mode(4)
	await _shot("20_war_map")
	m._set_map_mode(0)
	m._close_panel()
	for i in 240:
		g.tick()
	g.pending_events.clear()
	g.pending_peace.clear()
	m._show_game_over()
	await _shot("15_game_over")
	quit()
