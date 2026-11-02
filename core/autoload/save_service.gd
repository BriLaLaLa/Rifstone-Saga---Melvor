class_name SaveStore
extends Node
## Slot file store (autoload `SaveService`): reads and writes slot dictionaries, versions and migrations.
## It does not know GameSession.
##
## Stub of task M0-03 with the final signatures: nothing is read or written, every command fails with io_error.
## The real store arrives with M1-06. Contract type SlotInfo (core/save/slot_info.gd, M1-06) does not exist yet,
## so the slot info returns are typed with its base class RefCounted until it does.

var base_dir: String = "user://saves"
var last_error: StringName = &""


@warning_ignore("unused_parameter")
func configure(slot_count: int) -> void:
	pass


func slot_path(slot: int) -> String:
	return base_dir + "/slot_%d.json" % slot


@warning_ignore("unused_parameter")
func slot_exists(slot: int) -> bool:
	return false


@warning_ignore("unused_parameter")
func read_slot(slot: int) -> Dictionary:
	last_error = Reasons.IO_ERROR
	return {}


@warning_ignore("unused_parameter")
func write_slot(slot: int, payload: Dictionary) -> CommandResult:
	last_error = Reasons.IO_ERROR
	return CommandResult.fail(Reasons.IO_ERROR)


@warning_ignore("unused_parameter")
func delete_slot(slot: int) -> CommandResult:
	last_error = Reasons.IO_ERROR
	return CommandResult.fail(Reasons.IO_ERROR)


@warning_ignore("unused_parameter")
func read_slot_info(slot: int) -> RefCounted:
	return null


func list_slots() -> Array[RefCounted]:
	return []
