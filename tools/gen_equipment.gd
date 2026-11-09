extends SceneTree
## Generates the equipment catalogue of the Alpha (M14-05): 15 grades of every slot and material (docs/02_FORMULAS.md
## §8.4, F-118), the Masterwork bases and their blueprints (F-119), the 39 legendaries (F-120) and the placeholder icons.
## The numbers come from data/config/balance.json (`equipment.*`, `combat.armor.materials`); the names are those of
## docs/NOMI.md (section Alpha). The output is committed: the game never runs this script.
##
## Usage: godot --headless --path . -s tools/gen_equipment.gd
##
## Ids: grades 1-8 of Plate armour, weapons, rings and amulets keep the ids of the old catalogue (`emberbronze_sword`, ...)
## because tests and the starting kit refer to them; every other piece is `<slot>_<material>_<grade>` (`body_leather_9`),
## `sword_9`, `ring_9`; Masterworks `mw_<slot>_<grade>`, blueprints `bp_mw_<slot>_<grade>`, legendaries `leg_<slot>_<n>`.

const OUT_DIR: String = "res://data/items/"
const ICON_PATH: String = "res://assets/icons/items/"
const GRADES: int = 15

const METALS: Array[String] = ["emberbronze", "ashlead", "stormzinc", "duskcobalt", "glimmerite", "palecinnabar", "emberheart", "riftite"]
const WOODS: Array[String] = ["redbirch", "ashpine", "thornalder", "duskelm", "shardcedar", "veilcypress", "emberlarch", "riftspruce"]
const LEGACY_SUFFIX: Dictionary = {"sword": "sword", "greatsword": "greatsword", "body": "cuirass", "legs": "greaves",
	"head": "helm", "feet": "boots", "hands": "gauntlets", "shield": "shield", "ring": "ring", "neck": "amulet"}
const PLATE_VALUE: Array[int] = [7, 21, 42, 70, 126, 210, 350, 595, 800, 1080, 1460, 1980, 2670, 3600, 4860]
const SLOT_VALUE_MULT: Dictionary = {"sword": 2.0, "greatsword": 22.0 / 7.0, "body": 20.0 / 7.0, "legs": 16.0 / 7.0,
	"head": 12.0 / 7.0, "feet": 8.0 / 7.0, "hands": 8.0 / 7.0, "shield": 20.0 / 7.0}
const RING_VALUE: Array[int] = [10, 28, 54, 88, 130, 180, 238, 304, 378, 460, 550, 648, 754, 868, 990]
const NECK_VALUE: Array[int] = [12, 32, 60, 96, 140, 192, 252, 320, 396, 480, 572, 672, 780, 896, 1020]
const SLOT_ORDER: Dictionary = {"sword": 100, "greatsword": 200, "body": 400, "legs": 500, "head": 600, "feet": 700,
	"hands": 800, "shield": 900, "ring": 1000, "neck": 1100}
const ARMOUR_SLOTS: Array[String] = ["head", "body", "legs", "feet", "hands", "shield"]
const MATERIALS: Array[String] = ["plate", "leather", "cloth"]
const EQUIP_SLOT: Dictionary = {"sword": "weapon", "greatsword": "weapon", "body": "body", "legs": "legs", "head": "head",
	"feet": "feet", "hands": "hands", "shield": "offhand", "ring": "ring", "neck": "neck"}

# docs/NOMI.md, section Alpha.
const EPITHETS: Array[String] = ["del Novizio", "del Garzone", "del Fante", "del Mercenario", "del Soldato", "del Veterano",
	"del Capitano", "del Campione", "del Cavaliere", "del Condottiero", "della Brace Antica", "dell'Alba Spezzata",
	"dell'Eclissi", "dell'Abisso Stellato", "del Primo Rift"]
const MARKS: Array[String] = ["di Fucina Prima", "di Ferrovivo", "di Roccamartello", "di Valleincudine", "di Brace Fedele",
	"di Forgia Alta", "di Cenere Bianca", "di Torre Nera", "di Sole Battuto", "di Luna Forgiata", "di Fiamma Eterna",
	"di Stella Domata", "di Eclissi Vinta", "di Abisso Domato", "di Rift Domato"]
