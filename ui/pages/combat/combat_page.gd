class_name CombatPage
extends Page
## Combat page (docs/01_GDD.md §10.11, 05_INTERFACES.md §7), route `combat`: area list (requirements checked with
## `character.meets_requirements`), the player card, one card per enemy of the group (target highlighted), hit numbers,
## the loot bag with "Raccogli tutto", "Mangia" and "Ferma".
##
## Everything is read from `session.combat.get_state()`, `session.character`, `session.equipment`, `session.bank` and
## `session.data`: on the combat signals and every frame (`_process`, bars only move). Player actions are commands
## (`combat.start`, `combat.stop`, `combat.eat`, `combat.loot.collect_all`); a refused command shows its reason.
## It keeps no game state: only the session reference, its nodes (cards by position) and the connections.

const LOG_CATEGORY: String = "ui"
const CARD_SCENE: PackedScene = preload("res://ui/pages/combat/combatant_card.tscn")
const AREA_ROW_NAME: String = "Area_%s"
const ENEMY_CARD_NAME: String = "Enemy_%d"

var _session: GameSession = null
## Signal, callable pairs connected in `bind` (disconnected in `unbind`).
var _connections: Array[Array] = []
var _enemy_cards: Array[CombatantCard] = []
var _enemy_ids: Array[StringName] = []
var _area_buttons: Dictionary[StringName, Button] = {}

