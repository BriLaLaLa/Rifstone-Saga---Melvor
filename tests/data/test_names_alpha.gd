extends GutTest
## M14-05: the visible names of the Alpha in the real data against docs/NOMI.md (section "Alpha"): the 15 grades of weapons,
## rings and amulets, the armour by material and epithet, the Masterworks and their blueprints, the 39 legendaries with
## their sources, the affix "Schermato"; no name of another game; no duplicate name among the pieces.

const EPITHETS: Array[String] = ["del Novizio", "del Garzone", "del Fante", "del Mercenario", "del Soldato", "del Veterano",
	"del Capitano", "del Campione", "del Cavaliere", "del Condottiero", "della Brace Antica", "dell'Alba Spezzata",
	"dell'Eclissi", "dell'Abisso Stellato", "del Primo Rift"]
const MARKS: Array[String] = ["di Fucina Prima", "di Ferrovivo", "di Roccamartello", "di Valleincudine", "di Brace Fedele",
	"di Forgia Alta", "di Cenere Bianca", "di Torre Nera", "di Sole Battuto", "di Luna Forgiata", "di Fiamma Eterna",
	"di Stella Domata", "di Eclissi Vinta", "di Abisso Domato", "di Rift Domato"]
const TYPES: Dictionary = {
	"plate": {"head": "Elmo", "body": "Corazza", "legs": "Cosciali", "feet": "Schinieri", "hands": "Manopole", "shield": "Scudo"},
	"leather": {"head": "Cappuccio", "body": "Giubba", "legs": "Calzoni", "feet": "Stivali", "hands": "Guanti", "shield": "Rotella"},
	"cloth": {"head": "Cappello runico", "body": "Veste runica", "legs": "Brache runiche", "feet": "Sandali runici",
		"hands": "Mitene runiche", "shield": "Sigillo runico"},
}
const MASTER_TYPES: Dictionary = {"sword": "Lama", "greatsword": "Spadone", "shield": "Scudo", "head": "Elmo", "body": "Corazza",
	"legs": "Cosciali", "feet": "Schinieri", "hands": "Manopole"}
const MODELS: Dictionary = {
	"sword": ["Spada d'addestramento", "Spada corta", "Gladio", "Sciabola", "Spada lunga", "Squarcina", "Spada d'ordinanza",
		"Lama del Cavaliere", "Fendente", "Lama temprata", "Lama della Brace Antica", "Lama dell'Alba Spezzata",
		"Lama dell'Eclissi", "Lama dell'Abisso", "Lama del Primo Rift"],
	"greatsword": ["Spadone grezzo", "Mandritto", "Montante", "Flamberga", "Claymore", "Spezzaferro", "Falciatore",
		"Spadone del Campione", "Mietitore", "Spaccaelmi", "Spadone della Brace Antica", "Spadone dell'Alba Spezzata",
		"Spadone dell'Eclissi", "Spadone dell'Abisso", "Giudizio del Primo Rift"],
	"ring": ["Fede di rame", "Anello di ferro", "Anello di bronzo", "Anello d'argento", "Anello con sigillo", "Anello d'oro",
		"Anello del Capitano", "Anello d'ossidiana", "Anello di giada", "Anello del Condottiero", "Anello della Brace Antica",
		"Anello dell'Alba Spezzata", "Anello dell'Eclissi", "Anello dell'Abisso", "Anello del Primo Rift"],
	"neck": ["Ciondolo", "Medaglione", "Talismano", "Amuleto", "Monile", "Pendente", "Collana del Capitano", "Collare",
		"Amuleto del Cavaliere", "Reliquia", "Amuleto della Brace Antica", "Amuleto dell'Alba Spezzata", "Amuleto dell'Eclissi",
		"Amuleto dell'Abisso", "Occhio del Primo Rift"],
}
## Legendary name -> [source id (boss or Monolith)].
const LEGENDARIES: Dictionary = {
	"Cimiero del Cinghiale Bianco": "boss_grade_1", "Zoccoli del Gran Cinghiale": "boss_grade_1", "Zanna d'Argento": "boss_grade_1",
	"Pelliccia di Cenere": "boss_grade_2", "Artigli del Capobranco": "boss_grade_2", "Zanna Grigia": "boss_grade_2",
	"Cosciali del Fango Antico": "boss_grade_3", "Talismano della Palude": "boss_grade_3", "Spaccapalude": "boss_grade_3",
	"Passi del Cavaliere Anonimo": "boss_grade_4", "Sigillo Senza Nome": "boss_grade_4", "Scudo del Giuramento Spezzato": "boss_grade_4",
	"Guanti del Custode": "boss_grade_5", "Brace Custode": "boss_grade_5", "Cappuccio della Fucina Spenta": "boss_grade_5",
	"Amuleto delle Vene Nere": "boss_grade_6", "Mietitore di Vene": "boss_grade_6", "Giubba della Strega": "boss_grade_6",
	"Anello della Guglia Spezzata": "boss_grade_7", "Rotella del Guardiano": "boss_grade_7", "Calzoni del Vento Alto": "boss_grade_7",
	"Scheggia di Ossidiana Viva": "boss_grade_8", "Cappello dell'Occhio Vitreo": "boss_grade_8", "Sandali del Colosso Lieve": "boss_grade_8",
	"Annuncio dell'Eclissi": "boss_grade_9", "Veste dell'Araldo": "boss_grade_9", "Mitene dell'Ombra Lunga": "boss_grade_9",
	"Sigillo del Primo Frammento": "boss_grade_10", "Brache dell'Origine": "boss_grade_10", "Frammento Originario": "boss_grade_10",
	"Accetta del Taglialegna Paziente": "redrock_stone", "Canna del Pescatore Sereno": "redrock_stone",
	"Accetta della Radura Cantante": "whisper_stone", "Piccone del Cercatore": "whisper_stone",
	"Piccone della Vena Profonda": "mine_stone", "Canna dei Pozzi Neri": "mine_stone",
	"Accetta del Bosco Perduto": "threshold_stone", "Piccone dell'Ultima Galleria": "threshold_stone",
	"Canna del Leviatano Dormiente": "threshold_stone",
}
## Names of other games that must not appear (clean room): fragments, lower case.
const FORBIDDEN: Array[String] = ["melvor", "metin", "path of exile", "excalibur", "mithril", "adamant", "scimitar", "rune sword",
	"dragon", "drago", "atlantis", "hearthstone", "diablo", "warcraft", "zelda", "skyrim", "elden"]

