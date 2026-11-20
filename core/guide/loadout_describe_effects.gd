class_name LoadoutDescribeEffects
extends RefCounted
## Texts of the M28 effect types of the traits (docs/02_FORMULAS_M28.md F-192, the combat types of F-120 allowed in the traits)
## and of the new ability params (`hits`, `target`, `execute`, `apply`, `drain_pct`, kind `ward`; 04_DATA_SCHEMA_M28.md §33.3).
## Part of LoadoutDescribe, kept apart to stay small. Every number comes from the params; the texts are in Italian.

const CONDITION_NAMES: Dictionary[StringName, String] = {
	&"bleed": "Sanguinamento",
	&"weaken": "Fiacchezza",
	&"expose": "Breccia",
	&"stagger": "Sbilanciamento",
	&"ward": "Riparo",
}
const APPLY_TEXTS: Dictionary[StringName, String] = {
	&"bleed": "Sanguinamento (il %s%% del danno del colpo, a scatti, in %s)",
	&"weaken": "Fiacchezza (il suo danno cala del %s%% per %s)",
	&"expose": "Breccia (i tuoi colpi fanno il %s%% in più per %s)",
}
const STAGGER_APPLY_TEXT: String = "Sbilanciamento (il suo prossimo attacco arriva %s più tardi)"
const GAIN_TEXTS: Dictionary[String, String] = {
	"kill": "Ogni uccisione", "hit": "Ogni colpo a segno", "block": "Ogni parata", "evade": "Ogni schivata",
}
const LOSE_TEXTS: Dictionary[String, String] = {
	"damaged": " Si azzera quando perdi PV.",
	"encounter": " Si azzera a ogni incontro.",
	"none": " Non si azzera mai.",
}
const WARD_EVENT_TEXTS: Dictionary[String, String] = {
	"kill": "Ogni uccisione", "block": "Ogni parata", "encounter_start": "A inizio incontro",
}
const KIND_TEXTS: Dictionary[String, String] = {
	"strike": "di colpo singolo", "cleave": "ad area", "heal": "di cura", "ward": "di Riparo",
}
const RIPOSTE_ON_TEXTS: Dictionary[String, String] = {"block": "Quando pari", "evade": "Quando schivi"}
const STACK_DAMAGE_TEXT: String = "%s dà +%s%% di danno, fino a %d cumuli.%s"
const STACK_HASTE_TEXT: String = "%s accorcia del %s%% l'attesa tra i tuoi attacchi, fino a %d cumuli.%s"
const FOCUS_COMBO_TEXT: String = "Ogni colpo base a segno di fila sullo stesso nemico dà +%s%% di danno, fino a %d colpi."
const RIPOSTE_TEXT: String = "%s, contrattacchi subito con il %s%% del danno."
const DAMAGE_TRADE_TEXT: String = "Infliggi il %s%% di danno in più, ma ne subisci il %s%% in più."
const APPLY_ON_HIT_TEXT: String = "%s applica %s."
const EVERY_TEXT: String = "Ogni %d° colpo base a segno"
const EVERY_FIRST_TEXT: String = "Ogni colpo base a segno"
const STATUS_MULT_TEXT: String = "Contro i nemici con %s: +%s%% di danno."
const COOLDOWN_CUT_TEXT: String = "Ogni uccisione accorcia di %s le ricariche delle abilità."
const AFTER_ABILITY_TEXT: String = "Dopo aver usato un'abilità, il danno del colpo base successivo è moltiplicato per %s."
const WARD_ON_TEXT: String = "%s ti dà un Riparo pari al %s%% dei PV massimi per %s."
const ABILITY_MULT_TEXT: String = "Abilità %s: +%s%% di effetto."
const LONE_TARGET_TEXT: String = "+%s%% di danno quando c'è un solo nemico vivo."
const EXECUTE_TEXT: String = "Sotto il %s%% dei PV del bersaglio il danno è moltiplicato per %s."
const HIT_CAP_TEXT: String = "Un colpo subito non ti toglie più del %s%% dei PV massimi."
const PIERCE_TEXT: String = "I tuoi attacchi ignorano il %s%% della riduzione del bersaglio."
const KILL_HEAL_TEXT: String = "Ogni uccisione ti cura del %s%% dei PV massimi."
const BLOCK_HEAL_TEXT: String = "Ogni parata ti cura del %s%% dei PV massimi."
const CONVERT_TEXT: String = "Converte il %s%% di %s in %s."
const DOUBLE_HIT_TEXT: String = "Il %s%% delle volte il colpo base ne porta un secondo."
const STRIKE_TEXT: String = "Colpisce %s con il %s%% della potenza."
const HITS_TEXT: String = "Colpisce %s %d volte, ognuna con il %s%% della potenza."
const EXECUTE_ABILITY_TEXT: String = " Sotto il %s%% dei PV del bersaglio il danno è moltiplicato per %s."
const APPLY_ABILITY_TEXT: String = " Applica: %s."
const DRAIN_TEXT: String = " Recuperi il %s%% del danno inflitto in PV."
const WARD_TEXT: String = "Ti dà un Riparo pari al %s%% dei PV massimi per %s."
const TARGET_NAMES: Dictionary[String, String] = {
	"first": "il primo nemico", "lowest_hp": "il nemico con meno PV", "highest_hp": "il nemico con più PV",
}
const LIST_SEPARATOR: String = ", "
const APPLY_SEPARATOR: String = "; "


