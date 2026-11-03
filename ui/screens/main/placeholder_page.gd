extends Page
## Minimal stand-in for the routes whose real page does not exist yet (route table PageHost.ROUTES).
##
## M1-15 replaces the `&"skill"` route with the generic SkillPage, M1-18 the `&"bank"` route with the BankPage: each
## changes one line of PageHost.ROUTES; when no route uses this scene any more it is deleted.
## It shows the route title, one line read from the session (skill level, bank slots) and "In arrivo".

const ROUTE_SKILL := &"skill"
const ROUTE_BANK := &"bank"
const BANK_TITLE := "Bank"

var _session: GameSession = null

@onready var _title_label: Label = %TitleLabel
@onready var _info_label: Label = %InfoLabel


func bind(session: GameSession) -> void:
	_session = session
	_title_label.text = _title()
	match PageHost.route_of(page_id):
		ROUTE_SKILL:
			_session.events.level_up.connect(_on_events_level_up)
		ROUTE_BANK:
			_session.events.bank_capacity_changed.connect(_on_events_bank_capacity_changed)
	_redraw()


func unbind() -> void:
	if _session == null or not is_instance_valid(_session):
		_session = null
		return
	if _session.events.level_up.is_connected(_on_events_level_up):
		_session.events.level_up.disconnect(_on_events_level_up)
	if _session.events.bank_capacity_changed.is_connected(_on_events_bank_capacity_changed):
		_session.events.bank_capacity_changed.disconnect(_on_events_bank_capacity_changed)
	_session = null


func _redraw() -> void:
	match PageHost.route_of(page_id):
		ROUTE_SKILL:
			var level: int = _session.skills.get_level(PageHost.argument_of(page_id))
			_info_label.text = "Livello %s" % NumberFormat.format_int(level)
		ROUTE_BANK:
			_info_label.text = "Caselle usate: %s / %s" % [NumberFormat.format_int(_session.bank.used()),
					NumberFormat.format_int(_session.bank.capacity())]
		_:
			_info_label.text = ""


func _title() -> String:
	match PageHost.route_of(page_id):
		ROUTE_SKILL:
			# PageHost only shows skill pages of known skills.
			var skill: SkillDef = _session.data.skill(PageHost.argument_of(page_id))
			if skill != null:
				return skill.name
		ROUTE_BANK:
			return BANK_TITLE
	return String(page_id)


func _on_events_level_up(skill_id: StringName, _new_level: int) -> void:
	if skill_id == PageHost.argument_of(page_id):
		_redraw()


func _on_events_bank_capacity_changed(_used: int, _capacity: int) -> void:
	_redraw()
