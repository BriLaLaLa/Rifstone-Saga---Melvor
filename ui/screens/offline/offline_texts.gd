class_name OfflineTexts
extends RefCounted
## Italian texts of the offline screens (progress overlay and summary), defined once, plus the formatting of times.
## Display only: no game rule lives here.

const PROGRESS_TITLE := "Mentre eri via..."
const PROGRESS_TIME := "%s / %s"
const SUMMARY_TITLE := "Bentornato"
const CLOSE_BUTTON := "Continua"
const AWAY_LINE := "Tempo trascorso: %s"
const SIMULATED_LINE := "Tempo simulato: %s su un massimo di %s"
const CAPPED_LINE := "Il tempo via supera il limite: il resto non viene recuperato."
const NOTHING_HAPPENED := "Nulla di rilevante è successo mentre eri via."

const SECTION_PROGRESS := "ESPERIENZA E LIVELLI"
const SECTION_ITEMS := "OGGETTI"
const SECTION_COMBAT := "COMBATTIMENTO"
const SECTION_ARMORY := "ARMERIA"
const SECTION_STOPS := "INTERRUZIONI"

const CHARACTER_NAME := "Personaggio"
const XP_LINE := "%s: +%s XP"
const XP_LEVEL_LINE := "%s: +%s XP (livello %d -> %d)"
const LEVEL_ONLY_LINE := "%s: livello %d -> %d"
const ITEM_GAINED_LINE := "%s x%s"
const ITEM_CONSUMED_LINE := "%s -%s (consumati)"
const ITEM_REJECTED_LINE := "%s x%s persi: banca piena"
const GOLD_GAINED_LINE := "Oro: +%s"
const GOLD_SPENT_LINE := "Oro: -%s"
const KILLS_LINE := "%s: %s uccisioni"
const DEATHS_LINE := "Morti: %s"
const FOOD_LINE := "Cibo mangiato: %s"
const PIECES_STORED_LINE := "Pezzi conservati: %s"
const PIECES_DISMANTLED_LINE := "Pezzi smantellati dal filtro: %s"
const PIECES_REJECTED_LINE := "Pezzi persi per Armeria piena: %s"
const STOP_LINE := "%s (dopo %s)"

const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.NO_FOOD: "Cibo finito: il combattimento si è fermato",
	Reasons.PLAYER_DIED: "Il personaggio è morto",
	Reasons.MISSING_INPUTS: "Ingredienti finiti",
	Reasons.BANK_FULL: "Banca piena",
	Reasons.ARMORY_FULL: "Armeria piena",
	Reasons.REQUIREMENT_NOT_MET: "Requisito non soddisfatto",
	Reasons.LEVEL_TOO_LOW: "Livello troppo basso",
	Reasons.STOPPED_BY_USER: "Attività interrotta",
	Reasons.REPLACED: "Attività sostituita",
}
const REASON_UNKNOWN := "Attività interrotta (%s)"

const MS_PER_SECOND: int = 1000
const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60


## "3 h 12 min", "12 min 5 s", "40 s": the two largest units.
@warning_ignore("integer_division")
static func duration(ms: int) -> String:
	var total_seconds: int = maxi(ms, 0) / MS_PER_SECOND
	var hours: int = total_seconds / (SECONDS_PER_MINUTE * MINUTES_PER_HOUR)
	var minutes: int = (total_seconds / SECONDS_PER_MINUTE) % MINUTES_PER_HOUR
	var seconds: int = total_seconds % SECONDS_PER_MINUTE
	if hours > 0:
		return "%d h %d min" % [hours, minutes]
	if minutes > 0:
		return "%d min %d s" % [minutes, seconds]
	return "%d s" % seconds


static func reason_text(reason: StringName) -> String:
	if REASON_TEXTS.has(reason):
		return REASON_TEXTS[reason]
	return REASON_UNKNOWN % reason
