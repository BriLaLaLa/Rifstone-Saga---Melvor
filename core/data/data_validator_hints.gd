class_name DataValidatorHints
extends RefCounted
## Part of DataValidator (internal, not API for other modules): `data/hints/hints.json` (M9, docs/04_DATA_SCHEMA.md §10)
## and the structure of the balance keys `combat.auto_eat_tiers` (F-30) and `rift.sockets` (GDD §11), written with the
## toolkit of DataValidatorRules. A missing or mistyped key is already reported by the required-key checks.

const HINT_FIELDS: PackedStringArray = ["id", "title", "text", "trigger"]
const TRIGGERS: PackedStringArray = ["session_started_new", "bank_full", "first_shard", "mastery_node_affordable",
	"player_died", "first_level_10"]
const TIER_FIELDS: PackedStringArray = ["threshold_pct", "target_pct"]
const SOCKET_SKILL: String = "riftbinding"


static func validate(v: DataValidatorRules, files: Dictionary[String, Dictionary]) -> void:
	var seen: Dictionary[StringName, bool] = {}
	for path: String in files:
		v.at_file(path)
		var list: Array[Dictionary] = DataValidator.entries(v, files[path], "hints")
		for index: int in list.size():
			var e: Dictionary = list[index]
			v.entry("hint", index, e, seen, HINT_FIELDS)
			v.text(e, "title")
			v.text(e, "text")
			v.one_of(e, "trigger", TRIGGERS)


## `combat.auto_eat_tiers`: index 0 is null (off), every other tier is {threshold_pct, target_pct} with
## 0 < threshold <= target <= 100. `rift.sockets`: at least one {level} with levels in 1..max skill level, not decreasing.
static func validate_balance(v: DataValidatorRules, balance: Dictionary) -> void:
	var tiers: Variant = DataValidator.lookup(balance, "combat.auto_eat_tiers")
	if tiers is Array:
		_tiers(v, tiers as Array)
	var sockets: Variant = DataValidator.lookup(balance, "rift.sockets")
	if sockets is Array:
		_sockets(v, sockets as Array)


static func _tiers(v: DataValidatorRules, tiers: Array) -> void:
	if tiers.size() < 2 or tiers[0] != null:
		v.fail("key 'combat.auto_eat_tiers' needs null at index 0 and at least one tier")
	for index: int in range(1, tiers.size()):
		var prefix: String = "combat.auto_eat_tiers[%d]" % index
		if not tiers[index] is Dictionary:
			v.fail("key '%s' must be an object" % prefix)
			continue
		var tier: Dictionary = tiers[index] as Dictionary
		v.keys(tier, TIER_FIELDS, prefix)
		var ok: bool = v.number(tier, "threshold_pct", 0.0, 100.0, prefix, true)
		ok = v.number(tier, "target_pct", 0.0, 100.0, prefix, true) and ok
		if ok and float(tier["threshold_pct"]) > float(tier["target_pct"]):
			v.fail("key '%s' needs threshold_pct <= target_pct" % prefix)


static func _sockets(v: DataValidatorRules, sockets: Array) -> void:
	if sockets.is_empty():
		v.fail("key 'rift.sockets' needs at least one socket")
	var previous: float = 0.0
	for index: int in sockets.size():
		var prefix: String = "rift.sockets[%d]" % index
		if not sockets[index] is Dictionary:
			v.fail("key '%s' must be an object" % prefix)
			continue
		var socket: Dictionary = sockets[index] as Dictionary
		v.keys(socket, ["level"], prefix)
		if v.integer(socket, "level", 1.0, v.max_skill_level, prefix):
			if float(socket["level"]) < previous:
				v.fail("key '%s.level' must not decrease" % prefix)
			previous = float(socket["level"])
