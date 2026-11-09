class_name MapEffectLabels
extends RefCounted
## Italian names of the risk and reward types of the Card modifiers (F-111) and of the boss abilities (F-112), shared by the
## Fractures page, the Combat page and the generated tables of the Guide. Text only: the values always come from the data.

const LABELS: Dictionary[StringName, String] = {
	&"monster_hp_pct": "PV dei mostri",
	&"monster_damage_pct": "Danno dei mostri",
	&"monster_speed_pct": "Velocità d'attacco dei mostri",
	&"monster_defence_pct": "Evasione dei mostri",
	&"pack_bonus": "Mostri in più in ogni gruppo",
	&"food_heal_pct": "Cura del cibo",
	&"pulse": "Impulso periodico sui tuoi PV massimi",
	&"loot_qty_pct": "Quantità del bottino",
	&"item_rarity_pct": "Rarità dei pezzi",
	&"xp_pct": "XP del personaggio",
	&"gold_drop_pct": "Oro dai mostri",
	&"blueprint_pct": "Progetti",
	&"dust_pct": "Polvere del Rift",
	&"card_chance_pct": "Carte della Frattura",
}
## Types whose value is a decrease ("Cura del cibo -40%") and types whose value is not a percentage.
const DECREASES: Array[StringName] = [&"food_heal_pct"]
const PLAIN_NUMBERS: Array[StringName] = [&"pack_bonus"]

const ABILITY_NAMES: Dictionary[StringName, String] = {
	&"heavy_strike": "Colpo pesante",
	&"shield": "Scudo",
	&"summon": "Evocazione",
}
const RANGE_SEPARATOR: String = " - "


static func label(type: StringName) -> String:
	return LABELS.get(type, String(type))


static func ability_name(type: StringName) -> String:
	return ABILITY_NAMES.get(type, String(type))


## "PV dei mostri +40%", "Cura del cibo -40%", "Mostri in più in ogni gruppo +2".
static func line(type: StringName, value: float) -> String:
	return "%s %s" % [label(type), _signed(type, value)]


## "PV dei mostri +20% - +60%" for the range of a modifier.
static func range_line(type: StringName, min_value: float, max_value: float) -> String:
	return "%s %s%s%s" % [label(type), _signed(type, min_value), RANGE_SEPARATOR, _signed(type, max_value)]


static func _signed(type: StringName, value: float) -> String:
	var sign_text: String = "-" if DECREASES.has(type) else "+"
	var number: String = str(int(roundf(value)))
	return "%s%s" % [sign_text, number] if PLAIN_NUMBERS.has(type) else "%s%s%%" % [sign_text, number]
