class_name FractureTexts
extends RefCounted
## Italian texts of the Fractures page, of the Fracture in the Combat page and of the Fracture toasts (docs/05_INTERFACES.md
## §7.v, docs/NOMI.md "Fratture come mappe"). Display only: every number comes from the session or the data, no rule here.

const TITLE_TEXT: String = "Fratture"
const INTRO_TEXT: String = "Una Frattura si apre solo con una Carta: la Carta viene consumata e parte il primo gruppo. Il bottino resta nella Borsa della Frattura e arriva al Deposito solo se vinci."
const NO_CARDS_TEXT: String = "Non hai Carte della Frattura. Cadono dai mostri e dai Monoliti."
const CARDS_TITLE_TEXT: String = "Carte"
const CARD_GRADE_TEXT: String = "Grado %d"
const RECOMMENDED_TEXT: String = "Livello consigliato: %d"
const CARD_NO_MODS_TEXT: String = "Nessun modificatore."
const RISK_PREFIX: String = "Rischio: "
const REWARD_PREFIX: String = "Premio: "
const EFFECT_JOIN: String = "   |   "

const OPEN_TEXT: String = "Apri"
const LOCK_TEXT: String = "Blocca"
const UNLOCK_TEXT: String = "Sblocca"
const SALVAGE_TEXT: String = "Smantella"
const CRYSTALS_TEXT: String = "Cristalli"
const LOCKED_TAG_TEXT: String = "bloccata"

const CRYSTAL_TITLE_TEXT: String = "Cristalli per la Carta di grado %d"
const CRYSTAL_NONE_TEXT: String = "Non hai Cristalli."
const CRYSTAL_USE_TEXT: String = "Usa Cristallo"
const CRYSTAL_CLOSE_TEXT: String = "Chiudi"
const CRYSTAL_OPTION_TEXT: String = "%s  x%s"

const PENDING_TITLE_TEXT: String = "Bottino in attesa"
const COLLECT_TEXT: String = "Raccogli"

const RUN_TITLE_TEXT: String = "Frattura di grado %d"
const GROUP_TEXT: String = "Gruppo %d/%d"
const BOSS_TEXT: String = "Boss"
const BOSS_NAMED_TEXT: String = "Boss: %s"
const MODS_TITLE_TEXT: String = "Modificatori attivi"
const NO_MODS_TEXT: String = "Nessun modificatore."
const BAG_TITLE_TEXT: String = "Borsa della Frattura"
const BAG_EMPTY_TEXT: String = "La borsa è vuota."
const ABANDON_TEXT: String = "Abbandona"
const ABANDON_TITLE_TEXT: String = "Abbandonare la Frattura?"
const ABANDON_QUESTION_TEXT: String = "Se abbandoni, la Borsa della Frattura va persa e la Carta è già consumata."

const COMBAT_HEADER_TEXT: String = "Frattura di grado %d - gruppo %d/%d"
const COMBAT_HEADER_BOSS_TEXT: String = "Frattura di grado %d - boss"
const COMBAT_HINT_TEXT: String = "La borsa e \"Abbandona\" sono nella pagina Fratture."
const COMBAT_OPEN_PAGE_TEXT: String = "Vai alle Fratture"
const COMBAT_SHIELD_TEXT: String = "Scudo attivo: %s"
const COMBAT_ABILITY_TEXT: String = "Abilità: %s tra %s s"

const RARITY_NAMES: Dictionary[StringName, String] = {
	&"common": "Comune", &"magic": "Magica", &"rare": "Rara",
}

const OUTCOME_TEXTS: Dictionary[StringName, String] = {
	&"won": "vinta",
	&"died": "persa",
	&"abandoned": "abbandonata",
}
const OUTCOME_UNKNOWN_TEXT: String = "terminata"

