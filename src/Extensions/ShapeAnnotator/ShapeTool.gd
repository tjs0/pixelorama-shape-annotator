extends BaseTool
## Draws shape annotations by click-drag. Writes only metadata, never pixels.

const ShapeGeom = preload("ShapeGeom.gd")
const ShapeStore = preload("ShapeStore.gd")
const ShapeConfig = preload("ShapeConfig.gd")
const ShapeHit = preload("ShapeHit.gd")

enum { ACTION_DRAW = 0, ACTION_EDIT = 1 }
var current_action := ACTION_DRAW

var _action_picker: OptionButton
var _gesture := {}  # {kind:"move"/"resize"/"rotate", handle_id, index, start_pos, td0}

# Injected by Main before the tool node is instantiated by the Tools API.
static var shared_store: ShapeStore
static var shared_overlay: Node
# The Main extension node, used for open_settings() / tag_names(). A plain Node
# reference is stored here rather than capturing lambdas: storing a self-capturing
# lambda Callable in a `static` var outlives the capturing instance and double-frees
# at engine teardown (heap corruption / crash).
static var shared_host: Node

var current_type := "rect"
var current_tag := ""
var current_mode := ShapeStore.MODE_SPRITE
var default_radius := 4

var _shape_picker: OptionButton
var _tag_pick: OptionButton
var _mode_picker: OptionButton
var _radius_row: HBoxContainer
var _radius_spin: SpinBox
var _show_check: CheckButton

var _start := Vector2i.ZERO
var _dragging := false

func _ready() -> void:
	super()  # BaseTool: colored bar + tool name label + load_config()
	_build_options()
	_refresh_tag_dropdown()
	# BaseTool.load_config() (in super) ran set_config() before the pickers
	# existed, so update_config() bailed early and left the UI + overlay out of
	# sync with the loaded config. Re-sync now that the controls are built —
	# otherwise current_action can be ACTION_EDIT while the dropdown shows "Draw",
	# routing draw_start() into edit mode so no shapes are drawn.
	update_config()
	if shared_host != null and shared_host.has_method("register_tool"):
		shared_host.register_tool(self)

func _exit_tree() -> void:
	if shared_host != null and is_instance_valid(shared_host) and shared_host.has_method("unregister_tool"):
		shared_host.unregister_tool(self)

func _labeled_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	add_child(row)
	return row

func _build_options() -> void:
	_action_picker = OptionButton.new()
	_action_picker.add_item("Draw")   # ACTION_DRAW
	_action_picker.add_item("Edit")   # ACTION_EDIT
	_action_picker.item_selected.connect(func(i):
		current_action = i
		if shared_overlay != null:
			shared_overlay.editing = (i == ACTION_EDIT)
			shared_overlay.refresh()
		save_config())
	_labeled_row("Action:", _action_picker)

	_shape_picker = OptionButton.new()
	_shape_picker.add_item("Rectangle"); _shape_picker.add_item("Circle"); _shape_picker.add_item("Capsule")
	_shape_picker.item_selected.connect(func(i):
		current_type = ["rect", "circle", "capsule"][i]
		_apply_radius_visibility()
		save_config())
	_labeled_row("Shape:", _shape_picker)

	# Single Tag control: a dropdown whose first entry, "Add New…", opens the
	# settings dialog to define a new tag→color mapping. Remaining entries are the
	# configured tags, each shown with its color swatch.
	_tag_pick = OptionButton.new()
	_tag_pick.item_selected.connect(func(i):
		if i == 0:  # "Add New…"
			_select_current_tag()  # don't leave "Add New…" showing
			if shared_host != null:
				shared_host.open_settings()
			return
		current_tag = _tag_pick.get_item_text(i)
		save_config())
	_labeled_row("Tag:", _tag_pick)

	_mode_picker = OptionButton.new()
	_mode_picker.add_item("Sprite (all frames)")  # index 0 = MODE_SPRITE
	_mode_picker.add_item("This frame")           # index 1 = MODE_FRAME
	_mode_picker.item_selected.connect(func(i): current_mode = i; save_config())
	_labeled_row("Mode:", _mode_picker)

	_radius_spin = SpinBox.new()
	_radius_spin.min_value = 1
	_radius_spin.max_value = 256
	_radius_spin.value = default_radius
	_radius_spin.value_changed.connect(func(v): default_radius = int(v); save_config())
	_radius_row = _labeled_row("Radius:", _radius_spin)

	_show_check = CheckButton.new()
	_show_check.text = "Show annotations"
	_show_check.button_pressed = shared_overlay == null or shared_overlay.visible
	_show_check.toggled.connect(func(on):
		if shared_overlay != null:
			shared_overlay.visible = on
			shared_overlay.refresh()
		ShapeConfig.save_show(Global.config_cache, on)
		Global.config_cache.save(Global.CONFIG_PATH))
	add_child(_show_check)

	var settings_btn := Button.new()
	settings_btn.text = "Settings…"
	settings_btn.pressed.connect(func():
		if shared_host != null:
			shared_host.open_settings())
	add_child(settings_btn)

