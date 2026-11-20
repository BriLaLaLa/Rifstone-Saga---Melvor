class_name StackHaste
extends StackBase
## F-192 `stack_haste` (`gain`, `pct`, `max`, `lose`): the timer of the next base attack is multiplied by `1 - s x pct/100` (the engine
## floors it and keeps it at `combat.min_attack_interval_ms` or more). `s` is the value before the hits of that attack.


func base_timer_mult(_ctx: EffectContext) -> float:
	if _stacks <= 0:
		return 1.0
	return maxf(0.0, 1.0 - float(_stacks) * float(params["pct"]) / 100.0)
