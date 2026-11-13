class_name PageHost
extends Control
## Central area of the main screen: shows one Page at a time (docs/03_ARCHITECTURE.md §11, 05_INTERFACES.md §7).
##
## `show_page(page_id)` instantiates the scene of the page's route, sets `page_id`, adds it and calls `bind`; the
## page shown before gets `unbind` and is freed. A page id is `<route>` or `<route>:<argument>` (`&"skill:forestry"`).
## `setup(null)` unbinds and frees the current page (the main screen does it on `session_ended`).
## It keeps no game state: only the session reference and the current page node.

signal page_changed(page_id: StringName)

const LOG_CATEGORY: String = "ui"
const ROUTE_SEPARATOR: String = ":"
const ROUTE_SKILL := &"skill"
const ROUTE_GUIDE := &"guide"
## Alias of the guide route: `help:<entry>` opens the Guide on that entry (the "?" buttons, M11-05).
const ROUTE_HELP := &"help"
## Route table: route -> page scene. A route that is not here is not available yet (the sidebar shows "In arrivo").
const ROUTES: Dictionary[StringName, String] = {
	ROUTE_SKILL: "res://ui/pages/skill/skill_page.tscn",
	&"bank": "res://ui/pages/bank/bank_page.tscn",
	&"shop": "res://ui/pages/shop/shop_page.tscn",
	&"village": "res://ui/pages/village/village_page.tscn",
	&"noticeboard": "res://ui/pages/noticeboard/noticeboard_page.tscn",
	&"equipment": "res://ui/pages/equipment/equipment_page.tscn",
	&"character": "res://ui/pages/character/character_page.tscn",
	&"combat": "res://ui/pages/combat/combat_page.tscn",
	&"rift": "res://ui/pages/rift/rift_page.tscn",
	&"fractures": "res://ui/pages/fractures/fractures_page.tscn",
	&"dungeon": "res://ui/pages/dungeon/dungeon_page.tscn",
	ROUTE_GUIDE: "res://ui/pages/guide/guide_page.tscn",
	ROUTE_HELP: "res://ui/pages/guide/guide_page.tscn",
}
## Skill categories drawn by the skill page (combat skills belong to the combat page).
const SKILL_PAGE_CATEGORIES: Array[StringName] = [&"gathering", &"artisan"]

var _session: GameSession = null
var _page: Page = null


## Session whose pages are shown; null unbinds and frees the current page.
func setup(session: GameSession) -> void:
	_clear_page()
	_session = session


## Shows the page of `page_id`; an unavailable page is reported and the current page stays.
func show_page(page_id: StringName) -> void:
	if _session == null:
		Log.warn(LOG_CATEGORY, "show_page('%s') without a session" % page_id)
		return
	if not has_page(page_id):
		Log.warn(LOG_CATEGORY, "show_page: page '%s' is not available" % page_id)
		return
	if _page != null and _page.page_id == page_id:
		return
	# A live Guide opens the requested entry itself (keeps its history) instead of being rebuilt.
	if _page is GuidePage and is_guide_route(page_id) and String(page_id).contains(ROUTE_SEPARATOR):
		(_page as GuidePage).open_page(StringName(String(page_id).substr(String(route_of(page_id)).length() + 1)))
		return
	_clear_page()
	var scene: PackedScene = load(ROUTES[route_of(page_id)]) as PackedScene
	var page: Page = scene.instantiate() as Page
	assert(page != null, "the scene of route '%s' must extend Page" % route_of(page_id))
	page.page_id = page_id
	page.name = "Page"
	if page.has_signal(&"page_requested"):
		page.connect(&"page_requested", show_page)
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page = page
	page.bind(_session)
	page_changed.emit(page_id)


## True if `page_id` has a page now: its route is in ROUTES and, for `skill:<id>`, the skill exists, is drawn by
## the skill page and has actions in the data.
func has_page(page_id: StringName) -> bool:
	if _session == null or not ROUTES.has(route_of(page_id)):
		return false
	if is_guide_route(page_id):
		return true  # `guide` / `help` accept an entry id after the route (which has ":" itself)
	if route_of(page_id) != ROUTE_SKILL:
		return not String(page_id).contains(ROUTE_SEPARATOR)
	var skill_id: StringName = argument_of(page_id)
	for skill: SkillDef in _session.data.skills():
		if skill.id == skill_id:
			var has_actions: bool = not _session.data.actions_for_skill(skill_id).is_empty()
			return SKILL_PAGE_CATEGORIES.has(skill.category) and has_actions
	return false


## Id of the page shown now; `&""` if none.
func current_page_id() -> StringName:
	return _page.page_id if _page != null else &""


## True for `guide`, `help` and `guide:<entry>` / `help:<entry>`.
static func is_guide_route(page_id: StringName) -> bool:
	return route_of(page_id) == ROUTE_GUIDE or route_of(page_id) == ROUTE_HELP


## Route of a page id: the part before ":" (`&"skill:forestry"` -> `&"skill"`).
static func route_of(page_id: StringName) -> StringName:
	return StringName(String(page_id).get_slice(ROUTE_SEPARATOR, 0))


## Argument of a page id: the part after ":" (`&"skill:forestry"` -> `&"forestry"`), `&""` if none.
static func argument_of(page_id: StringName) -> StringName:
	var text: String = String(page_id)
	return StringName(text.get_slice(ROUTE_SEPARATOR, 1)) if text.contains(ROUTE_SEPARATOR) else &""


func _exit_tree() -> void:
	# The page is leaving the tree with this node: unbind it, no remove_child while the tree is busy.
	if _page != null:
		var page: Page = _page
		_page = null
		page.unbind()
		page.queue_free()


func _clear_page() -> void:
	if _page == null:
		return
	var page: Page = _page
	_page = null
	page.unbind()
	remove_child(page)
	page.queue_free()
