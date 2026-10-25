extends SceneTree
## UI smoke test: plays every playable nation for 40 years (default) headless and opens every panel and popup on the way.
## Any GDScript error shows up as "SCRIPT ERROR" in the output (CI greps for it).
## godot --headless --path . -s res://tools/ui_smoke.gd -- [--years 40] [--tags FRA,ENG]

const MAJORS := ["FRA", "ENG", "SPA", "BOH", "HAB", "RUS", "NAP", "TUR", "POL", "BUR"]


func _init() -> void:
	var years := 40
	var tags: Array = MAJORS
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--years":
			years = int(args[i + 1])
		elif args[i] == "--tags":
			tags = args[i + 1].split(",")
	_run(tags, years)


func _run(tags: Array, years: int) -> void:
	await process_frame
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.2).timeout
	m.settings.tips = true
	m.settings.tips_seen = []
	m.settings.sound = false
	var opened := 0
	for tag in tags:
		m._start_game(tag)
		m._close_modal()
		var g = m.game
		for month in years * 12:
			g.tick()
			# answer everything the way a player would
			while not g.pending_events.is_empty():
				m._show_event(g.pending_events[0])
				g.choose_event_option(tag, g.pending_events[0], month % 3)
			while not g.pending_peace.is_empty():
				m._show_peace_offer(g.pending_peace[0])
				g.answer_player_peace(g.pending_peace[0], month % 2 == 0)
			m._after_tick()
			m._close_modal()
			if month % 36 == 0:
				opened += _all_panels(m, g, tag, month)
			if g.game_over:
				break
		m._show_game_over()
		m._close_modal()
		print("SMOKE %s ok: %s, alive=%s, panels=%d" % [tag, g.date_string(), g.nations[tag].alive, opened])
	quit()


func _all_panels(m, g, tag: String, month: int) -> int:
	var n := 0
	for mode in ["nation", "economy", "mapmodes", "diplomacy", "wars", "missions", "log", "ranking", "hre"]:
		m._open_panel(mode)
		n += 1
	for t in ["trade", "goods", "overview"]:
		m.econ_tab = t
		m._open_panel("economy")
		n += 1
	var own: Array = g.provinces_of(tag)
	if not own.is_empty():
		for t in ["build", "army", "info"]:
			m.prov_tab = t
			m._open_panel("province", own[month % own.size()])
			n += 1
	# tech + government: play them like a player (AI choices), open every screen and popup
	for k in g.POWERS:
		var id: String = g.tree.best_choice(g, tag, k)
		if id != "":
			g.research(tag, id)
		m.tech_screen._select(k)
		m._open_panel("tech")
		m.tech_screen._detail(g.tree.techs_for(tag, k)[month % 27].id)
		m._close_modal()
		n += 1
	g.govt.ai_think(g, g.nations[tag])
	m._open_panel("government")
	m.gov_screen._pick_advisor()
	m._close_modal()
	m.gov_screen._pick_company()
	m._close_modal()
	m.gov_screen._pick_law(g.govt.laws[month % g.govt.laws.size()].id)
	m._close_modal()
	n += 1
	var others: Array = g.order.filter(func(t): return t != tag and g.nations[t].alive)
	if not others.is_empty():
		m._open_panel("other", others[month % others.size()])
		n += 1
	for w in g.wars_of(tag):
		m._open_panel("peace", w.id)
		n += 1
	var provs: Array = g.provinces_of(tag)
	if not provs.is_empty():
		m._on_province_tapped(provs[month % provs.size()])
		n += 1
	m._on_province_tapped(month % g.provinces.size())
	m._on_province_info(month % g.provinces.size())
	m._panel_back()
	m._panel_back()
	var arms: Array = g.armies_of(tag)
	if not arms.is_empty():
		m._on_army_tapped(arms[0].id)
		n += 1
	for mode in range(m.map.MODE_NAMES.size()):
		m._set_map_mode(mode)
	m._cycle_map_mode()
	# play the economy like a player: best building, move a merchant around
	var nat = g.nations[tag]
	var best: Array = g.Economy.best_building(g, nat, g.is_at_war(tag))
	if not best.is_empty():
		g.construct(tag, best[0], best[1])
	if not nat.merchants.is_empty() and month % 36 == 0:
		var mk: int = nat.merchants[0]
		g.Economy.recall_merchant(g, tag, mk)
		g.Economy.send_merchant(g, tag, g.markets[month % g.markets.size()])
		m._open_panel("economy")
	m._show_menu()
	m._close_modal()
	m._close_panel()
	return n
