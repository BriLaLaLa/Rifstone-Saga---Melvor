class_name EnemyCard
extends PanelContainer
## Card of one enemy on the combat page (docs/UI_GDR.md §2): icon, name, style tag, HP bar, attack bar, floating hit
## numbers and the three minimal animations (lunge when it attacks, flash when it is hit, fade at death).
##
## `large` (set before the card enters the tree) makes the big "target" card: icon on the left, details on the right,
## HP numbers and the info line. The small variant is a column of the queue. The page passes the values read from
## `combat.get_state()` and the data; the card keeps only its nodes and a few presentation flags.

const HALO_MARGIN: float = 8.0

var large: bool = false

var _fade: Tween = null
var _lunge: Tween = null
var _flash: Tween = null
var _dead: bool = false
var _last_hit_text: String = ""
var _stone: bool = false
var _breath: Tween = null
var _halo_tween: Tween = null
var _halo: Panel = null
## Presentation: HP bar value being eased towards the real one (large card only); -1 = snap on the next draw.
var _hp_eased: float = -1.0
var _hp_target: int = 0

@onready var _box: BoxContainer = %Box
@onready var _portrait: Control = %Portrait
@onready var _frame: Panel = %Frame
@onready var _icon: TextureRect = %Icon
@onready var _floaters: Control = %Floaters
@onready var _details: VBoxContainer = %Details
@onready var _name: Label = %NameLabel
@onready var _tag: Label = %TagLabel
@onready var _info: Label = %InfoLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _timer_bar: ProgressBar = %TimerBar


func _ready() -> void:
	var side: int = UiStyle.COMBAT_TARGET_PORTRAIT_SIDE if large else UiStyle.COMBAT_QUEUE_ICON_SIDE
	_box.vertical = not large
	_portrait.custom_minimum_size = Vector2(side, side)
	_frame.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.COMBAT_ENEMY_BORDER, 1, 0.0))
	var border: Color = UiStyle.COMBAT_TARGET_BORDER_COLOR if large else UiStyle.COMBAT_ENEMY_BORDER
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_ENEMY_BG, border,
			UiStyle.COMBAT_FRAME_WIDTH if large else 1, 8.0))
	if not large:
		custom_minimum_size.x = UiStyle.COMBAT_QUEUE_CARD_WIDTH
	for label: Label in [_name, _tag]:
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_color_override("font_color", UiStyle.COMBAT_ENEMY_TEXT)
	if large:
		_name.theme_type_variation = &"TitleLabel"
	_info.visible = large
	_hp_label.visible = large
	_hp_bar.custom_minimum_size.y = UiStyle.COMBAT_TARGET_BAR_HEIGHT if large else UiStyle.COMBAT_BAR_HEIGHT - 6
	_timer_bar.custom_minimum_size.y = UiStyle.COMBAT_TIMER_BAR_HEIGHT if large else 5
	_hp_bar.show_percentage = false
	_timer_bar.show_percentage = false
	UiStyle.style_bar(_hp_bar, UiStyle.HP)
	UiStyle.style_bar(_timer_bar, UiStyle.COMBAT_TIMER_COLOR)
	_icon.pivot_offset = _portrait.custom_minimum_size / 2.0
	if large:
		_halo = Panel.new()
		_halo.name = "Halo"
		_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_halo.offset_left = -HALO_MARGIN
		_halo.offset_top = -HALO_MARGIN
		_halo.offset_right = HALO_MARGIN
		_halo.offset_bottom = HALO_MARGIN
		var glow: Color = UiStyle.COMBAT_STONE_BORDER
		glow.a = 0.3
		_halo.add_theme_stylebox_override("panel", UiStyle.flat(glow, UiStyle.COMBAT_STONE_BORDER, 3, 16.0))
		_halo.visible = false
		_portrait.add_child(_halo)
		_portrait.move_child(_halo, 0)


## Width of a small card (the zone widens the cards to fill its row).
func set_card_width(width: float) -> void:
	custom_minimum_size.x = width


## Static values, set when the group is built or the relation changes.
func setup(title: String, icon_path: String, tag_text: String, info_text: String) -> void:
	_name.text = title
	_tag.text = tag_text
	_info.text = info_text
	_icon.texture = ItemSlotView.icon_of(icon_path)


## Distinct look of a Rift Stone: violet frame and name (its attack bar is the pulse).
func set_stone(stone: bool) -> void:
	_stone = stone
	var border: Color = UiStyle.COMBAT_ENEMY_BORDER
	if stone:
		border = UiStyle.COMBAT_STONE_BORDER
	elif large:
		border = UiStyle.COMBAT_TARGET_BORDER_COLOR
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_STONE_BG if stone else UiStyle.COMBAT_ENEMY_BG,
			border, UiStyle.COMBAT_FRAME_WIDTH if (large or stone) else 1, 8.0))
	_name.add_theme_color_override("font_color", UiStyle.COMBAT_STONE_TEXT if stone else UiStyle.COMBAT_ENEMY_TEXT)
	UiStyle.style_bar(_timer_bar, UiStyle.COMBAT_STONE_BORDER if stone else UiStyle.COMBAT_TIMER_COLOR)


