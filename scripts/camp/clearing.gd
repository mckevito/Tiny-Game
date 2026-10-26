class_name Clearing
extends Node3D
## The clearing: places felt models from data/clearing.json (and the woods round its edge), gives solid models a collider
## (data/models.json "collide") and fire pits a light (data/models.json "light"; colour and strength by mood).

## Also place the starting camp objects (data/clearing.json "objects"). The sandbox does; the camp scene builds its
## objects from the camp save instead.
@export var include_objects := true

var fire_lights: Array[OmniLight3D] = []
## Meshes that dither away when they hide a player (data/models.json "fade").
var faders: Array[MeshInstance3D] = []
## The scenery placed from data/clearing.json "placements", by index (trees are chopped by this index).
var placed: Array[Node3D] = []


func _ready() -> void:
	for row: Dictionary in Tuning.table("clearing").get("placements", []):
		placed.append(place(row))
	for row: Dictionary in border_rows():
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


## The woods round the walking edge as placement rows (data/clearing.json "border"), the same every run.
static func border_rows() -> Array:
	var border: Dictionary = Tuning.table("clearing").get("border", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(border.get("seed", 0))
	var out: Array = []
	for ring: Dictionary in border.get("rings", []):
		var models: Array = ring.get("models", [])
		var count := int(ring.get("count", 0))
		var jitter := float(ring.get("jitter_m", 0.0))
		for i in count:
			var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
			var r := float(ring.get("radius_m", 0.0)) + rng.randf_range(-jitter, jitter)
			out.append({"model": models[i % models.size()], "pos": [sin(a) * r, cos(a) * r],
					"yaw": rng.randf_range(0.0, 360.0), "scale": float(ring.get("scale", 1.0))})
	return out


func place(row: Dictionary) -> Node3D:
	var id := str(row.get("model", ""))
	var model := FeltBuilder.resolve(id)
	var root := Node3D.new()
	root.name = "%s_%d" % [id, get_child_count()]
	root.transform = placement_transform(row)
	if row.has("scale"):
		root.scale = Vector3.ONE * float(row["scale"])
	var mesh := FeltBuilder.build(id)
	root.add_child(mesh)
	if model.get("fade", false):
		faders.append(mesh)
	var collide: Dictionary = model.get("collide", {})
	if not collide.is_empty():
		root.add_child(collider(collide))
	if model.has("light"):
		var light := OmniLight3D.new()
		light.name = "FireLight"
		light.position = FeltBuilder.vec3(model["light"].get("pos"))
		light.shadow_enabled = true
		root.add_child(light)
		fire_lights.append(light)
	add_child(root)
	return root


## A solid model's collider (data/models.json "collide": one box or cylinder, or several in "shapes", each turned by its
## own yaw). GuestPath reads the same rows, so what stops a player also turns a guest.
static func collider(collide: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	for row: Dictionary in collide.get("shapes", [collide]):
		var shape := CollisionShape3D.new()
		if row.has("box"):
			var box := BoxShape3D.new()
			box.size = FeltBuilder.vec3(row["box"], Vector3.ONE)
			shape.shape = box
			shape.position = FeltBuilder.vec3(row.get("offset"))
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = float(row.get("radius", 0.3))
			cyl.height = float(row.get("height", 1.0))
			shape.shape = cyl
			shape.position = Vector3(0, cyl.height * 0.5, 0)
		shape.rotation.y = deg_to_rad(float(row.get("yaw", 0.0)))
		body.add_child(shape)
	return body
