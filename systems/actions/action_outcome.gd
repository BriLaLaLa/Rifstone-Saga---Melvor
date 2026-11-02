class_name ActionOutcome
extends RefCounted
## Result of one action cycle, filled by a resolver (GatheringResolver, ArtisanResolver in M3-01).
##
## `ok` false: the cycle did not count, nothing changed and `reason` says why (e.g. `bank_full`).
## `ok` true: `outputs` are the items added to the bank (the rift shard included), `consumed` the inputs removed,
## `xp` the skill xp granted (F-02), `mastery_xp` the F-10 mxp, `shard` whether a rift shard dropped (F-07).

var ok: bool = false
var reason: StringName = &""
var outputs: Dictionary[StringName, int] = {}
var consumed: Dictionary[StringName, int] = {}
var xp: int = 0
var mastery_xp: int = 0
var shard: bool = false
