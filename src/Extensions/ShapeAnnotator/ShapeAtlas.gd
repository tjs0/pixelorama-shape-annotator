extends RefCounted
## Pure spritesheet packing + atlas-dict assembly. No Pixelorama dependency.

const ShapeStore = preload("ShapeStore.gd")

static func pack_rects(frame_sizes: Array, columns: int) -> Dictionary:
    var rects: Array = []
    if frame_sizes.is_empty():
        return {"rects": rects, "size": {"w": 0, "h": 0}}
    var per_row: int = frame_sizes.size() if columns <= 0 else columns
    var cursor_x := 0
    var cursor_y := 0
    var row_h := 0
    var sheet_w := 0
    var col := 0
    for size in frame_sizes:
        var s: Vector2i = size
        if col == per_row:
            cursor_x = 0
            cursor_y += row_h
            row_h = 0
            col = 0
        rects.append({"x": cursor_x, "y": cursor_y, "w": s.x, "h": s.y})
        cursor_x += s.x
        row_h = max(row_h, s.y)
        sheet_w = max(sheet_w, cursor_x)
        col += 1
    var sheet_h := cursor_y + row_h
    return {"rects": rects, "size": {"w": sheet_w, "h": sheet_h}}

static func _most_frequent(values: Array) -> int:
    if values.is_empty():
        return 0
    var counts := {}
    var best_val: int = values[0]
    var best_count := 0
    for v in values:
        counts[v] = counts.get(v, 0) + 1
        if counts[v] > best_count:
            best_count = counts[v]
            best_val = v
    return best_val

static func build_atlas_dict(p: Dictionary) -> Dictionary:
    var packed := pack_rects(p["frame_sizes"], p["columns"])
    var rects: Array = packed["rects"]
    var durations: Array = p["frame_durations_ms"]
    var overrides: Array = p["frame_overrides"]
    var default_ms := _most_frequent(durations)

    var frames: Array = []
    for i in rects.size():
        var ov: Variant = overrides[i]
        frames.append({
            "rect": rects[i],
            "duration_ms": null if durations[i] == default_ms else durations[i],
            "shape_annotations": ov if ov is Array else null,
        })

    var tags_0: Array = []
    for t in p["tags"]:
        tags_0.append({"name": t["name"], "from": int(t["from"]) - 1, "to": int(t["to"]) - 1})

    return {
        "meta": {
            "image": p["image_name"],
            "size": packed["size"],
            "schema_version": ShapeStore.SCHEMA_VERSION,
            "duration_ms": default_ms,
            "tags": tags_0,
        },
        "shape_annotations": p["defaults"],
        "frames": frames,
    }
