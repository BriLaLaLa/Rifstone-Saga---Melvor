extends GutTest
## Equipment: equip/unequip rules, two-handed weapons, requirements, full bank, combat lock, food, stance,
## sources equipment:<slot>, tool effect on the F-03 interval, save round trip.
##
## Fixture items: test_blade (weapon, blade 1), test_greatsword (two-handed), test_shield (offhand), test_helm (head),
## test_helm_high (head, blade 10), test_hatchet (tool_forestry, requires test_gather 1), test_ration (food).

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
const SMALL_BASE_SLOTS: int = 4
const JUNK: Array[StringName] = [&"test_log", &"test_twig", &"test_plank", &"rift_shard"]

var _tmp_config: String = PreRun.test_dir("test_equipment").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null


class _FakeCombat extends RefCounted:
	var active: bool = false

	func is_active() -> bool:
		return active


class _CombatSession extends GameSession:
	var combat: Object = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	(balance["bank"] as Dictionary)["base_slots"] = SMALL_BASE_SLOTS
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


# Session whose bank has only SMALL_BASE_SLOTS slots.
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


# Fills the bank with junk items until it is full.
func _fill_bank_with_junk() -> void:
	for id: StringName in JUNK:
		if _session.bank.used() < _session.bank.capacity():
			_session.bank.add(id, 1)


func _fake_combat(active: bool) -> void:
	var combat: _FakeCombat = _FakeCombat.new()
	combat.active = active
	(_session as _CombatSession).combat = combat


func test_new_game_is_empty_with_offensive_stance() -> void:
	for slot: StringName in Equipment.SLOTS:
		assert_eq(_session.equipment.get_item(slot), &"")
	assert_eq(_session.equipment.get_food(), &"")
	assert_eq(_session.equipment.get_stance(), &"offensive")
	assert_null(_session.equipment.weapon())


func test_equip_moves_one_item_from_bank_to_slot() -> void:
	TestFactory.give(_session, HELM, 2)
	watch_signals(_session.events)
	assert_true(_session.equipment.equip(HELM).ok)
	assert_eq(_session.equipment.get_item(&"head"), HELM)
	assert_eq(_session.bank.get_count(HELM), 1)
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"head", HELM])


func test_equip_last_unit_frees_the_bank_stack() -> void:
	TestFactory.give(_session, HELM, 1)
	_session.equipment.equip(HELM)
	assert_eq(_session.bank.get_count(HELM), 0)


func test_equip_replaces_and_returns_previous_piece() -> void:
	TestFactory.give(_session, HELM, 1)
	TestFactory.give(_session, HELM_HIGH, 1)
	TestFactory.set_level(_session, &"blade", 10)
	_session.equipment.equip(HELM)
	assert_true(_session.equipment.equip(HELM_HIGH).ok)
	assert_eq(_session.equipment.get_item(&"head"), HELM_HIGH)
	assert_eq(_session.bank.get_count(HELM), 1)
	assert_eq(_session.bank.get_count(HELM_HIGH), 0)


