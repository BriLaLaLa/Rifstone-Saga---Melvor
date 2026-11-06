extends GutTest
## Integration, Rift Stone flow (M7, F-87) on the real data: the pity guarantee, the stone encounter (pulse, summoned
## pack), the rewards (XP, shards, drops with the stone rarity and the area item level), save/load in the middle of
## the encounter and the equivalence of the advance steps.
##
## A private copy of the real data makes the stone drops certain (the shared real data is never changed). Fixed seeds.

const SEED: int = 70702
const OTHER_SEED: int = 31
const NOW_MS: int = 1793603600000
const AREA: StringName = &"redrock_plains"
const STONE: StringName = &"redrock_stone"
const SEAL: StringName = &"warding_seal"
const SHARD: StringName = &"rift_shard"
const HERO: StringName = &"test:hero"
const TANK: StringName = &"test:tank"
# From data/combat/rift_stones.json (redrock_stone) and F-87.
const STONE_XP: int = 400
const PULSE_DAMAGE: int = 2
const PULSE_MS: int = 3000
const SHARDS_MIN: int = 3
const SHARDS_MAX: int = 6

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
	return data


func _session(data: GameData, seed_value: int = SEED, hero: bool = true, tank: bool = true) -> GameSession:
	var s: GameSession = autofree(TestFactory.session(seed_value, data))
	if hero:
		s.modifiers.set_source(HERO, [Modifier.make(&"power_bonus", 5000.0), Modifier.make(&"max_hp_flat", 100000.0)])
	elif tank:
		s.modifiers.set_source(TANK, [Modifier.make(&"max_hp_flat", 1000.0)])
	s.modifiers.set_source(&"test:room", [Modifier.make(&"armory_slots", 100.0)])
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
func _set_stone(s: GameSession, since: int, pending: bool) -> void:
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": since, "pending": pending}
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
	assert_eq(_appeared, [STONE] as Array[StringName], "the stone of the area appears")
	assert_eq(_kills_at_appearance, 1, "during the first group: since 299 + its first kill >= pity")
	_run_until(s, func() -> bool: return s.combat.state() == CombatEngine.STATE_RIFTSTONE)
	var last: Array = _encounters[_encounters.size() - 1]
	assert_eq(last, [STONE], "the next encounter is the stone alone (summon_pack null for Roccarossa)")
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
	assert_eq(s.character.get_xp() - xp_before, STONE_XP, "F-28: the XP of the stone, nothing else")
	assert_eq(s.wallet.get_gold(), gold_before, "no gold from a stone")
	assert_eq(_kills, 0, "a stone is not a counted monster kill")
	assert_true(s.combat.total_kills().is_empty())
	var bag: Dictionary = {}
	for entry: Dictionary in s.combat.loot.items():
		bag[entry["item"]] = int(entry["qty"])
	var shards: int = int(bag.get(SHARD, 0)) + s.bank.get_count(SHARD) - shards_before
	assert_between(shards, SHARDS_MIN, SHARDS_MAX, "shards in the range of the stone")
	assert_eq(int(bag.get(SEAL, 0)) + s.bank.get_count(SEAL), 1, "the Seal (certain in this copy) reaches the loot bag")
	# Pieces: the two rolls land in the Armory with the stone rarity table and the item level of the area.
	var bases: Array[StringName] = []
	for inst: ItemInstance in s.armory.instances():
		bases.append(inst.base_id)
		assert_eq(inst.ilvl, 8, "F-85: the highest combat level among the monsters of the area (redrock_raider)")
		assert_eq(inst.upgrade, 0)
	bases.sort()
	assert_eq(bases, [&"emberbronze_greaves", &"emberbronze_ring"] as Array[StringName], "one of each, once")
	assert_eq(s.combat.state(), CombatEngine.STATE_BETWEEN, "then the usual wait before the next group")


func test_loot_of_the_stone_survives_death_rules_like_any_loot() -> void:
	# The Seal waits in the loot bag until collected, and a death loses it like every bag item (not the pieces).
	var s: GameSession = _session(_data())
	_set_stone(s, 0, true)
	s.combat.start(AREA)
	_run_until(s, func() -> bool: return _stone_kills > 0, 100)
	var pieces: int = s.armory.used()
	assert_eq(pieces, 2)
	assert_true(s.combat.loot.used() > 0)
	var lost: Array[StringName] = []
	s.events.loot_lost.connect(func(item: StringName, _q: int) -> void: lost.append(item))
	s.combat.loot.lose_all()
	assert_true(lost.has(SEAL) and lost.has(SHARD), "shards and Seal are bag items")
	assert_eq(s.armory.used(), pieces, "pieces went straight to the Armory: a death does not touch them")


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


func test_whisper_stone_summons_its_pack_with_the_stone_first() -> void:
	var s: GameSession = _session(_data())
	TestFactory.set_character_level(s, 16)
	var d: Dictionary = s.combat.to_save()
	d["stone"] = {"since": 0, "pending": true}
	s.combat.from_save(d)
	assert_true(s.combat.start(&"whisper_wood").ok)
	var enemies: Array = s.combat.get_state()["enemies"]
	var ids: Array[StringName] = []
	for e: Dictionary in enemies:
		ids.append(e["monster"])
	var pack: Array[StringName] = s.data.area(&"whisper_wood").packs[s.data.rift_stone_for_area(&"whisper_wood").summon_pack].monster_ids
	assert_eq(ids[0], &"whisper_stone")
	assert_eq(ids.slice(1), pack, "the summoned pack follows, in position order")
	assert_eq(s.combat.state(), CombatEngine.STATE_RIFTSTONE)


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
	assert_gt(_stone_kills, 0, "the stone died in the minute and paid")


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
