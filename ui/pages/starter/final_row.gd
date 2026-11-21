class_name FinalRow
extends PanelContainer
## The final bonus of the Primi passi page: name, description, reward and Riscuoti (disabled, with a hint, until 20/20). It reads
## `StarterQuests` at every `refresh` and keeps only its nodes; the click only emits `claim_requested`.

signal claim_requested

const SEPARATION: int = 6
const FILLED_SEPARATION: int = 16

var _name_label: Label
var _description_label: Label
var _reward_box: HBoxContainer
var _hint_label: Label
var _claim_button: Button
var _claimed_label: Label
var _reward_name: String = ""


func _init() -> void:
	name = "FinalRow"
	theme_type_variation = &"HudPanel"
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", FILLED_SEPARATION)
	add_child(box)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", SEPARATION)
	box.add_child(texts)
	var title := _label(texts, "TitleLabel", StarterTexts.FINAL_TITLE_TEXT, &"MutedLabel")
	title.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	_name_label = _label(texts, "NameLabel", "", &"HeaderLabel")
	_description_label = _label(texts, "DescriptionLabel", "", &"MutedLabel")
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_box = HBoxContainer.new()
	_reward_box.name = "RewardBox"
	_reward_box.add_theme_constant_override("separation", StarterRow.REWARD_SEPARATION)
	texts.add_child(_reward_box)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.custom_minimum_size.x = UiStyle.STARTER_BAR_WIDTH
	box.add_child(buttons)
	_claim_button = Button.new()
	_claim_button.name = "ClaimButton"
	_claim_button.text = StarterTexts.CLAIM_TEXT
	_claim_button.theme_type_variation = &"AccentButton"
	_claim_button.focus_mode = Control.FOCUS_NONE
	_claim_button.pressed.connect(func() -> void: claim_requested.emit())
	buttons.add_child(_claim_button)
	_hint_label = _label(buttons, "HintLabel", StarterTexts.FINAL_LOCKED_TEXT, &"MutedLabel")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_claimed_label = _label(buttons, "ClaimedLabel", StarterTexts.CLAIMED_TEXT, &"MutedLabel")
	_claimed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func refresh(starter: StarterQuests, data: GameData) -> void:
	var def: StarterFinalDef = starter.final_reward()
	var claimed: bool = starter.is_final_claimed()
	var can: CommandResult = starter.can_claim_final()
	_name_label.text = def.name
	_description_label.text = def.description
	_claim_button.visible = not claimed
	_claim_button.disabled = not can.ok
	_claim_button.tooltip_text = "" if can.ok or can.reason == Reasons.QUEST_INCOMPLETE else StarterTexts.refused(can.reason)
	_hint_label.visible = not claimed and can.reason == Reasons.QUEST_INCOMPLETE
	_claimed_label.visible = claimed
	modulate = UiStyle.STARTER_DONE_MODULATE if claimed else Color.WHITE
	if _reward_name != String(def.id):
		_reward_name = String(def.id)
		StarterRewardView.draw(_reward_box, def.reward_money, def.reward_items, def.reward_character_xp, data)


func _label(parent: Node, node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
