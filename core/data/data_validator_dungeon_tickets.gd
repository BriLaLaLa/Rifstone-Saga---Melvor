class_name DataValidatorDungeonTickets
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the tickets of the dungeons (docs/04_DATA_SCHEMA.md §27).
## A ticket is a `misc` item with `value` 0 and a `dungeon` id; every dungeon has exactly one. It may drop only from the
## minibosses of the areas whose last level reaches the level required by the dungeon (the first areas have no ticket)
## and from the loot tables of the Rift Stones of those areas; nowhere else.


static func validate(v: DataValidatorRules, raw: Dictionary) -> void:
	if not raw.has("dungeons"):
		return  # a raw dictionary built without the section (older tests): there is nothing to cross-check
	var dungeon_files: Dictionary = DataValidatorDungeon.section(raw, "dungeons")
	var required: Dictionary[StringName, int] = {}  # dungeon id -> level required
	var paths: Dictionary[StringName, String] = {}
	for path: Variant in dungeon_files:
		var d: Dictionary = dungeon_files[path] as Dictionary
		if d.get("id") is String:
			required[StringName(d["id"] as String)] = int((d.get("requirements", {}) as Dictionary).get("character", 0))
			paths[StringName(d["id"] as String)] = str(path)
	var tickets: Dictionary[StringName, StringName] = _tickets(v, raw, required)  # item id -> dungeon id
	var count: Dictionary[StringName, int] = {}
	for dungeon: StringName in tickets.values():
		count[dungeon] = count.get(dungeon, 0) + 1
	for dungeon: StringName in required:
		if count.get(dungeon, 0) != 1:
			v.at_file(paths[dungeon])
			v.at_entry("dungeon", 0, {"id": str(dungeon)})
			v.fail("%d tickets (items with `dungeon` '%s'), exactly 1 is needed" % [count.get(dungeon, 0), dungeon])
	if tickets.is_empty():
		return
	var levels: Dictionary[StringName, int] = _area_levels(raw)  # area id -> level_max (narrow areas only)
	var mini_area: Dictionary[StringName, StringName] = _miniboss_areas(raw)  # miniboss id -> area id
	_monsters(v, raw, tickets, required, levels, mini_area)
	_dungeon_drops(v, raw, tickets)
	_tables(v, raw, tickets, required, levels)


# The items with a `dungeon` field: category misc, value 0, a known dungeon. Returns item id -> dungeon id.
static func _tickets(v: DataValidatorRules, raw: Dictionary, required: Dictionary[StringName, int]) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	var files: Dictionary = DataValidatorDungeon.section(raw, "items")
	for path: Variant in files:
		var list: Array = (files[path] as Dictionary).get("items", []) as Array
		for index: int in list.size():
			var e: Variant = list[index]
			if not e is Dictionary or not (e as Dictionary).has("dungeon"):
				continue
			var item: Dictionary = e as Dictionary
			v.at_file(str(path))
			var id: StringName = v.at_entry("item", index, item)
			if str(item.get("category")) != "misc":
				v.fail("field 'dungeon': only a `misc` item can be a ticket")
			if not DataValidatorRules.is_int(item.get("value")) or int(item["value"]) != 0:
				v.fail("a ticket must have value 0 (it cannot be sold)")
			if not v.text(item, "dungeon") or not required.has(StringName(item["dungeon"] as String)):
				if item.get("dungeon") is String:
					v.fail("field 'dungeon': unknown dungeon '%s'" % item["dungeon"])
				continue
			result[id] = StringName(item["dungeon"] as String)
	return result


