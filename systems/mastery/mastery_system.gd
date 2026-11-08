class_name MasterySystem
extends RefCounted
## Per-action mastery and the mastery pool of every skill with mastery (docs/01_GDD.md §6.1-6.2).
##
## State: mastery xp of each tracked action (`mastery: true` actions of `has_mastery` skills) and the pool of each
## `has_mastery` skill. Levels derive from the F-09 table; xp stops at the max-level total. A cycle gives F-10 mxp and
## F-12 pool share up to the F-13 cap; the pool can be spent on an action (F-14). Per-action bonuses (F-11) are the
## `mastery_item:<action_id>` modifier sources, rebuilt from the levels and refreshed on every mastery level up.
## Mastery nodes (docs/01_GDD.md §6.3) cost F-15 of the pool cap, need their prerequisites and are permanent once
## bought; each owned node is the `mastery_node:<node_id>` source with the node's modifiers.
## Signals go to the session EventBus after the state changed; `new_game`/`from_save` emit nothing.
## Dependencies: data, events, modifiers.

const SAVE_KEY: StringName = &"mastery"
const LOG_CATEGORY: String = "mastery"
const SHARE_PCT_KEY: String = "mastery.pool_share_pct"
const CAP_PER_ITEM_KEY: String = "mastery.pool_cap_per_item"
const XP_PCT_STAT: StringName = &"mastery_xp_pct"
const ITEM_SOURCE_PREFIX: String = "mastery_item:"
const NODE_SOURCE_PREFIX: String = "mastery_node:"
const SAVE_POOL_KEY: String = "pool"
const SAVE_ACTIONS_KEY: String = "actions"
const SAVE_NODES_KEY: String = "nodes"

var _data: GameData
var _events: GameEvents
var _modifiers: ModifierService
var _table: XpTable
var _max_xp: int = 0
var _share_pct: float = 0.0
# Tracked actions: action id -> skill id; skill id -> its tracked action ids (data order).
var _skill_of: Dictionary[StringName, StringName] = {}
var _actions_of: Dictionary[StringName, Array] = {}
# skill id -> pool cap (F-13); one entry per has_mastery skill.
var _caps: Dictionary[StringName, int] = {}
# State: action id -> mastery xp; skill id -> pool xp.
var _xp: Dictionary[StringName, int] = {}
var _pool: Dictionary[StringName, int] = {}
# Nodes of the has_mastery skills: node id -> def; skill id -> its node ids (data order).
var _node_defs: Dictionary[StringName, MasteryNodeDef] = {}
var _nodes_of: Dictionary[StringName, Array] = {}
# State: owned node ids (permanent).
var _owned: Dictionary[StringName, bool] = {}


func _init(session: GameSession) -> void:
	assert(session != null, "MasterySystem needs a session")
	_data = session.data
	_events = session.events
	_modifiers = session.modifiers
	_table = _data.mastery_table()
	_max_xp = _table.xp_for_level(_table.max_level)
	_share_pct = float(_data.balance_value(SHARE_PCT_KEY))
	var per_item: int = int(_data.balance_value(CAP_PER_ITEM_KEY))
	for skill: SkillDef in _data.skills():
		if not skill.has_mastery:
			continue
		var ids: Array[StringName] = []
		for action: ActionDef in _data.mastery_actions_for_skill(skill.id):
			ids.append(action.id)
			_skill_of[action.id] = skill.id
		_actions_of[skill.id] = ids
		_caps[skill.id] = MasteryMath.pool_cap(ids.size(), per_item)
		var node_ids: Array[StringName] = []
		for node: MasteryNodeDef in _data.mastery_nodes(skill.id):
			node_ids.append(node.id)
			_node_defs[node.id] = node
		_nodes_of[skill.id] = node_ids
	_reset()


## Every tracked action at 0 mastery xp, every pool empty, no node owned.
func new_game() -> void:
	_reset()


## {skill_id: {"pool": int, "actions": {action_id: xp}, "nodes": []}} for every skill with mastery (§6).
## `nodes` lists the owned node ids of the skill in data order.
func to_save() -> Dictionary:
	var d: Dictionary = {}
	for skill_id: StringName in _actions_of:
		var actions: Dictionary = {}
		for action_id: StringName in _actions_of[skill_id]:
			actions[String(action_id)] = _xp[action_id]
		var nodes: Array = []
		for node_id: StringName in _nodes_of[skill_id]:
			if _owned.has(node_id):
				nodes.append(String(node_id))
		d[String(skill_id)] = {SAVE_POOL_KEY: _pool[skill_id], SAVE_ACTIONS_KEY: actions, SAVE_NODES_KEY: nodes}
	return d


