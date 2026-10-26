class_name PlayerInput
extends RefCounted
## One player's share of the input devices, for couch play. Alone, player one has every device (ANY); on the couch
## each player has exactly one: the keyboard and mouse (KEYS) or one controller. Reads the bindings in data/input.json
## (with this PC's remaps, InputSetup.row) for those devices only, so the other player's device never steers them.

## Every device not taken by someone else.
const ANY := -1
## The keyboard and mouse.
const KEYS := -2

## The device this player owns: a controller (0 and up), KEYS, or ANY.
var pad := ANY
## Controllers owned by other players; an ANY player skips them.
var taken: Array[int] = []


func _init(own: int = ANY, others: Array[int] = []) -> void:
	pad = own
	taken = others


## The device an event came from (KEYS or a controller), or ANY for events that belong to no device (mouse motion).
static func device_of(event: InputEvent) -> int:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device
	if event is InputEventKey or event is InputEventMouseButton:
		return KEYS
	return ANY


## True when this event came from one of this player's devices.
func owns_event(event: InputEvent) -> bool:
	var device := device_of(event)
	if pad == ANY:
		return not taken.has(device)
	return device == pad or (device == ANY and pad == KEYS)


func _pads() -> Array[int]:
	if pad >= 0:
		return [pad]
	var out: Array[int] = []
	if pad == ANY:
		for device in Input.get_connected_joypads():
			if not taken.has(device):
				out.append(device)
	return out


## How far an action is pressed (0 to 1) on this player's devices.
func strength(action: String) -> float:
	var row := InputSetup.row(action)
	var deadzone := InputSetup.deadzone()
	var best := 0.0
	if pad == ANY or pad == KEYS:
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


## The pointing stick for this player (data/input.json aim_axes: the right stick), for the tool ring: (0, 0) inside
## the deadzone, +x right and +y down.
func aim() -> Vector2:
	var axes: Array = Tuning.value("input", "aim_axes", [2, 3])
	var best := Vector2.ZERO
	for device in _pads():
		var v := Vector2(Input.get_joy_axis(device, int(axes[0])), Input.get_joy_axis(device, int(axes[1])))
		if v.length() > maxf(InputSetup.deadzone(), best.length()):
			best = v.limit_length(1.0)
	return best


## The walking stick for this player, like Input.get_vector.
func move() -> Vector2:
	var v := Vector2(strength("move_right") - strength("move_left"), strength("move_back") - strength("move_forward"))
	return v.limit_length(1.0)
