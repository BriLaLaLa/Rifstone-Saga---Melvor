class_name NoticeboardTexts
extends RefCounted
## Italian texts of the Noticeboard page (docs/01_GDD.md §31, docs/05_INTERFACES.md §7.s). Presentation only: no game number here.

const TITLE_TEXT: String = "Bacheca"
const CLAIM_TEXT: String = "Riscuoti"
const ABANDON_TEXT: String = "Abbandona"
const EMPTY_SLOT_TEXT: String = "Nessun incarico disponibile"
const NO_BOARD_TEXT: String = "Costruisci la Bacheca al Villaggio"
const PROGRESS_TEXT: String = "%s / %s"
const REWARD_TITLE_TEXT: String = "Ricompensa:"
const REWARD_GOLD_TEXT: String = "%s oro"
const REWARD_XP_TEXT: String = "%s XP %s"
const REWARD_ITEM_TEXT: String = "%s x%s"
const REWARD_SEPARATOR: String = ", "
## Reason of `can_claim` / `claim` -> text; other reasons: REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Incarico sconosciuto.",
	Reasons.SLOT_EMPTY: "Nessun incarico in questa casella.",
	Reasons.QUEST_INCOMPLETE: "Incarico non ancora completato.",
	Reasons.BANK_FULL:"Deposito pieno: fai spazio per la ricompensa.",
}
const REFUSED_TEXT_DEFAULT: String = "Operazione non riuscita."


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_TEXT_DEFAULT)
