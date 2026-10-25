class_name PlayerInput
extends RefCounted
## One player's share of the input devices, for couch play. Player one has the keyboard, the mouse and every
## controller that is not someone else's; a couch player has exactly one controller. Reads the bindings in
## data/input.json for those devices only, so a second controller never steers player one.

## The controller this player owns, or -1 for player one (keyboard, mouse and every free controller).
var pad := -1
## Controllers owned by other players; player one skips them. Shared with the camp, which fills it.
var taken: Array[int] = []


func _init(own_pad: int = -1, others: Array[int] = []) -> void:
	pad = own_pad
	taken = others


## True when this event came from one of this player's devices.
func owns_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device == pad if pad >= 0 else not taken.has(event.device)
	return pad < 0


func _pads() -> Array[int]:
	if pad >= 0:
		return [pad]
	var out: Array[int] = []
	for device in Input.get_connected_joypads():
		if not taken.has(device):
			out.append(device)
	return out


## How far an action is pressed (0 to 1) on this player's devices.
func strength(action: String) -> float:
	var row: Dictionary = Tuning.value("input", "actions." + action, {})
	var deadzone := float(Tuning.value("input", "deadzone", 0.2))
	var best := 0.0
	if pad < 0:
		for key_name: String in row.get("keys", []):
			if Input.is_physical_key_pressed(OS.find_keycode_from_string(key_name)):
				return 1.0
	for device in _pads():
		for button: int in row.get("joy_buttons", []):
			if Input.is_joy_button_pressed(device, button):
				return 1.0
		for axis_row: Array in row.get("joy_axes", []):
			var v := Input.get_joy_axis(device, int(axis_row[0])) * signf(float(axis_row[1]))
			if v > deadzone:
				best = maxf(best, inverse_lerp(deadzone, 1.0, minf(v, 1.0)))
	return best


## The walking stick for this player, like Input.get_vector.
func move() -> Vector2:
	var v := Vector2(strength("move_right") - strength("move_left"), strength("move_back") - strength("move_forward"))
	return v.limit_length(1.0)
