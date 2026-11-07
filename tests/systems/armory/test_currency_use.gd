extends GutTest
## GDD §26 / M8-09: Armory.use_currency (to_magic, to_rare, reroll), its refusals, atomicity, worn pieces, bank order.

const BLADE: StringName = &"test_blade"
const TO_MAGIC: StringName = &"test_currency"
const TO_RARE: StringName = &"test_currency_rare"
const REROLL: StringName = &"test_currency_reroll"

var _s: GameSession = null


func before_each() -> void:
	_s = autofree(TestFactory.session(11))


func _piece(rarity: StringName) -> int:
	return TestFactory.give_piece(_s, BLADE, rarity, 50)


func _ids(inst: ItemInstance) -> Array[StringName]:
	var out: Array[StringName] = []
	for roll: AffixRoll in inst.affixes:
		out.append(roll.affix_id)
	return out


func test_to_magic() -> void:
	var uid: int = _piece(&"common")
	TestFactory.give(_s, TO_MAGIC, 2)
	watch_signals(_s.events)
	var r: CommandResult = _s.armory.use_currency(uid, TO_MAGIC)
	assert_true(r.ok)
	var inst: ItemInstance = _s.armory.get_instance(uid)
	assert_eq(inst.rarity, &"magic")
	assert_between(inst.affixes.size(), 1, 2, "F-85 magic count")
	assert_eq(_s.bank.get_count(TO_MAGIC), 1, "one spent")
	assert_signal_emitted_with_parameters(_s.events, "armory_changed", [uid, &"updated"])


func test_to_rare_keeps_existing_affixes() -> void:
	var uid: int = _piece(&"magic")
	var before: Array[StringName] = _ids(_s.armory.get_instance(uid))
	TestFactory.give(_s, TO_RARE, 1)
	assert_true(_s.armory.use_currency(uid, TO_RARE).ok)
	var inst: ItemInstance = _s.armory.get_instance(uid)
	assert_eq(inst.rarity, &"rare")
	var after: Array[StringName] = _ids(inst)
	for id: StringName in before:
		assert_true(after.has(id), "kept " + String(id))
	assert_eq(after.slice(0, before.size()), before, "existing first, unchanged")
	assert_between(inst.affixes.size(), before.size(), 4)
	var unique: Dictionary = {}
	for id: StringName in after:
		unique[id] = true
	assert_eq(unique.size(), after.size(), "no duplicate affix")
	assert_eq(_s.bank.get_count(TO_RARE), 0)


func test_reroll_keeps_rarity_upgrade_sockets_locked() -> void:
	var uid: int = _piece(&"rare")
	var saved: Dictionary = _s.armory.to_save()
	for entry: Dictionary in saved["items"]:
		entry["upgrade"] = 3
		entry["sockets"] = ["test_stone"]
		entry["locked"] = false
	_s.armory.from_save(saved)
	TestFactory.give(_s, REROLL, 1)
	assert_true(_s.armory.use_currency(uid, REROLL).ok)
	var inst: ItemInstance = _s.armory.get_instance(uid)
	assert_eq(inst.rarity, &"rare")
	assert_eq(inst.upgrade, 3)
	assert_eq(inst.sockets, [&"test_stone"] as Array[StringName])
	assert_between(inst.affixes.size(), 2, 4, "fixture weapon has only 2 candidate affixes")


func test_reroll_is_a_new_draw() -> void:
	var uid: int = _piece(&"rare")
	TestFactory.give(_s, REROLL, 30)
	var seen: Dictionary = {}
	for _i: int in 30:
		assert_true(_s.armory.use_currency(uid, REROLL).ok)
		seen[str(_s.armory.get_instance(uid).to_dict()["affixes"])] = true
	assert_gt(seen.size(), 1, "affixes change between rerolls")


func test_same_seed_same_result() -> void:
	var uid: int = _piece(&"common")
	TestFactory.give(_s, TO_MAGIC, 1)
	_s.armory.use_currency(uid, TO_MAGIC)
	var other: GameSession = autofree(TestFactory.session(11))
	var uid2: int = TestFactory.give_piece(other, BLADE, &"common", 50)
	TestFactory.give(other, TO_MAGIC, 1)
	other.armory.use_currency(uid2, TO_MAGIC)
	assert_eq(_s.armory.get_instance(uid).to_dict()["affixes"], other.armory.get_instance(uid2).to_dict()["affixes"])


func test_wrong_rarity_refused_and_atomic() -> void:
	var common: int = _piece(&"common")
	var magic: int = _piece(&"magic")
	var rare: int = _piece(&"rare")
	TestFactory.give(_s, TO_MAGIC, 1)
	TestFactory.give(_s, TO_RARE, 1)
	TestFactory.give(_s, REROLL, 1)
	var cases: Array = [[magic, TO_MAGIC], [rare, TO_MAGIC], [common, TO_RARE], [rare, TO_RARE], [common, REROLL]]
	for c: Array in cases:
		var before: Dictionary = _s.armory.get_instance(c[0]).to_dict()
		var r: CommandResult = _s.armory.use_currency(c[0], c[1])
		assert_eq(r.reason, Reasons.REQUIREMENT_NOT_MET, "%s on %s" % [c[1], before["rarity"]])
		assert_eq(_s.armory.get_instance(c[0]).to_dict(), before)
	assert_eq(_s.bank.get_count(TO_MAGIC), 1)
	assert_eq(_s.bank.get_count(TO_RARE), 1)
	assert_eq(_s.bank.get_count(REROLL), 1)


func test_refusals() -> void:
	var uid: int = _piece(&"common")
	TestFactory.give(_s, TO_MAGIC, 1)
	assert_eq(_s.armory.use_currency(999, TO_MAGIC).reason, Reasons.UNKNOWN_ID)
	assert_eq(_s.armory.use_currency(uid, &"test_stone").reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_s.armory.use_currency(uid, &"nope").reason, Reasons.NOT_EQUIPPABLE)
	_s.armory.set_locked(uid, true)
	assert_eq(_s.armory.use_currency(uid, TO_MAGIC).reason, Reasons.ITEM_LOCKED)
	_s.armory.set_locked(uid, false)
	_s.armory.set_worn(uid, true)
	assert_eq(_s.armory.use_currency(uid, TO_MAGIC).reason, Reasons.ITEM_EQUIPPED)
	_s.armory.set_worn(uid, false)
	assert_eq(_s.bank.get_count(TO_MAGIC), 1, "nothing spent")
	assert_eq(_s.armory.get_instance(uid).rarity, &"common")
	_s.bank.remove(TO_MAGIC, 1)
	assert_eq(_s.armory.use_currency(uid, TO_MAGIC).reason, Reasons.NOT_ENOUGH_ITEMS)
	assert_eq(_s.armory.get_instance(uid).rarity, &"common")


func test_bank_sorts_stone_and_currency_last() -> void:
	TestFactory.give(_s, TO_MAGIC, 1)
	TestFactory.give(_s, &"test_stone", 1)
	TestFactory.give(_s, &"rift_shard", 1)
	_s.bank.sort_stacks()
	var order: Array = []
	for st: Dictionary in _s.bank.stacks():
		order.append(st["item"])
	assert_lt(order.find(&"rift_shard"), order.find(&"test_stone"))
	assert_lt(order.find(&"test_stone"), order.find(TO_MAGIC))
