class_name EquipmentSide
extends RefCounted
## Redraws of the paper doll header and of the stats column of the Equipment page (docs/UI_GDR.md §3): everything is
## read from the session at the call; no state.

const LEVEL_TEXT: String = "Livello %s  ·  Assetto: %s"
const UNARMED_TEXT: String = "Mani nude"


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


## Totals of the stats column.
static func redraw_side(session: GameSession, stats: RichTextLabel) -> void:
	stats.text = EquipmentStatsText.totals(session)


## The Cibo slot: the chosen food and its count in the Bank (the same Bank stack, nothing is duplicated).
static func redraw_food(session: GameSession, slot: FoodSlotView) -> void:
	var food_id: StringName = session.equipment.get_food()
	var food: ItemDef = session.data.item(food_id) if food_id != &"" else null
	slot.show_food(food, session.bank.get_count(food_id) if food != null else 0)


## The foods the player can choose: [{"item": ItemDef, "count": int}] of the Bank stacks that are food.
static func food_choices(session: GameSession) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for stack: Dictionary in session.bank.stacks():
		var item: ItemDef = session.data.item(stack["item"] as StringName)
		if item != null and item.is_food():
			choices.append({"item": item, "count": stack["count"]})
	return choices


## Text of the capacity label: pieces in the armory, capacity and worn pieces.
static func capacity_label_text(session: GameSession) -> String:
	var worn: int = 0
	for slot: StringName in Equipment.SLOTS:
		worn += 1 if session.equipment.get_uid(slot) != 0 else 0
	return ArmoryTexts.capacity_text(session.deposit.used(), session.deposit.capacity(), worn)


## Lights the slots of `doll` that accept the dragged piece `data` (a `PieceDrag` payload from the inventory).
static func light_targets(session: GameSession, doll: EquipmentDoll, data: Variant) -> void:
	var targets: Array[StringName] = []
	if PieceDrag.is_piece(data) and PieceDrag.from_of(data) == &"":
		targets = EquipTargets.compatible_slots(session, PieceDrag.uid_of(data))
	for view: EquipmentSlotView in doll.slot_views():
		view.set_glow(targets.has(view.slot()))
