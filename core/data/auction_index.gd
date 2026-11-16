class_name AuctionIndex
extends RefCounted
## Helper of GameData (internal, kept out of game_data.gd for its size limit): the `auction` parameters of balance.json
## and the items of data/auction/auction_items.json (docs/04_DATA_SCHEMA.md §28), in file order.

const FILE: String = "auction/auction_items.json"

var params: AuctionParams = null
var by_id: Dictionary[StringName, AuctionItemDef] = {}
var list: Array[AuctionItemDef] = []


## `raw` is `{path: top-level object}` of the single file; a Def that cannot be built is reported in `errors`.
func build(balance: Dictionary, raw: Dictionary, errors: PackedStringArray) -> void:
	params = AuctionParams.from_dict(balance["auction"] as Dictionary)
	if params == null:
		errors.append("balance.json: key 'auction': cannot be built (see the log)")
	for path: String in raw:
		for d: Variant in (raw[path]["items"] as Array):
			var def: AuctionItemDef = AuctionItemDef.from_dict(d as Dictionary)
			if def == null:
				errors.append("%s: auction item '%s': cannot be built (see the log)" % [path, (d as Dictionary).get("item")])
				continue
			by_id[def.item] = def
			list.append(def)


func clear() -> void:
	params = null
	by_id.clear()
	list.clear()
