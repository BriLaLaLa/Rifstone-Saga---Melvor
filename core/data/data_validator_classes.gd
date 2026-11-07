class_name DataValidatorClasses
extends RefCounted
## Fourth part of DataValidator (internal, not API for other modules): the rules of areas and monsters
## (docs/04_DATA_SCHEMA.md §8), classes (§14) and affixes (§15), written with the toolkit of DataValidatorRules.

const AREA_FIELDS: PackedStringArray = ["id", "name", "description", "order", "requirements", "packs",
		"rift_stone_chance_pct"]
const MONSTER_FIELDS: PackedStringArray = ["id", "name", "description", "icon", "hp", "xp", "style",
	"attack_interval_ms", "attack_level", "power_level", "defence_level", "accuracy_bonus", "power_bonus",
	"evasion_bonus", "damage_reduction", "gold", "rift_shard_chance", "drops", "sprite"]
const MONSTER_ICON_DIR: String = "res://assets/icons/monsters/"
const CLASS_ICON_DIR: String = "res://assets/icons/classes/"
const SPRITE_STATES: PackedStringArray = ["idle", "attack", "hit", "death"]  # reserved, no use yet (M6-00a)
const SPRITE_DIR: String = "res://assets/"
const MAX_DROPS: int = 4
const DAMAGE_REDUCTION_STAT: StringName = &"damage_reduction"  # bounds monster damage_reduction (stats.json)
const CLASS_FIELDS: PackedStringArray = ["id", "name", "description", "icon", "order", "weapon_kinds", "offhand_kinds",
	"setups", "traits", "abilities"]
const SETUP_FIELDS: PackedStringArray = ["id", "name", "weapon", "offhand", "alternate", "modifiers"]
const WEAPON_KINDS: PackedStringArray = DataValidatorItems.WEAPON_KINDS
const UNARMED_SETUP: String = "unarmed"  # reserved setup id (F-72)
const AFFIX_FIELDS: PackedStringArray = ["id", "name", "stat", "slots", "weight", "tiers"]
const TIER_FIELDS: PackedStringArray = ["min_ilvl", "min", "max", "step"]
const ITEM_LEVEL_MAX: int = 99
const STEP_TOLERANCE: float = 1e-6


static func validate_areas(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "areas")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("area", index, e, seen, AREA_FIELDS, orders)
			v.level_map(e, "requirements", "", DataValidatorRules.LEVELS_CHARACTER)
			if e.has("rift_stone_chance_pct"):
				v.number(e, "rift_stone_chance_pct", 0.0, 100.0)
			var packs: Array[Dictionary] = v.object_list(e, "packs", "", 1)
			for pack_index: int in packs.size():
				_pack(v, packs[pack_index], "packs[%d]" % pack_index)


static func _pack(v: DataValidatorRules, pack: Dictionary, prefix: String) -> void:
	v.keys(pack, ["weight", "monsters"], prefix)
	v.integer(pack, "weight", 1, DataValidatorRules.NO_LIMIT, prefix)
	var ids: Array = v.id_list(pack, "monsters", v.monsters, "monster", 1, prefix)
	if float(ids.size()) > v.max_pack_size:
		v.fail("field '%s.monsters' has %d monsters, at most %d (combat.max_pack_size)"
				% [prefix, ids.size(), int(v.max_pack_size)])


static func validate_monsters(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var max_dr: float = float(v.stats.info(DAMAGE_REDUCTION_STAT)["max"]) if v.stats.has(DAMAGE_REDUCTION_STAT) \
			else DataValidatorRules.NO_LIMIT
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "monsters")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("monster", index, e, seen, MONSTER_FIELDS)
			existing_icon(v, e, MONSTER_ICON_DIR)
			_sprite(v, e)
			v.integer(e, "hp", 1)
			v.integer(e, "xp", 0)
			v.one_of(e, "style", DataValidatorRules.STYLES)
			v.integer(e, "attack_interval_ms", maxf(v.min_attack_interval_ms, 1))
			for key: String in ["attack_level", "power_level", "defence_level"]:
				v.integer(e, key, 1, v.max_skill_level)
			for key: String in ["accuracy_bonus", "power_bonus", "evasion_bonus"]:
				v.integer(e, key, 0)
			v.number(e, "damage_reduction", 0.0, max_dr)
			v.int_pair(e, "gold", 0, DataValidatorRules.NO_LIMIT, true)
			v.number(e, "rift_shard_chance", 0.0, 100.0)
			drops(v, e)


