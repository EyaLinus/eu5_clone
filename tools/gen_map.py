#!/usr/bin/env python3
"""Generates data/map.json: province polygons (Voronoi cells clipped to land),
adjacency and 1444 start ownership.

Usage: python3 tools/gen_map.py path/to/ne_50m_land.geojson
Land data: Natural Earth 1:50m land (public domain).
"""
import json
import math
import sys

from shapely import voronoi_polygons
from shapely.geometry import MultiPoint, Point, box, shape
from shapely.ops import unary_union

# (key, name, lon, lat, owner, dev[, max radius in degrees for desert provinces])
PROVINCES = [
    # England
    ("london", "London", -0.1, 51.5, "ENG", 13),
    ("wessex", "Wessex", -2.6, 51.0, "ENG", 7),
    ("eastanglia", "East Anglia", 1.0, 52.6, "ENG", 8),
    ("midlands", "Midlands", -1.6, 52.6, "ENG", 7),
    ("york", "York", -1.1, 54.0, "ENG", 8),
    ("northumberland", "Northumberland", -2.0, 55.1, "ENG", 5),
    ("wales", "Wales", -3.8, 52.3, "ENG", 5),
    ("cornwall", "Cornwall", -4.8, 50.4, "ENG", 4),
    ("pale", "Dublin", -6.3, 53.4, "ENG", 5),
    ("calais", "Calais", 1.9, 50.9, "ENG", 6),
    ("normandy", "Normandie", 0.0, 49.2, "ENG", 9),
    ("bordeaux", "Guyenne", -0.6, 44.8, "ENG", 8),
    # Scotland / Ireland
    ("lothian", "Lothian", -3.2, 55.9, "SCO", 6),
    ("highlands", "Highlands", -4.5, 57.3, "SCO", 4),
    ("munster", "Munster", -8.5, 52.2, "IRE", 4),
    ("ulster", "Ulster", -6.8, 54.6, "IRE", 3),
    # France
    ("paris", "Paris", 2.35, 48.85, "FRA", 15),
    ("orleans", "Orléans", 1.9, 47.9, "FRA", 8),
    ("champagne", "Champagne", 4.0, 49.0, "FRA", 8),
    ("picardy", "Picardie", 2.3, 49.9, "FRA", 7),
    ("berry", "Berry", 2.4, 47.0, "FRA", 7),
    ("lyon", "Lyon", 4.8, 45.75, "FRA", 8),
    ("auvergne", "Auvergne", 3.1, 45.4, "FRA", 5),
    ("toulouse", "Toulouse", 1.4, 43.6, "FRA", 8),
    ("languedoc", "Languedoc", 3.9, 43.6, "FRA", 7),
    ("poitou", "Poitou", 0.0, 46.4, "FRA", 6),
    ("anjou", "Anjou", 0.2, 47.5, "FRA", 7),
    ("limousin", "Limousin", 1.3, 45.6, "FRA", 5),
    ("dauphine", "Dauphiné", 5.7, 45.0, "FRA", 6),
    # Brittany / Burgundy / Provence / Savoy
    ("rennes", "Rennes", -1.7, 48.1, "BRI", 6),
    ("brest", "Finistère", -4.0, 48.3, "BRI", 4),
    ("dijon", "Dijon", 4.9, 47.3, "BUR", 9),
    ("flanders", "Flandern", 3.2, 51.0, "BUR", 14),
    ("brabant", "Brabant", 4.6, 50.8, "BUR", 11),
    ("holland", "Holland", 4.9, 52.3, "BUR", 10),
    ("franchecomte", "Franche-Comté", 6.0, 47.0, "BUR", 6),
    ("luxembourg", "Luxemburg", 6.0, 49.7, "BUR", 5),
    ("provence", "Provence", 5.9, 43.6, "PRV", 7),
    ("savoy", "Savoyen", 6.5, 45.7, "SAV", 6),
    ("piedmont", "Piemont", 7.7, 44.9, "SAV", 7),
    # Iberia
    ("burgos", "Burgos", -3.7, 42.3, "SPA", 8),
    ("toledo", "Toledo", -4.0, 39.8, "SPA", 10),
    ("leon", "León", -5.6, 42.0, "SPA", 6),
    ("galicia", "Galicien", -8.0, 42.8, "SPA", 6),
    ("sevilla", "Sevilla", -6.0, 37.5, "SPA", 10),
    ("murcia", "Murcia", -1.3, 38.1, "SPA", 6),
    ("extremadura", "Extremadura", -6.2, 39.2, "SPA", 5),
    ("biscay", "Biskaya", -3.0, 43.2, "SPA", 6),
    ("zaragoza", "Saragossa", -0.9, 41.6, "ARA", 8),
    ("barcelona", "Barcelona", 1.8, 41.7, "ARA", 11),
    ("valencia", "Valencia", -0.6, 39.4, "ARA", 9),
    ("sardinia", "Sardinien", 9.0, 40.0, "ARA", 4),
    ("sicily", "Sizilien", 14.0, 37.6, "ARA", 8),
    ("pamplona", "Navarra", -1.6, 42.8, "NAV", 5),
    ("lisbon", "Lissabon", -8.8, 39.0, "POR", 10),
    ("porto", "Porto", -8.2, 41.3, "POR", 7),
    ("algarve", "Algarve", -8.0, 37.3, "POR", 4),
    ("granada", "Granada", -3.4, 37.3, "GRA", 9),
    ("malaga", "Málaga", -4.8, 36.8, "GRA", 6),
    # Italy
    ("napoli", "Neapel", 14.6, 40.9, "NAP", 14),
    ("apulia", "Apulien", 16.6, 41.0, "NAP", 8),
    ("calabria", "Kalabrien", 16.3, 39.1, "NAP", 6),
    ("abruzzo", "Abruzzen", 13.9, 42.2, "NAP", 6),
    ("rome", "Rom", 12.5, 42.0, "PAP", 11),
    ("bologna", "Bologna", 11.6, 44.4, "PAP", 8),
    ("ancona", "Ancona", 13.0, 43.4, "PAP", 6),
    ("florence", "Florenz", 11.25, 43.75, "TUS", 11),
    ("siena", "Siena", 11.2, 43.0, "TUS", 6),
    ("milan", "Mailand", 9.2, 45.5, "MLO", 13),
    ("parma", "Parma", 10.3, 44.9, "MLO", 6),
    ("genoa", "Genua", 8.9, 44.4, "GEN", 9),
    ("corsica", "Korsika", 9.1, 42.1, "GEN", 3),
    ("venice", "Venedig", 12.3, 45.5, "VEN", 13),
    ("verona", "Verona", 11.0, 45.5, "VEN", 8),
    ("friuli", "Friaul", 13.2, 46.1, "VEN", 5),
    ("dalmatia", "Dalmatien", 16.2, 43.7, "VEN", 5),
    # Austria / Bohemia / HRE
    ("wien", "Wien", 16.4, 48.2, "HAB", 12),
    ("linz", "Oberösterreich", 14.0, 48.1, "HAB", 7),
    ("steiermark", "Steiermark", 15.4, 47.2, "HAB", 7),
    ("carniola", "Krain", 14.5, 46.2, "HAB", 5),
    ("tirol", "Tirol", 11.4, 47.1, "HAB", 6),
    ("prague", "Prag", 14.6, 50.0, "BOH", 12),
    ("pilsen", "Pilsen", 13.2, 49.6, "BOH", 7),
    ("moravia", "Mähren", 16.8, 49.3, "BOH", 9),
    ("silesia", "Schlesien", 17.0, 51.0, "BOH", 10),
    ("lusatia", "Lausitz", 14.6, 51.3, "BOH", 5),
    ("munich", "München", 11.5, 48.0, "BAV", 9),
    ("regensburg", "Regensburg", 12.2, 49.0, "BAV", 7),
    ("dresden", "Dresden", 13.4, 50.9, "SAX", 8),
    ("leipzig", "Leipzig", 12.2, 51.5, "SAX", 8),
    ("berlin", "Brandenburg", 13.3, 52.5, "BRA", 7),
    ("cologne", "Köln", 7.0, 50.9, "KOL", 9),
    ("palatinate", "Pfalz", 8.4, 49.5, "PAL", 8),
    ("swabia", "Schwaben", 9.4, 48.6, "WUR", 8),
    ("nuremberg", "Nürnberg", 10.7, 49.6, "NUR", 8),
    ("hesse", "Hessen", 9.2, 50.7, "HES", 6),
    ("brunswick", "Braunschweig", 10.2, 52.3, "LUN", 7),
    ("bremen", "Bremen", 8.6, 53.1, "LUN", 6),
    ("hamburg", "Hamburg", 10.4, 53.5, "HSA", 8),
    ("pomerania", "Pommern", 14.6, 53.6, "POM", 6),
    ("mecklenburg", "Mecklenburg", 12.0, 53.7, "POM", 5),
    ("bern", "Bern", 7.4, 46.8, "SWI", 7),
    ("zurich", "Zürich", 8.7, 47.4, "SWI", 7),
    # East
    ("prussia", "Preußen", 20.6, 54.5, "TEU", 8),
    ("marienburg", "Marienburg", 18.6, 53.9, "TEU", 7),
    ("krakow", "Krakau", 20.0, 50.1, "POL", 11),
    ("poznan", "Großpolen", 17.0, 52.4, "POL", 9),
    ("warsaw", "Masowien", 21.2, 52.3, "POL", 8),
    ("lwow", "Rotruthenien", 24.0, 49.7, "POL", 7),
    ("vilnius", "Wilna", 25.3, 54.8, "LIT", 9),
    ("minsk", "Minsk", 27.6, 53.8, "LIT", 6),
    ("kiev", "Kiew", 30.5, 50.4, "LIT", 8),
    ("smolensk", "Smolensk", 32.0, 54.7, "LIT", 7),
    ("volhynia", "Wolhynien", 25.5, 51.0, "LIT", 5),
    ("chernigov", "Tschernigow", 31.5, 51.9, "LIT", 5),
    ("buda", "Buda", 19.1, 47.4, "HUN", 12),
    ("kassa", "Oberungarn", 21.3, 48.6, "HUN", 7),
    ("transylvania", "Siebenbürgen", 23.8, 46.6, "HUN", 8),
    ("croatia", "Kroatien", 15.8, 45.6, "HUN", 6),
    ("pressburg", "Pressburg", 17.6, 48.3, "HUN", 7),
    ("temes", "Temesvar", 21.2, 45.8, "HUN", 6),
    ("slavonia", "Slawonien", 18.3, 45.6, "HUN", 5),
    # Russia
    ("moscow", "Moskau", 37.6, 55.75, "RUS", 12),
    ("tver", "Twer", 35.3, 56.9, "RUS", 7),
    ("yaroslavl", "Jaroslawl", 39.6, 57.8, "RUS", 6),
    ("vladimir", "Wladimir", 41.0, 56.2, "RUS", 6),
    ("nizhny", "Nischni Nowgorod", 44.0, 56.3, "RUS", 6),
    ("tula", "Tula", 37.4, 54.0, "RUS", 6),
    ("vologda", "Wologda", 40.2, 59.4, "RUS", 4),
    ("ryazan", "Rjasan", 40.5, 54.4, "RYA", 6),
    ("novgorod", "Nowgorod", 31.6, 58.5, "NOV", 9),
    ("pskov", "Pskow", 28.6, 57.6, "NOV", 6),
    ("karelia", "Karelien", 33.0, 61.6, "NOV", 3),
    ("beloozero", "Beloosero", 37.0, 60.0, "NOV", 3),
    ("kazan", "Kasan", 49.1, 55.8, "KAZ", 7),
    ("crimea", "Krim", 34.2, 45.1, "CRI", 6),
    ("zaporozhia", "Wildes Feld", 35.5, 47.5, "CRI", 3),
    ("riga", "Riga", 24.6, 56.9, "LIV", 7),
    ("reval", "Reval", 25.3, 58.9, "LIV", 5),
    # Scandinavia (Kalmar Union)
    ("copenhagen", "Kopenhagen", 12.0, 55.5, "DAN", 10),
    ("jutland", "Jütland", 9.2, 56.2, "DAN", 7),
    ("holstein", "Holstein", 9.8, 54.3, "DAN", 6),
    ("scania", "Schonen", 13.6, 56.0, "DAN", 6),
    ("oslo", "Oslo", 10.5, 60.0, "DAN", 5),
    ("bergen", "Bergen", 6.2, 60.6, "DAN", 4),
    ("stockholm", "Stockholm", 17.6, 59.6, "DAN", 8),
    ("gotaland", "Götaland", 14.0, 57.8, "DAN", 6),
    ("turku", "Finnland", 23.5, 61.0, "DAN", 4),
    ("dalarna", "Dalarna", 15.0, 61.0, "DAN", 3),
    # Balkans
    ("edirne", "Edirne", 26.6, 41.8, "TUR", 10),
    ("sofia", "Sofia", 23.6, 42.7, "TUR", 7),
    ("skopje", "Makedonien", 21.8, 41.4, "TUR", 6),
    ("thessaly", "Thessalien", 22.4, 39.6, "TUR", 5),
    ("varna", "Varna", 27.5, 43.2, "TUR", 5),
    ("constantinople", "Konstantinopel", 28.9, 41.1, "BYZ", 14),
    ("morea", "Morea", 22.2, 37.6, "BYZ", 5),
    ("serbia", "Serbien", 20.7, 44.0, "SER", 6),
    ("bosnia", "Bosnien", 18.0, 44.1, "BOS", 5),
    ("wallachia", "Walachei", 25.6, 44.6, "WAL", 7),
    ("moldavia", "Moldau", 27.2, 47.0, "MOL", 6),
    ("albania", "Albanien", 20.0, 41.1, "ALB", 4),
    # --- the south and east (added after the first 161 provinces so their ids stay stable) ---
    # Anatolia
    ("bursa", "Bursa", 29.06, 40.18, "TUR", 10),
    ("izmit", "Kocaeli", 30.1, 40.75, "TUR", 6),
    ("saruhan", "Saruhan", 27.6, 38.75, "TUR", 6),
    ("aydin", "Aydın", 28.0, 37.85, "TUR", 7),
    ("mentese", "Menteşe", 28.6, 37.05, "TUR", 4),
    ("germiyan", "Germiyan", 30.0, 39.4, "TUR", 5),
    ("hamid", "Hamid", 30.7, 37.9, "TUR", 4),
    ("teke", "Teke", 30.7, 36.95, "TUR", 5),
    ("ankara", "Ankara", 32.85, 39.93, "TUR", 7),
    ("amasya", "Amasya", 35.83, 40.65, "TUR", 6),
    ("sivas", "Sivas", 37.0, 39.75, "TUR", 5),
    ("kastamonu", "Kastamonu", 33.78, 41.38, "CND", 5),
    ("sinop", "Sinope", 35.15, 42.0, "CND", 4),
    ("konya", "Konya", 32.48, 37.87, "KAR", 8),
    ("larende", "Larende", 33.3, 37.0, "KAR", 4),
    ("aksaray", "Aksaray", 34.0, 38.4, "KAR", 4),
    ("kayseri", "Kayseri", 35.48, 38.73, "KAR", 6),
    ("icel", "İçel", 33.9, 36.4, "KAR", 3),
    ("marash", "Maraş", 36.93, 37.58, "DUL", 5),
    ("adana", "Adana", 35.32, 37.0, "MAM", 6),
    ("malatya", "Malatya", 38.3, 38.35, "MAM", 5),
    ("trebizond", "Trapezunt", 39.72, 41.0, "TRE", 7),
    ("diyarbakir", "Diyarbakır", 40.22, 37.91, "AKK", 7),
    ("urfa", "Urfa", 38.8, 37.15, "AKK", 4),
    ("erzincan", "Erzincan", 39.5, 39.75, "AKK", 4),
    ("erzurum", "Erzurum", 41.27, 39.9, "QAR", 4),
    ("van", "Van", 43.38, 38.5, "QAR", 5),
    ("mosul", "Mossul", 43.13, 36.34, "QAR", 6, 2.2),
    ("yerevan", "Eriwan", 44.5, 40.18, "QAR", 5),
    ("tabriz", "Täbris", 46.3, 38.08, "QAR", 10, 2.2),
    # Caucasus
    ("tbilisi", "Tiflis", 44.8, 41.7, "GEO", 8),
    ("imereti", "Imeretien", 42.7, 42.27, "GEO", 5),
    ("kakheti", "Kachetien", 46.0, 41.95, "GEO", 4),
    ("abkhazia", "Abchasien", 41.0, 43.0, "GEO", 3),
    ("shamakhi", "Schemacha", 48.64, 40.63, "SHI", 7),
    ("derbent", "Derbent", 48.29, 42.06, "SHI", 5),
    ("circassia", "Tscherkessien", 39.5, 44.6, "CIR", 4),
    ("kabarda", "Kabarda", 43.6, 43.5, "CIR", 3),
    # Levant, Egypt, Cyrenaica (Mamluks)
    ("aleppo", "Aleppo", 37.16, 36.2, "MAM", 9),
    ("tripoli_sy", "Tripolis (Syrien)", 35.85, 34.43, "MAM", 6),
    ("damascus", "Damaskus", 36.3, 33.5, "MAM", 10, 2.2),
    ("jerusalem", "Jerusalem", 35.2, 31.78, "MAM", 7, 2.2),
    ("cairo", "Kairo", 31.24, 30.04, "MAM", 16, 2.2),
    ("alexandria", "Alexandria", 29.92, 31.2, "MAM", 10),
    ("damietta", "Damiette", 31.8, 31.42, "MAM", 6),
    ("upper_egypt", "Oberägypten", 30.8, 28.3, "MAM", 5, 2.2),
    ("marmarica", "Marmarika", 25.0, 31.6, "MAM", 2, 2.2),
    ("barqa", "Barka", 20.07, 32.1, "MAM", 3, 2.2),
    # Maghreb
    ("sirte", "Syrte", 16.6, 31.2, "TUN", 2, 2.2),
    ("tripoli", "Tripolis", 13.18, 32.9, "TUN", 6, 2.2),
    ("gabes", "Gabès", 10.1, 33.9, "TUN", 3, 2.2),
    ("kairouan", "Kairouan", 10.1, 35.68, "TUN", 6, 2.2),
    ("tunis", "Tunis", 10.18, 36.8, "TUN", 12),
    ("constantine", "Konstantine", 6.61, 36.36, "TUN", 6),
    ("bejaia", "Bejaia", 5.08, 36.75, "TUN", 5),
    ("algiers", "Algier", 3.06, 36.75, "TLE", 6),
    ("oran", "Oran", -0.63, 35.7, "TLE", 5),
    ("tlemcen", "Tlemcen", -1.32, 34.88, "TLE", 8, 2.2),
    ("rif", "Rif", -3.9, 35.1, "MOR", 3),
    ("tangier", "Tanger", -5.8, 35.77, "MOR", 5),
    ("fez", "Fès", -5.0, 34.03, "MOR", 12),
    ("rabat", "Salé", -6.84, 34.02, "MOR", 5),
    ("marrakesh", "Marrakesch", -8.0, 31.63, "MOR", 9, 2.2),
    ("sous", "Sous", -9.4, 30.2, "MOR", 3, 2.2),
    # Eastern Mediterranean islands
    ("crete", "Kreta", 24.9, 35.25, "VEN", 6),
    ("cyprus", "Zypern", 33.36, 35.1, "CYP", 6),
    ("rhodes", "Rhodos", 28.0, 36.2, "KNI", 4),
]

