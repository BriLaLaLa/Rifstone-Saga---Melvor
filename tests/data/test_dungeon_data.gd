extends GutTest
## M22-03: the real data of the Monkey Den and of the minibosses (docs/04_DATA_SCHEMA.md §27, F-139, F-142, F-143): ten monsters,
## three stages with the abilities of F-112, the room types of F-138, the ticket only where §27 puts it, the ticket rate of the
## example of F-139, the minibosses of the ten areas, the generators up to date.

const DEN_PATH: String = "res://data/dungeons/monkey_den.json"
const TICKET: StringName = &"dungeon_ticket_monkey_den"
const ROLE_IDS: Array[String] = ["monkey_imp", "monkey_grunt", "monkey_slinger", "monkey_shaman", "monkey_guard", "monkey_gorilla",
	"monkey_packlead", "monkey_gorom", "monkey_ziki", "monkey_king"]

var _data: GameData = null
var _den: Dictionary = {}
var _balance: Dictionary = {}


func before_all() -> void:
	_data = GameData.load_from_dirs()
	_den = _read(DEN_PATH)
	_balance = _read("res://data/config/balance.json")


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func test_real_data_is_valid_and_the_den_loads() -> void:
	assert_true(_data.is_valid(), str(_data.errors))
	var den: DungeonDef = _data.dungeon(&"monkey_den")
	assert_not_null(den)
	_eq(den.req_character, 35)
	_eq(den.recommended_level, 45)
	_eq(den.ticket, TICKET)
	_eq(_data.dungeon_for_ticket(TICKET), den)
	_eq(den.forks, 5)


func test_ten_monsters_with_the_levels_and_styles_of_f139() -> void:
	var levels: Dictionary = {"monkey_imp": 40, "monkey_grunt": 44, "monkey_slinger": 45, "monkey_shaman": 46, "monkey_guard": 46,
		"monkey_gorilla": 49, "monkey_packlead": 50, "monkey_gorom": 50, "monkey_ziki": 51, "monkey_king": 54}
	var styles: Dictionary = {"monkey_slinger": "marksmanship", "monkey_shaman": "arcana", "monkey_ziki": "arcana"}
	var list: Array = _den["monsters"] as Array
	_eq(list.size(), 10)
	for i: int in list.size():
		var m: Dictionary = list[i] as Dictionary
		_eq(m["id"], ROLE_IDS[i])
		_eq(int(m["level"]), int(levels[m["id"]]), m["id"])
		_eq(m["style"], styles.get(m["id"], "blade"), m["id"])
		_eq(m["loot_tables"], ["loot_dungeon_monkey_den"], m["id"])
		assert_true(FileAccess.file_exists(m["icon"]), "icon of %s" % m["id"])
		var monster: MonsterDef = _data.monster(StringName(m["id"]))
		_eq(monster.dungeon, &"monkey_den")
	var by_id: Dictionary = {}
	for m: Dictionary in list:
		by_id[m["id"]] = m
	# the hp multipliers of F-139 order the monsters of a similar level: imp < grunt < guard < gorilla < packlead < gorom < king
	var order: Array[String] = ["monkey_imp", "monkey_grunt", "monkey_guard", "monkey_gorilla", "monkey_packlead", "monkey_gorom", "monkey_king"]
	for i: int in order.size() - 1:
		assert_lt(int(by_id[order[i]]["hp"]), int(by_id[order[i + 1]]["hp"]), "%s has fewer hp than %s" % [order[i], order[i + 1]])
	assert_gt(float(by_id["monkey_ziki"]["damage_reduction"]), float(by_id["monkey_shaman"]["damage_reduction"]), "Ziki DR x1.3")


func test_three_stages_with_the_abilities_of_f139() -> void:
	var stages: Array = _den["stages"] as Array
	_eq(stages.size(), 3)
	_eq([stages[0]["monster"], stages[1]["monster"], stages[2]["monster"]], ["monkey_gorom", "monkey_ziki", "monkey_king"])
	_eq(stages[0]["escorts"], ["monkey_guard", "monkey_guard"])
	_eq((stages[1]["escorts"] as Array).size(), 3)
	_eq(stages[1]["escorts"], ["monkey_slinger", "monkey_slinger", "monkey_slinger"])
	_eq((stages[2]["escorts"] as Array).size(), 0, "the King is alone")
	_eq([stages[0]["intro_ms"], stages[1]["intro_ms"], stages[2]["intro_ms"]], [3500, 3500, 5500])
	_eq(stages[0]["ability"], {"type": "heavy_strike", "every_ms": 9000, "mult": 2.2})
	_eq(stages[1]["ability"]["type"], "summon")
	_eq([stages[1]["ability"]["every_ms"], stages[1]["ability"]["count"], stages[1]["ability"]["max_alive"]], [10000, 2, 4])
	_eq(stages[1]["ability"]["monsters"], ["monkey_slinger"])
	_eq(stages[2]["ability"], {"type": "shield", "every_ms": 14000, "duration_ms": 6000, "shield_pct": 20})
	assert_true(String(stages[2]["quote"]).contains("ruggito"), "the roar of the King")
	assert_false(stages[2].has("reward"), "the reward of the last stage is the boss loot")
	var max_pack: int = int((_balance["combat"] as Dictionary)["max_pack_size"])
	assert_lte(int(stages[1]["ability"]["max_alive"]) + 1, max_pack, "summons plus the Strategist fit a pack")


