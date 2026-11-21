extends GutTest
## M28-08 (docs/02_FORMULAS_M28.md F-194 (4)): the real non-regression against M27. After M28-06 `loadout=auto` fills slots that used
## to stay empty with the new contents, so the golden numbers of test_combat_regression_m28.gd were re-recorded; here the loadout is
## EXPLICIT and made of the M27 contents only (the first 12 traits and 6 abilities of rift_blade.json, `traits=` / `abilities=` of
## tools/sim_combat.gd) and the events, hp and random generator state are the ones recorded on `main` before M28-06 (791cdd3).
## The same 2 h cases of the regression test; the four that reach level 30 (cracked_mines, weak gear) carry the OLD numbers.

const Sim := preload("res://tools/sim_combat.gd")
const SimLoadout := preload("res://tools/sim_loadout.gd")
const Rig := preload("res://tests/systems/combat/combat_regression_rig.gd")
const SEED: int = 1234
const HOURS: float = 2.0

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _m27_csv(session: GameSession, is_trait: bool) -> String:
	var pool: Array[StringName] = SimLoadout.M27_TRAITS if is_trait else SimLoadout.M27_ABILITIES
	var picked: Array[StringName] = SimLoadout.pick(session, _data, is_trait, pool)
	return ",".join(picked) if not picked.is_empty() else "none"


# Rig.run with the loadout of the M27 contents given through the explicit options.
func _run(area_id: StringName, setup: StringName, level_offset: int, grade_minus: int, food_count: int) -> Dictionary:
	var area: AreaDef = _data.area(area_id)
	var level: int = maxi(int(area.requirements.get(&"character", 1)), Sim.auto_level(_data, area) + level_offset)
	var grade: int = maxi(1, Sim.auto_grade(_data, level) - grade_minus)
	var session: GameSession = Sim._new_session(_data, SEED)
	var xp_before: int = Sim._set_level(session, level)
	Sim._equip_set(session, grade, setup)
	var opts: Dictionary = {"loadout": "none", "traits": _m27_csv(session, true), "abilities": _m27_csv(session, false)}
	assert_true(SimLoadout.apply(session, _data, opts), "the explicit M27 loadout is accepted")
	var food_id: StringName = Sim.food_for_grade(_data, grade)
	session.bank.add(food_id, food_count)
	session.equipment.set_food(food_id)
	Sim._set_tier(session, Sim.auto_tier(_data, level))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	var tally: Dictionary = {"events": 0, "hash": 17}
	Rig._connect(session, tally)
	var total_ms: int = int(HOURS * 3600000.0)
	var elapsed: int = 0
	while elapsed < total_ms:
		if not session.combat.is_active() and not session.combat.start(area_id).ok:
			break
		var step: int = mini(Rig.SLICE_MS, total_ms - elapsed)
		session.advance(step)
		elapsed += step
		Sim._pin_level(session, xp_before)
	var kills: int = 0
	for count: int in session.combat.total_kills().values():
		kills += count
	var result: Dictionary = {"deaths": session.combat.deaths(), "events": tally["events"], "food": session.combat.food_eaten(),
			"hash": tally["hash"], "kills": kills, "rng": str(session.rng.to_save()["state"]).hash()}
	session.free()
	return result


func test_the_explicit_m27_loadout_reaches_the_slots() -> void:
	var session: GameSession = Sim._new_session(_data, SEED)
	Sim._set_level(session, 60)
	Sim._equip_set(session, 5, &"sword_shield")
	assert_true(SimLoadout.apply(session, _data, {"loadout": "none", "traits": "stone_stance,last_stand", "abilities": "shield_bash"}))
	assert_eq([session.loadout.get_trait(0), session.loadout.get_trait(1), session.loadout.get_ability(0)],
			[&"stone_stance", &"last_stand", &"shield_bash"])
	assert_eq(session.loadout.get_trait(2), &"", "what is not listed stays empty")
	assert_false(SimLoadout.apply(session, _data, {"loadout": "none", "traits": "no_such_trait", "abilities": "-"}), "an unknown id is refused")
	session.free()


func test_sword_shield_plains() -> void:
	assert_eq(_run(&"redrock_plains", &"sword_shield", -3, 0, 1000000),
			{"deaths": 0, "events": 12768, "food": 387, "hash": 2038849273073428160, "kills": 529, "rng": 1163697843})


func test_greatsword_plains() -> void:
	assert_eq(_run(&"redrock_plains", &"greatsword", -3, 0, 1000000),
			{"deaths": 0, "events": 10485, "food": 375, "hash": 8313901566582730724, "kills": 385, "rng": 1217041523})


func test_dual_plains() -> void:
	assert_eq(_run(&"redrock_plains", &"dual", -3, 0, 1000000),
			{"deaths": 0, "events": 12894, "food": 381, "hash": 9215568773177735570, "kills": 487, "rng": 763040687})


func test_sword_shield_mines() -> void:
	assert_eq(_run(&"cracked_mines", &"sword_shield", -4, 0, 1000000),
			{"deaths": 0, "events": 26804, "food": 489, "hash": 8754797600491544843, "kills": 916, "rng": 3780298914})


func test_greatsword_mines() -> void:
	assert_eq(_run(&"cracked_mines", &"greatsword", -4, 0, 1000000),
			{"deaths": 0, "events": 30662, "food": 778, "hash": 8884716108105007507, "kills": 1044, "rng": 2482867834})


func test_dual_mines() -> void:
	assert_eq(_run(&"cracked_mines", &"dual", -4, 0, 1000000),
			{"deaths": 0, "events": 32778, "food": 748, "hash": 5486399411839162937, "kills": 838, "rng": 2361128376})


func test_weak_gear_sword_shield() -> void:
	assert_eq(_run(&"cracked_mines", &"sword_shield", -4, 4, 30),
			{"deaths": 186, "events": 14642, "food": 30, "hash": 7207199079807063643, "kills": 302, "rng": 691805859})


func test_weak_gear_dual() -> void:
	assert_eq(_run(&"whisper_wood", &"dual", -4, 3, 20),  # M31: kit 30 + 20 = the 50 food of the numbers
			{"deaths": 180, "events": 16145, "food": 50, "hash": 9021191194629548746, "kills": 353, "rng": 1132470544})
