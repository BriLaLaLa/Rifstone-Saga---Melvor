class_name DataValidatorTutorialCombat
extends RefCounted
## Combat rules of the tutorial steps (internal, M33-02; docs/M33_TUTORIAL_FORZATO.md §3.1, §5.2): `force_pack`, `force_node`,
## `freeze_combat` and the top-level `force_pack_max_attack_level` of data/tutorial/steps.json.

const COMBAT_EVENTS: PackedStringArray = ["monster_killed", "food_eaten", "node_started", "encounter_started", "encounter_cleared",
	"travel_started", "node_finished"]
const MAX_ATTACK_LEVEL_HIGH: int = 20


## The lookups of the other files, built once: {"areas": {id: [monster ids of its packs]}, "nodes": {area id: [skill ids]}, "stones": {id: true}, "has_nodes": bool}.
static func context(raw: Dictionary) -> Dictionary:
	var areas: Dictionary = {}
	var nodes: Dictionary = {}
	var stones: Dictionary = {}
	var area_files: Dictionary = raw.get("areas", {}) as Dictionary
	for path: Variant in area_files:
		for area: Variant in (area_files[path] as Dictionary).get("areas", []) as Array:
			var monsters: Array = []
			for pack: Variant in (area as Dictionary).get("packs", []) as Array:
				for monster: Variant in (pack as Dictionary).get("monsters", []) as Array:
					if not monsters.has(str(monster)):
						monsters.append(str(monster))
			areas[str((area as Dictionary).get("id"))] = monsters
	var node_files: Dictionary = raw.get("encounters", {}) as Dictionary
	for path: Variant in node_files:
		for area: Variant in (node_files[path] as Dictionary).get("areas", []) as Array:
			var skills: Array = []
			for entry: Variant in (area as Dictionary).get("nodes", []) as Array:
				skills.append(str((entry as Dictionary).get("skill")))
			nodes[str((area as Dictionary).get("area"))] = skills
	var stone_files: Dictionary = raw.get("rift_stones", {}) as Dictionary
	for path: Variant in stone_files:
		for stone: Variant in (stone_files[path] as Dictionary).get("rift_stones", []) as Array:
			stones[str((stone as Dictionary).get("id"))] = true
	return {"areas": areas, "nodes": nodes, "stones": stones, "has_nodes": raw.has("encounters")}


## The top-level threshold: mandatory (1..20) as soon as one step has a `force_pack`.
static func validate_file(v: DataValidatorRules, file: Dictionary, steps: Array[Dictionary]) -> void:
	var any: bool = false
	for e: Dictionary in steps:
		any = any or e.has("force_pack")
	if file.has("force_pack_max_attack_level"):
		v.integer(file, "force_pack_max_attack_level", 1, MAX_ATTACK_LEVEL_HIGH)
	elif any:
		v.fail("field 'force_pack_max_attack_level' is mandatory when a step has `force_pack`")


## One step: `conditions` are its `done_when` objects.
static func validate_step(v: DataValidatorRules, e: Dictionary, conditions: Array, file: Dictionary, ctx: Dictionary) -> void:
	var events: Array[Dictionary] = []
	for c: Variant in conditions:
		if str((c as Dictionary).get("type")) == "event":
			events.append(c as Dictionary)
	_freeze(v, e, events)
	if e.get("force_node") == true and not e.has("force_pack"):
		v.fail("field 'force_node' needs a `force_pack` in the same step")
	if e.has("force_pack"):
		_pack(v, e, events, file, ctx)


static func _freeze(v: DataValidatorRules, e: Dictionary, events: Array[Dictionary]) -> void:
	if e.get("freeze_combat") != true:
		return
	for c: Dictionary in events:
		if COMBAT_EVENTS.has(str(c.get("signal"))):
			v.fail("field 'freeze_combat': the step waits for the combat event '%s', it could never end" % c.get("signal"))


static func _pack(v: DataValidatorRules, e: Dictionary, events: Array[Dictionary], file: Dictionary, ctx: Dictionary) -> void:
	var pack: Dictionary = v.object(e, "force_pack")
	v.keys(pack, ["area", "monsters"], "force_pack")
	var areas: Dictionary = ctx["areas"] as Dictionary
	if not v.text(pack, "area", "force_pack"):
		return
	var area: String = pack["area"] as String
	if not areas.has(area):
		v.fail("field 'force_pack.area': unknown area '%s'" % area)
		return
	var monsters: Array = v.id_list(pack, "monsters", null, "monster", 1)
	if v.max_pack_size != DataValidatorRules.NO_LIMIT and monsters.size() > int(v.max_pack_size):
		v.fail("field 'force_pack.monsters': at most %d monsters, got %d" % [int(v.max_pack_size), monsters.size()])
	var limit: int = int(file.get("force_pack_max_attack_level", 0)) if DataValidatorRules.is_int(file.get("force_pack_max_attack_level")) else 0
	for monster: Variant in monsters:
		_monster(v, str(monster), area, limit, ctx)
	for c: Dictionary in events:
		if str(c.get("signal")) == "monster_killed" and DataValidatorRules.is_int(c.get("count")) and int(c["count"]) > monsters.size():
			v.fail("field 'force_pack.monsters': %d monsters, fewer than the %d kills of `done_when`" % [monsters.size(), int(c["count"])])
		if str(c.get("signal")) == "node_started" and c.get("args") is Dictionary:
			_skills(v, ((c["args"] as Dictionary).get("skill_id")), area, ctx)


static func _monster(v: DataValidatorRules, id: String, area: String, limit: int, ctx: Dictionary) -> void:
	var raw: Dictionary = v.monsters.get(StringName(id), {})
	if not (ctx["areas"][area] as Array).has(id):
		v.fail("field 'force_pack.monsters': '%s' is not in the packs of area '%s'" % [id, area])
	elif raw.is_empty() or raw.get("miniboss") == true or (ctx["stones"] as Dictionary).has(id):
		v.fail("field 'force_pack.monsters': '%s' is unknown, a miniboss or a Rift Stone" % id)
	elif limit > 0 and int(raw.get("attack_level", 0)) > limit:
		v.fail("field 'force_pack.monsters': '%s' has attack_level %d, above force_pack_max_attack_level %d" % [id, int(raw.get("attack_level", 0)), limit])


static func _skills(v: DataValidatorRules, skills: Variant, area: String, ctx: Dictionary) -> void:
	if not ctx["has_nodes"]:  # a raw without `encounters/nodes.json` (unit fixtures): nothing to compare with
		return
	var allowed: Array = (ctx["nodes"] as Dictionary).get(area, []) as Array
	for skill: Variant in (skills as Array if skills is Array else ([] if skills == null else [skills])):
		if not allowed.has(str(skill)):
			v.fail("field 'done_when.args.skill_id': '%s' is not a node discipline of area '%s'" % [skill, area])
