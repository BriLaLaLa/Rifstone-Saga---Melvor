extends GutTest
## GuideIndex (docs/05_INTERFACES.md §5.19): sources and uses on the fixtures (one case per kind present there) and on
## the real data (a sample for every kind of source and use), the summary line, the exceptions and unknown ids.

const FIXTURE_ROOT: String = "res://tests/fixtures/data"
const CONFIG_ROOT: String = "res://data/config"
const REAL_ROOT: String = "res://data"

var _fixture: GameData = null
var _real: GameData = null
var _fixture_index: GuideIndex = null
var _real_index: GuideIndex = null


## Index with declared exceptions, standing in for GameData.guide_exceptions() (M11-02).
class ExceptionIndex extends GuideIndex:
	static var declared: Dictionary = {}

	func _init(data: GameData) -> void:
		super(data)

	func _declared_exceptions() -> Dictionary:
		return declared



func before_all() -> void:
	_fixture = GameData.load_from_dirs(FIXTURE_ROOT, CONFIG_ROOT)
	_real = GameData.load_from_dirs(REAL_ROOT, CONFIG_ROOT)
	_fixture_index = GuideIndex.new(_fixture)
	_real_index = GuideIndex.new(_real)


func _kinds(refs: Array[GuideRef]) -> Array[StringName]:
	var result: Array[StringName] = []
	for ref: GuideRef in refs:
		if not result.has(ref.kind):
			result.append(ref.kind)
	return result


func _find(refs: Array[GuideRef], kind: StringName, target: StringName = &"") -> GuideRef:
	for ref: GuideRef in refs:
		if ref.kind == kind and (target == &"" or ref.target == target):
			return ref
	return null


func test_entry_ids() -> void:
	assert_eq(GuideIndex.entry(&"item", &"boar_tusk"), &"item:boar_tusk")
	assert_eq(GuideIndex.entry(&"monster", &"x"), &"monster:x")


func test_fixture_monster_stone_recipe_and_shop_sources() -> void:
	var refs: Array[GuideRef] = _fixture_index.sources_of(&"test_log")
	var monster: GuideRef = _find(refs, GuideRef.KIND_MONSTER, &"monster:test_monster_a")
	assert_not_null(monster)
	assert_eq(monster.label, "Mostro di prova A")
	assert_eq(monster.detail, "Area di prova, 25%")
	var stone: GuideRef = _find(refs, GuideRef.KIND_RIFT_STONE, &"area:test_stone_area")
	assert_not_null(stone)
	assert_eq(stone.label, "Pietra di prova")
	assert_eq(stone.detail, "Area della Pietra, 100%")
	assert_not_null(_find(refs, GuideRef.KIND_RECIPE, &"skill:test_gather"))
	assert_not_null(_find(refs, GuideRef.KIND_SHOP))


func test_fixture_uses() -> void:
	assert_not_null(_find(_fixture_index.uses_of(&"test_log"), GuideRef.KIND_RECIPE, &"skill:test_craft"))
	assert_not_null(_find(_fixture_index.uses_of(&"test_ration"), GuideRef.KIND_FOOD))
	assert_not_null(_find(_fixture_index.uses_of(&"test_infusion"), GuideRef.KIND_ALTAR))
	assert_not_null(_find(_fixture_index.uses_of(&"test_currency"), GuideRef.KIND_REFINE))


func test_real_drop_sources_have_area_and_percentage() -> void:
	var refs: Array[GuideRef] = _real_index.sources_of(&"boar_tusk")
	var carrier: MonsterDef = null  # M17-04: the monster that carries the tusk is generated, find it
	for candidate: AreaDef in _real.areas():
		for monster_id: StringName in candidate.monster_ids:
			for entry: DropEntry in _real.monster(monster_id).drops:
				if entry.item_id == &"boar_tusk":
					carrier = _real.monster(monster_id)
	assert_not_null(carrier)
	var monster: GuideRef = _find(refs, GuideRef.KIND_MONSTER, StringName("monster:" + String(carrier.id)))
	assert_not_null(monster)
	var drop: DropEntry = null
	for entry: DropEntry in carrier.drops:
		if entry.item_id == &"boar_tusk":
			drop = entry
	var area: AreaDef = null
	for candidate: AreaDef in _real.areas():
		if candidate.monster_ids.has(carrier.id):
			area = candidate
	assert_eq(monster.detail, "%s, %s%%" % [area.name, GuideIndex.num(drop.chance_pct)])


func test_real_stone_sources() -> void:
	var stone: GuideRef = _find(_real_index.sources_of(&"warding_seal"), GuideRef.KIND_RIFT_STONE,
			&"area:redrock_plains")
	assert_not_null(stone)
	assert_eq(stone.label, _real.rift_stones_for_area(&"redrock_plains")[0].name)
	assert_not_null(_find(_real_index.sources_of(&"rift_shard"), GuideRef.KIND_RIFT_STONE))


func test_real_recipe_blueprint_salvage_and_kit_sources() -> void:
	assert_not_null(_find(_real_index.sources_of(&"emberbronze_plate"), GuideRef.KIND_RECIPE, &"skill:forging"))
	var sword: Array[GuideRef] = _real_index.sources_of(&"emberbronze_sword")
	assert_not_null(_find(_real_index.sources_of(&"mw_sword_1"), GuideRef.KIND_BLUEPRINT, &"item:bp_mw_sword_1"))
	assert_not_null(_find(sword, GuideRef.KIND_STARTER_KIT))
	assert_not_null(_find(_real_index.sources_of(&"emberbronze_plate"), GuideRef.KIND_SALVAGE))
	assert_not_null(_find(_real_index.sources_of(&"unique_hatchet"), GuideRef.KIND_STARTER_KIT))
	assert_not_null(_find(_real_index.sources_of(&"seared_brookfin"), GuideRef.KIND_STARTER_KIT))


