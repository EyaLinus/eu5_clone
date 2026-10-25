extends RefCounted
## Balance metrics for one finished (or running) game and aggregation over many runs.

const MAJORS := ["FRA", "ENG", "SPA", "BOH", "HAB", "RUS", "NAP", "TUR", "POL", "BUR"]  # all playable nations


static func collect(g) -> Dictionary:
	var total := 0
	for p in g.provinces:
		total += p.dev
	var alive := 0
	var top_share := 0.0
	var top_tag := ""
	var majors := {}
	for tag in g.order:
		var n = g.nations[tag]
		if n.alive:
			alive += 1
		var share: float = float(g.nation_dev(tag)) / total
		if share > top_share:
			top_share = share
			top_tag = tag
		if MAJORS.has(tag):
			majors[tag] = {"dev": g.nation_dev(tag), "provs": g.provinces_of(tag).size(), "alive": n.alive,
					"tech": n.tech.adm + n.tech.dip + n.tech.mil, "gold": snappedf(n.gold, 0.1), "ae": snappedf(n.ae, 0.1)}
	var negative_gold := 0
	for tag in g.order:
		if g.nations[tag].alive and g.nations[tag].gold < 0:
			negative_gold += 1
	return {"alive": alive, "top_share": snappedf(top_share, 0.001), "top_tag": top_tag, "total_dev": total,
			"stats": g.stats.duplicate(), "majors": majors, "open_wars": g.wars.size(), "negative_gold": negative_gold,
			"month": g.month}


static func aggregate(rs: Array) -> Dictionary:
	var n := float(maxi(rs.size(), 1))
	var a := {"runs": rs.size(), "alive": 0.0, "top_share": 0.0, "max_top_share": 0.0, "negative_gold": 0.0,
			"open_wars": 0.0, "stats": {}, "major_dev": {}, "major_alive": {}, "top_tags": {}}
	for r in rs:
		a.alive += r.alive / n
		a.top_share += r.top_share / n
		a.max_top_share = maxf(a.max_top_share, r.top_share)
		a.negative_gold += r.negative_gold / n
		a.open_wars += r.open_wars / n
		a.top_tags[r.top_tag] = a.top_tags.get(r.top_tag, 0) + 1
		for k in r.stats:
			a.stats[k] = a.stats.get(k, 0.0) + r.stats[k] / n
		for t in r.majors:
			a.major_dev[t] = a.major_dev.get(t, 0.0) + r.majors[t].dev / n
			a.major_alive[t] = a.major_alive.get(t, 0.0) + (1.0 if r.majors[t].alive else 0.0) / n
	return a
