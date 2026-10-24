#!/usr/bin/env python3
"""Asset registry (assets/manifest.yaml by default).

Commands
  add NAME [--kind K] [--source S] [--outputs ...] [--status S] [--note N]   create or update
  list [--kind K] [--status S] [--paths]                                    overview / source paths
  find TERM                                                                  search names, kinds, notes
  status NAME STATUS                                                         change status
  missing                                                                    entries whose files don't exist

Statuses: planned | wip | done | needs_rework
"""
from __future__ import annotations

import argparse
import datetime as dt
import glob
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from _common import die  # noqa: E402

STATUSES = ["planned", "wip", "done", "needs_rework"]


def load(path):
    import yaml
    p = Path(path)
    if not p.exists():
        return {"assets": {}}
    data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    data.setdefault("assets", {})
    return data


def save(path, data):
    import yaml
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(yaml.safe_dump(data, sort_keys=True, allow_unicode=True), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default="assets/manifest.yaml")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("add")
    s.add_argument("name")
    s.add_argument("--kind")
    s.add_argument("--source")
    s.add_argument("--outputs", nargs="*")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--note")
    s.add_argument("--method")
    s = sub.add_parser("list")
    s.add_argument("--kind")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--paths", action="store_true")
    s = sub.add_parser("find")
    s.add_argument("term")
    s = sub.add_parser("status")
    s.add_argument("name")
    s.add_argument("status", choices=STATUSES)
    sub.add_parser("missing")
    a = ap.parse_args()

    data = load(a.manifest)
    assets = data["assets"]
    today = dt.date.today().isoformat()

    if a.cmd == "add":
        e = assets.get(a.name, {"created": today})
        for field in ("kind", "source", "status", "note", "method"):
            v = getattr(a, field)
            if v is not None:
                e[field] = v
        if a.outputs is not None:
            outs = []
            for o in a.outputs:
                outs += sorted(glob.glob(o)) or [o]
            e["outputs"] = outs
        e.setdefault("status", "wip")
        e["updated"] = today
        assets[a.name] = e
        save(a.manifest, data)
        print(f"{'updated' if 'created' in e and e['created'] != today else 'saved'} {a.name}")
    elif a.cmd == "list":
        for n, e in sorted(assets.items()):
            if a.kind and e.get("kind") != a.kind:
                continue
            if a.status and e.get("status") != a.status:
                continue
            if a.paths:
                if e.get("source"):
                    print(e["source"])
            else:
                print(f"{n:30} {e.get('kind', '-'):12} {e.get('status', '-'):13} {e.get('note', '')}")
    elif a.cmd == "find":
        t = a.term.lower()
        for n, e in sorted(assets.items()):
            hay = " ".join([n, str(e.get("kind", "")), str(e.get("note", "")), str(e.get("source", ""))]).lower()
            if t in hay:
                print(f"{n:30} {e.get('kind', '-'):12} {e.get('status', '-'):13} {e.get('source', '')}")
    elif a.cmd == "status":
        if a.name not in assets:
            die(f"unknown asset {a.name}")
        assets[a.name]["status"] = a.status
        assets[a.name]["updated"] = today
        save(a.manifest, data)
        print(f"{a.name}: {a.status}")
    elif a.cmd == "missing":
        bad = 0
        for n, e in sorted(assets.items()):
            for f in ([e["source"]] if e.get("source") else []) + list(e.get("outputs", [])):
                if not Path(f).exists():
                    print(f"{n}: missing {f}")
                    bad += 1
        sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
