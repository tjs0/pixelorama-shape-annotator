extends GutTest

const ShapeExporter = preload("res://src/Extensions/ShapeAnnotator/ShapeExporter.gd")
const ShapeStore = preload("res://src/Extensions/ShapeAnnotator/ShapeStore.gd")

class FakeProject:
    extends Object
    var frames: Array = []

class FakeFrame:
    extends Object

class FakeProcessed:
    extends RefCounted
    var image: Image
    var frame_index: int
    var duration: float
    func _init(img: Image, idx: int, dur: float):
        image = img
        frame_index = idx
        duration = dur

func _img(w: int, h: int) -> Image:
    return Image.create(w, h, false, Image.FORMAT_RGBA8)

func test_collect_inputs_maps_durations_and_overrides():
    var proj = FakeProject.new()
    var f0 = FakeFrame.new()
    var f1 = FakeFrame.new()
    proj.frames = [f0, f1]
    proj.set_meta(ShapeStore.META_KEY, [{"type": "rect", "type_data": {}, "meta": {"tag": "hurtbox"}}])
    f1.set_meta(ShapeStore.META_KEY, [])  # real empty override

    var processed = [
        FakeProcessed.new(_img(32, 32), 0, 0.1),
        FakeProcessed.new(_img(32, 32), 1, 0.15),
    ]
    var p = ShapeExporter.collect_export_inputs(proj, processed)
    assert_eq(p["frame_sizes"], [Vector2i(32, 32), Vector2i(32, 32)])
    assert_eq(p["frame_durations_ms"], [100, 150])
    assert_eq(p["frame_overrides"], [null, []])
    assert_eq(p["defaults"], [{"type": "rect", "type_data": {}, "meta": {"tag": "hurtbox"}}])
    assert_eq(p["images"].size(), 2)
    proj.free(); f0.free(); f1.free()

class FakeProjectBlend:
    extends Object
    var frames: Array = []
    var size := Vector2i(16, 16)
    var fps := 10.0

class FakeFrameBlend:
    extends Object
    func get_duration_in_seconds(_fps: float) -> float:
        return 0.1

func test_export_project_to_writes_files_without_drawing_algos():
    # The standalone menu export blends frames itself; with drawing_algos = null
    # it yields blank frames but must still write both files end to end.
    var proj = FakeProjectBlend.new()
    var f0 = FakeFrameBlend.new()
    proj.frames = [f0]
    var exporter = ShapeExporter.new()
    var base := "user://_test_export_blend"
    assert_true(exporter.export_project_to(proj, null, base + ".atlas.json"), "export returns true")
    assert_true(FileAccess.file_exists(base + ".png"), "png written")
    assert_true(FileAccess.file_exists(base + ".atlas.json"), "atlas json written")
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(base + ".atlas.json"))
    assert_eq(parsed["meta"]["image"], "_test_export_blend.png")
    assert_eq(parsed["frames"].size(), 1)
    # 0.1s * 1000 -> 100ms, carried as the sheet default (per-frame is null when equal).
    assert_eq(parsed["meta"]["duration_ms"], 100)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(base + ".png"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(base + ".atlas.json"))
    proj.free(); f0.free(); exporter.free()

func test_override_export_writes_png_and_json():
    var proj = FakeProject.new()
    var f0 = FakeFrame.new()
    proj.frames = [f0]
    var processed = [FakeProcessed.new(_img(32, 32), 0, 0.1)]
    var exporter = ShapeExporter.new()
    var base := "user://_test_export"
    var details := {
        "processed_images": processed,
        "export_paths": [base + ".atlas.json"],
        "project": proj,
    }
    assert_true(exporter.override_export(details), "override_export returns true")
    assert_true(FileAccess.file_exists(base + ".png"), "png written")
    assert_true(FileAccess.file_exists(base + ".atlas.json"), "atlas json written")
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(base + ".atlas.json"))
    assert_eq(parsed["meta"]["image"], "_test_export.png")
    assert_eq(parsed["frames"].size(), 1)
    # cleanup
    DirAccess.remove_absolute(ProjectSettings.globalize_path(base + ".png"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(base + ".atlas.json"))
    proj.free(); f0.free()
    exporter.free()
