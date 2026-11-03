class_name CombatantCard
extends PanelContainer
## Card of one combatant on the combat page (docs/01_GDD.md §10.11): name, subtitle, HP bar, attack timer bar, target
## highlight and the hit number of the last attack (faded in place, no movement).
##
## The page passes the values read from `combat.get_state()`; the card holds no game state, only its nodes.

var _target_style: StyleBoxFlat = null
var _fade: Tween = null

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _hit_label: Label = %HitLabel


func _ready() -> void:
	custom_minimum_size = UiStyle.COMBAT_CARD_SIZE
	_target_style = UiStyle.flat(UiStyle.BG_WINDOW, UiStyle.GOLD_LIGHT, UiStyle.COMBAT_TARGET_BORDER, 10.0)
	_hp_bar.custom_minimum_size.y = UiStyle.COMBAT_BAR_HEIGHT
	_timer_bar.custom_minimum_size.y = UiStyle.COMBAT_TIMER_BAR_HEIGHT
	_hp_bar.show_percentage = false
	_timer_bar.show_percentage = false
	UiStyle.style_bar(_hp_bar, UiStyle.HP)
	UiStyle.style_bar(_timer_bar, UiStyle.COMBAT_TIMER_COLOR)
	_hit_label.add_theme_font_size_override("font_size", UiStyle.COMBAT_HIT_FONT_SIZE)
	_hit_label.modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_PASS


## Name and second line, set once.
func setup(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle


## Draws the values read from the session; `timer_ms` counts down to the attack.
func redraw(hp: int, max_hp: int, timer_ms: int, interval_ms: int, is_target: bool) -> void:
	_hp_bar.max_value = maxf(1.0, max_hp)
	_hp_bar.value = hp
	_hp_label.text = CombatTexts.HP_TEXT % [NumberFormat.format_int(hp), NumberFormat.format_int(max_hp)]
	var progress: float = 0.0
	if interval_ms > 0 and hp > 0:
		progress = clampf(1.0 - float(timer_ms) / float(interval_ms), 0.0, 1.0)
	_timer_bar.value = progress
	if is_target:
		add_theme_stylebox_override("panel", _target_style)
	else:
		remove_theme_stylebox_override("panel")
	modulate.a = 1.0 if hp > 0 else 0.5


## Shows the outcome of an attack against this combatant: damage, "Mancato" or "Parato"; fades in place.
func show_hit(hit: bool, damage: int, blocked: bool, color: Color) -> void:
	if blocked:
		_hit_label.text = CombatTexts.BLOCKED_TEXT
	elif not hit:
		_hit_label.text = CombatTexts.MISS_TEXT
	else:
		_hit_label.text = CombatTexts.HIT_TEXT % NumberFormat.format_int(damage)
	_hit_label.add_theme_color_override("font_color", color)
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_hit_label.modulate.a = 1.0
	_fade = create_tween()
	_fade.tween_property(_hit_label, "modulate:a", 0.0, UiStyle.COMBAT_HIT_FADE_SEC)


## Text of the hit label, for tests.
func hit_text() -> String:
	return _hit_label.text


## HP bar value, for tests.
func shown_hp() -> int:
	return int(_hp_bar.value)


## True while the target highlight is on, for tests.
func is_highlighted() -> bool:
	return has_theme_stylebox_override("panel")


## Timer bar fraction (0..1), for tests.
func shown_timer() -> float:
	return _timer_bar.value
