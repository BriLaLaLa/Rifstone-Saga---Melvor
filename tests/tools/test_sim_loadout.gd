extends GutTest
## M28-08: the options of tools/sim_combat.gd added for F-194 (`setup=sword`, `traits=`, `abilities=`) and tools/sim_loadout.gd.

const Sim := preload("res://tools/sim_combat.gd")
const SimLoadout := preload("res://tools/sim_loadout.gd")
const PLAINS: StringName = &"redrock_plains"

var _data: GameData = null


func before_all() -> void:
	_data = TestFactory.real_data()


func _session(setup: StringName, level: int) -> GameSession:
	var session: GameSession = Sim._new_session(_data, 1234)
	Sim._set_level(session, level)
	Sim._equip_set(session, 1, setup)
	return autofree(session)


func test_parse_args_accepts_the_new_options() -> void:
	var opts: Dictionary = Sim.parse_args(PackedStringArray(["setup=sword", "traits=momentum,first_blood", "abilities=none"]))
	assert_false(opts.has("error"))
	assert_eq([opts["setup"], opts["traits"], opts["abilities"]], ["sword", "momentum,first_blood", "none"])
	var defaults: Dictionary = Sim.parse_args(PackedStringArray())
	assert_eq([defaults["traits"], defaults["abilities"]], ["-", "-"], "not given = follow loadout=")


func test_setup_sword_is_a_sword_without_offhand() -> void:
	var session: GameSession = _session(&"sword", 10)
	assert_eq(session.equipment.setup(), &"sword")
	assert_eq(session.equipment.get_uid(&"offhand"), 0, "the starting shield is taken off")
	assert_ne(session.equipment.get_uid(&"weapon"), 0)


func test_the_three_other_assemblies_keep_their_setup() -> void:
	assert_eq(_session(&"sword_shield", 10).equipment.setup(), &"sword_shield")
	assert_eq(_session(&"greatsword", 10).equipment.setup(), &"greatsword")
	assert_eq(_session(&"dual", 10).equipment.setup(), &"dual_swords")


func test_explicit_lists_go_in_slot_order_and_none_leaves_the_slots_empty() -> void:
	var session: GameSession = _session(&"sword", 30)
	assert_true(SimLoadout.apply(session, _data, {"loadout": "auto", "traits": "momentum,first_blood", "abilities": "none"}))
	assert_eq([session.loadout.get_trait(0), session.loadout.get_trait(1)], [&"momentum", &"first_blood"])
	assert_eq([session.loadout.get_ability(0), session.loadout.get_ability(1)], [&"", &""], "abilities=none wins over loadout=auto")


func test_a_refused_id_is_reported() -> void:
	var session: GameSession = _session(&"sword", 5)
	assert_false(SimLoadout.apply(session, _data, {"loadout": "none", "traits": "heavy_iron", "abilities": "-"}), "heavy_iron needs a greatsword and level 28")


func test_loadout_auto_is_unchanged_when_only_m27_contents_are_open() -> void:
	# Level 8, sword and shield: one trait slot and two ability slots; the M27 contents come first in the file, so `auto` and the
	# explicit M27 list agree.
	var a: GameSession = _session(&"sword_shield", 8)
	var b: GameSession = _session(&"sword_shield", 8)
	SimLoadout.apply(a, _data, {"loadout": "auto", "traits": "-", "abilities": "-"})
	var traits: String = ",".join(SimLoadout.pick(b, _data, true, SimLoadout.M27_TRAITS))
	var abilities: String = ",".join(SimLoadout.pick(b, _data, false, SimLoadout.M27_ABILITIES))
	SimLoadout.apply(b, _data, {"loadout": "none", "traits": traits, "abilities": abilities})
	assert_eq(a.loadout.get_trait(0), &"chain_cleave")
	assert_eq(a.loadout.get_trait(0), b.loadout.get_trait(0))
	for i: int in 2:
		assert_eq(a.loadout.get_ability(i), b.loadout.get_ability(i))


func test_full_loadouts_fit_the_open_slots_and_the_setup() -> void:
	for setup: String in ["greatsword", "sword_shield", "dual", "sword"]:
		for level: int in [25, 50, 80, 95]:
			for kind: String in ["offensive", "defensive", "synergy"]:
				var traits: Array[StringName] = SimLoadout.full_loadout(_data, setup, level, kind, true)
				var abilities: Array[StringName] = SimLoadout.full_loadout(_data, setup, level, kind, false)
				assert_eq(traits.size(), 3 if level < 50 else 4, "%s %d %s trait slots" % [setup, level, kind])
				assert_eq(abilities.size(), 2 if level < 30 else 3, "%s %d %s ability slots" % [setup, level, kind])
				var allowed: Array[StringName] = SimLoadout.available(_data, SimLoadout.SETUP_ID[setup], level, true)
				for id: StringName in traits:
					assert_true(allowed.has(id), "%s is allowed for %s at %d" % [id, setup, level])
