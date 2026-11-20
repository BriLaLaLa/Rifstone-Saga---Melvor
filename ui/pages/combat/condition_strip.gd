class_name ConditionStrip
extends HFlowContainer
## Row of chips (icon, number, seconds left) with the conditions of one enemy (GDD M28 §40.3, 05_INTERFACES_M28.md §7.aa). It draws
## `get_state().enemies[i].conditions`; no state of its own beyond its nodes. Hidden while the enemy has no condition.

const ORDER: Array[StringName] = [ConditionTexts.BLEED, ConditionTexts.WEAKEN, ConditionTexts.EXPOSE, ConditionTexts.STAGGER]
const SEPARATION: int = 6

var _chips: Dictionary[StringName, HBoxContainer] = {}
var _labels: Dictionary[StringName, Label] = {}


func _init() -> void:
	name = "Conditions"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", SEPARATION)
	add_theme_constant_override("v_separation", 2)
	for id: StringName in ORDER:
		var chip := HBoxContainer.new()
		chip.name = "Chip_%s" % id
		chip.visible = false
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.texture = ConditionTexts.icon(id)
		icon.custom_minimum_size = Vector2.ONE * UiStyle.COMBAT_CONDITION_ICON_SIDE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", UiStyle.COMBAT_CONDITION_COLORS[id])
		chip.add_child(label)
		add_child(chip)
		_chips[id] = chip
		_labels[id] = label


## Draws `conditions` (`get_state().enemies[i].conditions`); `tick_ms` = the Bleed tick from the balance data.
func show_conditions(conditions: Dictionary, tick_ms: int) -> void:
	visible = not conditions.is_empty()
	for id: StringName in ORDER:
		var data: Dictionary = conditions.get(id, {})
		_chips[id].visible = conditions.has(id)
		if conditions.has(id):
			_labels[id].text = ConditionTexts.chip_text(id, data, tick_ms)
			_chips[id].tooltip_text = ConditionTexts.chip_tip(id, data)


# --- For tests ---

## Ids of the chips shown, in order.
func shown_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in ORDER:
		if _chips[id].visible:
			ids.append(id)
	return ids


func chip_label(id: StringName) -> String:
	return _labels[id].text
