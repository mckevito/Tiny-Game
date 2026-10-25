extends RefCounted
## Milestone 1: movement follows the camera, the camera fades trees that hide the player, models face where placed.


func test_forward_is_away_from_the_camera() -> String:
	var v := Camper.wish_velocity(Vector2(0, -1), 0.0)
	if not (v.z < 0.0 and absf(v.x) < 0.001):
		return "forward with an unturned camera should be -Z, got %s" % v
	var turned := Camper.wish_velocity(Vector2(0, -1), PI / 2.0)
	return "" if turned.x < -0.9 * turned.length() else "forward with the camera turned 90 degrees gave %s" % turned


func test_tree_between_camera_and_player_fades() -> String:
	var eye := Vector3(0, 8, 8)
	var aim := Vector3(0, 0.7, 0)
	if not PlayCamera.column_hides(eye, aim, Vector3(0, 0, 2), 1.0, 3.0):
		return "a tree in front of the player should fade"
	if PlayCamera.column_hides(eye, aim, Vector3(0, 0, -3), 1.0, 3.0):
		return "a tree behind the player should not fade"
	if PlayCamera.column_hides(eye, aim, Vector3(4, 0, 2), 1.0, 3.0):
		return "a tree off to the side should not fade"
	return ""


func test_face_turns_the_front_toward_a_point() -> String:
	var t := Clearing.placement_transform({"pos": [4, 0], "face": [0, 0]})
	var front := -t.basis.z
	return "" if front.is_equal_approx(Vector3(-1, 0, 0)) else "front points %s" % front


func test_camera_zoom_limits_are_ordered() -> String:
	var lo := Tuning.num("tuning", "camera.min_distance_m")
	var mid := Tuning.num("tuning", "camera.distance_m")
	var hi := Tuning.num("tuning", "camera.max_distance_m")
	return "" if lo > 0.0 and lo <= mid and mid <= hi else "camera distances out of order: %s %s %s" % [lo, mid, hi]
