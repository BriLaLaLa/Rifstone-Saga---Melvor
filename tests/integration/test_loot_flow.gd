extends GutTest
## Integration, loot flow (M7): monster drops -> Armory (automatic filter F-88 / full Armory) -> refinement F-86 (also
## with the Seal) -> equip -> effect on the stats. Also the conservation of the pieces: a piece exists once, refining
## and salvaging never copy or lose it, and the materials move exactly as the tables say.
##
## Real data (a private copy where the monsters of Roccarossa drop a sword and a ring 100% of the time), fixed seeds,
## only the public APIs of docs/05_INTERFACES.md 5.10, 5.17. No slot is written, no file is read except the data.

const SEED: int = 70701
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const RING: StringName = &"emberbronze_ring"
const INGOT: StringName = &"emberbronze_ingot"
const PLATE: StringName = &"emberbronze_plate"
const SHARD: StringName = &"rift_shard"
const DUST: StringName = &"rift_dust"
const DUSTS: Array[int] = [0, 0, 0, 0, 10, 20, 30, 40, 50]  # upgrade.levels[].dust (M14, Q71)
const SEAL: StringName = &"warding_seal"
const HERO: StringName = &"test:hero"
var _room: Array[int] = []
const DOWNGRADE_FROM: int = 4
const MAX_LEVEL: int = 9
# F-86 table (docs/02_FORMULAS.md): gold per grade, ingots, shards for N -> N+1.
const GOLD_PER_GRADE: Array[int] = [50, 100, 200, 400, 800, 1600, 3200, 6400, 12800]
const INGOTS: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5]
const SHARDS: Array[int] = [0, 0, 0, 0, 0, 5, 10, 15, 20]

var _added: Array[int] = []
var _auto_salvaged: Array[StringName] = []
var _kills: int = 0
var _rejected: int = 0


# A fresh real-data copy (GameData is shared by TestFactory.real_data(): this one can be changed freely).
func _drop_data() -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	assert_true(data.is_valid(), "real data valid")
	for monster_id: StringName in data.area(AREA).monster_ids:
		var list: Array[DropEntry] = []
		for item_id: StringName in [SWORD, RING]:
			var entry := DropEntry.new()
			entry.item_id = item_id
			entry.chance_pct = 100.0
			entry.qty_min = 1
			entry.qty_max = 1
			list.append(entry)
		data.monster(monster_id).drops = list
	return data


func _hero_session(data: GameData, seed_value: int = SEED) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, data))
	s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	_room = TestFactory.make_roomy(s)
	_added = []
	_auto_salvaged = []
	_kills = 0
	_rejected = 0
	s.events.armory_changed.connect(func(uid: int, change: StringName) -> void:
		if change == &"added":
			_added.append(uid))
	s.events.item_salvaged.connect(func(_uid: int, base_id: StringName, auto: bool) -> void:
		if auto:
			_auto_salvaged.append(base_id))
	s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: _kills += 1)
	s.events.bank_rejected.connect(func(_i: StringName, _q: int) -> void: _rejected += 1)
	return s


func _fight_until_kills(s: GameSession, kills: int) -> void:
	assert_true(s.combat.start(AREA).ok)
	var guard: int = 0
	while _kills < kills and guard < 20000:
		s.advance(500)
		guard += 1
	assert_gte(_kills, kills, "enough kills before the guard")


func _count_by_base(base: StringName, ids: Array[StringName]) -> int:
	var n: int = 0
	for id: StringName in ids:
		if id == base:
			n += 1
	return n


