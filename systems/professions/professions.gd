class_name Professions
extends RefCounted
## Profession levels as colors (docs/01_GDD_M26.md §38.1-§38.3, docs/05_INTERFACES_M26.md §5.35).
##
## The level of a profession is the level of its discipline. A completed cycle of a colored recipe gives the expected skill-up
## (F-168): xp x chance, the fraction kept per skill in `frac` (slot state). No random numbers. Also reads the model for the
## origin of a recipe and the unlocks at level thresholds (F-169).

const SAVE_KEY: StringName = &"professions"
const SAVE_FRAC_KEY: String = "frac"
const LOG_CATEGORY: String = "professions"
const KIND_TRAINER: StringName = &"trainer"
const KIND_SCHEME: StringName = &"scheme"
const KIND_REAGENT: StringName = &"reagent"
const SOURCE_DROP: StringName = &"drop"
const _KIND_RANK: Dictionary = {&"trainer": 0, &"scheme": 1, &"reagent": 2}

var _session: GameSession
var _data: GameData
var _frac: Dictionary[StringName, int] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "Professions needs a session")
	_session = session
	_data = session.data
	session.events.skill_reset.connect(_on_skill_reset)


## {"id": color, "chance_ppm": int} at the current level; {} for an unknown or non-artisan action.
func recipe_color(action_id: StringName) -> Dictionary:
	if not _data.has_action(action_id):
		return {}
	var action: ActionDef = _data.action(action_id)
	if not action.is_artisan():
		return {}
	var level: int = _session.skills.get_level(action.skill_id)
	return {"id": ProfessionMath.color_id(action.colors, level), "chance_ppm": ProfessionMath.chance_ppm(action.colors, level)}


## F-168: the xp base of one completed cycle; updates the fraction of the skill. Called only by ArtisanResolver.
func craft_xp_base(action: ActionDef) -> int:
	var level: int = _session.skills.get_level(action.skill_id)
	var chance: int = ProfessionMath.chance_ppm(action.colors, level)
	var split: Vector2i = ProfessionMath.split_xp(action.xp, chance, frac(action.skill_id))
	_set_frac(action.skill_id, split.y)
	return split.x


func frac(skill_id: StringName) -> int:
	return _frac.get(skill_id, 0)


## F-169: &"trainer", &"scheme" or &"drop"; &"" when unknown, not artisan or single.
func recipe_source(action_id: StringName) -> StringName:
	if not _data.has_action(action_id):
		return &""
	var action: ActionDef = _data.action(action_id)
	if not action.is_artisan() or action.single:
		return &""
	if not action.discover:
		return KIND_TRAINER
	return KIND_SCHEME if scheme_entry(action_id) != &"" else SOURCE_DROP


## The shop entry that sells the Recipe of the action; &"" if none.
func scheme_entry(action_id: StringName) -> StringName:
	var item: ItemDef = _data.recipe_item_for(action_id)
	if item == null:
		return &""
	var entry: ShopEntryDef = _data.shop_entry_selling(item.id)
	return entry.id if entry != null else &""


func vendor(skill_id: StringName) -> StringName:
	var trainer: TrainerDef = _data.trainer(skill_id)
	return trainer.vendor if trainer != null else &""


## F-169: [{"level", "kind", "id"}] by level, then trainer < scheme < reagent, then file order.
func unlocks(skill_id: StringName) -> Array[Dictionary]:
	var rows: Array = []  # [level, rank, index, row]
	var index: int = 0
	for action: ActionDef in _data.actions_for_skill(skill_id):
		if recipe_source(action.id) == KIND_TRAINER:
			rows.append([action.level, 0, index, {"level": action.level, "kind": KIND_TRAINER, "id": action.id}])
			index += 1
	var vendor_id: StringName = vendor(skill_id)
	if vendor_id != &"":
		for entry: ShopEntryDef in _data.shop_entries_of_vendor(vendor_id):
			var kind: StringName = _entry_kind(entry)
			if kind != &"" and entry.req_skills.has(skill_id):
				var level: int = entry.req_skills[skill_id]
				rows.append([level, _KIND_RANK[kind], index, {"level": level, "kind": kind, "id": entry.id}])
				index += 1
	rows.sort_custom(_row_before)
	var result: Array[Dictionary] = []
	for row: Array in rows:
		result.append(row[3])
	return result


## The first `count` unlocks above the current level of the skill.
func next_unlocks(skill_id: StringName, count: int) -> Array[Dictionary]:
	var level: int = _session.skills.get_level(skill_id)
	var result: Array[Dictionary] = []
	for row: Dictionary in unlocks(skill_id):
		if result.size() >= count:
			break
		if int(row["level"]) > level:
			result.append(row)
	return result


func new_game() -> void:
	_frac.clear()


## {"frac": {skill: int}} only for fractions above 0.
func to_save() -> Dictionary:
	var out: Dictionary = {}
	for skill: SkillDef in _data.skills():
		if _frac.get(skill.id, 0) > 0:
			out[String(skill.id)] = _frac[skill.id]
	return {SAVE_FRAC_KEY: out}


## Tolerant: unknown skills, skills without colored recipes and invalid values are dropped (Log.warn).
func from_save(d: Dictionary) -> void:
	_frac.clear()
	var raw: Variant = d.get(SAVE_FRAC_KEY, {})
	if not raw is Dictionary:
		Log.warn(LOG_CATEGORY, "'frac' is not an object: ignored")
		return
	for key: Variant in (raw as Dictionary):
		var skill_id := StringName(str(key))
		if not _has_colored_recipes(skill_id):
			Log.warn(LOG_CATEGORY, "frac of '%s' dropped: unknown skill or no colored recipes" % skill_id)
			continue
		var value: Variant = (raw as Dictionary)[key]
		var number: int = 0
		if value is int or (value is float and is_equal_approx(float(value), floorf(float(value)))):
			number = int(value)
		if number < 0 or number >= ProfessionMath.PPM:
			Log.warn(LOG_CATEGORY, "frac of '%s' is out of range: 0" % skill_id)
			number = 0
		_set_frac(skill_id, number)


func _set_frac(skill_id: StringName, value: int) -> void:
	if value > 0:
		_frac[skill_id] = value
	else:
		_frac.erase(skill_id)


func _on_skill_reset(skill_id: StringName) -> void:
	_frac.erase(skill_id)


func _has_colored_recipes(skill_id: StringName) -> bool:
	if _data.skills().filter(func(s: SkillDef) -> bool: return s.id == skill_id).is_empty():
		return false
	for action: ActionDef in _data.actions_for_skill(skill_id):
		if action.has_colors():
			return true
	return false


func _entry_kind(entry: ShopEntryDef) -> StringName:
	if entry.effect_item == null or not _data.has_item(entry.effect_item.item_id):
		return &""
	var category: StringName = _data.item(entry.effect_item.item_id).category
	if category == &"recipe":
		return KIND_SCHEME
	return KIND_REAGENT if category == &"reagent" else &""


static func _row_before(a: Array, b: Array) -> bool:
	for i: int in 3:
		if a[i] != b[i]:
			return a[i] < b[i]
	return false
