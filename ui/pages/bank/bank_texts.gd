class_name BankTexts
extends RefCounted
## Italian texts of the refusals of the bank commands shown by `BankPage` (extracted from it), display only.

const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "L'oggetto non è più nel deposito.",
	Reasons.INVALID_AMOUNT: "Quantità o posizione non valida.",
	Reasons.ITEM_LOCKED: "L'oggetto è bloccato: sbloccalo per venderlo.",
	Reasons.NOT_SELLABLE: "Questo oggetto non si vende.",
	Reasons.NOT_ENOUGH_ITEMS: "Non ci sono abbastanza oggetti.",
	Reasons.REQUIREMENT_NOT_MET: "Requisiti non soddisfatti.",
	Reasons.COMBAT_ACTIVE: "Non puoi cambiare arma durante il combattimento.",
	Reasons.BANK_FULL: "Il deposito è pieno.",
	Reasons.NOT_FOOD: "Questo oggetto non è un cibo.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
