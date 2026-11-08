extends GutTest
## F-95 salvage to components: the numbers of 02_FORMULAS.md (pure), Armory.salvage on the M10 fixtures (blueprints with
## 5 plates + 1 handle for test_blade and 10 plates + 2 handles for test_greatsword), rules and signals.

const BlueprintData := preload("res://tests/systems/actions/blueprint_data.gd")
const SHARD: StringName = &"rift_shard"
const PLATE: StringName = &"test_plate_1"
const HANDLE: StringName = &"test_handle_1"
const BLADE: StringName = &"test_blade"
const GREATSWORD: StringName = &"test_greatsword"

var _data: GameData = BlueprintData.data()
var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session(11, _data))


func _piece(base: StringName, rarity: StringName, level: int = 0, locked: bool = false) -> int:
	var inst := ItemInstance.new()
	inst.base_id = base
	inst.rarity = rarity
	inst.ilvl = 1
	inst.upgrade = level
	inst.locked = locked
	return _session.armory.add(inst)


## 02_FORMULAS.md F-95: sword grade 3 (6 plates, 2 handles) -> 2 plates, 0 handles; body (10 plates) -> 4; greatsword
## grade 8 (10 plates) -> 4.
func test_component_amounts() -> void:
	assert_eq(Salvage.component_amount(6, _data), 2)
	assert_eq(Salvage.component_amount(2, _data), 0, "floor(0.8)")
	assert_eq(Salvage.component_amount(10, _data), 4)
	assert_eq(Salvage.component_amount(5, _data), 2)
	assert_eq(Salvage.component_amount(1, _data), 0)


## Magic grade 3 +0 -> 3 shards; rare grade 8 +2 -> 26; ring rare grade 5 -> 15; common -> 0.
func test_shard_examples() -> void:
	assert_eq(Salvage.shards(3, &"magic", 0, _data), 3)
	assert_eq(Salvage.shards(8, &"rare", 2, _data), 26)
	assert_eq(Salvage.shards(5, &"rare", 0, _data), 15)
	assert_eq(Salvage.shards(4, &"common", 0, _data), 0)


func test_components_come_from_the_blueprint_of_the_base() -> void:
	assert_eq(Salvage.components(BLADE, _data), {PLATE: 2} as Dictionary[StringName, int], "5 plates -> 2, 1 handle -> 0")
	assert_eq(Salvage.components(GREATSWORD, _data), {PLATE: 4} as Dictionary[StringName, int], "10 -> 4, 2 handles -> 0")
	assert_true(Salvage.components(&"test_shield", _data).is_empty(), "no blueprint in the fixtures: nothing")
	var rare: Dictionary[StringName, int] = Salvage.components(BLADE, _data)
	assert_false(rare.has(&"test_log"), "the rare component is never returned")


func test_salvage_pays_components_and_shards() -> void:
	var uid: int = _piece(GREATSWORD, &"rare", 2)
	watch_signals(_session.events)
	assert_true(_session.armory.salvage(uid).ok)
	assert_false(_session.armory.has(uid))
	assert_eq(_session.bank.get_count(PLATE), 4)
	assert_eq(_session.bank.get_count(HANDLE), 0)
	assert_eq(_session.bank.get_count(SHARD), 3 * 1 + 2, "rare 3 x grade 1 + upgrade 2")
	assert_signal_emitted_with_parameters(_session.events, "item_salvaged", [uid, GREATSWORD, false])
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [uid, &"removed"])


func test_common_piece_pays_only_components() -> void:
	var uid: int = _piece(BLADE, &"common")
	assert_true(_session.armory.salvage(uid).ok)
	assert_eq(_session.bank.get_count(PLATE), 2)
	assert_eq(_session.bank.get_count(SHARD), 0)


func test_piece_without_blueprint_pays_only_shards() -> void:
	var uid: int = _piece(&"test_shield", &"magic")
	assert_true(_session.armory.salvage(uid).ok)
	assert_eq(_session.bank.get_count(SHARD), 1, "magic 1 x grade 1")
	assert_eq(_session.bank.get_count(PLATE), 0)


func test_rejections_change_nothing() -> void:
	assert_eq(_session.armory.salvage(999).reason, Reasons.UNKNOWN_ID)
	var locked: int = _piece(BLADE, &"magic", 0, true)
	assert_eq(_session.armory.salvage(locked).reason, Reasons.ITEM_LOCKED)
	var worn: int = _piece(GREATSWORD, &"common")
	assert_true(_session.equipment.equip(worn).ok)
	assert_eq(_session.armory.salvage(worn).reason, Reasons.ITEM_EQUIPPED)
	assert_true(_session.armory.has(locked) and _session.armory.has(worn))
	assert_eq(_session.bank.get_count(SHARD), 0)


func test_unique_tool_cannot_be_salvaged() -> void:
	var uid: int = _session.armory.tool_uid(&"tool_forestry")
	assert_gt(uid, 0)
	assert_eq(_session.armory.salvage(uid).reason, Reasons.ITEM_UNIQUE)
	assert_true(_session.armory.has(uid))


func test_full_bank_blocks_the_salvage() -> void:
	var uid: int = _piece(GREATSWORD, &"magic")
	for def: ItemDef in _data.items():
		if _session.deposit.free_slots() <= 1:
			break
		if not Bank.PIECE_CATEGORIES.has(def.category) and def.category != &"blueprint" and def.id != SHARD \
				and def.id != PLATE:
			_session.bank.add(def.id, 1)
	var spare: int = _session.deposit.free_slots()  # what is left after the real items: take it with a filler
	_session.deposit.register_occupant(&"test_filler", func() -> int: return spare)
	assert_eq(_session.deposit.free_slots(), 0, "deposit full")
	var result: CommandResult = _session.armory.salvage(uid)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.BANK_FULL)
	assert_true(_session.armory.has(uid), "nothing lost")
