class_name DungeonFightView
extends VBoxContainer
## Dungeon page, in a room (phases `fight` and `intro`, docs/05_INTERFACES.md §7.q). It reuses, read-only, the components of the
## Combat page: PlayerColumn, EnemyZone and CombatFeed (hit numbers and log lines). Header with the name of the room and the
## progress, food, "Mangia" and "Fuggi" (the page asks the confirmation); in the `intro` phase the IntroCard replaces the enemies.
## It reads `session.combat.get_state()` every frame and keeps no game state: only its nodes and the log of the feed.

signal flee_requested
signal message_requested(text: String)

const PLAYER_SCENE: PackedScene = preload("res://ui/pages/combat/player_column.tscn")
const ZONE_SCENE: PackedScene = preload("res://ui/pages/combat/enemy_zone.tscn")
const LOG_LINES: int = 4
const HEADER_SEPARATION: int = 16

var _session: GameSession = null
var _connections: Array[Array] = []
var _feed: CombatFeed = null
var _yield: CombatYield = null
var _player: PlayerColumn = null
var _zone: EnemyZone = null
var _intro: DungeonIntroCard = null
var _room_label: Label = null
var _progress_label: Label = null
var _food_label: Label = null
var _eat_button: Button = null
var _flee_button: Button = null
var _log_label: Label = null


func _init() -> void:
	add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	_build()


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_yield = CombatYield.new(session.play_time_ms)
	_feed = CombatFeed.new(session, _yield, _zone, _player)
	var events: GameEvents = session.events
	_connect(events.combat_hit, _on_combat_hit)
	_connect(events.monster_killed, _on_monster_killed)
	_connect(events.ability_used, _on_ability_used)
	_connect(events.trait_triggered, _on_trait_triggered)
	_connect(events.equipment_changed, _on_equipment_changed)
	_connect(events.food_changed, _on_food_changed)
	_connect(events.food_eaten, _on_food_eaten)
	_player.refresh_static(session)
	_redraw_food()


func unbind() -> void:
	for pair: Array in _connections:
		var source: Signal = pair[0]
		var callable: Callable = pair[1]
		if source.is_connected(callable):
			source.disconnect(callable)
	_connections.clear()
	if _player != null:
		_player.hide_tooltip()
	_session = null
	_feed = null


## Redraws the header from `state` (`DungeonSystem.state()`) and the cards from the combat state; every frame.
func tick(state: Dictionary) -> void:
	if _session == null:
		return
	_room_label.text = DungeonTexts.room_title(state)
	_progress_label.text = DungeonTexts.progress_text(state)
	var in_intro: bool = state.get("phase", &"") == &"intro" and state.has("stage")
	_intro.visible = in_intro
	_zone.visible = not in_intro
	if in_intro:
		_intro.show_stage(state["stage"] as Dictionary)
	var paused: bool = bool(state.get("paused", false))
	_flee_button.visible = not paused
	_eat_button.visible = not paused
	var combat_state: Dictionary = _session.combat.get_state()
	_player.tick(combat_state)
	_zone.refresh(_session, combat_state)
	if _feed.flush():
		_refresh_log()


func intro_visible() -> bool:
	return _intro.visible


func _build() -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", HEADER_SEPARATION)
	add_child(header)
	_room_label = _label("RoomLabel", &"TitleLabel")
	_progress_label = _label("ProgressLabel", &"MutedLabel")
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_food_label = _label("FoodLabel", &"")
	_eat_button = _button("EatButton", DungeonTexts.EAT_TEXT, _on_eat_pressed)
	_flee_button = _button("FleeButton", DungeonTexts.FLEE_TEXT, func() -> void: flee_requested.emit())
	for node: Control in [_room_label, _progress_label, _food_label, _eat_button, _flee_button]:
		header.add_child(node)
	var arena := HBoxContainer.new()
	arena.name = "Arena"
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	add_child(arena)
	_player = PLAYER_SCENE.instantiate() as PlayerColumn
	_player.name = "PlayerColumn"
	arena.add_child(_player)
	_zone = ZONE_SCENE.instantiate() as EnemyZone
	_zone.name = "EnemyZone"
	_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.add_child(_zone)
	_intro = DungeonIntroCard.new()
	_intro.name = "IntroCard"
	_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro.visible = false
	arena.add_child(_intro)
	_log_label = _label("LogLabel", &"MutedLabel")
	add_child(_log_label)


func _label(node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.clip_text = true
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _button(node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


func _refresh_log() -> void:
	_log_label.text = "\n".join(_yield.last_lines(LOG_LINES))


func _redraw_food() -> void:
	var food_id: StringName = _session.equipment.get_food()
	var def: ItemDef = _session.data.item(food_id) if food_id != &"" else null
	_food_label.text = CombatTexts.NO_FOOD_TEXT if def == null else CombatTexts.FOOD_TEXT % [def.name,
			NumberFormat.format_int(_session.bank.get_count(food_id))]


func _on_eat_pressed() -> void:
	if _session == null:
		return
	var result: CommandResult = _session.combat.eat()
	message_requested.emit("" if result.ok else CombatTexts.REASON_TEXTS.get(result.reason, CombatTexts.REASON_TEXT_DEFAULT))
	_redraw_food()


func _on_combat_hit(attacker: int, target: int, hit: bool, damage: int, blocked: bool) -> void:
	if _feed != null:
		_feed.hit(attacker, target, hit, damage, blocked)
		_refresh_log()


func _on_monster_killed(index: int, _monster_id: StringName) -> void:
	if _feed != null:
		_feed.kill(index)
		_refresh_log()


func _on_ability_used(ability_id: StringName, _targets: Array) -> void:
	_player.flash_entry(ability_id)


func _on_trait_triggered(trait_id: StringName) -> void:
	_player.flash_entry(trait_id)


func _on_equipment_changed(_slot: StringName, _uid: int) -> void:
	_player.refresh_static(_session)


func _on_food_changed(_item_id: StringName) -> void:
	_redraw_food()


func _on_food_eaten(_item_id: StringName, _healed: int) -> void:
	_redraw_food()


func _exit_tree() -> void:
	unbind()