const TYPE_NAMES: Dictionary = {
	"plate": {"head": "Elmo", "body": "Corazza", "legs": "Cosciali", "feet": "Schinieri", "hands": "Manopole", "shield": "Scudo"},
	"leather": {"head": "Cappuccio", "body": "Giubba", "legs": "Calzoni", "feet": "Stivali", "hands": "Guanti", "shield": "Rotella"},
	"cloth": {"head": "Cappello runico", "body": "Veste runica", "legs": "Brache runiche", "feet": "Sandali runici",
		"hands": "Mitene runiche", "shield": "Sigillo runico"},
}
const MASTER_TYPES: Dictionary = {"sword": "Lama", "greatsword": "Spadone", "shield": "Scudo", "head": "Elmo", "body": "Corazza",
	"legs": "Cosciali", "feet": "Schinieri", "hands": "Manopole"}
const MASTER_SLOTS: Array[String] = ["sword", "greatsword", "shield", "head", "body", "legs", "feet", "hands"]
const SWORDS: Array[String] = ["Spada d'addestramento", "Spada corta", "Gladio", "Sciabola", "Spada lunga", "Squarcina",
	"Spada d'ordinanza", "Lama del Cavaliere", "Fendente", "Lama temprata", "Lama della Brace Antica",
	"Lama dell'Alba Spezzata", "Lama dell'Eclissi", "Lama dell'Abisso", "Lama del Primo Rift"]
const GREATSWORDS: Array[String] = ["Spadone grezzo", "Mandritto", "Montante", "Flamberga", "Claymore", "Spezzaferro",
	"Falciatore", "Spadone del Campione", "Mietitore", "Spaccaelmi", "Spadone della Brace Antica",
	"Spadone dell'Alba Spezzata", "Spadone dell'Eclissi", "Spadone dell'Abisso", "Giudizio del Primo Rift"]
const RINGS: Array[String] = ["Fede di rame", "Anello di ferro", "Anello di bronzo", "Anello d'argento", "Anello con sigillo",
	"Anello d'oro", "Anello del Capitano", "Anello d'ossidiana", "Anello di giada", "Anello del Condottiero",
	"Anello della Brace Antica", "Anello dell'Alba Spezzata", "Anello dell'Eclissi", "Anello dell'Abisso", "Anello del Primo Rift"]
const NECKS: Array[String] = ["Ciondolo", "Medaglione", "Talismano", "Amuleto", "Monile", "Pendente", "Collana del Capitano",
	"Collare", "Amuleto del Cavaliere", "Reliquia", "Amuleto della Brace Antica", "Amuleto dell'Alba Spezzata",
	"Amuleto dell'Eclissi", "Amuleto dell'Abisso", "Occhio del Primo Rift"]

# Rare components of the area of each grade (two different ones, Q68): areas by grade level, NOMI/F-119.
const RARE_PAIRS: Array = [
	["boar_tusk", "scorched_fur"], ["boar_tusk", "scorched_fur"], ["boar_tusk", "scorched_fur"],
	["wolf_fang", "troll_moss"], ["troll_moss", "hollow_arrowhead"], ["wolf_fang", "hollow_arrowhead"], ["wolf_fang", "troll_moss"],
	["golem_core", "crawler_carapace"], ["crawler_carapace", "witch_charm"], ["golem_core", "witch_charm"],
	["golem_core", "crawler_carapace"],
	["wraith_veil", "knight_plate"], ["knight_plate", "colossus_shard"], ["wraith_veil", "colossus_shard"],
	["wraith_veil", "knight_plate"],
]
const RARE_QTY: int = 3
## §8.2: plates and handles per base [plates, handle kind ("" / "grip" / "shieldcore"), handles].
const RECIPES: Dictionary = {"sword": [6, "grip", 2], "greatsword": [10, "grip", 2], "shield": [8, "shieldcore", 2],
	"body": [10, "", 0], "legs": [8, "", 0], "head": [6, "", 0], "feet": [4, "", 0], "hands": [4, "", 0]}

