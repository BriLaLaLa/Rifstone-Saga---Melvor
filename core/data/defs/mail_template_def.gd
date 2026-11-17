class_name MailTemplateDef
extends RefCounted
## One text model of the Mail (docs/04_DATA_SCHEMA_M27.md §32.5): the UI fills `{item}`, `{qty}`, `{price}`, `{money}`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped; ranges are the validator's job.

var kind: StringName = &""
var sender: String = ""
var subject: String = ""
var body: String = ""


static func from_dict(d: Dictionary) -> MailTemplateDef:
	var r := DefReader.new(d, "mail template")
	var def := MailTemplateDef.new()
	def.kind = r.id("kind")
	def.sender = r.text("sender")
	def.subject = r.text("subject")
	def.body = r.text("body")
	return def if r.ok else null
