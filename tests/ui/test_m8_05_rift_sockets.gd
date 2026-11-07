extends GutTest
## M8-05: Altar of the Rift page, sockets of the piece panel, Rift currencies, "Incastona" of the bank item panel and the
## sidebar entry. Fixture content (test_infusion, test_stone, test_currency*, test_blade) with the real config plus the
## `sockets` section of docs/02_FORMULAS.md F-89 (the real balance.json has none yet, as in test_sockets.gd).

const RIFT_SCENE: PackedScene = preload("res://ui/pages/rift/rift_page.tscn")
const EQUIP_SCENE: PackedScene = preload("res://ui/pages/equipment/equipment_page.tscn")
const BANK_SCENE: PackedScene = preload("res://ui/pages/bank/bank_page.tscn")
const INF: StringName = &"test_infusion"
const STONE: StringName = &"test_stone"
const STONE_B: StringName = &"test_stone_b"
const TO_MAGIC: StringName = &"test_currency"
const REROLL: StringName = &"test_currency_reroll"
const BLADE: StringName = &"test_blade"
const CONFIG_ROOT: String = "res://data/config"
const PreRun := preload("res://tests/helpers/gut_pre_run.gd")

var _tmp_config: String = PreRun.test_dir("test_m8_05").path_join("config")
var _data: GameData = null
var _session: GameSession = null
var _page: Node = null


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_config)
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_ROOT.path_join("balance.json")))
	balance["sockets"] = {"by_rarity": {"common": 0, "magic": 1, "rare": 2}, "bonus_at_upgrade": 7}
	_write(_tmp_config.path_join("balance.json"), JSON.stringify(balance))
	_write(_tmp_config.path_join("stats.json"), FileAccess.get_file_as_string(CONFIG_ROOT.path_join("stats.json")))
	_data = GameData.load_from_dirs(TestFactory.FIXTURE_CONTENT_ROOT, _tmp_config)
	assert_true(_data.is_valid(), str(_data.errors))


func after_all() -> void:
	for file: String in ["balance.json", "stats.json"]:
		DirAccess.remove_absolute(_tmp_config.path_join(file))
	DirAccess.remove_absolute(_tmp_config)
	DirAccess.remove_absolute(_tmp_config.get_base_dir())


func before_each() -> void:
	_session = TestFactory.session(11, _data)


func after_each() -> void:
	if is_instance_valid(_page):
		_page.free()
	if is_instance_valid(_session):
		_session.free()
	await wait_physics_frames(1)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _open(scene: PackedScene, id: StringName) -> void:
	_page = scene.instantiate()
	_page.page_id = id
	add_child(_page)
	_page.bind(_session)


func _press(root: Node, node_name: String) -> void:
	var button: Button = root.find_child(node_name, true, false) as Button
	assert_not_null(button, node_name)
	if button != null:
		button.pressed.emit()


func _text(root: Node, node_name: String) -> String:
	var node: Node = root.find_child(node_name, true, false)
	return (node as Label).text if node is Label else (node as RichTextLabel).text


# --- Altar page -----------------------------------------------------------------------------------------------

func test_altar_shows_five_sockets_locked_free_and_the_unlock_level() -> void:
	_open(RIFT_SCENE, &"rift")
	for i: int in 5:
		assert_not_null(_page.find_child("Socket%d" % i, true, false), "socket %d" % i)
	assert_not_null(_page.find_child("SocketButton", true, false), "socket 0 is free")
	assert_string_contains(_text(_page.find_child("Socket1", true, false), "StateText"), "livello 20")
	assert_string_contains(_text(_page.find_child("Socket4", true, false), "StateText"), "livello 80")
	assert_string_contains(_text(_page, "SummaryText"), RiftTexts.SUMMARY_NONE_TEXT)


func test_socketing_from_the_bank_and_the_summary() -> void:
	TestFactory.give(_session, INF, 2)
	_open(RIFT_SCENE, &"rift")
	_press(_page, "SocketButton")
	_press(_page, "Pick_%s" % INF)
	assert_eq(_session.rift.get_socket(0), INF)
	assert_eq(_session.bank.get_count(INF), 1)
	assert_not_null(_page.find_child("RemoveButton", true, false))
	assert_string_contains(_text(_page, "SummaryText"), "-3")


func test_socket_picker_without_infusions_says_so() -> void:
	_open(RIFT_SCENE, &"rift")
	_press(_page, "SocketButton")
	assert_eq(_text(_page, "NoInfusions"), RiftTexts.NO_INFUSIONS_TEXT)