func test_every_drop_is_either_in_the_armory_or_salvaged_by_the_filter() -> void:
	var s: GameSession = _hero_session(_drop_data())
	assert_true(s.armory.set_filter(&"weapon", &"magic", 1).ok)
	_fight_until_kills(s, 40)
	var dropped: int = _kills * 2
	assert_eq(_added.size() + _auto_salvaged.size(), dropped, "a sword and a ring per kill, none lost, none copied")
	assert_eq(s.armory.used(), _added.size(), "the Armory holds exactly the pieces that entered")
	var seen: Dictionary[int, bool] = {}
	for inst: ItemInstance in s.armory.instances():
		assert_false(seen.has(inst.uid), "uid %d once" % inst.uid)
		seen[inst.uid] = true
		assert_true(_added.has(inst.uid), "%d announced as added" % inst.uid)
		if inst.base_id == SWORD:
			assert_ne(inst.rarity, &"common", "common swords are under the weapon filter")
		assert_true([1, 4, 8].has(inst.ilvl), "ilvl = highest combat level of the monster that dropped it (F-85): boar 1, rat 4, raider 8")
	assert_eq(_count_by_base(RING, _auto_salvaged), 0, "the ring has no rule: never filtered")
	assert_gt(_count_by_base(SWORD, _auto_salvaged), 0, "with 40 kills some common sword is filtered (20+3% only)")
	# F-88 / F-95 (M14): a piece without a blueprint (an ordinary sword) gives no components and no shard when common.
	assert_eq(s.bank.get_count(PLATE), 0, "an ordinary sword has no blueprint: no plates (F-95)")
	assert_eq(s.bank.get_count(SHARD), 0, "common pieces give no shards")
	for stack: Dictionary in s.bank.stacks():
		assert_false(String(stack["item"]).ends_with("_sword") or String(stack["item"]).ends_with("_ring"),
				"pieces never reach the bank")


func test_full_armory_salvages_the_drop_and_the_bank_full_is_never_silent() -> void:
	var s: GameSession = _hero_session(_drop_data())
	# Take the room away: the shared Deposit is filled by commons, so the yield cannot be stored either.
	_room[0] = 0
	var cap: int = s.deposit.capacity()
	for i: int in cap:
		TestFactory.give_piece(s, RING)
	assert_eq(s.armory.used(), cap)
	assert_eq(s.deposit.free_slots(), 0, "Deposit full")
	var pieces_before: int = s.armory.used()
	_added = []
	_fight_until_kills(s, 8)
	assert_eq(s.armory.used(), pieces_before, "the full Armory takes no drop")
	assert_eq(_added.size(), 0)
	assert_eq(_auto_salvaged.size(), _kills * 2, "every drop is salvaged, with a signal (auto = true)")
	assert_gt(_rejected, 0, "yields that do not fit are reported by bank_rejected, not lost in silence")
	assert_eq(s.bank.get_count(INGOT), 0, "and nothing was stored")


func test_salvage_and_the_filter_respect_lock_and_worn() -> void:
	var s: GameSession = _hero_session(_drop_data())
	var worn: int = TestFactory.give_piece(s, SWORD)
	var locked: int = TestFactory.give_piece(s, SWORD)
	var spare: int = TestFactory.give_piece(s, SWORD, &"magic", 8)
	assert_true(s.equipment.equip(worn).ok)
	assert_true(s.armory.set_locked(locked, true).ok)
	assert_eq(s.armory.salvage(worn).reason, Reasons.ITEM_EQUIPPED)
	assert_eq(s.armory.salvage(locked).reason, Reasons.ITEM_LOCKED)
	assert_eq(s.armory.used(), 2, "worn pieces do not count, the other two are in")
	assert_true(s.armory.salvage(spare).ok)
	assert_false(s.armory.has(spare), "gone for good")
	assert_eq(s.armory.salvage(spare).reason, Reasons.UNKNOWN_ID, "it cannot be salvaged twice")
	# magic T1 sword: no plates (an ordinary sword has no blueprint, F-95 M14) and 1 shard (magic x grade 1), no refinement.
	assert_eq(s.bank.get_count(PLATE), 0)
	assert_eq(s.bank.get_count(SHARD), 1)
	assert_eq(_auto_salvaged.size(), 0, "a manual salvage is not auto")


func _cost(level: int) -> Dictionary:
	return {"gold": GOLD_PER_GRADE[level], "ingots": INGOTS[level], "shards": SHARDS[level], "dust": DUSTS[level]}


func _stock(s: GameSession, seals: int) -> void:
	if s.wallet.get_gold() > 0:
		s.wallet.spend(s.wallet.get_gold())
	s.wallet.add_gold(5000000)
	if s.bank.get_count(INGOT) > 0:
		s.bank.remove(INGOT, s.bank.get_count(INGOT))
	TestFactory.give(s, INGOT, 5000)
	TestFactory.give(s, SHARD, 5000)
	TestFactory.give(s, DUST, 5000)
	if seals > 0:
		TestFactory.give(s, SEAL, seals)


