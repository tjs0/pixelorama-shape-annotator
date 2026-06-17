extends GutTest

const ShapeConfig = preload("res://src/Extensions/ShapeAnnotator/ShapeConfig.gd")

func _tmp_cfg() -> ConfigFile:
	return ConfigFile.new()

func test_resolve_known_and_fallback():
	var colors := {"hitbox": Color.RED}
	assert_eq(ShapeConfig.resolve_color(colors, "hitbox"), Color.RED)
	assert_eq(ShapeConfig.resolve_color(colors, "mystery"), ShapeConfig.FALLBACK_COLOR)

func test_tag_colors_roundtrip_through_configfile():
	var path := "user://_sa_test_cfg.ini"
	var cfg := _tmp_cfg()
	ShapeConfig.save_tag_colors(cfg, {"hitbox": Color.RED, "hurtbox": Color.BLUE})
	cfg.save(path)
	var loaded := ConfigFile.new()
	loaded.load(path)
	var colors := ShapeConfig.load_tag_colors(loaded)
	assert_eq(colors.get("hitbox"), Color.RED)
	assert_eq(colors.get("hurtbox"), Color.BLUE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_load_tag_colors_empty_when_unset():
	assert_eq(ShapeConfig.load_tag_colors(_tmp_cfg()), {})

func test_seed_if_empty_seeds_then_preserves():
	var cfg := _tmp_cfg()
	var seeded := ShapeConfig.seed_if_empty(cfg)
	assert_eq(seeded, ShapeConfig.DEFAULT_TAG_COLORS)
	# second call must not overwrite a customized map
	ShapeConfig.save_tag_colors(cfg, {"custom": Color.GREEN})
	assert_eq(ShapeConfig.seed_if_empty(cfg), {"custom": Color.GREEN})

func test_show_flag_roundtrip_defaults_true():
	var cfg := _tmp_cfg()
	assert_true(ShapeConfig.load_show(cfg), "defaults to true when unset")
	ShapeConfig.save_show(cfg, false)
	assert_false(ShapeConfig.load_show(cfg))
