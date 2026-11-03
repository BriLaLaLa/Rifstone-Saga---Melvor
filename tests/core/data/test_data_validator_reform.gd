extends GutTest
## DataValidator, part 4: the rules of the M4 reform (04_DATA_SCHEMA.md §3, §5, §14, §15): piece kinds and grades,
## requirements by category, classes, affixes and the new balance keys. One test per rule, on a broken copy of the
## fixture data; helpers from test_data_validator.gd.

const V: GDScript = preload("res://tests/core/data/test_data_validator.gd")
const CLASS_FILE: String = "test_class.json"
const AFFIXES: String = "affixes.json"


func _expect(raw: Dictionary, fragments: Array[String]) -> void:
	var errors: PackedStringArray = V.validate(raw)
	for message: String in errors:
		var matched: bool = true
		for fragment: String in fragments:
			matched = matched and message.contains(fragment)
		if matched:
			assert_true(true)
			return
	fail_test("no error with %s in %s" % [fragments, errors])


func _equip(raw: Dictionary, file_name: String, index: int = 0) -> Dictionary:
	return V.entry_of(raw, "items", file_name, "items", index)["equip"] as Dictionary


func _class(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "classes", CLASS_FILE)


func _setup(raw: Dictionary, index: int) -> Dictionary:
	return (_class(raw)["setups"] as Array)[index] as Dictionary


func _affix(raw: Dictionary, index: int) -> Dictionary:
	return V.entry_of(raw, "affixes", AFFIXES, "affixes", index)


func _balance(raw: Dictionary) -> Dictionary:
	return V.file_of(raw, "balance", "balance.json")


# --- equipment: kind, grade, requirements ------------------------------------------------------------------------

func test_fixtures_have_the_three_kinds() -> void:
	var raw: Dictionary = V.fixture_raw()
	assert_eq(_equip(raw, "equipment.json", 0)["kind"], "sword")
	assert_eq(_equip(raw, "equipment.json", 1)["kind"], "greatsword")
	assert_eq(_equip(raw, "equipment.json", 2)["kind"], "shield")


func test_kind_is_required_for_weapon_and_offhand_slots() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 0).erase("kind")
	_equip(raw, "equipment.json", 2).erase("kind")
	_expect(raw, ["equipment.json", "item 'test_blade'", "missing field 'equip.kind'"])
	_expect(raw, ["equipment.json", "item 'test_shield'", "missing field 'equip.kind'"])


func test_kind_is_forbidden_for_other_slots() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 3)["kind"] = "sword"
	_expect(raw, ["equipment.json", "item 'test_helm'", "field 'equip.kind' is allowed only with slots"])


func test_kind_must_fit_the_slot() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 0)["kind"] = "shield"
	_equip(raw, "equipment.json", 2)["kind"] = "sword"
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.kind' must be one of"])
	_expect(raw, ["equipment.json", "item 'test_shield'", "field 'equip.kind' must be one of"])


func test_two_handed_is_true_only_for_greatswords() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_equip(raw, "equipment.json", 0)["weapon"] as Dictionary)["two_handed"] = true
	(_equip(raw, "equipment.json", 1)["weapon"] as Dictionary)["two_handed"] = false
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.weapon.two_handed' must be false for kind 'sword'"])
	_expect(raw, ["equipment.json", "item 'test_greatsword'",
			"field 'equip.weapon.two_handed' must be true for kind 'greatsword'"])


func test_grade_is_required_and_between_1_and_8() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 0).erase("grade")
	_equip(raw, "equipment.json", 1)["grade"] = 9
	_equip(raw, "tools.json")["grade"] = 0
	_expect(raw, ["equipment.json", "item 'test_blade'", "missing field 'equip.grade'"])
	_expect(raw, ["equipment.json", "item 'test_greatsword'", "field 'equip.grade' must be >= 1 and <= 8"])
	_expect(raw, ["tools.json", "item 'test_hatchet'", "field 'equip.grade' must be >= 1 and <= 8"])


func test_weapon_slot_needs_the_weapon_object() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 0).erase("weapon")
	_expect(raw, ["equipment.json", "item 'test_blade'", "missing field 'equip.weapon'"])


func test_equipment_blade_requirement_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 0)["requirements"] = {"blade": 1}
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.requirements.blade': only 'character'"])


