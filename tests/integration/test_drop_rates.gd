extends GutTest
## Rates of the drops of the Alpha (F-121, F-84, F-120, F-124) on the real data, through the public API: the static table
## of the pool adds up to the declared chances; a seeded sample of rolls matches them within 4 sigma; rarity and legendary
## rolls follow their chances. Nothing here depends on the tuned value: every expectation is read from `balance.json`.

const SEED: int = 8642
const ROLLS: int = 40000
const SIGMAS: float = 4.0

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _pct(key: String) -> float:
	return float(_data.balance_value(key))


## The tolerance of `n` Bernoulli trials of probability `p`, in counts.
func _tolerance(n: int, p: float) -> float:
	return SIGMAS * sqrt(float(n) * p * (1.0 - p)) + 1.0


func test_the_static_table_adds_up_to_the_declared_chances() -> void:
	for level: int in [1, 20, 45, 70, 99]:
		var pieces: float = 0.0
		var blueprints: float = 0.0
		var table: Dictionary[StringName, float] = EquipmentPool.table(level, _data)
		assert_false(table.is_empty(), "level %d has a table" % level)
		for id: StringName in table:
			if _data.item(id).is_blueprint():
				blueprints += table[id]
			else:
				pieces += table[id]
		assert_almost_eq(pieces, _pct("loot.equipment.chance_pct"), 0.0001, "pieces at level %d" % level)
		assert_almost_eq(blueprints, _pct("loot.blueprint.chance_pct"), 0.0001, "blueprints at level %d" % level)


func test_a_sample_of_pool_rolls_matches_the_chances() -> void:
	var rng: RngService = RngService.new(SEED)
	var level: int = 60
	var pieces: int = 0
	var blueprints: int = 0
	var grades: Array[int] = EquipmentDrop.candidate_grades(level, _data)
	var kinds: Dictionary = {}
	for _i: int in ROLLS:
		var piece: StringName = EquipmentDrop.roll(level, _data, rng)
		if piece != &"":
			pieces += 1
			var def: ItemDef = _data.item(piece)
			assert_true(grades.has(def.equip.grade), "%s: the grade is in the window of level %d" % [piece, level])
			kinds[EquipmentPool.kind_of(def)] = kinds.get(EquipmentPool.kind_of(def), 0) + 1
		var blueprint: StringName = EquipmentDrop.roll_blueprint(level, _data, rng)
		if blueprint != &"":
			blueprints += 1
			assert_true(_data.item(blueprint).is_blueprint())
	var piece_p: float = _pct("loot.equipment.chance_pct") / 100.0
	var bp_p: float = _pct("loot.blueprint.chance_pct") / 100.0
	assert_almost_eq(float(pieces), float(ROLLS) * piece_p, _tolerance(ROLLS, piece_p), "pieces in %d kills" % ROLLS)
	assert_almost_eq(float(blueprints), float(ROLLS) * bp_p, _tolerance(ROLLS, bp_p), "blueprints in %d kills" % ROLLS)
	var kind_list: Array[StringName] = EquipmentPool.kinds(_data)
	for kind: StringName in kind_list:
		var p: float = piece_p * EquipmentPool.share(kind, kind_list, _data)
		assert_almost_eq(float(kinds.get(kind, 0)), float(ROLLS) * p, _tolerance(ROLLS, p), "type %s" % kind)


func test_rarity_rolls_follow_rarity_drop() -> void:
	var rng: RngService = RngService.new(SEED)
	for source: StringName in [ItemRoller.SOURCE_MONSTER, ItemRoller.SOURCE_RIFT_STONE]:
		var chances: Vector2 = ItemRoller.drop_chances(source, 0.0, _data)
		var counts: Dictionary = {}
		for _i: int in ROLLS:
			var rarity: StringName = ItemRoller.roll_rarity(chances, rng)
			counts[rarity] = counts.get(rarity, 0) + 1
		var magic_p: float = chances.x / 100.0
		var rare_p: float = chances.y / 100.0
		assert_almost_eq(float(counts.get(&"magic", 0)), float(ROLLS) * magic_p, _tolerance(ROLLS, magic_p), "%s magic" % source)
		assert_almost_eq(float(counts.get(&"rare", 0)), float(ROLLS) * rare_p, _tolerance(ROLLS, rare_p), "%s rare" % source)
		assert_false(counts.has(Rarities.MASTERWORK) or counts.has(Rarities.LEGENDARY), "%s: no Masterwork or legendary" % source)
	var boosted: Vector2 = ItemRoller.drop_chances(ItemRoller.SOURCE_MONSTER, 100.0, _data)
	var plain: Vector2 = ItemRoller.drop_chances(ItemRoller.SOURCE_MONSTER, 0.0, _data)
	assert_gt(boosted.y, plain.y, "item rarity raises the rare chance")


func test_a_sample_of_legendary_rolls_matches_the_chance_of_each_source() -> void:
	var rng: RngService = RngService.new(SEED)
	var sources: Dictionary = {}
	for def: ItemDef in _data.legendaries():
		var info: LegendaryInfo = def.equip.legendary
		if info.source_type in [LegendaryInfo.SOURCE_BOSS, LegendaryInfo.SOURCE_MONOLITH]:
			sources["%s|%s" % [info.source_type, info.source_id]] = [info.source_type, info.source_id]
	assert_gt(sources.size(), 1, "boss and Monolith sources")
	var trials: int = ROLLS / 2  # legendaries_from scans the items: a few sources, not all
	var keys: Array = sources.keys().slice(0, 3)
	for key: Variant in keys:
		var source: Array = sources[key]
		var items: Array[ItemDef] = _data.legendaries_from(source[0], source[1])
		var counts: Dictionary = {}
		for _i: int in trials:
			for id: StringName in LegendaryRoller.roll(source[0], source[1], _data, rng):
				counts[id] = counts.get(id, 0) + 1
		for def: ItemDef in items:
			var p: float = def.equip.legendary.chance_pct / 100.0
			assert_almost_eq(float(counts.get(def.id, 0)), float(trials) * p, _tolerance(trials, p), "%s from %s" % [def.id, key])
