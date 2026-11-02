class_name SessionSnapshot
extends RefCounted
## Copy of the counters a summary compares before and after a stretch of play (offline, tests).
##
## `take` reads only the systems that exist: a missing system leaves its fields empty (0).
## Each system's task fills its part: skills xp/levels (M1-08), bank and gold (M1-07), kills/deaths/food (M4).

var xp: Dictionary[StringName, int] = {}
var levels: Dictionary[StringName, int] = {}
var bank: Dictionary[StringName, int] = {}
var gold: int = 0
var kills: Dictionary[StringName, int] = {}
var deaths: int = 0
var food_eaten: int = 0


static func take(session: GameSession) -> SessionSnapshot:
	assert(session != null, "SessionSnapshot.take needs a session")
	var snapshot: SessionSnapshot = SessionSnapshot.new()
	return snapshot
