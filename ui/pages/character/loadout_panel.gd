class_name LoadoutPanel
extends PanelContainer
## Choice of traits and abilities (docs/01_GDD.md §19, 05_INTERFACES.md §5.16b), part of the character page: every entry
## of the class is a card (name, description, unlock level, slot taken). A click on a free card is the command
## `loadout.set_trait` / `set_ability` on the first empty open slot; a click on a chosen card empties its slot.
##
## Reads `session.loadout` and the class at every redraw (`refresh`, called by the page on `traits_changed`, level up,
## equipment and combat signals). A refused command shows its reason and the cards are redrawn from the model. During an
## encounter nothing can be changed: one warning per section, the cards do not react. It keeps only its nodes.

const KIND_TRAIT: StringName = &"trait"
const KIND_ABILITY: StringName = &"ability"
const COLUMNS: int = 2
const GRID_SEPARATION: int = 8

var _session: GameSession = null
## Per kind: {"note": Label, "summary": Label, "grid": GridContainer, "cards": Array[LoadoutCard]}.
var _sections: Dictionary[StringName, Dictionary] = {}

@onready var _tabs: TabContainer = %Tabs
@onready var _trait_rows: VBoxContainer = %TraitRows
@onready var _ability_rows: VBoxContainer = %AbilityRows
@onready var _message: Label = %Message


func _ready() -> void:
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_trait_rows), LoadoutTexts.TRAITS_TITLE)
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_ability_rows), LoadoutTexts.ABILITIES_TITLE)
	_message.add_theme_color_override("font_color", UiStyle.BAD)
	_message.visible = false


## Builds the cards (one per entry of the class) and draws them.
func bind(session: GameSession) -> void:
	_session = session
	_sections.clear()
	var class_def: ClassDef = _session.character.class_def()
	_build_section(_trait_rows, KIND_TRAIT, class_def)
	_build_section(_ability_rows, KIND_ABILITY, class_def)
	_message.visible = false
	refresh()


func unbind() -> void:
	_session = null
	_sections.clear()


## Rereads the loadout, the level, the setup and the combat state.
func refresh() -> void:
	if _session == null:
		return
	var locked: bool = _session.combat != null and _session.combat.in_encounter()
	var class_def: ClassDef = _session.character.class_def()
	for kind: StringName in _sections:
		_refresh_section(kind, class_def, locked)


func _build_section(container: VBoxContainer, kind: StringName, class_def: ClassDef) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var note := Label.new()
	note.text = LoadoutTexts.COMBAT_ACTIVE_TEXT
	note.add_theme_color_override("font_color", UiStyle.BAD)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(note)
	var summary := Label.new()
	summary.theme_type_variation = &"MutedLabel"
	container.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	container.add_child(grid)
	var cards: Array[LoadoutCard] = []
	for entry: Variant in _entries(class_def, kind == KIND_TRAIT):
		var card := LoadoutCard.new()
		card.chosen.connect(_on_card_chosen.bind(kind))
		grid.add_child(card)
		cards.append(card)
	_sections[kind] = {"note": note, "summary": summary, "grid": grid, "cards": cards}


func _refresh_section(kind: StringName, class_def: ClassDef, locked: bool) -> void:
	var is_trait: bool = kind == KIND_TRAIT
	var section: Dictionary = _sections[kind]
	var entries: Array = _entries(class_def, is_trait)
	var cards: Array = section["cards"]
	var level: int = _session.character.get_level()
	var setup_id: StringName = _session.equipment.setup()
	var open: int = _open_slots(is_trait)
	var total: int = _slot_levels(is_trait).size()
	(section["note"] as Label).visible = locked
	(section["summary"] as Label).text = _summary_text(open, total, is_trait)
	for i: int in mini(entries.size(), cards.size()):
		var entry: Variant = entries[i]
		var slot: int = _slot_of(entry.id, is_trait, open)
		var unlock_text: String = LoadoutTexts.UNLOCK_TEXT % entry.unlock_level if level < entry.unlock_level \
				else LoadoutTexts.UNLOCKED_TEXT % entry.unlock_level
		var warning: String = LoadoutTexts.NOT_FOR_SETUP_TEXT if slot >= 0 and not entry.allows_setup(setup_id) else ""
		var description: String = LoadoutDescribe.trait_text(entry, _session.data, class_def) if is_trait \
				else LoadoutDescribe.ability_text(entry, _session.data, class_def)
		(cards[i] as LoadoutCard).show_entry(entry.id, entry.name, description, unlock_text,
				LoadoutTexts.SLOT_CHOSEN_TEXT % (slot + 1) if slot >= 0 else "", warning,
				level < entry.unlock_level and slot < 0, not locked)


