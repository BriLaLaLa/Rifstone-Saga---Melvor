extends GutTest
## Discoveries (F-124, M14-07): the set of items obtained at least once, per slot; `item_obtained` from Bank, loot bag,
## Armory and CardStore; `item_discovered`; save v5; the starting kit counts.

const LOG_ITEM: StringName = &"redbirch_log"
const SWORD: StringName = &"mw_sword_1"

var _data: GameData
var _discovered: Array[StringName] = []


func before_all() -> void:
	_data = TestFactory.real_data()


func _session() -> GameSession:
	var session: GameSession = autofree(TestFactory.session(11, _data))
	_discovered.clear()
	session.events.item_discovered.connect(func(item_id: StringName) -> void: _discovered.append(item_id))
	return session


func test_the_starting_kit_counts_as_obtained() -> void:
	var s: GameSession = _session()
	for row: Variant in (_data.balance_value("start") as Dictionary)["items"]:
		assert_true(s.discoveries.has(StringName(str((row as Dictionary)["item"]))))
	for key: String in ["armory", "tools"]:
		for row: Variant in (_data.balance_value("start") as Dictionary)[key]:
			assert_true(s.discoveries.has(StringName(str((row as Dictionary)["base"]))), key)
	assert_false(s.discoveries.has(LOG_ITEM))


func test_note_is_new_once_and_emits_item_discovered() -> void:
	var s: GameSession = _session()
	assert_true(s.discoveries.note(LOG_ITEM))
	assert_false(s.discoveries.note(LOG_ITEM))
	assert_eq(_discovered, [LOG_ITEM] as Array[StringName], "only the first time")
	assert_true(s.discoveries.has(LOG_ITEM))
	assert_true(s.discoveries.items().has(LOG_ITEM))


func test_an_unknown_id_is_ignored() -> void:
	var s: GameSession = _session()
	var before: int = s.discoveries.items().size()
	assert_false(s.discoveries.note(&"no_such_item"))
	assert_eq(s.discoveries.items().size(), before)


func test_the_bank_loot_bag_armory_and_cards_emit_item_obtained() -> void:
	var s: GameSession = _session()
	TestFactory.give(s, LOG_ITEM, 3)
	assert_true(s.discoveries.has(LOG_ITEM), "Bank.add")
	assert_true(s.combat.loot.add(&"rift_shard", 2), "loot bag")
	assert_true(s.discoveries.has(&"rift_shard"), "LootBag.add")
	var uid: int = s.armory.create(SWORD, &"masterwork", 5)
	assert_gt(uid, 0)
	assert_true(s.discoveries.has(SWORD), "Armory.add: the id of the base")
	var card_uid: int = s.cards.create(2, &"magic")
	assert_gt(card_uid, 0)
	assert_true(s.discoveries.has(&"fracture_card_2"), "CardStore: the id of the base")


func test_an_item_stays_discovered_after_it_is_sold_or_lost() -> void:
	var s: GameSession = _session()
	TestFactory.give(s, LOG_ITEM, 3)
	s.bank.remove(LOG_ITEM, 3)
	assert_eq(s.bank.get_count(LOG_ITEM), 0)
	assert_true(s.discoveries.has(LOG_ITEM))


func test_quantity_zero_notes_nothing() -> void:
	var s: GameSession = _session()
	s.events.item_obtained.emit(LOG_ITEM, 0)
	assert_false(s.discoveries.has(LOG_ITEM))


func test_a_piece_filtered_out_by_the_armory_is_still_seen() -> void:
	var s: GameSession = _session()
	assert_true(s.armory.set_filter(&"head", &"rare", 15).ok)
	var inst: ItemInstance = ItemRoller.create(_data.item(&"emberbronze_helm"), &"common", 1, _data, s.rng)
	s.armory.add_drop(inst)
	assert_eq(s.armory.instances().filter(func(i: ItemInstance) -> bool: return i.base_id == &"emberbronze_helm").size(), 0)
	assert_true(s.discoveries.has(&"emberbronze_helm"), "seen even when sold by the filter")


func test_save_round_trip_keeps_the_order_and_is_silent() -> void:
	var s: GameSession = _session()
	TestFactory.give(s, LOG_ITEM, 1)
	var saved: Dictionary = s.discoveries.to_save()
	assert_eq(saved["items"][saved["items"].size() - 1], String(LOG_ITEM))
	var other: GameSession = _session()
	_discovered.clear()
	other.discoveries.from_save(saved)
	assert_eq(other.discoveries.items(), s.discoveries.items())
	assert_eq(_discovered, [] as Array[StringName], "from_save is silent")


func test_from_save_is_tolerant() -> void:
	var s: GameSession = _session()
	s.discoveries.from_save({"items": [String(LOG_ITEM), "no_such_item", LOG_ITEM, 5]})
	assert_eq(s.discoveries.items(), [LOG_ITEM] as Array[StringName], "unknown dropped, duplicates merged")
	s.discoveries.from_save({"items": "x"})
	assert_eq(s.discoveries.items().size(), 0)
	s.discoveries.from_save({})
	assert_eq(s.discoveries.items().size(), 0, "missing = empty")


func test_new_game_starts_from_the_kit_only() -> void:
	var s: GameSession = _session()
	var kit: Array[StringName] = s.discoveries.items()
	TestFactory.give(s, LOG_ITEM, 1)
	s.discoveries.new_game()
	assert_eq(s.discoveries.items(), kit)


func test_offline_gathering_unlocks_what_it_produces() -> void:
	var s: GameSession = _session()
	assert_true(s.actions.start(&"forestry", &"cut_redbirch").ok)
	OfflineSimulator.advance_silently(s, 60000)
	assert_true(s.discoveries.has(LOG_ITEM))
