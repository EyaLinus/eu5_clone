extends SceneTree
## AI behaviour diagnostics: where do bankruptcies, revolts, unused power and lost wars come from?
## godot --headless --path . -s res://tools/ai_diag.gd -- --runs 4 --years 100 --seed 1 [--balance file.json]
## Prints one DIAG json line per run plus an aggregate (per-nation sums are averaged over runs).

const Game = preload("res://scripts/core/game.gd")
const Data = preload("res://scripts/core/data.gd")


func _init() -> void:
	var args := {}
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size() - 1, 2):
		args[a[i].trim_prefix("--")] = a[i + 1]
	var runs := int(args.get("runs", "4"))
	var years := int(args.get("years", "100"))
	var seed0 := int(args.get("seed", "1"))
	var data := Data.load_all()
	if args.has("balance"):
		var override = Data.load_json(args.balance)
		for k in override:
			data.balance[k] = override[k]
	var all := []
	for i in runs:
		var g = Game.new()
		g.setup(data, seed0 + i, "")
		var d := _run(g, years)
		all.append(d)
		print("DIAG " + JSON.stringify(d))
	print("AGG " + JSON.stringify(_aggregate(all), "  "))
	quit()


func _run(g, years: int) -> Dictionary:
	var per := {}  # tag -> counters
	for tag in g.order:
		per[tag] = {"bankrupt": 0, "revolts": 0, "neg_gold": 0, "peace_m": 0, "peace_fl": 0.0, "war_m": 0, "war_fl": 0.0,
				"gold_sum": 0.0, "dip_sum": 0.0, "mil_sum": 0.0, "adm_sum": 0.0, "alive_m": 0,
				"declared": 0, "won": 0, "lost": 0, "white": 0, "def_won": 0, "def_lost": 0}
	var war_seen := {}  # id -> {att, def, ws}
	var dev_before := {}
	for p in g.provinces:
		dev_before[p.id] = p.dev
	var revolts_before: int = g.stats.revolts
	for m in years * 12:
		g.tick()
		if g.game_over:
			break
		# revolts: dev dropped and province freshly suppressed by the uprising
		if g.stats.revolts != revolts_before:
			for p in g.provinces:
				if p.dev < dev_before[p.id] and p.suppress_months == 24:
					per[p.owner].revolts += 1
			revolts_before = g.stats.revolts
		for p in g.provinces:
			dev_before[p.id] = p.dev
		var live := {}
		for w in g.wars:
			live[w.id] = true
			if not war_seen.has(w.id):
				war_seen[w.id] = {"att": w.attackers[0], "def": w.defenders[0], "ws": 0.0, "coal": w.coalition}
				if not w.coalition:
					per[w.attackers[0]].declared += 1
			war_seen[w.id].ws = g.warscore(w)
		for id in war_seen.keys():
			if live.has(id):
				continue
			var e: Dictionary = war_seen[id]
			war_seen.erase(id)
			if e.coal:
				continue
			if e.ws > 10.0:
				per[e.att].won += 1
				per[e.def].def_lost += 1
			elif e.ws < -10.0:
				per[e.att].lost += 1
				per[e.def].def_won += 1
			else:
				per[e.att].white += 1
		for tag in g.order:
			var n = g.nations[tag]
			if not n.alive:
				continue
			var c: Dictionary = per[tag]
			c.alive_m += 1
			if n.gold < -20.0:
				c.bankrupt += 1
			if n.gold < 0.0:
				c.neg_gold += 1
			c.gold_sum += n.gold
			c.adm_sum += n.adm
			c.dip_sum += n.dip
			c.mil_sum += n.mil
			var fl: float = maxf(1.0, g.force_limit(tag))
			if g.is_at_war(tag):
				c.war_m += 1
				c.war_fl += g.army_regs(tag) / fl
			else:
				c.peace_m += 1
				c.peace_fl += g.army_regs(tag) / fl
	var out := {}
	for tag in per:
		var c: Dictionary = per[tag]
		var am: float = maxf(1.0, c.alive_m)
		out[tag] = {"major": g.nations[tag].major, "alive": g.nations[tag].alive, "dev": g.nation_dev(tag),
				"bankrupt": c.bankrupt, "neg_gold": c.neg_gold, "revolts": c.revolts,
				"gold": snappedf(c.gold_sum / am, 0.1), "adm": snappedf(c.adm_sum / am, 0.1),
				"dip": snappedf(c.dip_sum / am, 0.1), "mil": snappedf(c.mil_sum / am, 0.1),
				"army_peace": snappedf(c.peace_fl / maxf(1.0, c.peace_m), 0.01),
				"army_war": snappedf(c.war_fl / maxf(1.0, c.war_m), 0.01), "war_share": snappedf(c.war_m / am, 0.01),
				"declared": c.declared, "won": c.won, "lost": c.lost, "white": c.white,
				"def_won": c.def_won, "def_lost": c.def_lost}
	return {"seed": g.rng.seed, "stats": g.stats.duplicate(), "nations": out}


func _aggregate(all: Array) -> Dictionary:
	var n := float(maxi(all.size(), 1))
	var groups := {"major": {}, "minor": {}}
	var per := {}
	for d in all:
		for tag in d.nations:
			var e: Dictionary = d.nations[tag]
			var gk := "major" if e.major else "minor"
			if not per.has(tag):
				per[tag] = {}
			for k in e:
				if typeof(e[k]) in [TYPE_INT, TYPE_FLOAT]:
					per[tag][k] = per[tag].get(k, 0.0) + float(e[k]) / n
					groups[gk][k] = groups[gk].get(k, 0.0) + float(e[k]) / n
				elif typeof(e[k]) == TYPE_BOOL and k == "alive":
					per[tag]["alive"] = per[tag].get("alive", 0.0) + (1.0 if e[k] else 0.0) / n
					groups[gk]["alive"] = groups[gk].get("alive", 0.0) + (1.0 if e[k] else 0.0) / n
	var worst := {}
	for k in ["bankrupt", "revolts", "lost", "dip", "mil", "gold"]:
		var tags: Array = per.keys()
		tags.sort_custom(func(x, y): return per[x].get(k, 0.0) > per[y].get(k, 0.0))
		var top := []
		for t in tags.slice(0, 6):
			top.append("%s %.1f" % [t, per[t].get(k, 0.0)])
		worst[k] = top
	return {"groups": groups, "worst": worst}