const DESCRIPTIONS: Dictionary = {
	"sword": "Una spada a una mano: danno medio e colpi rapidi.",
	"greatsword": "Un'arma a due mani: lenta, ma colpisce forte.",
	"ring": "Un anello che affina la mira di chi lo porta.",
	"neck": "Un ciondolo che rinforza chi lo porta.",
}
const SLOT_WORDS: Dictionary = {"head": "per la testa", "body": "per il busto", "legs": "per le gambe", "feet": "per i piedi",
	"hands": "per le mani", "shield": "da imbracciare"}
const MATERIAL_WORDS: Dictionary = {
	"plate": "Piastre battute: Armatura alta, nessuna Barriera.",
	"leather": "Cuoio conciato: Armatura media, molta Schivata e un po' di Barriera.",
	"cloth": "Tessuto inciso di rune: poca Armatura, molta Barriera.",
}

# Boss ids (data/maps/bosses.json) and Monolith ids (data/combat/rift_stones.json).
const B: String = "boss_grade_"
const MONOLITHS: Dictionary = {"plains": "redrock_stone", "wood": "whisper_stone", "mines": "mine_stone", "threshold": "threshold_stone"}

## Legendary pieces: [slot, material, grade, name, boss grade, effect, description].
const LEGENDARY_PIECES: Array = [
	["head", "plate", 10, "Cimiero del Cinghiale Bianco", 1, {"type": "hit_cap_pct", "pct": 35}, "Nessun colpo toglie più del 35% dei PV."],
	["feet", "plate", 10, "Zoccoli del Gran Cinghiale", 1, {"type": "target_rule", "rule": "lowest_hp"}, "Colpisci sempre il nemico più ferito."],
	["ring", "", 10, "Zanna d'Argento", 1, {"type": "monolith_loot_mult", "mult": 2}, "Il bottino dei Monoliti è raddoppiato."],
	["body", "plate", 11, "Pelliccia di Cenere", 2, {"type": "reflect_pct", "pct": 25}, "Il 25% del danno subito torna a chi ti colpisce."],
	["hands", "plate", 11, "Artigli del Capobranco", 2, {"type": "armor_pierce_pct", "pct": 30}, "I colpi ignorano il 30% dell'Armatura dei nemici."],
	["sword", "", 11, "Zanna Grigia", 2, {"type": "double_hit_pct", "pct": 15}, "15% di probabilità di colpire due volte."],
	["legs", "plate", 11, "Cosciali del Fango Antico", 3, {"type": "on_kill_timer_cut", "pct": 30}, "Dopo ogni uccisione il prossimo attacco è più vicino del 30%."],
	["neck", "", 11, "Talismano della Palude", 3, {"type": "leech_pct", "pct": 6}, "Recuperi il 6% del danno inflitto."],
	["greatsword", "", 11, "Spaccapalude", 3, {"type": "on_kill_timer_cut", "pct": 100}, "Ogni uccisione fa partire subito il prossimo attacco."],
	["feet", "leather", 13, "Passi del Cavaliere Anonimo", 4, {"type": "every_nth_attack_all", "n": 5}, "Ogni 5 attacchi colpisci tutti i nemici."],
	["ring", "", 13, "Sigillo Senza Nome", 4, {"type": "kill_heal_pct", "pct": 4}, "Ogni uccisione cura il 4% dei PV."],
	["shield", "plate", 13, "Scudo del Giuramento Spezzato", 4, {"type": "block_heal_pct", "pct": 10}, "Una parata riuscita restituisce il 10% dei PV."],
	["hands", "leather", 13, "Guanti del Custode", 5, {"type": "double_hit_pct", "pct": 12}, "12% di probabilità di colpire due volte."],
	["sword", "", 13, "Brace Custode", 5, {"type": "on_kill_timer_cut", "pct": 50}, "Dopo ogni uccisione il prossimo attacco è più vicino del 50%."],
	["head", "leather", 13, "Cappuccio della Fucina Spenta", 5, {"type": "opening_strike"}, "Il primo attacco di ogni incontro parte subito."],
	["neck", "", 14, "Amuleto delle Vene Nere", 6, {"type": "every_nth_attack_all", "n": 4}, "Ogni 4 attacchi colpisci tutti i nemici."],
	["greatsword", "", 14, "Mietitore di Vene", 6, {"type": "every_nth_attack_all", "n": 3}, "Ogni 3 attacchi colpisci tutti i nemici."],
	["body", "leather", 14, "Giubba della Strega", 6, {"type": "low_hp_damage_mult", "hp_pct": 30, "mult": 1.5, "no_auto_eat": false}, "Sotto il 30% dei PV infliggi il 50% di danno in più."],
	["ring", "", 14, "Anello della Guglia Spezzata", 7, {"type": "card_drop_mult", "mult": 2}, "Le Carte cadono il doppio."],
	["shield", "leather", 14, "Rotella del Guardiano", 7, {"type": "reflect_pct", "pct": 40}, "Il 40% del danno subito torna a chi ti colpisce."],
	["legs", "leather", 14, "Calzoni del Vento Alto", 7, {"type": "stat_convert", "from": "evasion_bonus", "to": "armor", "pct": 20}, "Il 20% dell'Evasione diventa Armatura."],
	["sword", "", 15, "Scheggia di Ossidiana Viva", 8, {"type": "armor_pierce_pct", "pct": 50}, "I colpi ignorano metà dell'Armatura dei nemici."],
	["head", "cloth", 15, "Cappello dell'Occhio Vitreo", 8, {"type": "kill_heal_pct", "pct": 3}, "Ogni uccisione cura il 3% dei PV."],
	["feet", "cloth", 15, "Sandali del Colosso Lieve", 8, {"type": "stat_convert", "from": "barrier", "to": "evasion_bonus", "pct": 50}, "La metà della Barriera diventa Evasione."],
	["greatsword", "", 15, "Annuncio dell'Eclissi", 9, {"type": "execute_mult", "hp_pct": 25, "mult": 2}, "Contro nemici sotto il 25% dei PV il danno è doppio."],
	["body", "cloth", 15, "Veste dell'Araldo", 9, {"type": "stat_convert", "from": "barrier", "to": "armor", "pct": 50}, "La metà della Barriera diventa Armatura."],
	["hands", "cloth", 15, "Mitene dell'Ombra Lunga", 9, {"type": "execute_mult", "hp_pct": 30, "mult": 1.5}, "Contro nemici sotto il 30% dei PV il danno è +50%."],
	["shield", "cloth", 15, "Sigillo del Primo Frammento", 10, {"type": "stat_convert", "from": "armor", "to": "barrier", "pct": 40}, "Il 40% dell'Armatura diventa Barriera."],
	["legs", "cloth", 15, "Brache dell'Origine", 10, {"type": "leech_pct", "pct": 4}, "Recuperi il 4% del danno inflitto."],
	["neck", "", 15, "Frammento Originario", 10, {"type": "reflect_pct", "pct": 30}, "Il 30% del danno subito torna a chi ti colpisce."],
]
const CHIPS: Array[String] = ["stone_ember_chip", "stone_eye_chip", "stone_shade_chip", "stone_root_chip"]
## Legendary tools: [tool kind, name, skill level, Monolith key, effect, description].
const LEGENDARY_TOOLS: Array = [
	["hatchet", "Accetta del Taglialegna Paziente", 10, "plains", {"type": "byproduct_mult", "mult": 3}, "I sottoprodotti della maestria escono 3 volte più spesso."],
	["rod", "Canna del Pescatore Sereno", 10, "plains", {"type": "gather_bonus_item", "items": ["rune_slab"], "pct": 2}, "A volte la pesca dà una Lastra runica."],
	["hatchet", "Accetta della Radura Cantante", 30, "wood", {"type": "gather_bonus_item", "items": ["rift_dust"], "pct": 8}, "A volte il taglio dà Polvere del Rift."],
	["pick", "Piccone del Cercatore", 30, "wood", {"type": "gather_bonus_item", "items": CHIPS, "pct": 5}, "Ogni minerale ha il 5% di dare una Scheggia."],
	["pick", "Piccone della Vena Profonda", 50, "mines", {"type": "byproduct_mult", "mult": 3}, "I sottoprodotti della maestria escono 3 volte più spesso."],
	["rod", "Canna dei Pozzi Neri", 50, "mines", {"type": "byproduct_mult", "mult": 3}, "I sottoprodotti della maestria escono 3 volte più spesso."],
	["hatchet", "Accetta del Bosco Perduto", 75, "threshold", {"type": "gather_grade_up_pct", "pct": 10}, "Il 10% dei tagli dà il legno del grado superiore."],
	["pick", "Piccone dell'Ultima Galleria", 75, "threshold", {"type": "gather_grade_up_pct", "pct": 10}, "Il 10% dei minerali è del grado superiore."],
	["rod", "Canna del Leviatano Dormiente", 75, "threshold", {"type": "gather_grade_up_pct", "pct": 10}, "Il 10% delle catture dà il pesce del grado superiore."],
]
const TOOL_SKILL: Dictionary = {"hatchet": "forestry", "pick": "quarrying", "rod": "angling"}
const TOOL_STATS: Dictionary = {"plains": [-26, 3], "wood": [-28, 4], "mines": [-30, 5], "threshold": [-35, 7]}

