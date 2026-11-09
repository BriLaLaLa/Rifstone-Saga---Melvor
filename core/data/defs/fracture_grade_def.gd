class_name FractureGradeDef
extends RefCounted
## One row of `fracture.grades` of balance.json (docs/04_DATA_SCHEMA.md §11.4, F-110). `grade` is the position + 1.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var grade: int = 0
var areas: Array[StringName] = []
var level_bonus: int = 0
var hp_mult: float = 1.0
var damage_mult: float = 1.0
var reward_mult: float = 1.0
var piece_grade: int = 1
var recommended_level: int = 1


static func from_dict(d: Dictionary, grade_number: int) -> FractureGradeDef:
	var r := DefReader.new(d, "fracture grade %d" % grade_number)
	var def := FractureGradeDef.new()
	def.grade = grade_number
	def.areas = r.id_list("areas")
	def.level_bonus = r.integer("level_bonus")
	def.hp_mult = r.number("hp_mult")
	def.damage_mult = r.number("damage_mult")
	def.reward_mult = r.number("reward_mult")
	def.piece_grade = r.integer("piece_grade")
	def.recommended_level = r.integer("recommended_level")
	return def if r.ok else null
