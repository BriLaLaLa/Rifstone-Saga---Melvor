extends SceneTree
## Generates the 15 Market entries of data/shop/shop.json (M20-04, docs/02_FORMULAS.md F-136, docs/04_DATA_SCHEMA.md §25).
## The hand-written entries stay as they are; every line from the first `market_` entry to the end of the file is
## rewritten. Idempotent. `--check` writes nothing and exits 1 if the file differs from the generated text.
##
## Usage: godot --headless --path . -s tools/gen_market.gd [-- --check]

const SHOP_PATH: String = "res://data/shop/shop.json"
const MARKER: String = '    {"id":"market_'
const TAIL: String = "\n  ]\n}\n"
const SKILL_NAMES: Dictionary = {"forestry": "Boscaiolo", "quarrying": "Minatore", "angling": "Pescatore", "hearthcraft": "Cuoco"}


func _initialize() -> void:
	var text: String = FileAccess.get_file_as_string(SHOP_PATH)
	var cut: int = text.find(MARKER)
	var head: String = text.substr(0, cut).rstrip(" \n") if cut >= 0 else text.substr(0, text.rfind("\n  ]"))
	head += "\n" if head.ends_with(",") else ",\n"
	var rows: PackedStringArray = []
	for entry: Dictionary in entries():
		rows.append("    " + JSON.stringify(entry, "", false))
	var out: String = head + ",\n".join(rows) + TAIL
	if OS.get_cmdline_user_args().has("--check"):
		print_rich("gen_market: " + ("up to date" if out == text else "OUT OF DATE (rerun tools/gen_market.gd)"))
		quit(0 if out == text else 1)
		return
	if out != text:
		var file: FileAccess = FileAccess.open(SHOP_PATH, FileAccess.WRITE)
		file.store_string(out)
		file.close()
	print_rich("gen_market: %s" % ("written" if out != text else "unchanged"))
	quit(0)


## The 15 entries of F-136 in table order (a pure function of the table below).
static func entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var shelf_prices: Array[int] = [2000, 12000, 24000, 36000]
	var shelf_levels: Array[int] = [1, 3, 5, 7]
	var shelf_names: Array[String] = ["I", "II", "III", "IV"]
	for i: int in 4:
		list.append(_entry("market_shelf_%d" % (i + 1), "Scaffale del mercante %s" % shelf_names[i],
				"Quattro caselle in più nel Deposito.", shelf_prices[i], shelf_levels[i],
				["market_shelf_%d" % i] if i > 0 else [], "deposit_slots", 4, ""))
	var spice_prices: Array[int] = [6000, 16000, 30000]
	var spice_levels: Array[int] = [2, 4, 6]
	for i: int in 3:
		list.append(_entry("market_spice_%d" % (i + 1), "Spezie del mercante %s" % shelf_names[i],
				"Il cibo cura di più.", spice_prices[i], spice_levels[i],
				["market_spice_%d" % i] if i > 0 else [], "food_healing_pct", 4, ""))
	for skill: String in ["forestry", "quarrying", "angling", "hearthcraft"]:
		list.append(_entry("market_manual_" + skill, "Manuale: %s" % SKILL_NAMES[skill],
				"Più esperienza nel mestiere.", 12000, 3, [], "skill_xp_pct", 5, "skill:" + skill))
	for skill: String in ["forestry", "quarrying", "angling"]:
		list.append(_entry("market_tools_" + skill, "Attrezzi affilati: %s" % SKILL_NAMES[skill],
				"Le azioni del mestiere sono più rapide.", 30000, 6, [], "skill_interval_pct", -3, "skill:" + skill))
	list.append(_entry("market_loot_pouch", "Tasca del cacciatore", "Sei posti in più nella borsa del bottino.",
			50000, 8, [], "loot_bag_slots", 6, ""))
	return list


static func _entry(id: String, entry_name: String, description: String, gold: int, market_level: int,
		chain: Array, stat: String, value: int, scope: String) -> Dictionary:
	var requires: Dictionary = {}
	if not chain.is_empty():
		requires["entries"] = chain
	requires["village"] = {"market": market_level}
	var modifier: Dictionary = {"stat": stat, "value": value}
	if scope != "":
		modifier["scope"] = scope
	return {"id": id, "name": entry_name, "category": "market", "vendor": "mercato", "description": description,
			"cost": {"gold": gold}, "max_purchases": 1, "requires": requires, "effect": {"modifiers": [modifier]}}
