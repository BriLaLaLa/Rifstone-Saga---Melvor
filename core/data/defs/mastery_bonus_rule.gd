class_name MasteryBonusRule
extends RefCounted
## One rule of `mastery_bonuses` in skills.json (docs/04_DATA_SCHEMA.md §4, F-11).
##
## A rule has `every_levels` or `at_level` (the absent one is 0) and `modifiers`. Having neither is a conversion
## error; having both is left to DataValidator (M1-04). The schema says the modifiers' `scope` is ignored here:
## it is dropped and the modifiers are built global, as placeholders. MasterySystem applies them with scope
## `action:<action_id>` (and the F-11 multiplier) when it registers the `mastery_item:<action_id>` source.
## `from_dict` returns null (after logging, see DefReader) if a field is missing or mistyped.

var every_levels: int = 0
var at_level: int = 0
var modifiers: Array[Modifier] = []


static func from_dict(d: Dictionary) -> MasteryBonusRule:
	var r := DefReader.new(d, "mastery bonus rule")
	var def := MasteryBonusRule.new()
	if r.has("every_levels"):
		def.every_levels = r.integer("every_levels")
	if r.has("at_level"):
		def.at_level = r.integer("at_level")
	if not r.has("every_levels") and not r.has("at_level"):
		r.fail("needs 'every_levels' or 'at_level'")
	def.modifiers = r.modifiers("modifiers", String(Modifier.SCOPE_GLOBAL), true)
	return def if r.ok else null
