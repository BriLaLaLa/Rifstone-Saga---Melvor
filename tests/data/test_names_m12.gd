extends GutTest
## Visible names of the Riforma 2 in the real data against docs/NOMI.md (section Riforma 2): the Engraver, Rift Dust and
## Rune Slab, the Crystals, the stones, the bags, the contracts, the runes by grade, the Monoliti del Rift; and no old name
## in any text of data/.

const OLD_NAMES: PackedStringArray = ["Legatura del Rift", "Scintilla del Rift", "Sabbia del mutamento", "Essenza del Rift",
	"Cuore di", "Cuore d'", "Pietra del Rift", "Pietre del Rift", "Pietra di furia", "Pietra d'ombra", "Pietra di roccia"]
const FIXED: Dictionary = {
	"riftbinding": "Incisore", "rift_dust": "Polvere del Rift", "rune_slab": "Lastra runica",
	"currency_spark": "Cristallo del risveglio", "currency_crown": "Cristallo dell'ascesa", "currency_flux": "Cristallo del mutamento",
	"bag_canvas": "Borsa di tela", "bag_leather": "Borsa di cuoio", "bag_reinforced": "Borsa rinforzata",
	"bag_wayfarer": "Borsa del viandante", "bag_runic": "Borsa runica",
	"redrock_stone": "Monolito di Roccarossa", "whisper_stone": "Monolito dei Sussurri", "mine_stone": "Monolito delle Miniere",
	"threshold_stone": "Monolito della Soglia",
	"contract_forestry_journeyman": "Contratto: Garzone boscaiolo", "contract_quarrying_apprentice": "Contratto: Apprendista minatore",
	"contract_angling_expert": "Contratto: Esperto pescatore", "contract_forestry_master": "Contratto: Maestro boscaiolo",
	"stone_ember_heart": "Pietra perfetta di forza", "stone_eye_chip": "Scheggia di precisione",
	"stone_shade_stone": "Pietra di agilità", "stone_root_heart": "Pietra perfetta di tempra",
}
const RUNES: Dictionary = {"inf_swift_hands": "Runa della rapidità", "inf_bountiful": "Runa dell'abbondanza",
	"inf_scholar": "Runa della sapienza", "inf_keen_edge": "Runa della precisione", "inf_stoneskin": "Runa della pelle di pietra",
	"inf_deep_roots": "Runa della pazienza", "inf_hearthfire": "Runa del banchetto", "inf_riftsense": "Runa del senso del Rift",
	"inf_bulwark": "Runa del baluardo"}
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

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


func test_fixed_names() -> void:
	for id: String in FIXED:
		assert_eq(_names.get(id, ""), FIXED[id] as String, "name of %s" % id)


func test_rune_names_by_grade() -> void:
	for id: String in RUNES:
		for grade: int in 5:
			var rune_id: String = id if grade == 0 else "%s_%d" % [id, grade + 1]
			assert_eq(_names.get(rune_id, ""), "%s %s" % [RUNES[id], ROMAN[grade]], "name of %s" % rune_id)


func test_stone_names_by_family() -> void:
	var families: Dictionary = {"ember": "forza", "eye": "precisione", "shade": "agilità", "root": "tempra"}
	for family: String in families:
		assert_eq(_names.get("stone_%s_chip" % family), "Scheggia di %s" % families[family])
		assert_eq(_names.get("stone_%s_stone" % family), "Pietra di %s" % families[family])
		assert_eq(_names.get("stone_%s_heart" % family), "Pietra perfetta di %s" % families[family])


func test_no_old_name_in_any_text() -> void:
	for text: String in _texts:
		for old: String in OLD_NAMES:
			assert_false(text.contains(old), "'%s' in: %s" % [old, text])
