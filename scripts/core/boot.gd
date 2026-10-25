extends Node
## Autoload: sets up what every scene needs before it runs.


func _enter_tree() -> void:
	InputSetup.apply()
