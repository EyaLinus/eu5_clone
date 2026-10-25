extends Control
## Zoomable/pannable 2D province map. Touch (drag, pinch, tap) and mouse (drag, wheel, click).

signal province_tapped(pid: int)
signal army_tapped(army_id: int)
signal province_long_pressed(pid: int)

const SEA := Color("1d3a5c")
const WASTE := Color("55574d")
const ARMY_R := 15.0
const Icons = preload("res://scripts/ui/icons.gd")
## Painted base map (tools/art/map_terrain.py). Without it the map falls back to flat SEA/WASTE.
const TERRAIN_PATH := "res://assets/art/map/terrain.png"
const TERRAIN_HALF_PATH := "res://assets/art/map/terrain_half.png"
const FILL_ALPHA := 0.74
const PROV_BORDER := Color(0.12, 0.09, 0.06, 0.28)
const NATION_BORDER := Color(0.07, 0.05, 0.09, 0.9)
const COAST := Color(0.03, 0.09, 0.16, 0.8)
const COUNTER_SIZE := Vector2(48, 28)

var game
var polys: Array = []
var bboxes: Array = []
var background: Array = []
var terrain: Texture2D
var terrain_half: Texture2D
var _terrain_rect: TextureRect
var _sea_rect: ColorRect
## Border segments in world space: points 2e and 2e+1 between provinces edge_l[e] and edge_r[e] (-1 = sea)
var edge_pts := PackedVector2Array()
var edge_l := PackedInt32Array()
var edge_r := PackedInt32Array()
var world_size := Vector2(2000, 1300)
var zoom := 0.8
var offset := Vector2.ZERO
var selected_pid := -1
var selected_army := -1
var font: Font
## 0 political, 1 diplomatic (player view), 2 development, 3 unrest, 4 goods, 5 trade (markets), 6 war (player)
var map_mode := 0
const MODE_NAMES := ["Politisch", "Diplomatisch", "Entwicklung", "Unruhe", "Güter", "Handel", "Krieg"]
const MARKET_COLORS := ["c0392b", "2e5bd4", "e3b21b", "1e8449", "8e44ad", "d35400", "16a085", "7f8c8d", "e84393",
		"6c5ce7", "00b894", "fdcb6e", "a0522d"]

var _touches := {}
var _pinch_dist := 0.0
var _press_pos := Vector2.ZERO
var _moved := false
var _mouse_down := false
# touch comfort: long press, double tap, fling
const LONG_PRESS_S := 0.5
const DOUBLE_TAP_S := 0.3
var _press_time := 0.0
var _long_fired := false
var _last_tap_time := -10.0
var _last_tap_pos := Vector2.ZERO
var _velocity := Vector2.ZERO
var _touch_used := false


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
	_build_edges()
	_setup_terrain()
	queue_redraw()


## Terrain lives in child nodes drawn behind this one, so it can use linear filtering while the
## pixel-art icons on top keep nearest filtering. _sync_terrain() follows pan and zoom.
func _setup_terrain() -> void:
	terrain = load(TERRAIN_PATH) if ResourceLoader.exists(TERRAIN_PATH) else null
	terrain_half = load(TERRAIN_HALF_PATH) if ResourceLoader.exists(TERRAIN_HALF_PATH) else null
	if terrain == null:
		return
	if _terrain_rect == null:
		_sea_rect = ColorRect.new()
		_sea_rect.color = Color("132a45")
		_sea_rect.show_behind_parent = true
		_sea_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sea_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_sea_rect)
		_terrain_rect = TextureRect.new()
		_terrain_rect.show_behind_parent = true
		_terrain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_terrain_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_terrain_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_terrain_rect.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(_terrain_rect)
	_sync_terrain()


func _sync_terrain() -> void:
	if _terrain_rect == null:
		return
	var tex := terrain_half if zoom < 0.7 and terrain_half != null else terrain
	if _terrain_rect.texture != tex:
		_terrain_rect.texture = tex
	_terrain_rect.position = offset
	_terrain_rect.size = world_size
	_terrain_rect.scale = Vector2(zoom, zoom)


