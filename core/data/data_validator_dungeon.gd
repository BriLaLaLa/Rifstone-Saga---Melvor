class_name DataValidatorDungeon
extends RefCounted
## Part of DataValidator (internal, not API for other modules): the rules of the dungeons of M22
## (docs/04_DATA_SCHEMA.md §27, F-137...F-143): `data/dungeons/<id>.json` and the `dungeon` and `miniboss` sections of
## balance.json. Tickets and their placement: DataValidatorDungeonTickets; the area `miniboss`: DataValidatorMiniboss.

## Transitional (M22-02): with `false` the real data may have no `data/dungeons/` and no area `miniboss` (the rules apply
## to every file that exists); M22-03 brings the data and sets it to `true`. The fixtures (areas in the old format, without
## `level_min`) never need a dungeon or a miniboss unless they have one: what they have is always checked in full.
const STRICT_REAL_DATA: bool = true
const FIELDS: PackedStringArray = ["id", "name", "description", "icon", "order", "requirements", "recommended_level",
	"ticket", "map", "monsters", "rooms", "stages", "boss", "loot_table"]
const ICON_DIR: String = "res://assets/icons/"
const MAP_FIELDS: PackedStringArray = ["forks", "width_weights", "exit_weights", "hint_pct"]
const FORKS_MAX: int = 8
const ROOM_TYPES: PackedStringArray = ["pack", "horde", "elite", "miniboss", "trap", "rest"]
const COMBAT_TYPES: PackedStringArray = ["pack", "horde", "elite", "miniboss"]
const TYPE_FIELDS: PackedStringArray = ["id", "weight", "min_layer", "hint", "reward"]
const COMPOSITION_FIELDS: PackedStringArray = ["size", "pool", "fixed"]
const SIZE_MAX: int = 30  # the entrance and the combat rooms
const SIDE_SIZE_MAX: int = 8  # the ambush and the forage
const REWARD_KEYS: PackedStringArray = ["gold", "dust", "crystal_pct", "piece_pct"]
const STAGE_COUNT: int = 3
const STAGE_FIELDS: PackedStringArray = ["id", "monster", "escorts", "intro_ms", "title", "quote", "ability", "reward"]
const ESCORTS_MAX: int = 4
const INTRO_MS_MIN: int = 1000
const INTRO_MS_MAX: int = 10000
const BOSS_FIELDS: PackedStringArray = ["gold", "dust", "pieces", "crystals", "card_pct", "card_grade", "drops"]
const PIECES_MAX: int = 3
const CRYSTALS_MAX: int = 5
const CARD_GRADE_MAX: int = 10
const RARITIES: PackedStringArray = ["common", "magic", "rare"]
const FORBIDDEN_TABLE_CATEGORIES: PackedStringArray = ["map", "contract"]  # no Cards and no Contracts in a dungeon table
const MINIBOSS_KEYS: PackedStringArray = ["chance_pct", "hp_mult", "power_mult", "xp_mult", "gold_mult"]
const BANDS_COUNT: int = 6
const BAND_WIDTH_MAX: float = 0.25  # F-137: rooms of a level are at least this far apart, so no band may hold two exits
const EPSILON: float = 1e-9


# --- balance.json ------------------------------------------------------------------------------------------------

## True for the sections `dungeon` and `miniboss` and their keys (so that DataValidator does not report them as unknown).
static func is_known_key(path: String) -> bool:
	return path == "dungeon" or path == "dungeon.direction_bands" or path == "miniboss" \
			or (path.begins_with("miniboss.") and MINIBOSS_KEYS.has(path.get_slice(".", 1)))


static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var dungeon: Variant = DataValidator.lookup(balance, "dungeon")
	if not dungeon is Dictionary:
		v.fail("missing key 'dungeon'")
	else:
		v.keys(dungeon as Dictionary, ["direction_bands"], "dungeon")
		_bands(v, dungeon as Dictionary)
	var miniboss: Variant = DataValidator.lookup(balance, "miniboss")
	if not miniboss is Dictionary:
		v.fail("missing key 'miniboss'")
		return
	var m: Dictionary = miniboss as Dictionary
	v.keys(m, MINIBOSS_KEYS, "miniboss")
	v.number(m, "chance_pct", 0.0, 100.0, "miniboss")
	for key: String in ["hp_mult", "power_mult", "xp_mult", "gold_mult"]:
		v.number(m, key, 1.0, DataValidatorRules.NO_LIMIT, "miniboss")


