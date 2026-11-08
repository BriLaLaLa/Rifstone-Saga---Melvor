class_name DataValidatorGuide
extends RefCounted
## Part of DataValidator (internal, not API for other modules): `data/guide/*.json` (M11, docs/04_DATA_SCHEMA.md §19),
## written with the toolkit of DataValidatorRules. The texts are checked with GuideText.check on lookups built from the
## raw files (GameData does not exist yet). `exceptions.json` is the one file without `pages`.
## The folder is optional: no `raw["guide"]` or an empty one is valid.

const GUIDE_DIR: String = "guide"
const EXCEPTIONS_FILE: String = "exceptions.json"
const SECTIONS: PackedStringArray = ["first_steps", "character", "loot", "crafts", "altar", "offline"]
const PAGE_FIELDS: PackedStringArray = ["id", "section", "title", "order", "blocks", "help_for", "allow_digits"]
const BLOCK_TYPES: PackedStringArray = ["text", "heading", "table", "links"]
## Generated tables a `table` block may use: GuideTables.ids() (single definition) plus the families
## `actions:<skill>`, `area_monsters:<area>`, `monster_drops:<monster>`, `mastery_milestones:<skill>` for an existing skill, area or monster.
## Game pages the "?" can open (PageHost routes, plus `skill:<id>` for an existing skill).
const ROUTES: PackedStringArray = ["bank", "shop", "equipment", "armory", "character", "combat", "rift", "altar", "settings"]
const SKILL_ROUTE_PREFIX: String = "skill:"
const EXCEPTION_KEYS: PackedStringArray = ["no_source", "no_use"]
const INDEX_SCRIPT: String = "res://core/guide/guide_index.gd"


## The `.json` files of the guide folder; a missing folder gives an empty list (the Guide data is optional).
static func list_files(content_root: String, errors: PackedStringArray) -> PackedStringArray:
	var dir: String = content_root.path_join(GUIDE_DIR)
	if not DirAccess.dir_exists_absolute(dir):
		return PackedStringArray()
	return JsonLoader.list_json_files(dir, errors)


static func validate(v: DataValidatorRules, raw: Dictionary) -> void:
	var files: Dictionary[String, Dictionary] = {}
	var section: Variant = raw.get(GUIDE_DIR)
	for path: Variant in (section as Dictionary if section is Dictionary else {}):
		if (section as Dictionary)[path] is Dictionary:
			files[str(path)] = (section as Dictionary)[path] as Dictionary
	if files.is_empty():
		return
	var pages: Dictionary[StringName, bool] = {}
	for path: String in files:
		if path.get_file() != EXCEPTIONS_FILE:
			for e: Dictionary in _Context._list(files[path], "pages"):
				pages[StringName(e["id"] as String)] = true
	var context := _Context.new(raw, pages)
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		if path.get_file() == EXCEPTIONS_FILE:
			_exceptions(v, files[path], context)
		else:
			_pages(v, files[path], seen, context)


## The errors of the exceptions that are not needed: an `no_source` item that has a source or a `no_use` item that has
## a use (`has_source`/`has_use`: Callable(id: StringName) -> bool).
static func superfluous_exceptions(exceptions: Dictionary, has_source: Callable, has_use: Callable) -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: StringName in exceptions.get("no_source", []) as Array:
		if has_source.call(id):
			errors.append("%s: superfluous exception no_source '%s': the item has a source" % [EXCEPTIONS_FILE, id])
	for id: StringName in exceptions.get("no_use", []) as Array:
		if has_use.call(id):
			errors.append("%s: superfluous exception no_use '%s': the item has a use" % [EXCEPTIONS_FILE, id])
	return errors


## `superfluous_exceptions` against the GuideIndex of `data` (M11-01); with no index script yet nothing is checked.
static func check_exceptions(data: GameData) -> PackedStringArray:
	if not ResourceLoader.exists(INDEX_SCRIPT):
		return PackedStringArray()
	var index: RefCounted = (load(INDEX_SCRIPT) as GDScript).new(data) as RefCounted
	return superfluous_exceptions(data.guide_exceptions(),
			func(id: StringName) -> bool: return not (index.call("sources_of", id) as Array).is_empty(),
			func(id: StringName) -> bool: return not (index.call("uses_of", id) as Array).is_empty())


static func _pages(v: DataValidatorRules, content: Dictionary, seen: Dictionary[StringName, bool], context: _Context) -> void:
	var list: Array[Dictionary] = DataValidator.entries(v, content, "pages")
	for index: int in list.size():
		var e: Dictionary = list[index]
		v.entry("guide page", index, e, seen, PAGE_FIELDS)
		v.text(e, "title")
		v.one_of(e, "section", SECTIONS)
		v.integer(e, "order", 0.0)
		var digits_ok: bool = false
		if e.has("allow_digits") and v.flag(e, "allow_digits"):
			digits_ok = e["allow_digits"] as bool
		if e.get("title") is String:
			_text(v, e["title"] as String, "title", digits_ok, context)
		if e.has("help_for"):
			for route: String in v.id_list(e, "help_for", null, "route", 0):
				if not context.is_route(route):
					v.fail("field 'help_for': unknown route '%s'" % route)
		var blocks: Array[Dictionary] = v.object_list(e, "blocks", "", 1)
		for position: int in blocks.size():
			_block(v, blocks[position], "blocks[%d]" % position, digits_ok, context)


