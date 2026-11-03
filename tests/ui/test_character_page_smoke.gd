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


func test_shows_class_level_and_xp() -> void:
	var class_def: ClassDef = _session.character.class_def()
	assert_eq(_label("%ClassLabel").text, class_def.name)
	assert_eq(_label("%DescriptionLabel").text, class_def.description)
	assert_eq(_label("%LevelLabel").text, "Livello 1")
	assert_eq((_page.get_node("%XpBar") as XpBar).shown_progress(), 0.0)


func test_xp_and_level_up_redraw() -> void:
	_session.character.add_xp(_session.data.character_xp_table().xp_for_level(3))
	assert_eq(_label("%LevelLabel").text, "Livello %d" % _session.character.get_level())
	assert_gte(_session.character.get_level(), 3)


func test_lists_the_setups_of_the_class() -> void:
	for setup: SetupDef in _session.character.class_def().setups:
		assert_not_null(_page.find_child("Setup_%s" % setup.id, true, false), setup.id)


func test_current_setup_text_is_never_empty() -> void:
	assert_string_contains(_label("%CurrentSetupLabel").text, "In uso: ")
	_session.events.equipment_changed.emit(&"weapon", &"")
	assert_string_contains(_label("%CurrentSetupLabel").text, "In uso: ")


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