# Six strictly increasing numbers in -1..1 whose inner bands are not wider than BAND_WIDTH_MAX (F-137).
static func _bands(v: DataValidatorRules, dungeon: Dictionary) -> void:
	var bands: Variant = dungeon.get("direction_bands")
	if not bands is Array or (bands as Array).size() != BANDS_COUNT:
		v.fail("key 'dungeon.direction_bands' must be an array of %d numbers" % BANDS_COUNT)
		return
	for value: Variant in (bands as Array):
		if not DataValidatorRules.is_number(value) or absf(float(value)) > 1.0:
			v.fail("key 'dungeon.direction_bands' must hold numbers in -1..1, got %s" % JSON.stringify(bands))
			return
	for i: int in BANDS_COUNT - 1:
		var width: float = float((bands as Array)[i + 1]) - float((bands as Array)[i])
		if width <= 0.0:
			v.fail("key 'dungeon.direction_bands' must be strictly increasing, got %s" % JSON.stringify(bands))
			return
		if width > BAND_WIDTH_MAX + EPSILON:
			v.fail("key 'dungeon.direction_bands': the band %d is %s wide, at most %s (two exits of a room would share a direction)"
					% [i, width, BAND_WIDTH_MAX])


# --- the dungeon files ------------------------------------------------------------------------------------------

## Every `data/dungeons/*.json` (`raw` is the whole raw data of DataValidator) and what depends on them.
static func validate(v: DataValidatorRules, raw: Dictionary) -> void:
	var files: Dictionary = section(raw, "dungeons")
	var areas: Dictionary = section(raw, "areas")
	var narrow: bool = false
	for path: Variant in areas:
		for a: Variant in ((areas[path] as Dictionary).get("areas", []) as Array):
			narrow = narrow or (a is Dictionary and (a as Dictionary).has("level_min"))
	var strict: bool = STRICT_REAL_DATA and narrow
	DataValidatorMiniboss.validate(v, areas, section(raw, "monsters"), strict)
	var tables: Dictionary[StringName, Dictionary] = loot_tables(raw)
	var seen: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	for path: Variant in files:
		var d: Dictionary = files[path] as Dictionary
		_dungeon(v, str(path), d, seen, orders, tables)
	if strict and files.is_empty():
		v.at_file("section 'dungeons'")
		v.fail("no dungeon: data/dungeons/ must hold at least one")
	DataValidatorDungeonTickets.validate(v, raw)


static func _dungeon(v: DataValidatorRules, path: String, d: Dictionary, seen: Dictionary[StringName, bool],
		orders: Dictionary[int, bool], tables: Dictionary[StringName, Dictionary]) -> void:
	v.at_file(path)
	v.entry("dungeon", 0, d, seen, FIELDS, orders)
	if d.get("id") is String and d["id"] != path.get_file().get_basename():
		v.fail("id '%s' must be equal to the file name" % d["id"])
	DataValidator.icon(v, d, ICON_DIR)
	v.level_map(d, "requirements", "", DataValidatorRules.LEVELS_CHARACTER)
	var requirements: Variant = d.get("requirements")
	if requirements is Dictionary and not (requirements as Dictionary).has(DataValidatorRules.CHARACTER_KEY):
		v.fail("field 'requirements.character' is required")
	if v.integer(d, "recommended_level", 1, 99.0) and requirements is Dictionary \
			and DataValidatorRules.is_number((requirements as Dictionary).get(DataValidatorRules.CHARACTER_KEY)) \
			and int(d["recommended_level"]) < int((requirements as Dictionary)[DataValidatorRules.CHARACTER_KEY]):
		v.fail("field 'recommended_level' is below requirements.character")
	if v.ref(d, "ticket", v.items, "item") and str(v.items[StringName(d["ticket"] as String)].get("dungeon")) != str(d.get("id")):
		v.fail("field 'ticket': item '%s' has no `dungeon` equal to the id" % d["ticket"])
	var forks: int = _map(v, d)
	var local: Dictionary[StringName, bool] = _monsters(v, d)
	v.at_entry("dungeon", 0, d)
	_rooms(v, d, local, forks)
	v.at_entry("dungeon", 0, d)
	_stages(v, d, local)
	v.at_entry("dungeon", 0, d)
	_boss(v, d)
	_loot_table(v, d, tables)


