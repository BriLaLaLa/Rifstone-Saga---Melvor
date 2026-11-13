class_name CombatPage
extends Page
## Combat page, GDR layout (docs/UI_GDR.md §2), route `combat`: header (area, food, Eat, Stop), player column against
## the enemy zone, bottom row with loot bag, yield and log. Everything is read from `session` (combat state, character,
## equipment, loadout, armory, bank, data) on the combat signals and every frame (`_process`, bars only move). Player
## actions are commands (`combat.start/stop/eat`, `combat.loot.collect_all`); a refused command shows its reason. It keeps
## no game state. The yield and the log (`CombatYield`) are derived readings of the events, never saved.

var _session: GameSession = null
## Signal, callable pairs connected in `bind` (disconnected in `unbind`).
var _connections: Array[Array] = []
var _yield: CombatYield = null
var _yield_values: Dictionary[StringName, Label] = {}
var _log_open: bool = false
## Presentation kept while another page is shown (the page is freed on navigation): yield window and log view of the
## session last drawn. Derived readings only, never saved.
static var _kept_session: GameSession = null
static var _kept_yield: CombatYield = null
static var _kept_log_open: bool = false
## Presentation: whether MessageLabel shows the no-food warning (B2).
var _food_warning: bool = false
## Presentation: the state line without the Fracture boss part, and the link to the Fractures page.
var _state_base: String = ""
var _fracture_link: Button = null
var _skip_control: SkipStoneControl = null
## Feedback of the combat events (numbers, counters, log lines), made in `bind`.
var _feed: CombatFeed = null
## The clickable map of the areas (overlay, built in `_ready`).
var _map: CombatMap = null

@onready var _margin: MarginContainer = %Margin
@onready var _main: VBoxContainer = %Main
@onready var _area_label: Label = %AreaLabel
@onready var _state_label: Label = %StateLabel
@onready var _map_button: Button = %MapButton
@onready var _food_label: Label = %FoodLabel
@onready var _eat_button: Button = %EatButton
@onready var _stop_button: Button = %StopButton
@onready var _message_label: Label = %MessageLabel
@onready var _player: PlayerColumn = %PlayerColumn
@onready var _vs_box: VBoxContainer = %VsBox
@onready var _vs_top: ColorRect = %VsTop
@onready var _vs_label: Label = %VsLabel
@onready var _vs_bottom: ColorRect = %VsBottom
@onready var _zone: EnemyZone = %EnemyZone
@onready var _bottom: HBoxContainer = %Bottom
@onready var _loot_title: Label = %LootTitle
@onready var _loot_count: Label = %LootCount
@onready var _collect_button: Button = %CollectButton
@onready var _loot_list: HBoxContainer = %LootList
@onready var _yield_title: Label = %YieldTitle
@onready var _yield_window: Label = %YieldWindow
@onready var _yield_grid: GridContainer = %YieldGrid
@onready var _log_scroll: ScrollContainer = %LogScroll
@onready var _log_label: Label = %LogLabel
@onready var _log_button: Button = %LogButton


