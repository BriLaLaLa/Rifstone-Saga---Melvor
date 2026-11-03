class_name SlotTexts
extends RefCounted
## Italian texts of the slot screens: command errors, slot states, save date and play time (display only).
##
## The name length in the invalid_name message is read from balance.json with the Game coordinator's keys, so the
## rule has a single definition. Numbers use NumberFormat.format_int.

const GameScript := preload("res://core/autoload/game.gd")
const STATE_EMPTY := &"empty"
const STATE_OK := &"ok"
const STATE_CORRUPTED := &"corrupted"
const STATE_UNSUPPORTED := &"unsupported"
const STATE_TEXTS: Dictionary[StringName, String] = {
	STATE_EMPTY: "Slot vuoto",
	STATE_OK: "Partita salvata",
	STATE_CORRUPTED: "Salvataggio danneggiato: si può solo eliminare",
	STATE_UNSUPPORTED: "Versione non supportata: salvato da una versione più recente del gioco",
}
const REASON_TEXTS: Dictionary[StringName, String] = {
	Reasons.SLOT_ACTIVE: "Lo slot è in uso da una partita aperta: chiudila prima.",
	Reasons.IO_ERROR: "Impossibile leggere o scrivere lo slot.",
	Reasons.CORRUPTED: "Il salvataggio è danneggiato e non si può caricare.",
	Reasons.VERSION_UNSUPPORTED: "Il salvataggio è di una versione più recente del gioco e non si può caricare.",
}
const INVALID_NAME_TEXT := "Il nome deve avere da %d a %d caratteri (gli spazi ai bordi non contano)."
const UNKNOWN_REASON_TEXT := "Operazione non riuscita (%s)."
const UNKNOWN_STATE_TEXT := "Stato sconosciuto"
const MS_PER_SECOND: int = 1000
const SECONDS_PER_MINUTE: int = 60
const MINUTES_PER_HOUR: int = 60


## Message for a failed command.
static func reason_text(reason: StringName) -> String:
	if reason == Reasons.INVALID_NAME:
		var data: GameData = DataRegistry.data
		return INVALID_NAME_TEXT % [int(data.balance_value(GameScript.NAME_MIN_LENGTH_KEY)),
				int(data.balance_value(GameScript.NAME_MAX_LENGTH_KEY))]
	if REASON_TEXTS.has(reason):
		return REASON_TEXTS[reason]
	return UNKNOWN_REASON_TEXT % reason


static func state_text(state: StringName) -> String:
	if STATE_TEXTS.has(state):
		return STATE_TEXTS[state]
	return UNKNOWN_STATE_TEXT


## "Slot 2" or "Slot 2 · Aria" for a slot with a game.
static func slot_title(info: SlotInfo) -> String:
	if info.state == STATE_OK:
		return "Slot %d  ·  %s" % [info.slot, info.player_name]
	return "Slot %d" % info.slot


## Details of a slot: date, play time and total level for a saved game, the state text otherwise.
static func slot_details(info: SlotInfo) -> String:
	if info.state != STATE_OK:
		return state_text(info.state)
	return "Salvata il %s  ·  Tempo di gioco %s  ·  Livello totale %s" % [
		saved_at(info.saved_at_unix_ms), play_time(info.play_time_ms), NumberFormat.format_int(info.total_level)]


## "1 h 05 min" or "12 min" (whole minutes, rounded down).
@warning_ignore("integer_division")
static func play_time(ms: int) -> String:
	var minutes: int = maxi(ms, 0) / (MS_PER_SECOND * SECONDS_PER_MINUTE)
	var hours: int = minutes / MINUTES_PER_HOUR
	if hours == 0:
		return "%d min" % minutes
	return "%s h %02d min" % [NumberFormat.format_int(hours), minutes % MINUTES_PER_HOUR]


## Local date and time of a save: "03/11/2026 14:05".
@warning_ignore("integer_division")
static func saved_at(unix_ms: int) -> String:
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local_s: int = unix_ms / MS_PER_SECOND + bias_minutes * SECONDS_PER_MINUTE
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(local_s)
	return "%02d/%02d/%04d %02d:%02d" % [dt["day"], dt["month"], dt["year"], dt["hour"], dt["minute"]]
