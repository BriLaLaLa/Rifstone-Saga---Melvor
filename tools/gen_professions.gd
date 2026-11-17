extends SceneTree
## Generates the profession data of M26 (docs/04_DATA_SCHEMA_M26.md §31, docs/02_FORMULAS_M26.md F-166, F-169, F-170, F-171):
## `colors` and `discover` of the actions of forging, woodwright and hearthcraft, the reagent at the end of the inputs of
## the scheme recipes, the 28 scheme recipes (data/items/recipes.json), the 12 reagents (data/items/reagents.json) and the
## `buy_recipe_*` / `buy_reagent_*` entries of data/shop/shop.json. Hand-written content is preserved. Idempotent.
## `--check` writes nothing and exits 1 if a file differs from the regenerated text.
##
## Usage: godot --headless --path . -s tools/gen_professions.gd [-- --check]

const SKILLS: Array[String] = ["forging", "woodwright", "hearthcraft"]
const ACTIONS_PATH: String = "res://data/actions/%s.json"
const RECIPES_PATH: String = "res://data/items/recipes.json"
const REAGENTS_PATH: String = "res://data/items/reagents.json"
const SHOP_PATH: String = "res://data/shop/shop.json"
const TRAINERS_PATH: String = "res://data/disciplines/trainers.json"
const BALANCE_PATH: String = "res://data/config/balance.json"
const ITEMS_DIR: String = "res://data/items"
const SHOP_MARKER: String = '    {"id":"buy_'
const MARKET_MARKER: String = '    {"id":"market_'
const SHOP_TAIL: String = "\n  ]\n}\n"

# F-166: colour thresholds above the level of a recipe (same distance as `encounters.colors`, F-154).
const YELLOW_OFFSET: int = 10
const GREEN_OFFSET: int = 20
const GREY_OFFSET: int = 30
# F-169: schemes from tier 2 up; the families of each skill by action id prefix and suffix.
const SCHEME_MIN_TIER: int = 2
const SCHEME_FAMILIES: Dictionary = {
	"forging": [["forge_", "_plate"]],
	"woodwright": [["carve_", "_shieldcore"], ["carve_", "_handle"]],
	"hearthcraft": [["cook_", ""]],
}
# F-170: price of a scheme.
const SCHEME_VALUE_MULT: int = 50
const SCHEME_MIN_GOLD: int = 100
# F-171: reagent bands (tiers) and prices, in percent.
const BAND_TIERS: Array = [[2, 3], [4, 5], [6, 7], [8, 8]]
const REAGENT_PRICE_PCT: int = 10
const REAGENT_VALUE_PCT: int = 25

const VERBS: Dictionary = {"forging": "forgiare", "woodwright": "intagliare", "hearthcraft": "cucinare"}
const SKILL_TAGS: Dictionary = {
	"forging": "macchiato dal fumo della forgia",
	"woodwright": "con la segatura ancora fra le pieghe",
	"hearthcraft": "unto di sugo e di fumo",
}
# Original texts, indexed by tier - 2 (tiers 2-8).
const LEADS: Array[String] = [
	"Un foglio spiegazzato", "Appunti fitti, scritti a carboncino", "Una tavoletta incisa con cura",
	"Un rotolo legato con filo d'argento", "Una pergamena scura, lucida come vetro", "Un foglio che scotta al tatto",
	"Un foglio attraversato da una luce sottile",
]
const REAGENT_NAMES: Dictionary = {
	"forging": ["Fondente di cenere", "Sale di tempra", "Limatura stellata", "Nucleo di brace"],
	"woodwright": ["Cera d'api", "Colla di ossa", "Olio di noce", "Lacca del vespro"],
	"hearthcraft": ["Sale grosso", "Erbe aromatiche", "Spezie di brace", "Aroma del Rift"],
}
const REAGENT_TEXTS: Dictionary = {
	"forging": [
		"Una manciata di polvere grigia che aiuta il metallo a fondersi senza bolle.",
		"Cristalli bianchi per la tempra: il metallo ne esce duro e senza crepe.",
		"Limatura fine che brilla come un cielo d'inverno e rende la lega più pulita.",
		"Un grumo caldo che non si spegne mai, usato per le forgiature più difficili.",
	],
	"woodwright": [
		"Un panetto giallo che rende scorrevoli le giunzioni del legno.",
		"Colla scura e tenace, cotta nel pentolino del falegname.",
		"Olio denso che nutre le fibre e le protegge dall'umidità.",
		"Una lacca scura che si stende nelle ore del vespro e asciuga lucida.",
	],
	"hearthcraft": [
		"Cristalli ruvidi per insaporire e conservare ogni piatto.",
		"Un mazzetto di erbe secche, legate con lo spago.",
		"Una polvere rossa e piccante, macinata sulla brace.",
		"Una goccia d'essenza dal profumo strano, che sa di nebbia e di ferro.",
	],
}
const REAGENT_ICONS: Dictionary = {
	"forging": ["iron_slag", "silver_flake", "obsidian_geode", "astrite_glow"],
	"woodwright": ["birch_resin", "whisper_resin", "rift_bark", "ebony_knot"],
	"hearthcraft": ["mint_leaf", "sage_bud", "lily_petal", "orchid_nectar"],
}
const SCHEME_ICON: String = "res://assets/icons/items/recipe_tonic_1.svg"


