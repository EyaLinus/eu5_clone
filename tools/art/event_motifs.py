"""Assigns every event in data/events.json one picture motif from tools/art/event_scenes.py.

Writes assets/art/events/event_motifs.json (event id -> motif). An event can also set
"image": "<motif>" itself, which wins over this file. New events without either show the
fallback motif (court). Run after adding events:

    python3 tools/art/event_motifs.py
"""
import json
import os
import re
import sys
from collections import Counter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "art", "events", "event_motifs.json")
FALLBACK = "court"

# Hand-picked where keywords would guess wrong.
EXPLICIT = {
    "fra_charles7": "camp", "fra_louis11": "conspiracy", "fra_brittany": "wedding", "fra_italian_wars": "camp",
    "fra_richelieu": "court", "eng_roses": "battle", "eng_calais": "city", "eng_tudor": "coronation",
    "eng_elizabeth": "court", "eng_union": "coronation", "eng_wool": "market", "spa_isabella": "wedding",
    "spa_columbus": "exploration", "spa_silver": "naval", "spa_tercios": "camp", "spa_habsburg": "wedding",
    "boh_podiebrad": "coronation", "boh_kutna": "mine", "boh_jagiellon": "diet", "boh_defenestration": "revolt",
    "hab_frederick": "court", "hab_mary": "wedding", "hab_mohacs": "mourning", "hab_bohemia_inherit": "coronation",
    "hab_spanish_branch": "wedding", "rus_ivan3": "coronation", "rus_ugra": "steppe", "rus_third_rome": "church",
    "rus_oprichnina": "conspiracy", "rus_troubles": "famine", "rus_siberia": "steppe", "nap_alfonso": "court",
    "nap_barons": "conspiracy", "nap_french_invasion": "camp", "nap_vesuvius": "volcano", "nap_masaniello": "revolt",
    "nap_trade": "naval", "gen_heir": "heir", "gen_border": "border", "fra_burgundy_fall": "mourning",
    "fra_albret": "wedding", "eng_navy": "naval", "eng_poynings": "diet", "eng_castillon": "mourning",
    "spa_navarre": "border", "spa_escorial": "city", "boh_compacts": "treaty", "boh_silesia": "diet",
    "boh_rudolf": "alchemy", "boh_majesty": "treaty", "hab_corvinus": "battle", "hab_worms": "diet",
    "hab_schwaz": "mine", "hab_bavaria": "battle", "rus_novgorod": "siege", "rus_ryazan": "court",
    "rus_sudebnik": "diet", "rus_kazan": "siege", "nap_ferrante": "court", "nap_otranto": "siege",
    "nap_viceroy": "court", "nap_studium": "scholar", "fra_jacques_coeur": "bank", "fra_marignano": "battle",
    "fra_pavia": "battle", "fra_capitulations": "treaty", "fra_cloth_of_gold": "camp", "fra_concordat": "treaty",
    "fra_new_france": "exploration", "fra_paulette": "bank", "eng_cade": "revolt", "eng_cabot": "exploration",
    "eng_bloody_mary": "inquisition", "eng_drake": "naval", "eng_armada": "naval", "eng_east_india": "bank",
    "eng_gunpowder": "conspiracy", "spa_alhambra": "inquisition", "spa_magellan": "exploration",
    "spa_bankruptcy": "bank", "spa_lepanto": "naval", "spa_moriscos": "inquisition", "spa_olivares": "court",
    "boh_wagenburg": "artillery", "boh_ladislaus": "heir", "boh_brethren": "reformation",
    "boh_land_ordinance": "diet", "boh_winter_king": "coronation", "boh_white_mountain": "battle",
    "hab_aeiou": "court", "hab_landsknechte": "camp", "hab_frundsberg": "camp", "hab_augsburg": "treaty",
    "hab_counter_reformation": "church", "hab_wallenstein": "camp", "hab_eger": "conspiracy",
    "rus_sophia": "wedding", "rus_streltsy": "camp", "rus_moscow_burns": "town_fire", "rus_livonian_war": "battle",
    "rus_cossacks": "steppe", "rus_romanov": "coronation", "nap_aragon_split": "court", "nap_skanderbeg": "battle",
    "nap_pontano": "scholar", "nap_borgia": "church", "nap_corsairs": "naval", "nap_toledo": "city",
    "gen_comet": "comet", "gen_famine": "famine", "gen_fire": "town_fire", "gen_revolt": "revolt",
    "gen_war_weariness": "mourning", "gen_veterans": "procession", "gen_university": "scholar", "gen_fugger": "bank",
    "gen_artist": "artist", "gen_royal_wedding": "wedding", "gen_spy": "conspiracy", "gen_ruler_ill": "sickbed",
    "gen_copernicus": "scholar", "gen_price_revolution": "bank", "gen_new_crops": "harvest",
    "gen_little_ice_age": "famine", "gen_witch_trials": "inquisition", "gen_mercenary_mutiny": "camp",
    "gen_jubilee": "church", "gen_jubilee_1500": "church", "gen_alchemist": "alchemy",
    "gen_alchemist_result": "alchemy", "gen_minor_neutrality": "treaty", "gen_minor_mercenaries": "camp",
    "gen_minor_fair": "market", "gen_minor_militia": "camp", "gen_minor_court": "artist",
    "tur_constantinople": "siege", "tur_janissaries": "camp", "tur_suleiman": "ottoman", "pol_lublin": "diet",
    "pol_grunwald": "battle", "bur_charles_bold": "knights", "ven_stato_da_mar": "naval", "hun_matthias": "court",
    "dan_stockholm": "conspiracy", "por_india": "exploration", "pap_borgia": "conspiracy", "swi_reislaufen": "camp",
    "gen_peace_party": "diet", "gen_deserters": "camp", "gen_victory_te_deum": "procession",
    "gen_war_widows": "mourning", "gen_exhausted_land": "famine", "gen_unrest_agitators": "revolt",
    "gen_unrest_amnesty": "court", "gen_vassal_tribute": "bank", "gen_vassal_court": "court",
    "gen_overlord_vassal_loyalty": "diet", "sax_electoral_vote": "diet", "pal_electoral_vote": "diet",
    "bra_electoral_vote": "diet", "boh_golden_bull": "treaty", "tur_mohacs": "battle", "tur_lepanto": "naval",
    "pol_henrician": "diet", "pol_vienna_relief": "battle", "bur_nancy": "siege", "bur_golden_fleece": "knights",
    "gen_hre_reichstag": "diet", "gen_hre_landfriede": "treaty", "gen_hre_reichskreis": "diet",
    "gen_emperor_coronation": "coronation", "gen_emperor_reform": "diet", "ven_lodi": "treaty",
    "ven_cambrai": "treaty", "ven_agnadello": "mourning", "ven_cyprus": "naval", "mlo_sforza_coup": "revolt",
    "mlo_ludovico": "court", "mlo_french_betrayal": "conspiracy", "pap_julius": "camp", "pap_indulgences": "church",
    "pap_trent": "diet", "pap_sack_of_rome": "town_fire", "tus_pazzi": "conspiracy", "tus_lorenzo_naples": "treaty",
    "tus_savonarola": "town_fire", "tus_galileo": "scholar", "dan_engelbrekt": "diet", "dan_brunkeberg": "battle",
    "dan_count_feud": "battle", "dan_christian4": "city", "dan_tycho": "scholar", "gen_newspapers": "printing",
    "gen_coffee_house": "tavern", "gen_mercantilism": "market", "gen_standing_army": "camp", "gen_baroque": "artist",
    "gen_bureaucracy": "scholar", "gen_thirty_years": "battle", "gen_plague_1630": "plague", "sco_flodden": "battle",
    "sco_knox": "reformation", "ire_kildare": "court", "por_henry": "exploration", "por_tordesillas": "treaty",
    "por_alcacer": "battle", "gra_boabdil": "city", "ara_remensa": "revolt", "hun_hunyadi": "battle",
    "hun_dozsa": "revolt", "lit_grunwald_legacy": "knights", "nov_marfa": "diet", "cri_mengli": "steppe",
    "wal_dracula": "conspiracy", "mol_stephen": "battle", "alb_skanderbeg_league": "diet",
    "ser_smederevo": "siege", "sax_luther": "reformation", "bra_hohenzollern": "court", "bav_reinheitsgebot": "tavern",
    "hsa_wars": "naval", "teu_secularize": "knights", "kaz_khanate": "steppe", "kaz_volga_trade": "market",
    "rya_last_prince": "mourning", "liv_plettenberg": "knights", "byz_last_emperor": "siege", "byz_morea": "city",
    "bos_church": "church", "sav_shroud": "church", "sav_emmanuel_philibert": "knights", "genoa_doria": "naval",
    "prv_good_king_rene": "artist", "bri_francis2": "court", "nav_albret": "wedding", "kol_soest": "siege",
    "wur_poor_conrad": "revolt", "nur_duerer": "artist", "hes_philip": "reformation", "lun_salt": "market",
    "pom_bogislaw": "court", "tur_istanbul": "ottoman", "tur_cem": "conspiracy", "tur_selim": "battle",
    "tur_barbarossa": "naval", "tur_hurrem": "ottoman", "tur_sokollu": "ottoman", "tur_osman2": "revolt",
    "pol_nieszawa": "diet", "pol_nihil_novi": "diet", "pol_wawel": "artist", "pol_prussian_homage": "coronation",
    "pol_livonia": "treaty", "pol_warsaw_confederation": "treaty", "pol_zamoyski": "battle",
    "pol_dymitriad": "conspiracy", "bur_philip_good": "court", "bur_ghent": "revolt", "bur_liege": "town_fire",
    "bur_neuss": "siege", "bur_trier": "coronation", "bur_great_privilege": "diet", "bur_antwerp_bourse": "bank",
    "bur_iconoclasm": "reformation", "fra_reconquest_normandy": "siege", "fra_religion": "battle",
    "eng_reformation": "reformation", "spa_granada_war": "siege", "spa_inquisition": "inquisition",
    "boh_crusade": "battle", "boh_university": "scholar", "hab_vienna_siege": "siege", "gen_plague": "plague",
    "gen_harvest": "harvest", "gen_printing": "printing", "gen_reformation": "reformation", "gen_condottieri": "camp",
    "gen_military_revolution": "artillery", "gen_merchants": "market", "fra_estates": "diet", "spa_comuneros": "revolt",
}

