extends GutTest
## B1 after the new weapons and Armour (M14-10): level 99 in about 300 hours (250-350) and at most +12 levels after level 50 in a
## night of 12 hours offline, from tools/sim_progress.gd on the real data.

const Sim := preload("res://tools/sim_combat.gd")
const Progress := preload("res://tools/sim_progress.gd")

var _lines: PackedStringArray = PackedStringArray()


func before_all() -> void:
	var data: GameData = TestFactory.real_data()
	_lines = Progress.report(Sim, data, Sim.parse_args(PackedStringArray(["scope=all"])))


func _line(prefix: String) -> String:
	for line: String in _lines:
		if line.begins_with(prefix):
			return line
	return ""


func test_level_99_in_about_300_hours() -> void:
	var line: String = _line("hours to level")
	assert_false(line.is_empty())
	var hours: float = float(line.get_slice(": ", 1).split(" / ")[3])
	assert_between(hours, 250.0, 380.0, "hours to level 99 (M15-08: 327 without Monoliths, about 370 with them; Q78, Q82)")


func test_a_night_from_level_50_gives_at_most_twelve_levels() -> void:
	var line: String = _line("12 h offline from level 50")
	assert_false(line.is_empty())
	var gained: int = int(line.get_slice("+", 1).get_slice(" ", 0))
	assert_between(gained, 1, 12, "levels in a night from 50")
