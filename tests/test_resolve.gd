extends GutTest

const ShapeStore = preload("res://src/Extensions/ShapeAnnotator/ShapeStore.gd")

func _shape(tag: String) -> Dictionary:
    return {"type": "rect", "type_data": {"x": 0, "y": 0, "w": 1, "h": 1}, "meta": {"tag": tag}}

func test_no_override_returns_defaults():
    var defaults = [_shape("hurtbox")]
    assert_eq(ShapeStore.resolve_effective(defaults, null), defaults)

func test_override_replaces_defaults():
    var defaults = [_shape("hurtbox")]
    var override = [_shape("hitbox"), _shape("hurtbox")]
    assert_eq(ShapeStore.resolve_effective(defaults, override), override)

func test_empty_override_array_is_a_real_override():
    var defaults = [_shape("hurtbox")]
    assert_eq(ShapeStore.resolve_effective(defaults, []), [], "empty list means 'this frame has no shapes', not 'use defaults'")
