class_name CombatPage
extends Page
## Combat page, GDR layout (docs/UI_GDR.md §2, docs/mockups/combat.dc.html), route `combat`: header with the area
## choice, food, Eat and Stop; the player column (gold frame) against the enemy zone (red frame); the bottom row with the
## loot bag, the yield and the log.
##
## Everything is read from `session.combat.get_state()`, `session.character`, `session.equipment`, `session.loadout`,
## `session.armory`, `session.bank` and `session.data`: on the combat signals and every frame (`_process`, bars only
## move). Player actions are commands (`combat.start`, `combat.stop`, `combat.eat`, `combat.loot.collect_all`); a
## refused command shows its reason. It keeps no game state: the session reference, its nodes and the connections.
## The yield and the log (`CombatYield`) are derived readings of the events, never saved.

const ITEM_SLOT_SCENE: PackedScene = preload("res://ui/components/item_slot/item_slot.tscn")

var _session: GameSession = null
## Signal, callable pairs connected in `bind` (disconnected in `unbind`).
var _connections: Array[Array] = []
var _yield: CombatYield = null
var _area_ids: Array[StringName] = []
var _yield_values: Dictionary[StringName, Label] = {}
var _log_open: bool = false

@onready var _margin: MarginContainer = %Margin
@onready var _main: VBoxContainer = %Main
@onready var _area_label: Label = %AreaLabel
@onready var _state_label: Label = %StateLabel
@onready var _area_choice_label: Label = %AreaChoiceLabel
@onready var _area_option: OptionButton = %AreaOption
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
	_area_choice_label.text = CombatTexts.AREA_LABEL_TEXT
	_loot_title.text = CombatTexts.LOOT_TITLE
	_yield_title.text = CombatTexts.YIELD_TITLE
	_eat_button.text = CombatTexts.EAT_TEXT
	_stop_button.text = CombatTexts.STOP_TEXT
	_collect_button.text = CombatTexts.COLLECT_TEXT
	_message_label.add_theme_color_override("font_color", UiStyle.BAD)
	_message_label.visible = false
	_build_yield_grid()
	_eat_button.pressed.connect(_on_eat_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_collect_button.pressed.connect(_on_collect_pressed)
	_log_button.pressed.connect(_on_log_pressed)
	_area_option.item_selected.connect(_on_area_selected)
	set_process(false)


## Draws the combat of `session` and follows its signals.
func bind(session: GameSession) -> void:
	unbind()
	_session = session
	_yield = CombatYield.new(_session.play_time_ms)
	var events: GameEvents = _session.events
	var resync: Callable = _redraw_all
	var static_resync: Callable = _refresh_static
	_connect(events.combat_started, _on_combat_started)
	_connect(events.combat_stopped, _on_combat_stopped)
	_connect(events.encounter_started, resync.unbind(1))
	_connect(events.encounter_cleared, resync)
	_connect(events.player_hp_changed, resync.unbind(2))
	_connect(events.monster_hp_changed, resync.unbind(3))
	_connect(events.monster_killed, _on_monster_killed)
	_connect(events.food_eaten, _on_food_eaten)
	_connect(events.food_changed, resync.unbind(1))
	_connect(events.bank_changed, resync.unbind(3))
	_connect(events.loot_bag_changed, resync.unbind(2))
	_connect(events.equipment_changed, _on_equipment_changed)
	_connect(events.combat_hit, _on_combat_hit)
	_connect(events.player_died, _on_player_died)
	_connect(events.character_level_up, _on_character_level_up)
	_connect(events.traits_changed, static_resync)
	_connect(events.character_xp_gained, _on_xp_gained)
	_connect(events.gold_changed, _on_gold_changed)
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
		_redraw_yield()


func _connect(source: Signal, callable: Callable) -> void:
	source.connect(callable)
	_connections.append([source, callable])


# --- Header ---------------------------------------------------------------------------------------------------

## One entry per area of the data; the requirements are rechecked on level up.
func _refresh_area_option() -> void:
	_area_option.clear()
	_area_ids.clear()
	for area: AreaDef in _session.data.areas():
		var unlocked: bool = _session.character.meets_requirements(area.requirements)
		var text: String = area.name
		if not unlocked:
			text = CombatTexts.AREA_REQUIREMENT_TEXT % [area.name,
					ItemTooltipLines.CHARACTER_REQUIREMENT_TEXT % area.requirements.get(&"character", 1)]
		_area_option.add_item(text)
		var index: int = _area_option.item_count - 1
		_area_option.set_item_disabled(index, not unlocked)
		_area_option.set_item_tooltip(index, area.description)
		_area_ids.append(area.id)
	_sync_area_choice()


## Shows the running area in the choice (the placeholder when idle); no item is rebuilt.
func _sync_area_choice() -> void:
	var current: StringName = _session.combat.area_id() if _session.combat.is_active() else &""
	_area_option.select(_area_ids.find(current))
	if current == &"":
		_area_option.text = CombatTexts.NO_AREA_TEXT


## Rereads the combat state and redraws header, food and loot (the cards follow every frame).
func _redraw_all() -> void:
	if _session == null:
		return
	var state: Dictionary = _session.combat.get_state()
	var running: bool = state["state"] != CombatEngine.STATE_IDLE
	var area: AreaDef = _session.data.area(state["area"]) if running else null
	_area_label.text = area.name if area != null else CombatTexts.NO_AREA_TEXT
	var state_text: String = CombatTexts.STATE_TEXTS.get(state["state"], CombatTexts.STATE_TEXT_DEFAULT)
	var enemy_count: int = (state["enemies"] as Array).size()
	_state_label.text = CombatTexts.HEADER_ENEMIES_TEXT % [state_text, CombatTexts.group_size_text(enemy_count)] \
			if enemy_count > 0 else state_text
	_stop_button.disabled = not running
	_eat_button.disabled = not running
	_redraw_food()
	_redraw_loot()
	_refresh_log()
	_sync_area_choice()


## Rereads what changes only on level, loadout and equipment: area choice, player names, slots, gear.
func _refresh_static() -> void:
	if _session != null:
		_refresh_area_option()
		_player.refresh_static(_session)


func _redraw_food() -> void:
	var food_id: StringName = _session.equipment.get_food()
	var def: ItemDef = _session.data.item(food_id) if food_id != &"" else null
	if def == null:
		_food_label.text = CombatTexts.NO_FOOD_TEXT
		return
	_food_label.text = CombatTexts.FOOD_TEXT % [def.name, NumberFormat.format_int(_session.bank.get_count(food_id))]


# --- Bottom row -----------------------------------------------------------------------------------------------

## The last icons of the bag with the color of the rarity, "Borsa N / M" and "Raccogli tutto".
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
	var first: int = maxi(0, items.size() - UiStyle.COMBAT_LOOT_MAX_ICONS)
	for i: int in range(first, items.size()):
		var def: ItemDef = _session.data.item(items[i]["item"])
		if def == null:
			continue
		var cell: ItemSlotView = ITEM_SLOT_SCENE.instantiate() as ItemSlotView
		cell.custom_minimum_size = Vector2(UiStyle.COMBAT_LOOT_ICON_SIDE, UiStyle.COMBAT_LOOT_ICON_SIDE)
		cell.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.rarity_color(&"common"),
				UiStyle.COMBAT_FRAME_WIDTH, 2.0))
		_loot_list.add_child(cell)
		cell.set_item(def, int(items[i]["qty"]))
	if first > 0:
		var more := Label.new()
		more.text = CombatTexts.LOOT_MORE_TEXT % first
		more.theme_type_variation = &"MutedLabel"
		_loot_list.add_child(more)


