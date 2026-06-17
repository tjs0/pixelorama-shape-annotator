extends RefCounted
## Pure editing math for shape annotations: hit-testing, handle positions, and
## move/resize/rotate transforms with cardinal snap. Image space (Y-down).
## Angles in degrees, clockwise-positive on screen, about the rect center.

const HANDLE_PX := 4.0
const ROTATE_OFFSET_PX := 12.0
const SNAP_DEG := 5.0

static func _axes(deg: float) -> Array:
	var a := deg_to_rad(deg)
	var c := cos(a)
	var s := sin(a)
	return [Vector2(c, s), Vector2(-s, c)]  # [local-X unit, local-Y unit]

static func rect_center(td: Dictionary) -> Vector2:
	return Vector2(td["x"] + td["w"] / 2.0, td["y"] + td["h"] / 2.0)

static func rect_corners(td: Dictionary) -> PackedVector2Array:
	var c := rect_center(td)
	var ax := _axes(td.get("angle", 0.0))
	var u: Vector2 = ax[0]
	var v: Vector2 = ax[1]
	var hw: float = td["w"] / 2.0
	var hh: float = td["h"] / 2.0
	var pts := PackedVector2Array()
	pts.append(c - u * hw - v * hh)  # nw
	pts.append(c + u * hw - v * hh)  # ne
	pts.append(c + u * hw + v * hh)  # se
	pts.append(c - u * hw + v * hh)  # sw
	return pts

static func _dist_point_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	var t := 0.0
	if denom > 0.0:
		t = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func point_in_shape(type: String, td: Dictionary, p: Vector2) -> bool:
	match type:
		"rect":
			var c := rect_center(td)
			var ax := _axes(td.get("angle", 0.0))
			var d := p - c
			return absf(d.dot(ax[0])) <= td["w"] / 2.0 and absf(d.dot(ax[1])) <= td["h"] / 2.0
		"circle":
			return Vector2(td["x"], td["y"]).distance_to(p) <= td["r"]
		"capsule":
			return _dist_point_segment(p, Vector2(td["x1"], td["y1"]), Vector2(td["x2"], td["y2"])) <= td["r"]
	return false

