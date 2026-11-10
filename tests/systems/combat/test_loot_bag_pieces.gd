extends GutTest
## M15-04 (METIN Z1): pieces wait in the LootBag until collected; auto_loot sends them at once; save v6.

var _session: GameSession
var _bag: LootBag


func before_each() -> void:
	_session = autofree(TestFactory.session_no_kit(7, TestFactory.real_data()))
	_bag = LootBag.new(_session)


func _piece(rarity: StringName = Rarities.COMMON) -> ItemInstance:
	var base: ItemDef = null
	for def: ItemDef in _session.data.items():
		if def.equip != null and _session.data.is_equipment_pool_base(def.id):
			base = def
			break
	return ItemRoller.create(base, rarity, 10, _session.data, _session.rng)


func test_a_dropped_piece_is_not_in_the_armory_until_collected() -> void:
	var before: int = _session.armory.instances().size()
	_bag.add_piece(_piece())
	assert_eq(_bag.pieces().size(), 1)
	assert_eq(_session.armory.instances().size(), before)
	assert_true(_bag.collect_all().ok)
	assert_eq(_bag.pieces().size(), 0)
	assert_eq(_session.armory.instances().size(), before + 1, "conserved: moved, not duplicated")


func test_auto_loot_sends_the_piece_at_once() -> void:
	_session.modifiers.set_source(&"test:auto", [Modifier.make(&"auto_loot", 1.0)] as Array[Modifier])
	var before: int = _session.armory.instances().size()
	_bag.add_piece(_piece())
	assert_eq(_bag.pieces().size(), 0)
	assert_eq(_session.armory.instances().size(), before + 1)


func test_death_loses_the_pieces() -> void:
	_bag.add_piece(_piece())
	var before: int = _session.armory.instances().size()
	_bag.lose_all()
	assert_eq(_bag.pieces().size(), 0)
	assert_eq(_session.armory.instances().size(), before)


func test_save_round_trip_keeps_pieces_and_stacks() -> void:
	_bag.add(&"rift_shard", 3)
	_bag.add_piece(_piece(Rarities.RARE))
	var saved: Dictionary = _bag.to_save()
	var copy := LootBag.new(_session)
	copy.from_save(saved)
	assert_eq(copy.items(), _bag.items())
	assert_eq(copy.pieces().size(), 1)
	assert_eq(copy.pieces()[0].base_id, _bag.pieces()[0].base_id)
	assert_eq(copy.pieces()[0].rarity, Rarities.RARE)


func test_migration_5_to_6_wraps_the_loot_array() -> void:
	var v5: Dictionary = {"format_version": 5, "modules": {"combat": {"loot": [{"item": "rift_shard", "qty": 4}]}}}
	var out: Dictionary = SaveMigrator.migrate(v5)
	assert_eq(out["format_version"], 6)
	var loot: Dictionary = out["modules"]["combat"]["loot"]
	assert_eq(loot["stacks"], [{"item": "rift_shard", "qty": 4}])
	assert_eq(loot["pieces"], [])
	assert_eq(v5["modules"]["combat"]["loot"].size(), 1, "input untouched")


func test_a_v5_session_save_loads_into_the_bag() -> void:
	_session.combat.loot.add(&"rift_shard", 2)
	var saved: Dictionary = _session.to_save(1)
	var combat: Dictionary = saved["modules"]["combat"]
	combat["loot"] = (combat["loot"] as Dictionary)["stacks"]
	saved["format_version"] = 5
	var other: GameSession = autofree(TestFactory.session_no_kit(8, TestFactory.real_data()))
	assert_true(other.from_save(SaveMigrator.migrate(saved)).ok)
	assert_eq(other.combat.loot.items(), [{"item": &"rift_shard", "qty": 2}])
