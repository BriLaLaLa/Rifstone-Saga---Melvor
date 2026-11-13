extends GutTest
## M16-02 regression: Masterwork body of Roccamartello from a blueprint (real data) lands in the Armory, can be worn,
## the blueprint leaves the bank at start, and refining a piece changes its modifiers.

const BP: StringName = &"bp_mw_body_3"
const BASE: StringName = &"mw_body_3"

var _s: GameSession = null


func before_each() -> void:
	_s = TestFactory.session_no_kit(777, TestFactory.real_data())


func after_each() -> void:
	if _s != null:
		_s.free()
	_s = null


func _prepare() -> void:
	TestFactory.set_level(_s, &"forging", BlueprintCraft.required_level(_s.data.item(BP), _s.data))
	TestFactory.give(_s, BP, 1)
	for entry: ItemQty in BlueprintCraft.inputs(_s.data.item(BP)):
		TestFactory.give(_s, entry.item_id, entry.qty)


func test_body_masterwork_reaches_armory_and_equipment() -> void:
	_prepare()
	var started: CommandResult = _s.actions.start_blueprint(BP)
	assert_true(started.ok, "start: %s" % started.reason)
	assert_eq(_s.bank.get_count(BP), 0, "the blueprint leaves the Deposit at Start")
	_s.advance(int(_s.actions.blueprint_state()["duration_ms"]) + 1000)
	var pieces: Array[ItemInstance] = _s.armory.instances()
	assert_eq(pieces.size(), 1, "the body is in the Armory")
	if pieces.is_empty():
		return
	assert_eq(pieces[0].base_id, BASE)
	assert_eq(_s.bank.get_count(BP), 0)
	var req: Dictionary = _s.data.item(BASE).equip.requirements
	var eq0: CommandResult = _s.equipment.equip(pieces[0].uid)
	assert_eq(eq0.ok, _s.character.meets_requirements(req), "worn iff the character meets %s" % [req])
	if eq0.ok:
		return
	TestFactory.set_character_level(_s, int(req.get("character", 1)))
	var eq: CommandResult = _s.equipment.equip(pieces[0].uid)
	assert_true(eq.ok, "the body can be worn: %s" % eq.reason)
	assert_true(_s.armory.is_worn(pieces[0].uid))


func test_blueprint_consume_removes_it_from_bank() -> void:
	_prepare()
	BlueprintCraft.consume(_s, BP)
	assert_eq(_s.bank.get_count(BP), 0)


func test_upgrade_changes_modifiers_of_the_piece() -> void:
	var uid: int = TestFactory.give_piece(_s, BASE, &"rare", 1)
	var before: Array[Modifier] = _s.armory.instance_modifiers(uid)
	var price: Dictionary = Upgrade.cost(0, Upgrade.material_grade(_s.armory.get_instance(uid), _s.data), _s.data)
	_s.wallet.add_gold(int(price["gold"]) * 1000)
	TestFactory.give(_s, price["ingot"], int(price["ingots"]) * 1000)
	TestFactory.give(_s, Upgrade.SHARD_ITEM, int(price["shards"]) * 1000 + 1)
	if int(price["dust"]) > 0:
		TestFactory.give(_s, Upgrade.DUST_ITEM, int(price["dust"]) * 1000)
	var level: int = 0
	for i: int in 40:
		assert_true(_s.armory.upgrade(uid).ok)
		level = _s.armory.get_instance(uid).upgrade
		if level > 0:
			break
	assert_gt(level, 0, "a refinement succeeded")
	var after: Array[Modifier] = _s.armory.instance_modifiers(uid)
	assert_eq(after.size(), before.size())
	var changed: bool = false
	for i: int in before.size():
		changed = changed or not is_equal_approx(before[i].value, after[i].value)
	assert_true(changed, "the modifiers of the refined piece changed")
