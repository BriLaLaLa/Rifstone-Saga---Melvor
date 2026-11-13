class_name DungeonDef
extends RefCounted
## A dungeon of data/dungeons/<id>.json (docs/04_DATA_SCHEMA.md §27, F-137...F-143). It builds its own monsters
## (`monsters`, ordinary MonsterDefs marked with `dungeon`; GameData registers them) and resolves the stage monsters.
## Numbers of the hidden map (`forks`, weights, `hint_pct`), the room types, the events, the stages and the boss loot
## are all data; nothing here is a design number.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var icon: String = ""
var order: int = 0
var req_character: int = 0
var recommended_level: int = 0
var ticket: StringName = &""
# map (F-137)
var forks: int = 0
var width_weights: Array[int] = []  # width 2, 3, 4
var exit_weights: Array[int] = []  # exits 2, 3, 4
var hint_pct: float = 0.0
var monsters: Array[MonsterDef] = []
var entrance: DungeonRoomType = null
var room_types: Array[DungeonRoomType] = []
# events (F-140)
var trap_kinds: Array[StringName] = []
var trap_dash_hp_pct: float = 0.0
var trap_ambush: DungeonRoomType = null
var trap_reward: Dictionary = {}
var rest_heal_pct: float = 0.0
var rest_forage: DungeonRoomType = null  # `reward` = {dust, crystal_pct}
var stages: Array[DungeonStageDef] = []
# boss loot (F-143)
var boss_gold: Vector2i = Vector2i.ZERO
var boss_dust: Vector2i = Vector2i.ZERO
var boss_pieces: Array[Dictionary] = []  # {"rarity": StringName} or {"min_rarity": StringName}
var boss_crystals: int = 0
var boss_card_pct: float = 0.0
var boss_card_grade: int = 0
var boss_drops: Array[DropEntry] = []
var loot_table: StringName = &""


static func from_dict(d: Dictionary) -> DungeonDef:
	var r := DefReader.new(d, "dungeon")
	var def := DungeonDef.new()
	def.id = r.id("id")
	r.set_context("dungeon '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.icon = r.text("icon")
	def.order = r.integer("order")
	def.req_character = int((d.get("requirements", {}) as Dictionary).get("character", 0))
	def.recommended_level = r.integer("recommended_level")
	def.ticket = r.id("ticket")
	def.loot_table = r.id("loot_table")
	if r.is_dict("map"):
		_read_map(def, r.dict("map"), r)
	for entry: Dictionary in r.dict_list("monsters"):
		var monster: MonsterDef = MonsterDef.from_dict(entry)
		r.absorb(monster != null)
		if monster != null:
			monster.dungeon = def.id
			def.monsters.append(monster)
	if r.is_dict("rooms"):
		_read_rooms(def, r.dict("rooms"), r)
	for entry: Dictionary in r.dict_list("stages"):
		var stage: DungeonStageDef = DungeonStageDef.from_dict(entry)
		r.absorb(stage != null)
		if stage != null:
			stage.monster = def.monster_def(stage.monster_id)
			r.absorb(stage.monster != null)
			def.stages.append(stage)
	if r.is_dict("boss"):
		_read_boss(def, r.dict("boss"), r)
	return def if r.ok else null


## The dungeon's own monster `monster_id`; null (no error) if it is not one of them.
func monster_def(monster_id: StringName) -> MonsterDef:
	for monster: MonsterDef in monsters:
		if monster.id == monster_id:
			return monster
	return null


## The room type `type_id` of `rooms.types`; null if the dungeon has no such type.
func room_type(type_id: StringName) -> DungeonRoomType:
	for type: DungeonRoomType in room_types:
		if type.id == type_id:
			return type
	return null


static func _read_map(def: DungeonDef, map: Dictionary, r: DefReader) -> void:
	var m := DefReader.new(map, r.context() + " map")
	def.forks = m.integer("forks")
	for key: String in ["width_weights", "exit_weights"]:
		var weights: Array[int] = []
		for value: Variant in (map.get(key, []) as Array):
			weights.append(int(value))
		if key == "width_weights":
			def.width_weights = weights
		else:
			def.exit_weights = weights
	def.hint_pct = m.number("hint_pct")
	r.absorb(m.ok)


static func _read_rooms(def: DungeonDef, rooms: Dictionary, r: DefReader) -> void:
	var rr := DefReader.new(rooms, r.context() + " rooms")
	if rr.is_dict("entrance"):
		def.entrance = DungeonRoomType.from_dict(rr.dict("entrance"), &"entrance")
		r.absorb(def.entrance != null)
	for entry: Dictionary in rr.dict_list("types"):
		var type: DungeonRoomType = DungeonRoomType.from_dict(entry, StringName(str(entry.get("id", ""))))
		r.absorb(type != null)
		if type != null:
			def.room_types.append(type)
	if rr.is_dict("trap"):
		var trap: Dictionary = rr.dict("trap")
		var tr := DefReader.new(trap, r.context() + " trap")
		def.trap_kinds = tr.id_list("kinds")
		def.trap_dash_hp_pct = tr.number("dash_hp_pct")
		if tr.is_dict("ambush"):
			def.trap_ambush = DungeonRoomType.from_dict(tr.dict("ambush"), &"ambush")
			tr.absorb(def.trap_ambush != null)
		def.trap_reward = DungeonRoomType.read_reward(trap.get("reward", {}) as Dictionary, tr)
		r.absorb(tr.ok)
	if rr.is_dict("rest"):
		var rest: Dictionary = rr.dict("rest")
		var rs := DefReader.new(rest, r.context() + " rest")
		def.rest_heal_pct = rs.number("heal_pct")
		if rs.is_dict("forage"):
			def.rest_forage = DungeonRoomType.from_dict(rs.dict("forage"), &"forage", true)
			rs.absorb(def.rest_forage != null)
		r.absorb(rs.ok)
	r.absorb(rr.ok)


static func _read_boss(def: DungeonDef, boss: Dictionary, r: DefReader) -> void:
	var b := DefReader.new(boss, r.context() + " boss")
	def.boss_gold = b.int_pair("gold")
	def.boss_dust = b.int_pair("dust")
	def.boss_crystals = b.integer("crystals")
	def.boss_card_pct = b.number("card_pct")
	def.boss_card_grade = b.integer("card_grade")
	for piece: Dictionary in b.dict_list("pieces"):
		var typed: Dictionary = {}
		for key: Variant in piece:
			typed[str(key)] = StringName(str(piece[key]))
		def.boss_pieces.append(typed)
	for entry: Dictionary in b.dict_list("drops"):
		var drop: DropEntry = DropEntry.from_dict(entry)
		b.absorb(drop != null)
		if drop != null:
			def.boss_drops.append(drop)
	r.absorb(b.ok)
