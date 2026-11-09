extends GutTest
## Combat page ritocchi of the Alpha (M14-06, docs/01_GDD.md §29): XP bar of the character, "Altri nemici", the triangle
## labels "Forte contro di te" / "Debole contro di te" / "Alla pari". Fixture data.

const SCENE: PackedScene = preload("res://ui/pages/combat/combat_page.tscn")

var _session: GameSession
var _page: CombatPage


func before_each() -> void:
	_session = TestFactory.session()
	_page = SCENE.instantiate() as CombatPage
	_page.page_id = &"combat"
	add_child(_page)
	_page.bind(_session)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _player() -> PlayerColumn:
	return _page.get_node("%PlayerColumn") as PlayerColumn


func _expected_xp_text() -> String:
	var level: int = _session.character.get_level()
	return XpBar.XP_TEXT % [NumberFormat.format_int(_session.character.get_xp()),
			NumberFormat.format_int(_session.data.character_xp_table().xp_for_level(level + 1))]


func test_player_card_has_the_xp_bar_with_the_numbers_of_the_model() -> void:
	assert_eq(_player().xp_text(), _expected_xp_text())


func test_xp_bar_follows_character_xp_gained() -> void:
	var before: String = _player().xp_text()
	_session.character.add_xp(5)
	assert_ne(_player().xp_text(), before)
	assert_eq(_player().xp_text(), _expected_xp_text())


func test_queue_title_says_altri_nemici() -> void:
	assert_eq(CombatTexts.QUEUE_TITLE % 3, "Altri nemici (3)")


func test_triangle_labels_read_from_the_monster_point_of_view() -> void:
	assert_eq(CombatTexts.RELATION_TEXTS[&"disadvantage"], "Forte contro di te")
	assert_eq(CombatTexts.RELATION_TEXTS[&"advantage"], "Debole contro di te")
	assert_eq(CombatTexts.RELATION_TEXTS[&"neutral"], "Alla pari")


func test_enemy_tag_uses_the_new_label() -> void:
	var data: GameData = _session.data
	var checked: int = 0
	for area: AreaDef in data.areas():
		for monster_id: StringName in area.monster_ids:
			var def: MonsterDef = data.monster(monster_id)
			var relation: StringName = CombatMath.triangle(_session.equipment.style(), def.style, data)
			var tag: String = EnemyView.tag_text(data, monster_id, _session.equipment.style())
			assert_true(tag.ends_with(CombatTexts.RELATION_TEXTS[relation]), tag)
			checked += 1
	assert_gt(checked, 0)
