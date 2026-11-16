class_name QueueTexts
extends RefCounted
## Italian texts of the production queue panel and of the "Metti in coda" controls (docs/01_GDD_M24.md §35.4, §35.11).
## Presentation only: durations are the model's (`estimate_ms`), only formatted here.

const TITLE_TEXT: String = "Coda di produzione"
const COUNT_TEXT: String = "%s / %s lavori"
const TOTAL_TEXT: String = "Tempo totale stimato: %s"
const EMPTY_TEXT: String = "La coda è vuota."
const ROW_TEXT: String = "%s  x%s"
const ROW_REPEAT_TEXT: String = "%s  (ripeti)"
const ROW_BLUEPRINT_TEXT: String = "Progetto: %s"
const ROW_ESTIMATE_TEXT: String = "%s"
const WAITING_TEXT: String = "In attesa: Deposito pieno"
const CANCEL_TEXT: String = "Annulla"
const UP_TEXT: String = "Su"
const DOWN_TEXT: String = "Giù"
const ENQUEUE_TEXT: String = "Metti in coda"
const QUANTITY_TEXT: String = "Quantità"
const REPEAT_TEXT: String = "Ripeti"
const SHORTCUTS: Array[int] = [1, 10, 100]
const SHORTCUT_TEXT: String = "x%s"
const LOCKED_TEXT: String = "Da scoprire"
const LOCKED_TIP: String = "Ricetta da scoprire: si impara da una Ricetta trovata."
const DAY_TEXT: String = "%s g %s h"
const HOUR_TEXT: String = "%s h %s min"
const MINUTE_TEXT: String = "%s min %s s"
const SECOND_TEXT: String = "%s s"
const MS_PER_SECOND: int = 1000
const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24


## A duration in milliseconds as "2 h 5 min", "3 min 10 s" or "45 s" (formatting only).
@warning_ignore("integer_division")
static func duration(ms: int) -> String:
	var seconds: int = maxi(0, ms) / MS_PER_SECOND
	var minutes: int = seconds / SECONDS_PER_MINUTE
	var hours: int = minutes / MINUTES_PER_HOUR
	if hours >= HOURS_PER_DAY:
		return DAY_TEXT % [hours / HOURS_PER_DAY, hours % HOURS_PER_DAY]
	if hours > 0:
		return HOUR_TEXT % [hours, minutes % MINUTES_PER_HOUR]
	if minutes > 0:
		return MINUTE_TEXT % [minutes, seconds % SECONDS_PER_MINUTE]
	return SECOND_TEXT % seconds
