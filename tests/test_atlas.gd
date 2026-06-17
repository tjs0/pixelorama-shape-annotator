extends GutTest

const ShapeAtlas = preload("res://src/Extensions/ShapeAnnotator/ShapeAtlas.gd")

func _rect_shape(tag: String) -> Dictionary:
    return {"type": "rect", "type_data": {"x": 6, "y": 4, "w": 12, "h": 24}, "meta": {"tag": tag}}

func test_full_atlas_shape():
    var atlas = ShapeAtlas.build_atlas_dict({
        "image_name": "knight_attack.png",
        "frame_sizes": [Vector2i(32, 32), Vector2i(32, 32)],
        "frame_durations_ms": [100, 150],
        "frame_overrides": [null, [_rect_shape("hurtbox")]],
        "defaults": [_rect_shape("hurtbox")],
        "tags": [{"name": "idle", "from": 1, "to": 1}, {"name": "attack", "from": 2, "to": 2}],
        "columns": 0,
    })
    assert_eq(atlas["meta"]["image"], "knight_attack.png")
    assert_eq(atlas["meta"]["size"], {"w": 64, "h": 32})
    assert_eq(atlas["meta"]["schema_version"], 1)
    assert_eq(atlas["meta"]["duration_ms"], 100, "default = most frequent; tie→first, here 100 appears first")
    assert_eq(atlas["meta"]["tags"], [
        {"name": "idle", "from": 0, "to": 0},
        {"name": "attack", "from": 1, "to": 1},
    ], "tags converted to 0-based")
    assert_eq(atlas["shape_annotations"], [_rect_shape("hurtbox")])
    assert_eq(atlas["frames"][0], {
        "rect": {"x": 0, "y": 0, "w": 32, "h": 32},
        "duration_ms": null,
        "shape_annotations": null,
    })
    assert_eq(atlas["frames"][1], {
        "rect": {"x": 32, "y": 0, "w": 32, "h": 32},
        "duration_ms": 150,
        "shape_annotations": [_rect_shape("hurtbox")],
    })

func test_default_duration_picks_most_frequent():
    var atlas = ShapeAtlas.build_atlas_dict({
        "image_name": "x.png",
        "frame_sizes": [Vector2i(8, 8), Vector2i(8, 8), Vector2i(8, 8)],
        "frame_durations_ms": [100, 200, 200],
        "frame_overrides": [null, null, null],
        "defaults": [],
        "tags": [],
        "columns": 0,
    })
    assert_eq(atlas["meta"]["duration_ms"], 200)
    assert_eq(atlas["frames"][0]["duration_ms"], 100, "differs from default → explicit")
    assert_null(atlas["frames"][1]["duration_ms"], "equals default → null")
