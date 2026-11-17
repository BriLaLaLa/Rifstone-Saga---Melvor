class_name Disciplines
extends RefCounted
## Disciplines and their Trainers (docs/01_GDD_M24.md §35.3, §35.5; docs/02_FORMULAS_M24.md F-158, F-159, F-160;
## docs/05_INTERFACES_M24.md §5.31): which of the skills with `discipline` are learned (at most `disciplines.max_per_category`
## per category), at which grade, and which Recipes were discovered.
##
## State: skill id -> grade (1..n), and the discovered recipe action ids in order of discovery. The grade fixes the level cap
## of the discipline (F-160, enforced by SkillsSystem through `xp_max`). Commands are atomic: a refusal changes nothing and emits
## nothing. Signals go to the session EventBus after the state changed; `new_game`/`from_save` emit nothing.
## No modifier sources. Dependencies: data, events, wallet, bank, skills, character, mastery, actions (only `drop_jobs_of`),
## combat (only `node_skill`).

const SAVE_KEY: StringName = &"disciplines"
const LOG_CATEGORY: String = "disciplines"
const MAX_PER_CATEGORY_KEY: String = "disciplines.max_per_category"
const SKILL_MARGIN_KEY: String = "trainer.skill_margin"
const UNLEARN_PCT_KEY: String = "trainer.unlearn_pct"
const UNLEARN_MIN_KEY: String = "trainer.unlearn_min_gold"
const XP_CAP_KEY: String = "xp_curve.xp_cap"
const SAVE_LEARNED_KEY: String = "learned"
const SAVE_RECIPES_KEY: String = "recipes"
const SAVE_EXTRA_KEY: String = "extra"

var _session: GameSession
var _data: GameData
var _events: GameEvents
# skill id -> grade (1..n); only learned disciplines.
var _grades: Dictionary[StringName, int] = {}
# Discovered recipe action ids, in order of discovery.
var _recipes: Array[StringName] = []
# Learned disciplines that occupy an extra slot (only a v8 -> v9 save creates one, docs/01_GDD_M25.md §37.2).
var _extra: Array[StringName] = []


func _init(session: GameSession) -> void:
	assert(session != null, "Disciplines needs a session")
	_session = session
	_data = session.data
	_events = session.events


# --- reads ------------------------------------------------------------------------------------------------------------------

func is_discipline(skill_id: StringName) -> bool:
	return _data.disciplines().has(skill_id)


## &"gathering" or &"artisan" for a discipline, &"" otherwise.
func category_of(skill_id: StringName) -> StringName:
	return _data.skill(skill_id).category if is_discipline(skill_id) else &""


## A learned discipline, or a known skill that is not a discipline (the Incisore); false for an unknown skill.
func is_learned(skill_id: StringName) -> bool:
	if is_discipline(skill_id):
		return _grades.has(skill_id)
	return _is_skill(skill_id)


