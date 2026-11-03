class_name Equipment
extends RefCounted
## Worn pieces (by Armory `uid`), chosen food and the setup derived from the weapon and offhand (docs/01_GDD.md §9).
##
## A worn piece stays in the Armory, flagged as worn (`Armory.set_worn`). Equipping into an occupied slot, a two-handed
## weapon, an offhand with a two-handed weapon and taking the weapon off with a sword in the offhand send pieces back
## to the not-worn ones; if the Armory has no room for them the command fails with `armory_full` and nothing changes.
## The setup (F-72) is derived, never chosen: its modifiers are the source `setup:<id>`; the pieces' are
## `equipment:<slot>` (Armory.instance_modifiers). Weapon and offhand do not change during an encounter.
## Signals: `equipment_changed(slot, uid)` (0 = empty) and `food_changed(item_id)` after the change;
## `new_game`/`from_save` emit nothing.
## Dependencies: data, events, modifiers, bank (food only), character, armory, combat (only `in_encounter`, null-safe).

const SAVE_KEY: StringName = &"equipment"
const LOG_CATEGORY: String = "equipment"
const SLOTS: Array[StringName] = [&"head", &"body", &"legs", &"feet", &"hands", &"neck", &"ring",
	&"weapon", &"offhand", &"tool_forestry", &"tool_quarrying", &"tool_angling"]
const WEAPON: StringName = &"weapon"
const OFFHAND: StringName = &"offhand"
const UNARMED: StringName = &"unarmed"
const SHIELD_KIND: StringName = &"shield"
const SOURCE_PREFIX: String = "equipment:"
const SETUP_PREFIX: String = "setup:"
const UNARMED_STYLE_KEY: String = "combat.unarmed.style"
const UNARMED_INTERVAL_KEY: String = "combat.unarmed.attack_interval_ms"
const DUAL_MULT_KEY: String = "combat.dual_wield.interval_mult"
const SAVE_SLOTS_KEY: String = "slots"
const SAVE_FOOD_KEY: String = "food"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _bank: Bank
var _armory: Armory
var _unarmed_style: StringName = &""
var _unarmed_interval_ms: int = 0
var _dual_mult: float = 1.0
# State: slot -> uid of the worn instance (only occupied slots), food item id (&"" = none).
var _worn: Dictionary[StringName, int] = {}
var _food: StringName = &""
# Id of the setup whose source `setup:<id>` is currently set (&"" = none).
var _applied_setup: StringName = &""


