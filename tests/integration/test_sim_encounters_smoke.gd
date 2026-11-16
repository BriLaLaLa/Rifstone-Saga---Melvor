extends GutTest
## M24-07, smoke of `tools/sim_encounters.gd` (docs/02_FORMULAS_M24.md F-156): a short run on the real data and the real engine ends,
## fills every measure and the closed form, the reference run (`nodes=0`) works no node, and the arguments are parsed. The thresholds
## themselves are checked by the tool (`godot --headless --path . -s tools/sim_encounters.gd`), not here: this test only has to be stable.

const SIM: String = "res://tools/sim_encounters.gd"


func _data() -> GameData:
	# The reference run edits the balance of its own data: never the shared one of the factory.
	return GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)


func _opts(extra: Dictionary = {}) -> Dictionary:
	var opts: Dictionary = (load(SIM) as GDScript).call("parse_args", PackedStringArray(["hours=0.5"]))
	opts.merge(extra, true)
	return opts


func test_the_arguments_are_parsed() -> void:
	var sim: GDScript = load(SIM) as GDScript
	var opts: Dictionary = sim.call("parse_args", PackedStringArray(["hours=3", "area=ash_marsh", "learned=forestry,angling", "nodes=0"]))
	assert_false(opts.has("error"))
	assert_eq(opts["area"], "ash_marsh")
	assert_eq(opts["hours"], "3")
	assert_eq(opts["nodes"], "0")
	assert_eq(opts["seed"], "1234", "the defaults stay")
	assert_true((sim.call("parse_args", PackedStringArray(["nonsense=1"])) as Dictionary).has("error"))
	assert_true((sim.call("parse_args", PackedStringArray(["hours"])) as Dictionary).has("error"))


func test_a_short_run_fills_the_measures_and_the_closed_form() -> void:
	var sim: GDScript = load(SIM) as GDScript
	var row: Dictionary = sim.call("measure", _data(), _opts(), true)
	assert_gt(float(row["fights_per_hour"]), 10.0)
	assert_gt(float(row["kills_per_hour"]), 10.0)
	assert_gt(float(row["fight_ms"]), 1000.0)
	assert_gt(float(row["worked_per_hour"]) + float(row["skipped_per_hour"]), 0.0, "the nodes of the cycle happen")
	assert_eq((row["learned"] as Array).size(), 2, "auto learns the two gathering disciplines with the highest weight")
	for skill: StringName in row["learned"]:
		assert_true((row["skills"] as Dictionary).has(skill))
	var expected: Dictionary = row["expected"]
	assert_gt(float(expected["per_hour"]), 0.0)
	assert_lt(absf(float(row["per_hour"]) / float(expected["per_hour"]) - 1.0), 0.25, "the closed form is near after half an hour")


func test_the_reference_run_has_no_nodes_and_the_report_has_no_failure_without_them() -> void:
	var sim: GDScript = load(SIM) as GDScript
	var opts: Dictionary = _opts({"nodes": "0"})
	var row: Dictionary = sim.call("measure", _data(), opts, false)
	assert_eq(float(row["worked_per_hour"]), 0.0)
	assert_eq(float(row["skipped_per_hour"]), 0.0)
	assert_gt(float(row["fights_per_hour"]), 10.0)
	var lines: PackedStringArray = PackedStringArray()
	assert_true((sim.call("report", opts, lines) as PackedStringArray).is_empty(), "nothing to check without the cycle")
	assert_gt(lines.size(), 2)
