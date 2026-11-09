class_name DataValidatorRules
extends RefCounted
## Second half of DataValidator (internal, not API for other modules): the field toolkit (types, ranges, unknown
## fields, ids, references, modifiers, `{item, qty}` lists) and the rules of mastery (areas, monsters, classes and
## affixes are in DataValidatorClasses; docs/04_DATA_SCHEMA.md §7). Each problem is one line in `errors`:
## `<file>: <kind> '<id>': <message>`
## (`<kind> #<index>` while the entry has no usable id). Checkers return whether the field is valid.

const DOC_KEY: String = "_doc"
const ID_PATTERN: String = "^[a-z][a-z0-9_]{1,47}$"
const NO_LIMIT: float = INF  # "no limit"; also when a limit's balance key is missing (already an error)
const CHARACTER_KEY: String = "character"  # reserved key of the requirements: the character level
const LEVELS_SKILLS: int = 0  # level_map modes
const LEVELS_CHARACTER: int = 1
const STYLES: PackedStringArray = ["blade", "marksmanship", "arcana"]
const MASTERY_COST_MAX_PCT: float = 50.0
const MASTERY_POS_MAX: int = 5
const NODE_FIELDS: PackedStringArray = ["id", "name", "description", "cost_pct", "requires", "pos", "modifiers"]

var errors: PackedStringArray = []
var stats: StatRegistry = StatRegistry.new()
var skills: Dictionary[StringName, Dictionary] = {}  # raw entries by id, collected before the rules run
var items: Dictionary[StringName, Dictionary] = {}
var actions: Dictionary[StringName, Dictionary] = {}
var monsters: Dictionary[StringName, Dictionary] = {}
var shop_entries: Dictionary[StringName, Dictionary] = {}
var classes: Dictionary[StringName, Dictionary] = {}
var max_skill_level: float = NO_LIMIT  # limits from balance.json (NO_LIMIT or 0 if malformed: already reported)
var max_mastery_level: float = NO_LIMIT
var max_character_level: float = NO_LIMIT  # character_curve.max_level
var max_pack_size: float = NO_LIMIT  # combat.max_pack_size
var min_action_interval_ms: float = 0.0
var helper_grade_ids: PackedStringArray = []  # helper.grades ids (M12), collected with the balance before the items
var milestone_thresholds: Array[int] = []  # mastery.milestones byproduct_at, resource_at, trade_at (M12), when valid
var merge_ratio: int = 0  # engraver.merge_ratio (M12), when valid
var upgrade_ratio: int = 0  # rune.upgrade_ratio (M12), when valid
var grade_mult: Array[float] = []  # rune.grade_mult (M12), when valid
var min_attack_interval_ms: float = 0.0
var grade_material: Array[int] = []  # equipment.grade_material (M14), when valid: material grade of each piece grade
var extra_rare: int = 2  # blueprint.extra_rare (M14): how many different rare components a blueprint asks for

var _file: String = ""
var _where: String = ""
var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)


func at_file(file: String) -> void:
	_file = file
	_where = ""


## Starts the messages of entry `index` of kind `kind`; returns its id (&"" if `id` is not a non-empty string).
func at_entry(kind: String, index: int, d: Dictionary) -> StringName:
	var raw_id: Variant = d.get("id")
	var has_id: bool = raw_id is String and not (raw_id as String).is_empty()
	_where = "%s '%s'" % [kind, raw_id] if has_id else "%s #%d" % [kind, index]
	return StringName(raw_id as String) if has_id else &""


## The common rules of an entry: message context, duplicate id within `seen`, unknown fields, `id` format and the
## `name`/`description` strings (when `allowed` has them) and, given `orders`, a unique integer `order`.
func entry(kind: String, index: int, e: Dictionary, seen: Dictionary[StringName, bool], allowed: PackedStringArray,
		orders: Variant = null) -> StringName:
	var id: StringName = at_entry(kind, index, e)
	if id != &"" and seen.has(id):
		fail("duplicate %s '%s'" % [kind, id])
	seen[id] = true
	keys(e, allowed)
	if text(e, "id") and _id_regex.search(e["id"] as String) == null:
		fail("id '%s' does not match %s" % [e["id"], ID_PATTERN])
	for key: String in ["name", "description"]:
		if allowed.has(key):
			text(e, key)
	if orders is Dictionary and integer(e, "order", -NO_LIMIT):
		if (orders as Dictionary).has(int(e["order"])):
			fail("duplicate order %d" % int(e["order"]))
		(orders as Dictionary)[int(e["order"])] = true
	return id


