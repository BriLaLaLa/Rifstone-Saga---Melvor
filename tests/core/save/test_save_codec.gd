extends GutTest
## SaveCodec: tab-indented JSON with sorted keys, decode returns {} for anything that is not a JSON object.


func test_encode_sorts_keys_and_indents_with_tabs() -> void:
	var text: String = SaveCodec.encode({"b": 1, "a": {"d": 2, "c": 3}})
	assert_eq(text, "{\n\t\"a\": {\n\t\t\"c\": 3,\n\t\t\"d\": 2\n\t},\n\t\"b\": 1\n}")


func test_encode_same_state_gives_same_text() -> void:
	var first: Dictionary = {"z": [1, 2], "m": "x", "a": true}
	var second: Dictionary = {"a": true, "m": "x", "z": [1, 2]}
	assert_eq(SaveCodec.encode(first), SaveCodec.encode(second))


func test_decode_round_trip() -> void:
	var d: Dictionary = {"format_version": 1, "player_name": "Davide", "modules": {"wallet": {"gold": 1250}}}
	var back: Dictionary = SaveCodec.decode(SaveCodec.encode(d))
	assert_eq(back["player_name"], "Davide")
	assert_eq(int(back["modules"]["wallet"]["gold"]), 1250)


func test_decode_numbers_arrive_as_float() -> void:
	var back: Dictionary = SaveCodec.decode("{\"saved_at_unix_ms\": 1793603600000}")
	assert_typeof(back["saved_at_unix_ms"], TYPE_FLOAT)
	assert_eq(int(back["saved_at_unix_ms"]), 1793603600000, "ms timestamps fit a double exactly")


func test_decode_invalid_json_returns_empty() -> void:
	assert_eq(SaveCodec.decode("{\"format_version\": 1,"), {})


func test_decode_empty_text_returns_empty() -> void:
	assert_eq(SaveCodec.decode(""), {})


func test_decode_non_dictionary_root_returns_empty() -> void:
	assert_eq(SaveCodec.decode("[1, 2, 3]"), {})
	assert_eq(SaveCodec.decode("42"), {})
