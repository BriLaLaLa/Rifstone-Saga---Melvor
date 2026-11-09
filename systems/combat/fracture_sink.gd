class_name FractureSink
extends LootSink
## The sink of the drops inside a Fracture (docs/05_INTERFACES.md §5.23): everything goes to the bag of the Fracture
## (pieces and Cards too) and the rewards of the Card change the drops (F-111): `loot_qty_pct`, `dust_pct`, `blueprint_pct`.

const DUST_ITEM: StringName = &"rift_dust"
const EPSILON: float = 1e-9

var _session: GameSession
var _run: FractureRun


func _init(session: GameSession, run: FractureRun) -> void:
	_session = session
	_run = run


func add(item_id: StringName, qty: int) -> bool:
	_run.bag.add_stack(item_id, qty)
	_changed()
	return true


func add_piece(inst: ItemInstance) -> void:
	_run.bag.add_piece(inst)
	_changed()


func add_card(card: MapCard) -> void:
	_run.bag.add_card(card)
	_changed()


## F-113 / F-32: a Card from a drop table, rarity of F-109 with the global `item_rarity_pct`.
func drop_card(grade: int) -> void:
	var card: MapCard = MapCardRoller.create(grade, _session.cards.roll_rarity(), _session.data, _session.rng)
	if card != null:
		add_card(card)


## F-111 `blueprint_pct`: the probability of a blueprint x (1 + v/100), at most 100.
func drop_chance(base: ItemDef, chance_pct: float) -> float:
	if not base.is_blueprint():
		return chance_pct
	return minf(100.0, chance_pct * (1.0 + FractureScaler.total(_run.effects, FractureScaler.REWARD_BLUEPRINT) / 100.0))


## F-111 `loot_qty_pct` (never below the rolled quantity) and, for the Rift Dust, `dust_pct` (round).
func drop_qty(base: ItemDef, qty: int) -> int:
	var result: int = maxi(qty, int(round(float(qty) * (1.0 + FractureScaler.total(_run.effects, FractureScaler.REWARD_QTY) / 100.0))))
	if base.id == DUST_ITEM:
		result = int(round(float(result) * (1.0 + FractureScaler.total(_run.effects, FractureScaler.REWARD_DUST) / 100.0)))
	return result


func _changed() -> void:
	var counts: Dictionary = _run.bag.counts()
	_session.events.fracture_bag_changed.emit(counts["stacks"], counts["pieces"], counts["cards"])
