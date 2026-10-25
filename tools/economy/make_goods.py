import json
assign = """
grain: pale orleans picardy normandy toulouse berry piedmont zaragoza valencia sevilla sicily apulia rome bologna ancona verona friuli pilsen moravia munich regensburg berlin hesse pomerania mecklenburg prussia marienburg poznan warsaw kiev volhynia chernigov pressburg slavonia moscow tver vladimir ryazan reval gotaland edirne thessaly varna
wine: bordeaux champagne anjou languedoc dijon provence pamplona porto malaga napoli siena wien palatinate morea
wool: wessex eastanglia midlands york calais leon toledo burgos extremadura abruzzo skopje
cloth: calabria london paris flanders brabant lyon barcelona murcia granada florence genoa silesia lusatia leipzig cologne swabia zurich pskov constantinople
fish: lothian brest holland galicia algarve dalmatia bremen hamburg copenhagen scania bergen nizhny
salt: rennes poitou franchecomte lisbon sardinia venice linz brunswick krakow transylvania crimea
iron: luxembourg biscay milan steiermark carniola nuremberg bosnia tula stockholm
copper: cornwall kassa dalarna
silver: prague tirol dresden serbia
timber: dauphine corsica croatia vilnius minsk smolensk riga oslo turku
furs: novgorod karelia beloozero vologda yaroslavl kazan
livestock: northumberland wales highlands munster ulster auvergne limousin savoy parma bern lwow buda temes zaporozhia jutland holstein sofia wallachia moldavia albania
"""
m = json.load(open('data/map.json'))
keys = [p['key'] for p in m['provinces']]
prov = {}
for line in assign.strip().splitlines():
    g, ks = line.split(':')
    for k in ks.split():
        assert k in keys, k
        assert k not in prov, k
        prov[k] = g.strip()
missing = [k for k in keys if k not in prov]
assert not missing, missing
goods = {
 "grain":     {"name": "Getreide", "price": 0.20, "bonus": {"manpower": 0.10}, "bonus_text": "+10 % Mannschaften"},
 "wine":      {"name": "Wein",     "price": 0.30, "bonus": {"dip": 0.5}, "bonus_text": "+0,5 Diplomatie/Monat"},
 "wool":      {"name": "Wolle",    "price": 0.25, "bonus": {"tax": 0.10}, "bonus_text": "+10 % Steuern"},
 "cloth":     {"name": "Tuch",     "price": 0.35, "bonus": {"production": 0.10}, "bonus_text": "+10 % Produktion"},
 "fish":      {"name": "Fisch",    "price": 0.20, "bonus": {"maintenance": -0.10}, "bonus_text": "-10 % Armeeunterhalt"},
 "salt":      {"name": "Salz",     "price": 0.30, "bonus": {"trade": 0.10}, "bonus_text": "+10 % Handelseinnahmen"},
 "iron":      {"name": "Eisen",    "price": 0.30, "bonus": {"combat": 0.05}, "bonus_text": "+5 % Kampfkraft"},
 "copper":    {"name": "Kupfer",   "price": 0.35, "bonus": {"develop_cost": -0.10}, "bonus_text": "-10 % Entwicklungskosten"},
 "silver":    {"name": "Silber",   "price": 0.45, "bonus": {"income": 0.05}, "bonus_text": "+5 % Einkommen"},
 "timber":    {"name": "Holz",     "price": 0.20, "bonus": {"build_cost": -0.10}, "bonus_text": "-10 % Baukosten"},
 "furs":      {"name": "Pelze",    "price": 0.35, "bonus": {"adm": 0.5}, "bonus_text": "+0,5 Admin/Monat"},
 "livestock": {"name": "Vieh",     "price": 0.20, "bonus": {"force_limit": 2.0}, "bonus_text": "+2 Truppenlimit"},
}
for g in goods: goods[g]["emoji"] = {"grain":"🌾","wine":"🍷","wool":"🐑","cloth":"🧵","fish":"🐟","salt":"🧂","iron":"⛏️","copper":"🟠","silver":"🪙","timber":"🪵","furs":"🦊","livestock":"🐄"}[g]
out = {"goods": goods, "provinces": prov,
       "markets": ["london", "paris", "flanders", "hamburg", "novgorod", "moscow", "krakow", "wien", "nuremberg", "venice", "genoa", "sevilla", "constantinople"]}
for k in out["markets"]: assert k in keys
s = json.dumps(out, ensure_ascii=False, indent=1)
open('data/goods.json','w').write(s + "\n")
from collections import Counter
print(Counter(prov.values()))
