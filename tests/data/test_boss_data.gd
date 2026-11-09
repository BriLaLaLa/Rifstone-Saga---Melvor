extends GutTest
## The real bosses (M13-04; docs/04_DATA_SCHEMA.md §11.3, 02_FORMULAS.md F-112, F-115, docs/NOMI.md section Fratture):
## one per grade with the NOMI name and ability, valid icon, summons from the monsters of the grade.

const NAMES: Array[String] = ["Zannalunga, il Gran Cinghiale", "Capobranco Cenere", "Re del Fango", "Cavaliere senza Nome",
	"Custode della Fucina", "Strega delle Vene Nere", "Guardiano della Guglia", "Colosso d'Ossidiana", "Araldo dell'Eclissi",
	"Il Primo Frammento"]
const ABILITIES: Array[StringName] = [&"heavy_strike", &"summon", &"shield", &"heavy_strike", &"shield", &"summon",
	&"heavy_strike", &"shield", &"summon", &"heavy_strike"]
const FORBIDDEN: PackedStringArray = ["Melvor", "Metin", "Path of Exile"]

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func test_one_boss_per_grade_with_name_and_ability_of_nomi() -> void:
	for grade: int in range(1, 11):
		var b: BossDef = _data.boss_for_grade(grade)
		assert_not_null(b, "boss of grade %d" % grade)
		if b == null:
			continue
		assert_eq(String(b.id), "boss_grade_%d" % grade)
		assert_eq(b.grade, grade)
		assert_eq(b.name, NAMES[grade - 1])
		assert_not_null(b.ability, b.name)
		if b.ability != null:
			assert_eq(b.ability.type, ABILITIES[grade - 1], b.name)
		assert_ne(b.description.strip_edges(), "")
		for word: String in FORBIDDEN:
			assert_false((b.name + b.description).contains(word))


func test_abilities_distribution_and_icons() -> void:
	var counts: Dictionary = {}
	for grade: int in range(1, 11):
		var b: BossDef = _data.boss_for_grade(grade)
		counts[b.ability.type] = int(counts.get(b.ability.type, 0)) + 1
		assert_true(ResourceLoader.exists(b.icon), "icon of %s" % b.id)
		assert_true(b.icon.begins_with("res://assets/icons/monsters/"), b.icon)
	for type: StringName in [&"heavy_strike", &"shield", &"summon"]:
		assert_gte(int(counts.get(type, 0)), 3, String(type))


func test_summoned_monsters_belong_to_the_areas_of_the_grade() -> void:
	var rows: Array = _data.balance_value("fracture.grades") as Array
	for grade: int in range(1, 11):
		var b: BossDef = _data.boss_for_grade(grade)
		if b.ability.type != BossAbilityDef.SUMMON:
			continue
		var allowed: Array[StringName] = []
		for area_id: Variant in (rows[grade - 1] as Dictionary)["areas"]:
			allowed.append_array(_data.area(StringName(area_id)).monster_ids)
		for monster_id: StringName in b.ability.monsters:
			assert_true(allowed.has(monster_id), "%s summons %s" % [b.id, monster_id])
		assert_lte(b.ability.max_alive + 1, int(_data.balance_value("combat.max_pack_size")))


func test_stats_grow_with_the_grade() -> void:
	for grade: int in range(2, 11):
		var prev: BossDef = _data.boss_for_grade(grade - 1)
		var cur: BossDef = _data.boss_for_grade(grade)
		assert_gt(cur.hp, prev.hp, "hp grade %d" % grade)
		assert_gte(cur.xp, prev.xp, "xp grade %d" % grade)
		assert_gte(cur.dust_min, prev.dust_min, "dust grade %d" % grade)
	for grade: int in range(1, 11):
		var b: BossDef = _data.boss_for_grade(grade)
		assert_gte(b.dust_min, 1)
		assert_gte(b.dust_max, b.dust_min)
