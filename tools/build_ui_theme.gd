extends SceneTree
## Regenerates the global UI theme from UiStyle.build_theme() into UiStyle.THEME_PATH.
## Usage: godot --headless --path . -s tools/build_ui_theme.gd
## Exit code 0 on success, 1 if the theme cannot be saved (the error is reported with push_error).


func _init() -> void:
	var theme: Theme = UiStyle.build_theme()
	var err: Error = ResourceSaver.save(theme, UiStyle.THEME_PATH)
	if err != OK:
		push_error("build_ui_theme: cannot save %s (error %d)" % [UiStyle.THEME_PATH, err])
		quit(1)
		return
	quit(0)
