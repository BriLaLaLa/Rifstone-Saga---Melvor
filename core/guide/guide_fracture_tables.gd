class_name GuideFractureTables
extends RefCounted
## The generated tables of the Guide page "Fratture" (docs/05_INTERFACES.md §7.v): grades (F-110), Card modifiers (F-111)
## and bosses (F-112, F-115). Rows of text, the first one is the header; every number is read from GameData.

const GRADES_KEY: String = "fracture.grades"


static func grades(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Grado", "Aree", "Livello consigliato", "PV dei mostri", "Danno dei mostri", "Ricompense",
			"Grado dei pezzi del boss"]]
	for grade: int in _grade_count(data):
		var def: FractureGradeDef = data.fracture_grade(grade + 1)
		if def == null:
			continue
		var areas: PackedStringArray = PackedStringArray()
		for area_id: StringName in def.areas:
			areas.append(data.area(area_id).name if data.area(area_id) != null else String(area_id))
		rows.append([str(def.grade), ", ".join(areas), str(def.recommended_level), "x%s" % GuideIndex.num(def.hp_mult),
				"x%s" % GuideIndex.num(def.damage_mult), "x%s" % GuideIndex.num(def.reward_mult), str(def.piece_grade)])
	return rows


static func mods(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Modificatore", "Dal grado", "Rischio", "Premio"]]
	for def: MapModDef in data.map_mods():
		rows.append([def.name, str(def.min_grade),
				MapEffectLabels.range_line(def.risk.type, def.risk.min_value, def.risk.max_value),
				MapEffectLabels.range_line(def.reward.type, def.reward.min_value, def.reward.max_value)])
	return rows


static func bosses(data: GameData) -> Array[Array]:
	var rows: Array[Array] = [["Grado", "Boss", "PV", "Abilità", "Polvere del Rift garantita"]]
	for grade: int in _grade_count(data):
		var boss: BossDef = data.boss_for_grade(grade + 1)
		if boss == null:
			continue
		rows.append([str(boss.grade), boss.name, GuideIndex.num(boss.hp), ability_text(boss.ability, data),
				"%d - %d" % [boss.dust_min, boss.dust_max]])
	return rows


## "Colpo pesante ogni 8 s: danno x2" / "Scudo ogni 12 s: 20% dei PV per 5 s" / "Evocazione ogni 15 s: 2 mostri (al massimo 4)".
static func ability_text(ability: BossAbilityDef, data: GameData) -> String:
	if ability == null:
		return ""
	var name_text: String = MapEffectLabels.ability_name(ability.type)
	var every: String = GuideIndex.num(ability.every_ms / 1000.0)
	match ability.type:
		BossAbilityDef.HEAVY_STRIKE:
			return "%s ogni %s s: danno x%s" % [name_text, every, GuideIndex.num(ability.mult)]
		BossAbilityDef.SHIELD:
			return "%s ogni %s s: %d%% dei PV per %s s" % [name_text, every, ability.shield_pct,
					GuideIndex.num(ability.duration_ms / 1000.0)]
		BossAbilityDef.SUMMON:
			var names: PackedStringArray = PackedStringArray()
			for id: StringName in ability.monsters:
				names.append(data.monster(id).name if data.has_monster(id) else String(id))
			return "%s ogni %s s: %d mostri (al massimo %d vivi): %s" % [name_text, every, ability.count,
					ability.max_alive, ", ".join(names)]
	return name_text


static func _grade_count(data: GameData) -> int:
	var rows: Variant = data.balance_value(GRADES_KEY)
	return (rows as Array).size() if rows is Array else 0
