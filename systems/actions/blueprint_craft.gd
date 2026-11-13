class_name BlueprintCraft
extends RefCounted
## Blueprint craft: pure rules of the single-cycle Forging action (docs/01_GDD.md §5.1, F-90, F-91, F-92;
## docs/05_INTERFACES.md §5.8b). No state: the running craft lives in ActionRunner.
## The level and the XP of a grade come from the Forging smelting recipe of that grade (the action that makes the
## ingot `upgrade.ingot_items[grade - 1]`): its level is the level of the grade (02 §8.1), its XP and interval give `xp_min`.

const SKILL: StringName = &"forging"
const ACTION: StringName = &"blueprint_craft"
const RARITY_STAT: StringName = &"item_rarity_pct"
const LOG_CATEGORY: String = "actions"
const MS_PER_MIN: int = 60000
const EPSILON: float = 0.000001
## Returned for a grade without smelting recipe (a data error, logged): nobody reaches it.
const UNREACHABLE_LEVEL: int = 9999


## Level of the grade `grade` (02 §8.1) = level of its smelting recipe.
static func grade_level(grade: int, data: GameData) -> int:
	var recipe: ActionDef = _smelt_recipe(grade, data)
	return recipe.level if recipe != null else UNREACHABLE_LEVEL


## Forging level needed to craft `blueprint`.
static func required_level(blueprint: ItemDef, data: GameData) -> int:
	return grade_level(blueprint.blueprint.grade, data)


## F-90: duration in ms, F-03 included (`interval_pct` = `skill_interval_pct` total, minimum `action.min_interval_ms`).
static func duration_ms(blueprint: ItemDef, interval_pct: float, data: GameData) -> int:
	var base_ms: int = roundi(_duration_min(blueprint, data) * MS_PER_MIN)
	return ActionMath.interval_ms(base_ms, interval_pct, int(data.balance_value("action.min_interval_ms")))


## F-90: XP before F-02. `floor(xp_mult × duration_min × xp_min(n))`, `duration_min` without F-03.
static func xp(blueprint: ItemDef, data: GameData) -> int:
	var recipe: ActionDef = _smelt_recipe(blueprint.blueprint.grade, data)
	if recipe == null:
		return 0
	var xp_min: float = float(recipe.xp) * MS_PER_MIN / float(recipe.interval_ms)
	return floori(float(data.balance_value("blueprint.xp_mult")) * _duration_min(blueprint, data) * xp_min + EPSILON)


## Materials of the craft: the `inputs` of the blueprint plus its rare components (the blueprint itself excluded).
static func inputs(blueprint: ItemDef) -> Array[ItemQty]:
	var result: Array[ItemQty] = blueprint.blueprint.inputs.duplicate()
	result.append_array(blueprint.blueprint.rare_components)
	return result


## unknown_id (not a blueprint, or not in the bank), level_too_low, invalid_choice, missing_inputs, armory_full.
static func can_start(session: GameSession, blueprint_id: StringName, chosen_affix: StringName = &"") -> CommandResult:
	var data: GameData = session.data
	if not data.has_item(blueprint_id) or not data.item(blueprint_id).is_blueprint():
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not session.bank.has(blueprint_id, 1):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var bp: ItemDef = data.item(blueprint_id)
	var level: int = session.skills.get_level(SKILL)
	if level < required_level(bp, data):
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	if chosen_affix != &"" and not _choice_allowed(bp, chosen_affix, level, data):
		return CommandResult.fail(Reasons.INVALID_CHOICE)
	var needed: Dictionary[StringName, int] = _needed(bp)
	for item_id: StringName in needed:
		if not session.bank.has(item_id, needed[item_id]):
			return CommandResult.fail(Reasons.MISSING_INPUTS)
	if not session.armory.can_add(1):
		return CommandResult.fail(Reasons.ARMORY_FULL)
	return CommandResult.success()


## Creates the Masterwork (F-91/F-92 with the current Forging level and `item_rarity_pct`) and puts it in the Armory.
## Returns its uid, 0 (no rolls made) when the Armory is full.
static func finish(session: GameSession, blueprint_id: StringName, chosen_affix: StringName) -> int:
	if not session.armory.can_add(1):
		return 0
	var ctx: ModifierContext = ModifierContext.for_action(SKILL, ACTION)
	var inst: ItemInstance = ItemRoller.create_from_blueprint(session.data.item(blueprint_id),
			session.skills.get_level(SKILL), session.modifiers.total(RARITY_STAT, ctx), chosen_affix, session.data,
			session.rng)
	return session.armory.add(inst)


## Takes the blueprint and its materials out of the bank (the caller checked `can_start`; nothing changes otherwise).
static func consume(session: GameSession, blueprint_id: StringName) -> void:
	var needed: Dictionary[StringName, int] = _needed(session.data.item(blueprint_id))
	for item_id: StringName in needed:
		# Not inside assert(): asserts are stripped from release builds and the removal would never run.
		var removed: CommandResult = session.bank.remove(item_id, needed[item_id])
		assert(removed.ok, "bank.remove failed after the inputs check")


## Gives the blueprint and its materials back (a stop before the end). An item that does not fit is lost
## (`bank_rejected`, 05 §5.8b).
static func refund(session: GameSession, blueprint_id: StringName) -> void:
	var needed: Dictionary[StringName, int] = _needed(session.data.item(blueprint_id))
	for item_id: StringName in needed:
		session.bank.add(item_id, needed[item_id])


# Blueprint + inputs + rare component, duplicates added up.
static func _needed(bp: ItemDef) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {bp.id: 1}
	for entry: ItemQty in inputs(bp):
		result[entry.item_id] = result.get(entry.item_id, 0) + entry.qty
	return result


static func _choice_allowed(bp: ItemDef, affix_id: StringName, level: int, data: GameData) -> bool:
	if level < int(data.balance_value("blueprint.choose_affix_level")):
		return false
	var base: ItemDef = data.item(bp.blueprint.base_id)
	for def: AffixDef in ItemRoller.chosen_affix_candidates(base, data.grade_level(base.equip.grade), data):
		if def.id == affix_id:
			return true
	return false


# F-90: duration_base_min + duration_per_grade_min × (n − 1), before F-03.
static func _duration_min(bp: ItemDef, data: GameData) -> float:
	return float(data.balance_value("blueprint.duration_base_min")) + float(
			data.balance_value("blueprint.duration_per_grade_min")) * (bp.blueprint.grade - 1)


# The Forging action that makes the ingot of `grade`; null (and an error) when there is none.
static func _smelt_recipe(grade: int, data: GameData) -> ActionDef:
	var ingots: Variant = data.balance_value("upgrade.ingot_items")
	if ingots is Array and grade >= 1 and grade <= (ingots as Array).size():
		var ingot: StringName = StringName(str((ingots as Array)[grade - 1]))
		for action: ActionDef in data.actions_for_skill(SKILL):
			for out: ItemQty in action.outputs:
				if out.item_id == ingot:
					return action
	Log.error(LOG_CATEGORY, "no smelting recipe for grade %d" % grade)
	return null
