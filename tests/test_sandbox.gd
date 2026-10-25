extends RefCounted
## The one sandbox scene loads with the Milestone 1 clearing, both campers and the play camera.

const PROOF_MODELS := ["camper_a", "camper_b", "tent", "tree_pine", "tree_round", "tree_puff", "picnic_table",
		"chair_teal", "chair_honey", "fire_pit"]


func _sandbox() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var sandbox: Node = load("res://scenes/sandbox.tscn").instantiate()
	root.add_child(sandbox)
	return sandbox


func test_sandbox_loads() -> String:
	var packed: PackedScene = load("res://scenes/sandbox.tscn")
	if packed == null:
		return "scenes/sandbox.tscn did not load"
	var root := packed.instantiate()
	var missing: PackedStringArray = []
	for node in ["Clearing", "Player", "Friend", "PlayCamera", "Sun", "World"]:
		if not root.has_node(node):
			missing.append(node)
	root.free()
	return "" if missing.is_empty() else "sandbox is missing " + ", ".join(missing)


func test_clearing_shows_every_proof_model() -> String:
	var sandbox := _sandbox()
	var shown: Array = []
	for node in sandbox.find_children("*", "MeshInstance3D", true, false):
		shown.append(str(node.name))
	sandbox.free()
	var missing := PROOF_MODELS.filter(func(id: String) -> bool: return not shown.has(id))
	return "" if missing.is_empty() else "not in the sandbox: " + str(missing)


func test_fire_pit_has_a_light_and_trees_can_fade() -> String:
	var sandbox := _sandbox()
	var lights: int = sandbox.clearing.fire_lights.size()
	var faders: int = sandbox.clearing.faders.size()
	sandbox.free()
	if lights < 1:
		return "no fire light"
	return "" if faders >= 3 else "only %d trees can fade" % faders


func test_both_light_moods_apply() -> String:
	var names := LightMoods.names()
	if not (names.has("day") and names.has("dusk")):
		return "data/lighting.json needs day and dusk, has %s" % names
	var sun := DirectionalLight3D.new()
	var fire := OmniLight3D.new()
	var env := Environment.new()
	var fires: Array[OmniLight3D] = [fire]
	LightMoods.apply("day", sun, env, fires)
	var day_sun := sun.light_energy
	var day_fire := fire.light_energy
	LightMoods.apply("dusk", sun, env, fires)
	var result := ""
	if not (sun.light_energy < day_sun and fire.light_energy > day_fire):
		result = "dusk should have a weaker sun and a stronger fire than day"
	sun.free()
	fire.free()
	return result


func test_dev_key_cycles_the_mood() -> String:
	var sandbox := _sandbox()
	var before: int = sandbox.mood_index
	sandbox.set_mood(before + 1)
	var after: int = sandbox.mood_index
	sandbox.set_mood(after + 1)
	var wrapped: int = sandbox.mood_index
	sandbox.free()
	return "" if after != before and wrapped == before else "moods did not cycle: %d %d %d" % [before, after, wrapped]
