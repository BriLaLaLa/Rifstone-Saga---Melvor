class_name SkillDef
extends RefCounted
## A skill of data/skills/skills.json (docs/04_DATA_SCHEMA.md §4). `color` comes from `#rrggbb`.
## `mastery_bonuses` is optional (only skills with mastery have it) and empty when absent.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var id: StringName = &""
var name: String = ""
var description: String = ""
var category: StringName = &""
var order: int = 0
var icon: String = ""
var color: Color = Color()
var has_mastery: bool = false
var mastery_bonuses: Array[MasteryBonusRule] = []
var level_modifiers: Array[LevelModifier] = []  # M10 (F-93): empty when absent


static func from_dict(d: Dictionary) -> SkillDef:
	var r := DefReader.new(d, "skill")
	var def := SkillDef.new()
	def.id = r.id("id")
	r.set_context("skill '%s'" % def.id)
	def.name = r.text("name")
	def.description = r.text("description")
	def.category = r.id("category")
	def.order = r.integer("order")
	def.icon = r.text("icon")
	def.color = r.color("color")
	def.has_mastery = r.flag("has_mastery")
	if r.has("mastery_bonuses"):
		for entry: Dictionary in r.dict_list("mastery_bonuses"):
			var rule: MasteryBonusRule = MasteryBonusRule.from_dict(entry)
			r.absorb(rule != null)
			if rule != null:
				def.mastery_bonuses.append(rule)
	if r.has("level_modifiers"):
		for entry: Dictionary in r.dict_list("level_modifiers"):
			var level_mod: LevelModifier = LevelModifier.from_dict(entry)
			r.absorb(level_mod != null)
			if level_mod != null:
				def.level_modifiers.append(level_mod)
	return def if r.ok else null
