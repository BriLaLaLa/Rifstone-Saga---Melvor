class_name MapCard
extends RefCounted
## A Fracture Card (docs/05_INTERFACES.md §5.23): an instance like a piece, with a grade (that of its base
## `fracture_card_<grade>`), a rarity, its rolled modifiers and a lock. `uid` is 0 until the CardStore (or a Fracture
## bag) assigns one.

const RARITIES: Array[StringName] = [&"common", &"magic", &"rare"]
const LOG_CATEGORY: String = "cards"

var uid: int = 0
var base_id: StringName = &""
var grade: int = 0
var rarity: StringName = &"common"
var mods: Array[MapModRoll] = []
var locked: bool = false


func duplicate_card() -> MapCard:
	var copy := MapCard.new()
	copy.uid = uid
	copy.base_id = base_id
	copy.grade = grade
	copy.rarity = rarity
	for roll: MapModRoll in mods:
		copy.mods.append(MapModRoll.make(roll.mod_id, roll.step))
	copy.locked = locked
	return copy


func to_dict() -> Dictionary:
	var rolls: Array = []
	for roll: MapModRoll in mods:
		rolls.append({"mod": String(roll.mod_id), "step": roll.step})
	return {"uid": uid, "base": String(base_id), "rarity": String(rarity), "mods": rolls, "locked": locked}


## Null (after a warning) when the dictionary is not a valid Card: a base that is not a Card base, a bad rarity, a
## modifier that is unknown or repeated, a `step` outside `0..fracture.intensity_steps`. The grade is that of the base.
static func from_dict(d: Dictionary, data: GameData) -> MapCard:
	var card := MapCard.new()
	if not (_is_whole(d.get("uid")) and int(d["uid"]) >= 0):
		return _reject("bad uid in %s" % [d])
	card.uid = int(d["uid"])
	var base_raw: Variant = d.get("base")
	if not base_raw is String or not data.has_item(StringName(base_raw)) or not data.item(StringName(base_raw)).is_map():
		return _reject("unknown Card base '%s'" % [base_raw])
	card.base_id = StringName(base_raw)
	card.grade = data.item(card.base_id).map_grade
	var rarity_raw: Variant = d.get("rarity")
	if not rarity_raw is String or not RARITIES.has(StringName(rarity_raw)):
		return _reject("invalid rarity '%s'" % [rarity_raw])
	card.rarity = StringName(rarity_raw)
	var locked_raw: Variant = d.get("locked", false)
	if not locked_raw is bool:
		return _reject("invalid locked")
	card.locked = locked_raw
	var mods_raw: Variant = d.get("mods")
	if not mods_raw is Array:
		return _reject("missing mods")
	var steps: int = int(data.balance_value("fracture.intensity_steps"))
	for entry: Variant in mods_raw:
		var roll: MapModRoll = _parse_mod(entry, steps, card, data)
		if roll == null:
			return null
		card.mods.append(roll)
	return card


static func _parse_mod(entry: Variant, steps: int, card: MapCard, data: GameData) -> MapModRoll:
	if not entry is Dictionary:
		return _reject("modifier entry is not an object")
	var mod_raw: Variant = (entry as Dictionary).get("mod")
	var step_raw: Variant = (entry as Dictionary).get("step")
	if not mod_raw is String or data.map_mod(StringName(mod_raw)) == null:
		return _reject("unknown modifier '%s'" % [mod_raw])
	if not _is_whole(step_raw) or int(step_raw) < 0 or int(step_raw) > steps:
		return _reject("step '%s' out of 0..%d" % [step_raw, steps])
	for existing: MapModRoll in card.mods:
		if existing.mod_id == StringName(mod_raw):
			return _reject("repeated modifier '%s'" % [mod_raw])
	return MapModRoll.make(StringName(mod_raw), int(step_raw))


static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value as float) and (value as float) == floorf(value as float))


static func _reject(message: String) -> Variant:
	Log.warn(LOG_CATEGORY, "Card rejected: %s" % message)
	return null
