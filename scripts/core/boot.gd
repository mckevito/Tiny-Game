extends Node
## Autoload: sets up what every scene needs before it runs: this PC's settings (Settings), which also register the
## input actions with any remaps, and the reading font. Sound goes quiet while the game is in the background, unless Options says not to.


func _enter_tree() -> void:
	# The reading font for every control without a theme of its own (data/look.json "fonts").
	ThemeDB.fallback_font = UiLook.font("body")
	Settings.apply_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, (what == NOTIFICATION_APPLICATION_FOCUS_OUT and not Settings.value("background_sound"))
				or Settings.num("master") <= 0.0)
