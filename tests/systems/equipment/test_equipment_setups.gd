extends GutTest
## Equipment by uid, part 2: setups (F-72, F-73), modifier sources, tool intervals and food. Part 1: test_equipment.gd.
## Fixture items: test_blade (sword), test_greatsword (two-handed), test_shield (offhand), unique_hatchet, test_ration.

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


func test_setup_derivation() -> void:
	var great: int = _piece(GREAT)
	var blade: int = _piece(BLADE)
	var blade2: int = _piece(BLADE)
	var shield: int = _piece(SHIELD)
	assert_eq(_session.equipment.setup(), Equipment.UNARMED)
	_session.equipment.equip(great)
	assert_eq(_session.equipment.setup(), &"greatsword")
	_session.equipment.equip(blade)
	assert_eq(_session.equipment.setup(), &"sword")
	_session.equipment.equip(shield)
	assert_eq(_session.equipment.setup(), &"sword_shield")
	assert_null(_session.equipment.offhand_weapon(), "a shield is not a weapon")
	_session.equipment.equip(blade2, &"offhand")
	assert_eq(_session.equipment.setup(), &"dual_swords")
	assert_eq(_session.equipment.offhand_weapon().id, BLADE)
	assert_false(_session.armory.is_worn(shield), "the shield went back")
	_session.equipment.unequip(&"weapon")
	assert_eq(_session.equipment.setup(), Equipment.UNARMED, "taking the weapon off took the sword off too")
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)
	assert_false(_session.armory.is_worn(blade2))
	_session.equipment.equip(shield)
	assert_eq(_session.equipment.setup(), Equipment.UNARMED, "no weapon with a shield")


func test_taking_the_weapon_off_keeps_a_shield() -> void:
	var blade: int = _piece(BLADE)
	var shield: int = _piece(SHIELD)
	_session.equipment.equip(blade)
	_session.equipment.equip(shield)
	assert_true(_session.equipment.unequip(&"weapon").ok)
	assert_eq(_session.equipment.get_uid(&"offhand"), shield)


func test_combinations_without_a_setup_are_refused() -> void:
	var blade: int = _piece(BLADE)
	var great: int = _piece(GREAT)
	assert_eq(_session.equipment.equip(blade, &"offhand").reason, Reasons.REQUIREMENT_NOT_MET, "no weapon: only a shield")
	assert_eq(_session.equipment.equip(great, &"offhand").reason, Reasons.NOT_EQUIPPABLE, "two-handed never offhand")
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)
	assert_false(_session.armory.is_worn(blade))


func test_setup_source_follows_the_setup() -> void:
	var blade: int = _piece(BLADE)
	var blade2: int = _piece(BLADE)
	_session.equipment.equip(blade)
	assert_true(_session.modifiers.has_source(&"setup:sword"))
	var before: float = _session.modifiers.total(&"accuracy_pct")
	_session.equipment.equip(blade2, &"offhand")
	assert_false(_session.modifiers.has_source(&"setup:sword"))
	assert_true(_session.modifiers.has_source(&"setup:dual_swords"))
	assert_eq(_session.modifiers.total(&"accuracy_pct"), before - 10.0)
	_session.equipment.unequip(&"offhand")
	assert_false(_session.modifiers.has_source(&"setup:dual_swords"))
	assert_eq(_session.modifiers.total(&"accuracy_pct"), before)
	_session.equipment.unequip(&"weapon")
	assert_false(_session.modifiers.has_source(&"setup:sword"))


func test_style_and_interval_follow_weapon_or_unarmed() -> void:
	var unarmed_style: StringName = StringName(str(_session.data.balance_value("combat.unarmed.style")))
	var unarmed_ms: int = int(_session.data.balance_value("combat.unarmed.attack_interval_ms"))
	assert_eq(_session.equipment.style(), unarmed_style)
	assert_eq(_session.equipment.base_attack_interval_ms(), unarmed_ms)
	_session.equipment.equip(_piece(GREAT))
	assert_eq(_session.equipment.style(), &"blade")
	assert_eq(_session.equipment.base_attack_interval_ms(), 3200)
	assert_eq(_session.equipment.weapon().id, GREAT)


func test_dual_wield_interval_f73() -> void:
	_session.equipment.equip(_piece(BLADE))
	assert_eq(_session.equipment.base_attack_interval_ms(), 2400, "one sword: its own interval")
	_session.equipment.equip(_piece(BLADE), &"offhand")
	assert_eq(_session.equipment.base_attack_interval_ms(), 1800, "2400 and 2400 -> 1800")


func test_modifier_sources_follow_slots() -> void:
	var helm: int = _piece(HELM)
	var blade: int = _piece(BLADE)
	_session.equipment.equip(helm)
	_session.equipment.equip(blade)
	assert_true(_session.modifiers.has_source(&"equipment:head"))
	assert_eq(_session.modifiers.total(&"armor"), 2.0)
	assert_eq(_session.modifiers.total(&"accuracy_bonus"), 8.0)
	_session.equipment.unequip(&"head")
	assert_false(_session.modifiers.has_source(&"equipment:head"))
	assert_eq(_session.modifiers.total(&"armor"), 0.0)


func test_swap_rebuilds_the_modifiers_once() -> void:
	var shield: int = _piece(SHIELD)
	var great: int = _piece(GREAT)
	_session.equipment.equip(shield)
	var changes: Array[int] = [0]
	_session.events.modifiers_changed.connect(func() -> void: changes[0] += 1)
	_session.equipment.equip(great)
	assert_eq(changes[0], 1, "weapon in, offhand out: one batch")


func test_a_unique_tool_is_worn_without_effect_outside_its_skill() -> void:
	# M10: a unique tool acts on the skill of its slot (F-94, scope skill:forestry); the legacy fixtures have no forestry,
	# so only the equipping is checked here (the interval effect is tested in tests/systems/armory/test_upgrade_tool.gd).
	assert_eq(_session.actions.current_interval_ms(TWIG), 3000)
	var hatchet: int = _piece(HATCHET)
	assert_true(_session.equipment.equip(hatchet).ok)
	assert_eq(_session.equipment.get_item(&"tool_forestry"), HATCHET)
	assert_eq(_session.actions.current_interval_ms(TWIG), 3000, "no effect on a skill that is not forestry")


func test_food_set_and_errors() -> void:
	assert_eq(_session.equipment.set_food(&"nope").reason, Reasons.UNKNOWN_ID)
	TestFactory.give(_session, &"test_log", 1)
	assert_eq(_session.equipment.set_food(&"test_log").reason, Reasons.NOT_FOOD)
	assert_eq(_session.equipment.set_food(RATION).reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(_session, RATION, 3)
	watch_signals(_session.events)
	assert_true(_session.equipment.set_food(RATION).ok)
	assert_eq(_session.equipment.get_food(), RATION)
	assert_eq(_session.bank.get_count(RATION), 3)
	assert_signal_emitted_with_parameters(_session.events, "food_changed", [RATION])
	assert_signal_not_emitted(_session.events, "equipment_changed")
	assert_true(_session.equipment.set_food(&"").ok)
	assert_eq(_session.equipment.get_food(), &"")
