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
var progress_text: String = ""  # M31 (docs/M31_RITOCCHI_TUTORIAL.md §2.1): the counter label with two `%d`
var ack_text: String = ""  # M31: the label of the confirm button ("" = the UI default)
var freeze_combat: bool = false  # M31: the combat is frozen while the step is current (`ack` steps only)
var force_node: bool = false  # M31: the first journey after the entry is a node (§4)
var wound_hp_pct: int = 0  # M31: the hp of the character go to this percent (0 = absent)
var force_pack_area: StringName = &""  # M33 (docs/M33_TUTORIAL_FORZATO.md §3.1): the forced pack of the step (`&""` = none)
var force_pack: Array[StringName] = []


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
	def.progress_text = r.text("progress_text") if r.has("progress_text") else ""
	def.ack_text = r.text("ack_text") if r.has("ack_text") else ""
	def.freeze_combat = r.flag("freeze_combat") if r.has("freeze_combat") else false
	def.force_node = r.flag("force_node") if r.has("force_node") else false
	def.wound_hp_pct = r.integer("wound_hp_pct") if r.has("wound_hp_pct") else 0
	if r.has("force_pack") and r.is_dict("force_pack"):
		var p := DefReader.new(r.dict("force_pack"), r.context() + " force_pack")
		def.force_pack_area = p.id("area")
		def.force_pack = p.id_list("monsters")
		r.absorb(p.ok)
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
