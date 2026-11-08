class_name GuideBook
extends RefCounted
## The Guide data held by GameData (M11, docs/04_DATA_SCHEMA.md §19): the hand-written pages ordered by section, order
## and id, and the exceptions of `data/guide/exceptions.json`. Internal to GameData (kept out of game_data.gd for its
## size limit); the public accessors are `GameData.guide_pages/guide_page/guide_exceptions`.

var by_id: Dictionary[StringName, GuidePageDef] = {}
var list: Array[GuidePageDef] = []
var exceptions: Dictionary = {"no_source": [], "no_use": []}


## Builds the pages and exceptions from the raw files (`{path: object}`, may be empty). Problems go to `data.errors`;
## an exception that is not needed (the item has a source or a use) is one of them.
func build(files: Dictionary, data: GameData) -> void:
	for path: String in files:
		var content: Dictionary = files[path] as Dictionary
		if path.get_file() == DataValidatorGuide.EXCEPTIONS_FILE:
			for key: String in DataValidatorGuide.EXCEPTION_KEYS:
				exceptions[key] = (content.get(key, []) as Array).map(func(id: String) -> StringName: return StringName(id))
			continue
		for d: Dictionary in GameData._list(content, "pages"):
			data._add(GuidePageDef.from_dict(d), by_id, list, path, "guide page", d)
	list.sort_custom(_before)
	if data.errors.is_empty():
		data.errors.append_array(DataValidatorGuide.check_exceptions(data))


func clear() -> void:
	by_id.clear()
	list.clear()
	exceptions = {"no_source": [], "no_use": []}


static func _before(a: GuidePageDef, b: GuidePageDef) -> bool:
	var section_a: int = DataValidatorGuide.SECTIONS.find(String(a.section))
	var section_b: int = DataValidatorGuide.SECTIONS.find(String(b.section))
	if section_a != section_b:
		return section_a < section_b
	if a.order != b.order:
		return a.order < b.order
	return String(a.id) < String(b.id)
