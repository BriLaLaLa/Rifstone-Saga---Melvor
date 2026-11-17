class_name MerchantTexts
extends RefCounted
## Italian texts of the Mercante tab of a production page (docs/01_GDD_M26.md §38.2). Presentation only.

const PAGE_LABEL: String = "Mercante"
const TITLE_TEXT: String = "Mercante: %s"
const CAPTION: String = "Qui compri gli schemi delle ricette avanzate e i reagenti che servono per usarli."
const GOLD_CAPTION: String = "Monete:"
const SCHEMES_TITLE: String = "Schemi"
const REAGENTS_TITLE: String = "Reagenti"
const NOTHING_TEXT: String = "Il mercante non ha nulla in vendita."
const PRICE_TEXT: String = "Prezzo: %s"
const PRICE_EACH_TEXT: String = "%s l'uno"
const OWNED_TEXT: String = "Ne hai %s"
const STATE_KNOWN: String = "Schema appreso"
const STATE_LEARN: String = "Comprato, da imparare"
const STATE_BUY: String = "In vendita"
const STATE_LOCKED_TEXT: String = "Bloccato: richiede il livello %s"
const STATE_LOCKED_GENERIC: String = "Bloccato: requisiti non soddisfatti"
const BUY_TEXT: String = "Compra"
const LEARN_TEXT: String = "Impara ora"
const BUY_MANY_TEXT: String = "x%s"
const BUY_MANY_COUNTS: Array[int] = [1, 10, 100]
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Voce non disponibile.",
	Reasons.INVALID_AMOUNT: "Quantità non valida.",
	Reasons.MAX_PURCHASES: "Hai già acquistato il massimo.",
	Reasons.REQUIREMENT_NOT_MET: "Requisiti non soddisfatti.",
	Reasons.RECIPE_KNOWN: "Conosci già questa ricetta.",
	Reasons.NOT_ENOUGH_GOLD: "Monete insufficienti.",
	Reasons.BANK_FULL: "Il deposito è pieno.",
	Reasons.ARMORY_FULL: "L'Armeria è piena.",
	Reasons.NOT_A_RECIPE: "Non è uno schema.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
