extends SceneTree
## Generates the Rift Stones of M15 (docs/04_DATA_SCHEMA.md §22, docs/02_FORMULAS.md §5f, docs/01_GDD.md §24b):
## one stone per (area, level) with a level every 5 (Z2), written to data/combat/rift_stones.json. It also adds the
## `metin.*` and `combat.crowd_threshold` / `combat.skip_stone_level` keys to data/config/balance.json and sets the
## Plains `rift_stone_chance_pct` in data/combat/areas.json (Z5). Both edits are idempotent text patches, so the
## formatting of the files stays untouched. The output is committed: the game never runs this script.
##
## Usage: godot --headless --path . -s tools/gen_metin.gd
##
## Pool of an area (Z2): multiples of 5 from ceil5(requirements.character) (at least 5) up to the area's last level
## (= first level of the next area - 1; last area: character_curve.max_level). Ids: `<area>_stone_<level>`.

const OUT_PATH: String = "res://data/combat/rift_stones.json"
const AREAS_PATH: String = "res://data/combat/areas.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const ICON_DIR: String = "res://assets/icons/monsters/"
const STEP: int = 5
const PULSE_MS: int = 3000
const PLAINS_CHANCE_PCT: String = "0.6"

## Per area: icon, shared loot table (F-32), base xp / shards (the values of the single stone of M12, scaled by
## level / mean level of the pool), warding seal chance, and the names and descriptions in pool order.
const AREA_DATA: Dictionary = {
	"redrock_plains": {
		"icon": "redrock_stone", "loot": "loot_monolith_redrock", "xp": 400, "shards": [3, 6], "seal": 25,
		"names": ["Monolito del Sentiero Rosso", "Monolito della Brace Sepolta", "Monolito del Vento di Ruggine"],
		"descs": ["Un sasso rosso piantato nel sentiero: batte piano, come un cuore addormentato.",
			"Sotto la crosta di terra cova una brace che non si spegne mai.",
			"Il vento ci gira attorno e porta un odore di ferro e di cenere."]},
	"whisper_wood": {
		"icon": "whisper_stone", "loot": "loot_monolith_whisper", "xp": 1600, "shards": [8, 14], "seal": 30,
		"names": ["Monolito del Muschio Cupo", "Monolito dell'Eco Fitto", "Monolito della Radice Bisbigliante",
			"Monolito del Cerchio Muto"],
		"descs": ["Una lastra coperta di muschio scuro che mormora quando nessuno la guarda.",
			"Ogni colpo ritorna dagli alberi più forte, come se il bosco rispondesse.",
			"Radici sottili la stringono e sussurrano nomi di chi non è tornato.",
			"Un cerchio di funghi spenti la circonda: lì dentro non vola nemmeno un uccello."]},
	"cracked_mines": {
		"icon": "mine_stone", "loot": "loot_monolith_mine", "xp": 4800, "shards": [15, 25], "seal": 35,
		"names": ["Monolito della Vena Viola", "Monolito del Pozzo Crepato", "Monolito dello Scavo Cieco",
			"Monolito della Geode Lenta", "Monolito del Filone Spezzato"],
		"descs": ["Una vena di luce viola corre nella roccia e si ferma proprio qui.",
			"Il cristallo si è incastrato in un pozzo franato e ne tiene su il soffitto.",
			"In fondo allo scavo non c'è lampada che regga: la luce la fa lui.",
			"Una geode grande come una botte, che si apre e si chiude a ogni battito.",
			"Il filone si è spezzato attorno a lui e le crepe respirano insieme."]},
	"rift_threshold": {
		"icon": "threshold_stone", "loot": "loot_monolith_threshold", "xp": 12000, "shards": [30, 50], "seal": 40,
		"names": ["Monolito dell'Orlo Strappato", "Monolito della Cucitura Aperta", "Monolito del Varco Nero",
			"Monolito dell'Eco Spento", "Monolito del Velo Sottile", "Monolito del Cuore Vuoto",
			"Monolito dell'Ultimo Confine"],
		"descs": ["Il bordo del mondo si sfilaccia attorno a questa pietra nera.",
			"Una cucitura nell'aria si è aperta e il monolito la tiene spalancata.",
			"Uno strappo scuro nel cielo, e al centro lui, immobile.",
			"Qui anche il rumore dei passi si spegne prima di nascere.",
			"L'aria è così sottile che si vede attraverso, e dall'altra parte qualcosa guarda.",
			"Il monolito è cavo: dentro non c'è nulla, ed è questo che pesa.",
			"Oltre questa pietra il mondo non ha più un nome."]},
}

## Starting values of balance.json (docs/02_FORMULAS.md §9, Q78); inserted before `"rift_stone"`.
const METIN_BLOCK: String = """  "metin": {
    "hp_base": 200,
    "hp_per_level": 0.25,
    "pulse_damage": 1,
    "wave_size": 7,
    "wave_thresholds": [75, 50, 25],
    "rarity_bonus_pct": 100,
    "guaranteed_pieces": 1
  },
"""


