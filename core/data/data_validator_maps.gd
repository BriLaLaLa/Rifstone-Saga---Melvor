class_name DataValidatorMaps
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the Card items (category `map`), the modifiers of
## data/maps/map_mods.json and the bosses of data/maps/bosses.json (docs/04_DATA_SCHEMA.md §11, M13). The balance
## section `fracture` is in DataValidatorFracture.
##
## The set rules ("10 Cards", "at least 12 modifiers", "4 distinct risk types per grade", "one boss per grade") always
## apply: empty lists are errors (the transitional exception of M13-01 was removed by M13-04).

const GRADE_COUNT: int = 10
const CARD_ID_PREFIX: String = "fracture_card_"
const MODS_MIN: int = 12
const RISKS_PER_GRADE_MIN: int = 4
const MOD_FIELDS: PackedStringArray = ["id", "name", "description", "min_grade", "weight", "risk", "reward"]
const EFFECT_FIELDS: PackedStringArray = ["type", "min", "max"]
## F-111: the closed lists of types. Stat-based rewards need their stat in stats.json.
const RISK_TYPES: PackedStringArray = ["monster_hp_pct", "monster_damage_pct", "monster_speed_pct",
	"monster_defence_pct", "pack_bonus", "food_heal_pct", "pulse"]
const REWARD_TYPES: PackedStringArray = ["loot_qty_pct", "item_rarity_pct", "xp_pct", "gold_drop_pct", "blueprint_pct",
	"dust_pct", "card_chance_pct"]
const REWARD_STATS: Dictionary[String, String] = {"item_rarity_pct": "item_rarity_pct", "xp_pct": "skill_xp_pct",
	"gold_drop_pct": "gold_drop_pct"}
const FOOD_HEAL_MAX_PCT: float = 100.0
const SPEED_MAX_PCT: float = 90.0
const BOSS_FIELDS: PackedStringArray = ["id", "name", "description", "icon", "hp", "xp", "style", "attack_interval_ms",
	"attack_level", "power_level", "defence_level", "accuracy_bonus", "power_bonus", "evasion_bonus", "damage_reduction",
	"gold", "rift_shard_chance", "drops", "sprite", "loot_tables", "grade", "ability", "rewards"]
const ABILITY_FIELDS: Dictionary = {
	"heavy_strike": ["type", "every_ms", "mult"],
	"shield": ["type", "every_ms", "duration_ms", "shield_pct"],
	"summon": ["type", "every_ms", "count", "max_alive", "monsters"],
}
const EVERY_MS_MIN: Dictionary[String, int] = {"heavy_strike": 2000, "shield": 4000, "summon": 4000}


# --- Cards (items of category `map`) ----------------------------------------------------------------------------

## The `map` sub-object of one item (the caller checked that the category wants it).
static func map_item(v: DataValidatorRules, e: Dictionary) -> void:
	v.keys(e["map"] as Dictionary, ["grade"], "map")
	if v.integer(e["map"] as Dictionary, "grade", 1, GRADE_COUNT, "map") and e.get("id") is String \
			and e["id"] != "%s%d" % [CARD_ID_PREFIX, int(e["map"]["grade"])]:
		v.fail("a Card id must be '%s<grade>'" % CARD_ID_PREFIX)
	if DataValidatorRules.is_int(e.get("value")) and int(e["value"]) != 0:
		v.fail("a Card must have value 0 (it cannot be sold)")


