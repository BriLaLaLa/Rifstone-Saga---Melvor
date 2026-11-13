class_name OfflineSummary
extends RefCounted
## What happened while the player was away: the difference of two SessionSnapshots plus the counters and stop
## reasons the simulator collected (docs/01_GDD.md §12, docs/05_INTERFACES.md §5.13).

var elapsed_ms: int = 0
var capped: bool = false
var xp: Dictionary[StringName, int] = {}
var levels: Dictionary[StringName, Vector2i] = {}  # x = from, y = to
var items: Dictionary[StringName, int] = {}  # bank difference (positive = gained, negative = consumed)
var gold_delta: int = 0
var kills: Dictionary[StringName, int] = {}
var deaths: int = 0
var food_eaten: int = 0
var stop_reasons: Array[StringName] = []
# Extras filled by OfflineSimulator (not part of the snapshots).
var stop_times_ms: Array[int] = []  # offline time at which each stop reason happened (parallel to stop_reasons)
var pieces_stored: int = 0  # pieces that entered the Armory
var pieces_dismantled: int = 0  # pieces salvaged by the Armory filter (item_salvaged with auto = true)
var pieces_rejected: int = 0  # pieces lost because the Armory was full (armory_rejected)
var bank_rejected: Dictionary[StringName, int] = {}  # yields that did not fit the bank (also auto-salvage yields)
var dungeon_frozen: bool = false  # M22: a dungeon run was in progress; it did not advance (F-144 rule 2)
var fractures: Array[Dictionary] = []  # M13: one {"grade", "outcome", "groups", "cards", "pieces"} per Fracture that ended


static func from_snapshots(before: SessionSnapshot, after: SessionSnapshot, elapsed_ms: int, capped: bool,
		stop_reasons: Array[StringName]) -> OfflineSummary:
	var summary: OfflineSummary = OfflineSummary.new()
	summary.elapsed_ms = elapsed_ms
	summary.capped = capped
	summary.xp = _diff(before.xp, after.xp)
	for key: StringName in after.levels:
		var from_level: int = before.levels.get(key, after.levels[key])
		if from_level != after.levels[key]:
			summary.levels[key] = Vector2i(from_level, after.levels[key])
	summary.items = _diff(before.bank, after.bank)
	summary.gold_delta = after.gold - before.gold
	summary.kills = _diff(before.kills, after.kills)
	summary.deaths = after.deaths - before.deaths
	summary.food_eaten = after.food_eaten - before.food_eaten
	summary.stop_reasons = stop_reasons.duplicate()
	return summary


## True when nothing happened: no gain, no loss, no kill, no stop.
func is_empty() -> bool:
	return (xp.is_empty() and levels.is_empty() and items.is_empty() and gold_delta == 0 and kills.is_empty()
		and deaths == 0 and food_eaten == 0 and stop_reasons.is_empty() and pieces_stored == 0
		and pieces_dismantled == 0 and pieces_rejected == 0 and bank_rejected.is_empty()
		and fractures.is_empty() and not dungeon_frozen)


# after - before for every key, zero differences left out.
static func _diff(before: Dictionary[StringName, int], after: Dictionary[StringName, int]) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for key: StringName in after:
		var delta: int = after[key] - before.get(key, 0)
		if delta != 0:
			result[key] = delta
	for key: StringName in before:
		if not after.has(key) and before[key] != 0:
			result[key] = -before[key]
	return result
