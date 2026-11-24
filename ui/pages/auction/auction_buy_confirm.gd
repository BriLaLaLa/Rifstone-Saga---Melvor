class_name AuctionBuyConfirm
extends ConfirmationDialog
## Confirmation of a huge purchase (docs/05_INTERFACES_M38.md §7.ag, F-218): total, average price and share of the book from
## `AuctionHouse.buy_preview`. «Compra» emits `confirmed`, «Annulla» only closes. The caller decides when to show it (`large`).

func _init() -> void:
	name = "BuyConfirm"
	title = AuctionDetailTexts.CONFIRM_TITLE_TEXT
	ok_button_text = AuctionDetailTexts.CONFIRM_OK_TEXT
	cancel_button_text = AuctionDetailTexts.CONFIRM_CANCEL_TEXT
	dialog_autowrap = true
	exclusive = true


## Fills the text from `preview` (`buy_preview` result) and opens the dialog.
func ask(item_name: String, qty: int, preview: Dictionary, currency: CurrencyParams) -> void:
	dialog_text = AuctionDetailTexts.confirm_text(item_name, qty, preview, currency)
	popup_centered(UiStyle.DIALOG_SIZE)
