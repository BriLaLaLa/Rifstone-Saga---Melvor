class_name AuctionDuration
extends RefCounted
## One duration of a player listing (balance.json `auction.listing.durations`, docs/04_DATA_SCHEMA_M27.md §32.4, F-180): its length
## in hours and in market blocks, and the deposit in ppm of the value of the pieces.

var id: StringName = &""
var hours: int = 0
var blocks: int = 0
var deposit_ppm: int = 0


## `block_ms` converts the hours into blocks (`hours * 3.600.000 / block_ms`, whole by validation). Null (after logging) if mistyped.
@warning_ignore("integer_division")
static func from_dict(d: Dictionary, block_ms: int) -> AuctionDuration:
	var r := DefReader.new(d, "auction duration")
	var duration := AuctionDuration.new()
	duration.id = r.id("id")
	duration.hours = r.integer("hours")
	duration.deposit_ppm = AuctionParams.ppm(r.number("deposit_pct"))
	duration.blocks = duration.hours * 3600000 / maxi(1, block_ms)
	return duration if r.ok else null
