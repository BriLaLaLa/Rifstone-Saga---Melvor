class_name DataValidatorTraits
extends RefCounted
## Fifth part of DataValidator (internal, not API for other modules): the `traits` and `abilities` of a class file
## (docs/04_DATA_SCHEMA.md §14, effect types of F-81, ability kinds of F-80), plus the `traits`/`abilities` keys of
## balance.json (F-78). Written with the toolkit of DataValidatorRules.

const TRAIT_FIELDS: PackedStringArray = ["id", "name", "description", "unlock_level", "setups", "effects", "modifiers"]
const ABILITY_FIELDS: PackedStringArray = ["id", "name", "description", "unlock_level", "setups", "kind", "cooldown_ms",
	"params"]
const EFFECT_FIELDS: PackedStringArray = ["type", "params"]
const TARGET_RULES: PackedStringArray = ["first", "lowest_hp", "highest_hp"]  # F-76
const ABILITY_KINDS: PackedStringArray = ["strike", "cleave", "heal", "buff"]
# Stats `stat_trade` can scale: the ones that feed a combat number (F-81 map, CombatantStats.scale_stat).
const STAT_TRADE_STATS: PackedStringArray = ["accuracy_bonus", "accuracy_pct", "evasion_bonus", "evasion_pct",
	"power_bonus", "power_pct", "max_hp_flat", "armor", "barrier", "block_chance"]
const SLOT_LEVEL_KEYS: PackedStringArray = ["traits.slot_levels", "abilities.slot_levels"]
# Format limits (not design values) of the parameters.
const NTH_MAX: int = 20
const MULT_MAX: float = 10.0
const BUFF_MIN_DURATION_MS: int = 1000
const SLOT_COUNT_MAX: int = 8

static var _id_regex: RegEx = RegEx.create_from_string(DataValidatorRules.ID_PATTERN)


static func validate_class_lists(v: DataValidatorRules, c: Dictionary) -> void:
	var setup_ids: Dictionary[String, bool] = _setup_ids(c)
	var seen: Dictionary[StringName, bool] = {}
	var traits: Array[Dictionary] = v.object_list(c, "traits")
	for index: int in traits.size():
		_trait(v, traits[index], index, setup_ids, seen)
	seen = {}
	var abilities: Array[Dictionary] = v.object_list(c, "abilities")
	for index: int in abilities.size():
		_ability(v, abilities[index], index, setup_ids, seen)


static func _setup_ids(c: Dictionary) -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	for setup: Variant in (c["setups"] as Array if c.get("setups") is Array else []):
		if setup is Dictionary and (setup as Dictionary).get("id") is String:
			ids[(setup as Dictionary)["id"] as String] = true
	return ids


# The fields shared by traits and abilities; the entries are named by their list and index (`traits[2].id`).
static func _common(v: DataValidatorRules, e: Dictionary, prefix: String, setup_ids: Dictionary[String, bool],
		seen: Dictionary[StringName, bool], allowed: PackedStringArray) -> void:
	v.keys(e, allowed, prefix)
	if v.text(e, "id", prefix):
		var id: StringName = StringName(e["id"] as String)
		if _id_regex.search(String(id)) == null:
			v.fail("field '%s.id': '%s' does not match %s" % [prefix, id, DataValidatorRules.ID_PATTERN])
		if seen.has(id):
			v.fail("field '%s.id': duplicate '%s'" % [prefix, id])
		seen[id] = true
	v.text(e, "name", prefix)
	v.text(e, "description", prefix)
	v.integer(e, "unlock_level", 1, v.max_character_level, prefix)
	for setup: Variant in v.id_list(e, "setups", null, "", 0, prefix):
		if not setup_ids.has(str(setup)):
			v.fail("field '%s.setups': unknown setup '%s' of this class" % [prefix, setup])


static func _trait(v: DataValidatorRules, e: Dictionary, index: int, setup_ids: Dictionary[String, bool],
		seen: Dictionary[StringName, bool]) -> void:
	var prefix: String = "traits[%d]" % index
	_common(v, e, prefix, setup_ids, seen, TRAIT_FIELDS)
	var effects: Array[Dictionary] = v.object_list(e, "effects", prefix, 1)
	for effect_index: int in effects.size():
		_effect(v, effects[effect_index], "%s.effects[%d]" % [prefix, effect_index])
	v.modifiers(e, "modifiers", prefix)