var _balance: Dictionary = {}
var _levels: Array = []
var _grade_material: Array = []
var _weights: Dictionary = {}
var _budget: Dictionary = {}
var _materials: Dictionary = {}
var _icons: RefCounted = preload("res://tools/gen_equipment_icons.gd").new()


func _initialize() -> void:
	_balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json")) as Dictionary
	_levels = (_balance["equipment"] as Dictionary)["grade_levels"] as Array
	_grade_material = (_balance["equipment"] as Dictionary)["grade_material"] as Array
	_weights = (_balance["equipment"] as Dictionary)["slot_weights"] as Dictionary
	_budget = (_balance["equipment"] as Dictionary)["set_budget"] as Dictionary
	_materials = ((_balance["combat"] as Dictionary)["armor"] as Dictionary)["materials"] as Dictionary
	_write_catalogue()
	quit(0)


func _write_catalogue() -> void:
	var weapons: Array = []
	var jewels: Array = []
	var by_material: Dictionary = {"plate": [], "leather": [], "cloth": []}
	for g: int in range(1, GRADES + 1):
		weapons.append(_weapon("sword", g, false, 1.0))
		weapons.append(_weapon("greatsword", g, false, 1.0))
		jewels.append(_jewel("ring", g))
		jewels.append(_jewel("neck", g))
		for material: String in MATERIALS:
			for slot: String in ARMOUR_SLOTS:
				(by_material[material] as Array).append(_armour(slot, material, g, false))
	var masterworks: Array = []
	var blueprints: Array = []
	for g: int in range(1, GRADES + 1):
		for slot: String in MASTER_SLOTS:
			var item: Dictionary = _masterwork(slot, g)
			masterworks.append(item)
			blueprints.append(_blueprint(slot, g, item))
	var legendaries: Array = []
	var counters: Dictionary = {}
	for row: Array in LEGENDARY_PIECES:
		counters[row[0]] = int(counters.get(row[0], 0)) + 1
		legendaries.append(_legendary_piece(row, int(counters[row[0]])))
	var tools: Array = []
	var tool_counters: Dictionary = {}
	for row: Array in LEGENDARY_TOOLS:
		tool_counters[row[0]] = int(tool_counters.get(row[0], 0)) + 1
		tools.append(_legendary_tool(row, int(tool_counters[row[0]])))
	_write("equipment_weapons.json", "Armi (02_FORMULAS.md §8.4, F-118): spade e spadoni dei 15 gradi. Generato da tools/gen_equipment.gd.", "items", weapons)
	_write("equipment_jewels.json", "Anelli e colli (02_FORMULAS.md §8.4): 15 gradi. Generato da tools/gen_equipment.gd.", "items", jewels)
	_write("equipment_plate.json", "Armature di Piastre e scudi, 15 gradi (F-118): Armatura alta, niente Barriera. Generato da tools/gen_equipment.gd.", "items", by_material["plate"] as Array)
	_write("equipment_leather.json", "Armature di Cuoio e rotelle, 15 gradi (F-118): Armatura media, Schivata. Generato da tools/gen_equipment.gd.", "items", by_material["leather"] as Array)
	_write("equipment_cloth.json", "Armature di Tessuto runico e sigilli, 15 gradi (F-118): Barriera alta. Generato da tools/gen_equipment.gd.", "items", by_material["cloth"] as Array)
	_write("equipment_masterwork.json", "Basi dei Capolavori (F-119): 8 tipi di Piastre x 15 gradi, solo da progetti. Generato da tools/gen_equipment.gd.", "items", masterworks)
	_write("equipment_legendary.json", "Leggendari (F-120): 30 pezzi, 3 per slot. Fonte ed effetto di NOMI.md. Generato da tools/gen_equipment.gd.", "items", legendaries)
	_write("tools_legendary.json", "Attrezzi leggendari (F-120): 9, sostituiscono l'attrezzo unico. Generato da tools/gen_equipment.gd.", "items", tools)
	_write("blueprints.json", "Progetti (F-119): uno per base di Capolavoro, 8 tipi x 15 gradi = 120; costo x3 piu due componenti rari. Generato da tools/gen_equipment.gd.", "items", blueprints)
	print_rich("gen_equipment: %d weapons, %d jewels, %d armour, %d masterworks, %d blueprints, %d legendary pieces, %d legendary tools" % [
			weapons.size(), jewels.size(), (by_material["plate"] as Array).size() * 3, masterworks.size(), blueprints.size(),
			legendaries.size(), tools.size()])


