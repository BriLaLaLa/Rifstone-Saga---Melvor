class_name ActionDef
extends RefCounted
## An action of data/actions/<skill>.json (docs/04_DATA_SCHEMA.md §6).
##
## `skill_id` is not a field of the action but of its file (`"skill"` at the top level), so the caller passes it
## as `file_skill_id`; an empty one is a conversion error. `icon` is optional: it stays "" when absent, and the
## schema's default (icon of the first output) is resolved by GameData, which knows the items.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var skill_id: StringName = &""
var name: String = ""
var level: int = 0
var interval_ms: int = 0
var xp: int = 0
var mastery: bool = false
var icon: String = ""
var inputs: Array[ItemQty] = []
var outputs: Array[ItemQty] = []
var single: bool = false  # M10: single-cycle action (04 §6); false when absent
var milestones: Array[MilestoneDef] = []  # M12: gathering actions only (F-103), in the order 25/50/99
var kind: StringName = &"craft"  # M12: `craft` (default) or `crystallize` (F-104), Incisore only


static func from_dict(d: Dictionary, file_skill_id: StringName = &"") -> ActionDef:
	var r := DefReader.new(d, "action")
	var def := ActionDef.new()
	def.id = r.id("id")
	r.set_context("action '%s'" % def.id)
	if file_skill_id == &"":
		r.fail("no skill id given (it comes from the file's 'skill')")
	def.skill_id = file_skill_id
	def.name = r.text("name")
	def.level = r.integer("level")
	def.interval_ms = r.integer("interval_ms")
	def.xp = r.integer("xp")
	def.mastery = r.flag("mastery")
	if r.has("icon"):
		def.icon = r.text("icon")
	def.inputs = _item_list(r, "inputs")
	def.outputs = _item_list(r, "outputs")
	if r.has("single"):
		def.single = r.flag("single")
	if r.has("kind"):
		def.kind = r.id("kind")
	if r.has("milestones"):
		for entry: Dictionary in r.dict_list("milestones"):
			var milestone: MilestoneDef = MilestoneDef.from_dict(entry, def.id, file_skill_id)
			r.absorb(milestone != null)
			if milestone != null:
				def.milestones.append(milestone)
	return def if r.ok else null


## Artisan actions consume inputs; gathering actions have none. A single-cycle action (M10) is artisan too.
func is_artisan() -> bool:
	return not inputs.is_empty() or single


static func _item_list(r: DefReader, key: String) -> Array[ItemQty]:
	var result: Array[ItemQty] = []
	for entry: Dictionary in r.dict_list(key):
		var item: ItemQty = ItemQty.from_dict(entry)
		r.absorb(item != null)
		if item != null:
			result.append(item)
	return result


## The milestone of the given type (M12), or null if the action has none.
func milestone_of(type: StringName) -> MilestoneDef:
	for milestone: MilestoneDef in milestones:
		if milestone.type == type:
			return milestone
	return null
