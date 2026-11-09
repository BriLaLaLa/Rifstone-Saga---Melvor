extends RefCounted
## Placeholder icons of tools/gen_equipment.gd: simple 64x64 SVG shapes, colour by material, accent by rarity.

const ICON_DIR: String = "res://assets/icons/items/"
const BODY_COLORS: Dictionary = {"plate": "#9aa7b5", "leather": "#a0693a", "cloth": "#7d5fb0"}
const ACCENT: Dictionary = {"normal": "#000", "masterwork": "#a64dff", "legendary": "#ff9a2e"}

var _written: Dictionary = {}
var quiet: bool = false  # true while a base is built only to copy its values (no file)


## Writes the icon `icon_name` once (rarity "normal", "masterwork" or "legendary").
func write(icon_name: String, slot: String, material: String, rarity: String) -> void:
	if quiet or _written.has(icon_name):
		return
	_written[icon_name] = true
	var color: String = BODY_COLORS[material]
	var accent: String = ACCENT[rarity]
	var stroke: String = "stroke=\"%s\" stroke-opacity=\"%s\" stroke-width=\"%s\"" % [accent, "0.35" if rarity == "normal" else "1", "2" if rarity == "normal" else "3"]
	var shape: String = _shape(slot, color, stroke)
	if rarity == "legendary":
		shape += "<circle cx=\"54\" cy=\"10\" r=\"5\" fill=\"#ff9a2e\" stroke=\"#000\" stroke-opacity=\"0.35\" stroke-width=\"1\"/>"
	var svg: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"64\" height=\"64\" viewBox=\"0 0 64 64\">\n  %s\n</svg>\n" % shape
	var f: FileAccess = FileAccess.open(ICON_DIR + icon_name + ".svg", FileAccess.WRITE)
	f.store_string(svg)
	f.close()


func _shape(slot: String, color: String, stroke: String) -> String:
	var dark: String = "#5a4030"
	match slot:
		"sword":
			return "<polygon points=\"32,4 40,38 24,38\" fill=\"%s\" %s/><rect x=\"18\" y=\"38\" width=\"28\" height=\"5\" fill=\"%s\"/><rect x=\"29\" y=\"43\" width=\"6\" height=\"14\" fill=\"%s\"/>" % [color, stroke, dark, dark]
		"greatsword":
			return "<polygon points=\"32,2 44,40 20,40\" fill=\"%s\" %s/><rect x=\"14\" y=\"40\" width=\"36\" height=\"5\" fill=\"%s\"/><rect x=\"28\" y=\"45\" width=\"8\" height=\"16\" fill=\"%s\"/>" % [color, stroke, dark, dark]
		"shield":
			return "<path d=\"M12,8 H52 V32 Q52,52 32,60 Q12,52 12,32 Z\" fill=\"%s\" %s/><circle cx=\"32\" cy=\"30\" r=\"6\" fill=\"%s\"/>" % [color, stroke, dark]
		"head":
			return "<path d=\"M12,40 Q12,10 32,10 Q52,10 52,40 V48 H12 Z\" fill=\"%s\" %s/><rect x=\"24\" y=\"34\" width=\"16\" height=\"6\" fill=\"%s\"/>" % [color, stroke, dark]
		"body":
			return "<polygon points=\"20,8 44,8 56,20 48,28 44,24 44,56 20,56 20,24 16,28 8,20\" fill=\"%s\" %s/>" % [color, stroke]
		"legs":
			return "<polygon points=\"16,8 48,8 50,58 36,58 32,26 28,58 14,58\" fill=\"%s\" %s/>" % [color, stroke]
		"feet":
			return "<path d=\"M20,8 H36 V38 L54,44 V56 H18 Z\" fill=\"%s\" %s/>" % [color, stroke]
		"hands":
			return "<path d=\"M18,30 L18,14 H24 V28 H28 V10 H34 V28 H38 V12 H44 V30 H48 V40 Q48,56 32,56 Q18,56 18,40 Z\" fill=\"%s\" %s/>" % [color, stroke]
		"ring":
			return "<circle cx=\"32\" cy=\"36\" r=\"16\" fill=\"none\" stroke=\"%s\" stroke-width=\"7\"/><circle cx=\"32\" cy=\"16\" r=\"6\" fill=\"%s\" %s/>" % [color, dark, stroke]
		"neck":
			return "<path d=\"M14,8 Q32,44 50,8\" fill=\"none\" stroke=\"%s\" stroke-width=\"4\"/><circle cx=\"32\" cy=\"42\" r=\"11\" fill=\"%s\" %s/>" % [dark, color, stroke]
		"tool_hatchet":
			return "<rect x=\"29\" y=\"8\" width=\"6\" height=\"50\" fill=\"%s\"/><polygon points=\"35,10 56,16 56,34 35,30\" fill=\"%s\" %s/>" % [dark, color, stroke]
		"tool_pick":
			return "<rect x=\"29\" y=\"10\" width=\"6\" height=\"48\" fill=\"%s\"/><path d=\"M8,22 Q32,0 56,22 L52,26 Q32,10 12,26 Z\" fill=\"%s\" %s/>" % [dark, color, stroke]
		"tool_rod":
			return "<line x1=\"12\" y1=\"58\" x2=\"50\" y2=\"8\" stroke=\"%s\" stroke-width=\"4\"/><path d=\"M50,8 Q60,30 46,44\" fill=\"none\" stroke=\"%s\" stroke-width=\"2\"/><circle cx=\"46\" cy=\"46\" r=\"4\" fill=\"%s\" %s/>" % [dark, "#444", color, stroke]
	return "<rect x=\"12\" y=\"12\" width=\"40\" height=\"40\" fill=\"%s\" %s/>" % [color, stroke]
