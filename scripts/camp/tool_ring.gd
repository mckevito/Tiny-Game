class_name ToolRing
extends Control
## A player's tool ring, like Animal Crossing's tool wheel: hold the tool button and every tool sits in a ring of felt
## buttons around the camper; point at one with the mouse or the stick (or the walking keys) and let go to take it out.
## A tap, let go before the ring opens, still steps to the next tool. One per local player, so on the couch each ring
## opens round its own camper in its own half. The tool in hand has a rust edge, the one pointed at is honey and a
## little bigger, and its name sits under the ring. Sizes and colours: data/tuning.json "ring".

## The player this ring belongs to.
var who := ""
## Seconds the tool button has been held.
var held := 0.0
## The slot pointed at, or -1 while nothing is.
var hover := -1
## The tool names, in data/items.json tools.order.
var names: Array[String] = []
## The slot of the tool in hand.
var current := 0
## True when opening the ring stopped the camper walking (closing it lets them walk again).
var froze := false

var _font: Font


static func _n(key: String, fallback: float = 0.0) -> float:
	return Tuning.num("tuning", "ring." + key, fallback)


static func _colour(key: String, fallback: String) -> Color:
	return FeltBuilder.swatch(str(Tuning.value("tuning", "ring." + key, fallback))).linear_to_srgb()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_font = get_theme_default_font()


## True once the button has been held long enough for the ring to show (tuning ring.hold_s).
func tick(delta: float) -> bool:
	held += delta
	if not visible and held >= _n("hold_s", 0.25):
		visible = true
		return true
	return false


## Shows the ring round `centre` (screen pixels), moved in so the whole ring stays inside `view`.
func place(centre: Vector2, view: Rect2) -> void:
	var reach := _n("radius_px", 120.0) + _n("slot_px", 40.0) * _n("hover_scale", 1.2) + _n("name_px", 22.0) * 2.0
	var room := view.grow(-reach)
	position = centre.clamp(room.position, room.end) if room.has_area() else view.get_center()
	queue_redraw()


## Points from the ring's centre along `dir` (screen space: +x right, +y down); a short `dir` keeps the last slot.
func point(dir: Vector2, deadzone: float) -> void:
	if dir.length() < deadzone or names.is_empty():
		return
	hover = slot_at(dir, names.size())
	queue_redraw()


## The slot a direction points at, slot 0 at the top and the rest clockwise.
static func slot_at(dir: Vector2, count: int) -> int:
	var turn := fposmod(atan2(dir.x, -dir.y), TAU)
	return posmod(roundi(turn / (TAU / count)), count)


## Where slot `i` of `count` sits from the ring's centre.
static func slot_offset(i: int, count: int, radius: float) -> Vector2:
	var a := TAU * i / count
	return Vector2(sin(a), -cos(a)) * radius


func _draw() -> void:
	var count := names.size()
	if count == 0:
		return
	var radius := _n("radius_px", 120.0)
	var slot := _n("slot_px", 40.0)
	var font_px := int(_n("font_px", 17))
	var ink := _colour("ink_swatch", "ink_brown")
	var bed := _colour("swatch", "warm_cream")
	bed.a = _n("alpha", 0.9)
	# The felt band as one polygon (out round the outer edge, back round the inner): a thick draw_arc leaves a seam.
	var half := slot + _n("pad_px", 12.0)
	var band := PackedVector2Array()
	for i in 65:
		band.append(Vector2.from_angle(TAU * i / 64.0) * (radius + half))
	for i in 65:
		band.append(Vector2.from_angle(TAU * (64 - i) / 64.0) * (radius - half))
	draw_colored_polygon(band, bed)
	for i in count:
		var at := slot_offset(i, count, radius)
		var big := slot * (_n("hover_scale", 1.2) if i == hover else 1.0)
		var fill := _colour("hover_swatch", "honey_thread") if i == hover else _colour("slot_swatch", "warm_cream")
		draw_circle(at, big, fill)
		var edge := _colour("current_swatch", "rust_canvas") if i == current else _colour("edge_swatch", "honey_thread")
		draw_arc(at, big, 0.0, TAU, 40, edge, _n("edge_px", 4.0), true)
		var w := big * 2.0 - _n("edge_px", 4.0) * 2.0
		var size := _font.get_multiline_string_size(names[i], HORIZONTAL_ALIGNMENT_CENTER, w, font_px)
		draw_multiline_string(_font, at - Vector2(w * 0.5, size.y * 0.5 - _font.get_ascent(font_px)), names[i],
				HORIZONTAL_ALIGNMENT_CENTER, w, font_px, -1, ink)
	if hover >= 0:
		# The pointed tool's name under the ring, outlined like the dock's captions.
		var name_px := int(_n("name_px", 22))
		var w := radius * 2.0 + slot * 2.0
		var y := radius + slot * _n("hover_scale", 1.2) + _n("pad_px", 12.0) + _font.get_ascent(name_px)
		var from := Vector2(-w * 0.5, y)
		draw_string_outline(_font, from, names[hover], HORIZONTAL_ALIGNMENT_CENTER, w, name_px,
				int(_n("outline_px", 6)), Color.BLACK)
		draw_string(_font, from, names[hover], HORIZONTAL_ALIGNMENT_CENTER, w, name_px, Color.WHITE)