func test_equip_errors() -> void:
	assert_eq(_session.equipment.equip(&"nope").reason, Reasons.UNKNOWN_ID)
	TestFactory.give(_session, RATION, 1)
	assert_eq(_session.equipment.equip(RATION).reason, Reasons.NOT_EQUIPPABLE)
	assert_eq(_session.equipment.equip(HELM).reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(_session, HELM_HIGH, 1)
	assert_eq(_session.equipment.equip(HELM_HIGH).reason, Reasons.REQUIREMENT_NOT_MET)
	assert_eq(_session.bank.get_count(HELM_HIGH), 1)
	assert_eq(_session.equipment.get_item(&"head"), &"")


func test_requirement_met_at_the_exact_level() -> void:
	TestFactory.give(_session, HELM_HIGH, 1)
	TestFactory.set_level(_session, &"blade", 10)
	assert_true(_session.equipment.equip(HELM_HIGH).ok)


func test_swap_with_full_bank_is_refused_and_changes_nothing() -> void:
	_session = _small()
	TestFactory.give(_session, HELM, 1)
	TestFactory.give(_session, HELM_HIGH, 2)
	TestFactory.set_level(_session, &"blade", 10)
	_session.equipment.equip(HELM)
	_fill_bank_with_junk()
	assert_eq(_session.bank.used(), _session.bank.capacity(), "bank must be full")
	watch_signals(_session.events)
	var before: float = _session.modifiers.total(&"damage_reduction")
	assert_eq(_session.equipment.equip(HELM_HIGH).reason, Reasons.BANK_FULL)
	assert_eq(_session.equipment.get_item(&"head"), HELM)
	assert_eq(_session.bank.get_count(HELM_HIGH), 2)
	assert_eq(_session.bank.get_count(HELM), 0)
	assert_eq(_session.modifiers.total(&"damage_reduction"), before)
	assert_signal_not_emitted(_session.events, "equipment_changed")


func test_swap_works_in_full_bank_when_taken_stack_is_the_last_unit() -> void:
	_session = _small()
	TestFactory.give(_session, HELM, 1)
	TestFactory.give(_session, HELM_HIGH, 1)
	TestFactory.set_level(_session, &"blade", 10)
	_session.equipment.equip(HELM)
	_fill_bank_with_junk()
	assert_eq(_session.bank.used(), _session.bank.capacity(), "bank must be full")
	assert_true(_session.equipment.equip(HELM_HIGH).ok)
	assert_eq(_session.bank.get_count(HELM), 1)


func test_unequip_returns_item_and_errors() -> void:
	_session = _small()
	assert_eq(_session.equipment.unequip(&"head").reason, Reasons.SLOT_EMPTY)
	TestFactory.give(_session, HELM, 1)
	_session.equipment.equip(HELM)
	_fill_bank_with_junk()
	assert_eq(_session.bank.used(), _session.bank.capacity(), "bank must be full")
	assert_eq(_session.equipment.unequip(&"head").reason, Reasons.BANK_FULL)
	assert_eq(_session.equipment.get_item(&"head"), HELM)
	var first: StringName = _session.bank.stacks()[0]["item"]
	_session.bank.remove(first, 1)
	watch_signals(_session.events)
	assert_true(_session.equipment.unequip(&"head").ok)
	assert_eq(_session.bank.get_count(HELM), 1)
	assert_eq(_session.equipment.get_item(&"head"), &"")
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"head", &""])


func test_two_handed_weapon_returns_offhand() -> void:
	TestFactory.give(_session, SHIELD, 1)
	TestFactory.give(_session, GREAT, 1)
	_session.equipment.equip(SHIELD)
	assert_true(_session.equipment.equip(GREAT).ok)
	assert_eq(_session.equipment.get_item(&"weapon"), GREAT)
	assert_eq(_session.equipment.get_item(&"offhand"), &"")
	assert_eq(_session.bank.get_count(SHIELD), 1)
	assert_false(_session.modifiers.has_source(&"equipment:offhand"))


func test_offhand_removes_two_handed_weapon() -> void:
	TestFactory.give(_session, SHIELD, 1)
	TestFactory.give(_session, GREAT, 1)
	_session.equipment.equip(GREAT)
	assert_true(_session.equipment.equip(SHIELD).ok)
	assert_eq(_session.equipment.get_item(&"weapon"), &"")
	assert_eq(_session.equipment.get_item(&"offhand"), SHIELD)
	assert_eq(_session.bank.get_count(GREAT), 1)
	assert_null(_session.equipment.weapon())


func test_offhand_with_one_handed_weapon_keeps_both() -> void:
	TestFactory.give(_session, SHIELD, 1)
	TestFactory.give(_session, BLADE, 1)
	_session.equipment.equip(BLADE)
	_session.equipment.equip(SHIELD)
	assert_eq(_session.equipment.get_item(&"weapon"), BLADE)
	assert_eq(_session.equipment.get_item(&"offhand"), SHIELD)


