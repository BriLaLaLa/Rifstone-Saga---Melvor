extends GutTest
## Loot tables (docs/05_INTERFACES.md §5.22, 04 §8b, F-32 per entry): parsed Defs, order of the rolls at a kill (own
## drops, area tables, monster tables), the Rift Stone using only its own tables, chance 100 / near 0, and no change of
## the rolls of monsters without tables.
##
## Fixture: `test_loot_area` (table `test_area_loot`: 2 rift_dust at 100%, test_chip at 0.01%), monster `test_loot_monster`
## (table `test_monster_loot`: test_crystal at 100%), stone `test_loot_stone` (table `test_stone_loot`: test_stone 100%,
## test_chip 0.01%). `test_area` has no tables.

const AREA: StringName = &"test_loot_area"
const MONSTER: StringName = &"test_loot_monster"
const PLAIN_AREA: StringName = &"test_area"
const PLAIN_MONSTER: StringName = &"test_monster_a"
const DUST: StringName = &"rift_dust"
const CRYSTAL: StringName = &"test_crystal"
const CHIP: StringName = &"test_chip"
const STONE_ITEM: StringName = &"test_stone"
const SOURCE: StringName = &"test:loot_tables"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session(99))


func _count(session: GameSession, item: StringName) -> int:
	for entry: Dictionary in session.combat.loot.items():
		if entry["item"] == item:
			return int(entry["qty"])
	return 0


func test_defs_are_parsed() -> void:
	var data: GameData = _session.data
	assert_eq(data.loot_tables().size(), 3)
	var table: LootTableDef = data.loot_table(&"test_area_loot")
	assert_eq(table.entries.size(), 2)
	assert_eq(table.entries[0].item_id, DUST)
	assert_eq(table.entries[0].qty_min, 2)
	assert_eq(table.entries[1].chance_pct, 0.01)
	assert_eq(data.area(AREA).loot_tables, [&"test_area_loot"] as Array[StringName])
	assert_eq(data.monster(MONSTER).loot_tables, [&"test_monster_loot"] as Array[StringName])
	assert_eq(data.rift_stone(&"test_loot_stone").loot_tables, [&"test_stone_loot"] as Array[StringName])
	assert_eq(data.area(PLAIN_AREA).loot_tables, [] as Array[StringName])
	assert_null(data.loot_table(&"nope"))
	assert_push_error("unknown loot table")


func test_kill_rolls_area_then_monster_tables_with_chance_100() -> void:
	var loot: LootBag = _session.combat.loot
	KillRewards.grant(_session, loot, _session.data.monster(MONSTER), AREA)
	assert_eq(loot.items()[0], {"item": DUST, "qty": 2}, "the area table comes first")
	assert_eq(loot.items()[1], {"item": CRYSTAL, "qty": 1}, "then the table of the monster")
	for i: int in 9:
		KillRewards.grant(_session, loot, _session.data.monster(MONSTER), AREA)
	assert_eq(_count(_session, DUST), 20, "chance 100: always")
	assert_eq(_count(_session, CRYSTAL), 10)


func test_without_the_area_only_the_monster_tables_roll() -> void:
	KillRewards.grant(_session, _session.combat.loot, _session.data.monster(MONSTER))
	assert_eq(_count(_session, DUST), 0)
	assert_eq(_count(_session, CRYSTAL), 1)


func test_a_tiny_chance_almost_never_drops() -> void:
	var chips: int = 0
	for i: int in 300:
		KillRewards.grant(_session, _session.combat.loot, _session.data.monster(MONSTER), AREA)
		chips += _count(_session, CHIP)
		_session.combat.loot.lose_all()
	assert_lte(chips, 1, "0.01% x 300 kills")


func test_monsters_without_tables_keep_their_rolls() -> void:
	var with_area: GameSession = autofree(TestFactory.session(99))
	var without_area: GameSession = autofree(TestFactory.session(99))
	for i: int in 20:
		KillRewards.grant(with_area, with_area.combat.loot, with_area.data.monster(PLAIN_MONSTER), PLAIN_AREA)
		KillRewards.grant(without_area, without_area.combat.loot, without_area.data.monster(PLAIN_MONSTER))
	assert_eq(with_area.rng.to_save(), without_area.rng.to_save(), "no table, no roll")
	assert_eq(with_area.combat.loot.items(), without_area.combat.loot.items())


func test_the_rift_stone_uses_only_its_own_tables() -> void:
	var stone := RiftStone.new(_session)
	var loot: LootBag = _session.combat.loot
	stone.reward(loot, _session.data.rift_stone(&"test_loot_stone"))
	assert_eq(_count(_session, STONE_ITEM), 1)
	assert_eq(_count(_session, DUST), 0, "not the tables of the area")
	assert_eq(_count(_session, CRYSTAL), 0, "not the tables of the monsters")


func test_a_real_kill_in_the_engine_gives_the_tables() -> void:
	_session.modifiers.set_source(SOURCE, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	var killed: Array[int] = [0]
	_session.events.monster_killed.connect(func(_i: int, _id: StringName) -> void: killed[0] += 1)
	assert_true(_session.combat.start(AREA).ok)
	var guard: int = 0
	while killed[0] < 1 and guard < 2000:
		_session.combat.advance(5000)
		guard += 1
	assert_gte(killed[0], 1)
	assert_eq(_count(_session, DUST), 2 * killed[0])
	assert_eq(_count(_session, CRYSTAL), killed[0])
