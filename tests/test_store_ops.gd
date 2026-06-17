extends GutTest

const ShapeStore = preload("res://src/Extensions/ShapeAnnotator/ShapeStore.gd")

func _shape(tag: String) -> Dictionary:
    return {"type": "rect", "type_data": {"x": 0, "y": 0, "w": 1, "h": 1}, "meta": {"tag": tag}}

func test_array_with_added_is_copy():
    var orig := [_shape("a")]
    var out := ShapeStore.array_with_added(orig, _shape("b"))
    assert_eq(out.size(), 2)
    assert_eq(orig.size(), 1, "input not mutated")

func test_array_without_index_is_copy():
    var orig := [_shape("a"), _shape("b")]
    var out := ShapeStore.array_without_index(orig, 0)
    assert_eq(out, [_shape("b")])
    assert_eq(orig.size(), 2, "input not mutated")

func test_array_with_added_deep_copies_existing():
    var orig := [_shape("a")]
    var out := ShapeStore.array_with_added(orig, _shape("b"))
    out[0]["meta"]["tag"] = "mutated"
    assert_eq(orig[0]["meta"]["tag"], "a", "nested dict of input not mutated")

func test_array_without_index_deep_copies_remaining():
    var orig := [_shape("a"), _shape("b")]
    var out := ShapeStore.array_without_index(orig, 1)
    out[0]["meta"]["tag"] = "mutated"
    assert_eq(orig[0]["meta"]["tag"], "a", "nested dict of input not mutated")

func test_target_for_mode():
    var f := Object.new()
    assert_null(ShapeStore.target_for_mode(ShapeStore.MODE_SPRITE, f))
    assert_eq(ShapeStore.target_for_mode(ShapeStore.MODE_FRAME, f), f)
    f.free()

func test_array_with_replaced_swaps_index_and_copies():
    var orig := [_shape("a"), _shape("b")]
    var out := ShapeStore.array_with_replaced(orig, 1, _shape("c"))
    assert_eq(out[1]["meta"]["tag"], "c")
    assert_eq(orig[1]["meta"]["tag"], "b", "input not mutated")

func test_array_with_replaced_out_of_range_is_noop_copy():
    var orig := [_shape("a")]
    var out := ShapeStore.array_with_replaced(orig, 5, _shape("z"))
    assert_eq(out, [_shape("a")])
