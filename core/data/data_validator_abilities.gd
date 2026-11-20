class_name DataValidatorAbilities
extends DataValidatorTraits
## The `abilities` of a class file (M28-02, split from DataValidatorTraits without changing the rules; docs/04_DATA_SCHEMA.md §14,
## ability kinds of F-80). Shares the fields of traits (`_common`) and the format limits with DataValidatorTraits.

const ABILITY_FIELDS: PackedStringArray = ["id", "name", "description", "unlock_level", "setups", "kind", "cooldown_ms",
	"params"]
const ABILITY_KINDS: PackedStringArray = ["strike", "cleave", "heal", "buff"]
const BUFF_MIN_DURATION_MS: int = 1000  # format limit (not a design value)


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
