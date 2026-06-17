extends Control

const ShapeStore = preload("ShapeStore.gd")
const ShapeOverlay = preload("ShapeOverlay.gd")

var store: ShapeStore
var overlay: ShapeOverlay
var get_current_frame: Callable

var _root: VBoxContainer

func _ready() -> void:
	name = "Shapes"
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	if store != null:
		store.changed.connect(rebuild)
	rebuild()

func rebuild() -> void:
	if _root == null or store == null:
		return
	for c in _root.get_children():
		c.queue_free()
	var has_override := false
	if get_current_frame.is_valid():
		has_override = store.get_frame_shapes(get_current_frame.call()) is Array
	_add_section("Sprite defaults", store.get_defaults(), null, not has_override)
	if get_current_frame.is_valid() and has_override:
		var frame: Object = get_current_frame.call()
		_add_section("This frame (override)", store.get_frame_shapes(frame), frame, true)

func _add_section(title: String, shapes: Array, frame: Variant, effective: bool) -> void:
	var label := Label.new()
	label.text = title
	_root.add_child(label)
	for idx in shapes.size():
		var shape: Dictionary = shapes[idx]
		var tag: String = shape.get("meta", {}).get("tag", "")
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.color = overlay.color_for_tag(tag) if overlay != null else Color.WHITE
		row.add_child(swatch)
		var name_btn := Button.new()
		name_btn.text = "%s [%s]" % [shape["type"], tag]
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.pressed.connect(func(i := idx, eff := effective):
			if overlay != null and eff:
				overlay.selected_index = i
				overlay.refresh())
		var del := Button.new()
		del.text = "X"
		del.pressed.connect(_make_delete(frame, idx))
		row.add_child(name_btn)
		row.add_child(del)
		_root.add_child(row)

func _make_delete(frame: Variant, idx: int) -> Callable:
	return func(): store.delete_shape_undoable(frame, idx)
