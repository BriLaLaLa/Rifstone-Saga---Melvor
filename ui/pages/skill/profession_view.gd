class_name ProfessionView
extends HBoxContainer
## Body of a production page (artisan disciplines and the Engraver): the recipe list on the left, the detail of the picked
## recipe on the right (and, on the Forging page, the blueprint and bench pages in the same place). It keeps presentation
## state only (the picked id); every redraw reads the session. A recipe the player puts in the queue goes out as
## `enqueue_requested` and the page sends the command.

signal enqueue_requested(action_id: StringName, count: int, repeat: bool)

const LIST_WIDTH: float = 340.0
const SEPARATION: int = 12

var _data: GameData = null
var _skill_id: StringName = &""
var _list: RecipeList = null
var _detail: RecipeDetail = null
var _caption: Label = null
var _unlocks: ProfessionUnlocks = null
var _pages: Dictionary[StringName, Control] = {}
var _picked: StringName = &""
## The session of the last redraw, kept only to refresh the detail right after a pick (cleared by `forget_session`).
var _session: GameSession = null


## Builds the list and the detail of `skill_id`; `pages` maps a special page id (ForgeTabs.TAB_BLUEPRINTS / TAB_BENCH) to
## its node, already created by the page and still without parent.
func setup(data: GameData, skill_id: StringName, pages: Dictionary[StringName, Control]) -> void:
	_data = data
	_skill_id = skill_id
	add_theme_constant_override("separation", SEPARATION)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := PanelContainer.new()
	left.name = "ListPanel"
	left.theme_type_variation = &"HudPanel"
	left.custom_minimum_size = Vector2(LIST_WIDTH, 0)
	add_child(left)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(list_scroll)
	_list = RecipeList.new()
	_list.name = "RecipeList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	_list.setup(data, skill_id)
	var right := ScrollContainer.new()
	right.name = "DetailScroll"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(right)
	var column := VBoxContainer.new()
	column.name = "DetailColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", SEPARATION)
	right.add_child(column)
	_caption = Label.new()
	_caption.name = "PageCaption"
	_caption.theme_type_variation = &"MutedLabel"
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	column.add_child(_caption)
	_detail = RecipeDetail.new()
	_detail.name = "RecipeDetail"
	column.add_child(_detail)
	_unlocks = ProfessionUnlocks.new()
	_unlocks.setup(skill_id)
	column.add_child(_unlocks)
	for page_id: StringName in pages:
		var node: Control = pages[page_id]
		node.visible = false
		column.add_child(node)
		_pages[page_id] = node
	_list.recipe_selected.connect(show_recipe)
	_list.page_selected.connect(show_page)
	_detail.enqueue_requested.connect(func(action_id: StringName, count: int, repeat: bool) -> void:
		enqueue_requested.emit(action_id, count, repeat))


## Reads the session into the list and the detail; the first time it picks the first recipe the player can make.
func redraw(session: GameSession) -> void:
	_session = session
	_list.redraw(session)
	if _picked == &"":
		var first: StringName = _list.first_recipe()
		if first != &"":
			show_recipe(first)
	_detail.redraw(session)
	_unlocks.redraw(session, _detail.visible)


## Picks a recipe: the detail shows it and the special pages hide.
func show_recipe(action_id: StringName) -> void:
	var action: ActionDef = _data.action(action_id)
	if action == null:
		return
	_picked = action_id
	for node: Control in _pages.values():
		node.visible = false
	_caption.visible = false
	_detail.visible = true
	_list.select(action_id)
	_detail.show_action(action, _data)
	if _session != null:
		_detail.redraw(_session)
		_unlocks.redraw(_session, true)


## Picks a special page (blueprints, bench): its node replaces the detail.
func show_page(page_id: StringName) -> void:
	_picked = page_id
	_detail.visible = false
	_unlocks.visible = false
	for id: StringName in _pages:
		_pages[id].visible = id == page_id
	_caption.text = ForgeTabs.CAPTIONS.get(page_id, "")
	_caption.visible = not _caption.text.is_empty()
	_list.select(page_id)


func picked() -> StringName:
	return _picked


func list() -> RecipeList:
	return _list


func detail() -> RecipeDetail:
	return _detail




func forget_session() -> void:
	_session = null
