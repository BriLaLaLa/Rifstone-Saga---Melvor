class_name AuctionPopulationBand
extends RefCounted
## One band of data/auction/population.json (docs/04_DATA_SCHEMA_M26.md §31.7, F-172): the items up to `max_value` (the first
## band that fits) have `buyers` and `sellers` as base population. `max_value` is -1 for the open last band.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped; ranges are the validator's job.

var max_value: int = -1
var buyers: int = 0
var sellers: int = 0


static func from_dict(d: Dictionary) -> AuctionPopulationBand:
	var r := DefReader.new(d, "auction population band")
	var band := AuctionPopulationBand.new()
	if r.has("max_value"):
		band.max_value = r.integer("max_value")
	band.buyers = r.integer("buyers")
	band.sellers = r.integer("sellers")
	return band if r.ok else null


## The bands of a parsed population.json (`{"bands": [...]}`) in file order (one that cannot be built is logged and left out).
static func list_from(content: Dictionary) -> Array[AuctionPopulationBand]:
	var bands: Array[AuctionPopulationBand] = []
	var raw: Variant = content.get("bands")
	if not raw is Array:
		return bands
	for d: Variant in raw as Array:
		if not d is Dictionary:
			continue
		var band: AuctionPopulationBand = from_dict(d as Dictionary)
		if band != null:
			bands.append(band)
	return bands
