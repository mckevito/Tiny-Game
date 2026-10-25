class_name FeltBuilder
extends RefCounted
## Builds felt models from data/models.json: every part of a model is merged into one mesh, painted with vertex
## colours from data/palette.json and drawn with the one shared felt material (scripts/art/felt.gdshader).
## Mesh detail and stitch sizes: data/art.json "mesh" and "stitch".

const SHADER := preload("res://scripts/art/felt.gdshader")
const SHAPES := ["sphere", "cone", "cylinder", "capsule", "prism", "box", "stitch", "ring", "seam", "lathe"]

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Every model id in the table (keys starting with "_" are notes).
static func model_ids() -> Array:
	return Tuning.table("models").keys().filter(func(k: String) -> bool: return not k.begins_with("_"))


## A model's entry with its base merged in: parts and settings from the base, slots and show from both.
static func resolve(id: String) -> Dictionary:
	var models := Tuning.table("models")
	var row: Dictionary = models.get(id, {})
	if not row.has("base"):
		return row
	var out: Dictionary = resolve(row["base"]).duplicate()
	var slots: Dictionary = out.get("slots", {}).duplicate()
	slots.merge(row.get("slots", {}), true)
	for key: String in row:
		out[key] = row[key]
	out["slots"] = slots
	return out


## A palette swatch as a linear colour, or magenta when the name is unknown (tests catch that).
static func swatch(name: String) -> Color:
	var hex: Variant = Tuning.value("palette", "swatches." + name)
	if hex == null:
		push_error("FeltBuilder: unknown swatch %s" % name)
		return Color.MAGENTA
	return Color.html(str(hex)).srgb_to_linear()


## The swatch name a part is painted with, after filling a $slot.
static func swatch_name(part: Dictionary, model: Dictionary) -> String:
	var name := str(part.get("color", ""))
	if name.begins_with("$"):
		return str(model.get("slots", {}).get(name.substr(1), ""))
	return name