func _initialize() -> void:
	var outputs: Dictionary = build()
	var differs: PackedStringArray = []
	for path: String in outputs:
		var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if text != outputs[path]:
			differs.append(path)
	if OS.get_cmdline_user_args().has("--check"):
		print_rich("gen_professions: " + ("up to date" if differs.is_empty() else "OUT OF DATE (rerun tools/gen_professions.gd): %s" % ", ".join(differs)))
		quit(0 if differs.is_empty() else 1)
		return
	for path: String in differs:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(outputs[path] as String)
		file.close()
	print_rich("gen_professions: %s" % ("written: " + ", ".join(differs) if not differs.is_empty() else "unchanged"))
	quit(0)


## path -> full text of every generated file (a pure function of the data read from disk).
static func build() -> Dictionary:
	var out: Dictionary = {}
	var balance: Dictionary = _read(BALANCE_PATH)
	var levels: Array = ((balance["village"] as Dictionary)["woodwright_levels"]) as Array
	var values: Dictionary = _item_values()
	var names: Dictionary = _item_names()
	var vendors: Dictionary = _vendors()
	var docs: Dictionary = {}
	var schemes: Array[Dictionary] = []  # {action, skill, tier, level, product, scheme_gold}
	var recipe_items: Array = []
	var shop_rows: Array[String] = []
	var reagent_rows: Array[String] = []
	var band_min: Dictionary = {}  # "<skill>_<band>" -> smallest first-output value of the band's first tier
	for skill: String in SKILLS:
		var doc: Dictionary = _read(ACTIONS_PATH % skill)
		docs[skill] = doc
		for a: Dictionary in doc["actions"] as Array:
			if a.get("single", false):
				continue
			var level: int = int(a["level"])
			a["colors"] = {"yellow": level + YELLOW_OFFSET, "green": level + GREEN_OFFSET, "grey": level + GREY_OFFSET}
			var tier: int = levels.find(level) + 1
			if tier < SCHEME_MIN_TIER or not _is_scheme(skill, a["id"] as String):
				continue
			var band: int = _band_of(tier)
			a["discover"] = true
			var inputs: Array = a["inputs"] as Array
			var reagent: String = "reagent_%s_%d" % [skill, band + 1]
			if inputs.is_empty() or not str((inputs[inputs.size() - 1] as Dictionary)["item"]).begins_with("reagent_"):
				inputs.append({"item": reagent, "qty": 1})
			var product: String = str(((a["outputs"] as Array)[0] as Dictionary)["item"])
			schemes.append({"action": a, "skill": skill, "tier": tier, "level": level, "product": product, "band": band})
			var key: String = "%s_%d" % [skill, band]
			if tier == (BAND_TIERS[band] as Array)[0]:
				band_min[key] = mini(int(band_min.get(key, 1 << 30)), int(values[product]))
	for s: Dictionary in schemes:
		var a: Dictionary = s["action"] as Dictionary
		var skill: String = s["skill"] as String
		var aid: String = a["id"] as String
		var product_name: String = names[s["product"]] as String
		var scheme_name: String = "Schema: " + product_name
		var recipe_id: String = "recipe_" + aid
		var lead: String = LEADS[(s["tier"] as int) - SCHEME_MIN_TIER]
		var text: String = "%s, %s: insegna a %s %s." % [lead, SKILL_TAGS[skill], VERBS[skill], product_name.substr(0, 1).to_lower() + product_name.substr(1)]
		recipe_items.append(_item_row({"id": recipe_id, "name": scheme_name, "category": "recipe", "icon": SCHEME_ICON, "value": 0,
				"sort_order": 100 + SKILLS.find(skill) * 100 + (_count_of(schemes, skill, a) * 10), "description": text, "recipe": {"action": aid}}))
		var gold: int = maxi(SCHEME_MIN_GOLD, SCHEME_VALUE_MULT * int(values[s["product"]]))
		shop_rows.append("    " + JSON.stringify({"id": "buy_" + recipe_id, "name": scheme_name, "category": "profession",
				"vendor": vendors[skill], "description": "Si impara dal mercante e resta tua: serve un reagente a ogni lavoro.",
				"cost": {"gold": gold}, "max_purchases": 1, "requires": {"skills": {skill: s["level"]}},
				"effect": {"item": {"item": recipe_id, "qty": 1}}}, "", false))
	for skill: String in SKILLS:
		for band: int in 4:
			var item_id: String = "reagent_%s_%d" % [skill, band + 1]
			var m: int = int(band_min["%s_%d" % [skill, band]])
			var price: int = maxi(1, (m * REAGENT_PRICE_PCT + 50) / 100)
			var value: int = price * REAGENT_VALUE_PCT / 100
			var level: int = int(levels[(BAND_TIERS[band] as Array)[0] - 1])
			var rname: String = (REAGENT_NAMES[skill] as Array)[band] as String
			reagent_rows.append(_item_row({"id": item_id, "name": rname, "category": "reagent",
					"icon": "res://assets/icons/items/%s.svg" % (REAGENT_ICONS[skill] as Array)[band], "value": value,
					"sort_order": 10 + SKILLS.find(skill) * 100 + band * 10, "description": (REAGENT_TEXTS[skill] as Array)[band]}))
			shop_rows.append("    " + JSON.stringify({"id": "buy_" + item_id, "name": rname, "category": "profession",
					"vendor": vendors[skill], "description": "Un ingrediente per i lavori più delicati: se ne usa uno a ogni ciclo.",
					"cost": {"gold": price}, "max_purchases": 0, "requires": {"skills": {skill: level}},
					"effect": {"item": {"item": item_id, "qty": 1}}}, "", false))
	for skill: String in SKILLS:
		out[ACTIONS_PATH % skill] = _actions_text(docs[skill] as Dictionary)
	out[RECIPES_PATH] = _recipes_text(recipe_items, schemes)
	out[REAGENTS_PATH] = '{\n  "_doc": "Reagenti dei mercanti (04_DATA_SCHEMA_M26.md §31.3, F-171): generati da tools/gen_professions.gd, un ingrediente per ogni ricetta-schema, venduti solo dai mercanti.",\n  "items": [\n' + ",\n".join(reagent_rows) + "\n  ]\n}\n"
	out[SHOP_PATH] = _shop_text(shop_rows)
	return out


