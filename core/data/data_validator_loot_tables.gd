class_name DataValidatorLootTables
extends RefCounted
## Loot table rules of DataValidator (internal, M12; docs/04_DATA_SCHEMA.md §8b): `data/combat/loot_tables.json` and the
## `loot_tables` references of areas, monsters and Rift Stones. The file is mandatory (see SINGLE_FILE_SECTIONS);
## it must have tables, and every table must be used by an area, a monster or a Rift Stone.

const TABLE_FIELDS: PackedStringArray = ["id", "entries"]
const ENTRY_FIELDS: PackedStringArray = ["item", "chance_pct", "qty"]
const CATEGORIES: PackedStringArray = ["material", "stone", "currency", "bag", "contract"]
const ENTRIES_MAX: int = 24
const CHANCE_MIN: float = 0.01


## `owners` is [[areas files, "areas", "area"], [monsters files, "monsters", "monster"], [stones files, "rift_stones",
## "rift stone"]]: the files of a section, the key of its list and the name of its entries.
static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary], owners: Array) -> void:
	var known: Dictionary[StringName, Dictionary] = {}
	var table_file: String = ""
	for path: String in files:
		table_file = path
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "tables")
		if list.is_empty():
			v.fail("the file needs at least 1 table")
		var seen: Dictionary[StringName, bool] = {}
		for index: int in list.size():
			var id: StringName = v.entry("loot table", index, list[index], seen, TABLE_FIELDS)
			if id != &"":
				known[id] = list[index]
			_entries(v, list[index])
	var used: Dictionary[StringName, bool] = {}
	for owner: Array in owners:
		var owner_files: Dictionary[String, Dictionary] = owner[0]
		for path: String in owner_files:
			v.at_file(path)
			var list: Array[Dictionary] = []
			list.assign((owner_files[path].get(owner[1], []) as Array).filter(func(x: Variant) -> bool: return x is Dictionary))
			for index: int in list.size():
				v.at_entry(owner[2] as String, index, list[index])
				if list[index].has("loot_tables"):
					for id: Variant in v.id_list(list[index], "loot_tables", known, "loot table", 0):
						used[StringName(id as String)] = true
	if table_file.is_empty():
		return
	v.at_file(table_file)
	for id: StringName in known:
		if not used.has(id):
			v.at_entry("loot table", 0, known[id])
			v.fail("not used by any area, monster or Rift Stone")


static func _entries(v: DataValidatorRules, table: Dictionary) -> void:
	var entries: Array[Dictionary] = v.object_list(table, "entries", "", 1)
	if entries.size() > ENTRIES_MAX:
		v.fail("field 'entries' has %d entries, at most %d" % [entries.size(), ENTRIES_MAX])
	for index: int in entries.size():
		var prefix: String = "entries[%d]" % index
		var entry: Dictionary = entries[index]
		v.keys(entry, ENTRY_FIELDS, prefix)
		if v.ref(entry, "item", v.items, "item", prefix):
			var category: String = str(v.items[StringName(entry["item"] as String)].get("category"))
			if not CATEGORIES.has(category):
				v.fail("field '%s.item': '%s' is %s, a loot table holds only %s" % [prefix, entry["item"], category, CATEGORIES])
		v.number(entry, "chance_pct", CHANCE_MIN, 100.0, prefix)
		v.int_pair(entry, "qty", 1, DataValidatorRules.NO_LIMIT, true, prefix)