## A new node showing the model. Trees and bushes sway (data/models.json "sway").
static func build(id: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = id
	node.mesh = mesh(id)
	node.material_override = material(bool(resolve(id).get("sway", false)))
	return node


## The model's merged mesh, built once and cached.
static func mesh(id: String) -> ArrayMesh:
	if _meshes.has(id):
		return _meshes[id]
	var model := resolve(id)
	if model.has("file"):
		_meshes[id] = _file_mesh(model)
		return _meshes[id]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var shown: Array = model.get("show", [])
	var weaves: Dictionary = Tuning.table("art").get("weaves", {})
	for part: Dictionary in model.get("parts", []):
		if part.has("option") and not shown.has(part["option"]):
			continue
		var color := swatch(swatch_name(part, model))
		color.a = 1.0 - float(part.get("glow", 0.0))
		var weave := float(weaves.get(str(part.get("weave", model.get("weave", "felt"))), 0))
		var arrays := _part_arrays(part)
		var start := verts.size()
		for xform: Transform3D in _copies(part):
			_append(arrays, xform * _part_transform(part), color, verts, normals, colors, indices)
		for i in verts.size() - start:
			uvs.append(Vector2(weave, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	if not verts.is_empty():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[id] = out
	return out


## A model sculpted outside the game (a .glb under art/, made by its own build script): its UV.x is the weave and
## its UV.y the index into the model's "file_slots" (swatch names or $slots), so it is painted from the palette here
## and variants swap colours like any other model.
static func _file_mesh(model: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	var scene: PackedScene = load(str(model["file"]))
	if scene == null:
		push_error("FeltBuilder: can't load %s" % model["file"])
		return out
	var root := scene.instantiate()
	var found: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		root.free()
		return out
	var src: Mesh = (found[0] as MeshInstance3D).mesh
	var arrays := src.surface_get_arrays(0)
	root.free()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var names: Array = model.get("file_slots", [])
	var palette: Array[Color] = []
	for n: Variant in names:
		palette.append(swatch(swatch_name({"color": n}, model)))
	var colors := PackedColorArray()
	colors.resize(uvs.size())
	for i in uvs.size():
		# glTF flips V (v = 1 - y), so the slot comes back as 1 - UV.y.
		var slot := clampi(roundi(1.0 - uvs[i].y), 0, palette.size() - 1)
		colors[i] = palette[slot] if not palette.is_empty() else Color.WHITE
	arrays[Mesh.ARRAY_COLOR] = colors
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## The shared felt material, with or without sway. Values: data/art.json "felt".
static func material(sway: bool) -> ShaderMaterial:
	if _materials.has(sway):
		return _materials[sway]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var felt: Dictionary = Tuning.table("art").get("felt", {})
	for key in ["noise_scale", "noise_strength", "grain_scale", "grain_strength", "fuzz_strength", "rim", "rim_tint",
			"glow_strength", "sway_speed", "fibre_scale", "fibre_strength", "bump_strength", "hair_edge", "knit_scale",
			"knit_depth", "knit_bump", "wood_scale", "wood_strength", "water_scale", "water_strength", "grass_tint",
			"fine_scale", "fine_strength"]:
		mat.set_shader_parameter(key, float(felt.get(key, 0.0)))
	for key in ["grass_light", "grass_dark"]:
		mat.set_shader_parameter(key, vec3(felt.get(key), Vector3.ONE))
	mat.set_shader_parameter("sway_height", float(felt.get("sway_height_m", 3.0)))
	mat.set_shader_parameter("sway_amount", float(felt.get("sway_amount_m", 0.0)) if sway else 0.0)
	# Fuzz shells as next passes (data/art.json "shells"), left off for the presets in shells.off_presets.
	var shells: Dictionary = Tuning.table("art").get("shells", {})
	var last := mat
	if not (shells.get("off_presets", []) as Array).has(Quality.current):
		for i in int(shells.get("count", 0)):
			var shell := mat.duplicate() as ShaderMaterial
			shell.set_shader_parameter("shell", float(i + 1))
			for key in ["shell_height", "shell_keep", "strand_scale"]:
				shell.set_shader_parameter(key, float(shells.get(key, 0.0)))
			last.next_pass = shell
			last = shell
	_materials[sway] = mat
	return mat


## Drops cached meshes and materials, so edited tables are read again.
static func clear_cache() -> void:
	_meshes.clear()
	_materials.clear()


## Where a part's copies go: one in place; `repeat` copies spun round Y; `scatter` copies strewn over an area.
## scatter: {count, area [x, z] (centred on pos), seed, scale [min, max], avoid [[x, z, radius], ...] in the model's
## space, keep_out (radius of a circle round the origin left empty), keep_in (only inside this radius)}. Placement is
## seeded, so every PC builds the same.
static func _copies(part: Dictionary) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var copies := int(part.get("repeat", 1))
	# Copies spin round the model's centre, or round `pivot` (a plant's own stem) when the part names one.
	var pivot := vec3(part.get("pivot"))
	for i in copies:
		out.append(Transform3D(Basis(), pivot) * Transform3D(Basis(Vector3.UP, TAU * i / copies), -pivot))
	var cfg: Dictionary = part.get("scatter", {})
	if cfg.is_empty():
		return out
	out.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var area: Array = cfg.get("area", [10, 10])
	var scale: Array = cfg.get("scale", [1, 1])
	var keep_out := float(cfg.get("keep_out", 0.0))
	var keep_in := float(cfg.get("keep_in", 1.0e9))
	var centre := vec3(part.get("pos"))
	var tries := 0
	while out.size() < int(cfg.get("count", 10)) and tries < int(cfg.get("count", 10)) * 20:
		tries += 1
		var at := Vector3(rng.randf_range(-0.5, 0.5) * float(area[0]), 0.0, rng.randf_range(-0.5, 0.5) * float(area[1]))
		var spot := Vector2(centre.x + at.x, centre.z + at.z)
		var turn := rng.randf() * TAU
		var size := rng.randf_range(float(scale[0]), float(scale[1]))
		if spot.length() < keep_out or spot.length() > keep_in:
			continue
		var clear := true
		for a: Array in cfg.get("avoid", []):
			if spot.distance_to(Vector2(float(a[0]), float(a[1]))) < float(a[2]):
				clear = false
				break
		if not clear:
			continue
		# Spun and sized about the part's own position, then moved to the spot.
		var about := Transform3D(Basis(), centre) * Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size),
				Vector3.ZERO) * Transform3D(Basis(), -centre)
		out.append(Transform3D(Basis(), at) * about)
	return out


## A JSON [x, y, z] array as a Vector3.
static func vec3(v: Variant, fallback := Vector3.ZERO) -> Vector3:
	if v is Array and v.size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


static func _part_transform(part: Dictionary) -> Transform3D:
	var rot := vec3(part.get("rot")) * (PI / 180.0)
	var basis := Basis.from_euler(rot)
	var shape := str(part.get("shape"))
	if shape in ["sphere", "cone", "cylinder", "prism", "lathe"]:
		basis = basis * Basis.from_scale(vec3(part.get("size"), Vector3.ONE))
	elif shape == "capsule":
		var size := vec3(part.get("size"), Vector3.ONE)
		var r := minf(size.x, size.z)
		basis = basis * Basis.from_scale(Vector3(size.x / r, 1.0, size.z / r))
	return Transform3D(basis, vec3(part.get("pos")))


## Mesh arrays for one part in its own frame (unit shapes are scaled by _part_transform).
static func _part_arrays(part: Dictionary) -> Array:
	var mesh_cfg: Dictionary = Tuning.table("art").get("mesh", {})
	var size := vec3(part.get("size"), Vector3.ONE)
	# Wide discs (ponds, clearings) get more segments so their edge stays round.
	var segs := clampi(int(maxf(size.x, size.z) * float(mesh_cfg.get("segments_per_m", 8))),
			int(mesh_cfg.get("round_segments", 20)), int(mesh_cfg.get("max_round_segments", 64)))
	match str(part.get("shape")):
		"sphere":
			var m := SphereMesh.new()
			m.radius = 0.5
			m.height = 1.0
			# Tiny or many-times-copied parts (leaves, clover) ask for fewer segments.
			m.radial_segments = int(part.get("segments", mesh_cfg.get("sphere_segments", 24)))
			m.rings = maxi(int(part.get("segments", mesh_cfg.get("sphere_rings", 12) * 2)) / 2, 3)
			return m.get_mesh_arrays()
		"cone", "cylinder":
			var m := CylinderMesh.new()
			m.bottom_radius = 0.5
			m.top_radius = 0.0 if part["shape"] == "cone" else 0.5 * float(part.get("taper", 1.0))
			m.height = 1.0
			m.radial_segments = int(part.get("segments", segs))
			m.rings = 1
			return m.get_mesh_arrays()
		"capsule":
			var m := CapsuleMesh.new()
			m.radius = minf(size.x, size.z) * 0.5
			m.height = maxf(size.y, m.radius * 2.0)
			m.radial_segments = segs
			m.rings = 6
			return m.get_mesh_arrays()
		"prism":
			var m := PrismMesh.new()
			m.size = Vector3.ONE
			m.left_to_right = float(part.get("tip", 0.5))
			return m.get_mesh_arrays()
		"box":
			var r := float(part.get("round", mesh_cfg.get("default_box_round_m", 0.03)))
			return rounded_box(size, r, int(mesh_cfg.get("box_round_steps", 3)))
		"stitch":
			var points := PackedVector3Array()
			for p: Variant in part.get("points", [part.get("from"), part.get("to")]):
				points.append(vec3(p))
			return _stitch_path(points, part)
		"ring":
			return _stitch_path(_ellipse_ring(size, part.get("wave", [])), part)
		"lathe":
			return _lathe(part.get("profile", []), part.get("wave", []), int(part.get("segments", segs)))
		"seam":
			var arrays := []
			var count := int(part.get("count", 4))
			for i in count:
				var path := _meridian(size, TAU * i / count + deg_to_rad(float(part.get("turn", 0.0))),
						deg_to_rad(float(part.get("from_lat", -50.0))), deg_to_rad(float(part.get("to_lat", 70.0))))
				arrays = _merge(arrays, _stitch_path(path, part))
			return arrays
	push_error("FeltBuilder: unknown shape %s" % part.get("shape"))
	return []


## A box with rounded edges and corners: a grid on each face, pulled onto a rounded shell of radius r.
static func rounded_box(size: Vector3, r: float, steps: int) -> Array:
	var half := size * 0.5
	r = clampf(r, 0.0, minf(half.x, minf(half.y, half.z)))
	var inner := half - Vector3(r, r, r)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			var u_axis := (axis + 1) % 3
			var v_axis := (axis + 2) % 3
			var us := _grid(half[u_axis], r, steps)
			var vs := _grid(half[v_axis], r, steps)
			var face_n := Vector3.ZERO
			face_n[axis] = sgn
			var start := verts.size()
			for u: float in us:
				for v: float in vs:
					var q := Vector3.ZERO
					q[axis] = sgn * half[axis]
					q[u_axis] = u
					q[v_axis] = v
					var c := q.clamp(-inner, inner)
					var d := q - c
					var n := d.normalized() if d.length() > 0.00001 else face_n
					verts.append(c + n * r if r > 0.0 else q)
					normals.append(n if r > 0.0 else face_n)
			var cols := vs.size()
			for i in us.size() - 1:
				for j in cols - 1:
					var a := start + i * cols + j
					var b := a + cols
					_quad(indices, verts, face_n, a, b, b + 1, a + 1)
	return _pack(verts, normals, indices)


## Grid lines along one face axis: dense in the rounded bands at each end, one span across the flat middle.
static func _grid(h: float, r: float, steps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if r <= 0.0:
		out.append_array([-h, h])
		return out
	for k in steps + 1:
		out.append(-h + r * k / steps)
	for k in steps + 1:
		var x := h - r + r * k / steps
		if x > out[out.size() - 1] + 0.00001:
			out.append(x)
	return out


## Two triangles, wound so they face along `n` (Godot draws clockwise faces as the front).
static func _quad(indices: PackedInt32Array, verts: PackedVector3Array, n: Vector3, a: int, b: int, c: int, d: int) -> void:
	for tri: Array in [[a, b, c], [a, c, d]]:
		var cross := (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
		if cross.dot(n) > 0.0:
			indices.append_array([tri[0], tri[2], tri[1]])
		else:
			indices.append_array([tri[0], tri[1], tri[2]])


## Running-stitch dashes along a polyline. Sizes: data/art.json "stitch"; a part's "thick", "dash" and "gap" scale
## them (gap 0 makes a solid cord, such as a guy rope).
static func _stitch_path(points: PackedVector3Array, part: Dictionary = {}) -> Array:
	var cfg: Dictionary = Tuning.table("art").get("stitch", {})
	var dash := float(cfg.get("dash_m", 0.07)) * float(part.get("dash", 1.0))
	var gap := float(cfg.get("gap_m", 0.05)) * float(part.get("gap", 1.0))
	var thick := float(cfg.get("thickness_m", 0.02)) * float(part.get("thick", 1.0))
	var piece := rounded_box(Vector3(thick, thick, dash), 0.0, 1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var carry := 0.0
	for s in points.size() - 1:
		var a := points[s]
		var b := points[s + 1]
		var length := a.distance_to(b)
		if length < 0.0001:
			continue
		var dir := (b - a) / length
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		var basis := Basis.looking_at(dir, up)
		if gap <= 0.0:
			# A cord: one piece per segment, a little longer so the joints close.
			var cord := rounded_box(Vector3(thick, thick, length + thick), 0.0, 1)
			_append(cord, Transform3D(basis, (a + b) * 0.5), Color.WHITE, verts, normals, colors, indices)
			continue
		var d := carry
		while d + dash <= length + 0.0001:
			_append(piece, Transform3D(basis, a + dir * (d + dash * 0.5)), Color.WHITE, verts, normals, colors, indices)
			d += dash + gap
		carry = maxf(d - length, 0.0)
	return _pack(verts, normals, indices)


## A closed ellipse in the XZ plane with the given [x, _, z] size, scalloped like a lathe with the same wave.
static func _ellipse_ring(size: Vector3, wave: Array = []) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps := int(Tuning.num("art", "mesh.round_segments", 20)) * 2
	if wave.size() == 2:
		steps = maxi(steps, int(wave[0]) * 8)
	for i in steps + 1:
		var a := TAU * i / steps
		var k := _wave(a, wave)
		out.append(Vector3(sin(a) * size.x * 0.5 * k, 0.0, cos(a) * size.z * 0.5 * k))
	return out


## How far in a wave pulls the radius at angle `a`: wave is [count, depth]; 1 at each lobe, 1 - depth between them.
static func _wave(a: float, wave: Array) -> float:
	if wave.size() != 2:
		return 1.0
	return 1.0 - float(wave[1]) * 0.5 * (1.0 - cos(float(wave[0]) * a))


## A shape turned round Y from a profile of [radius, height] points (radius 0..1 of the half-width, height 0..1 from
## the bottom), centred like the other unit shapes. An optional wave [count, depth] scallops it (pine tiers) or ribs
## it (a knit beanie).
static func _lathe(profile: Array, wave: Array, segs: int) -> Array:
	if wave.size() == 2:
		segs = maxi(segs, int(wave[0]) * 6)
	var rows := profile.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for p: Array in profile:
		for j in segs:
			var a := TAU * j / segs
			var r := float(p[0]) * 0.5 * _wave(a, wave)
			verts.append(Vector3(sin(a) * r, float(p[1]) - 0.5, cos(a) * r))
			normals.append(Vector3.ZERO)
	for i in rows - 1:
		for j in segs:
			var a := i * segs + j
			var b := i * segs + (j + 1) % segs
			var c := a + segs
			var d := b + segs
			for tri: Array in [[a, b, c], [b, d, c]]:
				# tri runs anticlockwise seen from outside; Godot's front faces are clockwise, so it is written reversed.
				var n := (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
				for k: int in tri:
					normals[k] += n
				indices.append_array([tri[0], tri[2], tri[1]])
	for k in normals.size():
		normals[k] = normals[k].normalized() if normals[k].length() > 0.0 else Vector3.UP
	return _pack(verts, normals, indices)


## A line of longitude on an ellipsoid of the given size, at angle `lon`, between two latitudes.
static func _meridian(size: Vector3, lon: float, lat_from: float, lat_to: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var steps := int(Tuning.num("art", "mesh.round_segments", 20))
	for i in steps + 1:
		var lat := lerpf(lat_from, lat_to, float(i) / steps)
		out.append(Vector3(cos(lat) * sin(lon) * size.x, sin(lat) * size.y, cos(lat) * cos(lon) * size.z) * 0.5)
	return out


## Two mesh arrays as one (either may be empty).
static func _merge(a: Array, b: Array) -> Array:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append(a, Transform3D.IDENTITY, Color.WHITE, verts, normals, colors, indices)
	_append(b, Transform3D.IDENTITY, Color.WHITE, verts, normals, colors, indices)
	return _pack(verts, normals, indices)


static func _pack(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> Array:
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_INDEX] = indices
	return out


static func _append(src: Array, xform: Transform3D, color: Color, verts: PackedVector3Array,
		normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	if src.is_empty():
		return
	var offset := verts.size()
	var normal_basis := xform.basis.inverse().transposed()
	var src_verts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	for i in src_verts.size():
		verts.append(xform * src_verts[i])
		normals.append((normal_basis * src_normals[i]).normalized())
		colors.append(color)
	var src_indices: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var flip := xform.basis.determinant() < 0.0
	for i in range(0, src_indices.size(), 3):
		if flip:
			indices.append_array([src_indices[i] + offset, src_indices[i + 2] + offset, src_indices[i + 1] + offset])
		else:
			indices.append_array([src_indices[i] + offset, src_indices[i + 1] + offset, src_indices[i + 2] + offset])
