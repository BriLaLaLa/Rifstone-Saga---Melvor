class_name SlotInfo
extends RefCounted
## Menu summary of one save slot, read from the header fields of the slot file (05_INTERFACES.md §6).
##
## Built by SaveStore.read_slot_info; it is a plain value, it never touches the disk.
## Header fields are filled only when state is &"ok"; otherwise they keep their defaults.

var slot: int = 0
var state: StringName = &"empty" # &"empty", &"ok", &"corrupted", &"unsupported"
var player_name: String = ""
var saved_at_unix_ms: int = 0
var play_time_ms: int = 0
var total_level: int = 0
