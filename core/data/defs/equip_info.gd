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
var weapon: WeaponInfo = null


static func from_dict(d: Dictionary) -> EquipInfo:
	var r := DefReader.new(d, "equip")
	var def := EquipInfo.new()
	def.slot = r.id("slot")
	r.set_context("equip '%s'" % def.slot)
	def.requirements = r.level_map("requirements")
	def.modifiers = r.modifiers("modifiers")
	def.grade = r.integer("grade")
	if r.has("kind"):
		def.kind = r.id("kind")
	if r.has("weapon") and r.is_dict("weapon"):
		def.weapon = WeaponInfo.from_dict(r.dict("weapon"))
		r.absorb(def.weapon != null)
	return def if r.ok else null