@onready var _margin: MarginContainer = %Margin
@onready var _root_row: HBoxContainer = %Root
@onready var _area_panel: PanelContainer = %AreaPanel
@onready var _areas_title: Label = %AreasTitle
@onready var _area_list: VBoxContainer = %AreaList
@onready var _main_column: VBoxContainer = %MainColumn
@onready var _area_label: Label = %AreaLabel
@onready var _state_label: Label = %StateLabel
@onready var _food_label: Label = %FoodLabel
@onready var _eat_button: Button = %EatButton
@onready var _stop_button: Button = %StopButton
@onready var _message_label: Label = %MessageLabel
@onready var _player_card: CombatantCard = %PlayerCard
@onready var _enemy_flow: HFlowContainer = %EnemyFlow
@onready var _loot_title: Label = %LootTitle
@onready var _loot_count: Label = %LootCount
@onready var _collect_button: Button = %CollectButton
@onready var _loot_list: VBoxContainer = %LootList
@onready var _loot_scroll: ScrollContainer = %LootScroll


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.COMBAT_MARGIN)
	_root_row.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	_main_column.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	_area_panel.custom_minimum_size.x = UiStyle.COMBAT_AREA_LIST_WIDTH
	_loot_scroll.custom_minimum_size.y = UiStyle.COMBAT_LOOT_MIN_HEIGHT
	_areas_title.text = CombatTexts.AREAS_TITLE
	_loot_title.text = CombatTexts.LOOT_TITLE
	_eat_button.text = CombatTexts.EAT_TEXT
	_stop_button.text = CombatTexts.STOP_TEXT
	_collect_button.text = CombatTexts.COLLECT_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.visible = false
	_eat_button.pressed.connect(_on_eat_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_collect_button.pressed.connect(_on_collect_pressed)
	set_process(false)


## Draws the combat of `session` and follows its signals.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	var events: GameEvents = _session.events
	var resync: Callable = _redraw_all
	_connect(events.combat_started, _on_combat_started)
	_connect(events.combat_stopped, resync.unbind(1))
	_connect(events.encounter_started, resync.unbind(1))
	_connect(events.encounter_cleared, resync)
	_connect(events.player_hp_changed, resync.unbind(2))
	_connect(events.monster_hp_changed, resync.unbind(3))
	_connect(events.monster_killed, resync.unbind(2))
	_connect(events.food_eaten, resync.unbind(2))
	_connect(events.food_changed, resync.unbind(1))
	_connect(events.bank_changed, resync.unbind(3))
	_connect(events.loot_bag_changed, resync.unbind(2))
	_connect(events.equipment_changed, resync.unbind(2))
	_connect(events.combat_hit, _on_combat_hit)
	_connect(events.player_died, _on_player_died)
	_connect(events.character_level_up, _on_character_level_up)
	_build_area_list()
	_message_label.visible = false
	_redraw_all()
	set_process(true)


## Disconnects every signal connected in `bind`.
func unbind() -> void:
	set_process(false)
	for pair: Array in _connections:
		var source: Signal = pair[0]
		var callable: Callable = pair[1]
		if source.is_connected(callable):
			source.disconnect(callable)
	_connections.clear()
	_session = null


func _exit_tree() -> void:
	unbind()


func _process(_delta: float) -> void:
	if _session != null:
		var state: Dictionary = _session.combat.get_state()
		_redraw_player(state)
		_redraw_enemies(state)


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


## One button per area of the data; the requirements are rechecked on level up.
func _build_area_list() -> void:
	for child: Node in _area_list.get_children():
		_area_list.remove_child(child)
		child.queue_free()
	_area_buttons.clear()
	for area: AreaDef in _session.data.areas():
		var button := Button.new()
		button.name = AREA_ROW_NAME % area.id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = area.description
		button.pressed.connect(_on_area_pressed.bind(area.id))
		_area_list.add_child(button)
		_area_buttons[area.id] = button
	_refresh_area_list()


func _refresh_area_list() -> void:
	var current: StringName = _session.combat.area_id() if _session.combat.is_active() else &""
	for area: AreaDef in _session.data.areas():
		var button: Button = _area_buttons[area.id]
		var unlocked: bool = _session.character.meets_requirements(area.requirements)
		var text: String = area.name
		if not unlocked:
			text += "\n" + ItemTooltipLines.CHARACTER_REQUIREMENT_TEXT % area.requirements.get(&"character", 1)
		elif area.id == current:
			text += "\n" + CombatTexts.CURRENT_AREA_TEXT
		button.text = text
		button.disabled = not unlocked
		button.add_theme_color_override("font_color", UiStyle.GOLD_LIGHT if area.id == current else UiStyle.TEXT)


## Rereads the combat state and redraws header, cards and loot.
func _redraw_all() -> void:
	if _session == null:
		return
	var state: Dictionary = _session.combat.get_state()
	var running: bool = state["state"] != CombatEngine.STATE_IDLE
	var area: AreaDef = _session.data.area(state["area"]) if running else null
	_area_label.text = area.name if area != null else CombatTexts.NO_AREA_TEXT
	_state_label.text = CombatTexts.STATE_TEXTS.get(state["state"], CombatTexts.STATE_TEXT_DEFAULT)
	_stop_button.disabled = not running
	_eat_button.disabled = not running
	_refresh_area_list()
	_redraw_food()
	_redraw_player(state)
	_redraw_enemies(state)
	_redraw_loot()


func _redraw_food() -> void:
	var food_id: StringName = _session.equipment.get_food()
	var def: ItemDef = _session.data.item(food_id) if food_id != &"" else null
	if def == null:
		_food_label.text = CombatTexts.NO_FOOD_TEXT
		return
	_food_label.text = CombatTexts.FOOD_TEXT % [def.name, NumberFormat.format_int(_session.bank.get_count(food_id))]


func _redraw_player(state: Dictionary) -> void:
	var class_def: ClassDef = _session.character.class_def()
	var setup: SetupDef = _session.equipment.setup_def()
	_player_card.setup(class_def.name if class_def != null else "", setup.name if setup != null else "")
	_player_card.redraw(state["player_hp"], state["player_max_hp"], state["player_timer_ms"],
			state["player_interval_ms"], false)


## One card per position of the encounter; rebuilt when the group (monster ids) changes.
func _redraw_enemies(state: Dictionary) -> void:
	var enemies: Array = state["enemies"]
	var ids: Array[StringName] = []
	for enemy: Dictionary in enemies:
		ids.append(enemy["monster"])
	if ids != _enemy_ids:
		_rebuild_enemy_cards(ids)
	for i: int in enemies.size():
		var enemy: Dictionary = enemies[i]
		_enemy_cards[i].redraw(enemy["hp"], enemy["max_hp"], enemy["timer_ms"], enemy["interval_ms"],
				i == int(state["target"]))


func _rebuild_enemy_cards(ids: Array[StringName]) -> void:
	for card: CombatantCard in _enemy_cards:
		_enemy_flow.remove_child(card)
		card.queue_free()
	_enemy_cards.clear()
	_enemy_ids = ids.duplicate()
	for i: int in ids.size():
		var def: MonsterDef = _session.data.monster(ids[i])
		var card: CombatantCard = CARD_SCENE.instantiate() as CombatantCard
		card.name = ENEMY_CARD_NAME % i
		_enemy_flow.add_child(card)
		if def != null:
			card.setup(def.name, CombatTexts.INTERVAL_TEXT % CombatTexts.seconds_text(def.attack_interval_ms))
		else:
			card.setup(String(ids[i]), "")
		_enemy_cards.append(card)


func _redraw_loot() -> void:
	var bag: LootBag = _session.combat.loot
	_loot_count.text = CombatTexts.LOOT_COUNT_TEXT % [NumberFormat.format_int(bag.used()),
			NumberFormat.format_int(bag.capacity())]
	for child: Node in _loot_list.get_children():
		_loot_list.remove_child(child)
		child.queue_free()
	var items: Array[Dictionary] = bag.items()
	_collect_button.disabled = items.is_empty()
	if items.is_empty():
		var empty := Label.new()
		empty.text = CombatTexts.LOOT_EMPTY_TEXT
		empty.theme_type_variation = &"MutedLabel"
		_loot_list.add_child(empty)
		return
	for entry: Dictionary in items:
		var def: ItemDef = _session.data.item(entry["item"])
		var line := Label.new()
		line.text = CombatTexts.LOOT_LINE_TEXT % [def.name if def != null else String(entry["item"]),
				NumberFormat.format_int(entry["qty"])]
		_loot_list.add_child(line)


func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = CombatTexts.REASON_TEXTS.get(result.reason, CombatTexts.REASON_TEXT_DEFAULT)
	_redraw_all()


func _on_area_pressed(area_id: StringName) -> void:
	if _session != null:
		_show_result(_session.combat.start(area_id))


func _on_stop_pressed() -> void:
	if _session != null:
		_session.combat.stop()
		_message_label.visible = false
		_redraw_all()


func _on_eat_pressed() -> void:
	if _session != null:
		_show_result(_session.combat.eat())


func _on_collect_pressed() -> void:
	if _session != null:
		_show_result(_session.combat.loot.collect_all())


func _on_combat_hit(_attacker: int, target: int, hit: bool, damage: int, blocked: bool) -> void:
	if target == CombatEngine.PLAYER:
		_player_card.show_hit(hit, damage, blocked, UiStyle.BAD)
	elif target >= 0 and target < _enemy_cards.size():
		_enemy_cards[target].show_hit(hit, damage, blocked, UiStyle.GOLD_LIGHT)


func _on_player_died() -> void:
	_message_label.text = CombatTexts.DEFEAT_TEXT
	_message_label.visible = true


func _on_character_level_up(_new_level: int) -> void:
	if _session != null:
		_refresh_area_list()


# A new start (from this page or elsewhere) clears the defeat or refusal message of the previous run.
func _on_combat_started(_area_id: StringName) -> void:
	_message_label.visible = false
	_redraw_all()
