class_name BaseTool
extends VBoxContainer
## Compile-time stub of Pixelorama's host `BaseTool`.
##
## This file exists ONLY so the extension's scripts/scenes (e.g. ShapeTool.gd,
## which does `extends BaseTool`) can be parsed and compiled when packing the
## .pck outside of the Pixelorama source tree. It is deliberately EXCLUDED from
## the exported pack (see `res://src/Tools/*` in export_presets.cfg) so it never
## ships and never shadows the real BaseTool that Pixelorama provides at runtime.
##
## Keep the signatures here in sync with the members the extension calls via
## `super(...)` or directly; bodies are intentionally empty.

func _ready() -> void:
	pass

func draw_start(_pos: Vector2i) -> void:
	pass

func draw_move(_pos: Vector2i) -> void:
	pass

func draw_end(_pos: Vector2i) -> void:
	pass

func save_config() -> void:
	pass

func get_config() -> Dictionary:
	return {}

func set_config(_config: Dictionary) -> void:
	pass

func update_config() -> void:
	pass