static func _ability(v: DataValidatorRules, e: Dictionary, index: int, setup_ids: Dictionary[String, bool],
		seen: Dictionary[StringName, bool]) -> void:
	var prefix: String = "abilities[%d]" % index
	_common(v, e, prefix, setup_ids, seen, ABILITY_FIELDS)
	v.integer(e, "cooldown_ms", maxf(v.min_attack_interval_ms, 1), DataValidatorRules.NO_LIMIT, prefix)
	var kind_ok: bool = v.one_of(e, "kind", ABILITY_KINDS, prefix)
	var params: Dictionary = v.object(e, "params", prefix)
	if not kind_ok or not e.get("params") is Dictionary:
		return
	var at: String = prefix + ".params"
	match e["kind"]:
		"strike":
			v.keys(params, ["power_mult"], at)
			v.number(params, "power_mult", 0.0, MULT_MAX, at, true)
		"cleave":
			v.keys(params, ["power_mult", "targets"], at)
			v.number(params, "power_mult", 0.0, MULT_MAX, at, true)
			v.integer(params, "targets", 0, DataValidatorRules.NO_LIMIT, at)
		"heal":
			v.keys(params, ["heal_pct"], at)
			v.number(params, "heal_pct", 1.0, 100.0, at)
		"buff":
			v.keys(params, ["modifiers", "duration_ms"], at)
			v.modifiers(params, "modifiers", at)
			if params.get("modifiers") is Array and (params["modifiers"] as Array).is_empty():
				v.fail("field '%s.modifiers' needs at least 1 entries" % at)
			v.integer(params, "duration_ms", BUFF_MIN_DURATION_MS, DataValidatorRules.NO_LIMIT, at)


# One effect: its type must be one of F-81 and its params exactly those of the table, in range.
static func _effect(v: DataValidatorRules, effect: Dictionary, prefix: String) -> void:
	v.keys(effect, EFFECT_FIELDS, prefix)
	var params: Dictionary = v.object(effect, "params", prefix)
	if not v.text(effect, "type", prefix):
		return
	var at: String = prefix + ".params"
	match effect["type"]:
		"every_nth_attack_all":
			v.keys(params, ["n"], at)
			v.integer(params, "n", 2, NTH_MAX, at)
		"on_kill_timer_cut", "reflect_pct", "leech_pct":
			v.keys(params, ["pct"], at)
			v.number(params, "pct", 0.0, 100.0, at, true)
		"low_hp_damage_mult":
			v.keys(params, ["hp_pct", "mult", "no_auto_eat"], at)
			v.number(params, "hp_pct", 0.0, 100.0, at, true)
			v.number(params, "mult", 0.0, MULT_MAX, at, true)
			v.flag(params, "no_auto_eat", at)
		"stat_trade":
			v.keys(params, ["zero", "mult"], at)
			_stat_trade(v, params, at)
		"target_rule":
			v.keys(params, ["rule"], at)
			v.one_of(params, "rule", TARGET_RULES, at)
		"opening_strike":
			v.keys(params, [], at)
		_:
			v.fail("field '%s.type': unknown effect type '%s'" % [prefix, effect["type"]])


static func _stat_trade(v: DataValidatorRules, params: Dictionary, at: String) -> void:
	var zero: Array = v.id_list(params, "zero", null, "", 0, at)
	for stat: Variant in zero:
		if not v.stats.has(StringName(str(stat))):
			v.fail("field '%s.zero': stat '%s' is not in stats.json" % [at, stat])
		elif not STAT_TRADE_STATS.has(str(stat)):
			v.fail("field '%s.zero': stat '%s' has no combat effect (F-81)" % [at, stat])
	var mult: Dictionary = v.object(params, "mult", at)
	for stat: Variant in mult:
		var key: String = "%s.mult.%s" % [at, stat]
		if not v.stats.has(StringName(str(stat))):
			v.fail("field '%s': stat '%s' is not in stats.json" % [key, stat])
		elif not STAT_TRADE_STATS.has(str(stat)):
			v.fail("field '%s': stat '%s' has no combat effect (F-81)" % [key, stat])
		elif zero.has(str(stat)):
			v.fail("field '%s': stat '%s' is also in zero" % [key, stat])
		if not DataValidatorRules.is_number(mult[stat]) or float(mult[stat]) <= 0.0:
			v.fail("field '%s' must be a number > 0, got %s" % [key, JSON.stringify(mult[stat])])
	if zero.is_empty() and mult.is_empty():
		v.fail("field '%s' needs at least one stat in zero or mult" % at)


# balance.json `traits.slot_levels` / `abilities.slot_levels` (F-78): integers in 1..max character level, not decreasing.
static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	for key: String in SLOT_LEVEL_KEYS:
		var levels: Variant = DataValidator.lookup(balance, key)
		if not levels is Array:
			continue
		var list: Array = levels as Array
		if list.is_empty() or list.size() > SLOT_COUNT_MAX:
			v.fail("key '%s' needs 1..%d levels, got %d" % [key, SLOT_COUNT_MAX, list.size()])
		var last: int = 1
		for level: Variant in list:
			if not DataValidatorRules.is_int(level) or float(level) < float(last) or float(level) > v.max_character_level:
				v.fail("key '%s': levels must be integers in 1..%s, not decreasing, got %s"
						% [key, v.max_character_level, JSON.stringify(list)])
				break
			last = int(level)
