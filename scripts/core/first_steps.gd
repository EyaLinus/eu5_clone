extends RefCounted
## "Erste Schritte": six beginner goals that walk a new player through the main actions (develop, build,
## research, hire an advisor, raise a regiment, find a partner). Each finished goal pays a small reward when
## the player claims it. Progress is measured against a baseline taken at the first look, stored in n.flags
## (saved with the game), so old saves start from their current state. Static helpers on the game `g`.

const STEPS := [
	["develop", "🏘️ Entwickeln", "Eine Provinz entwickeln: Provinzfenster → 🏘️ mit 📜, 🕊️ oder ⚔️ bezahlen. Mehr Entwicklung bringt Steuern, Mannschaften und Punkte."],
	["build", "🏗️ Bauen", "Ein Gebäude bauen: Provinzfenster → Bauen. Gebäude steigern Steuer, Produktion oder Truppenlimit."],
	["tech", "🔬 Forschen", "Eine Technologie erforschen: unter 🔬 Technik mit Macht bezahlen. Jede Technologie bringt dauerhafte Boni."],
	["advisor", "👔 Berater", "Einen Berater einstellen: unter ⚖️ Staat → Hof. Berater liefern Macht und Boni, kosten aber Gold pro Monat."],
	["army", "🛡️ Regiment", "Ein Regiment ausheben: Provinzfenster → Armee. Mehr Regimenter schrecken Nachbarn ab und gewinnen Kriege, kosten aber Unterhalt."],
	["partner", "🤝 Bündnis/Heirat", "Ein Bündnis schließen oder eine Heirat arrangieren: bei einer anderen Nation (Diplomatie). Verbündete schützen dich, Heiraten verbessern dauerhaft die Beziehung."],
]
const TARGETS := {"develop": "province", "build": "province", "tech": "tech", "advisor": "government",
		"army": "province", "partner": "diplomacy"}
const REWARD_GOLD := 25.0
const REWARD_PRESTIGE := 5


static func _counts(g, n) -> Dictionary:
	var bld := 0
	for pid in g.provinces_of(n.tag):
		for b in g.provinces[pid].buildings:
			bld += int(g.provinces[pid].buildings[b])
	return {"develop": int(n.dev_total), "build": bld, "tech": n.techs.size(), "advisor": n.gov.advisors.size(),
			"army": int(round(g.army_regs(n.tag))), "partner": n.allies.size() + n.marriages.size()}


## Takes the baseline once per realm.
static func ensure(g, tag: String) -> void:
	var n = g.nations[tag]
	if n.flags.has("fs_base"):
		return
	n.flags["fs_base"] = _counts(g, n)


## Every step: {id, text, tip, mode, done, claimed}.
static func steps(g, tag: String) -> Array:
	ensure(g, tag)
	var n = g.nations[tag]
	var base: Dictionary = n.flags["fs_base"]
	var now := _counts(g, n)
	var out := []
	for s in STEPS:
		var id: String = s[0]
		var claimed: bool = n.flags.has("fs_" + id)
		var done: bool = claimed or int(now[id]) > int(base.get(id, 0))
		out.append({"id": id, "text": s[1], "tip": s[2], "mode": TARGETS[id], "done": done, "claimed": claimed})
	return out


## Number of finished goals whose reward waits.
static func claimable(g, tag: String) -> int:
	var c := 0
	for s in steps(g, tag):
		if s.done and not s.claimed:
			c += 1
	return c


static func all_claimed(g, tag: String) -> bool:
	for s in STEPS:
		if not g.nations[tag].flags.has("fs_" + s[0]):
			return false
	return true


## Pays the reward of a finished goal; "" or why not.
static func claim(g, tag: String, id: String) -> String:
	for s in steps(g, tag):
		if s.id != id:
			continue
		if s.claimed:
			return "Schon abgeholt."
		if not s.done:
			return "Noch nicht erledigt."
		var n = g.nations[tag]
		n.flags["fs_" + id] = g.month
		n.gold += REWARD_GOLD
		n.prestige += REWARD_PRESTIGE
		return ""
	return "Unbekanntes Ziel."
