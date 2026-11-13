extends SceneTree
## Generates the narrow areas of M17-04 (docs/02_FORMULAS.md §8.5, docs/04_DATA_SCHEMA.md §8): data/combat/areas.json (10 areas,
## levels 1-10 ... 91-99, packs of 1..8 monsters with the weights of `combat.pack_size_weights`), data/combat/monsters.json (five
## monsters per area) and data/combat/loot_tables.json (an area table and a Monolith table per area). Names and texts are in
## tools/gen_areas_data.gd; the numbers are computed here from the curves below and from balance.json. The output is committed:
## the game never runs this script. Nothing is written by hand; run in this order (each reads the file of the previous one):
##   godot --headless --path . -s tools/gen_areas.gd
##   godot --headless --path . -s tools/gen_metin.gd          (Rift Stones of the areas)
##   godot --headless --path . -s tools/gen_monster_xp.gd -- --check   (must say 0 monsters out of date)
##
## Monster curve (declared here, not in balance.json: it only feeds generated data). For a monster of level L and role r:
##   hp = round(hp_curve(L) x r.hp_mult x HP_SCALE[area]), attack_level = defence_level = L, power_level = round(L x POWER_SCALE[area]),
##   accuracy_bonus = round((L - 1) x 1.15 x r.accuracy), power_bonus = round((L - 1) x 0.9 x r.power x POWER_SCALE),
##   evasion_bonus = round((L - 1) x 1.2 x r.evasion), damage_reduction = min(25, 0.27 x (L - 1) x r.dr) in steps of 0.5,
##   gold = [0.08, 0.16] x hp, rift_shard_chance = 0.5 + 0.027 L in steps of 0.25,
##   xp = round(combat.monster_xp.base x growth^(L - 1)) (the same formula as tools/gen_monster_xp.gd, F-130).

const Data := preload("res://tools/gen_areas_data.gd")
const AREAS_PATH: String = "res://data/combat/areas.json"
const MONSTERS_PATH: String = "res://data/combat/monsters.json"
const LOOT_PATH: String = "res://data/combat/loot_tables.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const MINIBOSS_ESCORTS: int = 2  # escorts of every area miniboss: the data lives in areas.json (F-139)
const ICON_DIR: String = "res://assets/icons/monsters/"