# Keyword fallback for events added later (matched against "id title text", lower case).
RULES = [
    (r"pest|plague|seuche", "plague"), (r"belager|siege|festung", "siege"), (r"flotte|armada|see|korsar|navy", "naval"),
    (r"schlacht|battle|krieg|feldzug", "battle"), (r"hochzeit|heirat|wedding|braut", "wedding"),
    (r"krönung|krone|coronation|thron", "coronation"), (r"aufstand|revolt|rebell|bauern", "revolt"),
    (r"vertrag|friede|treaty|bündnis", "treaty"), (r"reichstag|stände|landtag|diet|wahl", "diet"),
    (r"söldner|heer|armee|truppen|mercenar", "camp"), (r"kirche|papst|bischof|church|heilig", "church"),
    (r"reformation|luther|ketzer", "reformation"), (r"handel|markt|messe|kaufleute|trade", "market"),
    (r"bank|gold|silber|schulden|steuer", "bank"), (r"universität|gelehrt|wissen|astronom", "scholar"),
    (r"künstler|maler|kunst|artist", "artist"), (r"verschwörung|spion|mord|attentat", "conspiracy"),
    (r"hunger|winter|missernte", "famine"), (r"brand|feuer|fire", "town_fire"), (r"ernte|harvest|feld", "harvest"),
    (r"entdeck|neue welt|seeweg|explor", "exploration"), (r"krank|tod des|ill", "sickbed"),
]


def motif_for(e):
    if e.get("image"):
        return e["image"]
    if e["id"] in EXPLICIT:
        return EXPLICIT[e["id"]]
    hay = ("%s %s %s" % (e["id"], e["title"], e.get("text", ""))).lower()
    for pat, m in RULES:
        if re.search(pat, hay):
            return m
    return FALLBACK


def main():
    sys.path.insert(0, os.path.dirname(__file__))
    import event_scenes
    events = json.load(open(os.path.join(ROOT, "data", "events.json")))
    mapping = {e["id"]: motif_for(e) for e in events}
    bad = sorted({m for m in mapping.values() if m not in event_scenes.MOTIFS})
    if bad:
        sys.exit("unknown motifs: %s" % bad)
    unused = sorted(set(event_scenes.MOTIFS) - set(mapping.values()))
    with open(OUT, "w") as f:
        json.dump(mapping, f, indent=0, sort_keys=True, ensure_ascii=False)
        f.write("\n")
    c = Counter(mapping.values())
    print("%d events, %d motifs used; unused: %s" % (len(mapping), len(c), unused or "-"))
    print(", ".join("%s %d" % kv for kv in c.most_common()))


if __name__ == "__main__":
    main()
