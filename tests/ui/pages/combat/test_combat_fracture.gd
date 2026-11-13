extends GutTest
## The Fracture in progress in the Combat page (M13-05, docs/05_INTERFACES.md §7.v): "Frattura di grado N - gruppo i/N" in place
## of the area, no area choice, the boss with its name and ability, the link to the Fractures page, and back to the normal
## page when the Fracture ends. The loadout cannot be changed during the Fracture.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")

var _s: GameSession
var _page: CombatPage


func before_each() -> void:
	_s = FractureUtil.session(21)
	FractureUtil.hero(_s)
	_page = SCENE.instantiate() as CombatPage
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_s)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_s):
		_s.free()
	await wait_physics_frames(1)


func _label(path: String) -> Label:
	return _page.get_node(path) as Label


func _open(grade: int = 1) -> void:
	assert_true(_s.fractures.open(FractureUtil.card(_s, grade)).ok)


func test_outside_a_fracture_the_page_is_unchanged() -> void:
	assert_true((_page.get_node("%MapButton") as Control).visible)
	assert_false((_page.find_child("FractureLinkButton", true, false) as Control).visible)


func test_header_tells_grade_and_group_in_place_of_the_area() -> void:
	_open(2)
	assert_eq(_label("%AreaLabel").text, FractureTexts.COMBAT_HEADER_TEXT % [2, 1, 3])
	assert_false((_page.get_node("%MapButton") as Control).visible, "no area choice in a Fracture")
	assert_true((_page.find_child("FractureLinkButton", true, false) as Control).visible)


func test_header_follows_the_groups() -> void:
	_open()
	FractureUtil.run_until(_s, func() -> bool: return _s.combat.get_state()["fracture"]["group"] >= 2)
	_page._process(0.0)
	assert_eq(_label("%AreaLabel").text, FractureTexts.COMBAT_HEADER_TEXT % [1, 2, 3])


func test_boss_has_its_name_and_ability() -> void:
	_open()
	FractureUtil.run_until(_s, func() -> bool: return _s.combat.get_state()["fracture"]["boss"] as bool)
	_s.advance(100)
	_page._process(0.0)
	var boss: BossDef = _s.fractures.run().boss_def(_s.data)
	assert_eq(_label("%AreaLabel").text, FractureTexts.COMBAT_HEADER_BOSS_TEXT % 1)
	assert_eq(EnemyView.name_of(_s.data, boss.id), boss.name)
	assert_eq(EnemyView.icon_of(_s.data, boss.id), boss.icon)
	assert_true(EnemyView.info_text(_s.data, boss.id).contains(MapEffectLabels.ability_name(boss.ability.type)))
	assert_true(EnemyView.tag_text(_s.data, boss.id, &"blade").begins_with(EnemyView.BOSS_TAG_TEXT))


func test_normal_page_returns_when_the_fracture_ends() -> void:
	_open()
	assert_true(_s.fractures.abandon().ok)
	assert_true((_page.get_node("%MapButton") as Control).visible)
	assert_false((_page.find_child("FractureLinkButton", true, false) as Control).visible)
	assert_eq(_label("%AreaLabel").text, CombatTexts.NO_AREA_TEXT)


func test_boss_state_line_names_the_ability_and_the_shield() -> void:
	_open()
	FractureUtil.run_until(_s, func() -> bool: return _s.combat.get_state()["fracture"]["boss"] as bool)
	var fracture: Dictionary = (_s.combat.get_state()["fracture"] as Dictionary).duplicate()
	var boss: BossDef = _s.fractures.run().boss_def(_s.data)
	fracture["shield"] = 250
	var text: String = CombatFracture.state_text(fracture, "base", _s.data)
	assert_true(text.begins_with("base"), text)
	assert_true(text.contains(MapEffectLabels.ability_name(boss.ability.type)), text)
	assert_true(text.contains(FractureTexts.COMBAT_SHIELD_TEXT % "250"), text)


func test_loadout_note_shows_during_the_fracture() -> void:
	var character: CharacterPage = preload("res://ui/pages/character/character_page.tscn").instantiate() as CharacterPage
	character.page_id = &"character"
	add_child(character)
	character.bind(_s)
	var panel: LoadoutPanel = character.get_node("%LoadoutPanel") as LoadoutPanel
	assert_false(panel.combat_note_visible(LoadoutPanel.KIND_TRAIT))
	_open()
	assert_true(panel.combat_note_visible(LoadoutPanel.KIND_TRAIT))
	assert_true(panel.combat_note_visible(LoadoutPanel.KIND_ABILITY))
	character.free()
