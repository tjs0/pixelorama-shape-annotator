extends Node2D
## Draws shape-annotation outlines for the current frame in canvas/pixel space.

const ShapeStore = preload("ShapeStore.gd")
const ShapeConfig = preload("ShapeConfig.gd")
const ShapeGeom = preload("ShapeGeom.gd")
const ShapeHit = preload("ShapeHit.gd")

var store: ShapeStore
var get_current_frame: Callable
var selected_index := -1

var tag_colors: Dictionary = ShapeConfig.DEFAULT_TAG_COLORS.duplicate(true)
var fallback: Color = ShapeConfig.FALLBACK_COLOR
var preview: Variant = null  # {type, start: Vector2i, dest: Vector2i, tag, radius}
var edit_preview: Variant = null  # full shape dict being dragged, or null
var editing := false              # true while the Shape tool is in Edit mode

func color_for_tag(tag: String) -> Color:
	return tag_colors.get(tag, fallback)

static func capsule_outline_points(td: Dictionary, segments: int) -> PackedVector2Array:
	var a := Vector2(td["x1"], td["y1"])
	var b := Vector2(td["x2"], td["y2"])
	var r: float = td["r"]
	var ang := (b - a).angle()
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var t := ang - PI / 2.0 + PI * float(i) / float(segments)
		pts.append(b + Vector2(cos(t), sin(t)) * r)
	for i in range(segments + 1):
		var t := ang + PI / 2.0 + PI * float(i) / float(segments)
		pts.append(a + Vector2(cos(t), sin(t)) * r)
	pts.append(pts[0])
	return pts

func set_preview(p: Variant) -> void:
	preview = p
	queue_redraw()

func clear_preview() -> void:
	preview = null
	queue_redraw()

func set_edit_preview(shape: Variant) -> void:
	edit_preview = shape
	queue_redraw()

func clear_edit_preview() -> void:
	edit_preview = null
	queue_redraw()

func selected_shape() -> Variant:
	if not get_current_frame.is_valid() or store == null:
		return null
	var shapes := store.effective_for(get_current_frame.call())
	if selected_index >= 0 and selected_index < shapes.size():
		return shapes[selected_index]
	return null

func refresh() -> void:
	queue_redraw()

func _input(event: InputEvent) -> void:
	# Mirror Pixelorama's Previews/Indicators: repaint live during a drag.
	if (preview != null or edit_preview != null) and event is InputEventMouse:
		queue_redraw()

func _line_width() -> float:
	var g := get_node_or_null("/root/Global")
	if g != null and g.camera != null:
		return 1.0 / maxf(0.001, g.camera.zoom.x)
	return 1.0

func _draw_shape(type: String, td: Dictionary, col: Color, lw: float) -> void:
	match type:
		"rect":
			if absf(td.get("angle", 0.0)) < 0.001:
				draw_rect(Rect2(td["x"], td["y"], td["w"], td["h"]), col, false, lw)
			else:
				var cor := ShapeHit.rect_corners(td)
				var pts := PackedVector2Array(cor)
				pts.append(cor[0])
				draw_polyline(pts, col, lw)
		"circle":
			draw_arc(Vector2(td["x"], td["y"]), td["r"], 0, TAU, 32, col, lw)
		"capsule":
			draw_polyline(capsule_outline_points(td, 12), col, lw)

func _draw() -> void:
	if store == null or not get_current_frame.is_valid():
		return
	var lw := _line_width()
	var shapes := store.effective_for(get_current_frame.call())
	for idx in shapes.size():
		var shape: Dictionary = shapes[idx]
		# While dragging, the selected shape shows its in-progress geometry.
		if idx == selected_index and edit_preview is Dictionary:
			shape = edit_preview
		var tag: String = shape.get("meta", {}).get("tag", "")
		var col := color_for_tag(tag)
		if idx == selected_index:
			col = col.lightened(0.4)
		_draw_shape(shape["type"], shape["type_data"], col, lw)
	if preview is Dictionary:
		var td := ShapeGeom.from_drag(preview["type"], preview["start"], preview["dest"], preview["radius"])
		_draw_shape(preview["type"], td, color_for_tag(preview["tag"]), lw)
	if editing:
		_draw_handles(lw)

func _draw_handles(lw: float) -> void:
	var sel = edit_preview if edit_preview is Dictionary else selected_shape()
	if not (sel is Dictionary):
		return
	var hs := ShapeHit.handles(sel["type"], sel["type_data"])
	var sz := ShapeHit.HANDLE_PX * lw
	# White fill + black outline so handles stay visible on any canvas color.
	for id in hs:
		var pos: Vector2 = hs[id]
		if id == "rotate":
			draw_circle(pos, sz, Color.WHITE)
			draw_arc(pos, sz, 0, TAU, 12, Color.BLACK, lw)
		else:
			var rect := Rect2(pos - Vector2(sz, sz), Vector2(sz, sz) * 2.0)
			draw_rect(rect, Color.WHITE, true)
			draw_rect(rect, Color.BLACK, false, lw)