func _edge_key(a: Vector2, b: Vector2) -> String:
	var ka := Vector2i(roundi(a.x * 10.0), roundi(a.y * 10.0))
	var kb := Vector2i(roundi(b.x * 10.0), roundi(b.y * 10.0))
	if ka.x > kb.x or (ka.x == kb.x and ka.y > kb.y):
		var t := ka
		ka = kb
		kb = t
	return "%d,%d,%d,%d" % [ka.x, ka.y, kb.x, kb.y]


## Splits all polygon outlines into unique segments and finds the province on the other side.
func _build_edges() -> void:
	var seen := {}
	edge_pts = PackedVector2Array()
	edge_l = PackedInt32Array()
	edge_r = PackedInt32Array()
	for pid in polys.size():
		for poly in polys[pid]:
			var n: int = poly.size()
			for i in n:
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % n]
				var k := _edge_key(a, b)
				if seen.has(k):
					var e: int = seen[k]
					if edge_r[e] == -1 and edge_l[e] != pid:
						edge_r[e] = pid
					continue
				seen[k] = edge_l.size()
				edge_pts.append(a)
				edge_pts.append(b)
				edge_l.append(pid)
				edge_r.append(-1)
	# segments whose vertices differ slightly between neighbours: probe both sides
	for e in edge_l.size():
		if edge_r[e] != -1:
			continue
		var a := edge_pts[e * 2]
		var b := edge_pts[e * 2 + 1]
		var nrm := (b - a).orthogonal().normalized() * 1.5
		for probe in [(a + b) / 2 + nrm, (a + b) / 2 - nrm]:
			var q := world_province_at(probe)
			if q >= 0 and q != edge_l[e]:
				edge_r[e] = q
				break


func world_province_at(w: Vector2) -> int:
	for pid in polys.size():
		if not bboxes[pid].has_point(w):
			continue
		for poly in polys[pid]:
			if Geometry2D.is_point_in_polygon(w, poly):
				return pid
	return -1


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
	_sync_terrain()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var textured := _terrain_rect != null
	if not textured:
		draw_rect(Rect2(Vector2.ZERO, size), SEA)
	if game == null:
		return
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	if not textured:
		for bg in background:
			draw_colored_polygon(bg, WASTE)
	var view := Rect2(to_world(Vector2.ZERO), size / zoom)
	for p in game.provinces:
		if not view.intersects(bboxes[p.id]):
			continue
		var c := province_color(p)
		if textured:
			c.a = FILL_ALPHA if map_mode < 2 else 0.86
		for poly in polys[p.id]:
			draw_colored_polygon(poly, c)
		if p.controller != p.owner:
			var cc: Color = game.nations[p.controller].color
			cc.a = 0.6
			for poly in polys[p.id]:
				_draw_hatch(poly, bboxes[p.id], cc)
	_draw_borders(view)
	if selected_pid >= 0:
		for poly in polys[selected_pid]:
			var closed: PackedVector2Array = poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, Color.WHITE, 3.0 / zoom)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_labels()
	_draw_armies()


