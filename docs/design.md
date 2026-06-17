# Shape Annotator — Architecture & Design

This document describes how the Shape Annotator extension is structured and why.
It reflects the code as it exists under `src/Extensions/ShapeAnnotator/`. For
install and usage see [installation.md](installation.md) and [usage.md](usage.md);
for the `.atlas.json` schema see [atlas-spec.md](atlas-spec.md).

## Overview

Shape Annotator is a Pixelorama extension that lets users draw
rect/circle/capsule **shape annotations** onto a sprite without touching any
image pixels. Annotations are persisted as Godot **metadata** on the Pixelorama
`Project`/`Frame` objects (so they ride along inside the `.pxo` file) and can be
exported as a packed PNG spritesheet plus a self-contained `.atlas.json` sidecar.

The design has two guiding principles:

1. **Pixels are never modified.** The tool only reads/writes metadata.
2. **Logic lives in pure, testable functions.** Anything that can be expressed
   without a live Pixelorama instance (geometry, the defaults/override resolver,
   spritesheet packing, atlas-dict assembly) is a `static` function with no
   engine dependency, so it can be unit-tested under headless GUT.

## Module map

| File | Type | Responsibility |
|------|------|----------------|
| `Main.gd` | `Node` (extension entry) | Wires everything into Pixelorama via `ExtensionsApi`; owns lifecycle and signal subscriptions. |
| `ShapeGeom.gd` | `RefCounted`, pure | Builds a shape's `type_data` dict from a click-drag (start/end + default radius). |
| `ShapeStore.gd` | `RefCounted` | Single source of truth for annotations. Reads/writes metadata; resolves defaults vs. per-frame overrides; emits `changed`. |
| `ShapeTool.gd` | `BaseTool` | The toolbar tool. Translates drags into shapes and hands them to the store. |
| `ShapeOverlay.gd` | `Node2D` | Draws annotation outlines for the current frame in canvas/pixel space. |
| `ShapePanel.gd` | `Control` | The "Shapes" dock: lists defaults + current-frame override, supports select/delete. |
| `ShapeExporter.gd` | `Node` | Custom export option: packs the sheet and writes `<name>.png` + `<name>.atlas.json`. |
| `ShapeAtlas.gd` | `RefCounted`, pure | Spritesheet rect packing + `.atlas.json` dict assembly. No Pixelorama dependency. |

```
                         ExtensionsApi (Pixelorama host)
                                   │
                                Main.gd
          ┌───────────┬───────────┼───────────┬───────────────┐
          │           │           │           │               │
      ShapeTool   ShapeOverlay  ShapePanel  ShapeExporter   signals
          │           │           │           │            (project/cel
          └───────────┴────┬──────┴───────────┘             switched)
                           ▼
                       ShapeStore  ──(changed)──► overlay.refresh / panel.rebuild
                           │
              metadata on Project / Frame
                           │
        ShapeGeom (drag→type_data)   ShapeAtlas (pack + atlas dict)
```

## Data model

### Storage

Annotations are stored as Godot object metadata under stable keys defined in
`ShapeStore.gd`:

- `shape_annotator_shape_annotations` — the array of shape dicts.
- `shape_annotator_schema_version` — integer schema version (currently `1`).

Keys are underscore-namespaced because Godot meta names must be valid ASCII
identifiers (no `/`). Because they are object metadata, they serialize into the
`.pxo` automatically — there is no separate save/load code path.

A single shape dict looks like:

```gdscript
{ "type": "rect", "type_data": { "x":4, "y":6, "w":24, "h":20 }, "meta": { "tag": "hurtbox" } }
```

### Defaults vs. per-frame overrides

There are two storage scopes:

- **Sprite defaults** — stored on the `Project`. Apply to every frame.
- **Per-frame override** — stored on a `Frame`. A non-null `Array` **fully
  replaces** the defaults for that frame (it does not merge). An empty `Array`
  is a real override meaning "this frame intentionally has no shapes." Absence of
  the meta key means "use the defaults."

The resolution rule is one pure function, `ShapeStore.resolve_effective`:

```gdscript
static func resolve_effective(defaults, frame_override):
    return frame_override if frame_override is Array else defaults
```

`ShapeStore.effective_for(frame)` composes `get_defaults()` +
`get_frame_shapes(frame)` through this resolver, and is what the overlay draws.

### Change propagation

`ShapeStore` emits a `changed` signal on every mutation. `ShapePanel` connects
to it to rebuild its list; `Main` additionally refreshes the overlay and panel
on Pixelorama's `project_switched` / `cel_switched` signals so the view always
matches the active project/frame.

## Lifecycle (`Main.gd`)

On `_enter_tree()`, `Main`:

1. Looks up `/root/ExtensionsApi` (bails with an error if absent).
2. Creates a `ShapeStore` and binds it to the current project.
3. Injects the store and a target callable into `ShapeTool` via **static vars**
   (the Tools API instantiates the tool node itself, so dependencies must be set
   before instantiation). The default target callable returns `null` =
   "write to sprite defaults."
