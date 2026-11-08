extends GutTest
## LoadoutDescribe: every number of a trait or ability description comes from its data (effects, params, cooldown).

var _session: GameSession


func before_each() -> void:
	_session = TestFactory.session()


func after_each() -> void:
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func test_ability_text_has_power_cooldown_and_setups() -> void:
	var class_def: ClassDef = _session.character.class_def()
	for def: AbilityDef in class_def.abilities:
		var text: String = LoadoutDescribe.ability_text(def, _session.data, class_def)
		assert_string_contains(text, NumberFormat.format_seconds(def.cooldown_ms), def.id)
		if def.kind == AbilityDef.KIND_STRIKE or def.kind == AbilityDef.KIND_CLEAVE:
			assert_string_contains(text, NumberFormat.format_number(def.power_mult * 100.0) + "%", def.id)
		if def.kind == AbilityDef.KIND_HEAL:
			assert_string_contains(text, NumberFormat.format_number(def.heal_pct) + "%", def.id)
		assert_string_contains(text, "Assetto", def.id)


func test_text_follows_the_data_not_the_description_field() -> void:
	var class_def: ClassDef = _session.character.class_def()
	var def: AbilityDef = class_def.abilities[0]
	def.description = "Testo a mano con 999 numeri"
	var before: String = LoadoutDescribe.ability_text(def, _session.data, class_def)
	assert_does_not_have(Array(before.split(" ")), "999")
	if def.kind == AbilityDef.KIND_STRIKE or def.kind == AbilityDef.KIND_CLEAVE:
		def.power_mult = 3.5
		assert_string_contains(LoadoutDescribe.ability_text(def, _session.data, class_def), "350%")
	def.cooldown_ms = 7000
	assert_string_contains(LoadoutDescribe.ability_text(def, _session.data, class_def), NumberFormat.format_seconds(7000))


func test_every_trait_effect_type_has_a_text() -> void:
	var class_def: ClassDef = _session.character.class_def()
	for def: TraitDef in class_def.traits:
		var text: String = LoadoutDescribe.trait_text(def, _session.data, class_def)
		assert_ne(text.strip_edges(), "", def.id)
		assert_false(text.contains(LoadoutDescribe.UNKNOWN_EFFECT_TEXT), def.id)


func test_trait_numbers_come_from_the_params() -> void:
	var def := TraitDef.new()
	def.id = &"t"
	var every := TraitEffectDef.new()
	every.type = &"every_nth_attack_all"
	every.params = {"n": 4.0}
	var leech := TraitEffectDef.new()
	leech.type = &"leech_pct"
	leech.params = {"pct": 7.5}
	def.effects = [every, leech]
	var text: String = LoadoutDescribe.trait_text(def, _session.data, _session.character.class_def())
	assert_string_contains(text, "4°")
	assert_string_contains(text, "7,5%")
	assert_string_contains(text, LoadoutDescribe.ANY_SETUP_TEXT)
