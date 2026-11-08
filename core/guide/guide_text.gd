class_name GuideText
extends RefCounted
## Placeholders of the hand-written Guide texts (docs/04_DATA_SCHEMA.md §19, docs/05_INTERFACES.md §5.19): the only way
## to cite a number. Pure logic, no state.
##
## Forms: `{balance:<path>|<format>}`, `{stat:<id>}` / `{stat:<id>|desc|min|max}`, `{link:<kind>:<id>|<text>}`.
## Literal braces do not exist in the texts and digits outside a placeholder are errors (unless `allow_digits`).
## The checks run on a "lookups" dictionary so that the same rules serve the raw files (DataValidatorGuide, before
## GameData exists) and a built GameData (`validate`, `resolve`):
##   "balance": Callable(path: String) -> Variant   (null when the path does not exist)
##   "stat":    Callable(id: String) -> Dictionary  ({} when unknown; else name, description, min, max)
##   "link":    Callable(kind: String, id: String) -> bool

const LOG_CATEGORY: String = "guide"
const FORMATS: PackedStringArray = ["int", "pct", "ore", "min", "sec"]
const STAT_PARTS: PackedStringArray = ["desc", "min", "max"]
const LINK_KINDS: PackedStringArray = ["item", "monster", "area", "skill", "stat", "trait", "ability", "page"]
const MS_DIVISORS: Dictionary[String, float] = {"ore": 3600000.0, "min": 60000.0, "sec": 1000.0}
const PLACEHOLDER_PATTERN: String = "\\{[^{}]*\\}"
const DIGITS_PATTERN: String = "[0-9]+"


## `text` with `{balance:…}` and `{stat:…}` replaced by their values and `{link:…}` by its text only. A placeholder that
## cannot be resolved stays as written, with a `Log.error` (no silent fallback).
static func resolve(text: String, data: GameData) -> String:
	var lookups: Dictionary = data_lookups(data)
	var parsed: Dictionary = tokenize(text)
	for message: String in parsed["errors"] as PackedStringArray:
		Log.error(LOG_CATEGORY, "%s in '%s'" % [message, text])
	var result: String = ""
	var cursor: int = 0
	for token: Dictionary in parsed["tokens"] as Array[Dictionary]:
		result += text.substr(cursor, int(token["start"]) - cursor)
		cursor = int(token["end"])
		var value: Variant = _value(token, lookups)
		if value is String:
			result += value as String
		else:
			Log.error(LOG_CATEGORY, "cannot resolve '%s' in '%s'" % [token["raw"], text])
			result += token["raw"] as String
	return result + text.substr(cursor)


