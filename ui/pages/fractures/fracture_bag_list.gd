class_name FractureBagList
extends VBoxContainer
## The content of the Fracture bag (M29-02, docs/01_GDD.md §17.2): one row per stack of items (icon, name, quantity), per piece
## (icon, name, rarity) and per Card, drawn from `session.fractures.bag_contents()` at every `redraw`. A click on a piece or a
## Card opens its detail (affixes / modifiers). The list only shows: nothing can be withdrawn before the boss. The only state
## it keeps is which details are open (presentation).

const ICON_SIZE: int = 36
const ROW_SEPARATION: int = 10
const LIST_SEPARATION: int = 4

## Keys ("p<index>", "c<index>") of the rows with the detail open.
var _open: Dictionary[String, bool] = {}
var _session: GameSession = null


func _init() -> void:
	add_theme_constant_override("separation", LIST_SEPARATION)


## Rebuilds the rows from the bag of the Fracture in progress (empty outside).
func redraw(session: GameSession) -> void:
	_session = session
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var bag: Dictionary = session.fractures.bag_contents()
	if bag.is_empty():
		_open.clear()
		return
	var any: bool = false
	for entry: Dictionary in bag["stacks"] as Array[Dictionary]:
		var def: ItemDef = session.data.item(entry["item"] as StringName)
		if def != null:
			add_child(_row("Stack_%s" % def.id, def, def.name, "", int(entry["qty"]), UiStyle.rarity_color(&"common"), "", ""))
			any = true
	var pieces: Array[ItemInstance] = bag["pieces"] as Array[ItemInstance]
	for i: int in pieces.size():
		var inst: ItemInstance = pieces[i]
		var base: ItemDef = session.data.item(inst.base_id)
		if base == null:
			continue
		var detail: String = "\n".join(ArmoryTexts.affix_lines(inst, session.data))
		add_child(_row("Piece_%d" % i, base, ArmoryTexts.piece_name(inst, base),
				"%s  ·  %s" % [ArmoryTexts.rarity_name(inst.rarity), ArmoryTexts.LEVEL_TEXT % inst.ilvl], 0,
				UiStyle.rarity_color(inst.rarity), "p%d" % i, detail))
		any = true
	var cards: Array[MapCard] = bag["cards"] as Array[MapCard]
	for i: int in cards.size():
		var card: MapCard = cards[i]
		var base: ItemDef = session.data.item(card.base_id)
		if base == null:
			continue
		add_child(_row("Card_%d" % i, base, base.name, "%s  ·  %s" % [FractureTexts.rarity_name(card.rarity),
				FractureTexts.CARD_GRADE_TEXT % card.grade], 0, UiStyle.rarity_color(card.rarity), "c%d" % i,
				_card_detail(session, card)))
		any = true
	if not any:
		var empty := Label.new()
		empty.name = "BagEmpty"
		empty.text = FractureTexts.BAG_EMPTY_TEXT
		empty.theme_type_variation = &"MutedLabel"
		add_child(empty)


func _card_detail(session: GameSession, card: MapCard) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for effect: Dictionary in MapCardRoller.effects(card, session.data):
		var def: MapModDef = session.data.map_mod(effect["mod"] as StringName)
		lines.append("%s: %s" % [ItemTooltipLines.escape(def.name if def != null else String(effect["mod"])),
				ItemTooltipLines.escape(FractureTexts.effect_line(effect))])
	return "\n".join(lines) if not lines.is_empty() else FractureTexts.CARD_NO_MODS_TEXT


## One row. `key` = "" for a row without detail; `detail` is BBCode shown under the row while its key is open.
func _row(node_name: String, def: ItemDef, title: String, subtitle: String, qty: int, color: Color, key: String,
		detail: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	var column := VBoxContainer.new()
	panel.add_child(column)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", ROW_SEPARATION)
	column.add_child(line)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ItemSlotView.icon_of(def.icon)
	line.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(texts)
	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title
	title_label.clip_text = true
	title_label.add_theme_color_override("font_color", color)
	texts.add_child(title_label)
	if subtitle != "":
		var sub := Label.new()
		sub.name = "SubtitleLabel"
		sub.text = subtitle
		sub.theme_type_variation = &"MutedLabel"
		texts.add_child(sub)
	if qty > 0:
		var qty_label := Label.new()
		qty_label.name = "QtyLabel"
		qty_label.text = "x%s" % NumberFormat.format_int(qty)
		line.add_child(qty_label)
	if key == "":
		panel.tooltip_text = def.description
		return panel
	var is_open: bool = _open.get(key, false)
	var hint := Label.new()
	hint.name = "DetailHint"
	hint.text = FractureTexts.BAG_HIDE_TEXT if is_open else FractureTexts.BAG_SHOW_TEXT
	hint.theme_type_variation = &"MutedLabel"
	line.add_child(hint)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_row_input.bind(key))
	if is_open:
		var body := RichTextLabel.new()
		body.name = "Detail"
		body.bbcode_enabled = true
		body.fit_content = true
		body.scroll_active = false
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.text = detail if detail != "" else FractureTexts.BAG_NO_DETAIL_TEXT
		column.add_child(body)
	return panel


func _on_row_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_open[key] = not _open.get(key, false)
		redraw.call_deferred(_session)


