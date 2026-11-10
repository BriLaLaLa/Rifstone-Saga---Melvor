class_name SkipStoneControl
extends HBoxContainer
## "Salta i Monoliti fino al livello X" (docs/METIN.md Z7; 0 = off) in the header of the combat page. The value shown is
## read from `combat.skip_stone_level()` (slot state); a change is the command `combat.set_skip_stone_level`, whose result
## goes to the page through `result_given` (a refusal shows its reason). Keeps only its two nodes.

signal result_given(result: CommandResult)

const MAX_LEVEL: int = 99

var _session: GameSession = null
var _spin: SpinBox = null


func _ready() -> void:
	var label := Label.new()
	label.text = CrowdTexts.SKIP_LABEL_TEXT
	label.theme_type_variation = &"MutedLabel"
	add_child(label)
	_spin = SpinBox.new()
	_spin.min_value = 0
	_spin.max_value = MAX_LEVEL
	_spin.step = 1
	_spin.tooltip_text = CrowdTexts.SKIP_TIP_TEXT
	_spin.value_changed.connect(_on_value_changed)
	add_child(_spin)


## Starts reading `session` (null to stop) and shows the current value.
func bind(session: GameSession) -> void:
	_session = session
	refresh()


## Rereads the setting (also after `skip_stone_changed`) without sending a command.
func refresh() -> void:
	if _session != null and _spin != null:
		_spin.set_value_no_signal(_session.combat.skip_stone_level())


func spin_box() -> SpinBox:
	return _spin


func _on_value_changed(value: float) -> void:
	if _session != null:
		result_given.emit(_session.combat.set_skip_stone_level(int(value)))
		refresh()
