class_name MapCardRoller
extends RefCounted
## Rolls of a Fracture Card (docs/02_FORMULAS.md F-109). Pure logic, no state. Order of draws on `rng`: rarity (one
## randf, `roll_rarity`), the number of modifiers (always one `randi_range`), then for each modifier the choice
## (`pick_weighted`) and the intensity step (`randi_range`). F-123: the total risk points of a Card stay within `risk_cap`
## (the step is reduced; a candidate that does not fit at step 0 is dropped and the choice is repeated).

const LOG_CATEGORY: String = "cards"
const EPSILON: float = 1e-9


## F-109: `p_magic`/`p_rare` = `fracture.card_rarity` x `k`, `k = 1 + rarity_pct / 100`; rare if `r < p_rare`, magic if
## `r < p_rare + p_magic`, else common. Clamped like F-84 (rare <= 100, magic <= 100 - rare).
static func roll_rarity(rarity_pct: float, data: GameData, rng: RngService) -> StringName:
	var chances: Vector2 = rarity_chances(rarity_pct, data)
	var r: float = rng.randf() * 100.0
	if r < chances.y:
		return &"rare"
	if r < chances.y + chances.x:
		return &"magic"
	return &"common"


## x = magic %, y = rare % (F-109), with `rarity_pct` the `item_rarity_pct` total.
static func rarity_chances(rarity_pct: float, data: GameData) -> Vector2:
	var k: float = 1.0 + rarity_pct / 100.0
	var rare: float = minf(float(data.balance_value("fracture.card_rarity.rare_pct")) * k, 100.0)
	var magic: float = minf(float(data.balance_value("fracture.card_rarity.magic_pct")) * k, 100.0 - rare)
	return Vector2(magic, rare)


## A new Card of `grade` (uid 0) with the modifiers of F-109. Null (after an error) when the grade has no base.
static func create(grade: int, rarity: StringName, data: GameData, rng: RngService) -> MapCard:
	if grade < 1 or not data.has_item(StringName("fracture_card_%d" % grade)):
		Log.error(LOG_CATEGORY, "no Card base for grade %d" % grade)
		return null
	var card := MapCard.new()
	card.base_id = data.map_base(grade).id
	card.grade = grade
	card.rarity = rarity
	card.mods = extend_mods(card, rarity, data, rng)
	return card


## The modifiers of `card` plus new ones up to the number drawn for `rarity` (the old ones are kept; the draw is the
## total, so a Card never loses a modifier). A new modifier has `min_grade` <= the grade of the card, an id and a risk
## type that the card does not have yet; without candidates it stops. The card is not changed.
static func extend_mods(card: MapCard, rarity: StringName, data: GameData, rng: RngService) -> Array[MapModRoll]:
	var result: Array[MapModRoll] = []
	for roll: MapModRoll in card.mods:
		result.append(MapModRoll.make(roll.mod_id, roll.step))
	var range_raw: Array = data.balance_value("fracture.mod_count.%s" % rarity) as Array
	var target: int = rng.randi_range(int(range_raw[0]), int(range_raw[1]))
	var steps: int = int(data.balance_value("fracture.intensity_steps"))
	var cap: float = risk_cap(card.grade, data)
	var discarded: Dictionary[StringName, bool] = {}  # F-123: candidates that do not fit even at step 0
	while result.size() < target:
		var candidates: Array[MapModDef] = _candidates(result, card.grade, data)
		for id: StringName in discarded:
			candidates = candidates.filter(func(def: MapModDef) -> bool: return def.id != id)
		if candidates.is_empty():
			break
		var weights: Array[int] = []
		for def: MapModDef in candidates:
			weights.append(def.weight)
		var picked: MapModDef = candidates[rng.pick_weighted(weights)]
		var step: int = fitting_step(picked, rng.randi_range(0, steps), cap - total_risk_points(result, data), data)
		if step < 0:
			discarded[picked.id] = true
			continue
		result.append(MapModRoll.make(picked.id, step))
	return result


## F-123: risk points of a modifier at `step`: `risk_value x fracture.risk_unit[risk type]` (unit 1 by default).
static func risk_points(mod: MapModDef, step: int, data: GameData) -> float:
	var steps: int = int(data.balance_value("fracture.intensity_steps"))
	var units: Dictionary = data.balance_value("fracture.risk_unit") as Dictionary
	return mod.risk.value_at(step, steps) * float(units.get(String(mod.risk.type), 1.0))


## F-123: `fracture.risk_cap.base + fracture.risk_cap.per_grade x (grade - 1)`.
static func risk_cap(grade: int, data: GameData) -> float:
	return float(data.balance_value("fracture.risk_cap.base")) \
			+ float(data.balance_value("fracture.risk_cap.per_grade")) * float(grade - 1)


## F-123: the sum of the risk points of `mods`.
static func total_risk_points(mods: Array[MapModRoll], data: GameData) -> float:
	var total: float = 0.0
	for roll: MapModRoll in mods:
		var def: MapModDef = data.map_mod(roll.mod_id)
		if def != null:
			total += risk_points(def, roll.step, data)
	return total


## F-123: the highest step `<= step` of `mod` whose points fit in `room`; -1 when not even step 0 fits.
static func fitting_step(mod: MapModDef, step: int, room: float, data: GameData) -> int:
	for s: int in range(step, -1, -1):
		if risk_points(mod, s, data) <= room + EPSILON:
			return s
	return -1


## F-109: for every modifier of the card the risk and the reward at its step: `[{"mod": id, "risk_type": StringName,
## "risk": float, "reward_type": StringName, "reward": float}]`.
static func effects(card: MapCard, data: GameData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var steps: int = int(data.balance_value("fracture.intensity_steps"))
	for roll: MapModRoll in card.mods:
		var def: MapModDef = data.map_mod(roll.mod_id)
		if def == null:
			continue
		result.append({"mod": def.id, "risk_type": def.risk.type, "risk": def.risk.value_at(roll.step, steps),
				"reward_type": def.reward.type, "reward": def.reward.value_at(roll.step, steps)})
	return result


static func _candidates(have: Array[MapModRoll], grade: int, data: GameData) -> Array[MapModDef]:
	var used_ids: Dictionary[StringName, bool] = {}
	var used_risks: Dictionary[StringName, bool] = {}
	for roll: MapModRoll in have:
		used_ids[roll.mod_id] = true
		var def: MapModDef = data.map_mod(roll.mod_id)
		if def != null:
			used_risks[def.risk.type] = true
	var result: Array[MapModDef] = []
	for def: MapModDef in data.map_mods():
		if def.min_grade <= grade and not used_ids.has(def.id) and not used_risks.has(def.risk.type):
			result.append(def)
	return result
