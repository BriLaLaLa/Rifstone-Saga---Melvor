extends GutTest
## Tooltips (M1-16): `show_item` with fixture items produces the expected lines (labels and formats from the stat
## registry, names from the data), `show_text`, `hide_tooltip`, placement inside the viewport.
## The `Tooltips` autoload is used with the fixture GameData injected through `data` (restored after each test).

const FIXTURE_CONTENT := "res://tests/fixtures/data"
const CONFIG := "res://data/config"

var _data: GameData
var _tooltip: CustomTooltip


func before_all() -> void:
	_data = GameData.load_from_dirs(FIXTURE_CONTENT, CONFIG)


func before_each() -> void:
	assert_true(_data.is_valid(), "fixture data must be valid: %s" % ", ".join(_data.errors))
	Tooltips.data = _data
	Tooltips.hide_tooltip()
	_tooltip = Tooltips.get_node("TooltipLayer/CustomTooltip") as CustomTooltip


func after_each() -> void:
	Tooltips.hide_tooltip()
	Tooltips.data = null


func test_hidden_after_hide() -> void:
	assert_false(_tooltip.is_shown())
	assert_false(_tooltip.visible)


func test_show_item_weapon_lines() -> void:
	_show_item(&"test_blade", 3)
	assert_true(_tooltip.is_shown())
	assert_true(_tooltip.visible)
	assert_eq(_lines(_tooltip.title_text()), PackedStringArray([
		"Lama di prova", "Equipaggiamento  ·  Quantità: 3"]))
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray([
		"Richiede Lama livello 1",
		"Stile Lama, un attacco ogni 2,4 s",
		"Precisione +8",
		"Potenza +6",
		"Valore: 12 oro",
	]))
	assert_eq(_tooltip.footer_text().strip_edges(), "Arma a lama per i test.")


func test_show_item_tool_shows_pct_and_skill_scope() -> void:
	_show_item(&"test_hatchet", 1)
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray([
		"Richiede Raccolta di prova livello 1",
		"Velocità delle azioni -5% (Raccolta di prova)",
		"Valore: 10 oro",
	]))


func test_show_item_infusion_lines() -> void:
	_show_item(&"test_infusion", 2)
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray([
		"Velocità delle azioni -3%",
		"Unica: non si incastona in più prese",
		"Non vendibile",
	]))


func test_show_item_food_lines() -> void:
	_show_item(&"test_ration", 5)
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray(["Cura 20 punti vita", "Valore: 2 oro"]))


func test_show_item_quantity_uses_thousands_separator() -> void:
	_show_item(&"test_twig", 1250)
	assert_eq(_lines(_tooltip.title_text()), PackedStringArray(["Rametto di prova", "Materiale  ·  Quantità: 1.250"]))
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray(["Valore: 1 oro"]))


func test_show_item_without_count_has_no_quantity() -> void:
	_show_item(&"rift_shard", 0)
	assert_eq(_lines(_tooltip.title_text()), PackedStringArray(["Frammento del Rift", "Varie"]))
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray(["Non vendibile"]))


func test_show_item_null_hides_and_reports() -> void:
	_show_item(&"test_blade", 1)
	Tooltips.show_item(null, 1, Vector2.ZERO)
	assert_push_error("null item")
	assert_false(_tooltip.is_shown())


func test_show_text_title_and_body() -> void:
	Tooltips.show_text("Taglialegna", "Livello 12", Vector2(50, 50))
	assert_true(_tooltip.is_shown())
	assert_eq(_tooltip.title_text().strip_edges(), "Taglialegna")
	assert_eq(_tooltip.body_text().strip_edges(), "Livello 12")
	assert_eq(_tooltip.footer_text(), "")


func test_hide_tooltip_hides_and_clears() -> void:
	_show_item(&"test_blade", 3)
	Tooltips.hide_tooltip()
	assert_false(_tooltip.is_shown())
	assert_false(_tooltip.visible)
	assert_eq(_tooltip.title_text(), "")
	assert_eq(_tooltip.body_text(), "")
	assert_eq(_tooltip.footer_text(), "")


