class_name DungeonCombatNotice
extends RefCounted
## The Dungeon seen from the Combat page (docs/05_INTERFACES.md §7.q): with `combat.in_dungeon()` the header says "Sei nel Covo
## delle Scimmie", the choice of the area is hidden and a link leads to the Dungeon page. No state, no rules.


## True while the combat engine runs a dungeon.
static func is_in(session: GameSession) -> bool:
	return session.combat.in_dungeon()


## Adds the hidden "Vai al Dungeon" button to `parent` (the header of the page).
static func add_link(parent: Node) -> Button:
	var link := Button.new()
	link.name = "DungeonLinkButton"
	link.text = DungeonTexts.COMBAT_OPEN_PAGE_TEXT
	link.tooltip_text = DungeonTexts.COMBAT_NOTICE_HINT_TEXT
	link.visible = false
	link.pressed.connect(open_page.bind(link))
	parent.add_child(link)
	return link


## Goes to the Dungeon page through the PageHost that holds `from`.
static func open_page(from: Node) -> void:
	var node: Node = from.get_parent()
	while node != null and not node is PageHost:
		node = node.get_parent()
	if node != null:
		(node as PageHost).show_page.call_deferred(&"dungeon")
