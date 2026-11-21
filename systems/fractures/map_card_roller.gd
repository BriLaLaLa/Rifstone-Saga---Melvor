class_name MapCardRoller
extends RefCounted
## Rolls of a Fracture Card (docs/02_FORMULAS.md F-109). Pure logic, no state. Order of draws on `rng`: rarity (one
## randf, `roll_rarity`), the number of modifiers (one `randi_range`; none for `reroll_mods`, which keeps the number of
## the Card), then for each modifier the choice (`pick_weighted`) and the intensity step (`randi_range`). F-123: the total risk points of a Card stay within `risk_cap`
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
	return _fill(result, target, card.grade, data, rng)


## M29-01, `reroll` Crystal: brand-new modifiers for `card` (the old ones are replaced, never dropped): the number is the
## one the Card has now (`card.mods.size()`), no draw for it. Same constraints as `extend_mods` (F-109 candidates, one
## risk type per Card, F-123 cap): only when no candidate fits any more the number can drop. Draws on `rng`: per modifier
## the choice and the step. The card is not changed.
static func reroll_mods(card: MapCard, data: GameData, rng: RngService) -> Array[MapModRoll]:
	var result: Array[MapModRoll] = []
	return _fill(result, card.mods.size(), card.grade, data, rng)


# Appends modifiers to `result` until it has `target` (or no candidate is left): choice, then step, for each. F-123 with a
# reserve (M29-01): the step of a modifier leaves room for the cheapest step-0 modifiers (one per other risk type) that the
# remaining ones still need, so a high `target` is not lost to the first modifiers taking the whole cap. When nothing fits
# with the reserve, the wanted number drops by one and the discarded candidates are tried again; no extra draws.
static func _fill(result: Array[MapModRoll], target: int, grade: int, data: GameData, rng: RngService) -> Array[MapModRoll]:
	var steps: int = int(data.balance_value("fracture.intensity_steps"))
	var cap: float = risk_cap(grade, data)
	var want: int = target
	_make_room(result, want, grade, cap, data)
	var discarded: Dictionary[StringName, bool] = {}  # F-123: candidates that do not fit (with the reserve) even at step 0
	while result.size() < want:
		var candidates: Array[MapModDef] = _candidates(result, grade, data)
		for id: StringName in discarded:
			candidates = candidates.filter(func(def: MapModDef) -> bool: return def.id != id)
		if candidates.is_empty():
			if want - result.size() > 1 and not discarded.is_empty():
				want -= 1
				discarded.clear()
				continue
			break
		var weights: Array[int] = []
		for def: MapModDef in candidates:
			weights.append(def.weight)
		var picked: MapModDef = candidates[rng.pick_weighted(weights)]
		var room: float = cap - total_risk_points(result, data) - _reserve(candidates, picked, want - result.size() - 1, data)
		var step: int = fitting_step(picked, rng.randi_range(0, steps), room, data)
		if step < 0:
			discarded[picked.id] = true
			continue
		result.append(MapModRoll.make(picked.id, step))
	return result


# M29-01 (`to_rare`): the modifiers already on the Card are kept, but when they leave no room for the cheapest ones the Card
# still needs, the steps of the dearest are lowered one at a time (never below 0, never removed; no draws).
static func _make_room(result: Array[MapModRoll], want: int, grade: int, cap: float, data: GameData) -> void:
	if result.is_empty() or result.size() >= want:
		return
	var candidates: Array[MapModDef] = _candidates(result, grade, data)
	var floor_points: float = 0.0  # the Card with every step at 0
	for roll: MapModRoll in result:
		floor_points += risk_points(data.map_mod(roll.mod_id), 0, data)
	var more: int = want - result.size()
	while more > 0 and floor_points + _reserve(candidates, null, more, data) > cap + EPSILON:
		more -= 1  # what the cap can never hold is not made room for
	var needed: float = _reserve(candidates, null, more, data)
	while total_risk_points(result, data) + needed > cap + EPSILON:
		var dearest: MapModRoll = null
		var most: float = -1.0
		for roll: MapModRoll in result:
			var points: float = risk_points(data.map_mod(roll.mod_id), roll.step, data)
			if roll.step > 0 and points > most:
				dearest = roll
				most = points
		if dearest == null:
			return
		dearest.step -= 1


# M29-01: the points to keep free for `remaining` more modifiers: the cheapest step-0 candidates, one per risk type other than
# the type of `picked` (none when null) (fewer if there are not enough types).
static func _reserve(candidates: Array[MapModDef], picked: MapModDef, remaining: int, data: GameData) -> float:
	if remaining <= 0:
		return 0.0
	var cheapest: Dictionary[StringName, float] = {}
	for def: MapModDef in candidates:
		if picked != null and def.risk.type == picked.risk.type:
			continue
		var points: float = risk_points(def, 0, data)
		if not cheapest.has(def.risk.type) or points < cheapest[def.risk.type]:
			cheapest[def.risk.type] = points
	var costs: Array[float] = []
	costs.assign(cheapest.values())
	costs.sort()
	var sum: float = 0.0
	for i: int in mini(remaining, costs.size()):
		sum += costs[i]
	return sum


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
