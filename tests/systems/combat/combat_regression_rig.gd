extends RefCounted
## Not a test: drives the real CombatEngine on a session of the real data (like tools/sim_combat.gd, `loadout=auto`) and folds
## every event of the fight into one number, so that a refactor of the engine can prove it changed nothing (M28-03).

const Sim := preload("res://tools/sim_combat.gd")
const SLICE_MS: int = 30000


## {"events": int, "hash": int, "kills": int, "deaths": int, "food": int, "rng": int} of `hours` of fight in `area_id` with the
## `setup` assembly at `level_offset` levels from the area (a lower level gives deaths and food). Fixed seed.
static func run(data: GameData, area_id: StringName, setup: StringName, level_offset: int, hours: float, seed_value: int,
		grade_minus: int = 0, food_count: int = 1000000) -> Dictionary:
	var area: AreaDef = data.area(area_id)
	var level: int = maxi(int(area.requirements.get(&"character", 1)), Sim.auto_level(data, area) + level_offset)
	var grade: int = maxi(1, Sim.auto_grade(data, level) - grade_minus)
	var session: GameSession = Sim._new_session(data, seed_value)
	var xp_before: int = Sim._set_level(session, level)
	Sim._equip_set(session, grade, setup)
	Sim._fill_loadout(session, data)
	var food_id: StringName = Sim.food_for_grade(data, grade)
	session.bank.add(food_id, food_count)
	session.equipment.set_food(food_id)
	Sim._set_tier(session, Sim.auto_tier(data, level))
	session.deposit.register_occupant(&"sim:room", func() -> int: return -10000)
	var tally: Dictionary = {"events": 0, "hash": 17}
	_connect(session, tally)
	var total_ms: int = int(hours * 3600000.0)
	var elapsed: int = 0
	while elapsed < total_ms:
		if not session.combat.is_active() and not session.combat.start(area_id).ok:
			break
		var step: int = mini(SLICE_MS, total_ms - elapsed)
		session.advance(step)
		elapsed += step
		Sim._pin_level(session, xp_before)
	var kills: int = 0
	for count: int in session.combat.total_kills().values():
		kills += count
	var result: Dictionary = {"events": tally["events"], "hash": tally["hash"], "kills": kills,
		"deaths": session.combat.deaths(), "food": session.combat.food_eaten(),
		"rng": str(session.rng.to_save()["state"]).hash()}
	session.free()
	return result


static func _connect(session: GameSession, tally: Dictionary) -> void:
	var ev: EventBus = session.events
	ev.combat_hit.connect(func(a: int, t: int, h: bool, d: int, b: bool) -> void:
		_fold(tally, [1, a, t, int(h), d, int(b)]))
	ev.monster_killed.connect(func(i: int, id: StringName) -> void: _fold(tally, [2, i, String(id).hash()]))
	ev.player_hp_changed.connect(func(hp: int, max_hp: int) -> void: _fold(tally, [3, hp, max_hp]))
	ev.player_died.connect(func() -> void: _fold(tally, [4]))
	ev.ability_used.connect(func(id: StringName, targets: Array[int]) -> void:
		_fold(tally, [5, String(id).hash(), targets.size()] + targets))
	ev.trait_triggered.connect(func(id: StringName) -> void: _fold(tally, [6, String(id).hash()]))
	ev.encounter_started.connect(func(ids: Array[StringName]) -> void: _fold(tally, [7, ids.size()]))


static func _fold(tally: Dictionary, values: Array) -> void:
	tally["events"] += 1
	var h: int = tally["hash"]
	for v: int in values:
		h = (h * 1000003 + v + 1) & 0x7FFFFFFFFFFFFFFF
	tally["hash"] = h
