class_name HelperIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the helper grades of balance.json
## (`helper.grades`, in order of grade) and the contract items by (trade, grade).

var grades: Array[HelperGradeDef] = []
var by_id: Dictionary[StringName, HelperGradeDef] = {}
var _contracts: Dictionary[String, ItemDef] = {}


func build(balance: Dictionary, items: Array[ItemDef]) -> void:
	for entry: Variant in (DataValidator.lookup(balance, "helper.grades") as Array):
		var def: HelperGradeDef = HelperGradeDef.from_dict(entry as Dictionary)
		if def != null:
			grades.append(def)
			by_id[def.id] = def
	for def: ItemDef in items:
		if def.is_contract():
			_contracts[_key(def.contract_skill, def.contract_grade)] = def


func clear() -> void:
	grades.clear()
	by_id.clear()
	_contracts.clear()



func contract_for(skill_id: StringName, grade_id: StringName) -> ItemDef:
	return _contracts.get(_key(skill_id, grade_id)) as ItemDef


static func _key(skill_id: StringName, grade_id: StringName) -> String:
	return "%s|%s" % [skill_id, grade_id]
