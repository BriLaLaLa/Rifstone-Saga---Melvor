extends GutTest
## CharacterPage (M4-09) with a TestFactory session: class, level and XpBar read from the character, redraw on
## character_xp_gained / character_level_up / equipment_changed, everything disconnected by unbind.

const SCENE: PackedScene = preload("res://ui/pages/character/character_page.tscn")
const OBSERVED: Array[StringName] = [&"character_xp_gained", &"character_level_up", &"equipment_changed"]

var _session: GameSession
var _page: CharacterPage


func before_each() -> void:
	_session = TestFactory.session()
	_page = SCENE.instantiate() as CharacterPage
	_page.page_id = &"character"
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_shows_name_class_level_and_xp() -> void:
	var class_def: ClassDef = _session.character.class_def()
	assert_eq(_label("%NameLabel").text, _session.player_name)
	assert_eq(_label("%LevelLabel").text, "%s · Livello 1" % class_def.name)
	assert_null(_page.find_child("DescriptionLabel", true, false))
	assert_eq((_page.get_node("%XpBar") as XpBar).shown_progress(), 0.0)


func test_xp_and_level_up_redraw() -> void:
	_session.character.add_xp(_session.data.character_xp_table().xp_for_level(3))
	assert_string_ends_with(_label("%LevelLabel").text, "Livello %d" % _session.character.get_level())
	assert_gte(_session.character.get_level(), 3)


func test_no_setup_section() -> void:
	assert_null(_page.find_child("SetupList", true, false))
	assert_null(_page.find_child("SetupTitle", true, false))


func test_rename_opens_field_then_sets_the_name() -> void:
	var button: Button = _page.get_node("%RenameButton") as Button
	var edit: LineEdit = _page.get_node("%NameEdit") as LineEdit
	assert_false(edit.visible)
	button.pressed.emit()
	assert_true(edit.visible)
	edit.text = "  Aldo  "
	button.pressed.emit()
	assert_eq(_session.player_name, "Aldo")
	assert_eq(_label("%NameLabel").text, "Aldo")
	assert_false(edit.visible)


func test_rename_refused_keeps_the_name_and_shows_the_reason() -> void:
	var old_name: String = _session.player_name
	var edit: LineEdit = _page.get_node("%NameEdit") as LineEdit
	(_page.get_node("%RenameButton") as Button).pressed.emit()
	edit.text = "   "
	(_page.get_node("%RenameButton") as Button).pressed.emit()
	assert_eq(_session.player_name, old_name)
	assert_true(edit.visible, "the field stays open")
	assert_true(_label("%RenameError").visible)
	var max_length: int = int(_session.data.balance_value("player_name.max_length"))
	assert_false(PlayerName.rename(_session, "x".repeat(max_length + 1)).ok)
	assert_true(PlayerName.rename(_session, "x".repeat(max_length)).ok)


func test_traits_and_abilities_share_one_panel_with_two_tabs() -> void:
	var tabs: TabContainer = _page.find_child("Tabs", true, false) as TabContainer
	assert_eq(tabs.get_tab_count(), 2)
	assert_eq(tabs.get_tab_title(0), LoadoutTexts.TRAITS_TITLE)
	assert_eq(tabs.get_tab_title(1), LoadoutTexts.ABILITIES_TITLE)


func test_unbind_disconnects_everything() -> void:
	_page.unbind()
	for event_name: StringName in OBSERVED:
		var sig: Signal = Signal(_session.events, event_name)
		for connection: Dictionary in sig.get_connections():
			assert_ne((connection["callable"] as Callable).get_object(), _page, "%s still connected" % event_name)
	var shown: String = _label("%LevelLabel").text
	_session.character.add_xp(_session.data.character_xp_table().xp_for_level(3))
	assert_eq(_label("%LevelLabel").text, shown, "no redraw after unbind")


func _label(path: String) -> Label:
	return _page.get_node(path) as Label
