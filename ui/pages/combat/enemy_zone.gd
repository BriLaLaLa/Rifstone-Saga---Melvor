class_name EnemyZone
extends PanelContainer
## Enemy side of the combat page (docs/UI_GDR.md §2, red frame): the big target card on top and the other enemies of
## the group as small cards "in fila" (the dead ones stay dimmed until the next group).
##
## One small card per position of the encounter, rebuilt when the group (monster ids) changes; the target position is
## hidden in the queue and shown in the big card. Everything is redrawn from the state the page reads from
## `combat.get_state()`; the zone keeps only its nodes, the monster definitions of the group (data, read-only) and the
## index shown in the big card.

const CARD_SCENE: PackedScene = preload("res://ui/pages/combat/enemy_card.tscn")
const CARD_NAME: String = "Enemy_%d"

var _ids: Array[StringName] = []
var _cards: Array[EnemyCard] = []
var _target_card: EnemyCard = null
var _shown_index: int = -2
## Presentation: the compact view (docs/METIN.md Z6) is shown instead of the cards.
var _compact: bool = false
var _crowd: CrowdView = null

@onready var _title: Label = %TargetTitle
@onready var _count: Label = %CountLabel
@onready var _target_holder: VBoxContainer = %TargetHolder
@onready var _empty: Label = %EmptyLabel
@onready var _queue_title: Label = %QueueTitle
@onready var _queue: HFlowContainer = %QueueFlow
@onready var _queue_scroll: ScrollContainer = %QueueScroll


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.COMBAT_ENEMY_BG, UiStyle.COMBAT_ENEMY_BORDER,
			UiStyle.COMBAT_FRAME_WIDTH, 14.0))
	_title.text = CombatTexts.TARGET_TITLE
	_title.add_theme_color_override("font_color", UiStyle.COMBAT_TARGET_BORDER_COLOR)
	_queue_title.add_theme_color_override("font_color", UiStyle.COMBAT_TARGET_BORDER_COLOR)
	_target_card = CARD_SCENE.instantiate() as EnemyCard
	_target_card.large = true
	_target_card.name = "TargetCard"
	_target_holder.add_child(_target_card)
	_target_card.visible = false
	_queue.resized.connect(_fit_cards)
	_crowd = CrowdView.new()
	_crowd.name = "CrowdView"
	_crowd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crowd.visible = false
	_queue_scroll.get_parent().add_child(_crowd)


## Redraws from `state` (`combat.get_state()`); `session` gives the data and the player's style.
func refresh(session: GameSession, state: Dictionary) -> void:
	var enemies: Array = state["enemies"]
	if _set_compact(session, state):
		_crowd.refresh(session, state)
		_count.text = CombatTexts.ENEMY_COUNT_TEXT % [int(state["enemies_alive"]), enemies.size()]
		return
	var ids: Array[StringName] = []
	for enemy: Dictionary in enemies:
		ids.append(enemy["monster"])
	if ids != _ids:
		_rebuild(session.data, ids)
	var target: int = int(state["target"])
	var player_style: StringName = session.equipment.style()
	var alive: int = 0
	# M16-03: with a Monolith in the fight (`state.stone` not empty) the dead ones leave the screen; otherwise they stay dimmed.
	var hide_dead: bool = not (state.get("stone", {}) as Dictionary).is_empty()
	for i: int in enemies.size():
		var enemy: Dictionary = enemies[i]
		var card: EnemyCard = _cards[i]
		card.visible = i != target and not (hide_dead and int(enemy["hp"]) <= 0)
		card.redraw(enemy["hp"], enemy["max_hp"], enemy["timer_ms"], enemy["interval_ms"])
		card.set_hit_pct(int(enemy["hit_pct"]), int(enemy["enemy_hit_pct"]))
		if int(enemy["hp"]) > 0:
			alive += 1
			card.set_tag(EnemyView.tag_text(session.data, _ids[i], player_style))
	_redraw_target(session, enemies, target, player_style)
	var queued: int = 0
	for card: EnemyCard in _cards:
		queued += 1 if card.visible else 0
	_queue_title.text = CombatTexts.QUEUE_TITLE % queued
	_count.text = CombatTexts.ENEMY_COUNT_TEXT % [alive, enemies.size()] if not enemies.is_empty() else ""
	_empty.visible = target < 0
	_fit_cards()
	_empty.text = CombatTexts.STATE_TEXTS.get(state["state"], CombatTexts.STATE_TEXT_DEFAULT) \
			if enemies.is_empty() else CombatTexts.NO_TARGET_TEXT


