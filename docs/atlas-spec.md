# .atlas.json specification

The contract between the exporter and downstream consumers (e.g. the TERL game).

## `.atlas.json` Schema

```json
{
  "meta": {
    "image": "sprite.png",
    "size": { "w": 64, "h": 32 },
    "schema_version": 1,
    "duration_ms": 100,
    "tags": [
      { "name": "idle", "from": 0, "to": 3 }
    ]
  },
  "shape_annotations": [
    {
      "type": "rect",
      "type_data": { "x": 4, "y": 6, "w": 24, "h": 20, "angle": 0 },
      "meta": { "tag": "hurtbox" }
    }
  ],
  "frames": [
    {
      "rect": { "x": 0, "y": 0, "w": 32, "h": 32 },
      "duration_ms": null,
      "shape_annotations": null
    },
    {
      "rect": { "x": 32, "y": 0, "w": 32, "h": 32 },
      "duration_ms": 200,
      "shape_annotations": [
        {
          "type": "circle",
          "type_data": { "x": 16, "y": 16, "r": 8 },
          "meta": { "tag": "hitbox" }
        }
      ]
    }
  ]
}
```

**Schema rules:**
- `meta.duration_ms` — the most frequent per-frame duration (ties → first seen). Frames matching this value have `duration_ms: null`; frames differing have their explicit value.
- `meta.tags` — animation tags converted to **0-based** indices.
- `shape_annotations` (top-level) — per-sprite default shapes.
- `frames[i].shape_annotations` — `null` means "use defaults"; an Array (even empty) is an explicit frame override that fully replaces the defaults.
- Tag indices in `meta.tags` are **0-based inclusive** (`from`/`to`).

## Coordinate Contract

All coordinates are **frame-local, origin top-left, Y-down** (image/pixel space):
- `rect`: `{ "x", "y", "w", "h", "angle" }` — `x,y,w,h` is the **unrotated**
  top-left + size box. `angle` is rotation in **degrees**, **clockwise-positive
  on screen** (Y-down image space), about the rect's center `(x+w/2, y+h/2)`.
  Always present (`0` = unrotated). Consumers convert to a Y-up world rotation as
  `world_rotation_radians = -angle * PI / 180`.
- `circle`: `{ "x", "y", "r" }` — center + radius.
- `capsule`: `{ "x1", "y1", "x2", "y2", "r" }` — spine endpoints + radius.
