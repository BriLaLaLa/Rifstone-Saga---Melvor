extends GutTest
## Integration, Rift Stone flow (M7, F-87, M15) on the real data: the pity guarantee, the stone encounter (fixed pulse, waves
## pack), the rewards (XP, shards, drops with the stone rarity and the area item level), save/load in the middle of
## the encounter and the equivalence of the advance steps.
##
## A private copy of the real data makes the stone drops certain (the shared real data is never changed). Fixed seeds.

const SEED: int = 70702
const OTHER_SEED: int = 31
const NOW_MS: int = 1793603600000
const AREA: StringName = &"redrock_plains"
const STONE: StringName = &"redrock_plains_stone_5"
const SEAL: StringName = &"warding_seal"
const SHARD: StringName = &"rift_shard"
const HERO: StringName = &"test:hero"
const TANK: StringName = &"test:tank"
# From data/combat/rift_stones.json (redrock_plains_stone_5, level 5: 450 hp by F-125; M17-04: xp and shards of tools/gen_metin.gd) and F-87.
const STONE_XP: int = 290
const PULSE_DAMAGE: int = 1
const PULSE_MS: int = 3000
const SHARDS_MIN: int = 2
const SHARDS_MAX: int = 4

var _encounters: Array = []
var _appeared: Array[StringName] = []
var _kills_at_appearance: int = -1
var _kills: int = 0
var _stone_kills: int = 0


func _data(certain_drops: bool = true) -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	assert_true(data.is_valid(), "real data valid")
	if certain_drops:
		for entry: DropEntry in data.rift_stone(STONE).drops:
			entry.chance_pct = 100.0
		# M14-05: the stone has no pieces or blueprints in the data any more (the pool of F-121 replaces them); this copy adds
		# them so that the delivery rules (pieces to the Armory with the stone rarity, blueprints to the bag) stay tested.
		for item_id: StringName in [&"emberbronze_ring", &"emberbronze_amulet", &"bp_mw_hands_2"]:
			var extra := DropEntry.new()
			extra.item_id = item_id
			extra.chance_pct = 100.0
			extra.qty_min = 1
			extra.qty_max = 1
			data.rift_stone(STONE).drops.append(extra)
	return data


func _session(data: GameData, seed_value: int = SEED, hero: bool = true, tank: bool = true) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, data))
	if hero:
		s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	elif tank:
		s.modifiers.set_source(TANK, [Modifier.make(&"max_hp_flat", 1000.0)])
	TestFactory.make_roomy(s)
	_encounters = []
	_appeared = []
	_kills_at_appearance = -1
	_kills = 0
	_stone_kills = 0
	s.events.encounter_started.connect(func(ids: Array[StringName]) -> void: _encounters.append(ids.duplicate()))
	s.events.rift_stone_appeared.connect(func(id: StringName) -> void:
		_appeared.append(id)
		_kills_at_appearance = _encounters.size())
	s.events.monster_killed.connect(func(_i: int, id: StringName) -> void:
		if id == STONE:
			_stone_kills += 1
		else:
			_kills += 1)
	return s


# The combat save with the Rift Stone counter set (public: 05 5.10 "combat.stone").
func _set_stone(s: GameSession, since: int, pending: bool, stone_id: StringName = STONE) -> void:
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": since, "pending": pending, "stone_id": String(stone_id) if pending else ""}
	s.combat.from_save(d)


func _run_until(s: GameSession, done: Callable, step_ms: int = 250, limit: int = 4000) -> void:
	var guard: int = 0
	while not done.call() and guard < limit:
		s.advance(step_ms)
		guard += 1
	assert_true(done.call(), "condition reached before the guard")


func test_pity_guarantees_the_stone_after_the_next_kill_then_the_counter_restarts() -> void:
	var s: GameSession = _session(_data())
	_set_stone(s, 299, false)  # pity_kills = 300 (balance.json)
	assert_true(s.combat.start(AREA).ok)
	_run_until(s, func() -> bool: return _appeared.size() > 0)
	assert_eq(_appeared.size(), 1, "a stone of the area appears")
	assert_eq(s.data.rift_stone(_appeared[0]).area_id, AREA, "drawn from the pool of the area (5, 10, 15)")
	assert_eq(_kills_at_appearance, 1, "during the first group: since 299 + its first kill >= pity")
	_run_until(s, func() -> bool: return s.combat.state() == CombatEngine.STATE_RIFTSTONE)
	var last: Array = _encounters[_encounters.size() - 1]
	assert_eq(last, [_appeared[0]], "the next encounter is the drawn stone alone (its waves come with the hits)")
	var stone: Dictionary = s.combat.to_save()["stone"]
	assert_eq(stone["pending"], false, "the stone is consumed when it starts")
	assert_eq(stone["since"], 0, "the counter restarted when it appeared")


