extends GutTest
## Tooltips (M1-16): `show_item` with fixture items produces the expected lines (labels and formats from the stat
## registry, names from the data), `show_text`, `hide_tooltip`, placement inside the viewport.
## The `Tooltips` autoload is used with the fixture GameData injected through `data` (restored after each test).

const FIXTURE_CONTENT := "res://tests/fixtures/data"
const CONFIG := "res://data/config"
## Idle frames the tooltip needs to place itself: deferred call, then one process frame, then a spare one.
const PLACEMENT_FRAMES: int = 3

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
		"Spada di prova", "Equipaggiamento  ·  Quantità: 3"]))
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray([
		"Richiede il livello 1 del personaggio",
		"Stile Lama, un attacco ogni 2,4 s",
		"Precisione +8",
		"Potenza +6",
		"Valore: 12 oro",
	]))
	assert_eq(_tooltip.footer_text().strip_edges(), "Spada a una mano per i test.")


func test_show_item_tool_shows_pct_and_skill_scope() -> void:
	_show_item(&"unique_hatchet", 1)
	assert_eq(_lines(_tooltip.body_text()), PackedStringArray([
		"Velocità delle azioni -5% (Raccolta di prova)",
		"Non vendibile",  # a unique tool (M10): no value, never sold
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
	_show_item(&"unique_hatchet", 1)
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
	_show_item(&"unique_hatchet", 3)
	Tooltips.hide_tooltip()
	assert_false(_tooltip.is_shown())
	assert_false(_tooltip.visible)
	assert_eq(_tooltip.title_text(), "")
	assert_eq(_tooltip.body_text(), "")
	assert_eq(_tooltip.footer_text(), "")


func test_hide_before_placement_keeps_it_hidden() -> void:
	_show_item(&"unique_hatchet", 3)
	Tooltips.hide_tooltip()
	await _process_frames(3)
	assert_false(_tooltip.visible)


func test_tooltip_is_clamped_inside_viewport() -> void:
	Tooltips.show_item(_data.item(&"unique_hatchet"), 1, Vector2(100000, 100000))
	# Placement = a deferred call plus one process frame (CustomTooltip._resize_and_place): wait for idle frames, not
	# for physics frames, whose count per rendered frame varies (this made the test intermittent).
	await _process_frames(PLACEMENT_FRAMES)
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


func _process_frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func test_modifiers_of_the_same_stat_are_summed_in_one_line() -> void:
	var mods: Array[Modifier] = [Modifier.make(&"power_bonus", 2.0), Modifier.make(&"damage_reduction", 3.0),
			Modifier.make(&"power_bonus", 5.0)]
	var lines: PackedStringArray = ItemTooltipLines.modifier_lines(mods, _data)
	assert_eq(lines.size(), 2, "one line per stat")
	assert_string_contains(lines[0], ItemTooltipLines.format_stat("flat", 7.0))


func test_colored_title_uses_the_given_color() -> void:
	var text: String = ItemTooltipLines.colored_title("Lama [x]", UiStyle.rarity_color(&"rare"))
	assert_string_contains(text, UiStyle.RARITY_RARE.to_html(false))
	assert_string_contains(text, "Lama [lb]x]")
