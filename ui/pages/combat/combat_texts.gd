class_name CombatTexts
extends RefCounted
## Italian texts of the combat page and of the combat values on the character page (docs/01_GDD.md §10.11, F-70),
## display only. Presentation constants: `UiStyle.COMBAT_*`. Area and monster names come from the data.

## Most floating numbers (damage / miss / parry) alive over one card; the oldest are dropped.
const MAX_HIT_NUMBERS: int = 3
const LOOT_TITLE: String = "Bottino"
const STATS_TITLE: String = "Valori di combattimento"
const STATE_TEXTS: Dictionary[StringName, String] = {
	CombatEngine.STATE_IDLE: "In attesa",
	CombatEngine.STATE_ENCOUNTER: "In combattimento",
	CombatEngine.STATE_BETWEEN: "Il prossimo gruppo sta arrivando",
	CombatEngine.STATE_RIFTSTONE: "Pietra del Rift",
}
const STATE_TEXT_DEFAULT: String = "In attesa"
const NO_AREA_TEXT: String = "Scegli un'area per combattere."
const STOP_TEXT: String = "Ferma"
const EAT_TEXT: String = "Mangia"
const COLLECT_TEXT: String = "Raccogli tutto"
const FOOD_TEXT: String = "Cibo: %s (x%s)"
const NO_FOOD_TEXT: String = "Nessun cibo scelto"
const NO_FOOD_WARNING: String = "Non hai cibo equipaggiato: in combattimento non potrai mangiare."
const LOOT_COUNT_TEXT: String = "Borsa: %s / %s"
const LOOT_LINE_TEXT: String = "%s x%s"
const LOOT_EMPTY_TEXT: String = "La borsa è vuota."
const HP_TEXT: String = "%s / %s PV"
const INTERVAL_TEXT: String = "Attacco ogni %s s"
const MISS_TEXT: String = "Mancato"
const BLOCKED_TEXT: String = "Parato"
const HIT_TEXT: String = "-%s"
const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.UNKNOWN_ID: "Area non valida.",
	Reasons.REQUIREMENT_NOT_MET: "Non hai ancora il livello richiesto.",
	Reasons.NO_FOOD: "Non hai cibo da mangiare.",
	Reasons.NOT_RUNNING: "Nessun combattimento in corso.",
	Reasons.BANK_FULL: "Il deposito è pieno: parte del bottino è rimasta nella borsa.",
}
const REASON_TEXT_DEFAULT: String = "Operazione non riuscita."
const DEFEAT_TEXT: String = "Sei stato sconfitto: il bottino della borsa è andato perso."
## Character page, values of F-70 (CombatantStats.for_player): "<name>: <value>", the name is the one of the stat in
## data/config/stats.json (STAT_NAME_SOURCES); damage has no stat of its own.
const STAT_LINE_TEXT: String = "%s: %s"
const STAT_NAME_SOURCES: Dictionary[StringName, StringName] = {
	&"accuracy": &"accuracy_bonus", &"evasion": &"evasion_bonus", &"max_hp": &"max_hp_flat",
}
const STAT_DAMAGE_TEXT: String = "Danno: %s - %s"
## Combat page, GDR layout (docs/UI_GDR.md §2).
const AREA_LABEL_TEXT: String = "Area"
const AREA_REQUIREMENT_TEXT: String = "%s (%s)"
const HEADER_ENEMIES_TEXT: String = "%s · %s"
const ENEMY_COUNT_TEXT: String = "%d / %d in campo"
const GROUP_SIZE_TEXT: String = "%d nemici"
const GROUP_SIZE_ONE_TEXT: String = "1 nemico"
const LOOT_MORE_TEXT: String = "+%d"
const TARGET_TITLE: String = "Bersaglio"
const QUEUE_TITLE: String = "In fila (%d)"
const NO_TARGET_TEXT: String = "Nessun nemico in campo."
const DEFEATED_TEXT: String = "sconfitto"
const TAG_TEXT: String = "%s · %s"
const RELATION_TEXTS: Dictionary[StringName, String] = {
	&"advantage": "sei in vantaggio", &"neutral": "alla pari", &"disadvantage": "svantaggio",
}
const ENEMY_INFO_TEXT: String = "Attacca ogni %s s · riduzione del danno %s"
const LEVEL_TEXT: String = "Livello %d · %s"
const TRIANGLE_HINT_TEXT: String = "%s: forte contro %s, debole contro %s"
const HP_TITLE: String = "Punti vita"
const ATTACK_TITLE: String = "Attacco"
const HP_NUMBERS_TEXT: String = "%s / %s"
const SECONDS_TEXT: String = "%s s"
const ABILITIES_TITLE: String = "Abilità"
const TRAITS_TITLE: String = "Tratti"
const GEAR_TITLE: String = "Equipaggiamento"
const SLOT_LOCKED_TEXT: String = "Slot al liv. %d"
const SLOT_EMPTY_TEXT: String = "Slot vuoto"
const ABILITY_READY_TEXT: String = "pronta"
const ABILITY_COOLDOWN_TEXT: String = "ricarica %s s"
const ABILITY_OFF_TEXT: String = "disattivata"
const NOT_FOR_SETUP_TEXT: String = "non con questo assetto"
const VS_TEXT: String = "VS"
const YIELD_TITLE: String = "Rendimento"
const YIELD_WINDOW_HOUR_TEXT: String = "ultima ora"
const YIELD_WINDOW_MINUTES_TEXT: String = "ultimi %d min"
const YIELD_WINDOW_ONE_MINUTE_TEXT: String = "ultimo minuto"
const YIELD_WINDOW_SHORT_TEXT: String = "da pochi istanti"
const YIELD_LABELS: Dictionary[StringName, String] = {
	&"kills": "uccisioni/ora", &"xp": "XP/ora", &"gold": "oro/ora", &"damage": "danno/s",
}
const LOG_SUMMARY_TEXT: String = "Registro: %s · %s · %s · %s"
const LOG_HITS_ONE_TEXT: String = "1 colpo"
const LOG_HITS_TEXT: String = "%s colpi"
const LOG_ABILITIES_ONE_TEXT: String = "1 abilità"
const LOG_ABILITIES_TEXT: String = "%s abilità"
const LOG_BLOCKS_ONE_TEXT: String = "1 parata"
const LOG_BLOCKS_TEXT: String = "%s parate"
const LOG_MEALS_ONE_TEXT: String = "1 cibo"
const LOG_MEALS_TEXT: String = "%s cibi"
const LOG_ABILITY_TEXT: String = "Usi %s."
const LOG_TRAIT_TEXT: String = "Il tratto %s scatta."
const BUFF_ACTIVE_TEXT: String = "attiva %s s"
const FEEDBACK_FLASH_SEC: float = 0.35
const LOG_HIDE_TEXT: String = "Chiudi il registro"
const LOG_EMPTY_TEXT: String = "Nessun evento ancora."
const LOG_PLAYER_HIT_TEXT: String = "Colpisci %s per %s."
const LOG_PLAYER_MISS_TEXT: String = "Manchi %s."
const LOG_ENEMY_HIT_TEXT: String = "%s ti colpisce per %s."
const LOG_ENEMY_MISS_TEXT: String = "%s ti manca."
const LOG_BLOCK_TEXT: String = "Pari il colpo di %s."
const LOG_KILL_TEXT: String = "%s sconfitto."
const LOG_EAT_TEXT: String = "Mangi %s (+%s PV)."


