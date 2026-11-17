class_name MailTexts
extends RefCounted
## Italian texts of the Mail page (docs/05_INTERFACES_M27.md §7.o). Presentation only: the text of a message is composed from the
## data models (`data/mail/templates.json`) with the fields of the message; no game number here.

const TITLE_TEXT: String = "Posta"
const UNREAD_TEXT: String = "%s non letti su %s"
const EMPTY_TEXT: String = "La casella è vuota."
const NEW_TEXT: String = "NUOVO"
const SELECT_TEXT: String = "Scegli un messaggio dall'elenco."
const COLLECT_TEXT: String = "Ritira"
const COLLECT_ALL_TEXT: String = "Ritira tutto"
const ATTACHMENT_TITLE: String = "Allegato"
const ITEM_LINE_TEXT: String = "%s x%s"
const FROM_TEXT: String = "Da: %s"
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Messaggio non trovato.",
	Reasons.BANK_FULL: "Deposito pieno: fai spazio per ritirare gli oggetti.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."
const MISSING_MODEL_TEXT: String = "Messaggio della Casa d'Aste."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)


## {"sender", "subject", "body"} of `message` (a MailBox message copy): the model is picked by the message id among those of
## its kind (no random draw), then `{item}`, `{qty}`, `{price}` and `{money}` are replaced.
static func compose(message: Dictionary, data: GameData) -> Dictionary:
	var models: Array[MailTemplateDef] = data.mail_templates(message["kind"] as StringName)
	if models.is_empty():
		Log.warn("ui", "mail: no text model for kind '%s'" % message["kind"])
		return {"sender": "", "subject": MISSING_MODEL_TEXT, "body": ""}
	var model: MailTemplateDef = models[int(message["id"]) % models.size()]
	return {"sender": model.sender, "subject": _fill(model.subject, message, data), "body": _fill(model.body, message, data)}


static func item_name(item_id: StringName, data: GameData) -> String:
	var def: ItemDef = data.item(item_id)
	return def.name if def != null else String(item_id)


static func _fill(text: String, message: Dictionary, data: GameData) -> String:
	var currency: CurrencyParams = data.currency()
	return text.replace("{item}", item_name(message["item"] as StringName, data)) \
			.replace("{qty}", NumberFormat.format_int(int(message["qty"]))) \
			.replace("{price}", Money.text(int(message["price"]), currency)) \
			.replace("{money}", Money.text(int(message["money"]), currency))
