class_name PlayerColumn
extends PanelContainer
## Player side of the combat page (docs/UI_GDR.md §2, gold frame): portrait (class icon), name, level and setup,
## triangle reminder, HP and attack bars, ability slots with their cooldown, trait slots and the 12-slot equipment
## grid with the shared piece tooltip.
##
## `refresh_static` rereads names, loadout and equipment (called on the matching signals); `tick` moves the bars and the
## cooldowns every frame from `combat.get_state()`. The column keeps only its nodes (the cards of the ability slots by
## position) and a flag for the tooltip; abilities and traits come from `session.loadout`.

var _session: GameSession = null
var _gear: Dictionary[StringName, GearCell] = {}
## One entry per open or locked ability slot: {"id": StringName, "bar": ProgressBar, "state": Label}.
var _ability_cards: Array[Dictionary] = []
## Ability cards and trait chips by id, to flash them (`flash_entry`); rebuilt with the sections.
var _entries: Dictionary[StringName, Control] = {}
var _entry_flash: Dictionary[StringName, Tween] = {}
var _hovering: bool = false
var _flash: Tween = null
var _last_hit_text: String = ""

@onready var _portrait: Control = %Portrait
@onready var _frame: Panel = %Frame
@onready var _icon: TextureRect = %Icon
@onready var _floaters: Control = %Floaters
@onready var _name: Label = %NameLabel
@onready var _level: Label = %LevelLabel
@onready var _hint: Label = %HintLabel
@onready var _hp_title: Label = %HpTitle
@onready var _hp_label: Label = %HpLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _atk_title: Label = %AtkTitle
@onready var _atk_label: Label = %AtkLabel
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _abilities_title: Label = %AbilitiesTitle
@onready var _ability_flow: HFlowContainer = %AbilityFlow
@onready var _traits_title: Label = %TraitsTitle
@onready var _trait_flow: HFlowContainer = %TraitFlow
@onready var _gear_title: Label = %GearTitle
@onready var _gear_grid: GridContainer = %GearGrid


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_PLAYER_BG, UiStyle.COMBAT_PLAYER_BORDER,
			UiStyle.COMBAT_FRAME_WIDTH, 14.0))
	custom_minimum_size.x = UiStyle.COMBAT_PLAYER_WIDTH
	_portrait.custom_minimum_size = Vector2(UiStyle.COMBAT_PORTRAIT_SIDE, UiStyle.COMBAT_PORTRAIT_SIDE)
	_frame.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD_LIGHT,
			UiStyle.COMBAT_FRAME_WIDTH, 0.0))
	_hp_title.text = CombatTexts.HP_TITLE
	_atk_title.text = CombatTexts.ATTACK_TITLE
	_abilities_title.text = CombatTexts.ABILITIES_TITLE
	_traits_title.text = CombatTexts.TRAITS_TITLE
	_gear_title.text = CombatTexts.GEAR_TITLE
	_hp_bar.custom_minimum_size.y = UiStyle.COMBAT_BAR_HEIGHT
	_timer_bar.custom_minimum_size.y = UiStyle.COMBAT_TIMER_BAR_HEIGHT
	_hp_bar.show_percentage = false
	_timer_bar.show_percentage = false
	UiStyle.style_bar(_hp_bar, UiStyle.HP)
	UiStyle.style_bar(_timer_bar, UiStyle.COMBAT_TIMER_COLOR)
	_gear_grid.columns = UiStyle.COMBAT_GEAR_COLUMNS
	for slot: StringName in Equipment.SLOTS:
		var cell := GearCell.new()
		_gear_grid.add_child(cell)
		cell.setup(slot)
		cell.hover_started.connect(_on_gear_hover)
		cell.hover_ended.connect(hide_tooltip)
		_gear[slot] = cell


## Rereads everything that is not a per-frame bar: names, triangle reminder, loadout, equipment.
func refresh_static(session: GameSession) -> void:
	_session = session
	var class_def: ClassDef = session.character.class_def()
	var setup: SetupDef = session.equipment.setup_def()
	_name.text = class_def.name if class_def != null else ""
	_icon.texture = ItemSlotView.icon_of(class_def.icon) if class_def != null else null
	_level.text = CombatTexts.LEVEL_TEXT % [session.character.get_level(), setup.name if setup != null else ""]
	_hint.text = _triangle_hint(session)
	_refresh_abilities(session)
	_refresh_traits(session)
	_refresh_gear(session)