4. Adds the overlay to the canvas, the panel as a dock tab, the tool to the
   toolbar, and registers the exporter as an image export option.
5. Subscribes to `project_switched` / `cel_switched`.

`_exit_tree()` is the mirror image: it unsubscribes signals, removes the export
option, removes/free the panel, tool, overlay, and exporter. (Note:
`remove_node_from_tab()` already frees the panel, so it is not double-freed.)

## Authoring flow

`ShapeTool` extends Pixelorama's `BaseTool`:

- `draw_start` records the drag origin and disables undo during the drag
  (via `super`).
- `draw_move` requests a preview redraw.
- `draw_end` converts the drag to `type_data` with `ShapeGeom.from_drag`, wraps
  it in a shape dict (with the current `type`/`tag`), resolves the target from
  the injected `shared_target` callable, and calls `store.add_shape(target, …)`.

`ShapeStore.add_shape` routes by target: `null` appends to the defaults;
otherwise it appends to that frame's override, seeding the override from a deep
copy of the defaults if the frame did not already have one.

The tool's own UI (`ShapeTool.tscn`) provides the type picker, tag field, and
radius spinner.

## Rendering (`ShapeOverlay.gd`)

The overlay is a `Node2D` child of the canvas, so it draws in pixel space. In
`_draw` it asks the store for the effective shapes of the current frame and
strokes each one: `draw_rect` for rects, `draw_arc` for circles, and a computed
polyline for capsules (`capsule_outline_points` builds the two semicircular caps
plus connecting sides). Outlines are color-coded by tag (`hitbox`=red,
`hurtbox`=blue, else yellow); the selected index is lightened. Line width is
divided by camera zoom so strokes stay 1px on screen at any zoom.

## Export pipeline (`ShapeExporter.gd` + `ShapeAtlas.gd`)

The exporter is registered as a custom image export format ending in
`.atlas.json`. Pixelorama calls `override_export(details)`, which:

1. Normalizes the output path to `<name>.png` / `<name>.atlas.json`
   (Pixelorama hands over a path ending in `.atlas.json`; `get_basename`
   strips only the last extension, so a trailing `.atlas` is dropped).
2. Calls `collect_export_inputs` to gather per-frame sizes, durations (ms),
   overrides, and the sprite defaults from project/frame metadata. This is a
   deliberate **pure seam** — it takes the project + processed images and
   returns a plain dict, so it can be tested with a fake project.
3. Passes that plus animation tags into `ShapeAtlas.build_atlas_dict`.
4. Composes the spritesheet by blitting each frame image into its packed rect
   (`_compose_sheet`), saves the PNG, and writes the JSON via `JSON.stringify`.

`ShapeAtlas` is fully pure:

- `pack_rects` lays frames out left-to-right, wrapping after `columns`
  (`0` = single row), and returns each frame's rect plus the overall sheet size.
- `build_atlas_dict` assembles the final document: it picks the **most frequent**
  per-frame duration as `meta.duration_ms` (frames matching it emit
  `duration_ms: null`, others their explicit value), converts 1-based Pixelorama
  tag ranges to **0-based** `from`/`to`, carries the sprite defaults to
  top-level `shape_annotations`, and emits per-frame `shape_annotations` as the
  override `Array` or `null`.

See [atlas-spec.md](atlas-spec.md) for the full `.atlas.json` schema and worked example.

## Coordinate contract

All coordinates are **frame-local, origin top-left, Y-down** (image/pixel
space):

- `rect`: `{ x, y, w, h }` — top-left corner + size.
- `circle`: `{ x, y, r }` — center + radius.
- `capsule`: `{ x1, y1, x2, y2, r }` — spine endpoints + radius.

## Testing strategy

The pure-function seams are what the GUT suite under `tests/` exercises without
a running Pixelorama:

- `test_shape_geom` — drag → `type_data` for each shape type.
- `test_resolve` / `test_store_meta` — the defaults/override resolver and store
  metadata CRUD.
- `test_pack` / `test_atlas` — rect packing and atlas-dict assembly
  (duration mode, 0-based tags, override passthrough).
- `test_exporter_io` — `collect_export_inputs` against a fake project.
- `test_overlay_helpers` — color-for-tag and capsule outline math.
- `test_smoke` — sanity.

Run them with:

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## Known limitations & extension points (v0.1)

- **No tool-level target toggle.** `Main` injects a `shared_target` that always
  returns `null`, so the tool always writes to sprite defaults. The data model,
  store, panel, and exporter already support per-frame overrides — exposing a
  "draw into this frame" toggle (and override authoring/inspection from the
  panel) is the natural next step and requires no schema change.
- **Single-row default packing.** `columns` defaults to `0` (one row); a UI to
  set it is not yet wired.
- The GUT tests and `.pck` build require Godot 4.x and have not been run in the
  authoring environment.
