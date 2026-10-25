extends Node3D
## The one sandbox scene (CLAUDE.md). Milestone 1: the felt clearing, two campers, the play camera and the light moods.
## The dev key (F1, "dev_menu") cycles the moods from data/lighting.json. The hint follows the last-used device.

var mood_index := 0
var _pad_hint := false
var _flicker_time := 0.0

@onready var clearing: Clearing = $Clearing
@onready var player: Camper = $Player
@onready var friend: Camper = $Friend
@onready var camera: PlayCamera = $PlayCamera


func _ready() -> void:
	_spawn(player, Tuning.value("clearing", "player", {}))
	_spawn(friend, Tuning.value("clearing", "friend", {}))
	player.camera = camera
	camera.target = player
	camera.set_faders(clearing.faders)
	camera.snap()
	set_mood(0)
	_update_hint()


func _spawn(camper: Camper, row: Dictionary) -> void:
	camper.transform = Clearing.placement_transform(row)


func set_mood(index: int) -> void:
	var names := LightMoods.names()
	if names.is_empty():
		return
	mood_index = posmod(index, names.size())
	LightMoods.apply(names[mood_index], $Sun, $World.environment, clearing.fire_lights)
	$Mood.text = Tuning.text("mood." + str(names[mood_index]))


func _unhandled_input(event: InputEvent) -> void:
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	var pc := event is InputEventKey or event is InputEventMouseButton
	if (pad and not _pad_hint) or (pc and _pad_hint):
		_pad_hint = pad
		_update_hint()
	if event.is_action_pressed("dev_menu"):
		set_mood(mood_index + 1)


func _update_hint() -> void:
	$Hint.text = Tuning.text("sandbox.hint_pad" if _pad_hint else "sandbox.hint_keys")


## Fire lights flicker gently (data/art.json "fire").
func _process(delta: float) -> void:
	_flicker_time += delta * Tuning.num("art", "fire.flicker_speed", 7.0)
	var amount := Tuning.num("art", "fire.flicker_amount", 0.15)
	for light in clearing.fire_lights:
		var base: float = light.get_meta("base_energy", light.light_energy)
		light.light_energy = base * (1.0 + amount * (sin(_flicker_time) * 0.6 + sin(_flicker_time * 2.7) * 0.4))
