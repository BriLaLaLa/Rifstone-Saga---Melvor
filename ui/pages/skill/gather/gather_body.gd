class_name GatherBody
extends VBoxContainer
## Body of a gathering page (docs/01_GDD_M36.md §44.2, docs/05_INTERFACES_M36.md §7.ae): the bar Panoramica / Risorse / Attrezzo and the
## three tabs. The tab is a view setting (not saved); it opens on Panoramica. Commands go out as signals, the page sends them to the
## model. `redraw` rereads only the visible tab (a tab shown later is redrawn when it is shown). No game state.
## Nodes: GatherTabs, TabOverview, ResourceTable (tab Risorse), TabTool.

signal go_to_area_requested(area_id: StringName)
signal tool_upgrade_requested(uid: int)
signal tool_head_chosen(uid: int, step: int, head_id: StringName)

const TAB_OVERVIEW: StringName = &"overview"
const TAB_RESOURCES: StringName = &"resources"
const TAB_TOOL: StringName = &"tool"
const TAB_ORDER: Array[StringName] = [TAB_OVERVIEW, TAB_RESOURCES, TAB_TOOL]
## Disciplines with a tool (the Attrezzo tab is hidden for the others).
const TOOL_SKILLS: Array[StringName] = [&"forestry", &"quarrying", &"angling", &"herbalism"]
const TOOL_PANEL_SCENE: PackedScene = preload("res://ui/pages/skill/tool_upgrade_panel.tscn")

var _session: GameSession = null
var _skill_id: StringName = &""
var _tab: StringName = TAB_OVERVIEW
var _tabs: TabBar = null
var _overview: GatherOverview = null
var _table: ResourceTable = null
var _tool_panel: ToolUpgradePanel = null
var _pages: Dictionary[StringName, Control] = {}


## Builds the tabs for `skill_id` (call once, after the body entered the tree).
func setup(session: GameSession, skill_id: StringName) -> void:
	_session = session
	_skill_id = skill_id
	name = "GatherBody"
	add_theme_constant_override("separation", 12)
	_tabs = TabBar.new()
	_tabs.name = "GatherTabs"
	_tabs.focus_mode = Control.FOCUS_NONE
	for tab: StringName in TAB_ORDER:
		_tabs.add_tab(OverviewTexts.TAB_TITLES[tab])
	_tabs.tab_changed.connect(_on_tab_changed)
	add_child(_tabs)
	_overview = GatherOverview.new()
	add_child(_overview)
	_overview.setup(skill_id)
	_overview.tool_tab_requested.connect(show_tab.bind(TAB_TOOL))
	_pages[TAB_OVERVIEW] = _overview
	_table = ResourceTable.new()
	add_child(_table)
	_table.setup(session.data, skill_id)
	_table.zone_requested.connect(go_to_area_requested.emit)
	_pages[TAB_RESOURCES] = _table
	_tool_panel = TOOL_PANEL_SCENE.instantiate() as ToolUpgradePanel
	_tool_panel.name = "TabTool"
	add_child(_tool_panel)
	_tool_panel.setup(skill_id)
	_tool_panel.upgrade_requested.connect(tool_upgrade_requested.emit)
	_tool_panel.head_chosen.connect(tool_head_chosen.emit)
	_pages[TAB_TOOL] = _tool_panel
	for id: StringName in TAB_ORDER:  # every tab is drawn once, then only the visible one follows the events
		_tab = id
		redraw(session)
	_tabs.set_tab_hidden(TAB_ORDER.find(TAB_TOOL), not TOOL_SKILLS.has(skill_id))
	show_tab(TAB_OVERVIEW)


## Rereads the visible tab.
func redraw(session: GameSession) -> void:
	_session = session
	match _tab:
		TAB_OVERVIEW:
			_overview.redraw(session)
		TAB_RESOURCES:
			_table.redraw(session)
		TAB_TOOL:
			_tool_panel.redraw(session)


## The page unbound: the body keeps no reference to the session.
func forget_session() -> void:
	_session = null


func current_tab() -> StringName:
	return _tab


func show_tab(tab: StringName) -> void:
	if not _pages.has(tab):
		return
	_tab = tab
	_tabs.current_tab = TAB_ORDER.find(tab)
	for id: StringName in _pages:
		_pages[id].visible = id == tab
	if _session != null:
		redraw(_session)


func _on_tab_changed(index: int) -> void:
	if index >= 0 and index < TAB_ORDER.size() and TAB_ORDER[index] != _tab:
		show_tab(TAB_ORDER[index])
