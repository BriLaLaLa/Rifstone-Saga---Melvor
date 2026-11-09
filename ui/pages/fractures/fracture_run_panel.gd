class_name FractureRunPanel
extends VBoxContainer
## The Fracture in progress (docs/05_INTERFACES.md §7.v): grade, "Gruppo N/30" bar, the boss, the active modifiers and the
## Fracture bag. Everything is read from `session.fractures.state()` at every `redraw`; the panel keeps no data.

const SEPARATION: int = 8
const BAR_HEIGHT: int = 18


func _init() -> void:
	add_theme_constant_override("separation", SEPARATION)


## Rebuilds the panel from the state of the Fracture; empty (and hidden) outside the Fracture.
func redraw(session: GameSession) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var state: Dictionary = session.fractures.state()
	visible = not state.is_empty()
	if state.is_empty():
		return
	var card: MapCard = state["card"] as MapCard
	add_child(_label("TitleLabel", FractureTexts.RUN_TITLE_TEXT % int(state["grade"]), &"HeaderLabel"))
	add_child(_progress(state))
	add_child(_boss_label(session, state))
	add_child(_label("ModsTitle", FractureTexts.MODS_TITLE_TEXT, &"HeaderLabel"))
	var effects: Array[Dictionary] = MapCardRoller.effects(card, session.data)
	if effects.is_empty():
		add_child(_label("NoMods", FractureTexts.NO_MODS_TEXT, &"MutedLabel"))
	for effect: Dictionary in effects:
		var def: MapModDef = session.data.map_mod(effect["mod"] as StringName)
		var line: Label = _label("Mod_%s" % effect["mod"], "%s: %s" % [def.name if def != null else effect["mod"],
				FractureTexts.effect_line(effect)], &"")
		add_child(line)
	add_child(_label("BagTitle", FractureTexts.BAG_TITLE_TEXT, &"HeaderLabel"))
	var bag_text: String = FractureTexts.bag_text(state["bag"] as Dictionary)
	add_child(_label("BagText", bag_text if bag_text != "" else FractureTexts.BAG_EMPTY_TEXT, &"MutedLabel"))


func _progress(state: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Progress"
	var groups: int = int(state["groups"])
	var group: int = mini(int(state["group"]), groups)
	var bar := ProgressBar.new()
	bar.name = "GroupBar"
	bar.min_value = 0
	bar.max_value = groups
	bar.value = groups if bool(state["boss"]) else group
	bar.show_percentage = false
	bar.custom_minimum_size.y = BAR_HEIGHT
	box.add_child(bar)
	box.add_child(_label("GroupLabel", FractureTexts.GROUP_TEXT % [group, groups], &""))
	return box


func _boss_label(session: GameSession, state: Dictionary) -> Label:
	var text: String = FractureTexts.BOSS_TEXT
	if bool(state["boss"]):
		var boss: BossDef = session.fractures.run().boss_def(session.data)
		if boss != null:
			text = FractureTexts.BOSS_NAMED_TEXT % boss.name
	return _label("BossLabel", text, &"MutedLabel" if not bool(state["boss"]) else &"")


func _label(node_name: String, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != &"":
		label.theme_type_variation = variation
	return label