## Missing entries start at 0. Unknown skills or actions and malformed values are reported and dropped;
## xp is limited to 0..max-level total and the pool to 0..cap. Unknown node ids, nodes of another skill and
## non-id entries of `nodes` are reported and dropped.
func from_save(d: Dictionary) -> void:
	_reset()
	for key: Variant in d:
		var skill_id: StringName = StringName(str(key))
		if not _actions_of.has(skill_id):
			Log.warn(LOG_CATEGORY, "unknown mastery skill '%s' in save ignored" % skill_id)
			continue
		if not d[key] is Dictionary:
			Log.warn(LOG_CATEGORY, "invalid mastery entry for skill '%s': starts empty" % skill_id)
			continue
		_load_skill(skill_id, d[key])


func get_mastery_xp(action_id: StringName) -> int:
	return _xp.get(action_id, 0)


## Level from the F-09 table; 0 for an action without mastery (or unknown).
func get_mastery_level(action_id: StringName) -> int:
	if not _xp.has(action_id):
		return 0
	return _table.level_for_xp(_xp[action_id])


## R of F-10: sum of the mastery levels of the skill's mastery actions / (max level × their number).
## 0.0 for a skill without mastery or without mastery actions.
func get_skill_ratio(skill_id: StringName) -> float:
	var ids: Array = _actions_of.get(skill_id, [])
	if ids.is_empty():
		return 0.0
	var levels: int = 0
	for action_id: StringName in ids:
		levels += _table.level_for_xp(_xp[action_id])
	return float(levels) / float(_table.max_level * ids.size())


## Pool xp of the skill; 0 for a skill without mastery.
func get_pool(skill_id: StringName) -> int:
	return _pool.get(skill_id, 0)


## F-13 cap of the skill's pool; 0 for a skill without mastery.
func get_pool_cap(skill_id: StringName) -> int:
	return _caps.get(skill_id, 0)


## One completed cycle of `action`: F-10 mastery xp (capped at the max level), F-12 share to the pool (capped at
## F-13). With `share_pct` < 100 (helper, M12 F-102) the mxp is round(F-10 × share_pct / 100) and F-12 applies to it. Returns the mxp, or 0 for an action without mastery (nothing changes). Emits mastery_xp_gained,
## one mastery_level_up per level (after the action's bonus source is updated) and mastery_pool_changed.
func add_for_action(action: ActionDef, share_pct: float = 100.0) -> int:
	if action == null:
		Log.error(LOG_CATEGORY, "add_for_action without an action")
		return 0
	if not _xp.has(action.id):
		return 0
	var skill_id: StringName = _skill_of[action.id]
	var ctx: ModifierContext = ModifierContext.for_action(skill_id, action.id)
	var mxp: int = MasteryMath.mastery_xp(action.interval_ms, get_mastery_level(action.id),
			get_skill_ratio(skill_id), _modifiers.total(XP_PCT_STAT, ctx), _data)
	if share_pct != 100.0:
		mxp = MasteryMath.helper_share(mxp, share_pct)
	_grant(skill_id, action.id, mxp)
	_change_pool(skill_id, mini(_pool[skill_id] + MasteryMath.pool_gain(mxp, _share_pct), _caps[skill_id]))
	return mxp


## F-14: spends min(amount, pool, needed) of the skill's pool as mastery xp of the action, where needed is what
## is missing to the max level. unknown_id (no mastery), invalid_amount (≤ 0), mastery_max, pool_insufficient.
func spend_pool_on_action(action_id: StringName, amount: int) -> CommandResult:
	if not _xp.has(action_id):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if amount <= 0:
		return CommandResult.fail(Reasons.INVALID_AMOUNT)
	var needed: int = _max_xp - _xp[action_id]
	if needed <= 0:
		return CommandResult.fail(Reasons.MASTERY_MAX)
	var skill_id: StringName = _skill_of[action_id]
	if _pool[skill_id] <= 0:
		return CommandResult.fail(Reasons.POOL_INSUFFICIENT)
	var spent: int = mini(amount, mini(_pool[skill_id], needed))
	_grant(skill_id, action_id, spent)
	_change_pool(skill_id, _pool[skill_id] - spent)
	return CommandResult.success()


