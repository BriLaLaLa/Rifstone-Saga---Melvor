class_name PackDef
extends RefCounted
## A monster pack of an area (`packs` of data/combat/areas.json, docs/04_DATA_SCHEMA.md §8): a weight for the random
## choice and the monsters in position order (ids may repeat). `monsters` becomes `monster_ids`.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var weight: int = 0
var monster_ids: Array[StringName] = []


static func from_dict(d: Dictionary) -> PackDef:
	var r := DefReader.new(d, "pack")
	var def := PackDef.new()
	def.weight = r.integer("weight")
	def.monster_ids = r.id_list("monsters")
	return def if r.ok else null
