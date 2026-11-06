class_name TargetRuleEffect
extends TraitEffect
## F-81 `target_rule` (`rule`): the target rule of F-76 (`first`, `lowest_hp`, `highest_hp`). With two such traits the
## lowest slot wins (decided by the order of the effects).


func target_rule() -> StringName:
	return StringName(str(params["rule"]))