static func drops(v: DataValidatorRules, monster: Dictionary) -> void:
	var drops: Array[Dictionary] = v.object_list(monster, "drops")
	if drops.size() > MAX_DROPS:
		v.fail("field 'drops' has %d entries, at most %d" % [drops.size(), MAX_DROPS])
	for drop_index: int in drops.size():
		var drop: Dictionary = drops[drop_index]
		var prefix: String = "drops[%d]" % drop_index
		v.keys(drop, ["item", "chance_pct", "qty"], prefix)
		v.ref(drop, "item", v.items, "item", prefix)  # from M7 an equipment or tool entry drops instances (F-84)
		v.number(drop, "chance_pct", 0.0, 100.0, prefix)
		v.int_pair(drop, "qty", 1, DataValidatorRules.NO_LIMIT, true, prefix)


# --- classes -------------------------------------------------------------------------------------------------------

static func validate_classes(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	for path: String in files:
		v.at_file(path)
		var c: Dictionary = files[path]
		v.entry("class", 0, c, seen, CLASS_FIELDS, orders)
		if c.get("id") is String and c["id"] != path.get_file().get_basename():
			v.fail("id '%s' must be equal to the file name" % c["id"])
		existing_icon(v, c, CLASS_ICON_DIR)
		var weapon_kinds: Array = _kinds(v, c, "weapon_kinds", WEAPON_KINDS, 1)
		var offhand_kinds: Array = _kinds(v, c, "offhand_kinds", _offhand_kinds(), 0)
		_setups(v, c, weapon_kinds, offhand_kinds)
		DataValidatorTraits.validate_class_lists(v, c)


# The kinds under `key`: strings of `allowed`, at least `min_count`.
static func _kinds(v: DataValidatorRules, c: Dictionary, key: String, allowed: PackedStringArray, min_count: int
) -> Array:
	var result: Array = v.id_list(c, key, null, "", min_count)
	for kind: Variant in result:
		if not allowed.has(str(kind)):
			v.fail("field '%s': kind '%s' must be one of %s" % [key, kind, allowed])
	return result


static func _setups(v: DataValidatorRules, c: Dictionary, weapon_kinds: Array, offhand_kinds: Array) -> void:
	var ids: Dictionary[String, bool] = {}
	var pairs: Dictionary[String, bool] = {}
	var setups: Array[Dictionary] = v.object_list(c, "setups", "", 1)
	for index: int in setups.size():
		var s: Dictionary = setups[index]
		var prefix: String = "setups[%d]" % index
		v.keys(s, SETUP_FIELDS, prefix)
		v.text(s, "name", prefix)
		if v.text(s, "id", prefix):
			var id: String = s["id"] as String
			if id == UNARMED_SETUP:
				v.fail("field '%s.id': '%s' is reserved" % [prefix, UNARMED_SETUP])
			if ids.has(id):
				v.fail("duplicate setup '%s'" % id)
			ids[id] = true
		var weapon_ok: bool = v.text(s, "weapon", prefix)
		if weapon_ok and not weapon_kinds.has(s["weapon"]):
			v.fail("field '%s.weapon': kind '%s' is not in weapon_kinds" % [prefix, s["weapon"]])
		var offhand_ok: bool = v.text(s, "offhand", prefix)
		if offhand_ok and s["offhand"] != "" and not offhand_kinds.has(s["offhand"]):
			v.fail("field '%s.offhand': kind '%s' must be \"\" or in offhand_kinds" % [prefix, s["offhand"]])
		if weapon_ok and offhand_ok:
			var pair: String = "%s+%s" % [s["weapon"], s["offhand"]]
			if pairs.has(pair):
				v.fail("setups with weapon '%s' and offhand '%s' are duplicated" % [s["weapon"], s["offhand"]])
			pairs[pair] = true
		if s.has("alternate") and v.flag(s, "alternate", prefix) and s["alternate"] == true \
				and not WEAPON_KINDS.has(str(s.get("offhand"))):
			v.fail("field '%s.alternate' is allowed only with a weapon in the offhand" % prefix)
		v.modifiers(s, "modifiers", prefix)
		for modifier: Variant in (s["modifiers"] as Array if s.get("modifiers") is Array else []):
			if modifier is Dictionary and (modifier as Dictionary).has("scope") \
					and modifier["scope"] != String(Modifier.SCOPE_GLOBAL):
				v.fail("field '%s.modifiers': scope '%s' must be global" % [prefix, modifier["scope"]])


# --- affixes -------------------------------------------------------------------------------------------------------

static func validate_affixes(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "affixes")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("affix", index, e, seen, AFFIX_FIELDS)
			if v.text(e, "stat") and not v.stats.has(StringName(e["stat"] as String)):
				v.fail("field 'stat': stat '%s' is not in stats.json" % e["stat"])
			for slot: Variant in v.id_list(e, "slots", null, "", 1):
				if not DataValidatorItems.EQUIP_SLOTS.has(str(slot)):
					v.fail("field 'slots': '%s' must be one of %s" % [slot, DataValidatorItems.EQUIP_SLOTS])
			v.integer(e, "weight", 1)
			var last_ilvl: int = 0
			var tiers: Array[Dictionary] = v.object_list(e, "tiers", "", 1)
			for tier_index: int in tiers.size():
				last_ilvl = _tier(v, tiers[tier_index], "tiers[%d]" % tier_index, last_ilvl)


# One tier; returns its min_ilvl (or `last_ilvl` if invalid) for the increasing-order check of the next one.
static func _tier(v: DataValidatorRules, t: Dictionary, prefix: String, last_ilvl: int) -> int:
	v.keys(t, TIER_FIELDS, prefix)
	var result: int = last_ilvl
	if v.integer(t, "min_ilvl", 1, ITEM_LEVEL_MAX, prefix):
		result = int(t["min_ilvl"])
		if result <= last_ilvl:
			v.fail("field '%s.min_ilvl' must be greater than the previous tier's (%d)" % [prefix, last_ilvl])
	var has_range: bool = v.number(t, "min", -DataValidatorRules.NO_LIMIT, DataValidatorRules.NO_LIMIT, prefix)
	has_range = v.number(t, "max", -DataValidatorRules.NO_LIMIT, DataValidatorRules.NO_LIMIT, prefix) and has_range
	if has_range and float(t["min"]) > float(t["max"]):
		v.fail("field '%s' needs min <= max, got %s..%s" % [prefix, t["min"], t["max"]])
		has_range = false
	if t.has("step") and v.number(t, "step", 0.0, DataValidatorRules.NO_LIMIT, prefix, true) and has_range:
		var steps: float = (float(t["max"]) - float(t["min"])) / float(t["step"])
		if absf(steps - roundf(steps)) > STEP_TOLERANCE:
			v.fail("field '%s': max - min must be a multiple of step %s" % [prefix, t["step"]])
	return result


# --- balance.json (rules of the M4 keys; missing or mistyped values are already reported by the key checks) ----------

static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var dual: Variant = DataValidator.lookup(balance, "combat.dual_wield")
	if dual is Dictionary and DataValidatorRules.is_number((dual as Dictionary).get("interval_mult")):
		v.number(dual as Dictionary, "interval_mult", 0.0, 1.0, "combat.dual_wield", true)
	var combat: Variant = DataValidator.lookup(balance, "combat")
	if combat is Dictionary and DataValidatorRules.is_number((combat as Dictionary).get("max_pack_size")):
		v.integer(combat as Dictionary, "max_pack_size", 1, DataValidator.PACK_SIZE_MAX, "combat")
	DataValidatorTraits.validate_balance(v, balance)
	var counts: Variant = DataValidator.lookup(balance, "rarity.affix_count")
	for rarity: String in ["magic", "rare"]:
		if counts is Dictionary and (counts as Dictionary).get(rarity) is Array:
			v.int_pair(counts as Dictionary, rarity, 0, DataValidator.AFFIX_COUNT_MAX, true, "rarity.affix_count")


# Offhand kinds of a class: the offhand-slot kinds plus the one-handed sword (a greatsword is two-handed).
static func _offhand_kinds() -> PackedStringArray:
	var kinds: PackedStringArray = DataValidatorItems.OFFHAND_SLOT_KINDS.duplicate()
	kinds.append("sword")
	return kinds


# A required icon path under `dir` whose file must exist (monsters and classes have no placeholder fallback).
static func existing_icon(v: DataValidatorRules, e: Dictionary, dir: String) -> void:
	DataValidator.icon(v, e, dir)
	if e.get("icon") is String and (e["icon"] as String).begins_with(dir) and not ResourceLoader.exists(e["icon"] as String):
		v.fail("field 'icon': file '%s' does not exist" % e["icon"])


# The optional, reserved `sprite` of a monster: {idle, attack, hit, death}, each an existing file under res://assets/.
static func _sprite(v: DataValidatorRules, e: Dictionary) -> void:
	if not e.has("sprite"):
		return
	var sprite: Dictionary = v.object(e, "sprite")
	v.keys(sprite, SPRITE_STATES, "sprite")
	for state: String in SPRITE_STATES:
		if not sprite.has(state):
			v.fail("field 'sprite.%s' is required" % state)
		elif v.text(sprite, state, "sprite"):
			var path: String = sprite[state] as String
			if not path.begins_with(SPRITE_DIR) or not ResourceLoader.exists(path):
				v.fail("field 'sprite.%s': '%s' must be an existing file under %s" % [state, path, SPRITE_DIR])