static func _is_scheme(skill: String, id: String) -> bool:
	for family: Array in SCHEME_FAMILIES[skill] as Array:
		if id.begins_with(family[0] as String) and id.ends_with(family[1] as String):
			return true
	return false


static func _band_of(tier: int) -> int:
	for band: int in BAND_TIERS.size():
		var bounds: Array = BAND_TIERS[band] as Array
		if tier >= int(bounds[0]) and tier <= int(bounds[1]):
			return band
	return -1


static func _actions_text(doc: Dictionary) -> String:
	var rows: PackedStringArray = []
	for a: Dictionary in doc["actions"] as Array:
		rows.append("    " + JSON.stringify(a, "", false))
	return '{\n  "_doc": %s,\n  "skill": %s,\n  "actions": [\n%s\n  ]\n}\n' % [JSON.stringify(doc["_doc"]), JSON.stringify(doc["skill"]), ",\n".join(rows)]


static func _recipes_text(scheme_rows: Array, schemes: Array[Dictionary]) -> String:
	var old: Dictionary = _read(RECIPES_PATH)
	var scheme_actions: Dictionary = {}
	for s: Dictionary in schemes:
		scheme_actions[(s["action"] as Dictionary)["id"]] = true
	var rows: PackedStringArray = []
	for item: Dictionary in old["items"] as Array:
		if not scheme_actions.has((item["recipe"] as Dictionary)["action"]):
			rows.append(_item_row(item))
	for row: String in scheme_rows:
		rows.append(row)
	var doc: String = "Ricette da imparare (04_DATA_SCHEMA_M24.md §29.4, 04_DATA_SCHEMA_M26.md §31.2): i Tonici cadono dalle tabelle di drop delle aree (tools/gen_areas.gd); gli schemi di piastre, anime, manici e cotture si comprano dai mercanti e sono generati da tools/gen_professions.gd. Nessuna si vende."
	return '{\n  "_doc": %s,\n  "items": [\n%s\n  ]\n}\n' % [JSON.stringify(doc), ",\n".join(rows)]


