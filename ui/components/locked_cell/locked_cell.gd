class_name LockedCell
extends PanelContainer
## One cell of the "wiki a scoperta" of the Guide (docs/01_GDD.md §27.1, docs/05_INTERFACES.md §7.u): "???" with a
## shaded icon while the item is not discovered, name and base percentage once it is. The owner decides which of the two
## (it asks `Discoveries.has`); the cell only draws what it is told and keeps no game state.

const LOCKED_TEXT: String = "???"
const LOCKED_TOOLTIP: String = "Non l'hai ancora trovato."
const PCT_TEXT: String = "%s%%"
const NAME_FONT_SIZE: int = 13

var _data: GameData = null
var _icon: TextureRect = null
var _name: Label = null
var _chance: Label = null
var _item_id: StringName = &""
var _locked: bool = true


func _init() -> void:
	custom_minimum_size = UiStyle.LOCKED_CELL_SIZE
	add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.BG_FIELD, UiStyle.GOLD_FAINT,
			UiStyle.LOCKED_CELL_BORDER_WIDTH, UiStyle.LOCKED_CELL_RADIUS))
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(UiStyle.LOCKED_CELL_ICON_SIDE, UiStyle.LOCKED_CELL_ICON_SIDE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_icon)
	_name = Label.new()
	_name.name = "NameLabel"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	box.add_child(_name)
	_chance = Label.new()
	_chance.name = "ChanceLabel"
	_chance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chance.theme_type_variation = &"MutedLabel"
	box.add_child(_chance)
	show_locked()


## The data that give the icon and the name of an item (set once by the owner).
func setup(data: GameData) -> void:
	_data = data


## "???" with a shaded icon and no percentage: nothing about the item is revealed.
func show_locked() -> void:
	_locked = true
	_item_id = &""
	_icon.texture = load(UiStyle.MISSING_ICON) as Texture2D
	_icon.modulate = UiStyle.LOCKED_ICON_SHADE
	_name.text = LOCKED_TEXT
	_chance.text = ""
	tooltip_text = LOCKED_TOOLTIP


## The item with its icon, its name and its base percentage (`chance_pct` < 0: no percentage).
func show_item(item_id: StringName, chance_pct: float) -> void:
	if _data == null or not _data.has_item(item_id):
		Log.warn("ui", "locked cell: unknown item '%s'" % item_id)
		show_locked()
		return
	var def: ItemDef = _data.item(item_id)
	_locked = false
	_item_id = item_id
	_icon.texture = ItemSlotView.icon_of(def.icon)
	_icon.modulate = Color.WHITE
	_name.text = def.name
	_chance.text = PCT_TEXT % GuideDrops.pct_text(chance_pct) if chance_pct >= 0.0 else ""
	tooltip_text = def.name


func is_locked() -> bool:
	return _locked


func shown_name() -> String:
	return _name.text


func shown_chance() -> String:
	return _chance.text


func item_id() -> StringName:
	return _item_id
