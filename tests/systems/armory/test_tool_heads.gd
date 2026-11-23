extends GutTest
## M35-D F-196 (base effect), F-197 (heads at +3/+6/+9) and F-198 (choice, change cost, refusals) with the examples of
## docs/02_FORMULAS_M35.md. Content: the real data plus the M35-D2 content (`m35_data.gd`).

const M35 := preload("res://tests/systems/armory/m35_data.gd")
const PICK: StringName = &"tool_quarrying"
const AXE: StringName = &"tool_forestry"
const ROD: StringName = &"tool_angling"
const SICKLE: StringName = &"tool_herbalism"
const QUARRYING: StringName = &"quarrying"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session(5, M35.data()))


## The unique tool of `slot` at `+upgrade` (set straight: the commands that pay are tested elsewhere).
func _tool(slot: StringName, upgrade: int) -> int:
	var uid: int = _s.armory.tool_uid(slot)
	_s.armory._items[uid].upgrade = upgrade
	_s.events.armory_changed.emit(uid, Armory.CHANGE_UPDATED)
	return uid


func _total(stat: StringName, skill: StringName) -> float:
	return _s.modifiers.total(stat, ModifierContext.for_skill(skill))


func _choose_all(uid: int, head: StringName) -> void:
	for step: int in [3, 6, 9]:
		assert_true(_s.armory.choose_tool_head(uid, step, head).ok, "step %d" % step)


# --- F-196 ---------------------------------------------------------------------------------------------------------

func test_base_effect_of_the_refinement() -> void:
	_tool(PICK, 0)
	assert_eq(_total(&"skill_interval_pct", QUARRYING), -5.0)
	assert_eq(_total(&"node_units_pct", QUARRYING), 0.0)
	_tool(PICK, 4)
	assert_eq(_total(&"skill_interval_pct", QUARRYING), -13.0)
	assert_eq(_total(&"node_units_pct", QUARRYING), 4.0)
	_tool(PICK, 9)
	assert_eq(_total(&"skill_interval_pct", QUARRYING), -23.0)
	assert_eq(_total(&"node_units_pct", QUARRYING), 9.0)
	assert_eq(_total(&"node_units_pct", &"forestry"), 0.0, "the scope is the skill of the tool")


func test_the_sickle_at_plus_zero() -> void:
	assert_eq(_total(&"skill_interval_pct", &"herbalism"), -5.0)
	assert_eq(_total(&"node_units_pct", &"herbalism"), 0.0)


func test_no_extras_at_any_step() -> void:
	_tool(AXE, 9)
	assert_eq(_total(&"double_item_chance", &"forestry"), 0.0)
	_tool(ROD, 9)
	assert_eq(_total(&"rift_shard_chance", &"angling"), 0.0)


# --- F-197 ---------------------------------------------------------------------------------------------------------

func test_pick_at_nine_all_yield() -> void:
	var uid: int = _tool(PICK, 9)
	_choose_all(uid, &"pick_vein")
	assert_eq(_total(&"node_units_pct", QUARRYING), 24.0)


func test_pick_at_nine_all_richness() -> void:
	var uid: int = _tool(PICK, 9)
	_choose_all(uid, &"pick_quarry")
	assert_eq(_total(&"node_rich_pct", QUARRYING), 18.0)
	assert_eq(_total(&"double_item_chance", QUARRYING), 6.0)
	assert_eq(_total(&"node_units_pct", QUARRYING), 9.0)


func test_a_step_not_reached_does_not_count() -> void:
	var uid: int = _tool(PICK, 5)
	assert_true(_s.armory.choose_tool_head(uid, 3, &"pick_vein").ok)
	assert_eq(_total(&"node_units_pct", QUARRYING), 10.0, "5 + 5")
	assert_eq(_s.armory.choose_tool_head(uid, 6, &"pick_vein").reason, Reasons.HEAD_LOCKED)
	var low: int = _tool(PICK, 2)
	_s.armory._items[low].heads = [&"pick_vein", &"pick_vein", &"pick_vein"] as Array[StringName]
	_s.events.armory_changed.emit(low, Armory.CHANGE_UPDATED)
	assert_eq(_total(&"node_units_pct", QUARRYING), 2.0, "heads saved above the refinement give nothing")


func test_mixing_heads_per_step() -> void:
	var uid: int = _tool(PICK, 9)
	assert_true(_s.armory.choose_tool_head(uid, 3, &"pick_vein").ok)
	assert_true(_s.armory.choose_tool_head(uid, 6, &"pick_quarry").ok)
	assert_eq(_s.armory.tool_heads(uid), [&"pick_vein", &"pick_quarry", &""] as Array[StringName])
	assert_eq(_total(&"node_units_pct", QUARRYING), 14.0)
	assert_eq(_total(&"node_rich_pct", QUARRYING), 6.0)


func test_axe_richness_gives_double_and_byproduct() -> void:
	var uid: int = _tool(AXE, 9)
	_choose_all(uid, &"hatchet_fine")
	assert_eq(_total(&"double_item_chance", &"forestry"), 12.0)
	assert_eq(_total(&"byproduct_chance_pct", &"forestry"), 3.0)


func test_rod_hook_and_sickle_bundle() -> void:
	_choose_all(_tool(ROD, 9), &"rod_hook")
	assert_eq(_total(&"rift_shard_chance", &"angling"), 25.0, "8 + 8 + 9")
	assert_eq(_total(&"double_item_chance", &"angling"), 9.0)
	_choose_all(_tool(SICKLE, 9), &"sickle_bundle")
	assert_eq(_total(&"node_rich_pct", &"herbalism"), 12.0)
	assert_eq(_total(&"double_item_chance", &"herbalism"), 9.0)


# --- F-198 ---------------------------------------------------------------------------------------------------------

