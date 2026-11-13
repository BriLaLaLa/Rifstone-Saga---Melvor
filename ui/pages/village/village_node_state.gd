class_name VillageNodeState
extends RefCounted
## State of a node of the Village map (docs/01_GDD.md §32): a pure function of the building's level and of the first
## reason of `Village.can_upgrade`; derived on every redraw, never stored.

const LOCKED: StringName = &"locked"
const UNBUILT: StringName = &"unbuilt"
const READY: StringName = &"ready"
const BUILT: StringName = &"built"
const MAXED: StringName = &"maxed"
const PLACEHOLDER: StringName = &"placeholder"

const REASON_OK: StringName = &"ok"
const REASON_LEVEL_TOO_LOW: StringName = &"level_too_low"


## `upgrade_reason` is `&"ok"` or the reason of `can_upgrade`.
static func of(level: int, max_level: int, buildable: bool, upgrade_reason: StringName) -> StringName:
	if not buildable:
		return PLACEHOLDER
	if level >= max_level:
		return MAXED
	if upgrade_reason == REASON_OK:
		return READY
	if level == 0:
		return LOCKED if upgrade_reason == REASON_LEVEL_TOO_LOW else UNBUILT
	return BUILT
