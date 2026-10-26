"""Writes data/coastal.json: keys of provinces that touch the sea (outline not covered by other land).
Run after tools/gen_map.py. Uses shapely."""
import json
from shapely.geometry import Polygon, box
from shapely.ops import unary_union

m = json.load(open('data/map.json'))
land = [Polygon(r) for r in m['background'] if len(r) >= 3]
shapes = {}
for p in m['provinces']:
    polys = [Polygon(r).buffer(0) for r in p['polys'] if len(r) >= 3]
    shapes[p['key']] = unary_union(polys)
W, H = m['size']
inner = box(4, 4, W - 4, H - 4)  # the map border is not sea
coastal = []
for p in m['provinces']:
    me = shapes[p['key']]
    others = unary_union([s for k, s in shapes.items() if k != p['key']] + land).buffer(2.0)
    rest = me.boundary.difference(others).intersection(inner)
    if rest.length > 12.0:
        coastal.append(p['key'])
json.dump(sorted(coastal), open('data/coastal.json', 'w'), indent=0)
print(len(coastal), 'of', len(m['provinces']), 'coastal')
