class_name DungeonTexts
extends RefCounted
## Italian texts of the Dungeon page, of the Dungeon in the Combat page and of the Dungeon toasts (docs/05_INTERFACES.md
## §7.q). Display only: every number comes from `DungeonSystem.state()` or the data, no rule lives here.

const TITLE_TEXT: String = "Dungeon"
const INTRO_TEXT: String = "Un dungeon si apre con un Biglietto. Dentro scegli solo la direzione: il combattimento è automatico. Se muori o fuggi, la borsa del dungeon è persa."
const NO_DUNGEON_TEXT: String = "Nessun dungeon disponibile."
const REQUIRES_TEXT: String = "Richiede il livello %d del personaggio"
const RECOMMENDED_TEXT: String = "Livello consigliato: %d"
const TICKETS_TEXT: String = "%s: %s"
const WINS_TEXT: String = "Vittorie: %s"
const ENTER_TEXT: String = "Entra"
const PENDING_TITLE_TEXT: String = "Bottino in attesa"
const COLLECT_TEXT: String = "Raccogli"
const COLLECTED_TEXT: String = "Bottino raccolto."
const LAST_RESULT_TEXT: String = "Ultima volta: %s"

const PROGRESS_TEXT: String = "Stanza %d di %d"
const PROGRESS_BOSS_TEXT: String = "Stanza ? di %d"
const CHOICE_TITLE_TEXT: String = "Dove vuoi andare?"
const EVENT_TRAP_TITLE_TEXT: String = "Una trappola"
const EVENT_REST_TITLE_TEXT: String = "Un posto per riposare"
const HINT_TEXT: String = "%s  (%s)"
const BAG_TITLE_TEXT: String = "Borsa del dungeon"
const BAG_EMPTY_TEXT: String = "La borsa è vuota."
const LEAVE_TEXT: String = "Esci dal Covo"
const LEAVE_TITLE_TEXT: String = "Uscire dal Covo?"
const LEAVE_QUESTION_TEXT: String = "Esci con la borsa del dungeon, ma rinunci al boss. Il Biglietto è già consumato."
const FLEE_TEXT: String = "Fuggi"
const FLEE_TITLE_TEXT: String = "Fuggire dal Covo?"
const FLEE_QUESTION_TEXT: String = "Se fuggi, la borsa del dungeon va persa e il Biglietto è già consumato."
const EAT_TEXT: String = "Mangia"
const RESUME_TEXT: String = "Riprendi"
const PAUSED_TEXT: String = "La run è in pausa: premi Riprendi quando sei pronto."
const RISK_TEXT: String = "Attenzione: se muori o fuggi, la borsa del dungeon è persa."
const ROOM_TEXT: String = "%s  -  %s"
const COMBAT_NOTICE_TEXT: String = "Sei nel Covo delle Scimmie"
const COMBAT_NOTICE_HINT_TEXT: String = "Le scelte e \"Fuggi\" sono nella pagina Dungeon."
const COMBAT_OPEN_PAGE_TEXT: String = "Vai al Dungeon"
const INTRO_STAGE_TEXT: String = "Atto %d"

const DIRECTION: Dictionary[StringName, String] = {
	&"far_left": "Tutto a sinistra",
	&"left": "A sinistra",
	&"slight_left": "Leggermente a sinistra",
	&"forward": "Dritto davanti a te",
	&"slight_right": "Leggermente a destra",
	&"right": "A destra",
	&"far_right": "Tutto a destra",
}
const DIRECTION_UNKNOWN_TEXT: String = "Avanti"

const EVENT_CHOICE: Dictionary[StringName, String] = {
	&"dash": "Attraversa di corsa",
	&"detour": "Aggira",
	&"rest": "Riposa",
	&"forage": "Fruga tra i rami",
}
const EVENT_DESCRIPTION: Dictionary[StringName, String] = {
	&"dash": "Perdi il %d%% dei PV massimi (mai fino alla morte) e prosegui.",
	&"detour": "Nessun danno, ma devi affrontare un'imboscata.",
	&"rest": "Recuperi il %d%% dei PV massimi.",
	&"forage": "Non ti curi: affronti un branco, poi trovi una scorta.",
}

const KIND_NAMES: Dictionary[StringName, String] = {
	&"entrance": "Ingresso", &"pack": "Branco", &"horde": "Orda", &"elite": "Guardiano", &"miniboss": "Capobranco",
	&"trap": "Trappola", &"rest": "Riposo", &"boss": "Tana del Re",
}
const KIND_UNKNOWN_TEXT: String = "Stanza"

