extends Control
## Zoomable/pannable 2D province map. Touch (drag, pinch, tap) and mouse (drag, wheel, click).

signal province_tapped(pid: int)
signal army_tapped(army_id: int)

const SEA := Color("1d3a5c")
const WASTE := Color("55574d")
const BORDER := Color(0, 0, 0, 0.55)
const ARMY_R := 15.0
const Icons = preload("res://scripts/ui/icons.gd")

var game
var polys: Array = []
var bboxes: Array = []
var background: Array = []
var world_size := Vector2(2000, 1300)
var zoom := 0.8
var offset := Vector2.ZERO
var selected_pid := -1
var selected_army := -1
var font: Font
## 0 = political, 1 = diplomatic (player view), 2 = development
var map_mode := 0
const MODE_NAMES := ["Politisch", "Diplomatisch", "Entwicklung", "Unruhe"]

var _touches := {}
var _pinch_dist := 0.0
var _press_pos := Vector2.ZERO
var _moved := false
var _mouse_down := false


func setup(g, map_data: Dictionary) -> void:
	game = g
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = get_theme_default_font()
	polys.clear()
	bboxes.clear()
	background.clear()
	world_size = Vector2(map_data.size[0], map_data.size[1])
	for pd in map_data.provinces:
		var list := []
		var bb := Rect2()
		var first := true
		for poly in pd.polys:
			var arr := PackedVector2Array()
			for pt in poly:
				arr.append(Vector2(pt[0], pt[1]))
			list.append(arr)
			var r := _rect_of(arr)
			bb = r if first else bb.merge(r)
			first = false
		polys.append(list)
		bboxes.append(bb)
	for poly in map_data.background:
		var arr := PackedVector2Array()
		for pt in poly:
			arr.append(Vector2(pt[0], pt[1]))
		background.append(arr)
	queue_redraw()


func _rect_of(arr: PackedVector2Array) -> Rect2:
	var r := Rect2(arr[0], Vector2.ZERO)
	for p in arr:
		r = r.expand(p)
	return r


func focus(world_pos: Vector2, z: float = -1.0) -> void:
	if z > 0:
		zoom = z
	offset = size / 2 - world_pos * zoom
	_clamp()
	queue_redraw()


func to_screen(w: Vector2) -> Vector2:
	return offset + w * zoom


func to_world(s: Vector2) -> Vector2:
	return (s - offset) / zoom


func zoom_by(factor: float, at: Vector2 = Vector2(-1, -1)) -> void:
	if at.x < 0:
		at = size / 2
	var before := to_world(at)
	zoom = clampf(zoom * factor, 0.3, 4.0)
	offset = at - before * zoom
	_clamp()
	queue_redraw()


func _clamp() -> void:
	var margin := 200.0
	var ws := world_size * zoom
	offset.x = (size.x - ws.x) / 2 if ws.x < size.x else clampf(offset.x, size.x - ws.x - margin, margin)
	offset.y = (size.y - ws.y) / 2 if ws.y < size.y else clampf(offset.y, size.y - ws.y - margin, margin)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SEA)
	if game == null:
		return
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	for bg in background:
		draw_colored_polygon(bg, WASTE)
	var view := Rect2(to_world(Vector2.ZERO), size / zoom)
	for p in game.provinces:
		if not view.intersects(bboxes[p.id]):
			continue
		var c := province_color(p)
		for poly in polys[p.id]:
			draw_colored_polygon(poly, c)
		if p.controller != p.owner:
			var cc: Color = game.nations[p.controller].color
			cc.a = 0.6
			for poly in polys[p.id]:
				_draw_hatch(poly, bboxes[p.id], cc)
	var bw := 1.0 / zoom
	for p in game.provinces:
		if not view.intersects(bboxes[p.id]):
			continue
		for poly in polys[p.id]:
			var closed: PackedVector2Array = poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, BORDER, bw)
	if selected_pid >= 0:
		for poly in polys[selected_pid]:
			var closed: PackedVector2Array = poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, Color.WHITE, 3.0 / zoom)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_labels()
	_draw_armies()


func province_color(p) -> Color:
	match map_mode:
		1:
			var me: String = game.player
			if me == "":
				return game.nations[p.owner].color
			var n = game.nations[me]
			if p.owner == me:
				return Color("3a9d4a")
			if game.nations[p.owner].overlord == me:
				return Color("7fc98a")
			if game.is_allied(me, p.owner):
				return Color("4a7fd0")
			if game.at_war(me, p.owner):
				return Color("c0392b")
			if n.claims.has(p.id):
				return Color("e0a030")
			if n.coalition.has(p.owner):
				return Color("8e3a8e")
			if game.has_truce(me, p.owner):
				return Color("9aa7b0")
			return Color("6b6b62")
		2:
			var t := clampf((p.dev - 3.0) / 22.0, 0.0, 1.0)
			return Color("2d1b4e").lerp(Color("f4d35e"), t)
		3:
			if p.owner != game.player:
				return Color("4a4a44")
			var u := clampf(game.unrest(p.id) / float(game.bal.revolt_threshold), 0.0, 1.0)
			return Color("3a9d4a").lerp(Color("d03a2a"), u)
	var c: Color = game.nations[p.owner].color
	if p.owner == game.player:
		c = c.lightened(0.1)
	return c


