class_name GatherContext
extends RefCounted
## What `GatheringResolver` hands to the `on_gather` effects of the legendary tools (F-120) and reads back. Effects only
## fill the outputs; the rolls go through `rng` in the order of the effects.

# Inputs.
var rng: RngService = null
var action: ActionDef = null
## The action of the next resource of the skill (null if `action` is the last one): the product of `gather_grade_up_pct`.
var upgraded_action: ActionDef = null

# Outputs.
var grade_up: bool = false
var bonus_items: Array[StringName] = []
var byproduct_mult: float = 1.0