## F-15: ceil(pool cap of the node's skill × cost_pct / 100); 0 for an unknown node.
func node_cost(node_id: StringName) -> int:
	var node: MasteryNodeDef = _node_defs.get(node_id)
	if node == null:
		return 0
	return MasteryMath.node_cost(_caps[node.skill_id], node.cost_pct)


func owns_node(node_id: StringName) -> bool:
	return _owned.has(node_id)


## Checks in order: unknown_id (not a node of a skill with mastery), node_owned, node_prereq_missing (a required
## node is not owned), pool_insufficient (pool below node_cost). Changes nothing.
func can_buy_node(node_id: StringName) -> CommandResult:
	var node: MasteryNodeDef = _node_defs.get(node_id)
	if node == null:
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _owned.has(node_id):
		return CommandResult.fail(Reasons.NODE_OWNED)
	for required: StringName in node.requires:
		if not _owned.has(required):
			return CommandResult.fail(Reasons.NODE_PREREQ_MISSING)
	if _pool[node.skill_id] < node_cost(node_id):
		return CommandResult.fail(Reasons.POOL_INSUFFICIENT)
	return CommandResult.success()


## Buys a node: its F-15 cost leaves the pool and the node stays owned for good. Effects in order: state →
## `mastery_node:<node_id>` source (one modifiers_changed) → mastery_node_purchased → mastery_pool_changed (only if
## the pool changed). On error (see can_buy_node) nothing changes and nothing is emitted.
func buy_node(node_id: StringName) -> CommandResult:
	var check: CommandResult = can_buy_node(node_id)
	if not check.ok:
		return check
	var node: MasteryNodeDef = _node_defs[node_id]
	var new_pool: int = _pool[node.skill_id] - node_cost(node_id)
	_owned[node_id] = true
	_apply_node_bonus(node)
	_events.mastery_node_purchased.emit(node.skill_id, node_id)
	_change_pool(node.skill_id, new_pool)
	return CommandResult.success()


## Registers, in one batch, the `mastery_item:<action_id>` source of every tracked action from its level (F-11;
## actions without a bonus have no source) and the `mastery_node:<node_id>` source of every owned node.
## Called inside the GameSession.rebuild_modifiers batch.
func rebuild_modifiers() -> void:
	_modifiers.begin_batch()
	for action_id: StringName in _xp:
		_apply_item_bonus(action_id)
	for node_id: StringName in _node_defs:
		if _owned.has(node_id):
			_apply_node_bonus(_node_defs[node_id])
	_modifiers.end_batch()


func _reset() -> void:
	_xp.clear()
	_pool.clear()
	_owned.clear()
	for skill_id: StringName in _actions_of:
		_pool[skill_id] = 0
		for action_id: StringName in _actions_of[skill_id]:
			_xp[action_id] = 0


func _load_skill(skill_id: StringName, entry: Dictionary) -> void:
	if entry.has(SAVE_POOL_KEY):
		var pool: Variant = _read_int(entry[SAVE_POOL_KEY])
		if pool == null or pool < 0:
			Log.warn(LOG_CATEGORY, "invalid pool for skill '%s': starts at 0" % skill_id)
		elif pool > _caps[skill_id]:
			Log.warn(LOG_CATEGORY, "pool of skill '%s' above its cap: limited to %d" % [skill_id, _caps[skill_id]])
			_pool[skill_id] = _caps[skill_id]
		else:
			_pool[skill_id] = pool
	_load_nodes(skill_id, entry.get(SAVE_NODES_KEY, []))
	var actions: Variant = entry.get(SAVE_ACTIONS_KEY, {})
	if not actions is Dictionary:
		Log.warn(LOG_CATEGORY, "invalid actions for skill '%s': start at 0" % skill_id)
		return
	for key: Variant in actions:
		var action_id: StringName = StringName(str(key))
		if _skill_of.get(action_id, &"") != skill_id:
			Log.warn(LOG_CATEGORY, "unknown mastery action '%s' of skill '%s' ignored" % [action_id, skill_id])
			continue
		var xp: Variant = _read_int((actions as Dictionary)[key])
		if xp == null or xp < 0:
			Log.warn(LOG_CATEGORY, "invalid mastery xp for action '%s': starts at 0" % action_id)
			continue
		_xp[action_id] = mini(xp, _max_xp)