## One Card per grade 1..10.
static func validate_card_set(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var grades: Dictionary[int, bool] = {}
	for id: StringName in v.items:
		var e: Dictionary = v.items[id]
		if e.get("category") != "map" or not e.get("map") is Dictionary:
			continue
		var grade: Variant = (e["map"] as Dictionary).get("grade")
		if DataValidatorRules.is_int(grade):
			grades[int(grade)] = true
	v.at_file("section 'items'" if files.is_empty() else (files.keys()[0] as String).get_base_dir())
	for grade: int in range(1, GRADE_COUNT + 1):
		if not grades.has(grade):
			v.fail("missing the Card of grade %d (%s%d)" % [grade, CARD_ID_PREFIX, grade])


# --- map_mods.json ----------------------------------------------------------------------------------------------

static func validate_mods(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var mods: Array[Dictionary] = []
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "mods")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("map mod", index, e, seen, MOD_FIELDS)
			v.integer(e, "min_grade", 1, GRADE_COUNT)
			v.integer(e, "weight", 1)
			_effect(v, e, "risk", RISK_TYPES)
			_effect(v, e, "reward", REWARD_TYPES)
			mods.append(e)
	DataValidatorStep.validate_cap_candidates(v, mods)
	v.at_file(files.keys()[0] as String if not files.is_empty() else "map_mods.json")
	v.at_entry("map mods", 0, {})
	if mods.size() < MODS_MIN:
		v.fail("needs at least %d modifiers, got %d" % [MODS_MIN, mods.size()])
	for grade: int in range(1, GRADE_COUNT + 1):
		var risks: Dictionary[String, bool] = {}
		for e: Dictionary in mods:
			if DataValidatorRules.is_number(e.get("min_grade")) and int(e["min_grade"]) <= grade and e.get("risk") is Dictionary:
				risks[str((e["risk"] as Dictionary).get("type"))] = true
		if risks.size() < RISKS_PER_GRADE_MIN:
			v.fail("grade %d has %d distinct risk types, needs at least %d" % [grade, risks.size(), RISKS_PER_GRADE_MIN])


# The risk or reward object `key` of a modifier: closed type, 0 < min <= max, and the limits of some types.
static func _effect(v: DataValidatorRules, mod: Dictionary, key: String, types: PackedStringArray) -> void:
	var effect: Dictionary = v.object(mod, key)
	if not mod.get(key) is Dictionary:
		return
	v.keys(effect, EFFECT_FIELDS, key)
	var type_ok: bool = v.one_of(effect, "type", types, key)
	var min_ok: bool = v.number(effect, "min", 0.0, DataValidatorRules.NO_LIMIT, key, true)
	var max_ok: bool = v.number(effect, "max", 0.0, DataValidatorRules.NO_LIMIT, key, true)
	if min_ok and max_ok and float(effect["min"]) > float(effect["max"]):
		v.fail("field '%s': min must be <= max" % key)
	if not type_ok:
		return
	var type: String = effect["type"] as String
	if REWARD_STATS.has(type) and not v.stats.has(StringName(REWARD_STATS[type])):
		v.fail("field '%s.type': stat '%s' is not in stats.json" % [key, REWARD_STATS[type]])
	if not max_ok:
		return
	var top: float = float(effect["max"])
	if type == "pack_bonus":
		for field: String in ["min", "max"]:
			if DataValidatorRules.is_number(effect.get(field)) and not DataValidatorRules.is_int(effect[field]):
				v.fail("field '%s.%s': pack_bonus must be an integer" % [key, field])
		if v.max_pack_size != DataValidatorRules.NO_LIMIT and top > v.max_pack_size - 1.0:
			v.fail("field '%s.max': pack_bonus must be <= combat.max_pack_size - 1" % key)
	elif type == "food_heal_pct" and top > FOOD_HEAL_MAX_PCT:
		v.fail("field '%s.max': food_heal_pct must be <= %d" % [key, int(FOOD_HEAL_MAX_PCT)])
	elif type == "monster_speed_pct" and top > SPEED_MAX_PCT:
		v.fail("field '%s.max': monster_speed_pct must be <= %d" % [key, int(SPEED_MAX_PCT)])


# --- bosses.json ------------------------------------------------------------------------------------------------

static func validate_bosses(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var grades: Dictionary[int, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "bosses")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("boss", index, e, seen, BOSS_FIELDS)
			DataValidatorClasses.combat_fields(v, e)
			if v.integer(e, "grade", 1, GRADE_COUNT):
				if grades.has(int(e["grade"])):
					v.fail("duplicate boss grade %d" % int(e["grade"]))
				grades[int(e["grade"])] = true
			_ability(v, e)
			var rewards: Dictionary = v.object(e, "rewards")
			if e.get("rewards") is Dictionary:
				v.keys(rewards, ["dust"], "rewards")
				v.int_pair(rewards, "dust", 1, DataValidatorRules.NO_LIMIT, true, "rewards")
	v.at_file(files.keys()[0] as String if not files.is_empty() else "bosses.json")
	v.at_entry("bosses", 0, {})
	for grade: int in range(1, GRADE_COUNT + 1):
		if not grades.has(grade):
			v.fail("missing the boss of grade %d" % grade)


static func _ability(v: DataValidatorRules, boss: Dictionary) -> void:
	var ability: Dictionary = v.object(boss, "ability")
	if not boss.get("ability") is Dictionary:
		return
	if not v.one_of(ability, "type", PackedStringArray(ABILITY_FIELDS.keys()), "ability"):
		return
	var type: String = ability["type"] as String
	v.keys(ability, PackedStringArray(ABILITY_FIELDS[type]), "ability")
	var every_ok: bool = v.integer(ability, "every_ms", EVERY_MS_MIN[type], DataValidatorRules.NO_LIMIT, "ability")
	match type:
		"heavy_strike":
			v.number(ability, "mult", 1.2, 4.0, "ability")
		"shield":
			v.integer(ability, "duration_ms", 1000, float(ability["every_ms"]) if every_ok else DataValidatorRules.NO_LIMIT,
					"ability")
			v.integer(ability, "shield_pct", 5, 50, "ability")
		"summon":
			v.integer(ability, "count", 1, 3, "ability")
			var max_limit: float = 5.0
			if v.max_pack_size != DataValidatorRules.NO_LIMIT:
				max_limit = minf(max_limit, v.max_pack_size - 1.0)
			v.integer(ability, "max_alive", 1, max_limit, "ability")
			v.id_list(ability, "monsters", v.monsters, "monster", 1, "ability")
