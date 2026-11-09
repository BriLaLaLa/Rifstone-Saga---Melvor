class_name ItemRoller
extends RefCounted
## Rarity and affix rolls and the modifiers of an instance (F-84, F-85, F-86, F-91, F-92; docs/05_INTERFACES.md §5.18).
## Pure logic, no state. Order of draws on `rng`: rarity (one randf), affix count, then for each affix the choice,
## the tier and the value.

const LOG_CATEGORY: String = "items"
const SOURCE_MONSTER: StringName = &"monster"
const SOURCE_RIFT_STONE: StringName = &"rift_stone"
const TOOL_SLOT_PREFIX: String = "tool_"
const EPSILON: float = 0.000001


## F-91 (M14): chance in percent (0..100) that a blueprint piece (always a Masterwork) has the maximum number of
## affixes (2) instead of the minimum (1): `min(100, (rare_base_pct + rare_per_forging_level x L) x k)`.
static func blueprint_two_affix_chance(forging_level: int, rarity_pct: float, data: GameData) -> float:
	var k: float = 1.0 + rarity_pct / 100.0
	var base: float = float(data.balance_value("blueprint.rare_base_pct"))
	var per_level: float = float(data.balance_value("blueprint.rare_per_forging_level"))
	return minf((base + per_level * forging_level) * k, 100.0)


## Same value as `blueprint_two_affix_chance` (the name of M10; the UI of the Forging page still calls it).
static func blueprint_rare_chance(forging_level: int, rarity_pct: float, data: GameData) -> float:
	return blueprint_two_affix_chance(forging_level, rarity_pct, data)


## F-84: x = magic %, y = rare %. `source` is `&"monster"` (rarity.drop) or `&"rift_stone"` (rarity.rift_stone); an
## unknown source logs an error and gives zero. Same `k` and same clamping as F-91.
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
	if base.equip == null or rarity == Rarities.COMMON or rarity == Rarities.LEGENDARY:
		return result
	var span: Vector2i = Rarities.affix_range(rarity, data)
	if span == Vector2i.ZERO:
		Log.error(LOG_CATEGORY, "no affix count for rarity '%s'" % rarity)
		return result
	var count: int = rng.randi_range(span.x, span.y)
	_roll_more(base, ilvl, result, count - existing.size(), data, rng)
	return result


# F-85: appends up to `missing` new rolls to `result` (no repeated affix; stops when no candidate is left).
static func _roll_more(
	base: ItemDef, ilvl: int, result: Array[AffixRoll], missing: int, data: GameData, rng: RngService
) -> void:
	var used: Array[StringName] = []
	for roll: AffixRoll in result:
		used.append(roll.affix_id)
	for _i: int in maxi(0, missing):
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
		used.append(chosen.id)
		result.append(AffixRoll.make(chosen.id, tier_index + 1, _roll_value(chosen.tiers[tier_index], rng)))


static func _roll_value(tier: AffixTier, rng: RngService) -> float:
	var steps: int = floori((tier.max - tier.min) / tier.step + EPSILON)
	return snappedf(tier.min + rng.randi_range(0, steps) * tier.step, EPSILON)


## F-92 (M10): the affixes the player may choose for `base` at `ilvl` (allowed by the slot, with an unlocked tier).
static func chosen_affix_candidates(base: ItemDef, ilvl: int, data: GameData) -> Array[AffixDef]:
	var result: Array[AffixDef] = []
	if base == null or base.equip == null:
		return result
	for def: AffixDef in data.affixes_for_slot(base.equip.slot):
		if _unlocked_count(def, ilvl) > 0:
			result.append(def)
	return result


## F-91/F-92 (M14): new instance (uid 0) of the base of blueprint `bp`: always a Masterwork (F-119), `ilvl` = level of the
## grade of the piece (`equipment.grade_levels`). `chosen_affix` &"" = no choice. Draws on `rng`: the number of affixes (one
## randf against `blueprint_two_affix_chance`: 2 affixes or 1), the value of the chosen affix, then the others.
## The caller checked the choice (Forging level, allowed by the slot); an invalid one is logged and ignored.
static func create_from_blueprint(
	bp: ItemDef, forging_level: int, rarity_pct: float, chosen_affix: StringName, data: GameData, rng: RngService
) -> ItemInstance:
	var base: ItemDef = data.item(bp.blueprint.base_id)
	var ilvl: int = data.grade_level(base.equip.grade)
	var inst := ItemInstance.new()
	inst.base_id = base.id
	inst.ilvl = ilvl
	inst.rarity = Rarities.MASTERWORK
	var span: Vector2i = Rarities.affix_range(Rarities.MASTERWORK, data)
	var count: int = span.y if rng.randf() * 100.0 < blueprint_two_affix_chance(forging_level, rarity_pct, data) else span.x
	var picked: AffixDef = null
	for def: AffixDef in chosen_affix_candidates(base, ilvl, data):
		if def.id == chosen_affix:
			picked = def
	if chosen_affix != &"" and picked == null:
		Log.error(LOG_CATEGORY, "chosen affix '%s' is not allowed on '%s'" % [chosen_affix, base.id])
	if picked != null:
		var cap: int = int(data.balance_value("blueprint.chosen_affix_tier"))
		var tier_number: int = mini(cap, _unlocked_count(picked, ilvl))
		inst.affixes.append(AffixRoll.make(picked.id, tier_number, _roll_value(picked.tiers[tier_number - 1], rng)))
	_roll_more(base, ilvl, inst.affixes, count - inst.affixes.size(), data, rng)
	return inst


## New instance (uid 0). The rarity is given (rolled by the caller with `roll_rarity`); a Masterwork or legendary base
## imposes its own and `rarity` is ignored (04 §21).
static func create(
	base: ItemDef, rarity: StringName, ilvl: int, data: GameData, rng: RngService
) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.base_id = base.id
	var imposed: StringName = Rarities.of_base(base)
	inst.rarity = imposed if imposed != &"" else rarity
	rarity = inst.rarity
	inst.ilvl = ilvl
	inst.affixes = roll_affixes(base, rarity, ilvl, data, rng)
	return inst


## A unique tool: F-94 (ToolUpgrade.modifiers). Otherwise base modifiers x (1 + upgrade.mod_pct_per_level x N / 100), then one modifier per affix, then those of the stones in the active sockets (F-89).
static func instance_modifiers(inst: ItemInstance, data: GameData) -> Array[Modifier]:
	var result: Array[Modifier] = []
	if not data.has_item(inst.base_id):
		return result
	var base: ItemDef = data.item(inst.base_id)
	if base.equip == null:
		return result
	if base.equip.unique:
		return ToolUpgrade.modifiers(base, inst.upgrade, data)  # F-94 instead of F-86; no affixes, no sockets
	if base.equip.is_legendary_tool():  # F-120: fixed modifiers, no multiplier, no refinement
		return _tool_modifiers(base, inst, data)
	var factor: float = Rarities.base_mult(inst.rarity, data)  # F-119/F-120, before the refinement (F-86)
	if inst.upgrade > 0:
		factor *= 1.0 + float(data.balance_value("upgrade.mod_pct_per_level")) * inst.upgrade / 100.0
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


# A legendary tool: its modifiers as authored (the scope is in the data) and the stones of its sockets.
static func _tool_modifiers(base: ItemDef, inst: ItemInstance, data: GameData) -> Array[Modifier]:
	var result: Array[Modifier] = base.equip.modifiers.duplicate()
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
