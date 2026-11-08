extends GutTest
## No old name is left in the texts of the UI (M12-06, docs/NOMI.md "Riforma 2"): the code and scenes of `res://ui`,
## the hand-written Guide and the hints. Comment lines are skipped (they may quote the old names as history).

const ROOTS: Array[String] = ["res://ui", "res://data/guide", "res://data/hints"]
const EXTENSIONS: Array[String] = ["gd", "tscn", "json"]
const OLD_NAMES: Array[String] = [
	"Legatura del Rift", "Pietra del Rift", "Pietre del Rift", "Scintilla del Rift", "Sabbia del mutamento",
	"Essenza del Rift", "Spazio nel deposito", "Spazio nell'armeria", "Spazio nell'Armeria", "Cuore di ",
	"Scheggia di furia", "Pietra di furia", "di furia", "d'ombra", "di roccia", "comprabil", "acquistabil",
]


func test_no_old_name_in_the_visible_texts() -> void:
	var offences: PackedStringArray = []
	for root: String in ROOTS:
		for path: String in _files(root):
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for index: int in lines.size():
				var line: String = lines[index]
				if line.strip_edges().begins_with("#"):
					continue
				for old: String in OLD_NAMES:
					if line.contains(old):
						offences.append("%s:%d '%s'" % [path, index + 1, old])
	assert_eq(offences, PackedStringArray(), "old names still in the UI texts")


func test_the_names_of_the_riforma_are_in_the_data() -> void:
	var data: GameData = TestFactory.real_data()
	assert_eq(data.skill(&"riftbinding").name, "Incisore")
	assert_eq(data.item(&"currency_spark").name, "Cristallo del risveglio")
	assert_eq(data.item(&"rift_dust").name, "Polvere del Rift")
	assert_eq(CombatTexts.STATE_TEXTS[CombatEngine.STATE_RIFTSTONE], "Monolito del Rift")
	assert_eq(EnemyView.STONE_TAG_TEXT, "Monolito del Rift")


func _files(root: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file: String in DirAccess.get_files_at(root):
		if EXTENSIONS.has(file.get_extension()):
			result.append(root.path_join(file))
	for dir: String in DirAccess.get_directories_at(root):
		result.append_array(_files(root.path_join(dir)))
	return result