static func _map(v: DataValidatorRules, d: Dictionary) -> int:
	var map: Dictionary = v.object(d, "map")
	if not d.get("map") is Dictionary:
		return 0
	v.keys(map, MAP_FIELDS, "map")
	var forks: int = int(map["forks"]) if v.integer(map, "forks", 1, FORKS_MAX, "map") else 0
	for key: String in ["width_weights", "exit_weights"]:
		var weights: Variant = map.get(key)
		var total: float = 0.0
		var valid: bool = weights is Array and (weights as Array).size() == 3
		for w: Variant in (weights as Array if weights is Array else []):
			valid = valid and DataValidatorRules.is_int(w) and float(w) >= 0.0
			total += float(w) if DataValidatorRules.is_number(w) else 0.0
		if not valid or total < 1.0:
			v.fail("field 'map.%s' needs 3 integer weights >= 0 with a sum >= 1, got %s" % [key, JSON.stringify(weights)])
	v.number(map, "hint_pct", 0.0, 100.0, "map")
	return forks


# The monsters of the dungeon: the monster rules of the areas, a `level`, ids unused by every other monster of the game.
# They join `v.monsters` afterwards (loot tables and boss abilities refer to them). Returns their ids.
static func _monsters(v: DataValidatorRules, d: Dictionary) -> Dictionary[StringName, bool]:
	var local: Dictionary[StringName, bool] = {}
	var allowed: PackedStringArray = ["level"]
	for field: String in DataValidatorClasses.MONSTER_FIELDS:
		if field != "miniboss":
			allowed.append(field)
	var list: Array[Dictionary] = v.object_list(d, "monsters", "", 1)
	for index: int in list.size():
		var e: Dictionary = list[index]
		var id: StringName = v.entry("dungeon monster", index, e, local, allowed)
		if id != &"" and v.monsters.has(id):
			v.fail("monster id '%s' is already used by another monster" % id)
		DataValidatorClasses.combat_fields(v, e)
		v.integer(e, "level", 1, 99.0)
	for e: Dictionary in list:
		if e.get("id") is String:
			v.monsters[StringName(e["id"] as String)] = e
	return local


static func _rooms(v: DataValidatorRules, d: Dictionary, local: Dictionary[StringName, bool], forks: int) -> void:
	var rooms: Dictionary = v.object(d, "rooms")
	if not d.get("rooms") is Dictionary:
		return
	v.keys(rooms, ["entrance", "types", "trap", "rest"], "rooms")
	var entrance: Dictionary = v.object(rooms, "entrance", "rooms")
	v.keys(entrance, ["size", "pool", "reward"], "rooms.entrance")
	_composition(v, entrance, "rooms.entrance", local, false)
	_reward(v, entrance, "rooms.entrance")
	var types: Array[Dictionary] = v.object_list(rooms, "types", "rooms", 1)
	var seen: Dictionary[StringName, bool] = {}
	for index: int in types.size():
		_type(v, types[index], "rooms.types[%d]" % index, local, forks, seen)
	if types.size() > 0 and not seen.has(&"pack"):
		v.fail("field 'rooms.types': the type 'pack' is required")
	var trap: Dictionary = v.object(rooms, "trap", "rooms")
	v.keys(trap, ["kinds", "dash_hp_pct", "ambush", "reward"], "rooms.trap")
	v.id_list(trap, "kinds", null, "trap kind", 1, "rooms.trap")
	v.number(trap, "dash_hp_pct", 1.0, 50.0, "rooms.trap")
	_side(v, v.object(trap, "ambush", "rooms.trap"), "rooms.trap.ambush", local, [])
	_reward(v, trap, "rooms.trap")
	var rest: Dictionary = v.object(rooms, "rest", "rooms")
	v.keys(rest, ["heal_pct", "forage"], "rooms.rest")
	v.number(rest, "heal_pct", 1.0, 100.0, "rooms.rest")
	_side(v, v.object(rest, "forage", "rooms.rest"), "rooms.rest.forage", local, ["dust", "crystal_pct"])
	var forage: Dictionary = rest.get("forage", {}) as Dictionary
	if not forage.has("dust"):
		v.fail("field 'rooms.rest.forage.dust' is required")
	if not forage.has("crystal_pct"):
		v.fail("field 'rooms.rest.forage.crystal_pct' is required")


