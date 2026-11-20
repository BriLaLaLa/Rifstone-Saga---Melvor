class_name DataValidatorSellableDrops
extends RefCounted
## Part of DataValidator (internal, not API for other modules): every item that can drop must be sellable
## (`value` >= 1), otherwise a surplus stays stuck in the Stash (docs/DECISIONS_LOG.md V37, docs/OPEN_QUESTIONS.md Q183).
## Droppable = the entries of the loot tables, the `drops` of areas, monsters, Rift Stones and bosses, plus the items with
## a dedicated drop key: `rift_shard`, `rift_dust`, every blueprint (random project drop) and every currency (dungeon
## boss crystals). Exception: the Cards (category `map`) never reach the Stash (CardStore) and have value 0.

const ALWAYS_DROPPED: Array[StringName] = [&"rift_shard", &"rift_dust"]
const ALWAYS_DROPPED_CATEGORIES: PackedStringArray = ["blueprint", "currency"]
const EXEMPT_CATEGORY: String = "map"


## `tables` = the loot table files, `owners` = the same `[files, key, kind]` triples DataValidatorLootTables receives.
static func validate(v: DataValidatorRules, tables: Dictionary[String, Dictionary], owners: Array) -> void:
	var dropped: Dictionary[StringName, bool] = {}
	for id: StringName in ALWAYS_DROPPED:
		dropped[id] = true
	for id: StringName in v.items:
		if ALWAYS_DROPPED_CATEGORIES.has(str(v.items[id].get("category"))):
			dropped[id] = true
	for path: String in tables:
		for table: Variant in _dicts(tables[path].get("tables")):
			_collect(dropped, (table as Dictionary).get("entries"))
	for owner: Array in owners:
		var files: Dictionary[String, Dictionary] = owner[0]
		for path: String in files:
			for e: Variant in _dicts(files[path].get(owner[1] as String)):
				_collect(dropped, (e as Dictionary).get("drops"))
	var ids: Array[StringName] = dropped.keys()
	ids.sort()
	for id: StringName in ids:
		if not v.items.has(id) or str(v.items[id].get("category")) == EXEMPT_CATEGORY:
			continue
		var value: Variant = v.items[id].get("value")
		if DataValidatorRules.is_number(value) and float(value) < 1.0:
			v.at_file("items")
			v.at_entry("item", 0, v.items[id])
			v.fail("a droppable item must have 'value' >= 1 (it can be sold; only Cards are exempt)")


static func _collect(into: Dictionary[StringName, bool], entries: Variant) -> void:
	for e: Variant in _dicts(entries):
		if (e as Dictionary).get("item") is String:
			into[StringName((e as Dictionary)["item"] as String)] = true


static func _dicts(list: Variant) -> Array:
	return (list as Array).filter(func(x: Variant) -> bool: return x is Dictionary) if list is Array else []
