class_name ActionProgressBar
extends ProgressBar
## Progress bar of an action cycle (docs/05_INTERFACES.md §7, F-04), filled continuously.
##
## It holds no game state and computes no time: its owner reads `actions.get_progress(lane)` every frame and passes
## it to `set_progress`. The range is 0..1 with no step, so every frame value is drawn as it is.


func _init() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	show_percentage = false


## Draws `progress` (0..1, clamped) as read from the session.
func set_progress(progress: float) -> void:
	value = clampf(progress, 0.0, 1.0)
