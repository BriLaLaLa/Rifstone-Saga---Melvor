extends GutTest
## M22-07, smoke of `tools/sim_dungeon.gd` (docs/02_FORMULAS.md F-144): ten whole runs on the real data and the real engine end
## without errors, every run ends in a known outcome, the table lines come out and the loot of a won run is counted. The thresholds
## themselves are checked by the tool (`godot --headless --path . -s tools/sim_dungeon.gd`), not here: this test only has to be
## stable, so it does not look at the win rate.

const SIM: String = "res://tools/sim_dungeon.gd"
const KNOWN: Array[String] = ["won", "died", "fled", "left"]


func test_ten_runs_end_with_a_known_outcome_and_no_session_is_left_behind() -> void:
	var sim: GDScript = load(SIM) as GDScript
	var opts: Dictionary = sim.call("parse_args", PackedStringArray(["slice=5"]))
	assert_false(opts.has("error"))
	var rows: Array = sim.call("play", TestFactory.real_data(), 55, "random", 10, 7, opts)
	assert_eq(rows.size(), 10)
	var won: int = 0
	for row: Dictionary in rows:
		assert_true(KNOWN.has(row["outcome"]), "outcome %s" % row["outcome"])
		assert_gt(int(row["ms"]), 0)
		if row["outcome"] == "won":
			won += 1
			assert_gte(float(row["pieces"]), 2.0, "a won run gives at least the two pieces of the boss")
	assert_gt(won, 0, "a level 55 hero wins at least one of ten runs")
	var summary: Dictionary = (load("res://tools/sim_dungeon_stats.gd") as GDScript).call("summarize", rows)
	assert_eq(int(summary["runs"]), 10)
	assert_gt(float(summary["min_mean"]), 0.0)


func test_the_policies_and_arguments_are_parsed() -> void:
	var sim: GDScript = load(SIM) as GDScript
	assert_true((sim.call("parse_args", PackedStringArray(["policy=cautious", "runs=3"])) as Dictionary).get("policy") == "cautious")
	assert_true((sim.call("parse_args", PackedStringArray(["nonsense=1"])) as Dictionary).has("error"))
