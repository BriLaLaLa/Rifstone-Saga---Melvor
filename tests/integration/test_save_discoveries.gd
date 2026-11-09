extends GutTest
## Integration (M14-07, F-124): what the player discovered survives the save, a copy continues the same, a new game forgets.

const LOG_ITEM: StringName = &"redbirch_log"
const SWORD: StringName = &"mw_sword_1"


func _session(seed_value: int) -> GameSession:
	return autofree(TestFactory.session(seed_value, TestFactory.real_data()))


func test_the_discoveries_survive_save_codec_and_load() -> void:
	var s: GameSession = _session(5)
	TestFactory.give(s, LOG_ITEM, 4)
	assert_gt(s.armory.create(SWORD, &"masterwork", 3), 0)
	s.bank.remove(LOG_ITEM, 4)  # sold or lost: the discovery stays
	var text: String = SaveCodec.encode(s.to_save(7))
	var other: GameSession = _session(6)
	assert_true(other.from_save(SaveCodec.decode(text)).ok)
	assert_eq(other.discoveries.items(), s.discoveries.items())
	assert_true(other.discoveries.has(LOG_ITEM))
	assert_true(other.discoveries.has(SWORD))
	assert_eq(SaveCodec.encode(other.to_save(7)), text, "the second save is identical")


func test_the_copy_continues_discovering_like_the_original() -> void:
	var s: GameSession = _session(5)
	var other: GameSession = _session(6)
	assert_true(other.from_save(SaveCodec.decode(SaveCodec.encode(s.to_save(7)))).ok)
	for session: GameSession in [s, other]:
		TestFactory.give(session, &"rift_shard", 1)
	assert_eq(other.discoveries.items(), s.discoveries.items())
	assert_true(other.discoveries.has(&"rift_shard"))


func test_a_new_game_forgets_and_keeps_the_kit() -> void:
	var s: GameSession = _session(5)
	var kit: Array[StringName] = s.discoveries.items()
	TestFactory.give(s, LOG_ITEM, 1)
	s.new_game()
	assert_eq(s.discoveries.items(), kit)
	assert_false(s.discoveries.has(LOG_ITEM))


func test_offline_play_unlocks_and_the_save_keeps_it() -> void:
	var s: GameSession = _session(5)
	assert_false(s.discoveries.has(LOG_ITEM))
	assert_true(s.actions.start(&"forestry", &"cut_redbirch").ok)
	OfflineSimulator.advance_silently(s, 30000)
	assert_true(s.discoveries.has(LOG_ITEM))
	var other: GameSession = _session(6)
	assert_true(other.from_save(SaveCodec.decode(SaveCodec.encode(s.to_save(1)))).ok)
	assert_true(other.discoveries.has(LOG_ITEM))
