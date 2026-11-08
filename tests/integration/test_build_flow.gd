extends GutTest
## Integration, build flow (M6): character level opens slots -> choose traits and abilities with the real class data ->
## the build changes how the fight goes (traits fire, abilities are used) -> the setup filters what is active -> the
## loadout is locked during an encounter -> save/load mid-fight gives the same continuation -> the loadout never
## creates or moves items. Also a smoke over every trait and ability of rift_blade.
##
## Real data, fixed seeds, only public APIs (docs/05_INTERFACES.md 5.10, 5.16b, 6). No slot is written.

const SEED: int = 6006
const OTHER_SEED: int = 31
const NOW_MS: int = 1793603600000
const AREA: StringName = &"redrock_plains"
const SWORD: StringName = &"emberbronze_sword"
const SHIELD: StringName = &"emberbronze_shield"
const BOOST: StringName = &"test:flow"
const BIG_HP: float = 100000.0
const STEP_MS: int = 1000
const FIGHT_MS: int = 600000
const LEVEL: int = 30
const GREATSWORD: StringName = &"emberbronze_greatsword"

var _triggered: Array[StringName] = []
var _used: Array[StringName] = []
var _kills: int = 0
var _changed: int = 0


# A real-data session at `level` with a sword (+ `offhand` if given) worn and a practically immortal player.
func _build(seed_value: int, offhand: StringName = SHIELD, level: int = LEVEL) -> GameSession:
	var s: GameSession = autofree(TestFactory.session_no_kit(seed_value, TestFactory.real_data()))
	TestFactory.set_character_level(s, level)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SWORD)).ok)
	if offhand != &"":
		assert_true(s.equipment.equip(TestFactory.give_piece(s, offhand)).ok)
	s.modifiers.set_source(BOOST, [Modifier.make(&"max_hp_flat", BIG_HP)])
	_hook(s)
	return s


func _hook(s: GameSession) -> void:
	_triggered = []
	_used = []
	_kills = 0
	_changed = 0
	s.events.trait_triggered.connect(func(id: StringName) -> void: _triggered.append(id))
	s.events.ability_used.connect(func(id: StringName, _t: Array[int]) -> void: _used.append(id))
	s.events.monster_killed.connect(func(_i: int, _m: StringName) -> void: _kills += 1)
	s.events.traits_changed.connect(func() -> void: _changed += 1)


func _run(s: GameSession, total_ms: int, step_ms: int = STEP_MS) -> void:
	for i: int in total_ms / step_ms:
		s.advance(step_ms)


func _blob(s: GameSession) -> String:
	return SaveCodec.encode(s.to_save(NOW_MS))


func _inventory(s: GameSession) -> Dictionary:
	return {"bank": s.bank.to_save(), "armory": s.armory.to_save(), "worn": s.equipment.to_save()}


# --- slots and choice ------------------------------------------------------------------------------------------

func test_slots_open_with_the_character_level() -> void:
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	assert_eq(s.loadout.trait_slots(), 1, "level 1: one trait slot")
	assert_eq(s.loadout.ability_slots(), 2, "level 1: two ability slots")
	TestFactory.set_character_level(s, LEVEL)
	assert_eq(s.loadout.trait_slots(), 3, "level 30: three trait slots")
	assert_eq(s.loadout.ability_slots(), 3, "level 30: three ability slots")
	assert_eq(s.loadout.set_trait(3, &"chain_cleave").reason, Reasons.SLOT_LOCKED, "the fourth slot opens at 50")


func test_choice_rules_with_real_ids() -> void:
	var s: GameSession = _build(SEED, SHIELD, 12)
	assert_true(s.loadout.set_trait(0, &"chain_cleave").ok)
	assert_eq(_changed, 1, "traits_changed once")
	assert_eq(s.loadout.set_trait(1, &"chain_cleave").reason, Reasons.REQUIREMENT_NOT_MET, "duplicate")
	assert_eq(s.loadout.set_trait(1, &"nothing").reason, Reasons.UNKNOWN_ID)
	assert_eq(s.loadout.set_trait(1, &"blood_ember").reason, Reasons.LEVEL_TOO_LOW, "blood_ember needs 20")
	assert_true(s.loadout.set_trait(0, &"").ok, "empty removes")
	assert_eq(s.loadout.get_trait(0), &"")
	assert_true(s.loadout.set_ability(0, &"shield_bash").ok)
	assert_eq(s.loadout.set_ability(1, &"shield_bash").reason, Reasons.REQUIREMENT_NOT_MET, "duplicate")
	assert_true(s.loadout.set_ability(1, &"ember_breath").ok, "level 8 ability at level 12")