func test_equipment_character_requirement_is_a_level() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "equipment.json", 0)["requirements"] = {"character": 100}
	_expect(raw, ["equipment.json", "item 'test_blade'", "field 'equip.requirements.character' must be >= 1 and <= 99"])


func test_tool_cannot_require_the_character_level() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "tools.json")["requirements"] = {"character": 5}
	_expect(raw, ["tools.json", "item 'test_hatchet'", "field 'equip.requirements.character': unknown skill"])


func test_tool_requires_only_the_skill_of_its_slot() -> void:
	var raw: Dictionary = V.fixture_raw()
	var skills: Array = V.file_of(raw, "skills", "skills.json")["skills"] as Array
	var forestry: Dictionary = (skills[0] as Dictionary).duplicate(true)
	forestry["id"] = "forestry"
	forestry["order"] = 20
	skills.append(forestry)
	_equip(raw, "tools.json")["requirements"] = {"test_gather": 1}
	_expect(raw, ["tools.json", "item 'test_hatchet'", "field 'equip.requirements.test_gather'",
			"only requires skill 'forestry'"])
	_equip(raw, "tools.json")["requirements"] = {"forestry": 1}
	for message: String in V.validate(raw):
		assert_false(message.contains("only requires skill"), message)


func test_tool_slots_belong_to_tools() -> void:
	var raw: Dictionary = V.fixture_raw()
	_equip(raw, "tools.json")["slot"] = "head"
	_expect(raw, ["tools.json", "item 'test_hatchet'", "slot 'head' does not fit category 'tool'"])


# --- classes -----------------------------------------------------------------------------------------------------

func test_class_id_must_match_the_file_name() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["id"] = "other_class"
	_expect(raw, [CLASS_FILE, "class 'other_class'", "id 'other_class' must be equal to the file name"])


func test_class_order_is_unique() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["order"] = 2
	_expect(raw, [CLASS_FILE, "class 'test_class'", "duplicate order 2"])


func test_class_needs_weapon_kinds_of_the_right_kind() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["weapon_kinds"] = []
	_class(raw)["offhand_kinds"] = ["shield", "bow"]
	_expect(raw, [CLASS_FILE, "field 'weapon_kinds' needs at least 1 entries"])
	_expect(raw, [CLASS_FILE, "field 'offhand_kinds': kind 'bow' must be one of"])
	_class(raw)["offhand_kinds"] = ["shield", "greatsword"]
	_expect(raw, [CLASS_FILE, "field 'offhand_kinds': kind 'greatsword' must be one of"])
	_class(raw)["weapon_kinds"] = ["shield"]
	_expect(raw, [CLASS_FILE, "field 'weapon_kinds': kind 'shield' must be one of"])


func test_class_needs_at_least_one_setup() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["setups"] = []
	_expect(raw, [CLASS_FILE, "field 'setups' needs at least 1 entries"])


func test_setup_id_is_unique_and_not_unarmed() -> void:
	var raw: Dictionary = V.fixture_raw()
	_setup(raw, 1)["id"] = "greatsword"
	_setup(raw, 3)["id"] = "unarmed"
	_expect(raw, [CLASS_FILE, "class 'test_class'", "duplicate setup 'greatsword'"])
	_expect(raw, [CLASS_FILE, "class 'test_class'", "field 'setups[3].id': 'unarmed' is reserved"])


func test_setup_weapon_must_be_a_class_weapon_kind() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["weapon_kinds"] = ["sword"]
	_expect(raw, [CLASS_FILE, "field 'setups[0].weapon': kind 'greatsword' is not in weapon_kinds"])


func test_setup_offhand_must_be_empty_or_an_offhand_kind() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["offhand_kinds"] = ["shield"]
	_expect(raw, [CLASS_FILE, "field 'setups[2].offhand': kind 'sword' must be"])
	_class(raw)["offhand_kinds"] = ["shield", "sword"]
	_setup(raw, 0)["offhand"] = "bow"
	_expect(raw, [CLASS_FILE, "field 'setups[0].offhand': kind 'bow' must be"])


func test_setup_weapon_offhand_pair_is_unique() -> void:
	var raw: Dictionary = V.fixture_raw()
	_setup(raw, 3)["offhand"] = "shield"
	_expect(raw, [CLASS_FILE, "setups with weapon 'sword' and offhand 'shield' are duplicated"])


