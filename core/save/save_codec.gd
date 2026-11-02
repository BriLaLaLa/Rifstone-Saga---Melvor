class_name SaveCodec
extends RefCounted
## Text form of a slot file: JSON indented with tabs and sorted keys, so two saves of the same state are identical.
##
## decode never fails loudly: invalid JSON or a non-dictionary root returns {} and the caller decides what that means.

const INDENT: String = "\t"


static func encode(d: Dictionary) -> String:
	return JSON.stringify(d, INDENT, true)


static func decode(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	var root: Variant = json.data
	if root is Dictionary:
		return root as Dictionary
	return {}
