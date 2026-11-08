extends GutTest
## Visible names of the real data against docs/NOMI.md (Q52: ids never change, only `name`). Also no "Bank" in any
## visible text of data/ (the UI says "Deposito").

const GRADE_IDS: Array[String] = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar",
	"emberheart", "riftite"]
const WOOD_IDS: Array[String] = ["redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress",
	"emberlarch", "riftspruce"]
const FISH_IDS: Array[String] = ["brookfin", "ashgill", "redscale", "dusk_eel", "shard_gar", "mist_barbel",
	"ember_sturgeon", "riftmaw"]
const METALS: Array[String] = ["rame", "ferro", "acciaio", "acciaio nero", "argento runico", "ossidiana", "astrite",
	"riftite"]
const ORES: Array[String] = ["rame", "ferro", "ferro scuro", "ferro nero", "argento runico", "ossidiana", "astrite",
	"riftite"]
const WOODS: Array[String] = ["betulla", "pino", "quercia", "olmo", "tasso", "ebano", "legno ardente", "legno del Rift"]
const LOGS: Array[String] = ["Legno di betulla", "Legno di pino", "Legno di quercia", "Legno di olmo", "Legno di tasso",
	"Legno di ebano", "Legno ardente", "Legno del Rift"]
const FISH: Array[String] = ["Trota", "Persico", "Carpa", "Luccio", "Anguilla", "Storione", "Pesce lanterna",
	"Leviatano del Rift"]
const COOKED: Array[String] = ["Trota alla griglia", "Persico arrosto", "Carpa affumicata", "Luccio al forno",
	"Anguilla glassata", "Storione in crosta", "Pesce lanterna laccato", "Stufato di leviatano"]
const MODELS: Dictionary = {
	"sword": ["Spada corta", "Gladio", "Sciabola", "Spada lunga", "Lama runica", "Falce d'ossidiana", "Lama stellare",
		"Lama del Rift"],
	"greatsword": ["Spadone grezzo", "Montante", "Flamberga", "Claymore", "Spadone runico", "Spezzaferro",
		"Mietitore d'astrite", "Giudizio del Rift"],
	"shield": ["Rotella", "Brocchiere", "Scudo a goccia", "Scudo torre", "Pavese runico", "Egida d'ossidiana",
		"Scudo stellare", "Bastione del Rift"],
	"helm": ["Calotta", "Elmetto", "Barbuta", "Celata", "Elmo runico", "Elmo d'ossidiana", "Corona d'astrite",
		"Visiera del Rift"],
	"cuirass": ["Giaco", "Cotta di maglia", "Corazza", "Usbergo", "Corazza runica", "Corazza d'ossidiana",
		"Armatura stellare", "Corazza del Rift"],
	"greaves": ["Brache imbottite", "Cosciali", "Gambali di maglia", "Gambali a piastre", "Gambali runici",
		"Gambali d'ossidiana", "Gambali stellari", "Gambali del Rift"],
	"boots": ["Stivali di cuoio", "Stivali chiodati", "Calzari", "Schinieri", "Stivali runici", "Stivali d'ossidiana",
		"Passi stellari", "Stivali del Rift"],
	"gauntlets": ["Guanti di cuoio", "Guanti di maglia", "Manopole", "Guanti a piastre", "Guanti runici",
		"Manopole d'ossidiana", "Artigli stellari", "Guanti del Rift"],
	"ring": ["Fede di rame", "Anello di ferro", "Anello d'argento", "Anello con sigillo", "Anello runico",
		"Anello d'ossidiana", "Anello stellare", "Anello del Rift"],
	"amulet": ["Ciondolo", "Medaglione", "Talismano", "Amuleto", "Amuleto runico", "Amuleto d'ossidiana",
		"Stella d'astrite", "Occhio del Rift"],
}
## Fixed names by id (skills, class, areas, monsters, drops, traits, abilities, stones, currencies, infusions, shop).
const FIXED: Dictionary = {
	"forestry": "Boscaiolo", "quarrying": "Minatore", "angling": "Pescatore", "forging": "Fabbro",
	"hearthcraft": "Cuoco", "woodwright": "Falegname", "riftbinding": "Legatura del Rift", "rift_blade": "Spadaccino",
	"redrock_plains": "Pianure di Roccarossa", "whisper_wood": "Bosco dei Sussurri",
	"cracked_mines": "Miniere Abbandonate", "rift_threshold": "Soglia del Rift",
	"plains_boar": "Cinghiale", "ember_rat": "Ratto rosso", "redrock_raider": "Predone", "whisper_wolf": "Lupo grigio",
	"moss_troll": "Troll del bosco", "hollow_archer": "Bracconiere", "crack_golem": "Golem di pietra",
	"deep_crawler": "Ragno delle gallerie", "vein_witch": "Strega della miniera", "shard_wraith": "Spettro cristallino",
	"rift_knight": "Cavaliere caduto", "riftborn_colossus": "Colosso del Rift",
	"boar_tusk": "Zanna di cinghiale", "scorched_fur": "Pelliccia di ratto", "raider_bandage": "Benda del predone",
	"redrock_flint": "Selce di Roccarossa", "wolf_fang": "Zanna di lupo", "troll_moss": "Muschio di troll",
	"hollow_arrowhead": "Punta di freccia", "whisper_resin": "Resina del bosco", "golem_core": "Nucleo di golem",
	"crawler_carapace": "Chitina di ragno", "witch_charm": "Feticcio della strega", "mine_dust": "Polvere di miniera",
	"wraith_veil": "Velo dello spettro", "knight_plate": "Placca del caduto", "colossus_shard": "Scheggia di colosso",
	"threshold_ash": "Cenere della Soglia", "rift_shard": "Frammento del Rift", "warding_seal": "Sigillo di protezione",
	"chain_cleave": "Fendente a catena", "first_blood": "Primo sangue", "hunters_eye": "Occhio del cacciatore",
	"last_stand": "Ultimo bastione", "stone_stance": "Postura di roccia", "glass_edge": "Lama di vetro",
	"rift_thorns": "Spine del Rift", "cornered_fury": "Furia alle strette", "giant_breaker": "Spezzagiganti",
	"greedy_fangs": "Zanne fameliche", "ember_thirst": "Sete di sangue", "blood_ember": "Linfa vitale",
	"whirl": "Mulinello", "shield_bash": "Colpo di scudo", "twin_frenzy": "Frenesia gemella",
	"blade_volley": "Raffica di lame", "rift_maul": "Colpo spaccaossa", "ember_breath": "Seconda forza",
	"stone_ember_chip": "Scheggia di furia", "stone_ember_stone": "Pietra di furia", "stone_ember_heart": "Cuore di furia",
	"stone_eye_chip": "Scheggia di precisione", "stone_eye_stone": "Pietra di precisione",
	"stone_eye_heart": "Cuore di precisione", "stone_shade_chip": "Scheggia d'ombra",
	"stone_shade_stone": "Pietra d'ombra", "stone_shade_heart": "Cuore d'ombra", "stone_root_chip": "Scheggia di roccia",
	"stone_root_stone": "Pietra di roccia", "stone_root_heart": "Cuore di roccia",
	"currency_spark": "Scintilla del Rift", "currency_flux": "Sabbia del mutamento", "currency_crown": "Essenza del Rift",
	"inf_swift_hands": "Runa della rapidità", "inf_bountiful": "Runa dell'abbondanza",
	"inf_scholar": "Runa della sapienza", "inf_keen_edge": "Runa della precisione",
	"inf_stoneskin": "Runa della pelle di pietra", "inf_deep_roots": "Runa della pazienza",
	"inf_hearthfire": "Runa del banchetto", "inf_riftsense": "Runa del senso del Rift",
	"inf_bulwark": "Runa del baluardo",
	"auto_eat_1": "Razioni da campo I",
	"auto_eat_2": "Razioni da campo II", "auto_eat_3": "Razioni da campo III",
	"auto_loot": "Raccolta automatica del bottino", "loot_pocket": "Tasca della borsa",
	"unique_hatchet": "Accetta", "unique_pick": "Piccone", "unique_rod": "Canna da pesca",
}

