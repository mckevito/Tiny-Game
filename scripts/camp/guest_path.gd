class_name GuestPath
extends RefCounted
## Guests walk round the camp's things instead of through them: chairs, benches, stools, tents, the fire and its ring
## of log seats, the picnic table, standing trees and the pond. Every solid model's footprint comes from its collider
## (data/models.json "collide"), so what stops a player also turns a guest. A route is worked out on a grid from the
## shared day alone, so both PCs see the same walk with no extra netcode. Numbers: data/guests.json "path".

## The last grid built, kept while the footprints stay the same (most routes in a row share them).
static var _grid: AStarGrid2D
static var _grid_key := 0


static func _v(key: String, fallback: Variant = null) -> Variant:
	return Tuning.value("guests", "path." + key, fallback)


## The footprints of one model's collider (data/models.json "collide": one box or cylinder, or several in "shapes"),
## placed at `at` turned `yaw` radians: [{at (Vector2), yaw, half (Vector2 half sizes), oval (true for a cylinder)}].
## Flat shapes that never stand above the ground (the ground itself) leave no footprint.
static func shapes(collide: Dictionary, at: Vector2, yaw: float, scale := 1.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if collide.is_empty():
		return out
	for row: Dictionary in collide.get("shapes", [collide]):
		var off := FeltBuilder.vec3(row.get("offset"))
		var half := Vector2.ZERO
		var top := 0.0
		if row.has("box"):
			var size := FeltBuilder.vec3(row["box"], Vector3.ONE)
			half = Vector2(size.x, size.z) * 0.5
			top = off.y + size.y * 0.5
		else:
			half = Vector2.ONE * float(row.get("radius", 0.3))
			top = off.y + float(row.get("height", 1.0))
		if top <= float(_v("min_top_m", 0.05)):
			continue
		out.append({"at": at + Vector2(off.x, off.z).rotated(-yaw) * scale,
				"yaw": yaw + deg_to_rad(float(row.get("yaw", 0.0))), "half": half * scale, "oval": not row.has("box")})
	return out


## Every footprint a guest walks round: the clearing's solid scenery (standing trees only), the camp's things nobody is
## carrying (a pitch with a guest on it is that guest's tent), the fire at its current size with its ring's log seats,
## and the path.avoid rows (the pond, which has no collider because players may walk on its felt).
static func footprints(state: CampState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array = Tuning.table("clearing").get("placements", [])
	var tree_models: Array = Tuning.value("gather", "trees.models", [])
	var fire_model := str(Tuning.value("craft", "fire.model", "fire_pit"))
	var level := mini(state.build.fire_level(), CampBuild.fire_levels().size())
	for i in rows.size():
		var row: Dictionary = rows[i]
		var model := str(row.get("model", ""))
		if tree_models.has(model) and state.gather.tree(i)["stage"] != "standing":
			continue
		var t := Clearing.placement_transform(row)
		var at := Vector2(t.origin.x, t.origin.z)
		var yaw := t.basis.get_euler().y
		var collide: Dictionary = FeltBuilder.resolve(model).get("collide", {})
		if model == fire_model and level > 0:
			collide = collide.duplicate()
			collide["radius"] = float(CampBuild.fire_levels()[level - 1].get("collide_m", collide.get("radius", 0.3)))
			for up: Dictionary in CampBuild.fire_levels().slice(0, level):
				out.append_array(shapes(FeltBuilder.resolve(str(up.get("model", ""))).get("collide", {}), at, yaw))
		out.append_array(shapes(collide, at, yaw, float(row.get("scale", 1.0))))
	var pitched := {}
	for id: String in state.camp["stays"]:
		pitched[str(state.camp["stays"][id].get("pitch", ""))] = true
	var ids: Array = state.camp["objects"].keys()
	ids.sort()
	for id: String in ids:
		if state.carriers.has(id):
			continue
		var row: Dictionary = state.camp["objects"][id]
		var model := str(_v("pitched_model", "tent_guest")) if pitched.has(id) else str(row["model"])
		var at := Vector2(float(row["pos"][0]), float(row["pos"][1]))
		out.append_array(shapes(FeltBuilder.resolve(model).get("collide", {}), at, deg_to_rad(float(row.get("yaw", 0.0)))))
	for row: Dictionary in _v("avoid", []):
		var half: Array = row.get("half", [0.5, 0.5])
		out.append({"at": Vector2(float(row["at"][0]), float(row["at"][1])), "yaw": deg_to_rad(float(row.get("yaw", 0.0))),
				"half": Vector2(float(half[0]), float(half[1])), "oval": bool(row.get("oval", true))})
	return out


## True when `p` is within `pad` metres of a footprint (a box's corners count as square, near enough at this size).
static func inside(p: Vector2, f: Dictionary, pad: float) -> bool:
	var local: Vector2 = (p - f["at"]).rotated(f["yaw"])
	var half: Vector2 = f["half"] + Vector2.ONE * pad
	if f["oval"]:
		return (local.x * local.x) / (half.x * half.x) + (local.y * local.y) / (half.y * half.y) <= 1.0
	return absf(local.x) <= half.x and absf(local.y) <= half.y


## True when no footprint comes within path.pad_m of `p`.
static func clear_at(p: Vector2, prints: Array[Dictionary]) -> bool:
	var pad := float(_v("pad_m", 0.3))
	for f: Dictionary in prints:
		if inside(p, f, pad):
			return false
	return true


## The way from `from` to `to` round the footprints: the points to walk through after `from`, ending at `to`. A start
## or end inside a footprint (a seat) steps straight out to the nearest open ground, or in from it. With no way round
## at all the guest walks straight there.
static func route(from: Vector2, to: Vector2, prints: Array[Dictionary]) -> Array[Vector2]:
	var grid := _grid_for(prints)
	var a := _open_cell(grid, _cell(grid, from))
	var b := _open_cell(grid, _cell(grid, to))
	if a == Vector2i(-1, -1) or b == Vector2i(-1, -1):
		return [to]
	# An end shut in where nobody fits (an old save's chair hard by the fire) is reached from the nearest open point.
	var ids: Array[Vector2i] = grid.get_id_path(a, b, true)
	if ids.is_empty():
		return [to]
	var pts: Array[Vector2] = []
	for id in ids:
		pts.append(_centre(grid, id))
	var start_open := not grid.is_point_solid(_cell(grid, from))
	var end_open := not grid.is_point_solid(_cell(grid, to))
	if start_open:
		pts[0] = from
	if end_open and ids.back() == b:
		pts[pts.size() - 1] = to
	var out: Array[Vector2] = []
	if not start_open:
		out.append(pts[0])
	# Straighten the stair steps: from each corner, go to the farthest later point in plain sight.
	var i := 0
	while i < pts.size() - 1:
		var j := i + 1
		while j + 1 < pts.size() and _sight(grid, pts[i], pts[j + 1]):
			j += 1
		out.append(pts[j])
		i = j
	if out.is_empty() or out.back() != to:
		out.append(to)
	return out


## The total length of a walk from `from` through `points`.
static func length(from: Vector2, points: Array[Vector2]) -> float:
	var total := 0.0
	var at := from
	for p in points:
		total += at.distance_to(p)
		at = p
	return total


static func _grid_for(prints: Array[Dictionary]) -> AStarGrid2D:
	var key := str(prints).hash()
	if _grid and key == _grid_key:
		return _grid
	var cell := maxf(float(_v("cell_m", 0.2)), 0.05)
	var reach := Tuning.num("tuning", "movement.edge_m", 14.0) + float(_v("margin_m", 2.0))
	var n := int(ceil(reach * 2.0 / cell))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, n, n)
	grid.cell_size = Vector2(cell, cell)
	grid.offset = Vector2(-reach, -reach) + Vector2(cell, cell) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var pad := float(_v("pad_m", 0.3))
	for f: Dictionary in prints:
		var r: float = (f["half"] as Vector2).length() + pad
		var lo := _cell(grid, f["at"] - Vector2(r, r))
		var hi := _cell(grid, f["at"] + Vector2(r, r))
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				if inside(_centre(grid, Vector2i(x, y)), f, pad):
					grid.set_point_solid(Vector2i(x, y))
	_grid = grid
	_grid_key = key
	return grid


static func _cell(grid: AStarGrid2D, p: Vector2) -> Vector2i:
	var c := ((p - grid.offset) / grid.cell_size + Vector2(0.5, 0.5)).floor()
	return Vector2i(clampi(int(c.x), 0, grid.region.size.x - 1), clampi(int(c.y), 0, grid.region.size.y - 1))


static func _centre(grid: AStarGrid2D, id: Vector2i) -> Vector2:
	return grid.offset + Vector2(id) * grid.cell_size


## The nearest open cell to `id` (itself when open), searching outward ring by ring; (-1, -1) when there is none near.
static func _open_cell(grid: AStarGrid2D, id: Vector2i) -> Vector2i:
	if not grid.is_point_solid(id):
		return id
	for r in range(1, int(_v("search_cells", 20)) + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for x in range(id.x - r, id.x + r + 1):
			for y in range(id.y - r, id.y + r + 1):
				var c := Vector2i(x, y)
				if maxi(absi(x - id.x), absi(y - id.y)) != r or not grid.is_in_boundsv(c) or grid.is_point_solid(c):
					continue
				var d := Vector2(c - id).length()
				if d < best_d:
					best_d = d
					best = c
		if best != Vector2i(-1, -1):
			return best
	return Vector2i(-1, -1)


## True when the straight line between two points crosses no blocked cell.
static func _sight(grid: AStarGrid2D, a: Vector2, b: Vector2) -> bool:
	var steps := int(ceil(a.distance_to(b) / (grid.cell_size.x * 0.5)))
	for k in range(1, steps):
		if grid.is_point_solid(_cell(grid, a.lerp(b, float(k) / steps))):
			return false
	return true
