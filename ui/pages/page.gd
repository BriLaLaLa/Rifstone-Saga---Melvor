class_name Page
extends Control
## Base of every page shown by the PageHost (docs/05_INTERFACES.md §7, docs/03_ARCHITECTURE.md §11).
##
## The PageHost sets `page_id` (e.g. `&"skill:forestry"`, `&"bank"`), adds the page to the tree and calls `bind`;
## when the player changes page (or the session ends) it calls `unbind` and frees the page.
## A page keeps no game state: only references to the session and to its own nodes. Every redraw reads the
## session's getters; every player action is a command that returns a CommandResult.
## Subclasses connect to `session.events` in `bind` and disconnect every connection in `unbind`.

## Route of this page, set by the PageHost before `bind`. Its part after ":" (if any) is the route argument.
var page_id: StringName = &""


## Virtual: connects to the session's events and draws the first state read from the session.
func bind(_session: GameSession) -> void:
	pass


## Virtual: disconnects everything connected in `bind`. Called once, before the page is freed.
func unbind() -> void:
	pass
