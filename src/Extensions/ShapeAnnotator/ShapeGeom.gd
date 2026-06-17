extends RefCounted
## Pure geometry helpers: build a shape's `type_data` from a click-drag.

static func from_drag(type: String, start: Vector2i, end: Vector2i, default_radius: int) -> Dictionary:
	match type:
		"rect":
			var x: int = min(start.x, end.x)
			var y: int = min(start.y, end.y)
			return {"x": x, "y": y, "w": abs(end.x - start.x), "h": abs(end.y - start.y), "angle": 0}
		"circle":
			var r: int = roundi(Vector2(start).distance_to(Vector2(end)))
			return {"x": start.x, "y": start.y, "r": r}
		"capsule":
			# Placed vertical; reorient afterward in Edit mode.
			return {"x1": start.x, "y1": start.y, "x2": start.x, "y2": end.y, "r": default_radius}
		_:
			push_error("ShapeGeom.from_drag: unknown type '%s'" % type)
			return {}
