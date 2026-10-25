extends RefCounted
## Central icon lookup for the pixel-art pipeline.
## Every icon has an emoji fallback. If res://assets/art/icons/<key>.png exists it is used instead.
## Nation flags: key "flag_<TAG>" (e.g. flag_FRA.png). Army marker on the map: "army_marker".
## Recommended source size: 32x32 or 64x64 PNG, transparent background, nearest-neighbour filtering.

const DIR := "res://assets/art/icons/"
const EMOJI := {
	"gold": "💰", "adm": "📜", "dip": "🕊️", "mil": "⚔️", "manpower": "👥", "army": "🛡️", "ae": "😠",
	"prestige": "⭐", "dev": "🏘️", "fort": "🏰", "date": "📅", "siege": "🔥", "claim": "📜",
	"tab_nation": "🏛️", "tab_tech": "🔬", "tab_government": "⚖️", "tab_diplomacy": "🤝", "tab_wars": "⚔️", "tab_missions": "🎯", "tab_log": "📜",
	"tab_mapmode": "🗺️", "event": "📯", "peace": "🕊️", "war": "🔥", "coalition": "⚠️",
	"vassal": "⛓️", "annex": "📜",
}

static var _cache := {}


static func emoji(key: String) -> String:
	return EMOJI.get(key, "")


static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path := DIR + key + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = tex
	return tex


## "💰 " when no texture exists, "" when a texture will be shown next to the text.
static func prefix(key: String) -> String:
	return "" if texture(key) != null else emoji(key) + " "


static func flag(tag: String) -> Texture2D:
	return texture("flag_" + tag)
