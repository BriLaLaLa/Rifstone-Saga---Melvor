class_name HelperTexts
extends RefCounted
## Italian texts of the helper row and of the hire command (docs/05_INTERFACES.md §7.w, docs/01_GDD.md §6.4), display
## only. Grade names: `HelperGradeNames` (docs/NOMI.md).

const NONE_TEXT: String = "Aiutante: nessuno"
const HELPER_TEXT: String = "Aiutante: %s"
const WORKING_TEXT: String = " — lavora: %s"
const IDLE_TEXT: String = " — nessuna risorsa scelta"
const INTERVAL_TEXT: String = "ciclo %s s"
const BLOCKED_TEXT: String = "In attesa: Deposito pieno"
const CHANGE_TEXT: String = "Cambia"
const STOP_TEXT: String = "Ferma"
const HIRE_TEXT: String = "Assumi"
const PICK_TEXT: String = "Scegli la risorsa"
const NO_CONTRACT_TEXT: String = "Nessun contratto nel Deposito."
const REFUSED: Dictionary[StringName, String] = {
	Reasons.HELPER_NOT_BETTER: "Hai già un aiutante di grado uguale o migliore: il contratto non si consuma.",
	Reasons.NOT_A_CONTRACT: "Questo oggetto non è un contratto.",
	Reasons.NOT_ENOUGH_ITEMS: "Non hai questo contratto nel Deposito.",
	Reasons.UNKNOWN_ID: "Contratto o risorsa sconosciuti.",
	Reasons.NO_HELPER: "Questo mestiere non ha un aiutante.",
	Reasons.LEVEL_TOO_LOW: "Il livello del mestiere non basta per questa risorsa.",
}
const REFUSED_DEFAULT: String = "Operazione non riuscita."
## Toast when the helper stops for a full Deposit: "L'aiutante del <mestiere> è fermo: Deposito pieno".
const BLOCKED_TOAST_TEXT: String = "L'aiutante del %s è fermo: Deposito pieno"


static func refused(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_DEFAULT)
