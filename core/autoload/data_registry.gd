extends Node
## Data registry (autoload `DataRegistry`): loads and holds the read-only GameData from res://data.
##
## `data` is replaced on every `reload()`, also when the data is not valid, so that the UI can show `data.errors`
## and refuse to start a game (docs/03_ARCHITECTURE.md §10). Each error is logged as a warning, plus one error line.

const LOG_CATEGORY: String = "data"

var data: GameData = null


func _ready() -> void:
	reload()


## Loads res://data again; true if valid.
func reload() -> bool:
	data = GameData.load_from_dirs()
	if data.is_valid():
		Log.info(LOG_CATEGORY, "game data loaded")
		return true
	for message: String in data.errors:
		Log.warn(LOG_CATEGORY, message)
	Log.error(LOG_CATEGORY, "game data not valid (%d errors)" % data.errors.size())
	return false
