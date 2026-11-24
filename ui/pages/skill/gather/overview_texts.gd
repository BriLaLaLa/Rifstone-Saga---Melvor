class_name OverviewTexts
extends RefCounted
## Texts of the Overview tab of a gathering page (docs/01_GDD_M36.md §44.2). Italian; names, percentages and levels come from the model. No state.

const ZONE_NOW_TEXT: String = "Zona attuale: %s"
const NO_ZONE_TEXT: String = "Nessuna zona: vai in combattimento."
const NO_RESOURCES_TEXT: String = "Questa disciplina non ha risorse in questa zona."
const RESOURCE_LINE_TEXT: String = "%s  %d%%"
const NOT_WORKABLE_TEXT: String = "non ancora lavorabile"
const COLOR_BALL: String = "●"
const TOOL_PREFIX: String = "Attrezzo: %s"
const TOOL_EFFECT_SEPARATOR: String = " · "
const OPEN_TOOL_TEXT: String = "Apri Attrezzo"
const TAB_TITLES: Dictionary[StringName, String] = {
	&"overview": "Panoramica",
	&"resources": "Risorse",
	&"tool": "Attrezzo",
}