## Province borders thin, coasts medium, borders between different owners thick.
func _draw_borders(view: Rect2) -> void:
	if edge_l.is_empty():
		return
	var thin := PackedVector2Array()
	var coast := PackedVector2Array()
	var nation := PackedVector2Array()
	var v := view.grow(20.0)
	for e in edge_l.size():
		var a := edge_pts[e * 2]
		var b := edge_pts[e * 2 + 1]
		if not v.has_point(a) and not v.has_point(b):
			continue
		var r := edge_r[e]
		if r < 0:
			coast.append(a)
			coast.append(b)
		elif game.provinces[edge_l[e]].owner != game.provinces[r].owner:
			nation.append(a)
			nation.append(b)
		else:
			thin.append(a)
			thin.append(b)
	if zoom >= 0.6 and not thin.is_empty():
		draw_multiline(thin, PROV_BORDER, 1.0 / zoom)
	if not coast.is_empty():
		draw_multiline(coast, COAST, 1.5 / zoom)
	if not nation.is_empty():
		draw_multiline(nation, NATION_BORDER, clampf(2.6 * zoom, 1.6, 3.4) / zoom)


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
			var t := clampf((p.dev - 3.0) / 37.0, 0.0, 1.0)
			return Color("2d1b4e").lerp(Color("f4d35e"), t)
		3:
			if p.owner != game.player:
				return Color("4a4a44")
			var u := clampf(game.unrest(p.id) / float(game.bal.revolt_threshold), 0.0, 1.0)
			return Color("3a9d4a").lerp(Color("d03a2a"), u)
		4:
			var gc := Color(game.goods_def[p.good].get("color", "#888888"))
			return gc if p.owner == game.player or game.player == "" else gc.darkened(0.25)
		5:
			var i: int = game.markets.find(p.market)
			var mc := Color(MARKET_COLORS[i % MARKET_COLORS.size()])
			if p.id == p.market:
				return mc.lightened(0.45)
			return mc if p.owner == game.player else mc.darkened(0.35)
		6:
			return war_color(p)
	var c: Color = game.nations[p.owner].color
	if p.owner == game.player:
		c = c.lightened(0.1)
	return c


## War map: your side green/blue, enemies red, fronts (occupations) bright; everyone else grey.
func war_color(p) -> Color:
	var me: String = game.player
	if me == "":
		return Color("5a5a52")
	var owner_enemy: bool = game.at_war(me, p.owner)
	var ctrl_enemy: bool = game.at_war(me, p.controller)
	if p.owner == me:
		return Color("e67e22") if ctrl_enemy else Color("3a9d4a")
	if owner_enemy:
		return Color("f1c40f") if not ctrl_enemy else Color("b03a2e")
	var mine_or_ally: bool = game.is_allied(me, p.owner) or game.nations[p.owner].overlord == me
	if mine_or_ally:
		for w in game.wars_of(me):
			if game.side_tags(w, game.is_attacker(w, me)).has(p.owner):
				return Color("e67e22") if ctrl_enemy else Color("4a7fd0")
	return Color("5a5a52")


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
			var owned: Array = game.provinces_of(tag)
			if not n.alive or owned.size() < 2:
				continue
			var s := to_screen(_realm_center(tag, owned))
			var txt: String = n.name
			var big := clampf(sqrt(float(owned.size())) / 3.0, 1.0, 1.6)
			fs = int(clampf((16.0 * zoom + 4.0) * big, 10.0, 30.0))
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := s + Vector2(-w / 2, -ARMY_R - 4)
			var flag := Icons.flag(tag)
			if flag != null:
				var fsz := Vector2(fs * 1.5, fs)
				draw_texture_rect(flag, Rect2(pos + Vector2(-fsz.x - 4, -fs * 0.85), fsz), false)
			draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
			draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Label anchor for a nation: the owned province closest to the development-weighted center of its land
## (so the label sits on the realm even for crescent-shaped or split territories).
func _realm_center(tag: String, owned: Array) -> Vector2:
	var sum := Vector2.ZERO
	var w := 0.0
	for pid in owned:
		var p = game.provinces[pid]
		sum += p.center * (p.dev + 5.0)
		w += p.dev + 5.0
	var c := sum / maxf(w, 0.001)
	var best: Vector2 = game.provinces[game.nations[tag].capital].center
	var best_d := INF
	for pid in owned:
		var d: float = game.provinces[pid].center.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = game.provinces[pid].center
	return best


