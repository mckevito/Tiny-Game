class_name Wildlife
extends Node3D
## Friendly felt animals: rabbits, squirrels, deer at the edges in the morning and evening, and a bear who comes to
## sit by the fire. Scenery that wanders and reacts, never a resource or a threat: no physics, no lights, a capped
## number, each one model from data/models.json moved by code. Each PC draws its own (they are not sent over the
## network); a local player who comes close spots one, and the camp tells the host. Numbers: data/wildlife.json.

## Each animal: {"node", "row" (its herd), "home" (Vector3), "target" (Vector3), "wait" (s), "seen_day" (int)}.
var animals: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0


static func _v(key: String, fallback: Variant = null) -> Variant:
	return Tuning.value("wildlife", key, fallback)


func _ready() -> void:
	_rng.seed = 7
	var cap := int(_v("max_animals", 10))
	for row: Dictionary in _v("herds", []):
		for i in int(row.get("count", 1)):
			if animals.size() >= cap:
				return
			var node := Node3D.new()
			node.name = "%s_%d" % [row["model"], i]
			node.add_child(FeltBuilder.build(str(row["model"])))
			node.visible = false
			add_child(node)
			var h: Array = row.get("home", [0, 0])
			var home := Vector3(float(h[0]), 0.0, float(h[1]))
			var a := {"node": node, "row": row, "home": home, "target": home, "wait": 0.0, "seen_day": 0}
			node.position = _wander_point(a)
			a["target"] = node.position
			animals.append(a)


## Every animal kind (model) in data/wildlife.json.
static func kinds() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _v("herds", []):
		out.append(str(row["model"]))
	return out


## Whether a herd is out at this hour of this day.
static func is_out(row: Dictionary, hour: float, today: int) -> bool:
	if today < int(row.get("from_day", 1)):
		return false
	for span: Array in row.get("hours", [[0, 24]]):
		if hour >= float(span[0]) and hour < float(span[1]):
			return true
	return false


func _wander_point(a: Dictionary) -> Vector3:
	var roam := float(a["row"].get("roam_m", 0.0))
	var angle := _rng.randf() * TAU
	return (a["home"] as Vector3) + Vector3(cos(angle), 0.0, sin(angle)) * roam * sqrt(_rng.randf())


## Moves the animals on: each walks or rests, shies away from a nearby player, and shows only at its hours.
## `players` are the campers' positions; `spotters` the local ones. Returns the kinds (models) a local player just
## spotted for the first time today.
func tick(delta: float, hour: float, today: int, players: Array[Vector3], spotters: Array[Vector3]) -> Array[String]:
	_time += delta
	var seen: Array[String] = []
	for a in animals:
		var node: Node3D = a["node"]
		var row: Dictionary = a["row"]
		var out := is_out(row, hour, today)
		if out != node.visible:
			node.visible = out
			if out:
				node.position = a["home"] if bool(row.get("sit", false)) else _wander_point(a)
				a["target"] = node.position
		if not out:
			continue
		if bool(row.get("sit", false)):
			var face: Vector3 = Vector3.ZERO - node.position
			node.rotation.y = atan2(-face.x, -face.z)
		else:
			_move(a, delta, players)
		var spot := float(_v("spot_m", 5.0))
		if int(a["seen_day"]) != today:
			for p in spotters:
				if p.distance_to(node.position) <= spot:
					a["seen_day"] = today
					if not seen.has(str(row["model"])):
						seen.append(str(row["model"]))
					break
	return seen


func _move(a: Dictionary, delta: float, players: Array[Vector3]) -> void:
	var node: Node3D = a["node"]
	var row: Dictionary = a["row"]
	var speed := float(row.get("speed_mps", 1.0))
	var shy := float(row.get("shy_m", 0.0))
	for p in players:
		var away := node.position - Vector3(p.x, 0.0, p.z)
		if shy > 0.0 and away.length() < shy:
			var flee := node.position + away.normalized() * shy
			var home: Vector3 = a["home"]
			var limit := float(row.get("roam_m", 0.0)) * 1.5 + 0.01
			a["target"] = home + (flee - home).limit_length(limit)
			a["wait"] = 0.0
			speed *= 2.0
			break
	if float(a["wait"]) > 0.0:
		a["wait"] = float(a["wait"]) - delta
		node.get_child(0).position.y = 0.0
		return
	var target: Vector3 = a["target"]
	var step := target - node.position
	if step.length() < 0.05:
		a["target"] = _wander_point(a)
		a["wait"] = float(row.get("idle_s", 2.0)) * _rng.randf_range(0.5, 1.5)
		return
	node.position += step.limit_length(speed * delta)
	node.rotation.y = lerp_angle(node.rotation.y, atan2(-step.x, -step.z), minf(delta * 8.0, 1.0))
	if bool(row.get("hop", false)):
		node.get_child(0).position.y = absf(sin(_time * PI * float(_v("hop_hz", 3.0)))) * float(_v("hop_m", 0.1))


## The kind (model) of the nearest animal out now within `max_m` of a spot, or "".
func nearest(pos: Vector3, max_m: float) -> String:
	var best := ""
	var best_d := max_m
	for a in animals:
		var node: Node3D = a["node"]
		if node.visible and node.position.distance_to(pos) <= best_d:
			best_d = node.position.distance_to(pos)
			best = str(a["row"]["model"])
	return best

