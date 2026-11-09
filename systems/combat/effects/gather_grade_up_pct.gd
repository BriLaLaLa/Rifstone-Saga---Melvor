class_name GatherGradeUpPct
extends TraitEffect
## F-120 `gather_grade_up_pct` (`pct`), hook `on_gather`: `roll_pct(pct)` for the product of the next resource of the same
## skill (the action after the worked one, by level; xp and mastery stay those of the worked resource). Nothing is
## rolled if the worked action is the last one of its skill.


func on_gather(ctx: GatherContext) -> void:
	if ctx.upgraded_action != null and ctx.rng.roll_pct(float(params["pct"])):
		ctx.grade_up = true
