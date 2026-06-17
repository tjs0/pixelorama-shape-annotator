extends RefCounted
## Single source of truth for shape annotations. This task adds only the pure
## resolver; CRUD + meta I/O follow in Task 4.

# Godot meta names must be valid ASCII identifiers (no "/"), so namespace with "_".
const META_KEY := "shape_annotator_shape_annotations"
const VERSION_KEY := "shape_annotator_schema_version"
const SCHEMA_VERSION := 1

## A frame override (a non-null Array) fully replaces the defaults for that
## frame; otherwise the per-sprite defaults apply. An empty Array is a real
## override meaning "this frame has no shapes".
static func resolve_effective(defaults: Array, frame_override: Variant) -> Array:
    if frame_override is Array:
        return frame_override
    return defaults

signal changed

var _project: Object = null

func bind(project: Object) -> void:
    _project = project
    if _project != null and not _project.has_meta(VERSION_KEY):
        _project.set_meta(VERSION_KEY, SCHEMA_VERSION)

func get_defaults() -> Array:
    if _project != null and _project.has_meta(META_KEY):
        return _project.get_meta(META_KEY)
    return []

func set_defaults(shapes: Array) -> void:
    _project.set_meta(META_KEY, shapes)
    changed.emit()

func get_frame_shapes(frame: Object) -> Variant:
    if frame != null and frame.has_meta(META_KEY):
        return frame.get_meta(META_KEY)
    return null

func set_frame_shapes(frame: Object, shapes: Variant) -> void:
    if shapes == null:
        if frame.has_meta(META_KEY):
            frame.remove_meta(META_KEY)
    else:
        frame.set_meta(META_KEY, shapes)
    changed.emit()

func add_shape(target_frame: Variant, shape: Dictionary) -> void:
    if target_frame == null:
        var d := get_defaults()
        d.append(shape)
        set_defaults(d)
    else:
        var current: Variant = get_frame_shapes(target_frame)
        var list: Array = current if current is Array else get_defaults().duplicate(true)
        list.append(shape)
        set_frame_shapes(target_frame, list)

func effective_for(frame: Object) -> Array:
    return resolve_effective(get_defaults(), get_frame_shapes(frame))

const MODE_SPRITE := 0
const MODE_FRAME := 1

static func array_with_added(arr: Array, shape: Dictionary) -> Array:
    var a := arr.duplicate(true)
    a.append(shape)
    return a

static func array_without_index(arr: Array, idx: int) -> Array:
    var a := arr.duplicate(true)
    if idx >= 0 and idx < a.size():
        a.remove_at(idx)
    return a

static func array_with_replaced(arr: Array, idx: int, shape: Dictionary) -> Array:
    var a := arr.duplicate(true)
    if idx >= 0 and idx < a.size():
        a[idx] = shape
    return a

static func target_for_mode(mode: int, frame: Object) -> Variant:
    return null if mode == MODE_SPRITE else frame

## Build an undoable meta change on the bound project's UndoRedo. `obj` is the
## project (defaults) or a Frame (override). `new_val` is the resulting array;
## undo restores `old_val` (or removes the key when `had` is false).
func _commit_meta(obj: Object, action_name: String, had: bool, old_val: Variant, new_val: Array) -> void:
    if _project == null or _project.undo_redo == null:
        return
    var ur: UndoRedo = _project.undo_redo
    var g: Node = Engine.get_main_loop().root.get_node_or_null("Global")
    ur.create_action(action_name)
    ur.add_do_method(obj.set_meta.bind(META_KEY, new_val))
    if had:
        ur.add_undo_method(obj.set_meta.bind(META_KEY, old_val))
    else:
        ur.add_undo_method(obj.remove_meta.bind(META_KEY))
    # Set Global's undo_or_redo flag before refreshing, so any listener that
    # inspects it during the refresh sees the correct state.
    if g != null:
        ur.add_do_method(g.undo_or_redo.bind(false))
        ur.add_undo_method(g.undo_or_redo.bind(true))
    ur.add_do_method(_emit_changed)
    ur.add_undo_method(_emit_changed)
    ur.commit_action()

func _emit_changed() -> void:
    changed.emit()

func add_shape_undoable(target_frame: Variant, shape: Dictionary) -> void:
    var obj: Object = _project if target_frame == null else target_frame
    var had := obj.has_meta(META_KEY)
    var old_val: Variant = obj.get_meta(META_KEY) if had else null
    var base: Array
    if target_frame == null:
        base = get_defaults()
    else:
        base = old_val if old_val is Array else get_defaults().duplicate(true)
    _commit_meta(obj, "Add shape annotation", had, old_val, array_with_added(base, shape))

func delete_shape_undoable(target_frame: Variant, index: int) -> void:
    var obj: Object = _project if target_frame == null else target_frame
    if not obj.has_meta(META_KEY):
        return
    var old_val: Array = obj.get_meta(META_KEY)
    _commit_meta(obj, "Delete shape annotation", true, old_val, array_without_index(old_val, index))

func replace_shape_undoable(target_frame: Variant, index: int, shape: Dictionary) -> void:
    var obj: Object = _project if target_frame == null else target_frame
    if not obj.has_meta(META_KEY):
        return
    var old_val: Array = obj.get_meta(META_KEY)
    if index < 0 or index >= old_val.size():
        return
    _commit_meta(obj, "Edit shape annotation", true, old_val, array_with_replaced(old_val, index, shape))
