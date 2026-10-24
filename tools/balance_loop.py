#!/usr/bin/env python3
"""Headless auto-balancing loop.

Runs batches of all-AI 200-year games in parallel Godot processes, measures the
outcome and nudges balance values toward target ranges, then writes the result
to data/balance.json and a report to tools/balance_report.md.

Usage: python3 tools/balance_loop.py --godot /path/to/godot [--runs 16] [--iters 8] [--jobs 4]
"""
import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAJORS = ["FRA", "ENG", "SPA", "BOH", "HAB", "RUS", "NAP"]

# metric -> (low, high) acceptable range
TARGETS = {
    "eliminated": (15, 26),         # nations gone by 1644 (of 50; history: ~20)
    "top_share": (0.10, 0.22),      # largest nation's share of all development
    "major_survival": (0.8, 1.0),   # share of major nations alive at the end
    "coalition_wars": (0.3, 15.0),   # AE coalitions per game (AI self-limits AE)
    "timeout_share": (0.0, 0.12),   # wars ended by the hard timeout
    "bankrupt_months": (0, 1500),   # summed over all 50 nations x 2400 months
    "wars": (80, 220),              # keep the world lively
}


def run_batch(godot, balance, runs, jobs, seed):
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(balance, f)
        bpath = f.name
    per = max(1, runs // jobs)

    def one(i):
        cmd = [godot, "--headless", "--path", ROOT, "-s", "res://tools/sim.gd", "--",
               "--runs", str(per), "--years", "200", "--seed", str(seed + i * 1000), "--balance", bpath]
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3600).stdout
        return [json.loads(line[4:]) for line in out.splitlines() if line.startswith("RUN ")]

    with ThreadPoolExecutor(jobs) as ex:
        results = [r for batch in ex.map(one, range(jobs)) for r in batch]
    os.unlink(bpath)
    return results


def measure(results):
    def avg(f):
        return statistics.mean(f(r) for r in results)
    m = {
        "runs": len(results),
        "eliminated": avg(lambda r: r["stats"]["eliminated"]),
        "top_share": avg(lambda r: r["top_share"]),
        "max_top_share": max(r["top_share"] for r in results),
        "major_survival": avg(lambda r: sum(1 for t in MAJORS if r["majors"][t]["alive"]) / len(MAJORS)),
        "coalition_wars": avg(lambda r: r["stats"]["coalition_wars"]),
        "wars": avg(lambda r: r["stats"]["wars"]),
        "timeout_share": avg(lambda r: r["stats"]["timeouts"] / max(1, r["stats"]["wars"])),
        "bankrupt_months": avg(lambda r: r["stats"]["bankrupt_months"]),
        "events": avg(lambda r: r["stats"]["events"]),
        "missions": avg(lambda r: r["stats"]["missions"]),
        "battles": avg(lambda r: r["stats"]["battles"]),
        "major_dev": {t: round(avg(lambda r: r["majors"][t]["dev"]), 1) for t in MAJORS},
        "major_alive": {t: round(avg(lambda r: 1.0 if r["majors"][t]["alive"] else 0.0), 2) for t in MAJORS},
        "top_tags": {},
    }
    for r in results:
        m["top_tags"][r["top_tag"]] = m["top_tags"].get(r["top_tag"], 0) + 1
    return m


def adjust(b, m):
    """Rule-based nudges. Returns list of change descriptions."""
    ch = []

    def mul(k, f, lo, hi):
        old = b[k]
        b[k] = round(min(hi, max(lo, b[k] * f)), 4)
        if b[k] != old:
            ch.append(f"{k}: {old} -> {b[k]}")

    too_bloody = m["eliminated"] > TARGETS["eliminated"][1] or m["top_share"] > TARGETS["top_share"][1] \
        or m["major_survival"] < TARGETS["major_survival"][0]
    too_static = m["eliminated"] < TARGETS["eliminated"][0] or m["wars"] < TARGETS["wars"][0]
    if too_bloody:
        mul("ai_war_chance", 0.8, 0.03, 1.0)
        mul("ai_war_ratio", 1.08, 1.0, 3.0)
        mul("peace_cost_per_dev", 1.1, 0.5, 4.0)
        mul("ae_per_dev", 1.1, 0.3, 3.0)
    elif too_static:
        mul("ai_war_chance", 1.2, 0.03, 1.0)
        mul("ai_war_ratio", 0.95, 1.0, 3.0)
        mul("peace_cost_per_dev", 0.93, 0.5, 4.0)
    if m["coalition_wars"] < TARGETS["coalition_wars"][0]:
        mul("ae_coalition_threshold", 0.9, 20, 100)
    elif m["coalition_wars"] > TARGETS["coalition_wars"][1]:
        mul("ae_coalition_threshold", 1.1, 20, 100)
    if m["timeout_share"] > TARGETS["timeout_share"][1]:
        mul("siege_base", 1.15, 2, 40)
    if m["bankrupt_months"] > TARGETS["bankrupt_months"][1]:
        mul("regiment_maintenance", 0.92, 0.03, 0.5)
    return ch


def in_range(m):
    return all(TARGETS[k][0] <= m[k] <= TARGETS[k][1] for k in TARGETS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", required=True)
    ap.add_argument("--runs", type=int, default=16)
    ap.add_argument("--iters", type=int, default=8)
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--seed", type=int, default=1000)
    args = ap.parse_args()
    bpath = os.path.join(ROOT, "data", "balance.json")
    with open(bpath) as f:
        b = json.load(f)
    log = []
    for it in range(args.iters):
        m = measure(run_batch(args.godot, b, args.runs, args.jobs, args.seed + it * 7919))
        ok = in_range(m)
        changes = [] if ok else adjust(b, m)
        log.append({"iter": it, "metrics": m, "changes": changes, "ok": ok})
        print(json.dumps(log[-1]), flush=True)
        if ok:
            break
    with open(bpath, "w") as f:
        json.dump(b, f, indent=2)
        f.write("\n")
    with open(os.path.join(ROOT, "tools", "balance_report.md"), "w") as f:
        f.write("# Headless balance report\n\nGenerated by `tools/balance_loop.py` (all-AI games, 200 years each).\n\n")
        f.write("Targets: " + ", ".join(f"{k} {lo}–{hi}" for k, (lo, hi) in TARGETS.items()) + "\n\n")
        for e in log:
            mm = e["metrics"]
            f.write(f"## Iteration {e['iter']} ({mm['runs']} runs) {'✅ in range' if e['ok'] else ''}\n\n")
            for k in ["eliminated", "top_share", "max_top_share", "major_survival", "coalition_wars", "wars",
                      "timeout_share", "bankrupt_months", "battles", "events", "missions"]:
                f.write(f"- {k}: {round(mm[k], 3)}\n")
            f.write(f"- major_dev: {mm['major_dev']}\n- major_alive: {mm['major_alive']}\n- top_tags: {mm['top_tags']}\n")
            if e["changes"]:
                f.write("- changes: " + "; ".join(e["changes"]) + "\n")
            f.write("\n")
    sys.exit(0 if log[-1]["ok"] else 2)


if __name__ == "__main__":
    main()
