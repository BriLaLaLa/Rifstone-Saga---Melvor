class_name GuideRenderer
extends RefCounted
## Draws the blocks of a Guide page into a container (text, heading, table, links, rich) and routes every link click
## to `on_link: (entry_id: StringName) -> void`. Tables come from GuideTables; no content is written here.

const TABLE_H_SEPARATION: int = 18
const TABLE_V_SEPARATION: int = 4
const BODY_FONT_SIZE: int = 16
const CELL_MIN_WIDTH: float = 72.0
const BULLET: String = "- "

var _data: GameData = null
var _nav: GuideNav = null
var _entities: GuideEntityBlocks = null
var _on_link: Callable = Callable()


func _init(data: GameData, nav: GuideNav, entities: GuideEntityBlocks, on_link: Callable) -> void:
	_data = data
	_nav = nav
	_entities = entities
	_on_link = on_link


## Blocks of an entry: the hand-written page or the generated one; empty for an unknown entry.
func blocks_of(entry_id: StringName) -> Array[Dictionary]:
	var text: String = String(entry_id)
	if text.begins_with(GuideNav.KIND_PAGE + ":"):
		var page: GuidePageDef = _data.guide_page(StringName(text.trim_prefix(GuideNav.KIND_PAGE + ":")))
		if page == null:
			return []
		return page.blocks
	return _entities.build(entry_id)


## Replaces the content of `body` with the title and the blocks of `entry_id`.
func render(body: VBoxContainer, entry_id: StringName) -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var title: Label = Label.new()
	title.name = "PageTitle"
	title.text = _nav.title_of(entry_id)
	title.theme_type_variation = &"TitleLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var group: Label = Label.new()
	group.name = "PageGroup"
	group.text = _nav.group_of(entry_id)
	group.theme_type_variation = &"MutedLabel"
	body.add_child(group)
	for block: Dictionary in blocks_of(entry_id):
		_render_block(body, block)


func _render_block(body: VBoxContainer, block: Dictionary) -> void:
	match str(block.get("type", "")):
		"text":
			_add_rich(body, GuideRich.text_to_bbcode(str(block.get("text", "")), _data))
		"rich":
			_add_rich(body, str(block.get("bb", "")))
		"heading":
			var heading: Label = Label.new()
			heading.text = str(block.get("text", ""))
			heading.theme_type_variation = &"HeaderLabel"
			body.add_child(heading)
		"table":
			_add_table(body, str(block.get("source", "")))
		"links":
			for target: Variant in block.get("targets", []) as Array:
				var id: StringName = StringName(str(target))
				var label: String = _nav.title_of(id)
				_add_rich(body, BULLET + (GuideRich.link(id, label) if _nav.has_entry(id) else GuideRich.escape(str(target))))


func _add_rich(parent: Control, bbcode: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
	label.text = bbcode
	label.meta_clicked.connect(_on_meta_clicked)
	parent.add_child(label)
	return label


func _add_table(body: VBoxContainer, source: String) -> void:
	var rows: Array[Array] = GuideTables.build(source, _data)
	if rows.is_empty():
		return
	var grid: GridContainer = GridContainer.new()
	grid.columns = (rows[0] as Array).size()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", TABLE_H_SEPARATION)
	grid.add_theme_constant_override("v_separation", TABLE_V_SEPARATION)
	body.add_child(grid)
	for row_index: int in rows.size():
		for cell: Variant in rows[row_index] as Array:
			var bbcode: String = GuideRich.cell_to_bbcode(str(cell), _nav)
			var label: RichTextLabel = _add_rich(grid, "[b]%s[/b]" % bbcode if row_index == 0 else bbcode)
			label.custom_minimum_size.x = CELL_MIN_WIDTH


func _on_meta_clicked(meta: Variant) -> void:
	if _on_link.is_valid():
		_on_link.call(StringName(str(meta)))
