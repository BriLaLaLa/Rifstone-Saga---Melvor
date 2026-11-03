class_name MasteryTexts
extends RefCounted
## Italian texts and presentation constants of the mastery panel (docs/01_GDD.md §6), display only.
##
## Command errors of MasterySystem (`spend_pool_on_action`, `buy_node`) become the texts of REASON_TEXTS; the node
## states are the four of docs/07_TASKS.md M2-03 (owned, buyable, locked by prerequisites, pool too small).
## The presentation constants below belong to the mastery panel only; they are kept here (not in UiStyle) while
## UiStyle is edited by another task, and can move to `UiStyle.MASTERY_*` unchanged.

const STATE_OWNED := &"owned"
const STATE_BUYABLE := &"buyable"
const STATE_LOCKED := &"locked"
const STATE_UNAFFORDABLE := &"unaffordable"
const STATE_TEXTS: Dictionary[StringName, String] = {
	STATE_OWNED: "Acquistato",
	STATE_BUYABLE: "Disponibile",
	STATE_LOCKED: "Bloccato",
	STATE_UNAFFORDABLE: "Pool insufficiente",
}
## Italian text of each failure of the mastery commands; other reasons use REASON_TEXT_DEFAULT.
const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Questo elemento non ha maestria.",
	Reasons.INVALID_AMOUNT: "Scegli un importo maggiore di zero.",
	Reasons.MASTERY_MAX: "La maestria di questa azione è già al livello massimo.",
	Reasons.POOL_INSUFFICIENT: "Il pool di maestria non basta.",
	Reasons.NODE_OWNED: "Nodo già acquistato.",
	Reasons.NODE_PREREQ_MISSING: "Prima acquista i nodi richiesti.",
}
const REASON_TEXT_DEFAULT: String = "Operazione non riuscita."

const WINDOW_TITLE: String = "Maestria: %s"
const OPEN_BUTTON_TEXT: String = "Maestria"
const OPEN_BUTTON_TOOLTIP: String = "Pool, maestria delle azioni e nodi"
const POOL_TEXT: String = "%s / %s XP"
const POOL_WARNING_TEXT: String = "Pool quasi pieno: oltre il tetto la maestria in più va persa."
const LEVEL_TEXT: String = "Liv. %s"
const SPEND_TARGET_TEXT: String = "Spendi il pool su: %s"
const SPEND_NO_TARGET_TEXT: String = "Scegli un'azione da potenziare."
const SPEND_AMOUNT_TEXT: String = "%s XP"
const SPEND_BUTTON_TEXT: String = "Spendi"
const SELECT_TEXT: String = "Scegli"
const SELECTED_TEXT: String = "Scelta"
const BUY_TEXT: String = "Acquista"
const COST_TEXT: String = "Costo: %s XP (%s%% del tetto)"
const REQUIRES_TEXT: String = "Richiede: %s"
const NO_MASTERY_TEXT: String = "Questa skill non ha maestria."
const NO_NODES_TEXT: String = "Nessun nodo per questa skill."

# --- presentation constants (candidates for UiStyle.MASTERY_*) ---
## The pool bar turns red and the warning appears from this fraction of the cap (docs/01_GDD.md §6.2: 95%).
const POOL_WARNING_RATIO: float = 0.95
## Size of a node card in the tree and space between two cells (pos = [col, row] of the data).
const NODE_SIZE := Vector2(240, 156)
const NODE_GAP := Vector2(32, 32)
## Prerequisite links drawn between node cards.
const LINK_WIDTH: float = 2.0
const ACTION_ICON_SIDE: int = 36
## Opacity of a node card whose prerequisites are missing.
const LOCKED_ALPHA: float = 0.6


## Message for a failed mastery command.
static func reason_text(reason: StringName) -> String:
	return REASON_TEXTS.get(reason, REASON_TEXT_DEFAULT)


## Text of a node state (STATE_*).
static func state_text(state: StringName) -> String:
	return STATE_TEXTS.get(state, STATE_TEXTS[STATE_LOCKED])
