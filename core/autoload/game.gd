extends Node
## Game coordinator (autoload `Game`): creates and closes the GameSession, autosave, offline, clock wiring.
##
## Stub of task M0-03 with the final signatures: there is never a session, so save_now fails with
## slot_not_selected and every other command with no_session. The real coordinator arrives with M1-11.
## Contract types GameSession (M1-05), SlotInfo (M1-06) and OfflineSummary (M6-01) do not exist yet,
## so they are typed with their base classes (Node, RefCounted) until they do.

var session: Node = null
var active_slot: int = -1
var state: StringName = &"menu" # &"menu", &"loading", &"offline", &"playing"
var last_offline_summary: RefCounted = null


func list_slots() -> Array[RefCounted]:
	return []


@warning_ignore("unused_parameter")
func new_game(slot: int, player_name: String) -> CommandResult:
	return CommandResult.fail(Reasons.NO_SESSION)


@warning_ignore("unused_parameter")
func continue_game(slot: int) -> CommandResult:
	return CommandResult.fail(Reasons.NO_SESSION)


func save_now() -> CommandResult:
	return CommandResult.fail(Reasons.SLOT_NOT_SELECTED)


@warning_ignore("unused_parameter")
func end_session(save: bool = true) -> void:
	pass


@warning_ignore("unused_parameter")
func delete_slot(slot: int) -> CommandResult:
	return CommandResult.fail(Reasons.NO_SESSION)
