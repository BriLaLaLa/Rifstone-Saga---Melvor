extends RefCounted
## Content of the legendaries of the Monkey Den for tools/gen_equipment.gd (F-143, M22-03); the numbers of the pieces come from the generator.

## Legendary pieces of the Monkey Den (F-143, M22-03): [slot, material, grade, name, dungeon id, effect, description]. Grade 11 = the grade
## whose level (50) is the nearest to the level of the boss; the source is `{"type": "dungeon"}`, ids `leg_<slot>_monkey`.
const MONKEY_PIECES: Array = [
	["sword", "", 11, "Lama della Liana Spezzata", "monkey_den", {"type": "double_hit_pct", "pct": 12}, "12% di probabilità di colpire due volte."],
	["greatsword", "", 11, "Randello del Re dei Rami", "monkey_den", {"type": "execute_mult", "hp_pct": 25, "mult": 1.8}, "Contro nemici sotto il 25% dei PV il danno è +80%."],
	["shield", "plate", 11, "Scudo di Gusci di Cocco", "monkey_den", {"type": "block_heal_pct", "pct": 8}, "Una parata riuscita restituisce l'8% dei PV."],
	["ring", "", 11, "Anello della Scimmia Avida", "monkey_den", {"type": "kill_heal_pct", "pct": 2}, "Ogni uccisione cura il 2% dei PV."],
	["neck", "", 11, "Amuleto della Stratega", "monkey_den", {"type": "stat_convert", "from": "barrier", "to": "armor", "pct": 40}, "Il 40% della Barriera diventa Armatura."],
	["hands", "leather", 11, "Guanti da Cima d'Albero", "monkey_den", {"type": "on_kill_timer_cut", "pct": 60}, "Dopo ogni uccisione il prossimo attacco è più vicino del 60%."],
]
const DUNGEON_LEGENDARY_PCT: float = 3.5


static func source_of(dungeon_id: String) -> Dictionary:
	return {"type": "dungeon", "id": dungeon_id, "chance_pct": DUNGEON_LEGENDARY_PCT}