func _build_yield_grid() -> void:
	for kind: StringName in CombatTexts.YIELD_LABELS:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.add_theme_font_override("font", UiStyle.font_bold())
		value.add_theme_font_size_override("font_size", UiStyle.COMBAT_YIELD_FONT_SIZE)
		box.add_child(value)
		var caption := Label.new()
		caption.text = CombatTexts.YIELD_LABELS[kind]
		caption.theme_type_variation = &"MutedLabel"
		box.add_child(caption)
		_yield_grid.add_child(box)
		_yield_values[kind] = value


func _redraw_yield() -> void:
	var now: int = _session.play_time_ms
	_yield_values[CombatYield.KILLS].text = NumberFormat.format_int(_yield.per_hour(CombatYield.KILLS, now))
	_yield_values[CombatYield.XP].text = NumberFormat.format_int(_yield.per_hour(CombatYield.XP, now))
	_yield_values[CombatYield.GOLD].text = NumberFormat.format_int(_yield.per_hour(CombatYield.GOLD, now))
	_yield_values[CombatYield.DAMAGE].text = NumberFormat.format_int(_yield.per_second(CombatYield.DAMAGE, now))
	_yield_window.text = CombatTexts.yield_window_text(_yield.window_ms(now))


## The summary line (closed) or the last lines of the log (open).
func _refresh_log() -> void:
	var meals: int = _session.combat.food_eaten()
	_log_button.text = CombatTexts.LOG_HIDE_TEXT if _log_open else CombatTexts.LOG_SUMMARY_TEXT % [
			NumberFormat.format_int(_yield.hits), NumberFormat.format_int(_yield.blocks), NumberFormat.format_int(meals)]
	_log_scroll.visible = _log_open
	_yield_grid.visible = not _log_open
	if _log_open:
		var lines: PackedStringArray = _yield.last_lines(UiStyle.COMBAT_LOG_LINES)
		_log_label.text = "\n".join(lines) if not lines.is_empty() else CombatTexts.LOG_EMPTY_TEXT


