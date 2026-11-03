class_name Equipment
extends RefCounted
## Worn items, chosen food and stance (docs/01_GDD.md §9).
##
## An item is always in one place: the bank or one slot. Equipping takes 1 from the bank and the displaced pieces go
## back; if the bank has no room the command fails with `bank_full` and nothing changes. A two-handed weapon needs a
## free offhand and an offhand displaces a two-handed weapon. The weapon cannot change while combat is active.
## Worn modifiers are the `equipment:<slot>` sources. Food is a reference to a bank item (eaten straight from the
## bank). Signals: `equipment_changed(slot, item)` after the change (food and stance use the ids `&"food"` and
## `&"stance"`); `new_game`/`from_save` emit nothing.
## Dependencies: data, events, modifiers, bank, skills, combat (only `is_active`, null-safe).

const SAVE_KEY: StringName = &"equipment"
const LOG_CATEGORY: String = "equipment"
const SLOTS: Array[StringName] = [&"head", &"body", &"legs", &"feet", &"hands", &"neck", &"ring",
	&"weapon", &"offhand", &"tool_forestry", &"tool_quarrying", &"tool_angling"]
const STANCES: Array[StringName] = [&"offensive", &"balanced", &"defensive"]
const WEAPON: StringName = &"weapon"
const OFFHAND: StringName = &"offhand"
const FOOD_ID: StringName = &"food"
const STANCE_ID: StringName = &"stance"
const SOURCE_PREFIX: String = "equipment:"
const UNARMED_STYLE_KEY: String = "combat.unarmed.style"
const UNARMED_INTERVAL_KEY: String = "combat.unarmed.attack_interval_ms"
const SAVE_SLOTS_KEY: String = "slots"
const SAVE_FOOD_KEY: String = "food"
const SAVE_STANCE_KEY: String = "stance"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _bank: Bank
var _unarmed_style: StringName = &""
var _unarmed_interval_ms: int = 0
# State: slot -> item id (only occupied slots), food item id (&"" = none), stance.
var _worn: Dictionary[StringName, StringName] = {}
var _food: StringName = &""
var _stance: StringName = STANCES[0]