## Moves the bars and the cooldowns from `state` (`combat.get_state()`).
func tick(state: Dictionary) -> void:
	var hp: int = state["player_hp"]
	var max_hp: int = state["player_max_hp"]
	_hp_bar.max_value = maxf(1.0, max_hp)
	_hp_bar.value = hp
	_hp_label.text = CombatTexts.HP_NUMBERS_TEXT % [NumberFormat.format_int(hp), NumberFormat.format_int(max_hp)]
	var interval: int = state["player_interval_ms"]
	_atk_label.text = CombatTexts.SECONDS_TEXT % CombatTexts.seconds_text(interval)
	_timer_bar.value = clampf(1.0 - float(state["player_timer_ms"]) / float(interval), 0.0, 1.0) if interval > 0 else 0.0
	var running: Dictionary = {}
	for entry: Dictionary in state.get("abilities", []):
		running[entry["id"]] = entry
	for card: Dictionary in _ability_cards:
		_tick_ability(card, running.get(card["id"], {}), state.get("buffs", {}))


func _tick_ability(card: Dictionary, entry: Dictionary, buffs: Dictionary) -> void:
	var bar: ProgressBar = card["bar"]
	var label: Label = card["state"]
	if card["id"] == &"" or entry.is_empty():
		return
	var cooldown: int = entry["cooldown_ms"]
	var left: int = entry["timer_ms"]
	bar.value = clampf(1.0 - float(left) / float(cooldown), 0.0, 1.0) if cooldown > 0 else 1.0
	if buffs.has(card["id"]):
		label.text = CombatTexts.BUFF_ACTIVE_TEXT % CombatTexts.seconds_text(int(buffs[card["id"]]))
	elif not entry["enabled"]:
		label.text = CombatTexts.ABILITY_OFF_TEXT
	elif left <= 0:
		label.text = CombatTexts.ABILITY_READY_TEXT
	else:
		label.text = CombatTexts.ABILITY_COOLDOWN_TEXT % CombatTexts.seconds_text(left)


# --- Hits on the player ---

## Floating number over the portrait, with a red flash when the hit really landed.
func show_hit(text: String, color: Color, big: bool, flash: bool) -> void:
	_last_hit_text = text
	HitNumbers.spawn(_floaters, text, color, big)
	if flash:
		if _flash != null and _flash.is_valid():
			_flash.kill()
		_icon.modulate = UiStyle.COMBAT_FLASH_COLOR
		_flash = create_tween()
		_flash.tween_property(_icon, "modulate", Color.WHITE, UiStyle.COMBAT_FLASH_SEC)


func clear_effects() -> void:
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_icon.modulate = Color.WHITE
	HitNumbers.clear(_floaters)


# --- Sections ---

func _refresh_abilities(session: GameSession) -> void:
	_clear(_ability_flow)
	_entries.clear()
	_ability_cards.clear()
	var levels: Array = _levels(session, Loadout.ABILITY_LEVELS_KEY)
	var open: int = session.loadout.ability_slots()
	var active: Array[StringName] = []
	for def: AbilityDef in session.loadout.active_abilities():
		active.append(def.id)
	var defs: Array[AbilityDef] = session.character.class_def().abilities if session.character.class_def() != null \
			else ([] as Array[AbilityDef])
	for i: int in levels.size():
		var id: StringName = session.loadout.get_ability(i) if i < open else &""
		var description: String = ""
		var title: String = CombatTexts.SLOT_LOCKED_TEXT % int(levels[i])
		var state_text: String = ""
		if i < open:
			title = CombatTexts.SLOT_EMPTY_TEXT
			for def: AbilityDef in defs:
				if def.id == id:
					title = def.name
					description = def.description
			if id != &"" and not active.has(id):
				state_text = CombatTexts.NOT_FOR_SETUP_TEXT
		_ability_cards.append(_build_ability_card(id, title, state_text, i < open and id != &"", description))


func _build_ability_card(id: StringName, title: String, state_text: String, filled: bool, description: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UiStyle.COMBAT_ABILITY_CARD_SIZE
	panel.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD,
			UiStyle.GOLD_DIM if filled else UiStyle.COMBAT_EMPTY_BORDER, 1, 6.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var name_label := Label.new()
	name_label.text = title
	name_label.clip_text = true
	if not filled:
		name_label.theme_type_variation = &"MutedLabel"
	box.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	UiStyle.style_bar(bar, UiStyle.GOLD)
	box.add_child(bar)
	var state_label := Label.new()
	state_label.text = state_text if state_text != "" else (CombatTexts.ABILITY_READY_TEXT if filled else "")
	state_label.theme_type_variation = &"MutedLabel"
	box.add_child(state_label)
	panel.tooltip_text = description
	if id != &"":
		_entries[id] = panel
	_ability_flow.add_child(panel)
	return {"id": id, "bar": bar, "state": state_label}


func _refresh_traits(session: GameSession) -> void:
	_clear(_trait_flow)
	var levels: Array = _levels(session, Loadout.TRAIT_LEVELS_KEY)
	var open: int = session.loadout.trait_slots()
	var active: Array[StringName] = []
	for def: TraitDef in session.loadout.active_traits():
		active.append(def.id)
	var defs: Array[TraitDef] = session.character.class_def().traits if session.character.class_def() != null \
			else ([] as Array[TraitDef])
	for i: int in levels.size():
		var chip_tip: String = ""
		var trait_id: StringName = &""
		var label := Label.new()
		var border: Color = UiStyle.COMBAT_EMPTY_BORDER
		label.theme_type_variation = &"MutedLabel"
		label.text = CombatTexts.SLOT_LOCKED_TEXT % int(levels[i])
		if i < open:
			var id: StringName = session.loadout.get_trait(i)
			label.text = CombatTexts.SLOT_EMPTY_TEXT
			for def: TraitDef in defs:
				if def.id == id:
					label.text = def.name
					chip_tip = def.description
					trait_id = id
					label.theme_type_variation = &"" if active.has(id) else &"MutedLabel"
					border = UiStyle.GOLD_DIM
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, border, 1, 5.0))
		chip.tooltip_text = chip_tip
		if trait_id != &"":
			_entries[trait_id] = chip
		chip.add_child(label)
		_trait_flow.add_child(chip)


