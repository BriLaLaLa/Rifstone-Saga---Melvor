class_name AuctionReference
extends RefCounted
## The reference price ("recent average") of an item (docs/02_FORMULAS_M38.md F-214): the median of the last `W` epochs of two series,
## the sell series `s_e` and the buy series `a_e`, derived from the seed and the block (no state of the market). The value of an
## epoch is cached (the page asks for the whole list); the cache is dropped when the seed changes.

const PPM: int = AuctionMath.PPM

var _p: AuctionParams
var _seed: int = 0
var _cache: Dictionary[String, int] = {}


func _init(params: AuctionParams) -> void:
	_p = params


## F-214: the median of the epochs `epoch_now - W + 1 ... epoch_now` (negative ones are skipped); 0 if there is no value.
## `mode` is `&"buy"` or `&"sell"`; `value` and `band` are those of the item.
func price(item_id: StringName, mode: StringName, epoch_now: int, seed_value: int, value: int, band: AuctionPopulationBand) -> int:
	if seed_value != _seed:
		_cache.clear()
		_seed = seed_value
	var values: PackedInt64Array = []
	for epoch: int in range(maxi(0, epoch_now - _p.reference_epochs + 1), epoch_now + 1):
		values.append(_epoch_value(item_id, mode, epoch, value, band))
	return AuctionMath.median(values)


func clear() -> void:
	_cache.clear()


# `s_e` or `a_e` of the epoch (cached).
func _epoch_value(item_id: StringName, mode: StringName, epoch: int, value: int, band: AuctionPopulationBand) -> int:
	var key: String = "%s|%s|%d" % [item_id, mode, epoch]
	if _cache.has(key):
		return _cache[key]
	var result: int = _sell_value(item_id, epoch, value, band) if mode == &"sell" else _buy_value(item_id, epoch, value, band)
	_cache[key] = result
	return result


# F-214: the equilibrium of the item at the first block of the epoch, clamped to [MIN, MAX] (no saturation, no `taken`).
func _eq(item_id: StringName, block: int, band: AuctionPopulationBand) -> int:
	var pop: Vector2i = AuctionMath.population(band.buyers, band.sellers, AuctionMath.wave(item_id, "b", _seed, block, _p),
			AuctionMath.wave(item_id, "s", _seed, block, _p))
	var eq: int = _p.base_ppm + AuctionMath.drift(item_id, _seed, block, _p) + AuctionMath.pressure(pop.x, pop.y, _p)
	return clampi(eq, _p.min_ppm, _p.max_ppm)


@warning_ignore("integer_division")
func _sell_value(item_id: StringName, epoch: int, value: int, band: AuctionPopulationBand) -> int:
	return (value * _eq(item_id, epoch * _p.book_persist, band)) / PPM


@warning_ignore("integer_division")
func _buy_value(item_id: StringName, epoch: int, value: int, band: AuctionPopulationBand) -> int:
	var block: int = epoch * _p.book_persist
	var eq: int = _eq(item_id, block, band)
	var sellers: int = AuctionMath.population(band.buyers, band.sellers, AuctionMath.wave(item_id, "b", _seed, block, _p),
			AuctionMath.wave(item_id, "s", _seed, block, _p)).y
	var off_min: int = _p.book_hi_ppm
	for j: int in AuctionBook.listing_count(sellers, _p):
		off_min = mini(off_min, AuctionBook.ask_offset(item_id, _seed, epoch, j, _p))
	var ask: int = maxi(1, (value * eq * (PPM + off_min)) / (PPM * PPM))
	return AuctionMath.piece_price(ask, _p.markup_ppm)
