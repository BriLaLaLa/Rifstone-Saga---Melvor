extends SceneTree
## Writes docs/PROMPT_OGGETTI.md: every distinct item icon referenced by data/items/*.json, grouped by data file into
## sheets of 12 (4 columns x 3 rows), with the destination file (same name as the old SVG, .png) and a ready-to-paste prompt.
## Run: godot --headless --path . -s tools/gen_item_sheets.gd

const OUT := "res://docs/PROMPT_OGGETTI.md"
const SHEET_SIZE := 12
const PROMPT_HEAD := "Crea UN'UNICA immagine: un foglio di icone di oggetti per un gioco fantasy, %d oggetti in una griglia di 4 colonne x 3 righe. Riquadri quadrati e della stessa dimensione, con 24 pixel di spazio vuoto tra l'uno e l'altro. Un solo oggetto per riquadro, centrato e tutto visibile, ben ingrandito.\n\nStile identico per tutti: fantasy dipinto a mano, vista frontale o di tre quarti, contorno scuro spesso, palette terrosa e satura (rosso ruggine, verde muschio, grigio pietra, oro spento), leggibile anche rimpicciolito a 64x64 pixel. Ogni riquadro ha uno sfondo semplice di tinta unita beige-grigia, senza scena e senza ambiente. Sfondo unico grigio chiaro piatto attorno ai riquadri. Nessun testo, nessuna lettera, nessun numero, nessuna cornice."


func _initialize() -> void:
	var lines: PackedStringArray = ["# Prompt per i fogli di icone degli oggetti", "",
		"Generato da `tools/gen_item_sheets.gd`. Non modificare a mano.", "",
		"Ogni blocco è un prompt completo: copialo in Gemini, salva l'immagine come `oggetti_01.png`, `oggetti_02.png`, ... (numero del foglio).", ""]
	var seen: Dictionary = {}
	var sheet_no := 1
	var dir := DirAccess.open("res://data/items")
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for fname in files:
		if not fname.ends_with(".json"):
			continue
		var data: Dictionary = _load("res://data/items/" + fname)
		var entries: Array = []
		for it: Dictionary in data.get("items", []):
			var icon: String = String(it.get("icon", ""))
			if icon.begins_with("res://assets/icons/items/") and not seen.has(icon):
				seen[icon] = true
				entries.append({"file": icon.get_file().get_basename(), "name": it.get("name", ""), "desc": it.get("description", "")})
		sheet_no = _emit(lines, fname.get_basename(), entries, sheet_no)
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("gen_item_sheets: %d icons, %d sheets -> %s" % [seen.size(), sheet_no - 1, OUT])
	quit(0)


func _emit(lines: PackedStringArray, title: String, entries: Array, sheet_no: int) -> int:
	var i := 0
	while i < entries.size():
		var chunk: Array = entries.slice(i, i + SHEET_SIZE)
		lines.append("## Foglio %d, %s" % [sheet_no, title])
		lines.append("")
		lines.append("| # | file di destinazione | nome |")
		lines.append("|---|---|---|")
		var names: PackedStringArray = []
		for k in chunk.size():
			var e: Dictionary = chunk[k]
			lines.append("| %d | `assets/icons/items/%s.png` | %s |" % [k + 1, e["file"], e["name"]])
			var desc: String = String(e["desc"])
			if desc.length() > 110:
				desc = desc.substr(0, 110).rsplit(" ", true, 1)[0]
			names.append("%d) %s%s" % [k + 1, e["name"], (": " + desc) if not desc.is_empty() else ""])
		lines.append("")
		lines.append("Prompt da incollare:")
		lines.append("```")
		lines.append(PROMPT_HEAD % chunk.size() + "\n\nOggetti, da sinistra a destra e dall'alto in basso:\n" + "\n".join(names))
		lines.append("```")
		lines.append("")
		sheet_no += 1
		i += SHEET_SIZE
	return sheet_no


func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
