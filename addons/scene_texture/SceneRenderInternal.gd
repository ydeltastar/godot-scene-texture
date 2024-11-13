@tool
extends SceneRender
## Render a [SceneTexture] using the engine internal render.


# --- Signals --- #
# --- Enums --- #
# --- Constants --- #
# --- Exported Variables --- #
# --- Public Variables --- #
# --- Private Variables --- #
# --- Onready Variables --- #


# --- Engine Callbacks --- #


# --- Public Functions --- #
static var _main_viewport_active = true
func _render_subviewport(render: SubViewport, iterations:int = 1, disable_main = false):
	# Disable main viewport so it doesn't redrawn
	var scene_tree = Engine.get_main_loop() as SceneTree
	assert(is_instance_valid(scene_tree), "MainLoop is not a SceneTree.")
	var root_viewport = scene_tree.root.get_viewport().get_viewport_rid()
	if disable_main:
		RenderingServer.viewport_set_active(root_viewport, false)
		_main_viewport_active = false
	
	for i in iterations:
		await RenderingServer.frame_pre_draw
		RenderingServer.viewport_set_update_mode(render.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ONCE)
		RenderingServer.force_draw(true, 1.0 / iterations)
		await RenderingServer.frame_post_draw
	
	if not _main_viewport_active:
		# Enable main viewport again
		var v = scene_tree.root.get_viewport_rid()
		RenderingServer.viewport_set_active(v, true)
		_main_viewport_active = true
		await RenderingServer.frame_post_draw # image data doesn't updates correctly without this..

	# Set final texture
	render_finished.emit()


# --- Private Functions --- #
# - Common Use Functions - #
# - Setget Functions - #
# - Signal Functions - #
