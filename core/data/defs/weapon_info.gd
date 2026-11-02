class_name WeaponInfo
extends RefCounted
## The `equip.weapon` object of an item (docs/04_DATA_SCHEMA.md §5).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var style: StringName = &""
var attack_interval_ms: int = 0
var two_handed: bool = false


static func from_dict(d: Dictionary) -> WeaponInfo:
	var r := DefReader.new(d, "weapon")
	var def := WeaponInfo.new()
	def.style = r.id("style")
	def.attack_interval_ms = r.integer("attack_interval_ms")
	def.two_handed = r.flag("two_handed")
	return def if r.ok else null
