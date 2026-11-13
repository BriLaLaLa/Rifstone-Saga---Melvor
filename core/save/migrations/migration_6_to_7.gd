extends RefCounted
## v6 -> v7 (M17-04, docs/05_INTERFACES.md §6): the ten narrow areas replace the four wide ones (docs/02_FORMULAS.md §8.5).
## All in `modules`:
## - `combat.area` (and `fractures.run.return_area`) that no longer names an area becomes the area that contains the level of the
##   character (the highest area whose `level_min` is not above it; level 1 when the xp is missing). An area that still exists is kept;
## - a fight in progress (`encounter`, `riftstone`, `between`) restarts as `between` with no enemies: the monsters of the old areas
##   have other stats. The Rift Stone fight is gone (no `wave`), the pending Monolith is cancelled and the counter starts again
##   (`stone` = {since: 0, pending: false, stone_id: ""}). Bag, kills, deaths, food and the Fracture state stay.
## The data come from res://data (areas.json, balance.json), like the migration of the other versions would read them if needed.

const AREAS_PATH: String = "res://data/combat/areas.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const FIGHT_STATES: Array[String] = ["encounter", "riftstone", "between"]


static func migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	var modules: Variant = out.get("modules")
	if not modules is Dictionary:
		return out
	var areas: Array[Dictionary] = _areas()
	var level: int = _character_level(modules as Dictionary)
	var combat: Variant = (modules as Dictionary).get("combat")
	if combat is Dictionary:
		_migrate_combat(combat as Dictionary, areas, level)
	var fractures: Variant = (modules as Dictionary).get("fractures")
	if fractures is Dictionary and (fractures as Dictionary).get("run") is Dictionary:
		var run: Dictionary = (fractures as Dictionary)["run"]
		if run.get("return_area") is String and not (run["return_area"] as String).is_empty():
			run["return_area"] = _valid_area(run["return_area"] as String, areas, level)
	return out


static func _migrate_combat(combat: Dictionary, areas: Array[Dictionary], level: int) -> void:
	if combat.get("area") is String and not (combat["area"] as String).is_empty():
		combat["area"] = _valid_area(combat["area"] as String, areas, level)
	if FIGHT_STATES.has(str(combat.get("state", ""))):
		combat["state"] = "between"
		combat["enemies"] = []
		combat["effects"] = {}
	combat.erase("wave")
	var stone: Dictionary = combat["stone"] if combat.get("stone") is Dictionary else {}
	stone["since"] = 0
	stone["pending"] = false
	stone["stone_id"] = ""
	combat["stone"] = stone


## `id` if the area still exists, else the area of `level`.
static func _valid_area(id: String, areas: Array[Dictionary], level: int) -> String:
	for area: Dictionary in areas:
		if area.get("id") == id:
			return id
	return area_for_level(areas, level)


## The id of the highest area whose `level_min` is not above `level` ("" if there are no areas).
static func area_for_level(areas: Array[Dictionary], level: int) -> String:
	var best: String = ""
	var best_min: int = -1
	for area: Dictionary in areas:
		var low: int = int(area.get("level_min", 0))
		if low <= level and low > best_min:
			best = str(area.get("id", ""))
			best_min = low
	return best


static func _areas() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(AREAS_PATH))
	if raw is Dictionary and (raw as Dictionary).get("areas") is Array:
		for a: Variant in ((raw as Dictionary)["areas"] as Array):
			if a is Dictionary:
				result.append(a as Dictionary)
	return result


static func _character_level(modules: Dictionary) -> int:
	var character: Variant = modules.get("character")
	var xp: int = 0
	if character is Dictionary and ((character as Dictionary).get("xp") is int or (character as Dictionary).get("xp") is float):
		xp = maxi(0, int((character as Dictionary)["xp"]))
	var balance: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	if not balance is Dictionary or not (balance as Dictionary).get("character_curve") is Dictionary:
		return 1
	return maxi(1, DataBuildUtil.curve(balance as Dictionary, "character_curve").level_for_xp(xp))