## Refusals of the commands of the page, in Italian.
const REFUSED: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Questo dungeon non esiste.",
	Reasons.REQUIREMENT_NOT_MET: "Il tuo personaggio non ha il livello richiesto.",
	Reasons.DUNGEON_ACTIVE: "Sei già in un dungeon.",
	Reasons.FRACTURE_ACTIVE: "Una Frattura è in corso: finiscila prima.",
	Reasons.DUNGEON_BAG_PENDING: "Raccogli prima il bottino in attesa.",
	Reasons.NOT_ENOUGH_ITEMS: "Ti serve un Biglietto.",
	Reasons.NO_DUNGEON: "Non sei in un dungeon.",
	Reasons.NOT_AWAITING: "Non c'è nessuna scelta da fare ora.",
	Reasons.NOT_FIGHTING: "Puoi fuggire solo durante un combattimento.",
	Reasons.INVALID_CHOICE: "Scelta non valida.",
	Reasons.DUNGEON_PAUSED: "La run è in pausa: premi Riprendi.",
	Reasons.NOT_PAUSED: "La run non è in pausa.",
	Reasons.BANK_FULL: "Deposito pieno: fai spazio.",
	Reasons.ARMORY_FULL: "Armeria piena: fai spazio.",
}
const REFUSED_DEFAULT: String = "Azione non riuscita."

const OUTCOME_TEXTS: Dictionary[StringName, String] = {
	&"won": "Covo superato!",
	&"died": "Sei caduto nel Covo: bottino perduto",
	&"fled": "Sei fuggito: bottino perduto",
	&"left": "Sei uscito dal Covo",
}
const OUTCOME_UNKNOWN_TEXT: String = "Dungeon terminato"
const TOAST_LOOT_TEXT: String = "%s %s"
const TOAST_TRAP_TEXT: String = "Una trappola ti costa %s PV"
const OFFLINE_LINE: String = "Il dungeon era in corso: la run è rimasta ferma. Riprendila dalla pagina Dungeon."


static func refusal(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_DEFAULT)


static func direction_text(direction: StringName) -> String:
	return DIRECTION.get(direction, DIRECTION_UNKNOWN_TEXT)


static func kind_name(kind: StringName) -> String:
	return KIND_NAMES.get(kind, KIND_UNKNOWN_TEXT)


## The text of a fork button: the direction and, when the room has one, its hint.
static func choice_text(choice: Dictionary) -> String:
	var direction: String = direction_text(choice.get("direction", &"") as StringName)
	var hint: String = String(choice.get("hint", ""))
	return HINT_TEXT % [direction, hint] if hint != "" else direction


static func event_text(id: StringName) -> String:
	return EVENT_CHOICE.get(id, String(id))


## The description of an event choice; the percentage comes from the dungeon data (`def`).
static func event_description(id: StringName, def: DungeonDef) -> String:
	var text: String = EVENT_DESCRIPTION.get(id, "")
	if def == null:
		return text.replace("%d%%", "")
	match id:
		&"dash":
			return text % roundi(def.trap_dash_hp_pct)
		&"rest":
			return text % roundi(def.rest_heal_pct)
	return text


static func outcome_text(outcome: StringName) -> String:
	return OUTCOME_TEXTS.get(outcome, OUTCOME_UNKNOWN_TEXT)


static func progress_text(state: Dictionary) -> String:
	var progress: Dictionary = state.get("progress", {}) as Dictionary
	var total: int = int(progress.get("total", 0))
	var done: int = int(progress.get("done", 0))
	var room: Dictionary = state.get("room", {}) as Dictionary
	if (room.get("kind", &"") as StringName) == &"boss":
		return PROGRESS_BOSS_TEXT % total
	return PROGRESS_TEXT % [mini(done + 1, total), total]


## "Branco" or, in the boss, the title of the stage (`state["room"]["name"]`).
static func room_title(state: Dictionary) -> String:
	var room: Dictionary = state.get("room", {}) as Dictionary
	var name_text: String = String(room.get("name", ""))
	return name_text if name_text != "" else kind_name(room.get("kind", &"") as StringName)


## Toast of `dungeon_finished`.
static func toast_text(outcome: StringName, pieces: int) -> String:
	var text: String = outcome_text(outcome)
	if outcome == &"won" and pieces > 0:
		return TOAST_LOOT_TEXT % [text, FractureTexts.bag_text({"stacks": 0, "pieces": pieces, "cards": 0})]
	return text
