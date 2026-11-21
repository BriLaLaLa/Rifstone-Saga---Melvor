class_name StarterTexts
extends RefCounted
## Italian texts of the Primi passi page and widget (docs/05_INTERFACES_M30.md §7.ab). Presentation only.

const TITLE_TEXT: String = "Primi passi"
const INTRO_TEXT: String = "Incarichi per provare ogni sistema del gioco. Le ricompense arrivano per Posta."
const CLAIM_TEXT: String = "Riscuoti"
const CLAIMED_TEXT: String = "Riscosso"
const COUNT_TEXT: String = "%d / %d"
const WIDGET_DONE_TEXT: String = "Tutti gli incarichi riscossi"
const REWARD_TEXT: String = "Ricompensa:"
const REWARD_ITEM_TEXT: String = "%s x%s"
const REWARD_XP_TEXT: String = "%s XP"
const REWARD_SEPARATOR: String = ", "
const CLAIMED_NOTICE: String = "Ricompensa inviata alla Posta: ritirala da lì."
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Incarico sconosciuto.",
	Reasons.TUTORIAL_INACTIVE: "Gli incarichi si aprono a tutorial finito.",
	Reasons.ALREADY_CLAIMED: "Ricompensa già riscossa.",
	Reasons.QUEST_INCOMPLETE: "Incarico non ancora completato.",
	Reasons.MAILBOX_FULL: "Posta piena: ritira dei messaggi e riprova.",
}
const REFUSED_DEFAULT: String = "Operazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_DEFAULT)
