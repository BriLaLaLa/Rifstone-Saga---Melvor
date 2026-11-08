class_name GuidePage
extends Page
## In-game Guide (docs/05_INTERFACES.md §7.y, 01_GDD.md §27): index on the left, content on the right, search on top,
## clickable links and a "Indietro" history. Content is generated from GameData (GuideNav, GuideEntityBlocks,
## GuideRenderer); the page keeps no game state, only presentation state (current entry and history).
##
## The route is `guide` (or `help`), optionally followed by an entry id: `guide:item:redbirch_log`. The shell opens an
## entry of a live Guide with `open_page`. It listens to no EventBus signal.

signal entry_opened(entry_id: StringName)

const LOG_CATEGORY: String = "guide"
const ROUTE_PREFIXES: Array[String] = ["guide:", "help:"]
const UNKNOWN_TEXT: String = "Pagina non trovata: %s"
const NO_TITLE_FALLBACK := &"page:guide_first_steps"
const RESULT_TEXT: String = "%s  (%s)"
const MARGIN: int = 16

var _session: GameSession = null
var _nav: GuideNav = null
var _renderer: GuideRenderer = null
var _current: StringName = &""
var _history: Array[StringName] = []
var _results: Array[StringName] = []
var _syncing: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _back_button: Button = %BackButton
@onready var _message_label: Label = %MessageLabel
@onready var _search_edit: LineEdit = %SearchEdit
@onready var _index_tree: Tree = %IndexTree
@onready var _results_list: ItemList = %ResultsList
@onready var _content_view: ScrollContainer = %ContentView
@onready var _body: VBoxContainer = %Body


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, MARGIN)
	_back_button.pressed.connect(_on_back_pressed)
	_search_edit.text_changed.connect(_on_search_changed)
	_index_tree.item_selected.connect(_on_tree_item_selected)
	_results_list.item_selected.connect(_on_result_selected)
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_nav = GuideNav.new(session.data)
	var entities: GuideEntityBlocks = GuideEntityBlocks.new(session.data, GuideIndex.new(session.data), _nav)
	_renderer = GuideRenderer.new(session.data, _nav, entities, open_entry)
	_fill_tree()
	var argument: String = _route_argument()
	if argument.is_empty():
		var first: Array[StringName] = _nav.ids()
		open_entry(NO_TITLE_FALLBACK if _nav.has_entry(NO_TITLE_FALLBACK) else (first[0] if not first.is_empty() else &""))
	else:
		open_entry(StringName(argument))


func unbind() -> void:
	_session = null
	_nav = null
	_renderer = null
	_current = &""
	_history.clear()
	_results.clear()


## Opens a page (id of `GuideIndex.entry` or `page:<id>`); an unknown id is reported and the current page stays.
func open_entry(entry_id: StringName) -> void:
	if _nav == null:
		return
	if not _nav.has_entry(entry_id):
		Log.error(LOG_CATEGORY, "unknown page '%s'" % entry_id)
		_message_label.text = UNKNOWN_TEXT % entry_id
		return
	_message_label.text = ""
	if _current != &"" and _current != entry_id:
		_history.append(_current)
	_show(entry_id)


## Same as `open_entry` (name used by the help buttons of the pages).
func open_page(page_id: StringName) -> void:
	open_entry(page_id)


## Back to the previous page; false if the history is empty.
func go_back() -> bool:
	if _history.is_empty():
		return false
	_show(_history.pop_back())
	return true


## Pages whose title contains `query` (case and accents ignored); an empty query gives the whole index.
func search(query: String) -> Array[StringName]:
	return _nav.search(query) if _nav != null else []


## Id of the page shown now; `&""` if none.
func current_entry() -> StringName:
	return _current


func _show(entry_id: StringName) -> void:
	_current = entry_id
	_renderer.render(_body, entry_id)
	_content_view.scroll_vertical = 0
	_back_button.disabled = _history.is_empty()
	_select_in_tree(entry_id)
	entry_opened.emit(entry_id)


func _route_argument() -> String:
	for prefix: String in ROUTE_PREFIXES:
		if String(page_id).begins_with(prefix):
			return String(page_id).trim_prefix(prefix)
	return ""


func _fill_tree() -> void:
	_index_tree.clear()
	var root: TreeItem = _index_tree.create_item()
	for group: Dictionary in _nav.groups():
		var folder: TreeItem = _index_tree.create_item(root)
		folder.set_text(0, str(group["title"]))
		folder.set_selectable(0, false)
		folder.collapsed = true
		for id: StringName in group["ids"] as Array[StringName]:
			var row: TreeItem = _index_tree.create_item(folder)
			row.set_text(0, _nav.title_of(id))
			row.set_metadata(0, id)


func _select_in_tree(entry_id: StringName) -> void:
	var root: TreeItem = _index_tree.get_root()
	if root == null:
		return
	for folder: TreeItem in root.get_children():
		for row: TreeItem in folder.get_children():
			if row.get_metadata(0) == entry_id:
				_syncing = true
				folder.collapsed = false
				row.select(0)
				_index_tree.scroll_to_item(row)
				_syncing = false
				return


func _on_back_pressed() -> void:
	go_back()


func _on_search_changed(text: String) -> void:
	var searching: bool = not text.strip_edges().is_empty()
	_index_tree.visible = not searching
	_results_list.visible = searching
	_results_list.clear()
	_results.clear()
	if searching:
		_results = search(text)
	for id: StringName in _results:
		_results_list.add_item(RESULT_TEXT % [_nav.title_of(id), _nav.group_of(id)])


func _on_tree_item_selected() -> void:
	if _syncing:
		return
	var row: TreeItem = _index_tree.get_selected()
	if row != null and row.get_metadata(0) != null:
		open_entry(row.get_metadata(0) as StringName)


func _on_result_selected(index: int) -> void:
	if index >= 0 and index < _results.size():
		open_entry(_results[index])