## hp_curve anchors [level, hp], interpolated linearly (a role multiplies the result).
const HP_CURVE: Array = [[1, 20], [10, 62], [20, 105], [30, 150], [40, 200], [50, 255], [60, 300], [70, 340], [80, 380], [90, 420], [99, 460]]
## Power level as a fraction of the monster level, per area (the first areas hit softer: their packs are as wide as the others).
## Multiplier of the hp curve per area (1.0 = the curve; tuned with tools/sim_combat.gd so that the kills per hour stay even, M17-04).
const HP_SCALE: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0]
const POWER_SCALE: Array[float] = [0.1, 0.6, 0.75, 0.8, 0.85, 0.85, 0.85, 0.85, 0.85, 0.85]
## `rift_stone_chance_pct` of each tier of areas (F-87, Z5).
const STONE_CHANCE: Array[float] = [0.6, 0.6, 1.0, 1.2]
const AREA_SPAN: int = 10
## Multiplier of the attack interval of the monsters per area (the first area hits slower: a level 1 hero faces packs of up to 8, M17-04b).
const INTERVAL_SCALE: Array[float] = [2.4, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const RUNES_PATH: String = "res://data/actions/riftbinding.json"
const DROP_RARE_MIN_PCT: float = 15.0  # tests/data/test_blueprint_data.gd: 15-40% for the rare components
const DROP_RARE_MAX_PCT: float = 40.0
const DROP_RARE_AIM_PCT: float = 25.0
const RUNE_HOURS_V: float = 72.0
const DEFAULT_QTY: int = 5
## Kills per hour of each area as `tools/sim_combat.gd deposit=1 scope=all` measures them (sword and shield, gear of the level).
const DESIGN_KILLS_H: Array[float] = [223.0, 222.0, 207.0, 249.0, 239.0, 232.0, 171.0, 152.0, 231.0, 140.0]
const DROP_COMMON_PCT: int = 12
## Miniboss (F-139, M22-03): the commons of the kit drop from it with this chance and quantity; the ticket of the Monkey Den drops in the
## areas from level TICKET_MIN_LEVEL (areas 4-10) from the miniboss and from the Monoliti (percentages of F-139).
const MINIBOSS_COMMON_PCT: int = 40
const MINIBOSS_COMMON_QTY: Array = [2, 4]
const TICKET_ITEM: String = "dungeon_ticket_monkey_den"
const TICKET_MIN_LEVEL: int = 31
const TICKET_MINIBOSS_PCT: float = 25.0
const TICKET_MONOLITH_PCT: float = 20.0
## The table of the monsters of the Monkey Den (F-142): dust, the four chips, a leather bag; no Cards, no Contracts.
const DUNGEON_TABLE_ID: String = "loot_dungeon_monkey_den"
const TRADES: Array[String] = ["forestry", "quarrying", "angling"]
const FAMILIES: Array[String] = ["ember", "eye", "shade", "root"]
## Contract grades dropped by each tier of areas (and by the Monoliti): [grade, area chance, Monolith chance].
const CONTRACTS: Array = [
	[["apprentice", 0.02, 2.0]],
	[["apprentice", 0.02, -1.0], ["journeyman", 0.015, 2.0]],
	[["journeyman", 0.015, -1.0], ["expert", 0.01, 2.0]],
	[["expert", 0.01, -1.0], ["master", 0.01, 2.0]],
]
## Fracture Cards per tier: [card item, area chance, Monolith chance].
const CARDS: Array = [
	[["fracture_card_1", 0.16, 15.0]],
	[["fracture_card_1", 0.2, 10.0], ["fracture_card_2", 0.11, 15.0]],
	[["fracture_card_1", 0.15, -1.0], ["fracture_card_2", 0.15, 10.0], ["fracture_card_3", 0.11, 15.0]],
	[["fracture_card_2", 0.28, -1.0], ["fracture_card_3", 0.28, 10.0], ["fracture_card_4", -1.0, 20.0]],
]

var _balance: Dictionary = {}


func _init() -> void:
	_balance = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH)) as Dictionary
	var area_lines: Array[String] = []
	var monster_lines: Array[String] = []
	var tables: Array[String] = []
	for i: int in Data.AREAS.size():
		var area: Dictionary = Data.AREAS[i] as Dictionary
		var ids: Array[String] = []
		for m: Array in area["monsters"]:
			ids.append(m[0])
		var area_json: Dictionary = _area(area, i, ids)
		var drops: Dictionary = _area_drops(area, i, area_json["packs"] as Array)
		for m: Array in area["monsters"]:
			monster_lines.append("    " + JSON.stringify(_monster(m, i, drops), "", false))
		var boss: Array = miniboss_row(i)
		var boss_monster: Dictionary = _monster(boss, i, {boss[0]: _miniboss_drops(area, i)})
		boss_monster["miniboss"] = true
		monster_lines.append("    " + JSON.stringify(boss_monster, "", false))
		area_lines.append("    " + JSON.stringify(area_json, "", false))
		tables.append("    " + JSON.stringify(_area_table(area), "", false))
	for area: Dictionary in Data.AREAS:
		tables.append("    " + JSON.stringify(_monolith_table(area), "", false))
	tables.append("    " + JSON.stringify(_dungeon_table(), "", false))
	_save(AREAS_PATH, "{\n  \"areas\": [\n%s\n  ]\n}\n" % ",\n".join(area_lines))
	_save(MONSTERS_PATH, "{\n  \"monsters\": [\n%s\n  ]\n}\n" % ",\n".join(monster_lines))
	var doc: String = "Tabelle di drop (04_DATA_SCHEMA.md §8b, 02_FORMULAS.md §8.5b), generate da tools/gen_areas.gd (M17-04): una tabella per area (vale per ogni mostro dell'area) e una per i Monoliti dell'area."
	_save(LOOT_PATH, "{\n  \"_doc\": %s,\n  \"tables\": [\n%s\n  ]\n}\n" % [JSON.stringify(doc), ",\n".join(tables)])
	print_rich("gen_areas: %d areas, %d monsters, %d loot tables" % [area_lines.size(), monster_lines.size(), tables.size()])
	quit(0)


