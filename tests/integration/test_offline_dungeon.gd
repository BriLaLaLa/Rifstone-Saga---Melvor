extends GutTest
## F-144 rule 2 (docs/02_FORMULAS.md §5j, docs/01_GDD.md §33.6): offline, a dungeon run is frozen. The simulator does not
## advance the combat nor the run (no progress, no death, no automatic choice), the rest goes on, and the summary says that the
## run was waiting. Without a run the same hour of fighting does progress (the control).

const AREA: StringName = &"test_area"
const HOUR_MS: int = 3_600_000

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(FractureUtil.session(61))
	FractureUtil.hero(_s)


func _hour(session: GameSession) -> OfflineSummary:
	return await OfflineSimulator.new().run(session, HOUR_MS, false, false)


func test_without_a_run_an_hour_of_combat_progresses() -> void:
	_s.combat.start(AREA)
	var summary: OfflineSummary = await _hour(_s)
	assert_gt(summary.kills.size(), 0, "the control: the monsters die")
	assert_false(summary.dungeon_frozen)


func test_a_dungeon_run_does_not_advance_offline() -> void:
	var engine: DungeonEngineDouble = DungeonEngineDouble.attach(_s, 3, false)
	_s.combat.start(AREA)
	engine.open_and_clear_entrance()
	var run: DungeonRun = _s.dungeon.run()
	var before: Array = [run.layer, run.index, run.phase, run.cleared, run.stage, run.paused, run.bag.counts()]
	var kills: Dictionary = _s.combat.total_kills().duplicate()
	var deaths: int = _s.combat.deaths()
	var summary: OfflineSummary = await _hour(_s)
	assert_true(summary.dungeon_frozen)
	assert_false(summary.is_empty(), "the screen has something to say")
	assert_eq(_s.combat.total_kills(), kills, "the combat did not move")
	assert_eq(_s.combat.deaths(), deaths)
	assert_eq([run.layer, run.index, run.phase, run.cleared, run.stage, run.paused, run.bag.counts()], before)
	assert_true(_s.dungeon.is_active())
	assert_eq(engine.rooms.size(), 1, "no room begun, no automatic choice")


func test_a_run_loaded_from_a_save_is_frozen_too() -> void:
	var engine: DungeonEngineDouble = DungeonEngineDouble.attach(_s, 3, false)
	engine.open_and_clear_entrance()
	var twin: GameSession = autofree(FractureUtil.session(62))
	FractureUtil.hero(twin)
	twin.dungeon.from_save(_s.dungeon.to_save())
	twin.combat.start(AREA)
	var kills: Dictionary = twin.combat.total_kills().duplicate()
	var summary: OfflineSummary = await _hour(twin)
	assert_true(summary.dungeon_frozen)
	assert_eq(twin.combat.total_kills(), kills)
	assert_true(twin.dungeon.run().paused)


func test_the_silent_path_below_the_minimum_freezes_it_too() -> void:
	var engine: DungeonEngineDouble = DungeonEngineDouble.attach(_s, 3, false)
	_s.combat.start(AREA)
	engine.open_and_clear_entrance()
	var kills: Dictionary = _s.combat.total_kills().duplicate()
	OfflineSimulator.advance_silently(_s, 30_000)
	assert_eq(_s.combat.total_kills(), kills)
