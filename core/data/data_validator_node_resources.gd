class_name DataValidatorNodeResources
extends RefCounted
## Resource tables of the nodes (internal, M35B; docs/04_DATA_SCHEMA_M35B.md §36.1-§36.2, docs/02_FORMULAS_M35B.md F-200, F-201): `resources` of
## every node entry of data/encounters/nodes.json, the reachability of every gathering action and `encounters.resource_profile`.

const RESOURCE_FIELDS: PackedStringArray = ["action", "weight"]
const PROFILE_FIELDS: PackedStringArray = ["offset", "weight"]
const PERCENT_TOTAL: int = 100
const PROFILE_SIZE: int = 4
const PROFILE_OFFSET_LIMIT: int = 3


## `{action id: {"skill": StringName, "level": int}}` of the raw actions files (the skill is the one of the file).
static func action_index(raw: Dictionary) -> Dictionary[StringName, Dictionary]:
	var result: Dictionary[StringName, Dictionary] = {}
	var files: Dictionary = raw.get("actions", {}) as Dictionary
	for path: Variant in files:
		var content: Dictionary = files[path] as Dictionary
		for a: Variant in (content.get("actions", []) as Array):
			if a is Dictionary and (a as Dictionary).get("id") is String and DataValidatorRules.is_int((a as Dictionary).get("level")):
				result[StringName((a as Dictionary)["id"] as String)] = {"skill": StringName(str(content.get("skill", ""))),
						"level": int((a as Dictionary)["level"])}
	return result


## `resources` of a node entry (the caller checked `skill`): non-empty, actions of the discipline, unique, increasing levels, weights >= 1 summing to 100.
static func node(v: DataValidatorRules, entry: Dictionary, actions: Dictionary[StringName, Dictionary]) -> void:
	var skill_id: StringName = StringName(str(entry.get("skill", "")))
	var rows: Array[Dictionary] = v.object_list(entry, "resources", "nodes", 1)
	var seen: Dictionary[StringName, bool] = {}
	var total: int = 0
	var last_level: int = -1
	for row: Dictionary in rows:
		v.keys(row, RESOURCE_FIELDS, "nodes.resources")
		var weight_ok: bool = v.integer(row, "weight", 1, DataValidatorRules.NO_LIMIT, "nodes.resources")
		if weight_ok:
			total += int(row["weight"])
		if not row.get("action") is String:
			v.fail("field 'nodes.resources.action' must be a string")
			continue
		var action_id: StringName = StringName(row["action"] as String)
		if not actions.has(action_id):
			v.fail("field 'nodes.resources.action': unknown action '%s'" % action_id)
			continue
		if actions[action_id]["skill"] != skill_id:
			v.fail("field 'nodes.resources.action': '%s' is not an action of '%s'" % [action_id, skill_id])
		if seen.has(action_id):
			v.fail("duplicate resource '%s' in the table of '%s'" % [action_id, skill_id])
		seen[action_id] = true
		var level: int = int(actions[action_id]["level"])
		if level <= last_level:
			v.fail("the resources of '%s' must be in order of increasing level ('%s' has level %d after %d)" % [skill_id, action_id, level, last_level])
		last_level = maxi(last_level, level)
	if not rows.is_empty() and total != PERCENT_TOTAL:
		v.fail("the weights of the resources of '%s' must sum to %d, got %d" % [skill_id, PERCENT_TOTAL, total])


## Strict (real data): every action of a skill that has nodes appears in the table of at least one area (F-201: reachable).
static func reachability(v: DataValidatorRules, raw: Dictionary, actions: Dictionary[StringName, Dictionary]) -> void:
	var reached: Dictionary[StringName, bool] = {}
	var skills: Dictionary[StringName, bool] = {}
	var files: Dictionary = raw.get("encounters", {}) as Dictionary
	for path: Variant in files:
		for area: Variant in ((files[path] as Dictionary).get("areas", []) as Array):
			for entry: Variant in ((area as Dictionary).get("nodes", []) as Array) if area is Dictionary else []:
				if not entry is Dictionary:
					continue
				skills[StringName(str((entry as Dictionary).get("skill", "")))] = true
				for row: Variant in ((entry as Dictionary).get("resources", []) as Array) if (entry as Dictionary).get("resources") is Array else []:
					if row is Dictionary and (row as Dictionary).get("action") is String:
						reached[StringName((row as Dictionary)["action"] as String)] = true
	v.at_file("section 'encounters'")
	for action_id: StringName in actions:
		if skills.has(actions[action_id]["skill"]) and not reached.has(action_id):
			v.fail("action '%s' is in the resource table of no area (unreachable)" % action_id)


## `encounters.resource_profile` (optional here, read only by tools/gen_nodes.gd): 4 objects `{offset, weight}`, unique integer offsets -3..3, weights >= 1.
static func profile(v: DataValidatorRules, e: Dictionary) -> void:
	if not e.has("resource_profile"):
		return
	var rows: Array[Dictionary] = v.object_list(e, "resource_profile", "encounters", PROFILE_SIZE)
	if e["resource_profile"] is Array and (e["resource_profile"] as Array).size() != PROFILE_SIZE:
		v.fail("field 'encounters.resource_profile' must have %d entries" % PROFILE_SIZE)
	var seen: Dictionary[int, bool] = {}
	for row: Dictionary in rows:
		v.keys(row, PROFILE_FIELDS, "encounters.resource_profile")
		if v.integer(row, "offset", -PROFILE_OFFSET_LIMIT, PROFILE_OFFSET_LIMIT, "encounters.resource_profile"):
			if seen.has(int(row["offset"])):
				v.fail("field 'encounters.resource_profile.offset': duplicate offset %d" % int(row["offset"]))
			seen[int(row["offset"])] = true
		v.integer(row, "weight", 1, DataValidatorRules.NO_LIMIT, "encounters.resource_profile")
