extends RefCounted
## v7 -> v8 (M24-03, docs/05_INTERFACES_M24.md §6b, docs/01_GDD_M24.md §35.10): Disciplines and the production queue replace the
## helpers, the Contracts and the action lane. All in `modules`:
## 1. `helpers` is removed;
## 2. the twelve Contracts (historic ids, below) leave `bank.stacks`, `combat.loot.stacks`, the `stacks` of the bags of `fractures`
##    and `dungeon` (run and pending) and `discoveries.items`;
## 3. `disciplines.learned`: for `gathering` and for `artisan` at most `disciplines.max_per_category` skills with `discipline` and
##    xp > 0 are learned (the artisan skill of the lane in progress first, even with 0 xp, then by decreasing xp, ties by `order`),
##    each at the smallest grade whose cap is not below its level (F-158); `recipes` is empty;
## 4. the disciplines not learned lose their `skills` and `mastery` entries (xp 0); the Incisore is untouched;
## 5. `actions`: from {"lanes": {"main": ...}} to {"jobs", "elapsed_ms"}: gathering in progress gives no job; a recipe of a learned
##    skill gives a job that repeats until the ingredients run out; a blueprint craft gives a started project (`consumed`);
## 6. `combat` is unchanged (the engine loads the old `between` as a full travel, M24-04).
## The data come from res://data (skills.json, balance.json, trainers.json), like migration_6_to_7.gd.

const SKILLS_PATH: String = "res://data/skills/skills.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const TRAINERS_PATH: String = "res://data/disciplines/trainers.json"
const CONTRACT_KINDS: Array[String] = ["forestry", "quarrying", "angling"]
const CONTRACT_GRADES: Array[String] = ["apprentice", "journeyman", "expert", "master"]
const CATEGORIES: Array[String] = ["gathering", "artisan"]
const BLUEPRINT_ACTION: String = "blueprint_craft"


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary:
		return out
	var m: Dictionary = modules
	m.erase("helpers")
	_remove_contracts(m)
	var skills: Array[Dictionary] = _skill_defs()
	var lane: Dictionary = _main_lane(m)
	var learned: Dictionary = _learn(m, skills, _grade_caps(), _max_per_category(), lane)
	m["disciplines"] = {"learned": learned, "recipes": []}
	_drop_unlearned(m, skills, learned)
	m["actions"] = _jobs(lane, skills, learned)
	return out


## The historic ids of the twelve Contracts.
static func contract_ids() -> Array[String]:
	var ids: Array[String] = []
	for kind: String in CONTRACT_KINDS:
		for grade: String in CONTRACT_GRADES:
			ids.append("contract_%s_%s" % [kind, grade])
	return ids


static func _remove_contracts(m: Dictionary) -> void:
	var ids: Array[String] = contract_ids()
	_filter_stacks(m.get("bank"), ids)
	var combat: Variant = m.get("combat")
	if combat is Dictionary:
		_filter_stacks(combat.get("loot"), ids)
	for key: String in ["fractures", "dungeon"]:
		var module: Variant = m.get(key)
		if not module is Dictionary:
			continue
		var run: Variant = (module as Dictionary).get("run")
		if run is Dictionary:
			_filter_stacks((run as Dictionary).get("bag"), ids)
		_filter_stacks((module as Dictionary).get("pending"), ids)
	var discoveries: Variant = m.get("discoveries")
	if discoveries is Dictionary and (discoveries as Dictionary).get("items") is Array:
		var kept: Array = []
		for id: Variant in (discoveries as Dictionary)["items"] as Array:
			if not ids.has(str(id)):
				kept.append(id)
		(discoveries as Dictionary)["items"] = kept


# Removes from `holder.stacks` (an Array of {"item": id, ...}) the entries naming one of `ids`.
static func _filter_stacks(holder: Variant, ids: Array[String]) -> void:
	if not holder is Dictionary or not (holder as Dictionary).get("stacks") is Array:
		return
	var kept: Array = []
	for entry: Variant in (holder as Dictionary)["stacks"] as Array:
		if not (entry is Dictionary and ids.has(str((entry as Dictionary).get("item", "")))):
			kept.append(entry)
	(holder as Dictionary)["stacks"] = kept


# {"skill", "action", ...} of the lane `main`; {} when idle.
static func _main_lane(m: Dictionary) -> Dictionary:
	var actions: Variant = m.get("actions")
	if actions is Dictionary and (actions as Dictionary).get("lanes") is Dictionary:
		var main: Variant = ((actions as Dictionary)["lanes"] as Dictionary).get("main")
		if main is Dictionary:
			return main
	return {}


