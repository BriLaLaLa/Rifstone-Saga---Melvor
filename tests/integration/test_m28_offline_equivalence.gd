extends GutTest
## M28-08 (docs/01_GDD_M28.md §40.8, docs/02_FORMULAS_M28.md F-194, Q176): the offline run uses the same engine as the game. With a
## loadout of the real data that uses Bleed (Ferite aperte), Stagger and Weaken (Rintocco dello scudo), Ward (Guardia alta, Bastione
## vivente), a counter-attack (Risposta dello scudo) and stacks (Collera paziente), 12 hours in one block = in steps of 100 ms = in
## blocks of 60 s, the last two with a save and a reload in the middle. Then the real time of 12 offline hours with and without Bleed.

const Sim := preload("res://tools/sim_combat.gd")
const SimLoadout := preload("res://tools/sim_loadout.gd")
const SEED: int = 2828
const LEVEL: int = 82
const HOUR_MS: int = 3_600_000
const TWELVE_H: int = 12 * HOUR_MS
const TICK_MS: int = 100
const BLOCK_MS: int = 60_000
const SHIELD_TRAITS: String = "open_wounds,shield_answer,patient_wrath,living_bulwark"
const SHIELD_ABILITIES: String = "high_guard,shield_toll,shield_bash"
const BLEED_TRAITS: String = "twin_wounds,open_wounds,blood_scent,dodge_dance"
const BLEED_ABILITIES: String = "cross_cuts,twin_frenzy,thirsting_blade"
const CALM_TRAITS: String = "chain_cleave,momentum,blood_ember,dodge_dance"
const CALM_ABILITIES: String = "blade_volley,twin_frenzy,thirsting_blade"

var _data: GameData = null
var _area: AreaDef = null
var _tier: int = 0


func before_all() -> void:
	_data = TestFactory.real_data()
	_area = SimLoadout.area_for(_data, LEVEL)


## A session of the Sim (real data, forged set of the grade, food, rations) at LEVEL (every trait and ability of the loadouts is
## unlocked and the three ability slots and four trait slots are open), with the explicit loadout.
func _session(setup: StringName, traits: String, abilities: String, started: bool = true) -> GameSession:
	var level: int = LEVEL
	var grade: int = Sim.auto_grade(_data, level)
	var s: GameSession = autofree(Sim._new_session(_data, SEED))
	Sim._set_level(s, level)
	Sim._equip_set(s, grade, setup)
	assert_true(SimLoadout.apply(s, _data, {"loadout": "none", "traits": traits, "abilities": abilities}), "the loadout is accepted")
	var food_id: StringName = Sim.food_for_grade(_data, grade)
	s.bank.add(food_id, 1000000)
	s.equipment.set_food(food_id)
	_tier = Sim.auto_tier(_data, level)
	Sim._set_tier(s, _tier)
	s.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	if started:
		assert_true(s.combat.start(_area.id).ok)
	return s


func _state(s: GameSession) -> Dictionary:
	var d: Dictionary = s.to_save(0)
	d.erase("play_time_ms")
	return d


func _assert_same(a: GameSession, b: GameSession, what: String) -> void:
	var left: Dictionary = _state(a)
	var right: Dictionary = _state(b)
	for module: Variant in (left["modules"] as Dictionary):
		assert_eq((right["modules"] as Dictionary).get(module), (left["modules"] as Dictionary)[module], "%s: module %s" % [what, module])
	assert_eq(right["rng"], left["rng"], "%s: the rng" % what)


## The same fight in a new session built from the slot file of `s` (through the codec).
func _reload(s: GameSession, traits: String, abilities: String) -> GameSession:
	var saved: Dictionary = SaveCodec.decode(SaveCodec.encode(s.to_save(0)))
	var loaded: GameSession = _session(&"sword_shield", traits, abilities, false)
	assert_true(loaded.from_save(saved).ok)
	Sim._set_tier(loaded, _tier)  # a sim modifier source: not part of the slot file
	_assert_same(s, loaded, "right after the load")
	return loaded


func _count(s: GameSession, tally: Dictionary) -> void:
	s.events.combat_condition_damage.connect(func(_t: int, _d: int, condition: StringName) -> void:
		tally["cond_" + String(condition)] = int(tally.get("cond_" + String(condition), 0)) + 1)
	s.events.ability_used.connect(func(id: StringName, _t: Array[int]) -> void:
		tally["ability_" + String(id)] = int(tally.get("ability_" + String(id), 0)) + 1)
	s.events.trait_triggered.connect(func(id: StringName) -> void:
		tally["trait_" + String(id)] = int(tally.get("trait_" + String(id), 0)) + 1)


