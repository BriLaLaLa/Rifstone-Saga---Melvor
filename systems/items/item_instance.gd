class_name ItemInstance
extends RefCounted
## A unique piece (equipment or tool) with rarity, affixes and refinement (docs/05_INTERFACES.md §5.17).
## `uid` is 0 until the Armory assigns it.

const RARITIES: Array[StringName] = Rarities.ORDER  # M14: five rarities (common, magic, rare, masterwork, legendary)
const LOG_CATEGORY: String = "items"

var uid: int = 0
var base_id: StringName = &""
var rarity: StringName = &"common"
var ilvl: int = 1
var affixes: Array[AffixRoll] = []
var upgrade: int = 0
var sockets: Array[StringName] = []
var locked: bool = false


func duplicate_instance() -> ItemInstance:
	var copy := ItemInstance.new()
	copy.uid = uid
	copy.base_id = base_id
	copy.rarity = rarity
	copy.ilvl = ilvl
	for a: AffixRoll in affixes:
		copy.affixes.append(AffixRoll.make(a.affix_id, a.tier, a.value))
	copy.upgrade = upgrade
	copy.sockets = sockets.duplicate()
	copy.locked = locked
	return copy


func to_dict() -> Dictionary:
	var rolls: Array = []
	for a: AffixRoll in affixes:
		rolls.append({"affix": String(a.affix_id), "tier": a.tier, "value": a.value})
	var socket_ids: Array = []
	for s: StringName in sockets:
		socket_ids.append(String(s))
	return {
		"uid": uid, "base": String(base_id), "rarity": String(rarity), "ilvl": ilvl, "affixes": rolls,
		"upgrade": upgrade, "sockets": socket_ids, "locked": locked,
	}


## Null (after a warning) when the dictionary is not a valid instance: unknown or non-equippable base, bad rarity,
## an affix unknown, repeated or not allowed on the slot of the base, a tier out of range.
static func from_dict(d: Dictionary, data: GameData) -> ItemInstance:
	var inst := ItemInstance.new()
	if not (_is_num(d.get("uid")) and _is_num(d.get("ilvl")) and _is_num(d.get("upgrade"))):
		return _reject("missing numeric field in %s" % [d])
	inst.uid = int(d["uid"])
	inst.ilvl = int(d["ilvl"])
	inst.upgrade = int(d["upgrade"])
	var base_raw: Variant = d.get("base")
	if not base_raw is String or not data.has_item(StringName(base_raw)):
		return _reject("unknown base '%s'" % [base_raw])
	inst.base_id = StringName(base_raw)
	var base: ItemDef = data.item(inst.base_id)
	if base.equip == null:
		return _reject("base '%s' is not equipment" % inst.base_id)
	var rarity_raw: Variant = d.get("rarity")
	if not rarity_raw is String or not RARITIES.has(StringName(rarity_raw)):
		return _reject("invalid rarity '%s'" % [rarity_raw])
	inst.rarity = StringName(rarity_raw)
	var imposed: StringName = Rarities.of_base(base)
	if imposed != &"" and inst.rarity != imposed:
		return _reject("base '%s' is always %s, not %s" % [inst.base_id, imposed, inst.rarity])
	if inst.upgrade < 0 or inst.ilvl < 1:
		return _reject("invalid ilvl/upgrade in %s" % [d])
	var affixes_raw: Variant = d.get("affixes")
	if not affixes_raw is Array:
		return _reject("missing affixes")
	for entry: Variant in affixes_raw:
		var roll: AffixRoll = _parse_affix(entry, base.equip.slot, inst, data)
		if roll == null:
			return null
		inst.affixes.append(roll)
	var sockets_raw: Variant = d.get("sockets", [])
	if not sockets_raw is Array:
		return _reject("invalid sockets")
	for s: Variant in sockets_raw:
		inst.sockets.append(StringName(str(s)))
	var locked_raw: Variant = d.get("locked", false)
	if not locked_raw is bool:
		return _reject("invalid locked")
	inst.locked = locked_raw
	return inst


static func _parse_affix(entry: Variant, slot: StringName, inst: ItemInstance, data: GameData) -> AffixRoll:
	if not entry is Dictionary:
		_reject("affix entry is not an object")
		return null
	var e: Dictionary = entry
	if not (e.get("affix") is String and _is_num(e.get("tier")) and _is_num(e.get("value"))):
		_reject("malformed affix %s" % [e])
		return null
	var id := StringName(e["affix"])
	var def: AffixDef = null
	for candidate: AffixDef in data.affixes_for_slot(slot):
		if candidate.id == id:
			def = candidate
	if def == null:
		_reject("affix '%s' not allowed on slot '%s'" % [id, slot])
		return null
	for existing: AffixRoll in inst.affixes:
		if existing.affix_id == id:
			_reject("affix '%s' repeated" % id)
			return null
	var tier: int = int(e["tier"])
	if tier < 1 or tier > def.tiers.size():
		_reject("tier %d out of range for '%s'" % [tier, id])
		return null
	return AffixRoll.make(id, tier, float(e["value"]))


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


static func _reject(message: String) -> ItemInstance:
	Log.warn(LOG_CATEGORY, "invalid item instance: %s" % message)
	return null
