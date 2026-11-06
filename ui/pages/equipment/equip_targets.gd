class_name EquipTargets
extends RefCounted
## Which slots a piece can be dropped on, and where a right click puts it (docs/UI_GDR.md §3, U5). Stateless: it
## only reads the session (the definition of the piece, the class, the worn weapons) to decide what to light up while
## dragging; it never changes anything. The authority stays `Equipment.equip`: whatever it refuses (combat in
## progress, a full Armory...) is shown as its reason when the command is sent.
##
## The slots lit are those where the piece fits (its own slot, or the offhand for a one-handed weapon), whose
## weapon kind the class allows, whose requirements the character meets and where the resulting pair of weapons has a
## setup (`ClassDef.setup_for`, F-72).

const WEAPON: StringName = &"weapon"
const OFFHAND: StringName = &"offhand"


## The slots where `equipment.equip(uid, slot)` can work, in `Equipment.SLOTS` order; empty for a worn piece.
static func compatible_slots(session: GameSession, uid: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var def: ItemDef = _def_of(session, uid)
	if def == null or session.equipment.slot_of(uid) != &"":
		return result
	for slot: StringName in Equipment.SLOTS:
		if _fits(def, slot) and _allowed(session, def, slot):
			result.append(slot)
	return result


## Slot argument for the right click: the offhand for a one-handed weapon when a one-handed weapon is in hand and the
## offhand is free (U5), otherwise `&""` (the natural slot of the piece).
static func right_click_slot(session: GameSession, uid: int) -> StringName:
	var def: ItemDef = _def_of(session, uid)
	if def == null or not _is_one_handed_weapon(def) or session.equipment.get_uid(OFFHAND) != 0:
		return &""
	var in_hand: ItemDef = _worn_def(session, WEAPON)
	return OFFHAND if in_hand != null and _is_one_handed_weapon(in_hand) else &""


static func _fits(def: ItemDef, slot: StringName) -> bool:
	return slot == def.equip.slot or (slot == OFFHAND and _is_one_handed_weapon(def))


static func _allowed(session: GameSession, def: ItemDef, slot: StringName) -> bool:
	var cls: ClassDef = session.character.class_def()
	if cls == null or not session.character.meets_requirements(def.equip.requirements):
		return false
	if slot == WEAPON and not cls.weapon_kinds.has(def.equip.kind):
		return false
	if slot == OFFHAND and not cls.offhand_kinds.has(def.equip.kind):
		return false
	return _has_setup(session, cls, def, slot)


## F-72 on the pair of hands after the change; without a weapon the offhand can only be a shield.
static func _has_setup(session: GameSession, cls: ClassDef, def: ItemDef, slot: StringName) -> bool:
	var main: ItemDef = _worn_def(session, WEAPON)
	var second: ItemDef = _worn_def(session, OFFHAND)
	if slot == WEAPON:
		main = def
		if def.equip.weapon != null and def.equip.weapon.two_handed:
			second = null
	elif slot == OFFHAND:
		second = def
		if main != null and main.equip.weapon != null and main.equip.weapon.two_handed:
			main = null
	else:
		return true
	if main == null:
		return second == null or second.equip.kind == Equipment.SHIELD_KIND
	return cls.setup_for(main.equip.kind, second.equip.kind if second != null else &"") != null


static func _is_one_handed_weapon(def: ItemDef) -> bool:
	return def.equip != null and def.equip.slot == WEAPON and def.equip.weapon != null \
			and not def.equip.weapon.two_handed


static func _def_of(session: GameSession, uid: int) -> ItemDef:
	var inst: ItemInstance = session.armory.get_instance(uid)
	var def: ItemDef = session.data.item(inst.base_id) if inst != null else null
	return def if def != null and def.equip != null else null


static func _worn_def(session: GameSession, slot: StringName) -> ItemDef:
	return _def_of(session, session.equipment.get_uid(slot))
