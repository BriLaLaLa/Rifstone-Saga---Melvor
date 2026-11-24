class_name AuctionMarketBox
extends VBoxContainer
## "Mercato" block of the Auction House detail (docs/05_INTERFACES_M27.md §5.39): buyers, sellers, demand and the PNG listings,
## drawn from `AuctionHouse.population`. Extracted from `AuctionDetail` (M38-3); no state of its own.

var _buyers: Label = null
var _sellers: Label = null
var _demand: Label = null
var _hint: Label = null
var _listings: Label = null


func _ready() -> void:
	name = "MarketBox"
	_label("MarketCaption", &"HeaderLabel").text = AuctionTexts.MARKET_TITLE_TEXT
	_buyers = _label("BuyersLabel", &"")
	_sellers = _label("SellersLabel", &"")
	_demand = _label("DemandLabel", &"")
	_hint = _label("DemandHint", &"MutedLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_listings = _label("ListingsLabel", &"")


## Empty `pop` = item outside the list: the block is hidden.
func show_population(pop: Dictionary) -> void:
	visible = not pop.is_empty()
	if pop.is_empty():
		return
	var demand: StringName = pop["demand"]
	_buyers.text = AuctionTexts.BUYERS_TEXT % NumberFormat.format_int(int(pop["buyers"]))
	_sellers.text = AuctionTexts.SELLERS_TEXT % NumberFormat.format_int(int(pop["sellers"]))
	_demand.text = AuctionTexts.DEMAND_TEXT % AuctionTexts.demand_text(demand)
	var color: Color = UiStyle.GOOD if demand == &"high" else (UiStyle.BAD if demand == &"low" else UiStyle.GOLD_LIGHT)
	_demand.add_theme_color_override("font_color", color)
	_hint.text = AuctionTexts.demand_hint(demand)
	_listings.text = AuctionTexts.LISTINGS_TEXT % [NumberFormat.format_int(int(pop.get("listings", 0))),
			NumberFormat.format_int(int(pop.get("units", 0)))]


func _label(node_name: String, variation: StringName) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	if variation != &"":
		label.theme_type_variation = variation
	add_child(label)
	return label
