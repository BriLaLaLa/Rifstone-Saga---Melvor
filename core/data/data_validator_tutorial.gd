class_name DataValidatorTutorial
extends RefCounted
## Tutorial rules of DataValidator (internal, M30-02; docs/04_DATA_SCHEMA_M30.md §34): data/tutorial/steps.json and
## data/tutorial/starter_quests.json. The reachability of the real steps (start kit, trainers, areas) is checked by the data tests (M30-03).

const ROUTES: PackedStringArray = ["character", "equipment", "combat", "bank", "shop", "rift", "trainers", "skill", "village", "noticeboard",
	"auction", "mail", "fractures", "dungeon", "guide", "help", "starter"]
## Closed list of targets other than `page.<route>` (§34.4): id -> the page that shows it.
const TARGETS: Dictionary[String, String] = {"equipment.inventory": "equipment", "combat.map_button": "combat", "combat.enemy_zone": "combat",
	"combat.eat_button": "combat", "trainers.learn.forestry": "trainers", "skill.header": "skill", "mail.list": "mail"}
const DENIED_SIGNALS: PackedStringArray = ["combat_hit", "monster_hp_changed", "player_hp_changed", "node_attempt_done", "modifiers_changed",
	"xp_gained", "bank_changed", "gold_changed", "deposit_changed", "offline_started", "offline_progress", "offline_completed", "save_completed",
	"save_failed", "notification_requested", "session_started", "session_ended", "hint_triggered"]
const DENIED_PREFIXES: PackedStringArray = ["tutorial_", "starter_"]
const FORBIDDEN_REWARD_CATEGORIES: PackedStringArray = ["equipment", "weapon", "armor", "offhand", "tool", "bag", "map"]
const STEP_FIELDS: PackedStringArray = ["id", "page", "target", "title", "text", "done_when", "on_enter", "progress_text", "ack_text", "freeze_combat",
	"force_node", "wound_hp_pct"]
const QUEST_FIELDS: PackedStringArray = ["id", "group", "name", "description", "goal", "reward"]
const EVENT_FIELDS: PackedStringArray = ["type", "signal", "args", "count"]
const METRIC_FIELDS: PackedStringArray = ["type", "metric", "arg", "gte"]
const STUCK_MS_MIN: int = 10000
const TITLE_MAX: int = 40
const TEXT_MAX: int = 280
const GROUP_TITLE_MAX: int = 30
const QUEST_NAME_MAX: int = 40
const QUEST_DESCRIPTION_MAX: int = 140
const PROGRESS_TEXT_MAX: int = 40
const ACK_TEXT_MAX: int = 12
const XP_MAX: int = 1000
const MAIL_KIND: String = "tutorial_gift"
const CATEGORY_ARGS: PackedStringArray = ["gathering", "artisan"]


static func validate(v: DataValidatorRules, raw: Dictionary) -> void:
	var packs: Dictionary[String, bool] = _pack_monsters(raw.get("areas", {}) as Dictionary)
	var buildings: Dictionary[String, bool] = _ids(raw.get("village", {}) as Dictionary, "buildings")
	var files: Dictionary = raw.get("tutorial_steps", {}) as Dictionary
	for path: Variant in files:
		v.at_file(str(path))
		_validate_steps(v, files[path] as Dictionary, str(path), packs, buildings)
	files = raw.get("tutorial_quests", {}) as Dictionary
	for path: Variant in files:
		v.at_file(str(path))
		_validate_quests(v, files[path] as Dictionary, str(path), packs, buildings)


static func _validate_steps(v: DataValidatorRules, file: Dictionary, path: String, packs: Dictionary[String, bool],
		buildings: Dictionary[String, bool]) -> void:
	v.keys(file, ["stuck_ms", "always_open", "steps"])
	v.integer(file, "stuck_ms", STUCK_MS_MIN)
	for route: Variant in v.id_list(file, "always_open", null, "route", 0):
		if not ROUTES.has(str(route)):
			v.fail("field 'always_open': unknown route '%s'" % route)
	var seen: Dictionary[StringName, bool] = {}
	var list: Array[Dictionary] = v.object_list(file, "steps", "", 1)
	var gift_seen: bool = false
	var last_ack: bool = false
	for i: int in list.size():
		var e: Dictionary = list[i]
		v.entry("step", i, e, seen, STEP_FIELDS)
		var page: String = _route(v, e, "page")
		_target(v, e, page)
		_length(v, e, "title", TITLE_MAX)
		_length(v, e, "text", TEXT_MAX)
		if e.get("text") is String and ((e["text"] as String).contains("{") or (e["text"] as String).contains("}")):
			v.fail("field 'text' must not contain braces")
		var conditions: Array = _conditions(v, e.get("done_when"), "done_when", true, packs, buildings)
		_step_extras(v, e, conditions)
		gift_seen = _on_enter(v, e) or gift_seen
		last_ack = false
		for c: Variant in conditions:
			last_ack = last_ack or str((c as Dictionary).get("type")) == "ack"
			if str((c as Dictionary).get("metric")) == "mail_collected" and not gift_seen:
				v.fail("metric 'mail_collected' needs a gift (`on_enter`) in this step or before")
	v.at_file(path)
	if not list.is_empty() and not last_ack:
		v.fail("the last step must end with `ack`")


