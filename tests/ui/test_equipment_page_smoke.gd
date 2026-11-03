extends GutTest
## EquipmentPage (M3-07) with a TestFactory session: a row per slot of `Equipment.SLOTS`, worn pieces read from the
## model, "Rimuovi" = unequip, food (heal from `food_heal`, quantity, exhausted), stance buttons, stat summary with
## names and sources from the registry and `modifiers.breakdown`, refused commands show their reason, unbind.

const SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const HELM := &"test_helm"
const RATION := &"test_ration"
const DR := &"damage_reduction"
const OBSERVED: Array[StringName] = [&"equipment_changed", &"modifiers_changed", &"bank_changed"]

var _session: GameSession
var _page: EquipmentPage


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_a_row_per_slot_all_empty_at_start() -> void:
	_open()
	for slot: StringName in Equipment.SLOTS:
		assert_not_null(_row(slot), "row of %s" % slot)
		assert_eq(_item_label(slot).text, "Vuoto")
		assert_true(_remove(slot).disabled)
	assert_eq(Equipment.SLOTS.size(), 12)
	assert_eq(_label("%TitleLabel").text, "Equipaggiamento")


func test_worn_piece_and_stats_with_sources() -> void:
	pending("M4-08: pezzi nell'Armeria, pagina da rifare")
	return
	TestFactory.give(_session, HELM, 1)
	_open()
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, HELM)).ok)
	assert_eq(_item_label(&"head").text, _session.data.item(HELM).name)
	assert_false(_remove(&"head").disabled)
	var text: String = _stats_text()
	assert_string_contains(text, _session.data.stats.info(DR)["name"])
	assert_string_contains(text, _session.data.item(HELM).name)
	assert_string_contains(text, "Testa")
	var total: String = ItemTooltipLines.format_stat(_session.data.stats.info(DR)["format"],
			_session.modifiers.total(DR))
	assert_string_contains(text, total)


func test_no_bonus_text_without_sources() -> void:
	_open()
	assert_string_contains(_stats_text(), "Nessun bonus attivo.")


func test_remove_returns_the_piece_to_the_bank() -> void:
	pending("M4-08: pezzi nell'Armeria, pagina da rifare")
	return
	TestFactory.give(_session, HELM, 1)
	_session.equipment.equip(TestFactory.give_piece(_session, HELM))
	_open()
	_remove(&"head").pressed.emit()
	assert_eq(_session.equipment.get_item(&"head"), &"")
	assert_eq(_session.bank.get_count(HELM), 1)
	assert_eq(_item_label(&"head").text, "Vuoto")
	assert_true(_remove(&"head").disabled)
	assert_string_contains(_stats_text(), "Nessun bonus attivo.")


func test_refused_remove_shows_the_reason() -> void:
	_open()
	assert_false(_label("%MessageLabel").visible)
	_remove(&"head").pressed.emit()
	assert_true(_label("%MessageLabel").visible)
	assert_eq(_label("%MessageLabel").text, "Lo slot è già vuoto.")
	assert_eq(_session.equipment.get_item(&"head"), &"")


func test_food_shows_heal_quantity_and_exhausted() -> void:
	TestFactory.give(_session, RATION, 3)
	_open()
	assert_true(_session.equipment.set_food(RATION).ok)
	var heal: int = _session.data.item(RATION).food_heal
	assert_string_contains(_food_info().text, "Cura %s punti vita" % NumberFormat.format_int(heal))
	assert_string_contains(_food_info().text, "In bank: 3")
	assert_eq(_food_name().text, _session.data.item(RATION).name)
	_session.bank.remove(RATION, 3)
	assert_string_contains(_food_info().text, "Esaurito")
	assert_eq(_session.equipment.get_food(), RATION, "choice kept at quantity 0")
	_page.find_child("ClearFoodButton", true, false).pressed.emit()
	assert_eq(_session.equipment.get_food(), &"")
	assert_eq(_food_name().text, "Nessun cibo scelto")


func test_stance_buttons_follow_and_set_the_model() -> void:
	pending("M4-08: the stance no longer exists (D3), the page is redone")


func test_unbind_disconnects_everything() -> void:
	_open()
	_page.unbind()
	for event_name: StringName in OBSERVED:
		for connection: Dictionary in Signal(_session.events, event_name).get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)


func _open() -> void:
	_page = SCENE.instantiate() as EquipmentPage
	_page.page_id = &"equipment"
	add_child(_page)
	_page.bind(_session)


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _stats_text() -> String:
	return (_page.get_node("%StatsText") as RichTextLabel).text


func _row(slot: StringName) -> Node:
	return _page.find_child("Row_%s" % slot, true, false)


func _item_label(slot: StringName) -> Label:
	return _row(slot).find_child("ItemLabel", true, false) as Label


func _remove(slot: StringName) -> Button:
	return _row(slot).find_child("RemoveButton", true, false) as Button


func _food_name() -> Label:
	return _page.find_child("FoodName", true, false) as Label


func _food_info() -> Label:
	return _page.find_child("FoodInfo", true, false) as Label


func _stance(stance: StringName) -> Button:
	return _page.find_child("Stance_%s" % stance, true, false) as Button


func test_tool_slot_label_takes_the_skill_name_from_the_data() -> void:
	_open()
	var label: String = (_row(&"tool_forestry").find_child("SlotLabel", true, false) as Label).text
	var skill_id: StringName = &"forestry"
	var found: bool = false
	for skill: SkillDef in _session.data.skills():
		if skill.id == skill_id:
			found = true
			assert_eq(label, "Attrezzo: %s" % skill.name)
	if not found:
		assert_eq(label, "Attrezzo", "no skill with that id in the fixtures: generic label")
	for text: String in ["Selvicoltura", "Estrazione", "Pesca", "Cavatura", "Lenza"]:
		if text != _skill_name(skill_id):
			assert_false(label.contains(text), "no hand-written skill name '%s'" % text)


func test_summary_shows_the_tool_scoped_to_a_skill() -> void:
	pending("M4-08: pezzi nell'Armeria, pagina da rifare")
	return
	TestFactory.give(_session, &"test_hatchet", 1)
	_open()
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, &"test_hatchet")).ok)
	var text: String = _stats_text()
	assert_false(text.contains("Nessun bonus attivo."))
	assert_string_contains(text, _session.data.skill(&"test_gather").name)
	assert_string_contains(text, _session.data.item(&"test_hatchet").name)
	var stat: Dictionary = _session.data.stats.info(&"skill_interval_pct")
	assert_string_contains(text, stat["name"])
	var total: float = _session.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(&"test_gather"))
	assert_string_contains(text, ItemTooltipLines.format_stat(stat["format"], total))
	_remove(&"tool_forestry").pressed.emit()
	assert_string_contains(_stats_text(), "Nessun bonus attivo.")


func _skill_name(skill_id: StringName) -> String:
	for skill: SkillDef in _session.data.skills():
		if skill.id == skill_id:
			return skill.name
	return ""