static func _area_levels(raw: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var files: Dictionary = DataValidatorDungeon.section(raw, "areas")
	for path: Variant in files:
		for a: Variant in ((files[path] as Dictionary).get("areas", []) as Array):
			if a is Dictionary and (a as Dictionary).get("id") is String and DataValidatorRules.is_int((a as Dictionary).get("level_max")):
				result[StringName((a as Dictionary)["id"] as String)] = int((a as Dictionary)["level_max"])
	return result


static func _miniboss_areas(raw: Dictionary) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	var files: Dictionary = DataValidatorDungeon.section(raw, "areas")
	for path: Variant in files:
		for a: Variant in ((files[path] as Dictionary).get("areas", []) as Array):
			if a is Dictionary and (a as Dictionary).get("miniboss") is Dictionary \
					and ((a as Dictionary)["miniboss"] as Dictionary).get("monster") is String and (a as Dictionary).get("id") is String:
				result[StringName(((a as Dictionary)["miniboss"] as Dictionary)["monster"] as String)] = StringName((a as Dictionary)["id"] as String)
	return result


# The monsters of the areas: only a miniboss drops a ticket, and only in an area high enough for the dungeon.
static func _monsters(v: DataValidatorRules, raw: Dictionary, tickets: Dictionary[StringName, StringName],
		required: Dictionary[StringName, int], levels: Dictionary[StringName, int], mini_area: Dictionary[StringName, StringName]) -> void:
	var files: Dictionary = DataValidatorDungeon.section(raw, "monsters")
	for path: Variant in files:
		var list: Array = (files[path] as Dictionary).get("monsters", []) as Array
		for index: int in list.size():
			if not list[index] is Dictionary:
				continue
			var monster: Dictionary = list[index] as Dictionary
			for drop: Variant in (monster.get("drops", []) as Array):
				var item := StringName(str((drop as Dictionary).get("item"))) if drop is Dictionary else &""
				if not tickets.has(item):
					continue
				v.at_file(str(path))
				v.at_entry("monster", index, monster)
				if monster.get("miniboss") != true:
					v.fail("field 'drops': the ticket '%s' drops only from an area miniboss" % item)
				elif mini_area.has(StringName(str(monster.get("id")))):
					_level_fits(v, "monster", item, mini_area[StringName(str(monster["id"]))], tickets, required, levels)


# The monsters and the boss of a dungeon never drop a ticket.
static func _dungeon_drops(v: DataValidatorRules, raw: Dictionary, tickets: Dictionary[StringName, StringName]) -> void:
	var files: Dictionary = DataValidatorDungeon.section(raw, "dungeons")
	for path: Variant in files:
		var d: Dictionary = files[path] as Dictionary
		var owners: Array = (d.get("monsters", []) as Array).duplicate()
		owners.append(d.get("boss", {}))
		for owner: Variant in owners:
			for drop: Variant in ((owner as Dictionary).get("drops", []) as Array if owner is Dictionary else []):
				if drop is Dictionary and tickets.has(StringName(str((drop as Dictionary).get("item")))):
					v.at_file(str(path))
					v.at_entry("dungeon", 0, d)
					v.fail("field 'drops': the ticket '%s' does not drop inside a dungeon" % (drop as Dictionary).get("item"))


# The loot tables with a ticket: used only by Rift Stones of an area high enough.
static func _tables(v: DataValidatorRules, raw: Dictionary, tickets: Dictionary[StringName, StringName],
		required: Dictionary[StringName, int], levels: Dictionary[StringName, int]) -> void:
	var tables: Dictionary[StringName, Dictionary] = DataValidatorDungeon.loot_tables(raw)
	var with_ticket: Dictionary[StringName, StringName] = {}  # table id -> ticket item id
	for id: StringName in tables:
		for entry: Variant in (tables[id].get("entries", []) as Array):
			if entry is Dictionary and tickets.has(StringName(str((entry as Dictionary).get("item")))):
				with_ticket[id] = StringName(str((entry as Dictionary)["item"]))
	if with_ticket.is_empty():
		return
	var table_files: Dictionary = DataValidatorDungeon.section(raw, "loot_tables")
	v.at_file(str(table_files.keys()[0]) if not table_files.is_empty() else "loot_tables.json")
	for section: Array in [["areas", "areas", "area"], ["monsters", "monsters", "monster"], ["rift_stones", "rift_stones", "Rift Stone"]]:
		var files: Dictionary = DataValidatorDungeon.section(raw, section[0] as String)
		for path: Variant in files:
			for owner: Variant in ((files[path] as Dictionary).get(section[1] as String, []) as Array):
				if not owner is Dictionary:
					continue
				for table: Variant in ((owner as Dictionary).get("loot_tables", []) as Array):
					var table_id := StringName(str(table))
					if not with_ticket.has(table_id):
						continue
					v.at_entry("loot table", 0, {"id": str(table_id)})
					if section[0] != "rift_stones":
						v.fail("the ticket '%s' is in a table used by the %s '%s': tickets drop only from Rift Stones and minibosses"
								% [with_ticket[table_id], section[2], (owner as Dictionary).get("id")])
					else:
						_level_fits(v, "Rift Stone", with_ticket[table_id], StringName(str((owner as Dictionary).get("area"))),
								tickets, required, levels)
	var dungeon_files: Dictionary = DataValidatorDungeon.section(raw, "dungeons")
	for path: Variant in dungeon_files:
		var d: Dictionary = dungeon_files[path] as Dictionary
		v.at_file(str(path))
		if with_ticket.has(StringName(str(d.get("loot_table")))):
			v.at_entry("dungeon", 0, d)
			v.fail("field 'loot_table': the table holds the ticket '%s'" % with_ticket[StringName(str(d["loot_table"]))])
		for m: Variant in (d.get("monsters", []) as Array):
			for table: Variant in ((m as Dictionary).get("loot_tables", []) as Array if m is Dictionary else []):
				if with_ticket.has(StringName(str(table))):
					v.at_entry("dungeon monster", 0, m as Dictionary)
					v.fail("field 'loot_tables': the table '%s' holds the ticket '%s'" % [table, with_ticket[StringName(str(table))]])


# The ticket `item` of dungeon D may drop in `area` only if the area's last level reaches D's required level.
static func _level_fits(v: DataValidatorRules, kind: String, item: StringName, area: StringName,
		tickets: Dictionary[StringName, StringName], required: Dictionary[StringName, int], levels: Dictionary[StringName, int]) -> void:
	if not levels.has(area):
		return  # old-format areas have no levels
	if levels[area] < required.get(tickets[item], 0):
		v.fail("the %s drops the ticket '%s' in the area '%s' (up to level %d), below the level %d the dungeon requires"
				% [kind, item, area, levels[area], required.get(tickets[item], 0)])
