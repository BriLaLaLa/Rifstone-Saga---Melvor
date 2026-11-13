extends GutTest
## Tuning rule of the runes (decision post M12): for every rune family the hours of farming the thematic material are
## 5-10 h for grade III and 50-100 h for grade V, playing in the area where the material drops (F-106: a grade g rune is
## rune.upgrade_ratio^(g-1) grade I runes; each grade I rune takes the engrave input quantity of the material).
## Hours are estimated from the data, not from the simulator: kills per hour of each area x share of the monster among
## the kills of the area's packs x drop chance x mean quantity. The kills per hour are the measured defaults of
## `tools/sim_combat.gd deposit=1 scope=all` (M12-07, M17-04: sword and shield, level and gear of the area, collect every 10 min).

const KILLS_PER_HOUR: Dictionary = {&"redrock_plains": 223.0, &"whisper_wood": 222.0, &"dry_uplands": 207.0, &"cracked_mines": 249.0,
		&"ash_marsh": 239.0, &"weeping_gorge": 232.0, &"rift_threshold": 171.0, &"black_glass_desert": 152.0, &"sunken_citadel": 231.0,
		&"rift_heart": 140.0}  # M17-04: the ten narrow areas
const GRADE_III_H: Vector2 = Vector2(5.0, 10.0)
const GRADE_V_H: Vector2 = Vector2(50.0, 100.0)
## The sim measures 10-15% fewer drops than this estimate in the upper areas: keep that much margin on both ends.
const MARGIN: float = 1.15

var _data: GameData


func before_all() -> void:
	_data = TestFactory.real_data()


## Share of the kills of `area` that are `monster_id` (packs picked by weight).
func _kill_share(area: AreaDef, monster_id: StringName) -> float:
	var pack_weight: float = 0.0
	var kills: float = 0.0
	var wanted: float = 0.0
	for pack: PackDef in area.packs:
		pack_weight += pack.weight
		kills += pack.weight * pack.monster_ids.size()
		wanted += pack.weight * pack.monster_ids.count(monster_id)
	return wanted / kills if kills > 0.0 else 0.0


## Material drops per hour in the best area for it.
func _drops_per_hour(material: StringName) -> float:
	var best: float = 0.0
	for area: AreaDef in _data.areas():
		var kills_h: float = float(KILLS_PER_HOUR.get(area.id, 0.0))
		var seen: Dictionary = {}
		for pack: PackDef in area.packs:
			for monster_id: StringName in pack.monster_ids:
				seen[monster_id] = true
		for monster_id: Variant in seen:
			for drop: DropEntry in _data.monster(monster_id).drops:
				if drop.item_id == material:
					var per_kill: float = drop.chance_pct / 100.0 * (drop.qty_min + drop.qty_max) / 2.0
					best = maxf(best, kills_h * _kill_share(area, monster_id) * per_kill)
	return best


func _runes() -> Array[ActionDef]:
	var out: Array[ActionDef] = []
	for action: ActionDef in _data.actions_for_skill(&"riftbinding"):
		if str(action.id).begins_with("engrave_"):
			out.append(action)
	return out


func test_every_family_is_checked() -> void:
	assert_eq(_runes().size(), 9)


func test_grade_iii_and_v_farming_hours_are_in_range() -> void:
	var ratio: float = _data.balance_value("rune.upgrade_ratio")
	for action: ActionDef in _runes():
		var qty: float = action.inputs[1].qty
		var rate: float = _drops_per_hour(action.inputs[1].item_id)
		assert_gt(rate, 0.0, "%s: the material drops in an area" % action.id)
		var hours_iii: float = pow(ratio, 2.0) * qty / rate
		var hours_v: float = pow(ratio, 4.0) * qty / rate
		assert_between(hours_iii, GRADE_III_H.x, GRADE_III_H.y, "%s: grade III %.1f h" % [action.id, hours_iii])
		assert_between(hours_v, GRADE_V_H.x, GRADE_V_H.y, "%s: grade V %.1f h" % [action.id, hours_v])
		assert_between(hours_v, GRADE_V_H.x * MARGIN, GRADE_V_H.y / MARGIN, "%s: grade V %.1f h with margin" % [action.id, hours_v])
