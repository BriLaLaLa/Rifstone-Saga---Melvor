class_name SaveMigrator
extends RefCounted
## Save format versions: CURRENT_VERSION is the only definition of the format version written by this game.
##
## A file at version a is brought to CURRENT_VERSION by applying, in order, the scripts
## `migrations/migration_<a>_to_<a+1>.gd`, each with `static func migrate(d: Dictionary) -> Dictionary`.
## After each step format_version is set to the new version, so a migration does not have to do it.

const CURRENT_VERSION: int = 2
const FORMAT_VERSION_KEY: String = "format_version"
const MIGRATIONS_DIR: String = "res://core/save/migrations"
const MIGRATION_FILE: String = "migration_%d_to_%d.gd"
const MIGRATE_METHOD: StringName = &"migrate"
const LOG_CATEGORY: String = "save"


## True when the dictionary has an integral format_version not newer than CURRENT_VERSION.
static func can_load(d: Dictionary) -> bool:
	if not _has_format_version(d):
		return false
	return _format_version(d) <= CURRENT_VERSION


## Returns a migrated deep copy (the input is not changed), or {} if the chain cannot reach CURRENT_VERSION.
static func migrate(d: Dictionary) -> Dictionary:
	return migrate_chain(d, CURRENT_VERSION, _step_from_file)


## Brings d from its format_version to target_version; migrate() uses it with CURRENT_VERSION and the files in
## MIGRATIONS_DIR, tests with fake steps. step_for(from_version) returns the Callable that migrates from_version
## to from_version + 1, or an invalid Callable if there is none. Returns a deep copy (the input is not changed)
## with format_version = target_version, or {} if a step is missing or fails or d is newer than target_version.
static func migrate_chain(d: Dictionary, target_version: int, step_for: Callable) -> Dictionary:
	if not _has_format_version(d):
		Log.warn(LOG_CATEGORY, "cannot migrate: format_version missing or not an integer")
		return {}
	var version: int = _format_version(d)
	if version > target_version:
		Log.warn(LOG_CATEGORY, "cannot migrate: format_version %d is newer than %d" % [version, target_version])
		return {}
	var out: Dictionary = d.duplicate(true)
	out[FORMAT_VERSION_KEY] = version
	while version < target_version:
		var step: Callable = step_for.call(version)
		if not step.is_valid():
			Log.warn(LOG_CATEGORY, "no migration from format_version %d to %d" % [version, version + 1])
			return {}
		var migrated: Variant = step.call(out)
		if not migrated is Dictionary or (migrated as Dictionary).is_empty():
			Log.warn(LOG_CATEGORY, "migration from format_version %d failed" % version)
			return {}
		version += 1
		out = migrated as Dictionary
		out[FORMAT_VERSION_KEY] = version
	return out


static func _has_format_version(d: Dictionary) -> bool:
	var value: Variant = d.get(FORMAT_VERSION_KEY)
	if value is int:
		return true
	if value is float:
		var number: float = value as float
		return is_finite(number) and number == floorf(number)
	return false


static func _format_version(d: Dictionary) -> int:
	return int(d.get(FORMAT_VERSION_KEY, 0))


static func _step_from_file(from_version: int) -> Callable:
	var path: String = MIGRATIONS_DIR.path_join(MIGRATION_FILE % [from_version, from_version + 1])
	if not ResourceLoader.exists(path):
		return Callable()
	var script: GDScript = load(path) as GDScript
	if script == null:
		return Callable()
	return Callable(script, MIGRATE_METHOD)
