extends GutTest
## Integration: to_save → SaveCodec.encode → decode → from_save → to_save is identical byte for byte, also in the
## middle of a cycle (elapsed_ms) and with the RNG advanced; afterwards both copies produce the same sequences.
##
## The copy is created with a different seed, so everything it does afterwards comes from the save (rng block
## included). The disk variant goes through SaveService (base_dir user://test_saves, set by gut_pre_run.gd).

const SEED: int = 77001
const OTHER_SEED: int = 5
const NOW_MS: int = 1793603600000
const SKILL: StringName = &"forestry"
const ACTION: StringName = &"cut_redbirch"
const SHARD: StringName = &"rift_shard"
const TEST_DIR: String = "user://test_saves"
const TEST_SLOT: int = 1
# 20 whole cycles of 3000 ms (F-03, T1) plus 1500 ms: the lane is half way through cycle 21.
const MID_CYCLE_RUN_MS: int = 61500
const MID_CYCLE_ELAPSED_MS: int = 1500
const AFTER_LOAD_MS: int = 600000
# 600 000 / 3000 (F-03, T1, no interval modifiers).
const AFTER_LOAD_CYCLES: int = 200
const TICK_MS: int = 100
const SHARD_SOURCE: StringName = &"test:roundtrip"
# Enough shard chance that the outputs sequence after the load is not trivially the same.
const SHARD_CHANCE: float = 30.0
const DOUBLE_CHANCE: float = 40.0

var _sessions: Array[GameSession] = []
var _outputs: Dictionary = {}


func before_each() -> void:
	_sessions.clear()
	_outputs.clear()
	_clear_dir(TEST_DIR)


func after_each() -> void:
	for session: GameSession in _sessions:
		session.free()
	_sessions.clear()
	_clear_dir(TEST_DIR)


func test_new_game_roundtrip_is_identical() -> void:
	var original: GameSession = _new_session(SEED)
	var text: String = SaveCodec.encode(original.to_save(NOW_MS))
	var copy: GameSession = _load_copy(text)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), text)


func test_mid_cycle_roundtrip_is_identical() -> void:
	var original: GameSession = _played_session()
	assert_eq(int(original.actions.get_lane()["elapsed_ms"]), MID_CYCLE_ELAPSED_MS)
	var text: String = SaveCodec.encode(original.to_save(NOW_MS))
	var copy: GameSession = _load_copy(text)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), text, "byte for byte")
	assert_eq(int(copy.actions.get_lane()["elapsed_ms"]), MID_CYCLE_ELAPSED_MS, "elapsed_ms kept")
	assert_eq(copy.actions.get_lane()["action"], ACTION)
	assert_eq(copy.rng.to_save(), original.rng.to_save(), "rng seed and state kept")
	assert_ne(int(copy.rng.to_save()["seed"]), OTHER_SEED, "the seed comes from the save")


func test_derived_state_matches_after_load() -> void:
	var original: GameSession = _played_session()
	var copy: GameSession = _load_copy(SaveCodec.encode(original.to_save(NOW_MS)))
	assert_eq(copy.skills.get_level(SKILL), original.skills.get_level(SKILL))
	assert_eq(copy.mastery.get_mastery_level(ACTION), original.mastery.get_mastery_level(ACTION))
	assert_eq(copy.mastery.get_pool(SKILL), original.mastery.get_pool(SKILL))
	assert_eq(copy.bank.stacks(), original.bank.stacks())
	assert_eq(copy.bank.capacity(), original.bank.capacity())
	assert_eq(copy.total_level(), original.total_level())
	assert_eq(copy.actions.get_progress(), original.actions.get_progress(), "F-04 half way")
	for stat: StringName in copy.data.stats.ids():
		var ctx: ModifierContext = ModifierContext.for_action(SKILL, ACTION)
		assert_eq(copy.modifiers.total(stat, ctx), original.modifiers.total(stat, ctx), "%s rebuilt" % stat)


func test_both_copies_continue_with_the_same_sequences() -> void:
	var original: GameSession = _played_session()
	var copy: GameSession = _load_copy(SaveCodec.encode(original.to_save(NOW_MS)))
	_boost(original)
	_boost(copy)
	_record(original)
	_record(copy)
	_advance_in_ticks(original, AFTER_LOAD_MS)
	_advance_in_ticks(copy, AFTER_LOAD_MS)
	var seq_a: Array = _outputs[original.get_instance_id()]
	var seq_b: Array = _outputs[copy.get_instance_id()]
	assert_eq(seq_a.size(), AFTER_LOAD_CYCLES, "200 cycles after the load")
	assert_eq(seq_b, seq_a, "same outputs, cycle by cycle (doubles and shards from the same rng)")
	assert_gt(_count_shards(seq_a), 0, "the boosted run rolls shards")
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), SaveCodec.encode(original.to_save(NOW_MS)))
	var rolls_a: Array[float] = []
	var rolls_b: Array[float] = []
	for i: int in 10:
		rolls_a.append(original.rng.randf())
		rolls_b.append(copy.rng.randf())
	assert_eq(rolls_b, rolls_a, "the generators are still in step")


