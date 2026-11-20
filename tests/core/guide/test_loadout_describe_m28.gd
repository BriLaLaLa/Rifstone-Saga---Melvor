extends GutTest
## LoadoutDescribe for the M28 types (docs/05_INTERFACES_M28.md §5.10c): every effect type of F-192 and the F-120 combat types allowed in the
## traits, and every new ability param, give a text with its numbers; on the real data no entry falls back to "Effetto speciale".

var _data: GameData = null
var _class_def: ClassDef = null


func before_all() -> void:
	_data = TestFactory.real_data()
	_class_def = _data.character_class(&"rift_blade")


func _trait_text(type: StringName, params: Dictionary) -> String:
	var def := TraitDef.new()
	def.id = &"t"
	var effect := TraitEffectDef.new()
	effect.type = type
	effect.params = params
	def.effects = [effect]
	return LoadoutDescribe.trait_text(def, _data, _class_def)


func _ability(kind: StringName, power: float = 0.0) -> AbilityDef:
	var def := AbilityDef.new()
	def.id = &"a"
	def.kind = kind
	def.power_mult = power
	def.cooldown_ms = 8000
	return def


func test_real_data_has_no_special_effect_fallback() -> void:
	assert_not_null(_class_def)
	assert_gt(_class_def.traits.size(), 12, "the M28 traits are in the data")
	for def: TraitDef in _class_def.traits:
		var text: String = LoadoutDescribe.trait_text(def, _data, _class_def)
		assert_false(text.contains(LoadoutDescribe.UNKNOWN_EFFECT_TEXT), "trait %s" % def.id)
		assert_ne(text.split("\n")[0].strip_edges(), "", "trait %s has a first line" % def.id)
	for def: AbilityDef in _class_def.abilities:
		var text: String = LoadoutDescribe.ability_text(def, _data, _class_def)
		assert_false(text.contains(LoadoutDescribe.UNKNOWN_EFFECT_TEXT), "ability %s" % def.id)
		assert_ne(text.split("\n")[0].strip_edges(), "", "ability %s has a first line" % def.id)


## Every type, with parameters the validator accepts, a text that is not the fallback and carries the numbers of the params.
func test_every_new_trait_type_has_a_text_with_its_numbers() -> void:
	var cases: Array[Array] = [
		[&"stack_damage", {"gain": "kill", "pct": 5.0, "max": 5, "lose": "damaged"}, ["5%", "5 cumuli", "uccisione"]],
		[&"stack_haste", {"gain": "block", "pct": 3.0, "max": 8, "lose": "encounter"}, ["3%", "8 cumuli", "parata"]],
		[&"focus_combo", {"pct": 6.0, "max": 5}, ["6%", "5 colpi"]],
		[&"riposte", {"on": "evade", "mult": 0.8}, ["80%", "schivi"]],
		[&"damage_trade", {"dealt_pct": 25.0, "taken_pct": 15.0}, ["25%", "15%"]],
		[&"apply_on_hit", {"every": 3, "condition": "bleed", "pct": 40.0, "ms": 4000}, ["3°", "Sanguinamento", "40%", "4,0 s"]],
		[&"apply_on_hit", {"every": 1, "condition": "stagger", "ms": 1500}, ["Sbilanciamento", "1,5 s"]],
		[&"status_damage_mult", {"condition": "expose", "pct": 20.0}, ["Breccia", "20%"]],
		[&"kill_cooldown_cut", {"ms": 1500}, ["1,5 s"]],
		[&"after_ability_mult", {"mult": 1.5}, ["1,5"]],
		[&"ward_on", {"on": "kill", "pct": 8.0, "ms": 6000}, ["8%", "6,0 s", "Riparo"]],
		[&"ability_mult", {"kinds": ["heal", "ward"], "pct": 25.0}, ["25%", "cura", "Riparo"]],
		[&"lone_target_mult", {"pct": 25.0}, ["25%", "solo nemico"]],
		[&"execute_mult", {"hp_pct": 30.0, "mult": 2.0}, ["30%", "2"]],
		[&"hit_cap_pct", {"pct": 25.0}, ["25%"]],
		[&"armor_pierce_pct", {"pct": 40.0}, ["40%"]],
		[&"kill_heal_pct", {"pct": 2.0}, ["2%"]],
		[&"block_heal_pct", {"pct": 8.0}, ["8%"]],
		[&"stat_convert", {"from": "barrier", "to": "armor", "pct": 40.0}, ["40%"]],
		[&"double_hit_pct", {"pct": 12.0}, ["12%"]],
	]
	for entry: Array in cases:
		var text: String = _trait_text(entry[0], entry[1])
		assert_false(text.contains(LoadoutDescribe.UNKNOWN_EFFECT_TEXT), str(entry[0]))
		for part: String in entry[2]:
			assert_string_contains(text, part, "%s: %s" % [entry[0], part])


