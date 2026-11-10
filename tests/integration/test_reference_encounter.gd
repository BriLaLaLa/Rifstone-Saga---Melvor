extends GutTest
## Integration, F-34 reference encounter (docs/02_FORMULAS.md): level 1, bare hands, no traits, one pack with a single
## plains_boar, 0.5 hit chance for both sides -> over 1,000 simulated encounters (fixed seed, no wait between them)
## the mean time per kill is between 15 and 21 s (design simulation: 18.0 s).
##
## Real data, only public APIs. The "no wait" config is a copy of the real config with `combat.respawn_ms` = 0 written
## under PreRun.test_dir() (not a save slot) and removed afterwards. The player gets a huge `max_hp_flat` so that
## dying never interrupts the sample (it changes nothing in the offence); the character level is pinned at 1 because
## the kills would otherwise level it up and change the player.

const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const CONTENT_ROOT: String = "res://data"
const CONFIG_ROOT: String = "res://data/config"
const AREA: StringName = &"redrock_plains"
const BOAR: StringName = &"plains_boar"
const KILLS: int = 1000
const STEP_MS: int = 500
const MIN_MEAN_S: float = 15.0
const MAX_MEAN_S: float = 21.0
const SEED: int = 34
const OTHER_SEEDS: Array[int] = [1, 2, 3]

var _tmp_config: String = PreRun.test_dir("test_reference_encounter")
var _data: GameData = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["combat"] as Dictionary)["respawn_ms"] = 0
	(balance["rift_stone"] as Dictionary)["pity_kills"] = 1000000  # M15: a Rift Stone (450 hp, waves) is not the F-34 setup
	_write("balance.json", JSON.stringify(balance))
	_write("stats.json", FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_data = GameData.load_from_dirs(CONTENT_ROOT, _tmp_config)
	assert_true(_data.is_valid(), "data valid: %s" % ", ".join(_data.errors))
	# The test area: only the first pack, a single plains_boar (the area belongs to this private GameData).
	var area: AreaDef = _data.area(AREA)
	area.packs = area.packs.slice(0, 1)
	area.rift_stone_chance_pct = 0.0


func after_all() -> void:
	if not DirAccess.dir_exists_absolute(_tmp_config):
		return
	for file_name: String in DirAccess.get_files_at(_tmp_config):
		DirAccess.remove_absolute(_tmp_config.path_join(file_name))
	DirAccess.remove_absolute(_tmp_config)


func test_the_reference_setup_is_the_one_of_f34() -> void:
	var session: GameSession = TestFactory.session_no_kit(SEED, _data)
	assert_eq(int(_data.balance_value("combat.respawn_ms")), 0)
	assert_eq(_data.area(AREA).packs.size(), 1)
	assert_eq(_data.area(AREA).packs[0].monster_ids, [BOAR] as Array[StringName])
	assert_true(session.combat.start(AREA).ok)
	var player: CombatantStats = session.combat.player_stats()
	assert_eq([player.accuracy, player.max_hit, player.attack_interval_ms, player.max_hp], [450, 11, 2400, 60])
	var boar: CombatantStats = session.combat.enemy_stats(0)
	assert_eq([boar.max_hit, boar.attack_interval_ms, boar.max_hp], [11, 2800, 20])
	assert_almost_eq(CombatMath.hit_chance(player.accuracy, boar.evasion, _data), 0.5, 0.0001)
	assert_almost_eq(CombatMath.hit_chance(boar.accuracy, player.evasion, _data), 0.5, 0.0001)
	session.free()


func test_mean_time_per_kill_is_between_15_and_21_seconds() -> void:
	var mean_s: float = _mean_seconds_per_kill(SEED)
	gut.p("F-34 mean time per kill: %.2f s (seed %d)" % [mean_s, SEED])
	assert_between(mean_s, MIN_MEAN_S, MAX_MEAN_S, "mean seconds per kill")


func test_other_seeds_stay_in_the_band() -> void:
	for seed_value: int in OTHER_SEEDS:
		var mean_s: float = _mean_seconds_per_kill(seed_value)
		assert_between(mean_s, MIN_MEAN_S, MAX_MEAN_S, "seed %d: %.2f s" % [seed_value, mean_s])


func test_same_seed_gives_the_same_mean() -> void:
	assert_eq(_mean_seconds_per_kill(SEED), _mean_seconds_per_kill(SEED))


# Fights until KILLS boars are dead; returns elapsed seconds / kills.
func _mean_seconds_per_kill(seed_value: int) -> float:
	var session: GameSession = TestFactory.session_no_kit(seed_value, _data)
	session.modifiers.set_source(&"test:immortal", [Modifier.make(&"max_hp_flat", 100000.0)])
	var pinned_xp: int = session.character.get_xp()
	assert_true(session.combat.start(AREA).ok)
	var elapsed: int = 0
	var guard: int = 0
	while int(session.combat.total_kills().get(BOAR, 0)) < KILLS and guard < 400000:
		session.advance(STEP_MS)
		elapsed += STEP_MS
		guard += 1
		if session.character.get_xp() != pinned_xp:
			session.character.from_save({"class": String(session.character.class_id()), "xp": pinned_xp})
			session.events.modifiers_changed.emit()
	var kills: int = int(session.combat.total_kills().get(BOAR, 0))
	assert_eq(kills, KILLS, "the sample was completed")
	assert_eq(session.combat.deaths(), 0, "the player never dies in the sample")
	session.free()
	return float(elapsed) / 1000.0 / float(maxi(kills, 1))


func _write(file_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(_tmp_config.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()