## The `{link:…}` of `text`: [{"kind", "id", "label", "start", "end"}] with `start` inclusive and `end` exclusive,
## positions in `text` itself (the whole placeholder). Malformed placeholders are left out (`validate` reports them).
static func parse_links(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for token: Dictionary in tokenize(text)["tokens"] as Array[Dictionary]:
		if token["type"] == "link":
			result.append({"kind": token["kind"], "id": token["id"], "label": token["label"],
					"start": token["start"], "end": token["end"]})
	return result


## The problems of `text` (empty = ok): malformed, unknown or unresolvable placeholders, literal braces, written digits.
static func validate(text: String, data: GameData, allow_digits: bool) -> PackedStringArray:
	return check(text, allow_digits, data_lookups(data))


## `validate` on explicit lookups (see the file header).
static func check(text: String, allow_digits: bool, lookups: Dictionary) -> PackedStringArray:
	var parsed: Dictionary = tokenize(text)
	var errors: PackedStringArray = parsed["errors"] as PackedStringArray
	for token: Dictionary in parsed["tokens"] as Array[Dictionary]:
		var problem: String = _problem(token, lookups)
		if not problem.is_empty():
			errors.append(problem)
	if not allow_digits:
		var rest: String = _without_placeholders(text)
		var match: RegExMatch = RegEx.create_from_string(DIGITS_PATTERN).search(rest)
		if match != null:
			errors.append("digits written by hand ('%s'): use a placeholder" % match.get_string())
	return errors


## {"tokens": Array[Dictionary], "errors": PackedStringArray}. A token: type (balance/stat/link), raw, start, end and
## balance: path, format · stat: id, part · link: kind, id, label. Malformed placeholders only give errors.
static func tokenize(text: String) -> Dictionary:
	var tokens: Array[Dictionary] = []
	var errors: PackedStringArray = []
	for match: RegExMatch in RegEx.create_from_string(PLACEHOLDER_PATTERN).search_all(text):
		var raw: String = match.get_string()
		var token: Dictionary = _parse(raw.substr(1, raw.length() - 2), errors)
		if token.is_empty():
			continue
		token["raw"] = raw
		token["start"] = match.get_start()
		token["end"] = match.get_end()
		tokens.append(token)
	if _without_placeholders(text).contains("{") or _without_placeholders(text).contains("}"):
		errors.append("literal brace (use a placeholder or rewrite the text)")
	return {"tokens": tokens, "errors": errors}


## The lookups of a built GameData.
static func data_lookups(data: GameData) -> Dictionary:
	return {
		"balance": func(path: String) -> Variant: return data.balance_value(path),
		"stat": func(id: String) -> Dictionary:
			return data.stats.info(StringName(id)) if data.stats.has(StringName(id)) else {},
		"link": func(kind: String, id: String) -> bool: return _data_has(data, kind, id),
	}


static func format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	var text: String = "%.2f" % value
	return text.rstrip("0").rstrip(".")


static func _parse(body: String, errors: PackedStringArray) -> Dictionary:
	var type: String = body.get_slice(":", 0)
	var rest: String = body.substr(type.length() + 1) if body.contains(":") else ""
	var parts: PackedStringArray = rest.split("|")
	match type:
		"balance":
			if parts.size() != 2 or parts[0].is_empty() or not FORMATS.has(parts[1]):
				errors.append("malformed placeholder '{%s}': expected {balance:<path>|%s}" % [body, "|".join(FORMATS)])
				return {}
			return {"type": "balance", "path": parts[0], "format": parts[1]}
		"stat":
			if parts.size() > 2 or parts[0].is_empty() or (parts.size() == 2 and not STAT_PARTS.has(parts[1])):
				errors.append("malformed placeholder '{%s}': expected {stat:<id>} or {stat:<id>|%s}" % [body, "|".join(STAT_PARTS)])
				return {}
			return {"type": "stat", "id": parts[0], "part": parts[1] if parts.size() == 2 else "name"}
		"link":
			var target: PackedStringArray = parts[0].split(":")
			if parts.size() != 2 or target.size() != 2 or target[1].is_empty() or parts[1].is_empty():
				errors.append("malformed placeholder '{%s}': expected {link:<kind>:<id>|<text>}" % body)
				return {}
			if not LINK_KINDS.has(target[0]):
				errors.append("placeholder '{%s}': unknown link kind '%s'" % [body, target[0]])
				return {}
			return {"type": "link", "kind": target[0], "id": target[1], "label": parts[1]}
	errors.append("unknown placeholder '{%s}'" % body)
	return {}


# The text a token resolves to, or null if it cannot be resolved.
static func _value(token: Dictionary, lookups: Dictionary) -> Variant:
	match token["type"]:
		"link":
			return token["label"]
		"balance":
			var raw: Variant = (lookups["balance"] as Callable).call(token["path"])
			if not (raw is float or raw is int):
				return null
			var number: float = float(raw)
			match token["format"]:
				"int":
					return str(roundi(number))
				"pct":
					return format_number(number) + "%"
				_:
					return format_number(number / MS_DIVISORS[token["format"] as String])
		"stat":
			var info: Dictionary = (lookups["stat"] as Callable).call(token["id"])
			var key: String = "name" if token["part"] == "name" else "description" if token["part"] == "desc" \
					else token["part"] as String
			if info.is_empty() or not info.has(key):
				return null
			var value: Variant = info[key]
			return format_number(float(value)) if value is float or value is int else str(value)
	return null


static func _problem(token: Dictionary, lookups: Dictionary) -> String:
	match token["type"]:
		"balance":
			var raw: Variant = (lookups["balance"] as Callable).call(token["path"])
			if raw == null:
				return "unknown balance path '%s'" % token["path"]
			if not (raw is float or raw is int):
				return "balance path '%s' is not a number" % token["path"]
		"stat":
			if _value(token, lookups) == null:
				return "unknown stat '%s'" % token["id"]
		"link":
			if not (lookups["link"] as Callable).call(token["kind"], token["id"]):
				return "broken link: unknown %s '%s'" % [token["kind"], token["id"]]
	return ""


static func _without_placeholders(text: String) -> String:
	return RegEx.create_from_string(PLACEHOLDER_PATTERN).sub(text, "", true)


static func _data_has(data: GameData, kind: String, id: String) -> bool:
	var key := StringName(id)
	match kind:
		"item":
			return data.has_item(key)
		"monster":
			return data.has_monster(key)
		"area":
			return data.has_area(key)
		"skill":
			for skill: SkillDef in data.skills():
				if skill.id == key:
					return true
		"stat":
			return data.stats.has(key)
		"trait":
			for class_def: ClassDef in data.classes():
				for def: TraitDef in class_def.traits:
					if def.id == key:
						return true
		"ability":
			for class_def: ClassDef in data.classes():
				for def: AbilityDef in class_def.abilities:
					if def.id == key:
						return true
		"page":
			for page: GuidePageDef in data.guide_pages():
				if page.id == key:
					return true
	return false