func test_the_first_choice_is_free_and_a_change_pays() -> void:
	var uid: int = _tool(PICK, 9)
	_s.wallet.add_gold(2_000_000)
	var gold: int = _s.wallet.get_gold()
	assert_eq(_s.armory.tool_head_cost(uid, 3), 0, "no choice yet")
	_choose_all(uid, &"pick_vein")
	assert_eq(_s.wallet.get_gold(), gold, "the first choices cost nothing")
	assert_eq(_s.armory.tool_head_cost(uid, 3), 15000)
	assert_eq(_s.armory.tool_head_cost(uid, 6), 125000)
	assert_eq(_s.armory.tool_head_cost(uid, 9), 1000000)
	assert_eq(_s.armory.tool_head_cost(uid, 4), 0, "not a head step")
	for step: int in [3, 6, 9]:
		var before: int = _s.wallet.get_gold()
		var cost: int = _s.armory.tool_head_cost(uid, step)
		assert_true(_s.armory.choose_tool_head(uid, step, &"pick_quarry").ok)
		assert_eq(before - _s.wallet.get_gold(), cost)


func test_refusals_in_order() -> void:
	var uid: int = _tool(PICK, 5)
	assert_eq(_s.armory.choose_tool_head(9999, 3, &"pick_vein").reason, Reasons.UNKNOWN_ID)
	var sword: int = TestFactory.give_piece(_s, &"emberbronze_sword")
	assert_eq(_s.armory.choose_tool_head(sword, 3, &"pick_vein").reason, Reasons.NOT_A_TOOL)
	assert_eq(_s.armory.choose_tool_head(uid, 4, &"nope").reason, Reasons.INVALID_STEP, "the step comes before the head")
	assert_eq(_s.armory.choose_tool_head(uid, 6, &"nope").reason, Reasons.HEAD_LOCKED, "locked comes before unknown_head")
	assert_eq(_s.armory.choose_tool_head(uid, 3, &"nope").reason, Reasons.UNKNOWN_HEAD)
	assert_true(_s.armory.choose_tool_head(uid, 3, &"pick_vein").ok)
	assert_eq(_s.armory.choose_tool_head(uid, 3, &"pick_vein").reason, Reasons.HEAD_UNCHANGED)
	_s.wallet.spend(_s.wallet.get_gold())
	assert_eq(_s.armory.choose_tool_head(uid, 3, &"pick_quarry").reason, Reasons.NOT_ENOUGH_GOLD)
	assert_eq(_s.armory.tool_heads(uid)[0], &"pick_vein", "atomic: nothing changed")
	assert_eq(_s.wallet.get_gold(), 0)


func test_armory_changed_after_the_choice() -> void:
	var uid: int = _tool(PICK, 3)
	watch_signals(_s.events)
	assert_true(_s.armory.choose_tool_head(uid, 3, &"pick_vein").ok)
	assert_signal_emitted_with_parameters(_s.events, "armory_changed", [uid, Armory.CHANGE_UPDATED])
	_s.armory.choose_tool_head(uid, 3, &"pick_vein")
	assert_signal_emit_count(_s.events, "armory_changed", 1, "a refusal emits nothing")


func test_tool_next_step_tells_the_head_step() -> void:
	var uid: int = _tool(PICK, 2)
	assert_eq(_s.armory.tool_next_step(uid)["head_step"], 3)
	_tool(PICK, 3)
	assert_eq(_s.armory.tool_next_step(uid)["head_step"], 0)
	_tool(PICK, 5)
	assert_eq(_s.armory.tool_next_step(uid)["head_step"], 6)


func test_the_heads_of_a_piece_that_is_not_a_tool() -> void:
	var sword: int = TestFactory.give_piece(_s, &"emberbronze_sword")
	assert_eq(_s.armory.tool_heads(sword).size(), 0)
	assert_eq(_s.armory.tool_head_cost(sword, 3), 0)


func test_a_legendary_tool_has_no_heads_and_the_unique_keeps_them() -> void:
	var uid: int = _tool(AXE, 3)
	assert_true(_s.armory.choose_tool_head(uid, 3, &"hatchet_wide").ok)
	TestFactory.set_level(_s, &"forestry", 10)
	var legendary: int = TestFactory.give_piece(_s, &"leg_hatchet_1", &"legendary")
	assert_true(_s.equipment.equip(legendary).ok)
	assert_eq(_s.armory.choose_tool_head(legendary, 3, &"hatchet_wide").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.armory.upgrade_tool(legendary).reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_total(&"node_units_pct", &"forestry"), 0.0, "the unique tool is not worn: its heads do not count")
	assert_eq(_s.armory.tool_heads(uid)[0], &"hatchet_wide", "the heads stay on the unique tool")
	assert_true(_s.equipment.equip(uid).ok)
	assert_eq(_total(&"node_units_pct", &"forestry"), 8.0, "+3 and the head: 3 + 5")


## M35-D acceptance 8: the three stats are registered with a formula and a test that exists (on the M35-D2 content of `m35_data.gd`).
func test_the_new_stats_are_registered_with_their_tests() -> void:
	for stat: StringName in [&"node_units_pct", &"node_rich_pct", &"byproduct_chance_pct"]:
		assert_true(_s.data.stats.has(stat), str(stat))
		var info: Dictionary = _s.data.stats.info(stat)
		var parts: PackedStringArray = String(info["test"]).split("::")
		assert_true(FileAccess.file_exists("res://" + parts[0]), "%s: file %s" % [stat, parts[0]])
		assert_true(FileAccess.get_file_as_string("res://" + parts[0]).contains("func %s(" % parts[1]), "%s: %s" % [stat, parts[1]])
		assert_ne(String(info["formula"]), "")
