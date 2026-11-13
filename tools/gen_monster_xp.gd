extends SceneTree
## Regenerates the `xp` field of every monster in data/combat/monsters.json with F-130 (docs/02_FORMULAS.md §5g):
## xp = round(combat.monster_xp.base x combat.monster_xp.growth^(L_m - 1)), L_m = max(attack, power, defence level).
## Idempotent text patch: only the digits after `"xp":` change, the formatting of the file stays untouched. The output
## is committed: the game never runs this script. Prints the lines it changed; `--check` writes nothing and exits 1
## if a value differs.
##
## Usage: godot --headless --path . -s tools/gen_monster_xp.gd [-- --check]

const MONSTERS_PATH: String = "res://data/combat/monsters.json"
const BALANCE_PATH: String = "res://data/config/balance.json"


func _init() -> void:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var balance: Dictionary = _read_json(BALANCE_PATH)
	var spec: Dictionary = (balance["combat"] as Dictionary)["monster_xp"] as Dictionary
	var base: float = float(spec["base"])
	var growth: float = float(spec["growth"])
	var lines: PackedStringArray = FileAccess.get_file_as_string(MONSTERS_PATH).split("\n")
	var id_re := RegEx.create_from_string("\"id\":\"([a-z0-9_]+)\"")
	var xp_re := RegEx.create_from_string("\"xp\":\\d+")
	var level_re := RegEx.create_from_string("\"(attack|power|defence)_level\":(\\d+)")
	var changed: int = 0
	for i: int in lines.size():
		if id_re.search(lines[i]) == null:
			continue
		var level: int = 1
		for m: RegExMatch in level_re.search_all(lines[i]):
			level = maxi(level, int(m.get_string(2)))
		var xp: int = int(round(base * pow(growth, float(level - 1))))
		var patched: String = xp_re.sub(lines[i], "\"xp\":%d" % xp)
		if patched != lines[i]:
			changed += 1
			print("%s: level %d -> xp %d" % [id_re.search(lines[i]).get_string(1), level, xp])
			lines[i] = patched
	if check_only:
		print("%d monsters out of date" % changed)
		quit(1 if changed > 0 else 0)
		return
	var file := FileAccess.open(MONSTERS_PATH, FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	print("gen_monster_xp: %d monsters updated" % changed)
	quit(0)


func _read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
