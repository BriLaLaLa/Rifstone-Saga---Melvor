class_name DataValidatorStones
extends RefCounted
## Part of DataValidator (internal, not API for other modules): `data/combat/rift_stones.json` (M7,
## docs/04_DATA_SCHEMA.md §16, F-87), written with the toolkit of DataValidatorRules.

const STONE_FIELDS: PackedStringArray = ["id", "name", "description", "icon", "area", "hp", "xp", "pulse_damage",
	"pulse_ms", "summon_pack", "shards", "drops", "loot_tables"]
const ICON_DIR: String = "res://assets/icons/monsters/"


static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary],
		areas: Dictionary[String, Dictionary]) -> void:
	var packs: Dictionary[StringName, Dictionary] = {}  # area id -> its raw entry
	for path: String in areas:
		for a: Variant in (areas[path].get("areas", []) as Array):
			if a is Dictionary and (a as Dictionary).get("id") is String:
				packs[StringName((a as Dictionary)["id"] as String)] = a as Dictionary
	var seen: Dictionary[StringName, bool] = {}
	var used_areas: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "rift_stones")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("rift stone", index, e, seen, STONE_FIELDS)
			DataValidatorClasses.existing_icon(v, e, ICON_DIR)
			if v.ref(e, "area", packs, "area"):
				var area_id := StringName(e["area"] as String)
				if used_areas.has(area_id):
					v.fail("field 'area': '%s' already has a Rift Stone" % area_id)
				used_areas[area_id] = true
				_summon(v, e, (packs[area_id].get("packs", []) as Array).size())
			v.integer(e, "hp", 1)
			v.integer(e, "xp", 0)
			v.integer(e, "pulse_damage", 1)
			v.integer(e, "pulse_ms", maxf(v.min_attack_interval_ms, 1))
			v.int_pair(e, "shards", 0, DataValidatorRules.NO_LIMIT, true)
			DataValidatorClasses.drops(v, e)


# `summon_pack`: null (nobody) or the index of a pack of the area.
static func _summon(v: DataValidatorRules, e: Dictionary, pack_count: int) -> void:
	if not e.has("summon_pack"):
		v.fail("missing field 'summon_pack'")
	elif e["summon_pack"] != null:
		v.integer(e, "summon_pack", 0, float(pack_count - 1))
