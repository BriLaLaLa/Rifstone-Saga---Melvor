extends GutTest
## Loadout (M6-01): F-78 slot counts, set_trait/set_ability and their reasons, active lists by setup, trait modifiers
## (source trait:<id>), signals, save and session integration. Fixture class: test traits/abilities of rift_blade.json.

const CLEAVE: StringName = &"test_cleave"
const CUT: StringName = &"test_cut"          # greatsword only, level 10, +5 accuracy_pct
const REFLECT: StringName = &"test_reflect"  # level 10
const OPENING: StringName = &"test_opening"  # level 25
const WHIRL: StringName = &"test_whirl"      # greatsword only
const STRIKE: StringName = &"test_strike"
const MEND: StringName = &"test_mend"        # level 30
const GUARD: StringName = &"test_guard"      # sword_shield only

var _session: GameSession
var _loadout: Loadout
var _changed: int = 0


func before_each() -> void:
	_session = autofree(TestFactory.session())
	_loadout = _session.loadout
	_changed = 0
	_session.events.traits_changed.connect(func() -> void: _changed += 1)


func _level(level: int) -> void:
	TestFactory.set_character_level(_session, level)


func _wear(base_id: StringName, slot: StringName = &"") -> void:
	assert_true(_session.equipment.equip(TestFactory.give_piece(_session, base_id), slot).ok)


func test_slot_counts_f78() -> void:
	var expected: Array = [[1, 1, 2], [10, 2, 2], [25, 3, 2], [30, 3, 3], [50, 4, 3], [99, 4, 3]]
	for row: Array in expected:
		_level(int(row[0]))
		assert_eq(_loadout.trait_slots(), int(row[1]), "trait slots at level %d" % int(row[0]))
		assert_eq(_loadout.ability_slots(), int(row[2]), "ability slots at level %d" % int(row[0]))


func test_new_game_is_empty() -> void:
	assert_eq(_loadout.get_trait(0), &"")
	assert_eq(_loadout.get_ability(1), &"")
	assert_eq(_loadout.get_trait(99), &"", "an index outside the table is empty")
	assert_true(_loadout.active_traits().is_empty())
	assert_true(_loadout.active_abilities().is_empty())


func test_set_trait_success_signals_once() -> void:
	assert_true(_loadout.set_trait(0, CLEAVE).ok)
	assert_eq(_loadout.get_trait(0), CLEAVE)
	assert_eq(_changed, 1)
	assert_true(_loadout.set_trait(0, CLEAVE).ok, "the same trait again changes nothing")
	assert_eq(_changed, 1)
	assert_true(_loadout.set_trait(0, &"").ok)
	assert_eq(_loadout.get_trait(0), &"")
	assert_eq(_changed, 2)


func test_set_trait_reasons() -> void:
	assert_eq(_loadout.set_trait(1, CLEAVE).reason, Reasons.SLOT_LOCKED, "slot 1 opens at level 10")
	assert_eq(_loadout.set_trait(-1, CLEAVE).reason, Reasons.SLOT_LOCKED)
	assert_eq(_loadout.set_trait(0, &"ghost").reason, Reasons.UNKNOWN_ID)
	assert_eq(_loadout.set_trait(0, WHIRL).reason, Reasons.UNKNOWN_ID, "an ability is not a trait")
	assert_eq(_loadout.set_trait(0, REFLECT).reason, Reasons.LEVEL_TOO_LOW)
	assert_eq(_changed, 0)
	_level(10)
	_loadout.set_trait(0, CLEAVE)
	assert_eq(_loadout.set_trait(1, CLEAVE).reason, Reasons.REQUIREMENT_NOT_MET, "already in slot 0")
	assert_eq(_loadout.get_trait(1), &"")


func test_set_ability_reasons() -> void:
	assert_eq(_loadout.set_ability(2, STRIKE).reason, Reasons.SLOT_LOCKED, "slot 2 opens at level 30")
	assert_eq(_loadout.set_ability(0, &"ghost").reason, Reasons.UNKNOWN_ID)
	assert_eq(_loadout.set_ability(0, MEND).reason, Reasons.LEVEL_TOO_LOW)
	assert_true(_loadout.set_ability(0, STRIKE).ok)
	assert_true(_loadout.set_ability(1, WHIRL).ok)
	assert_eq(_loadout.set_ability(1, STRIKE).reason, Reasons.REQUIREMENT_NOT_MET)
	assert_eq(_changed, 2)


func test_changes_are_refused_during_an_encounter() -> void:
	assert_true(_loadout.set_trait(0, CLEAVE).ok)
	assert_true(_session.combat.start(&"test_area").ok)
	assert_true(_session.combat.in_encounter())
	assert_eq(_loadout.set_trait(0, &"").reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_loadout.set_ability(0, STRIKE).reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_loadout.get_trait(0), CLEAVE, "nothing changed")