# Refines `uid` to +9 attempt by attempt checking each against the F-86 table; returns the number of attempts.
func _refine_to_max(s: GameSession, uid: int, use_seal: bool) -> int:
	var attempts: int = 0
	var before: ItemInstance = s.armory.get_instance(uid)
	while s.armory.get_instance(uid).upgrade < MAX_LEVEL and attempts < 2000:
		var level: int = s.armory.get_instance(uid).upgrade
		var gold: int = s.wallet.get_gold()
		var ingots: int = s.bank.get_count(INGOT)
		var shards: int = s.bank.get_count(SHARD)
		var dust: int = s.bank.get_count(DUST)
		var seals: int = s.bank.get_count(SEAL)
		var outcome: Array = [false, 0]
		var conn: Callable = func(_u: int, ok: bool, lvl: int) -> void:
			outcome[0] = ok
			outcome[1] = lvl
		s.events.item_upgraded.connect(conn)
		var result: CommandResult = s.armory.upgrade(uid, use_seal)
		s.events.item_upgraded.disconnect(conn)
		assert_true(result.ok, "attempt from +%d: %s" % [level, result.reason])
		if not result.ok:
			break
		attempts += 1
		var cost: Dictionary = _cost(level)
		assert_eq(gold - s.wallet.get_gold(), cost["gold"], "gold from +%d" % level)
		assert_eq(ingots - s.bank.get_count(INGOT), cost["ingots"], "ingots from +%d" % level)
		assert_eq(shards - s.bank.get_count(SHARD), cost["shards"], "shards from +%d" % level)
		assert_eq(dust - s.bank.get_count(DUST), cost["dust"], "dust from +%d" % level)
		var after: ItemInstance = s.armory.get_instance(uid)
		var expected: int = level + 1
		var seal_spent: int = 0
		if not outcome[0]:
			expected = level
			if level >= DOWNGRADE_FROM:
				if use_seal:
					seal_spent = 1
				else:
					expected = level - 1
		assert_eq(after.upgrade, expected, "level after the attempt from +%d (success %s)" % [level, outcome[0]])
		assert_eq(outcome[1], after.upgrade, "item_upgraded carries the new level")
		assert_eq(seals - s.bank.get_count(SEAL), seal_spent, "the Seal is spent only on a protected failure at +4 or more")
		assert_eq(after.uid, uid)
		assert_eq(after.base_id, before.base_id)
		assert_eq(after.rarity, before.rarity)
		assert_eq(after.ilvl, before.ilvl)
		assert_eq(after.affixes.size(), before.affixes.size(), "the affixes never change")
		for i: int in before.affixes.size():
			assert_eq(after.affixes[i].affix_id, before.affixes[i].affix_id)
			assert_eq(after.affixes[i].value, before.affixes[i].value)
		assert_eq(s.armory.used(), 1, "one piece, never copied or lost")
		if use_seal:
			assert_gte(after.upgrade, level, "with the Seal the level never goes down")
	return attempts


func test_refine_to_max_without_the_seal_keeps_the_piece_and_charges_the_table() -> void:
	var s: GameSession = _hero_session(_drop_data(), 11)
	var uid: int = TestFactory.give_piece(s, SWORD, &"rare", 8)
	_stock(s, 0)
	var attempts: int = _refine_to_max(s, uid, false)
	assert_gte(attempts, MAX_LEVEL, "at least nine attempts")
	assert_eq(s.armory.get_instance(uid).upgrade, MAX_LEVEL)
	var gold: int = s.wallet.get_gold()
	assert_eq(s.armory.upgrade(uid).reason, Reasons.UPGRADE_MAX)
	assert_eq(s.wallet.get_gold(), gold, "a refused attempt changes nothing")
	assert_eq(s.armory.used(), 1)


func test_refine_to_max_with_the_seal_never_goes_down_and_spends_one_seal_per_protected_failure() -> void:
	var s: GameSession = _hero_session(_drop_data(), 12)
	var uid: int = TestFactory.give_piece(s, SWORD, &"magic", 8)
	_stock(s, 400)
	var seals_before: int = s.bank.get_count(SEAL)
	var attempts: int = _refine_to_max(s, uid, true)
	assert_eq(s.armory.get_instance(uid).upgrade, MAX_LEVEL)
	assert_gte(attempts, MAX_LEVEL)
	assert_lte(s.bank.get_count(SEAL), seals_before, "the Seal is only spent")


