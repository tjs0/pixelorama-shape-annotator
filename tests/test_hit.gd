# tests/test_hit.gd
extends GutTest

const ShapeHit = preload("res://src/Extensions/ShapeAnnotator/ShapeHit.gd")

func _rect(a := 0.0) -> Dictionary:
	return {"x": 10, "y": 20, "w": 40, "h": 20, "angle": a}

func test_point_in_unrotated_rect():
	assert_true(ShapeHit.point_in_shape("rect", _rect(), Vector2(30, 30)))
	assert_false(ShapeHit.point_in_shape("rect", _rect(), Vector2(0, 0)))

func test_point_in_rotated_rect():
	# 90° rotation about center (30,30): a point 9px above center stays inside
	# (half-width 20 along the now-vertical local X), 0px case trivially inside.
	var r := _rect(90.0)
	assert_true(ShapeHit.point_in_shape("rect", r, Vector2(30, 49)))   # 19px below center, within half-width 20
	assert_false(ShapeHit.point_in_shape("rect", r, Vector2(41, 30)))  # 11px sideways, beyond half-height 10

func test_point_in_circle():
	var c := {"x": 0, "y": 0, "r": 5}
	assert_true(ShapeHit.point_in_shape("circle", c, Vector2(3, 4)))
	assert_false(ShapeHit.point_in_shape("circle", c, Vector2(4, 4)))

func test_point_in_capsule():
	var cap := {"x1": 0, "y1": 0, "x2": 0, "y2": 10, "r": 3}
	assert_true(ShapeHit.point_in_shape("capsule", cap, Vector2(2, 5)))
	assert_false(ShapeHit.point_in_shape("capsule", cap, Vector2(4, 5)))

func test_shapes_at_point_returns_containing_indices():
	var shapes := [
		{"type": "rect", "type_data": _rect(), "meta": {}},
		{"type": "circle", "type_data": {"x": 30, "y": 30, "r": 4}, "meta": {}},
	]
	var hit := ShapeHit.shapes_at_point(shapes, Vector2(30, 30))
	assert_eq(hit, PackedInt32Array([0, 1]))
	assert_eq(ShapeHit.shapes_at_point(shapes, Vector2(200, 200)), PackedInt32Array())

func test_rect_handles_present():
	var h := ShapeHit.handles("rect", _rect())
	for id in ["nw", "ne", "se", "sw", "n", "e", "s", "w", "rotate"]:
		assert_true(h.has(id), "rect handle %s" % id)
	assert_eq(h["nw"], Vector2(10, 20))
	assert_eq(h["se"], Vector2(50, 40))

func test_hit_handle_picks_corner():
	assert_eq(ShapeHit.hit_handle("rect", _rect(), Vector2(11, 21), 3.0), "nw")
	assert_eq(ShapeHit.hit_handle("rect", _rect(), Vector2(30, 30), 3.0), "")

func test_apply_move_translates_all_coords():
	var out := ShapeHit.apply_move("capsule", {"x1": 0, "y1": 0, "x2": 0, "y2": 10, "r": 3}, Vector2(5, -2))
	assert_eq(out["x1"], 5); assert_eq(out["y1"], -2)
	assert_eq(out["x2"], 5); assert_eq(out["y2"], 8)

func test_resize_corner_keeps_opposite_corner():
	# drag the SE corner of an unrotated rect to (60,60); NW (10,20) must stay.
	var out := ShapeHit.apply_resize("rect", _rect(), "se", Vector2(60, 60))
	assert_eq(out["x"], 10); assert_eq(out["y"], 20)
	assert_eq(out["w"], 50); assert_eq(out["h"], 40)

func test_resize_edge_changes_only_one_extent():
	# drag the east edge to x=80; height and y unchanged.
	var out := ShapeHit.apply_resize("rect", _rect(), "e", Vector2(80, 30))
	assert_eq(out["h"], 20); assert_eq(out["y"], 20); assert_eq(out["x"], 10)
	assert_eq(out["w"], 70)

func test_resize_circle_sets_radius():
	var out := ShapeHit.apply_resize("circle", {"x": 0, "y": 0, "r": 5}, "radius", Vector2(8, 0))
	assert_eq(out["r"], 8)

func test_rotate_rect_sets_angle_pointer_up_is_zero():
	# pointer straight up from center → angle 0 (snap on).
	var out := ShapeHit.apply_rotate("rect", _rect(), Vector2(30, 0), true)
	assert_almost_eq(out["angle"], 0.0, 0.001)

func test_rotate_capsule_keeps_length_about_center():
	var cap := {"x1": 0, "y1": -5, "x2": 0, "y2": 5, "r": 2}  # vertical, len 10, center (0,0)
	var out := ShapeHit.apply_rotate("capsule", cap, Vector2(10, 0), false)  # point east
	# spine now horizontal, same half-length 5 about center
	assert_almost_eq(float(out["x2"]), 5.0, 0.001)
	assert_almost_eq(float(out["y2"]), 0.0, 0.001)
	assert_almost_eq(float(out["x1"]), -5.0, 0.001)

func test_snap_angle_within_threshold_and_beyond():
	assert_almost_eq(ShapeHit.snap_angle(3.0, true, 90.0), 0.0, 0.001)
	assert_almost_eq(ShapeHit.snap_angle(20.0, true, 90.0), 20.0, 0.001)
	assert_almost_eq(ShapeHit.snap_angle(3.0, false, 90.0), 3.0, 0.001)
