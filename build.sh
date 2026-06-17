#!/usr/bin/env bash
set -euo pipefail
# Packs the shipped Pixelorama extension into dist/ShapeAnnotator.pck.
#
# The pack contains RAW SOURCE (src/Extensions/ShapeAnnotator/*.gd + *.tscn +
# extension.json) plus the pre-imported tool icon/cursor textures. It deliberately
# does NOT use `godot --export-pack`, because that bundles project-level metadata
# (project.binary, .godot/global_script_class_cache.cfg, .godot/uid_cache.bin) that
# Pixelorama would mount with replace_files=true and clobber its own settings,
# global class registry and UID cache -- breaking Global/BaseTool resolution and
# the whole host. Shipping source also lets Pixelorama compile each script against
# its own `Global` autoload / `BaseTool`, instead of this repo's compile-time
# stubs. See tools/pack_source.gd and docs/development.md.
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT/dist"

OUT_PCK="$ROOT/dist/ShapeAnnotator.pck"

# Import so the tool icon/cursor .ctex exist (Pixelorama can't import a raw .png
# at runtime in an exported build).
godot --headless --path "$ROOT" --import

OUT="$OUT_PCK" godot --headless --path "$ROOT" --script res://tools/pack_source.gd

echo "Wrote dist/ShapeAnnotator.pck"