func _summary_text(open: int, total: int, is_trait: bool) -> String:
	if open < total:
		return LoadoutTexts.SLOTS_NEXT_TEXT % [open, total, _slot_levels(is_trait)[open]]
	return LoadoutTexts.SLOTS_OPEN_TEXT % [open, total]


func _entries(class_def: ClassDef, is_trait: bool) -> Array:
	if class_def == null:
		return []
	return class_def.traits if is_trait else class_def.abilities


func _chosen_id(is_trait: bool, slot: int) -> StringName:
	return _session.loadout.get_trait(slot) if is_trait else _session.loadout.get_ability(slot)


func _open_slots(is_trait: bool) -> int:
	return _session.loadout.trait_slots() if is_trait else _session.loadout.ability_slots()


## Slot (0-based) that holds `id` among the open ones; -1 if it is not chosen.
func _slot_of(id: StringName, is_trait: bool, open: int) -> int:
	for slot: int in open:
		if _chosen_id(is_trait, slot) == id:
			return slot
	return -1


## Unlock levels of the slots, from the balance table.
func _slot_levels(is_trait: bool) -> Array:
	var raw: Variant = _session.data.balance_value(Loadout.TRAIT_LEVELS_KEY if is_trait else Loadout.ABILITY_LEVELS_KEY)
	return raw as Array if raw is Array else []


func _on_card_chosen(id: StringName, kind: StringName) -> void:
	if _session == null:
		return
	var is_trait: bool = kind == KIND_TRAIT
	var open: int = _open_slots(is_trait)
	var held: int = _slot_of(id, is_trait, open)
	var slot: int = held if held >= 0 else _first_empty_slot(is_trait, open)
	if slot < 0:
		_show_message(LoadoutTexts.NO_FREE_SLOT_TEXT)
		return
	var target: StringName = &"" if held >= 0 else id
	var result: CommandResult = _session.loadout.set_trait(slot, target) if is_trait \
			else _session.loadout.set_ability(slot, target)
	_show_message("" if result.ok else LoadoutTexts.REASON_TEXTS.get(result.reason, LoadoutTexts.REASON_DEFAULT_TEXT))
	refresh()


## First empty open slot; slot 0 if none is open (the command then refuses with its reason); -1 if all are taken.
func _first_empty_slot(is_trait: bool, open: int) -> int:
	if open == 0:
		return 0
	for slot: int in open:
		if _chosen_id(is_trait, slot) == &"":
			return slot
	return -1


func _show_message(text: String) -> void:
	_message.visible = text != ""
	_message.text = text


# --- For tests ---

func card(kind: StringName, id: StringName) -> LoadoutCard:
	for c: Variant in _sections.get(kind, {}).get("cards", []):
		if (c as LoadoutCard).entry_id() == id:
			return c
	return null


func card_count(kind: StringName) -> int:
	return (_sections[kind]["cards"] as Array).size() if _sections.has(kind) else 0


## True while the section shows its single "no changes during an encounter" warning.
func combat_note_visible(kind: StringName) -> bool:
	return (_sections[kind]["note"] as Label).visible


func summary_text(kind: StringName) -> String:
	return (_sections[kind]["summary"] as Label).text


func message_text() -> String:
	return _message.text if _message.visible else ""
