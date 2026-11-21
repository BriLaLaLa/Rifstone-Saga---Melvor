class_name StarterFinalDef
extends RefCounted
## The final bonus of the starter quests, `final_reward` of data/tutorial/starter_quests.json (docs/M31_RITOCCHI_TUTORIAL.md §2.3, §5).
## The reward is money OR items (a Mail message holds one of them) plus optional character xp.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var reward_money: int = 0
var reward_items: Array[ItemQty] = []
var reward_character_xp: int = 0


static func from_dict(d: Dictionary) -> StarterFinalDef:
	var r := DefReader.new(d, "starter final reward")
	var def := StarterFinalDef.new()
	def.id = r.id("id")
	def.name = r.text("name")
	def.description = r.text("description")
	if r.is_dict("reward"):
		var m := DefReader.new(r.dict("reward"), r.context() + " reward")
		def.reward_money = m.integer("money") if m.has("money") else 0
		def.reward_character_xp = m.integer("character_xp") if m.has("character_xp") else 0
		if m.has("items"):
			def.reward_items = TutorialStepDef.items(m, m.dict_list("items"))
		r.absorb(m.ok)
	return def if r.ok else null
