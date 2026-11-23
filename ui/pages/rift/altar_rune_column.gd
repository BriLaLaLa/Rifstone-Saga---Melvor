class_name AltarRuneColumn
extends AltarColumn
## Step 2 of the Altar page: the runes of the Deposit, with effect and count. A rune that cannot be socketed is shown
## disabled with the reason. Picking a row emits `rune_selected`; the craft button opens the Engraver (or the Trainers).

signal rune_selected(item_id: StringName)
signal craft_pressed


func _init() -> void:
	name = "RuneColumn"
	custom_minimum_size.x = 280
	size_flags_stretch_ratio = 4.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	setup(2, RiftTexts.STEP2_TITLE_TEXT, RiftTexts.STEP2_HINT_TEXT)


## `selected_rune` is the rune chosen here (&"" = none).
func refresh(session: GameSession, selected_rune: StringName) -> void:
	_clear_body()
	var owned: Array[Dictionary] = RiftTexts.owned(session, &"infusion")
	if owned.is_empty():
		_muted(RiftTexts.NO_INFUSIONS_TEXT, "NoInfusions")
	for entry: Dictionary in owned:
		var def: ItemDef = entry["item"] as ItemDef
		var title: String = "%s  x%s" % [def.name, NumberFormat.format_int(int(entry["count"]))]
		var reason: String = RiftTexts.rune_block_reason(session, def.id)
		var effect: String = ItemTooltipLines.escape(RiftTexts.modifiers_inline(def.infusion_modifiers, session.data))
		var detail: String = color_text(UiStyle.GOLD_LIGHT, effect)
		if def.infusion_unique:
			detail += " " + color_text(UiStyle.TEXT_2, "(%s)" % RiftTexts.UNIQUE_TEXT)
		if reason != "":
			detail += "\n" + color_text(UiStyle.BAD, reason)
		var button: Button = _row("Pick_%s" % def.id, title, detail, def.id == selected_rune, ItemSlotView.icon_of(def.icon))
		button.disabled = reason != ""
		button.pressed.connect(func() -> void: rune_selected.emit(def.id))
	var craft := Button.new()
	craft.name = "CraftRunesButton"
	craft.text = RiftTexts.CRAFT_RUNES_TEXT if session.disciplines.is_learned(RiftAltar.SKILL) else RiftTexts.LEARN_ENGRAVER_TEXT
	craft.focus_mode = Control.FOCUS_NONE
	craft.custom_minimum_size.y = UiStyle.MENU_BUTTON_HEIGHT
	craft.pressed.connect(func() -> void: craft_pressed.emit())
	_body.add_child(craft)