func _ready() -> void:
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_margin.add_theme_constant_override(side, UiStyle.COMBAT_MARGIN)
	_main.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	_bottom.add_theme_constant_override("separation", UiStyle.COMBAT_SECTION_SEPARATION)
	_bottom.custom_minimum_size.y = UiStyle.COMBAT_BOTTOM_HEIGHT
	_vs_top.color = UiStyle.COMBAT_PLAYER_BORDER
	_vs_bottom.color = UiStyle.COMBAT_ENEMY_BORDER
	_vs_label.text = CombatTexts.VS_TEXT
	_loot_title.text = CombatTexts.LOOT_TITLE
	_yield_title.text = CombatTexts.YIELD_TITLE
	_eat_button.text = CombatTexts.EAT_TEXT
	_stop_button.text = CombatTexts.STOP_TEXT
	_fracture_link = CombatFracture.add_link(_stop_button.get_parent())
	_collect_button.text = CombatTexts.COLLECT_TEXT
	_skip_control = SkipStoneControl.new()
	_stop_button.get_parent().add_child(_skip_control)
	_skip_control.result_given.connect(_show_result)
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.visible = false
	_yield_values = CombatYield.build_grid(_yield_grid)
	_eat_button.pressed.connect(_on_eat_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_collect_button.pressed.connect(_on_collect_pressed)
	_log_button.pressed.connect(_on_log_pressed)
	_map_button.text = CombatTexts.MAP_BUTTON_TEXT
	_map_button.pressed.connect(_on_map_pressed)
	_map = CombatMap.new()
	_map.name = "CombatMap"
	add_child(_map)
	_map.area_chosen.connect(_on_area_chosen)
	set_process(false)


## Draws the combat of `session` and follows its signals.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	HelpButton.attach(_area_label.get_parent(), session.data, &"combat")
	if _kept_session == _session and _kept_yield != null:
		_yield = _kept_yield
		_log_open = _kept_log_open
	else:
		_yield = CombatYield.new(_session.play_time_ms)
		_log_open = false
	_kept_session = _session
	_kept_yield = _yield
	_feed = CombatFeed.new(_session, _yield, _zone, _player)
	_skip_control.bind(_session)
	var events: GameEvents = _session.events
	var resync: Callable = _redraw_all
	var static_resync: Callable = _refresh_static
	_connect(events.combat_started, _on_combat_started)
	_connect(events.combat_stopped, _on_combat_stopped)
	_connect(events.encounter_started, resync.unbind(1))
	_connect(events.encounter_cleared, resync)
	_connect(events.fracture_boss_started, resync.unbind(1))
	_connect(events.fracture_finished, resync.unbind(5))
	_connect(events.player_hp_changed, resync.unbind(2))
	_connect(events.monster_hp_changed, resync.unbind(3))
	_connect(events.monster_killed, _on_monster_killed)
	_connect(events.food_eaten, _on_food_eaten)
	_connect(events.food_changed, _on_food_changed)
	_connect(events.bank_changed, resync.unbind(3))
	_connect(events.loot_bag_changed, resync.unbind(2))
	_connect(events.equipment_changed, _on_equipment_changed)
	_connect(events.combat_hit, _on_combat_hit)
	_connect(events.player_died, _on_player_died)
	_connect(events.character_level_up, _on_character_level_up)
	_connect(events.traits_changed, static_resync)
	_connect(events.ability_used, _on_ability_used)
	_connect(events.trait_triggered, _on_trait_triggered)
	_connect(events.character_xp_gained, _on_xp_gained)
	_connect(events.gold_changed, _on_gold_changed)
	_connect(events.skip_stone_changed, _skip_control.refresh.unbind(1))
	_message_label.visible = false
	_refresh_static()
	_redraw_all()
	_process(0.0)
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
	if _player != null:
		_player.hide_tooltip()
	_session = null


func _exit_tree() -> void:
	unbind()


func _process(_delta: float) -> void:
	if _session != null:
		var state: Dictionary = _session.combat.get_state()
		_player.tick(state)
		_zone.refresh(_session, state)
		if CombatFracture.is_in(state):  # the ability timer and the shield move between events
			_state_label.text = CombatFracture.state_text(state["fracture"], _state_base, _session.data)
		_redraw_yield()
		if _feed.flush():  # compact view: the lines added up per type
			_refresh_log()


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


## Rereads the combat state and redraws header, food and loot (the cards follow every frame).
func _redraw_all() -> void:
	if _session == null:
		return
	var state: Dictionary = _session.combat.get_state()
	var running: bool = state["state"] != CombatEngine.STATE_IDLE
	var in_fracture: bool = CombatFracture.is_in(state)
	var area: AreaDef = _session.data.area(state["area"]) if running and state["area"] != &"" else null
	_area_label.text = area.name if area != null else CombatTexts.NO_AREA_TEXT
	var state_text: String = CombatTexts.STATE_TEXTS.get(state["state"], CombatTexts.STATE_TEXT_DEFAULT)
	var enemy_count: int = (state["enemies"] as Array).size()
	_state_base = CombatTexts.HEADER_ENEMIES_TEXT % [state_text, CombatTexts.group_size_text(enemy_count)] \
			if enemy_count > 0 else state_text
	_state_label.text = _state_base
	_map_button.visible = not in_fracture
	_fracture_link.visible = in_fracture
	if in_fracture:
		_area_label.text = CombatFracture.header_text(_session, state["fracture"])
		_state_label.text = CombatFracture.state_text(state["fracture"], _state_base, _session.data)
	_stop_button.disabled = not running
	_eat_button.disabled = not running
	_redraw_food()
	LootStrip.redraw(_session, _loot_list, _loot_count, _collect_button)
	_refresh_log()


## Rereads what changes only on level, loadout and equipment: area choice, player names, slots, gear.
func _refresh_static() -> void:
	if _session != null:
		_map.refresh(_session)
		_player.refresh_static(_session)


func _redraw_food() -> void:
	var food_id: StringName = _session.equipment.get_food()
	var def: ItemDef = _session.data.item(food_id) if food_id != &"" else null
	if def == null:
		_food_label.text = CombatTexts.NO_FOOD_TEXT
		return
	_food_label.text = CombatTexts.FOOD_TEXT % [def.name, NumberFormat.format_int(_session.bank.get_count(food_id))]


# --- Bottom row -----------------------------------------------------------------------------------------------

func _redraw_yield() -> void:
	var now: int = _session.play_time_ms
	_yield.redraw_values(_yield_values, now)
	_yield_window.text = CombatTexts.yield_window_text(_yield.window_ms(now))


## The summary line (closed) or the last lines of the log (open).
func _refresh_log() -> void:
	var meals: int = _session.combat.food_eaten()
	_log_button.text = CombatTexts.LOG_HIDE_TEXT if _log_open else CombatTexts.log_summary(
			_yield.hits, _yield.abilities, _yield.blocks, meals)
	_log_scroll.visible = _log_open
	_yield_grid.visible = not _log_open
	if _log_open:
		var lines: PackedStringArray = _yield.last_lines(UiStyle.COMBAT_LOG_LINES)
		_log_label.text = "\n".join(lines) if not lines.is_empty() else CombatTexts.LOG_EMPTY_TEXT


# --- Commands -------------------------------------------------------------------------------------------------
func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok or _food_warning
	if not result.ok:
		_message_label.text = CombatTexts.REASON_TEXTS.get(result.reason, CombatTexts.REASON_TEXT_DEFAULT)
	_redraw_all()


func _on_map_pressed() -> void:
	if _session != null:
		_map.open(_session)


## A click on an available area of the map: starts the fight there (a refusal is shown like any other).
func _on_area_chosen(area_id: StringName) -> void:
	_map.close()
	if _session != null and not (_session.combat.is_active() and _session.combat.area_id() == area_id):
		_show_result(_session.combat.start(area_id))


func _on_stop_pressed() -> void:
	if _session != null:
		_session.combat.stop()
		_food_warning = false
		_message_label.visible = false
		_redraw_all()


func _on_eat_pressed() -> void:
	if _session != null:
		_show_result(_session.combat.eat())


func _on_collect_pressed() -> void:
	if _session != null:
		_show_result(_session.combat.loot.collect_all())


func _on_log_pressed() -> void:
	_log_open = not _log_open
	_kept_log_open = _log_open
	if _session != null:
		_refresh_log()


# --- Signals --------------------------------------------------------------------------------------------------

## `attacker` / `target`: -1 = the player, 0..n-1 = position of the enemy (05_INTERFACES.md §3).
func _on_combat_hit(attacker: int, target: int, hit: bool, damage: int, blocked: bool) -> void:
	_feed.hit(attacker, target, hit, damage, blocked)
	_refresh_log()


func _on_monster_killed(index: int, _monster_id: StringName) -> void:
	_feed.kill(index)
	_redraw_all()


func _on_food_eaten(item_id: StringName, healed: int) -> void:
	var def: ItemDef = _session.data.item(item_id)
	_yield.add_log(CombatTexts.LOG_EAT_TEXT % [def.name if def != null else String(item_id), NumberFormat.format_int(healed)])
	_redraw_all()


func _on_xp_gained(amount: int) -> void:
	_yield.record(CombatYield.XP, amount, _session.play_time_ms)
	_player.refresh_xp(_session)


func _on_gold_changed(_new_amount: int, delta: int) -> void:
	if _session.combat.is_active():
		_yield.record(CombatYield.GOLD, delta, _session.play_time_ms)


func _on_equipment_changed(_slot: StringName, _uid: int) -> void:
	_refresh_static()
	_redraw_all()


func _on_player_died() -> void:
	_food_warning = false
	_message_label.text = CombatTexts.DEFEAT_TEXT
	_message_label.visible = true


func _on_character_level_up(_new_level: int) -> void:
	_refresh_static()


# A new start (from this page or elsewhere) clears the defeat or refusal message of the previous run.
func _on_combat_started(_area_id: StringName) -> void:
	_message_label.visible = false
	_food_warning = _has_no_food()
	if _food_warning:
		_message_label.text = CombatTexts.NO_FOOD_WARNING
		_message_label.visible = true
	_redraw_all()


## B2: the warning goes away at the first food chosen (it does not block the start).
func _on_food_changed(_item_id: StringName) -> void:
	if _food_warning and not _has_no_food():
		_food_warning = false
		_message_label.visible = false
	_redraw_all()


func _has_no_food() -> bool:
	var food_id: StringName = _session.equipment.get_food()
	return food_id == &"" or _session.bank.get_count(food_id) <= 0


# The numbers and animations go away with the combat (a number used to stay on screen after the defeat).
func _on_combat_stopped(_reason: StringName) -> void:
	if _food_warning:
		_food_warning = false
		_message_label.visible = false
	_player.clear_effects()
	_zone.clear_effects()
	_redraw_all()


# Feedback of the loadout: a line in the log and a flash on the card or chip (05 §3 `ability_used`, `trait_triggered`).
func _on_ability_used(ability_id: StringName, _targets: Array) -> void:
	_yield.abilities += 1
	_yield.add_log(CombatTexts.LOG_ABILITY_TEXT % _player.entry_name(ability_id))
	_player.flash_entry(ability_id)
	_refresh_log()


func _on_trait_triggered(trait_id: StringName) -> void:
	_yield.add_log(CombatTexts.LOG_TRAIT_TEXT % _player.entry_name(trait_id))
	_player.flash_entry(trait_id)
	_refresh_log()
