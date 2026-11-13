class_name DungeonStageDef
extends RefCounted
## One of the three stages of a dungeon boss (docs/04_DATA_SCHEMA.md §27, F-139): the right hand, the strategist, the
## king. `monster` is resolved by DungeonDef (null until then); `reward` is the stage reward of F-142 (empty for the
## last stage, whose reward is the boss loot of F-143).
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var monster_id: StringName = &""
var monster: MonsterDef = null
var escorts: Array[StringName] = []
var intro_ms: int = 0
var title: String = ""
var quote: String = ""
var ability: BossAbilityDef = null
var reward: Dictionary = {}


static func from_dict(d: Dictionary) -> DungeonStageDef:
	var r := DefReader.new(d, "dungeon stage")
	var def := DungeonStageDef.new()
	def.id = r.id("id")
	r.set_context("dungeon stage '%s'" % def.id)
	def.monster_id = r.id("monster")
	def.escorts = r.id_list("escorts")
	def.intro_ms = r.integer("intro_ms")
	def.title = r.text("title")
	def.quote = r.text("quote")
	if r.is_dict("ability"):
		def.ability = BossAbilityDef.from_dict(r.dict("ability"))
		r.absorb(def.ability != null)
	if d.get("reward") is Dictionary:
		def.reward = DungeonRoomType.read_reward(d["reward"] as Dictionary, r)
	return def if r.ok else null
