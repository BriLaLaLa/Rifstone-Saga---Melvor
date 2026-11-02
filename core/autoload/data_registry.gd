extends Node
## Data registry (autoload `DataRegistry`): loads and holds the read-only GameData from res://data.
##
## Stub of task M0-03 with the final signatures; the real loading arrives with M1-04.

# Contract type is GameData (core/data/game_data.gd, task M1-04). That class does not exist yet,
# so the variable is typed with its base class RefCounted until it does.
var data: RefCounted = null


func reload() -> bool:
	return false
