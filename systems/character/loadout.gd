class_name Loadout
extends RefCounted
## The traits and abilities the player equipped in the slots of the class (docs/01_GDD.md §19, F-78).
##
## State: one id (or &"") per slot, for traits and for abilities. A slot is open when the character level reaches the
## matching level of `traits.slot_levels` / `abilities.slot_levels`. A piece chosen for a setup that is not worn stays
## in its slot but is not active (`active_traits`, `active_abilities`). Trait modifiers are the sources `trait:<id>`;
## they follow the setup, so they are rebuilt on every change of weapon or offhand.
## Dependencies: data, events, modifiers, character, equipment, combat (only `in_encounter`).

const SAVE_KEY: StringName = &"loadout"
const LOG_CATEGORY: String = "loadout"
const TRAIT_LEVELS_KEY: String = "traits.slot_levels"
const ABILITY_LEVELS_KEY: String = "abilities.slot_levels"
const TRAIT_SOURCE_PREFIX: String = "trait:"
const SAVE_TRAITS_KEY: String = "traits"
const SAVE_ABILITIES_KEY: String = "abilities"

var _session: GameSession
var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _trait_levels: Array[int] = []
var _ability_levels: Array[int] = []
var _traits: Array[StringName] = []
var _abilities: Array[StringName] = []
# Trait ids whose source `trait:<id>` is currently set.
var _applied: Array[StringName] = []


func _init(session: GameSession) -> void:
	assert(session != null, "Loadout needs a session")
	_session = session
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_trait_levels = _levels(TRAIT_LEVELS_KEY)
	_ability_levels = _levels(ABILITY_LEVELS_KEY)
	_reset()
	_events.equipment_changed.connect(_on_equipment_changed)


## No trait, no ability. No signals.
func new_game() -> void:
	_reset()


## {"traits": [id | ""], "abilities": [id | ""]}, one entry per slot of the balance table (docs/05_INTERFACES.md §6).
func to_save() -> Dictionary:
	return {SAVE_TRAITS_KEY: _strings(_traits), SAVE_ABILITIES_KEY: _strings(_abilities)}


## Tolerant: unknown ids, ids not of the class, not unlocked, duplicated or in a slot not open become empty slots,
## with a warning. No signals.
func from_save(d: Dictionary) -> void:
	_reset()
	_load_list(d.get(SAVE_TRAITS_KEY), true)
	_load_list(d.get(SAVE_ABILITIES_KEY), false)


## F-78.
func trait_slots() -> int:
	return _open_slots(_trait_levels)


## F-78.
func ability_slots() -> int:
	return _open_slots(_ability_levels)


## &"" = empty (or an index outside the table).
func get_trait(slot_index: int) -> StringName:
	return _traits[slot_index] if slot_index >= 0 and slot_index < _traits.size() else &""


func get_ability(slot_index: int) -> StringName:
	return _abilities[slot_index] if slot_index >= 0 and slot_index < _abilities.size() else &""


## `trait_id` &"" empties the slot. Fails with `slot_locked`, `unknown_id`, `level_too_low`, `requirement_not_met`
## (the trait is already in another slot) or `combat_active`. Success: `traits_changed` (none if nothing changed).
func set_trait(slot_index: int, trait_id: StringName) -> CommandResult:
	return _set_slot(slot_index, trait_id, true)


## Same rules as `set_trait`, for abilities.
func set_ability(slot_index: int, ability_id: StringName) -> CommandResult:
	return _set_slot(slot_index, ability_id, false)


## The equipped traits the current setup allows, in slot order.
func active_traits() -> Array[TraitDef]:
	var result: Array[TraitDef] = []
	var setup_id: StringName = _session.equipment.setup()
	for slot_index: int in mini(trait_slots(), _traits.size()):
		var def: TraitDef = _trait_def(_traits[slot_index])
		if def != null and def.allows_setup(setup_id):
			result.append(def)
	return result


## The equipped abilities the current setup allows, in slot order.
func active_abilities() -> Array[AbilityDef]:
	var result: Array[AbilityDef] = []
	var setup_id: StringName = _session.equipment.setup()
	for slot_index: int in mini(ability_slots(), _abilities.size()):
		var def: AbilityDef = _ability_def(_abilities[slot_index])
		if def != null and def.allows_setup(setup_id):
			result.append(def)
	return result