# `page` must be "" or a route without argument.
static func _route(v: DataValidatorRules, e: Dictionary, key: String) -> String:
	if not v.text(e, key):
		return ""
	var page: String = e[key] as String
	if not page.is_empty() and not ROUTES.has(page):
		v.fail("field '%s': unknown route '%s' (no argument allowed)" % [key, page])
	return page


static func _target(v: DataValidatorRules, e: Dictionary, page: String) -> void:
	if not v.text(e, "target") or (e["target"] as String).is_empty():
		return
	var target: String = e["target"] as String
	var owner: String = TARGETS.get(target, "")
	if target.begins_with("page."):
		owner = target.trim_prefix("page.")
		if not ROUTES.has(owner):
			v.fail("field 'target': unknown route in '%s'" % target)
			return
	elif owner.is_empty():
		v.fail("field 'target': unknown target '%s'" % target)
		return
	if owner != page:
		v.fail("field 'target' '%s' belongs to page '%s', not to '%s'" % [target, owner, page])


static func _length(v: DataValidatorRules, e: Dictionary, key: String, high: int) -> void:
	if v.text(e, key) and ((e[key] as String).is_empty() or (e[key] as String).length() > high):
		v.fail("field '%s' must have 1..%d characters, got %d" % [key, high, (e[key] as String).length()])


# Returns whether the step has a gift.
static func _on_enter(v: DataValidatorRules, e: Dictionary) -> bool:
	if not e.has("on_enter"):
		return false
	var on_enter: Dictionary = v.object(e, "on_enter")
	v.keys(on_enter, ["mail"], "on_enter")
	var mail: Dictionary = v.object(on_enter, "mail", "on_enter")
	v.keys(mail, ["kind", "money", "items"], "on_enter.mail")
	if v.text(mail, "kind", "on_enter.mail") and mail["kind"] != MAIL_KIND:
		v.fail("field 'on_enter.mail.kind' must be '%s'" % MAIL_KIND)
	if mail.has("money") == mail.has("items"):
		v.fail("field 'on_enter.mail' needs `money` or `items`, not both and not none")
	if mail.has("money"):
		v.integer(mail, "money", 1, DataValidatorRules.NO_LIMIT, "on_enter.mail")
	if mail.has("items"):
		v.item_qty_list(mail, "items", 1, "on_enter.mail")
	return not mail.is_empty()


# One condition or a non-empty list; returns the conditions that are objects.
static func _conditions(v: DataValidatorRules, raw: Variant, key: String, allow_ack: bool, packs: Dictionary[String, bool],
		buildings: Dictionary[String, bool]) -> Array:
	var list: Array = raw as Array if raw is Array else [raw]
	if raw == null or list.is_empty():
		v.fail("field '%s' needs at least one condition" % key)
		return []
	var result: Array = []
	for i: int in list.size():
		if not list[i] is Dictionary:
			v.fail("field '%s' must hold objects" % key)
			continue
		var c: Dictionary = list[i] as Dictionary
		var at: String = "%s[%d]" % [key, i]
		result.append(c)
		if not v.one_of(c, "type", ["ack", "event", "metric"] if allow_ack else ["event", "metric"], at):
			continue
		match c["type"]:
			"ack":
				v.keys(c, ["type"], at)
			"event":
				v.keys(c, EVENT_FIELDS, at)
				if c.has("count"):
					v.integer(c, "count", 1, DataValidatorRules.NO_LIMIT, at)
				_event(v, c, at, packs)
			"metric":
				v.keys(c, METRIC_FIELDS, at)
				v.integer(c, "gte", 0, DataValidatorRules.NO_LIMIT, at)
				_metric(v, c, at, buildings)
	return result


