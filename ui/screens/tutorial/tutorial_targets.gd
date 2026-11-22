class_name TutorialTargets
extends RefCounted
## Table: tutorial target id (docs/04_DATA_SCHEMA_M30.md §34.4) -> the control to highlight. The data never carry node
## paths: the UI finds the control by the (unique) name it has in the scene of the page. `resolve` returns null when the
## control does not exist or is not visible; the overlay then falls back on the page area.

const PAGE_PREFIX: String = "page."
const LEARN_PREFIX: String = "trainers.learn."
const ENEMY_ZONE_ID: String = "combat.enemy_zone"
const REPLACEMENT_NAMES: Array[String] = ["TravelMap", "NodeCard"]  # added by the combat page next to the zone
const PAGE_HOST_NAME: String = "PageHost"
const PAGE_NODE_NAME: String = "Page"
## Id -> name of the node inside the page shown (found by name, first in tree order).
const BY_NAME: Dictionary[String, String] = {
	"equipment.inventory": "InventoryPanel",
	"combat.map_button": "MapButton",
	"combat.enemy_zone": "EnemyZone",
	"combat.eat_button": "EatButton",
	"skill.header": "Header",
	"mail.list": "ListScroll",
}


## The control of `id` inside the main screen `main`; null if absent or not visible.
static func resolve(id: String, main: Control) -> Control:
	if id.is_empty() or main == null:
		return null
	var host: Control = main.find_child(PAGE_HOST_NAME, true, false) as Control
	if host == null:
		return null
	if id.begins_with(PAGE_PREFIX):
		return _visible(host)
	var page: Node = host.get_node_or_null(PAGE_NODE_NAME)
	if page == null:
		return null
	if id.begins_with(LEARN_PREFIX):
		return _visible(_learn_button(page, StringName(id.trim_prefix(LEARN_PREFIX))))
	if BY_NAME.has(id):
		var found: Control = page.find_child(BY_NAME[id], true, false) as Control
		if found != null and id == ENEMY_ZONE_ID and not found.is_visible_in_tree():
			return _visible(_zone_replacement(found))
		return _visible(found)
	return null


## The "Impara" button of the row of a discipline in the Trainers page.
static func _learn_button(page: Node, skill_id: StringName) -> Control:
	for row: Node in page.find_children("*", "TrainerRow", true, false):
		if (row as TrainerRow).skill_id() == skill_id:
			return row.find_child("LearnButton", true, false) as Control
	return null


static func _visible(control: Control) -> Control:
	if control == null or not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
		return null
	return control


## The combat page swaps the enemy zone for the travel map or the node card between fights (the zone is hidden, e.g. with the
## paused tutorial step 6): the visible sibling that takes its place is the frame target.
static func _zone_replacement(zone: Control) -> Control:
	for sibling_name: String in REPLACEMENT_NAMES:
		var sibling: Node = zone.get_parent().get_node_or_null(sibling_name)
		if sibling is Control and (sibling as Control).is_visible_in_tree():
			return sibling as Control
	return null
