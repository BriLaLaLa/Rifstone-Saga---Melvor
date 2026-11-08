class_name HelpButton
extends Button
## The "?" in the header of every game page (docs/05_INTERFACES.md §7.y, docs/01_GDD.md §27): opens the Guide page
## that explains the page. The page-to-Guide map is not written here: it is the `help_for` field of the pages in
## data/guide/*.json, read through GameData. The button keeps no game state, only the entry it opens.
##
## Pressing it emits `guide_requested`; if the button lives inside a PageHost it also asks the host for the route
## `help:<entry>` (the host opens the entry of a live Guide). Pages add it with `HelpButton.attach`.

signal guide_requested(entry_id: StringName)

const LOG_CATEGORY: String = "ui"
const SCENE_PATH: String = "res://ui/components/help/help_button.tscn"
const NODE_NAME: String = "HelpButton"
const LABEL_TEXT: String = "?"
const TOOLTIP_TITLE: String = "Guida"
const TOOLTIP_BODY: String = "Apre la pagina della Guida su questa schermata."
const MIN_SIZE: Vector2 = Vector2(32, 32)

## Guide page opened by the button (an id of GuideIndex.entry, e.g. `page:<id>`); must exist (checked by tests).
@export var guide_entry: StringName = &""


func _ready() -> void:
	text = LABEL_TEXT
	custom_minimum_size = MIN_SIZE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


## Entry of the Guide page whose `help_for` lists `route` (the lowest `order` wins); `&""` if no page covers it.
static func entry_for(data: GameData, route: StringName) -> StringName:
	var best: GuidePageDef = null
	for page: GuidePageDef in data.guide_pages():
		if page.help_for.has(String(route)) and (best == null or page.order < best.order):
			best = page
	return GuideIndex.entry(&"page", best.id) if best != null else &""


## Adds (once) the "?" of `route` to `parent`, right after `after` when given. A route without a Guide page gets no
## button (and a warning): the tests list every route.
static func attach(parent: Node, data: GameData, route: StringName, after: Node = null) -> HelpButton:
	var existing: HelpButton = parent.get_node_or_null(NODE_NAME) as HelpButton
	if existing != null:
		return existing
	var entry: StringName = entry_for(data, route)
	if entry == &"":
		Log.warn(LOG_CATEGORY, "no Guide page for the help button of '%s'" % route)
		return null
	var button: HelpButton = (load(SCENE_PATH) as PackedScene).instantiate() as HelpButton
	button.name = NODE_NAME
	button.guide_entry = entry
	parent.add_child(button)
	if after != null and after.get_parent() == parent:
		parent.move_child(button, after.get_index() + 1)
	return button


func _on_pressed() -> void:
	guide_requested.emit(guide_entry)
	var node: Node = get_parent()
	while node != null and not node is PageHost:
		node = node.get_parent()
	if node != null:
		(node as PageHost).show_page(StringName("%s%s%s" % [PageHost.ROUTE_HELP, PageHost.ROUTE_SEPARATOR, guide_entry]))


func _on_mouse_entered() -> void:
	Tooltips.show_text(TOOLTIP_TITLE, TOOLTIP_BODY, get_global_mouse_position())


func _on_mouse_exited() -> void:
	Tooltips.hide_tooltip()
