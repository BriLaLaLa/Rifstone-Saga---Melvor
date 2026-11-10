extends GutTest
## GuideIndex.drops_of / drops_view / sources_visible (F-124, M14-07): everything a monster, an area, a Rift Stone, a
## boss or an action can give, with the base percentage; the sources of the pool (F-121) and of the legendaries (F-120).

var _data: GameData
var _index: GuideIndex


func before_all() -> void:
	_data = TestFactory.real_data()
	_index = GuideIndex.new(_data)


func _items(refs: Array[GuideRef]) -> Array[StringName]:
	var result: Array[StringName] = []
	for ref: GuideRef in refs:
		result.append(ref.item)
	return result


func _ref_of(refs: Array[GuideRef], item_id: StringName) -> GuideRef:
	for ref: GuideRef in refs:
		if ref.item == item_id:
			return ref
	return null


func _first_monster() -> MonsterDef:
	return _data.monster(_data.areas()[0].monster_ids[0])


func test_a_monster_lists_its_drops_with_the_data_percentages() -> void:
	var monster: MonsterDef = _first_monster()
	var refs: Array[GuideRef] = _index.drops_of(&"monster", monster.id)
	assert_false(refs.is_empty())
	for drop: DropEntry in monster.drops:
		var ref: GuideRef = _ref_of(refs, drop.item_id)
		assert_not_null(ref, String(drop.item_id))
		if ref != null:
			assert_eq(ref.chance_pct, drop.chance_pct)
			assert_eq(ref.target, GuideIndex.entry(&"item", drop.item_id))


func test_a_monster_lists_the_pool_pieces_of_its_level_with_the_f124_percentage() -> void:
	var monster: MonsterDef = _data.monster(_data.areas()[3].monster_ids[0])
	var level: int = EquipmentPool.monster_level(monster)
	var refs: Array[GuideRef] = _index.drops_of(&"monster", monster.id)
	var table: Dictionary[StringName, float] = EquipmentPool.table(level, _data)
	assert_gt(table.size(), 0)
	for id: StringName in table:
		var ref: GuideRef = _ref_of(refs, id)
		assert_not_null(ref, String(id))
		if ref != null:
			assert_eq(ref.chance_pct, table[id])
			assert_eq(ref.kind, GuideRef.KIND_POOL)


func test_an_area_gathers_what_its_monsters_can_give() -> void:
	var area: AreaDef = _data.areas()[0]
	var area_items: Array[StringName] = _items(_index.drops_of(&"area", area.id))
	for monster_id: StringName in area.monster_ids:
		for item_id: StringName in _items(_index.drops_of(&"monster", monster_id)):
			assert_true(area_items.has(item_id), "%s of %s" % [item_id, monster_id])


func test_a_rift_stone_lists_its_drops_and_its_legendaries() -> void:
	var stone: RiftStoneDef = null
	for area: AreaDef in _data.areas():
		var candidate: RiftStoneDef = _data.rift_stones_for_area(area.id)[0] if not _data.rift_stones_for_area(area.id).is_empty() else null
		if candidate != null and not _data.legendaries_from(&"monolith", candidate.area_id).is_empty():
			stone = candidate
			break
	assert_not_null(stone)
	var refs: Array[GuideRef] = _index.drops_of(&"rift_stone", stone.id)
	for legendary: ItemDef in _data.legendaries_from(&"monolith", stone.area_id):
		var ref: GuideRef = _ref_of(refs, legendary.id)
		assert_not_null(ref, String(legendary.id))
		assert_eq(ref.chance_pct, legendary.equip.legendary.chance_pct)


func test_a_boss_lists_dust_and_its_legendaries() -> void:
	var boss: BossDef = _data.boss_for_grade(1)
	var refs: Array[GuideRef] = _index.drops_of(&"boss", boss.id)
	assert_not_null(_ref_of(refs, &"rift_dust"))
	var legendaries: Array[ItemDef] = _data.legendaries_from(&"boss", boss.id)
	assert_gt(legendaries.size(), 0)
	for legendary: ItemDef in legendaries:
		assert_eq(_ref_of(refs, legendary.id).chance_pct, legendary.equip.legendary.chance_pct)


func test_an_action_lists_its_outputs_without_a_percentage() -> void:
	var action: ActionDef = _data.action(&"cut_redbirch")
	var refs: Array[GuideRef] = _index.drops_of(&"action", action.id)
	assert_eq(_ref_of(refs, action.outputs[0].item_id).chance_pct, -1.0)


func test_unknown_ids_give_nothing() -> void:
	assert_eq(_index.drops_of(&"monster", &"no_such_monster").size(), 0)
	assert_eq(_index.drops_of(&"boss", &"no_such_boss").size(), 0)
	assert_eq(_index.drops_of(&"nonsense", &"x").size(), 0)
	assert_push_error(3)

func test_the_sources_of_the_pool_and_of_the_legendaries_are_in_the_index() -> void:
	var legendary: ItemDef = _data.legendaries()[0]
	var sources: Array[GuideRef] = _index.sources_of(legendary.id)
	assert_eq(sources.size(), 1)
	assert_eq(sources[0].chance_pct, legendary.equip.legendary.chance_pct)
	assert_eq(sources[0].item, legendary.id)
	var piece: StringName = EquipmentPool.base_for(&"sword", &"", 3, _data)
	var piece_sources: Array[GuideRef] = _index.sources_of(piece)
	assert_gt(piece_sources.size(), 0, "a pool piece has the areas where it falls")
	assert_eq(piece_sources[0].kind, GuideRef.KIND_POOL)
	assert_gt(piece_sources[0].chance_pct, 0.0)


func test_percentage_text_keeps_four_decimals() -> void:
	assert_eq(GuideDrops.pct_text(0.020833), "0.0208")
	assert_eq(GuideDrops.pct_text(2.5), "2.5")
	assert_eq(GuideDrops.pct_text(8.0), "8")
	assert_eq(GuideDrops.pct_text(0.8), "0.8")
