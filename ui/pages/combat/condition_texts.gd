class_name ConditionTexts
extends RefCounted
## Texts and icons of the combat conditions (GDD M28 §40.3) for the chips on the enemy cards and the Ward strip of the player. Italian.

const ICON_PATH: String = "res://assets/icons/conditions/%s.svg"
const BLEED_TEXT: String = "%s · %s"
const PERCENT_LOSS_TEXT: String = "-%s%% · %s"
const PERCENT_GAIN_TEXT: String = "+%s%% · %s"
const WARD_TEXT: String = "Riparo %s · %s"
const TIP_BLEED_TEXT: String = "Sanguinamento: %s danni ancora da subire."
const TIP_WEAKEN_TEXT: String = "Fiacchezza: il suo danno cala del %s%%."
const TIP_EXPOSE_TEXT: String = "Breccia: i tuoi colpi fanno il %s%% in più."
const TIP_STAGGER_TEXT: String = "Sbilanciamento: il suo prossimo attacco arriva più tardi."
const BLEED: StringName = &"bleed"
const WEAKEN: StringName = &"weaken"
const EXPOSE: StringName = &"expose"
const STAGGER: StringName = &"stagger"
const WARD: StringName = &"ward"


## Text of a chip: `data` = the entry of `get_state().enemies[i].conditions` for `id`; `tick_ms` = the Bleed tick (balance).
static func chip_text(id: StringName, data: Dictionary, tick_ms: int) -> String:
	match id:
		BLEED:
			return BLEED_TEXT % [NumberFormat.format_int(int(data["left"])),
					NumberFormat.format_seconds(int(data["ticks"]) * tick_ms)]
		WEAKEN:
			return PERCENT_LOSS_TEXT % [NumberFormat.format_number(float(data["pct"])),
					NumberFormat.format_seconds(int(data["ms"]))]
		EXPOSE:
			return PERCENT_GAIN_TEXT % [NumberFormat.format_number(float(data["pct"])),
					NumberFormat.format_seconds(int(data["ms"]))]
	return NumberFormat.format_seconds(int(data.get("ms", 0)))


## Tooltip of a chip.
static func chip_tip(id: StringName, data: Dictionary) -> String:
	match id:
		BLEED:
			return TIP_BLEED_TEXT % NumberFormat.format_int(int(data["left"]))
		WEAKEN:
			return TIP_WEAKEN_TEXT % NumberFormat.format_number(float(data["pct"]))
		EXPOSE:
			return TIP_EXPOSE_TEXT % NumberFormat.format_number(float(data["pct"]))
	return TIP_STAGGER_TEXT


## "Riparo 35 · 4,2 s" from `get_state().ward`.
static func ward_text(ward: Dictionary) -> String:
	return WARD_TEXT % [NumberFormat.format_int(int(ward["amount"])), NumberFormat.format_seconds(int(ward["ms"]))]


static func icon(id: StringName) -> Texture2D:
	return load(ICON_PATH % id) as Texture2D