# --- the build changes the fight ---------------------------------------------------------------------------------

func test_traits_change_how_the_fight_goes() -> void:
	# Summed over three seeds: the loot tables of M12 draw from the same stream, so a single seed is too lucky to compare.
	var plain_kills: int = 0
	var built_kills: int = 0
	for seed_value: int in [SEED, OTHER_SEED, 77]:
		var plain: GameSession = _build(seed_value)
		assert_true(plain.combat.start(AREA).ok)
		_run(plain, FIGHT_MS)
		plain_kills += _kills
		assert_eq(_triggered.size(), 0, "no trait, no trait_triggered")
		var built: GameSession = _build(seed_value)
		assert_true(built.loadout.set_trait(0, &"ember_thirst").ok)
		assert_true(built.loadout.set_trait(1, &"chain_cleave").ok)
		assert_true(built.combat.start(AREA).ok)
		_run(built, FIGHT_MS)
		built_kills += _kills
		assert_true(_triggered.has(&"ember_thirst"), "ember_thirst fired: %s" % [_triggered.slice(0, 5)])
		assert_true(_triggered.has(&"chain_cleave"), "chain_cleave fired")
	assert_gt(built_kills, plain_kills, "timer cut and cleave kill more than the plain build in the same time")


func test_abilities_are_used_and_respect_the_cooldown() -> void:
	var s: GameSession = _build(SEED)
	assert_true(s.loadout.set_ability(0, &"shield_bash").ok)
	assert_true(s.combat.start(AREA).ok)
	var listed: Array = s.combat.get_state()["abilities"]
	assert_eq(listed.size(), 1)
	assert_eq(listed[0]["id"], &"shield_bash")
	_run(s, 120000)
	assert_gt(_used.size(), 0, "ability_used emitted")
	assert_lte(_used.size(), 120000 / 7000 + 1, "at most one use per 7 s cooldown (F-79)")
	for id: StringName in _used:
		assert_eq(id, &"shield_bash")


func test_the_setup_filters_active_traits_and_abilities_but_keeps_the_choice() -> void:
	var s: GameSession = _build(SEED, SHIELD, 15)
	assert_true(s.loadout.set_trait(0, &"rift_thorns").ok, "sword_shield only")
	assert_true(s.loadout.set_trait(1, &"chain_cleave").ok, "all setups")
	assert_true(s.loadout.set_ability(0, &"shield_bash").ok)
	assert_eq(s.equipment.setup(), &"sword_shield")
	assert_eq(s.loadout.active_traits().size(), 2)
	assert_eq(s.loadout.active_abilities().size(), 1)
	assert_true(s.equipment.unequip(&"offhand").ok, "back to the plain sword setup")
	assert_eq(s.equipment.setup(), &"sword")
	var traits: Array[TraitDef] = s.loadout.active_traits()
	assert_eq(traits.size(), 1, "rift_thorns is not active without the shield")
	assert_eq(traits[0].id, &"chain_cleave")
	assert_eq(s.loadout.active_abilities().size(), 0, "shield_bash is not active")
	assert_false(s.modifiers.has_source(&"trait:rift_thorns"))
	assert_eq(s.loadout.get_trait(0), &"rift_thorns", "the choice is kept in the slot")
	assert_eq(s.loadout.get_ability(0), &"shield_bash")
	assert_true(s.equipment.equip(TestFactory.give_piece(s, SHIELD)).ok)
	assert_eq(s.loadout.active_traits().size(), 2, "back with the shield")
	assert_eq(s.loadout.active_abilities().size(), 1)


func test_stat_trade_trait_changes_the_player_stats_and_is_removed() -> void:
	var s: GameSession = _build(SEED, SHIELD, 12)
	s.modifiers.set_source(BOOST, [Modifier.make(&"damage_reduction", 10.0), Modifier.make(&"evasion_bonus", 20.0)])
	var before: CombatantStats = s.combat.player_stats()
	assert_gt(before.damage_reduction, 0.0)
	assert_true(s.loadout.set_trait(0, &"stone_stance").ok)
	var after: CombatantStats = s.combat.player_stats()
	assert_gt(after.block_chance, before.block_chance, "stone_stance: +10 block_chance")
	assert_gt(after.damage_reduction, before.damage_reduction, "stone_stance doubles the damage reduction")
	assert_lt(after.evasion, before.evasion, "stone_stance gives up the evasion bonus")
	assert_true(s.loadout.set_trait(0, &"").ok)
	var restored: CombatantStats = s.combat.player_stats()
	assert_eq(restored.damage_reduction, before.damage_reduction, "removed: the base is back")
	assert_eq(restored.block_chance, before.block_chance)
	assert_eq(restored.evasion, before.evasion)