## Interval in milliseconds as seconds with one decimal and a comma ("2,0").
static func seconds_text(ms: int) -> String:
	return String.num(ms / 1000.0, 1).replace(".", ",")


## "<stat name>: <value>" for a key of STAT_NAME_SOURCES, the name read from the stat registry of `data`.
static func stat_line(data: GameData, key: StringName, value: int) -> String:
	var info: Dictionary = data.stats.info(STAT_NAME_SOURCES[key])
	return STAT_LINE_TEXT % [str(info.get("name", key)), NumberFormat.format_int(value)]


## Smallest damage drawn as a "strong" hit: the given share (`UiStyle.COMBAT_STRONG_HIT_FRACTION`) of the player's
## maximum hit, rounded up. Presentation only.
static func strong_hit_threshold(max_hit: int) -> int:
	return ceili(max_hit * UiStyle.COMBAT_STRONG_HIT_FRACTION)


## "ultima ora" / "ultimi N min" / "da pochi istanti" for the length of the yield window.
static func yield_window_text(window_ms: int) -> String:
	if window_ms >= CombatYield.WINDOW_MS:
		return YIELD_WINDOW_HOUR_TEXT
	if window_ms >= CombatYield.MS_PER_MINUTE:
		var minutes: int = window_ms / CombatYield.MS_PER_MINUTE
		return YIELD_WINDOW_ONE_MINUTE_TEXT if minutes == 1 else YIELD_WINDOW_MINUTES_TEXT % minutes
	return YIELD_WINDOW_SHORT_TEXT


static func group_size_text(count: int) -> String:
	return GROUP_SIZE_ONE_TEXT if count == 1 else GROUP_SIZE_TEXT % count


## "1 colpo" / "N colpi" (singular for exactly one).
static func counted(count: int, one_text: String, many_text: String) -> String:
	return one_text if count == 1 else many_text % NumberFormat.format_int(count)


## Closed summary of the log, with singular and plural: "Registro: 1 colpo · 2 abilità · 0 parate · 1 cibo".
static func log_summary(hits: int, abilities: int, blocks: int, meals: int) -> String:
	return LOG_SUMMARY_TEXT % [counted(hits, LOG_HITS_ONE_TEXT, LOG_HITS_TEXT),
			counted(abilities, LOG_ABILITIES_ONE_TEXT, LOG_ABILITIES_TEXT),
			counted(blocks, LOG_BLOCKS_ONE_TEXT, LOG_BLOCKS_TEXT), counted(meals, LOG_MEALS_ONE_TEXT, LOG_MEALS_TEXT)]


## The base combat values of F-70 (accuracy, evasion, damage, HP) of the player as one line each. The character page and
## the equipment page both show these lines.
static func final_stat_lines(session: GameSession) -> Array[String]:
	var stats: CombatantStats = CombatantStats.for_player(session)
	return [
		stat_line(session.data, &"accuracy", stats.accuracy),
		stat_line(session.data, &"evasion", stats.evasion),
		STAT_DAMAGE_TEXT % [NumberFormat.format_int(stats.min_hit), NumberFormat.format_int(stats.max_hit)],
		stat_line(session.data, &"max_hp", stats.max_hp),
	]
