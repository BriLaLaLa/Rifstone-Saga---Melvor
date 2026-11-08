class_name LoadoutDescribe
extends RefCounted
## Descriptions of the traits and abilities of a class built from their data (effects, params, modifiers, cooldown,
## setups), so every number shown comes from `data/classes/<id>.json` and `stats.json` (docs/01_GDD.md §19, F-81).
## The `description` field of the data is not used here: it is flavour text and could drift from the numbers.

const EVERY_NTH_TEXT: String = "Ogni %s attacco colpisce tutti i nemici."
const OPENING_STRIKE_TEXT: String = "Il primo colpo di ogni incontro parte subito."
const KILL_TIMER_CUT_TEXT: String = "Ogni uccisione riduce del %s%% l'attesa del colpo successivo."
const TARGET_TEXTS: Dictionary[String, String] = {
	"first": "Mira al primo nemico.",
	"lowest_hp": "Mira sempre al nemico con meno PV.",
	"highest_hp": "Mira per primo al nemico con più PV.",
}
const LOW_HP_TEXT: String = "Sotto il %s%% dei PV il danno è moltiplicato per %s."
const NO_AUTO_EAT_TEXT: String = " Smetti di mangiare."
const TRADE_ZERO_TEXT: String = "Azzera: %s."
const TRADE_MULT_TEXT: String = "Moltiplica per %s: %s."
const REFLECT_TEXT: String = "Chi ti colpisce perde il %s%% del danno che ti infligge."
const LEECH_TEXT: String = "Recuperi il %s%% del danno inflitto in PV."
const BONUS_TEXT: String = "Bonus: %s."
const STAT_VALUE_TEXT: String = "%s %s"
const STRIKE_TEXT: String = "Colpisce il primo nemico con il %s%% della potenza."
const CLEAVE_ALL_TEXT: String = "Colpisce tutti i nemici con il %s%% della potenza."
const CLEAVE_TEXT: String = "Colpisce i primi %d nemici con il %s%% della potenza."
const HEAL_TEXT: String = "Cura il %s%% dei PV."
const BUFF_TEXT: String = "Per %s: %s."
const COOLDOWN_TEXT: String = "Ricarica: %s"
const SETUPS_TEXT: String = "Assetto: %s"
const ANY_SETUP_TEXT: String = "Assetto: qualsiasi"
const UNKNOWN_EFFECT_TEXT: String = "Effetto speciale."
const LIST_SEPARATOR: String = ", "
const PCT_FACTOR: float = 100.0


## Text of a trait: what each effect does, its stat bonuses and the setups that allow it.
static func trait_text(def: TraitDef, data: GameData, class_def: ClassDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for effect: TraitEffectDef in def.effects:
		parts.append(_effect_text(effect, data))
	if not def.modifiers.is_empty():
		parts.append(BONUS_TEXT % LIST_SEPARATOR.join(_modifier_texts(def.modifiers, data)))
	return " ".join(parts) + "\n" + _setups_text(def.setups, class_def)


## Text of an ability: what it does, its cooldown and the setups that allow it.
static func ability_text(def: AbilityDef, data: GameData, class_def: ClassDef) -> String:
	var what: String = ""
	match def.kind:
		AbilityDef.KIND_STRIKE:
			what = STRIKE_TEXT % _pct(def.power_mult * PCT_FACTOR)
		AbilityDef.KIND_CLEAVE:
			what = CLEAVE_ALL_TEXT % _pct(def.power_mult * PCT_FACTOR) if def.targets <= 0 \
					else CLEAVE_TEXT % [def.targets, _pct(def.power_mult * PCT_FACTOR)]
		AbilityDef.KIND_HEAL:
			what = HEAL_TEXT % _pct(def.heal_pct)
		AbilityDef.KIND_BUFF:
			what = BUFF_TEXT % [NumberFormat.format_seconds(def.duration_ms),
					LIST_SEPARATOR.join(_modifier_texts(def.modifiers, data))]
		_:
			what = UNKNOWN_EFFECT_TEXT
	return "%s\n%s · %s" % [what, COOLDOWN_TEXT % NumberFormat.format_seconds(def.cooldown_ms),
			_setups_text(def.setups, class_def)]


static func _effect_text(effect: TraitEffectDef, data: GameData) -> String:
	var p: Dictionary = effect.params
	match effect.type:
		&"every_nth_attack_all":
			return EVERY_NTH_TEXT % ("%d°" % int(p["n"]))
		&"opening_strike":
			return OPENING_STRIKE_TEXT
		&"on_kill_timer_cut":
			return KILL_TIMER_CUT_TEXT % _pct(float(p["pct"]))
		&"target_rule":
			return TARGET_TEXTS.get(str(p["rule"]), UNKNOWN_EFFECT_TEXT)
		&"low_hp_damage_mult":
			return LOW_HP_TEXT % [_pct(float(p["hp_pct"])), NumberFormat.format_number(float(p["mult"]))] \
					+ (NO_AUTO_EAT_TEXT if bool(p.get("no_auto_eat", false)) else "")
		&"stat_trade":
			return _trade_text(p, data)
		&"reflect_pct":
			return REFLECT_TEXT % _pct(float(p["pct"]))
		&"leech_pct":
			return LEECH_TEXT % _pct(float(p["pct"]))
	return UNKNOWN_EFFECT_TEXT


static func _trade_text(p: Dictionary, data: GameData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var zero: PackedStringArray = PackedStringArray()
	for stat: Variant in p.get("zero", []) as Array:
		zero.append(_stat_name(StringName(str(stat)), data))
	if not zero.is_empty():
		parts.append(TRADE_ZERO_TEXT % LIST_SEPARATOR.join(zero))
	var mult: Dictionary = p.get("mult", {}) as Dictionary
	for stat: Variant in mult:
		parts.append(TRADE_MULT_TEXT % [NumberFormat.format_number(float(mult[stat])),
				_stat_name(StringName(str(stat)), data)])
	return " ".join(parts)


static func _modifier_texts(modifiers: Array[Modifier], data: GameData) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for modifier: Modifier in modifiers:
		var info: Dictionary = data.stats.info(modifier.stat)
		var sign_text: String = "+" if modifier.value >= 0.0 else ""
		var suffix: String = "%" if str(info.get("format", "")) == "pct" else ""
		texts.append(STAT_VALUE_TEXT % [_stat_name(modifier.stat, data),
				sign_text + NumberFormat.format_number(modifier.value) + suffix])
	return texts


static func _setups_text(setup_ids: Array[StringName], class_def: ClassDef) -> String:
	if setup_ids.is_empty() or class_def == null:
		return ANY_SETUP_TEXT
	var names: PackedStringArray = PackedStringArray()
	for setup: SetupDef in class_def.setups:
		if setup_ids.has(setup.id):
			names.append(setup.name)
	return SETUPS_TEXT % LIST_SEPARATOR.join(names)


static func _stat_name(stat: StringName, data: GameData) -> String:
	return str(data.stats.info(stat).get("name", stat))


static func _pct(value: float) -> String:
	return NumberFormat.format_number(value)


## "Stat +N, Stat +N%" for a list of modifiers (labels from the stat registry).
static func modifiers_text(modifiers: Array[Modifier], data: GameData) -> String:
	return LIST_SEPARATOR.join(_modifier_texts(modifiers, data))
