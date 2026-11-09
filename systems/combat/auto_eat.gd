class_name AutoEat
extends RefCounted
## Food during combat: the manual "eat" (F-29) and the field rations (F-30, docs/01_GDD.md §10.5).
## Stateless: the worn food is in `Equipment`, the stock in the bank.


## Eats one piece of the worn food. Returns the new hp, or -1 if there is no food to eat (none worn or none left).
## At full hp nothing is eaten and `hp` is returned unchanged. Emits `food_eaten(item, healed)`, `healed` being the
## hp actually restored.
static func eat_one(session: GameSession, hp: int, max_hp: int) -> int:
	var food_id: StringName = session.equipment.get_food()
	if food_id == &"" or not session.bank.has(food_id, 1):
		return -1
	if hp >= max_hp:
		return hp
	var heal_base: int = session.data.item(food_id).food_heal
	var heal: int = int(floor(heal_base * (1.0 + session.modifiers.total(&"food_healing_pct") / 100.0) + 1e-9))
	# F-111 `food_heal_pct` (inside a Fracture): the heal x (1 - v/100), floor, minimum 0.
	var cut: float = 1.0 - session.fractures.effect_total(FractureScaler.RISK_FOOD) / 100.0
	heal = maxi(0, int(floor(float(heal) * cut + 1e-9)))
	if not session.bank.remove(food_id, 1).ok:
		return -1
	var new_hp: int = mini(max_hp, hp + heal)
	session.events.food_eaten.emit(food_id, new_hp - hp)
	return new_hp


## F-30: after a hit taken, eats pieces while hp is at or below the threshold of the tier and under its target.
static func after_hit(session: GameSession, hp: int, max_hp: int) -> int:
	var tiers: Array = session.data.balance_value("combat.auto_eat_tiers")
	var tier: int = clampi(int(floor(session.modifiers.total(&"auto_eat_tier"))), 0, tiers.size() - 1)
	if tier == 0 or hp <= 0:
		return hp
	var threshold_pct: int = int((tiers[tier] as Dictionary)["threshold_pct"])
	var target_pct: int = int((tiers[tier] as Dictionary)["target_pct"])
	if hp > max_hp * threshold_pct / 100:
		return hp
	var target: int = (max_hp * target_pct + 99) / 100
	var current: int = hp
	while current < target:
		var next: int = eat_one(session, current, max_hp)
		if next <= current:
			break
		current = next
	return current
