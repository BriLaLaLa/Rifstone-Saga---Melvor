extends SceneTree
## Cuts the generated icon sheets into one PNG per creature and points the data files at them.
## Reads docs/PROMPT_MOSTRI.md for the order (sheet number -> destination files), finds the tiles of each sheet by
## itself (the grid position changes from sheet to sheet) and writes assets/icons/monsters/<id>.png (256x256).
## Run: godot --headless --path . -s tools/split_monster_sheets.gd -- <folder with foglioN.png> [--no-data]

const OUT_SIZE := 256
const INSET := 3
const BG_TOLERANCE := 24
const MIN_RUN := 150
const DATA_FILES := ["res://data/combat/monsters.json", "res://data/maps/bosses.json", "res://data/dungeons/monkey_den.json"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <sheet folder> [--no-data]")
		quit(1)
		return
	var folder: String = args[0]
	var sheets: Dictionary = _parse_manifest()
	var ids_done: Array = []
	var failed := false
	for n: int in sheets.keys():
		var ids: Array = sheets[n]
		var img: Image = _load_sheet(folder, n)
		if img == null:
			push_error("sheet %d: file not found in %s" % [n, folder])
			failed = true
			continue
		var tiles: Array = _find_tiles(img)
		if tiles.size() < ids.size():
			push_error("sheet %d: found %d tiles, need %d" % [n, tiles.size(), ids.size()])
			failed = true
			continue
		for k in ids.size():
			var r: Rect2i = tiles[k]
			var tile: Image = img.get_region(Rect2i(r.position + Vector2i(INSET, INSET), r.size - Vector2i(INSET * 2, INSET * 2)))
			tile.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
			var path := "res://assets/icons/monsters/%s.png" % ids[k]
			if tile.save_png(path) != OK:
				push_error("cannot save " + path)
				failed = true
			ids_done.append(ids[k])
		print("sheet %d: %d tiles ok (grid %d found)" % [n, ids.size(), tiles.size()])
	if not failed and not args.has("--no-data"):
		_rewire(ids_done)
	quit(1 if failed else 0)


func _parse_manifest() -> Dictionary:
	var f := FileAccess.open("res://docs/PROMPT_MOSTRI.md", FileAccess.READ)
	var text: String = f.get_as_text()
	var sheets: Dictionary = {}
	var current := 0
	var re := RegEx.new()
	re.compile("^\\| \\d+ \\| `assets/icons/monsters/([a-z0-9_]+)\\.png`")
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
	for name: String in ["foglio%d.png" % n, "Foglio%d.png" % n, "foglio_%02d.png" % n]:
		var p := folder.path_join(name)
		if FileAccess.file_exists(p):
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(p)
			var img := Image.new()
			# The generator saves JPEG data under a .png name: read the real format from the first bytes.
			var err: int = img.load_png_from_buffer(bytes) if bytes.size() > 4 and bytes[1] == 0x50 else img.load_jpg_from_buffer(bytes)
			if err == OK:
				img.convert(Image.FORMAT_RGBA8)
				return img
	return null


func _is_bg(c: Color, bg: Color) -> bool:
	return (absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)) * 255.0 <= BG_TOLERANCE


## Returns the tile rectangles in reading order (row by row).
func _find_tiles(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var bg: Color = img.get_pixel(2, 2)
	var col_count: PackedInt32Array = PackedInt32Array()
	col_count.resize(w)
	for x in w:
		var c := 0
		for y in range(0, h, 2):
			if not _is_bg(img.get_pixel(x, y), bg):
				c += 1
		col_count[x] = c * 2
	var xs: Array = _runs(col_count)
	var row_count: PackedInt32Array = PackedInt32Array()
	row_count.resize(h)
	for y in h:
		var c := 0
		for x in range(0, w, 2):
			if not _is_bg(img.get_pixel(x, y), bg):
				c += 1
		row_count[y] = c * 2
	var ys: Array = _runs(row_count)
	var tiles: Array = []
	for yr: Vector2i in ys:
		for xr: Vector2i in xs:
			tiles.append(Rect2i(xr.x, yr.x, xr.y - xr.x, yr.y - yr.x))
	return tiles


## Runs of positions where the projection is above the threshold: Vector2i(start, end exclusive).
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


func _rewire(ids: Array) -> void:
	for path: String in DATA_FILES:
		var f := FileAccess.open(path, FileAccess.READ)
		var text: String = f.get_as_text()
		f.close()
		var changed := 0
		for id: String in ids:
			var re := RegEx.new()
			re.compile("(\"id\"\\s*:\\s*\"%s\"[^{}]*?\"icon\"\\s*:\\s*\")[^\"]*(\")" % id)
			var m := re.search(text)
			if m != null:
				text = text.substr(0, m.get_start()) + m.get_string(1) + "res://assets/icons/monsters/%s.png" % id + m.get_string(2) + text.substr(m.get_end())
				changed += 1
		var w := FileAccess.open(path, FileAccess.WRITE)
		w.store_string(text)
		w.close()
		print("%s: %d icons repointed" % [path, changed])