func test_room_types_follow_f138() -> void:
	var rooms: Dictionary = _den["rooms"] as Dictionary
	var types: Dictionary = {}
	for t: Dictionary in rooms["types"]:
		types[t["id"]] = t
	_eq(types.keys(), ["pack", "horde", "elite", "miniboss", "trap", "rest"])
	var weights: Array = []
	var layers: Array = []
	for id: String in types:
		weights.append(types[id]["weight"])
		layers.append(types[id]["min_layer"])
	_eq(weights, [30, 16, 14, 10, 14, 10])
	_eq(layers, [1, 1, 2, 3, 1, 2])
	_eq(types["horde"]["size"], 12, "the Horde has 12 monsters")
	_eq(types["pack"]["size"], [3, 6])
	_eq(types["elite"]["fixed"], ["monkey_gorilla"])
	_eq(types["miniboss"]["fixed"], ["monkey_packlead", "monkey_guard", "monkey_guard"])
	_eq((rooms["entrance"] as Dictionary)["size"], 6)
	_eq(int(_den["map"]["hint_pct"]), 45)
	_eq((rooms["trap"] as Dictionary)["dash_hp_pct"], 20)
	_eq((rooms["rest"] as Dictionary)["heal_pct"], 35)


func test_rewards_follow_f142_and_f143() -> void:
	var rooms: Dictionary = _den["rooms"] as Dictionary
	var by_type: Dictionary = {}
	for t: Dictionary in rooms["types"]:
		by_type[t["id"]] = t
	_eq((by_type["miniboss"]["reward"] as Dictionary), {"gold": [1200, 2000], "dust": [10, 18], "crystal_pct": 25, "piece_pct": 70})
	_eq((by_type["elite"]["reward"] as Dictionary), {"gold": [600, 1200], "piece_pct": 40})
	_eq((by_type["horde"]["reward"] as Dictionary), {"gold": [400, 800], "dust": [4, 8]})
	_eq(((rooms["entrance"] as Dictionary)["reward"] as Dictionary), {"gold": [200, 400]})
	for stage: Dictionary in (_den["stages"] as Array).slice(0, 2):
		_eq(stage["reward"], {"gold": [1500, 2500], "dust": [15, 25], "crystal_pct": 60, "piece_pct": 60})
	var boss: Dictionary = _den["boss"] as Dictionary
	_eq([boss["gold"], boss["dust"], boss["crystals"], boss["card_pct"], boss["card_grade"]], [[3000, 5000], [40, 60], 2, 60, 4])
	_eq(boss["pieces"], [{"rarity": "rare"}, {"min_rarity": "magic"}])
	_eq((boss["drops"] as Array).size(), 4)
	for d: Dictionary in boss["drops"]:
		_eq([d["chance_pct"], d["qty"]], [50, [3, 6]], d["item"])


func test_the_den_table_has_no_cards_and_no_contracts_and_no_ticket() -> void:
	var table: LootTableDef = null
	for t: LootTableDef in _data.loot_tables():
		if t.id == &"loot_dungeon_monkey_den":
			table = t
	assert_not_null(table)
	for entry: DropEntry in table.entries:
		var category: StringName = _data.item(entry.item_id).category
		assert_false([&"map", &"contract"].has(category), String(entry.item_id))
		assert_ne(entry.item_id, TICKET)


