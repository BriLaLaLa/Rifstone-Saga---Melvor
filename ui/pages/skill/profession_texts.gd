class_name ProfessionTexts
extends RefCounted
## Italian texts of the production page (recipe list on the left, detail on the right). Presentation only: every number
## shown comes from the session or the data; the categories of the list are the sub-tabs of the Forging page and of the
## Engraver (ForgeTabs, EngraverSections), the other crafts have a single one.

const SEARCH_HINT: String = "Cerca ricetta"
const ONLY_CRAFTABLE_TEXT: String = "Solo creabili"
const ONLY_CRAFTABLE_TIP: String = "Mostra solo le ricette che puoi creare con quello che hai nel Deposito."
const ALL_CATEGORY_LABEL: String = "Ricette"
const CRAFTABLE_TEXT: String = "(%s)"
const LEVEL_SHORT_TEXT: String = "Liv. %s"
const NO_RECIPES_TEXT: String = "Nessuna ricetta corrisponde."
const PICK_RECIPE_TEXT: String = "Scegli una ricetta dall'elenco."
const REAGENTS_TITLE: String = "Reagenti"
const PRODUCT_TITLE: String = "Prodotto"
const NO_REAGENTS_TEXT: String = "Nessun reagente."
const REAGENT_TEXT: String = "%s   %s / %s"
const PRODUCT_TEXT: String = "%s  (ne hai %s)"
const XP_TEXT: String = "%s XP"
const MASTERY_STAT_TEXT: String = "Maestria %s"
const NO_MASTERY_TEXT: String = "Nessuna maestria"
const STAT_SEPARATOR: String = "   |   "
const CHANCE_TEXT: String = "%s%%"
const STAT_PAIR_TEXT: String = "%s %s"
const SECTION_OPEN_TEXT: String = "- %s"
const SECTION_CLOSED_TEXT: String = "+ %s"
const LEVEL_NEEDED_TEXT: String = "Richiede il livello %s"
const LEVEL_OK_TEXT: String = "Livello %s"
const PROGRESS_COLOR_TEXT: String = "Avanzamento: %s%%  (ricetta %s)"
const COLOR_NAMES: Dictionary[StringName, String] = {
	&"orange": "arancione", &"yellow": "gialla", &"green": "verde", &"grey": "grigia",
}
const ORIGIN_TRAINER_TEXT: String = "Origine: la insegna il Maestro."
const ORIGIN_TRAINER_LOCKED_TEXT: String = "Origine: la insegna il Maestro. Non ancora appresa."
const ORIGIN_DROP_TEXT: String = "Origine: si trova come bottino."
const ORIGIN_SCHEME_KNOWN_TEXT: String = "Origine: schema dal mercante (%s). Schema appreso."
const ORIGIN_SCHEME_LEVEL_TEXT: String = "Origine: schema dal mercante (%s). Non appreso: si vende dal livello %s."
const ORIGIN_SCHEME_BUY_TEXT: String = "Origine: schema dal mercante (%s). Non appreso: costa %s."
const UNLOCKS_TITLE: String = "Prossimi sblocchi"
const UNLOCK_LINE_TEXT: String = "Liv. %s   %s   %s"
const UNLOCK_KINDS: Dictionary[StringName, String] = {
	&"trainer": "Ricetta del Maestro", &"scheme": "Schema in vendita", &"reagent": "Reagente in vendita",
}
