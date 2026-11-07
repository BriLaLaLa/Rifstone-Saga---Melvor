class_name LevelToastTexts
extends RefCounted
## Texts of the level toasts (B5): one toast per skill when several levels are gained in the same frame. Defined once
## here. No state.

const SINGLE_TEXT: String = "%s: livello %d"
const RANGE_TEXT: String = "%s: livello %d → %d"


## "Skill: livello 5" for one level, "Skill: livello 2 → 5" when `to_level` is more than one level above `from_level`
## (the level before the first gain).
static func text(skill_name: String, from_level: int, to_level: int) -> String:
	if to_level - from_level <= 1:
		return SINGLE_TEXT % [skill_name, to_level]
	return RANGE_TEXT % [skill_name, from_level, to_level]
