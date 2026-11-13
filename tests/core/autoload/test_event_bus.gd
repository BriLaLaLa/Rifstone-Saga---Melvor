extends GutTest
## EventBus (GameEvents): exactly the signals of docs/05_INTERFACES.md §3 (without M6/M7), with typed parameters.

const SN := TYPE_STRING_NAME
const I := TYPE_INT
const B := TYPE_BOOL

## Signal name -> list of [parameter name, Variant type, class name ("" if not an object)].
const EXPECTED: Dictionary = {
	"session_started": [["slot", I, ""], ["is_new", B, ""]],
	"session_ended": [["slot", I, ""]],
	"action_started": [["lane", SN, ""], ["skill_id", SN, ""], ["action_id", SN, ""]],
	"action_completed": [
		["lane", SN, ""], ["skill_id", SN, ""], ["action_id", SN, ""], ["outputs", TYPE_DICTIONARY, ""],
	],
	"action_stopped": [["lane", SN, ""], ["skill_id", SN, ""], ["reason", SN, ""]],
	"blueprint_crafted": [["blueprint_id", SN, ""], ["uid", I, ""]],
	"xp_gained": [["skill_id", SN, ""], ["amount", I, ""]],
	"level_up": [["skill_id", SN, ""], ["new_level", I, ""]],
	"mastery_xp_gained": [["skill_id", SN, ""], ["action_id", SN, ""], ["amount", I, ""]],
	"mastery_level_up": [["skill_id", SN, ""], ["action_id", SN, ""], ["new_level", I, ""]],
	"mastery_pool_changed": [["skill_id", SN, ""], ["pool_xp", I, ""]],
	"mastery_node_purchased": [["skill_id", SN, ""], ["node_id", SN, ""]],
	"mastery_milestone_reached": [["skill_id", SN, ""], ["action_id", SN, ""], ["at", I, ""]],
	"character_xp_gained": [["amount", I, ""]],
	"character_level_up": [["new_level", I, ""]],
	"player_renamed": [["new_name", TYPE_STRING, ""]],
	"traits_changed": [],
	"bank_changed": [["item_id", SN, ""], ["new_count", I, ""], ["delta", I, ""]],
	"bank_rejected": [["item_id", SN, ""], ["qty", I, ""]],
	"gold_changed": [["new_amount", I, ""], ["delta", I, ""]],
	"equipment_changed": [["slot_id", SN, ""], ["uid", I, ""]],
	"food_changed": [["item_id", SN, ""]],
	"armory_changed": [["uid", I, ""], ["change", SN, ""]],
	"deposit_changed": [["used", I, ""], ["capacity", I, ""]],
	"bags_changed": [],
	"helper_changed": [["skill_id", SN, ""], ["grade", SN, ""], ["action_id", SN, ""]],
	"helper_completed": [["skill_id", SN, ""], ["action_id", SN, ""], ["outputs", TYPE_DICTIONARY, ""]],
	"helper_blocked": [["skill_id", SN, ""], ["blocked", B, ""]],
	"armory_rejected": [["base_id", SN, ""], ["qty", I, ""]],
	"item_obtained": [["item_id", SN, ""], ["qty", I, ""]],
	"item_discovered": [["item_id", SN, ""]],
	"item_upgraded": [["uid", I, ""], ["success", B, ""], ["new_level", I, ""]],
	"item_salvaged": [["uid", I, ""], ["base_id", SN, ""], ["auto", B, ""]],
	"modifiers_changed": [],
	"combat_started": [["area_id", SN, ""]],
	"combat_stopped": [["reason", SN, ""]],
	"encounter_started": [["monster_ids", TYPE_ARRAY, ""]],
	"encounter_cleared": [],
	"rift_stone_appeared": [["stone_id", SN, ""]],
	"rift_stone_wave": [["stone_id", SN, ""], ["threshold", I, ""], ["count", I, ""]],
	"rift_stone_skipped": [["stone_id", SN, ""]],
	"skip_stone_changed": [["level", I, ""]],
	"combat_hit": [["attacker", I, ""], ["target", I, ""], ["hit", B, ""], ["damage", I, ""], ["blocked", B, ""]],
	"player_hp_changed": [["hp", I, ""], ["max_hp", I, ""]],
	"monster_hp_changed": [["index", I, ""], ["hp", I, ""], ["max_hp", I, ""]],
	"monster_killed": [["index", I, ""], ["monster_id", SN, ""]],
	"player_died": [],
	"food_eaten": [["item_id", SN, ""], ["healed", I, ""]],
	"loot_bag_changed": [["used", I, ""], ["capacity", I, ""]],
	"loot_lost": [["item_id", SN, ""], ["qty", I, ""]],
	"trait_triggered": [["trait_id", SN, ""]],
	"ability_used": [["ability_id", SN, ""], ["targets", TYPE_ARRAY, ""]],
	"shop_purchased": [["entry_id", SN, ""], ["count", I, ""]],
	"item_sold": [["item_id", SN, ""], ["qty", I, ""], ["gold", I, ""]],
	"village_upgraded": [["building_id", SN, ""], ["new_level", I, ""]],
	"infusion_socketed": [["socket_index", I, ""], ["item_id", SN, ""]],
	"infusion_removed": [["socket_index", I, ""], ["item_id", SN, ""]],
	"offline_started": [["elapsed_ms", I, ""], ["capped", B, ""]],
	"offline_progress": [["done_ms", I, ""], ["total_ms", I, ""]],
	"offline_completed": [["summary", TYPE_OBJECT, "OfflineSummary"]],
	"save_completed": [["slot", I, ""]],
	"save_failed": [["slot", I, ""], ["reason", SN, ""]],
	"notification_requested": [["text", TYPE_STRING, ""], ["kind", SN, ""]],
	"hint_triggered": [["hint_id", SN, ""]],
	"fracture_opened": [["grade", I, ""]],
	"fracture_group_cleared": [["index", I, ""], ["total", I, ""]],
	"fracture_boss_started": [["boss_id", SN, ""]],
	"fracture_finished": [["outcome", SN, ""], ["grade", I, ""], ["groups", I, ""], ["cards", I, ""], ["pieces", I, ""]],
	"fracture_bag_changed": [["stacks", I, ""], ["pieces", I, ""], ["cards", I, ""]],
	"fracture_loot_lost": [["stacks", I, ""], ["pieces", I, ""], ["cards", I, ""]],
	"card_changed": [["uid", I, ""], ["change", SN, ""]],
	"card_rejected": [["grade", I, ""]],
}