## True while the card shows a Rift Stone, for tests.
func is_stone() -> bool:
	return _stone


## Updates only the second line (the triangle relation changes with the equipment).
func set_tag(tag_text: String) -> void:
	_tag.text = tag_text


## Draws the values read from the session; `timer_ms` counts down to the attack.
func redraw(hp: int, max_hp: int, timer_ms: int, interval_ms: int) -> void:
	_hp_bar.max_value = maxf(1.0, max_hp)
	_hp_target = hp
	if large:  # the big card eases the bar (CombatFx.ease_bar); the small ones snap
		_hp_eased = CombatFx.ease_bar(_hp_eased, float(hp), get_process_delta_time())
		_hp_bar.value = _hp_eased
	else:
		_hp_bar.value = hp
	_hp_label.text = CombatTexts.HP_TEXT % [NumberFormat.format_int(hp), NumberFormat.format_int(max_hp)]
	var progress: float = 0.0
	if interval_ms > 0 and hp > 0:
		progress = clampf(1.0 - float(timer_ms) / float(interval_ms), 0.0, 1.0)
	_timer_bar.value = progress
	_dead = hp <= 0
	if _dead:
		_tag.text = CombatTexts.DEFEATED_TEXT
		if _fade == null or not _fade.is_running():
			modulate.a = UiStyle.COMBAT_DEAD_ALPHA
	else:
		_stop_fade()
		modulate.a = 1.0


## Floating number or word over the portrait.
func show_hit(text: String, color: Color, big: bool) -> void:
	_last_hit_text = text
	HitNumbers.spawn(_floaters, text, color, big, big and large)


## Lunge towards the player when this enemy attacks.
func play_attack() -> void:
	if _lunge != null and _lunge.is_valid():
		_lunge.kill()
	_icon.position.x = 0.0
	_lunge = create_tween()
	_lunge.tween_property(_icon, "position:x", -UiStyle.COMBAT_LUNGE_PX, UiStyle.COMBAT_LUNGE_SEC)
	_lunge.tween_property(_icon, "position:x", 0.0, UiStyle.COMBAT_LUNGE_SEC)


## Red flash of the icon when this enemy is hit.
func play_hit() -> void:
	if _flash != null and _flash.is_valid():
		_flash.kill()
	_icon.modulate = UiStyle.COMBAT_FLASH_COLOR
	_flash = create_tween()
	_flash.tween_property(_icon, "modulate", Color.WHITE, UiStyle.COMBAT_FLASH_SEC)


## Dissolve to the dimmed state when this enemy dies.
func play_death() -> void:
	_stop_fade()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", UiStyle.COMBAT_DEAD_ALPHA, UiStyle.COMBAT_DEATH_FADE_SEC)


## Starts the ambient loops of the big card: the breathing icon and the pulsing halo of a Monolith. Not in the compact
## view (the caller does not show the card) and not with reduced effects.
func start_ambient() -> void:
	stop_ambient()
	if not large:
		return
	_breath = CombatFx.breathe(_icon)
	_halo.visible = _stone
	if _stone:
		_halo_tween = CombatFx.pulse(_halo)


func stop_ambient() -> void:
	for tween: Tween in [_breath, _halo_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_icon.scale = Vector2.ONE
	if _halo != null:
		_halo.visible = false


## Stops animations and removes the numbers (end of the combat, or another enemy shown in this card).
func clear_effects() -> void:
	for tween: Tween in [_fade, _lunge, _flash]:
		if tween != null and tween.is_valid():
			tween.kill()
	stop_ambient()
	_hp_eased = -1.0
	_icon.position.x = 0.0
	_icon.modulate = Color.WHITE
	modulate.a = UiStyle.COMBAT_DEAD_ALPHA if _dead else 1.0
	HitNumbers.clear(_floaters)


func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()


## Text of the last floating number, for tests.
func hit_text() -> String:
	return _last_hit_text


## Numbers still on screen, for tests.
func floater_count() -> int:
	return _floaters.get_child_count()


## HP bar value, for tests.
func shown_hp() -> int:
	return _hp_target


## Attack bar fraction (0..1), for tests.
func shown_timer() -> float:
	return _timer_bar.value


## Name shown, for tests.
func shown_name() -> String:
	return _name.text


## Tag shown, for tests.
func shown_tag() -> String:
	return _tag.text


## True while the card is dimmed as a dead enemy, for tests.
func is_dead() -> bool:
	return _dead
