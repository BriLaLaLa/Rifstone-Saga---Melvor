class_name EquipInfo
extends RefCounted
## The `equip` object of an item (docs/04_DATA_SCHEMA.md §5). `slot`, `requirements`, `modifiers` and `grade` are
## required (`requirements`, with the key `character` for the character level, and `modifiers` may be empty); `kind`
## (weapon and offhand slots only) is &"" when absent; `weapon` is optional and null when absent.
## Modifiers without `scope` are global. `from_dict` returns null (after logging, see DefReader) on a bad field.

var slot: StringName = &""
var requirements: Dictionary[StringName, int] = {}
var modifiers: Array[Modifier] = []
var kind: StringName = &""
var grade: int = 0
var material: StringName = &""  # M14: &"plate" / &"leather" / &"cloth" for armour and shields, &"" otherwise
var weapon: WeaponInfo = null
var unique: bool = false  # M10: unique tool (04 §5); false when absent
var upgrade_extras: Array[ToolExtra] = []  # M10: empty when absent
var masterwork: bool = false  # M14: a base of Masterwork (F-119), false when absent
var legendary: LegendaryInfo = null  # M14: null unless a legendary (F-120)


static func from_dict(d: Dictionary) -> EquipInfo:
	var r := DefReader.new(d, "equip")
	var def := EquipInfo.new()
	def.slot = r.id("slot")
	r.set_context("equip '%s'" % def.slot)
	def.requirements = r.level_map("requirements")
	def.modifiers = r.modifiers("modifiers")
	def.grade = r.integer("grade")
	if r.has("material"):
		def.material = r.id("material")
	if r.has("kind"):
		def.kind = r.id("kind")
	if r.has("weapon") and r.is_dict("weapon"):
		def.weapon = WeaponInfo.from_dict(r.dict("weapon"))
		r.absorb(def.weapon != null)
	if r.has("unique"):
		def.unique = r.flag("unique")
	if r.has("upgrade_extras"):
		for entry: Dictionary in r.dict_list("upgrade_extras"):
			var extra: ToolExtra = ToolExtra.from_dict(entry)
			r.absorb(extra != null)
			if extra != null:
				def.upgrade_extras.append(extra)
	if r.has("masterwork"):
		def.masterwork = r.flag("masterwork")
	if r.has("legendary") and r.is_dict("legendary"):
		def.legendary = LegendaryInfo.from_dict(r.dict("legendary"))
		r.absorb(def.legendary != null)
	return def if r.ok else null


## True for a legendary tool (slot `tool_*`, F-120): it replaces the unique tool of its slot.
func is_legendary_tool() -> bool:
	return legendary != null and String(slot).begins_with("tool_")
