extends SceneTree
## Adds the low-level Engraver content of M18-01 (V6, docs/02_FORMULAS.md §8.7): the Minor slab, its recipe and the three
## single-grade minor runes with their engraving recipes. Idempotent text patch: a row whose id is already in the file is
## skipped, the formatting of the rest of the file stays untouched. The output is committed: the game never runs this
## script. `--check` writes nothing and exits 1 if a row is missing.
##
## Usage: godot --headless --path . -s tools/gen_engraver_minor.gd [-- --check]

const ACTIONS_PATH: String = "res://data/actions/riftbinding.json"
const INFUSIONS_PATH: String = "res://data/items/infusions.json"
const MATERIALS_PATH: String = "res://data/items/materials.json"
const SLAB_ICON: String = "res://assets/icons/items/rune_slab.svg"

## id, name, level, xp, interval_ms, drop item, drop qty, stat, value, description
const RUNES: Array = [
	["inf_minor_vigor", "Runa minore del vigore", 2, 10, 3000, "scorched_fur", 3, "max_hp_flat", 10,
			"Un poco di vita massima in più."],
	["inf_minor_aim", "Runa minore della mira", 4, 16, 3000, "boar_tusk", 3, "accuracy_pct", 1,
			"Colpi un poco più precisi."],
	["inf_minor_guard", "Runa minore della guardia", 6, 24, 3500, "boar_tusk", 4, "armor", 4,
			"Un poco di armatura in più."],
]


func _init() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var missing: int = 0
	var slab_row: String = ('{"id":"make_minor_slab","name":"Preparare lastra minore","level":1,"interval_ms":2500,"xp":4,'
			+ '"mastery":true,"inputs":[{"item":"rift_dust","qty":2}],"outputs":[{"item":"minor_slab","qty":1}]}')
	missing += _patch(ACTIONS_PATH, "make_minor_slab", slab_row)
	missing += _patch(MATERIALS_PATH, "minor_slab",
			'{"id":"minor_slab","name":"Lastra minore","category":"material","icon":"%s","value":0,"sort_order":971,"description":"Una lastretta grezza: basta per incidere una runa minore."}' % SLAB_ICON)
	var order: int = 100
	for r: Array in RUNES:
		var recipe: String = ('{"id":"engrave_%s","name":"Incidere %s","level":%d,"interval_ms":%d,"xp":%d,"mastery":true,'
				+ '"inputs":[{"item":"minor_slab","qty":1},{"item":"%s","qty":%d}],"outputs":[{"item":"%s","qty":1}]}') % [
				String(r[0]).trim_prefix("inf_"), String(r[1]).to_lower(), r[2], r[4], r[3], r[5], r[6], r[0]]
		missing += _patch(ACTIONS_PATH, "engrave_" + String(r[0]).trim_prefix("inf_"), recipe)
		var item: String = ('{"id":"%s","name":"%s","category":"infusion","value":0,"sort_order":%d,"icon":"res://assets/icons/items/inf_swift_hands.svg",'
				+ '"description":"%s","infusion":{"modifiers":[{"stat":"%s","value":%s}],"unique":false,"grade":1,"family":"%s"}}') % [
				r[0], r[1], order, r[9], r[7], str(r[8]), r[0]]
		missing += _patch(INFUSIONS_PATH, String(r[0]), item)
		order += 10
	print_rich("%d rows %s" % [missing, "missing" if check_only else "added"])
	quit(1 if check_only and missing > 0 else 0)


## Inserts `row` as the last element of the "[ ... ]" list of `path` unless `id` is already there. Returns 1 if added.
func _patch(path: String, id: String, row: String) -> int:
	var text: String = FileAccess.get_file_as_string(path)
	if text.contains('"id":"%s"' % id):
		return 0
	if OS.get_cmdline_user_args().has("--check"):
		return 1
	var end: int = text.rfind("\n  ]")
	text = text.substr(0, end) + ",\n    " + row + text.substr(end)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return 1
