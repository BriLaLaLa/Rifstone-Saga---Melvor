
class_name SkillHeader
extends RefCounted
## Header readings of `SkillPage` (extracted from it): the thin mastery pool bar under the XP bar, the status line and the
## Italian text of each refusal of the queue commands. Pure functions over the session; the page keeps the bar node.

const QUEUE_ACTION_KEY: String = "action"
const IDLE_TEXT: String = "Nessun lavoro in coda"
const NODE_IDLE_TEXT: String = "Si raccoglie ai nodi, durante il viaggio in combattimento"
const NODE_RUNNING_TEXT: String = "Nodo in corso"
const RUNNING_TEXT: String = "In corso: %s"
const RUNNING_OTHER_TEXT: String = "In corso: %s (%s)"
const POOL_TEXT: String = "Pool di maestria: %s / %s XP"
## Italian text of each refusal of `actions.enqueue`; other reasons use REFUSED_TEXT_DEFAULT.
const REFUSED_TEXTS: Dictionary[StringName, String] = {
	Reasons.LEVEL_TOO_LOW: "Livello troppo basso per questa azione.",
	Reasons.UNKNOWN_ID: "Questa azione non è ancora disponibile.",
	Reasons.NOT_LEARNED: "Devi prima imparare la disciplina dal Maestro.",
	Reasons.RECIPE_UNKNOWN: "Ricetta da scoprire: serve una Ricetta trovata.",
	Reasons.QUEUE_FULL: "La coda di produzione è piena.",
	Reasons.INVALID_AMOUNT: "Quantità non valida.",
	Reasons.MISSING_INPUTS: "Materiali insufficienti.",
	Reasons.BANK_FULL: "Il deposito è pieno.",
}
const REFUSED_TEXT_DEFAULT: String = "Impossibile mettere il lavoro in coda."


## Id of the action at the head of the production queue, empty if the queue is empty.
static func running_action_id(session: GameSession) -> StringName:
	return session.actions.current().get(QUEUE_ACTION_KEY, &"")


## The status line of the skill page of `skill_id`: the queue head, or for a gathering discipline the node in progress.
static func status_text(session: GameSession, skill_id: StringName) -> String:
	if session.data.skill(skill_id).category == &"gathering":
		return NODE_RUNNING_TEXT if session.combat.node_skill() == skill_id else NODE_IDLE_TEXT
	var running_id: StringName = running_action_id(session)
	if running_id == &"":
		return IDLE_TEXT
	var action: ActionDef = session.data.action(running_id)
	if action == null:  # a blueprint craft is not an ActionDef of the data
		return RUNNING_TEXT % String(running_id)
	if action.skill_id == skill_id:
		return RUNNING_TEXT % action.name
	return RUNNING_OTHER_TEXT % [action.name, session.data.skill(action.skill_id).name]


## The mastery pool bar, added after `xp_bar`.
static func build_pool_bar(xp_bar: Control) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "PoolBar"
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(0, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.add_sibling(bar)
	return bar


static func redraw_pool_bar(bar: ProgressBar, session: GameSession, skill_id: StringName) -> void:
	var cap: int = session.mastery.get_pool_cap(skill_id)
	var pool: int = session.mastery.get_pool(skill_id)
	bar.value = float(pool) / float(cap) if cap > 0 else 0.0
	bar.tooltip_text = POOL_TEXT % [NumberFormat.format_int(pool), NumberFormat.format_int(cap)]
