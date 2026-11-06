class_name EffectKit
extends RefCounted
## Test helpers for the trait effects: puts a test trait into the fixture class (restored by `cleanup`), equips it, and
## builds the save of a controlled fight. The fixture data is shared by all tests, so every test using `add_trait` must
## call `EffectKit.cleanup()` in `after_each`.

static var _added: Array[Array] = []  # [ClassDef, TraitDef]


## A trait with `effects` ([{"type", "params"}]) available to the loadout of the session; returns its id.
static func add_trait(session: GameSession, id: StringName, effects: Array) -> StringName:
	var def: TraitDef = TraitDef.from_dict({"id": String(id), "name": "Prova", "description": "Prova.",
		"unlock_level": 1, "setups": [], "effects": effects, "modifiers": []})
	assert(def != null, "EffectKit: invalid test trait")
	var class_def: ClassDef = session.character.class_def()
	class_def.traits.append(def)
	_added.append([class_def, def])
	return id


## Adds the trait and equips it in `slot`; the character level must open the slot.
static func equip_trait(session: GameSession, id: StringName, effects: Array, slot: int = 0) -> void:
	add_trait(session, id, effects)
	var result: CommandResult = session.loadout.set_trait(slot, id)
	assert(result.ok, "EffectKit: set_trait failed: %s" % result.reason)


static func cleanup() -> void:
	for pair: Array in _added:
		(pair[0] as ClassDef).traits.erase(pair[1])
	_added.clear()


## Save of a fight in `test_area` with the given enemies ([{"monster", "hp", "timer_ms"}]); the default hp is the
## maximum of a `sturdy` player (60 + 100000).
static func fight(enemies: Array, player_timer_ms: int = 2400, player_hp: int = 100060) -> Dictionary:
	return {"state": "encounter", "area": "test_area", "player_hp": player_hp, "player_timer_ms": player_timer_ms,
		"hand": 0, "between_ms": 0, "enemies": enemies, "loot": [], "kills": {}, "deaths": 0, "food_eaten": 0}


static func enemy(monster: String, hp: int, timer_ms: int) -> Dictionary:
	return {"monster": monster, "hp": hp, "timer_ms": timer_ms}


## A player that does not die: +100000 max hp.
static func sturdy(session: GameSession) -> void:
	session.modifiers.set_source(&"test:sturdy", [Modifier.make(&"max_hp_flat", 100000.0)] as Array[Modifier])
