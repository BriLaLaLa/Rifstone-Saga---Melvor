extends RefCounted
## TEMPORARY bridge for the data tests until the M4 content (M4-02) is merged: the real balance.json is still the
## pre-reform one, so the tests that load it with the new fixtures read a patched copy. Every function is a no-op
## once data/config/balance.json has the M4 keys of 02_FORMULAS.md §9 (then this file can be deleted).

const CONFIG_ROOT: String = "res://data/config"
const M4_CONFIG_TMP: String = "user://m4_config_tmp"


## `balance` with the M4 keys added where missing and the keys removed by the reform dropped.
static func m4_balance(balance: Dictionary) -> Dictionary:
	var result: Dictionary = balance.duplicate(true)
	var combat: Dictionary = result.get("combat", {}) as Dictionary
	for old_key: String in ["hp_skill", "defence_skill", "hp_per_vitality", "xp_per_damage_style",
			"xp_per_damage_vitality"]:
		combat.erase(old_key)
	var defaults: Dictionary = {
		"hp_per_level": 10, "dual_wield": {"interval_mult": 0.75}, "max_pack_size": 6,
	}
	for key: String in defaults:
		if not combat.has(key):
			combat[key] = defaults[key]
	result["combat"] = combat
	var top: Dictionary = {
		"character_curve": {"base": 70, "growth": 1.1, "linear": 8, "max_level": 99, "xp_cap": 50000000},
		"character": {"start_class": "rift_blade"},
		"armory": {"base_slots": 40, "slot_cost_base": 1000, "slot_cost_growth": 1.12, "slot_cost_cap": 2000000},
		"rarity": {
			"craft": {"magic_base_pct": 10, "magic_per_mastery_level": 0.4, "rare_base_pct": 1,
					"rare_per_mastery_level": 0.1},
			"affix_count": {"magic": [1, 2], "rare": [3, 4]},
		},
	}
	for key: String in top:
		if not result.has(key):
			result[key] = top[key]
	return result


## A config root whose balance.json has the M4 keys (see m4_balance): the real one if already up to date, otherwise a
## copy under user:// (stats.json is copied as it is). TEMPORARY, same as m4_balance.
static func config_root() -> String:
	var errors: PackedStringArray = []
	var balance: Variant = JsonLoader.load_file(CONFIG_ROOT.path_join(GameData.BALANCE_FILE), errors)
	if not balance is Dictionary or JSON.stringify(m4_balance(balance as Dictionary)) == JSON.stringify(balance):
		return CONFIG_ROOT
	DirAccess.make_dir_recursive_absolute(M4_CONFIG_TMP)
	var file: FileAccess = FileAccess.open(M4_CONFIG_TMP.path_join(GameData.BALANCE_FILE), FileAccess.WRITE)
	file.store_string(JSON.stringify(m4_balance(balance as Dictionary), "  "))
	file.close()
	DirAccess.copy_absolute(CONFIG_ROOT.path_join(GameData.STATS_FILE), M4_CONFIG_TMP.path_join(GameData.STATS_FILE))
	return M4_CONFIG_TMP
