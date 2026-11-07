class_name ItemRoller
extends RefCounted
## Rarity and affix rolls and the modifiers of an instance (F-83, F-85, F-86; docs/05_INTERFACES.md §5.18).
## Pure logic, no state. Order of draws on `rng`: rarity (one randf), affix count, then for each affix the choice,
## the tier and the value.

const LOG_CATEGORY: String = "items"
const SOURCE_MONSTER: StringName = &"monster"
const SOURCE_RIFT_STONE: StringName = &"rift_stone"
const TOOL_SLOT_PREFIX: String = "tool_"
const EPSILON: float = 0.000001


## F-83: x = magic %, y = rare %. `rarity_pct` is the total item_rarity_pct.
static func craft_chances(mastery_level: int, rarity_pct: float, data: GameData) -> Vector2:
	var k: float = 1.0 + rarity_pct / 100.0
	var magic: float = (
		float(data.balance_value("rarity.craft.magic_base_pct"))
		+ float(data.balance_value("rarity.craft.magic_per_mastery_level")) * mastery_level
	) * k
	var rare: float = (
		float(data.balance_value("rarity.craft.rare_base_pct"))
		+ float(data.balance_value("rarity.craft.rare_per_mastery_level")) * mastery_level
	) * k
	rare = minf(rare, 100.0)
	magic = minf(magic, 100.0 - rare)
	return Vector2(magic, rare)


## F-84: x = magic %, y = rare %. `source` is `&"monster"` (rarity.drop) or `&"rift_stone"` (rarity.rift_stone); an
## unknown source logs an error and gives zero. Same `k` and same clamping as F-83.
static func drop_chances(source: StringName, rarity_pct: float, data: GameData) -> Vector2:
	if source != SOURCE_MONSTER and source != SOURCE_RIFT_STONE:
		Log.error(LOG_CATEGORY, "unknown drop source '%s'" % source)
		return Vector2.ZERO
	var section: String = "drop" if source == SOURCE_MONSTER else "rift_stone"
	var k: float = 1.0 + rarity_pct / 100.0
	var rare: float = minf(float(data.balance_value("rarity.%s.rare_pct" % section)) * k, 100.0)
	var magic: float = minf(float(data.balance_value("rarity.%s.magic_pct" % section)) * k, 100.0 - rare)
	return Vector2(magic, rare)


static func roll_rarity(chances: Vector2, rng: RngService) -> StringName:
	var r: float = rng.randf() * 100.0
	if r < chances.y:
		return &"rare"
	if r < chances.y + chances.x:
		return &"magic"
	return &"common"


## F-85.
static func roll_affixes(
	base: ItemDef, rarity: StringName, ilvl: int, data: GameData, rng: RngService
) -> Array[AffixRoll]:
	return extend_affixes(base, rarity, ilvl, [], data, rng)


## F-85 keeping `existing` (M8-09): draws the affix count of `rarity` as the total, then rolls only the missing ones
## (none if `existing` already reaches it). Returns existing + new rolls; same draws as `roll_affixes` when empty.
static func extend_affixes(
	base: ItemDef, rarity: StringName, ilvl: int, existing: Array[AffixRoll], data: GameData, rng: RngService
) -> Array[AffixRoll]:
	var result: Array[AffixRoll] = existing.duplicate()
	if base.equip == null or rarity == &"common":
		return result
	var range_raw: Variant = data.balance_value("rarity.affix_count.%s" % rarity)
	if not range_raw is Array or (range_raw as Array).size() != 2:
		Log.error(LOG_CATEGORY, "no affix count for rarity '%s'" % rarity)
		return result
	var count: int = rng.randi_range(int(range_raw[0]), int(range_raw[1]))
	var used: Array[StringName] = []
	for roll: AffixRoll in existing:
		used.append(roll.affix_id)
	for _i: int in maxi(0, count - existing.size()):
		var candidates: Array[AffixDef] = []
		for def: AffixDef in data.affixes_for_slot(base.equip.slot):
			if not used.has(def.id) and _unlocked_count(def, ilvl) > 0:
				candidates.append(def)
		if candidates.is_empty():
			break
		var weights: Array[int] = []
		for def: AffixDef in candidates:
			weights.append(def.weight)
		var chosen: AffixDef = candidates[rng.pick_weighted(weights)]
		var tier_index: int = rng.randi_range(0, _unlocked_count(chosen, ilvl) - 1)
		var tier: AffixTier = chosen.tiers[tier_index]
		var steps: int = floori((tier.max - tier.min) / tier.step + EPSILON)
		var value: float = snappedf(tier.min + rng.randi_range(0, steps) * tier.step, EPSILON)
		used.append(chosen.id)
		result.append(AffixRoll.make(chosen.id, tier_index + 1, value))
	return result


## New instance (uid 0). The rarity is given (rolled by the caller with `roll_rarity`).
static func create(
	base: ItemDef, rarity: StringName, ilvl: int, data: GameData, rng: RngService
) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.base_id = base.id
	inst.rarity = rarity
	inst.ilvl = ilvl
	inst.affixes = roll_affixes(base, rarity, ilvl, data, rng)
	return inst


## Base modifiers x (1 + upgrade.mod_pct_per_level x N / 100), then one modifier per affix, then those of the stones in the active sockets (F-89).
static func instance_modifiers(inst: ItemInstance, data: GameData) -> Array[Modifier]:
	var result: Array[Modifier] = []
	if not data.has_item(inst.base_id):
		return result
	var base: ItemDef = data.item(inst.base_id)
	if base.equip == null:
		return result
	var factor: float = 1.0
	if inst.upgrade > 0:
		factor += float(data.balance_value("upgrade.mod_pct_per_level")) * inst.upgrade / 100.0
	for m: Modifier in base.equip.modifiers:
		result.append(m.scaled(factor))
	var slot: StringName = base.equip.slot
	var scope_kind: StringName = Modifier.SCOPE_GLOBAL
	var scope_id: StringName = &""
	if String(slot).begins_with(TOOL_SLOT_PREFIX):
		scope_kind = Modifier.SCOPE_SKILL
		scope_id = StringName(String(slot).trim_prefix(TOOL_SLOT_PREFIX))
	for roll: AffixRoll in inst.affixes:
		var def: AffixDef = data.affix(roll.affix_id)
		if def != null:
			result.append(Modifier.make(def.stat, roll.value, scope_kind, scope_id))
	for stone_id: StringName in Sockets.active(inst, data):
		if data.has_item(stone_id):
			result.append_array(data.item(stone_id).stone_modifiers)
	return result


static func _unlocked_count(def: AffixDef, ilvl: int) -> int:
	var n: int = 0
	for tier: AffixTier in def.tiers:
		if tier.min_ilvl <= ilvl:
			n += 1
	return n
