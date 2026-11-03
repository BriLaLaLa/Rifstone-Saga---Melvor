extends GutTest
## EquipmentPage (M3-07) with a TestFactory session: a row per slot of `Equipment.SLOTS`, worn pieces read from the
## model, "Rimuovi" = unequip, food (heal from `food_heal`, quantity, exhausted), stat summary with
## names and sources from the registry and `modifiers.breakdown`, refused commands show their reason, unbind.

const SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const HELM := &"test_helm"
const RATION := &"test_ration"
const DR := &"damage_reduction"
const OBSERVED: Array[StringName] = [
	&"equipment_changed", &"food_changed", &"modifiers_changed", &"bank_changed", &"armory_changed",
]

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
	var uid: int = TestFactory.give_piece(_session, HELM, &"magic")
	_open()
	assert_true(_session.equipment.equip(uid).ok)
	assert_eq(_item_label(&"head").text, _session.data.item(HELM).name)
	assert_eq(_item_label(&"head").get_theme_color("font_color"), UiStyle.RARITY_MAGIC, "rarity color of the name")
	assert_false(_remove(&"head").disabled)
	var text: String = _stats_text()
	assert_string_contains(text, _session.data.stats.info(DR)["name"])
	assert_string_contains(text, _session.data.item(HELM).name)
	assert_string_contains(text, "Testa")
	var total: String = ItemTooltipLines.format_stat(_session.data.stats.info(DR)["format"],
			_session.modifiers.total(DR))
	assert_string_contains(text, total)


## The "+N" suffix of an upgraded piece is not testable yet: the upgrade (balance key `upgrade.*`) arrives with M7.
func test_rare_piece_name_has_the_rare_color_and_no_suffix() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM, &"rare")
	_open()
	assert_true(_session.equipment.equip(uid).ok)
	assert_eq(_item_label(&"head").text, _session.data.item(HELM).name)
	assert_eq(_item_label(&"head").get_theme_color("font_color"), UiStyle.RARITY_RARE)


func test_no_bonus_text_without_sources() -> void:
	_open()
	assert_string_contains(_stats_text(), "Nessun bonus attivo.")


func test_remove_returns_the_piece_to_the_armory() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_session.equipment.equip(uid)
	_open()
	assert_eq(_session.armory.used(), 0, "a worn piece does not use a slot")
	_remove(&"head").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_true(_session.armory.has(uid))
	assert_eq(_session.armory.used(), 1)
	assert_eq(_item_label(&"head").text, "Vuoto")
	assert_true(_remove(&"head").disabled)
	assert_string_contains(_stats_text(), "Nessun bonus attivo.")


func test_remove_with_a_full_armory_shows_the_reason() -> void:
	var uid: int = TestFactory.give_piece(_session, HELM)
	_session.equipment.equip(uid)
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, HELM)
	_open()
	_remove(&"head").pressed.emit()
	assert_eq(_session.equipment.get_uid(&"head"), uid, "nothing changed")
	assert_eq(_label("%MessageLabel").text, "L'Armeria è piena: non c'è posto per il pezzo.")


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


func test_setup_follows_the_worn_weapons() -> void:
	_open()
	assert_eq(_setup_text(), "Mani nude")
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, &"test_greatsword")).ok)
	assert_eq(_setup_text(), _session.equipment.setup_def().name)
	assert_eq(_setup_text(), "Spadone")
	_remove(&"weapon").pressed.emit()
	assert_eq(_setup_text(), "Mani nude")



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


func _setup_text() -> String:
	return (_page.find_child("SetupLabel", true, false) as Label).text


func test_tool_slot_label_takes_the_skill_name_from_the_data() -> void:
	_open()
	var label: String = (_row(&"tool_forestry").find_child("SlotLabel", true, false) as Label).text
	var found: SkillDef = null
	for skill: SkillDef in _session.data.skills():
		if skill.id == &"forestry":
			found = skill
	if found != null:
		assert_eq(label, "Attrezzo: %s" % found.name)
	else:
		assert_eq(label, "Attrezzo", "no skill with that id in the fixtures: generic label")


func test_summary_shows_the_tool_scoped_to_a_skill() -> void:
	var uid: int = TestFactory.give_piece(_session, &"test_hatchet")
	_open()
	assert_true(_session.equipment.equip(uid).ok)
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


func test_setup_source_is_shown_as_text() -> void:
	var setup: SetupDef = _session.character.class_def().setups[0]
	var expected: String = "Assetto: %s" % setup.name
	assert_eq(EquipmentStatsText.source_name(StringName("setup:%s" % setup.id), _session), expected)
	assert_ne(expected, "setup:%s" % setup.id)
