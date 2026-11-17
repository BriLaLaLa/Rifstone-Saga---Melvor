class_name ProfessionUnlocks
extends PanelContainer
## "Prossimi sblocchi" box of a production page: the next unlocks of the profession (level, kind, name) read from
## `Professions.next_unlocks`; hidden when there is none. Also the recipe origin and progress texts (formatting only).

const COUNT: int = 3
const BOX_SEPARATION: int = 6

var _skill_id: StringName = &""
var _lines: HFlowContainer = null


func setup(skill_id: StringName) -> void:
	_skill_id = skill_id
	name = "ProfessionUnlocks"
	theme_type_variation = &"HudPanel"
	var box := HFlowContainer.new()  # one compact row (it sits above the detail, always in sight)
	box.add_theme_constant_override("h_separation", BOX_SEPARATION * 3)
	add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = ProfessionTexts.UNLOCKS_TITLE
	title.theme_type_variation = &"HeaderLabel"
	box.add_child(title)
	_lines = box
	visible = false


## Reads the next unlocks; `allowed` is false while a special page replaces the recipe detail.
func redraw(session: GameSession, allowed: bool) -> void:
	for child: Node in _lines.get_children():
		if child.name != "Title":
			_lines.remove_child(child)
			child.queue_free()
	var rows: Array[Dictionary] = session.professions.next_unlocks(_skill_id, COUNT)
	for row: Dictionary in rows:
		var label := Label.new()
		label.text = ProfessionTexts.UNLOCK_LINE_TEXT % [NumberFormat.format_int(int(row["level"])),
				ProfessionTexts.UNLOCK_KINDS.get(StringName(row["kind"]), ""), _name_of(session, row)]
		_lines.add_child(label)
	visible = allowed and not rows.is_empty()


static func _name_of(session: GameSession, row: Dictionary) -> String:
	var id: StringName = StringName(row["id"])
	if StringName(row["kind"]) == &"trainer":
		return session.data.action(id).name
	return session.data.shop_entry(id).name


## The origin line of the recipe (for a scheme: learned or not, and why not); empty when it has no origin.
static func origin_text(session: GameSession, action: ActionDef) -> String:
	var source: StringName = session.professions.recipe_source(action.id)
	var known: bool = session.disciplines.knows_recipe(action.id)
	if source == &"trainer":
		return ProfessionTexts.ORIGIN_TRAINER_TEXT if known else ProfessionTexts.ORIGIN_TRAINER_LOCKED_TEXT
	if source == &"drop":
		return ProfessionTexts.ORIGIN_DROP_TEXT
	if source != &"scheme":
		return ""
	var entry: ShopEntryDef = session.data.shop_entry(session.professions.scheme_entry(action.id))
	if known:
		return ProfessionTexts.ORIGIN_SCHEME_KNOWN_TEXT % entry.name
	var need: int = int(entry.req_skills.get(action.skill_id, 0))
	if session.skills.get_level(action.skill_id) < need:
		return ProfessionTexts.ORIGIN_SCHEME_LEVEL_TEXT % [entry.name, NumberFormat.format_int(need)]
	return ProfessionTexts.ORIGIN_SCHEME_BUY_TEXT % [entry.name, Money.text(session.shop.price(entry.id), session.data.currency())]


## "Avanzamento: n% (colore)"; empty when the recipe has no colours.
@warning_ignore("integer_division")
static func progress_text(session: GameSession, action: ActionDef) -> String:
	var color: Dictionary = session.professions.recipe_color(action.id)
	var id: StringName = StringName(color.get("id", &""))
	if id == &"":
		return ""
	var percent: String = NumberFormat.format_int(int(color["chance_ppm"]) * 100 / ProfessionMath.PPM)
	return ProfessionTexts.PROGRESS_COLOR_TEXT % [percent, ProfessionTexts.COLOR_NAMES.get(id, "")]
