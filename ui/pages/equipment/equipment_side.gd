class_name EquipmentSide
extends RefCounted
## Redraws of the paper doll header and of the stats column of the Equipment page (docs/UI_GDR.md §3): everything is
## read from the session at the call; no state.

const LEVEL_TEXT: String = "Livello %s  ·  Assetto: %s"
const UNARMED_TEXT: String = "Mani nude"
const NO_FOOD_TEXT: String = "Nessun cibo scelto"
const FOOD_TEXT: String = "Cibo: %s (in bank: %s)"


## Class and setup labels and the 12 slots of `doll`.
static func redraw_doll(session: GameSession, doll: EquipmentDoll, class_label: Label, setup_label: Label) -> void:
	var class_def: ClassDef = session.character.class_def()
	class_label.text = class_def.name if class_def != null else ""
	var setup: SetupDef = session.equipment.setup_def()
	setup_label.text = LEVEL_TEXT % [NumberFormat.format_int(session.character.get_level()),
			setup.name if setup != null else UNARMED_TEXT]
	for view: EquipmentSlotView in doll.slot_views():
		var inst: ItemInstance = session.armory.get_instance(session.equipment.get_uid(view.slot()))
		var base: ItemDef = session.data.item(inst.base_id) if inst != null else null
		if base == null:
			view.show_empty()
		else:
			view.show_piece(inst, base)


## Totals, food line and the state of the "Togli" button.
static func redraw_side(session: GameSession, stats: RichTextLabel, food_label: Label, clear_button: Button) -> void:
	stats.text = EquipmentStatsText.totals(session)
	var food_id: StringName = session.equipment.get_food()
	var food: ItemDef = session.data.item(food_id) if food_id != &"" else null
	clear_button.disabled = food == null
	food_label.text = NO_FOOD_TEXT if food == null else FOOD_TEXT % [food.name,
			NumberFormat.format_int(session.bank.get_count(food_id))]