func test_setup_alternate_needs_a_weapon_in_the_offhand() -> void:
	var raw: Dictionary = V.fixture_raw()
	_setup(raw, 1)["alternate"] = true
	_expect(raw, [CLASS_FILE, "field 'setups[1].alternate' is allowed only with a weapon in the offhand"])
	_setup(raw, 1)["alternate"] = "yes"
	_expect(raw, [CLASS_FILE, "field 'setups[1].alternate' must be a boolean"])


func test_setup_modifiers_are_checked_and_global() -> void:
	var raw: Dictionary = V.fixture_raw()
	_setup(raw, 0)["modifiers"] = [{"stat": "luck", "value": 1}]
	_setup(raw, 1)["modifiers"] = [{"stat": "accuracy_pct", "value": 5, "scope": "skill:test_gather"}]
	_setup(raw, 3).erase("modifiers")
	_expect(raw, [CLASS_FILE, "setups[0].modifiers[0].stat': stat 'luck' is not in"])
	_expect(raw, [CLASS_FILE, "field 'setups[1].modifiers': scope 'skill:test_gather' must be global"])
	_expect(raw, [CLASS_FILE, "missing field 'setups[3].modifiers'"])


func test_setup_unknown_field_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	_setup(raw, 0)["twohand"] = true
	_expect(raw, [CLASS_FILE, "unknown field 'setups[0].twohand'"])


func test_traits_and_abilities_are_empty_in_m4() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["traits"] = [{"id": "x"}]
	_class(raw).erase("abilities")
	_expect(raw, [CLASS_FILE, "field 'traits' must be empty"])
	_expect(raw, [CLASS_FILE, "missing field 'abilities'"])


func test_class_unknown_field_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	_class(raw)["subclass"] = "x"
	_expect(raw, [CLASS_FILE, "unknown field 'subclass'"])


# --- affixes -----------------------------------------------------------------------------------------------------

func test_affix_stat_must_be_registered() -> void:
	var raw: Dictionary = V.fixture_raw()
	_affix(raw, 0)["stat"] = "luck"
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'stat': stat 'luck' is not in stats.json"])


func test_affix_slots_are_known_and_not_empty() -> void:
	var raw: Dictionary = V.fixture_raw()
	_affix(raw, 0)["slots"] = ["weapon", "tail"]
	_affix(raw, 1)["slots"] = []
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'slots': 'tail' must be one of"])
	_expect(raw, [AFFIXES, "affix 'test_mighty'", "field 'slots' needs at least 1 entries"])


func test_affix_weight_and_duplicates() -> void:
	var raw: Dictionary = V.fixture_raw()
	_affix(raw, 0)["weight"] = 0
	_affix(raw, 1)["id"] = "test_keen"
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'weight' must be >= 1"])
	_expect(raw, [AFFIXES, "affix 'test_keen'", "duplicate affix 'test_keen'"])


func test_affix_needs_tiers() -> void:
	var raw: Dictionary = V.fixture_raw()
	_affix(raw, 0)["tiers"] = []
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'tiers' needs at least 1 entries"])


func test_affix_tier_ilvl_is_increasing_and_in_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	var tiers: Array = _affix(raw, 0)["tiers"] as Array
	(tiers[1] as Dictionary)["min_ilvl"] = 1
	(tiers[2] as Dictionary)["min_ilvl"] = 100
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'tiers[1].min_ilvl' must be greater than the previous"])
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'tiers[2].min_ilvl' must be >= 1 and <= 99"])


func test_affix_tier_min_must_not_exceed_max() -> void:
	var raw: Dictionary = V.fixture_raw()
	((_affix(raw, 0)["tiers"] as Array)[0] as Dictionary)["min"] = 9
	_expect(raw, [AFFIXES, "affix 'test_keen'", "field 'tiers[0]' needs min <= max, got 9..6"])


func test_affix_tier_step_divides_the_range() -> void:
	var raw: Dictionary = V.fixture_raw()
	var tier: Dictionary = (_affix(raw, 1)["tiers"] as Array)[1] as Dictionary
	tier["step"] = 3
	_expect(raw, [AFFIXES, "affix 'test_mighty'", "field 'tiers[1]': max - min must be a multiple of step 3"])
	tier["step"] = 0
	_expect(raw, [AFFIXES, "affix 'test_mighty'", "field 'tiers[1].step' must be > 0"])
	tier["step"] = 0.5
	assert_eq(V.validate(raw), PackedStringArray())