func test_remove_needs_a_confirmation_and_destroys() -> void:
	TestFactory.give(_session, INF, 1)
	_session.rift.socket(0, INF)
	_open(RIFT_SCENE, &"rift")
	_press(_page, "RemoveButton")
	assert_eq(_session.rift.get_socket(0), INF, "not yet")
	_press(_page, "CancelRemoveButton")
	assert_eq(_session.rift.get_socket(0), INF)
	_press(_page, "RemoveButton")
	_press(_page, "ConfirmRemoveButton")
	assert_eq(_session.rift.get_socket(0), &"")
	assert_eq(_session.bank.get_count(INF), 0, "destroyed, not returned")


func test_unique_infusion_refusal_is_shown_in_italian() -> void:
	TestFactory.give(_session, INF, 2)
	TestFactory.set_level(_session, &"riftbinding", 20)
	_session.rift.socket(0, INF)
	_open(RIFT_SCENE, &"rift")
	_press(_page, "SocketButton")
	_press(_page, "Pick_%s" % INF)
	assert_eq(_session.rift.get_socket(1), &"")
	var message: Label = _page.find_child("MessageLabel", true, false) as Label
	assert_true(message.visible)
	assert_eq(message.text, RiftTexts.refused(Reasons.REQUIREMENT_NOT_MET))


func test_altar_reacts_to_events_and_unbind_disconnects() -> void:
	_open(RIFT_SCENE, &"rift")
	TestFactory.give(_session, INF, 1)
	_session.rift.socket(0, INF)
	assert_not_null(_page.find_child("RemoveButton", true, false), "redrawn by infusion_socketed")
	_page.unbind()
	assert_false(_session.events.infusion_socketed.is_connected(_page._redraw_from_event))
	assert_false(_session.events.bank_changed.is_connected(_page._redraw_from_event))


func test_sidebar_and_host_have_the_altar_route() -> void:
	assert_true(PageHost.ROUTES.has(&"rift"))
	var pages: Array[StringName] = []
	for section: Dictionary in Sidebar.SECTIONS:
		pages.append(section["page"] as StringName)
	assert_true(pages.has(&"rift"))


# --- Piece panel: sockets and currencies -----------------------------------------------------------------------

func _select_piece(rarity: StringName) -> int:
	var uid: int = TestFactory.give_piece(_session, BLADE, rarity)
	_open(EQUIP_SCENE, &"equipment")
	_page._select(uid)
	return uid


func test_piece_without_sockets_says_so() -> void:
	_select_piece(&"common")
	assert_eq(_text(_page, "NoSockets"), SocketTexts.NO_SOCKETS_TEXT)


func test_piece_socket_a_stone_then_remove_with_confirmation() -> void:
	TestFactory.give(_session, STONE, 1)
	var uid: int = _select_piece(&"magic")
	_press(_page, "SocketButton")
	assert_eq(_session.armory.get_instance(uid).sockets, [STONE] as Array[StringName])
	assert_eq(_session.bank.get_count(STONE), 0)
	assert_string_contains(_text(_page, "StoneLabel"), "Pietra di prova")
	_press(_page, "RemoveButton")
	assert_eq(_session.armory.get_instance(uid).sockets.size(), 1, "waits for the confirmation")
	_press(_page, "ConfirmRemoveButton")
	assert_eq(_session.armory.get_instance(uid).sockets.size(), 0)
	assert_eq(_session.bank.get_count(STONE), 0, "destroyed")


func test_inactive_stone_is_marked_grey() -> void:
	TestFactory.give(_session, STONE, 1)
	var uid: int = _select_piece(&"magic")
	_session.armory.socket_stone(uid, STONE)
	# The save format keeps a stone beyond the active sockets (a refinement lost): force it with a second stone.
	var saved: Dictionary = _session.armory.to_save()
	for entry: Dictionary in saved["items"]:
		entry["sockets"] = [String(STONE), String(STONE_B)]
	_session.armory.from_save(saved)
	_page._redraw()
	var labels: Array[Node] = _page.find_children("StoneLabel", "Label", true, false)
	assert_eq(labels.size(), 2)
	assert_string_contains((labels[1] as Label).text, SocketTexts.INACTIVE_TEXT)
	assert_false((labels[0] as Label).text.contains(SocketTexts.INACTIVE_TEXT))


