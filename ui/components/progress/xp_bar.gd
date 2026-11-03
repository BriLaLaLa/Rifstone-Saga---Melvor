class_name XpBar
extends Control
## Experience bar of a level (docs/05_INTERFACES.md §7): skill xp with the F-01 table, mastery xp with F-09.
##
## The owner reads the cumulative xp from the session and passes it with the table; the bar shows the fraction of
## the current level (`XpTable.progress`) and the text "<xp> / <xp of the next level> XP" ("Livello massimo" at the
## top). It keeps no game state and never reads the session.

const XP_TEXT: String = "%s / %s XP"
const MAX_TEXT: String = "%s XP  ·  Livello massimo"
const NEXT_TOOLTIP: String = "Al prossimo livello: %s XP"


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


## Draws `xp` (cumulative) on the levels of `table`.
func set_xp(table: XpTable, xp: int) -> void:
	if table == null:
		push_error("XpBar.set_xp: null table")
		return
	var level: int = table.level_for_xp(xp)
	_bar().value = table.progress(xp)
	if level >= table.max_level:
		_label().text = MAX_TEXT % NumberFormat.format_int(xp)
		tooltip_text = ""
		return
	var next_xp: int = table.xp_for_level(level + 1)
	_label().text = XP_TEXT % [NumberFormat.format_int(xp), NumberFormat.format_int(next_xp)]
	tooltip_text = NEXT_TOOLTIP % NumberFormat.format_int(next_xp - xp)


## Fraction of the level drawn now (0..1), for tests and accessibility.
func shown_progress() -> float:
	return _bar().value


## Text drawn on the bar.
func shown_text() -> String:
	return _label().text


func _bar() -> ProgressBar:
	return get_node("%Bar") as ProgressBar


func _label() -> Label:
	return get_node("%XpLabel") as Label
