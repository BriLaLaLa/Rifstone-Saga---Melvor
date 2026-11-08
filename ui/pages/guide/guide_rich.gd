class_name GuideRich
extends RefCounted
## BBCode of the Guide: placeholders resolved by GuideText, `{link:…}` and known names turned into `[url]` links whose
## meta is the canonical entry id (GuideIndex.entry). Pure text conversion; no state.

const LEFT_BRACKET_ESCAPE: String = "[lb]"
const CELL_SEPARATOR: String = ", "


## `[url=<entry>]label[/url]` in the link colour.
static func link(entry_id: StringName, label: String) -> String:
	return "[url=%s][color=#%s]%s[/color][/url]" % [entry_id, UiStyle.GOLD.to_html(false), escape(label)]


static func escape(text: String) -> String:
	return text.replace("[", LEFT_BRACKET_ESCAPE)


## A text block: `{balance}`/`{stat}` replaced by the data, `{link:kind:id|label}` turned into a link.
static func text_to_bbcode(text: String, data: GameData) -> String:
	var result: String = ""
	var cursor: int = 0
	for found: Dictionary in GuideText.parse_links(text):
		var start: int = int(found["start"])
		result += escape(GuideText.resolve(text.substr(cursor, start - cursor), data))
		result += link(GuideIndex.entry(StringName(str(found["kind"])), StringName(str(found["id"]))),
				str(found["label"]))
		cursor = int(found["end"])
	return result + escape(GuideText.resolve(text.substr(cursor), data))


## A table cell: each ", "-separated part that is the exact title of an entry (optionally after a quantity such as
## "3 ") becomes a link; the rest stays text.
static func cell_to_bbcode(cell: String, nav: GuideNav) -> String:
	var parts: PackedStringArray = []
	for part: String in cell.split(CELL_SEPARATOR):
		parts.append(_part_to_bbcode(part, nav))
	return CELL_SEPARATOR.join(parts)


static func _part_to_bbcode(part: String, nav: GuideNav) -> String:
	var whole: StringName = nav.entry_by_name(part)
	if whole != &"":
		return link(whole, part)
	var space: int = part.find(" ")
	if space > 0 and part.substr(0, space).is_valid_int():
		var rest: StringName = nav.entry_by_name(part.substr(space + 1))
		if rest != &"":
			return escape(part.substr(0, space + 1)) + link(rest, part.substr(space + 1))
	return escape(part)
