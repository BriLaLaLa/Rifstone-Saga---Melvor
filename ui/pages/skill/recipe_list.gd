class_name RecipeList
extends VBoxContainer
## Left column of a production page: a search box, the "Solo creabili" filter and the recipes in collapsible sections
## (ProfessionCategories); on the Forging page the blueprints and the bench follow as entries. Each row is a RecipeRow.
## Picking a row emits `recipe_selected` / `page_selected`; the owner shows the matching detail. It keeps presentation
## state only (the search text, the filter, which sections are closed, the picked id); every redraw reads the session.

signal recipe_selected(action_id: StringName)
signal page_selected(page_id: StringName)

const SEPARATION: int = 6
const SECTION_SEPARATION: int = 2

var _skill_id: StringName = &""
var _actions: Array[ActionDef] = []
var _rows: Dictionary[StringName, RecipeRow] = {}
var _section_of: Dictionary[StringName, StringName] = {}
var _bodies: Dictionary[StringName, VBoxContainer] = {}
var _headers: Dictionary[StringName, Button] = {}
var _labels: Dictionary[StringName, String] = {}
var _closed: Dictionary[StringName, bool] = {}
var _specials: Dictionary[StringName, RecipeRow] = {}
var _group: ButtonGroup = ButtonGroup.new()
var _search: LineEdit = null
var _only_craftable: CheckBox = null
var _empty: Label = null
var _session: GameSession = null


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)


## Builds the sections and the rows of the recipes of `skill_id` (blueprint crafting is not a recipe row).
func setup(data: GameData, skill_id: StringName) -> void:
	_skill_id = skill_id
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = ProfessionTexts.SEARCH_HINT
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _apply_filter())
	add_child(_search)
	_only_craftable = CheckBox.new()
	_only_craftable.name = "OnlyCraftable"
	_only_craftable.text = ProfessionTexts.ONLY_CRAFTABLE_TEXT
	_only_craftable.tooltip_text = ProfessionTexts.ONLY_CRAFTABLE_TIP
	_only_craftable.focus_mode = Control.FOCUS_NONE
	_only_craftable.toggled.connect(func(_on: bool) -> void: _apply_filter())
	add_child(_only_craftable)
	for page: Dictionary in ProfessionCategories.special_pages(skill_id):  # on top, always in sight
		var entry: RecipeRow = RecipeRow.new()
		entry.button_group = _group
		add_child(entry)
		entry.setup_special(StringName(page["id"]), str(page["label"]))
		var page_id: StringName = StringName(page["id"])
		entry.pressed.connect(func() -> void: page_selected.emit(page_id))
		_specials[page_id] = entry
	if ProfessionCategories.has_merchant(data, skill_id):
		var merchant: RecipeRow = RecipeRow.new()
		merchant.button_group = _group
		add_child(merchant)
		merchant.setup_special(ProfessionCategories.MERCHANT_PAGE, MerchantTexts.PAGE_LABEL)
		merchant.pressed.connect(func() -> void: page_selected.emit(ProfessionCategories.MERCHANT_PAGE))
		_specials[ProfessionCategories.MERCHANT_PAGE] = merchant
	for section: Dictionary in ProfessionCategories.sections(skill_id):
		_add_section(StringName(section["id"]), str(section["label"]))
	for action: ActionDef in data.actions_for_skill(skill_id):
		if action.id == BlueprintCraft.ACTION:
			continue
		var section_id: StringName = ProfessionCategories.section_of(action)
		var row: RecipeRow = RecipeRow.new()
		row.button_group = _group
		_bodies[section_id].add_child(row)
		row.setup(action)
		row.pressed.connect(func() -> void: recipe_selected.emit(action.id))
		_rows[action.id] = row
		_actions.append(action)
		_section_of[action.id] = section_id
	_empty = Label.new()
	_empty.name = "EmptyLabel"
	_empty.text = ProfessionTexts.NO_RECIPES_TEXT
	_empty.theme_type_variation = &"MutedLabel"
	_empty.visible = false
	add_child(_empty)