func _area(area: Dictionary, index: int, ids: Array[String]) -> Dictionary:
	var level_min: int = level_min_of(index)
	return {
		"id": area["id"], "loot_tables": ["loot_area_" + (area["id"] as String)], "name": area["name"], "order": index + 1,
		"description": area["desc"], "level_min": level_min, "level_max": level_max_of(index),
		"map_pos": area["pos"], "requirements": {"character": level_min},
		"rift_stone_chance_pct": STONE_CHANCE[int(area["tier"])], "packs": _packs(ids),
		"miniboss": {"monster": miniboss_row(index)[0], "escorts": MINIBOSS_ESCORTS}}


## The monster row of the miniboss of area `index` (the format of the rows of Data.AREAS): the strongest monster of the area, a new id,
## name, text and the same icon.
static func miniboss_row(index: int) -> Array:
	var area: Dictionary = Data.AREAS[index] as Dictionary
	var strongest: Array = (area["monsters"] as Array)[-1] as Array
	var text: Array = Data.MINIBOSSES[index] as Array
	return ["miniboss_" + (area["id"] as String), text[0], strongest[2], strongest[3], strongest[4], strongest[5], text[1]]


## Drops of a miniboss: the common materials of the kit, and from the areas of level TICKET_MIN_LEVEL on the ticket of the Monkey Den.
func _miniboss_drops(area: Dictionary, index: int) -> Array:
	var drops: Array = []
	for item: String in area["kit"]:
		if not Data.RARE_MATERIALS.has(item):
			drops.append({"item": item, "chance_pct": MINIBOSS_COMMON_PCT, "qty": MINIBOSS_COMMON_QTY})
	if level_min_of(index) >= TICKET_MIN_LEVEL:
		drops.append(_entry(TICKET_ITEM, TICKET_MINIBOSS_PCT))
	return drops


static func level_min_of(index: int) -> int:
	return 1 + index * AREA_SPAN


static func level_max_of(index: int) -> int:
	return mini(99, (index + 1) * AREA_SPAN) if index < Data.AREAS.size() - 1 else 99


## One group per size 1..max_pack_size at least; the weight of each size is `combat.pack_size_weights[size - 1]`, split in two
## groups (a mix and a swarm with one strong monster) when it is 10 or more. `ids` is ordered by level.
func _packs(ids: Array[String]) -> Array:
	var weights: Array = (_balance["combat"] as Dictionary)["pack_size_weights"] as Array
	var packs: Array = []
	for size: int in range(1, int((_balance["combat"] as Dictionary)["max_pack_size"]) + 1):
		var weight: int = int(weights[size - 1])
		var variants: int = 2 if weight >= 10 and size > 1 else 1
		var left: int = weight
		for variant: int in variants:
			var w: int = left if variant == variants - 1 else int(ceil(float(weight) / variants))
			left -= w
			packs.append({"weight": w, "monsters": _composition(ids, size, variant)})
	return packs


static func _composition(ids: Array[String], size: int, variant: int) -> Array:
	var picks: Array[int] = []
	for k: int in size:
		if variant == 0:
			picks.append((k * 2) % ids.size())
		else:
			picks.append((ids.size() - 1) if k == size - 1 else k % 2)
	picks.sort()
	var result: Array = []
	for p: int in picks:
		result.append(ids[p])
	return result


