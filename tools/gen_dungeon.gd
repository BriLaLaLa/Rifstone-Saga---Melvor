extends SceneTree
## Generates data/dungeons/monkey_den.json (M22-03; docs/02_FORMULAS.md F-137...F-143, docs/04_DATA_SCHEMA.md §27): the Monkey Den, its ten
## monsters, the room types, the three stages of the boss and the rewards. Nothing is written by hand: the numbers are the constants below
## (the taratura of F-138, F-140, F-142, F-143) and the curves of tools/gen_areas.gd; names and texts are Italian and original.
## The output is committed: the game never runs this script.
##
## Usage: godot --headless --path . -s tools/gen_dungeon.gd [-- --check]   (--check writes nothing, exits 1 if the file differs)
##
## Monster of the dungeon (F-139): the statistics of an area monster of the same level L (the HP curve, the bonuses and the interval of
## its role, tools/gen_areas.gd) times the multipliers of the row: hp x PV, the damage x Danno (applied to the whole max hit, so
## power_bonus = round(Danno x (power_bonus_of_the_area + maxhit_bonus_offset) - maxhit_bonus_offset)), xp (F-130) and gold x XP/oro.

const Areas := preload("res://tools/gen_areas.gd")
const Data := preload("res://tools/gen_areas_data.gd")
const OUT_PATH: String = "res://data/dungeons/monkey_den.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const ICON_DIR: String = "res://assets/icons/monsters/"
const DUNGEON_ICON: String = "res://assets/icons/ui/dungeon.svg"
const TICKET_ITEM: String = "dungeon_ticket_monkey_den"
const LOOT_TABLE: String = "loot_dungeon_monkey_den"

## Rows: [id, name, level, base role (Data.ROLES), style override, icon, hp x, damage x, xp and gold x, damage reduction x, description].
const MONSTERS: Array = [
	["monkey_imp", "Monello del branco", 40, "swarm", "blade", "ember_rat", 1.00, 0.65, 0.5, 1.0,
		"Piccolo, rumoroso e mai da solo: ti morde i lacci degli stivali e scappa ridendo."],
	["monkey_grunt", "Scimmia predona", 44, "warrior", "", "redrock_raider", 2.00, 1.09, 1.0, 1.0,
		"Ruba tutto quello che brilla e difende il bottino a morsi."],
	["monkey_slinger", "Lanciatrice di noci", 45, "skirmisher", "", "hollow_archer", 1.60, 1.20, 1.0, 1.0,
		"Dai rami alti scaglia noci dure come sassi, e non sbaglia mai due volte."],
	["monkey_shaman", "Scimmia sciamana", 46, "mystic", "", "vein_witch", 2.00, 1.20, 1.0, 1.0,
		"Agita ossa e piume, e il Rift risponde con scintille storte."],
	["monkey_guard", "Guardia dei rami", 46, "brute", "", "rift_knight", 3.20, 1.31, 1.5, 1.0,
		"Armata di un tronco e di poca pazienza, difende i sentieri del Covo."],
	["monkey_gorilla", "Gorilla guardiano", 49, "brute", "", "crack_golem", 6.00, 1.53, 3.0, 1.0,
		"Un muro di pelo e muscoli: si batte il petto e la terra trema."],
	["monkey_packlead", "Capobranco", 50, "warrior", "", "whisper_wolf", 8.00, 1.64, 4.0, 1.0,
		"Guida le scimmie con un ruggito basso e punisce chi arretra."],
	["monkey_gorom", "Gorom, il Braccio Destro", 50, "warrior", "", "riftborn_colossus", 12.00, 1.53, 6.0, 1.0,
		"Il pugno del Re: spacca tutto ciò che il suo padrone gli indica."],
	["monkey_ziki", "Ziki, la Stratega", 51, "mystic", "", "shard_wraith", 10.00, 1.31, 5.0, 1.3,
		"Piccola e spietata, muove le scimmie come pezzi su una scacchiera di rami."],
	["monkey_king", "Uuk-Maar, il Re delle Scimmie", 54, "brute", "", "boss_grade_10", 20.00, 1.74, 10.0, 1.0,
		"Il Re del Covo: siede su un trono di radici e ogni scimmia gli deve un ruggito."],
]