func army_positions() -> Dictionary:
	var per := {}
	var out := {}
	for a in game.armies:
		var i: int = per.get(a.pid, 0)
		per[a.pid] = i + 1
		var step := 12.0 if zoom < 0.8 else 22.0
		out[a.id] = to_screen(game.provinces[a.pid].center) + Vector2(i * 6, 8 + i * step)
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
		var counter := Icons.texture("army_counter")
		var marker := Icons.texture("army_marker")
		if counter != null:
			_draw_counter(a, s, c, counter)
			continue
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

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	# long press: hold still on a province to open its info (even while an army is selected)
	var holding: bool = (_touches.size() == 1 or _mouse_down) and not _moved and not _long_fired
	if holding and _now() - _press_time >= LONG_PRESS_S:
		_long_fired = true
		var pid := province_at(_press_pos)
		if pid >= 0:
			Input.vibrate_handheld(30)
			province_long_pressed.emit(pid)
	# fling: the map keeps gliding after a quick swipe
	if _velocity.length() > 20.0 and _touches.is_empty() and not _mouse_down:
		offset += _velocity * delta
		_velocity *= pow(0.04, delta)
		_clamp()
		queue_redraw()
	elif _touches.is_empty() and not _mouse_down:
		_velocity = Vector2.ZERO


func _release_tap(pos: Vector2) -> void:
	if _long_fired:
		return
	var t := _now()
	if t - _last_tap_time < DOUBLE_TAP_S and pos.distance_to(_last_tap_pos) < 40.0:
		_last_tap_time = -10.0
		zoom_by(1.7, pos)
		return
	_last_tap_time = t
	_last_tap_pos = pos
	_tap(pos)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_used = true
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_pos = event.position
				_press_time = _now()
				_moved = false
				_long_fired = false
				_velocity = Vector2.ZERO
		else:
			if _touches.size() == 1 and not _moved:
				_release_tap(event.position)
			_touches.erase(event.index)
			_pinch_dist = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			if _moved or event.position.distance_to(_press_pos) > 14.0:
				_moved = true
				offset += event.relative
				_velocity = event.velocity
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
				_press_time = _now()
				_moved = false
				_long_fired = false
				_velocity = Vector2.ZERO
			else:
				_mouse_down = false
				if not _moved:
					_release_tap(event.position)
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
	# fingers are less precise than a mouse pointer
	var best_d := ARMY_R + (22.0 if _touch_used else 8.0)
	for id in pos:
		var d: float = pos[id].distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = id
	if best >= 0:
		army_tapped.emit(best)
		return
	var pid := province_at(screen_pos)
	if pid >= 0:
		province_tapped.emit(pid)


func province_at(screen_pos: Vector2) -> int:
	if game == null:
		return -1
	var w := to_world(screen_pos)
	for p in game.provinces:
		if not bboxes[p.id].has_point(w):
			continue
		for poly in polys[p.id]:
			if Geometry2D.is_point_in_polygon(w, poly):
				return p.id
	return -1


## Army counter: nation-tinted plate, steel pikeman, regiment count, march arrow when moving.
func _draw_counter(a, s: Vector2, c: Color, counter: Texture2D) -> void:
	# zoomed out: native 1x plate with just the number, so Europe stays readable
	var compact := zoom < 0.8
	var csz := COUNTER_SIZE / 2 if compact else COUNTER_SIZE
	var r := Rect2(s - csz / 2, csz)
	if a.id == selected_army:
		draw_rect(r.grow(3.0), Color(1, 1, 1, 0.9))
	draw_texture_rect(counter, r, false, c)
	var unit := Icons.texture("army_unit")
	if unit != null and not compact:
		draw_texture_rect(unit, Rect2(r.position, Vector2(20, 28)), false)
	if a.target >= 0 and not compact:
		var arrow := Icons.texture("army_moving")
		if arrow != null:
			draw_texture_rect(arrow, Rect2(Vector2(r.end.x - 10, r.position.y - 8), Vector2(18, 14)), false)
	var txt := str(int(round(a.regs)))
	var fs := (15 if txt.length() < 3 else 13) if not compact else 10
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx := r.get_center().x if compact else r.position.x + 33
	var tp := Vector2(cx - w / 2, s.y + fs * 0.36)
	draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2 if compact else 3, Color.BLACK)
	draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