func test_killing_the_stone_pays_xp_shards_and_the_stone_drops() -> void:
	var s: GameSession = _session(_data())
	_set_stone(s, 0, true)
	var xp_before: int = s.character.get_xp()
	var shards_before: int = s.bank.get_count(SHARD)
	var gold_before: int = s.wallet.get_gold()
	assert_true(s.combat.start(AREA).ok)
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE, "a pending stone is the first encounter")
	_run_until(s, func() -> bool: return _stone_kills > 0, 100)
	s.combat.loot.collect_all()
	var mult: float = float(s.data.balance_value("combat.kill_xp_mult"))
	assert_eq(s.character.get_xp() - xp_before, floori(STONE_XP * mult * 1.2 + 1e-9), "F-28 x F-130: stone level 5 vs character level 1 (d +4, x1.2)")
	assert_eq(s.wallet.get_gold(), gold_before, "no gold from a stone")
	assert_eq(_kills, 0, "a stone is not a counted monster kill")
	assert_true(s.combat.total_kills().is_empty())
	var bag: Dictionary = {}
	for entry: Dictionary in s.combat.loot.items():
		bag[entry["item"]] = int(entry["qty"])
	var shards: int = int(bag.get(SHARD, 0)) + s.bank.get_count(SHARD) - shards_before
	assert_between(shards, SHARDS_MIN, SHARDS_MAX, "shards in the range of the stone")
	assert_eq(int(bag.get(SEAL, 0)) + s.bank.get_count(SEAL), 1, "the Seal (certain in this copy) reaches the loot bag")
	# Pieces: the two drop rolls and the guaranteed piece (F-127) wait in the bag, then land in the Armory.
	var bases: Array[StringName] = []
	for inst: ItemInstance in s.armory.instances():
		bases.append(inst.base_id)
		assert_true(inst.ilvl == 10 or inst.ilvl == 5, "F-85: the highest combat level of the area (10) or the level of the stone (5)")
		assert_eq(inst.upgrade, 0)
	assert_eq(bases.size(), 3, "two drops and the guaranteed piece")
	assert_true(bases.has(&"emberbronze_amulet") and bases.has(&"emberbronze_ring"), "one of each, once")
	var blueprints: int = int(bag.get(&"bp_mw_hands_2", 0)) + s.bank.get_count(&"bp_mw_hands_2")
	assert_eq(blueprints, 1, "the blueprint of the stone reaches the loot bag or the bank, never the Armory")
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN, "then the usual wait before the next group")


func test_loot_of_the_stone_survives_death_rules_like_any_loot() -> void:
	# The Seal and the pieces wait in the loot bag until collected, and a death loses them.
	var s: GameSession = _session(_data())
	_set_stone(s, 0, true)
	s.combat.start(AREA)
	_run_until(s, func() -> bool: return _stone_kills > 0, 100)
	var pieces: int = s.combat.loot.pieces().size()
	assert_eq(pieces, 3, "two drops and the guaranteed piece")
	assert_true(s.combat.loot.used() > 0)
	var lost: Array[StringName] = []
	s.events.loot_lost.connect(func(item: StringName, _q: int) -> void: lost.append(item))
	s.combat.loot.lose_all()
	assert_true(lost.has(SEAL) and lost.has(SHARD), "shards and Seal are bag items")
	assert_eq(s.armory.used(), 0, "pieces wait in the bag (M15-04): a death loses them, the Armory is untouched")
	assert_eq(s.combat.loot.pieces().size(), 0)


func test_pulse_hits_every_pulse_ms_for_the_data_damage() -> void:
	var s: GameSession = _session(_data(), SEED, false)
	_set_stone(s, 0, true)
	s.combat.start(AREA)
	var hp: int = int(s.combat.get_state()["player_hp"])
	s.combat.advance(PULSE_MS - 1)
	assert_eq(int(s.combat.get_state()["player_hp"]), hp, "nothing before the pulse")
	s.combat.advance(1)
	assert_eq(int(s.combat.get_state()["player_hp"]), hp - PULSE_DAMAGE, "pulse_damage from data/combat/rift_stones.json")
	s.combat.advance(PULSE_MS)
	assert_eq(int(s.combat.get_state()["player_hp"]), hp - 2 * PULSE_DAMAGE)