func test_the_numbers_follow_the_params() -> void:
	var low: String = _trait_text(&"stack_damage", {"gain": "hit", "pct": 4.0, "max": 3, "lose": "none"})
	var high: String = _trait_text(&"stack_damage", {"gain": "hit", "pct": 9.0, "max": 7, "lose": "none"})
	assert_ne(low, high)
	assert_string_contains(high, "9%")
	assert_string_contains(high, "7 cumuli")


func test_ability_params_are_described() -> void:
	var strike: AbilityDef = _ability(AbilityDef.KIND_STRIKE, 0.5)
	strike.hits = 3
	strike.target_rule = &"lowest_hp"
	strike.execute_hp_pct = 30.0
	strike.execute_mult = 2.5
	strike.drain_pct = 30.0
	var bleed := ConditionApply.new()
	bleed.condition = ConditionApply.BLEED
	bleed.pct = 30.0
	bleed.ms = 4000
	var weaken := ConditionApply.new()
	weaken.condition = ConditionApply.WEAKEN
	weaken.pct = 25.0
	weaken.ms = 6000
	strike.applies = [bleed, weaken]
	var text: String = LoadoutDescribe.ability_text(strike, _data, _class_def)
	for part: String in ["3 volte", "50%", "meno PV", "30%", "2,5", "Sanguinamento", "Fiacchezza", "25%", "4,0 s"]:
		assert_string_contains(text, part)
	assert_false(text.contains(LoadoutDescribe.UNKNOWN_EFFECT_TEXT))


func test_cleave_extras_and_ward_ability() -> void:
	var cleave: AbilityDef = _ability(AbilityDef.KIND_CLEAVE, 0.8)
	var expose := ConditionApply.new()
	expose.condition = ConditionApply.EXPOSE
	expose.pct = 15.0
	expose.ms = 6000
	cleave.applies = [expose]
	cleave.drain_pct = 20.0
	var text: String = LoadoutDescribe.ability_text(cleave, _data, _class_def)
	for part: String in ["80%", "Breccia", "15%", "20%"]:
		assert_string_contains(text, part)
	var ward: AbilityDef = _ability(AbilityDef.KIND_WARD)
	ward.ward_pct = 15.0
	ward.duration_ms = 6000
	var ward_text: String = LoadoutDescribe.ability_text(ward, _data, _class_def)
	for part: String in ["Riparo", "15%", "6,0 s", "Ricarica"]:
		assert_string_contains(ward_text, part)
	assert_false(ward_text.contains(LoadoutDescribe.UNKNOWN_EFFECT_TEXT))


func test_stagger_application_has_no_percentage() -> void:
	var strike: AbilityDef = _ability(AbilityDef.KIND_STRIKE, 1.0)
	var stagger := ConditionApply.new()
	stagger.condition = ConditionApply.STAGGER
	stagger.ms = 1200
	strike.applies = [stagger]
	var text: String = LoadoutDescribe.ability_text(strike, _data, _class_def)
	assert_string_contains(text, "Sbilanciamento")
	assert_string_contains(text, "1,2 s")