# --- pieces ------------------------------------------------------------------------------------------------------

func _legacy_id(slot: String, g: int) -> String:
	return "%s_%s" % [METALS[g - 1], LEGACY_SUFFIX[slot]]


func _id(slot: String, material: String, g: int) -> String:
	if g <= 8 and (material == "plate" or material == ""):
		return _legacy_id(slot, g)
	if material == "":
		return "%s_%d" % [slot, g]
	return "%s_%s_%d" % [slot, material, g]


func _value(slot: String, g: int) -> int:
	if slot == "ring":
		return RING_VALUE[g - 1]
	if slot == "neck":
		return NECK_VALUE[g - 1]
	return roundi(PLATE_VALUE[g - 1] * float(SLOT_VALUE_MULT[slot]))


func _level(g: int) -> int:
	return int(_levels[g - 1])


func _weapon(slot: String, g: int, _unused: bool, _mult: float) -> Dictionary:
	var two_handed: bool = slot == "greatsword"
	var dmg_max: int = 12 + 8 * (g - 1) if two_handed else 6 + 4 * (g - 1)
	var dmg_min: int = roundi((0.5 if two_handed else 0.6) * dmg_max)
	var id: String = _id(slot, "", g)
	var equip: Dictionary = {"slot": "weapon", "kind": slot, "grade": g, "requirements": {"character": _level(g)},
		"modifiers": [{"stat": "accuracy_bonus", "value": (5 if two_handed else 4) * g}],
		"weapon": {"dmg_min": dmg_min, "dmg_max": dmg_max, "style": "blade", "attack_interval_ms": 3200 if two_handed else 2000,
			"two_handed": two_handed}}
	return _item(id, (GREATSWORDS if two_handed else SWORDS)[g - 1], _icon_for(slot, "plate", "normal", id), _value(slot, g),
			SLOT_ORDER[slot] + g, DESCRIPTIONS[slot], equip)


