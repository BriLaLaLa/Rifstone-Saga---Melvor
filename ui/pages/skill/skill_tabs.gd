class_name SkillTabs
extends RefCounted
## Sub-tabs of the Forging and Engraver pages (docs/01_GDD.md §29): builds the SubTabBar above the page body and shows
## only the cards and sections of the picked tab. Presentation only and not saved; the SkillPage owns the nodes.

var _bar: SubTabBar = null
var _skill_id: StringName = &""
var _extras: Container = null
var _cards: Dictionary[StringName, ActionCard] = {}
var _data: GameData = null
var _blueprints: Control = null
var _bench: Control = null


## The tabs `[{"id", "label"}]` of `skill_id`; empty for a skill without sub-tabs.
static func tabs_for(skill_id: StringName) -> Array[Dictionary]:
	var tabs: Array[Dictionary] = []
	if skill_id == ForgeTabs.SKILL:
		tabs.assign(ForgeTabs.TABS)
	elif skill_id == EngraverSections.SKILL:
		tabs.assign(EngraverSections.TABS)
	return tabs


## Puts the bar at the top of the parent of `extras` (if the skill has tabs) and shows the first tab.
func build(skill_id: StringName, extras: Container, cards: Dictionary[StringName, ActionCard], data: GameData,
		blueprints: Control, bench: Control) -> void:
	clear()
	var tabs: Array[Dictionary] = tabs_for(skill_id)
	if tabs.is_empty():
		return
	_skill_id = skill_id
	_extras = extras
	_cards = cards
	_data = data
	_blueprints = blueprints
	_bench = bench
	_bar = SubTabBar.new()
	_bar.name = "SubTabs"
	extras.get_parent().add_child(_bar)
	extras.get_parent().move_child(_bar, 0)
	_bar.setup(tabs)
	_bar.tab_selected.connect(show_tab)
	show_tab(_bar.current())


## Removes the bar.
func clear() -> void:
	if _bar != null and is_instance_valid(_bar):
		_bar.get_parent().remove_child(_bar)
		_bar.queue_free()
	_bar = null


func show_tab(tab_id: StringName) -> void:
	if _skill_id == EngraverSections.SKILL:
		EngraverSections.show_tab(_extras, tab_id)
		return
	for action_id: StringName in _cards:
		_cards[action_id].visible = ForgeTabs.tab_of(_data.action(action_id)) == tab_id
	if _blueprints != null:
		_blueprints.visible = tab_id == ForgeTabs.TAB_BLUEPRINTS
	if _bench != null:
		_bench.visible = tab_id == ForgeTabs.TAB_BENCH