func test_real_uses() -> void:
	var plate: Array[GuideRef] = _real_index.uses_of(&"emberbronze_plate")
	assert_not_null(_find(plate, GuideRef.KIND_BLUEPRINT, &"item:bp_mw_sword_1"))
	assert_not_null(_find(plate, GuideRef.KIND_REFINE))
	assert_not_null(_find(_real_index.uses_of(&"boar_tusk"), GuideRef.KIND_BLUEPRINT))
	assert_not_null(_find(_real_index.uses_of(&"bp_mw_sword_1"), GuideRef.KIND_BLUEPRINT,
			&"item:mw_sword_1"))
	assert_not_null(_find(_real_index.uses_of(&"emberbronze_ingot"), GuideRef.KIND_RECIPE, &"skill:forging"))
	assert_not_null(_find(_real_index.uses_of(&"emberbronze_ingot"), GuideRef.KIND_REFINE))
	assert_not_null(_find(_real_index.uses_of(&"warding_seal"), GuideRef.KIND_REFINE))
	assert_not_null(_find(_real_index.uses_of(&"rift_shard"), GuideRef.KIND_REFINE))
	assert_not_null(_find(_real_index.uses_of(&"stone_ember_chip"), GuideRef.KIND_SOCKET))
	assert_not_null(_find(_real_index.uses_of(&"inf_swift_hands"), GuideRef.KIND_ALTAR))
	assert_not_null(_find(_real_index.uses_of(&"seared_brookfin"), GuideRef.KIND_FOOD))
	assert_not_null(_find(_real_index.uses_of(&"emberbronze_sword"), GuideRef.KIND_SALVAGE))
	assert_not_null(_find(_real_index.uses_of(&"unique_hatchet"), GuideRef.KIND_REFINE))
	assert_not_null(_find(_real_index.uses_of(&"currency_spark"), GuideRef.KIND_REFINE))


func test_every_ref_is_consistent_with_the_data() -> void:
	for item: ItemDef in _real.items():
		for ref: GuideRef in _real_index.sources_of(item.id) + _real_index.uses_of(item.id):
			assert_false(ref.label.is_empty(), "label of %s" % item.id)
			if ref.target != &"":
				var parts: PackedStringArray = String(ref.target).split(":")
				assert_eq(parts.size(), 2, "target of %s" % item.id)


func test_summary_line() -> void:
	var refs: Array[GuideRef] = []
	assert_eq(_real_index.summary_line(refs), "")
	for label: String in ["a", "b", "c"]:
		refs.append(GuideRef.make(GuideRef.KIND_MONSTER, &"", label))
	assert_eq(_real_index.summary_line(refs), "a, b, c")
	refs.append(GuideRef.make(GuideRef.KIND_MONSTER, &"", "d"))
	assert_eq(_real_index.summary_line(refs), "a, b, c e altro")
	assert_eq(_real_index.summary_line(refs, 2), "a, b e altro")
	refs.append(GuideRef.make(GuideRef.KIND_MONSTER, &"", "a"))
	assert_eq(_real_index.summary_line(refs, 4), "a, b, c, d", "repeated labels count once")


func test_items_without_source_and_use_list_orphans() -> void:
	# Real data: every orphan is covered by a declared exception, so both lists are empty.
	# M14-05: pieces and blueprints get their sources from the drop pool and the legendaries (M14-08, F-121, F-124).
	var missing: Array[StringName] = []
	for id: StringName in _real_index.items_without_source():
		if not [&"equipment", &"tool", &"blueprint"].has(_real.item(id).category):
			missing.append(id)
	assert_eq(missing.size(), 0, str(missing))
	assert_eq(_real_index.items_without_use().size(), 0, str(_real_index.items_without_use()))
	# Fixtures have orphans (and no exceptions): the lists match exactly the items without source/use.
	var no_source: Array[StringName] = _fixture_index.items_without_source()
	var no_use: Array[StringName] = _fixture_index.items_without_use()
	assert_gt(no_source.size(), 0, "fixtures have items without a source")
	assert_gt(no_use.size(), 0, "fixtures have items without a use")
	for item: ItemDef in _fixture.items():
		assert_eq(no_source.has(item.id), _fixture_index.sources_of(item.id).is_empty(), "source of %s" % item.id)
		assert_eq(no_use.has(item.id), _fixture_index.uses_of(item.id).is_empty(), "use of %s" % item.id)


func test_exceptions_are_excluded() -> void:
	var no_source: Array[StringName] = _fixture_index.items_without_source()
	var no_use: Array[StringName] = _fixture_index.items_without_use()
	assert_gt(no_source.size(), 0, "the fixtures still have items without a source")
	assert_gt(no_use.size(), 0, "the fixtures still have items without a use")
	ExceptionIndex.declared = {"no_source": [String(no_source[0])], "no_use": [String(no_use[0])]}
	var index: GuideIndex = ExceptionIndex.new(_fixture)
	assert_false(index.items_without_source().has(no_source[0]))
	assert_eq(index.items_without_source().size(), no_source.size() - 1)
	assert_false(index.items_without_use().has(no_use[0]))
	assert_eq(index.items_without_use().size(), no_use.size() - 1)
	ExceptionIndex.declared = {}


func test_unknown_item_gives_empty_list_and_error() -> void:
	assert_eq(_real_index.sources_of(&"no_such_item").size(), 0)
	assert_eq(_real_index.uses_of(&"no_such_item").size(), 0)
	assert_push_error(2)
