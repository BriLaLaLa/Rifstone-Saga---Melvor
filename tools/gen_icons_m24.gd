extends SceneTree
## Writes the placeholder icons of M24-05 (64x64 SVG, simple shapes): the Herbalist skill, 8 herbs, 8 byproducts, 8 Tonics and 8 Recipes.
## Idempotent: the same text every run. The output is committed: the game never runs this script.
##
## Usage: godot --headless --path . -s tools/gen_icons_m24.gd

const ITEMS_DIR: String = "res://assets/icons/items/"
const SKILL_FILE: String = "res://assets/icons/skills/herbalism.svg"
const HEAD: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
const FOOT: String = "</svg>\n"
## Flower or liquid color of each step T1-T8.
const COLORS: Array[String] = ["#c9534a", "#9aa8a0", "#7fa8c8", "#8a63b8", "#5fc8d8", "#c8d4e0", "#e8742a", "#b050e0"]
const HERBS: Array[String] = ["redrock_clover", "ash_mint", "thorn_sage", "dusk_lily", "shard_bloom", "veil_fern", "ember_thistle", "rift_orchid"]
const BYPRODUCTS: Array[String] = ["clover_seed", "mint_leaf", "sage_bud", "lily_petal", "bloom_pollen", "fern_spore", "thistle_burr", "orchid_nectar"]


func _initialize() -> void:
	_write(SKILL_FILE, HEAD
			+ '  <rect x="2" y="2" width="60" height="60" rx="12" fill="#1c1a17" stroke="#8fc24a" stroke-width="3"/>\n'
			+ '  <path d="M32 54 V26" fill="none" stroke="#8fc24a" stroke-width="5" stroke-linecap="round"/>\n'
			+ '  <path d="M32 38 C20 38 14 30 14 20 C26 20 32 28 32 38 Z" fill="#8fc24a"/>\n'
			+ '  <path d="M32 30 C44 30 50 22 50 12 C38 12 32 20 32 30 Z" fill="#8fc24a"/>\n' + FOOT)
	for i: int in COLORS.size():
		var c: String = COLORS[i]
		_write(ITEMS_DIR + HERBS[i] + ".svg", HEAD
				+ '  <path d="M32 58 V30" fill="none" stroke="#4f8a3a" stroke-width="4" stroke-linecap="round"/>\n'
				+ '  <ellipse cx="22" cy="46" rx="10" ry="5" fill="#4f8a3a"/>\n'
				+ '  <circle cx="32" cy="22" r="13" fill="%s" stroke="#000000" stroke-opacity="0.35" stroke-width="2"/>\n' % c
				+ '  <circle cx="32" cy="22" r="5" fill="#e8d878"/>\n' + FOOT)
		_write(ITEMS_DIR + BYPRODUCTS[i] + ".svg", HEAD
				+ '  <ellipse cx="32" cy="34" rx="16" ry="10" fill="%s" stroke="#000000" stroke-opacity="0.35" stroke-width="2"/>\n' % c
				+ '  <circle cx="26" cy="31" r="3" fill="#ffffff" fill-opacity="0.45"/>\n' + FOOT)
		_write(ITEMS_DIR + "tonic_%d.svg" % (i + 1), HEAD
				+ '  <rect x="26" y="8" width="12" height="10" fill="#8a7a64"/>\n'
				+ '  <rect x="28" y="16" width="8" height="10" fill="#cfd8dc"/>\n'
				+ '  <path d="M28 26 L14 52 Q12 58 20 58 H44 Q52 58 50 52 L36 26 Z" fill="#cfd8dc" stroke="#000000" stroke-opacity="0.35" stroke-width="2"/>\n'
				+ '  <path d="M22 44 H42 L48 54 Q49 56 46 56 H18 Q15 56 16 54 Z" fill="%s"/>\n' % c + FOOT)
		_write(ITEMS_DIR + "recipe_tonic_%d.svg" % (i + 1), HEAD
				+ '  <rect x="12" y="8" width="40" height="48" rx="4" fill="#e8dcc0" stroke="#000000" stroke-opacity="0.35" stroke-width="2"/>\n'
				+ '  <line x1="20" y1="20" x2="44" y2="20" stroke="#6a5a44" stroke-width="3"/>\n'
				+ '  <line x1="20" y1="30" x2="44" y2="30" stroke="#6a5a44" stroke-width="3"/>\n'
				+ '  <circle cx="32" cy="44" r="7" fill="%s"/>\n' % c + FOOT)
	print_rich("gen_icons_m24: written")
	quit(0)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