## Refusals of the commands of the page (docs/05_INTERFACES.md §7.v), in Italian.
const REFUSED: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "La Carta non esiste più.",
	Reasons.FRACTURE_ACTIVE: "Una Frattura è già in corso.",
	Reasons.FRACTURE_BAG_PENDING: "Raccogli prima il bottino in attesa.",
	Reasons.ITEM_LOCKED: "La Carta è bloccata: sbloccala prima.",
	Reasons.REQUIREMENT_NOT_MET: "Questo Cristallo non è adatto alla rarità della Carta.",
	Reasons.NOT_ENOUGH_ITEMS: "Non hai questo Cristallo.",
	Reasons.NOT_EQUIPPABLE: "Questo oggetto non è un Cristallo.",
	Reasons.BANK_FULL: "Deposito pieno: fai spazio.",
	Reasons.ARMORY_FULL: "Armeria piena: fai spazio.",
	Reasons.NO_FRACTURE: "Non c'è nulla da raccogliere.",
}
const REFUSED_DEFAULT: String = "Azione non riuscita."

const SALVAGED_TEXT: String = "Carta smantellata: %s Polvere del Rift."
const COLLECTED_TEXT: String = "Bottino raccolto."
const USED_TEXT: String = "Cristallo usato."

## Toasts (docs/05_INTERFACES.md §7.v).
const TOAST_WON_TEXT: String = "Frattura vinta! %s"
const TOAST_LOST_TEXT: String = "Frattura persa: bottino perduto"
const TOAST_ABANDONED_TEXT: String = "Frattura abbandonata"
const TOAST_REJECTED_TEXT: String = "Carta persa: Deposito pieno"


static func rarity_name(rarity: StringName) -> String:
	return RARITY_NAMES.get(rarity, String(rarity))


static func ability_name(ability_type: StringName) -> String:
	return MapEffectLabels.ability_name(ability_type)


## "PV dei mostri +40%" for the risk of one entry of `MapCardRoller.effects`.
static func risk_line(effect: Dictionary) -> String:
	var type: StringName = effect.get("risk_type", &"") as StringName
	return MapEffectLabels.line(type, float(effect.get("risk", 0.0)))


## "Quantità del bottino +10%" for the reward of one entry of `MapCardRoller.effects`.
static func reward_line(effect: Dictionary) -> String:
	var type: StringName = effect.get("reward_type", &"") as StringName
	return MapEffectLabels.line(type, float(effect.get("reward", 0.0)))


## One line with the risk and the reward of an entry.
static func effect_line(effect: Dictionary) -> String:
	return risk_line(effect) + EFFECT_JOIN + reward_line(effect)


static func outcome_text(outcome: StringName) -> String:
	return OUTCOME_TEXTS.get(outcome, OUTCOME_UNKNOWN_TEXT)


static func refusal(reason: StringName) -> String:
	return REFUSED.get(reason, REFUSED_DEFAULT)


## "3 materiali, 1 pezzo, 1 Carta" for a bag or a pending summary ({"stacks": Array or int, "pieces": int, "cards": int}).
static func bag_text(bag: Dictionary) -> String:
	var stacks: Variant = bag.get("stacks", [])
	var kinds: int = (stacks as Array).size() if stacks is Array else int(stacks)
	var parts: PackedStringArray = PackedStringArray()
	if kinds > 0:
		parts.append("%d %s" % [kinds, "tipo di oggetto" if kinds == 1 else "tipi di oggetti"])
	var pieces: int = int(bag.get("pieces", 0))
	if pieces > 0:
		parts.append("%d %s" % [pieces, "pezzo" if pieces == 1 else "pezzi"])
	var cards: int = int(bag.get("cards", 0))
	if cards > 0:
		parts.append("%d %s" % [cards, "Carta" if cards == 1 else "Carte"])
	return ", ".join(parts)


## Text of the toast of `fracture_finished`.
static func toast_text(outcome: StringName, cards: int, pieces: int) -> String:
	match outcome:
		&"won":
			var loot: String = bag_text({"stacks": 0, "pieces": pieces, "cards": cards})
			return TOAST_WON_TEXT % loot if loot != "" else TOAST_WON_TEXT.replace(" %s", "")
		&"abandoned":
			return TOAST_ABANDONED_TEXT
	return TOAST_LOST_TEXT
