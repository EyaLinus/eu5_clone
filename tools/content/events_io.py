"""Shared helper for content generators that own a block of generic events in data/events.json.

Each generator owns one id prefix ("eco_", "rel_", ...). replace_block() drops all events with that prefix and
inserts the new ones right before the "gov_" block (gov_events.py keeps that block at the tail of the file),
keeping the one-entry-per-chunk layout of the file.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PATH = os.path.join(ROOT, "data/events.json")


def render_event(e):
    head = {k: e[k] for k in ("id", "once", "tag", "title", "text", "image") if k in e}
    s = "  " + json.dumps(head, ensure_ascii=False)[:-1] + ",\n"
    s += '   "trigger": ' + json.dumps(e["trigger"], ensure_ascii=False) + ",\n"
    s += '   "options": [\n'
    s += ",\n".join("     " + json.dumps(o, ensure_ascii=False) for o in e["options"])
    return s + "]}"


def replace_block(prefix, events):
    txt = open(PATH, encoding="utf-8").read().strip()
    assert txt.startswith("[") and txt.endswith("]")
    chunks = [c for c in re.split(r',\n(?=  \{"id": ")', txt[1:-1].strip("\n")) if c.strip()]
    chunks = [c for c in chunks if not c.startswith('  {"id": "%s' % prefix)]
    gov = next((i for i, c in enumerate(chunks) if c.startswith('  {"id": "gov_')), len(chunks))
    chunks[gov:gov] = [render_event(e) for e in events]
    out = "[\n" + ",\n".join(chunks) + "\n]\n"
    data = json.loads(out)
    assert len({e["id"] for e in data}) == len(data)
    open(PATH, "w", encoding="utf-8").write(out)
    return data
