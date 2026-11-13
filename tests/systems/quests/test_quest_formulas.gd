extends GutTest
## F-134 (docs/02_FORMULAS.md §5i): the examples with their numbers, the regeneration of data/quests/quests.json and the
## validator rules. Real data.

const QUESTS_PATH: String = "res://data/quests/quests.json"

var _gen: GDScript
var _params: Dictionary
var _items: Dictionary[String, Dictionary] = {}
var _actions: Dictionary[String, Dictionary] = {}
var _lookup: Dictionary


func before_all() -> void:
	_gen = load("res://tools/gen_quests.gd") as GDScript
	_params = (JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json")) as Dictionary)["quest"]
	var items: Dictionary = _gen.call("read_dir", "res://data/items") as Dictionary
	for path: String in items:
		_items[path] = items[path] as Dictionary
	var actions: Dictionary = _gen.call("read_dir", "res://data/actions") as Dictionary
	for path: String in actions:
		_actions[path] = actions[path] as Dictionary
	_lookup = DataValidatorQuests.lookup_from(_items, _actions)


func _quest(type: String, skill: String, tier: int) -> Dictionary:
	return DataValidatorQuests.quest_for(type, skill, tier, _params, _lookup)


func _written() -> Array:
	return (JSON.parse_string(FileAccess.get_file_as_string(QUESTS_PATH)) as Dictionary)["quests"] as Array


func test_kill_examples() -> void:
	var first: Dictionary = _quest("kill", "", 1)
	assert_eq(first["id"], "kill_any_t1")
	assert_eq(first["target"], 40)
	assert_eq(first["reward"]["gold"], 80)
	assert_eq(first["reward"]["items"], [{"item": "seared_brookfin", "qty": 20}])
	assert_eq(first["requires"]["character"], 1)
	var last: Dictionary = _quest("kill", "", 8)
	assert_eq(last["target"], 96)
	assert_eq(last["reward"]["gold"], 1030)
	assert_eq(last["reward"]["items"], [{"item": "seared_riftmaw", "qty": 20}])
	assert_eq(last["requires"]["character"], 90)
	assert_false((last["reward"] as Dictionary).has("xp"))


func test_gather_examples() -> void:
	var wood: Dictionary = _quest("gather", "forestry", 5)
	assert_eq(wood["item"], "shardcedar_log")
	assert_eq(wood["target"], 210)
	assert_eq(wood["reward"]["gold"], 480)
	assert_eq(wood["reward"]["xp"], {"skill": "forestry", "amount": 2320})
	assert_eq(wood["requires"], {"character": 45, "skills": {"forestry": 45}})
	var fish: Dictionary = _quest("gather", "angling", 1)
	assert_eq(fish["item"], "brookfin")
	assert_eq(fish["target"], 150)
	assert_eq(fish["reward"]["gold"], 60, "64 rounds to 60")
	assert_eq(fish["reward"]["xp"]["amount"], 400)


func test_craft_examples() -> void:
	var meal: Dictionary = _quest("craft", "hearthcraft", 3)
	assert_eq(meal["item"], "seared_redscale")
	assert_eq(meal["target"], 114)
	assert_eq(meal["reward"]["gold"], 340)
	assert_eq(meal["reward"]["xp"], {"skill": "hearthcraft", "amount": 1680})
	assert_eq(meal["requires"], {"character": 20, "skills": {"hearthcraft": 20}})
	var grip: Dictionary = _quest("craft", "woodwright", 8)
	assert_eq(grip["item"], "riftspruce_grip")
	assert_eq(grip["target"], 232)
	assert_eq(grip["reward"]["gold"], 1030)
	assert_eq(grip["reward"]["xp"]["amount"], 8700)
	assert_eq(grip["requires"], {"character": 90, "skills": {"woodwright": 90}})
	assert_eq(_quest("craft", "forging", 8)["target"], 58)


func test_file_has_56_quests_and_equals_the_regeneration() -> void:
	var all: Dictionary = DataValidatorQuests.all_for(_params, _lookup)
	assert_eq((all["errors"] as PackedStringArray).size(), 0)
	assert_eq((all["quests"] as Array).size(), 56)
	var written: Array = _written()
	assert_eq(written.size(), 56)
	for index: int in written.size():
		assert_eq(DataValidatorQuests._first_diff(written[index], (all["quests"] as Array)[index], ""), "", "quest #%d" % index)
	var generated: Dictionary = _gen.call("generate", _params, _gen.call("read_dir", "res://data/items"),
			_gen.call("read_dir", "res://data/actions")) as Dictionary
	assert_eq(generated["text"], FileAccess.get_file_as_string(QUESTS_PATH))


func _validate(written: Array) -> PackedStringArray:
	var v := DataValidatorRules.new()
	var files: Dictionary[String, Dictionary] = {"quests.json": {"quests": written}}
	var balance: Dictionary[String, Dictionary] = {"balance.json": {"quest": _params}}
	DataValidatorQuests.validate(v, files, balance, _items, _actions)
	return v.errors


func test_validator_accepts_the_file_and_an_empty_list() -> void:
	assert_eq(_validate(_written()).size(), 0)
	assert_eq(_validate([]).size(), 0)


func test_validator_rejects_a_hand_edited_value() -> void:
	var written: Array = _written()
	(written[3] as Dictionary)["target"] = 999
	var errors: PackedStringArray = _validate(written)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "target")


func test_validator_rejects_a_wrong_order_and_a_missing_quest() -> void:
	var written: Array = _written()
	var swapped: Variant = written[0]
	written[0] = written[1]
	written[1] = swapped
	assert_true(_validate(written).size() >= 2)
	written = _written()
	written.pop_back()
	assert_true(_validate(written).size() >= 1)
