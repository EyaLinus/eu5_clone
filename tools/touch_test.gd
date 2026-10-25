extends SceneTree
## Input test for the touch layer: dragging on a button scrolls the side panel without clicking it,
## a long press shows the tooltip without clicking. Prints "TOUCH ok" or "TOUCH FAIL ...".
## godot --headless --path . -s res://tools/touch_test.gd


func _init() -> void:
	_run()


func _mouse(m, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e)


func _move(m, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)


func _run() -> void:
	await process_frame
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(0.3).timeout
	m._start_game("FRA")
	m.settings.tips = false
	m._close_modal()
	m._open_panel("economy")
	await create_timer(0.3).timeout
	var fails := []
	# find a button in the lower half of the scroll area
	var target: Button = null
	for c in m.side_box.get_children():
		if c is Button and c.get_global_rect().position.y > m.side_scroll.get_global_rect().position.y + 150:
			target = c
			break
	if target == null:
		print("TOUCH FAIL no button")
		quit(1)
		return
	var clicked := [0]
	target.pressed.connect(func(): if not m._suppress_click: clicked[0] += 1)
	var p: Vector2 = target.get_global_rect().get_center()
	var before: int = m.side_scroll.scroll_vertical
	_mouse(m, p, true)
	for i in 10:
		await process_frame
		_move(m, p - Vector2(0, 15 * (i + 1)))
	await process_frame
	_mouse(m, p - Vector2(0, 150), false)
	await process_frame
	if m.side_scroll.scroll_vertical <= before:
		fails.append("drag did not scroll (%d -> %d)" % [before, m.side_scroll.scroll_vertical])
	if clicked[0] > 0:
		fails.append("drag clicked the button")
	# long press shows a tooltip, no click
	m.side_scroll.scroll_vertical = 0
	await process_frame
	var tipped: Button = null
	for c in m.side_box.get_children():
		if c is Button and c.tooltip_text != "" and c.is_visible_in_tree():
			tipped = c
			break
	if tipped != null:
		var q: Vector2 = tipped.get_global_rect().get_center()
		var panel_before: String = m.panel_mode
		_mouse(m, q, true)
		await create_timer(0.7).timeout
		_mouse(m, q, false)
		await process_frame
		if m._tip_panel == null or not m._tip_panel.visible:
			fails.append("long press showed no tooltip")
		if m.panel_mode != panel_before:
			fails.append("long press triggered the button")
	# a normal tap still clicks
	var tap_ok := [false]
	var b: Button = m._btn("test", func(): tap_ok[0] = true)
	m.side_box.add_child(b)
	m.side_box.move_child(b, 0)
	m.side_scroll.scroll_vertical = 0
	await process_frame
	await process_frame
	var r: Vector2 = b.get_global_rect().get_center()
	_mouse(m, r, true)
	await process_frame
	_mouse(m, r, false)
	await process_frame
	if not tap_ok[0]:
		fails.append("tap did not click")
	# the same drag as real touch events (as on Android; also emulated to mouse by the engine)
	m.side_scroll.scroll_vertical = 0
	await process_frame
	var t0: Vector2 = target.get_global_rect().get_center()
	var tclicked: int = clicked[0]
	var st := InputEventScreenTouch.new()
	st.index = 0
	st.position = t0
	st.pressed = true
	Input.parse_input_event(st)
	for i in 10:
		await process_frame
		var sd := InputEventScreenDrag.new()
		sd.index = 0
		sd.position = t0 - Vector2(0, 15 * (i + 1))
		sd.relative = Vector2(0, -15)
		Input.parse_input_event(sd)
	await process_frame
	var su := InputEventScreenTouch.new()
	su.index = 0
	su.position = t0 - Vector2(0, 150)
	su.pressed = false
	Input.parse_input_event(su)
	await process_frame
	await process_frame
	if m.side_scroll.scroll_vertical <= 0:
		fails.append("touch drag did not scroll")
	if clicked[0] > tclicked:
		fails.append("touch drag clicked the button")
	print("TOUCH ok" if fails.is_empty() else "TOUCH FAIL " + "; ".join(fails))
	quit(0 if fails.is_empty() else 1)