static func _block(v: DataValidatorRules, block: Dictionary, prefix: String, digits_ok: bool, context: _Context) -> void:
	if not v.one_of(block, "type", BLOCK_TYPES, prefix):
		return
	match block["type"]:
		"text", "heading":
			v.keys(block, ["type", "text"], prefix)
			if v.text(block, "text", prefix):
				_text(v, block["text"] as String, "%s.text" % prefix, digits_ok, context)
		"table":
			v.keys(block, ["type", "source"], prefix)
			if v.text(block, "source", prefix) and not context.is_table(block["source"] as String):
				v.fail("field '%s.source': unknown table source '%s'" % [prefix, block["source"]])
		"links":
			v.keys(block, ["type", "targets"], prefix)
			for target: Variant in v.id_list(block, "targets", null, "target", 1, prefix):
				var parts: PackedStringArray = (target as String).split(":")
				if parts.size() != 2 or not GuideText.LINK_KINDS.has(parts[0]):
					v.fail("field '%s.targets': '%s' must be '<kind>:<id>' with kind in %s" % [prefix, target,
							GuideText.LINK_KINDS])
				elif not context.has_target(parts[0], parts[1]):
					v.fail("field '%s.targets': broken link: unknown %s '%s'" % [prefix, parts[0], parts[1]])


static func _text(v: DataValidatorRules, text: String, where: String, digits_ok: bool, context: _Context) -> void:
	for message: String in GuideText.check(text, digits_ok, context.lookups()):
		v.fail("%s: %s" % [where, message])


static func _exceptions(v: DataValidatorRules, content: Dictionary, context: _Context) -> void:
	v.keys(content, EXCEPTION_KEYS)
	for key: String in EXCEPTION_KEYS:
		v.id_list(content, key, context.items, "item", 0)


## The ids of the raw files that the texts, links and routes refer to.
class _Context extends RefCounted:
	var items: Dictionary[StringName, Dictionary] = {}
	var monsters: Dictionary[StringName, bool] = {}
	var areas: Dictionary[StringName, bool] = {}
	var skills: Dictionary[StringName, bool] = {}
	var stats: Dictionary[StringName, Dictionary] = {}
	var traits: Dictionary[StringName, bool] = {}
	var abilities: Dictionary[StringName, bool] = {}
	var pages: Dictionary[StringName, bool] = {}
	var _balance: Dictionary = {}

	func _init(raw: Dictionary, hand_pages: Dictionary[StringName, bool]) -> void:
		pages = hand_pages
		for e: Dictionary in _entries(raw, "items", "items"):
			items[StringName(e["id"] as String)] = e
		for e: Dictionary in _entries(raw, "monsters", "monsters"):
			monsters[StringName(e["id"] as String)] = true
		for e: Dictionary in _entries(raw, "areas", "areas"):
			areas[StringName(e["id"] as String)] = true
		for e: Dictionary in _entries(raw, "skills", "skills"):
			skills[StringName(e["id"] as String)] = true
		for e: Dictionary in _entries(raw, "stats", "stats"):
			stats[StringName(e["id"] as String)] = e
		for path: Variant in _files(raw, "classes"):
			var content: Dictionary = (raw["classes"] as Dictionary)[path] as Dictionary
			for e: Dictionary in _list(content, "traits"):
				traits[StringName(e["id"] as String)] = true
			for e: Dictionary in _list(content, "abilities"):
				abilities[StringName(e["id"] as String)] = true
		for path: Variant in _files(raw, "balance"):
			_balance = (raw["balance"] as Dictionary)[path] as Dictionary

	func is_route(route: String) -> bool:
		if route.begins_with(SKILL_ROUTE_PREFIX):
			return skills.has(StringName(route.substr(SKILL_ROUTE_PREFIX.length())))
		return ROUTES.has(route)

	func is_table(source: String) -> bool:
		if source.begins_with(GuideTables.PREFIX_ACTIONS):
			return skills.has(StringName(source.trim_prefix(GuideTables.PREFIX_ACTIONS)))
		if source.begins_with(GuideTables.PREFIX_AREA_MONSTERS):
			return areas.has(StringName(source.trim_prefix(GuideTables.PREFIX_AREA_MONSTERS)))
		if source.begins_with(GuideTables.PREFIX_MONSTER_DROPS):
			return monsters.has(StringName(source.trim_prefix(GuideTables.PREFIX_MONSTER_DROPS)))
		if source.begins_with(GuideTables.PREFIX_MILESTONES):
			return skills.has(StringName(source.trim_prefix(GuideTables.PREFIX_MILESTONES)))
		return GuideTables.ids().has(source)

	func has_target(kind: String, id: String) -> bool:
		var key := StringName(id)
		match kind:
			"item":
				return items.has(key)
			"monster":
				return monsters.has(key)
			"area":
				return areas.has(key)
			"skill":
				return skills.has(key)
			"stat":
				return stats.has(key)
			"trait":
				return traits.has(key)
			"ability":
				return abilities.has(key)
			"page":
				return pages.has(key)
		return false

	func lookups() -> Dictionary:
		return {
			"balance": func(path: String) -> Variant: return DataValidator.lookup(_balance, path),
			"stat": func(id: String) -> Dictionary: return stats.get(StringName(id), {}),
			"link": func(kind: String, id: String) -> bool: return has_target(kind, id),
		}

	static func _files(raw: Dictionary, section: String) -> Array:
		var files: Variant = raw.get(section)
		var result: Array = []
		for path: Variant in (files as Dictionary if files is Dictionary else {}):
			if (files as Dictionary)[path] is Dictionary:
				result.append(path)
		return result

	static func _list(content: Dictionary, key: String) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var raw_list: Array = content[key] as Array if content.get(key) is Array else []
		for e: Variant in raw_list:
			if e is Dictionary and (e as Dictionary).get("id") is String:
				result.append(e as Dictionary)
		return result

	static func _entries(raw: Dictionary, section: String, key: String) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for path: Variant in _files(raw, section):
			result.append_array(_list((raw[section] as Dictionary)[path] as Dictionary, key))
		return result
