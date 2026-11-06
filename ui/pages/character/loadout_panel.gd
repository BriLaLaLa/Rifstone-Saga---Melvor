class_name LoadoutPanel
extends PanelContainer
## Choice of traits and abilities (docs/01_GDD.md §19, 05_INTERFACES.md §5.16b), part of the character page: one row
## per slot of the balance table with an OptionButton listing the entries of the class.
##
## Reads `session.loadout` and the class at every redraw (`refresh`, called by the page on `traits_changed`, level up,
## equipment and combat signals). A choice is the command `loadout.set_trait` / `set_ability`; a refused one shows its
## reason and the rows are redrawn from the model. It keeps only its nodes.

const KIND_TRAIT: StringName = &"trait"
const KIND_ABILITY: StringName = &"ability"
const CAPTION_WIDTH: int = 80

var _session: GameSession = null
## Per slot, in order: {"kind", "slot", "option": OptionButton, "note": Label}.
var _rows: Array[Dictionary] = []

@onready var _title: Label = %PanelTitle
@onready var _trait_title: Label = %TraitTitle
@onready var _trait_rows: VBoxContainer = %TraitRows
@onready var _ability_title: Label = %AbilityTitle
@onready var _ability_rows: VBoxContainer = %AbilityRows
@onready var _message: Label = %Message


func _ready() -> void:
	_title.text = LoadoutTexts.PANEL_TITLE
	_trait_title.text = LoadoutTexts.TRAITS_TITLE
	_ability_title.text = LoadoutTexts.ABILITIES_TITLE
	_message.add_theme_color_override("font_color", UiStyle.BAD)
	_message.visible = false


## Builds the rows (one per slot) and draws them.
func bind(session: GameSession) -> void:
	_session = session
	_rows.clear()
	_build_rows(_trait_rows, KIND_TRAIT, Loadout.TRAIT_LEVELS_KEY)
	_build_rows(_ability_rows, KIND_ABILITY, Loadout.ABILITY_LEVELS_KEY)
	_message.visible = false
	refresh()


func unbind() -> void:
	_session = null
	_rows.clear()


## Rereads the loadout, the level, the setup and the combat state.
func refresh() -> void:
	if _session == null:
		return
	var class_def: ClassDef = _session.character.class_def()
	var combat_locked: bool = _session.combat != null and _session.combat.in_encounter()
	for row: Dictionary in _rows:
		_refresh_row(row, class_def, combat_locked)


func _build_rows(container: VBoxContainer, kind: StringName, key: String) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var levels: Variant = _session.data.balance_value(key)
	var count: int = (levels as Array).size() if levels is Array else 0
	for slot: int in count:
		var box := VBoxContainer.new()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var caption := Label.new()
		caption.text = LoadoutTexts.SLOT_TEXT % (slot + 1)
		caption.custom_minimum_size.x = CAPTION_WIDTH
		line.add_child(caption)
		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.item_selected.connect(_on_item_selected.bind(kind, slot))
		line.add_child(option)
		box.add_child(line)
		var note := Label.new()
		note.theme_type_variation = &"MutedLabel"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(note)
		container.add_child(box)
		_rows.append({"kind": kind, "slot": slot, "option": option, "note": note})


func _refresh_row(row: Dictionary, class_def: ClassDef, combat_locked: bool) -> void:
	var is_trait: bool = row["kind"] == KIND_TRAIT
	var slot: int = row["slot"]
	var option: OptionButton = row["option"]
	var note: Label = row["note"]
	var open: int = _session.loadout.trait_slots() if is_trait else _session.loadout.ability_slots()
	var current: StringName = _session.loadout.get_trait(slot) if is_trait else _session.loadout.get_ability(slot)
	option.clear()
	option.add_item(LoadoutTexts.EMPTY_TEXT)
	option.set_item_metadata(0, &"")
	var selected: int = 0
	var elsewhere: Array[StringName] = _chosen_ids(is_trait, slot)
	var level: int = _session.character.get_level()
	var setup_id: StringName = _session.equipment.setup()
	var note_text: String = ""
	for entry: Variant in _entries(class_def, is_trait):
		var id: StringName = entry.id
		var text: String = entry.name
		var enabled: bool = true
		if level < entry.unlock_level:
			text = LoadoutTexts.OPTION_LEVEL_TEXT % [text, entry.unlock_level]
			enabled = false
		elif elsewhere.has(id):
			text = LoadoutTexts.OPTION_IN_USE_TEXT % text
			enabled = false
		option.add_item(text)
		var index: int = option.item_count - 1
		option.set_item_metadata(index, id)
		option.set_item_disabled(index, not enabled)
		option.set_item_tooltip(index, entry.description)
		if id == current and slot < open:
			selected = index
			note_text = entry.description
			if not entry.allows_setup(setup_id):
				note_text += "\n" + LoadoutTexts.NOT_FOR_SETUP_TEXT
	option.select(selected)
	option.disabled = slot >= open or combat_locked
	if slot >= open:
		option.text = LoadoutTexts.SLOT_LOCKED_TEXT % _unlock_level(slot, is_trait)
		note_text = ""
	elif combat_locked:
		note_text = LoadoutTexts.COMBAT_ACTIVE_TEXT
	note.text = note_text
	note.visible = note_text != ""


func _entries(class_def: ClassDef, is_trait: bool) -> Array:
	if class_def == null:
		return []
	return class_def.traits if is_trait else class_def.abilities


## Ids chosen in the other slots (they cannot be chosen twice).
func _chosen_ids(is_trait: bool, except_slot: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for row: Dictionary in _rows:
		if (row["kind"] == KIND_TRAIT) != is_trait or row["slot"] == except_slot:
			continue
		var slot: int = row["slot"]
		var id: StringName = _session.loadout.get_trait(slot) if is_trait else _session.loadout.get_ability(slot)
		if id != &"":
			result.append(id)
	return result


func _unlock_level(slot: int, is_trait: bool) -> int:
	var raw: Variant = _session.data.balance_value(Loadout.TRAIT_LEVELS_KEY if is_trait else Loadout.ABILITY_LEVELS_KEY)
	return int((raw as Array)[slot]) if raw is Array and slot < (raw as Array).size() else 0


func _on_item_selected(index: int, kind: StringName, slot: int) -> void:
	if _session == null:
		return
	var option: OptionButton = _row(kind, slot)["option"]
	var id: StringName = option.get_item_metadata(index)
	var result: CommandResult = _session.loadout.set_trait(slot, id) if kind == KIND_TRAIT \
			else _session.loadout.set_ability(slot, id)
	_message.visible = not result.ok
	if not result.ok:
		_message.text = LoadoutTexts.REASON_TEXTS.get(result.reason, LoadoutTexts.REASON_DEFAULT_TEXT)
	refresh()


func _row(kind: StringName, slot: int) -> Dictionary:
	for row: Dictionary in _rows:
		if row["kind"] == kind and row["slot"] == slot:
			return row
	return {}


# --- For tests ---

func option(kind: StringName, slot: int) -> OptionButton:
	return _row(kind, slot).get("option")


func note_text(kind: StringName, slot: int) -> String:
	return (_row(kind, slot)["note"] as Label).text


func message_text() -> String:
	return _message.text if _message.visible else ""


func row_count(kind: StringName) -> int:
	var n: int = 0
	for row: Dictionary in _rows:
		if row["kind"] == kind:
			n += 1
	return n
