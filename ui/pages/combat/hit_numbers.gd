class_name HitNumbers
extends RefCounted
## Floating combat numbers over a portrait (docs/UI_GDR.md §2): a label that rises and fades inside `holder`, then
## frees itself. Big (gold) numbers are the strong hits. Several numbers at once stack one below the other instead of
## overlapping. Presentation only; durations and sizes in `UiStyle.COMBAT_*`.

const NODE_NAME: String = "HitNumber"
const START_FRACTION: float = 0.15
const STACK_GAP_PX: float = 2.0


## Shows `text` over `holder` (a plain Control, not a container). Returns the label.
static func spawn(holder: Control, text: String, color: Color, big: bool) -> Label:
	var label := Label.new()
	label.name = NODE_NAME
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_override("font", UiStyle.font_bold())
	label.add_theme_font_size_override("font_size",
			UiStyle.COMBAT_HIT_BIG_FONT_SIZE if big else UiStyle.COMBAT_HIT_FONT_SIZE)
	var ys: Array[float] = []
	for other: Node in holder.get_children():
		if other is Label and not other.is_queued_for_deletion():
			ys.append((other as Label).position.y)
	holder.add_child(label)
	var height: float = label.get_minimum_size().y
	label.size = Vector2(holder.size.x, height)
	label.position = Vector2(0.0, free_y(ys, holder.size.y * START_FRACTION, height + STACK_GAP_PX))
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - UiStyle.COMBAT_HIT_RISE, UiStyle.COMBAT_HIT_FADE_SEC)
	tween.tween_property(label, "modulate:a", 0.0, UiStyle.COMBAT_HIT_FADE_SEC)
	tween.chain().tween_callback(label.queue_free)
	return label


## Lowest y at or below `start` that is at least `step` away from every y in `taken` (the numbers on screen).
static func free_y(taken: Array[float], start: float, step: float) -> float:
	var y: float = start
	var moved: bool = true
	while moved:
		moved = false
		for other: float in taken:
			if absf(other - y) < step:
				y = other + step
				moved = true
	return y


## Removes every number still on screen (end of the combat).
static func clear(holder: Control) -> void:
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