## Public alias so Main can rebuild the dropdown after the tag→color map changes.
func refresh_tags() -> void:
	_refresh_tag_dropdown()

func _refresh_tag_dropdown() -> void:
	if _tag_pick == null:
		return
	_tag_pick.clear()
	_tag_pick.add_item("Add New…")  # index 0 — always first
	var colors: Dictionary = {}
	if shared_host != null and shared_host.has_method("tag_colors_map"):
		colors = shared_host.tag_colors_map()
	for t in colors:
		_tag_pick.add_icon_item(_color_swatch(colors[t]), t)
	_select_current_tag()

## Selects the dropdown entry matching current_tag, falling back to "Add New…".
func _select_current_tag() -> void:
	if _tag_pick == null:
		return
	for i in _tag_pick.item_count:
		if i > 0 and _tag_pick.get_item_text(i) == current_tag:
			_tag_pick.selected = i
			return
	_tag_pick.selected = 0

func _color_swatch(c: Color) -> ImageTexture:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _apply_radius_visibility() -> void:
	if _radius_row != null:
		_radius_row.visible = current_type == "capsule"

func _edit_target() -> Variant:
	var proj := Global.current_project
	var frame: Object = proj.frames[proj.current_frame]
	return frame if shared_store.get_frame_shapes(frame) is Array else null

func _effective_shapes() -> Array:
	var proj := Global.current_project
	return shared_store.effective_for(proj.frames[proj.current_frame])

func _pick_tol() -> float:
	var g := get_node_or_null("/root/Global")
	if g != null and g.camera != null:
		return 8.0 / maxf(0.001, g.camera.zoom.x)
	return 8.0

func draw_start(pos: Vector2i) -> void:
	super(pos)
	if current_action == ACTION_DRAW:
		_start = pos
		_dragging = true
		return
	_begin_edit(Vector2(pos))

func draw_move(pos: Vector2i) -> void:
	if current_action == ACTION_DRAW:
		if _dragging and shared_overlay != null:
			shared_overlay.set_preview({
				"type": current_type, "start": _start, "dest": pos,
				"tag": current_tag, "radius": default_radius,
			})
		return
	_update_edit(Vector2(pos))

func draw_end(pos: Vector2i) -> void:
	if current_action == ACTION_EDIT:
		_commit_edit()
		super(pos)
		return
	if not _dragging:
		return
	_dragging = false
	if shared_overlay != null:
		shared_overlay.clear_preview()
	if pos == _start:
		super(pos)
		return
	var td := ShapeGeom.from_drag(current_type, _start, pos, default_radius)
	var shape := {"type": current_type, "type_data": td, "meta": {"tag": current_tag}}
	if shared_store != null:
		var frame: Object = Global.current_project.frames[Global.current_project.current_frame]
		shared_store.add_shape_undoable(ShapeStore.target_for_mode(current_mode, frame), shape)
	super(pos)