func _refresh_gear(session: GameSession) -> void:
	for slot: StringName in _gear:
		var cell: GearCell = _gear[slot]
		var uid: int = session.equipment.get_uid(slot)
		var inst: ItemInstance = session.armory.get_instance(uid) if uid != 0 else null
		var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
		if base != null:
			cell.show_piece(inst, base)
		else:
			cell.show_empty()


## "Lama: forte contro Arcano, debole contro Mira", from the triangle of the data.
func _triangle_hint(session: GameSession) -> String:
	var own: StringName = session.equipment.style()
	var strong: PackedStringArray = PackedStringArray()
	var weak: PackedStringArray = PackedStringArray()
	for style: StringName in ItemTooltipLines.STYLE_NAMES:
		var relation: StringName = CombatMath.triangle(own, style, session.data)
		if relation == &"advantage":
			strong.append(ItemTooltipLines.STYLE_NAMES[style])
		elif relation == &"disadvantage":
			weak.append(ItemTooltipLines.STYLE_NAMES[style])
	return CombatTexts.TRIANGLE_HINT_TEXT % [ItemTooltipLines.STYLE_NAMES.get(own, String(own)),
			", ".join(strong), ", ".join(weak)]


static func _levels(session: GameSession, key: String) -> Array:
	var raw: Variant = session.data.balance_value(key)
	return raw as Array if raw is Array else []


static func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


# --- Tooltip (shared with the Equipment page: ArmoryTexts) ---

func _on_gear_hover(slot: StringName) -> void:
	if _session == null:
		return
	var uid: int = _session.equipment.get_uid(slot)
	var body: String = ArmoryTexts.tooltip_text(_session, uid) if uid != 0 else EquipmentStatsText.slot_text(slot, _session.data)
	if body.is_empty():
		return
	_hovering = true
	Tooltips.show_text("", body, get_global_mouse_position())


func hide_tooltip() -> void:
	if _hovering:
		_hovering = false
		Tooltips.hide_tooltip()


# --- For tests ---

func gear_cell(slot: StringName) -> GearCell:
	return _gear.get(slot)


func ability_card_count() -> int:
	return _ability_cards.size()


func trait_chip_count() -> int:
	return _trait_flow.get_child_count()


func hit_text() -> String:
	return _last_hit_text


func shown_hp() -> int:
	return int(_hp_bar.value)


func shown_timer() -> float:
	return _timer_bar.value


func hint_text() -> String:
	return _hint.text


func level_text() -> String:
	return _level.text


# --- Feedback of the loadout (ability_used, trait_triggered) ---

## Name of an ability or trait of the class, for the log.
func entry_name(id: StringName) -> String:
	var class_def: ClassDef = _session.character.class_def() if _session != null else null
	if class_def != null:
		for def: AbilityDef in class_def.abilities:
			if def.id == id:
				return def.name
		for def: TraitDef in class_def.traits:
			if def.id == id:
				return def.name
	return String(id)


## Quick light on the card or chip of `id` that fades out; nothing if it is not shown.
func flash_entry(id: StringName) -> void:
	var node: Control = _entries.get(id)
	if node == null or not is_instance_valid(node):
		return
	var old: Tween = _entry_flash.get(id)
	if old != null and old.is_valid():
		old.kill()
	node.modulate = UiStyle.GOLD_LIGHT
	var tween: Tween = create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, CombatTexts.FEEDBACK_FLASH_SEC)
	_entry_flash[id] = tween


func is_flashing(id: StringName) -> bool:
	var node: Control = _entries.get(id)
	return node != null and node.modulate != Color.WHITE


func ability_state_text(index: int) -> String:
	return (_ability_cards[index]["state"] as Label).text