func test_copy_without_the_rng_block_would_diverge() -> void:
	# Guard: the sequence check above is meaningful only if a different generator gives different outputs.
	var original: GameSession = _played_session()
	var d: Dictionary = SaveCodec.decode(SaveCodec.encode(original.to_save(NOW_MS)))
	d["rng"] = {"seed": OTHER_SEED, "state": OTHER_SEED}
	var other: GameSession = _new_session(OTHER_SEED)
	assert_true(other.from_save(d).ok)
	_boost(original)
	_boost(other)
	_record(original)
	_record(other)
	_advance_in_ticks(original, AFTER_LOAD_MS)
	_advance_in_ticks(other, AFTER_LOAD_MS)
	assert_ne(_outputs[other.get_instance_id()], _outputs[original.get_instance_id()])


func test_roundtrip_through_the_slot_file() -> void:
	var original: GameSession = _played_session()
	original.slot = TEST_SLOT
	var saved: Dictionary = original.to_save(NOW_MS)
	assert_true(SaveService.write_slot(TEST_SLOT, saved).ok)
	assert_true(SaveService.slot_path(TEST_SLOT).begins_with(TEST_DIR), "never a real slot")
	var read: Dictionary = SaveService.read_slot(TEST_SLOT)
	assert_false(read.is_empty(), "readable: %s" % SaveService.last_error)
	var copy: GameSession = _new_session(OTHER_SEED)
	assert_true(copy.from_save(read).ok)
	assert_eq(SaveCodec.encode(copy.to_save(NOW_MS)), SaveCodec.encode(saved))
	var info: SlotInfo = SaveService.read_slot_info(TEST_SLOT)
	assert_eq(info.state, &"ok")
	assert_eq(info.play_time_ms, MID_CYCLE_RUN_MS)
	assert_eq(info.total_level, original.total_level())


func test_second_roundtrip_is_stable() -> void:
	var original: GameSession = _played_session()
	var first: String = SaveCodec.encode(original.to_save(NOW_MS))
	var copy: GameSession = _load_copy(first)
	var again: GameSession = _load_copy(SaveCodec.encode(copy.to_save(NOW_MS)))
	assert_eq(SaveCodec.encode(again.to_save(NOW_MS)), first)


# A session with 61.5 s of cut_redbirch: 20 cycles done (rng advanced by 20 shard rolls), cycle 21 half done.
func _played_session() -> GameSession:
	var session: GameSession = _new_session(SEED)
	assert_true(session.actions.start(SKILL, ACTION).ok)
	_advance_in_ticks(session, MID_CYCLE_RUN_MS)
	return session


func _load_copy(text: String) -> GameSession:
	var copy: GameSession = _new_session(OTHER_SEED)
	var result: CommandResult = copy.from_save(SaveCodec.decode(text))
	assert_true(result.ok, "from_save: %s" % result.reason)
	return copy


func _new_session(seed_value: int) -> GameSession:
	var session: GameSession = TestFactory.session(seed_value, TestFactory.real_data())
	_sessions.append(session)
	return session


# A test-only modifier source (not saved: modifiers are derived state), added after the load in both copies.
func _boost(session: GameSession) -> void:
	var mods: Array[Modifier] = [
		Modifier.make(&"rift_shard_chance", SHARD_CHANCE),
		Modifier.make(&"double_item_chance", DOUBLE_CHANCE),
	]
	session.modifiers.set_source(SHARD_SOURCE, mods)


func _record(session: GameSession) -> void:
	var id: int = session.get_instance_id()
	_outputs[id] = []
	session.events.action_completed.connect(
			func(_lane: StringName, _skill: StringName, _action: StringName, outputs: Dictionary) -> void:
				(_outputs[id] as Array).append(outputs.duplicate()))


func _count_shards(sequence: Array) -> int:
	var total: int = 0
	for outputs: Dictionary in sequence:
		total += int(outputs.get(SHARD, 0))
	return total


func _advance_in_ticks(session: GameSession, ms: int) -> void:
	@warning_ignore("integer_division")
	var ticks: int = ms / TICK_MS
	for i: int in ticks:
		session.advance(TICK_MS)


func _clear_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
