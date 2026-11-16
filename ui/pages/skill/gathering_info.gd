class_name GatheringInfo
extends RefCounted
## "Si trova in:" line of a gathering page (docs/01_GDD_M24.md §35.7): the areas whose nodes (`data.area_nodes`) include the
## discipline, with the highest resource level of each area. Pure functions over the data; no state.

const FOUND_IN_TEXT: String = "Si trova in: %s"
const AREA_TEXT: String = "%s (risorse fino al livello %s)"
const SEPARATOR: String = ", "
const NONE_TEXT: String = "Nessuna area ha ancora nodi di questa disciplina."


## The line of `skill_id` (never empty).
static func text(data: GameData, skill_id: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for area: AreaDef in data.areas():
		var nodes: AreaNodesDef = data.area_nodes(area.id)
		if nodes == null:
			continue
		for entry: NodeEntryDef in nodes.entries:
			if entry.skill == skill_id:
				parts.append(AREA_TEXT % [area.name, NumberFormat.format_int(nodes.max_level)])
				break
	if parts.is_empty():
		return NONE_TEXT
	return FOUND_IN_TEXT % SEPARATOR.join(parts)


## A wrapped label named `FoundInLabel` with the line of `skill_id`.
static func build_label(data: GameData, skill_id: StringName) -> Label:
	var label := Label.new()
	label.name = "FoundInLabel"
	label.text = text(data, skill_id)
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
