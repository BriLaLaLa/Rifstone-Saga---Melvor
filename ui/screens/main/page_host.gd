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
## Temporary page of the routes whose real page does not exist yet.
const PLACEHOLDER_SCENE: String = "res://ui/screens/main/placeholder_page.tscn"
## Route table: route -> page scene. A route that is not here is not available yet (the sidebar shows "In arrivo").
## M1-15 sets `&"skill"` to res://ui/pages/skill/skill_page.tscn, M1-18 sets `&"bank"` to
## res://ui/pages/bank/bank_page.tscn; later tasks add `shop`, `equipment`, `combat`, `rift`, `settings`.
const ROUTES: Dictionary[StringName, String] = {
	ROUTE_SKILL: PLACEHOLDER_SCENE,
	&"bank": PLACEHOLDER_SCENE,
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
	_clear_page()
	var scene: PackedScene = load(ROUTES[route_of(page_id)]) as PackedScene
	var page: Page = scene.instantiate() as Page
	assert(page != null, "the scene of route '%s' must extend Page" % route_of(page_id))
	page.page_id = page_id
	page.name = "Page"
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