# Extra sea/strait connections (province keys)
STRAITS = [
    ("london", "calais"), ("wessex", "normandy"), ("pale", "wales"),
    ("ulster", "lothian"), ("corsica", "genoa"), ("corsica", "sardinia"),
    ("sicily", "calabria"), ("copenhagen", "scania"), ("copenhagen", "jutland"),
    ("stockholm", "turku"), ("turku", "reval"), ("constantinople", "edirne"),
    ("cornwall", "brest"), ("sardinia", "barcelona"), ("sicily", "napoli"),
    ("crimea", "zaporozhia"), ("dalmatia", "ancona"), ("morea", "thessaly"),
    ("constantinople", "izmit"), ("edirne", "bursa"), ("crimea", "circassia"), ("sevilla", "tangier"),
    ("granada", "tangier"), ("sicily", "tunis"), ("sardinia", "tunis"), ("crete", "morea"),
    ("crete", "rhodes"), ("rhodes", "mentese"), ("cyprus", "icel"), ("cyprus", "tripoli_sy"),
]

SCALE = 48.0  # pixels per degree latitude
LON0, LAT0 = -11.0, 63.0
COSLAT = math.cos(math.radians(50))
MIN_LAT = 27.0


def proj(lon, lat):
    return ((lon - LON0) * SCALE * COSLAT, (LAT0 - lat) * SCALE)