## Greys, counts and filters the rows from the session.
func redraw(session: GameSession) -> void:
	_session = session
	for action: ActionDef in _actions:
		_rows[action.id].show_state(session.disciplines.knows_recipe(action.id),
				session.skills.meets_requirements({action.skill_id: action.level}),
				craftable_count(action, session), action.level,
				StringName(session.professions.recipe_color(action.id).get("id", &"")))
	_apply_filter()


## How many times `action` can be made with what the bank holds now (a derived reading, not stored).
@warning_ignore("integer_division")
static func craftable_count(action: ActionDef, session: GameSession) -> int:
	var needed: Dictionary[StringName, int] = {}
	for input: ItemQty in action.inputs:
		needed[input.item_id] = needed.get(input.item_id, 0) + input.qty
	var result: int = -1
	for item_id: StringName in needed:
		var times: int = session.bank.get_count(item_id) / maxi(1, needed[item_id])
		result = times if result < 0 else mini(result, times)
	return maxi(result, 0)


## Marks the row of `id` (a recipe or a special page) as the picked one, without emitting.
func select(id: StringName) -> void:
	if _rows.has(id):
		_rows[id].set_pressed_no_signal(true)
	elif _specials.has(id):
		_specials[id].set_pressed_no_signal(true)


## The first recipe the player can put in the queue now, else the first one; `&""` when there is none.
func first_recipe() -> StringName:
	var first: StringName = &""
	for section_id: StringName in _bodies:  # the order of the screen: sections, then the rows of each
		for node: Node in _bodies[section_id].get_children():
			var row: RecipeRow = node as RecipeRow
			if first == &"":
				first = row.action_id()
			var action: ActionDef = _action_of(row.action_id())
			if row.visible and _session != null and _session.disciplines.knows_recipe(action.id) \
					and _session.skills.meets_requirements({action.skill_id: action.level}):
				return action.id
	return first


func _action_of(id: StringName) -> ActionDef:
	for action: ActionDef in _actions:
		if action.id == id:
			return action
	return null


func _add_section(id: StringName, label: String) -> void:
	_labels[id] = label
	var header: Button = Button.new()
	header.name = "Section_%s" % id
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_color_override("font_color", UiStyle.GOLD)
	header.add_theme_color_override("font_hover_color", UiStyle.GOLD_LIGHT)
	header.pressed.connect(_toggle_section.bind(id))
	add_child(header)
	_headers[id] = header
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body_%s" % id
	body.add_theme_constant_override("separation", SECTION_SEPARATION)
	add_child(body)
	_bodies[id] = body
	_closed[id] = false


func _toggle_section(id: StringName) -> void:
	_closed[id] = not _closed[id]
	_apply_filter()


## Shows the rows that match the search and the filter; a section without rows is hidden; a closed one hides its rows.
func _apply_filter() -> void:
	if _session == null:
		return
	var needle: String = _search.text.strip_edges().to_lower()
	var counts: Dictionary[StringName, int] = {}
	var shown: int = 0
	for action: ActionDef in _actions:
		var visible_now: bool = needle.is_empty() or action.name.to_lower().contains(needle)
		if visible_now and _only_craftable.button_pressed:
			visible_now = _session.disciplines.knows_recipe(action.id) \
					and _session.skills.meets_requirements({action.skill_id: action.level}) \
					and craftable_count(action, _session) > 0
		_rows[action.id].visible = visible_now
		if visible_now:
			counts[_section_of[action.id]] = counts.get(_section_of[action.id], 0) + 1
			shown += 1
	for id: StringName in _headers:
		var count: int = counts.get(id, 0)
		_headers[id].visible = count > 0
		_bodies[id].visible = count > 0 and not _closed[id]
		var template: String = ProfessionTexts.SECTION_CLOSED_TEXT if _closed[id] else ProfessionTexts.SECTION_OPEN_TEXT
		_headers[id].text = template % ("%s (%s)" % [_labels[id], NumberFormat.format_int(count)])
	_empty.visible = shown == 0 and not _actions.is_empty()