static func _event(v: DataValidatorRules, c: Dictionary, at: String, packs: Dictionary[String, bool]) -> void:
	if not v.text(c, "signal", at):
		return
	var name: StringName = StringName(c["signal"] as String)
	var signals: Dictionary = TutorialConditions.script_signals()
	var denied: bool = DENIED_SIGNALS.has(str(name))
	for prefix: String in DENIED_PREFIXES:
		denied = denied or str(name).begins_with(prefix)
	if not signals.has(name) or denied:
		v.fail("field '%s.signal': '%s' is not an allowed EventBus signal" % [at, name])
		return
	if not c.has("args"):
		return
	var args: Dictionary = v.object(c, "args", at)
	var types: Dictionary[String, int] = {}
	for a: Dictionary in (signals[name] as Array):
		types[str(a["name"])] = int(a["type"])
	for arg: Variant in args:
		var path: String = "%s.args.%s" % [at, arg]
		if not types.has(str(arg)):
			v.fail("field '%s': signal '%s' has no argument '%s'" % [at + ".args", name, arg])
			continue
		var rule: Variant = args[arg]
		if rule is Dictionary:
			if types[str(arg)] != TYPE_INT and types[str(arg)] != TYPE_FLOAT:
				v.fail("field '%s': a comparison needs a numeric argument" % path)
			v.keys(rule as Dictionary, TutorialConditions.COMPARES, path)
			for op: Variant in (rule as Dictionary):
				if not DataValidatorRules.is_number((rule as Dictionary)[op]):
					v.fail("field '%s.%s' must be a number" % [path, op])
			continue
		for value: Variant in (rule as Array if rule is Array else [rule]):
			_reference(v, str(arg), value, path, packs)


static func _reference(v: DataValidatorRules, arg: String, value: Variant, path: String, packs: Dictionary[String, bool]) -> void:
	if arg == "monster_id" and not packs.has(str(value)):
		v.fail("field '%s': monster '%s' does not exist or is in no area pack" % [path, value])
	elif arg == "skill_id" and not v.skills.has(StringName(str(value))):
		v.fail("field '%s': unknown skill '%s'" % [path, value])


static func _metric(v: DataValidatorRules, c: Dictionary, at: String, buildings: Dictionary[String, bool]) -> void:
	if not v.text(c, "metric", at):
		return
	var metric: StringName = StringName(c["metric"] as String)
	if not TutorialMetrics.METRICS.has(metric):
		v.fail("field '%s.metric': unknown metric '%s'" % [at, metric])
		return
	var arg: String = str(c.get("arg", ""))
	if c.has("arg"):
		v.text(c, "arg", at)
	match metric:
		&"page_visited":
			if not ROUTES.has(arg):
				v.fail("metric 'page_visited' needs `arg` = a route")
		&"disciplines_learned":
			if not arg.is_empty() and not CATEGORY_ARGS.has(arg):
				v.fail("metric 'disciplines_learned': `arg` must be one of %s" % [CATEGORY_ARGS])
		&"village_levels":
			if not arg.is_empty() and not buildings.has(arg):
				v.fail("metric 'village_levels': unknown building '%s'" % arg)
		_:
			if not arg.is_empty():
				v.fail("metric '%s' takes no `arg`" % metric)


static func _validate_quests(v: DataValidatorRules, file: Dictionary, path: String, packs: Dictionary[String, bool],
		buildings: Dictionary[String, bool]) -> void:
	v.keys(file, ["groups", "quests", "final_reward"])
	var groups: Dictionary[StringName, bool] = {}
	var used: Dictionary[String, bool] = {}
	var group_list: Array[Dictionary] = v.object_list(file, "groups", "", 1)
	for i: int in group_list.size():
		v.entry("group", i, group_list[i], groups, ["id", "title"])
		_length(v, group_list[i], "title", GROUP_TITLE_MAX)
	var seen: Dictionary[StringName, bool] = {}
	var list: Array[Dictionary] = v.object_list(file, "quests", "", 1)
	for i: int in list.size():
		var e: Dictionary = list[i]
		v.entry("starter quest", i, e, seen, QUEST_FIELDS)
		if v.ref(e, "group", groups, "group"):
			used[e["group"] as String] = true
		_length(v, e, "name", QUEST_NAME_MAX)
		_length(v, e, "description", QUEST_DESCRIPTION_MAX)
		_conditions(v, [e.get("goal")], "goal", false, packs, buildings)
		_reward(v, e)
	v.at_file(path)
	_final_reward(v, file)
	v.at_file(path)
	for group: StringName in groups:
		if not used.has(String(group)):
			v.fail("group '%s' has no quest" % group)


