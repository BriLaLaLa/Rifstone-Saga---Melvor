class_name StarterRow
extends PanelContainer
## One starter quest on the Primi passi page: name, description, reward, bar `n/target` and Riscuoti (or "Riscosso").
## Everything is read from the `StarterQuests` module at every `refresh`; the row keeps only the quest id and its nodes.

signal claim_requested(quest_id: StringName)

const SEPARATION: int = 6
const FILLED_SEPARATION: int = 16
const REWARD_SEPARATION: int = 8

var quest_id: StringName = &""
var _name_label: Label
var _description_label: Label
var _reward_box: HBoxContainer
var _bar: ProgressBar
var _bar_label: Label
var _claim_button: Button
var _claimed_label: Label
var _reward_key: String = ""


## Builds the nodes of the row of `def`.
func setup(def: StarterQuestDef) -> void:
	quest_id = def.id
	name = "Row_%s" % def.id
	theme_type_variation = &"HudPanel"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", FILLED_SEPARATION)
	add_child(box)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", SEPARATION)
	box.add_child(texts)
	_name_label = _label(texts, "NameLabel", def.name, &"HeaderLabel")
	_description_label = _label(texts, "DescriptionLabel", def.description, &"MutedLabel")
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_box = HBoxContainer.new()
	_reward_box.name = "RewardBox"
	_reward_box.add_theme_constant_override("separation", REWARD_SEPARATION)
	texts.add_child(_reward_box)
	var progress := VBoxContainer.new()
	progress.custom_minimum_size.x = UiStyle.STARTER_BAR_WIDTH
	progress.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(progress)
	_bar = ProgressBar.new()
	_bar.name = "ProgressBar"
	_bar.custom_minimum_size.y = UiStyle.STARTER_WIDGET_BAR_HEIGHT
	_bar.show_percentage = false
	_bar.step = 1.0
	progress.add_child(_bar)
	_bar_label = _label(progress, "ProgressLabel", "", &"")
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.custom_minimum_size.x = UiStyle.STARTER_BAR_WIDTH * 0.5
	box.add_child(buttons)
	_claim_button = Button.new()
	_claim_button.name = "ClaimButton"
	_claim_button.text = StarterTexts.CLAIM_TEXT
	_claim_button.theme_type_variation = &"AccentButton"
	_claim_button.focus_mode = Control.FOCUS_NONE
	_claim_button.pressed.connect(func() -> void: claim_requested.emit(quest_id))
	buttons.add_child(_claim_button)
	_claimed_label = _label(buttons, "ClaimedLabel", StarterTexts.CLAIMED_TEXT, &"MutedLabel")
	_claimed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Rereads the quest from `starter`; `data` gives names, icons and the currency of the reward.
func refresh(starter: StarterQuests, data: GameData) -> void:
	var def: StarterQuestDef = data.starter_quest(quest_id)
	if def == null:
		return
	var target: int = starter.target(quest_id)
	var progress: int = starter.progress(quest_id)
	var claimed: bool = starter.is_claimed(quest_id)
	_bar.max_value = maxi(target, 1)
	_bar.value = progress
	_bar_label.text = StarterTexts.COUNT_TEXT % [progress, target]
	var can: CommandResult = starter.can_claim(quest_id)
	_claim_button.visible = not claimed
	_claim_button.disabled = not can.ok
	_claim_button.tooltip_text = "" if can.ok or can.reason == Reasons.QUEST_INCOMPLETE else StarterTexts.refused(can.reason)
	_claimed_label.visible = claimed
	modulate = UiStyle.STARTER_DONE_MODULATE if claimed else Color.WHITE
	_draw_reward(def, data)


func _draw_reward(def: StarterQuestDef, data: GameData) -> void:
	if _reward_key == String(def.id):
		return
	_reward_key = String(def.id)
	StarterRewardView.draw(_reward_box, def.reward_money, def.reward_items, def.reward_character_xp, data)


func _label(parent: Node, node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