var _data: GameData = null
var _by_name: Dictionary = {}
var _models: Dictionary = {}
var _masterworks: Dictionary = {}


func before_all() -> void:
	_data = GameData.load_from_dirs()
	for item: ItemDef in _data.items():
		if item.category != &"equipment":
			continue
		var kind: String = String(item.equip.kind) if item.equip.kind != &"" else String(item.equip.slot)
		var key: String = "%s:%s:%d" % [kind, String(item.equip.material), item.equip.grade]
		if item.equip.masterwork:
			_masterworks[key] = item
		elif item.equip.legendary == null:
			_models[key] = item


func _name_of(table: Dictionary, key: String) -> String:
	var item: ItemDef = table.get(key)
	assert_not_null(item, "item %s" % key)
	return item.name if item != null else ""


func test_weapons_rings_and_amulets_of_the_15_grades() -> void:
	for kind: String in MODELS:
		for g: int in range(1, 16):
			assert_eq(_name_of(_models, "%s::%d" % [kind, g]), (MODELS[kind] as Array)[g - 1], "%s grade %d" % [kind, g])


func test_armour_is_the_type_of_the_material_plus_the_epithet() -> void:
	for material: String in TYPES:
		for slot: String in TYPES[material]:
			for g: int in range(1, 16):
				var want: String = "%s %s" % [TYPES[material][slot], EPITHETS[g - 1]]
				assert_eq(_name_of(_models, "%s:%s:%d" % [slot, material, g]), want, "%s %s %d" % [slot, material, g])


func test_masterworks_are_the_type_plus_the_mark_and_the_blueprint_follows() -> void:
	for slot: String in MASTER_TYPES:
		for g: int in range(1, 16):
			var key: String = "%s:%s:%d" % [slot, "" if slot in ["sword", "greatsword"] else "plate", g]
			var item: ItemDef = _masterworks.get(key)
			assert_not_null(item, key)
			if item == null:
				continue
			assert_eq(item.name, "%s %s" % [MASTER_TYPES[slot], MARKS[g - 1]], key)
			assert_eq(_data.blueprint_for_base(item.id).name, "Progetto: " + item.name, key)
	assert_eq(_name_of(_masterworks, "body:plate:11"), "Corazza di Fiamma Eterna")
	assert_eq(_name_of(_masterworks, "greatsword::15"), "Spadone di Rift Domato")
	assert_eq(_name_of(_masterworks, "shield:plate:10"), "Scudo di Luna Forgiata")


func test_the_39_legendaries_have_their_names_and_sources() -> void:
	var found: Dictionary = {}
	for item: ItemDef in _data.legendaries():
		found[item.name] = String(item.equip.legendary.source_id)
	assert_eq(found.size(), 39)
	for legendary_name: String in LEGENDARIES:
		assert_true(found.has(legendary_name), "legendary %s" % legendary_name)
		assert_eq(found.get(legendary_name, ""), LEGENDARIES[legendary_name], "source of %s" % legendary_name)


func test_no_two_pieces_share_a_name_and_no_name_of_another_game() -> void:
	var seen: Dictionary = {}
	for item: ItemDef in _data.items():
		if item.category != &"equipment" and item.category != &"tool" and item.category != &"blueprint":
			continue
		assert_false(seen.has(item.name), "duplicate name %s (%s and %s)" % [item.name, seen.get(item.name), item.id])
		seen[item.name] = item.id
		var lower: String = (item.name + " " + item.description).to_lower()
		for fragment: String in FORBIDDEN:
			assert_false(lower.contains(fragment), "%s contains '%s'" % [item.id, fragment])


func test_the_new_affix_is_called_schermato() -> void:
	var affixes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/affixes/affixes.json")) as Dictionary
	var names: Dictionary = {}
	for a: Dictionary in affixes["affixes"]:
		names[a["id"]] = a["name"]
	assert_eq(names["runeward"], "Schermato")
	assert_eq(names["warded"], "Protetto")