# --- locked during an encounter ------------------------------------------------------------------------------------

func test_loadout_is_locked_during_an_encounter_and_free_afterwards() -> void:
	var s: GameSession = _build(SEED)
	assert_true(s.loadout.set_trait(0, &"chain_cleave").ok)
	assert_true(s.combat.start(AREA).ok)
	s.advance(10)
	assert_true(s.combat.in_encounter())
	assert_eq(s.loadout.set_trait(1, &"first_blood").reason, Reasons.COMBAT_ACTIVE)
	assert_eq(s.loadout.set_ability(0, &"shield_bash").reason, Reasons.COMBAT_ACTIVE)
	assert_eq(s.loadout.set_trait(0, &"").reason, Reasons.COMBAT_ACTIVE, "even removing")
	assert_eq(s.loadout.get_trait(0), &"chain_cleave", "nothing changed")
	s.combat.stop()
	assert_true(s.loadout.set_trait(1, &"first_blood").ok, "free again")


# --- save and load -----------------------------------------------------------------------------------------------------

func test_save_mid_fight_gives_the_same_continuation() -> void:
	var a: GameSession = _build(SEED, SHIELD, 25)
	a.modifiers.set_source(BOOST, [])  # natural HP: the loaded session has no test source, so the fight can hurt
	var picks: Array[StringName] = [&"chain_cleave", &"ember_thirst", &"blood_ember"]
	for slot: int in picks.size():
		assert_true(a.loadout.set_trait(slot, picks[slot]).ok, "trait %s" % picks[slot])
	assert_true(a.loadout.set_ability(0, &"shield_bash").ok)
	assert_true(a.loadout.set_ability(1, &"ember_breath").ok)
	assert_true(a.combat.start(AREA).ok)
	_run(a, 90000)
	var blob: String = _blob(a)
	var b: GameSession = autofree(TestFactory.session_no_kit(OTHER_SEED, TestFactory.real_data()))
	assert_true(b.from_save(SaveCodec.decode(blob)).ok)
	assert_eq(b.loadout.get_trait(2), &"blood_ember")
	assert_eq(b.loadout.get_ability(1), &"ember_breath")
	assert_true(b.modifiers.has_source(&"ability:shield_bash") == a.modifiers.has_source(&"ability:shield_bash"))
	assert_eq(b.combat.get_state()["abilities"], a.combat.get_state()["abilities"], "cooldowns survive the load")
	assert_eq(_differing_modules(a, b), [] as Array[String], "modules that differ after the load")
	_run(a, 120000)
	_run(b, 120000)
	assert_eq(_differing_modules(a, b), [] as Array[String], "modules that differ after the same continuation")


func test_save_with_an_unknown_trait_id_loads_empty_without_breaking_the_game() -> void:
	var a: GameSession = _build(SEED)
	assert_true(a.loadout.set_trait(0, &"chain_cleave").ok)
	var d: Dictionary = a.to_save(NOW_MS)
	assert_true(d["modules"].has("loadout"), "the loadout is saved under modules.loadout")
	d["modules"]["loadout"]["traits"] = ["gone_trait", "chain_cleave"]
	var b: GameSession = autofree(TestFactory.session_no_kit(OTHER_SEED, TestFactory.real_data()))
	assert_true(b.from_save(SaveCodec.decode(SaveCodec.encode(d))).ok)
	assert_eq(b.loadout.get_trait(0), &"", "unknown id dropped")
	assert_eq(b.loadout.get_trait(1), &"chain_cleave", "the valid one in its slot stays")
	assert_true(b.combat.start(AREA).ok)
	_run(b, 30000)


func test_new_game_clears_the_loadout() -> void:
	var s: GameSession = _build(SEED)
	assert_true(s.loadout.set_trait(0, &"chain_cleave").ok)
	assert_true(s.loadout.set_ability(0, &"shield_bash").ok)
	s.new_game()
	assert_eq(s.loadout.get_trait(0), &"")
	assert_eq(s.loadout.get_ability(0), &"")
	assert_false(s.modifiers.has_source(&"trait:chain_cleave"))