func cancel_tool() -> void:
	_dragging = false
	_gesture = {}
	if shared_overlay != null:
		shared_overlay.clear_preview()
		shared_overlay.clear_edit_preview()

func _begin_edit(p: Vector2) -> void:
	_gesture = {}
	if shared_overlay == null or shared_store == null:
		return
	var shapes := _effective_shapes()
	var sel: int = shared_overlay.selected_index
	# 1) a handle of the currently-selected shape?
	if sel >= 0 and sel < shapes.size():
		var s: Dictionary = shapes[sel]
		var hid := ShapeHit.hit_handle(s["type"], s["type_data"], p, _pick_tol())
		if hid != "":
			# hit_handle only returns "" or a real handle id; any non-rotate id is a resize handle.
			var kind := "rotate" if hid == "rotate" else "resize"
			_gesture = {"kind": kind, "handle_id": hid, "index": sel, "start_pos": p, "td0": s["type_data"], "shape0": s}
			return
	# 2) otherwise hit-test shapes (topmost, cycling)
	var hits := ShapeHit.shapes_at_point(shapes, p)
	if hits.is_empty():
		shared_overlay.selected_index = -1
		shared_overlay.refresh()
		return
	var idx := _next_cycle(hits, sel)
	shared_overlay.selected_index = idx
	shared_overlay.refresh()
	var s2: Dictionary = shapes[idx]
	_gesture = {"kind": "move", "handle_id": "", "index": idx, "start_pos": p, "td0": s2["type_data"], "shape0": s2}

func _next_cycle(hits: PackedInt32Array, current: int) -> int:
	# pick the topmost (largest index) hit; if it's already selected, take the next one down (wrap).
	var ordered := hits.duplicate()
	ordered.sort()
	ordered.reverse()
	if ordered.has(current):
		var at := ordered.find(current)
		return ordered[(at + 1) % ordered.size()]
	return ordered[0]

func _update_edit(p: Vector2) -> void:
	if _gesture.is_empty() or shared_overlay == null:
		return
	var s0: Dictionary = _gesture["shape0"]
	var td0: Dictionary = _gesture["td0"]
	var new_td: Dictionary
	match _gesture["kind"]:
		"move":
			new_td = ShapeHit.apply_move(s0["type"], td0, p - _gesture["start_pos"])
		"resize":
			new_td = ShapeHit.apply_resize(s0["type"], td0, _gesture["handle_id"], p)
		"rotate":
			var snap := not Input.is_key_pressed(KEY_ALT)
			new_td = ShapeHit.apply_rotate(s0["type"], td0, p, snap)
		_:
			return
	shared_overlay.set_edit_preview({"type": s0["type"], "type_data": new_td, "meta": s0.get("meta", {})})

func _commit_edit() -> void:
	if _gesture.is_empty() or shared_overlay == null or shared_store == null:
		_gesture = {}
		if shared_overlay != null:
			shared_overlay.clear_edit_preview()
		return
	var preview = shared_overlay.edit_preview
	if preview is Dictionary:
		shared_store.replace_shape_undoable(_edit_target(), _gesture["index"], preview)
	shared_overlay.clear_edit_preview()
	_gesture = {}

func get_config() -> Dictionary:
	# `action` (Draw vs Edit) is a transient mode, intentionally not persisted —
	# the tool always opens in Draw mode so drawing works immediately on load.
	return {"type": current_type, "tag": current_tag, "mode": current_mode, "radius": default_radius}

func set_config(config: Dictionary) -> void:
	current_type = config.get("type", current_type)
	current_tag = config.get("tag", current_tag)
	current_mode = config.get("mode", current_mode)
	default_radius = config.get("radius", default_radius)

func update_config() -> void:
	if _shape_picker == null:
		return
	_shape_picker.selected = ["rect", "circle", "capsule"].find(current_type)
	_select_current_tag()
	_mode_picker.selected = current_mode
	_radius_spin.value = default_radius
	_apply_radius_visibility()
	_action_picker.selected = current_action
	if shared_overlay != null:
		shared_overlay.editing = (current_action == ACTION_EDIT)
