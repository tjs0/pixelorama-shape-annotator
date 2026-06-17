extends GutTest

const ShapeTool = preload("res://src/Extensions/ShapeAnnotator/ShapeTool.gd")

# Regression: the tool must open in Draw mode. A prior Edit selection used to be
# persisted as `action` and reloaded into current_action, while the rebuilt UI
# showed "Draw" — so draw_start() routed into edit mode and no shapes were drawn.

func test_action_mode_not_persisted_in_config():
	var t = ShapeTool.new()
	assert_false(t.get_config().has("action"), "action is transient and must not be saved")
	t.free()

func test_set_config_ignores_action_and_stays_in_draw_mode():
	var t = ShapeTool.new()
	t.set_config({"action": 1, "type": "circle", "mode": 1})
	assert_eq(t.current_action, t.ACTION_DRAW, "tool opens in Draw mode regardless of saved action")
	assert_eq(t.current_type, "circle", "other persisted config still loads")
	assert_eq(t.current_mode, 1, "other persisted config still loads")
	t.free()
