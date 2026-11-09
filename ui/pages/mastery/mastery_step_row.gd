class_name MasteryStepRow
extends HBoxContainer
## Mastery lines of an action card (docs/01_GDD.md §6.5, docs/05_INTERFACES.md §7.u): the bonuses reached now and the next
## one ("Al livello 40: ..."). It draws the `info` of `MasterySystem.step_info` and keeps no
## state; the labels of the stats come from the registry through `LoadoutDescribe`.

const CURRENT_TEXT: String = "Bonus attuali: %s"
const NONE_TEXT: String = "Nessun bonus ancora."
const MAX_TEXT: String = "Tutti i bonus di maestria raggiunti."

var _data: GameData = null
var _label: Label = null


func _init() -> void:
	_label = Label.new()
	_label.name = "StepLabel"
	_label.theme_type_variation = &"MutedLabel"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)


func setup(data: GameData) -> void:
	_data = data


## Draws `info` (`level`, `n`, `current`, `next`); an empty dictionary hides the row.
func show_info(info: Dictionary) -> void:
	visible = not info.is_empty() and _data != null
	if not visible:
		return
	var current: Array[Modifier] = []
	current.assign(info["current"])
	var lines: PackedStringArray = PackedStringArray()
	lines.append(CURRENT_TEXT % LoadoutDescribe.modifiers_text(current, _data) if not current.is_empty() else NONE_TEXT)
	var next: Dictionary = info["next"]
	lines.append(str(next["text"]) if not next.is_empty() else MAX_TEXT)
	_label.text = "\n".join(lines)


func shown_text() -> String:
	return _label.text
