class_name DataValidatorTraits
extends RefCounted
## Fifth part of DataValidator (internal, not API for other modules): the `traits` and `abilities` of a class file
## (docs/04_DATA_SCHEMA.md §14, effect types of F-81, ability kinds of F-80), plus the `traits`/`abilities` keys of
## balance.json (F-78). Written with the toolkit of DataValidatorRules.

const TRAIT_FIELDS: PackedStringArray = ["id", "name", "description", "unlock_level", "setups", "effects", "modifiers"]
const EFFECT_FIELDS: PackedStringArray = ["type", "params"]
const TARGET_RULES: PackedStringArray = ["first", "lowest_hp", "highest_hp"]  # F-76
# Stats `stat_trade` can scale: the ones that feed a combat number (F-81 map, CombatantStats.scale_stat).
const STAT_TRADE_STATS: PackedStringArray = ["accuracy_bonus", "accuracy_pct", "evasion_bonus", "evasion_pct",
	"power_bonus", "power_pct", "max_hp_flat", "armor", "barrier", "block_chance"]
const SLOT_LEVEL_KEYS: PackedStringArray = ["traits.slot_levels", "abilities.slot_levels"]
# M28 (docs/04_DATA_SCHEMA_M28.md §33.4): the types of F-192, the combat types of F-120 allowed in a trait, the ones with a state.
const M28_TYPES: PackedStringArray = ["stack_damage", "stack_haste", "focus_combo", "riposte", "damage_trade", "apply_on_hit",
	"status_damage_mult", "kill_cooldown_cut", "after_ability_mult", "ward_on", "ability_mult", "lone_target_mult"]
const STATE_TYPES: PackedStringArray = ["every_nth_attack_all", "stack_damage", "stack_haste", "focus_combo", "apply_on_hit",
	"after_ability_mult"]
const EFFECT_STACK_GAINS: PackedStringArray = ["kill", "hit", "block", "evade"]
const EFFECT_STACK_LOSES: PackedStringArray = ["damaged", "encounter", "none"]
const EFFECT_REACTIONS: PackedStringArray = ["block", "evade"]
const EFFECT_WARD_EVENTS: PackedStringArray = ["kill", "block", "encounter_start"]
const EFFECT_CONDITIONS: PackedStringArray = ["bleed", "weaken", "expose", "stagger"]
const EFFECT_MULT_KINDS: PackedStringArray = ["strike", "cleave", "heal", "ward"]
const EFFECT_STACK_PCT_MAX: float = 50.0
const EFFECT_STACK_MAX: int = 20
const EFFECT_PCT_MAX: float = 200.0
const EFFECT_MS_MAX: int = 60000
# Format limits (not design values) of the parameters.
const NTH_MAX: int = 20
const MULT_MAX: float = 10.0
const SLOT_COUNT_MAX: int = 8

static var _id_regex: RegEx = RegEx.create_from_string(DataValidatorRules.ID_PATTERN)


static func validate_class_lists(v: DataValidatorRules, c: Dictionary) -> void:
	var setup_ids: Dictionary[String, bool] = _setup_ids(c)
	var seen: Dictionary[StringName, bool] = {}
	var traits: Array[Dictionary] = v.object_list(c, "traits")
	for index: int in traits.size():
		_trait(v, traits[index], index, setup_ids, seen)


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
	var stateful: int = 0
	for effect_index: int in effects.size():
		_effect(v, effects[effect_index], "%s.effects[%d]" % [prefix, effect_index])
		if STATE_TYPES.has(effects[effect_index].get("type")):
			stateful += 1
	if stateful > 1:
		v.fail("field '%s.effects': at most one effect with a state per trait, got %d" % [prefix, stateful])
	v.modifiers(e, "modifiers", prefix)


## One effect `{"type", "params"}` of F-81 (also used by the effects of the legendaries, DataValidatorLegendary).
static func validate_effect(v: DataValidatorRules, effect: Dictionary, prefix: String) -> void:
	_effect(v, effect, prefix)


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
		"block_heal_pct", "kill_heal_pct", "armor_pierce_pct", "double_hit_pct", "hit_cap_pct", "stat_convert", "execute_mult":
			_combat_f120(v, str(effect["type"]), params, at)
		"gather_bonus_item", "gather_grade_up_pct", "byproduct_mult", "monolith_loot_mult", "card_drop_mult":
			v.fail("field '%s.type': '%s' (gathering, Monolith and Card effects) is not allowed in a trait" % [prefix, effect["type"]])
		_:
			if M28_TYPES.has(effect["type"]):
				_m28_effect(v, str(effect["type"]), params, at)
			else:
				v.fail("field '%s.type': unknown effect type '%s'" % [prefix, effect["type"]])