const REQUIRES_CHARACTER: int = 40
const RECOMMENDED_LEVEL: int = 45
## F-137: the parameters of the hidden map.
const MAP: Dictionary = {"forks": 5, "width_weights": [3, 4, 3], "exit_weights": [5, 3, 2], "hint_pct": 45}
## F-138: the entrance, then the types [id, weight, min layer, composition, hint, reward]; a composition is {"size", "pool"} or {"fixed"}.
const ENTRANCE: Dictionary = {"size": 6, "pool": [["monkey_grunt", 4], ["monkey_slinger", 2], ["monkey_imp", 3]], "reward": {"gold": [200, 400]}}
const TYPES: Array = [
	["pack", 30, 1, {"size": [3, 6], "pool": [["monkey_grunt", 4], ["monkey_slinger", 3], ["monkey_shaman", 2], ["monkey_guard", 2]]},
		"Rumore di rami e di risate sguaiate", {}],
	["horde", 16, 1, {"size": 12, "pool": [["monkey_imp", 8], ["monkey_grunt", 2]]}, "Un brusio fitto, di molte voci",
		{"gold": [400, 800], "dust": [4, 8]}],
	["elite", 14, 2, {"fixed": ["monkey_gorilla"]}, "Passi pesanti, uno solo", {"gold": [600, 1200], "piece_pct": 40}],
	["miniboss", 10, 3, {"fixed": ["monkey_packlead", "monkey_guard", "monkey_guard"]}, "Un ruggito basso che fa tremare le foglie",
		{"gold": [1200, 2000], "dust": [10, 18], "crystal_pct": 25, "piece_pct": 70}],
	["trap", 14, 1, {}, "Una liana tesa nell'ombra", {}],
	["rest", 10, 2, {}, "Odore di frutta matura e di acqua fresca", {}],
]
## F-140: the events. The ambush and the forage draw from the same pool.
const SIDE_POOL: Array = [["monkey_grunt", 4], ["monkey_slinger", 2]]
const TRAP: Dictionary = {"kinds": ["darts", "pit", "vines"], "dash_hp_pct": 20, "ambush_size": 3, "reward": {"dust": [3, 6]}}
const REST: Dictionary = {"heal_pct": 35, "forage_size": 4, "forage_dust": [8, 14], "forage_crystal_pct": 30}
## F-139, F-142: the three acts of the boss: [id, monster, escorts, intro_ms, title, quote, reward, ability].
const STAGES: Array = [
	["right_hand", "monkey_gorom", ["monkey_guard", "monkey_guard"], 3500, "Il Braccio Destro",
		"Gorom si batte i pugni sul petto: «Il Re non riceve i ladri. Prima dovete passare da me!»",
		{"gold": [1500, 2500], "dust": [15, 25], "crystal_pct": 60, "piece_pct": 60}, {"type": "heavy_strike", "every_ms": 9000, "mult": 2.2}],
	["strategist", "monkey_ziki", ["monkey_slinger", "monkey_slinger", "monkey_slinger"], 3500, "La Stratega",
		"Ziki alza una mano e tra i rami si accendono mille occhi: «Contateli. Poi contate voi.»",
		{"gold": [1500, 2500], "dust": [15, 25], "crystal_pct": 60, "piece_pct": 60},
		{"type": "summon", "every_ms": 10000, "count": 2, "max_alive": 4, "monsters": ["monkey_slinger"]}],
	["king", "monkey_king", [], 5500, "Il Re delle Scimmie",
		"Il ruggito scuote il Covo da cima a fondo: Uuk-Maar si alza dal trono di radici e il buio intorno a lui trema.",
		{}, {"type": "shield", "every_ms": 14000, "duration_ms": 6000, "shield_pct": 20}],
]
## F-143: the loot of the boss.
const BOSS_DROPS: Array = [["witch_charm", 50, [3, 6]], ["crawler_carapace", 50, [3, 6]], ["wraith_veil", 50, [3, 6]], ["knight_plate", 50, [3, 6]]]
const BOSS: Dictionary = {"gold": [3000, 5000], "dust": [40, 60], "pieces": [{"rarity": "rare"}, {"min_rarity": "magic"}], "crystals": 2,
	"card_pct": 60, "card_grade": 4}

var _balance: Dictionary = {}