func test_active_lists_follow_the_setup_in_slot_order() -> void:
	_level(10)
	_loadout.set_trait(0, CUT)
	_loadout.set_trait(1, REFLECT)
	_loadout.set_ability(0, GUARD)
	_loadout.set_ability(1, STRIKE)
	assert_eq(_session.equipment.setup(), Equipment.UNARMED)
	assert_eq(_trait_ids(), [REFLECT], "unarmed: CUT needs the greatsword")
	assert_eq(_ability_ids(), [STRIKE])
	_wear(&"test_greatsword")
	assert_eq(_trait_ids(), [CUT, REFLECT])
	assert_eq(_ability_ids(), [STRIKE])
	_wear(&"test_blade")
	_wear(&"test_shield")
	assert_eq(_session.equipment.setup(), &"sword_shield")
	assert_eq(_trait_ids(), [REFLECT])
	assert_eq(_ability_ids(), [GUARD, STRIKE])


func test_lists_ignore_slots_not_open() -> void:
	_level(10)
	_loadout.set_trait(1, REFLECT)
	_session.character.from_save({"class": String(_session.character.class_id()), "xp": 0})
	assert_eq(_loadout.trait_slots(), 1)
	assert_true(_loadout.active_traits().is_empty(), "slot 1 is closed again")


func test_trait_modifiers_follow_the_setup() -> void:
	_level(10)
	_loadout.set_trait(0, CUT)
	var acc: StringName = &"accuracy_pct"
	assert_eq(_session.modifiers.total(acc), 0.0, "unarmed: the trait is not active")
	assert_false(_session.modifiers.has_source(&"trait:test_cut"))
	_wear(&"test_greatsword")
	assert_true(_session.modifiers.has_source(&"trait:test_cut"))
	assert_eq(_session.modifiers.total(acc), 5.0)
	_wear(&"test_blade")
	assert_eq(_session.modifiers.total(acc), 0.0, "sword: the source is gone")
	assert_false(_session.modifiers.has_source(&"trait:test_cut"))
	_wear(&"test_greatsword")
	_loadout.set_trait(0, &"")
	assert_eq(_session.modifiers.total(acc), 0.0)
	assert_false(_session.modifiers.has_source(&"trait:test_cut"))


func test_save_roundtrip_is_identical() -> void:
	_level(30)
	_loadout.set_trait(0, CLEAVE)
	_loadout.set_trait(2, OPENING)
	_loadout.set_ability(1, MEND)
	var saved: Dictionary = _loadout.to_save()
	assert_eq(saved["traits"], ["test_cleave", "", "test_opening", ""])
	assert_eq(saved["abilities"], ["", "test_mend", ""])
	var other: GameSession = autofree(TestFactory.session())
	TestFactory.set_character_level(other, 30)
	other.loadout.from_save(saved)
	assert_eq(other.loadout.to_save(), saved)
	assert_eq(other.loadout.get_ability(1), MEND)


func test_from_save_drops_invalid_entries_with_a_warning() -> void:
	_level(10)
	_loadout.from_save({
		"traits": ["ghost", "test_cut", "test_cut", "test_opening"],
		"abilities": ["test_mend", "test_strike", "test_strike", 7],
	})
	assert_eq(_loadout.to_save()["traits"], ["", "test_cut", "", ""], "unknown, duplicated, not unlocked and closed")
	assert_eq(_loadout.to_save()["abilities"], ["", "test_strike", ""], "not unlocked, kept, closed")


func test_from_save_missing_keys_start_empty() -> void:
	_loadout.set_trait(0, CLEAVE)
	_loadout.from_save({})
	assert_eq(_loadout.get_trait(0), &"")
	assert_eq((_loadout.to_save()["traits"] as Array).size(), 4)


func test_equipment_change_emits_no_traits_changed() -> void:
	_wear(&"test_greatsword")
	assert_eq(_changed, 0)


func test_session_save_and_load_rebuilds_trait_modifiers() -> void:
	_level(10)
	_wear(&"test_greatsword")
	_loadout.set_trait(0, CUT)
	var file: Dictionary = _session.to_save(1)
	var other: GameSession = autofree(TestFactory.session())
	assert_true(other.from_save(JSON.parse_string(JSON.stringify(file)) as Dictionary).ok)
	assert_eq(other.loadout.get_trait(0), CUT)
	assert_eq(other.modifiers.total(&"accuracy_pct"), 5.0)
	assert_true(other.modifiers.has_source(&"trait:test_cut"))


func test_new_game_clears_the_loadout() -> void:
	_loadout.set_trait(0, CLEAVE)
	_session.new_game()
	assert_eq(_loadout.get_trait(0), &"")


func _trait_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def: TraitDef in _loadout.active_traits():
		result.append(def.id)
	return result


func _ability_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def: AbilityDef in _loadout.active_abilities():
		result.append(def.id)
	return result