static func _reward(v: DataValidatorRules, e: Dictionary) -> void:
	var reward: Dictionary = v.object(e, "reward")
	v.keys(reward, ["money", "items", "character_xp"], "reward")
	if reward.has("money") and reward.has("items"):
		v.fail("field 'reward': `money` and `items` cannot be together (one Mail message holds one of them)")
	if not (reward.has("money") or reward.has("items") or reward.has("character_xp")):
		v.fail("field 'reward' is empty")
	if reward.has("money"):
		v.integer(reward, "money", 1, DataValidatorRules.NO_LIMIT, "reward")
	if reward.has("character_xp"):
		v.integer(reward, "character_xp", 1, XP_MAX, "reward")
	if not reward.has("items"):
		return
	v.item_qty_list(reward, "items", 1, "reward")
	for row: Variant in (reward["items"] as Array if reward["items"] is Array else []):
		var item: Dictionary = v.items.get(StringName(str((row as Dictionary).get("item", ""))), {}) if row is Dictionary else {}
		if item.is_empty():
			continue
		if int(item.get("value", 0)) < 1 or FORBIDDEN_REWARD_CATEGORIES.has(str(item.get("category"))):
			v.fail("field 'reward.items': '%s' is not sellable or is a forbidden category" % (row as Dictionary).get("item"))


static func _pack_monsters(areas: Dictionary) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for path: Variant in areas:
		for area: Variant in (areas[path] as Dictionary).get("areas", []) as Array:
			for pack: Variant in (area as Dictionary).get("packs", []) as Array:
				for monster: Variant in (pack as Dictionary).get("monsters", []) as Array:
					result[str(monster)] = true
	return result


static func _ids(files: Dictionary, key: String) -> Dictionary[String, bool]:
	var result: Dictionary[String, bool] = {}
	for path: Variant in files:
		for e: Variant in (files[path] as Dictionary).get(key, []) as Array:
			if e is Dictionary:
				result[str((e as Dictionary).get("id"))] = true
	return result


# M31 (docs/M31_RITOCCHI_TUTORIAL.md §2.1): the five optional fields of a step, each tied to the kind of condition it needs.
static func _step_extras(v: DataValidatorRules, e: Dictionary, conditions: Array) -> void:
	var has_ack: bool = false
	var counted: bool = false
	var events: Array[String] = []
	for c: Variant in conditions:
		var cond: Dictionary = c as Dictionary
		has_ack = has_ack or str(cond.get("type")) == "ack"
		if str(cond.get("type")) == "event":
			events.append(str(cond.get("signal")))
			counted = counted or (DataValidatorRules.is_int(cond.get("count")) and int(cond["count"]) > 1)
	if e.has("progress_text") and v.text(e, "progress_text"):
		_length(v, e, "progress_text", PROGRESS_TEXT_MAX)
		if (e["progress_text"] as String).count("%d") != 2:
			v.fail("field 'progress_text' must contain exactly two `%d`")
		if not counted:
			v.fail("field 'progress_text' needs an `event` condition with `count` > 1")
	if e.has("ack_text") and v.text(e, "ack_text"):
		_length(v, e, "ack_text", ACK_TEXT_MAX)
		if not has_ack:
			v.fail("field 'ack_text' needs an `ack` condition")
	if e.has("freeze_combat") and v.flag(e, "freeze_combat") and e["freeze_combat"] == true and not has_ack:
		v.fail("field 'freeze_combat' needs an `ack` condition")
	if e.has("force_node") and v.flag(e, "force_node") and e["force_node"] == true and not events.has("node_started"):
		v.fail("field 'force_node' needs a `node_started` event condition")
	if e.has("wound_hp_pct") and v.integer(e, "wound_hp_pct", 1, 99) and not events.has("food_eaten"):
		v.fail("field 'wound_hp_pct' needs a `food_eaten` event condition")


# M31 (§2.3): `final_reward` is mandatory (no fallback); its reward follows the rules of the quests.
static func _final_reward(v: DataValidatorRules, file: Dictionary) -> void:
	if not file.has("final_reward"):
		v.fail("field 'final_reward' is mandatory")
		return
	var e: Dictionary = v.object(file, "final_reward")
	v.at_entry("final_reward", 0, e)
	v.keys(e, ["id", "name", "description", "reward"], "final_reward")
	_length(v, e, "name", QUEST_NAME_MAX)
	_length(v, e, "description", QUEST_DESCRIPTION_MAX)
	_reward(v, e)
