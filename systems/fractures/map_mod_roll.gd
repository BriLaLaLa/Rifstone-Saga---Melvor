class_name MapModRoll
extends RefCounted
## A modifier rolled on a Card (docs/05_INTERFACES.md §5.23, F-109): the id and the intensity step. The values are
## recomputed from the data (`MapCardRoller.effects`), so a saved Card keeps only `{mod, step}`.

var mod_id: StringName = &""
var step: int = 0


static func make(mod_id_value: StringName, step_value: int) -> MapModRoll:
	var roll := MapModRoll.new()
	roll.mod_id = mod_id_value
	roll.step = step_value
	return roll