func _draw_hatch(poly: PackedVector2Array, bb: Rect2, c: Color) -> void:
	# diagonal stripes clipped to the province polygon
	var step := 10.0
	var x := bb.position.x - bb.size.y
	while x < bb.end.x:
		var line := PackedVector2Array([Vector2(x, bb.position.y), Vector2(x + bb.size.y, bb.end.y)])
		for seg in Geometry2D.intersect_polyline_with_polygon(line, poly):
			if seg.size() >= 2:
				draw_line(seg[0], seg[seg.size() - 1], c, 3.0 / zoom)
		x += step


func _draw_labels() -> void:
	if zoom >= 1.1:
		var fs := int(clampf(11.0 * zoom, 11.0, 18.0))
		for p in game.provinces:
			var s := to_screen(p.center)
			if not Rect2(Vector2.ZERO, size).has_point(s):
				continue
			var txt: String = p.name
			if p.siege > 0.0:
				txt += " 🔥%d%%" % int(p.siege)
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := s + Vector2(-w / 2, -ARMY_R - 4)
			draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.7))
			draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	else:
		var fs := int(clampf(16.0 * zoom + 4.0, 10.0, 22.0))
		for tag in game.order:
			var n = game.nations[tag]
			if not n.alive or game.provinces_of(tag).size() < 2:
				continue
			var s := to_screen(game.provinces[n.capital].center)
			var txt: String = n.name
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := s + Vector2(-w / 2, -ARMY_R - 4)
			var flag := Icons.flag(tag)
			if flag != null:
				var fsz := Vector2(fs * 1.5, fs)
				draw_texture_rect(flag, Rect2(pos + Vector2(-fsz.x - 4, -fs * 0.85), fsz), false)
			draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
			draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func army_positions() -> Dictionary:
	var per := {}
	var out := {}
	for a in game.armies:
		var i: int = per.get(a.pid, 0)
		per[a.pid] = i + 1
		out[a.id] = to_screen(game.provinces[a.pid].center) + Vector2(i * (ARMY_R * 2 + 2), 6)
	return out


func _draw_armies() -> void:
	var pos := army_positions()
	for a in game.armies:
		if a.target >= 0 and (a.owner == game.player or a.id == selected_army):
			var pts := PackedVector2Array([pos[a.id]])
			for pid in a.path:
				pts.append(to_screen(game.provinces[pid].center))
			if pts.size() < 2:
				pts.append(to_screen(game.provinces[a.target].center))
			draw_polyline(pts, Color(1, 1, 1, 0.8), 2.0)
	for a in game.armies:
		var s: Vector2 = pos[a.id]
		if not Rect2(Vector2(-20, -20), size + Vector2(40, 40)).has_point(s):
			continue
		var c: Color = game.nations[a.owner].color
		var ring := Color.WHITE if a.id == selected_army else Color(0, 0, 0, 0.9)
		var marker := Icons.texture("army_marker")
		if marker != null:
			# pixel-art shield already has an outline: no circle, tint with the nation colour
			if a.id == selected_army:
				draw_circle(s, ARMY_R + 4, Color(1, 1, 1, 0.5))
			draw_texture_rect(marker, Rect2(s - Vector2(ARMY_R, ARMY_R) * 1.4, Vector2(ARMY_R, ARMY_R) * 2.8), false, c)
		else:
			draw_circle(s, ARMY_R + 2, ring)
			draw_circle(s, ARMY_R, c.darkened(0.15))
		var txt := str(int(round(a.regs)))
		var fs := 15
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := s + Vector2(-w / 2, 5)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color.BLACK)
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_pos = event.position
				_moved = false
		else:
			if _touches.size() == 1 and not _moved:
				_tap(event.position)
			_touches.erase(event.index)
			_pinch_dist = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			if _moved or event.position.distance_to(_press_pos) > 14.0:
				_moved = true
				offset += event.relative
				_clamp()
		elif _touches.size() >= 2:
			_moved = true
			var keys := _touches.keys()
			var p0: Vector2 = _touches[keys[0]]
			var p1: Vector2 = _touches[keys[1]]
			var d := p0.distance_to(p1)
			if _pinch_dist > 0.0 and d > 0.0:
				zoom_by(d / _pinch_dist, (p0 + p1) / 2)
			_pinch_dist = d
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_down = true
				_press_pos = event.position
				_moved = false
			else:
				_mouse_down = false
				if not _moved:
					_tap(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _mouse_down and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _moved or event.position.distance_to(_press_pos) > 6.0:
			_moved = true
			offset += event.relative
			_clamp()
			queue_redraw()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
	elif event is InputEventPanGesture:
		offset -= event.delta * 12.0
		_clamp()
		queue_redraw()


func _tap(screen_pos: Vector2) -> void:
	var pos := army_positions()
	var best := -1
	var best_d := ARMY_R + 8.0
	for id in pos:
		var d: float = pos[id].distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = id
	if best >= 0:
		army_tapped.emit(best)
		return
	var w := to_world(screen_pos)
	for p in game.provinces:
		if not bboxes[p.id].has_point(w):
			continue
		for poly in polys[p.id]:
			if Geometry2D.is_point_in_polygon(w, poly):
				province_tapped.emit(p.id)
				return
