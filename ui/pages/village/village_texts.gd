class_name VillageTexts
extends RefCounted
## Italian texts of the Village page (docs/01_GDD.md §30, docs/05_INTERFACES.md §7.t). Presentation only: no game number here.

const TITLE_TEXT: String = "Villaggio"
const GOLD_TEXT: String = "Oro: %s"
const BUILD_TEXT: String = "Costruisci"
const UPGRADE_TEXT: String = "Migliora"
const COMING_SOON_TEXT: String = "In arrivo"
const MAXED_TEXT: String = "Livello massimo"
const LEVEL_TEXT: String = "Livello %s/%s"
const EFFECT_NOW_TEXT: String = "Ora: %s"
const EFFECT_NEXT_TEXT: String = "Prossimo livello: %s"
## Buildings without a stat (the Market): the effect is this fixed line (docs/05_INTERFACES.md §7.s).
const FIXED_EFFECT_TEXT: String = "Sblocca nuove bancarelle"
const EFFECT_LINE_TEXT: String = "%s %s"
const COST_TITLE_TEXT: String = "Costo"
const COST_GOLD_TEXT: String = "Oro: %s / %s"
const COST_ITEM_TEXT: String = "%s: %s / %s"
const COST_MISSING_TEXT: String = " (mancano %s)"
const REQUIRES_WOODWRIGHT_TEXT: String = "Richiede Falegname %s"
## Reason of `can_upgrade` / `upgrade` -> text; other reasons: REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	&"unknown_id": "Edificio sconosciuto.",
	&"not_buildable": "Non ancora costruibile.",
	&"max_level": "Livello massimo raggiunto.",
	&"level_too_low": "Livello del Falegname troppo basso.",
	&"not_enough_gold": "Oro insufficiente.",
	&"not_enough_items": "Materiali insufficienti.",
}
## Map view (docs/01_GDD.md §32).
const VIEW_MAP_TEXT: String = "Mappa"
const VIEW_LIST_TEXT: String = "Elenco"
const NODE_UNBUILT_TEXT: String = "Da costruire"
const NODE_BUILDABLE_TEXT: String = "Costruibile"
const NODE_UPGRADABLE_TEXT: String = "Migliorabile"
const OPEN_TEXTS: Dictionary[StringName, String] = {&"noticeboard": "Apri Bacheca", &"shop": "Apri Mercato"}
const OPEN_DEFAULT_TEXT: String = "Apri"
const OPEN_LOCKED_TEXT: String = "Costruiscilo per usarlo"
const REFUSED_TEXT_DEFAULT: String = "Costruzione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)
