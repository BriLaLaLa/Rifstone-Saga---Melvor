class_name LoadoutPanel
extends PanelContainer
## Choice of traits and abilities (docs/01_GDD.md §19, 05_INTERFACES.md §5.16b), part of the character page: a header with
## the slots (occupied, free), then tiles grouped by setup (`LoadoutSection`, `LoadoutCard`); the full description is the
## tooltip of a tile. A click on a free tile is the command `loadout.set_trait` / `set_ability` on the first empty open
## slot; a click on a chosen tile empties its slot.
##
## Reads `session.loadout` and the class at every redraw (`refresh`, called by the page on `traits_changed`, level up,
## equipment and combat signals). A refused command shows its reason and the tiles are redrawn from the model. During an
## encounter nothing can be changed: one warning per section, the tiles do not react. It keeps only its nodes.

const KIND_TRAIT: StringName = &"trait"
const KIND_ABILITY: StringName = &"ability"
const ABILITY_ACCENTS: Dictionary[StringName, Color] = {
	AbilityDef.KIND_STRIKE: UiStyle.HP_LIGHT,
	AbilityDef.KIND_CLEAVE: UiStyle.COPPER,
	AbilityDef.KIND_HEAL: UiStyle.GOOD,
	AbilityDef.KIND_BUFF: UiStyle.RARITY_MAGIC,
	AbilityDef.KIND_WARD: UiStyle.COMBAT_WARD_COLOR,
}

var _session: GameSession = null
var _sections: Dictionary[StringName, LoadoutSection] = {}
## Presentation only (GDD M28 §40.9): show just the entries of the current setup (chosen ones always stay visible).
var _only_current: bool = true
var _toggle: CheckButton = null

@onready var _tabs: TabContainer = %Tabs
@onready var _trait_rows: VBoxContainer = %TraitRows
@onready var _ability_rows: VBoxContainer = %AbilityRows
@onready var _message: Label = %Message


func _ready() -> void:
	_toggle = CheckButton.new()
	_toggle.name = "OnlyCurrentToggle"
	_toggle.text = LoadoutTexts.ONLY_CURRENT_TEXT
	_toggle.button_pressed = _only_current
	_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toggle.toggled.connect(_on_only_current_toggled)
	_tabs.get_parent().add_child(_toggle)
	_tabs.get_parent().move_child(_toggle, 0)
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_trait_rows), LoadoutTexts.TRAITS_TITLE)
	_tabs.set_tab_title(_tabs.get_tab_idx_from_control(_ability_rows), LoadoutTexts.ABILITIES_TITLE)
	_message.add_theme_color_override("font_color", UiStyle.BAD)
	_message.visible = false


## Builds the tiles (one per entry of the class) and draws them.
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
	var locked: bool = _session.combat != null and (_session.combat.in_encounter() or _session.combat.in_fracture())
	var class_def: ClassDef = _session.character.class_def()
	for kind: StringName in _sections:
		_refresh_section(kind, class_def, locked)


func _build_section(container: VBoxContainer, kind: StringName, class_def: ClassDef) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	var section := LoadoutSection.new()
	container.add_child(section)
	section.build(_entries(class_def, kind == KIND_TRAIT), class_def, _on_card_chosen.bind(kind))
	_sections[kind] = section


func _refresh_section(kind: StringName, class_def: ClassDef, locked: bool) -> void:
	var is_trait: bool = kind == KIND_TRAIT
	var section: LoadoutSection = _sections[kind]
	var entries: Array = _entries(class_def, is_trait)
	var level: int = _session.character.get_level()
	var setup_id: StringName = _session.equipment.setup()
	var open: int = _open_slots(is_trait)
	var levels: Array = _slot_levels(is_trait)
	var chosen: int = 0
	section.note.visible = locked
	for i: int in mini(entries.size(), section.cards.size()):
		var entry: Variant = entries[i]
		var slot: int = _slot_of(entry.id, is_trait, open)
		chosen += 1 if slot >= 0 else 0
		var fits: bool = entry.allows_setup(setup_id)
		section.cards[i].visible = slot >= 0 or not _only_current or fits
		_draw_card(section.cards[i], entry, is_trait, class_def, slot, fits, level, locked)
	section.set_slots(chosen, open, levels.size(), int(levels[open]) if open < levels.size() else 0)
	section.sync_groups()


func _draw_card(card: LoadoutCard, entry: Variant, is_trait: bool, class_def: ClassDef, slot: int, fits: bool,
		level: int, locked: bool) -> void:
	var text: String = LoadoutDescribe.trait_text(entry, _session.data, class_def) if is_trait \
			else LoadoutDescribe.ability_text(entry, _session.data, class_def)
	var state: StringName = LoadoutCard.STATE_AVAILABLE
	var status: String = LoadoutTexts.STATUS_AVAILABLE_TEXT
	var hint: String = LoadoutTexts.DETAIL_CHOOSE_TEXT
	if slot >= 0:
		state = LoadoutCard.STATE_ACTIVE if fits else LoadoutCard.STATE_INACTIVE
		status = LoadoutTexts.STATUS_ACTIVE_TEXT % (slot + 1) if fits else LoadoutTexts.STATUS_INACTIVE_TEXT
		hint = LoadoutTexts.DETAIL_REMOVE_TEXT
	elif level < entry.unlock_level:
		state = LoadoutCard.STATE_LOCKED
		status = LoadoutTexts.STATUS_LOCKED_TEXT % entry.unlock_level
		hint = ""
	var detail: String = text + ("\n" + LoadoutTexts.NOT_FOR_SETUP_TEXT if slot >= 0 and not fits else "") \
			+ ("\n" + hint if hint != "" else "")
	var accent: Color = UiStyle.GOLD if is_trait else ABILITY_ACCENTS.get(entry.kind, UiStyle.GOLD)
	card.show_entry(entry.id, entry.name, text.get_slice("\n", 0), detail, state, status, accent, not locked)


## The entries of the class ordered by unlock level (the order of the file for equal levels).
func _entries(class_def: ClassDef, is_trait: bool) -> Array:
	if class_def == null:
		return []
	var source: Array = class_def.traits if is_trait else class_def.abilities
	var sorted: Array = source.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		return a.unlock_level < b.unlock_level or (a.unlock_level == b.unlock_level and source.find(a) < source.find(b)))
	return sorted


func _on_only_current_toggled(pressed: bool) -> void:
	_only_current = pressed
	refresh()


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
	for c: LoadoutCard in _sections[kind].cards if _sections.has(kind) else []:
		if c.entry_id() == id:
			return c
	return null


func card_count(kind: StringName) -> int:
	return _sections[kind].cards.size() if _sections.has(kind) else 0


func section(kind: StringName) -> LoadoutSection:
	return _sections.get(kind)


## True while the section shows its single "no changes during an encounter" warning.
func combat_note_visible(kind: StringName) -> bool:
	return _sections[kind].note.visible


func message_text() -> String:
	return _message.text if _message.visible else ""
