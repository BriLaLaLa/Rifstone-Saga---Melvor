extends RefCounted
## v9 -> v10 (M26-06, docs/05_INTERFACES_M26.md §6d, docs/01_GDD_M26.md §38.7): crafting recipes become schemes. In `modules`, only
## `disciplines.recipes` grows (no reagent, no purchase, no xp, no mastery change):
## 1. a scheme of the frozen historic list (V10_SCHEMES) whose skill is learned and whose level is not above the skill level is known;
## 2. a scheme that appears in `actions.jobs` is known;
## 3. a scheme unknown to the current data is skipped (Log.warn); known recipes are never duplicated.
## Levels and skills of the actions come from res://data/actions, the xp curve from balance.json (like migration_7_to_8.gd).

const Frozen := preload("res://core/save/migrations/migration_7_to_8.gd")
const ACTIONS_DIR: String = "res://data/actions"
const LOG_CATEGORY: String = "save"
## Frozen historic list of the 28 schemes (not read from the data).
const V10_SCHEMES: Array[String] = [
	"forge_ashlead_plate", "forge_stormzinc_plate", "forge_duskcobalt_plate", "forge_glimmerite_plate",
	"forge_palecinnabar_plate", "forge_emberheart_plate", "forge_riftite_plate",
	"carve_ashpine_shieldcore", "carve_thornalder_shieldcore", "carve_duskelm_shieldcore", "carve_shardcedar_shieldcore",
	"carve_veilcypress_shieldcore", "carve_emberlarch_shieldcore", "carve_riftspruce_shieldcore",
	"carve_ashpine_handle", "carve_thornalder_handle", "carve_duskelm_handle", "carve_shardcedar_handle",
	"carve_veilcypress_handle", "carve_emberlarch_handle", "carve_riftspruce_handle",
	"cook_ashgill", "cook_redscale", "cook_dusk_eel", "cook_shard_gar", "cook_mist_barbel", "cook_ember_sturgeon", "cook_riftmaw",
]


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary:
		return out
	var m: Dictionary = modules
	if not m.get("disciplines") is Dictionary:
		m["disciplines"] = {"learned": {}, "recipes": [], "extra": []}
	var disciplines: Dictionary = m["disciplines"]
	if not disciplines.get("learned") is Dictionary:
		disciplines["learned"] = {}
	if not disciplines.get("recipes") is Array:
		disciplines["recipes"] = []
	var recipes: Array = disciplines["recipes"]
	var learned: Dictionary = disciplines["learned"]
	var defs: Dictionary = _action_defs()
	var curve: XpTable = Frozen._xp_table()
	var queued: Array[String] = _queued(m)
	for id: String in V10_SCHEMES:
		if not defs.has(id):
			Log.warn(LOG_CATEGORY, "migration 9->10: scheme '%s' is not in the data: skipped" % id)
			continue
		if recipes.has(id):
			continue
		var def: Dictionary = defs[id]
		var skill: String = str(def["skill"])
		var reached: bool = false
		if int(learned.get(skill, 0)) >= 1 and curve != null:
			reached = curve.level_for_xp(Frozen._xp_of(m, skill)) >= int(def["level"])
		if reached or queued.has(id):
			recipes.append(id)
	return out


static func _queued(m: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var actions: Variant = m.get("actions")
	if actions is Dictionary and (actions as Dictionary).get("jobs") is Array:
		for job: Variant in (actions as Dictionary)["jobs"] as Array:
			if job is Dictionary:
				result.append(str((job as Dictionary).get("action", "")))
	return result


# Action id -> {"skill", "level"} of every action in res://data/actions.
static func _action_defs() -> Dictionary:
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at(ACTIONS_DIR):
		if not file.ends_with(".json"):
			continue
		var raw: Variant = Frozen._read_json(ACTIONS_DIR.path_join(file))
		if not raw is Dictionary or not (raw as Dictionary).get("actions") is Array:
			continue
		var skill: String = str((raw as Dictionary).get("skill", ""))
		for a: Variant in (raw as Dictionary)["actions"] as Array:
			if a is Dictionary:
				result[str((a as Dictionary).get("id", ""))] = {"skill": skill, "level": (a as Dictionary).get("level", 1)}
	return result