func test_whisper_stone_comes_alone_and_its_wave_comes_with_the_first_hit() -> void:
	var s: GameSession = _session(_data(), SEED, false, true)  # M17-04: the hero one-shots a stone of 1700 hp (no wave)
	TestFactory.set_character_level(s, 21)
	_set_stone(s, 0, true, &"dry_uplands_stone_30")
	assert_true(s.combat.start(&"dry_uplands").ok)
	var state: Dictionary = s.combat.get_state()
	assert_eq(state["state"], CombatEngine.STATE_RIFTSTONE)
	assert_eq((state["enemies"] as Array).size(), 1)
	assert_eq(state["enemies"][0]["monster"], &"dry_uplands_stone_30")
	assert_eq(state["stone"]["level"], 30)
	assert_eq(state["stone"]["max_hp"], StoneFight.max_hp(30, s.data))
	var waves: Array = []
	s.events.rift_stone_wave.connect(func(_id: StringName, threshold: int, count: int) -> void: waves.append([threshold, count]))
	_run_until(s, func() -> bool: return not waves.is_empty() or not s.combat.is_active(), 250, 400)
	assert_eq(waves.slice(0, 1), [[StoneFight.FIRST_HIT, 7]], "the first hit calls a wave of 7 monsters of the area")
	var area_monsters: Array[StringName] = s.data.area(&"dry_uplands").monster_ids
	for i: int in range(1, (s.combat.get_state()["enemies"] as Array).size()):
		assert_true(area_monsters.has(s.combat.get_state()["enemies"][i]["monster"]))


func test_save_load_in_the_middle_of_the_stone_continues_identically() -> void:
	var data: GameData = _data()
	# Only state that the save keeps: a test modifier source would not survive the load (hp would be clamped).
	var s: GameSession = _session(data, SEED, false, false)
	TestFactory.set_character_level(s, 12)
	_set_stone(s, 0, true)
	s.combat.start(AREA)
	s.advance(2500)
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE, "still fighting the stone")
	var text: String = SaveCodec.encode(s.to_save(NOW_MS))
	var copy: GameSession = _session(data, OTHER_SEED, false, false)
	assert_true(copy.from_save(SaveCodec.decode(text)).ok)
	assert_eq(_diff(SaveCodec.decode(SaveCodec.encode(copy.to_save(NOW_MS))), SaveCodec.decode(text), ""), [], "save -> load -> save identical in the stone state")
	assert_eq(copy.combat.state(), CombatEngine.STATE_RIFTSTONE)
	for i: int in 60:
		s.advance(1000)
		copy.advance(1000)
	assert_eq(_diff(SaveCodec.decode(SaveCodec.encode(copy.to_save(NOW_MS))), SaveCodec.decode(SaveCodec.encode(s.to_save(NOW_MS))), ""), [], "the same continuation after the load (rng included)")


func test_steps_do_not_change_the_stone_fight_on_real_data() -> void:
	var data: GameData = _data()
	var results: Array[String] = []
	for step_ms: int in [12000, 1000, 100]:
		var s: GameSession = _session(data, SEED, false)
		_set_stone(s, 0, true)
		s.combat.start(AREA)
		for i: int in 12000 / step_ms:
			s.combat.advance(step_ms)
		results.append(SaveCodec.encode(s.to_save(NOW_MS)))
	assert_eq(results[1], results[0], "1 x 12000 = 12 x 1000")
	assert_eq(results[2], results[0], "1 x 12000 = 120 x 100")


# Paths of the differences between two save dictionaries (empty = identical), for readable failures.
func _diff(a: Variant, b: Variant, path: String) -> Array[String]:
	var out: Array[String] = []
	if a is Dictionary and b is Dictionary:
		var keys: Dictionary = {}
		for k: Variant in (a as Dictionary).keys() + (b as Dictionary).keys():
			keys[k] = true
		for k: Variant in keys:
			out.append_array(_diff(a.get(k), b.get(k), path + "/" + str(k)))
	elif a is Array and b is Array and a.size() == b.size():
		for i: int in a.size():
			out.append_array(_diff(a[i], b[i], path + "[%d]" % i))
	elif str(a) != str(b):
		out.append("%s: %s != %s" % [path, a, b])
	return out
