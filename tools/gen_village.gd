extends SceneTree
## Generates the `levels` of data/village/buildings.json (M19-02, docs/02_FORMULAS.md F-131/F-132, docs/04_DATA_SCHEMA.md §24).
## Reads balance.json `village` and the hand-written parts of every building (id, name, description, icon, order,
## buildable, milestone, effect, cost_spec) and rewrites the file with the levels of DataValidatorVillage.levels_for.
## Idempotent: rerunning it does not change the file. Fails (exit 1, nothing written) if an item of a level does not
## exist in data/items/. The output is committed: the game never runs this script. `--check` writes nothing and exits 1
## if the file differs from the generated text.
##
## Usage: godot --headless --path . -s tools/gen_village.gd [-- --check]

const BALANCE_PATH: String = "res://data/config/balance.json"
const BUILDINGS_PATH: String = "res://data/village/buildings.json"
const ITEMS_DIR: String = "res://data/items"
const VALIDATOR_PATH: String = "res://core/data/data_validator_village.gd"


func _initialize() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH)) as Dictionary
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUILDINGS_PATH)) as Dictionary
	var result: Dictionary = generate(source, balance["village"] as Dictionary, item_ids())
	for message: String in result["errors"] as PackedStringArray:
		printerr("gen_village: " + message)
	if not (result["errors"] as PackedStringArray).is_empty():
		quit(1)
		return
	var text: String = result["text"] as String
	var current: String = FileAccess.get_file_as_string(BUILDINGS_PATH)
	if check_only:
		print_rich("gen_village: " + ("up to date" if text == current else "OUT OF DATE (rerun tools/gen_village.gd)"))
		quit(0 if text == current else 1)
		return
	if text != current:
		var file: FileAccess = FileAccess.open(BUILDINGS_PATH, FileAccess.WRITE)
		file.store_string(text)
		file.close()
	print_rich("gen_village: %s" % ("written" if text != current else "unchanged"))
	quit(0)


## F-131/F-132 for one level (same pure function as the validator uses).
static func levels_for(spec: Dictionary, params: Dictionary, level: int) -> Dictionary:
	# Loaded at run time: this script starts before the autoloads exist and the validator classes need `Log`.
	return (load(VALIDATOR_PATH) as GDScript).call("levels_for", spec, params, level) as Dictionary


## `{"text": String, "errors": PackedStringArray}`: the whole file text for the hand-written `source` (the parsed current
## file), the `village` parameters and the ids of the existing items. With errors the text is empty.
static func generate(source: Dictionary, params: Dictionary, items: Dictionary) -> Dictionary:
	var errors: PackedStringArray = []
	var rows: PackedStringArray = []
	for building: Variant in source["buildings"] as Array:
		var b: Dictionary = building as Dictionary
		var levels: Array[String] = []
		if bool(b["buildable"]):
			for level: int in range(1, int(params["max_level"]) + 1):
				var entry: Dictionary = levels_for(b, params, level)
				for row: Dictionary in entry["items"] as Array[Dictionary]:
					if not items.has(row["item"]):
						errors.append("%s level %d: item '%s' does not exist" % [b["id"], level, row["item"]])
				levels.append("      " + JSON.stringify(entry, "", false))
		rows.append(_render(b, levels))
	if not errors.is_empty():
		return {"text": "", "errors": errors}
	return {"text": '{\n  "buildings": [\n%s\n  ]\n}\n' % ",\n".join(rows), "errors": errors}


## The ids of every item of data/items/.
static func item_ids() -> Dictionary:
	var ids: Dictionary = {}
	for file: String in DirAccess.get_files_at(ITEMS_DIR):
		if file.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_DIR.path_join(file)))
			for item: Variant in (parsed as Dictionary).get("items", []) as Array:
				ids[str((item as Dictionary)["id"])] = true
	return ids


static func _render(b: Dictionary, levels: Array[String]) -> String:
	var head: String = ('    {"id": %s, "name": %s, "description": %s, "icon": %s, "order": %d, "buildable": %s' % [
			JSON.stringify(b["id"]), JSON.stringify(b["name"]), JSON.stringify(b["description"]), JSON.stringify(b["icon"]),
			int(b["order"]), str(bool(b["buildable"])).to_lower()])
	# M21: hand-written presentation fields, kept as they are
	var pos: Array = b["map_pos"] as Array
	head += ', "map_pos": [%s, %s]' % [str(float(pos[0])), str(float(pos[1]))]
	if b.has("page"):
		head += ', "page": %s' % JSON.stringify(b["page"])
	if not bool(b["buildable"]):
		return head + ', "milestone": %d, "levels": []}' % int(b["milestone"])
	if bool(b.get("unlocks_shop", false)):  # M20: no `effect`, the level opens shop entries
		head += ',\n     "unlocks_shop": true'
	else:
		head += ",\n     \"effect\": %s" % JSON.stringify(b["effect"], "", false)
	return "%s,\n     \"cost_spec\": %s,\n     \"levels\": [\n%s\n     ]}" % [head,
			JSON.stringify(b["cost_spec"], "", false), ",\n".join(levels)]
