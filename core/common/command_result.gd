class_name CommandResult
extends RefCounted
## Outcome of a command: either success, or failure with a reason from Reasons.
##
## Commands never change state when they fail, so the caller only needs to inspect `ok` and `reason`.

var ok: bool = false
var reason: StringName = &""


static func success() -> CommandResult:
	var result: CommandResult = CommandResult.new()
	result.ok = true
	result.reason = &""
	return result


static func fail(reason: StringName) -> CommandResult:
	if reason == &"":
		push_error("CommandResult.fail: empty reason")
	var result: CommandResult = CommandResult.new()
	result.ok = false
	result.reason = reason
	return result
