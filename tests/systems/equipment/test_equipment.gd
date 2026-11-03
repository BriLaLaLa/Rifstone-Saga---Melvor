extends GutTest
## Equipment by uid: equip/unequip rules, two-handed weapons, character and class requirements, setups (F-72, F-73),
## full Armory, combat lock, food, sources equipment:<slot> and setup:<id>. Save: test_equipment_save.gd.
##
## Fixture items: test_blade (sword, weapon), test_greatsword (two-handed), test_shield (offhand), test_helm (head),
## test_helm_high (head, character 10), test_hatchet (tool_forestry, requires test_gather 1), test_ration (food).

const BLADE: StringName = &"test_blade"
const GREAT: StringName = &"test_greatsword"
const SHIELD: StringName = &"test_shield"
const HELM: StringName = &"test_helm"
const HELM_HIGH: StringName = &"test_helm_high"
const HATCHET: StringName = &"test_hatchet"
const RATION: StringName = &"test_ration"
const TWIG: StringName = &"gather_twig"
const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SMALL_ARMORY_SLOTS: int = 4

var _tmp_config: String = PreRun.test_dir("test_equipment").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null


class _FakeCombat extends RefCounted:
	var active: bool = false

	func in_encounter() -> bool:
		return active


class _CombatSession extends GameSession:
	var combat: Object = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["armory"] as Dictionary)["base_slots"] = SMALL_ARMORY_SLOTS
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_small_data = GameData.load_from_dirs(FIXTURE_ROOT, _tmp_config)


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func before_each() -> void:
	_session = autofree(TestFactory.session())


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# Session whose Armory has only SMALL_ARMORY_SLOTS places.
func _small() -> GameSession:
	assert_true(_small_data.is_valid(), "\n".join(_small_data.errors))
	return autofree(TestFactory.session(1234, _small_data))


# Session with a `combat` field, like the real GameSession will have.
func _with_combat() -> GameSession:
	var events: GameEvents = GameEvents.new()
	var session: _CombatSession = _CombatSession.new(TestFactory.fixture_data(), events, 1234)
	session.add_child(events)
	session.new_game()
	return autofree(session)


# Fills the Armory with unworn helmets until it is full.
func _fill_armory() -> void:
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, HELM)


func _fake_combat(active: bool) -> void:
	var combat: _FakeCombat = _FakeCombat.new()
	combat.active = active
	(_session as _CombatSession).combat = combat


func _piece(base_id: StringName) -> int:
	return TestFactory.give_piece(_session, base_id)


func test_new_game_is_empty() -> void:
	for slot: StringName in Equipment.SLOTS:
		assert_eq(_session.equipment.get_uid(slot), 0)
		assert_eq(_session.equipment.get_item(slot), &"")
	assert_eq(_session.equipment.get_food(), &"")
	assert_eq(_session.equipment.setup(), Equipment.UNARMED)
	assert_null(_session.equipment.setup_def())
	assert_null(_session.equipment.weapon())
	assert_null(_session.equipment.offhand_weapon())


func test_equip_flags_the_piece_worn_and_signals_the_uid() -> void:
	var uid: int = _piece(HELM)
	assert_eq(_session.armory.used(), 1)
	watch_signals(_session.events)
	assert_true(_session.equipment.equip(uid).ok)
	assert_eq(_session.equipment.get_uid(&"head"), uid)
	assert_eq(_session.equipment.get_item(&"head"), HELM)
	assert_eq(_session.equipment.slot_of(uid), &"head")
	assert_true(_session.armory.is_worn(uid))
	assert_eq(_session.armory.used(), 0, "a worn piece takes no place")
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"head", uid])


func test_equip_replaces_and_returns_previous_piece() -> void:
	var low: int = _piece(HELM)
	var high: int = _piece(HELM_HIGH)
	TestFactory.set_character_level(_session, 10)
	_session.equipment.equip(low)
	assert_true(_session.equipment.equip(high).ok)
	assert_eq(_session.equipment.get_uid(&"head"), high)
	assert_false(_session.armory.is_worn(low))
	assert_true(_session.armory.has(low), "the old piece stays in the Armory")
	assert_eq(_session.equipment.slot_of(low), &"")


