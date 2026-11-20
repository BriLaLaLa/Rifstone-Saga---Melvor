extends SceneTree
## Cuts the generated item icon sheets (4 columns x 3 rows) into one PNG per item and points data/ at the new files.
## Order comes from docs/PROMPT_OGGETTI.md (sheet number -> destination files). Sheets missing from the folder are
## skipped, so it can run on a partial set. The tiles of each sheet are found by the script itself.
## Run: godot --headless --path . -s tools/split_item_sheets.gd -- <folder with oggetti_NN.jpg> [--no-data]

const OUT_SIZE := 256
const INSET := 3
const BG_TOLERANCE := 24
const MIN_RUN := 120
const ICON_DIR := "res://assets/icons/items/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <sheet folder> [--no-data]")
		quit(1)
		return
	var folder: String = args[0]
	var sheets: Dictionary = _parse_manifest()
	var done: Dictionary = {}
	var failed := false
	var skipped: Array = []
	for n: int in sheets.keys():
		var names: Array = sheets[n]
		var img: Image = _load_sheet(folder, n)
		if img == null:
			skipped.append(n)
			continue
		var tiles: Array = _find_tiles(img)
		if tiles.size() < names.size():
			push_error("sheet %d: found %d tiles, need %d" % [n, tiles.size(), names.size()])
			failed = true
			continue
		for k in names.size():
			var r: Rect2i = tiles[k]
			var tile: Image = img.get_region(Rect2i(r.position + Vector2i(INSET, INSET), r.size - Vector2i(INSET * 2, INSET * 2)))
			tile.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
			if tile.save_png(ICON_DIR + "%s.png" % names[k]) != OK:
				push_error("cannot save " + String(names[k]))
				failed = true
			done[names[k]] = true
		print_rich("sheet %d: %d icons ok (grid %d found)" % [n, names.size(), tiles.size()])
	if not skipped.is_empty():
		print_rich("sheets not found, skipped: %s" % str(skipped))
	if not failed and not args.has("--no-data"):
		_rewire(done)
	quit(1 if failed else 0)


func _parse_manifest() -> Dictionary:
	var text: String = FileAccess.open("res://docs/PROMPT_OGGETTI.md", FileAccess.READ).get_as_text()
	var sheets: Dictionary = {}
	var current := 0
	var re := RegEx.new()
	re.compile("^\\| \\d+ \\| `assets/icons/items/([A-Za-z0-9_]+)\\.png`")
	for line in text.split("\n"):
		if line.begins_with("## Foglio "):
			current = int(line.substr(10).split(",")[0])
			sheets[current] = []
		elif current > 0:
			var m := re.search(line)
			if m != null:
				(sheets[current] as Array).append(m.get_string(1))
	return sheets


func _load_sheet(folder: String, n: int) -> Image:
	for fname: String in ["oggetti_%02d.jpg" % n, "oggetti_%02d.png" % n, "oggetti_%02d.jpeg" % n]:
		var p: String = folder.path_join(fname)
		if not FileAccess.file_exists(p):
			continue
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(p)
		var img := Image.new()
		# The generator may save JPEG data under any extension: read the real format from the first bytes.
		var err: int = img.load_png_from_buffer(bytes) if bytes.size() > 4 and bytes[1] == 0x50 else img.load_jpg_from_buffer(bytes)
		if err == OK:
			img.convert(Image.FORMAT_RGBA8)
			return img
	return null


func _is_bg(c: Color, bg: Color) -> bool:
	return (absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)) * 255.0 <= BG_TOLERANCE


## Tile rectangles in reading order (row by row).
func _find_tiles(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var bg: Color = img.get_pixel(2, 2)
	var cols := PackedInt32Array()
	cols.resize(w)
	for x in w:
		var c := 0
		for y in range(0, h, 2):
			if not _is_bg(img.get_pixel(x, y), bg):
				c += 1
		cols[x] = c * 2
	var rows := PackedInt32Array()
	rows.resize(h)
	for y in h:
		var c := 0
		for x in range(0, w, 2):
			if not _is_bg(img.get_pixel(x, y), bg):
				c += 1
		rows[y] = c * 2
	var tiles: Array = []
	for yr: Vector2i in _runs(rows):
		for xr: Vector2i in _runs(cols):
			tiles.append(Rect2i(xr.x, yr.x, xr.y - xr.x, yr.y - yr.x))
	return tiles


func _runs(counts: PackedInt32Array) -> Array:
	var runs: Array = []
	var start := -1
	for i in counts.size():
		var on: bool = counts[i] >= MIN_RUN
		if on and start < 0:
			start = i
		elif not on and start >= 0:
			if i - start >= MIN_RUN:
				runs.append(Vector2i(start, i))
			start = -1
	if start >= 0 and counts.size() - start >= MIN_RUN:
		runs.append(Vector2i(start, counts.size()))
	return runs


## Points every `res://assets/icons/items/<name>.svg` in data/ at the new PNG for the converted names.
func _rewire(done: Dictionary) -> void:
	var re := RegEx.new()
	re.compile("res://assets/icons/items/([A-Za-z0-9_]+)\\.svg")
	var total := 0
	for path: String in _json_files("res://data"):
		var text: String = FileAccess.open(path, FileAccess.READ).get_as_text()
		var out := ""
		var last := 0
		var changed := 0
		for m: RegExMatch in re.search_all(text):
			if done.has(m.get_string(1)):
				out += text.substr(last, m.get_start() - last) + ICON_DIR + m.get_string(1) + ".png"
				last = m.get_end()
				changed += 1
		if changed > 0:
			out += text.substr(last)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(out)
			f.close()
			total += changed
	print_rich("data: %d icon references repointed" % total)


func _json_files(dir_path: String) -> Array:
	var files: Array = []
	var d := DirAccess.open(dir_path)
	for sub in d.get_directories():
		files.append_array(_json_files(dir_path.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".json"):
			files.append(dir_path.path_join(f))
	return files
