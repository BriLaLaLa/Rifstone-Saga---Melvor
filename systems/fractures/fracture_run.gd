class_name FractureRun
extends RefCounted
## The state of a Fracture in progress (docs/05_INTERFACES.md §5.23, F-50): plain data, no signals. `group` is the index of
## the last pack drawn (0 = none yet), `groups_cleared` the packs beaten. The combat engine reads and advances it.

const LOG_CATEGORY: String = "fracture"

var card: MapCard = null
var grade: int = 0
var groups_total: int = 0
var group: int = 0
var groups_cleared: int = 0
var boss_started: bool = false
var return_area: StringName = &""
var bag: FractureBag = FractureBag.new()
var effects: Array[Dictionary] = []


## A new run for `card` (the Card has just left the CardStore); the first group is drawn by the engine.
static func create(card_taken: MapCard, return_to: StringName, data: GameData) -> FractureRun:
	var run := FractureRun.new()
	run.card = card_taken
	run.grade = card_taken.grade
	run.groups_total = int(data.balance_value("fracture.groups"))
	run.return_area = return_to
	run.effects = MapCardRoller.effects(card_taken, data)
	return run


## F-50: the next pack, drawn as F-77 (`pick_weighted`) among the packs of all the areas of the grade, scaled with
## F-110 and F-111 and widened by `pack_bonus`. `group += 1`.
func next_pack(rng: RngService, data: GameData) -> Array[MonsterDef]:
	var packs: Array[PackDef] = []
	var weights: Array[int] = []
	for area_id: StringName in data.fracture_grade(grade).areas:
		for pack: PackDef in data.area(area_id).packs:
			packs.append(pack)
			weights.append(pack.weight)
	var result: Array[MonsterDef] = []
	var picked: int = rng.pick_weighted(weights)
	group += 1
	if picked < 0:
		return result
	var ids: Array[StringName] = packs[picked].monster_ids
	var size: int = FractureScaler.pack_size(ids.size(), effects, data)
	for i: int in size:
		result.append(FractureScaler.scale_monster(data.monster(ids[i % ids.size()]), grade, effects, data))
	return result


func boss_def(data: GameData) -> BossDef:
	return data.boss_for_grade(grade)


func to_save() -> Dictionary:
	return {"card": card.to_dict(), "group": group, "groups_cleared": groups_cleared, "boss_started": boss_started,
		"return_area": String(return_area), "bag": bag.to_save()}


## Null (after a warning) if the Card is not valid or a counter is out of range.
static func from_save(d: Dictionary, data: GameData) -> FractureRun:
	var card_raw: Variant = d.get("card")
	var card_loaded: MapCard = MapCard.from_dict(card_raw, data) if card_raw is Dictionary else null
	if card_loaded == null:
		Log.warn(LOG_CATEGORY, "saved Fracture without a valid Card: dropped")
		return null
	var run: FractureRun = create(card_loaded, StringName(str(d.get("return_area", ""))), data)
	if not data.has_area(run.return_area):
		run.return_area = &""
	var group_raw: Variant = d.get("group")
	var cleared_raw: Variant = d.get("groups_cleared")
	if not _is_count(group_raw) or not _is_count(cleared_raw) or int(group_raw) > run.groups_total \
			or int(cleared_raw) > int(group_raw):
		Log.warn(LOG_CATEGORY, "saved Fracture with bad group counters: dropped")
		return null
	run.group = int(group_raw)
	run.groups_cleared = int(cleared_raw)
	run.boss_started = d.get("boss_started") == true
	if d.get("bag") is Dictionary:
		run.bag.from_save(d["bag"], data)
	return run


static func _is_count(v: Variant) -> bool:
	return (v is int or (v is float and v == floorf(v))) and int(v) >= 0
