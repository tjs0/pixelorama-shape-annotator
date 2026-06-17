# Development

## Build

Requires Godot 4.x on PATH. Just run:

```bash
chmod +x build.sh
./build.sh
# Produces dist/ShapeAnnotator.pck
```

### Why the pack ships raw source (not `--export-pack`)

`build.sh` does **not** use Godot's `--export-pack`. That command always injects
project-level metadata into the pack — `project.binary`,
`.godot/global_script_class_cache.cfg`, and `.godot/uid_cache.bin`. For a standalone
game those are required, but for a Pixelorama **extension** they are toxic: Pixelorama
mounts extensions with `ProjectSettings.load_resource_pack(path)` (i.e.
`replace_files = true`), so those files **overwrite the host's own project settings,
global class registry and UID cache**. The result is exactly the breakage you see if you
ship an `--export-pack` pack: the host's `Global` autoload and `BaseTool` base class stop
resolving, and dozens of core Pixelorama scripts fail to compile
(`Cannot find member "config_cache" in base ".../Global.gd"`, `Could not resolve class
"BaseTool"`, …).

Instead, `tools/pack_source.gd` packs the extension's **raw source** (`*.gd`, text
`*.tscn`, `extension.json`) plus the pre-imported tool icon/cursor textures (`.ctex` —
an exported Pixelorama build cannot import a raw `.png` at runtime). Pixelorama then
compiles each script against its **own** `Global` / `BaseTool`, which is both correct and
self-contained. `export_presets.cfg` is no longer used by the build.

### Host stubs (dev/test only)

The extension's scripts reference Pixelorama host symbols that only exist when the
extension is loaded inside Pixelorama: `BaseTool` (base class of `ShapeTool`, also
instanced by `ShapeTool.tscn` as `res://src/Tools/BaseTool.tscn`) and the `Global`
singleton. So that this repo parses in the Godot editor and under GUT *outside* the
Pixelorama source tree, it ships minimal compile-time **stubs**:

- `src/Tools/BaseTool.gd` + `src/Tools/BaseTool.tscn`
- `src/Autoload/Global.gd` + `src/Autoload/GlobalProjectStub.gd`

These are **never shipped** — `pack_source.gd` only packs `src/Extensions/ShapeAnnotator/`
and the tool assets, so the stubs cannot shadow the real Pixelorama symbols. Keep the stub
signatures roughly in sync with any host members the extension starts using. Note the
`Global` stub uses `static` members purely so `Global.<member>` parses without an autoload;
because the shipped pack is **source**, the real (instance) `Global` autoload is what the
runtime actually compiles against, so the static/instance difference never reaches users.

### Gotcha: no self-capturing lambdas in `static` vars

`ShapeTool` receives its dependencies from `Main` through `static var`s (Pixelorama
instantiates the tool scene itself, so there is no instance handle to pass them to).
Store only plain object/Node references there (`shared_store`, `shared_overlay`,
`shared_host`). Do **not** assign a `self`-capturing lambda to a `static` var: the static
slot outlives the capturing instance and the lambda double-frees at engine teardown
(heap corruption / hard crash). `Main` therefore passes `self` as `shared_host` and
exposes `open_settings()` / `tag_names()` for the tool to call.

## Run tests (GUT)

Tests use [GUT](https://github.com/bitwes/Gut) (Godot Unit Test), v9.6.0, which lives
under `addons/gut/`.

> **Note:** `addons/gut/` is intentionally committed to the repo (vendored), not
> gitignored. Godot has no package manager, so vendoring the addon is the standard
> approach: it lets you `git clone` and immediately run the tests against the exact
> pinned GUT version, with no extra install step, and keeps CI trivial. The addon is a
> dev/test-only dependency — `pack_source.gd` only packs `src/Extensions/ShapeAnnotator/`
> and the tool assets, so it never ships with the extension. Do not edit files under
> `addons/gut/`; to upgrade GUT, replace the directory with a new release.

Requires Godot 4.x on PATH:

```bash
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

For what each test covers, see the [testing strategy](design.md#testing-strategy) in the
design doc.

## Manual smoke-test checklist

*(Complete this after installing in real Pixelorama)*

- [ ] **Tool panel.** Selecting the tool shows the colored header bar + "Shape Annotator"
  name, then Shape / Tag / Mode / (Radius for Capsule) / Show annotations / Settings…
- [ ] **Live preview.** Dragging shows the outline updating in real time; release commits it.
- [ ] **Modes.** "Sprite" shapes appear on all frames; "This frame" creates an override on
  the current frame only (visible in the Shapes panel's "This frame" section).
- [ ] **Show/hide.** The toggle hides/shows all overlays.
- [ ] **Colors.** Edit a tag color in Settings…; overlay + panel swatches update on Save.
- [ ] **Undo/redo.** Ctrl+Z undoes an add and a delete; Ctrl+Y redoes.
- [ ] **Persist.** Save/reload `.pxo`; defaults + overrides survive.
- [ ] **Export.** "Atlas + Spritesheet (ShapeAnnotator)" writes `<name>.png` + `<name>.atlas.json`.
- [ ] **Edit mode.** Set Action = Edit; click a shape (or its panel row) to select; handles appear.
- [ ] **Move/resize/rotate.** Drag body to move; drag a handle to resize; drag the rotate handle to rotate (Alt = free, otherwise snaps to vertical/horizontal). Capsule places vertical.
- [ ] **Undo per gesture.** Ctrl+Z reverts a whole move/resize/rotate in one step.
- [ ] **Rotation round-trips.** Rotate a rect, export; `<name>.atlas.json` records `angle` (degrees); reload `.pxo` preserves it.

## Release

`release.sh` cuts a new version and publishes it to GitHub. It requires `jq`, the
[`gh` CLI](https://cli.github.com/) (authenticated via `gh auth login`), and Godot on
PATH, and refuses to run on a dirty working tree.

```bash
./release.sh 0.2.0     # explicit version
./release.sh patch     # 0.1.0 -> 0.1.1
./release.sh minor     # 0.1.0 -> 0.2.0
./release.sh major     # 0.1.0 -> 1.0.0
```

In order, it:

1. Bumps `version` in `src/Extensions/ShapeAnnotator/extension.json` (the single
   source of truth for the extension version).
2. Prepends a row to the [compatibility table](../README.md#compatibility) in
   `README.md`, prefilled by carrying forward the current top row's Pixelorama and
   Godot columns, then opens `README.md` in `$EDITOR` so you can adjust it. Override
   the prefilled columns with `PIXELORAMA_VERSION=… GODOT_VERSION=… ./release.sh …`,
   or skip the editor entirely with `NO_EDIT=1` (keeps the prefilled row, e.g. in CI).
3. Builds `dist/ShapeAnnotator.pck` via `build.sh`.
4. Commits the manifest + README changes as `Release vX.Y.Z` and creates an annotated
   `vX.Y.Z` tag.
5. Pushes the branch and tag to `origin`.
6. Creates a **draft** GitHub release with the `.pck` attached and auto-generated
   notes. Review and publish it manually from the GitHub UI.
