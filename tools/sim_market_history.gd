extends RefCounted
## Check (5b) of `tools/sim_market.gd` (M37 F-209): any number of writes leaves at most `history_max` entries (the history is a
## plain list: money goes through the Mail).


## Returns {"failures": Array, "max": int, "writes": int, "size": int}.
static func history(data: GameData, seed_value: int, ids: Array[StringName]) -> Dictionary:
	var p: AuctionParams = data.auction_params()
	var h := AuctionHistory.new(p, data)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var failures: Array = []
	var writes: int = p.history_max * 5
	for i: int in writes:
		var item: StringName = ids[rng.randi_range(0, ids.size() - 1)]
		match rng.randi_range(0, 3):
			0: h.record_listing_sold(item, rng.randi_range(1, 9), 100, 95, i, rng.randi_range(1, 200))
			1: h.record_instant_sold(item, rng.randi_range(1, 9), rng.randi_range(1, 5000), i)
			2: h.record_closed(&"expired", item, rng.randi_range(1, 9), 100, i, i + 1000)
			_: h.record_closed(&"cancelled", item, rng.randi_range(1, 9), 100, i, i + 2000)
		if h.count() > p.history_max:
			failures.append("(5b) history has %d entries after write %d, max %d" % [h.count(), i, p.history_max])
			break
	return {"failures": failures, "max": p.history_max, "writes": writes, "size": h.count()}
