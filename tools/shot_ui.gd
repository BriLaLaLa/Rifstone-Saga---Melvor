extends Node
## Dev tool: renders the main screen with a test session at the window size and saves PNGs of the main pages.
## Needs a window (NOT --headless); always run it under a timeout:
##   timeout 90 Godot --path . --resolution 1280x720 res://tools/shot_ui.tscn -- <out_dir> <w>x<h>
## Default output: user://shots (printed). Pages: combat (plain fight, map, node, rich node, skipped node), trainers,
## village, auction, a skill page with a production queue, plus character, bank, equipment, rift, shop.

const SCENE: String = "res://ui/screens/main/main_screen.tscn"
const PAGES: Array[StringName] = [&"combat", &"character", &"bank", &"equipment", &"rift", &"shop", &"trainers",
		&"village", &"auction"]

var _out: String = "user://shots"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if args.size() > 1:
		var parts: PackedStringArray = args[1].split("x")
		get_tree().root.size = Vector2i(int(parts[0]), int(parts[1]))
	_run()


func _run() -> void:
	var session: GameSession = TestFactory.session(1234, TestFactory.real_data(), true)
	TestFactory.set_character_level(session, 30)
	TestFactory.learn_discipline(session, &"forestry")
	TestFactory.learn_discipline(session, &"forging")
	session.village.from_save({"levels": {"auction_house": 3}})
	var screen: MainScreen = (load(SCENE) as PackedScene).instantiate() as MainScreen
	screen.session = session
	get_tree().root.add_child.call_deferred(screen)
	await _frames(5)
	var host: PageHost = screen.get_node("%PageHost") as PageHost
	for hint: Node in screen.find_children("*", "Button", true, false):
		if (hint as Button).text == "Ho capito":
			(hint as Button).pressed.emit()
	await _frames(3)
	for page_id: StringName in PAGES:
		host.show_page(page_id)
		if page_id == &"combat":
			session.combat.start(&"redrock_plains")
			for i: int in 8:
				session.combat.advance(1000)
		await _frames(8)
		_save(page_id)
	await _auction_shots(session, host, screen)
	_queue_shot(session, host)
	await _frames(8)
	_save(&"skill_queue")
	await _prof_shots(session, host)
	await _merchant_shots(session, host)
	host.show_page(&"combat")
	await _frames(4)
	var map_button: Node = screen.find_child("MapButton", true, false)
	if map_button is Button:
		(map_button as Button).pressed.emit()
		await _frames(8)
		_save(&"combat_map")
		(screen.find_child("CombatMap", true, false) as CombatMap).close()
	await _travel_shot(session, host)
	await _node_shots(session, host)
	print_rich("shots in ", ProjectSettings.globalize_path(_out))
	get_tree().quit(0)


## Auction House: buy tab with an item picked, then the sell tab (Deposit stocked with listed items) with an item picked.
func _auction_shots(session: GameSession, host: PageHost, screen: Node) -> void:
	for id: StringName in session.auction.listed_items().slice(0, 40):
		TestFactory.give(session, id, 25)
	host.show_page(&"auction")
	await _frames(6)
	var rows: Array[Node] = screen.find_children("Row_*", "AuctionRow", true, false)
	if not rows.is_empty():
		(rows[2 if rows.size() > 2 else 0] as AuctionRow).row_clicked.emit((rows[2 if rows.size() > 2 else 0] as AuctionRow).item_id)
	await _frames(6)
	_save(&"auction_buy")
	(screen.find_child("Tab_sell", true, false) as Button).pressed.emit()
	await _frames(6)
	rows = screen.find_children("Row_*", "AuctionRow", true, false)
	if not rows.is_empty():
		(rows[1 if rows.size() > 1 else 0] as AuctionRow).row_clicked.emit((rows[1 if rows.size() > 1 else 0] as AuctionRow).item_id)
	await _frames(6)
	_save(&"auction_sell")


func _queue_shot(session: GameSession, host: PageHost) -> void:
	host.show_page(&"skill:forging")
	var count: int = 0
	for action: ActionDef in session.data.actions_for_skill(&"forging"):
		if count >= 4:
			break
		for input: ItemQty in action.inputs:
			TestFactory.give(session, input.item_id, 200)
		if session.actions.enqueue(&"forging", action.id, 5, count == 1).ok:
			count += 1


