extends RefCounted
## Pure config helpers for the tag→color map and the show/hide flag. Functions
## take a ConfigFile so they are headless-testable; runtime callers pass
## Global.config_cache and then Global.config_cache.save(Global.CONFIG_PATH).

const SECTION := "shape_annotator"
const KEY_TAG_COLORS := "tag_colors"
const KEY_SHOW := "show_annotations"

const DEFAULT_TAG_COLORS := {}
const FALLBACK_COLOR := Color.YELLOW

static func load_tag_colors(cfg: ConfigFile) -> Dictionary:
	var v: Variant = cfg.get_value(SECTION, KEY_TAG_COLORS, {})
	return v if v is Dictionary else {}

static func save_tag_colors(cfg: ConfigFile, colors: Dictionary) -> void:
	cfg.set_value(SECTION, KEY_TAG_COLORS, colors)

static func seed_if_empty(cfg: ConfigFile) -> Dictionary:
	var colors := load_tag_colors(cfg)
	if colors.is_empty():
		colors = DEFAULT_TAG_COLORS.duplicate(true)
		save_tag_colors(cfg, colors)
	return colors

static func resolve_color(colors: Dictionary, tag: String) -> Color:
	return colors.get(tag, FALLBACK_COLOR)

static func load_show(cfg: ConfigFile) -> bool:
	return bool(cfg.get_value(SECTION, KEY_SHOW, true))

static func save_show(cfg: ConfigFile, value: bool) -> void:
	cfg.set_value(SECTION, KEY_SHOW, value)