func _jewel(slot: String, g: int) -> Dictionary:
	var is_ring: bool = slot == "ring"
	var id: String = _id(slot, "", g)
	var equip: Dictionary = {"slot": slot, "grade": g, "requirements": {"character": _level(g)},
		"modifiers": [{"stat": "accuracy_bonus" if is_ring else "max_hp_flat", "value": 3 * g if is_ring else 6 * g + 4}]}
	return _item(id, (RINGS if is_ring else NECKS)[g - 1], _icon_for(slot, "plate", "normal", id), _value(slot, g),
			SLOT_ORDER[slot] + g, DESCRIPTIONS[slot], equip)


## The modifiers of an armour piece (F-118): armour, barrier (only if > 0), evasion, and the block chance of a shield.
func _armour_modifiers(slot: String, material: String, g: int) -> Array:
	var level: int = _level(g)
	var armor_budget: float = float((_budget["armor"] as Array)[0]) + float((_budget["armor"] as Array)[1]) * level
	var evasion_budget: float = roundf(float((_budget["evasion"] as Array)[0]) + float((_budget["evasion"] as Array)[1]) * level)
	var weight: float = float(_weights["offhand" if slot == "shield" else slot])
	var mult: Dictionary = _materials[material] as Dictionary
	var mods: Array = []
	var armor: int = roundi(armor_budget * weight * float(mult["armor"]))
	var barrier: int = roundi(armor_budget * weight * float(mult["barrier"]))
	var evasion: int = roundi(evasion_budget * weight * float(mult["evasion"]))
	if armor > 0:
		mods.append({"stat": "armor", "value": armor})
	if barrier > 0:
		mods.append({"stat": "barrier", "value": barrier})
	if evasion > 0:
		mods.append({"stat": "evasion_bonus", "value": evasion})
	if slot == "shield":
		mods.append({"stat": "block_chance", "value": 5 + floori(10.0 * (g - 1) / 14.0)})
	return mods


