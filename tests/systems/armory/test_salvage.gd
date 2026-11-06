extends GutTest
## F-88 salvage: yield examples of 02_FORMULAS.md (pure and with the real recipes), Armory.salvage rules and signals.

const SHARD: StringName = &"rift_shard"
const CUIRASS_T3: StringName = &"stormzinc_cuirass"
const INGOT_T3: StringName = &"stormzinc_ingot"
const SWORD_T8: StringName = &"riftite_sword"
const INGOT_T8: StringName = &"riftite_ingot"

var _data: GameData = TestFactory.real_data()
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


func test_amounts_examples() -> void:
	# Cuirass T3 (5 ingots) magic +0 -> 2 ingots and 3 shards.
	assert_eq(Salvage.amounts(3, &"magic", 0, 5, _data), {"ingots": 2, "shards": 3})
	# Sword T8 (3 ingots) rare +2 -> 1 ingot and 26 shards.
	assert_eq(Salvage.amounts(8, &"rare", 2, 3, _data), {"ingots": 1, "shards": 26})
	# Ring T5 rare, no recipe -> 0 ingots, 15 shards.
	assert_eq(Salvage.amounts(5, &"rare", 0, 0, _data), {"ingots": 0, "shards": 15})
	assert_eq(Salvage.amounts(4, &"common", 0, 3, _data), {"ingots": 1, "shards": 0}, "common: no shards")


func test_recipe_ingots_from_the_forge_actions() -> void:
	var recipes: Dictionary[StringName, int] = Salvage.recipe_ingots(_data)
	assert_eq(recipes[CUIRASS_T3], 5)
	assert_eq(recipes[SWORD_T8], 3, "the grip is not an ingot")


func test_salvage_cuirass_pays_ingots_and_shards() -> void:
	var uid: int = _piece(CUIRASS_T3, &"magic")
	watch_signals(_session.events)
	assert_true(_session.armory.salvage(uid).ok)
	assert_false(_session.armory.has(uid))
	assert_eq(_session.bank.get_count(INGOT_T3), 2)
	assert_eq(_session.bank.get_count(SHARD), 3)
	assert_signal_emitted_with_parameters(_session.events, "item_salvaged", [uid, CUIRASS_T3, false])
	assert_signal_emitted_with_parameters(_session.events, "armory_changed", [uid, &"removed"])


func test_salvage_refined_rare_sword() -> void:
	var uid: int = _piece(SWORD_T8, &"rare", 2)
	assert_true(_session.armory.salvage(uid).ok)
	assert_eq(_session.bank.get_count(INGOT_T8), 1)
	assert_eq(_session.bank.get_count(SHARD), 26)


func test_common_piece_without_shards_pays_only_ingots() -> void:
	var uid: int = _piece(&"emberbronze_sword", &"common")
	assert_true(_session.armory.salvage(uid).ok)
	assert_eq(_session.bank.get_count(&"emberbronze_ingot"), 1, "floor(3 x 0.4)")
	assert_eq(_session.bank.get_count(SHARD), 0)


func test_rejections_change_nothing() -> void:
	assert_eq(_session.armory.salvage(99).reason, Reasons.UNKNOWN_ID)
	var locked: int = _piece(CUIRASS_T3, &"magic", 0, true)
	assert_eq(_session.armory.salvage(locked).reason, Reasons.ITEM_LOCKED)
	var worn: int = _piece(&"emberbronze_sword", &"common")
	assert_true(_session.equipment.equip(worn).ok)
	assert_eq(_session.armory.salvage(worn).reason, Reasons.ITEM_EQUIPPED)
	assert_true(_session.armory.has(locked) and _session.armory.has(worn))
	assert_eq(_session.bank.get_count(SHARD), 0)


func test_full_bank_blocks_the_salvage() -> void:
	var uid: int = _piece(CUIRASS_T3, &"magic")
	var fill: Array[ItemDef] = []
	for def: ItemDef in _data.items():
		if not Bank.PIECE_CATEGORIES.has(def.category) and def.id != SHARD and def.id != INGOT_T3:
			fill.append(def)
	for def: ItemDef in fill:
		if _session.bank.used() >= _session.bank.capacity():
			break
		_session.bank.add(def.id, 1)
	assert_eq(_session.bank.used(), _session.bank.capacity(), "bank full of other items")
	var result: CommandResult = _session.armory.salvage(uid)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.BANK_FULL)
	assert_true(_session.armory.has(uid), "nothing lost")
