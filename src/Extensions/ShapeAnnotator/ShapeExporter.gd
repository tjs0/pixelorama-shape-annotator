extends Node
## Custom export format: packs a spritesheet and writes <base>.png + <base>.atlas.json.

const ShapeStore = preload("ShapeStore.gd")
const ShapeAtlas = preload("ShapeAtlas.gd")

var columns := 0  ## 0 = single row.

## Tested seam: pure dict assembly from project + processed images (no file I/O).
static func collect_export_inputs(project: Object, processed_images: Array) -> Dictionary:
    var frame_sizes: Array = []
    var frame_durations_ms: Array = []
    var frame_overrides: Array = []
    var images: Array = []
    for pi in processed_images:
        var img: Image = pi.image
        images.append(img)
        frame_sizes.append(Vector2i(img.get_width(), img.get_height()))
        frame_durations_ms.append(roundi(pi.duration * 1000.0))
        var frame: Object = project.frames[pi.frame_index]
        frame_overrides.append(frame.get_meta(ShapeStore.META_KEY) if frame.has_meta(ShapeStore.META_KEY) else null)
    var defaults: Variant = project.get_meta(ShapeStore.META_KEY) if project.has_meta(ShapeStore.META_KEY) else []
    return {
        "frame_sizes": frame_sizes,
        "frame_durations_ms": frame_durations_ms,
        "frame_overrides": frame_overrides,
        "defaults": defaults,
        "images": images,
    }

## Pixelorama's custom-export hook (used on the Web build, where the format is
## selectable). Builds inputs from the export pipeline's processed images.
func override_export(details: Dictionary) -> bool:
    var project: Object = details["project"]
    var inputs := collect_export_inputs(project, details["processed_images"])
    return write_atlas(project, inputs, details["export_paths"][0])

## Standalone export driven by the extension's own "Export Shape Atlas…" menu item.
## Blends every frame itself via DrawingAlgos so it does not depend on Pixelorama's
## export dialog — which on desktop (1.1.10) cannot select custom export formats.
## `drawing_algos` is ExtensionsApi.general.get_drawing_algos() (may be null in tests,
## which just yields blank frames).
func export_project_to(project: Object, drawing_algos: Object, out_path: String) -> bool:
    return write_atlas(project, _collect_blended_inputs(project, drawing_algos), out_path)

func _collect_blended_inputs(project: Object, drawing_algos: Object) -> Dictionary:
    var frame_sizes: Array = []
    var frame_durations_ms: Array = []
    var frame_overrides: Array = []
    var images: Array = []
    for frame in project.frames:
        var img := Image.create(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
        if drawing_algos != null:
            drawing_algos.blend_layers(img, frame, Vector2i.ZERO, project)
        images.append(img)
        frame_sizes.append(Vector2i(img.get_width(), img.get_height()))
        frame_durations_ms.append(roundi(frame.get_duration_in_seconds(project.fps) * 1000.0))
        frame_overrides.append(frame.get_meta(ShapeStore.META_KEY) if frame.has_meta(ShapeStore.META_KEY) else null)
    var defaults: Variant = project.get_meta(ShapeStore.META_KEY) if project.has_meta(ShapeStore.META_KEY) else []
    return {
        "frame_sizes": frame_sizes,
        "frame_durations_ms": frame_durations_ms,
        "frame_overrides": frame_overrides,
        "defaults": defaults,
        "images": images,
    }

## Shared core: assemble the atlas from `inputs` (the shape returned by
## collect_export_inputs / _collect_blended_inputs) and write <base>.png + <base>.atlas.json.
func write_atlas(project: Object, inputs: Dictionary, out_path: String) -> bool:
    var base := out_path.get_basename()  # get_basename strips only the last ext (".json").
    # out_path ends in ".atlas.json" -> base is "<name>.atlas"; drop the trailing ".atlas".
    if base.get_extension() == "atlas":
        base = base.get_basename()
    var png_path := base + ".png"
    var json_path := base + ".atlas.json"
    var image_name := png_path.get_file()

    var atlas := ShapeAtlas.build_atlas_dict({
        "image_name": image_name,
        "frame_sizes": inputs["frame_sizes"],
        "frame_durations_ms": inputs["frame_durations_ms"],
        "frame_overrides": inputs["frame_overrides"],
        "defaults": inputs["defaults"],
        "tags": _collect_tags(project),
        "columns": columns,
    })

    var sheet := _compose_sheet(inputs["images"], atlas["frames"], atlas["meta"]["size"])
    if sheet.save_png(png_path) != OK:
        return false
    var jf := FileAccess.open(json_path, FileAccess.WRITE)
    if jf == null:
        return false
    jf.store_string(JSON.stringify(atlas, "  "))
    jf.close()
    return true

func _compose_sheet(images: Array, frames: Array, size: Dictionary) -> Image:
    var sheet := Image.create(max(1, size["w"]), max(1, size["h"]), false, Image.FORMAT_RGBA8)
    for i in images.size():
        var r: Dictionary = frames[i]["rect"]
        var img: Image = images[i]
        sheet.blit_rect(img, Rect2i(0, 0, r["w"], r["h"]), Vector2i(r["x"], r["y"]))
    return sheet

func _collect_tags(project: Object) -> Array:
    # Pixelorama Projects expose `animation_tags: Array[AnimationTag]` with
    # name/from/to (1-based). Guard for the fake project in tests (no field).
    var tags: Array = []
    if "animation_tags" in project:
        for t in project.animation_tags:
            tags.append({"name": t.name, "from": t.from, "to": t.to})
    return tags