func test_stone_without_free_socket_refusal_is_shown() -> void:
	TestFactory.give(_session, STONE, 2)
	var uid: int = _select_piece(&"magic")
	_session.armory.socket_stone(uid, STONE)
	_page._on_panel_armory_command(_session.armory.socket_stone.bind(uid, STONE))
	var message: Label = _page.find_child("MessageLabel", true, false) as Label
	assert_true(message.visible)
	assert_eq(message.text, SocketTexts.refused(Reasons.SOCKET_OCCUPIED))


func test_currency_preview_and_use() -> void:
	TestFactory.give(_session, TO_MAGIC, 1)
	var uid: int = _select_piece(&"common")
	assert_string_contains(_text(_page, "Preview"), "diventa magico")
	assert_string_contains(_text(_page, "Preview"), SocketTexts.FITS_TEXT)
	_press(_page, "UseButton")
	assert_eq(_session.armory.get_instance(uid).rarity, &"magic")
	assert_eq(_session.bank.get_count(TO_MAGIC), 0)


func test_currency_not_fitting_is_flagged_and_refusal_shown() -> void:
	TestFactory.give(_session, TO_MAGIC, 1)
	var uid: int = _select_piece(&"magic")
	assert_string_contains(_text(_page, "Preview"), "Non adatta")
	_press(_page, "UseButton")
	assert_eq(_session.armory.get_instance(uid).rarity, &"magic")
	assert_eq(_session.bank.get_count(TO_MAGIC), 1, "nothing spent")
	assert_eq((_page.find_child("MessageLabel", true, false) as Label).text,
			SocketTexts.refused(Reasons.REQUIREMENT_NOT_MET))


func test_reroll_asks_for_confirmation() -> void:
	TestFactory.give(_session, REROLL, 1)
	var uid: int = _select_piece(&"magic")
	_press(_page, "UseButton")
	assert_eq(_session.bank.get_count(REROLL), 1, "first press only asks")
	assert_string_contains((_page.find_child("UseButton", true, false) as Button).text, "Conferma")
	assert_not_null(_page.find_child("Warning", true, false))
	_press(_page, "UseButton")
	assert_eq(_session.bank.get_count(REROLL), 0)
	assert_gt(_session.armory.get_instance(uid).affixes.size(), 0, "affixes rolled again")


func test_no_currencies_hint() -> void:
	_select_piece(&"common")
	assert_eq(_text(_page, "NoCurrencies"), SocketTexts.NO_CURRENCIES_TEXT)


func test_script_sizes_stay_under_the_limit() -> void:
	for path: String in ["res://ui/pages/equipment/equipment_page.gd", "res://ui/pages/bank/bank_page.gd",
			"res://ui/pages/rift/rift_page.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		assert_lt(file.get_as_text().count("\n"), 400, path)


# --- Bank item panel -------------------------------------------------------------------------------------------

func test_bank_infusion_goes_to_the_first_free_socket() -> void:
	TestFactory.give(_session, INF, 1)
	_open(BANK_SCENE, &"bank")
	var panel: BankItemPanel = _page.get_node("%ItemPanel") as BankItemPanel
	panel.show_item(_session, INF)
	_press(panel, "InfusionButton")
	assert_eq(_session.rift.get_socket(0), INF)
	TestFactory.give(_session, INF, 1)
	panel.show_item(_session, INF)
	_press(panel, "InfusionButton")
	assert_eq((_page.find_child("MessageLabel", true, false) as Label).text, RiftTexts.NO_FREE_SOCKET_TEXT)


func test_bank_stone_goes_to_the_chosen_piece() -> void:
	TestFactory.give(_session, STONE, 1)
	var uid: int = TestFactory.give_piece(_session, BLADE, &"magic")
	_open(BANK_SCENE, &"bank")
	var panel: BankItemPanel = _page.get_node("%ItemPanel") as BankItemPanel
	panel.show_item(_session, STONE)
	_press(panel, "StoneButton")
	assert_eq(_session.armory.get_instance(uid).sockets, [STONE] as Array[StringName])


func test_bank_stone_without_pieces_and_plain_item_has_no_section() -> void:
	TestFactory.give(_session, STONE, 1)
	_open(BANK_SCENE, &"bank")
	var panel: BankItemPanel = _page.get_node("%ItemPanel") as BankItemPanel
	panel.show_item(_session, STONE)
	assert_eq(_text(panel, "NoPieces"), SocketTexts.BANK_NO_PIECES_TEXT)
	TestFactory.give(_session, TO_MAGIC, 1)
	panel.show_item(_session, TO_MAGIC)
	assert_false((panel.find_child("SocketBox", true, false) as Control).visible)
