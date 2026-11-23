class_name DataValidatorToolHeads
extends RefCounted
## Part of DataValidator (internal): `equip.heads` of a unique tool and the M35 keys of `tool_upgrade` (docs/04_DATA_SCHEMA_M35.md §35.1, §35.2).
## `heads` is checked when present; it is not yet required (the real data gets it in M35-D2, which then makes it mandatory).

const HEAD_COUNT: int = 2
const HEAD_STEPS: int = 3  # = the length of `tool_upgrade.head_steps`
const MAX_NAME: int = 24
const MAX_DESCRIPTION: int = 80
const STEP_STATS: PackedStringArray = ["node_units_pct", "node_rich_pct", "byproduct_chance_pct", "double_item_chance", "rift_shard_chance"]


## The `heads` of an `equip` object: exactly 2 heads with a unique snake_case id, a name and a description, and one non-empty list of
## `{stat, value}` per head step (the scope is not written: the loader sets it).
static func heads(v: DataValidatorRules, equip: Dictionary) -> void:
	if not equip.has("heads"):
		return
	var list: Array[Dictionary] = v.object_list(equip, "heads", "equip")
	if (equip["heads"] as Array).size() != HEAD_COUNT:
		v.fail("field 'equip.heads' needs exactly %d heads, got %d" % [HEAD_COUNT, (equip["heads"] as Array).size()])
	var seen: Dictionary[String, bool] = {}
	for index: int in list.size():
		var prefix: String = "equip.heads[%d]" % index
		var head: Dictionary = list[index]
		v.keys(head, ["id", "name", "description", "steps"], prefix)
		if v.text(head, "id", prefix):
			if seen.has(head["id"] as String):
				v.fail("field '%s.id': '%s' is given twice" % [prefix, head["id"]])
			seen[head["id"] as String] = true
		_text(v, head, "name", MAX_NAME, prefix)
		_text(v, head, "description", MAX_DESCRIPTION, prefix)
		_steps(v, head, prefix)


static func _text(v: DataValidatorRules, head: Dictionary, key: String, max_length: int, prefix: String) -> void:
	if v.text(head, key, prefix) and (head[key] as String).length() > max_length:
		v.fail("field '%s.%s' is longer than %d characters" % [prefix, key, max_length])


static func _steps(v: DataValidatorRules, head: Dictionary, prefix: String) -> void:
	if not head.get("steps") is Array:
		v.fail("field '%s.steps' must be a list" % prefix)
		return
	var steps: Array = head["steps"] as Array
	if steps.size() != HEAD_STEPS:
		v.fail("field '%s.steps' needs exactly %d lists (one per head step), got %d" % [prefix, HEAD_STEPS, steps.size()])
	for index: int in steps.size():
		var at: String = "%s.steps[%d]" % [prefix, index]
		var holder: Dictionary = {"steps": steps[index]}
		if not steps[index] is Array or (steps[index] as Array).is_empty():
			v.fail("field '%s' needs a non-empty list of modifiers" % at)
			continue
		var mods: Array[Dictionary] = v.object_list(holder, "steps", prefix)
		for m_index: int in mods.size():
			var m: Dictionary = mods[m_index]
			v.keys(m, ["stat", "value"], "%s[%d]" % [at, m_index])
			if not STEP_STATS.has(str(m.get("stat"))):
				v.fail("field '%s[%d].stat': '%s' is not a stat of a head" % [at, m_index, m.get("stat")])
			elif not v.stats.has(StringName(m["stat"] as String)):
				v.fail("field '%s[%d].stat': stat '%s' is not in stats.json" % [at, m_index, m["stat"]])
			else:
				v.number(m, "value", 0.0, float(v.stats.info(StringName(m["stat"] as String))["max"]), "%s[%d]" % [at, m_index], true)


## `units_per_level_pct`, `head_steps` and `respec_pct` of `tool_upgrade` (checked when present; `levels` must already be a list).
static func balance(v: DataValidatorRules, tool_upgrade: Dictionary) -> void:
	if tool_upgrade.has("units_per_level_pct"):
		v.integer(tool_upgrade, "units_per_level_pct", 0.0, DataValidatorRules.NO_LIMIT, "tool_upgrade")
	if tool_upgrade.has("respec_pct"):
		v.integer(tool_upgrade, "respec_pct", 0.0, 100.0, "tool_upgrade")
	if not tool_upgrade.has("head_steps"):
		return
	var steps: Variant = tool_upgrade["head_steps"]
	if not steps is Array or (steps as Array).size() != HEAD_STEPS:
		v.fail("field 'tool_upgrade.head_steps' must be a list of %d steps" % HEAD_STEPS)
		return
	var previous: int = 0
	for step: Variant in steps as Array:
		if not DataValidatorRules.is_int(step) or int(step) <= previous or int(step) > DataValidatorM10.TOOL_STEPS:
			v.fail("field 'tool_upgrade.head_steps' must be increasing integers in 1..%d" % DataValidatorM10.TOOL_STEPS)
			return
		previous = int(step)


## The balance keys this file checks (`tool_upgrade.*` of M35), for the unknown-key rule of DataValidator.
static func is_known_key(path: String) -> bool:
	return path in ["tool_upgrade.units_per_level_pct", "tool_upgrade.head_steps", "tool_upgrade.respec_pct"]
