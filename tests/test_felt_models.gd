extends RefCounted
## Milestone 1: the felt models are built by code from data/models.json, painted only with palette swatches,
## stand on the ground and have believable sizes (metres).

const SIZES := {
	"camper_a": [1.1, 1.6], "camper_b": [1.1, 1.6], "tent": [1.2, 2.0], "tree_pine": [2.5, 4.5],
	"tree_round": [2.5, 4.5], "tree_puff": [2.5, 4.5], "picnic_table": [0.6, 1.0], "chair_teal": [0.7, 1.2],
	"chair_honey": [0.7, 1.2], "fire_pit": [0.4, 1.2],
}


func test_every_model_builds_a_mesh() -> String:
	FeltBuilder.clear_cache()
	var empty := FeltBuilder.model_ids().filter(func(id: String) -> bool:
		var m := FeltBuilder.mesh(id)
		return m.get_surface_count() == 0 or m.surface_get_array_len(0) == 0)
	return "" if empty.is_empty() else "empty meshes: %s" % empty


func test_parts_use_known_shapes_and_palette_swatches() -> String:
	var swatches: Dictionary = Tuning.table("palette").get("swatches", {})
	var bad: PackedStringArray = []
	for id: String in FeltBuilder.model_ids():
		var model := FeltBuilder.resolve(id)
		for part: Dictionary in model.get("parts", []):
			if not FeltBuilder.SHAPES.has(part.get("shape")):
				bad.append("%s: shape %s" % [id, part.get("shape")])
			var name := FeltBuilder.swatch_name(part, model)
			if not swatches.has(name):
				bad.append("%s: colour %s" % [id, part.get("color")])
	return "" if bad.is_empty() else ", ".join(bad)


func test_plan_palette_is_kept() -> String:
	var plan := {"moss_felt": "#536B50", "rust_canvas": "#BB704C", "honey_thread": "#D6AF66", "pond_blue": "#6B929C",
			"warm_cream": "#EEE3CB"}
	for name: String in plan:
		if str(Tuning.value("palette", "swatches." + name, "")).to_upper() != plan[name]:
			return "%s differs from docs/PLAN.md" % name
	return ""


func test_proof_models_stand_on_the_ground_at_believable_sizes() -> String:
	var bad: PackedStringArray = []
	for id: String in SIZES:
		var box := FeltBuilder.mesh(id).get_aabb()
		if box.position.y < -0.06 or box.position.y > 0.02:
			bad.append("%s floats or sinks (bottom %.2f m)" % [id, box.position.y])
		var height := box.end.y
		if height < SIZES[id][0] or height > SIZES[id][1]:
			bad.append("%s is %.2f m tall" % [id, height])
	return "" if bad.is_empty() else ", ".join(bad)


func test_variants_swap_colours_and_options() -> String:
	var a := FeltBuilder.mesh("camper_a")
	var b := FeltBuilder.mesh("camper_b")
	if a.surface_get_arrays(0)[Mesh.ARRAY_COLOR] == b.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		return "the two campers have the same colours"
	if a.surface_get_array_len(0) == b.surface_get_array_len(0):
		return "the two campers should differ in hat and hair"
	var teal: PackedColorArray = FeltBuilder.mesh("chair_teal").surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var honey: PackedColorArray = FeltBuilder.mesh("chair_honey").surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	return "" if teal != honey else "the two chairs have the same colours"


func test_rounded_box_keeps_its_size() -> String:
	var arrays := FeltBuilder.rounded_box(Vector3(1.0, 0.5, 2.0), 0.1, 3)
	var box := AABB()
	var first := true
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		if first:
			box = AABB(v, Vector3.ZERO)
			first = false
		box = box.expand(v)
	return "" if box.size.is_equal_approx(Vector3(1.0, 0.5, 2.0)) else "rounded box is %s" % box.size


func test_one_shared_felt_material() -> String:
	var a := FeltBuilder.build("tent")
	var b := FeltBuilder.build("picnic_table")
	var ok := a.material_override == b.material_override and a.material_override is ShaderMaterial
	a.free()
	b.free()
	return "" if ok else "solid models should share the one felt material"
