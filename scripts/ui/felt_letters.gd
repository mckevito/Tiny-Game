class_name FeltLetters
extends Control
## Felt lettering for titles and signs, the owner's Pinned Felt (26 Oct 2026): fat felt letters taking turns in the
## season's colours, a felt back behind them with a soft shadow, a running stitch just inside each letter's edge and a
## push pin on every other letter. Colours: UiLook.felt_colours() (data/look.json presets, by season, picked in
## Options); sizes: data/look.json "felt", as fractions of the font size. Long text wraps onto balanced lines.
##
## Drawn in three layers so the stitch can be dashed by its own shader: this node draws the shadow, the back and the
## fat letters; `_seam` the stitch line (felt_seam.gdshader cuts it into stitches); `_top` the letters' faces and the
## pins. The faces cover every part of a letter's stitch that falls inside it, which hides the font's overlapping
## pieces (the stem and bowl of p and g) that a plain outline would stitch across.

## An outline of size n spreads n / 4 px round a glyph (Godot's FreeType stroker; measured on Fredoka).
const OUTLINE_PER_PX := 4.0

@export var text := "":
	set(v):
		text = v
		_relayout()
@export var font_px := 56:
	set(v):
		font_px = v
		_relayout()
@export var pins := true:
	set(v):
		pins = v
		queue_redraw_all()

## Each glyph: [character code, baseline position, angle in radians, colour index].
var _glyphs: Array = []
var _seam := Control.new()
var _top := Control.new()


func _init() -> void:
	add_to_group("felt_letters")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for layer: Control in [_seam, _top]:
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(layer)
	_seam.draw.connect(_draw_seam)
	_top.draw.connect(_draw_top)
	var stitch := ShaderMaterial.new()
	stitch.shader = preload("res://scripts/ui/felt_seam.gdshader")
	_seam.material = stitch
	resized.connect(_relayout)


func _n(key: String, fallback: float) -> float:
	return Tuning.num("look", "felt." + key, fallback)


## Redraws all three layers (UiLook.refresh calls it on every felt lettering when the season or preset changes).
func queue_redraw_all() -> void:
	queue_redraw()
	_seam.queue_redraw()
	_top.queue_redraw()


## The lines the text is drawn on: one, or split at the spaces into as few balanced lines as fit the width.
func lines() -> PackedStringArray:
	var f := UiLook.font("felt")
	var room := size.x - font_px * _n("margin", 0.3) * 2.0
	if room <= 0.0 or _width(text, f) <= room:
		return PackedStringArray([text])
	var words := text.split(" ")
	for count in range(2, words.size() + 1):
		var split := _balanced(words, count, f)
		if Array(split).all(func(line: String) -> bool: return _width(line, f) <= room):
			return split
	return PackedStringArray(words)


## Splits words into `count` lines, each close to an equal share of the width.
func _balanced(words: PackedStringArray, count: int, f: Font) -> PackedStringArray:
	var share := _width(" ".join(words), f) / count
	var out := PackedStringArray()
	var line := ""
	for w in words:
		var next := w if line == "" else line + " " + w
		if line != "" and out.size() < count - 1 and _width(next, f) > share * _n("balance_slack", 1.1):
			out.append(line)
			line = w
		else:
			line = next
	out.append(line)
	return out


func _width(s: String, f: Font) -> float:
	var w := 0.0
	for ch in s:
		w += f.get_char_size(ch.unicode_at(0), font_px).x
	return w


func _relayout() -> void:
	var f := UiLook.font("felt")
	var rows := lines()
	var line_h := font_px * _n("line_gap", 1.08)
	var margin := font_px * _n("margin", 0.3)
	custom_minimum_size.y = line_h * rows.size() + margin * 2.0
	_glyphs.clear()
	# A fixed seed per text, so the hand-cut tilt is the same every time the title shows.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var tilt := deg_to_rad(_n("jitter_deg", 3.0))
	var bob := font_px * _n("jitter_y", 0.03)
	var k := 0
	for i in rows.size():
		var x := (size.x - _width(rows[i], f)) * 0.5
		var y := margin + f.get_ascent(font_px) + i * line_h
		for ch in rows[i]:
			var code := ch.unicode_at(0)
			_glyphs.append([code, Vector2(x, y + rng.randf_range(-bob, bob)), rng.randf_range(-tilt, tilt), k])
			x += f.get_char_size(code, font_px).x
			if ch != " ":
				k += 1
	queue_redraw_all()