func test_equip_errors() -> void:
	assert_eq(_session.equipment.equip(99).reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.equipment.equip(0).reason, Reasons.UNKNOWN_ID)
	var high: int = _piece(HELM_HIGH)
	assert_eq(_session.equipment.equip(high).reason, Reasons.REQUIREMENT_NOT_MET)
	assert_false(_session.armory.is_worn(high))
	var helm: int = _piece(HELM)
	assert_eq(_session.equipment.equip(helm, &"body").reason, Reasons.NOT_EQUIPPABLE, "wrong slot")
	assert_eq(_session.equipment.equip(helm, &"nowhere").reason, Reasons.NOT_EQUIPPABLE)
	assert_true(_session.equipment.equip(helm).ok)
	assert_eq(_session.equipment.equip(helm).reason, Reasons.NOT_EQUIPPABLE, "already worn")


func test_requirement_met_at_the_exact_character_level() -> void:
	var high: int = _piece(HELM_HIGH)
	TestFactory.set_character_level(_session, 9)
	assert_eq(_session.equipment.equip(high).reason, Reasons.REQUIREMENT_NOT_MET)
	TestFactory.set_character_level(_session, 10)
	assert_true(_session.equipment.equip(high).ok)


func test_tool_requires_its_skill_level_not_the_character() -> void:
	var hatchet: int = _piece(HATCHET)
	assert_true(_session.equipment.equip(hatchet).ok)
	assert_eq(_session.equipment.slot_of(hatchet), &"tool_forestry")


func test_swap_in_full_armory_works() -> void:
	_session = _small()
	var low: int = _piece(HELM)
	var high: int = _piece(HELM_HIGH)
	TestFactory.set_character_level(_session, 10)
	_session.equipment.equip(low)
	_fill_armory()
	assert_eq(_session.armory.used(), _session.armory.capacity(), "Armory must be full")
	assert_true(_session.equipment.equip(high).ok, "the piece worn leaves a place for the one that returns")
	assert_eq(_session.armory.used(), _session.armory.capacity())


func test_two_handed_weapon_returns_offhand() -> void:
	var shield: int = _piece(SHIELD)
	var great: int = _piece(GREAT)
	_session.equipment.equip(shield)
	watch_signals(_session.events)
	assert_true(_session.equipment.equip(great).ok)
	assert_eq(_session.equipment.get_item(&"weapon"), GREAT)
	assert_eq(_session.equipment.get_uid(&"offhand"), 0)
	assert_false(_session.armory.is_worn(shield))
	assert_false(_session.modifiers.has_source(&"equipment:offhand"))
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"offhand", 0], 0)
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"weapon", great], 1)


func test_equipment_changed_emits_emptied_slots_before_the_occupied_one() -> void:
	var shield: int = _piece(SHIELD)
	var great: int = _piece(GREAT)
	_session.equipment.equip(shield)
	var order: Array[StringName] = []
	_session.events.equipment_changed.connect(func(slot: StringName, _uid: int) -> void: order.append(slot))
	_session.equipment.equip(great)
	assert_eq(order, [&"offhand", &"weapon"] as Array[StringName])


func test_offhand_removes_two_handed_weapon() -> void:
	var shield: int = _piece(SHIELD)
	var great: int = _piece(GREAT)
	_session.equipment.equip(great)
	assert_true(_session.equipment.equip(shield).ok)
	assert_eq(_session.equipment.get_uid(&"weapon"), 0)
	assert_eq(_session.equipment.get_uid(&"offhand"), shield)
	assert_false(_session.armory.is_worn(great))
	assert_null(_session.equipment.weapon())
	assert_eq(_session.equipment.setup(), Equipment.UNARMED, "no weapon with a shield")


func test_offhand_with_one_handed_weapon_keeps_both() -> void:
	var shield: int = _piece(SHIELD)
	var blade: int = _piece(BLADE)
	_session.equipment.equip(blade)
	_session.equipment.equip(shield)
	assert_eq(_session.equipment.get_item(&"weapon"), BLADE)
	assert_eq(_session.equipment.get_item(&"offhand"), SHIELD)
	assert_eq(_session.equipment.setup(), &"sword_shield")


