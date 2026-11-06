class_name HitNumbers
extends RefCounted
## Floating combat numbers over a portrait (docs/UI_GDR.md §2): a label that rises and fades inside `holder`, then
## frees itself. Big (gold) numbers are the strong hits. Presentation only; durations and sizes in `UiStyle.COMBAT_*`.

const NODE_NAME: String = "HitNumber"
const JITTER_STEPS: int = 3
const JITTER_PX: float = 14.0


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
	holder.add_child(label)
	var step: int = holder.get_child_count() % JITTER_STEPS - 1
	label.size = Vector2(holder.size.x, label.get_minimum_size().y)
	label.position = Vector2(step * JITTER_PX, holder.size.y * 0.15)
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - UiStyle.COMBAT_HIT_RISE, UiStyle.COMBAT_HIT_FADE_SEC)
	tween.tween_property(label, "modulate:a", 0.0, UiStyle.COMBAT_HIT_FADE_SEC)
	tween.chain().tween_callback(label.queue_free)
	return label


## Removes every number still on screen (end of the combat).
static func clear(holder: Control) -> void:
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
