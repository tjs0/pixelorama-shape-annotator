extends SceneTree
## Builds the shipped Pixelorama extension .pck from RAW SOURCE files.
##
## Why source instead of `godot --export-pack`:
##   * --export-pack injects project-level metadata (project.binary,
##     .godot/global_script_class_cache.cfg, .godot/uid_cache.bin) which, because
##     Pixelorama mounts extensions with replace_files=true, OVERWRITE the host's
##     own project settings / global class registry / UID cache and break it.
##   * It also compiles the scripts to .gdc bytecode against this repo's *stub*
##     `Global` (a `class_name` with `static` members) and stub `BaseTool`. At
##     runtime Pixelorama's `Global` is an autoload *instance*, so that bytecode
##     is mismatched. Shipping source instead lets Pixelorama compile each script
##     against its OWN `Global`/`BaseTool`, producing correct code.
##
## The stubs in src/Tools/ and src/Autoload/ exist ONLY so this repo parses in the
## Godot editor and under GUT; they are never shipped. See docs/development.md.
##
## Pre-imported textures (.ctex) ARE shipped: Pixelorama loads the tool icon and
## cursor with load("res://assets/graphics/tools/<name>.png"), and an exported
## Pixelorama build cannot import a raw .png at runtime.
##
## Usage: godot --headless --path <repo> --script res://tools/pack_source.gd
## with env var OUT=<output .pck>. Run `--import` first so the .ctex exist.

const EXT_DIR := "res://src/Extensions/ShapeAnnotator"
const SKIP_EXT := ["uid"]  # editor-only UID sidecars; not needed at runtime

# Asset sidecars + their pre-imported textures (load() resolves .png via .import).
const ASSETS := [
	"res://assets/graphics/tools/shapeannotator.png",
	"res://assets/graphics/tools/shapeannotator.png.import",
	"res://assets/graphics/tools/cursors/shapeannotator.png",
	"res://assets/graphics/tools/cursors/shapeannotator.png.import",
]


func _collect_ext(out: Array) -> void:
	var d := DirAccess.open(EXT_DIR)
	if d == null:
		push_error("Cannot open %s" % EXT_DIR)
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if not d.current_is_dir() and not (n.get_extension() in SKIP_EXT):
			out.append(EXT_DIR.path_join(n))
		n = d.get_next()
	d.list_dir_end()


func _collect_imported_textures(out: Array) -> void:
	var d := DirAccess.open("res://.godot/imported")
	if d == null:
		push_error("Missing res://.godot/imported -- run `godot --import` first")
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n.begins_with("shapeannotator.png-") and n.get_extension() == "ctex":
			out.append("res://.godot/imported/".path_join(n))
		n = d.get_next()
	d.list_dir_end()


func _init() -> void:
	var out := OS.get_environment("OUT")
	if out == "":
		push_error("OUT environment variable is required")
		quit(1)
		return

	var files: Array = []
	_collect_ext(files)
	for a in ASSETS:
		if FileAccess.file_exists(a):
			files.append(a)
		else:
			push_error("Missing asset: %s" % a)
			quit(1)
			return
	_collect_imported_textures(files)
	files.sort()

	var packer := PCKPacker.new()
	if packer.pck_start(out) != OK:
		push_error("pck_start failed for %s" % out)
		quit(1)
		return
	for f in files:
		if packer.add_file(f, f) != OK:
			push_error("add_file failed for %s" % f)
			quit(1)
			return
		print("  + ", f)
	if packer.flush(false) != OK:
		push_error("flush failed for %s" % out)
		quit(1)
		return
	print("Packed %d source files -> %s" % [files.size(), out])
	quit(0)