# The learned disciplines {skill: grade} (rule 3).
static func _learn(m: Dictionary, skills: Array[Dictionary], caps: Array[int], max_per: int, lane: Dictionary) -> Dictionary:
	var curve: XpTable = _xp_table()
	var learned: Dictionary = {}
	for category: String in CATEGORIES:
		var candidates: Array[Dictionary] = []
		for def: Dictionary in skills:
			if def.get("discipline", false) != true or def.get("category") != category:
				continue
			var xp: int = _xp_of(m, str(def["id"]))
			var in_progress: bool = category == "artisan" and str(lane.get("skill", "")) == str(def["id"])
			if xp > 0 or in_progress:
				candidates.append({"id": str(def["id"]), "xp": xp, "order": int(def.get("order", 0)), "first": in_progress})
		candidates.sort_custom(_before)
		for entry: Dictionary in candidates.slice(0, max_per):
			learned[entry["id"]] = _grade_for(curve.level_for_xp(int(entry["xp"])) if curve != null else 1, caps)
	return learned


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["first"] != b["first"]:
		return a["first"]
	if a["xp"] != b["xp"]:
		return int(a["xp"]) > int(b["xp"])
	return int(a["order"]) < int(b["order"])


# The smallest grade (1-based) whose cap is not below `level`; the last one above all caps.
static func _grade_for(level: int, caps: Array[int]) -> int:
	for i: int in caps.size():
		if caps[i] >= level:
			return i + 1
	return maxi(caps.size(), 1)


# Rule 4: the entries of the disciplines not learned disappear.
static func _drop_unlearned(m: Dictionary, skills: Array[Dictionary], learned: Dictionary) -> void:
	for def: Dictionary in skills:
		var id: String = str(def["id"])
		if def.get("discipline", false) != true or learned.has(id):
			continue
		for key: String in ["skills", "mastery"]:
			if m.get(key) is Dictionary:
				(m[key] as Dictionary).erase(id)


# Rule 5.
static func _jobs(lane: Dictionary, skills: Array[Dictionary], learned: Dictionary) -> Dictionary:
	var result: Dictionary = {"jobs": [], "elapsed_ms": 0}
	var skill_id: String = str(lane.get("skill", ""))
	var def: Dictionary = {}
	for s: Dictionary in skills:
		if str(s["id"]) == skill_id:
			def = s
	if def.is_empty() or def.get("category") != "artisan":
		return result
	if def.get("discipline", false) == true and not learned.has(skill_id):
		return result
	var elapsed: int = maxi(0, int(lane.get("elapsed_ms", 0)))
	if lane.has("blueprint"):
		result["jobs"] = [{"skill": skill_id, "action": BLUEPRINT_ACTION, "blueprint": str(lane["blueprint"]),
				"chosen_affix": str(lane.get("chosen_affix", "")), "duration_ms": int(lane.get("duration_ms", 0)), "consumed": true}]
	else:
		result["jobs"] = [{"skill": skill_id, "action": str(lane.get("action", "")), "remaining": 0, "repeat": true}]
	result["elapsed_ms"] = elapsed
	return result


static func _xp_of(m: Dictionary, skill_id: String) -> int:
	var skills: Variant = m.get("skills")
	if skills is Dictionary and (skills as Dictionary).get(skill_id) is Dictionary:
		var xp: Variant = ((skills as Dictionary)[skill_id] as Dictionary).get("xp")
		if xp is int or xp is float:
			return maxi(0, int(xp))
	return 0


static func _skill_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = _read_json(SKILLS_PATH)
	if raw is Dictionary and (raw as Dictionary).get("skills") is Array:
		for s: Variant in (raw as Dictionary)["skills"] as Array:
			if s is Dictionary:
				result.append(s as Dictionary)
	return result


static func _grade_caps() -> Array[int]:
	var caps: Array[int] = []
	var raw: Variant = _read_json(TRAINERS_PATH)
	if raw is Dictionary and (raw as Dictionary).get("grades") is Array:
		for g: Variant in (raw as Dictionary)["grades"] as Array:
			if g is Dictionary and ((g as Dictionary).get("cap") is int or (g as Dictionary).get("cap") is float):
				caps.append(int((g as Dictionary)["cap"]))
	return caps


static func _max_per_category() -> int:
	var balance: Variant = _read_json(BALANCE_PATH)
	if balance is Dictionary and (balance as Dictionary).get("disciplines") is Dictionary:
		return int(((balance as Dictionary)["disciplines"] as Dictionary)["max_per_category"])
	Log.error("save", "balance.json has no disciplines.max_per_category: no discipline is learned")
	return 0


static func _xp_table() -> XpTable:
	var balance: Variant = _read_json(BALANCE_PATH)
	if not balance is Dictionary or not (balance as Dictionary).get("xp_curve") is Dictionary:
		return null
	return DataBuildUtil.curve(balance as Dictionary, "xp_curve")


static func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
