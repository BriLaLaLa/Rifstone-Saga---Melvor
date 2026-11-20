extends GutTest
## M28-08: the conditions on a real session (docs/01_GDD_M28.md §40.3-40.8, docs/05_INTERFACES_M28.md §5.10b): unlock at a level,
## choice, use, the conditions and the Ward in `get_state()`, the slot file and its reload; a `ward_on` at the start of an encounter
## and a `ward` ability whose timer ran out, that must start again when the Ward runs out.

const Sim := preload("res://tools/sim_combat.gd")
const SimLoadout := preload("res://tools/sim_loadout.gd")
const SEED: int = 2829
const TICK_MS: int = 100

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _session(data: GameData, level: int, setup: StringName = &"sword_shield") -> GameSession:
	var s: GameSession = autofree(Sim._new_session(data, SEED))
	Sim._set_level(s, level)
	var grade: int = Sim.auto_grade(data, level)
	Sim._equip_set(s, grade, setup)
	var food_id: StringName = Sim.food_for_grade(data, grade)
	s.bank.add(food_id, 1000000)
	s.equipment.set_food(food_id)
	Sim._set_tier(s, Sim.auto_tier(data, level))
	s.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	return s


func _area_of(level: int) -> StringName:
	return SimLoadout.area_for(_data, level).id


func _combat_of(s: GameSession) -> Dictionary:
	return (s.to_save(0)["modules"] as Dictionary)["combat"]


## The keys of two combat dictionaries that differ, with both values: [] when they are the same.
func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for key: Variant in a:
		if a[key] != b.get(key):
			out.append("%s: %s != %s" % [key, str(a[key]), str(b.get(key))])
	return out


func _bleeding(s: GameSession) -> bool:
	for enemy: Dictionary in s.combat.get_state().get("enemies", []):
		if (enemy.get("conditions", {}) as Dictionary).has("bleed"):
			return true
	return false


func test_unlock_at_the_level_choice_use_state_and_save() -> void:
	# --- unlock: Guardia alta at 25 (ability), Ferite aperte at 40 (trait)
	var s: GameSession = _session(_data, 24)
	assert_eq(s.loadout.set_ability(0, &"high_guard").reason, Reasons.LEVEL_TOO_LOW, "locked at 24")
	Sim._set_level(s, 25)
	assert_true(s.loadout.set_ability(0, &"high_guard").ok, "open at 25")
	assert_eq(s.loadout.set_trait(0, &"open_wounds").reason, Reasons.LEVEL_TOO_LOW, "Ferite aperte needs 40")
	Sim._set_level(s, 40)
	assert_true(s.loadout.set_trait(0, &"open_wounds").ok, "open at 40")
	assert_true(s.loadout.set_ability(1, &"shield_bash").ok)
	assert_eq(s.loadout.set_ability(2, &"shield_toll").reason, Reasons.LEVEL_TOO_LOW, "Rintocco dello scudo needs 50 (the slot opens at 30)")
	assert_eq(s.loadout.set_trait(3, &"momentum").reason, Reasons.SLOT_LOCKED, "the fourth trait slot opens at 50")
	# --- use: fight until a bleed and a Ward were seen
	assert_true(s.combat.start(_area_of(40)).ok)
	var bleed_save: Dictionary = {}
	var ward_seen: Dictionary = {}
	var used: Array[StringName] = []
	s.events.ability_used.connect(func(id: StringName, _t: Array[int]) -> void: used.append(id))
	for _i: int in 6000:
		s.advance(TICK_MS)
		if bleed_save.is_empty() and _bleeding(s):
			bleed_save = _combat_of(s).duplicate(true)
			var shown: Dictionary = {}
			for enemy: Dictionary in s.combat.get_state()["enemies"]:
				if (enemy["conditions"] as Dictionary).has("bleed"):
					shown = (enemy["conditions"] as Dictionary)["bleed"]
			assert_true(shown.has("left") and shown.has("ticks"), "get_state shows the bleed {left, ticks}")
			assert_gt(int(shown["left"]), 0)
		if ward_seen.is_empty() and not (s.combat.get_state().get("ward", {}) as Dictionary).is_empty():
			ward_seen = (s.combat.get_state()["ward"] as Dictionary).duplicate()
			assert_eq((_combat_of(s)["ward"] as Dictionary), ward_seen, "the slot file holds the Ward of get_state")
		if not bleed_save.is_empty() and not ward_seen.is_empty():
			break
	assert_true(used.has(&"high_guard") and used.has(&"shield_bash"), "both abilities were used")
	assert_false(bleed_save.is_empty(), "an enemy bled")
	assert_false(ward_seen.is_empty(), "the player had a Ward")
	assert_true(ward_seen.has("amount") and ward_seen.has("ms"))
	assert_gt(int(ward_seen["amount"]), 0)
	# --- save: the conditions are in the slot file of the fight, the clock too
	var with_cond: bool = false
	for enemy: Dictionary in bleed_save["enemies"]:
		with_cond = with_cond or (enemy.has("cond") and (enemy["cond"] as Dictionary).has("bleed"))
	assert_true(with_cond, "combat.enemies[i].cond has the bleed")
	assert_gt(int(bleed_save.get("cond_clock_ms", 0)), -1)
	assert_true(bleed_save.has("cond_clock_ms"), "the Bleed clock is saved while someone bleeds")