# Owned nodes of a save entry: only ids (strings) of the skill's own nodes are kept.
func _load_nodes(skill_id: StringName, nodes: Variant) -> void:
	if not nodes is Array:
		Log.warn(LOG_CATEGORY, "invalid nodes for skill '%s': none owned" % skill_id)
		return
	for entry: Variant in nodes:
		if not (entry is String or entry is StringName):
			Log.warn(LOG_CATEGORY, "invalid mastery node entry '%s' of skill '%s' ignored" % [entry, skill_id])
			continue
		var node_id: StringName = StringName(entry)
		var node: MasteryNodeDef = _node_defs.get(node_id)
		if node == null or node.skill_id != skill_id:
			Log.warn(LOG_CATEGORY, "unknown mastery node '%s' of skill '%s' ignored" % [node_id, skill_id])
			continue
		_owned[node_id] = true


# Adds mastery xp (capped at the max level), refreshes the action's bonus on a level up, then emits.
func _grant(skill_id: StringName, action_id: StringName, amount: int) -> void:
	var old_xp: int = _xp[action_id]
	var new_xp: int = mini(old_xp + maxi(amount, 0), _max_xp)
	if new_xp == old_xp:
		return
	var old_level: int = _table.level_for_xp(old_xp)
	_xp[action_id] = new_xp
	var new_level: int = _table.level_for_xp(new_xp)
	if new_level != old_level and _bonus_changes(skill_id, old_level, new_level):
		_modifiers.begin_batch()
		_apply_item_bonus(action_id)
		_modifiers.end_batch()
	_events.mastery_xp_gained.emit(skill_id, action_id, new_xp - old_xp)
	for level: int in range(old_level + 1, new_level + 1):
		_events.mastery_level_up.emit(skill_id, action_id, level)


func _change_pool(skill_id: StringName, new_pool: int) -> void:
	if new_pool == _pool[skill_id]:
		return
	_pool[skill_id] = new_pool
	_events.mastery_pool_changed.emit(skill_id, new_pool)


# True when some F-11 rule of the skill gives a different multiplier at the two levels.
func _bonus_changes(skill_id: StringName, old_level: int, new_level: int) -> bool:
	for rule: MasteryBonusRule in _data.skill(skill_id).mastery_bonuses:
		if MasteryMath.rule_multiplier(rule, old_level) != MasteryMath.rule_multiplier(rule, new_level):
			return true
	return false


# F-11: every rule's modifiers × its multiplier, with scope action:<id>; no modifiers → no source.
func _apply_item_bonus(action_id: StringName) -> void:
	var level: int = _table.level_for_xp(_xp[action_id])
	var mods: Array[Modifier] = []
	for rule: MasteryBonusRule in _data.skill(_skill_of[action_id]).mastery_bonuses:
		var times: int = MasteryMath.rule_multiplier(rule, level)
		if times <= 0:
			continue
		for mod: Modifier in rule.modifiers:
			mods.append(Modifier.make(mod.stat, mod.value * float(times), Modifier.SCOPE_ACTION, action_id))
	var source_id: StringName = StringName(ITEM_SOURCE_PREFIX + String(action_id))
	if mods.is_empty():
		_modifiers.clear_source(source_id)
	else:
		_modifiers.set_source(source_id, mods)


# The node's modifiers (scopes from the data) as source mastery_node:<id>; no modifiers → no source.
func _apply_node_bonus(node: MasteryNodeDef) -> void:
	var source_id: StringName = StringName(NODE_SOURCE_PREFIX + String(node.id))
	if node.modifiers.is_empty():
		_modifiers.clear_source(source_id)
	else:
		_modifiers.set_source(source_id, node.modifiers)


# int from an int or an integral float (JSON); null otherwise.
func _read_int(v: Variant) -> Variant:
	if v is int:
		return v
	if v is float:
		var f: float = v
		if f == floorf(f):
			return int(f)
	return null