# --- Commands -------------------------------------------------------------------------------------------------
func _show_result(result: CommandResult) -> void:
	_message_label.visible = not result.ok
	if not result.ok:
		_message_label.text = CombatTexts.REASON_TEXTS.get(result.reason, CombatTexts.REASON_TEXT_DEFAULT)
	_redraw_all()


func _on_area_selected(index: int) -> void:
		_show_result(_session.combat.start(_area_ids[index]))
		_refresh_area_option()


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


func _on_log_pressed() -> void:
	_log_open = not _log_open
	if _session != null:
		_refresh_log()


# --- Signals --------------------------------------------------------------------------------------------------

## `attacker` / `target`: -1 = the player, 0..n-1 = position of the enemy (05_INTERFACES.md §3).
func _on_combat_hit(attacker: int, target: int, hit: bool, damage: int, blocked: bool) -> void:
	var state: Dictionary = _session.combat.get_state()
	if attacker == CombatEngine.PLAYER:
		var strong: bool = hit and damage >= CombatTexts.strong_hit_threshold(_session.combat.player_stats().max_hit)
		var text: String = CombatTexts.HIT_TEXT % NumberFormat.format_int(damage) if hit else CombatTexts.MISS_TEXT
		_zone.show_hit(target, text, UiStyle.GOLD_LIGHT if strong else UiStyle.TEXT, strong, hit)
		_log_hit(CombatTexts.LOG_PLAYER_HIT_TEXT, CombatTexts.LOG_PLAYER_MISS_TEXT, _enemy_name(state, target), hit, damage)
		if hit:
			_yield.hits += 1
			_yield.record(CombatYield.DAMAGE, damage, _session.play_time_ms)
	elif target == CombatEngine.PLAYER:
		_zone.play_attack(attacker)
		var text: String = CombatTexts.BLOCKED_TEXT if blocked else (
				CombatTexts.HIT_TEXT % NumberFormat.format_int(damage) if hit else CombatTexts.MISS_TEXT)
		_player.show_hit(text, UiStyle.TEXT_2 if blocked else UiStyle.BAD, false, hit and not blocked)
		var who: String = _enemy_name(state, attacker)
		if blocked:
			_yield.blocks += 1
			_yield.add_log(CombatTexts.LOG_BLOCK_TEXT % who)
		else:
			_log_hit(CombatTexts.LOG_ENEMY_HIT_TEXT, CombatTexts.LOG_ENEMY_MISS_TEXT, who, hit, damage)
	_refresh_log()


func _log_hit(hit_line: String, miss_line: String, who: String, hit: bool, damage: int) -> void:
	_yield.add_log(hit_line % [who, NumberFormat.format_int(damage)] if hit else miss_line % who)


func _on_monster_killed(index: int, _monster_id: StringName) -> void:
	_zone.play_death(index)
	_yield.record(CombatYield.KILLS, 1, _session.play_time_ms)
	_yield.add_log(CombatTexts.LOG_KILL_TEXT % _enemy_name(_session.combat.get_state(), index))
	_redraw_all()


func _on_food_eaten(item_id: StringName, healed: int) -> void:
	var def: ItemDef = _session.data.item(item_id)
	_yield.add_log(CombatTexts.LOG_EAT_TEXT % [def.name if def != null else String(item_id), NumberFormat.format_int(healed)])
	_redraw_all()


func _on_xp_gained(amount: int) -> void:
	_yield.record(CombatYield.XP, amount, _session.play_time_ms)


func _on_gold_changed(_new_amount: int, delta: int) -> void:
	if _session.combat.is_active():
		_yield.record(CombatYield.GOLD, delta, _session.play_time_ms)


func _on_equipment_changed(_slot: StringName, _uid: int) -> void:
	_refresh_static()
	_redraw_all()


func _on_player_died() -> void:
	_message_label.text = CombatTexts.DEFEAT_TEXT
	_message_label.visible = true


func _on_character_level_up(_new_level: int) -> void:
	_refresh_static()


# A new start (from this page or elsewhere) clears the defeat or refusal message of the previous run.
func _on_combat_started(_area_id: StringName) -> void:
	_message_label.visible = false
	_redraw_all()


# The numbers and animations go away with the combat (a number used to stay on screen after the defeat).
func _on_combat_stopped(_reason: StringName) -> void:
	_player.clear_effects()
	_zone.clear_effects()
	_redraw_all()


func _enemy_name(state: Dictionary, index: int) -> String:
	var enemies: Array = state["enemies"]
	if index < 0 or index >= enemies.size():
		return ""
	var def: MonsterDef = _session.data.monster(enemies[index]["monster"])
	return def.name if def != null else String(enemies[index]["monster"])
