"""Event and mission audit: static checks over data/events.json and data/missions.json, plus (optionally)
how often each event fired in headless games (outputs of tools/event_audit.gd).

  python3 tools/event_audit.py                     # static checks only
  python3 tools/event_audit.py runs/*.txt          # plus "never fired" lists from AUDIT lines

Static checks: condition and effect keys the game code does not handle (silently ignored there), unknown
mod keys, tags, provinces, buildings, monuments and images, impossible year windows, duplicate titles and
texts, formal address ("Sie"/"Ihr") in a game written with "du", and missing final punctuation.
Exit code 1 if a static check fails.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
END_YEAR = 1644


def _load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def _keys_in(func, path="scripts/core/game.gd"):
    """String keys of the big match block in Game.<func> (the handled condition or effect keys)."""
    src = open(os.path.join(ROOT, path), encoding="utf-8").read()
    body = src.split("func %s(" % func, 1)[1].split("\nfunc ", 1)[0]
    keys = set()
    for line in body.splitlines():
        m = re.match(r'^\t\t\t("[a-z_]+"(?:, *"[a-z_]+")*):', line)
        if m:
            keys.update(re.findall(r'"([a-z_]+)"', m.group(1)))
    return keys


def _mod_keys():
    src = open(os.path.join(ROOT, "scripts/core/tech.gd"), encoding="utf-8").read()
    block = src.split("const LABELS", 1)[1].split("\n}", 1)[0]
    return set(re.findall(r'"([a-z_]+)": \[', block))


def static_checks():
    events = _load("events.json")
    missions = _load("missions.json")
    tags = set(_load("nations.json"))
    provs = {p["key"] for p in _load("map.json")["provinces"]}
    blds = set(_load("buildings.json"))
    mons = set(_load("monuments.json"))
    images = {f[:-4] for f in os.listdir(os.path.join(ROOT, "assets/art/events")) if f.endswith(".png")}
    cond_keys, eff_keys, mod_keys = _keys_in("check_conditions"), _keys_in("apply_effects"), _mod_keys()
    errs, warns = [], []

    def check_cond(where, c):
        for k, v in c.items():
            if k not in cond_keys:
                errs.append("%s: unknown condition %r" % (where, k))
            if k in ("owns", "owns_any", "not_owns"):
                for p in (v if isinstance(v, list) else [v]):
                    if p not in provs:
                        errs.append("%s: unknown province %r" % (where, p))
            if k in ("alive", "not_alive", "allied", "emperor") and isinstance(v, str) and v not in tags:
                errs.append("%s: unknown tag %r" % (where, v))
            if k in ("building", "no_building") and isinstance(v, str) and v not in blds:
                errs.append("%s: unknown building %r" % (where, v))
            if k in ("monument", "monument_building") and isinstance(v, str) and v not in mons:
                errs.append("%s: unknown monument %r" % (where, v))
        if c.get("year_min", 0) > min(c.get("year_max", END_YEAR), END_YEAR):
            errs.append("%s: year window can never open" % where)

    def check_eff(where, eff):
        for k, v in eff.items():
            if k not in eff_keys:
                errs.append("%s: unknown effect %r" % (where, k))
            if k == "mods":
                for mk in v:
                    if mk not in mod_keys:
                        errs.append("%s: unknown mod %r" % (where, mk))
            if k == "relations":
                for t in v:
                    if t not in tags:
                        errs.append("%s: unknown tag %r" % (where, t))
            if k in ("war", "alliance", "inherit", "vassal") and isinstance(v, str) and v not in tags:
                errs.append("%s: unknown tag %r" % (where, v))
            if k in ("claim", "province"):
                for p in (v if isinstance(v, list) else [v]):
                    if isinstance(p, str) and p not in provs:
                        errs.append("%s: unknown province %r" % (where, p))

    def check_text(where, s):
        if re.search(r"(?<![.!?:] )(?<!^)\b(Sie|Ihnen|Ihr|Euch|Euer|Eure|Eurer|Euren)\b", s):
            warns.append("%s: formal address? %r" % (where, s[:70]))
        if "  " in s or s != s.strip():
            warns.append("%s: stray whitespace" % where)
        if re.search(r"\b(\w{3,}) \1\b", s):
            warns.append("%s: doubled word %r" % (where, re.search(r"\b(\w{3,}) \1\b", s).group(0)))

    seen_title, seen_text = {}, {}
    for e in events:
        eid = e["id"]
        if e.get("tag", "*") != "*" and e["tag"] not in tags:
            errs.append("%s: unknown tag %r" % (eid, e["tag"]))
        if e.get("image") and e["image"] not in images:
            errs.append("%s: missing image %r" % (eid, e["image"]))
        check_cond(eid, e.get("trigger", {}))
        if len(e["options"]) < 2:
            warns.append("%s: only %d option(s)" % (eid, len(e["options"])))
        for i, o in enumerate(e["options"]):
            check_eff("%s/%d" % (eid, i), o.get("effects", {}))
            check_text("%s/%d" % (eid, i), o["text"])
        check_text(eid, e["title"])
        check_text(eid, e["text"])
        if not re.search(r'[.!?…"“”»«)]$', e["text"]):
            warns.append("%s: text without final punctuation" % eid)
        # the same title for two realms that can both see it (same tag, or one of them is "*")
        tag = e.get("tag", "*")
        for d, key in ((seen_title, e["title"].strip().lower()), (seen_text, e["text"].strip().lower())):
            for other, otag in d.get(key, []):
                if "*" in (tag, otag) or tag == otag:
                    warns.append("%s: same %s as %s" % (eid, "title" if d is seen_title else "text", other))
            d.setdefault(key, []).append((eid, tag))
    for tag, lst in missions.items():
        if tag not in tags:
            errs.append("missions: unknown tag %r" % tag)
        for m in lst:
            check_cond(m["id"], m.get("require", {}))
            check_eff(m["id"], m.get("reward", {}))
    return events, missions, errs, warns


def merge_runs(paths):
    runs, ev, ms = 0, {}, {}
    for p in paths:
        for line in open(p, encoding="utf-8", errors="replace"):
            if line.startswith("AUDIT "):
                d = json.loads(line[6:])
                runs += d["runs"]
                for k, v in d["events"].items():
                    ev[k] = ev.get(k, 0) + v
                for k, v in d["missions"].items():
                    ms[k] = ms.get(k, 0) + v
    return runs, ev, ms


def main():
    events, missions, errs, warns = static_checks()
    for s in errs:
        print("ERROR", s)
    for s in warns:
        print("WARN ", s)
    paths = [p for a in sys.argv[1:] for p in glob.glob(a)]
    if paths:
        runs, ev, ms = merge_runs(paths)
        print("\n%d runs" % runs)
        player_only = [e["id"] for e in events if e.get("trigger", {}).get("is_player") and e["id"] not in ev]
        never = [e["id"] for e in events if e["id"] not in ev and e["id"] not in player_only]
        print("events never fired: %d of %d (%d player-only events not counted)" % (len(never), len(events), len(player_only)))
        for eid in never:
            print("  never", eid)
        mids = [m["id"] for lst in missions.values() for m in lst]
        mnever = [m for m in mids if m not in ms]
        print("missions never done: %d of %d" % (len(mnever), len(mids)))
        for mid in mnever:
            print("  never", mid)
    print("\n%d errors, %d warnings" % (len(errs), len(warns)))
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
