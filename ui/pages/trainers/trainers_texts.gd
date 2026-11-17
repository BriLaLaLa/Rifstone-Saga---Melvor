class_name TrainersTexts
extends RefCounted
## Italian texts of the Trainers page (docs/01_GDD_M24.md §35.3 and §35.11). Presentation only: no game number here,
## every cost, cap and level comes from the model (`Disciplines`, `GameData`).

const TITLE_TEXT: String = "Maestri di mestiere"
const SIDEBAR_TEXT: String = "Maestri"
const GOLD_CAPTION: String = "Monete:"
const CATEGORY_TITLES: Dictionary[StringName, String] = {&"gathering": "Raccolta", &"artisan": "Produzione"}
const SLOTS_TEXT: String = "%s/%s posti"
const TRAINER_TEXT: String = "%s, %s"
const NOT_LEARNED_TEXT: String = "Non appresa"
const GRADE_TEXT: String = "Grado: %s (livello massimo %s)"
const LEVEL_TEXT: String = "Livello %s / %s"
const LEVEL_UNLEARNED_TEXT: String = "Livello massimo al primo grado: %s"
const COST_LEARN_TEXT: String = "Per imparare: %s"
const COST_FREE_TEXT: String = "Per imparare: gratis"
const COST_TRAIN_TEXT: String = "Grado successivo: %s (livello massimo %s, personaggio livello %s), %s"
const MAX_GRADE_TEXT: String = "Grado massimo raggiunto"
const EXTRA_SLOT_TEXT: String = "Posto extra"
const FED_BY_DROPS_TEXT: String = "Si alimenta con i drop dei mostri"
const FED_BY_TEXT: String = "Si alimenta con: %s"
const LEARN_TEXT: String = "Impara"
const TRAIN_TEXT: String = "Grado successivo"
const UNLEARN_TEXT: String = "Disimpara"
const UNLEARN_TITLE: String = "Disimparare %s"
const UNLEARN_QUESTION: String = "Disimparare %s costa %s. Perderai: %s. Vuoi procedere?"
const LOSS_LEVEL: String = "livello %s con %s XP"
const LOSS_MASTERY: String = "la maestria e il suo pool (%s XP di pool)"
const LOSS_JOBS: String = "%s lavori in coda"
const LOSS_SEPARATOR: String = ", "
## Reason of a learn / train / unlearn command -> text; other reasons: REFUSED_DEFAULT_TEXT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Disciplina sconosciuta.",
	Reasons.NOT_A_DISCIPLINE: "Questa skill non ha un Maestro.",
	Reasons.ALREADY_LEARNED: "Disciplina già appresa.",
	Reasons.DISCIPLINE_SLOTS_FULL: "Non hai posti liberi in questa categoria: disimpara una disciplina.",
	Reasons.REQUIREMENT_NOT_MET: "Il personaggio non ha ancora il livello richiesto.",
	Reasons.NOT_ENOUGH_GOLD: "Monete insufficienti.",
	Reasons.NOT_LEARNED: "Disciplina non appresa.",
	Reasons.MAX_GRADE: "Grado massimo già raggiunto.",
	Reasons.LEVEL_TOO_LOW: "Il livello della disciplina è troppo basso per il grado successivo.",
	Reasons.DISCIPLINE_BUSY: "Il nodo di questa disciplina è in corso: aspetta la fine del nodo.",
}
const REFUSED_DEFAULT_TEXT: String = "Operazione non riuscita."


## Title of a category box with the used and total places: "Raccolta  (1/2 posti)".
static func title(category: StringName, used: int, total: int) -> String:
	return "%s  (%s)" % [CATEGORY_TITLES.get(category, String(category)), SLOTS_TEXT % [used, total]]


static func refused(reason: StringName) -> String:
	return REFUSED_TEXTS.get(reason, REFUSED_DEFAULT_TEXT)