# The combat types of F-120 in a trait, with the intervals of F-120 (the same as in a legendary, whose shape is flat).
static func _combat_f120(v: DataValidatorRules, type: String, params: Dictionary, at: String) -> void:
	match type:
		"hit_cap_pct":
			v.keys(params, ["pct"], at)
			v.number(params, "pct", 1.0, 100.0, at)
		"stat_convert":
			v.keys(params, ["from", "to", "pct"], at)
			v.number(params, "pct", 0.0, 100.0, at, true)
			for key: String in ["from", "to"]:
				if not v.text(params, key, at):
					continue
				if not v.stats.has(StringName(params[key] as String)):
					v.fail("field '%s.%s': stat '%s' is not in stats.json" % [at, key, params[key]])
				elif not STAT_TRADE_STATS.has(params[key]):
					v.fail("field '%s.%s': stat '%s' has no combat effect" % [at, key, params[key]])
			if params.get("from") is String and params.get("from") == params.get("to"):
				v.fail("field '%s': 'from' and 'to' must differ" % at)
		"execute_mult":
			v.keys(params, ["hp_pct", "mult"], at)
			v.number(params, "hp_pct", 0.0, 100.0, at, true)
			v.number(params, "mult", 1.0, MULT_MAX, at, true)
		_:
			v.keys(params, ["pct"], at)
			v.number(params, "pct", 0.0, 100.0, at, true)


# The types of F-192 (§33.4); the ranges are format limits, not design values.
static func _m28_effect(v: DataValidatorRules, type: String, params: Dictionary, at: String) -> void:
	match type:
		"stack_damage", "stack_haste":
			v.keys(params, ["gain", "pct", "max", "lose"], at)
			v.one_of(params, "gain", EFFECT_STACK_GAINS, at)
			v.number(params, "pct", 0.0, EFFECT_STACK_PCT_MAX, at, true)
			v.integer(params, "max", 1, EFFECT_STACK_MAX, at)
			v.one_of(params, "lose", EFFECT_STACK_LOSES, at)
		"focus_combo":
			v.keys(params, ["pct", "max"], at)
			v.number(params, "pct", 0.0, EFFECT_STACK_PCT_MAX, at, true)
			v.integer(params, "max", 1, EFFECT_STACK_MAX, at)
		"riposte":
			v.keys(params, ["on", "mult"], at)
			v.one_of(params, "on", EFFECT_REACTIONS, at)
			v.number(params, "mult", 0.0, MULT_MAX, at, true)
		"damage_trade":
			v.keys(params, ["dealt_pct", "taken_pct"], at)
			v.number(params, "dealt_pct", 0.0, EFFECT_PCT_MAX, at, true)
			v.number(params, "taken_pct", 0.0, EFFECT_PCT_MAX, at, true)
		"apply_on_hit":
			v.keys(params, ["every", "condition", "pct", "ms"], at)
			v.integer(params, "every", 1, NTH_MAX, at)
			_effect_condition(v, params, at)
		"status_damage_mult":
			v.keys(params, ["condition", "pct"], at)
			v.one_of(params, "condition", EFFECT_CONDITIONS, at)
			v.number(params, "pct", 0.0, EFFECT_PCT_MAX, at, true)
		"kill_cooldown_cut":
			v.keys(params, ["ms"], at)
			v.integer(params, "ms", 1, EFFECT_MS_MAX, at)
		"after_ability_mult":
			v.keys(params, ["mult"], at)
			v.number(params, "mult", 1.0, MULT_MAX, at, true)
		"ward_on":
			v.keys(params, ["on", "pct", "ms"], at)
			v.one_of(params, "on", EFFECT_WARD_EVENTS, at)
			v.number(params, "pct", 0.0, 100.0, at, true)
			v.integer(params, "ms", 1000, EFFECT_MS_MAX, at)
		"ability_mult":
			v.keys(params, ["kinds", "pct"], at)
			v.number(params, "pct", 0.0, EFFECT_PCT_MAX, at, true)
			var seen: Dictionary[String, bool] = {}
			for kind: Variant in v.id_list(params, "kinds", null, "", 1, at):
				if not EFFECT_MULT_KINDS.has(str(kind)):
					v.fail("field '%s.kinds': '%s' is not one of %s" % [at, kind, EFFECT_MULT_KINDS])
				elif seen.has(str(kind)):
					v.fail("field '%s.kinds': duplicate '%s'" % [at, kind])
				seen[str(kind)] = true
		"lone_target_mult":
			v.keys(params, ["pct"], at)
			v.number(params, "pct", 0.0, EFFECT_PCT_MAX, at, true)


# The application of a condition at the level of the params (§33.2): `pct` only for the conditions that have one.
static func _effect_condition(v: DataValidatorRules, params: Dictionary, at: String) -> void:
	if not v.one_of(params, "condition", EFFECT_CONDITIONS, at):
		return
	match params["condition"]:
		"stagger":
			if params.has("pct"):
				v.fail("field '%s.pct': a stagger has no pct" % at)
			v.integer(params, "ms", 100, 5000, at)
		"bleed":
			v.number(params, "pct", 0.0, 300.0, at, true)
			v.integer(params, "ms", 1000, EFFECT_MS_MAX, at)
		"weaken":
			v.number(params, "pct", 0.0, 90.0, at, true)
			v.integer(params, "ms", 1000, EFFECT_MS_MAX, at)
		_:
			v.number(params, "pct", 0.0, 100.0, at, true)
			v.integer(params, "ms", 1000, EFFECT_MS_MAX, at)


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
