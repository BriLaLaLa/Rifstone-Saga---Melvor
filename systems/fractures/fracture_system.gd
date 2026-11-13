class_name FractureSystem
extends RefCounted
## The Fractures the player opens with a Card (docs/01_GDD.md §17, docs/05_INTERFACES.md §5.23). It owns the Fracture in
## progress (`FractureRun`) and the bag still waiting for room after a win; the fight itself is run by `CombatEngine`.
## Nothing here opens a Fracture except `open`. No timers (`advance`): the engine moves the Fracture forward.
## Dependencies: data, events, modifiers, rng, bank, armory, cards, combat (only for the commands), character.

const SAVE_KEY: StringName = &"fractures"
const LOG_CATEGORY: String = "fracture"
const SOURCE_PREFIX: String = "fracture:"
const OUTCOME_WON: StringName = &"won"

var _session: GameSession
var _run: FractureRun = null
var _pending: FractureBag = FractureBag.new()
var _source: StringName = &""  # the modifier source currently set, &"" = none


func _init(session: GameSession) -> void:
	assert(session != null, "FractureSystem needs a session")
	_session = session
	session.events.fracture_finished.connect(_on_finished)


func is_active() -> bool:
	return _run != null


## The run in progress, null outside a Fracture. The engine reads it and advances its counters.
func run() -> FractureRun:
	return _run


## Copy for the UI: `{}` outside a Fracture.
func state() -> Dictionary:
	if _run == null:
		return {}
	var counts: Dictionary = _run.bag.counts()
	return {"grade": _run.grade, "card": _run.card.duplicate_card(), "group": _run.group, "groups": _run.groups_total,
		"boss": _run.boss_started, "bag": counts}


## unknown_id, fracture_active, fracture_bag_pending (in this order). The Card is consumed now.
func open(card_uid: int) -> CommandResult:
	if not _session.cards.has(card_uid):
		return CommandResult.fail(Reasons.UNKNOWN_ID)
	if _session.dungeon.is_active():
		return CommandResult.fail(Reasons.DUNGEON_ACTIVE)  # M22: one instance at a time
	if _run != null or _session.combat.in_fracture():
		return CommandResult.fail(Reasons.FRACTURE_ACTIVE)
	if has_pending():
		return CommandResult.fail(Reasons.FRACTURE_BAG_PENDING)
	var card: MapCard = _session.cards.take(card_uid)
	_run = FractureRun.create(card, &"", _session.data)
	rebuild_modifiers()
	_session.events.fracture_opened.emit(_run.grade)
	return _session.combat.start_fracture(_run)


## no_fracture; otherwise like a defeat (the Card is already spent, the bag is lost).
func abandon() -> CommandResult:
	if _run == null:
		return CommandResult.fail(Reasons.NO_FRACTURE)
	_session.combat.abandon_fracture()
	return CommandResult.success()


## What is waiting for room after a win: `{}` if nothing, else `{"stacks": [...], "pieces": int, "cards": int}`.
func pending() -> Dictionary:
	if _pending.is_empty():
		return {}
	return {"stacks": _pending.stacks(), "pieces": _pending.pieces().size(), "cards": _pending.cards().size()}


func has_pending() -> bool:
	return not _pending.is_empty()


## F-116: tries again with what is waiting. no_fracture (nothing waits); bank_full / armory_full if something stays.
func collect() -> CommandResult:
	if _pending.is_empty():
		return CommandResult.fail(Reasons.NO_FRACTURE)
	_deliver(_pending)
	_emit_bag_changed(_pending)
	if not _pending.stacks().is_empty():
		return CommandResult.fail(Reasons.BANK_FULL)
	return CommandResult.fail(Reasons.ARMORY_FULL) if not _pending.cards().is_empty() else CommandResult.success()


## F-110 (information for the UI only).
func recommended_level(grade: int) -> int:
	return _session.data.fracture_grade(grade).recommended_level


## F-111: the total of a risk or reward `type` of the Fracture in progress (0 outside).
func effect_total(type: StringName) -> float:
	return FractureScaler.total(_run.effects, type) if _run != null else 0.0


## Source `fracture:<uid>` with the rewards that are player stats (F-111), only while a Fracture is in progress.
func rebuild_modifiers() -> void:
	if _source != &"":
		_session.modifiers.clear_source(_source)
		_source = &""
	if _run == null:
		return
	var mods: Array[Modifier] = []
	for stat: StringName in [FractureScaler.REWARD_RARITY, FractureScaler.REWARD_GOLD]:
		mods.append(Modifier.make(stat, effect_total(stat)))
	mods.append(Modifier.make(&"skill_xp_pct", effect_total(FractureScaler.REWARD_XP), Modifier.SCOPE_GLOBAL))
	_source = StringName(SOURCE_PREFIX + str(_run.card.uid))
	_session.modifiers.set_source(_source, mods)


func new_game() -> void:
	_run = null
	_pending = FractureBag.new()
	_source = &""


func to_save() -> Dictionary:
	return {"run": _run.to_save() if _run != null else {}, "pending": _pending.to_save() if has_pending() else {}}


## An invalid run is dropped with its bag (the combat engine then loads as idle); an invalid `pending` is emptied.
func from_save(d: Dictionary) -> void:
	new_game()
	if d.get("run") is Dictionary and not (d["run"] as Dictionary).is_empty():
		_run = FractureRun.from_save(d["run"], _session.data)
	if d.get("pending") is Dictionary:
		_pending.from_save(d["pending"], _session.data)


## Load only: the saved combat is not in a Fracture, so the saved run has nothing to run on. Dropped without a trace.
func drop_orphan_run() -> void:
	Log.warn(LOG_CATEGORY, "saved Fracture without a saved fight: dropped")
	_run = null


# fracture_finished (emitted by the engine): a win delivers the bag, anything else loses it (X4). Then the Fracture is over.
func _on_finished(outcome: StringName, _grade: int, _groups: int, _cards: int, _pieces: int) -> void:
	if _run == null:
		return
	var bag: FractureBag = _run.bag
	if outcome == OUTCOME_WON:
		_pending = bag
		_deliver(_pending)
	else:
		var counts: Dictionary = bag.counts()
		bag.clear()
		_session.events.fracture_loot_lost.emit(counts["stacks"], counts["pieces"], counts["cards"])
	_run = null
	rebuild_modifiers()
	_emit_bag_changed(_pending)


# F-116: stacks to the Bank, pieces through the Armory filter (nothing waits), Cards to the CardStore; what does not fit stays.
func _deliver(bag: FractureBag) -> void:
	for entry: Dictionary in bag.stacks():
		var item_id: StringName = entry["item"]
		if _session.bank.can_add(item_id) and _session.bank.add(item_id, entry["qty"]).ok:
			bag.remove_stack(item_id)
	for inst: ItemInstance in bag.pieces():
		_session.armory.add_drop(inst)
		bag.remove_piece(inst)
	for card: MapCard in bag.cards():
		if _session.cards.can_add(1) and _session.cards.add(card) > 0:
			bag.remove_card(card)


func _emit_bag_changed(bag: FractureBag) -> void:
	var counts: Dictionary = bag.counts()
	_session.events.fracture_bag_changed.emit(counts["stacks"], counts["pieces"], counts["cards"])
