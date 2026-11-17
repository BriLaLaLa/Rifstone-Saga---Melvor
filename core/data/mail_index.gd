class_name MailIndex
extends RefCounted
## Helper of GameData (internal): the Mail text models of data/mail/templates.json (docs/04_DATA_SCHEMA_M27.md §32.5), by kind, in file order.

const FILE: String = "mail/templates.json"

var by_kind: Dictionary[StringName, Array] = {}


## `raw` is `{path: top-level object}` of the single file; a model that cannot be built is reported in `errors`.
func build(raw: Dictionary, errors: PackedStringArray) -> void:
	for path: String in raw:
		for d: Dictionary in DataBuildUtil.list(raw[path], "templates"):
			var def: MailTemplateDef = MailTemplateDef.from_dict(d)
			if def == null:
				errors.append("%s: a mail template cannot be built (see the log)" % path)
				continue
			(by_kind.get_or_add(def.kind, []) as Array).append(def)


func of_kind(kind: StringName) -> Array[MailTemplateDef]:
	var result: Array[MailTemplateDef] = []
	result.assign(by_kind.get(kind, []) as Array)
	return result


func clear() -> void:
	by_kind.clear()
