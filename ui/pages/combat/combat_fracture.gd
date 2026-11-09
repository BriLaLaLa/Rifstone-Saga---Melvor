class_name CombatFracture
extends RefCounted
## The Fracture in progress seen from the Combat page (docs/05_INTERFACES.md §7.v): the header "Frattura di grado N - gruppo
## i/N", the line of the boss (ability in progress, shield) and the link to the Fractures page. Pure functions over
## `combat.get_state()["fracture"]` and the data; no state, no rules.


## True when `state` (combat.get_state()) is the state of a Fracture.
static func is_in(state: Dictionary) -> bool:
	return state.has("fracture") and not (state["fracture"] as Dictionary).is_empty()


## "Frattura di grado 3 - gruppo 12/30" / "Frattura di grado 3 - boss".
static func header_text(session: GameSession, fracture: Dictionary) -> String:
	var run: FractureRun = session.combat.fracture_run()
	var grade: int = run.grade if run != null else 0
	if bool(fracture["boss"]):
		return FractureTexts.COMBAT_HEADER_BOSS_TEXT % grade
	return FractureTexts.COMBAT_HEADER_TEXT % [grade, int(fracture["group"]), int(fracture["groups"])]


## `base` followed by the boss ability in progress and the active shield, when there are any.
static func state_text(fracture: Dictionary, base: String, data: GameData) -> String:
	var parts: PackedStringArray = PackedStringArray([base])
	var boss: BossDef = EnemyView.boss_of(data, fracture["boss_id"] as StringName)
	if bool(fracture["boss"]) and boss != null and boss.ability != null:
		parts.append(FractureTexts.COMBAT_ABILITY_TEXT % [FractureTexts.ability_name(boss.ability.type),
				CombatTexts.seconds_text(int(fracture["boss_ability_ms"]))])
	if int(fracture["shield"]) > 0:
		parts.append(FractureTexts.COMBAT_SHIELD_TEXT % NumberFormat.format_int(int(fracture["shield"])))
	return " - ".join(parts)


## Name and ability of the boss for the card of the target ("Colpo pesante").
static func ability_text(data: GameData, boss_id: StringName) -> String:
	var boss: BossDef = EnemyView.boss_of(data, boss_id)
	return FractureTexts.ability_name(boss.ability.type) if boss != null and boss.ability != null else ""


## Adds the hidden "Vai alle Fratture" button to `parent` (the header of the page).
static func add_link(parent: Node) -> Button:
	var link := Button.new()
	link.name = "FractureLinkButton"
	link.text = FractureTexts.COMBAT_OPEN_PAGE_TEXT
	link.tooltip_text = FractureTexts.COMBAT_HINT_TEXT
	link.visible = false
	link.pressed.connect(open_fractures_page.bind(link))
	parent.add_child(link)
	return link


## Goes to the Fractures page through the PageHost that holds `from` (as the "?" button does).
static func open_fractures_page(from: Node) -> void:
	var node: Node = from.get_parent()
	while node != null and not node is PageHost:
		node = node.get_parent()
	if node != null:
		(node as PageHost).show_page.call_deferred(&"fractures")