var _names: Dictionary = {}
var _texts: Array[String] = []


func before_all() -> void:
	_collect("res://data")


func _collect(dir_path: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub))
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".json"):
			_walk(JSON.parse_string(FileAccess.get_file_as_string(dir_path.path_join(file))))


func _walk(node: Variant) -> void:
	if node is Dictionary:
		var d: Dictionary = node
		if d.get("id") is String and d.get("name") is String and not _names.has(d["id"]):
			_names[d["id"]] = d["name"]
		for key: String in ["name", "description", "title", "text"]:
			if d.get(key) is String:
				_texts.append(d[key] as String)
		for v: Variant in d.values():
			_walk(v)
	elif node is Array:
		for v: Variant in node:
			_walk(v)


func _expect(id: String, expected: String) -> void:
	assert_true(_names.has(id), "id %s exists" % id)
	assert_eq(_names.get(id, ""), expected, "name of %s" % id)


func test_fixed_names() -> void:
	for id: String in FIXED:
		_expect(id, FIXED[id] as String)


func test_metal_grades() -> void:
	for i: int in 8:
		var g: String = GRADE_IDS[i]
		_expect(g + "_ore", "Minerale di " + ORES[i])
		_expect(g + "_ingot", "Lingotto di " + METALS[i])
		_expect(g + "_plate", "Piastra di " + METALS[i])


func test_wood_grades() -> void:
	for i: int in 8:
		var w: String = WOOD_IDS[i]
		_expect(w + "_log", LOGS[i])
		_expect(w + "_grip", "Impugnatura di " + WOODS[i])
		_expect(w + "_shieldcore", "Telaio di scudo in " + WOODS[i])
		_expect(w + "_handle", "Manico di " + WOODS[i])


func test_fish_grades() -> void:
	for i: int in 8:
		_expect(FISH_IDS[i], FISH[i])
		_expect("seared_" + FISH_IDS[i], COOKED[i])


func test_equipment_models_and_blueprints() -> void:
	for slot: String in MODELS:
		var models: Array = MODELS[slot]
		for i: int in 8:
			_expect(GRADE_IDS[i] + "_" + slot, models[i] as String)
			var bp_id: String = "bp_%s_%s" % [GRADE_IDS[i], slot]
			if _names.has(bp_id):
				assert_eq(_names[bp_id], "Progetto: " + (models[i] as String), "name of %s" % bp_id)


func test_no_bank_in_visible_texts() -> void:
	var re: RegEx = RegEx.create_from_string("(?i)\\bbank\\b|\\bbanca\\b")
	for text: String in _texts:
		assert_null(re.search(text), "no 'Bank' in: %s" % text)
