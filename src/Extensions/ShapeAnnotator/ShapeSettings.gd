extends Window
## Settings dialog: edit the tag→color map. A normal (native-decorated) Window —
## its title bar shows the title and the close "X", and closing saves. Starts
## hidden; only shown when the tool's Settings… button (or the Edit menu item)
## opens it. Saves to Global.config_cache and emits `saved` so Main can refresh
## the overlay/panel.

const ShapeConfig = preload("ShapeConfig.gd")

signal saved(tag_colors: Dictionary)

const ROW_HEIGHT := 38
const VISIBLE_ROWS := 5

var _rows_box: VBoxContainer

func _ready() -> void:
	title = "Shape Annotator Settings"
	visible = false
	size = Vector2i(520, 480)
	min_size = Vector2i(420, 360)
	# Closing the window (native "X") saves and hides.
	close_requested.connect(_on_save)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# --- Tag-Color Mappings section ---
	var section_lbl := Label.new()
	section_lbl.text = "Tag-Color Mappings"
	section_lbl.add_theme_font_size_override("font_size", 16)
	root.add_child(section_lbl)
	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, ROW_HEIGHT * VISIBLE_ROWS)
	root.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows_box)

	var add_btn := Button.new()
	add_btn.text = "Add tag"
	add_btn.pressed.connect(func(): _add_row("", Color.WHITE))
	root.add_child(add_btn)

func menu_item_clicked() -> void:
	popup_centered()

func load_from(colors: Dictionary) -> void:
	if _rows_box == null:
		return
	for c in _rows_box.get_children():
		c.queue_free()
	for tag in colors:
		_add_row(tag, colors[tag])

func _add_row(tag: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT - 4)
	# Color picker on the left, matching the Tool Options Tag dropdown's swatch+name order.
	var picker := ColorPickerButton.new()
	picker.color = color
	picker.custom_minimum_size = Vector2(60, 0)
	picker.name = "Color"
	var name_edit := LineEdit.new()
	name_edit.text = tag
	name_edit.placeholder_text = "tag name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.name = "Tag"
	var del := Button.new()
	del.text = "X"
	del.pressed.connect(func(): row.queue_free())
	row.add_child(picker)
	row.add_child(name_edit)
	row.add_child(del)
	_rows_box.add_child(row)

func _on_save() -> void:
	var colors := {}
	for row in _rows_box.get_children():
		var tag: String = row.get_node("Tag").text.strip_edges()
		if tag.is_empty():
			continue
		colors[tag] = row.get_node("Color").color
	var cfg: ConfigFile = Global.config_cache
	ShapeConfig.save_tag_colors(cfg, colors)
	cfg.save(Global.CONFIG_PATH)
	saved.emit(colors)
	hide()
