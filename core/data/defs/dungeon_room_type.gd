class_name DungeonRoomType
extends RefCounted
## A room type of a dungeon (docs/04_DATA_SCHEMA.md §27, F-138): an entry of `rooms.types`, or the entrance, the trap
## ambush and the rest forage, which share the composition fields. Fields a source does not have keep their defaults
## (`size` 0, empty `pool`, empty `fixed`). `reward` (F-142) holds only the keys the data gives:
## `gold` and `dust` as Vector2i(min, max), `crystal_pct` and `piece_pct` as float.
## `from_dict` returns null (after logging, see DefReader) if a field is mistyped.

var id: StringName = &""
var weight: int = 0
var min_layer: int = 0
var size_min: int = 0
var size_max: int = 0
var pool_monsters: Array[StringName] = []
var pool_weights: Array[int] = []
var fixed: Array[StringName] = []  # a composition with these monsters, in order, instead of `size` and `pool`
var hint: String = ""  # the fixed phrase of the type (F-138)
var reward: Dictionary = {}


## `inline_reward`: the reward keys are in `d` itself (the rest forage) instead of under `reward`.
static func from_dict(d: Dictionary, type_id: StringName, inline_reward: bool = false) -> DungeonRoomType:
	var r := DefReader.new(d, "dungeon room type '%s'" % type_id)
	var def := DungeonRoomType.new()
	def.id = type_id
	if r.has("weight"):
		def.weight = r.integer("weight")
	if r.has("min_layer"):
		def.min_layer = r.integer("min_layer")
	if r.has("hint"):
		def.hint = r.text("hint")
	var size: Variant = d.get("size")
	if size is Array:
		var pair: Vector2i = r.int_pair("size")
		def.size_min = pair.x
		def.size_max = pair.y
	elif r.has("size"):
		def.size_min = r.integer("size")
		def.size_max = def.size_min
	if r.has("pool"):
		for entry: Dictionary in r.dict_list("pool"):
			var entry_reader := DefReader.new(entry, r.context() + " pool")
			def.pool_monsters.append(entry_reader.id("monster"))
			def.pool_weights.append(entry_reader.integer("weight"))
			r.absorb(entry_reader.ok)
	if r.has("fixed"):
		def.fixed = r.id_list("fixed")
	def.reward = read_reward(d if inline_reward else (d.get("reward", {}) as Dictionary), r)
	return def if r.ok else null


## The reward keys of `d` (F-142) as typed values; a mistyped key fails `r`.
static func read_reward(d: Dictionary, r: DefReader) -> Dictionary:
	var reward: Dictionary = {}
	var source := DefReader.new(d, r.context() + " reward")
	for key: String in ["gold", "dust"]:
		if d.has(key):
			reward[key] = source.int_pair(key)
	for key: String in ["crystal_pct", "piece_pct"]:
		if d.has(key):
			reward[key] = source.number(key)
	r.absorb(source.ok)
	return reward
