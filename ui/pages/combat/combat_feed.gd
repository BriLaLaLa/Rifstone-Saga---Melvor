class_name CombatFeed
extends RefCounted
## Feedback of the combat events on the combat page: floating numbers on the enemy zone and on the player column, the
## counters and the lines of the log (`CombatYield`). Extracted from `CombatPage`. In the compact view (docs/METIN.md Z6)
## the hit and kill lines are added up per monster type and written once per `flush` (one line per type per frame).
## Reads the session, keeps no game state: the sums waiting for the flush are presentation.

var _session: GameSession = null
var _yield: CombatYield = null
var _zone: EnemyZone = null
var _player: PlayerColumn = null
## name -> [hits, damage] taken by the player / dealt to the player; name -> kills; waiting for `flush`.
var _dealt: Dictionary[String, Array] = {}
var _taken: Dictionary[String, Array] = {}
var _kills: Dictionary[String, int] = {}


func _init(session: GameSession, yield_log: CombatYield, zone: EnemyZone, player: PlayerColumn) -> void:
	_session = session
	_yield = yield_log
	_zone = zone
	_player = player


## `attacker` / `target`: -1 = the player, 0..n-1 = position of the enemy (05_INTERFACES.md §3).
func hit(attacker: int, target: int, hit_done: bool, damage: int, blocked: bool) -> void:
	var state: Dictionary = _session.combat.get_state()
	if attacker == CombatEngine.PLAYER:
		var strong: bool = hit_done and damage >= CombatTexts.strong_hit_threshold(_session.combat.player_stats().max_hit)
		var text: String = CombatTexts.HIT_TEXT % NumberFormat.format_int(damage) if hit_done else CombatTexts.MISS_TEXT
		_zone.show_hit(target, text, UiStyle.GOLD_LIGHT if strong else UiStyle.TEXT, strong, hit_done, damage if hit_done else 0)
		_log_hit(CombatTexts.LOG_PLAYER_HIT_TEXT, CombatTexts.LOG_PLAYER_MISS_TEXT, _dealt, state, target, hit_done, damage)
		if hit_done:
			_yield.hits += 1
			_yield.record(CombatYield.DAMAGE, damage, _session.play_time_ms)
	elif target == CombatEngine.PLAYER:
		_zone.play_attack(attacker)
		var text: String = CombatTexts.BLOCKED_TEXT if blocked else (
				CombatTexts.HIT_TEXT % NumberFormat.format_int(damage) if hit_done else CombatTexts.MISS_TEXT)
		_player.show_hit(text, UiStyle.TEXT_2 if blocked else UiStyle.BAD, false, hit_done and not blocked)
		if blocked:
			_yield.blocks += 1
			_yield.add_log(CombatTexts.LOG_BLOCK_TEXT % enemy_name(state, attacker))
		else:
			_log_hit(CombatTexts.LOG_ENEMY_HIT_TEXT, CombatTexts.LOG_ENEMY_MISS_TEXT, _taken, state, attacker, hit_done, damage)


func kill(index: int) -> void:
	_zone.play_death(index)
	_yield.record(CombatYield.KILLS, 1, _session.play_time_ms)
	var who: String = enemy_name(_session.combat.get_state(), index)
	if _zone.is_compact():
		_kills[who] = _kills.get(who, 0) + 1
	else:
		_yield.add_log(CombatTexts.LOG_KILL_TEXT % who)


## Writes the lines added up since the last call; true if there was any.
func flush() -> bool:
	var wrote: bool = false
	for who: String in _dealt:
		_yield.add_log(CrowdTexts.LOG_PLAYER_TEXT % [CrowdTexts.group_text(who, _dealt[who][0]), NumberFormat.format_int(_dealt[who][1])])
		wrote = true
	for who: String in _taken:
		_yield.add_log(CrowdTexts.LOG_ENEMY_TEXT % [CrowdTexts.group_text(who, _taken[who][0]), NumberFormat.format_int(_taken[who][1])])
		wrote = true
	for who: String in _kills:
		_yield.add_log(CrowdTexts.LOG_KILL_TEXT % CrowdTexts.group_text(who, _kills[who]))
		wrote = true
	_dealt.clear()
	_taken.clear()
	_kills.clear()
	return wrote


func enemy_name(state: Dictionary, index: int) -> String:
	var enemies: Array = state["enemies"]
	if index < 0 or index >= enemies.size():
		return ""
	return EnemyView.name_of(_session.data, enemies[index]["monster"])


## One line per event, or (compact view) added up in `sums` for `flush`; misses are not logged when compact.
func _log_hit(hit_line: String, miss_line: String, sums: Dictionary, state: Dictionary, index: int, hit_done: bool,
		damage: int) -> void:
	var who: String = enemy_name(state, index)
	if not _zone.is_compact():
		_yield.add_log(hit_line % [who, NumberFormat.format_int(damage)] if hit_done else miss_line % who)
	elif hit_done:
		var sum: Array = sums.get(who, [0, 0])
		sums[who] = [int(sum[0]) + 1, int(sum[1]) + damage]