## Text of an effect of the M28 types or of the F-120 combat types; "" if `type` is none of them.
static func effect_text(type: StringName, p: Dictionary, data: GameData) -> String:
	match type:
		&"stack_damage":
			return STACK_DAMAGE_TEXT % [GAIN_TEXTS.get(str(p["gain"]), ""), _n(p["pct"]), int(p["max"]),
					LOSE_TEXTS.get(str(p["lose"]), "")]
		&"stack_haste":
			return STACK_HASTE_TEXT % [GAIN_TEXTS.get(str(p["gain"]), ""), _n(p["pct"]), int(p["max"]),
					LOSE_TEXTS.get(str(p["lose"]), "")]
		&"focus_combo":
			return FOCUS_COMBO_TEXT % [_n(p["pct"]), int(p["max"])]
		&"riposte":
			return RIPOSTE_TEXT % [RIPOSTE_ON_TEXTS.get(str(p["on"]), ""), _n(float(p["mult"]) * 100.0)]
		&"damage_trade":
			return DAMAGE_TRADE_TEXT % [_n(p["dealt_pct"]), _n(p["taken_pct"])]
		&"apply_on_hit":
			var every: int = int(p["every"])
			return APPLY_ON_HIT_TEXT % [EVERY_TEXT % every if every > 1 else EVERY_FIRST_TEXT,
					apply_text(ConditionApply.from_dict(p))]
		&"status_damage_mult":
			return STATUS_MULT_TEXT % [CONDITION_NAMES.get(StringName(str(p["condition"])), ""), _n(p["pct"])]
		&"kill_cooldown_cut":
			return COOLDOWN_CUT_TEXT % NumberFormat.format_seconds(int(p["ms"]))
		&"after_ability_mult":
			return AFTER_ABILITY_TEXT % _n(p["mult"])
		&"ward_on":
			return WARD_ON_TEXT % [WARD_EVENT_TEXTS.get(str(p["on"]), ""), _n(p["pct"]),
					NumberFormat.format_seconds(int(p["ms"]))]
		&"ability_mult":
			var kinds: PackedStringArray = PackedStringArray()
			for kind: Variant in p["kinds"] as Array:
				kinds.append(KIND_TEXTS.get(str(kind), ""))
			return ABILITY_MULT_TEXT % [LIST_SEPARATOR.join(kinds), _n(p["pct"])]
		&"lone_target_mult":
			return LONE_TARGET_TEXT % _n(p["pct"])
		&"execute_mult":
			return EXECUTE_TEXT % [_n(p["hp_pct"]), _n(p["mult"])]
		&"hit_cap_pct":
			return HIT_CAP_TEXT % _n(p["pct"])
		&"armor_pierce_pct":
			return PIERCE_TEXT % _n(p["pct"])
		&"kill_heal_pct":
			return KILL_HEAL_TEXT % _n(p["pct"])
		&"block_heal_pct":
			return BLOCK_HEAL_TEXT % _n(p["pct"])
		&"stat_convert":
			return CONVERT_TEXT % [_n(p["pct"]), _stat(p["from"], data), _stat(p["to"], data)]
		&"double_hit_pct":
			return DOUBLE_HIT_TEXT % _n(p["pct"])
	return ""


## One condition application ("Sanguinamento (il 30% del danno del colpo, a scatti, in 4,0 s)"); "" for a null one.
static func apply_text(app: ConditionApply) -> String:
	if app == null:
		return ""
	if app.condition == ConditionApply.STAGGER:
		return STAGGER_APPLY_TEXT % NumberFormat.format_seconds(app.ms)
	return APPLY_TEXTS.get(app.condition, "") % [_n(app.pct), NumberFormat.format_seconds(app.ms)]


## Sentence of a strike: its target and the number of hits, `power_text` = power of every hit in %.
static func strike_text(def: AbilityDef, power_text: String) -> String:
	var who: String = TARGET_NAMES.get(str(def.target_rule), TARGET_NAMES["first"])
	if def.hits > 1:
		return HITS_TEXT % [who, def.hits, power_text]
	return STRIKE_TEXT % [who, power_text]


## Ward ability text.
static func ward_text(def: AbilityDef) -> String:
	return WARD_TEXT % [_n(def.ward_pct), NumberFormat.format_seconds(def.duration_ms)]


## Extra sentences of a strike or cleave: execute, applied conditions, drain (each starts with a space).
static func ability_extras(def: AbilityDef) -> String:
	var text: String = ""
	if def.execute_hp_pct > 0.0:
		text += EXECUTE_ABILITY_TEXT % [_n(def.execute_hp_pct), _n(def.execute_mult)]
	if not def.applies.is_empty():
		var parts: PackedStringArray = PackedStringArray()
		for app: ConditionApply in def.applies:
			parts.append(apply_text(app))
		text += APPLY_ABILITY_TEXT % APPLY_SEPARATOR.join(parts)
	if def.drain_pct > 0.0:
		text += DRAIN_TEXT % _n(def.drain_pct)
	return text


static func _n(value: Variant) -> String:
	return NumberFormat.format_number(float(value))


static func _stat(stat: Variant, data: GameData) -> String:
	return str(data.stats.info(StringName(str(stat))).get("name", stat))