func test_a_protected_attempt_without_the_seal_is_refused_whole_and_below_four_it_is_not_needed() -> void:
	var s: GameSession = _hero_session(_drop_data(), 13)
	var uid: int = TestFactory.give_piece(s, SWORD)
	_stock(s, 0)
	assert_true(s.armory.upgrade(uid, true).ok, "at +0 the Seal is neither required nor consumed")
	# Climb to +4 with guaranteed success (chance min(100, 25 x (1 + 300/100)) = 100 at every level).
	s.modifiers.set_source(&"test:luck", [Modifier.make(&"upgrade_success_pct", 300.0)])
	while s.armory.get_instance(uid).upgrade < DOWNGRADE_FROM:
		assert_true(s.armory.upgrade(uid).ok)
	assert_eq(s.armory.get_instance(uid).upgrade, DOWNGRADE_FROM)
	var gold: int = s.wallet.get_gold()
	var ingots: int = s.bank.get_count(INGOT)
	var result: CommandResult = s.armory.upgrade(uid, true)
	assert_false(result.ok)
	assert_eq(result.reason, Reasons.NOT_ENOUGH_ITEMS, "the Seal is required from +4")
	assert_eq(s.wallet.get_gold(), gold, "atomic: no gold spent")
	assert_eq(s.bank.get_count(INGOT), ingots, "atomic: no ingot spent")
	assert_eq(s.armory.get_instance(uid).upgrade, DOWNGRADE_FROM)
	s.wallet.spend(s.wallet.get_gold())
	assert_eq(s.armory.upgrade(uid).reason, Reasons.NOT_ENOUGH_GOLD)


func test_a_refined_piece_changes_the_stats_when_worn_and_the_affixes_come_along() -> void:
	var s: GameSession = _hero_session(_drop_data(), 14)
	s.modifiers.clear_source(HERO)
	var sword: int = TestFactory.give_piece(s, SWORD, &"common", 8)
	var ring: int = TestFactory.give_piece(s, RING, &"rare", 8)
	_stock(s, 0)
	s.modifiers.set_source(&"test:luck", [Modifier.make(&"upgrade_success_pct", 300.0)])
	var base_power: float = s.modifiers.total(&"accuracy_bonus")
	var base_hit: int = s.combat.player_stats().max_hit
	assert_true(s.equipment.equip(sword).ok)
	var plain_power: float = s.modifiers.total(&"accuracy_bonus") - base_power
	assert_eq(plain_power, 4.0, "the base sword gives accuracy_bonus 4 (F-118: 4 per grade)")
	var plain_hit: int = s.combat.player_stats().max_hit
	assert_gt(plain_hit, base_hit, "wearing the sword raises the maximum hit")
	for i: int in MAX_LEVEL:
		assert_true(s.armory.upgrade(sword).ok)
	assert_eq(s.armory.get_instance(sword).upgrade, MAX_LEVEL)
	var refined_power: float = s.modifiers.total(&"accuracy_bonus") - base_power
	assert_almost_eq(refined_power, 4.0 * (1.0 + 0.1 * MAX_LEVEL), 0.001, "F-86: base modifiers x (1 + 10% per level)")
	assert_gt(s.combat.player_stats().max_hit, plain_hit, "and the stats follow the refinement of the worn piece")
	# The ring: every global modifier of the instance (base + affixes) reaches the totals once.
	var totals_before: Dictionary[StringName, float] = {}
	var mods: Array[Modifier] = s.armory.instance_modifiers(ring)
	assert_gt(s.armory.get_instance(ring).affixes.size(), 0, "a rare piece has affixes")
	for m: Modifier in mods:
		if m.scope_kind == Modifier.SCOPE_GLOBAL:
			totals_before[m.stat] = s.modifiers.total(m.stat)
	assert_true(s.equipment.equip(ring).ok)
	var expected: Dictionary[StringName, float] = {}
	for m: Modifier in mods:
		if m.scope_kind == Modifier.SCOPE_GLOBAL:
			expected[m.stat] = float(expected.get(m.stat, 0.0)) + m.value
	for stat: StringName in expected:
		assert_almost_eq(s.modifiers.total(stat) - totals_before[stat], expected[stat], 0.001, "%s of the ring" % stat)
	assert_true(s.equipment.unequip(&"ring").ok)
	for stat: StringName in expected:
		assert_almost_eq(s.modifiers.total(stat), totals_before[stat], 0.001, "%s back after unequip" % stat)
	assert_true(s.armory.has(ring) and s.armory.has(sword), "both pieces survive")
	assert_eq(s.armory.instances().size(), 2)
