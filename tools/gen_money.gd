extends RefCounted
## Shared by the generators (M27-03, F-177): they compute in silver (the legacy "gold" of M26) and write copper.
## `CPS` comes from balance.json `currency.copper_per_silver`; nothing is cached across runs.


static func cps() -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/balance.json"))
	assert(parsed is Dictionary and (parsed as Dictionary).get("currency") is Dictionary, "balance.json currency missing")
	return int(((parsed as Dictionary)["currency"] as Dictionary)["copper_per_silver"])
