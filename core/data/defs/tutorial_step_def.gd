class_name TutorialStepDef
extends RefCounted
## A step of data/tutorial/steps.json (docs/04_DATA_SCHEMA_M30.md §34.1). `done_when`: one condition is enough.
## `gift_money` / `gift_items`: the `on_enter.mail` gift (money or items, never both); 0 / [] = no gift.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var page: StringName = &""
var target: String = ""
var title: String = ""
var text: String = ""
var done_when: Array[TutorialCondition] = []
var gift_money: int = 0
var gift_items: Array[ItemQty] = []


static func from_dict(d: Dictionary) -> TutorialStepDef:
	var r := DefReader.new(d, "tutorial step")
	var def := TutorialStepDef.new()
	def.id = r.id("id")
	r.set_context("tutorial step '%s'" % def.id)
	def.page = r.id("page")
	def.target = r.text("target")
	def.title = r.text("title")
	def.text = r.text("text")
	def.done_when = conditions(r, d.get("done_when"))
	if r.has("on_enter") and r.is_dict("on_enter"):
		var mail: Variant = r.dict("on_enter").get("mail")
		if mail is Dictionary:
			var m := DefReader.new(mail as Dictionary, r.context() + " on_enter.mail")
			if m.has("money"):
				def.gift_money = m.integer("money")
			if m.has("items"):
				def.gift_items = items(m, m.dict_list("items"))
			r.absorb(m.ok)
		else:
			r.fail("field 'on_enter.mail' must be an object")
	return def if r.ok else null


## One condition or an array of conditions to a typed array (a bad one is reported through `r`).
static func conditions(r: DefReader, raw: Variant) -> Array[TutorialCondition]:
	var result: Array[TutorialCondition] = []
	var list: Array = raw as Array if raw is Array else [raw]
	for entry: Variant in list:
		var c: TutorialCondition = TutorialCondition.from_dict(entry as Dictionary) if entry is Dictionary else null
		if c == null:
			r.fail("field 'done_when' has an invalid condition")
		else:
			result.append(c)
	return result


static func items(r: DefReader, rows: Array[Dictionary]) -> Array[ItemQty]:
	var result: Array[ItemQty] = []
	for row: Dictionary in rows:
		var q: ItemQty = ItemQty.from_dict(row)
		r.absorb(q != null)
		if q != null:
			result.append(q)
	return result
