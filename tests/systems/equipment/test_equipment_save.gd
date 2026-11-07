extends GutTest
## Equipment save: round trip with sources and setup, tolerant from_save (docs/05_INTERFACES.md §5.9), new_game.

const BLADE: StringName = &"test_blade"
const GREAT: StringName = &"test_greatsword"
const SHIELD: StringName = &"test_shield"
const HELM: StringName = &"test_helm"
const HATCHET: StringName = &"unique_hatchet"
const RATION: StringName = &"test_ration"
const TWIG: StringName = &"gather_twig"

var _session: GameSession = null


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _piece(base_id: StringName) -> int:
	return TestFactory.give_piece(_session, base_id)


func test_save_round_trip_restores_state_and_sources() -> void:
	var hatchet: int = _piece(HATCHET)
	var blade: int = _piece(BLADE)
	var blade2: int = _piece(BLADE)
	TestFactory.give(_session, RATION, 1)
	_session.equipment.equip(hatchet)
	_session.equipment.equip(blade)
	_session.equipment.equip(blade2, &"offhand")
	_session.equipment.set_food(RATION)
	var saved: Dictionary = _session.to_save(0)
	var section: Dictionary = (saved["modules"] as Dictionary)["equipment"]
	assert_eq((section["slots"] as Dictionary)["weapon"], blade)
	assert_false(section.has("stance"))
	var other: GameSession = autofree(TestFactory.session(99))
	assert_true(other.from_save(saved).ok)
	assert_eq(other.equipment.get_uid(&"weapon"), blade)
	assert_eq(other.equipment.get_uid(&"offhand"), blade2)
	assert_eq(other.equipment.get_uid(&"tool_forestry"), hatchet)
	assert_true(other.armory.is_worn(blade2))
	assert_eq(other.equipment.get_food(), RATION)
	assert_eq(other.equipment.setup(), &"dual_swords")
	assert_true(other.modifiers.has_source(&"setup:dual_swords"))
	assert_eq(other.modifiers.total(&"power_bonus"), 12.0)
	assert_eq(other.equipment.base_attack_interval_ms(), 1800)


func test_from_save_json_floats_are_accepted() -> void:
	var blade: int = _piece(BLADE)
	_session.equipment.from_save({"slots": {"weapon": float(blade)}})
	assert_eq(_session.equipment.get_uid(&"weapon"), blade)


func test_from_save_skips_invalid_entries_and_keeps_the_pieces() -> void:
	var blade: int = _piece(BLADE)
	var helm: int = _piece(HELM)
	var shield: int = _piece(SHIELD)
	_session.equipment.from_save({"slots": {"head": blade, "weapon": 99, "tail": helm, "offhand": shield,
			"body": "x", "ring": helm}, "food": "test_helm", "stance": "x"})
	assert_eq(_session.equipment.get_uid(&"head"), 0, "a sword does not fit the head")
	assert_eq(_session.equipment.get_uid(&"weapon"), 0, "uid not in the Armory")
	assert_eq(_session.equipment.get_uid(&"body"), 0)
	assert_eq(_session.equipment.get_uid(&"offhand"), shield, "a shield without a weapon is valid")
	assert_eq(_session.equipment.get_uid(&"ring"), 0, "the helm does not fit the ring")
	assert_true(_session.armory.has(blade) and not _session.armory.is_worn(blade), "the piece stays, not worn")
	assert_eq(_session.equipment.get_food(), &"")


func test_from_save_uid_used_in_two_slots_stays_in_the_first() -> void:
	var blade: int = _piece(BLADE)
	_session.equipment.from_save({"slots": {"weapon": blade, "offhand": blade}})
	assert_eq(_session.equipment.get_uid(&"weapon"), blade)
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)


func test_from_save_combination_without_a_setup_empties_the_offhand() -> void:
	var blade: int = _piece(BLADE)
	_session.equipment.from_save({"slots": {"offhand": blade}})
	assert_eq(_session.equipment.get_uid(&"offhand"), 0, "a sword without a weapon has no setup")
	assert_false(_session.armory.is_worn(blade))


func test_from_save_two_handed_weapon_with_shield_drops_the_offhand() -> void:
	var great: int = _piece(GREAT)
	var shield: int = _piece(SHIELD)
	watch_signals(_session.events)
	_session.equipment.from_save({"slots": {"offhand": shield, "weapon": great}})
	assert_eq(_session.equipment.get_uid(&"weapon"), great)
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)
	assert_false(_session.armory.is_worn(shield))
	assert_signal_not_emitted(_session.events, "equipment_changed")
	assert_signal_not_emitted(_session.events, "armory_changed")


func test_new_game_resets() -> void:
	var helm: int = _piece(HELM)
	_session.equipment.equip(helm)
	_session.new_game()
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_false(_session.modifiers.has_source(&"equipment:head"))
	assert_eq(_session.armory.instances().size(), ArmoryKit.pieces(_session.data).size(), "only the kit is left")
