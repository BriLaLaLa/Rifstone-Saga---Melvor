extends GutTest
## GuideText (M11-02): resolve, parse_links, validate/check (docs/04_DATA_SCHEMA.md §19, docs/05_INTERFACES.md §5.19).

var _data: GameData


func before_all() -> void:
	_data = TestFactory.fixture_data()


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for message: String in errors:
		if message.contains(fragment):
			return true
	return false


func test_resolve_balance_formats() -> void:
	assert_eq(GuideText.resolve("{balance:offline.cap_ms|ore}", _data), "12")
	assert_eq(GuideText.resolve("{balance:offline.min_ms|min}", _data), "1")
	var respawn: float = float(_data.balance_value("combat.respawn_ms"))
	assert_eq(GuideText.resolve("{balance:combat.respawn_ms|sec}", _data), GuideText.format_number(respawn / 1000.0))
	assert_eq(GuideText.resolve("{balance:bank.base_slots|int}", _data), str(int(_data.balance_value("bank.base_slots"))))
	var pct: float = float(_data.balance_value("rarity.drop.magic_pct"))
	assert_eq(GuideText.resolve("{balance:rarity.drop.magic_pct|pct}", _data), GuideText.format_number(pct) + "%")


func test_resolve_stat_parts() -> void:
	var info: Dictionary = _data.stats.info(&"skill_xp_pct")
	assert_eq(GuideText.resolve("{stat:skill_xp_pct}", _data), info["name"])
	assert_eq(GuideText.resolve("{stat:skill_xp_pct|desc}", _data), info["description"])
	assert_eq(GuideText.resolve("{stat:skill_xp_pct|min}", _data), GuideText.format_number(float(info["min"])))
	assert_eq(GuideText.resolve("{stat:skill_xp_pct|max}", _data), GuideText.format_number(float(info["max"])))


func test_resolve_link_keeps_only_the_text() -> void:
	assert_eq(GuideText.resolve("Vai a {link:item:test_twig|Rametto}, poi {link:page:test_guide_start|qui}.", _data),
			"Vai a Rametto, poi qui.")


func test_resolve_plain_text_is_unchanged() -> void:
	assert_eq(GuideText.resolve("Nessun segnaposto.", _data), "Nessun segnaposto.")


func test_resolve_unknown_stat_logs_and_keeps_the_placeholder() -> void:
	assert_eq(GuideText.resolve("x {stat:nope} y", _data), "x {stat:nope} y")
	assert_push_error("cannot resolve '{stat:nope}'")


func test_resolve_unknown_balance_path_logs_and_keeps_the_placeholder() -> void:
	assert_eq(GuideText.resolve("{balance:no.such.key|int}", _data), "{balance:no.such.key|int}")
	assert_push_error("balance key 'no.such.key' not found")
	assert_push_error("cannot resolve")


func test_parse_links_gives_kind_id_label_and_positions() -> void:
	var text: String = "ab {link:item:test_twig|Rametto} cd {link:stat:skill_xp_pct|XP}"
	var links: Array[Dictionary] = GuideText.parse_links(text)
	assert_eq(links.size(), 2)
	assert_eq([links[0]["kind"], links[0]["id"], links[0]["label"]], ["item", "test_twig", "Rametto"])
	assert_eq(text.substr(int(links[0]["start"]), int(links[0]["end"]) - int(links[0]["start"])),
			"{link:item:test_twig|Rametto}")
	assert_eq([links[1]["kind"], links[1]["id"], links[1]["label"]], ["stat", "skill_xp_pct", "XP"])
	assert_eq(GuideText.parse_links("niente"), [] as Array[Dictionary])


func test_validate_accepts_good_text() -> void:
	var text: String = "Fino a {balance:offline.cap_ms|ore} ore, {stat:skill_xp_pct}, {link:area:test_area|area}."
	assert_eq(GuideText.validate(text, _data, false), PackedStringArray())


func test_validate_reports_unknown_placeholder_type() -> void:
	assert_true(_has_error(GuideText.validate("{color:red}", _data, false), "unknown placeholder"))


func test_validate_reports_unknown_format() -> void:
	assert_true(_has_error(GuideText.validate("{balance:offline.cap_ms|days}", _data, false), "malformed"))
	assert_true(_has_error(GuideText.validate("{balance:offline.cap_ms}", _data, false), "malformed"))


func test_validate_reports_unknown_stat_part() -> void:
	assert_true(_has_error(GuideText.validate("{stat:skill_xp_pct|avg}", _data, false), "malformed"))


func test_validate_reports_unknown_stat() -> void:
	assert_true(_has_error(GuideText.validate("{stat:nope}", _data, false), "unknown stat 'nope'"))


func test_validate_reports_unknown_balance_path() -> void:
	assert_true(_has_error(GuideText.validate("{balance:no.such.key|int}", _data, false), "unknown balance path"))
	assert_push_error("balance key 'no.such.key' not found")


func test_validate_reports_unknown_link_kind_and_broken_link() -> void:
	assert_true(_has_error(GuideText.validate("{link:planet:x|y}", _data, false), "unknown link kind 'planet'"))
	assert_true(_has_error(GuideText.validate("{link:item:nope|y}", _data, false), "broken link"))
	assert_true(_has_error(GuideText.validate("{link:page:nope|y}", _data, false), "broken link"))
	assert_true(_has_error(GuideText.validate("{link:item:test_twig}", _data, false), "malformed"))


func test_validate_reports_hand_written_digits_unless_allowed() -> void:
	assert_true(_has_error(GuideText.validate("Al livello 10 succede.", _data, false), "digits written by hand"))
	assert_eq(GuideText.validate("Al livello 10 succede.", _data, true), PackedStringArray())


func test_digits_inside_placeholders_are_not_hand_written() -> void:
	assert_eq(GuideText.validate("{link:item:test_twig|Rametto 2}", _data, false), PackedStringArray())


func test_validate_reports_literal_braces() -> void:
	assert_true(_has_error(GuideText.validate("a { b", _data, false), "literal brace"))
	assert_true(_has_error(GuideText.validate("a } b", _data, false), "literal brace"))


func test_check_works_on_explicit_lookups() -> void:
	var lookups: Dictionary = {
		"balance": func(path: String) -> Variant: return 5.0 if path == "a.b" else null,
		"stat": func(_id: String) -> Dictionary: return {},
		"link": func(_kind: String, _id: String) -> bool: return false,
	}
	assert_eq(GuideText.check("{balance:a.b|int}", false, lookups), PackedStringArray())
	assert_true(_has_error(GuideText.check("{balance:a.c|int}", false, lookups), "unknown balance path"))
	assert_true(_has_error(GuideText.check("{link:item:x|y}", false, lookups), "broken link"))


func test_format_number() -> void:
	assert_eq(GuideText.format_number(12.0), "12")
	assert_eq(GuideText.format_number(1.5), "1.5")
	assert_eq(GuideText.format_number(0.25), "0.25")
