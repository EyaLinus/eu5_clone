extends RefCounted
## Progression: realm rank (Herzogtum -> Königreich -> Imperium) by development, with growing bonuses,
## and one-time milestones (economy, trade, conquest) that pay out rewards. Static helpers on the game `g`.

const RANKS := [
	{"name": "Herzogtum", "dev": 0, "bonus": {}},
	{"name": "Königreich", "dev": 150, "bonus": {"merchants": 1.0, "force_limit": 2.0, "adm": 0.5}},
	{"name": "Imperium", "dev": 400, "bonus": {"merchants": 2.0, "force_limit": 5.0, "adm": 1.0, "dip": 0.5}},
]

## id, title, text, reward effects; checked yearly for the player via `_reached`.
const MILESTONES := [
	{"id": "first_building", "title": "Baumeister", "text": "Das erste Gebäude fertigstellen.", "reward": {"gold": 30}},
	{"id": "manufactory", "title": "Manufakturwesen", "text": "Eine Manufaktur besitzen.", "reward": {"adm": 40}},
	{"id": "buildings_25", "title": "Blühendes Land", "text": "25 Gebäudestufen im Reich.", "reward": {"prestige": 10}},
	{"id": "goods_leader", "title": "Marktführer", "text": "Bei einem Gut Marktführer sein.", "reward": {"dip": 40}},
	{"id": "goods_leader_3", "title": "Handelsmonopol", "text": "Bei drei Gütern Marktführer sein.", "reward": {"prestige": 15}},
	{"id": "market_half", "title": "Herr der Märkte", "text": "In zwei Märkten die Hälfte der Handelsmacht halten.", "reward": {"gold": 80}},
	{"id": "trade_5", "title": "Handelsmacht", "text": "5 Gold Handelseinnahmen im Monat.", "reward": {"mods": {"income": 0.03}}},
	{"id": "income_20", "title": "Reiche Kassen", "text": "20 Gold Einnahmen im Monat.", "reward": {"prestige": 10}},
	{"id": "kingdom", "title": "Königreich", "text": "Den Rang Königreich erreichen (150 Entwicklung).", "reward": {"prestige": 10}},
	{"id": "empire", "title": "Imperium", "text": "Den Rang Imperium erreichen (400 Entwicklung).", "reward": {"prestige": 25}},
	{"id": "provinces_20", "title": "Großreich", "text": "20 Provinzen besitzen.", "reward": {"mil": 50}},
	{"id": "vassal", "title": "Lehnsherr", "text": "Einen Vasallen haben.", "reward": {"dip": 30}},
	{"id": "dev_30", "title": "Metropole", "text": "Eine Provinz mit 30 Entwicklung.", "reward": {"mods": {"production": 0.05}}},
	{"id": "harbors_5", "title": "Seefahrernation", "text": "5 Hafenstufen im Reich.", "reward": {"mods": {"trade": 0.05}}},
	{"id": "pacts_2", "title": "Handelsnetz", "text": "Zwei Handelsabkommen gleichzeitig.", "reward": {"dip": 50}},
	{"id": "trade_15", "title": "Handelsimperium", "text": "15 Gold Handelseinnahmen im Monat.", "reward": {"prestige": 15}},
	{"id": "buildings_60", "title": "Baumeister des Reiches", "text": "60 Gebäudestufen im Reich.", "reward": {"mods": {"build_cost": -0.1}}},
]


static func rank(g, tag: String) -> int:
	var dev: int = g.nations[tag].dev_total
	var r := 0
	for i in RANKS.size():
		if dev >= int(RANKS[i].dev):
			r = i
	return r


static func rank_name(g, tag: String) -> String:
	return RANKS[rank(g, tag)].name


## Rank bonuses without news (game start, after loading).
static func refresh(g) -> void:
	for tag in g.order:
		var n = g.nations[tag]
		var r := rank(g, tag)
		n.bonus["rank"] = RANKS[r].bonus
		if not n.flags.has("rank"):
			n.flags["rank"] = r


## Yearly for every nation: rank bonus; for the player also rank-up news and milestones.
static func yearly(g) -> void:
	for tag in g.order:
		var n = g.nations[tag]
		if not n.alive:
			continue
		var r := rank(g, tag)
		var old: int = int(n.flags.get("rank", 0))
		n.bonus["rank"] = RANKS[r].bonus
		if r > old:
			n.flags["rank"] = r
			if tag == g.player:
				g.log_msg("👑 %s ist jetzt ein %s!" % [n.name, RANKS[r].name])
		if tag == g.player:
			check_milestones(g, tag)


static func check_milestones(g, tag: String) -> Array:
	var n = g.nations[tag]
	var got: Array = []
	for m in MILESTONES:
		var f: String = "ms_" + m.id
		if n.flags.has(f) or not _reached(g, tag, m.id):
			continue
		n.flags[f] = true
		g.apply_effects(tag, m.reward)
		got.append(m)
		g.log_msg("🏆 Meilenstein: %s" % m.title)
	return got


static func done(g, tag: String, id: String) -> bool:
	return g.nations[tag].flags.has("ms_" + id)


static func _reached(g, tag: String, id: String) -> bool:
	var Eco = g.Economy
	var n = g.nations[tag]
	match id:
		"first_building":
			return _levels(g, tag) >= 1
		"manufactory":
			for pid in g.provinces_of(tag):
				if g.provinces[pid].buildings.has("manufactory"):
					return true
			return false
		"buildings_25":
			return _levels(g, tag) >= 25
		"goods_leader":
			return g.goods_leader.values().count(tag) >= 1
		"goods_leader_3":
			return g.goods_leader.values().count(tag) >= 3
		"market_half":
			var c := 0
			for m in g.markets:
				if Eco.trade_share(g, tag, m) >= 0.5:
					c += 1
			return c >= 2
		"trade_5":
			return n.trade_income >= 5.0
		"income_20":
			return n.income >= 20.0
		"kingdom":
			return rank(g, tag) >= 1
		"empire":
			return rank(g, tag) >= 2
		"provinces_20":
			return g.provinces_of(tag).size() >= 20
		"vassal":
			return not g.vassals_of(tag).is_empty()
		"dev_30":
			for pid in g.provinces_of(tag):
				if g.provinces[pid].dev >= 30:
					return true
			return false
	return false


static func _levels(g, tag: String) -> int:
	var v := 0
	for pid in g.provinces_of(tag):
		for b in g.provinces[pid].buildings:
			v += int(g.provinces[pid].buildings[b])
	return v
