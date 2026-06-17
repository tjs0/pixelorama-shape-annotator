extends GutTest

const ShapeStore = preload("res://src/Extensions/ShapeAnnotator/ShapeStore.gd")

class FakeProject:
    extends Object  # set_meta/get_meta are Object builtins

class FakeFrame:
    extends Object

func _shape(tag: String) -> Dictionary:
    return {"type": "rect", "type_data": {"x": 0, "y": 0, "w": 1, "h": 1}, "meta": {"tag": tag}}

func test_set_and_get_defaults_via_meta():
    var proj = FakeProject.new()
    var store = ShapeStore.new()
    store.bind(proj)
    store.set_defaults([_shape("hurtbox")])
    assert_eq(store.get_defaults(), [_shape("hurtbox")])
    assert_eq(proj.get_meta(ShapeStore.META_KEY), [_shape("hurtbox")], "persisted on the project meta")
    proj.free()

func test_get_defaults_empty_when_unset():
    var proj = FakeProject.new()
    var store = ShapeStore.new()
    store.bind(proj)
    assert_eq(store.get_defaults(), [])
    proj.free()

func test_frame_override_roundtrip_and_clear():
    var proj = FakeProject.new()
    var frame = FakeFrame.new()
    var store = ShapeStore.new()
    store.bind(proj)
    store.set_frame_shapes(frame, [_shape("hitbox")])
    assert_eq(store.get_frame_shapes(frame), [_shape("hitbox")])
    store.set_frame_shapes(frame, null)
    assert_null(store.get_frame_shapes(frame), "null clears the override key")
    proj.free()
    frame.free()

func test_add_shape_to_frame_seeds_from_defaults():
    var proj = FakeProject.new()
    var frame = FakeFrame.new()
    var store = ShapeStore.new()
    store.bind(proj)
    store.set_defaults([_shape("hurtbox")])
    store.add_shape(frame, _shape("hitbox"))
    assert_eq(store.get_frame_shapes(frame), [_shape("hurtbox"), _shape("hitbox")],
        "frame override is seeded from current defaults then appended")
    proj.free()
    frame.free()

func test_effective_for_uses_resolver():
    var proj = FakeProject.new()
    var frame = FakeFrame.new()
    var store = ShapeStore.new()
    store.bind(proj)
    store.set_defaults([_shape("hurtbox")])
    assert_eq(store.effective_for(frame), [_shape("hurtbox")])
    store.set_frame_shapes(frame, [_shape("hitbox")])
    assert_eq(store.effective_for(frame), [_shape("hitbox")])
    proj.free()
    frame.free()