static func shapes_at_point(shapes: Array, p: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in shapes.size():
		var s: Dictionary = shapes[i]
		if point_in_shape(s["type"], s["type_data"], p):
			out.append(i)
	return out

static func handles(type: String, td: Dictionary) -> Dictionary:
	var h := {}
	match type:
		"rect":
			var cor := rect_corners(td)
			h["nw"] = cor[0]; h["ne"] = cor[1]; h["se"] = cor[2]; h["sw"] = cor[3]
			h["n"] = (cor[0] + cor[1]) / 2.0
			h["e"] = (cor[1] + cor[2]) / 2.0
			h["s"] = (cor[2] + cor[3]) / 2.0
			h["w"] = (cor[3] + cor[0]) / 2.0
			var ax := _axes(td.get("angle", 0.0))
			h["rotate"] = h["n"] - ax[1] * ROTATE_OFFSET_PX
		"circle":
			h["radius"] = Vector2(td["x"] + td["r"], td["y"])
		"capsule":
			var a := Vector2(td["x1"], td["y1"])
			var b := Vector2(td["x2"], td["y2"])
			var dir := b - a
			var u := dir.normalized() if dir.length() > 0.0 else Vector2.DOWN
			var n := Vector2(-u.y, u.x)
			h["end1"] = a
			h["end2"] = b
			h["radius"] = (a + b) / 2.0 + n * td["r"]
			h["rotate"] = b + u * ROTATE_OFFSET_PX
	return h

static func hit_handle(type: String, td: Dictionary, p: Vector2, tol: float) -> String:
	var best := ""
	var best_d := tol
	var hs := handles(type, td)
	for id in hs:
		var d: float = (hs[id] as Vector2).distance_to(p)
		if d <= best_d:
			best_d = d
			best = id
	return best

## Transforms below round coordinate outputs to integer pixels.
static func apply_move(type: String, td: Dictionary, delta: Vector2) -> Dictionary:
	var out := td.duplicate(true)
	match type:
		"rect", "circle":
			out["x"] = roundi(td["x"] + delta.x)
			out["y"] = roundi(td["y"] + delta.y)
		"capsule":
			out["x1"] = roundi(td["x1"] + delta.x)
			out["y1"] = roundi(td["y1"] + delta.y)
			out["x2"] = roundi(td["x2"] + delta.x)
			out["y2"] = roundi(td["y2"] + delta.y)
	return out

static func apply_resize(type: String, td: Dictionary, handle_id: String, p: Vector2) -> Dictionary:
	var out := td.duplicate(true)
	match type:
		"circle":
			out["r"] = maxi(1, roundi(Vector2(td["x"], td["y"]).distance_to(p)))
		"capsule":
			match handle_id:
				"end1":
					out["x1"] = roundi(p.x); out["y1"] = roundi(p.y)
				"end2":
					out["x2"] = roundi(p.x); out["y2"] = roundi(p.y)
				"radius":
					var d := _dist_point_segment(p, Vector2(td["x1"], td["y1"]), Vector2(td["x2"], td["y2"]))
					out["r"] = maxi(1, roundi(d))
		"rect":
			return _resize_rect(td, handle_id, p)
	return out

static func _resize_rect(td: Dictionary, handle_id: String, p: Vector2) -> Dictionary:
	var ax := _axes(td.get("angle", 0.0))
	var u: Vector2 = ax[0]
	var v: Vector2 = ax[1]
	var cor := rect_corners(td)  # nw0 ne1 se2 sw3
	var anchor: Vector2
	var free_u := true
	var free_v := true
	match handle_id:
		"se": anchor = cor[0]
		"sw": anchor = cor[1]
		"ne": anchor = cor[3]
		"nw": anchor = cor[2]
		"e": anchor = (cor[0] + cor[3]) / 2.0; free_v = false  # west edge midpoint
		"w": anchor = (cor[1] + cor[2]) / 2.0; free_v = false  # east edge midpoint
		"s": anchor = (cor[0] + cor[1]) / 2.0; free_u = false  # north edge midpoint
		"n": anchor = (cor[2] + cor[3]) / 2.0; free_u = false  # south edge midpoint
	var d := p - anchor
	var du := d.dot(u)
	var dv := d.dot(v)
	var new_w: float = maxf(1.0, absf(du)) if free_u else float(td["w"])
	var new_h: float = maxf(1.0, absf(dv)) if free_v else float(td["h"])
	var cw: float = signf(du) * new_w / 2.0 if free_u else 0.0
	var ch: float = signf(dv) * new_h / 2.0 if free_v else 0.0
	var center := anchor + u * cw + v * ch
	var out := td.duplicate(true)
	out["w"] = roundi(new_w)
	out["h"] = roundi(new_h)
	out["x"] = roundi(center.x - new_w / 2.0)
	out["y"] = roundi(center.y - new_h / 2.0)
	return out

static func apply_rotate(type: String, td: Dictionary, p: Vector2, snap_enabled: bool) -> Dictionary:
	var out := td.duplicate(true)
	match type:
		"rect":
			var c := rect_center(td)
			# Rotate handle sits "up" (-Y) at angle 0; pointer angle + 90 maps up→0.
			var deg := rad_to_deg((p - c).angle()) + 90.0
			out["angle"] = snap_angle(deg, snap_enabled, 90.0)
		"capsule":
			var a := Vector2(td["x1"], td["y1"])
			var b := Vector2(td["x2"], td["y2"])
			var ctr := (a + b) / 2.0
			var halflen := a.distance_to(b) / 2.0
			var deg := snap_angle(rad_to_deg((p - ctr).angle()), snap_enabled, 90.0)
			var dir := Vector2.from_angle(deg_to_rad(deg))
			out["x2"] = roundi(ctr.x + dir.x * halflen)
			out["y2"] = roundi(ctr.y + dir.y * halflen)
			out["x1"] = roundi(ctr.x - dir.x * halflen)
			out["y1"] = roundi(ctr.y - dir.y * halflen)
	return out

static func _norm180(d: float) -> float:
	while d > 180.0:
		d -= 360.0
	while d < -180.0:
		d += 360.0
	return d

static func snap_angle(deg: float, enabled: bool, step: float) -> float:
	if not enabled:
		return deg
	var nearest: float = round(deg / step) * step
	if absf(_norm180(deg - nearest)) <= SNAP_DEG:
		return nearest
	return deg
