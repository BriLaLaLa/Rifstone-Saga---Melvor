class_name AuctionCategoryTree
extends VBoxContainer
## Left column of the Auction House page (docs/05_INTERFACES.md §7.p): the name search field and a collapsible tree of the
## item categories (`ItemDef.category`) with the number of items of the active tab in each. Presentation only: it keeps
## the text of the field and the tree nodes, the page owns the picked category and hands in the counts.

signal category_picked(category: StringName)
signal search_changed(text: String)
## "Posseduti" / "Comprabili ora" toggled (M37-4): the page applies them with the category and the search.
signal filters_changed(owned: bool, buyable: bool)

const ALL: StringName = &"__all"
const SEPARATION: int = 8

var _search: LineEdit = null
var _owned: CheckButton = null
var _buyable: CheckButton = null
var _tree: Tree = null
var _building: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	_search = LineEdit.new()
	_search.name = "SearchField"
	_search.placeholder_text = AuctionTexts.SEARCH_PLACEHOLDER_TEXT
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(text: String) -> void: search_changed.emit(text))
	add_child(_search)
	_owned = _filter("FilterOwned", AuctionTexts.FILTER_OWNED_TEXT)
	_buyable = _filter("FilterBuyable", AuctionTexts.FILTER_BUYABLE_TEXT)
	_tree = Tree.new()
	_tree.name = "CategoryTree"
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	add_child(_tree)


## Rebuilds the tree: `order` are the categories to list, `counts` the items of each (after the search), `total` the sum;
## `picked` is highlighted (`ALL` for the root entry).
func show_categories(order: Array[StringName], counts: Dictionary, total: int, picked: StringName) -> void:
	var collapsed: bool = false
	if _tree.get_root() != null and _tree.get_root().get_child_count() > 0:
		collapsed = _tree.get_root().get_first_child().collapsed
	_building = true
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var all_item: TreeItem = _tree.create_item(root)
	all_item.set_text(0, AuctionTexts.CATEGORY_COUNT_TEXT % [AuctionTexts.ALL_CATEGORIES_TEXT, total])
	all_item.set_metadata(0, ALL)
	all_item.collapsed = collapsed
	if picked == ALL:
		all_item.select(0)
	for category: StringName in order:
		var item: TreeItem = _tree.create_item(all_item)
		item.set_text(0, AuctionTexts.CATEGORY_COUNT_TEXT % [AuctionTexts.category_name(category), int(counts.get(category, 0))])
		item.set_metadata(0, category)
		if picked == category:
			item.select(0)
	_building = false


func search_text() -> String:
	return _search.text if _search != null else ""


func _on_item_selected() -> void:
	if _building:
		return
	var item: TreeItem = _tree.get_selected()
	if item != null:
		# Deferred: a Tree refuses to clear or create items while it emits `item_selected` for a mouse click
		# (`create_item` returns null), and the page rebuilds this tree in answer to the pick.
		category_picked.emit.call_deferred(item.get_metadata(0))


## Sets the filter switches (the page remembers them per tab); `owned_visible` is false in Vendi, where every item is owned.
func set_filters(owned: bool, buyable: bool, owned_visible: bool) -> void:
	_owned.set_pressed_no_signal(owned)
	_buyable.set_pressed_no_signal(buyable)
	_owned.visible = owned_visible


func _filter(node_name: String, text: String) -> CheckButton:
	var button: CheckButton = CheckButton.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.toggled.connect(func(_on: bool) -> void: filters_changed.emit(_owned.button_pressed, _buyable.button_pressed))
	add_child(button)
	return button


## Empties the name search field without emitting `search_changed` (the page clears its own copy).
func clear_search() -> void:
	if _search != null:
		_search.text = ""