## Switches between cards and compact view: more living enemies than `combat.crowd_threshold`. The cards are dropped
## while compact (none is built for a crowd) and rebuilt when the group is small again.
func _set_compact(session: GameSession, state: Dictionary) -> bool:
	var compact: bool = int(state.get("enemies_alive", 0)) > int(session.data.balance_value("combat.crowd_threshold"))
	if compact != _compact:
		_compact = compact
		_target_holder.visible = not compact
		_empty.visible = not compact
		_queue_title.visible = not compact
		_queue_scroll.visible = not compact
		_crowd.visible = compact
		_target_card.clear_effects()
		if compact:
			_rebuild(session.data, [] as Array[StringName])
		else:
			_crowd.clear_effects()
	return compact


func is_compact() -> bool:
	return _compact


func crowd_view() -> CrowdView:
	return _crowd


func _redraw_target(session: GameSession, enemies: Array, target: int, player_style: StringName) -> void:
	_target_card.visible = target >= 0
	if target < 0:
		_shown_index = -2
		return
	var id: StringName = _ids[target]
	if target != _shown_index:
		_target_card.clear_effects()
		_target_card.setup(EnemyView.name_of(session.data, id), EnemyView.icon_of(session.data, id), "",
				EnemyView.info_text(session.data, id))
		_target_card.set_stone(EnemyView.is_stone(session.data, id))
		_shown_index = target
	var enemy: Dictionary = enemies[target]
	_target_card.redraw(enemy["hp"], enemy["max_hp"], enemy["timer_ms"], enemy["interval_ms"])
	_target_card.set_hit_pct(int(enemy["hit_pct"]), int(enemy["enemy_hit_pct"]))
	_target_card.set_tag(EnemyView.tag_text(session.data, id, player_style))


func _rebuild(data: GameData, ids: Array[StringName]) -> void:
	for card: EnemyCard in _cards:
		_queue.remove_child(card)
		card.queue_free()
	_cards.clear()
	_ids = ids.duplicate()
	_shown_index = -2
	for i: int in ids.size():
		var card: EnemyCard = CARD_SCENE.instantiate() as EnemyCard
		card.name = CARD_NAME % i
		_queue.add_child(card)
		card.setup(EnemyView.name_of(data, ids[i]), EnemyView.icon_of(data, ids[i]), "", "")
		card.set_stone(EnemyView.is_stone(data, ids[i]))
		_cards.append(card)


## Width of a small card so that the cards of the row fill `avail`: as many columns as fit at the minimum width (at most
## one per card), the remaining space shared equally.
static func card_width(avail: float, count: int, min_width: float, separation: float) -> float:
	if avail <= 0.0 or count <= 0:
		return min_width
	var columns: int = clampi(floori((avail + separation) / (min_width + separation)), 1, count)
	return maxf(min_width, floorf((avail - separation * (columns - 1)) / columns))


## Widens the visible small cards to fill the row (they are 104 px wide at the least).
func _fit_cards() -> void:
	var visible_count: int = 0
	for card: EnemyCard in _cards:
		if card.visible:
			visible_count += 1
	var width: float = card_width(_queue.size.x, visible_count, UiStyle.COMBAT_QUEUE_CARD_WIDTH,
			float(_queue.get_theme_constant("h_separation")))
	for card: EnemyCard in _cards:
		card.set_card_width(width)


## Floating number on the enemy at `index` (and on the big card if it shows that enemy); flash if it was really hit.
func show_hit(index: int, text: String, color: Color, big: bool, flash: bool, damage: int = 0) -> void:
	if _compact:
		_crowd.add_hit(index, damage)  # one number per type and frame
		return
	if index < 0 or index >= _cards.size():
		return
	_cards[index].show_hit(text, color, big)
	if flash:
		_cards[index].play_hit()
	if index == _shown_index:
		_target_card.show_hit(text, color, big)
		if flash:
			_target_card.play_hit()


func play_attack(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index].play_attack()
	if index == _shown_index:
		_target_card.play_attack()


func play_death(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index].play_death()
	if index == _shown_index:
		_target_card.play_death()


## Removes numbers and animations everywhere (end of the combat).
func clear_effects() -> void:
	_target_card.clear_effects()
	_crowd.clear_effects()
	for card: EnemyCard in _cards:
		card.clear_effects()


## Card of the enemy at `index` in the queue, for tests.
func queue_card(index: int) -> EnemyCard:
	return _cards[index] if index >= 0 and index < _cards.size() else null


func target_card() -> EnemyCard:
	return _target_card


## Index of the enemy shown in the big card; -2 if none.
func shown_index() -> int:
	return _shown_index
