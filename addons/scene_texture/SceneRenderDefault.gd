@tool
extends "res://addons/scene_texture/SceneRender.gd"
## Render a [SceneTexture] using the engine internal render.


# --- Engine Callbacks --- #


# --- Public Functions --- #
func render(iterations: int):	
	await get_tree().process_frame
	
	render_target_update_mode = UpdateMode.UPDATE_ALWAYS
	_render_subviewport(iterations)


func _render_subviewport(iterations:int = 1, disable_main = false):
	RenderingServer.viewport_set_active(get_viewport_rid(), false)
	
	var scenario = RenderingServer.scenario_create()
	var viewport = RenderingServer.viewport_create()
	RenderingServer.viewport_set_update_mode(viewport, RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.viewport_set_scenario(viewport, scenario)
	RenderingServer.viewport_set_size(viewport, size.x, size.y)
	RenderingServer.viewport_set_transparent_background(viewport, transparent_bg)
	RenderingServer.viewport_set_active(viewport, true)
	RenderingServer.viewport_set_msaa_3d(viewport, RenderingServer.VIEWPORT_MSAA_4X)
	RenderingServer.viewport_set_screen_space_aa(viewport, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
	var viewport_texture = RenderingServer.viewport_get_texture(viewport)
	
	var instances = []
	for node in get_all_children(self):
		if node is VisualInstance3D:
			var base = node.get_instance()
			if base.is_valid():
				RenderingServer.instance_set_scenario(base, scenario)
		elif node is Camera3D: #and node == get_viewport().get_camera_3d():
			var camera = node.get_camera_rid()
			RenderingServer.viewport_attach_camera(viewport, camera)
			instances.append(camera)
	
	await RenderingServer.frame_pre_draw
	RenderingServer.force_draw(false, 1.0 / iterations)
	await RenderingServer.frame_post_draw
	
	_render = RenderingServer.texture_2d_get(viewport_texture)
	
	RenderingServer.free_rid(viewport)
	RenderingServer.free_rid(scenario)
	
	render_finished.emit()

# --- Private Functions --- #
static func get_all_children(node:Node) -> Array[Node]:
	var children:Array[Node] = []

	for child in node.get_children():
		children.append(child)
		children.append_array(get_all_children(child))

	return children


static func _get_children_of_type(node:Node, type, recursive = true) -> Array[Node]:
	var desired_children:Array[Node] = []
	for child in node.get_children():
		if is_instance_of(child, type):
			desired_children.append(child)

		if recursive:
			desired_children.append_array(_get_children_of_type(child, type, recursive))

	return desired_children
