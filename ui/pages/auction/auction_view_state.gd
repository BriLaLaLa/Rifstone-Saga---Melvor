class_name AuctionViewState
extends RefCounted
## Presentation choices of one tab of the Auction House page (Compra or Vendi): category, sort, filters and the selected item
## (docs/01_GDD_M37.md §45.2 punto 5). Kept per tab for the play session by `AuctionPage`, never saved, never a game value.

var category: StringName = AuctionCategoryTree.ALL
var sort_key: StringName = AuctionList.SORT_NAME
var sort_desc: bool = false
var owned_only: bool = false
var buyable_only: bool = false
var selected: StringName = &""


## Back to "no choice made" (used when the page is asked to show one item).
func reset_filters() -> void:
	category = AuctionCategoryTree.ALL
	owned_only = false
	buyable_only = false
