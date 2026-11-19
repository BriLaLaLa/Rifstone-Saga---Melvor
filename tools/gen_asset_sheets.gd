extends SceneTree
## Writes docs/ASSET_MOSTRI.md: every creature (monsters, area minibosses, dungeon monsters, fracture bosses)
## grouped into sheets of at most 8, with the target file name and a ready-to-paste prompt per sheet.
## Run: godot --headless --path . -s tools/gen_asset_sheets.gd

const OUT := "res://docs/ASSET_MOSTRI.md"
const SHEET_SIZE := 8
const STYLE := "Stile fisso per TUTTE le richieste: icone fantasy dipinte a mano, vista frontale o 3/4, contorno scuro spesso, " \
	+ "palette terrosa e satura (rosso ruggine, verde muschio, grigio pietra, oro spento), un solo soggetto per riquadro, " \
	+ "centrato, fondo trasparente, nessun testo, nessuna cornice, leggibile a 64x64 pixel. Riquadri quadrati uguali, " \
	+ "griglia 4 colonne x 2 righe, margine di 16 px tra i riquadri."


func _initialize() -> void:
	var monsters: Array = _load("res://data/combat/monsters.json").get("monsters", [])
	var by_id: Dictionary = {}
	for m: Dictionary in monsters:
		by_id[m["id"]] = m
	var areas: Array = _load("res://data/combat/areas.json").get("areas", [])
	var seen: Dictionary = {}
	var lines: PackedStringArray = ["# Mostri: elenco per i fogli di icone", "",
		"Generato da `tools/gen_asset_sheets.gd`. Non modificare a mano.", "",
		"**Stile (incollalo in testa a ogni richiesta):** " + STYLE, ""]
	var sheet_no := 1
	for a: Dictionary in areas:
		var ids: Array = []
		for p: Dictionary in a.get("packs", []):
			for mid: String in p.get("monsters", []):
				if not seen.has(mid) and by_id.has(mid):
					seen[mid] = true
					ids.append(mid)
		for mid: String in by_id.keys():
			if not seen.has(mid) and String(mid).begins_with("miniboss_" + String(a["id"])):
				seen[mid] = true
				ids.append(mid)
		sheet_no = _emit(lines, "Area: %s (livelli %s-%s)" % [a.get("name", a["id"]), a.get("level_min", "?"), a.get("level_max", "?")], ids, by_id, sheet_no)
	var rest: Array = []
	for mid: String in by_id.keys():
		if not seen.has(mid):
			rest.append(mid)
	if not rest.is_empty():
		sheet_no = _emit(lines, "Altri mostri", rest, by_id, sheet_no)
	var den: Dictionary = _load("res://data/dungeons/monkey_den.json")
	var den_ids: Array = []
	var den_by_id: Dictionary = {}
	for m: Dictionary in den.get("monsters", []):
		den_by_id[m["id"]] = m
		den_ids.append(m["id"])
	if not den_ids.is_empty():
		sheet_no = _emit(lines, "Covo delle Scimmie", den_ids, den_by_id, sheet_no)
	var bosses: Array = _load("res://data/maps/bosses.json").get("bosses", [])
	var b_ids: Array = []
	var b_by_id: Dictionary = {}
	for b: Dictionary in bosses:
		b_by_id[b["id"]] = b
		b_ids.append(b["id"])
	_emit(lines, "Boss delle Fratture (soggetti grandi, imponenti)", b_ids, b_by_id, sheet_no)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("gen_asset_sheets: %d creatures, %d sheets -> %s" % [seen.size() + den_ids.size() + b_ids.size(), sheet_no, OUT])
	quit(0)


func _emit(lines: PackedStringArray, title: String, ids: Array, defs: Dictionary, sheet_no: int) -> int:
	var i := 0
	while i < ids.size():
		var chunk: Array = ids.slice(i, i + SHEET_SIZE)
		lines.append("## Foglio %d, %s" % [sheet_no, title])
		lines.append("")
		lines.append("| # | file di destinazione | nome | descrizione |")
		lines.append("|---|---|---|---|")
		var names: PackedStringArray = []
		for k in chunk.size():
			var d: Dictionary = defs[chunk[k]]
			lines.append("| %d | `assets/icons/monsters/%s.png` | %s | %s |" % [k + 1, chunk[k], d.get("name", ""), d.get("description", "")])
			names.append("%d) %s: %s" % [k + 1, d.get("name", ""), d.get("description", "")])
		lines.append("")
		lines.append("Prompt: `Foglio di %d icone di creature, ordine da sinistra a destra e dall'alto in basso. %s`" % [chunk.size(), "; ".join(names)])
		lines.append("")
		sheet_no += 1
		i += SHEET_SIZE
	return sheet_no


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
