class_name HelperGradeNames
extends RefCounted
## Display names of the helper grades (`helper.grades` of balance.json; names from docs/NOMI.md, Riforma 2). Presentation
## only: the grade ids and their speed come from the data.

const NAMES: Dictionary[StringName, String] = {
	&"apprentice": "Apprendista",
	&"journeyman": "Garzone",
	&"expert": "Esperto",
	&"master": "Maestro",
}


## The Italian name of a grade id; the id itself when unknown (never invents a grade).
static func name_of(grade_id: StringName) -> String:
	return NAMES.get(grade_id, String(grade_id))
