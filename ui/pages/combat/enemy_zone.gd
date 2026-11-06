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

@onready var _title: Label = %TargetTitle
@onready var _count: Label = %CountLabel
@onready var _target_holder: VBoxContainer = %TargetHolder
@onready var _empty: Label = %EmptyLabel
@onready var _queue_title: Label = %QueueTitle
@onready var _queue: HFlowContainer = %QueueFlow


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


## Redraws from `state` (`combat.get_state()`); `session` gives the data and the player's style.
func refresh(session: GameSession, state: Dictionary) -> void:
	var enemies: Array = state["enemies"]
	var ids: Array[StringName] = []
	for enemy: Dictionary in enemies:
		ids.append(enemy["monster"])
	if ids != _ids:
		_rebuild(session.data, ids)
	var target: int = int(state["target"])
	var player_style: StringName = session.equipment.style()
	var alive: int = 0
	for i: int in enemies.size():
		var enemy: Dictionary = enemies[i]
		var card: EnemyCard = _cards[i]
		card.visible = i != target
		card.redraw(enemy["hp"], enemy["max_hp"], enemy["timer_ms"], enemy["interval_ms"])
		if int(enemy["hp"]) > 0:
			alive += 1
			card.set_tag(EnemyView.tag_text(session.data, _ids[i], player_style))
	_redraw_target(session, enemies, target, player_style)
	var queued: int = _cards.size() - (1 if target >= 0 else 0)
	_queue_title.text = CombatTexts.QUEUE_TITLE % maxi(queued, 0)
	_count.text = CombatTexts.ENEMY_COUNT_TEXT % [alive, enemies.size()] if not enemies.is_empty() else ""
	_empty.visible = target < 0
	_fit_cards()
	_empty.text = CombatTexts.STATE_TEXTS.get(state["state"], CombatTexts.STATE_TEXT_DEFAULT) \
			if enemies.is_empty() else CombatTexts.NO_TARGET_TEXT


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
func show_hit(index: int, text: String, color: Color, big: bool, flash: bool) -> void:
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
