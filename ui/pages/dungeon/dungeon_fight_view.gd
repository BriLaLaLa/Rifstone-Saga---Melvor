class_name DungeonFightView
extends VBoxContainer
## Dungeon page, in a room (phases `fight` and `intro`, docs/05_INTERFACES.md §7.q). It reuses, read-only, PlayerColumn, HitNumbers and
## CombatFeed of the Combat page; the enemies are the cells of DungeonEnemyGrid. Header with the name of the room, the progress
## ("Stanza finale" in the boss) and "Fuggi" (the page asks the confirmation); in the final boss the BossBar stays over the enemies,
## and in the `intro` phase the IntroCard replaces the grid. Food and "Mangia" are in the header of the page.
## It reads `session.combat.get_state()` every frame and keeps no game state: only its nodes and the log of the feed.

signal flee_requested

const PLAYER_SCENE: PackedScene = preload("res://ui/pages/combat/player_column.tscn")
const ZONE_SCENE: PackedScene = preload("res://ui/pages/combat/enemy_zone.tscn")
const LOG_LINES: int = 4
const HEADER_SEPARATION: int = 16

var _session: GameSession = null
var _connections: Array[Array] = []
var _feed: CombatFeed = null
var _yield: CombatYield = null
var _player: PlayerColumn = null
## Never shown nor refreshed: the CombatFeed needs an EnemyZone to send the hits to; with no cards it ignores them.
var _feed_zone: EnemyZone = null
var _grid: DungeonEnemyGrid = null
var _boss_bar: DungeonBossBar = null
var _intro: DungeonIntroCard = null
var _room_label: Label = null
var _progress_label: Label = null
var _flee_button: Button = null
var _log_label: Label = null
var _bag_label: Label = null


func _init() -> void:
	add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	_build()


func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_yield = CombatYield.new(session.play_time_ms)
	_feed = CombatFeed.new(session, _yield, _feed_zone, _player)
	var events: GameEvents = session.events
	_connect(events.combat_hit, _on_combat_hit)
	_connect(events.monster_killed, _on_monster_killed)
	_connect(events.ability_used, _on_ability_used)
	_connect(events.trait_triggered, _on_trait_triggered)
	_connect(events.equipment_changed, _on_equipment_changed)
	_player.refresh_static(session)


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


## Redraws the header from `state` (`DungeonSystem.state()`) and the cells from the combat state; every frame.
func tick(state: Dictionary) -> void:
	if _session == null:
		return
	_room_label.text = DungeonTexts.room_title(state)
	_progress_label.text = DungeonTexts.progress_text(state)
	var stage: Dictionary = state.get("stage", {}) as Dictionary
	var is_boss: bool = (state.get("room", {}) as Dictionary).get("kind", &"") == &"boss" and not stage.is_empty()
	_boss_bar.visible = is_boss
	if is_boss:
		_boss_bar.setup(stage)
	var in_intro: bool = state.get("phase", &"") == &"intro" and not stage.is_empty()
	_intro.visible = in_intro
	_grid.visible = not in_intro
	if in_intro:
		_intro.show_stage(stage)
	var paused: bool = bool(state.get("paused", false))
	_flee_button.visible = not paused
	var bag_text: String = FractureTexts.bag_text(state.get("bag", {}) as Dictionary)
	_bag_label.text = "%s: %s" % [DungeonTexts.BAG_TITLE_TEXT, bag_text if bag_text != "" else DungeonTexts.BAG_EMPTY_TEXT]
	var combat_state: Dictionary = _session.combat.get_state()
	_player.tick(combat_state)
	if not in_intro:
		_grid.refresh(_session, combat_state, state)
	if _feed.flush():
		_refresh_log()


func intro_visible() -> bool:
	return _intro.visible


func grid() -> DungeonEnemyGrid:
	return _grid


func boss_bar() -> DungeonBossBar:
	return _boss_bar


func _build() -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", HEADER_SEPARATION)
	add_child(header)
	_room_label = _label("RoomLabel", &"TitleLabel")
	_progress_label = _label("ProgressLabel", &"MutedLabel")
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flee_button = Button.new()
	_flee_button.name = "FleeButton"
	_flee_button.text = DungeonTexts.FLEE_TEXT
	_flee_button.focus_mode = Control.FOCUS_NONE
	_flee_button.pressed.connect(func() -> void: flee_requested.emit())
	for node: Control in [_room_label, _progress_label, _flee_button]:
		header.add_child(node)
	var arena := HBoxContainer.new()
	arena.name = "Arena"
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	add_child(arena)
	_player = PLAYER_SCENE.instantiate() as PlayerColumn
	_player.name = "PlayerColumn"
	arena.add_child(_player)
	var enemies := VBoxContainer.new()
	enemies.name = "Enemies"
	enemies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemies.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	arena.add_child(enemies)
	_boss_bar = DungeonBossBar.new()
	_boss_bar.visible = false
	enemies.add_child(_boss_bar)
	_grid = DungeonEnemyGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemies.add_child(_grid)
	_intro = DungeonIntroCard.new()
	_intro.name = "IntroCard"
	_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_intro.visible = false
	enemies.add_child(_intro)
	_feed_zone = ZONE_SCENE.instantiate() as EnemyZone
	_feed_zone.name = "FeedZone"
	_feed_zone.visible = false
	add_child(_feed_zone)
	_bag_label = _label("BagLabel", &"HeaderLabel")
	_bag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bag_label.clip_text = false
	add_child(_bag_label)
	_log_label = _label("LogLabel", &"MutedLabel")
	_log_label.clip_text = false
	add_child(_log_label)


func _label(node_name: String, variation: StringName) -> Label:
	var label := Label.new()
	label.name = node_name
	label.clip_text = true
	if variation != &"":
		label.theme_type_variation = variation
	return label


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


func _refresh_log() -> void:
	_log_label.text = "\n".join(_yield.last_lines(LOG_LINES))


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


func _exit_tree() -> void:
	unbind()
