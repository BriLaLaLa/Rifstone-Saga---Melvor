extends GutTest
## Integration, the node loop (M24-04; replaces the gathering loop of M3): a hero fights in `redrock_plains`, between the fights a journey
## leads to a node of a learned discipline that gives units, xp and mastery; the items are conserved; a session saved in the middle
## continues identical; the offline run counts the nodes. Real data, fixed seed, only public APIs (05_INTERFACES_M24.md §5.33, §6b).

const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const FORESTRY: StringName = &"forestry"
const LOG_ITEM: StringName = &"redbirch_log"
const BETULLA: StringName = &"cut_redbirch"
const SEED: int = 2024
const NOW_MS: int = 1793603600000
const HOUR_MS: int = 3600000

var _produced: Dictionary[StringName, int] = {}
var _units_signalled: int = 0


func _on_completed(lane: StringName, _skill: StringName, _action: StringName, outputs: Dictionary) -> void:
	if lane == ActionRunner.NODE:
		for item: StringName in outputs:
			_produced[item] = _produced.get(item, 0) + int(outputs[item])


func _on_finished(_skill: StringName, _action: StringName, units: int, _reason: StringName) -> void:
	_units_signalled += units


func _session() -> GameSession:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	var entry := NodeEntryDef.new()
	entry.skill = FORESTRY
	entry.weight = 1
	data.area_nodes(AREA).entries = [entry]  # every node is forestry: the loop is easy to follow
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, data))
	s.disciplines._grades.clear()
	TestFactory.learn_discipline(s, FORESTRY)
	TestFactory.set_character_level(s, 65)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	_boost(s)
	TestFactory.make_roomy(s)
	return s


func _boost(s: GameSession) -> void:
	s.modifiers.set_source(&"test:hero", [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])


func _run(s: GameSession, ms: int) -> void:
	for i: int in ms / 1000:
		s.advance(1000)


func test_nodes_give_units_xp_and_mastery_and_the_items_are_conserved() -> void:
	var s: GameSession = _session()
	s.events.action_completed.connect(_on_completed)
	s.events.node_finished.connect(_on_finished)
	assert_true(s.combat.start(AREA).ok)
	_run(s, 20 * 60 * 1000)
	var worked: int = s.combat.node_counts()["worked"]
	assert_gt(worked, 5, "in 20 minutes the cycle worked several nodes")
	assert_eq(s.combat.node_counts()["skipped"], 0, "forestry is learned and the only entry")
	var total: int = 0
	for item: StringName in _produced:
		assert_eq(s.bank.get_count(item), _produced[item], "what the signals announced is what the Deposit holds: %s" % item)
		total += _produced[item] if item != &"rift_shard" else 0
	assert_gte(total, _units_signalled, "the units are at least the logs announced (the double adds)")
	assert_gte(_units_signalled, worked * 80, "80 units a node")
	assert_gt(_produced.size(), 1, "the resource follows the level: more than one log")
	assert_gt(s.skills.get_xp(FORESTRY), 0)
	assert_gt(s.mastery.get_mastery_xp(BETULLA), 0)
	assert_gt(s.combat.total_kills().size(), 0, "the fights go on between the nodes")


func test_a_saved_session_in_the_middle_continues_identical() -> void:
	var a: GameSession = _session()
	a.combat.start(AREA)
	_run(a, 7 * 60 * 1000 + 3000)  # inside some state of the cycle
	var b: GameSession = _session()
	assert_true(b.from_save(SaveCodec.decode(SaveCodec.encode(a.to_save(NOW_MS))) as Dictionary).ok)
	_boost(b)  # the load rebuilds every modifier source: the boost of the test goes back, then the engine is read again (hp)
	b.combat.from_save(a.combat.to_save())
	assert_eq(b.combat.state(), a.combat.state())
	assert_eq(b.combat.to_save(), a.combat.to_save())
	_run(a, 10 * 60 * 1000)
	_run(b, 10 * 60 * 1000)
	assert_eq(b.combat.to_save(), a.combat.to_save())
	assert_eq(b.bank.get_count(LOG_ITEM), a.bank.get_count(LOG_ITEM))
	assert_eq(b.skills.get_xp(FORESTRY), a.skills.get_xp(FORESTRY))


func test_the_offline_run_works_nodes_and_the_summary_counts_them() -> void:
	var s: GameSession = _session()
	assert_true(s.combat.start(AREA).ok)
	var before: Dictionary = s.combat.node_counts()
	var summary: OfflineSummary = await OfflineSimulator.new().run(s, 2 * HOUR_MS, false, false)
	var after: Dictionary = s.combat.node_counts()
	assert_gt(summary.nodes_worked, 10)
	assert_eq(summary.nodes_worked, int(after["worked"]) - int(before["worked"]))
	assert_eq(summary.nodes_skipped, 0)
	var logs: int = 0
	for item: StringName in summary.items:
		logs += maxi(0, int(summary.items[item]))
	assert_gte(logs, summary.nodes_worked * 80, "at least 80 units a node (the fights add loot)")
	assert_gt(int(summary.xp.get(FORESTRY, 0)), 0)
	assert_false(summary.is_empty())
