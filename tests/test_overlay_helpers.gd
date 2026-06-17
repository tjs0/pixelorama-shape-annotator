extends GutTest

const ShapeOverlay = preload("res://src/Extensions/ShapeAnnotator/ShapeOverlay.gd")

func test_color_for_known_and_unknown_tags():
    var ov := ShapeOverlay.new()
    ov.tag_colors = {"hitbox": Color.RED, "hurtbox": Color.BLUE}
    assert_eq(ov.color_for_tag("hitbox"), Color.RED)
    assert_eq(ov.color_for_tag("hurtbox"), Color.BLUE)
    assert_eq(ov.color_for_tag("mystery"), Color.YELLOW)
    ov.free()

func test_capsule_outline_spans_endpoints():
    var pts = ShapeOverlay.capsule_outline_points({"x1": 0, "y1": 0, "x2": 10, "y2": 0, "r": 2}, 8)
    assert_gt(pts.size(), 4, "should produce a closed-ish polyline")
    var min_x := INF
    var max_x := -INF
    for pt in pts:
        min_x = min(min_x, pt.x)
        max_x = max(max_x, pt.x)
    assert_almost_eq(min_x, -2.0, 0.001, "left cap reaches x1 - r")
    assert_almost_eq(max_x, 12.0, 0.001, "right cap reaches x2 + r")
