class_name DataValidatorLoot
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the loot keys of balance.json, M7
## (docs/04_DATA_SCHEMA.md §16): `upgrade` (F-86) and `salvage` (F-88). A missing or mistyped key is already
## reported by the required-key checks of DataValidator, so these rules skip what is not the right type.

const LEVEL_FIELDS: PackedStringArray = ["success_pct", "gold_per_grade", "ingots", "shards"]
const RARITIES: PackedStringArray = ["common", "magic", "rare"]
# Format limits (not design values).
const UPGRADE_LEVELS_MAX: int = 9  # Q28: raffinazione fino a +9
const GRADE_COUNT: int = 8  # one ingot item per grade 1..8 (DataValidatorItems.GRADE_MAX)


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var upgrade: Variant = DataValidator.lookup(balance, "upgrade")
	if upgrade is Dictionary:
		_upgrade(v, upgrade as Dictionary)
	var salvage: Variant = DataValidator.lookup(balance, "salvage")
	if salvage is Dictionary:
		_salvage(v, salvage as Dictionary)


## Item references (the items are collected before this runs). `upgrade.seal_item` is an id only: the item itself
## comes with the content of M7 (docs/07_TASKS.md M7-05), which adds its reference check.
static func validate_refs(v: DataValidatorRules, balance: Dictionary) -> void:
	var upgrade: Variant = DataValidator.lookup(balance, "upgrade")
	if not upgrade is Dictionary or not (upgrade as Dictionary).get("ingot_items") is Array:
		return
	var ids: Array = v.id_list(upgrade as Dictionary, "ingot_items", v.items, "item", GRADE_COUNT, "upgrade")
	if ids.size() != GRADE_COUNT:
		v.fail("field 'upgrade.ingot_items' needs exactly %d items (one per grade), got %d" % [GRADE_COUNT, ids.size()])


static func _upgrade(v: DataValidatorRules, upgrade: Dictionary) -> void:
	var levels: Array[Dictionary] = []
	if upgrade.get("levels") is Array:
		levels = v.object_list(upgrade, "levels", "upgrade", 1)
		if levels.size() > UPGRADE_LEVELS_MAX:
			v.fail("field 'upgrade.levels' has %d entries, at most %d" % [levels.size(), UPGRADE_LEVELS_MAX])
	for i: int in levels.size():
		var prefix: String = "upgrade.levels[%d]" % i
		v.keys(levels[i], LEVEL_FIELDS, prefix)
		v.number(levels[i], "success_pct", 0.0, 100.0, prefix, true)
		for field: String in ["gold_per_grade", "ingots", "shards"]:
			v.integer(levels[i], field, 0.0, DataValidatorRules.NO_LIMIT, prefix)
	if DataValidatorRules.is_number(upgrade.get("downgrade_from")):
		v.integer(upgrade, "downgrade_from", 1.0, float(maxi(levels.size(), 1)), "upgrade")
	if DataValidatorRules.is_number(upgrade.get("mod_pct_per_level")):
		v.number(upgrade, "mod_pct_per_level", 0.0, DataValidatorRules.NO_LIMIT, "upgrade", true)


static func _salvage(v: DataValidatorRules, salvage: Dictionary) -> void:
	if DataValidatorRules.is_number(salvage.get("ingot_ratio")):
		v.number(salvage, "ingot_ratio", 0.0, 1.0, "salvage")
	if not salvage.get("shards_by_rarity") is Dictionary:
		return
	var shards: Dictionary = salvage["shards_by_rarity"] as Dictionary
	v.keys(shards, RARITIES, "salvage.shards_by_rarity")
	for rarity: String in RARITIES:
		if not shards.has(rarity):
			v.fail("field 'salvage.shards_by_rarity.%s' is required" % rarity)
		else:
			v.integer(shards, rarity, 0.0, DataValidatorRules.NO_LIMIT, "salvage.shards_by_rarity")