def project_geom(g):
    import shapely
    return shapely.transform(g, lambda c: [proj(x, y) for x, y in c])


def main(land_path):
    with open(land_path) as f:
        gj = json.load(f)
    window = box(-12.0, MIN_LAT, 52.0, 66.0)
    land_parts = []
    for feat in gj["features"]:
        g = shape(feat["geometry"])
        if g.intersects(window):
            land_parts.append(g.intersection(window))
    land_ll = unary_union(land_parts)
    full_land = project_geom(land_ll).buffer(0)
    land = project_geom(land_ll).buffer(0)

    pts = [proj(p[2], p[3]) for p in PROVINCES]
    vor = voronoi_polygons(MultiPoint(pts), extend_to=box(-500, -500, 4000, 3000))
    cells_by_idx = {}
    for cell in vor.geoms:
        for i, pt in enumerate(pts):
            if cell.contains(Point(pt)):
                cells_by_idx[i] = cell
                break

    max_r = 3.2 * SCALE
    provinces = []
    shapes = []
    for i, p in enumerate(PROVINCES):
        cell = cells_by_idx[i]
        disc = Point(pts[i]).buffer(p[6] * SCALE if len(p) > 6 else max_r, 24)
        g = cell.intersection(disc).intersection(land)
        g = g.simplify(1.2, preserve_topology=True)
        if g.geom_type == "MultiPolygon":
            polys = [q for q in g.geoms if q.area > 25.0]
        elif g.geom_type == "Polygon":
            polys = [g]
        else:
            polys = [q for q in getattr(g, "geoms", []) if q.geom_type == "Polygon" and q.area > 25.0]
        if not polys:
            raise SystemExit("empty province " + p[0])
        shapes.append(unary_union(polys))
        provinces.append({
            "id": i,
            "key": p[0],
            "name": p[1],
            "owner": p[4],
            "dev": p[5],
            "center": [round(pts[i][0], 1), round(pts[i][1], 1)],
            "polys": [[[round(x, 1), round(y, 1)] for x, y in list(q.exterior.coords)[:-1]] for q in polys],
        })

    key_to_id = {p[0]: i for i, p in enumerate(PROVINCES)}
    adj = [set() for _ in PROVINCES]
    for i in range(len(shapes)):
        for j in range(i + 1, len(shapes)):
            if shapes[i].distance(shapes[j]) < 1.5:
                inter = shapes[i].buffer(1.0).intersection(shapes[j].buffer(1.0))
                if inter.area > 6.0:
                    adj[i].add(j)
                    adj[j].add(i)
    for a, b in STRAITS:
        ia, ib = key_to_id[a], key_to_id[b]
        adj[ia].add(ib)
        adj[ib].add(ia)
    for i, p in enumerate(provinces):
        p["adj"] = sorted(adj[i])
        if not p["adj"]:
            raise SystemExit("isolated province " + p["key"])

    # background land (no province) for geography context
    covered = unary_union(shapes).buffer(0.5)
    rest = full_land.difference(covered).simplify(2.0, preserve_topology=True)
    bg = []
    for q in getattr(rest, "geoms", [rest]):
        if q.geom_type == "Polygon" and q.area > 200.0:
            bg.append([[round(x, 1), round(y, 1)] for x, y in list(q.exterior.coords)[:-1]])

    minx, miny, maxx, maxy = land.bounds
    out = {"size": [round(maxx, 1), round(min(maxy, (LAT0 - MIN_LAT - 0.5) * SCALE), 1)], "provinces": provinces, "background": bg}
    with open("data/map.json", "w") as f:
        json.dump(out, f, separators=(",", ":"), ensure_ascii=False)
    print(len(provinces), "provinces, bg polys:", len(bg), "size", out["size"])


if __name__ == "__main__":
    main(sys.argv[1])
