class_name Clearing
extends Node3D
## The clearing: places felt models from data/clearing.json, gives solid models a collider
## (data/models.json "collide") and fire pits a light (data/models.json "light"; colour and strength by mood).

## Also place the starting camp objects (data/clearing.json "objects"). The sandbox does; the camp scene builds its
## objects from the camp save instead.
@export var include_objects := true

var fire_lights: Array[OmniLight3D] = []
## Meshes that dither away when they hide a player (data/models.json "fade").
var faders: Array[MeshInstance3D] = []


func _ready() -> void:
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		place(row)
	if include_objects:
		for row: Dictionary in Tuning.table("clearing").get("objects", []):
			place(row)


## A placement's ground position and yaw: "yaw" in degrees, or "face" [x, z] to turn the front (-Z) toward a point.
static func placement_transform(row: Dictionary) -> Transform3D:
	var p: Array = row.get("pos", [0, 0])
	var origin := Vector3(float(p[0]), 0.0, float(p[1]))
	var yaw := deg_to_rad(float(row.get("yaw", 0.0)))
	if row.has("face"):
		var f: Array = row["face"]
		var d := Vector3(float(f[0]), 0.0, float(f[1])) - origin
		if d.length() > 0.001:
			yaw = atan2(-d.x, -d.z)
	return Transform3D(Basis(Vector3.UP, yaw), origin)


func place(row: Dictionary) -> Node3D:
	var id := str(row.get("model", ""))
	var model := FeltBuilder.resolve(id)
	var root := Node3D.new()
	root.name = "%s_%d" % [id, get_child_count()]
	root.transform = placement_transform(row)
	var mesh := FeltBuilder.build(id)
	root.add_child(mesh)
	if model.get("fade", false):
		faders.append(mesh)
	var collide: Dictionary = model.get("collide", {})
	if not collide.is_empty():
		root.add_child(_collider(collide))
	if model.has("light"):
		var light := OmniLight3D.new()
		light.name = "FireLight"
		light.position = FeltBuilder.vec3(model["light"].get("pos"))
		light.shadow_enabled = true
		root.add_child(light)
		fire_lights.append(light)
	add_child(root)
	return root


func _collider(collide: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	if collide.has("box"):
		var box := BoxShape3D.new()
		box.size = FeltBuilder.vec3(collide["box"], Vector3.ONE)
		shape.shape = box
		shape.position = FeltBuilder.vec3(collide.get("offset"))
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = float(collide.get("radius", 0.3))
		cyl.height = float(collide.get("height", 1.0))
		shape.shape = cyl
		shape.position = Vector3(0, cyl.height * 0.5, 0)
	body.add_child(shape)
	return body