func fail(message: String) -> void:
	errors.append(": ".join(PackedStringArray([_file, message] if _where.is_empty() else [_file, _where, message])))


## Unknown fields of `d` (everything outside `allowed`, except a string `_doc`).
func keys(d: Dictionary, allowed: PackedStringArray, prefix: String = "") -> void:
	for key: Variant in d:
		if not allowed.has(str(key)) and not (str(key) == DOC_KEY and d[key] is String):
			fail("unknown field '%s'" % _path(prefix, str(key)))


func text(d: Dictionary, key: String, prefix: String = "") -> bool:
	return _typed(d, key, prefix, d.get(key) is String, "a string")


func flag(d: Dictionary, key: String, prefix: String = "") -> bool:
	return _typed(d, key, prefix, d.get(key) is bool, "a boolean")


## An integer (a JSON number without fractional part) in [low, high].
func integer(d: Dictionary, key: String, low: float, high: float = NO_LIMIT, prefix: String = "") -> bool:
	return _typed(d, key, prefix, is_int(d.get(key)), "an integer") and _in_range(prefix, key, d[key], low, high)


## A number in [low, high] (or (low, high] with `low_exclusive`).
func number(d: Dictionary, key: String, low: float, high: float, prefix: String = "", low_exclusive: bool = false
) -> bool:
	return _typed(d, key, prefix, is_number(d.get(key)), "a number") \
			and _in_range(prefix, key, d[key], low, high, low_exclusive)


func one_of(d: Dictionary, key: String, values: PackedStringArray, prefix: String = "") -> bool:
	var ok: bool = text(d, key, prefix) and values.has(d[key] as String)
	if d.get(key) is String and not ok:
		fail("field '%s' must be one of %s, got '%s'" % [_path(prefix, key), values, d[key]])
	return ok


## A string id that is a key of `known` (`kind` names it in the message).
func ref(d: Dictionary, key: String, known: Dictionary, kind: String, prefix: String = "") -> bool:
	var ok: bool = text(d, key, prefix) and known.has(StringName(d[key] as String))
	if d.get(key) is String and not ok:
		fail("field '%s': unknown %s '%s'" % [_path(prefix, key), kind, d[key]])
	return ok


## The object under `key`, or {} (after an error) if it is missing or not an object.
func object(d: Dictionary, key: String, prefix: String = "") -> Dictionary:
	return d[key] as Dictionary if _typed(d, key, prefix, d.get(key) is Dictionary, "an object") else {}


## `[a, b]` of integers with `low <= a <= b` (ordered) or `low <= a, b <= high` (not ordered).
func int_pair(d: Dictionary, key: String, low: int, high: float, ordered: bool, prefix: String = "") -> bool:
	var pair: Array = _array(d, key, prefix)
	var ok: bool = d.get(key) is Array and pair.size() == 2 and is_int(pair[0]) and is_int(pair[1])
	if ok:
		var a: float = float(pair[0])
		ok = a >= low and float(pair[1]) >= (a if ordered else float(low)) and maxf(a, float(pair[1])) <= high
	if not ok and d.get(key) is Array:
		var rule: String = "%d <= min <= max" % low if ordered else "integers in %d..%s" % [low, high]
		fail("field '%s' must be [a, b] with %s, got %s" % [_path(prefix, key), rule, JSON.stringify(pair)])
	return ok


