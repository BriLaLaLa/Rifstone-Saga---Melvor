class_name QuestRow
extends PanelContainer
## One slot of the Noticeboard (docs/05_INTERFACES.md §7.s): name, description, progress bar, reward and the
## Riscuoti / Abbandona buttons; an empty slot shows only a message. Everything shown is read from the quests module
## and the data at every `refresh`; the row keeps only its slot index and references to its own nodes.
## `quests` is used through the contract signatures of §5.28 only; `definitions` answers `quest(id)`, `skill(id)`,
## `has_item(id)` and `item(id)` like GameData.

signal claim_requested(slot: int)
signal abandon_requested(slot: int)

const SEPARATION: int = 6
const ICON_SIDE: int = 24
const BAR_MIN_WIDTH: float = 260.0
const REWARD_SEPARATION: int = 8
const FILLED_SEPARATION: int = 16

var slot: int = 0
var _name_label: Label = null
var _description_label: Label = null
var _bar: ProgressBar = null
var _bar_label: Label = null
var _reward_box: HBoxContainer = null
var _claim_button: Button = null
var _abandon_button: Button = null
var _reason_label: Label = null
var _empty_label: Label = null
var _filled_box: HBoxContainer = null


## Builds the nodes of the row of slot `slot_index`.
func setup(slot_index: int) -> void:
	slot = slot_index
	name = "Row_%d" % slot_index
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", SEPARATION)
	add_child(root)
	_empty_label = _label(root, NoticeboardTexts.EMPTY_SLOT_TEXT, &"MutedLabel")
	_empty_label.name = "EmptyLabel"
	_filled_box = HBoxContainer.new()
	_filled_box.name = "FilledBox"
	_filled_box.add_theme_constant_override("separation", FILLED_SEPARATION)
	root.add_child(_filled_box)
	var text_column: VBoxContainer = VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filled_box.add_child(text_column)
	_name_label = _label(text_column, "", &"HeaderLabel")
	_name_label.name = "NameLabel"
	_description_label = _label(text_column, "", &"MutedLabel")
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_box = HBoxContainer.new()
	_reward_box.name = "RewardBox"
	_reward_box.add_theme_constant_override("separation", REWARD_SEPARATION)
	text_column.add_child(_reward_box)
	var progress_column: VBoxContainer = VBoxContainer.new()
	progress_column.custom_minimum_size.x = BAR_MIN_WIDTH
	progress_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_filled_box.add_child(progress_column)
	_bar = ProgressBar.new()
	_bar.name = "ProgressBar"
	_bar.show_percentage = false
	_bar.step = 1.0
	progress_column.add_child(_bar)
	_bar_label = _label(progress_column, "", &"")
	_bar_label.name = "ProgressLabel"
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_filled_box.add_child(buttons)
	_claim_button = Button.new()
	_claim_button.name = "ClaimButton"
	_claim_button.text = NoticeboardTexts.CLAIM_TEXT
	_claim_button.theme_type_variation = &"AccentButton"
	_claim_button.focus_mode = Control.FOCUS_NONE
	_claim_button.pressed.connect(func() -> void: claim_requested.emit(slot))
	buttons.add_child(_claim_button)
	_abandon_button = Button.new()
	_abandon_button.name = "AbandonButton"
	_abandon_button.text = NoticeboardTexts.ABANDON_TEXT
	_abandon_button.focus_mode = Control.FOCUS_NONE
	_abandon_button.pressed.connect(func() -> void: abandon_requested.emit(slot))
	buttons.add_child(_abandon_button)
	_reason_label = _label(root, "", &"")
	_reason_label.name = "ReasonLabel"
	_reason_label.add_theme_color_override("font_color", UiStyle.BAD)


## Rereads the slot from `quests` (a Quests, 5.28) and `definitions` (GameData-like).
func refresh(quests: Object, definitions: Object) -> void:
	var quest_id: StringName = quests.quest_at(slot)
	var filled: bool = quest_id != &""
	_empty_label.visible = not filled
	_filled_box.visible = filled
	_reason_label.visible = false
	if not filled:
		return
	var def: Object = definitions.call("quest", quest_id)
	_name_label.text = str(def.get("name")) if def != null else String(quest_id)
	_description_label.text = str(def.get("description")) if def != null else ""
	var target: int = quests.target_at(slot)
	var progress: int = quests.progress_at(slot)
	_bar.max_value = maxi(target, 1)
	_bar.value = progress
	_bar_label.text = NoticeboardTexts.PROGRESS_TEXT % [NumberFormat.format_int(progress), NumberFormat.format_int(target)]
	_draw_reward(def, definitions)
	var can: CommandResult = quests.can_claim(slot)
	_claim_button.disabled = not can.ok
	_abandon_button.disabled = false
	var reason_text: String = "" if can.ok else NoticeboardTexts.refused(can.reason)
	_claim_button.tooltip_text = reason_text
	# An incomplete quest is already visible from the bar: the reason is written only for the other refusals.
	_reason_label.text = reason_text
	_reason_label.visible = not can.ok and can.reason != NoticeboardTexts.INCOMPLETE_REASON


func _draw_reward(def: Object, definitions: Object) -> void:
	for child: Node in _reward_box.get_children():
		_reward_box.remove_child(child)
		child.queue_free()
	if def == null:
		return
	_label(_reward_box, NoticeboardTexts.REWARD_TITLE_TEXT, &"MutedLabel")
	var parts: PackedStringArray = PackedStringArray()
	var gold: int = int(def.get("reward_gold"))
	if gold > 0:
		parts.append(NoticeboardTexts.REWARD_GOLD_TEXT % NumberFormat.format_int(gold))
	var xp_skill: StringName = def.get("reward_xp_skill")
	var xp: int = int(def.get("reward_xp"))
	if xp_skill != &"" and xp > 0:
		var skill_def: Object = definitions.call("skill", xp_skill)
		var skill_name: String = str(skill_def.get("name")) if skill_def != null else String(xp_skill)
		parts.append(NoticeboardTexts.REWARD_XP_TEXT % [NumberFormat.format_int(xp), skill_name])
	if not parts.is_empty():
		var money: Label = _label(_reward_box, NoticeboardTexts.REWARD_SEPARATOR.join(parts), &"")
		money.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT)
	for entry: Variant in def.get("reward_items"):
		var item_id: StringName = entry.get("item_id")
		if not bool(definitions.call("has_item", item_id)):
			continue
		var item: Object = definitions.call("item", item_id)
		var icon: TextureRect = TextureRect.new()
		icon.texture = ItemSlotView.icon_of(str(item.get("icon")))
		icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_reward_box.add_child(icon)
		_label(_reward_box, NoticeboardTexts.REWARD_ITEM_TEXT % [str(item.get("name")),
				NumberFormat.format_int(int(entry.get("qty")))], &"")


func _label(parent: Node, text: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	parent.add_child(label)
	return label