## Sources `trait:<id>` of the active traits (the session has cleared every source first when it calls this).
func rebuild_modifiers() -> void:
	_modifiers.begin_batch()
	for old_id: StringName in _applied:
		_modifiers.clear_source(StringName(TRAIT_SOURCE_PREFIX + String(old_id)))
	_applied.clear()
	for def: TraitDef in active_traits():
		_modifiers.set_source(StringName(TRAIT_SOURCE_PREFIX + String(def.id)), def.modifiers)
		_applied.append(def.id)
	_modifiers.end_batch()


func _set_slot(slot_index: int, id: StringName, is_trait: bool) -> CommandResult:
	var slots: Array[StringName] = _traits if is_trait else _abilities
	var open: int = trait_slots() if is_trait else ability_slots()
	if slot_index < 0 or slot_index >= open:
		return CommandResult.fail(Reasons.SLOT_LOCKED)
	if id == &"":
		return _commit(slots, slot_index, id)
	var unlock_level: int = _unlock_level(id, is_trait)
	if unlock_level == 0:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _session.character.get_level() < unlock_level:
		return CommandResult.fail(Reasons.LEVEL_TOO_LOW)
	if slots[slot_index] == id:
		return CommandResult.success()
	if slots.has(id):
		return CommandResult.fail(Reasons.REQUIREMENT_NOT_MET)
	return _commit(slots, slot_index, id)


# Combat check, the change, the modifiers and the signal.
func _commit(slots: Array[StringName], slot_index: int, id: StringName) -> CommandResult:
	if _session.combat != null and (_session.combat.in_encounter() or _session.combat.in_fracture()):
		return CommandResult.fail(Reasons.COMBAT_ACTIVE)
	if slots[slot_index] == id:
		return CommandResult.success()
	slots[slot_index] = id
	rebuild_modifiers()
	_events.traits_changed.emit()
	return CommandResult.success()


func _on_equipment_changed(slot_id: StringName, _uid: int) -> void:
	if slot_id == Equipment.WEAPON or slot_id == Equipment.OFFHAND:
		rebuild_modifiers()


func _reset() -> void:
	_traits = _empty(_trait_levels.size())
	_abilities = _empty(_ability_levels.size())
	_applied.clear()


# Fills `_traits` or `_abilities` from a saved list, one slot at a time.
func _load_list(raw: Variant, is_trait: bool) -> void:
	var kind: String = "trait" if is_trait else "ability"
	var slots: Array[StringName] = _traits if is_trait else _abilities
	if not raw is Array:
		Log.warn(LOG_CATEGORY, "%ss missing or invalid in save: all empty" % kind)
		return
	var saved: Array = raw as Array
	var open: int = trait_slots() if is_trait else ability_slots()
	for slot_index: int in saved.size():
		var id: StringName = StringName(str(saved[slot_index])) if saved[slot_index] is String else &""
		if id == &"":
			continue
		var problem: String = ""
		if slot_index >= slots.size() or slot_index >= open:
			problem = "slot not open"
		elif _unlock_level(id, is_trait) == 0:
			problem = "unknown or not of the class"
		elif _session.character.get_level() < _unlock_level(id, is_trait):
			problem = "not unlocked"
		elif slots.has(id):
			problem = "duplicated"
		if problem.is_empty():
			slots[slot_index] = id
		else:
			Log.warn(LOG_CATEGORY, "%s '%s' in slot %d of the save: %s, slot left empty" % [kind, id, slot_index, problem])


# Level of the trait/ability in the character's class; 0 if the class has no such id.
func _unlock_level(id: StringName, is_trait: bool) -> int:
	if is_trait:
		var trait_def: TraitDef = _trait_def(id)
		return trait_def.unlock_level if trait_def != null else 0
	var ability: AbilityDef = _ability_def(id)
	return ability.unlock_level if ability != null else 0


func _trait_def(id: StringName) -> TraitDef:
	var class_def: ClassDef = _session.character.class_def()
	if class_def != null:
		for def: TraitDef in class_def.traits:
			if def.id == id:
				return def
	return null


func _ability_def(id: StringName) -> AbilityDef:
	var class_def: ClassDef = _session.character.class_def()
	if class_def != null:
		for def: AbilityDef in class_def.abilities:
			if def.id == id:
				return def
	return null


func _open_slots(levels: Array[int]) -> int:
	var level: int = _session.character.get_level()
	var count: int = 0
	for needed: int in levels:
		if needed <= level:
			count += 1
	return count


func _levels(key: String) -> Array[int]:
	var result: Array[int] = []
	var raw: Variant = _data.balance_value(key)
	if raw is Array:
		for value: Variant in raw as Array:
			result.append(int(value))
	return result


static func _empty(count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	result.resize(count)
	result.fill(&"")
	return result


static func _strings(ids: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for id: StringName in ids:
		result.append(String(id))
	return result