func test_affix_unknown_field_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	_affix(raw, 0)["rarity"] = "rare"
	_expect(raw, [AFFIXES, "affix 'test_keen'", "unknown field 'rarity'"])


# --- balance.json (M4 keys) --------------------------------------------------------------------------------------

func test_reform_keys_are_required() -> void:
	for key: String in ["character_curve.base", "character.start_class", "armory.slot_cost_cap",
			"rarity.craft.rare_base_pct", "rarity.affix_count.rare", "combat.dual_wield.interval_mult",
			"combat.max_pack_size", "combat.hp_per_level"]:
		assert_true(DataValidator.REQUIRED_BALANCE_KEYS.has(key), key)
	for key: String in ["combat.hp_skill", "combat.defence_skill", "combat.hp_per_vitality",
			"combat.xp_per_damage_style", "combat.xp_per_damage_vitality"]:
		assert_false(DataValidator.REQUIRED_BALANCE_KEYS.has(key), key)


func test_missing_reform_key_is_an_error() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["armory"] as Dictionary).erase("base_slots")
	_balance(raw).erase("character")
	_expect(raw, ["balance.json", "missing key 'armory.base_slots'"])
	_expect(raw, ["balance.json", "missing key 'character.start_class'"])


func test_dual_wield_mult_is_a_fraction() -> void:
	var raw: Dictionary = V.fixture_raw()
	var dual: Dictionary = (_balance(raw)["combat"] as Dictionary)["dual_wield"] as Dictionary
	dual["interval_mult"] = 0
	_expect(raw, ["balance.json", "field 'combat.dual_wield.interval_mult' must be > 0 and <= 1"])
	dual["interval_mult"] = 1.2
	_expect(raw, ["balance.json", "field 'combat.dual_wield.interval_mult' must be > 0 and <= 1"])
	dual["interval_mult"] = 1
	assert_eq(V.validate(raw), PackedStringArray())


func test_max_pack_size_is_an_integer_up_to_6() -> void:
	var raw: Dictionary = V.fixture_raw()
	var combat: Dictionary = _balance(raw)["combat"] as Dictionary
	for bad: Variant in [0, 7, 2.5]:
		combat["max_pack_size"] = bad
		_expect(raw, ["balance.json", "field 'combat.max_pack_size' must be"])


func test_pack_size_limit_comes_from_balance() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["combat"] as Dictionary)["max_pack_size"] = 1
	_expect(raw, ["areas.json", "area 'test_area'", "field 'packs[1].monsters' has 2 monsters, at most 1"])


func test_affix_count_is_a_valid_pair() -> void:
	var raw: Dictionary = V.fixture_raw()
	var counts: Dictionary = (_balance(raw)["rarity"] as Dictionary)["affix_count"] as Dictionary
	counts["magic"] = [3, 1]
	counts["rare"] = [3, 7]  # max over the format limit of 6
	_expect(raw, ["balance.json", "field 'rarity.affix_count.magic' must be [a, b] with 0 <= min <= max"])
	_expect(raw, ["balance.json", "field 'rarity.affix_count.rare' must be [a, b] with 0 <= min <= max"])


func test_character_curve_is_checked_like_the_other_curves() -> void:
	var raw: Dictionary = V.fixture_raw()
	var curve: Dictionary = _balance(raw)["character_curve"] as Dictionary
	curve["growth"] = 0
	curve["max_level"] = 9.5
	_expect(raw, ["balance.json", "key 'character_curve.growth' must be > 0"])
	_expect(raw, ["balance.json", "key 'character_curve.max_level' must be an integer >= 1"])


func test_character_requirements_use_the_character_curve_cap() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["character_curve"] as Dictionary)["max_level"] = 50
	_equip(raw, "equipment.json", 4)["requirements"] = {"character": 60}
	_expect(raw, ["equipment.json", "item 'test_helm_high'", "field 'equip.requirements.character' must be >= 1 and <= 50"])


func test_start_items_cannot_be_pieces() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["start"] as Dictionary)["items"] = [{"item": "test_blade", "qty": 1}]
	_expect(raw, ["balance.json", "field 'start.items': 'test_blade' is equipment, pieces live in the Armory"])


func test_reform_keys_removed_are_unknown() -> void:
	var raw: Dictionary = V.fixture_raw()
	(_balance(raw)["combat"] as Dictionary)["hp_per_vitality"] = 10
	_expect(raw, ["balance.json", "unknown key 'combat.hp_per_vitality'"])