## The learned disciplines of the category, in order of `order`.
func learned(category: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for skill_id: StringName in _data.disciplines(category):
		if _grades.has(skill_id):
			result.append(skill_id)
	return result


## Never negative, also with an extra slot.
func free_slots(category: StringName) -> int:
	return maxi(0, int(_data.balance_value(MAX_PER_CATEGORY_KEY)) - learned(category).size())


## True when the learned discipline occupies an extra slot (M25-11).
func is_extra(skill_id: StringName) -> bool:
	return _extra.has(skill_id)


## 1..n; 0 when not learned or not a discipline.
func grade(skill_id: StringName) -> int:
	return _grades.get(skill_id, 0)


## The grade's level cap; `xp_curve.max_level` for a skill that is not a discipline; 0 when a discipline is not learned.
func level_cap(skill_id: StringName) -> int:
	if is_discipline(skill_id):
		return _data.trainer_grade(grade(skill_id)).cap if _grades.has(skill_id) else 0
	return _data.xp_table().max_level if _is_skill(skill_id) else 0


## F-160: the xp the discipline can hold (`xp_curve.xp_cap` at the top grade or for a skill without discipline, 0 when not learned).
func xp_max(skill_id: StringName) -> int:
	if is_discipline(skill_id) and not _grades.has(skill_id):
		return 0
	var cap: int = level_cap(skill_id)
	if cap <= 0:
		return 0
	var table: XpTable = _data.xp_table()
	return int(_data.balance_value(XP_CAP_KEY)) if cap >= table.max_level else table.xp_for_level(cap)


## F-158: the gold of the next grade (grade 0: of grade 1); -1 at the top grade or for a skill that is not a discipline.
func next_grade_cost(skill_id: StringName) -> int:
	if not is_discipline(skill_id) or grade(skill_id) >= _data.trainer_grades().size():
		return -1
	return TrainerGradeDef.gold(_data, grade(skill_id) + 1)


## F-159; 0 when not learned.
func unlearn_cost(skill_id: StringName) -> int:
	var g: int = grade(skill_id)
	if g <= 0:
		return 0
	var total: int = 0
	for k: int in range(1, g + 1):
		total += TrainerGradeDef.gold(_data, k)
	return maxi(int(_data.balance_value(UNLEARN_MIN_KEY)), roundi(float(_data.balance_value(UNLEARN_PCT_KEY)) / 100.0 * total))


# --- commands ---------------------------------------------------------------------------------------------------------------

## unknown_id, not_a_discipline, already_learned, discipline_slots_full, requirement_not_met (character level), not_enough_gold.
func can_learn(skill_id: StringName) -> CommandResult:
	var check: CommandResult = _check_discipline(skill_id)
	if not check.ok:
		return check
	if _grades.has(skill_id):
		return CommandResult.fail(Reasons.ALREADY_LEARNED)
	if free_slots(category_of(skill_id)) <= 0:
		return CommandResult.fail(Reasons.DISCIPLINE_SLOTS_FULL)
	return _check_grade_costs(1)


## `learn_gold` leaves the wallet, the discipline gets grade 1: `discipline_changed(skill, 1)`.
func learn(skill_id: StringName) -> CommandResult:
	var check: CommandResult = can_learn(skill_id)
	if check.ok:
		_buy_grade(skill_id, 1)
	return check


## unknown_id, not_a_discipline, not_learned, max_grade, level_too_low (the discipline), requirement_not_met (character level),
## not_enough_gold.
func can_train(skill_id: StringName) -> CommandResult:
	var check: CommandResult = _check_discipline(skill_id)
	if not check.ok:
		return check
	if not _grades.has(skill_id):
		return CommandResult.fail(Reasons.NOT_LEARNED)
	var next: int = grade(skill_id) + 1
	if next > _data.trainer_grades().size():
		return CommandResult.fail(Reasons.MAX_GRADE)
	if _session.skills.get_level(skill_id) < level_cap(skill_id) - int(_data.balance_value(SKILL_MARGIN_KEY)):
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	return _check_grade_costs(next)


## The gold of the next grade leaves the wallet, the grade goes up: `discipline_changed(skill, grade)`.
func train(skill_id: StringName) -> CommandResult:
	var check: CommandResult = can_train(skill_id)
	if check.ok:
		_buy_grade(skill_id, grade(skill_id) + 1)
	return check


## unknown_id, not_a_discipline, not_learned, discipline_busy (the node being worked), not_enough_gold.
func can_unlearn(skill_id: StringName) -> CommandResult:
	var check: CommandResult = _check_discipline(skill_id)
	if not check.ok:
		return check
	if not _grades.has(skill_id):
		return CommandResult.fail(Reasons.NOT_LEARNED)
	if _session.combat != null and _session.combat.node_skill() == skill_id:
		return CommandResult.fail(Reasons.DISCIPLINE_BUSY)
	if _session.wallet.get_gold() < unlearn_cost(skill_id):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	return CommandResult.success()


## F-159: gold out, the jobs of the discipline dropped from the queue, xp and mastery back to 0, grade 0
## (`skill_reset`, then `discipline_changed(skill, 0)`).
func unlearn(skill_id: StringName) -> CommandResult:
	var check: CommandResult = can_unlearn(skill_id)
	if not check.ok:
		return check
	_session.wallet.spend(unlearn_cost(skill_id))
	_session.actions.drop_jobs_of(skill_id)
	_session.skills.reset_skill(skill_id)
	_session.mastery.reset_skill(skill_id)
	_grades.erase(skill_id)
	_release_extra(skill_id)
	_events.discipline_changed.emit(skill_id, 0)
	return CommandResult.success()


# --- recipes ----------------------------------------------------------------------------------------------------------------

## True for the actions that need no discovery; false for an unknown action.
func knows_recipe(action_id: StringName) -> bool:
	if not _data.has_action(action_id):
		return false
	return not _data.action(action_id).discover or _recipes.has(action_id)


## The discovered recipes in order of discovery.
func known_recipes() -> Array[StringName]:
	return _recipes.duplicate()


## One Recipe leaves the Bank and its action is discovered (`recipe_learned`). unknown_id, not_a_recipe, recipe_known, not_enough_items.
func learn_recipe(item_id: StringName) -> CommandResult:
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var item: ItemDef = _data.item(item_id)
	if not item.is_recipe():
		return CommandResult.fail(Reasons.NOT_A_RECIPE)
	if knows_recipe(item.recipe_action):
		return CommandResult.fail(Reasons.RECIPE_KNOWN)
	if not _session.bank.has(item_id, 1):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	_session.bank.remove(item_id, 1)
	_recipes.append(item.recipe_action)
	_events.recipe_learned.emit(item.recipe_action)
	return CommandResult.success()


# --- save -------------------------------------------------------------------------------------------------------------------

## Nothing learned, no recipe.
func new_game() -> void:
	_grades.clear()
	_recipes.clear()
	_extra.clear()


## {"learned": {skill: grade}, "recipes": [action ids]} (docs/05_INTERFACES_M24.md §6b).
func to_save() -> Dictionary:
	var learned_grades: Dictionary = {}
	for skill_id: StringName in _data.disciplines():
		if _grades.has(skill_id):
			learned_grades[String(skill_id)] = _grades[skill_id]
	var recipes: Array = []
	for action_id: StringName in _recipes:
		recipes.append(String(action_id))
	var extra: Array = []
	for skill_id: StringName in _data.disciplines():
		if _extra.has(skill_id):
			extra.append(String(skill_id))
	return {SAVE_LEARNED_KEY: learned_grades, SAVE_RECIPES_KEY: recipes, SAVE_EXTRA_KEY: extra}


## Tolerant: skills that are unknown or not disciplines, and grades outside 1..n, are reported and dropped; more than the
## category allows keeps the first by `order`; recipes of unknown actions or of actions without `discover` are dropped.
## Then a discipline that is not learned but has xp (or mastery) is reset: "xp > 0 implies learned".
func from_save(d: Dictionary) -> void:
	new_game()
	_load_learned(d.get(SAVE_LEARNED_KEY, {}), d.get(SAVE_EXTRA_KEY, []))
	_load_recipes(d.get(SAVE_RECIPES_KEY, []))
	for skill_id: StringName in _data.disciplines():
		if not _grades.has(skill_id) and _session.skills.get_xp(skill_id) > 0:
			Log.warn(LOG_CATEGORY, "discipline '%s' has xp but is not learned: reset" % skill_id)
			_session.skills.reset_skill(skill_id)
			_session.mastery.reset_skill(skill_id)


func _load_learned(raw: Variant, raw_extra: Variant) -> void:
	if not raw is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid learned disciplines in save: none learned")
		return
	var top: int = _data.trainer_grades().size()
	var read: Dictionary[StringName, int] = {}
	for key: Variant in raw as Dictionary:
		var skill_id := StringName(str(key))
		var value: Variant = ProductionQueueLoader.read_int((raw as Dictionary)[key])
		if not is_discipline(skill_id):
			Log.warn(LOG_CATEGORY, "'%s' in the save is not a discipline: ignored" % skill_id)
		elif value == null or int(value) < 1 or int(value) > top:
			Log.warn(LOG_CATEGORY, "invalid grade for discipline '%s': ignored" % skill_id)
		else:
			read[skill_id] = int(value)
	var max_per: int = int(_data.balance_value(MAX_PER_CATEGORY_KEY))
	var wanted: Array[StringName] = _read_extra(raw_extra, read)
	for skill_id: StringName in _data.disciplines():  # in order of `order`
		if not read.has(skill_id):
			continue
		var allowed: int = max_per
		for other: StringName in wanted:
			if category_of(other) == category_of(skill_id):
				allowed += 1
		if learned(category_of(skill_id)).size() >= allowed:
			Log.warn(LOG_CATEGORY, "too many '%s' disciplines in save: '%s' dropped" % [category_of(skill_id), skill_id])
			continue
		_grades[skill_id] = read[skill_id]
	for skill_id: StringName in wanted:
		if _grades.has(skill_id):
			_extra.append(skill_id)
	for category: StringName in [&"gathering", &"artisan"]:
		if learned(category).size() <= max_per:
			_clear_extra_of(category)


# The valid entries of the save's `extra` (learned in the save, disciplines); the others are reported and dropped.
func _read_extra(raw: Variant, read: Dictionary[StringName, int]) -> Array[StringName]:
	var result: Array[StringName] = []
	if not raw is Array:
		Log.warn(LOG_CATEGORY, "invalid extra disciplines in save: none")
		return result
	for entry: Variant in raw as Array:
		var skill_id := StringName(str(entry))
		if is_discipline(skill_id) and read.has(skill_id):
			if not result.has(skill_id):
				result.append(skill_id)
		else:
			Log.warn(LOG_CATEGORY, "extra '%s' in the save is not a learned discipline: ignored" % skill_id)
	return result


func _clear_extra_of(category: StringName) -> void:
	for skill_id: StringName in _extra.duplicate():
		if category_of(skill_id) == category:
			_extra.erase(skill_id)


# After unlearning: the discipline leaves `extra`; with the category back within the limit the extra slots go away.
func _release_extra(skill_id: StringName) -> void:
	_extra.erase(skill_id)
	var category: StringName = category_of(skill_id)
	if learned(category).size() <= int(_data.balance_value(MAX_PER_CATEGORY_KEY)):
		_clear_extra_of(category)


func _load_recipes(raw: Variant) -> void:
	if not raw is Array:
		Log.warn(LOG_CATEGORY, "invalid recipes in save: none discovered")
		return
	for entry: Variant in raw as Array:
		var action_id := StringName(str(entry))
		if not _data.has_action(action_id) or not _data.action(action_id).discover:
			Log.warn(LOG_CATEGORY, "recipe '%s' in the save is unknown or needs no discovery: ignored" % action_id)
		elif not _recipes.has(action_id):
			_recipes.append(action_id)


# --- helpers ----------------------------------------------------------------------------------------------------------------

func _is_skill(skill_id: StringName) -> bool:
	for def: SkillDef in _data.skills():
		if def.id == skill_id:
			return true
	return false


# unknown_id for an unknown skill, not_a_discipline for a skill without Trainer.
func _check_discipline(skill_id: StringName) -> CommandResult:
	if not _is_skill(skill_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if not is_discipline(skill_id):
		return CommandResult.fail(Reasons.NOT_A_DISCIPLINE)
	return CommandResult.success()


# requirement_not_met (character level of the grade), then not_enough_gold.
func _check_grade_costs(target_grade: int) -> CommandResult:
	if _session.character.get_level() < _data.trainer_grade(target_grade).character_level:
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if _session.wallet.get_gold() < TrainerGradeDef.gold(_data, target_grade):
		return CommandResult.fail(Reasons.NOT_ENOUGH_GOLD)
	return CommandResult.success()


# The checks passed: the gold leaves (a free grade spends nothing), the grade is set, the signal follows.
func _buy_grade(skill_id: StringName, target_grade: int) -> void:
	var gold: int = TrainerGradeDef.gold(_data, target_grade)
	if gold > 0:
		_session.wallet.spend(gold)
	_grades[skill_id] = target_grade
	_events.discipline_changed.emit(skill_id, target_grade)
