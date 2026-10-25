extends RefCounted
## Loads the static game data (map, nations, balance, events, missions).


static func load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open " + path)
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("invalid json " + path)
	return parsed


static func load_all() -> Dictionary:
	return {
		"map": load_json("res://data/map.json"),
		"nations": load_json("res://data/nations.json"),
		"balance": load_json("res://data/balance.json"),
		"events": load_json("res://data/events.json"),
		"missions": load_json("res://data/missions.json"),
		"diplomacy": load_json("res://data/diplomacy.json"),
		"goods": load_json("res://data/goods.json"),
		"buildings": load_json("res://data/buildings.json"),
	}
