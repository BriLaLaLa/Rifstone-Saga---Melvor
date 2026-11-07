extends GutTest
## Equipment by uid: equip/unequip rules, two-handed weapons, character and class requirements, full Armory,
## combat lock. Setups, sources and food: test_equipment_setups.gd. Save: test_equipment_save.gd.
##
## Fixture items: test_blade (sword, weapon), test_greatsword (two-handed), test_shield (offhand), test_helm (head),
## test_helm_high (head, character 10), unique_hatchet (tool_forestry, requires test_gather 1), test_ration (food).

const BLADE: StringName = &"test_blade"
const GREAT: StringName = &"test_greatsword"
const SHIELD: StringName = &"test_shield"
const HELM: StringName = &"test_helm"
const HELM_HIGH: StringName = &"test_helm_high"
const HATCHET: StringName = &"unique_hatchet"
const RATION: StringName = &"test_ration"
const TWIG: StringName = &"gather_twig"
const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")
const SMALL_ARMORY_SLOTS: int = 4

var _tmp_config: String = PreRun.test_dir("test_equipment").path_join("config")
var _small_data: GameData = null
var _session: GameSession = null


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


# The real session: its CombatEngine answers `in_encounter`.
func _with_combat() -> GameSession:
	return autofree(TestFactory.session(1234))


# Fills the Armory with unworn helmets until it is full.
func _fill_armory() -> void:
	while _session.armory.can_add(1):
		TestFactory.give_piece(_session, HELM)


func _fake_combat(active: bool) -> void:
	if active:
		assert_true(_session.combat.start(&"test_area").ok)
	else:
		_session.combat.stop()


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
	assert_false(_session.combat.in_encounter(), "idle combat does not lock the hands")
	assert_true(_session.equipment.equip(blade).ok)


func test_refining_a_worn_piece_updates_its_modifiers() -> void:
	# M7-01: armory_changed(uid, updated) refreshes the source equipment:<slot> (F-86: base x (1 + 10 N / 100)).
	var session: GameSession = autofree(TestFactory.session(5, TestFactory.real_data()))
	var uid: int = TestFactory.give_piece(session, &"emberbronze_sword")
	assert_true(session.equipment.equip(uid).ok)
	var before: float = session.modifiers.total(&"power_bonus")
	var unequipped_uid: int = TestFactory.give_piece(session, &"emberbronze_sword")
	TestFactory.give(session, &"emberbronze_ingot", 1)
	session.wallet.add_gold(50)
	# A +300% bonus makes the attempt certain (seed-independent).
	session.modifiers.set_source(&"test:upg", [Modifier.make(&"upgrade_success_pct", 300.0)])
	assert_true(session.armory.upgrade(uid).ok)
	assert_eq(session.armory.get_instance(uid).upgrade, 1)
	assert_almost_eq(session.modifiers.total(&"power_bonus"), before + 6.0 * 0.1, 0.0001, "power_bonus x1.1")
	assert_eq(session.armory.get_instance(unequipped_uid).upgrade, 0, "the other piece is untouched")
