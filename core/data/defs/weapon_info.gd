class_name WeaponInfo
extends RefCounted
## The `equip.weapon` object of an item (docs/04_DATA_SCHEMA.md §5, §21).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.
## M14: `dmg_min`/`dmg_max` are the base damage of the model (F-22, F-118); the validator checks min <= max.

var style: StringName = &""
var attack_interval_ms: int = 0
var two_handed: bool = false
var dmg_min: int = 0
var dmg_max: int = 0


static func from_dict(d: Dictionary) -> WeaponInfo:
	var r := DefReader.new(d, "weapon")
	var def := WeaponInfo.new()
	def.style = r.id("style")
	def.attack_interval_ms = r.integer("attack_interval_ms")
	def.two_handed = r.flag("two_handed")
	def.dmg_min = r.integer("dmg_min")
	def.dmg_max = r.integer("dmg_max")
	return def if r.ok else null
