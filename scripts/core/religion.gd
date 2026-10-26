extends RefCounted
## Faith: every nation has a state religion, every province the religion of its people. Provinces of
## another faith are restless; they convert slowly on their own, or faster with a missionary. From 1517
## the Reformation spreads Protestantism through the Holy Roman Empire, and realms whose people turned
## may change their state religion. Static helpers on the game `g`.

const FAITHS := {
	"catholic": {"name": "Katholisch", "color": "e8d27a"},
	"protestant": {"name": "Protestantisch", "color": "9a5ac8"},
	"orthodox": {"name": "Orthodox", "color": "6a9ae0"},
	"sunni": {"name": "Sunnitisch", "color": "3fa860"},
}


static func faith_name(r: String) -> String:
	return FAITHS.get(r, {}).get("name", r)


static func setup(g, data: Dictionary) -> void:
	for tag in g.nations:
		g.nations[tag].religion = str(data.nations[tag].get("religion", "catholic"))
	for p in g.provinces:
		p.religion = g.nations[p.owner].religion


static func unrest(g, p) -> float:
	return float(g.bal.religion_unrest) if p.religion != g.nations[p.owner].religion else 0.0


## Share (0..1) of a nation's development that follows religion r.
static func share(g, tag: String, r: String) -> float:
	var total := 0.0
	var same := 0.0
	for pid in g.provinces_of(tag):
		var p = g.provinces[pid]
		total += p.dev
		if p.religion == r:
			same += p.dev
	return same / total if total > 0.0 else 0.0


static func missionaries(g, tag: String) -> int:
	var c := 0
	for pid in g.provinces_of(tag):
		if g.provinces[pid].convert_months > 0:
			c += 1
	return c


static func convert_cost(g, p) -> float:
	return float(g.bal.convert_cost_base) + float(g.bal.convert_cost_per_dev) * p.dev


static func convert_block_reason(g, tag: String, pid: int) -> String:
	var p = g.provinces[pid]
	var n = g.nations[tag]
	if p.owner != tag:
		return "Nicht deine Provinz."
	if p.religion == n.religion:
		return "Die Provinz teilt deinen Glauben."
	if p.convert_months > 0:
		return "Ein Missionar ist schon dort."
	if p.controller != tag:
		return "Die Provinz ist besetzt."
	if missionaries(g, tag) >= int(g.bal.max_missionaries):
		return "Höchstens %d Missionare gleichzeitig." % int(g.bal.max_missionaries)
	if n.gold < convert_cost(g, p):
		return "Zu wenig Gold (%d)." % int(convert_cost(g, p))
	return ""


static func send_missionary(g, tag: String, pid: int) -> String:
	var r := convert_block_reason(g, tag, pid)
	if r != "":
		return r
	var p = g.provinces[pid]
	g.nations[tag].gold -= convert_cost(g, p)
	p.convert_months = int(g.bal.convert_months)
	return ""


## The state religion can follow the people once enough of the realm shares the other faith.
static func change_block_reason(g, tag: String, r: String) -> String:
	var n = g.nations[tag]
	if not FAITHS.has(r) or r == n.religion:
		return "Ungültiger Glaube."
	if r == "protestant" and g.year() < int(g.bal.reformation_year):
		return "Die Reformation hat noch nicht begonnen."
	var s := share(g, tag, r)
	if s < float(g.bal.religion_change_share):
		return "Nur %d%% deines Landes sind %s (braucht %d%%)." % [int(s * 100), faith_name(r).to_lower(), int(float(g.bal.religion_change_share) * 100)]
	if n.prestige < float(g.bal.religion_change_prestige):
		return "Zu wenig Prestige (%d)." % int(g.bal.religion_change_prestige)
	return ""


static func change_religion(g, tag: String, r: String) -> String:
	var e := change_block_reason(g, tag, r)
	if e != "":
		return e
	var n = g.nations[tag]
	n.prestige -= float(g.bal.religion_change_prestige)
	var old: String = n.religion
	n.religion = r
	for pid in g.provinces_of(tag):
		g.provinces[pid].convert_months = 0
	for t in g.order:
		var o = g.nations[t]
		if t != tag and o.alive:
			if o.religion == r:
				g.add_rel(tag, t, float(g.bal.religion_change_rel))
			elif o.religion == old:
				g.add_rel(tag, t, -float(g.bal.religion_change_rel))
	g.log_msg("⛪ %s wechselt zum Glauben: %s." % [n.name, faith_name(r)], [tag])
	return ""


## Monthly per nation: missionaries finish their work.
static func monthly(g, n) -> void:
	for pid in g.provinces_of(n.tag):
		var p = g.provinces[pid]
		if p.convert_months <= 0:
			continue
		if p.controller != n.tag or p.religion == n.religion:
			p.convert_months = 0
			continue
		p.convert_months -= 1
		if p.convert_months == 0:
			p.religion = n.religion
			if n.tag == g.player:
				g.log_msg("⛪ %s hat den Glauben angenommen: %s." % [p.name, faith_name(n.religion)], [n.tag])


static func yearly(g) -> void:
	var y: int = g.year()
	# people slowly take up the faith of their rulers
	for p in g.provinces:
		var own: String = g.nations[p.owner].religion
		if p.religion != own and p.convert_months == 0 and p.controller == p.owner and g.rng.randf() < float(g.bal.religion_drift):
			p.religion = own
	if y >= int(g.bal.reformation_year) and y <= int(g.bal.reformation_end):
		_reformation(g, y)
	# AI realms whose people turned follow them
	for tag in g.order:
		var n = g.nations[tag]
		if tag == g.player or not n.alive:
			continue
		for r in FAITHS:
			if r != n.religion and share(g, tag, r) > float(g.bal.religion_ai_change_share) \
					and change_block_reason(g, tag, r) == "" and g.rng.randf() < float(g.bal.religion_ai_change_chance):
				change_religion(g, tag, r)
				break


static func _reformation(g, y: int) -> void:
	var members: Array = g.hre_members()
	if y == int(g.bal.reformation_year):
		var seed_tag: String = "SAX" if g.nations.has("SAX") and g.nations.SAX.alive else ""
		var start: int = g.nations[seed_tag].capital if seed_tag != "" else -1
		if start < 0 or g.provinces[start].religion != "catholic":
			for pid in g.provinces.size():
				var q = g.provinces[pid]
				if members.has(q.owner) and q.religion == "catholic":
					start = pid
					break
		if start >= 0:
			g.provinces[start].religion = "protestant"
			g.log_msg("⛪ Thesenanschlag in %s: Die Reformation beginnt!" % g.provinces[start].name, [])
		return
	var turn := []
	for p in g.provinces:
		if p.religion != "catholic":
			continue
		var near := false
		for a in p.adj:
			if g.provinces[a].religion == "protestant":
				near = true
				break
		var chance: float = float(g.bal.reformation_spread) if members.has(p.owner) else float(g.bal.reformation_spread_outside)
		if g.nations[p.owner].religion == "protestant":
			chance *= 2.0
		if near and g.rng.randf() < chance:
			turn.append(p)
	for p in turn:
		p.religion = "protestant"
