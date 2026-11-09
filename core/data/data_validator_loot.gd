class_name DataValidatorLoot
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the loot keys of balance.json, M7
## (docs/04_DATA_SCHEMA.md §16): `upgrade` (F-86) and `salvage` (F-95). A missing or mistyped key is already
## reported by the required-key checks of DataValidator, so these rules skip what is not the right type.

const LEVEL_FIELDS: PackedStringArray = ["success_pct", "gold_per_grade", "ingots", "shards", "dust"]  # M14: dust from +5 (F-86, Q71)
const RARITIES: PackedStringArray = ["common", "magic", "rare", "masterwork", "legendary"]  # M14: five rarities
# Format limits (not design values).
const UPGRADE_LEVELS_MAX: int = 9  # Q28: raffinazione fino a +9
const GRADE_COUNT: int = 8  # one ingot item per grade 1..8 (DataValidatorItems.GRADE_MAX)


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var upgrade: Variant = DataValidator.lookup(balance, "upgrade")
	if upgrade is Dictionary:
		_upgrade(v, upgrade as Dictionary)
	var sockets: Variant = DataValidator.lookup(balance, "sockets")
	if sockets is Dictionary:
		_sockets(v, sockets as Dictionary)
	var salvage: Variant = DataValidator.lookup(balance, "salvage")
	if salvage is Dictionary:
		_salvage(v, salvage as Dictionary)
	var stone: Variant = DataValidator.lookup(balance, "rift_stone")
	if stone is Dictionary:
		_rift_stone(v, stone as Dictionary)
	for source: String in ["drop", "rift_stone"]:  # F-84 rarity chances (percent)
		var rarity: Variant = DataValidator.lookup(balance, "rarity.%s" % source)
		if rarity is Dictionary:
			for key: String in ["magic_pct", "rare_pct"]:
				if DataValidatorRules.is_number((rarity as Dictionary).get(key)):
					v.number(rarity as Dictionary, key, 0.0, 100.0, "rarity.%s" % source)


## Item references (the items are collected before this runs): `upgrade.ingot_items` and `upgrade.seal_item`.
static func validate_refs(v: DataValidatorRules, balance: Dictionary) -> void:
	var upgrade: Variant = DataValidator.lookup(balance, "upgrade")
	if not upgrade is Dictionary:
		return
	var seal: Variant = (upgrade as Dictionary).get("seal_item")
	if seal is String and not (seal as String).is_empty():
		v.ref(upgrade as Dictionary, "seal_item", v.items, "item", "upgrade")
	if not (upgrade as Dictionary).get("ingot_items") is Array:
		return
	var ids: Array = v.id_list(upgrade as Dictionary, "ingot_items", v.items, "item", GRADE_COUNT, "upgrade")
	if ids.size() != GRADE_COUNT:
		v.fail("field 'upgrade.ingot_items' needs exactly %d items (one per grade), got %d" % [GRADE_COUNT, ids.size()])


# F-89 (M8): sockets per rarity (>= 0) and the refinement level that gives one more (1..upgrade.levels).
static func _sockets(v: DataValidatorRules, sockets: Dictionary) -> void:
	v.keys(sockets, ["by_rarity", "bonus_at_upgrade"], "sockets")
	if not v.object(sockets, "by_rarity", "sockets").is_empty():
		var by_rarity: Dictionary = sockets["by_rarity"] as Dictionary
		v.keys(by_rarity, RARITIES, "sockets.by_rarity")
		for rarity: String in RARITIES:
			v.integer(by_rarity, rarity, 0.0, DataValidatorRules.NO_LIMIT, "sockets.by_rarity")
	v.integer(sockets, "bonus_at_upgrade", 1.0, float(UPGRADE_LEVELS_MAX), "sockets")


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
		if levels[i].has("dust"):  # optional: the fixtures of earlier milestones have none
			v.integer(levels[i], "dust", 0.0, DataValidatorRules.NO_LIMIT, prefix)
	if DataValidatorRules.is_number(upgrade.get("downgrade_from")):
		v.integer(upgrade, "downgrade_from", 1.0, float(maxi(levels.size(), 1)), "upgrade")
	if DataValidatorRules.is_number(upgrade.get("mod_pct_per_level")):
		v.number(upgrade, "mod_pct_per_level", 0.0, DataValidatorRules.NO_LIMIT, "upgrade", true)


static func _rift_stone(v: DataValidatorRules, stone: Dictionary) -> void:  # F-87
	if DataValidatorRules.is_number(stone.get("chance_pct")):
		v.number(stone, "chance_pct", 0.0, 100.0, "rift_stone")
	if DataValidatorRules.is_number(stone.get("pity_kills")):
		v.integer(stone, "pity_kills", 1.0, DataValidatorRules.NO_LIMIT, "rift_stone")


static func _salvage(v: DataValidatorRules, salvage: Dictionary) -> void:
	if DataValidatorRules.is_number(salvage.get("component_ratio")):
		v.number(salvage, "component_ratio", 0.0, 1.0, "salvage")
	if not salvage.get("shards_by_rarity") is Dictionary:
		return
	var shards: Dictionary = salvage["shards_by_rarity"] as Dictionary
	v.keys(shards, RARITIES, "salvage.shards_by_rarity")
	for rarity: String in RARITIES:
		if not shards.has(rarity):
			v.fail("field 'salvage.shards_by_rarity.%s' is required" % rarity)
		else:
			v.integer(shards, rarity, 0.0, DataValidatorRules.NO_LIMIT, "salvage.shards_by_rarity")
