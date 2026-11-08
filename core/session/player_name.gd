class_name PlayerName
extends RefCounted
## Renaming of the player (docs/01_GDD.md §1): the name belongs to the session but the rule lives here, so GameSession
## stays pure composition. The caller saves the slot afterwards (`Game.save_now`).

const GameScript := preload("res://core/autoload/game.gd")


## Sets `session.player_name` to `new_name` stripped of its edges. The length must be within player_name.min_length-
## max_length of balance.json (invalid_name, nothing changes).
static func rename(session: GameSession, new_name: String) -> CommandResult:
	var clean_name: String = new_name.strip_edges()
	var min_length: int = int(session.data.balance_value(GameScript.NAME_MIN_LENGTH_KEY))
	var max_length: int = int(session.data.balance_value(GameScript.NAME_MAX_LENGTH_KEY))
	if clean_name.length() < min_length or clean_name.length() > max_length:
		return CommandResult.fail(Reasons.INVALID_NAME)
	session.player_name = clean_name
	return CommandResult.success()
