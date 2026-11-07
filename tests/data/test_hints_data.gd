extends GutTest
## Real hints data (04_DATA_SCHEMA §10): every trigger covered, unique ids, non-empty texts.

const TRIGGERS: Array[String] = ["session_started_new", "bank_full", "first_shard", "mastery_node_affordable",
	"player_died", "first_level_10"]

var _hints: Array = []


func before_all() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hints/hints.json")) as Dictionary
	_hints = raw["hints"]


func test_every_trigger_has_a_hint() -> void:
	var seen: Dictionary = {}
	for h: Dictionary in _hints:
		seen[h["trigger"]] = true
	for t: String in TRIGGERS:
		assert_true(seen.has(t), "trigger %s covered" % t)


func test_ids_are_unique_and_texts_filled() -> void:
	var ids: Dictionary = {}
	for h: Dictionary in _hints:
		assert_false(ids.has(h["id"]), "duplicate id %s" % h["id"])
		ids[h["id"]] = true
		assert_false((h["title"] as String).is_empty(), "title of %s" % h["id"])
		assert_false((h["text"] as String).is_empty(), "text of %s" % h["id"])
		assert_true(TRIGGERS.has(h["trigger"]), "known trigger of %s" % h["id"])


func test_hints_pass_the_validator() -> void:
	var data: GameData = GameData.load_from_dirs("res://data", "res://data/config")
	assert_eq(data.errors, PackedStringArray())
