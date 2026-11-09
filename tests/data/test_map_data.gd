extends GutTest
## The real Cards and map modifiers (M13-04; docs/04_DATA_SCHEMA.md §11.1-§11.2, 02_FORMULAS.md F-109, F-111, docs/NOMI.md
## section Fratture): ten Cards with the names of NOMI.md, the twelve modifiers of F-111, four distinct risk types at
## every grade, no name from other games.

const CARD_NAMES: Array[String] = ["Carta della Radura", "Carta del Sentiero", "Carta della Palude", "Carta della Cripta",
	"Carta della Fucina spenta", "Carta del Baratro", "Carta della Guglia spezzata", "Carta dell'Eclissi",
	"Carta della Vertigine", "Carta dell'Origine"]
## id -> [name, min_grade, weight, risk type, risk min, risk max, reward type, reward min, reward max] (F-111 table).
const MODS: Dictionary = {
	&"sturdy": ["Mostri robusti", 1, 10, &"monster_hp_pct", 20, 60, &"loot_qty_pct", 5, 15],
	&"assault": ["Assalto", 1, 10, &"monster_speed_pct", 10, 35, &"item_rarity_pct", 10, 35],
	&"famine": ["Fame", 1, 8, &"food_heal_pct", 20, 60, &"blueprint_pct", 25, 75],
	&"brutal": ["Brutalità", 1, 8, &"monster_damage_pct", 15, 45, &"gold_drop_pct", 20, 60],
	&"hordes": ["Orde", 2, 8, &"pack_bonus", 1, 2, &"xp_pct", 10, 30],
	&"pulses": ["Impulsi", 2, 8, &"pulse", 2, 5, &"dust_pct", 20, 60],
	&"shrouded": ["Velati", 3, 6, &"monster_defence_pct", 20, 60, &"card_chance_pct", 20, 60],
	&"fasting": ["Digiuno", 4, 6, &"food_heal_pct", 50, 90, &"xp_pct", 25, 50],
	&"titans": ["Titani del Rift", 5, 6, &"monster_hp_pct", 60, 120, &"card_chance_pct", 30, 70],
	&"spectral": ["Lame spettrali", 5, 6, &"monster_damage_pct", 40, 90, &"item_rarity_pct", 30, 70],
	&"frenzy": ["Frenesia del Rift", 6, 6, &"monster_speed_pct", 30, 60, &"loot_qty_pct", 15, 35],
	&"abyssal": ["Tempesta dell'Abisso", 8, 6, &"pulse", 4, 8, &"blueprint_pct", 60, 120],
}
const FORBIDDEN: PackedStringArray = ["Melvor", "Metin", "Path of Exile"]

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


func test_ten_cards_with_the_names_of_nomi() -> void:
	for grade: int in range(1, 11):
		var base: ItemDef = _data.map_base(grade)
		assert_not_null(base, "Card of grade %d" % grade)
		if base == null:
			continue
		assert_eq(String(base.id), "fracture_card_%d" % grade)
		assert_eq(base.name, CARD_NAMES[grade - 1])
		assert_eq(base.map_grade, grade)
		assert_true(base.is_map())
		assert_eq(base.value, 0, "a Card cannot be sold")
		assert_true(ResourceLoader.exists(base.icon), "icon of %s" % base.id)
		assert_ne(base.description.strip_edges(), "")


func test_twelve_modifiers_with_the_values_of_f111() -> void:
	assert_eq(_data.map_mods().size(), MODS.size())
	for id: StringName in MODS:
		var m: MapModDef = _data.map_mod(id)
		assert_not_null(m, String(id))
		if m == null:
			continue
		var row: Array = MODS[id]
		assert_eq(m.name, row[0], "name of %s" % id)
		assert_eq(m.min_grade, row[1], "min_grade of %s" % id)
		assert_eq(m.weight, row[2], "weight of %s" % id)
		assert_eq(m.risk.type, row[3])
		assert_eq([m.risk.min_value, m.risk.max_value], [float(row[4]), float(row[5])], "risk of %s" % id)
		assert_eq(m.reward.type, row[6])
		assert_eq([m.reward.min_value, m.reward.max_value], [float(row[7]), float(row[8])], "reward of %s" % id)
		assert_ne(m.description.strip_edges(), "")


func test_every_grade_has_four_distinct_risk_types() -> void:
	for grade: int in range(1, 11):
		var risks: Dictionary = {}
		for m: MapModDef in _data.map_mods():
			if m.min_grade <= grade:
				risks[m.risk.type] = true
		assert_gte(risks.size(), 4, "grade %d" % grade)


func test_no_name_from_other_games() -> void:
	var texts: Array[String] = []
	for grade: int in range(1, 11):
		texts.append(_data.map_base(grade).name + " " + _data.map_base(grade).description)
	for m: MapModDef in _data.map_mods():
		texts.append(m.name + " " + m.description)
	for text: String in texts:
		for word: String in FORBIDDEN:
			assert_false(text.contains(word), "%s in '%s'" % [word, text])


func test_guide_page_exists() -> void:
	var found: bool = false
	for page: GuidePageDef in _data.guide_pages():
		if page.id == &"guide_fractures":
			found = true
	assert_true(found, "guide_fractures")