func _init() -> void:
	var areas: Array = _read(AREAS_PATH).get("areas", []) as Array
	var max_level: int = int(_read(BALANCE_PATH)["character_curve"]["max_level"])
	areas.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Dictionary)["order"]) < int((b as Dictionary)["order"]))
	var stones: Array[Dictionary] = []
	for i: int in areas.size():
		var area: Dictionary = areas[i] as Dictionary
		var first: int = int((area["requirements"] as Dictionary)["character"])
		var last: int = int(((areas[i + 1] as Dictionary)["requirements"] as Dictionary)["character"]) - 1 if i + 1 < areas.size() else max_level
		stones.append_array(_area_stones(area["id"] as String, first, last))
	_write_stones(stones)
	_patch_balance()
	_patch_areas()
	Log.info("gen_metin", "%d stones written" % stones.size())
	quit()


func _pool(first: int, last: int) -> Array[int]:
	var pool: Array[int] = []
	var level: int = maxi(STEP, int(ceil(float(first) / STEP)) * STEP)
	while level <= last:
		pool.append(level)
		level += STEP
	return pool


func _area_stones(area_id: String, first: int, last: int) -> Array[Dictionary]:
	var d: Dictionary = AREA_DATA[area_id] as Dictionary
	var pool: Array[int] = _pool(first, last)
	var names: Array = d["names"] as Array
	var descs: Array = d["descs"] as Array
	if pool.size() != names.size() or pool.size() != descs.size():
		push_error("gen_metin: area %s has pool %s but %d names" % [area_id, pool, names.size()])
		quit(1)
		return []
	var mean: float = 0.0
	for level: int in pool:
		mean += float(level)
	mean /= pool.size()
	var shards: Array = d["shards"] as Array
	var out: Array[Dictionary] = []
	for i: int in pool.size():
		var scale: float = float(pool[i]) / mean
		out.append({
			"id": "%s_stone_%d" % [area_id, pool[i]],
			"name": names[i], "description": descs[i],
			"icon": ICON_DIR + (d["icon"] as String) + ".svg",
			"area": area_id, "level": pool[i],
			"xp": int(round(float(d["xp"]) * scale / 10.0)) * 10,
			"pulse_ms": PULSE_MS,
			"shards": [maxi(1, int(round(float(shards[0]) * scale))), maxi(1, int(round(float(shards[1]) * scale)))],
			"wave_packs": null,
			"loot_tables": [d["loot"]],
			"drops": [{"item": "warding_seal", "chance_pct": d["seal"], "qty": [1, 1]}]})
	return out


func _write_stones(stones: Array[Dictionary]) -> void:
	var lines: Array[String] = []
	for i: int in stones.size():
		lines.append("    " + JSON.stringify(stones[i], "", false) + ("," if i < stones.size() - 1 else ""))
	var doc: String = "Monoliti del Rift (F-87, M15): uno per area e per livello (ogni 5 livelli), generati da tools/gen_metin.gd. PV da F-125, ondate F-126, bottino F-127: niente hp/pulse_damage qui."
	var text: String = "{\n  \"_doc\": %s,\n  \"rift_stones\": [\n%s\n  ]\n}\n" % [JSON.stringify(doc), "\n".join(lines)]
	_save(OUT_PATH, text)


func _patch_balance() -> void:
	var text: String = FileAccess.get_file_as_string(BALANCE_PATH)
	if not text.contains("\"metin\""):
		text = text.replace("\n  \"rift_stone\": {\"chance_pct\"", "\n" + METIN_BLOCK + "  \"rift_stone\": {\"chance_pct\"")
	if not text.contains("\"crowd_threshold\""):
		text = text.replace("    \"min_attack_interval_ms\": 800,\n",
				"    \"min_attack_interval_ms\": 800,\n    \"crowd_threshold\": 8,\n    \"skip_stone_level\": 0,\n")
	_save(BALANCE_PATH, text)
	var b: Dictionary = _read(BALANCE_PATH)  # must still parse
	if not b.has("metin") or not (b["combat"] as Dictionary).has("crowd_threshold"):
		push_error("gen_metin: balance.json patch failed")
		quit(1)


func _patch_areas() -> void:
	var text: String = FileAccess.get_file_as_string(AREAS_PATH)
	var re: RegEx = RegEx.create_from_string("(\"id\":\"redrock_plains\".*?\"rift_stone_chance_pct\":)[0-9.]+")
	var m: RegExMatch = re.search(text)
	if m == null:
		push_error("gen_metin: redrock_plains rift_stone_chance_pct not found")
		quit(1)
		return
	text = text.replace(m.get_string(), m.get_string(1) + PLAINS_CHANCE_PCT)
	_save(AREAS_PATH, text)


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _save(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