func _armour_equip(slot: String, material: String, g: int) -> Dictionary:
	var equip: Dictionary = {"slot": EQUIP_SLOT[slot]}
	if slot == "shield":
		equip["kind"] = "shield"
	equip["grade"] = g
	equip["material"] = material
	return equip


func _armour(slot: String, material: String, g: int, _unused: bool) -> Dictionary:
	var equip: Dictionary = _armour_equip(slot, material, g)
	equip["requirements"] = {"character": _level(g)}
	equip["modifiers"] = _armour_modifiers(slot, material, g)
	var id: String = _id(slot, material, g)
	var order: int = int(SLOT_ORDER[slot]) + MATERIALS.find(material) * 20 + g
	return _item(id, "%s %s" % [(TYPE_NAMES[material] as Dictionary)[slot], EPITHETS[g - 1]],
			_icon_for(slot, material, "normal", id), _value(slot, g), order,
			"Un pezzo %s. %s" % [SLOT_WORDS[slot], MATERIAL_WORDS[material]], equip)


func _masterwork(slot: String, g: int) -> Dictionary:
	var is_weapon: bool = slot == "sword" or slot == "greatsword"
	var id: String = "mw_%s_%d" % [slot, g]
	var base: Dictionary
	_icons.quiet = true
	if is_weapon:
		base = _weapon(slot, g, false, 1.0)
	else:
		base = _armour(slot, "plate", g, false)
	_icons.quiet = false
	var equip: Dictionary = base["equip"] as Dictionary
	var ordered: Dictionary = {}
	for key: String in ["slot", "kind", "grade", "material"]:
		if equip.has(key):
			ordered[key] = equip[key]
	ordered["masterwork"] = true
	for key: String in ["requirements", "modifiers", "weapon"]:
		if equip.has(key):
			ordered[key] = equip[key]
	var order: int = 1200 + MASTER_SLOTS.find(slot) * 20 + g
	return _item(id, "%s %s" % [MASTER_TYPES[slot], MARKS[g - 1]], _icon_for(slot, "plate", "masterwork", id),
			2 * int(base["value"]), order, "Un pezzo forgiato con cura, migliore di ogni altro del suo grado.", ordered)


func _blueprint(slot: String, g: int, masterwork: Dictionary) -> Dictionary:
	var m: int = int(_grade_material[g - 1])
	var recipe: Array = RECIPES[slot] as Array
	var inputs: Array = [{"item": "%s_plate" % METALS[m - 1], "qty": int(recipe[0]) * 3}]
	if recipe[1] != "":
		inputs.append({"item": "%s_%s" % [WOODS[m - 1], recipe[1]], "qty": int(recipe[2]) * 3})
	var pair: Array = RARE_PAIRS[g - 1] as Array
	var item: Dictionary = {"id": "bp_mw_%s_%d" % [slot, g], "name": "Progetto: %s" % masterwork["name"], "category": "blueprint",
		"icon": "res://assets/icons/items/bp_grade_%d.svg" % m, "value": 0, "sort_order": 3000 + MASTER_SLOTS.find(slot) * 20 + g,
		"description": "Lo schema per forgiare: %s." % masterwork["name"],
		"blueprint": {"base": masterwork["id"], "grade": m, "inputs": inputs,
			"rare_components": [{"item": pair[0], "qty": RARE_QTY}, {"item": pair[1], "qty": RARE_QTY}]}}
	return item