## An item on two lines (the description starts the second), as the existing item files.
static func _item_row(item: Dictionary) -> String:
	var head: PackedStringArray = []
	var tail: PackedStringArray = []
	var in_tail: bool = false
	for key: String in item:
		if key == "description":
			in_tail = true
		(tail if in_tail else head).append("%s: %s" % [JSON.stringify(key), JSON.stringify(item[key], "", false)])
	return "    {" + ", ".join(head) + ",\n     " + ", ".join(tail) + "}"


static func _shop_text(rows: Array[String]) -> String:
	var text: String = FileAccess.get_file_as_string(SHOP_PATH)
	var market: int = text.find(MARKET_MARKER)
	var first: int = text.find(SHOP_MARKER)
	if market < 0:
		push_error("gen_professions: no market entry in shop.json (run tools/gen_market.gd first)")
		return text
	var cut: int = first if first >= 0 and first < market else market
	return text.substr(0, cut) + ",\n".join(rows) + ",\n" + text.substr(market)


static func _vendors() -> Dictionary:
	var vendors: Dictionary = {}
	for t: Dictionary in _read(TRAINERS_PATH)["trainers"] as Array:
		if t.has("vendor"):
			vendors[t["skill"]] = t["vendor"]
	return vendors


static func _item_values() -> Dictionary:
	return _item_field("value")


static func _item_names() -> Dictionary:
	return _item_field("name")


static func _item_field(field: String) -> Dictionary:
	var result: Dictionary = {}
	for file_name: String in DirAccess.get_files_at(ITEMS_DIR):
		if not file_name.ends_with(".json") or file_name == "reagents.json" or file_name == "recipes.json":
			continue
		var doc: Dictionary = _read(ITEMS_DIR + "/" + file_name)
		for item: Variant in doc.get("items", []) as Array:
			if (item as Dictionary).has(field):
				result[(item as Dictionary)["id"]] = (item as Dictionary)[field]
	return result


static func _read(path: String) -> Dictionary:
	return _ints(JSON.parse_string(FileAccess.get_file_as_string(path))) as Dictionary


## JSON numbers parse as float: whole ones go back to int so that they are written without ".0".
static func _ints(v: Variant) -> Variant:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			(v as Dictionary)[k] = _ints((v as Dictionary)[k])
	elif v is Array:
		for i: int in (v as Array).size():
			(v as Array)[i] = _ints((v as Array)[i])
	elif v is float and is_equal_approx(floorf(v as float), v as float):
		return int(v as float)
	return v


## 1-based position of action `a` among the schemes of `skill`.
static func _count_of(schemes: Array[Dictionary], skill: String, a: Dictionary) -> int:
	var n: int = 0
	for s: Dictionary in schemes:
		if s["skill"] == skill:
			n += 1
		if s["action"] == a:
			return n
	return n