func test_hide_before_placement_keeps_it_hidden() -> void:
	_show_item(&"test_blade", 3)
	Tooltips.hide_tooltip()
	await wait_physics_frames(3)
	assert_false(_tooltip.visible)


func test_tooltip_is_clamped_inside_viewport() -> void:
	Tooltips.show_item(_data.item(&"test_blade"), 1, Vector2(100000, 100000))
	await wait_physics_frames(3)
	var screen: Rect2 = _tooltip.get_viewport_rect()
	var rect: Rect2 = _tooltip.get_global_rect()
	assert_true(screen.encloses(rect), "tooltip %s inside viewport %s" % [rect, screen])
	assert_eq(_tooltip.modulate.a, 1.0, "visible after placement")


func test_unregistered_stat_gets_no_line() -> void:
	var mods: Array[Modifier] = [Modifier.make(&"not_a_stat", 5.0), Modifier.make(&"power_bonus", 2.0)]
	assert_eq(ItemTooltipLines.modifier_lines(mods, _data).size(), 1, "only the registered stat has a line")


func test_stat_formats_follow_registry_format() -> void:
	assert_eq(ItemTooltipLines.format_stat("pct", 12.5), "+12,5%")
	assert_eq(ItemTooltipLines.format_stat("pct", -3.0), "-3%")
	assert_eq(ItemTooltipLines.format_stat("flat", 1500.0), "+1.500")
	assert_eq(ItemTooltipLines.format_stat("flag", 1.0), "Sì")
	assert_eq(ItemTooltipLines.format_stat("flag", 0.0), "No")


func test_item_without_data_hides_modifier_lines() -> void:
	var lines: PackedStringArray = ItemTooltipLines.body(_data.item(&"test_blade"), null)
	assert_eq(lines.size(), 1, "only the value line, no made-up labels")


func _show_item(item_id: StringName, count: int) -> void:
	Tooltips.show_item(_data.item(item_id), count, Vector2(40, 40))


## Non-empty lines of a parsed text, trimmed.
func _lines(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		if not line.strip_edges().is_empty():
			out.append(line.strip_edges())
	return out


## GameWindow (M1-16, ported with the tooltip): title bar built on `_ready`, open/close/toggle signals, first
## placement inside the parent. Kept here because test_tooltip.gd is the only test file of the task.
class TestGameWindow:
	extends GutTest

	var _host: Control
	var _window: GameWindow

	func before_each() -> void:
		_host = Control.new()
		_host.size = Vector2(1200, 700)
		add_child_autofree(_host)
		_window = GameWindow.new()
		_window.title = "Bank"
		var page := VBoxContainer.new()
		page.name = "VBox"
		_window.add_child(page)
		_host.add_child(_window)

	func test_ready_adds_title_bar_and_separator() -> void:
		var page: VBoxContainer = _window.get_node("VBox") as VBoxContainer
		assert_eq(String(page.get_child(0).name), "Header")
		assert_true(page.get_child(1) is HSeparator)
		var title_label: Label = page.get_child(0).get_child(0) as Label
		assert_eq(title_label.text, "BANK")
		assert_false(_window.visible, "starts closed")

	func test_toggle_opens_and_closes_with_signals() -> void:
		watch_signals(_window)
		_window.toggle()
		assert_true(_window.visible)
		assert_signal_emit_count(_window, "opened", 1)
		_window.toggle()
		assert_false(_window.visible)
		assert_signal_emit_count(_window, "closed", 1)
		_window.close_window()
		assert_signal_emit_count(_window, "closed", 1, "closing a closed window emits nothing")

	func test_first_open_fits_inside_parent() -> void:
		_window.open_window()
		var area: Rect2 = Rect2(Vector2.ZERO, _host.size)
		assert_true(area.encloses(Rect2(_window.position, _window.size)), "%s in %s" % [
			Rect2(_window.position, _window.size), area])