func _legendary_piece(row: Array, n: int) -> Dictionary:
	var slot: String = row[0]
	var material: String = row[1]
	var g: int = int(row[2])
	var is_weapon: bool = slot == "sword" or slot == "greatsword"
	var base: Dictionary
	_icons.quiet = true
	if is_weapon:
		base = _weapon(slot, g, false, 1.0)
	elif slot == "ring" or slot == "neck":
		base = _jewel(slot, g)
	else:
		base = _armour(slot, material, g, false)
	_icons.quiet = false
	var equip: Dictionary = base["equip"] as Dictionary
	var ordered: Dictionary = {}
	for key: String in ["slot", "kind", "grade", "material", "requirements", "modifiers", "weapon"]:
		if equip.has(key):
			ordered[key] = equip[key]
	ordered["legendary"] = {"source": {"type": "boss", "id": "%s%d" % [B, int(row[4])], "chance_pct": 0.6}, "effects": [row[5]]}
	var id: String = "leg_%s_%d" % [slot, n]
	return _item(id, row[3], _icon_for(slot, material if material != "" else "plate", "legendary", id), 5 * int(base["value"]),
			1700 + floori(float(SLOT_ORDER[slot]) / 10.0) + n, row[6], ordered)


func _legendary_tool(row: Array, n: int) -> Dictionary:
	var kind: String = row[0]
	var skill: String = TOOL_SKILL[kind]
	var stats: Array = TOOL_STATS[row[3]] as Array
	var id: String = "leg_%s_%d" % [kind, n]
	var equip: Dictionary = {"slot": "tool_%s" % skill, "grade": 1, "requirements": {skill: int(row[2])},
		"modifiers": [{"stat": "skill_interval_pct", "value": stats[0], "scope": "skill:%s" % skill},
			{"stat": "double_item_chance", "value": stats[1], "scope": "skill:%s" % skill}],
		"legendary": {"source": {"type": "monolith", "id": MONOLITHS[row[3]], "chance_pct": 0.3}, "effects": [row[4]]}}
	var item: Dictionary = _item(id, row[1], _icon_for("tool_" + kind, "plate", "legendary", id), 100 * int(row[2]),
			2000 + int(row[2]) + n, row[5], equip)
	item["category"] = "tool"
	return item


func _item(id: String, item_name: String, icon: String, value: int, sort_order: int, description: String, equip: Dictionary) -> Dictionary:
	return {"id": id, "name": item_name, "category": "equipment", "icon": icon, "value": value, "sort_order": sort_order,
		"description": description, "equip": equip}


# --- files -------------------------------------------------------------------------------------------------------

func _write(file: String, doc: String, key: String, items: Array) -> void:
	var lines: PackedStringArray = []
	for index: int in items.size():
		lines.append("    " + JSON.stringify(items[index], "", false) + ("," if index < items.size() - 1 else ""))
	var text: String = "{\n  \"_doc\": %s,\n  \"%s\": [\n%s\n  ]\n}\n" % [JSON.stringify(doc), key, "\n".join(lines)]
	var f: FileAccess = FileAccess.open(OUT_DIR + file, FileAccess.WRITE)
	f.store_string(text)
	f.close()
## The icon path of a piece. Pieces of the legacy ids keep their old icon; the others get one per slot x material x
## rarity (legendaries: one each), written by tools/gen_equipment_icons.gd.
func _icon_for(slot: String, material: String, rarity: String, id: String) -> String:
	var legacy: bool = rarity == "normal" and material == "plate" and id.find("_") > 0 and METALS.has(id.get_slice("_", 0))
	if legacy:
		return ICON_PATH + id + ".svg"
	var icon_name: String = id if rarity == "legendary" else "eq_%s_%s_%s" % [slot, material, rarity] if rarity == "normal" \
			else "eq_%s_%s" % [slot, rarity]
	_icons.write(icon_name, slot, material, rarity)
	return ICON_PATH + icon_name + ".svg"
