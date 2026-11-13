class_name DataValidatorMiniboss
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the miniboss of an area (docs/04_DATA_SCHEMA.md §27, F-139),
## kept apart from DataValidatorAreas for its size.

const FIELDS: PackedStringArray = ["monster", "escorts"]
const ESCORTS_MAX: int = 4


## `miniboss` of every area: `{"monster": id, "escorts": n}`, a monster marked `miniboss` that belongs to no pack, used by one
## area only, with a level inside the area's levels (areas of the narrow format). Required in every area once one has it, or
## with `required` (the real data after M22-03); a monster marked `miniboss` that no area names is an error. `areas` and
## `monsters` are `{path: top-level object}`.
static func validate(v: DataValidatorRules, areas: Dictionary, monsters: Dictionary, required: bool) -> void:
	var in_packs: Dictionary[StringName, bool] = {}
	var any: bool = false
	for path: Variant in areas:
		for a: Variant in ((areas[path] as Dictionary).get("areas", []) as Array):
			any = any or (a is Dictionary and (a as Dictionary).has("miniboss"))
			for pack: Variant in ((a as Dictionary).get("packs", []) as Array if a is Dictionary else []):
				for id: Variant in ((pack as Dictionary).get("monsters", []) as Array if pack is Dictionary else []):
					in_packs[StringName(str(id))] = true
	var used: Dictionary[StringName, bool] = {}
	for path: Variant in areas:
		v.at_file(str(path))
		var list: Array = (areas[path] as Dictionary).get("areas", []) as Array
		for index: int in list.size():
			if list[index] is Dictionary:
				_area(v, index, list[index] as Dictionary, required or any, in_packs, used)
	for path: Variant in monsters:
		v.at_file(str(path))
		var list: Array = (monsters[path] as Dictionary).get("monsters", []) as Array
		for index: int in list.size():
			if list[index] is Dictionary and (list[index] as Dictionary).get("miniboss") == true \
					and not used.has(StringName(str((list[index] as Dictionary).get("id")))):
				v.at_entry("monster", index, list[index] as Dictionary)
				v.fail("field 'miniboss': no area names this monster as its miniboss")


static func _area(v: DataValidatorRules, index: int, a: Dictionary, required: bool, in_packs: Dictionary[StringName, bool],
		used: Dictionary[StringName, bool]) -> void:
	v.at_entry("area", index, a)
	if not a.has("miniboss"):
		if required:
			v.fail("field 'miniboss' is required")
		return
	var miniboss: Dictionary = v.object(a, "miniboss")
	v.keys(miniboss, FIELDS, "miniboss")
	v.integer(miniboss, "escorts", 0, ESCORTS_MAX, "miniboss")
	if not v.ref(miniboss, "monster", v.monsters, "monster", "miniboss"):
		return
	var id := StringName(miniboss["monster"] as String)
	if v.monsters[id].get("miniboss") != true:
		v.fail("field 'miniboss.monster': '%s' is not marked `miniboss`" % id)
	if in_packs.has(id):
		v.fail("field 'miniboss.monster': '%s' is in a pack, a miniboss never is" % id)
	if used.has(id):
		v.fail("field 'miniboss.monster': '%s' is already the miniboss of another area" % id)
	used[id] = true
	_level(v, a, id)


static func _level(v: DataValidatorRules, a: Dictionary, id: StringName) -> void:
	if not DataValidatorRules.is_int(a.get("level_min")) or not DataValidatorRules.is_int(a.get("level_max")):
		return
	var level: int = 0
	for field: String in ["attack_level", "power_level", "defence_level"]:
		if DataValidatorRules.is_number(v.monsters[id].get(field)):
			level = maxi(level, int(v.monsters[id][field]))
	if level < int(a["level_min"]) or level > int(a["level_max"]):
		v.fail("field 'miniboss.monster': '%s' has level %d, outside the levels %d-%d of the area"
				% [id, level, int(a["level_min"]), int(a["level_max"])])