## The ticket drops only from the minibosses and the Monoliti of the areas 4-10 (level_min >= 31).
func test_the_ticket_only_where_the_schema_says() -> void:
	var areas: Array = _read("res://data/combat/areas.json")["areas"]
	var allowed_tables: Dictionary = {}
	var allowed_minibosses: Dictionary = {}
	for a: Dictionary in areas:
		if int(a["level_min"]) >= 31:
			allowed_tables["loot_monolith_" + String(a["id"])] = true
			allowed_minibosses[a["miniboss"]["monster"]] = true
	var tables_with: Dictionary = {}
	for t: LootTableDef in _data.loot_tables():
		for entry: DropEntry in t.entries:
			if entry.item_id == TICKET:
				tables_with[String(t.id)] = entry.chance_pct
	_eq(tables_with.keys().size(), 7, "the Monoliti of the areas 4-10")
	for id: String in tables_with:
		assert_true(allowed_tables.has(id), id)
		_eq(tables_with[id], 5.0, id)
	var with_ticket: Array[String] = []
	for m: Dictionary in _read("res://data/combat/monsters.json")["monsters"]:
		for d: Dictionary in m["drops"]:
			if d["item"] == str(TICKET):
				with_ticket.append(String(m["id"]))
				assert_true(m.get("miniboss", false), "only a miniboss drops the ticket")
				assert_true(allowed_minibosses.has(m["id"]), String(m["id"]))
				_eq(d["chance_pct"], 12.0)
	_eq(with_ticket.size(), 7)
	for dungeon_monster: Dictionary in _den["monsters"]:
		for d: Dictionary in dungeon_monster["drops"]:
			assert_ne(d["item"], str(TICKET))
	var ticket: ItemDef = _data.item(TICKET)
	_eq(ticket.category, &"misc")
	_eq(ticket.value, 0)


## F-139/F-144 (M22-07, measured by tools/sim_dungeon.gd with the hero of the area): about 530 kills/hour and 134 encounters/hour,
## the chances of the data (miniboss after an encounter, Monolith per kill, ticket in the miniboss and in the Monolith tables):
## one ticket every 1.5-2.5 hours in the areas 4-10.
func test_ticket_rate_is_one_every_one_and_a_half_to_two_and_a_half_hours() -> void:
	var encounters: float = 134.0
	var kills: float = 530.0
	var area: AreaDef = _data.area(&"ash_marsh")
	var from_miniboss: float = encounters * float(_balance["miniboss"]["chance_pct"]) / 100.0 * _ticket_pct(_data.monster(area.miniboss_id).drops) / 100.0
	var stones: Array[RiftStoneDef] = _data.rift_stones_for_area(area.id)
	var from_stones: float = kills * area.rift_stone_chance_pct / 100.0 * _ticket_pct(_data.loot_table(stones[0].loot_tables[0]).entries) / 100.0
	assert_between(1.0 / (from_miniboss + from_stones), 1.5, 2.5, "hours per ticket")


func _ticket_pct(entries: Array) -> float:
	var pct: float = 0.0
	for entry: DropEntry in entries:
		pct += entry.chance_pct if entry.item_id == TICKET else 0.0
	return pct


func test_every_area_has_its_own_miniboss() -> void:
	var seen: Dictionary = {}
	_eq(_data.areas().size(), 10)
	for area: AreaDef in _data.areas():
		_eq(area.miniboss_id, StringName("miniboss_%s" % area.id))
		_eq(area.miniboss_escorts, 2)
		var m: MonsterDef = _data.monster(area.miniboss_id)
		assert_true(m.is_miniboss)
		assert_false(seen.has(m.name), "unique name %s" % m.name)
		seen[m.name] = true
		assert_gt(m.drops.size(), 0, String(m.id))
		var level: int = maxi(m.attack_level, maxi(m.power_level, m.defence_level))
		assert_between(level, area.level_min, area.level_max, String(m.id))
		for pack: PackDef in area.packs:
			assert_false(pack.monster_ids.has(m.id), "never in a pack")


func test_the_direction_bands_and_the_miniboss_balance_are_the_ones_of_the_fixtures() -> void:
	_eq((_balance["dungeon"] as Dictionary)["direction_bands"], [-0.55, -0.30, -0.10, 0.10, 0.30, 0.55])
	_eq(_balance["miniboss"], {"chance_pct": 1.5, "hp_mult": 4.0, "power_mult": 1.5, "xp_mult": 4.0, "gold_mult": 4.0})


## JSON numbers are floats: whole numbers become integers, so that the expected values read like the file.
static func _norm(v: Variant) -> Variant:
	if v is float and is_equal_approx(float(v), roundf(float(v))):
		return int(roundf(float(v)))
	if v is Array:
		return (v as Array).map(func(e: Variant) -> Variant: return _norm(e))
	if v is Dictionary:
		var result: Dictionary = {}
		for k: Variant in (v as Dictionary):
			result[k] = _norm((v as Dictionary)[k])
		return result
	return v


func _eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	assert_eq(_norm(actual), _norm(expected), msg)