func _init(session: GameSession) -> void:
	assert(session != null, "Equipment needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_bank = session.bank
	_armory = session.armory
	_unarmed_style = StringName(str(_data.balance_value(UNARMED_STYLE_KEY)))
	_unarmed_interval_ms = int(_data.balance_value(UNARMED_INTERVAL_KEY))
	_dual_mult = float(_data.balance_value(DUAL_MULT_KEY))


## 0 if the slot is empty.
func get_uid(slot: StringName) -> int:
	return _worn.get(slot, 0)


## Base item id of the worn instance; &"" if the slot is empty.
func get_item(slot: StringName) -> StringName:
	var inst: ItemInstance = _armory.get_instance(get_uid(slot))
	return inst.base_id if inst != null else &""


## &"" if the piece is not worn.
func slot_of(uid: int) -> StringName:
	for slot: StringName in _worn:
		if _worn[slot] == uid:
			return slot
	return &""


## `slot` &"" = `equip.slot` of the base; a one-handed weapon can go to `offhand` if the class allows it.
func equip(uid: int, slot: StringName = &"") -> CommandResult:
	var inst: ItemInstance = _armory.get_instance(uid)
	if inst == null or not _data.has_item(inst.base_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	var def: ItemDef = _data.item(inst.base_id)
	if not def.is_equippable():
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	var target: StringName = slot if slot != &"" else def.equip.slot
	if slot_of(uid) != &"" or not _fits_slot(def, target):
		return CommandResult.fail(Reasons.NOT_EQUIPPABLE)
	if not _session.character.meets_requirements(def.equip.requirements) or not _class_allows(def, target):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	var after: Dictionary[StringName, int] = _worn.duplicate()
	var leaving: Array[StringName] = []
	if after.has(target):
		leaving.append(target)
	if target == WEAPON and _is_two_handed(def) and after.has(OFFHAND):
		leaving.append(OFFHAND)
	if target == OFFHAND and _is_two_handed(_def_of(get_uid(WEAPON))):
		leaving.append(WEAPON)
	var old_uids: Dictionary[StringName, int] = {}
	for old_slot: StringName in leaving:
		old_uids[old_slot] = _worn[old_slot]
		after.erase(old_slot)
	after[target] = uid
	if not _setup_is_valid(after):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	if _touches_hands(target, leaving) and _in_encounter():
		return CommandResult.fail(Reasons.COMBAT_ACTIVE)
	if leaving.size() > 1 and not _armory.can_add(leaving.size() - 1):
		return CommandResult.fail(Reasons.ARMORY_FULL)
	_commit(after, old_uids, uid)
	return CommandResult.success()


## Taking the weapon off with a sword in the offhand takes that one off too.
func unequip(slot: StringName) -> CommandResult:
	if get_uid(slot) == 0:
		return CommandResult.fail(Reasons.SLOT_EMPTY)
	var after: Dictionary[StringName, int] = _worn.duplicate()
	var leaving: Array[StringName] = [slot]
	if slot == WEAPON and after.has(OFFHAND) and not _is_shield(_def_of(after[OFFHAND])):
		leaving.append(OFFHAND)
	if _touches_hands(slot, leaving) and _in_encounter():
		return CommandResult.fail(Reasons.COMBAT_ACTIVE)
	if not _armory.can_add(leaving.size()):
		return CommandResult.fail(Reasons.ARMORY_FULL)
	var old_uids: Dictionary[StringName, int] = {}
	for old_slot: StringName in leaving:
		old_uids[old_slot] = _worn[old_slot]
		after.erase(old_slot)
	_commit(after, old_uids, 0)
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
	_events.food_changed.emit(item_id)
	return CommandResult.success()


## F-72: id of the derived setup, UNARMED without a weapon.
func setup() -> StringName:
	var def: SetupDef = setup_def()
	return def.id if def != null else UNARMED


## Null with UNARMED.
func setup_def() -> SetupDef:
	return _setup_of(_worn)


## The base of the worn weapon; null = bare hands.
func weapon() -> ItemDef:
	return _def_of(get_uid(WEAPON))


## The base of the sword in the offhand; null if shield or empty.
func offhand_weapon() -> ItemDef:
	var worn: ItemDef = _def_of(get_uid(OFFHAND))
	return worn if worn != null and worn.equip.weapon != null else null


func style() -> StringName:
	var worn: ItemDef = weapon()
	if worn != null and worn.equip.weapon != null:
		return worn.equip.weapon.style
	return _unarmed_style


## The weapon's interval; F-73 with an `alternate` setup; `combat.unarmed` without a weapon.
func base_attack_interval_ms() -> int:
	var worn: ItemDef = weapon()
	if worn == null or worn.equip.weapon == null:
		return _unarmed_interval_ms
	var second: ItemDef = offhand_weapon()
	var current: SetupDef = setup_def()
	if second != null and current != null and current.alternate:
		var sum_ms: int = worn.equip.weapon.attack_interval_ms + second.equip.weapon.attack_interval_ms
		return roundi(sum_ms / 2.0 * _dual_mult)
	return worn.equip.weapon.attack_interval_ms


## Sources `equipment:<slot>` of the worn pieces and `setup:<id>` (the session has cleared every source first).
func rebuild_modifiers() -> void:
	_applied_setup = &""
	_apply_sources()


## docs/01_GDD.md §1.1: nothing worn, no food.
func new_game() -> void:
	_reset()


func to_save() -> Dictionary:
	var slots: Dictionary = {}
	for slot: StringName in SLOTS:
		if _worn.has(slot):
			slots[String(slot)] = _worn[slot]
	return {SAVE_SLOTS_KEY: slots, SAVE_FOOD_KEY: String(_food)}


## Invalid entries (unknown slot or uid, uid worn twice, base that does not fit, combination without a setup) are
## reported and leave the slot empty; the piece stays in the Armory, not worn.
func from_save(d: Dictionary) -> void:
	_reset()
	var slots: Variant = d.get(SAVE_SLOTS_KEY, {})
	if slots is Dictionary:
		for slot: StringName in SLOTS:
			if (slots as Dictionary).has(String(slot)):
				_load_slot(slot, (slots as Dictionary)[String(slot)])
		for key: Variant in (slots as Dictionary):
			if not SLOTS.has(StringName(str(key))):
				Log.warn(LOG_CATEGORY, "unknown slot '%s' in save: ignored" % str(key))
	else:
		Log.warn(LOG_CATEGORY, "invalid slots in save: loaded as empty")
	_drop_invalid_hands()
	for slot: StringName in _worn:
		_armory.set_worn(_worn[slot], true, true)
	var food: Variant = d.get(SAVE_FOOD_KEY, "")
	if food is String and (food == "" or _is_food(StringName(food))):
		_food = StringName(food)
	else:
		Log.warn(LOG_CATEGORY, "invalid food %s in save: loaded as none" % str(food))


func _reset() -> void:
	for slot: StringName in _worn:
		_armory.set_worn(_worn[slot], false, true)
	_worn.clear()
	_food = &""
	_applied_setup = &""


func _is_food(item_id: StringName) -> bool:
	return _data.has_item(item_id) and _data.item(item_id).is_food()


func _load_slot(slot: StringName, value: Variant) -> void:
	var uid: int = 0
	if value is int or (value is float and is_equal_approx(float(value), roundf(float(value)))):
		uid = int(value)
	var inst: ItemInstance = _armory.get_instance(uid)
	if inst == null:
		Log.warn(LOG_CATEGORY, "slot '%s': uid %s is not in the Armory: left empty" % [slot, str(value)])
		return
	if slot_of(uid) != &"":
		Log.warn(LOG_CATEGORY, "uid %d is already worn in '%s': slot '%s' left empty" % [uid, slot_of(uid), slot])
		return
	var def: ItemDef = _data.item(inst.base_id) if _data.has_item(inst.base_id) else null
	if def == null or not def.is_equippable() or not _fits_slot(def, slot):
		Log.warn(LOG_CATEGORY, "uid %d does not fit slot '%s': left empty" % [uid, slot])
		return
	_worn[slot] = uid


# After loading: a weapon the class does not allow is dropped; a two-handed weapon loses the offhand (M3-11); an
# offhand without a setup with the weapon is dropped.
func _drop_invalid_hands() -> void:
	var worn_weapon: ItemDef = weapon()
	if worn_weapon != null and not _class_allows(worn_weapon, WEAPON):
		Log.warn(LOG_CATEGORY, "weapon '%s' is not allowed by the class: left empty" % worn_weapon.id)
		_worn.erase(WEAPON)
	if _is_two_handed(weapon()) and _worn.has(OFFHAND):
		Log.warn(LOG_CATEGORY, "two-handed weapon with an offhand in save: offhand left empty")
		_worn.erase(OFFHAND)
	if _worn.has(OFFHAND) and not (_class_allows(_def_of(_worn[OFFHAND]), OFFHAND) and _setup_is_valid(_worn)):
		Log.warn(LOG_CATEGORY, "offhand '%s' has no setup with the weapon: left empty" % get_item(OFFHAND))
		_worn.erase(OFFHAND)


func _def_of(uid: int) -> ItemDef:
	var inst: ItemInstance = _armory.get_instance(uid)
	return _data.item(inst.base_id) if inst != null and _data.has_item(inst.base_id) else null


func _is_two_handed(def: ItemDef) -> bool:
	return def != null and def.equip != null and def.equip.weapon != null and def.equip.weapon.two_handed


func _is_shield(def: ItemDef) -> bool:
	return def != null and def.equip != null and def.equip.kind == SHIELD_KIND


# The slot of the base, or the offhand for a one-handed weapon.
func _fits_slot(def: ItemDef, slot: StringName) -> bool:
	if not SLOTS.has(slot):
		return false
	if slot == def.equip.slot:
		return true
	return slot == OFFHAND and def.equip.slot == WEAPON and def.equip.weapon != null \
			and not def.equip.weapon.two_handed


# Weapon and offhand kinds must be allowed by the class (F-72); other slots have no kind.
func _class_allows(def: ItemDef, slot: StringName) -> bool:
	var cls: ClassDef = _session.character.class_def()
	if cls == null:
		return false
	if slot == WEAPON:
		return cls.weapon_kinds.has(def.equip.kind)
	if slot == OFFHAND:
		return cls.offhand_kinds.has(def.equip.kind)
	return true


# F-72 for a slot map; null without a weapon or without a matching setup.
func _setup_of(slots: Dictionary[StringName, int]) -> SetupDef:
	var cls: ClassDef = _session.character.class_def()
	var main: ItemDef = _def_of(slots.get(WEAPON, 0))
	if cls == null or main == null:
		return null
	var second: ItemDef = _def_of(slots.get(OFFHAND, 0))
	return cls.setup_for(main.equip.kind, second.equip.kind if second != null else &"")


# A weapon needs a setup; without a weapon the offhand can only be empty or a shield.
func _setup_is_valid(slots: Dictionary[StringName, int]) -> bool:
	if _def_of(slots.get(WEAPON, 0)) == null:
		return not slots.has(OFFHAND) or _is_shield(_def_of(slots[OFFHAND]))
	return _setup_of(slots) != null


func _touches_hands(target: StringName, leaving: Array[StringName]) -> bool:
	return target == WEAPON or target == OFFHAND or leaving.has(WEAPON) or leaving.has(OFFHAND)


func _in_encounter() -> bool:
	var combat: Variant = _session.get(&"combat")
	return combat != null and bool((combat as Object).call(&"in_encounter"))


# Applies a validated change: flags, slots, one rebuild, then the signals (emptied slots first).
func _commit(after: Dictionary[StringName, int], old_uids: Dictionary[StringName, int], new_uid: int) -> void:
	_modifiers.begin_batch()
	for old_slot: StringName in old_uids:
		_armory.set_worn(old_uids[old_slot], false)
	if new_uid != 0:
		_armory.set_worn(new_uid, true)
	_worn = after
	_apply_sources()
	_modifiers.end_batch()
	for old_slot: StringName in old_uids:
		if get_uid(old_slot) == 0:
			_events.equipment_changed.emit(old_slot, 0)
	if new_uid != 0:
		_events.equipment_changed.emit(slot_of(new_uid), new_uid)


# Sets or clears every `equipment:<slot>` source and moves `setup:<id>` to the current setup.
func _apply_sources() -> void:
	for slot: StringName in SLOTS:
		var source: StringName = StringName(SOURCE_PREFIX + String(slot))
		if _worn.has(slot):
			_modifiers.set_source(source, _armory.instance_modifiers(_worn[slot]))
		else:
			_modifiers.clear_source(source)
	if _applied_setup != &"":
		_modifiers.clear_source(StringName(SETUP_PREFIX + String(_applied_setup)))
		_applied_setup = &""
	var current: SetupDef = setup_def()
	if current != null:
		_applied_setup = current.id
		_modifiers.set_source(StringName(SETUP_PREFIX + String(current.id)), current.modifiers)