## Combat in the `travel` state (the little map in place of the enemies), half way.
func _travel_shot(session: GameSession, host: PageHost) -> void:
	session.combat.stop()
	session.combat.start(&"redrock_plains")
	for i: int in 4000:
		if session.combat.state() == &"travel":
			break
		session.combat.advance(100)
	for i: int in 8:
		session.combat.advance(250)
	host.show_page(&"combat")
	await _frames(8)
	_save(&"travel_live")


func _node_shots(session: GameSession, host: PageHost) -> void:
	session.combat.stop()
	session.combat.start(&"redrock_plains")
	for i: int in 4000:
		if session.combat.state() == &"node":
			break
		session.combat.advance(100)
	host.show_page(&"combat")
	await _frames(8)
	_save(&"node_live")
	var card: NodeCard = host.find_child("NodeCard", true, false) as NodeCard
	if card == null:
		return
	var page: Node = card
	while page != null and not page is Page:
		page = page.get_parent()
	if page == null:
		return
	page.set_process(false)
	var base: Dictionary = {"skill": &"forestry", "action": &"cut_redbirch", "duration_ms": 10000, "elapsed_ms": 4500,
			"skipped": false, "skip_reason": &"", "color": &"yellow", "attempts": 3, "attempt": 1, "rich": false,
			"units": 26, "units_planned": 80, "last_attempt": {"units": 26, "color": &"yellow", "xp": 7}}
	var variants: Dictionary[StringName, Dictionary] = {&"node_rich": {"rich": true, "attempts": 5},
			&"node_skipped": {"skipped": true, "skip_reason": Reasons.NOT_LEARNED},
			&"node_too_hard": {"skipped": true, "skip_reason": Reasons.TOO_HARD}}
	for key: StringName in variants:
		var node: Dictionary = base.duplicate(true)
		node.merge(variants[key], true)
		card.refresh({"state": &"node", "node": node}, session.data)
		await _frames(6)
		_save(key)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
	for hint: Node in get_tree().root.find_children("*", "Button", true, false):  # hint cards cover the page
		if (hint as Button).text == "Ho capito" and hint.is_visible_in_tree():
			(hint as Button).pressed.emit()
	await get_tree().process_frame


func _save(name: StringName) -> void:
	var image: Image = get_tree().root.get_texture().get_image()
	image.save_png("%s/%s.png" % [ProjectSettings.globalize_path(_out), String(name).replace(":", "_")])


## Other production pages (woodwright, riftbinding) and the blueprint page of the forge, with some stock in the Deposit.
func _prof_shots(session: GameSession, host: PageHost) -> void:
	for skill_id: StringName in [&"woodwright", &"riftbinding"]:
		TestFactory.learn_discipline(session, skill_id)
		for action: ActionDef in session.data.actions_for_skill(skill_id).slice(0, 8):
			for input: ItemQty in action.inputs:
				TestFactory.give(session, input.item_id, 6)
		host.show_page(StringName("skill:%s" % skill_id))
		await _frames(8)
		_save(StringName("prof_%s" % skill_id))
	TestFactory.set_level(session, &"forging", 32)  # recipes of the four colours; the plates of tier 2+ are schemes (locked)
	host.show_page(&"skill:forging")
	await _frames(8)
	_save(&"prof_forging_colors")
	var locked: Node = host.find_child("Row_forge_ashlead_plate", true, false)
	if locked is Button:
		(locked as Button).pressed.emit()
		await _frames(6)
		_save(&"prof_forging_scheme")
	var entry: Node = host.find_child("Page_blueprints", true, false)
	if entry is Button:
		(entry as Button).pressed.emit()
		await _frames(6)
		_save(&"prof_blueprints")


## Mercante tab of the Forging page: a known scheme, a bought one still to learn, a buyable one, a locked one, the reagents.
func _merchant_shots(session: GameSession, host: PageHost) -> void:
	session.wallet.add_gold(50000)
	session.shop.buy_many(&"buy_recipe_forge_ashlead_plate", 1)
	session.disciplines.learn_recipe(&"recipe_forge_ashlead_plate")
	session.shop.buy_many(&"buy_recipe_forge_stormzinc_plate", 1)
	session.shop.buy_many(&"buy_reagent_forging_1", 10)
	host.show_page(&"skill:forging")
	await _frames(6)
	var entry: Node = host.find_child("Page_merchant", true, false)
	if entry is Button:
		(entry as Button).pressed.emit()
		await _frames(6)
		_save(&"merchant_forging")
		session.wallet.spend(session.wallet.get_gold() - 5)
		var scroll: ScrollContainer = host.find_child("DetailScroll", true, false) as ScrollContainer
		scroll.scroll_vertical = 100000
		await _frames(6)
		_save(&"merchant_forging_reagents")