## Draws one glyph, its outline spread `px` round it (0: the plain face), turned to the glyph's angle.
func _glyph(on: CanvasItem, g: Array, px: float, colour: Color, shift := Vector2.ZERO) -> void:
	var f := UiLook.font("felt")
	on.draw_set_transform(g[1] + shift, g[2])
	if px > 0.0:
		f.draw_char_outline(on.get_canvas_item(), Vector2.ZERO, g[0], font_px, int(round(px * OUTLINE_PER_PX)), colour)
	else:
		f.draw_char(on.get_canvas_item(), Vector2.ZERO, g[0], font_px, colour)
	on.draw_set_transform(Vector2.ZERO)


func _letter(c: Dictionary, g: Array) -> Color:
	var list: Array = c["letters"]
	return list[g[3] % list.size()]


func _draw() -> void:
	var c := UiLook.felt_colours()
	var fat := font_px * _n("fat", 0.07)
	var back := fat + font_px * _n("back", 0.2)
	var shadow_at: Array = Tuning.value("look", "felt.shadow", [0.03, 0.06])
	var shadow := Color(0, 0, 0, _n("shadow_alpha", 0.35))
	for g: Array in _glyphs:
		_glyph(self, g, back, shadow, Vector2(shadow_at[0], shadow_at[1]) * font_px)
	for g: Array in _glyphs:
		_glyph(self, g, back, c["back"])
	for g: Array in _glyphs:
		var edge := _letter(c, g).darkened(_n("edge_darken", 0.22))
		_glyph(self, g, fat + _n("edge_px", 1.0), edge)
		_glyph(self, g, fat, _letter(c, g))


func _draw_seam() -> void:
	var c := UiLook.felt_colours()
	var m := _seam.material as ShaderMaterial
	m.set_shader_parameter("stitch_px", font_px * _n("stitch", 0.11))
	m.set_shader_parameter("on", _n("stitch_on", 0.6))
	var outer := font_px * (_n("fat", 0.07) - _n("seam_gap", 0.035))
	for g: Array in _glyphs:
		_glyph(_seam, g, outer, c["seam"])


func _draw_top() -> void:
	var c := UiLook.felt_colours()
	var inner := font_px * (_n("fat", 0.07) - _n("seam_gap", 0.035) - _n("seam_px", 0.03))
	for g: Array in _glyphs:
		if inner > 0.0:
			_glyph(_top, g, inner, _letter(c, g))
		_glyph(_top, g, 0.0, _letter(c, g))
	if not pins:
		return
	var f := UiLook.font("felt")
	var r := font_px * _n("pin_r", 0.085)
	var every := maxi(int(_n("pin_every", 2)), 1)
	var shadow_at: Array = Tuning.value("look", "felt.shadow", [0.03, 0.06])
	var pin_drop := _n("pin_drop", 6.0)
	for g: Array in _glyphs:
		if g[0] == 32 or g[3] % every != 0:
			continue
		var w := f.get_char_size(g[0], font_px).x
		var at: Vector2 = g[1] + Vector2(w * 0.5, -f.get_ascent(font_px) * _n("pin_y", 0.62)).rotated(g[2])
		var pin: Color = c["pins"][(g[3] / every) % (c["pins"] as Array).size()]
		_top.draw_circle(at + Vector2(shadow_at[0], shadow_at[1]) * r * pin_drop, r, Color(0, 0, 0, _n("shadow_alpha", 0.35)))
		_top.draw_circle(at, r, pin.darkened(_n("edge_darken", 0.22)))
		_top.draw_circle(at, r * _n("pin_face", 0.8), pin)
		_top.draw_circle(at - Vector2(r, r) * _n("pin_shine", 0.3), r * _n("pin_shine", 0.3), Color(1, 1, 1, _n("pin_shine_alpha", 0.7)))