# --- items stay in one place ------------------------------------------------------------------------------------------

func test_the_loadout_never_creates_or_moves_items() -> void:
	var s: GameSession = _build(SEED)
	var before: Dictionary = _inventory(s)
	assert_true(s.loadout.set_trait(0, &"chain_cleave").ok)
	assert_true(s.loadout.set_ability(0, &"shield_bash").ok)
	assert_eq(_inventory(s), before, "choosing changes no item")
	assert_true(s.equipment.unequip(&"offhand").ok)
	assert_true(s.equipment.equip(s.armory.instances()[1].uid).ok, "the same shield, worn again")
	assert_eq(s.armory.instances().size(), 2, "no copy appeared")
	assert_eq(s.armory.used(), 0, "both pieces are worn")


# --- every real trait and ability ---------------------------------------------------------------------------------------

# The gear of a class setup (data/classes/rift_blade.json): [weapon, offhand].
func _gear_for(setup: StringName) -> Array[StringName]:
	match setup:
		&"greatsword":
			return [GREATSWORD, &""]
		&"dual_swords":
			return [SWORD, SWORD]
		&"sword":
			return [SWORD, &""]
	return [SWORD, SHIELD]


# A session at `level` wearing the gear of the first setup in `setups` (empty = any: sword and shield).
func _session_for(setups: Array[StringName], level: int) -> GameSession:
	var setup: StringName = &"sword_shield" if setups.is_empty() else setups[0]
	var gear: Array[StringName] = _gear_for(setup)
	var s: GameSession = autofree(TestFactory.session_no_kit(SEED, TestFactory.real_data()))
	TestFactory.set_character_level(s, level)
	assert_true(s.equipment.equip(TestFactory.give_piece(s, gear[0])).ok)
	if gear[1] != &"":
		assert_true(s.equipment.equip(TestFactory.give_piece(s, gear[1]), &"offhand").ok)
	assert_eq(s.equipment.setup(), setup, "gear for %s" % setup)
	s.modifiers.set_source(BOOST, [Modifier.make(&"max_hp_flat", BIG_HP)])
	_hook(s)
	return s


func test_every_trait_of_the_class_can_be_chosen_and_fought_with() -> void:
	var def: ClassDef = TestFactory.real_data().character_class(&"rift_blade")
	assert_not_null(def)
	assert_eq(def.traits.size(), 12)
	for t: TraitDef in def.traits:
		var s: GameSession = _session_for(t.setups, maxi(LEVEL, t.unlock_level))
		assert_true(s.loadout.set_trait(0, t.id).ok, "%s can be chosen" % t.id)
		assert_eq(s.loadout.active_traits().size(), 1, "%s is active in %s" % [t.id, s.equipment.setup()])
		assert_true(s.combat.start(AREA).ok)
		_run(s, 120000)
		assert_gt(_kills, 0, "%s: the fight goes on" % t.id)
		s.combat.stop()


func test_every_ability_of_the_class_is_used_in_its_setup() -> void:
	var def: ClassDef = TestFactory.real_data().character_class(&"rift_blade")
	assert_eq(def.abilities.size(), 6)
	for a: AbilityDef in def.abilities:
		var s: GameSession = _session_for(a.setups, maxi(LEVEL, a.unlock_level))
		assert_true(s.loadout.set_ability(0, a.id).ok, "%s can be chosen" % a.id)
		assert_eq(s.loadout.active_abilities().size(), 1, "%s active in %s" % [a.id, s.equipment.setup()])
		assert_true(s.combat.start(AREA).ok)
		_run(s, 120000)
		assert_true(_used.has(a.id), "%s was used in 2 minutes (setup %s)" % [a.id, s.equipment.setup()])
		s.combat.stop()


# Names the modules whose save differs (diagnostics for the identical-save assertions).
func _differing_modules(a: GameSession, b: GameSession) -> Array[String]:
	var da: Dictionary = a.to_save(NOW_MS)["modules"]
	var db: Dictionary = b.to_save(NOW_MS)["modules"]
	var out: Array[String] = []
	for key: String in da:
		if JSON.stringify(da[key], "", true) != JSON.stringify(db.get(key), "", true):
			out.append(key)
	return out