func test_two_handed_with_full_bank_needs_room_for_offhand() -> void:
	_session = _small()
	TestFactory.give(_session, SHIELD, 1)
	TestFactory.give(_session, GREAT, 2)
	_session.equipment.equip(SHIELD)
	_fill_bank_with_junk()
	assert_eq(_session.bank.used(), _session.bank.capacity(), "bank must be full")
	assert_eq(_session.equipment.equip(GREAT).reason, Reasons.BANK_FULL)
	assert_eq(_session.equipment.get_item(&"offhand"), SHIELD)
	assert_eq(_session.bank.get_count(GREAT), 2)


func test_weapon_change_blocked_during_combat_other_slots_free() -> void:
	_session = _with_combat()
	TestFactory.give(_session, BLADE, 2)
	TestFactory.give(_session, HELM, 1)
	TestFactory.give(_session, SHIELD, 1)
	_session.equipment.equip(BLADE)
	_fake_combat(true)
	assert_eq(_session.equipment.equip(BLADE).reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_session.equipment.unequip(&"weapon").reason, Reasons.COMBAT_ACTIVE)
	assert_true(_session.equipment.equip(HELM).ok)
	assert_true(_session.equipment.equip(SHIELD).ok)
	assert_eq(_session.equipment.get_item(&"weapon"), BLADE)
	_fake_combat(false)
	assert_true(_session.equipment.unequip(&"weapon").ok)


func test_offhand_displacing_two_handed_weapon_blocked_during_combat() -> void:
	_session = _with_combat()
	TestFactory.give(_session, GREAT, 1)
	TestFactory.give(_session, SHIELD, 1)
	_session.equipment.equip(GREAT)
	_fake_combat(true)
	assert_eq(_session.equipment.equip(SHIELD).reason, Reasons.COMBAT_ACTIVE)
	assert_eq(_session.equipment.get_item(&"weapon"), GREAT)


func test_works_without_combat_system() -> void:
	TestFactory.give(_session, BLADE, 1)
	assert_null(_session.get(&"combat"))
	assert_true(_session.equipment.equip(BLADE).ok)


func test_style_and_interval_follow_weapon_or_unarmed() -> void:
	var unarmed_style: StringName = StringName(str(_session.data.balance_value("combat.unarmed.style")))
	var unarmed_ms: int = int(_session.data.balance_value("combat.unarmed.attack_interval_ms"))
	assert_eq(_session.equipment.style(), unarmed_style)
	assert_eq(_session.equipment.base_attack_interval_ms(), unarmed_ms)
	TestFactory.give(_session, GREAT, 1)
	_session.equipment.equip(GREAT)
	assert_eq(_session.equipment.style(), &"blade")
	assert_eq(_session.equipment.base_attack_interval_ms(), 3200)
	assert_eq(_session.equipment.weapon().id, GREAT)


func test_modifier_sources_follow_slots() -> void:
	TestFactory.give(_session, HELM, 1)
	TestFactory.give(_session, BLADE, 1)
	_session.equipment.equip(HELM)
	_session.equipment.equip(BLADE)
	assert_true(_session.modifiers.has_source(&"equipment:head"))
	assert_eq(_session.modifiers.total(&"damage_reduction"), 2.0)
	assert_eq(_session.modifiers.total(&"power_bonus"), 6.0)
	_session.equipment.unequip(&"head")
	assert_false(_session.modifiers.has_source(&"equipment:head"))
	assert_eq(_session.modifiers.total(&"damage_reduction"), 0.0)


func test_tool_changes_the_f03_interval_of_its_skill() -> void:
	assert_eq(_session.actions.current_interval_ms(TWIG), 3000)
	TestFactory.give(_session, HATCHET, 1)
	assert_true(_session.equipment.equip(HATCHET).ok)
	assert_eq(_session.equipment.get_item(&"tool_forestry"), HATCHET)
	assert_eq(_session.actions.current_interval_ms(TWIG), ActionMath.interval_ms(3000, -5.0, 250))
	assert_eq(_session.actions.current_interval_ms(TWIG), 2850)
	_session.equipment.unequip(&"tool_forestry")
	assert_eq(_session.actions.current_interval_ms(TWIG), 3000)