const REMOVED_SIGNALS: PackedStringArray = ["fracture_closed"]  # the timed Fracture is gone (R-04)

var _events: GameEvents


func before_each() -> void:
	_events = autofree(GameEvents.new())


func test_declares_exactly_the_contract_signals() -> void:
	var declared: PackedStringArray = []
	for info: Dictionary in (_events.get_script() as Script).get_script_signal_list():
		declared.append(String(info["name"]))
	declared.sort()
	var expected: PackedStringArray = PackedStringArray(EXPECTED.keys())
	expected.sort()
	assert_eq(declared, expected)


func test_each_signal_has_the_contract_arguments() -> void:
	var by_name: Dictionary[String, Dictionary] = {}
	for info: Dictionary in _events.get_signal_list():
		by_name[String(info["name"])] = info
	for signal_name: String in EXPECTED:
		if not by_name.has(signal_name):
			fail_test("missing signal %s" % signal_name)
			continue
		var args: Array = by_name[signal_name]["args"]
		var expected_args: Array = EXPECTED[signal_name]
		assert_eq(args.size(), expected_args.size(), "%s: argument count" % signal_name)
		for i: int in mini(args.size(), expected_args.size()):
			_assert_arg(signal_name, args[i] as Dictionary, expected_args[i] as Array)


func test_removed_signals_are_not_declared() -> void:
	for signal_name: String in REMOVED_SIGNALS:
		assert_false(_events.has_signal(signal_name), signal_name)


func test_has_no_state() -> void:
	var script_vars: Array[Dictionary] = []
	for prop: Dictionary in (_events.get_script() as Script).get_script_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			script_vars.append(prop)
	assert_eq(script_vars.size(), 0, "EventBus holds only signals")


func test_autoload_is_a_game_events() -> void:
	var bus: Node = get_tree().root.get_node_or_null(^"EventBus")
	assert_true(bus is GameEvents)


func _assert_arg(signal_name: String, arg: Dictionary, expected: Array) -> void:
	var label: String = "%s(%s)" % [signal_name, expected[0]]
	assert_eq(String(arg["name"]), String(expected[0]), label + ": name")
	assert_eq(int(arg["type"]), int(expected[1]), label + ": type")
	assert_eq(String(arg["class_name"]), String(expected[2]), label + ": class")