func test_a_reload_in_the_middle_of_a_bleed_and_a_ward_continues_the_same_evolution() -> void:
	var traits: String = "open_wounds,shield_answer,living_bulwark"
	var abilities: String = "high_guard,shield_toll"
	var a: GameSession = _session(_data, 55)
	assert_true(SimLoadout.apply(a, _data, {"loadout": "none", "traits": traits, "abilities": abilities}))
	assert_true(a.combat.start(_area_of(55)).ok)
	var steps: int = 0
	while steps < 6000 and not (_bleeding(a) and not (a.combat.get_state().get("ward", {}) as Dictionary).is_empty()):
		a.advance(TICK_MS)
		steps += 1
	assert_lt(steps, 6000, "a moment with a bleed and a Ward together")
	var b: GameSession = _session(_data, 55)
	assert_true(b.from_save(SaveCodec.decode(SaveCodec.encode(a.to_save(0)))).ok)
	Sim._set_tier(b, Sim.auto_tier(_data, 55))  # the rations of the sim are a modifier source, not part of the slot file
	assert_eq(b.combat.get_state()["ward"], a.combat.get_state()["ward"], "the Ward comes back")
	var conditions_a: Array = (a.combat.get_state()["enemies"] as Array).map(func(e: Dictionary) -> Dictionary: return e["conditions"])
	var conditions_b: Array = (b.combat.get_state()["enemies"] as Array).map(func(e: Dictionary) -> Dictionary: return e["conditions"])
	assert_eq(conditions_b, conditions_a, "the conditions come back")
	assert_eq(_diff(_combat_of(b), _combat_of(a)), [], "the same slot file right after the load")
	var first_diff: Array = []
	var at_tick: int = -1
	for i: int in 6000:  # ten minutes in ticks of 100 ms: the first moment the two fights differ
		a.advance(TICK_MS)
		b.advance(TICK_MS)
		first_diff = _diff(_combat_of(b), _combat_of(a))
		if not first_diff.is_empty():
			at_tick = i
			break
	assert_eq(first_diff, [], "the same fight ten minutes later (first difference at tick %d)" % at_tick)
	assert_eq(b.rng.to_save(), a.rng.to_save(), "the same random generator")


func test_a_stopped_fight_writes_no_condition() -> void:
	var s: GameSession = _session(_data, 55)
	assert_true(SimLoadout.apply(s, _data, {"loadout": "none", "traits": "open_wounds,living_bulwark", "abilities": "high_guard,shield_toll"}))
	assert_true(s.combat.start(_area_of(55)).ok)
	for _i: int in 3000:
		s.advance(TICK_MS)
	s.combat.stop()
	var saved: Dictionary = _combat_of(s)
	assert_true((saved.get("ward", {}) as Dictionary).is_empty(), "no Ward while stopped")
	assert_false(saved.has("cond_clock_ms") and int(saved["cond_clock_ms"]) > 0, "no clock while stopped")
	for enemy: Dictionary in saved.get("enemies", []):
		assert_false(enemy.has("cond"), "no condition while stopped")


# --- ward_on at the start of an encounter, and a `ward` ability that must start again when the Ward runs out ---------------------

