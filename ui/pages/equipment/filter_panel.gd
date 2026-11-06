class_name FilterPanel
extends PanelContainer
## Automatic filter of the Armory (docs/01_GDD.md §25): one row per equipment slot with the minimum rarity and the
## minimum grade; a dropped piece below the rule is salvaged at once. The rules live in `Armory` (`filter_rules`,
## no signal): `refresh` rereads them at every opening/redraw of the page. A change is emitted as `rule_changed` and the
## page sends `armory.set_filter`. No game state here: the option buttons only show what was read.

signal rule_changed(slot: StringName, min_rarity: StringName, min_grade: int)

const TITLE_TEXT: String = "Filtro automatico"
const NOTE_TEXT: String = "I pezzi sotto la soglia di rarità o di grado vengono smantellati appena li trovi."
const SLOT_HEADER_TEXT: String = "Slot"
const RARITY_HEADER_TEXT: String = "Rarità minima"
const GRADE_HEADER_TEXT: String = "Grado minimo"
const GRADE_TEXT: String = "Grado %d"
const COLUMNS: int = 3
const SEPARATION: int = 4

var _grid: GridContainer = null
var _rarity_options: Dictionary[StringName, OptionButton] = {}
var _grade_options: Dictionary[StringName, OptionButton] = {}
var _built: bool = false


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	visible = false


## Rereads the rules of `session.armory` (builds the rows at the first call).
func refresh(session: GameSession) -> void:
	if not _built:
		_build(session)
	var rules: Dictionary = session.armory.filter_rules()
	for slot: StringName in Equipment.SLOTS:
		var rule: Dictionary = rules.get(slot, session.armory.filter_rule(slot))
		_rarity_options[slot].select(ArmoryFilter.RARITY_ORDER.find(rule[ArmoryFilter.KEY_RARITY]))
		_grade_options[slot].select(int(rule[ArmoryFilter.KEY_GRADE]) - ArmoryFilter.MIN_GRADE)


func _build(session: GameSession) -> void:
	_built = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", SEPARATION)
	scroll.add_child(box)
	var title := Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = &"HeaderLabel"
	box.add_child(title)
	var note := Label.new()
	note.text = NOTE_TEXT
	note.theme_type_variation = &"MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", SEPARATION)
	box.add_child(_grid)
	for header: String in [SLOT_HEADER_TEXT, RARITY_HEADER_TEXT, GRADE_HEADER_TEXT]:
		var label := Label.new()
		label.text = header
		label.theme_type_variation = &"MutedLabel"
		_grid.add_child(label)
	var max_grade: int = (session.data.balance_value(Upgrade.INGOT_ITEMS_KEY) as Array).size()
	for slot: StringName in Equipment.SLOTS:
		var name_label := Label.new()
		name_label.text = EquipmentStatsText.slot_text(slot, session.data)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(name_label)
		var rarity := OptionButton.new()
		rarity.name = "Rarity_%s" % slot
		rarity.focus_mode = Control.FOCUS_NONE
		for r: StringName in ArmoryFilter.RARITY_ORDER:
			rarity.add_item(ArmoryTexts.rarity_name(r))
		rarity.item_selected.connect(_on_changed.bind(slot))
		_grid.add_child(rarity)
		_rarity_options[slot] = rarity
		var grade := OptionButton.new()
		grade.name = "Grade_%s" % slot
		grade.focus_mode = Control.FOCUS_NONE
		for g: int in range(ArmoryFilter.MIN_GRADE, max_grade + 1):
			grade.add_item(GRADE_TEXT % g)
		grade.item_selected.connect(_on_changed.bind(slot))
		_grid.add_child(grade)
		_grade_options[slot] = grade


func _on_changed(_index: int, slot: StringName) -> void:
	rule_changed.emit(slot, ArmoryFilter.RARITY_ORDER[_rarity_options[slot].selected],
			ArmoryFilter.MIN_GRADE + _grade_options[slot].selected)


## Option button of a slot, for tests.
func rarity_option(slot: StringName) -> OptionButton:
	return _rarity_options[slot]


func grade_option(slot: StringName) -> OptionButton:
	return _grade_options[slot]