func _init() -> void:
	_balance = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH)) as Dictionary
	var text: String = _document()
	if OS.get_cmdline_user_args().has("--check"):
		var same: bool = FileAccess.file_exists(OUT_PATH) and FileAccess.get_file_as_string(OUT_PATH) == text
		print_rich("gen_dungeon --check: %s" % ("up to date" if same else "OUT OF DATE"))
		quit(0 if same else 1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print_rich("gen_dungeon: %d monsters, %d room types, %d stages" % [MONSTERS.size(), TYPES.size(), STAGES.size()])
	quit(0)


func _document() -> String:
	var head: Dictionary = {"id": "monkey_den", "name": "Covo delle Scimmie",
		"description": "Un intrico di rami e tane dove le scimmie del Rift hanno eretto un regno. Si entra con un Biglietto e si sceglie la strada: la borsa si tiene solo uscendo vivi.",
		"icon": DUNGEON_ICON, "order": 1, "requirements": {"character": REQUIRES_CHARACTER}, "recommended_level": RECOMMENDED_LEVEL,
		"ticket": TICKET_ITEM, "map": MAP}
	var lines: Array[String] = []
	for key: String in head:
		lines.append("  %s: %s" % [JSON.stringify(key), _j(head[key])])
	lines.append("  \"monsters\": [\n%s\n  ]" % _rows(_monsters()))
	lines.append("  \"rooms\": {\n%s\n  }" % _rooms())
	lines.append("  \"stages\": [\n%s\n  ]" % _rows(_stages()))
	lines.append("  \"boss\": %s" % _j(_boss()))
	lines.append("  \"loot_table\": %s" % _j(LOOT_TABLE))
	return "{\n%s\n}\n" % ",\n".join(lines)


static func _j(value: Variant) -> String:
	return JSON.stringify(value, "", false)


static func _rows(list: Array) -> String:
	var rows: Array[String] = []
	for e: Variant in list:
		rows.append("    " + _j(e))
	return ",\n".join(rows)


static func _pool(pool: Array) -> Array:
	var result: Array = []
	for p: Array in pool:
		result.append({"monster": p[0], "weight": p[1]})
	return result


# --- monsters ----------------------------------------------------------------------------------------------------

func _monsters() -> Array:
	var result: Array = []
	for row: Array in MONSTERS:
		result.append(_monster(row))
	return result


func _monster(row: Array) -> Dictionary:
	var level: int = row[2]
	var role: Array = Data.ROLES[row[3]] as Array
	var index: int = mini(Areas.POWER_SCALE.size() - 1, floori(float(level - 1) / Areas.AREA_SPAN))  # the area of the same level
	var scale: float = Areas.POWER_SCALE[index]
	var up: float = float(maxi(0, level - 1))
	var base_hp: float = Areas.hp_at(level) * Areas.HP_SCALE[index]
	var offset: float = float(((_balance["combat"] as Dictionary))["maxhit_bonus_offset"])
	var area_bonus: float = up * 0.9 * float(role[4]) * scale
	var xp_spec: Dictionary = (_balance["combat"] as Dictionary)["monster_xp"] as Dictionary
	var xp_mult: float = row[8]
	return {
		"id": row[0], "name": row[1], "icon": ICON_DIR + (row[5] as String) + ".svg", "description": row[10], "level": level,
		"hp": maxi(1, roundi(base_hp * float(row[6]))), "style": row[4] if row[4] != "" else role[0],
		"attack_interval_ms": roundi(float(role[1]) * Areas.INTERVAL_SCALE[index] / 100.0) * 100,
		"attack_level": level, "power_level": maxi(1, roundi(level * scale)), "defence_level": level,
		"accuracy_bonus": roundi(up * 1.15 * float(role[3])),
		"power_bonus": maxi(0, roundi(float(row[7]) * (area_bonus + offset) - offset)),
		"evasion_bonus": roundi(up * 1.2 * float(role[5])),
		"damage_reduction": minf(25.0, roundf(0.27 * up * float(role[6]) * float(row[9]) * 2.0) / 2.0),
		"gold": [maxi(1, roundi(base_hp * 0.08 * xp_mult)), maxi(2, roundi(base_hp * 0.16 * xp_mult))],
		"rift_shard_chance": roundf((0.5 + 0.027 * level) * 4.0) / 4.0,
		"xp": roundi(float(xp_spec["base"]) * pow(float(xp_spec["growth"]), float(level - 1)) * xp_mult),
		"drops": [], "loot_tables": [LOOT_TABLE]}


# --- rooms, stages, boss -----------------------------------------------------------------------------------------

func _rooms() -> String:
	var entrance: Dictionary = {"size": ENTRANCE["size"], "pool": _pool(ENTRANCE["pool"] as Array), "reward": ENTRANCE["reward"]}
	var types: Array = []
	for t: Array in TYPES:
		var e: Dictionary = {"id": t[0], "weight": t[1], "min_layer": t[2]}
		var comp: Dictionary = t[3] as Dictionary
		if comp.has("size"):
			e["size"] = comp["size"]
			e["pool"] = _pool(comp["pool"] as Array)
		elif comp.has("fixed"):
			e["fixed"] = comp["fixed"]
		e["hint"] = t[4]
		if t[0] != "trap" and t[0] != "rest":
			e["reward"] = t[5]
		types.append(e)
	var trap: Dictionary = {"kinds": TRAP["kinds"], "dash_hp_pct": TRAP["dash_hp_pct"],
		"ambush": {"size": TRAP["ambush_size"], "pool": _pool(SIDE_POOL)}, "reward": TRAP["reward"]}
	var rest: Dictionary = {"heal_pct": REST["heal_pct"], "forage": {"size": REST["forage_size"], "pool": _pool(SIDE_POOL),
		"dust": REST["forage_dust"], "crystal_pct": REST["forage_crystal_pct"]}}
	return "    \"entrance\": %s,\n    \"types\": [\n%s\n    ],\n    \"trap\": %s,\n    \"rest\": %s" % [
			_j(entrance), ",\n".join(types.map(func(e: Variant) -> String: return "      " + _j(e))), _j(trap), _j(rest)]


func _stages() -> Array:
	var result: Array = []
	for s: Array in STAGES:
		var e: Dictionary = {"id": s[0], "monster": s[1], "escorts": s[2], "intro_ms": s[3], "title": s[4], "quote": s[5]}
		if not (s[6] as Dictionary).is_empty():
			e["reward"] = s[6]
		e["ability"] = s[7]
		result.append(e)
	return result


func _boss() -> Dictionary:
	var drops: Array = []
	for d: Array in BOSS_DROPS:
		drops.append({"item": d[0], "chance_pct": d[1], "qty": d[2]})
	var boss: Dictionary = BOSS.duplicate(true)
	boss["drops"] = drops
	return boss