## A copy of the real data with one more trait (a Ward of 20% for 3000 ms at the start of every encounter) and a short cooldown of
## Guardia alta, so that its timer runs out while that Ward is still up.
func _data_with_start_ward() -> GameData:
	var data: GameData = GameData.load_from_dirs(TestFactory.REAL_CONTENT_ROOT, TestFactory.CONFIG_ROOT)
	var def: TraitDef = TraitDef.from_dict({"id": "test_start_ward", "name": "Test", "description": "Test", "unlock_level": 1, "setups": [],
			"effects": [{"type": "ward_on", "params": {"on": "encounter_start", "pct": 20, "ms": 3000}}], "modifiers": []})
	assert_not_null(def)
	data.character_class(&"rift_blade").traits.append(def)
	for ability: AbilityDef in data.character_class(&"rift_blade").abilities:
		if ability.id == &"high_guard":
			ability.cooldown_ms = 2000  # ready (2 s) before the 3 s Ward of the trait ends
	return data


func _untouchable(s: GameSession) -> void:
	s.modifiers.set_source(&"test:evade", [Modifier.make(&"evasion_bonus", 80000.0), Modifier.make(&"max_hp_flat", 100000.0)])


func test_ward_on_encounter_start_grants_the_ward_when_the_encounter_begins() -> void:
	var data: GameData = _data_with_start_ward()
	var s: GameSession = _session(data, 30)
	_untouchable(s)
	assert_true(SimLoadout.apply(s, data, {"loadout": "none", "traits": "test_start_ward", "abilities": "none"}))
	var granted: Array = []
	s.events.encounter_started.connect(func(_ids: Array[StringName]) -> void:
		var ward: Dictionary = s.combat.get_state().get("ward", {})
		granted.append(ward.duplicate()))
	assert_true(s.combat.start(SimLoadout.area_for(data, 30).id).ok)
	for _i: int in 600:
		s.advance(TICK_MS)
	assert_gt(granted.size(), 0, "an encounter began")
	var first: Dictionary = granted[0]
	assert_eq(int(first.get("amount", 0)), int(floor(float(s.combat.player_stats().max_hp) * 0.2 + 0.000001)), "20% of the maximum hp")
	assert_eq(int(first.get("ms", 0)), 3000, "for 3000 ms")


func test_a_ward_ability_starts_again_when_the_ward_of_the_encounter_runs_out() -> void:
	# Guardia alta gives 15%: it is not used while the 20% Ward of the trait is up, and once that runs out (nobody can hit the player,
	# so only the time ends it) the ability, whose timer is long expired, must be used. One block, dated with advance_offset_ms.
	var data: GameData = _data_with_start_ward()
	var s: GameSession = _session(data, 30)
	_untouchable(s)
	assert_true(SimLoadout.apply(s, data, {"loadout": "none", "traits": "test_start_ward", "abilities": "high_guard"}))
	var when: Dictionary = {"started": -1, "used": -1}
	s.events.encounter_started.connect(func(_ids: Array[StringName]) -> void:
		if when["started"] < 0:
			when["started"] = s.combat.advance_offset_ms)
	s.events.ability_used.connect(func(id: StringName, _t: Array[int]) -> void:
		if id == &"high_guard" and when["used"] < 0:
			when["used"] = s.combat.advance_offset_ms)
	assert_true(s.combat.start(SimLoadout.area_for(data, 30).id).ok)
	s.advance(20_000)
	assert_gte(int(when["started"]), 0, "an encounter began")
	assert_gte(int(when["used"]), 0, "Guardia alta was used")
	var expired_at: int = int(when["started"]) + 3000
	var late: int = int(when["used"]) - expired_at
	gut.p("Ward ends at %d ms, Guardia alta used at %d ms: %d ms later" % [expired_at, int(when["used"]), late])
	assert_gte(late, 0, "never before the Ward runs out")
	assert_lte(late, TICK_MS, "used when the Ward runs out")


func test_the_late_ward_ability_is_the_same_in_ticks_and_in_one_block() -> void:
	var data: GameData = _data_with_start_ward()
	var one: GameSession = _session(data, 30)
	var ticks: GameSession = _session(data, 30)
	for s: GameSession in [one, ticks]:
		_untouchable(s)
		assert_true(SimLoadout.apply(s, data, {"loadout": "none", "traits": "test_start_ward", "abilities": "high_guard"}))
		assert_true(s.combat.start(SimLoadout.area_for(data, 30).id).ok)
	one.advance(60_000)
	for _i: int in 600:
		ticks.advance(TICK_MS)
	var diff: Array = _diff(_combat_of(ticks), _combat_of(one))
	assert_true(diff.is_empty(), "ticks and one block are the same: %s" % str(diff))
	assert_eq(ticks.rng.to_save(), one.rng.to_save())