# One entry of `rooms.types`.
static func _type(v: DataValidatorRules, t: Dictionary, prefix: String, local: Dictionary[StringName, bool], forks: int,
		seen: Dictionary[StringName, bool]) -> void:
	var is_combat: bool = COMBAT_TYPES.has(str(t.get("id")))
	var allowed: PackedStringArray = TYPE_FIELDS.duplicate()
	if is_combat:
		allowed.append_array(COMPOSITION_FIELDS)
	v.keys(t, allowed, prefix)
	if v.one_of(t, "id", ROOM_TYPES, prefix):
		var id := StringName(t["id"] as String)
		if seen.has(id):
			v.fail("field '%s.id': the type '%s' appears twice" % [prefix, id])
		seen[id] = true
	v.integer(t, "weight", 1, DataValidatorRules.NO_LIMIT, prefix)
	var top: float = float(forks) if forks > 0 else DataValidatorRules.NO_LIMIT
	if v.integer(t, "min_layer", 1, top, prefix) and t.get("id") == "pack" and int(t["min_layer"]) != 1:
		v.fail("field '%s.min_layer': the type 'pack' must start at layer 1" % prefix)
	if v.text(t, "hint", prefix) and (t["hint"] as String).is_empty():
		v.fail("field '%s.hint' must not be empty" % prefix)
	if is_combat:
		_composition(v, t, prefix, local, true)
	_reward(v, t, prefix)


# `size` (an integer or [min, max]) with `pool`, or (with `allow_fixed`) `fixed`.
static func _composition(v: DataValidatorRules, d: Dictionary, prefix: String, local: Dictionary[StringName, bool],
		allow_fixed: bool) -> void:
	if allow_fixed and d.has("fixed"):
		if d.has("size") or d.has("pool"):
			v.fail("field '%s': 'fixed' excludes 'size' and 'pool'" % prefix)
		v.id_list(d, "fixed", local, "monster", 1, prefix)
		return
	if not d.has("size"):
		v.fail("field '%s' needs 'size' with 'pool'%s" % [prefix, ", or 'fixed'" if allow_fixed else ""])
	elif d["size"] is Array:
		v.int_pair(d, "size", 1, SIZE_MAX, true, prefix)
	else:
		v.integer(d, "size", 1, SIZE_MAX, prefix)
	_pool(v, d, prefix, local)


static func _pool(v: DataValidatorRules, d: Dictionary, prefix: String, local: Dictionary[StringName, bool]) -> void:
	var pool: Array[Dictionary] = v.object_list(d, "pool", prefix, 1)
	for index: int in pool.size():
		var at: String = "%s.pool[%d]" % [prefix, index]
		v.keys(pool[index], ["monster", "weight"], at)
		v.ref(pool[index], "monster", local, "monster", at)
		v.integer(pool[index], "weight", 1, DataValidatorRules.NO_LIMIT, at)


# The trap ambush and the rest forage: a size 1..SIDE_SIZE_MAX with a pool, plus the reward keys of `extra`.
static func _side(v: DataValidatorRules, d: Dictionary, prefix: String, local: Dictionary[StringName, bool],
		extra: PackedStringArray) -> void:
	var allowed: PackedStringArray = ["size", "pool"]
	allowed.append_array(extra)
	v.keys(d, allowed, prefix)
	v.integer(d, "size", 1, SIDE_SIZE_MAX, prefix)
	_pool(v, d, prefix, local)
	if extra.has("dust"):
		v.int_pair(d, "dust", 1, DataValidatorRules.NO_LIMIT, true, prefix)
		v.number(d, "crystal_pct", 0.0, 100.0, prefix)


# The optional `reward` of `d` (F-142): all keys optional.
static func _reward(v: DataValidatorRules, d: Dictionary, prefix: String) -> void:
	if not d.has("reward"):
		return
	var reward: Dictionary = v.object(d, "reward", prefix)
	var at: String = prefix + ".reward"
	v.keys(reward, REWARD_KEYS, at)
	for key: String in ["gold", "dust"]:
		if reward.has(key):
			v.int_pair(reward, key, 1, DataValidatorRules.NO_LIMIT, true, at)
	for key: String in ["crystal_pct", "piece_pct"]:
		if reward.has(key):
			v.number(reward, key, 0.0, 100.0, at)


