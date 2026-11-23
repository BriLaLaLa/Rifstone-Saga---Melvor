extends GutTest
## M35-D: the Sickle and the fourth tool slot (`ArmoryKit.ensure_tools`, new game, old v12 saves) and the save of heads (docs/05_INTERFACES_M35.md
## §5.45, §6h). Content: the real data plus the M35-D2 content (`m35_data.gd`).

const M35 := preload("res://tests/systems/armory/m35_data.gd")
const SICKLE: StringName = &"unique_sickle"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session(11, M35.data()))


func _count(session: GameSession, base: StringName) -> int:
	var n: int = 0
	for inst: ItemInstance in session.armory.instances():
		n += 1 if inst.base_id == base else 0
	return n


## A save of `_s` as a v12 file written before M35-D: without the Sickle and without the new fields.
func _old_save() -> Dictionary:
	var d: Dictionary = JSON.parse_string(JSON.stringify(_s.to_save(0)))
	var modules: Dictionary = d["modules"]
	var items: Array = ((modules["armory"] as Dictionary)["items"] as Array).filter(func(i: Dictionary) -> bool: return i["base"] != String(SICKLE))
	for item: Dictionary in items:
		item.erase("heads")
	(modules["armory"] as Dictionary)["items"] = items
	((modules["equipment"] as Dictionary)["slots"] as Dictionary).erase("tool_herbalism")
	(modules["disciplines"] as Dictionary).erase("focus")
	return d


func test_the_slot_exists() -> void:
	assert_true(Equipment.SLOTS.has(&"tool_herbalism"))


func test_a_new_game_gives_the_sickle_worn() -> void:
	assert_eq(_count(_s, SICKLE), 1)
	var uid: int = _s.armory.tool_uid(&"tool_herbalism")
	assert_gt(uid, 0)
	assert_eq(_s.equipment.get_uid(&"tool_herbalism"), uid)
	assert_eq(_s.armory.get_instance(uid).upgrade, 0)
	assert_eq(_s.armory.tool_heads(uid), [&"", &"", &""] as Array[StringName])


func test_an_old_save_gets_a_sickle_at_plus_zero() -> void:
	var old: Dictionary = _old_save()
	var loaded: GameSession = autofree(TestFactory.session(12, M35.data()))
	assert_true(loaded.from_save(old).ok)
	assert_eq(_count(loaded, SICKLE), 1)
	var uid: int = loaded.armory.tool_uid(&"tool_herbalism")
	assert_eq(loaded.equipment.get_uid(&"tool_herbalism"), uid, "worn")
	assert_eq(loaded.armory.get_instance(uid).upgrade, 0)
	assert_eq(loaded.modifiers.total(&"skill_interval_pct", ModifierContext.for_skill(&"herbalism")), -5.0)
	assert_eq(loaded.to_save(0)["format_version"], 12, "no migration of version")


func test_an_existing_sickle_is_not_duplicated() -> void:
	var loaded: GameSession = autofree(TestFactory.session(12, M35.data()))
	assert_true(loaded.from_save(JSON.parse_string(JSON.stringify(_s.to_save(0)))).ok)
	assert_eq(_count(loaded, SICKLE), 1, "worn")
	var d: Dictionary = JSON.parse_string(JSON.stringify(_s.to_save(0)))
	((d["modules"] as Dictionary)["equipment"] as Dictionary)["slots"].erase("tool_herbalism")
	var in_armory: GameSession = autofree(TestFactory.session(13, M35.data()))
	assert_true(in_armory.from_save(d).ok)
	assert_eq(_count(in_armory, SICKLE), 1, "in the Armory, not worn: still one")
	assert_eq(ArmoryKit.ensure_tools(in_armory), false)


func test_heads_round_trip() -> void:
	var uid: int = _s.armory.tool_uid(&"tool_quarrying")
	_s.armory._items[uid].upgrade = 9
	assert_true(_s.armory.choose_tool_head(uid, 3, &"pick_vein").ok)
	assert_true(_s.armory.choose_tool_head(uid, 9, &"pick_quarry").ok)
	var loaded: GameSession = autofree(TestFactory.session(12, M35.data()))
	assert_true(loaded.from_save(JSON.parse_string(JSON.stringify(_s.to_save(0)))).ok)
	var loaded_uid: int = loaded.armory.tool_uid(&"tool_quarrying")
	assert_eq(loaded.armory.tool_heads(loaded_uid), [&"pick_vein", &"", &"pick_quarry"] as Array[StringName])
	assert_eq(loaded.modifiers.total(&"node_rich_pct", ModifierContext.for_skill(&"quarrying")), 6.0)
	assert_eq(loaded.modifiers.total(&"node_units_pct", ModifierContext.for_skill(&"quarrying")), 14.0, "9 + 5")


func test_invalid_heads_are_ignored() -> void:
	var d: Dictionary = JSON.parse_string(JSON.stringify(_s.to_save(0)))
	for item: Dictionary in ((d["modules"] as Dictionary)["armory"] as Dictionary)["items"]:
		if item["base"] == "unique_pick":
			item["upgrade"] = 9
			item["heads"] = ["pick_vein", "no_such_head"]
		if item["base"] == "unique_hatchet":
			item["heads"] = ["pick_vein", "", "", "hatchet_wide"]  # a head of another tool, and one too many
	var loaded: GameSession = autofree(TestFactory.session(12, M35.data()))
	assert_true(loaded.from_save(d).ok)
	assert_eq(loaded.armory.tool_heads(loaded.armory.tool_uid(&"tool_quarrying")), [&"pick_vein", &"", &""] as Array[StringName])
	assert_eq(loaded.armory.tool_heads(loaded.armory.tool_uid(&"tool_forestry")), [&"", &"", &""] as Array[StringName])
	assert_eq(loaded.to_save(0)["format_version"], 12)


func test_a_save_without_the_new_fields_loads() -> void:
	var loaded: GameSession = autofree(TestFactory.session(12, M35.data()))
	var old: Dictionary = _old_save()
	for item: Dictionary in ((old["modules"] as Dictionary)["armory"] as Dictionary)["items"]:
		assert_false(item.has("heads"))
	assert_true(loaded.from_save(old).ok)
	for slot: StringName in [&"tool_forestry", &"tool_quarrying", &"tool_angling", &"tool_herbalism"]:
		assert_eq(loaded.armory.tool_heads(loaded.armory.tool_uid(slot)), [&"", &"", &""] as Array[StringName], str(slot))
