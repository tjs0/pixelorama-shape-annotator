extends Node
## Extension entry point listed in extension.json `nodes`.

const ShapeStore = preload("ShapeStore.gd")
const ShapeOverlay = preload("ShapeOverlay.gd")
const ShapePanel = preload("ShapePanel.gd")
const ShapeExporter = preload("ShapeExporter.gd")
const ShapeTool = preload("ShapeTool.gd")
const ShapeConfig = preload("ShapeConfig.gd")
const ShapeSettings = preload("ShapeSettings.gd")

const TOOL_NAME := "ShapeAnnotator"

var _api: Node
var _store: ShapeStore
var _overlay: ShapeOverlay
var _panel: ShapePanel
var _exporter: ShapeExporter
var _export_id := -1
var _export_menu_id := -1
var _export_dialog: FileDialog
var _settings: Window
var _settings_menu_id := -1
var _tag_colors: Dictionary
var _tool: Node  # the live ShapeTool, registered so we can refresh its tag dropdown

func _enter_tree() -> void:
    _api = get_node_or_null("/root/ExtensionsApi")
    if _api == null:
        push_error("ShapeAnnotator: ExtensionsApi not found")
        return

    _store = ShapeStore.new()
    _store.bind(_api.project.current_project)

    var cfg: ConfigFile = _api.general.get_config_file()
    _tag_colors = ShapeConfig.seed_if_empty(cfg)
    cfg.save(_api.general.get_global().CONFIG_PATH)

    # Overlay on the canvas (pixel space).
    _overlay = ShapeOverlay.new()
    _overlay.store = _store
    _overlay.get_current_frame = _current_frame
    _overlay.tag_colors = _tag_colors
    _overlay.fallback = ShapeConfig.FALLBACK_COLOR
    _overlay.visible = ShapeConfig.load_show(cfg)
    _api.general.get_canvas().add_child(_overlay)

    # Inject store + overlay into ShapeTool via static vars. We pass `self` as a
    # plain Node reference (not self-capturing lambdas): a lambda Callable stored in
    # a `static` var outlives the capturing instance and double-frees at teardown.
    ShapeTool.shared_store = _store
    ShapeTool.shared_overlay = _overlay
    ShapeTool.shared_host = self

    # Panel.
    _panel = ShapePanel.new()
    _panel.store = _store
    _panel.overlay = _overlay
    _panel.get_current_frame = _current_frame
    _api.panel.add_node_as_tab(_panel)

    # Settings dialog.
    _settings = ShapeSettings.new()
    _api.dialog.get_dialogs_parent_node().add_child(_settings)
    _settings.saved.connect(_on_settings_saved)
    _settings.load_from(_tag_colors)
    _settings_menu_id = _api.menu.add_menu_item(_api.menu.EDIT, "Shape Annotator Settings…", _settings)

    # Tool.
    _api.tools.add_tool(TOOL_NAME, "Shape Annotator", "res://src/Extensions/ShapeAnnotator/ShapeTool.tscn",
        [], "", "", [], -1)

    # Exporter.
    _exporter = ShapeExporter.new()
    add_child(_exporter)
    _export_id = _api.export.add_export_option(
        {"extension": ".atlas.json", "description": "Atlas + Spritesheet (ShapeAnnotator)"},
        _exporter, _api.export.ExportTab.IMAGE, true)

    # Standalone "Export Shape Atlas…" File-menu item + save dialog. Pixelorama's
    # own export dialog can't select a custom format on desktop (1.1.10), so we
    # drive the export ourselves.
    _export_dialog = FileDialog.new()
    _export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    _export_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _export_dialog.title = "Export Shape Atlas"
    _export_dialog.current_file = "sprite.atlas.json"
    _export_dialog.add_filter("*.atlas.json", "Shape Atlas (PNG + JSON sidecar)")
    _export_dialog.file_selected.connect(_on_export_path_selected)
    _api.dialog.get_dialogs_parent_node().add_child(_export_dialog)
    _export_menu_id = _api.menu.add_menu_item(_api.menu.FILE, "Export Shape Atlas…", self)

    # Keep store + overlay current.
    _api.signals.signal_project_switched(_on_project_switched)
    _api.signals.signal_cel_switched(_on_cel_switched)

## Called by ShapeTool (via its `shared_host` static reference) to open the dialog.
func open_settings() -> void:
    if _settings != null:
        _settings.popup_centered()

## Pixelorama calls this on the File-menu "Export Shape Atlas…" item.
func menu_item_clicked() -> void:
    if _export_dialog != null:
        _export_dialog.popup_centered_ratio(0.6)

func _on_export_path_selected(path: String) -> void:
    var project: Object = _api.project.current_project
    var drawing_algos: Object = _api.general.get_drawing_algos()
    if _exporter.export_project_to(project, drawing_algos, path):
        print("ShapeAnnotator: exported atlas to ", path)
    else:
        push_error("ShapeAnnotator: atlas export failed for " + path)

## Called by ShapeTool (via its `shared_host` static reference) for the tag list.
func tag_names() -> PackedStringArray:
    return PackedStringArray(_tag_colors.keys())

## Called by ShapeTool to render color swatches next to each tag in its dropdown.
func tag_colors_map() -> Dictionary:
    return _tag_colors

## ShapeTool registers/unregisters itself so we can refresh its tag dropdown when
## the tag→color map changes (Main has no instance handle to the tool otherwise).
func register_tool(tool: Node) -> void:
    _tool = tool

func unregister_tool(tool: Node) -> void:
    if _tool == tool:
        _tool = null

func _on_settings_saved(colors: Dictionary) -> void:
    _tag_colors = colors
    _overlay.tag_colors = _tag_colors
    _overlay.refresh()
    _panel.rebuild()
    if _tool != null and is_instance_valid(_tool):
        _tool.refresh_tags()

func _exit_tree() -> void:
    if _api == null:
        return
    _api.signals.signal_project_switched(_on_project_switched, true)
    _api.signals.signal_cel_switched(_on_cel_switched, true)
    if _settings_menu_id != -1:
        _api.menu.remove_menu_item(_api.menu.EDIT, _settings_menu_id)
    if _settings != null:
        _settings.queue_free()
    if _export_id != -1:
        _api.export.remove_export_option(_export_id)
    if _export_menu_id != -1:
        _api.menu.remove_menu_item(_api.menu.FILE, _export_menu_id)
    if _export_dialog != null:
        _export_dialog.queue_free()
    if _panel != null:
        # remove_node_from_tab() already queue_free()s the node; do not double-free.
        _api.panel.remove_node_from_tab(_panel)
    _api.tools.remove_tool(TOOL_NAME)
    # Drop ShapeTool's static references so they don't dangle after disable.
    ShapeTool.shared_store = null
    ShapeTool.shared_overlay = null
    ShapeTool.shared_host = null
    if _overlay != null:
        _overlay.queue_free()
    if _exporter != null:
        _exporter.queue_free()

func _current_frame() -> Object:
    var proj = _api.project.current_project
    return proj.frames[proj.current_frame]

func _clear_selection() -> void:
    # A selection indexes the previous frame's effective shape list; switching
    # frame/project would leave it pointing at the wrong shape, so drop it.
    _overlay.selected_index = -1
    _overlay.clear_edit_preview()

func _on_project_switched() -> void:
    _store.bind(_api.project.current_project)
    _clear_selection()
    _overlay.refresh()
    _panel.rebuild()

func _on_cel_switched() -> void:
    _clear_selection()
    _overlay.refresh()
    _panel.rebuild()
