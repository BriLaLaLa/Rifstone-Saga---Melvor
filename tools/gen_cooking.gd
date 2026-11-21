extends SceneTree
## M32-03: adds the meat of the Cucina (raw materials, cooked food, `cook_*` recipes, placeholder icons). Idempotent.
## Usage: godot --headless --path . -s tools/gen_cooking.gd
## Raw: [id, name, description, cooked name, colour]; level, heal, cooked value come from docs/M32_CIBO.md (decisions 2-3).
const MEAT: Array = [
	["plains_haunch", "Cosciotto di pianura", "Carne cruda e scura di bestia delle Pianure, ancora da cuocere.", "Cosciotto arrostito", "#b5583c"],
	["wood_venison", "Selvaggina del bosco", "Carne cruda di lupo, ragno o cervo del Bosco dei Sussurri.", "Spiedo di selvaggina", "#9c6b45"],
	["upland_game", "Carne d'altopiano", "Carne cruda e magra, secca come il vento degli Altipiani.", "Spezzatino d'altopiano", "#c98a4b"],
	["gallery_game", "Carne di galleria", "Carne cruda di creatura delle miniere, dura e salata.", "Brasato di galleria", "#8a6d6d"],
	["marsh_fowl", "Volatile di palude", "Carne cruda e grassa di uccello e bestia delle Paludi di Cenere.", "Volatile di palude arrosto", "#a89a7a"],
	["scorpion_pulp", "Polpa di scorpione", "Polpa cruda e chiara, estratta da sotto il guscio di vetro.", "Scorpione croccante", "#d8a0b0"],
	["hound_cut", "Taglio del varco", "Carne cruda e scura di bestia uscita dalla Soglia del Rift.", "Bistecca del varco", "#7a4a8a"],
	["serpent_fillet", "Filetto di serpe", "Filetto crudo e lucido di serpe del Deserto di Vetro Nero.", "Filetto di serpe glassato", "#4a6a6a"],
	["coral_tentacle", "Tentacolo di corallo", "Tentacolo crudo e gommoso, ancora pieno d'acqua salmastra.", "Tentacolo grigliato", "#d06a5a"],
	["leech_pulp", "Polpa del battito", "Polpa cruda che pulsa piano, come se avesse ancora un cuore.", "Stufato del battito", "#c0305a"],
]
const LEVELS: Array[int] = [1, 10, 20, 30, 40, 50, 60, 70, 80, 90]
const HEALS: Array[int] = [20, 35, 55, 80, 95, 123, 150, 183, 220, 260]
const COOKED_VALUE: Array[int] = [200, 600, 1200, 2000, 3000, 4600, 6000, 8200, 12000, 17000]
const FISH_XP: Array = [[1, 9], [10, 16], [20, 25], [30, 36], [45, 52], [60, 72], [75, 97], [90, 130]]
const ICON_DIR: String = "res://assets/icons/items/"


func _init() -> void:
	var mats: String = FileAccess.get_file_as_string("res://data/items/materials.json")
	var food: String = FileAccess.get_file_as_string("res://data/items/food.json")
	var acts: String = FileAccess.get_file_as_string("res://data/actions/hearthcraft.json")
	var mat_lines: Array[String] = []
	var food_lines: Array[String] = []
	var act_lines: Array[String] = []
	for i: int in MEAT.size():
		var m: Array = MEAT[i]
		var id: String = m[0]
		var cooked: String = "cooked_" + id
		var lvl: int = LEVELS[i]
		mat_lines.append(JSON.stringify({"id": id, "name": m[1], "category": "material", "icon": ICON_DIR + id + ".svg",
			"value": COOKED_VALUE[i] / 2, "sort_order": 1101 + i, "description": m[2]}, "", false))
		food_lines.append(JSON.stringify({"id": cooked, "name": m[3], "category": "food", "icon": ICON_DIR + cooked + ".svg",
			"value": COOKED_VALUE[i], "sort_order": 210 + i * 10, "description": "Cura %d punti vita." % HEALS[i],
			"food": {"heal": HEALS[i]}}, "", false))
		var inputs: Array = [{"item": id, "qty": 1}]
		if lvl >= 10:
			inputs.append({"item": "reagent_hearthcraft_%d" % (1 if lvl <= 20 else 2 if lvl <= 40 else 3 if lvl <= 70 else 4), "qty": 1})
		act_lines.append(JSON.stringify({"id": "cook_" + id, "name": "Cucinare " + (m[1] as String).to_lower(), "level": lvl,
			"interval_ms": 2500, "xp": _xp(lvl), "mastery": true, "inputs": inputs, "outputs": [{"item": cooked, "qty": 1}],
			"colors": {"yellow": lvl + 10, "green": lvl + 20, "grey": lvl + 30}}, "", false))
		_icon(id, m[4], false)
		_icon(cooked, m[4], true)
	if not mats.contains("\"plains_haunch\""):
		_write("res://data/items/materials.json", _append(mats, mat_lines))
	if not food.contains("cooked_plains_haunch"):
		_write("res://data/items/food.json", _append(food, food_lines))
	if not acts.contains("cook_plains_haunch"):
		var at: int = acts.find("    {\"id\":\"brew_tonic_1\"")
		var block: String = ""
		for l: String in act_lines:
			block += "    " + l + ",\n"
		_write("res://data/actions/hearthcraft.json", acts.substr(0, at) + block + acts.substr(at))
	print("gen_cooking: done")
	quit(0)


func _xp(level: int) -> int:
	for k: int in range(FISH_XP.size() - 1):
		var a: Array = FISH_XP[k]
		var b: Array = FISH_XP[k + 1]
		if level <= int(b[0]):
			return roundi(float(a[1]) + float(int(b[1]) - int(a[1])) * float(level - int(a[0])) / float(int(b[0]) - int(a[0])))
	return int((FISH_XP[-1] as Array)[1])


func _append(text: String, lines: Array[String]) -> String:
	var at: int = text.rfind("\n  ]\n}")
	var body: String = ""
	for l: String in lines:
		body += ",\n    " + l
	return text.substr(0, at) + body + text.substr(at)


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Placeholder icon: raw = ellipse of the colour, cooked = the same on a plate.
func _icon(id: String, color: String, cooked: bool) -> void:
	var body: String
	if cooked:
		body = "<circle cx=\"32\" cy=\"34\" r=\"26\" fill=\"#d8d2c4\" stroke=\"#000000\" stroke-opacity=\"0.35\" stroke-width=\"2\"/>\n  <ellipse cx=\"32\" cy=\"32\" rx=\"16\" ry=\"11\" fill=\"%s\"/>\n  <ellipse cx=\"32\" cy=\"32\" rx=\"16\" ry=\"11\" fill=\"#3a2418\" fill-opacity=\"0.4\"/>" % color
	else:
		body = "<ellipse cx=\"32\" cy=\"34\" rx=\"22\" ry=\"14\" fill=\"%s\" stroke=\"#000000\" stroke-opacity=\"0.35\" stroke-width=\"2\"/>\n  <circle cx=\"20\" cy=\"30\" r=\"4\" fill=\"#ffffff\" fill-opacity=\"0.6\"/>" % color
	_write(ICON_DIR + id + ".svg", "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 64 64\">\n  %s\n</svg>\n" % body)
