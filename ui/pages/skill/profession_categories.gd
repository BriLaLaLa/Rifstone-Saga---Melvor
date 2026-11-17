class_name ProfessionCategories
extends RefCounted
## Categories of the recipe list of a production page (presentation only): the sub-tabs of the Forging page and of the
## Engraver become sections; Forging also has two pages that are not recipes (blueprints and the smith's bench), which the
## list offers as entries after the sections. Any other craft has one section with all its recipes.

const ALL: StringName = &"all"


## `[{"id", "label"}]` of the recipe sections of `skill_id`, in the order they are drawn.
static func sections(skill_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if skill_id == ForgeTabs.SKILL:
		for tab: Dictionary in ForgeTabs.TABS:
			if tab["id"] == ForgeTabs.TAB_INGOTS or tab["id"] == ForgeTabs.TAB_PLATES:
				result.append(tab)
	elif skill_id == EngraverSections.SKILL:
		for tab: Dictionary in EngraverSections.TABS:
			result.append({"id": tab["id"], "label": tab["label"]})
	else:
		result.append({"id": ALL, "label": ProfessionTexts.ALL_CATEGORY_LABEL})
	return result


## The pages of the list that are not recipes: `[{"id", "label"}]` (Forging only).
static func special_pages(skill_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if skill_id == ForgeTabs.SKILL:
		for tab: Dictionary in ForgeTabs.TABS:
			if tab["id"] == ForgeTabs.TAB_BLUEPRINTS or tab["id"] == ForgeTabs.TAB_BENCH:
				result.append(tab)
	return result


## The section of the recipe `action`.
static func section_of(action: ActionDef) -> StringName:
	if action.skill_id == ForgeTabs.SKILL:
		return ForgeTabs.tab_of(action)
	if action.skill_id == EngraverSections.SKILL:
		return EngraverSections.tab_of(EngraverSections.section_of(action))
	return ALL