func test_two_handed_with_full_armory_needs_room_for_both_pieces() -> void:
	_session = _small()
	var blade: int = _piece(BLADE)
	var shield: int = _piece(SHIELD)
	_session.equipment.equip(blade)
	_session.equipment.equip(shield)
	var great: int = _piece(GREAT)
	_fill_armory()
	assert_eq(_session.armory.used(), _session.armory.capacity(), "Armory must be full")
	watch_signals(_session.events)
	var before: float = _session.modifiers.total(&"power_bonus")
	assert_eq(_session.equipment.equip(great).reason, Reasons.ARMORY_FULL, "two pieces would return for one place")
	assert_eq(_session.equipment.get_uid(&"offhand"), shield)
	assert_eq(_session.equipment.get_uid(&"weapon"), blade)
	assert_true(_session.armory.is_worn(shield))
	assert_eq(_session.modifiers.total(&"power_bonus"), before)
	assert_signal_not_emitted(_session.events, "equipment_changed")


func test_unequip_returns_the_piece_and_errors() -> void:
	_session = _small()
	assert_eq(_session.equipment.unequip(&"head").reason, Reasons.SLOT_EMPTY)
	var helm: int = _piece(HELM)
	_session.equipment.equip(helm)
	_fill_armory()
	assert_eq(_session.equipment.unequip(&"head").reason, Reasons.ARMORY_FULL)
	assert_eq(_session.equipment.get_uid(&"head"), helm)
	assert_true(_session.armory.is_worn(helm))
	assert_true(_session.armory.remove(_session.armory.instances()[1].uid).ok)
	watch_signals(_session.events)
	assert_true(_session.equipment.unequip(&"head").ok)
	assert_false(_session.armory.is_worn(helm))
	assert_eq(_session.equipment.get_uid(&"head"), 0)
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"head", 0])


func test_weapon_and_offhand_blocked_in_encounter_other_slots_free() -> void:
	_session = _with_combat()
	var blade: int = _piece(BLADE)
	var blade2: int = _piece(BLADE)
	var helm: int = _piece(HELM)
	var shield: int = _piece(SHIELD)
	_session.equipment.equip(blade)
	_fake_combat(true)
	assert_eq(_session.equipment.equip(blade2).reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_session.equipment.unequip(&"weapon").reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_session.equipment.equip(shield).reason, Reasons.COMBAT_ACTIVE, "the offhand is locked too")
	assert_true(_session.equipment.equip(helm).ok)
	assert_eq(_session.equipment.get_uid(&"weapon"), blade)
	_fake_combat(false)
	assert_true(_session.equipment.unequip(&"weapon").ok)


func test_offhand_displacing_two_handed_weapon_blocked_during_combat() -> void:
	_session = _with_combat()
	var great: int = _piece(GREAT)
	var shield: int = _piece(SHIELD)
	_session.equipment.equip(great)
	_fake_combat(true)
	assert_eq(_session.equipment.equip(shield).reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_session.equipment.get_uid(&"weapon"), great)


func test_works_without_combat_system() -> void:
	var blade: int = _piece(BLADE)
	assert_null(_session.get(&"combat"))
	assert_true(_session.equipment.equip(blade).ok)


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
	assert_eq(_session.modifiers.total(&"damage_reduction"), 2.0)
	assert_eq(_session.modifiers.total(&"power_bonus"), 6.0)
	_session.equipment.unequip(&"head")
	assert_false(_session.modifiers.has_source(&"equipment:head"))
	assert_eq(_session.modifiers.total(&"damage_reduction"), 0.0)


func test_swap_rebuilds_the_modifiers_once() -> void:
	var shield: int = _piece(SHIELD)
	var great: int = _piece(GREAT)
	_session.equipment.equip(shield)
	var changes: Array[int] = [0]
	_session.events.modifiers_changed.connect(func() -> void: changes[0] += 1)
	_session.equipment.equip(great)
	assert_eq(changes[0], 1, "weapon in, offhand out: one batch")


func test_tool_changes_the_f03_interval_of_its_skill() -> void:
	assert_eq(_session.actions.current_interval_ms(TWIG), 3000)
	var hatchet: int = _piece(HATCHET)
	assert_true(_session.equipment.equip(hatchet).ok)
	assert_eq(_session.equipment.get_item(&"tool_forestry"), HATCHET)
	assert_eq(_session.actions.current_interval_ms(TWIG), ActionMath.interval_ms(3000, -5.0, 250))
	assert_eq(_session.actions.current_interval_ms(TWIG), 2850)
	_session.equipment.unequip(&"tool_forestry")
	assert_eq(_session.actions.current_interval_ms(TWIG), 3000)


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