## The objects of the array under `key` (at least `min_count`; each non-object element is an error).
func object_list(d: Dictionary, key: String, prefix: String = "", min_count: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for element: Variant in _array(d, key, prefix, min_count):
		if element is Dictionary:
			result.append(element as Dictionary)
		else:
			fail("field '%s' must contain only objects, got %s" % [_path(prefix, key), JSON.stringify(element)])
	return result


## The string ids under `key` (at least `min_count`); each must be a key of `known` unless `known` is null.
func id_list(d: Dictionary, key: String, known: Variant, kind: String, min_count: int, prefix: String = "") -> Array:
	var result: Array = []
	var path: String = _path(prefix, key)
	for element: Variant in _array(d, key, prefix, min_count):
		if not element is String:
			fail("field '%s' must contain only strings, got %s" % [path, JSON.stringify(element)])
			continue
		if known is Dictionary and not (known as Dictionary).has(StringName(element as String)):
			fail("field '%s': unknown %s '%s'" % [path, kind, element])
		result.append(element)
	return result


## `{skill_id: level}`: existing skills, integer levels 1..max skill level. The reserved key `character` is the
## character level (1..max character level): with `LEVELS_CHARACTER` it is the only key, with `LEVELS_SKILLS` it is an
## unknown skill.
func level_map(d: Dictionary, key: String, prefix: String = "", mode: int = LEVELS_SKILLS) -> void:
	var levels: Dictionary = object(d, key, prefix)
	var at: String = _path(prefix, key)
	for skill: Variant in levels:
		if str(skill) == DOC_KEY and levels[skill] is String:
			continue
		if str(skill) == CHARACTER_KEY and mode != LEVELS_SKILLS:
			integer(levels, CHARACTER_KEY, 1, max_character_level, at)
		elif mode == LEVELS_CHARACTER:
			fail("field '%s.%s': only '%s' is allowed here" % [at, skill, CHARACTER_KEY])
		else:
			if not skills.has(StringName(str(skill))):
				fail("field '%s.%s': unknown skill '%s'" % [at, skill, skill])
			integer(levels, str(skill), 1, max_skill_level, at)


## The `{item, qty}` list under `key` (at least `min_count`): existing items, integer quantities >= 1.
func item_qty_list(d: Dictionary, key: String, min_count: int, prefix: String = "") -> void:
	var entries: Array[Dictionary] = object_list(d, key, prefix, min_count)
	for index: int in entries.size():
		item_qty(entries[index], "%s[%d]" % [_path(prefix, key), index])


func item_qty(d: Dictionary, prefix: String) -> void:
	keys(d, ["item", "qty"], prefix)
	ref(d, "item", items, "item", prefix)
	integer(d, "qty", 1, NO_LIMIT, prefix)


## The modifiers under `key` (§1). Without `check_scope` a `scope` is allowed but not checked (mastery bonuses).
func modifiers(d: Dictionary, key: String, prefix: String = "", check_scope: bool = true) -> void:
	var entries: Array[Dictionary] = object_list(d, key, prefix)
	for index: int in entries.size():
		var m: Dictionary = entries[index]
		var at: String = "%s[%d]" % [_path(prefix, key), index]
		keys(m, ["stat", "value", "scope"], at)
		if text(m, "stat", at) and not stats.has(StringName(m["stat"] as String)):
			fail("field '%s': stat '%s' is not in stats.json" % [_path(at, "stat"), m["stat"]])
		if number(m, "value", -NO_LIMIT, NO_LIMIT, at) and float(m["value"]) == 0.0:
			fail("field '%s' must not be 0" % _path(at, "value"))
		if check_scope and m.has("scope") and text(m, "scope", at):
			_scope(m["scope"] as String, _path(at, "scope"))


static func is_int(v: Variant) -> bool:
	return v is int or (v is float and is_finite(v as float) and (v as float) == floorf(v as float))


static func is_number(v: Variant) -> bool:
	return v is int or (v is float and is_finite(v as float))


func validate_mastery(files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var graph: Dictionary[StringName, Array] = {}       # node id -> requires
	var owner: Dictionary[StringName, String] = {}      # node id -> "<skill>|<file>"
	for path: String in files:
		at_file(path)
		var skill: String = DataValidator.file_skill(self, files[path], path, [])
		if not skill.is_empty() and skills[StringName(skill)].get("has_mastery") != true:
			fail("skill '%s' has no mastery ('has_mastery': false)" % skill)
		var cells: Dictionary[String, bool] = {}
		var list: Array[Dictionary] = DataValidator.entries(self, files[path], "nodes", ["skill"])
		for index: int in list.size():
			var e: Dictionary = list[index]
			var id: StringName = entry("mastery node", index, e, seen, NODE_FIELDS)
			if id != &"" and not skill.is_empty() and not String(id).begins_with(skill + "_"):
				fail("id must start with '%s_'" % skill)
			number(e, "cost_pct", 0.0, MASTERY_COST_MAX_PCT, "", true)
			if int_pair(e, "pos", 0, MASTERY_POS_MAX, false):
				var cell: String = "%d,%d" % [int(e["pos"][0]), int(e["pos"][1])]
				if cells.has(cell):
					fail("position %s is already used in this skill" % JSON.stringify(e["pos"]))
				cells[cell] = true
			modifiers(e, "modifiers")
			graph[id] = id_list(e, "requires", null, "", 0)
			owner[id] = "%s|%s" % [skill, path]
	graph.erase(&"")  # entries without a usable id (already reported)
	_check_requires(graph, owner)


# `requires` point to nodes of the same skill and have no cycles: nodes are unlocked repeatedly (a node is unlockable
# once all its known requires are); whatever stays locked is in a cycle or depends on one.
func _check_requires(graph: Dictionary[StringName, Array], owner: Dictionary[StringName, String]) -> void:
	var unlocked: Dictionary[StringName, bool] = {}
	var progress: bool = true
	while progress:
		progress = false
		for id: StringName in graph:
			var ready: bool = not unlocked.has(id)
			for required: Variant in graph[id]:
				ready = ready and (unlocked.has(StringName(str(required))) or not graph.has(StringName(str(required))))
			if ready:
				unlocked[id] = true
				progress = true
	for id: StringName in graph:
		at_file(owner[id].get_slice("|", 1))
		_where = "mastery node '%s'" % id
		for required: Variant in graph[id]:
			if not graph.has(StringName(str(required))):
				fail("field 'requires': unknown mastery node '%s'" % required)
			elif owner[StringName(str(required))].get_slice("|", 0) != owner[id].get_slice("|", 0):
				fail("field 'requires': node '%s' belongs to another skill" % required)
		if not unlocked.has(id):
			fail("field 'requires' is part of a cycle (or depends on one): %s" % JSON.stringify(graph[id]))


# `global`, `skill:<existing skill>` or `action:<existing action>`.
func _scope(scope: String, label: String) -> void:
	if scope == String(Modifier.SCOPE_GLOBAL):
		return
	var separator: int = scope.find(Modifier.SCOPE_SEPARATOR)
	var kind := StringName(scope.substr(0, separator) if separator > 0 else "")
	var target := StringName(scope.substr(separator + Modifier.SCOPE_SEPARATOR.length()))
	if kind != Modifier.SCOPE_SKILL and kind != Modifier.SCOPE_ACTION:
		fail("field '%s': scope '%s' must be global, skill:<id> or action:<id>" % [label, scope])
	elif not (skills if kind == Modifier.SCOPE_SKILL else actions).has(target):
		fail("field '%s': scope '%s' points to an unknown %s" % [label, scope, kind])


# The array under `key` ([] after an error), with at least `min_count` elements.
func _array(d: Dictionary, key: String, prefix: String, min_count: int = 0) -> Array:
	if not _typed(d, key, prefix, d.get(key) is Array, "an array"):
		return []
	if (d[key] as Array).size() < min_count:
		fail("field '%s' needs at least %d entries" % [_path(prefix, key), min_count])
	return d[key] as Array


func _typed(d: Dictionary, key: String, prefix: String, type_ok: bool, expected: String) -> bool:
	if not d.has(key):
		fail("missing field '%s'" % _path(prefix, key))
	elif not type_ok:
		fail("field '%s' must be %s, got %s" % [_path(prefix, key), expected, JSON.stringify(d[key])])
	return d.has(key) and type_ok


func _in_range(prefix: String, key: String, value: float, low: float, high: float, low_exclusive: bool = false
) -> bool:
	var ok: bool = (value > low if low_exclusive else value >= low) and value <= high
	if not ok:
		var low_text: String = ("> %s" if low_exclusive else ">= %s") % _num(low)
		var high_text: String = "" if high == NO_LIMIT else " and <= %s" % _num(high)
		fail("field '%s' must be %s%s, got %s" % [_path(prefix, key), low_text, high_text, _num(value)])
	return ok


static func _num(v: float) -> String:
	return str(int(v)) if is_finite(v) and v == floorf(v) else str(v)


static func _path(prefix: String, key: String) -> String:
	return key if prefix.is_empty() else "%s.%s" % [prefix, key]
