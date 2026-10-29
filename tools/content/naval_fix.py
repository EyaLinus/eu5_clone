"""Brings older fleet-themed events and missions in line with the naval system (v0.9.3+):
fleet options give ships and the "naval" modifier instead of land "combat", fleet missions require ships
(ships_min) instead of land regiments. Thresholds: start fleet limits are 3-7 ships, about 15-50 by 1520.
Edits data/events.json and data/missions.json in place.
Run: python3 tools/content/naval_fix.py (idempotent: it sets values, it does not add to them).
"""
import json
import os
import re

import events_io

# event id -> {option index: new effects}
EVENTS = {
    "eng_navy": {0: {"gold": -60, "ships": 4, "mods": {"naval": 0.03}}},
    "eng_armada": {0: {"prestige": 20, "gold": -60, "mods": {"naval": 0.03}}},
    "spa_lepanto": {0: {"mil": -40, "ships": -2, "prestige": 20, "relations": {"PAP": 40, "VEN": 40, "TUR": -50}}},
    "tur_lepanto": {0: {"gold": -80, "ships": 6, "prestige": 10}},
    "tur_barbarossa": {0: {"ships": 4, "mods": {"naval": 0.03}, "relations": {"SPA": -30, "FRA": 30}}},
    "ven_stato_da_mar": {0: {"gold": -60, "ships": 3, "mods": {"naval": 0.03}}},
    "dan_christian4": {1: {"ships": 3, "mods": {"naval": 0.03}, "gold": -50}},
    "eco_shipwrights": {0: {"mods": {"trade": 0.01}, "ships": 1, "estate": {"buerger": -3}}},
}

# mission id -> (require, reward)
MISSIONS = {
    "fra_levant_fleet": ({"tech": {"mil": 12}, "ships_min": 8}, {"mods": {"income": 0.05}, "mil": 40}),
    "eng_navy": ({"tech": {"mil": 10}, "ships_min": 8}, {"mods": {"naval": 0.05}, "gold": 100}),
    "eng_royal_navy": ({"tech": {"mil": 16}, "ships_min": 14}, {"mods": {"naval": 0.05}, "prestige": 15}),
    "spa_armada": ({"tech": {"mil": 14}, "ships_min": 14}, {"mods": {"naval": 0.05}, "prestige": 15}),
    "nap_galleys": ({"tech": {"mil": 10}, "ships_min": 6}, {"mods": {"naval": 0.05}, "prestige": 10}),
    "tur_fleet": ({"tech": {"mil": 10}, "ships_min": 10}, {"mods": {"naval": 0.05}, "prestige": 10}),
    "ven_arsenal": ({"tech": {"mil": 8}, "ships_min": 6}, {"mods": {"naval": 0.05}}),
    "dan_baltic": (None, {"mods": {"naval": 0.03}, "prestige": 10}),
}


def fix_events():
    txt = open(events_io.PATH, encoding="utf-8").read()
    data = json.loads(txt)
    by_id = {e["id"]: e for e in data}
    for eid, opts in EVENTS.items():
        e = by_id[eid]
        for i, eff in opts.items():
            e["options"][i]["effects"] = eff
    # rewrite only the touched chunks, keeping the one-entry-per-chunk layout
    chunks = [c for c in re.split(r',\n(?=  \{"id": ")', txt.strip()[1:-1].strip("\n")) if c.strip()]
    for k, c in enumerate(chunks):
        eid = re.match(r'  \{"id": "([^"]+)"', c).group(1)
        if eid in EVENTS:
            chunks[k] = events_io.render_event(by_id[eid])
    out = "[\n" + ",\n".join(chunks) + "\n]\n"
    assert json.loads(out) == data
    open(events_io.PATH, "w", encoding="utf-8").write(out)


def fix_missions():
    path = os.path.join(events_io.ROOT, "data/missions.json")
    txt = open(path, encoding="utf-8").read()
    ms = json.loads(txt)
    done = set()
    for tag, lst in ms.items():
        for m in lst:
            if m["id"] in MISSIONS:
                req, rew = MISSIONS[m["id"]]
                old = json.dumps({"require": m["require"], "reward": m["reward"]}, ensure_ascii=False)[1:-1]
                if req is not None:
                    m["require"] = req
                m["reward"] = rew
                new = json.dumps({"require": m["require"], "reward": m["reward"]}, ensure_ascii=False)[1:-1]
                assert txt.count(old) == 1, m["id"]
                txt = txt.replace(old, new)
                done.add(m["id"])
    assert done == set(MISSIONS), set(MISSIONS) - done
    assert json.loads(txt) == ms
    open(path, "w", encoding="utf-8").write(txt)


if __name__ == "__main__":
    fix_events()
    fix_missions()
    print("fixed %d events, %d missions" % (len(EVENTS), len(MISSIONS)))