func _sample(s: GameSession, tally: Dictionary) -> void:
	var state: Dictionary = s.combat.get_state()
	if not (state.get("ward", {}) as Dictionary).is_empty():
		tally["seen_ward"] = int(tally.get("seen_ward", 0)) + 1
	for enemy: Dictionary in state.get("enemies", []):
		for condition: Variant in (enemy.get("conditions", {}) as Dictionary):
			var key: String = "seen_" + String(condition)
			tally[key] = int(tally.get(key, 0)) + 1


func _in_ticks(s: GameSession, ms: int, tally: Dictionary) -> void:
	for i: int in ms / TICK_MS:
		s.advance(TICK_MS)
		if i % 10 == 0:
			_sample(s, tally)


func _in_blocks(s: GameSession, ms: int) -> void:
	for _i: int in ms / BLOCK_MS:
		s.advance(BLOCK_MS)


func test_twelve_hours_in_one_block_in_ticks_and_in_blocks_with_a_reload_are_the_same_state() -> void:
	var tally: Dictionary = {}
	var one: GameSession = _session(&"sword_shield", SHIELD_TRAITS, SHIELD_ABILITIES)
	var ticks: GameSession = _session(&"sword_shield", SHIELD_TRAITS, SHIELD_ABILITIES)
	var blocks: GameSession = _session(&"sword_shield", SHIELD_TRAITS, SHIELD_ABILITIES)
	_count(ticks, tally)
	one.advance(TWELVE_H)
	_in_ticks(ticks, TWELVE_H / 2, tally)
	ticks = _reload(ticks, SHIELD_TRAITS, SHIELD_ABILITIES)
	_count(ticks, tally)
	_in_ticks(ticks, TWELVE_H / 2, tally)
	_in_blocks(blocks, TWELVE_H / 2)
	blocks = _reload(blocks, SHIELD_TRAITS, SHIELD_ABILITIES)
	_in_blocks(blocks, TWELVE_H / 2)
	gut.p("tally: %s" % str(tally))
	# The test is not vacuous: every mechanic of the loadout happened.
	for key: String in ["cond_bleed", "ability_high_guard", "ability_shield_toll", "ability_shield_bash", "trait_shield_answer",
			"trait_patient_wrath", "trait_living_bulwark", "seen_ward", "seen_bleed", "seen_stagger", "seen_weaken"]:
		assert_gt(int(tally.get(key, 0)), 0, "happened: %s" % key)
	assert_gt(int(one.combat.deaths()), -1)
	_assert_same(one, ticks, "12 h block vs ticks (reload at 6 h)")
	_assert_same(one, blocks, "12 h block vs blocks (reload at 6 h)")


## Real seconds of 12 offline hours on a loadout.
func _real_ms(traits: String, abilities: String) -> int:
	var s: GameSession = _session(&"dual", traits, abilities)
	var t0: int = Time.get_ticks_msec()
	for _hour: int in 12:  # a death stops the fight (as in the game): start it again at the next hour
		if not s.combat.is_active():
			s.combat.start(_area.id)
		OfflineSimulator.advance_silently(s, HOUR_MS)
	var ms: int = Time.get_ticks_msec() - t0
	var kills: int = 0
	for count: int in s.combat.total_kills().values():
		kills += count
	gut.p("  %s: %d ms, kills %d, deaths %d, active %s, stops %s" % [traits, ms, kills, s.combat.deaths(), s.combat.is_active(), str(s.combat.stop_reasons_log())])
	assert_gt(kills, 1000, "the fight ran for the 12 hours")
	return ms


func test_twelve_offline_hours_with_bleed_cost_at_most_one_and_a_half_times_those_without() -> void:
	var without: int = _real_ms(CALM_TRAITS, CALM_ABILITIES)
	var with_bleed: int = _real_ms(BLEED_TRAITS, BLEED_ABILITIES)
	var again: int = _real_ms(CALM_TRAITS, CALM_ABILITIES)
	var base: int = mini(without, again)
	gut.p("12 h offline: without bleed %d ms and %d ms, with bleed %d ms (ratio %.2f)" % [without, again, with_bleed, float(with_bleed) / maxf(1.0, base)])
	assert_lte(float(with_bleed), 1.5 * float(base), "Q176: Bleed costs at most 1.5x")
