class_name Miniature
extends RefCounted
## The miniature-photo look: a tilt-shift blur that keeps the players' spot sharp and softens what is nearer and
## farther, like a macro lens on a tabletop set. The play camera calls `focus` each frame. Numbers: data/art.json
## "miniature"; off for any picture preset listed in "off_presets" (the weakest laptop).


## The camera attributes for a camera focused `distance` metres away, or null when the preset turns the blur off.
static func attributes_for(distance: float, old: CameraAttributes) -> CameraAttributes:
	var cfg: Dictionary = Tuning.table("art").get("miniature", {})
	if cfg.is_empty() or (cfg.get("off_presets", []) as Array).has(Quality.current):
		return null
	var attr: CameraAttributesPractical = old if old is CameraAttributesPractical else CameraAttributesPractical.new()
	attr.dof_blur_amount = float(cfg.get("blur_amount", 0.1))
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = distance + float(cfg.get("far_gap_m", 2.0))
	attr.dof_blur_far_transition = float(cfg.get("far_transition_m", 6.0))
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = maxf(distance - float(cfg.get("near_gap_m", 3.0)), 0.5)
	attr.dof_blur_near_transition = float(cfg.get("near_transition_m", 2.0))
	return attr


## Keeps a camera's blur focused `distance` metres ahead.
static func focus(camera: Camera3D, distance: float) -> void:
	camera.attributes = attributes_for(distance, camera.attributes)
