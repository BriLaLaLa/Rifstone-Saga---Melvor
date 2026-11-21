extends GutTest
## Mail data (docs/04_DATA_SCHEMA_M27.md §32.5): the text models, `mail.capacity` and the validator rejections.

const BALANCE: String = "balance.json"
const V: String = "res://tests/core/data/test_data_validator.gd"


func _expect(raw: Dictionary, parts: Array) -> void:
	var errors: PackedStringArray = []
	DataValidator.validate(raw, errors)
	var found: bool = false
	for e: String in errors:
		var all: bool = true
		for part: String in parts:
			all = all and e.contains(part)
		found = found or all
	assert_true(found, "expected an error with %s, got %s" % [str(parts), str(errors)])


func _raw() -> Dictionary:
	return load(V).fixture_raw() as Dictionary


func _templates(raw: Dictionary) -> Array:
	return load(V).file_of(raw, "mail", "templates.json")["templates"] as Array


func test_real_data_has_a_model_for_every_kind() -> void:
	var data: GameData = TestFactory.real_data()
	for kind: StringName in MailBox.KINDS:
		var list: Array[MailTemplateDef] = data.mail_templates(kind)
		assert_gt(list.size(), 0, String(kind))
		for def: MailTemplateDef in list:
			assert_eq(def.kind, kind)
			assert_false(def.subject.is_empty())
	assert_eq(data.mail_templates(&"nothing").size(), 0)


func test_the_accessor_keeps_file_order() -> void:
	var list: Array[MailTemplateDef] = TestFactory.real_data().mail_templates(&"auction_sold")
	assert_eq(list.size(), 2)
	assert_ne(list[0].subject, list[1].subject)


func test_fixture_data_is_valid_and_has_the_capacity() -> void:
	var data: GameData = TestFactory.fixture_data()
	assert_eq(int(data.balance_value("mail.capacity")), 50)
	assert_eq(data.mail_templates(&"auction_sale").size(), 1)


func test_unknown_kind_is_an_error() -> void:
	var raw: Dictionary = _raw()
	(_templates(raw)[0] as Dictionary)["kind"] = "gift"
	_expect(raw, ["templates.json", "kind"])


func test_a_kind_without_models_is_an_error() -> void:
	var raw: Dictionary = _raw()
	var list: Array = _templates(raw)
	for i: int in range(list.size() - 1, -1, -1):
		if (list[i] as Dictionary)["kind"] == "auction_cancelled":
			list.remove_at(i)
	_expect(raw, ["templates.json", "no template of kind 'auction_cancelled'"])


func test_unknown_placeholder_is_an_error() -> void:
	var raw: Dictionary = _raw()
	(_templates(raw)[0] as Dictionary)["body"] = "Ciao {player}"
	_expect(raw, ["templates.json", "placeholder"])


func test_unbalanced_braces_are_an_error() -> void:
	var raw: Dictionary = _raw()
	(_templates(raw)[0] as Dictionary)["subject"] = "Ciao {item"
	_expect(raw, ["templates.json", "placeholder"])
	raw = _raw()
	(_templates(raw)[0] as Dictionary)["subject"] = "Ciao item}"
	_expect(raw, ["templates.json", "unbalanced"])


func test_too_long_texts_are_an_error() -> void:
	var raw: Dictionary = _raw()
	(_templates(raw)[0] as Dictionary)["body"] = "x".repeat(DataValidatorMail.BODY_MAX + 1)
	_expect(raw, ["templates.json", "body", "at most 240"])
	raw = _raw()
	(_templates(raw)[0] as Dictionary)["subject"] = "x".repeat(DataValidatorMail.SUBJECT_MAX + 1)
	_expect(raw, ["templates.json", "subject", "at most 60"])


func test_empty_sender_is_an_error() -> void:
	var raw: Dictionary = _raw()
	(_templates(raw)[0] as Dictionary)["sender"] = ""
	_expect(raw, ["templates.json", "sender"])


func test_capacity_zero_or_missing_is_an_error() -> void:
	var raw: Dictionary = _raw()
	(load(V).file_of(raw, "balance", BALANCE)["mail"] as Dictionary)["capacity"] = 0
	_expect(raw, [BALANCE, "mail.capacity"])
	raw = _raw()
	load(V).file_of(raw, "balance", BALANCE).erase("mail")
	_expect(raw, [BALANCE, "missing key 'mail'"])


func test_the_tutorial_kinds_are_accepted_and_have_models() -> void:
	assert_true(DataValidatorMail.KINDS.has("tutorial_gift") and DataValidatorMail.KINDS.has("starter_reward"))
	assert_true(MailBox.KINDS.has(&"tutorial_gift") and MailBox.KINDS.has(&"starter_reward"))
	for kind: StringName in [&"tutorial_gift", &"starter_reward"]:
		assert_gte(TestFactory.fixture_data().mail_templates(kind).size(), 1, String(kind))
