extends Node
## The single tooltip of the game (autoload `Tooltips`), on its own CanvasLayer above every screen.
##
## Ported from the previous game's tooltip manager. Public API (docs/05_INTERFACES.md §2): `show_item`, `show_text`,
## `hide_tooltip`. Changes: no game-state lookups and no item dictionaries, the input is an `ItemDef` plus a
## quantity; the item lines read stat labels and formats from `GameData.stats`; the layer and the tooltip are
## children of this node, built synchronously in `_ready` (no deferred add to the root, no awaits); no prints.
##
## Injection point: `data` is the GameData used for stat labels and skill names; null means `DataRegistry.data`.
## Tests set it to the fixture data (GameData.load_from_dirs("res://tests/fixtures/data", "res://data/config")).

const TOOLTIP_SCENE: PackedScene = preload("res://ui/components/tooltip/custom_tooltip.tscn")
## Above every other CanvasLayer of the UI.
const TOOLTIP_LAYER: int = 100

## GameData for labels and names; null = the `DataRegistry` autoload's data.
var data: GameData = null

var _layer: CanvasLayer
var _tooltip: CustomTooltip


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "TooltipLayer"
	_layer.layer = TOOLTIP_LAYER
	add_child(_layer)
	_tooltip = TOOLTIP_SCENE.instantiate() as CustomTooltip
	_layer.add_child(_tooltip)
	_tooltip.hide_tooltip()


## Tooltip of `item` with `count` owned (0 = no quantity line) near the global cursor position `global_pos`.
func show_item(item: ItemDef, count: int, global_pos: Vector2) -> void:
	if item == null:
		push_error("Tooltips.show_item: null item")
		hide_tooltip()
		return
	_tooltip.setup_item(item, count, _data())
	_tooltip.show_at(global_pos)


## Text tooltip (gold title, BBCode body) near the global cursor position `global_pos`.
func show_text(title: String, body: String, global_pos: Vector2) -> void:
	_tooltip.setup_text(title, body)
	_tooltip.show_at(global_pos)


func hide_tooltip() -> void:
	_tooltip.hide_tooltip()


## Missing or invalid data is reported by ItemTooltipLines, only when an item needs it.
func _data() -> GameData:
	return data if data != null else DataRegistry.data