func _monster(m: Array, index: int, drops: Dictionary) -> Dictionary:
	var role: Array = Data.ROLES[m[3]] as Array
	var level: int = m[2]
	var scale: float = POWER_SCALE[index]
	var hp: int = maxi(1, roundi(hp_at(level) * float(role[2]) * HP_SCALE[index]))
	var up: float = float(maxi(0, level - 1))
	var xp_spec: Dictionary = (_balance["combat"] as Dictionary)["monster_xp"] as Dictionary
	return {
		"id": m[0], "name": m[1], "icon": ICON_DIR + (m[5] as String) + ".svg", "description": m[6], "hp": hp,
		"style": m[4] if m[4] != "" else role[0], "attack_interval_ms": roundi(float(role[1]) * INTERVAL_SCALE[index] / 100.0) * 100,
		"attack_level": level, "power_level": maxi(1, roundi(level * scale)), "defence_level": level,
		"accuracy_bonus": roundi(up * 1.15 * float(role[3])), "power_bonus": roundi(up * 0.9 * float(role[4]) * scale),
		"evasion_bonus": roundi(up * 1.2 * float(role[5])),
		"damage_reduction": minf(25.0, roundf(0.27 * up * float(role[6]) * 2.0) / 2.0),
		"gold": [maxi(1, roundi(hp * 0.08)), maxi(2, roundi(hp * 0.16))],
		"rift_shard_chance": roundf((0.5 + 0.027 * level) * 4.0) / 4.0,
		"xp": roundi(float(xp_spec["base"]) * pow(float(xp_spec["growth"]), float(level - 1))),
		"drops": drops[m[0]]}


static func m_index(area: Dictionary, monster_id: String) -> int:
	for i: int in (area["monsters"] as Array).size():
		if ((area["monsters"] as Array)[i] as Array)[0] == monster_id:
			return i
	return 0


## The drops of the monsters of an area (monster id -> drops). Each rare material of the kit has one carrier monster, a different one for
## each material when there are enough, and the chance that makes its drops per hour the target of the material: `rune.upgrade_ratio^4 x
## qty / RUNE_HOURS_V` for the material of a rune (the grade V rune takes RUNE_HOURS_V hours of farming, the middle of the 50-100 h rule of
## tests/data/test_rune_farming_hours.gd, which counts the best single monster), DEFAULT_QTY otherwise. drops/h = kills per hour of the area
## (DESIGN_KILLS_H) x share of the kills made by the carrier x chance (qty 1). The carrier is the monster whose chance comes nearest to
## DROP_RARE_AIM_PCT inside DROP_RARE_MIN_PCT..DROP_RARE_MAX_PCT. The common materials (DROP_COMMON_PCT) go to the monsters with the fewest
## drops, so every monster drops something.
func _area_drops(area: Dictionary, index: int, packs: Array) -> Dictionary:
	var kit: Array = area["kit"] as Array
	var monsters: Array = area["monsters"] as Array
	var total: float = 0.0
	var count: Dictionary = {}
	for pack: Dictionary in packs:
		for id: String in pack["monsters"]:
			total += float(pack["weight"])
			count[id] = float(count.get(id, 0.0)) + float(pack["weight"])
	var ratio: float = float(_balance["rune"]["upgrade_ratio"])
	var drops: Dictionary = {}
	for m: Array in monsters:
		drops[m[0]] = []
	var used: Array[String] = []
	for item: String in kit:
		if not Data.RARE_MATERIALS.has(item):
			continue
		var rate: float = pow(ratio, 4.0) * float(_rune_qty(item)) / RUNE_HOURS_V
		var best_id: String = ""
		var best_cost: float = INF
		var best_chance: float = 0.0
		for m: Array in monsters:
			if used.has(m[0]) and used.size() < monsters.size():
				continue
			var chance: float = 100.0 * rate / (DESIGN_KILLS_H[index] * float(count.get(m[0], 0.0)) / total)
			var cost: float = absf(chance - DROP_RARE_AIM_PCT)
			if chance < DROP_RARE_MIN_PCT or chance > DROP_RARE_MAX_PCT:
				cost += 1000.0
			if cost < best_cost:
				best_cost = cost
				best_id = m[0]
				best_chance = chance
		used.append(best_id)
		(drops[best_id] as Array).append({"item": item, "chance_pct": clampf(roundf(best_chance * 2.0) / 2.0, DROP_RARE_MIN_PCT, DROP_RARE_MAX_PCT), "qty": [1, 1]})
	var commons: Array[String] = []
	for item: String in kit:
		if not Data.RARE_MATERIALS.has(item):
			commons.append(item)
	var added: int = 0
	while added < 2 * commons.size() or _has_empty(drops):
		var poorest: String = (monsters[0] as Array)[0]
		for m: Array in monsters:
			if (drops[m[0]] as Array).size() < (drops[poorest] as Array).size():
				poorest = m[0]
		(drops[poorest] as Array).append({"item": commons[added % commons.size()], "chance_pct": DROP_COMMON_PCT, "qty": [1, 2]})
		added += 1
	return drops


