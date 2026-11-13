class_name QuestPicker
extends RefCounted
## Choice of the next quest of a free Noticeboard slot (docs/02_FORMULAS.md F-135): pure static functions, no state.


## F-135 `current_tier`: the highest tier whose `tier_levels` entry is <= the character level (0 if none).
static func current_tier(character_level: int, tier_levels: Array) -> int:
	var tier: int = 0
	for index: int in tier_levels.size():
		if int(tier_levels[index]) <= character_level:
			tier = index + 1
	return tier


## F-135: from `cursor` (circular over `quests`, in file order) the first candidate; `cursor` becomes `(index + 1) mod N`.
## A candidate meets its requirements (character and skill levels), has `tier >= current_tier - (tier_window - 1)`, is not in
## `active` and not in `recent`; if nobody qualifies `recent` is ignored; if still nobody, `{"id": &"", "cursor": cursor}`.
## `params` is the `quest` section of balance.json (`tier_levels`, `tier_window`); returns `{"id": StringName, "cursor": int}`.
static func pick(quests: Array[QuestDef], cursor: int, recent: Array[StringName], active: Array[StringName],
		character_level: int, skill_levels: Dictionary, params: Dictionary) -> Dictionary:
	var count: int = quests.size()
	if count == 0:
		return {"id": &"", "cursor": cursor}
	var lowest: int = current_tier(character_level, params["tier_levels"] as Array) - (int(params["tier_window"]) - 1)
	for use_memory: bool in [true, false]:
		for step: int in count:
			var index: int = posmod(cursor + step, count)
			var quest: QuestDef = quests[index]
			if _is_candidate(quest, lowest, character_level, skill_levels, active) \
					and not (use_memory and recent.has(quest.id)):
				return {"id": quest.id, "cursor": (index + 1) % count}
	return {"id": &"", "cursor": cursor}


static func _is_candidate(quest: QuestDef, lowest_tier: int, character_level: int, skill_levels: Dictionary,
		active: Array[StringName]) -> bool:
	if quest.tier < lowest_tier or quest.req_character > character_level or active.has(quest.id):
		return false
	for skill: StringName in quest.req_skills:
		if int(skill_levels.get(skill, 0)) < quest.req_skills[skill]:
			return false
	return true
