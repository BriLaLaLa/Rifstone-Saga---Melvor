class_name TrainerGradeDef
extends RefCounted
## A grade of the Trainers of data/disciplines/trainers.json `grades` (docs/04_DATA_SCHEMA_M24.md §29.2, F-158):
## the level cap it allows and the character level it asks for. `from_dict` returns null (after logging) on a bad field.

var id: StringName = &""
var name: String = ""
var cap: int = 0
var character_level: int = 0


static func from_dict(d: Dictionary) -> TrainerGradeDef:
	var r := DefReader.new(d, "trainer grade")
	var def := TrainerGradeDef.new()
	def.id = r.id("id")
	r.set_context("trainer grade '%s'" % def.id)
	def.name = r.text("name")
	def.cap = r.integer("cap")
	def.character_level = r.integer("character_level")
	return def if r.ok else null


## F-158: the gold price of grade `grade` (1-based): `trainer.learn_gold` for grade 1, then
## `round(trainer.gold_base * trainer.gold_growth ^ (grade - 2))`. 0 for a grade below 1.
static func gold(data: GameData, grade: int) -> int:
	if grade < 1:
		return 0
	if grade == 1:
		return int(data.balance_value("trainer.learn_gold"))
	return int(roundf(float(data.balance_value("trainer.gold_base")) * pow(float(data.balance_value("trainer.gold_growth")), grade - 2)))
