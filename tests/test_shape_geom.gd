extends GutTest

const ShapeGeom = preload("res://src/Extensions/ShapeAnnotator/ShapeGeom.gd")

func test_rect_normalizes_corners():
	var td = ShapeGeom.from_drag("rect", Vector2i(10, 8), Vector2i(4, 20), 3)
	assert_eq(td, {"x": 4, "y": 8, "w": 6, "h": 12, "angle": 0}, "rect uses min corner + abs size")

func test_rect_zero_drag_has_zero_size():
	var td = ShapeGeom.from_drag("rect", Vector2i(5, 5), Vector2i(5, 5), 3)
	assert_eq(td, {"x": 5, "y": 5, "w": 0, "h": 0, "angle": 0})

func test_circle_center_and_rounded_radius():
	var td = ShapeGeom.from_drag("circle", Vector2i(10, 10), Vector2i(13, 14), 3)
	assert_eq(td, {"x": 10, "y": 10, "r": 5}, "radius = round(dist((3,4))) = 5")

func test_capsule_endpoints_and_default_radius():
	# Capsule is placed vertical: x1==x2==start.x; y1=start.y, y2=end.y.
	var td = ShapeGeom.from_drag("capsule", Vector2i(2, 3), Vector2i(8, 10), 4)
	assert_eq(td, {"x1": 2, "y1": 3, "x2": 2, "y2": 10, "r": 4})