static func _has_empty(drops: Dictionary) -> bool:
	for id: String in drops:
		if (drops[id] as Array).is_empty():
			return true
	return false


## Quantity of `item` in the engrave recipe that uses it (data/actions/riftbinding.json), DEFAULT_QTY if no rune uses it.
func _rune_qty(item: String) -> int:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RUNES_PATH)) as Dictionary
	for action: Dictionary in raw["actions"]:
		if (action["id"] as String).begins_with("engrave_"):
			for input: Dictionary in action["inputs"]:
				if input["item"] == item:
					return int(input["qty"])
	return DEFAULT_QTY


static func hp_at(level: int) -> float:
	for i: int in range(1, HP_CURVE.size()):
		var a: Array = HP_CURVE[i - 1] as Array
		var b: Array = HP_CURVE[i] as Array
		if level <= int(b[0]):
			return lerpf(float(a[1]), float(b[1]), float(level - int(a[0])) / float(int(b[0]) - int(a[0])))
	return float((HP_CURVE[-1] as Array)[1])


func _entry(item: String, chance: float, qty_min: int = 1, qty_max: int = 1) -> Dictionary:
	return {"item": item, "chance_pct": chance, "qty": [qty_min, qty_max]}


## The table of an area (same drops as the tables of the first four areas of M12, by tier).
func _area_table(area: Dictionary) -> Dictionary:
	var tier: int = int(area["tier"])
	var entries: Array = [_entry("rift_dust", 8)]
	for family: String in FAMILIES:
		entries.append(_entry("stone_%s_chip" % family, 1))
	if tier >= 1:
		for family: String in FAMILIES:
			entries.append(_entry("stone_%s_stone" % family, 0.05))
		entries.append_array([_entry("currency_spark", 0.05), _entry("currency_flux", 0.03), _entry("currency_crown", 0.02)])
	for grade: Array in CONTRACTS[tier]:
		for trade: String in TRADES:
			entries.append(_entry("contract_%s_%s" % [trade, grade[0]], grade[1]))
	if tier <= 1:
		entries.append(_entry("bag_leather", 0.05))
	elif tier == 2:
		entries.append(_entry("bag_wayfarer", 0.02))
	for card: Array in CARDS[tier]:
		if float(card[1]) > 0.0:
			entries.append(_entry(card[0], card[1]))
	return {"id": "loot_area_" + (area["id"] as String), "entries": entries}


## The table of the Monoliti of an area (every stone of the area rolls it).
func _monolith_table(area: Dictionary) -> Dictionary:
	var tier: int = int(area["tier"])
	var entries: Array = [_entry("rift_dust", 100, 20, 40)]
	for family: String in FAMILIES:
		entries.append(_entry("stone_%s_chip" % family, 100, 2, 4))
	for family: String in FAMILIES:
		entries.append(_entry("stone_%s_stone" % family, 20))
	entries.append_array([_entry("currency_spark", 15), _entry("currency_flux", 10), _entry("currency_crown", 5)])
	if tier == 3:
		entries.append(_entry("bag_runic", 5))
	for grade: Array in CONTRACTS[tier]:
		if float(grade[2]) > 0.0:
			for trade: String in TRADES:
				entries.append(_entry("contract_%s_%s" % [trade, grade[0]], grade[2]))
	for card: Array in CARDS[tier]:
		if float(card[2]) > 0.0:
			entries.append(_entry(card[0], card[2]))
	if level_min_of(Data.AREAS.find(area)) >= TICKET_MIN_LEVEL:
		entries.append(_entry(TICKET_ITEM, TICKET_MONOLITH_PCT))
	return {"id": "loot_monolith_" + (area["id"] as String), "entries": entries}


## The table of the monsters of the Monkey Den (F-142): no Card and no Contract.
func _dungeon_table() -> Dictionary:
	var entries: Array = [_entry("rift_dust", 6)]
	for family: String in FAMILIES:
		entries.append(_entry("stone_%s_chip" % family, 1))
	entries.append(_entry("bag_leather", 0.05))
	return {"id": DUNGEON_TABLE_ID, "entries": entries}


func _save(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
