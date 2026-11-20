class_name BleedClock
extends RefCounted
## The one clock of the Bleed of an encounter (docs/02_FORMULAS_M28.md F-186): on while an enemy bleeds, it expires every
## `combat.conditions.tick_ms`, and each expiry is an event of the engine (the ticks of every bleeding enemy). Off = -1.

var ms: int = -1  # ms to the next tick; -1 = off


## An enemy starts to bleed: the clock starts if it is off (it keeps its time if it is on).
func start_if_idle(params: ConditionParams) -> void:
	if ms < 0:
		ms = params.tick_ms


## Time passes (nothing while it is off).
func elapse(delta_ms: int) -> void:
	if ms >= 0:
		ms = maxi(0, ms - delta_ms)


func due() -> bool:
	return ms == 0


## Ms to the next tick, `AbilityRunner.NO_TIMER` while it is off.
func next_ms() -> int:
	return AbilityRunner.NO_TIMER if ms < 0 else ms


## After the ticks: on again for `tick_ms` if somebody still bleeds, off otherwise.
func rearm(any_bleeding: bool, params: ConditionParams) -> void:
	ms = params.tick_ms if any_bleeding else -1


func reset() -> void:
	ms = -1
