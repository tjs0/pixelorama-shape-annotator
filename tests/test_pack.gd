extends GutTest

const ShapeAtlas = preload("res://src/Extensions/ShapeAnnotator/ShapeAtlas.gd")

func test_single_row_uniform():
    var out = ShapeAtlas.pack_rects([Vector2i(32, 32), Vector2i(32, 32)], 0)
    assert_eq(out["rects"], [
        {"x": 0, "y": 0, "w": 32, "h": 32},
        {"x": 32, "y": 0, "w": 32, "h": 32},
    ])
    assert_eq(out["size"], {"w": 64, "h": 32})

func test_two_columns_wraps_to_second_row():
    var out = ShapeAtlas.pack_rects(
        [Vector2i(32, 32), Vector2i(32, 32), Vector2i(32, 32)], 2)
    assert_eq(out["rects"], [
        {"x": 0, "y": 0, "w": 32, "h": 32},
        {"x": 32, "y": 0, "w": 32, "h": 32},
        {"x": 0, "y": 32, "w": 32, "h": 32},
    ])
    assert_eq(out["size"], {"w": 64, "h": 64})

func test_empty_is_zero_sized():
    var out = ShapeAtlas.pack_rects([], 0)
    assert_eq(out["rects"], [])
    assert_eq(out["size"], {"w": 0, "h": 0})
