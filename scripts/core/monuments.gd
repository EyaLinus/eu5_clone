extends RefCounted
## Great works (data/monuments.json): one of each per realm, built one at a time in the capital. They are
## expensive late-game gold sinks; the price grows with the realm's development. Finished works add
## their bonus to n.bonus["monuments"]. Static helpers on the game `g`.


static func cost(g, tag: String, id: String) -> float:
	var n = g.nations[tag]
	return float(g.monument_defs[id].cost) * (1.0 + float(n.dev_total) / float(g.bal.monument_dev_scale))


static func block_reason(g, tag: String, id: String) -> String:
	var n = g.nations[tag]
	if not g.monument_defs.has(id):
		return "Unbekanntes Bauwerk."
	var m: Dictionary = g.monument_defs[id]
	if n.monuments.has(id):
		return "Schon gebaut."
	if not n.monument_build.is_empty():
		return "Es wird schon gebaut: %s." % g.monument_defs[n.monument_build.id].name
	var req: Array = m.tech
	if int(n.tech[req[0]]) < int(req[1]):
		return "Braucht %s-Technologie %d." % [{"adm": "Verwaltungs", "dip": "Diplomatie", "mil": "Militär"}[req[0]], int(req[1])]
	if g.provinces[n.capital].controller != tag:
		return "Die Hauptstadt ist besetzt."
	if n.gold < cost(g, tag, id):
		return "Zu wenig Gold (%d)." % int(cost(g, tag, id))
	return ""


static func start(g, tag: String, id: String) -> String:
	var r := block_reason(g, tag, id)
	if r != "":
		return r
	var n = g.nations[tag]
	n.gold -= cost(g, tag, id)
	n.monument_build = {"id": id, "months": int(g.monument_defs[id].months)}
	g.fire_event(tag, "mon_%s_start" % id)
	return ""


## Monthly: building goes on while the capital is held.
static func tick(g, n) -> void:
	if n.monument_build.is_empty() or g.provinces[n.capital].controller != n.tag:
		return
	n.monument_build.months -= 1
	var id: String = n.monument_build.id
	# context events: "mon_<id>_start" (in start), "_half" once half the time is done, "_done" on completion
	if int(n.monument_build.months) * 2 <= int(g.monument_defs[id].months):
		g.fire_event(n.tag, "mon_%s_half" % id)
	if n.monument_build.months > 0:
		return
	n.monument_build = {}
	n.monuments[id] = true
	refresh(g, n)
	var m: Dictionary = g.monument_defs[id]
	g.log_msg("%s %s vollendet: %s." % [m.emoji, n.name, m.name])
	g.fire_event(n.tag, "mon_%s_done" % id)


static func refresh(g, n) -> void:
	var b := {}
	for id in n.monuments:
		var m: Dictionary = g.monument_defs.get(id, {})
		for k in m.get("bonus", {}):
			b[k] = b.get(k, 0.0) + float(m.bonus[k])
	n.bonus["monuments"] = b