static func _stages(v: DataValidatorRules, d: Dictionary, local: Dictionary[StringName, bool]) -> void:
	var stages: Array[Dictionary] = v.object_list(d, "stages")
	if d.get("stages") is Array and stages.size() != STAGE_COUNT:
		v.fail("field 'stages' needs exactly %d stages, got %d" % [STAGE_COUNT, stages.size()])
	var seen: Dictionary[StringName, bool] = {}
	for index: int in stages.size():
		var e: Dictionary = stages[index]
		var prefix: String = "stages[%d]" % index
		var last: bool = index == stages.size() - 1
		v.entry("stage", index, e, seen, STAGE_FIELDS)
		v.ref(e, "monster", local, "monster", prefix)
		var escorts: Array = v.id_list(e, "escorts", local, "monster", 0, prefix)
		if escorts.size() > ESCORTS_MAX or (last and not escorts.is_empty()):
			v.fail("field '%s.escorts': %s" % [prefix, "the last stage has none" if last else "at most %d" % ESCORTS_MAX])
		v.integer(e, "intro_ms", INTRO_MS_MIN, INTRO_MS_MAX, prefix)
		v.text(e, "title", prefix)
		v.text(e, "quote", prefix)
		DataValidatorMaps._ability(v, e)
		var ability: Variant = e.get("ability")
		if ability is Dictionary and (ability as Dictionary).get("monsters") is Array:
			for id: Variant in ((ability as Dictionary)["monsters"] as Array):
				if id is String and not local.has(StringName(id as String)):
					v.fail("field '%s.ability.monsters': '%s' is not a monster of the dungeon" % [prefix, id])
		if last and e.has("reward"):
			v.fail("field '%s.reward': the last stage has none (its reward is `boss`)" % prefix)
		elif not last and not e.has("reward"):
			v.fail("field '%s.reward' is required" % prefix)
		_reward(v, e, prefix)


static func _boss(v: DataValidatorRules, d: Dictionary) -> void:
	var boss: Dictionary = v.object(d, "boss")
	if not d.get("boss") is Dictionary:
		return
	v.keys(boss, BOSS_FIELDS, "boss")
	for key: String in ["gold", "dust"]:
		v.int_pair(boss, key, 1, DataValidatorRules.NO_LIMIT, true, "boss")
	var pieces: Array[Dictionary] = v.object_list(boss, "pieces", "boss", 1)
	if pieces.size() > PIECES_MAX:
		v.fail("field 'boss.pieces' has %d entries, at most %d" % [pieces.size(), PIECES_MAX])
	for index: int in pieces.size():
		var at: String = "boss.pieces[%d]" % index
		var piece: Dictionary = pieces[index]
		v.keys(piece, ["rarity", "min_rarity"], at)
		if piece.size() != 1:
			v.fail("field '%s' needs exactly one of 'rarity' and 'min_rarity'" % at)
		for key: String in ["rarity", "min_rarity"]:
			if piece.has(key):
				v.one_of(piece, key, RARITIES, at)
	v.integer(boss, "crystals", 0, CRYSTALS_MAX, "boss")
	v.number(boss, "card_pct", 0.0, 100.0, "boss")
	v.integer(boss, "card_grade", 1, CARD_GRADE_MAX, "boss")
	DataValidatorClasses.drops(v, boss)


# `loot_table`: an existing table without Cards and Contracts.
static func _loot_table(v: DataValidatorRules, d: Dictionary, tables: Dictionary[StringName, Dictionary]) -> void:
	if not v.ref(d, "loot_table", tables, "loot table"):
		return
	for entry: Variant in (tables[StringName(d["loot_table"] as String)].get("entries", []) as Array):
		if not entry is Dictionary:
			continue
		var item: StringName = StringName(str((entry as Dictionary).get("item")))
		if v.items.has(item) and FORBIDDEN_TABLE_CATEGORIES.has(str(v.items[item].get("category"))):
			v.fail("field 'loot_table': '%s' holds '%s' (%s), a dungeon table has no Cards and no Contracts"
					% [d["loot_table"], item, v.items[item].get("category")])


static func loot_tables(raw: Dictionary) -> Dictionary[StringName, Dictionary]:
	var tables: Dictionary[StringName, Dictionary] = {}
	var files: Dictionary = section(raw, "loot_tables")
	for path: Variant in files:
		for t: Variant in ((files[path] as Dictionary).get("tables", []) as Array):
			if t is Dictionary and (t as Dictionary).get("id") is String:
				tables[StringName((t as Dictionary)["id"] as String)] = t as Dictionary
	return tables


## `{path: top-level object}` of a section of the raw data (non-object files are left out; the loader reports them).
static func section(raw: Dictionary, key: String) -> Dictionary:
	var result: Dictionary = {}
	var files: Variant = raw.get(key)
	for path: Variant in (files as Dictionary if files is Dictionary else {}):
		if (files as Dictionary)[path] is Dictionary:
			result[path] = (files as Dictionary)[path]
	return result


## The monsters of the dungeon files as one fake `monsters` file per dungeon, for the checks that read every monster
## (the loot tables of DataValidatorLootTables).
static func monster_files(raw: Dictionary) -> Dictionary[String, Dictionary]:
	var result: Dictionary[String, Dictionary] = {}
	var files: Dictionary = section(raw, "dungeons")
	for path: Variant in files:
		result[str(path)] = {"monsters": (files[path] as Dictionary).get("monsters", [])}
	return result
