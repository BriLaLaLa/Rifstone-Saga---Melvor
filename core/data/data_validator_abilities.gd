class_name DataValidatorAbilities
extends DataValidatorTraits
## The `abilities` of a class file (M28-02, split from DataValidatorTraits; docs/04_DATA_SCHEMA.md §14, ability kinds of F-80;
## M28-04: docs/04_DATA_SCHEMA_M28.md §33.2-§33.3, F-191). Shares the fields of traits (`_common`) and the format limits with
## DataValidatorTraits.

const ABILITY_FIELDS: PackedStringArray = ["id", "name", "description", "unlock_level", "setups", "kind", "cooldown_ms",
	"params"]
const ABILITY_KINDS: PackedStringArray = ["strike", "cleave", "heal", "buff", "ward"]
const BUFF_MIN_DURATION_MS: int = 1000  # format limit (not a design value)
# Format limits of the M28 parameters (§33.3, §33.2).
const HITS_MAX: int = 5
const APPLY_MAX: int = 3
const EXECUTE_FIELDS: PackedStringArray = ["hp_pct", "mult"]
const APPLY_CONDITIONS: PackedStringArray = ["bleed", "weaken", "expose", "stagger"]
const APPLY_PCT_MAX: Dictionary = {"bleed": 300.0, "weaken": 90.0, "expose": 100.0}
const APPLY_MS_RANGE: Dictionary = {"stagger": Vector2(100.0, 5000.0)}  # the others: APPLY_MS_DEFAULT
const APPLY_MS_DEFAULT: Vector2 = Vector2(1000.0, 60000.0)
const WARD_MIN_DURATION_MS: int = 1000
const WARD_MAX_DURATION_MS: int = 60000


## Hooked in `DataValidator.validate` right after `DataValidatorClasses.validate_classes` (same message context: file and class).
static func validate_classes(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	for path: String in files:
		v.at_file(path)
		var c: Dictionary = files[path]
		v.at_entry("class", 0, c)
		var setup_ids: Dictionary[String, bool] = _setup_ids(c)
		var seen: Dictionary[StringName, bool] = {}
		var abilities: Array[Dictionary] = v.object_list(c, "abilities")
		for index: int in abilities.size():
			_ability(v, abilities[index], index, setup_ids, seen)


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
			v.keys(params, ["power_mult", "hits", "target", "execute", "apply", "drain_pct"], at)
			v.number(params, "power_mult", 0.0, MULT_MAX, at, true)
			if params.has("hits"):
				v.integer(params, "hits", 1, HITS_MAX, at)
			if params.has("target"):
				v.one_of(params, "target", TARGET_RULES, at)
			_power_extras(v, params, at)
		"cleave":
			v.keys(params, ["power_mult", "targets", "execute", "apply", "drain_pct"], at)
			v.number(params, "power_mult", 0.0, MULT_MAX, at, true)
			v.integer(params, "targets", 0, DataValidatorRules.NO_LIMIT, at)
			_power_extras(v, params, at)
		"heal":
			v.keys(params, ["heal_pct"], at)
			v.number(params, "heal_pct", 1.0, 100.0, at)
		"buff":
			v.keys(params, ["modifiers", "duration_ms"], at)
			v.modifiers(params, "modifiers", at)
			if params.get("modifiers") is Array and (params["modifiers"] as Array).is_empty():
				v.fail("field '%s.modifiers' needs at least 1 entries" % at)
			v.integer(params, "duration_ms", BUFF_MIN_DURATION_MS, DataValidatorRules.NO_LIMIT, at)
		"ward":
			v.keys(params, ["ward_pct", "duration_ms"], at)
			v.number(params, "ward_pct", 1.0, 100.0, at)
			v.integer(params, "duration_ms", WARD_MIN_DURATION_MS, WARD_MAX_DURATION_MS, at)


# `execute`, `apply` and `drain_pct` (strike and cleave, §33.3).
static func _power_extras(v: DataValidatorRules, params: Dictionary, at: String) -> void:
	if params.has("execute"):
		var execute: Dictionary = v.object(params, "execute", at)
		v.keys(execute, EXECUTE_FIELDS, at + ".execute")
		v.number(execute, "hp_pct", 0.0, 100.0, at + ".execute", true)
		v.number(execute, "mult", 1.0, MULT_MAX, at + ".execute", true)
	if params.has("apply"):
		var entries: Array[Dictionary] = v.object_list(params, "apply", at, 1)
		if entries.size() > APPLY_MAX:
			v.fail("field '%s.apply' needs at most %d entries" % [at, APPLY_MAX])
		var seen: Dictionary[String, bool] = {}
		for index: int in entries.size():
			var entry_at: String = "%s.apply[%d]" % [at, index]
			apply_entry(v, entries[index], entry_at)
			var condition: String = str(entries[index].get("condition", ""))
			if seen.has(condition):
				v.fail("field '%s.condition': duplicate '%s'" % [entry_at, condition])
			seen[condition] = true
	if params.has("drain_pct"):
		v.number(params, "drain_pct", 0.0, 100.0, at, true)


## One application of a condition (§33.2), shared with `apply_on_hit` of the traits: `pct` and `ms` by condition, no other keys.
static func apply_entry(v: DataValidatorRules, e: Dictionary, at: String) -> void:
	v.keys(e, ["condition", "pct", "ms"], at)
	if not v.one_of(e, "condition", APPLY_CONDITIONS, at):
		return
	var condition: String = e["condition"]
	if condition == "stagger":
		if e.has("pct"):
			v.fail("unknown field '%s.pct'" % at)
	else:
		v.number(e, "pct", 0.0, APPLY_PCT_MAX[condition], at, true)
	var ms_range: Vector2 = APPLY_MS_RANGE.get(condition, APPLY_MS_DEFAULT)
	v.integer(e, "ms", ms_range.x, ms_range.y, at)
