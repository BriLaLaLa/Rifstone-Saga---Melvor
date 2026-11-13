extends SceneTree
## Generates the Rift Stones (docs/04_DATA_SCHEMA.md §22, docs/02_FORMULAS.md §5f, docs/01_GDD.md §24b): one stone per
## (area, level) with a level every 5 (Z2), written to data/combat/rift_stones.json. Since M17-04 the pool of an area comes from
## its `level_min` / `level_max` in data/combat/areas.json (written by tools/gen_areas.gd, run that first); names and texts are
## the STONES of tools/gen_areas_data.gd, in pool order. The output is committed: the game never runs this script.
##
## Usage: godot --headless --path . -s tools/gen_metin.gd
##
## Pool of an area (Z2): multiples of 5 from ceil5(level_min) (at least 5) up to level_max (area 10: 95). Ids: `<area>_stone_<level>`.
## Numbers (declared here): xp = round to 10 of STONE_XP_MULT x combat.monster_xp(level) (the xp of a monster of the stone's level,
## F-130), shards = [max(2, round(0.45 L)), max(lo + 1, round(0.75 L))], warding seal chance 25 + 5 x tier.

const Data := preload("res://tools/gen_areas_data.gd")
const OUT_PATH: String = "res://data/combat/rift_stones.json"
const AREAS_PATH: String = "res://data/combat/areas.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const ICON_DIR: String = "res://assets/icons/monsters/"
const STEP: int = 5
const PULSE_MS: int = 3000
const STONE_XP_MULT: float = 3.0


func _init() -> void:
	var balance: Dictionary = _read(BALANCE_PATH)
	var areas: Array = _read(AREAS_PATH).get("areas", []) as Array
	areas.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Dictionary)["order"]) < int((b as Dictionary)["order"]))
	var stones: Array[Dictionary] = []
	var index: int = 0
	for area: Dictionary in areas:
		var info: Dictionary = _area_info(area["id"] as String)
		for level: int in _pool(int(area["level_min"]), int(area["level_max"])):
			if index >= Data.STONES.size():
				push_error("gen_metin: not enough names in gen_areas_data.gd (%d)" % Data.STONES.size())
				quit(1)
				return
			stones.append(_stone(area["id"] as String, info, level, Data.STONES[index] as Array, balance))
			index += 1
	if index != Data.STONES.size():
		push_error("gen_metin: %d stones generated, %d names" % [index, Data.STONES.size()])
		quit(1)
		return
	_write_stones(stones)
	print_rich("gen_metin: %d stones written" % stones.size())
	quit()


func _area_info(area_id: String) -> Dictionary:
	for area: Dictionary in Data.AREAS:
		if area["id"] == area_id:
			return area
	return {}


static func _pool(first: int, last: int) -> Array[int]:
	var pool: Array[int] = []
	var level: int = maxi(STEP, int(ceil(float(first) / STEP)) * STEP)
	while level <= last:
		pool.append(level)
		level += STEP
	return pool


func _stone(area_id: String, info: Dictionary, level: int, text: Array, balance: Dictionary) -> Dictionary:
	var xp_spec: Dictionary = (balance["combat"] as Dictionary)["monster_xp"] as Dictionary
	var monster_xp: float = float(xp_spec["base"]) * pow(float(xp_spec["growth"]), float(level - 1))
	var low: int = maxi(2, roundi(0.45 * level))
	return {
		"id": "%s_stone_%d" % [area_id, level], "name": text[0], "description": text[1],
		"icon": ICON_DIR + (info["stone_icon"] as String) + ".svg", "area": area_id, "level": level,
		"xp": roundi(STONE_XP_MULT * monster_xp / 10.0) * 10, "pulse_ms": PULSE_MS,
		"shards": [low, maxi(low + 1, roundi(0.75 * level))], "wave_packs": null,
		"loot_tables": ["loot_monolith_" + area_id],
		"drops": [{"item": "warding_seal", "chance_pct": 25 + 5 * int(info["tier"]), "qty": [1, 1]}]}


func _write_stones(stones: Array[Dictionary]) -> void:
	var lines: Array[String] = []
	for i: int in stones.size():
		lines.append("    " + JSON.stringify(stones[i], "", false) + ("," if i < stones.size() - 1 else ""))
	var doc: String = "Monoliti del Rift (F-87, M15): uno per area e per livello (ogni 5 livelli), generati da tools/gen_metin.gd (M17-04: aree strette). PV da F-125, ondate F-126, bottino F-127: niente hp/pulse_damage qui."
	var text: String = "{\n  \"_doc\": %s,\n  \"rift_stones\": [\n%s\n  ]\n}\n" % [JSON.stringify(doc), "\n".join(lines)]
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
