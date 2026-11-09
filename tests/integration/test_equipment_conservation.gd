extends GutTest
## Lesson "single source of truth" for the equipment of the Alpha (docs/03_ARCHITECTURE.md §12): no piece is created or lost
## out of sight. Hours of combat on the real data with the drop pool of F-121: every piece obtained is either stored in the
## Armory once or salvaged by the filter (never silent), every other item is in the loot bag or the Bank; the legendaries
## arrive once; the save round-trip keeps the same pieces. Seeded, no real slot.

const SEED: int = 31337
const AREA: StringName = &"rift_threshold"
const BLOCK_MS: int = 600000
const BLOCKS: int = 36  # 6 hours
const HERO: StringName = &"test:hero"

var _data: GameData = null
var _obtained: Dictionary = {}
var _added: int = 0
var _removed: int = 0
var _salvaged: int = 0
var _rejected: int = 0


func before_all() -> void:
	_data = TestFactory.real_data()


func _hero() -> GameSession:
	var s: GameSession = autofree(TestFactory.session(SEED, _data))
	TestFactory.set_character_level(s, 65)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, &"emberbronze_sword")).ok)
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 100000.0), Modifier.make(&"max_hp_flat", 100000.0),
			Modifier.make(&"armor", 100000.0), Modifier.make(&"barrier", 100000.0), Modifier.make(&"evasion_bonus", 80000.0)])
	TestFactory.make_roomy(s)
	_obtained = {}
	_added = 0
	_removed = 0
	_salvaged = 0
	_rejected = 0
	s.events.item_obtained.connect(func(id: StringName, qty: int) -> void: _obtained[id] = _obtained.get(id, 0) + qty)
	s.events.armory_changed.connect(func(_uid: int, change: StringName) -> void:
		_added += 1 if change == Armory.CHANGE_ADDED else 0
		_removed += 1 if change == Armory.CHANGE_REMOVED else 0)
	s.events.item_salvaged.connect(func(_uid: int, _base: StringName, _auto: bool) -> void: _salvaged += 1)
	s.events.armory_rejected.connect(func(_base: StringName, qty: int) -> void: _rejected += qty)
	return s


func _bank_counts(s: GameSession) -> Dictionary:
	var result: Dictionary = {}
	for def: ItemDef in _data.items():
		var n: int = s.bank.get_count(def.id)
		if n > 0:
			result[def.id] = n
	return result


func test_hours_of_combat_create_and_lose_nothing() -> void:
	var s: GameSession = _hero()
	var armory_before: int = s.armory.instances().size()
	var bank_before: Dictionary = _bank_counts(s)
	assert_true(s.combat.start(AREA).ok)
	for _i: int in BLOCKS:
		s.advance(BLOCK_MS)
	assert_eq(s.combat.deaths(), 0, "the hero never dies: nothing is lost with the bag")
	var kills: int = 0
	for n: int in s.combat.total_kills().values():
		kills += n
	assert_gt(kills, 500, "a real workload")
	var pieces_obtained: int = 0
	for id: StringName in _obtained:
		if _data.item(id).equip != null and not _data.item(id).is_map():
			pieces_obtained += int(_obtained[id])
	assert_gt(pieces_obtained, 5, "the pool gave pieces")
	assert_eq(pieces_obtained, _added + _salvaged, "every piece obtained is stored or salvaged by the filter")
	assert_eq(s.armory.instances().size(), armory_before + _added - _removed, "the Armory holds what was stored")
	assert_eq(_rejected, 0, "nothing rejected in a roomy Armory")
	var seen: Dictionary = {}
	for inst: ItemInstance in s.armory.instances():
		assert_false(seen.has(inst.uid), "uid %d appears once" % inst.uid)
		seen[inst.uid] = true
		assert_true(_data.has_item(inst.base_id))
	var bag: Dictionary = {}
	for entry: Dictionary in s.combat.loot.items():
		bag[entry["item"]] = int(entry["qty"])
	var bank_after: Dictionary = _bank_counts(s)
	for id: StringName in _obtained:
		var def: ItemDef = _data.item(id)
		if def.equip != null or def.is_map():
			continue
		var in_bank: int = int(bank_after.get(id, 0)) - int(bank_before.get(id, 0))
		assert_eq(int(_obtained[id]), int(bag.get(id, 0)) + in_bank, "%s: obtained = in the bag + in the Bank" % id)


func test_the_save_round_trip_keeps_the_same_pieces() -> void:
	var s: GameSession = _hero()
	s.combat.start(AREA)
	for _i: int in 12:
		s.advance(BLOCK_MS)
	var pieces: Array[Dictionary] = _snapshot(s)
	assert_gt(pieces.size(), 1)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_save(0)))
	var loaded: GameSession = autofree(TestFactory.session_no_kit(SEED, _data))
	assert_true(loaded.from_save(saved).ok)
	assert_eq(_snapshot(loaded), pieces, "same uids, bases, rarities, affixes, upgrades and worn flags")
	for slot: StringName in Equipment.SLOTS:
		assert_eq(loaded.equipment.get_uid(slot), s.equipment.get_uid(slot), "slot %s" % slot)


func _snapshot(s: GameSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for inst: ItemInstance in s.armory.instances():
		result.append({"uid": inst.uid, "base": inst.base_id, "rarity": inst.rarity, "affixes": inst.affixes.size(),
				"upgrade": inst.upgrade, "worn": s.armory.is_worn(inst.uid)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["uid"] < b["uid"])
	return result


func test_a_legendary_arrives_once_and_is_never_filtered() -> void:
	var s: GameSession = _hero()
	s.armory.set_filter(&"head", &"rare", 15)  # the strictest filter
	var legendary: ItemDef = _data.legendaries_from(LegendaryInfo.SOURCE_BOSS, &"boss_grade_1")[0]
	var before: int = s.armory.instances().size()
	var inst: ItemInstance = ItemRoller.create(legendary, Rarities.LEGENDARY, 10, _data, s.rng)
	var uid: int = s.armory.add_drop(inst)
	assert_gt(uid, 0, "stored, not salvaged")
	assert_eq(s.armory.instances().size(), before + 1)
	assert_eq(_obtained.get(legendary.id, 0), 1, "one item_obtained")
	assert_eq(_salvaged, 0)
	assert_true(s.discoveries.has(legendary.id))


func test_salvage_and_refinement_do_not_create_pieces() -> void:
	var s: GameSession = _hero()
	var uid: int = TestFactory.give_piece(s, &"emberbronze_sword", &"rare", 10)
	var before: int = s.armory.instances().size()
	var expected: Dictionary[StringName, int] = Salvage.paid(s.armory.get_instance(uid), _data)
	var bank_before: Dictionary = _bank_counts(s)
	assert_true(s.armory.salvage(uid).ok)
	assert_false(s.armory.has(uid), "the piece is gone")
	assert_eq(s.armory.instances().size(), before - 1)
	var after: Dictionary = _bank_counts(s)
	for id: StringName in expected:
		assert_eq(int(after.get(id, 0)) - int(bank_before.get(id, 0)), expected[id], "%s paid exactly" % id)
	assert_eq(s.armory.salvage(uid).ok, false, "a piece is salvaged once")
