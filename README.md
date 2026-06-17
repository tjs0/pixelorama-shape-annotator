# Pixelorama Shape Annotator

A Pixelorama extension that lets users draw rect/circle/capsule shape annotations on a sprite, stores them as `.pxo` metadata (per-sprite defaults + per-frame overrides), and exports a PNG spritesheet plus a self-contained `.atlas.json` sidecar.

One use case for this is to annotate sprites with hitbox metadata, so that authoring both the sprite and hitboxes can be managed together within Pixelorama.

Only convex primitives are supported (rect / circle / capsule); there are no freeform or concave shapes.

## Compatibility

| pixelorama-shape-annotator | Pixelorama | Godot          |
| -------------------------- | ---------- | -------------- |
| 0.1.0                      | 1.1.10     | 4.6.2, 4.6.3   |

## Documentation

- **[Installation](docs/installation.md)** — build or download the `.pck` and enable it in Pixelorama.
- **[Usage](docs/usage.md)** — drawing, editing, managing, and exporting shape annotations.
- **[`.atlas.json` specification](docs/atlas-spec.md)** — the export schema, override semantics, and coordinate contract.
- **[Architecture & design](docs/design.md)** — how the extension is structured internally and why.
- **[Development](docs/development.md)** — building the `.pck`, running the tests, and the manual smoke-test checklist.

## Quick start

1. Install the extension (see [Installation](docs/installation.md)).
2. Select the **Shape Annotator** tool, choose a shape type and tag, and click-drag on the canvas to draw an annotation. No image pixels are changed — only metadata is written.
3. Save the `.pxo` to persist annotations, or export via **Atlas + Spritesheet (ShapeAnnotator)** to write `<name>.png` + `<name>.atlas.json`.

See [Usage](docs/usage.md) for the full workflow.