func test_food_set_and_errors() -> void:
	assert_eq(_session.equipment.set_food(&"nope").reason, Reasons.UNKNOWN_ID)
	TestFactory.give(_session, HELM, 1)
	assert_eq(_session.equipment.set_food(HELM).reason, Reasons.NOT_FOOD)
	assert_eq(_session.equipment.set_food(RATION).reason, Reasons.NOT_ENOUGH_ITEMS)
	TestFactory.give(_session, RATION, 3)
	watch_signals(_session.events)
	assert_true(_session.equipment.set_food(RATION).ok)
	assert_eq(_session.equipment.get_food(), RATION)
	assert_eq(_session.bank.get_count(RATION), 3)
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"food", RATION])
	assert_true(_session.equipment.set_food(&"").ok)
	assert_eq(_session.equipment.get_food(), &"")


func test_stance() -> void:
	watch_signals(_session.events)
	assert_eq(_session.equipment.set_stance(&"sideways").reason, Reasons.UNKNOWN_ID)
	assert_eq(_session.equipment.get_stance(), &"offensive")
	assert_true(_session.equipment.set_stance(&"defensive").ok)
	assert_eq(_session.equipment.get_stance(), &"defensive")
	assert_signal_emitted_with_parameters(_session.events, "equipment_changed", [&"stance", &"defensive"])


func test_save_round_trip_restores_state_and_sources() -> void:
	TestFactory.give(_session, HATCHET, 1)
	TestFactory.give(_session, BLADE, 1)
	TestFactory.give(_session, RATION, 1)
	_session.equipment.equip(HATCHET)
	_session.equipment.equip(BLADE)
	_session.equipment.set_food(RATION)
	_session.equipment.set_stance(&"balanced")
	var saved: Dictionary = _session.to_save(0)
	var other: GameSession = autofree(TestFactory.session(99))
	assert_true(other.from_save(saved).ok)
	assert_eq(other.equipment.get_item(&"weapon"), BLADE)
	assert_eq(other.equipment.get_item(&"tool_forestry"), HATCHET)
	assert_eq(other.equipment.get_food(), RATION)
	assert_eq(other.equipment.get_stance(), &"balanced")
	assert_eq(other.modifiers.total(&"power_bonus"), 6.0)
	assert_eq(other.actions.current_interval_ms(TWIG), 2850)


func test_from_save_skips_invalid_entries() -> void:
	_session.equipment.from_save({"slots": {"head": "test_blade", "weapon": "nope", "tail": "test_helm",
			"offhand": "test_shield"}, "food": "test_helm", "stance": "x"})
	assert_eq(_session.equipment.get_item(&"head"), &"")
	assert_eq(_session.equipment.get_item(&"weapon"), &"")
	assert_eq(_session.equipment.get_item(&"offhand"), SHIELD)
	assert_eq(_session.equipment.get_food(), &"")
	assert_eq(_session.equipment.get_stance(), &"offensive")


func test_from_save_two_handed_weapon_with_shield_drops_the_offhand() -> void:
	watch_signals(_session.events)
	_session.equipment.from_save({"slots": {"offhand": "test_shield", "weapon": "test_greatsword"}})
	assert_eq(_session.equipment.get_item(&"weapon"), GREAT)
	assert_eq(_session.equipment.get_item(&"offhand"), &"")
	assert_signal_not_emitted(_session.events, "equipment_changed")



func test_new_game_resets() -> void:
	TestFactory.give(_session, HELM, 1)
	_session.equipment.equip(HELM)
	_session.equipment.set_stance(&"defensive")
	_session.new_game()
	assert_eq(_session.equipment.get_item(&"head"), &"")
	assert_eq(_session.equipment.get_stance(), &"offensive")
	assert_false(_session.modifiers.has_source(&"equipment:head"))
