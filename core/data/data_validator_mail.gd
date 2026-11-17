class_name DataValidatorMail
extends RefCounted
## Mail rules of DataValidator (internal, M27-05; docs/04_DATA_SCHEMA_M27.md §32.5): `mail` of balance.json and data/mail/templates.json.

const KINDS: PackedStringArray = ["auction_sold", "auction_sale", "auction_expired", "auction_cancelled"]
const PLACEHOLDERS: PackedStringArray = ["item", "qty", "price", "money"]
const SUBJECT_MAX: int = 60
const BODY_MAX: int = 240
const FIELDS: PackedStringArray = ["kind", "sender", "subject", "body"]


static func is_known_key(path: String) -> bool:
	return path == "mail"


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var section: Variant = DataValidator.lookup(balance, "mail")
	if not section is Dictionary:
		v.fail("missing key 'mail'")
		return
	v.keys(section as Dictionary, ["capacity"], "mail")
	v.integer(section as Dictionary, "capacity", 1.0, DataValidatorRules.NO_LIMIT, "mail")


static func validate(v: DataValidatorRules, raw: Dictionary) -> void:
	var balance_files: Dictionary = raw.get("balance", {}) as Dictionary
	for path: Variant in balance_files:
		v.at_file(str(path))
		validate_balance(v, balance_files[path] as Dictionary)
	var files: Dictionary = raw.get("mail", {}) as Dictionary
	for path: Variant in files:
		v.at_file(str(path))
		var seen: Dictionary[String, bool] = {}
		var list: Array[Dictionary] = DataValidator.entries(v, files[path] as Dictionary, "templates")
		for i: int in list.size():
			var e: Dictionary = list[i]
			v.at_entry("template", i, e)
			v.keys(e, FIELDS)
			if v.one_of(e, "kind", KINDS):
				seen[e["kind"] as String] = true
			for key: String in ["sender", "subject", "body"]:
				if v.text(e, key) and (e[key] as String).is_empty():
					v.fail("field '%s' must not be empty" % key)
			_check_text(v, e, "subject", SUBJECT_MAX)
			_check_text(v, e, "body", BODY_MAX)
		v.at_file(str(path))
		for kind: String in KINDS:
			if not seen.has(kind):
				v.fail("no template of kind '%s'" % kind)


# At most `limit` characters; balanced braces with known placeholders only.
static func _check_text(v: DataValidatorRules, e: Dictionary, key: String, limit: int) -> void:
	if not e.get(key) is String:
		return
	var s: String = e[key] as String
	if s.length() > limit:
		v.fail("field '%s' has at most %d characters, got %d" % [key, limit, s.length()])
	var i: int = 0
	while i < s.length():
		var c: String = s[i]
		if c == "{":
			var end: int = s.find("}", i)
			var inner: String = s.substr(i + 1, end - i - 1) if end >= 0 else ""
			if end < 0 or not PLACEHOLDERS.has(inner):
				v.fail("field '%s' has an unknown or unbalanced placeholder at %d (allowed: %s)" % [key, i, PLACEHOLDERS])
				return
			i = end
		elif c == "}":
			v.fail("field '%s' has an unbalanced '}' at %d" % [key, i])
			return
		i += 1