func _init(session: GameSession) -> void:
	assert(session != null, "Equipment needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_bank = session.bank
	_unarmed_style = StringName(str(_data.balance_value(UNARMED_STYLE_KEY)))
	_unarmed_interval_ms = int(_data.balance_value(UNARMED_INTERVAL_KEY))


func get_item(slot: StringName) -> StringName:
	return _worn.get(slot, &"")


func equip(item_id: StringName) -> CommandResult:
	if not _data.has_item(item_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var def: ItemDef = _data.item(item_id)
	if not def.is_equippable():
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	for skill_id: StringName in def.equip.requirements:
		if _session.skills.get_level(skill_id) < def.equip.requirements[skill_id]:
			return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if not _bank.has(item_id, 1):
		return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	var slot: StringName = def.equip.slot
	var displaced: Dictionary[StringName, StringName] = _displaced_by(def)
	if (slot == WEAPON or displaced.has(WEAPON)) and _combat_active():
		return CommandResult.fail(Reasons.COMBAT_ACTIVE)
	if not _has_room_after_taking(item_id, displaced):
		return CommandResult.fail(Reasons.BANK_FULL)
	_modifiers.begin_batch()
	_bank.remove(item_id, 1)
	for old_slot: StringName in displaced:
		_bank.add(displaced[old_slot], 1)
		_clear_slot(old_slot)
	_worn[slot] = item_id
	_modifiers.set_source(StringName(SOURCE_PREFIX + String(slot)), def.equip.modifiers)
	_modifiers.end_batch()
	for old_slot: StringName in displaced:
		if old_slot != slot:
			_events.equipment_changed.emit(old_slot, &"")
	_events.equipment_changed.emit(slot, item_id)
	return CommandResult.success()


func unequip(slot: StringName) -> CommandResult:
	var item_id: StringName = get_item(slot)
	if item_id == &"":
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	if slot == WEAPON and _combat_active():
		return CommandResult.fail(Reasons.COMBAT_ACTIVE)
	if not _bank.can_add(item_id):
		return CommandResult.fail(Reasons.BANK_FULL)
	_bank.add(item_id, 1)
	_clear_slot(slot)
	_events.equipment_changed.emit(slot, &"")
	return CommandResult.success()


func get_food() -> StringName:
	return _food


## &"" clears the choice; otherwise the item must be food and be in the bank.
func set_food(item_id: StringName) -> CommandResult:
	if item_id != &"":
		if not _data.has_item(item_id):
			return CommandResult.fail(Reasons.UNKNOWN_ID)
		if not _data.item(item_id).is_food():
			return CommandResult.fail(Reasons.NOT_FOOD)
		if not _bank.has(item_id, 1):
			return CommandResult.fail(Reasons.NOT_ENOUGH_ITEMS)
	_food = item_id
	_events.equipment_changed.emit(FOOD_ID, item_id)
	return CommandResult.success()


func get_stance() -> StringName:
	return _stance


func set_stance(stance: StringName) -> CommandResult:
	if not STANCES.has(stance):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	_stance = stance
	_events.equipment_changed.emit(STANCE_ID, stance)
	return CommandResult.success()


## The worn weapon; null = bare hands.
func weapon() -> ItemDef:
	var item_id: StringName = get_item(WEAPON)
	return _data.item(item_id) if item_id != &"" else null


func style() -> StringName:
	var worn: ItemDef = weapon()
	if worn != null and worn.equip.weapon != null:
		return worn.equip.weapon.style
	return _unarmed_style


func base_attack_interval_ms() -> int:
	var worn: ItemDef = weapon()
	if worn != null and worn.equip.weapon != null:
		return worn.equip.weapon.attack_interval_ms
	return _unarmed_interval_ms


## Sources `equipment:<slot>` of the worn pieces (the session has cleared every source first).
func rebuild_modifiers() -> void:
	for slot: StringName in _worn:
		_modifiers.set_source(StringName(SOURCE_PREFIX + String(slot)), _data.item(_worn[slot]).equip.modifiers)


## docs/01_GDD.md §1.1: nothing worn, no food, stance offensive.
func new_game() -> void:
	_worn.clear()
	_food = &""
	_stance = STANCES[0]


func to_save() -> Dictionary:
	var slots: Dictionary = {}
	for slot: StringName in SLOTS:
		if _worn.has(slot):
			slots[String(slot)] = String(_worn[slot])
	return {SAVE_SLOTS_KEY: slots, SAVE_FOOD_KEY: String(_food), SAVE_STANCE_KEY: String(_stance)}


## Slots with an unknown item, a non-equippable one or one for another slot are reported and left empty.
func from_save(d: Dictionary) -> void:
	new_game()
	var slots: Variant = d.get(SAVE_SLOTS_KEY, {})
	if slots is Dictionary:
		for key: Variant in (slots as Dictionary):
			_load_slot(StringName(str(key)), (slots as Dictionary)[key])
	else:
		Log.warn(LOG_CATEGORY, "invalid slots in save: loaded as empty")
	if _worn_weapon_is_two_handed() and get_item(OFFHAND) != &"":
		Log.warn(LOG_CATEGORY, "two-handed weapon with offhand '%s' in save: offhand dropped" % get_item(OFFHAND))
		_worn.erase(OFFHAND)
	var food: Variant = d.get(SAVE_FOOD_KEY, "")
	if food is String and (food == "" or _is_food(StringName(food))):
		_food = StringName(food)
	else:
		Log.warn(LOG_CATEGORY, "invalid food %s in save: loaded as none" % str(food))
	var stance: Variant = d.get(SAVE_STANCE_KEY, String(STANCES[0]))
	if stance is String and STANCES.has(StringName(stance)):
		_stance = StringName(stance)
	else:
		Log.warn(LOG_CATEGORY, "invalid stance %s in save: loaded as %s" % [str(stance), STANCES[0]])


func _is_food(item_id: StringName) -> bool:
	return _data.has_item(item_id) and _data.item(item_id).is_food()


func _load_slot(slot: StringName, value: Variant) -> void:
	var item_id: StringName = StringName(str(value))
	if not (SLOTS.has(slot) and value is String and _data.has_item(item_id)):
		Log.warn(LOG_CATEGORY, "invalid slot entry %s=%s in save: ignored" % [slot, str(value)])
		return
	var def: ItemDef = _data.item(item_id)
	if not def.is_equippable() or def.equip.slot != slot:
		Log.warn(LOG_CATEGORY, "item '%s' does not fit slot '%s': ignored" % [item_id, slot])
		return
	_worn[slot] = item_id


# slot -> item that leaves its slot when `def` is worn: the piece of its own slot, the offhand for a two-handed
# weapon, the two-handed weapon for an offhand.
func _displaced_by(def: ItemDef) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	var slot: StringName = def.equip.slot
	if get_item(slot) != &"":
		result[slot] = get_item(slot)
	if slot == WEAPON and def.equip.weapon != null and def.equip.weapon.two_handed and get_item(OFFHAND) != &"":
		result[OFFHAND] = get_item(OFFHAND)
	if slot == OFFHAND and _worn_weapon_is_two_handed():
		result[WEAPON] = get_item(WEAPON)
	return result


func _worn_weapon_is_two_handed() -> bool:
	var worn: ItemDef = weapon()
	return worn != null and worn.equip.weapon != null and worn.equip.weapon.two_handed


# Whether the displaced pieces fit once `taken` has left the bank (one unit; its stack frees if it was the last).
func _has_room_after_taking(taken: StringName, displaced: Dictionary[StringName, StringName]) -> bool:
	var free: int = _bank.capacity() - _bank.used()
	if _bank.get_count(taken) == 1:
		free += 1
	var needed: int = 0
	for old_slot: StringName in displaced:
		var old_id: StringName = displaced[old_slot]
		if _bank.get_count(old_id) - (1 if old_id == taken else 0) <= 0:
			needed += 1
	return needed <= free


func _clear_slot(slot: StringName) -> void:
	_worn.erase(slot)
	_modifiers.clear_source(StringName(SOURCE_PREFIX + String(slot)))


func _combat_active() -> bool:
	var combat: Variant = _session.get(&"combat")
	return combat != null and bool((combat as Object).call(&"is_active"))
