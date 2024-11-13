@tool
extends SceneRender
## Render a [SceneTexture] using the engine internal render.


# --- Engine Callbacks --- #


# --- Public Functions --- #
func render(iterations: int):	
	await get_tree().process_frame
	
	render_target_update_mode = UpdateMode.UPDATE_ALWAYS
	RenderingServer.call_on_render_thread(_render_subviewport.bind(iterations))


func _render_subviewport(iterations:int = 1, disable_main = false):
	RenderingServer.viewport_set_active(get_viewport_rid(), false)
	
	var mesh_instances = _get_children_of_type(self, MeshInstance3D)
	
	var scenario = RenderingServer.scenario_create()
	
	var viewport = RenderingServer.viewport_create()
	RenderingServer.viewport_set_update_mode(viewport, RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.viewport_set_scenario(viewport, scenario)
	RenderingServer.viewport_set_size(viewport, size.x, size.y)
	RenderingServer.viewport_set_transparent_background(viewport, true)
	RenderingServer.viewport_set_active(viewport, true)
	var viewport_texture = RenderingServer.viewport_get_texture(viewport)
	
	var instances = []
	for node in get_all_children(self):
		if node is MeshInstance3D:
			var base = node.get_base()
			if node.mesh:
				var instance = RenderingServer.instance_create2(node.mesh.get_rid(), scenario)
				RenderingServer.instance_set_transform(instance, Transform3D())
				instances.append(instance)
		elif node is Camera3D: #and node == get_viewport().get_camera_3d():
			var camera = RenderingServer.camera_create()
			RenderingServer.viewport_attach_camera(viewport, camera)
			RenderingServer.camera_set_transform(camera, node.global_transform)
			RenderingServer.camera_set_perspective(camera, node.fov, node.near, node.far)
			instances.append(camera)
		elif node is DirectionalLight3D:
			var light = RenderingServer.directional_light_create()
			var light_instance = RenderingServer.instance_create2(light, scenario)
			var xform = node.global_transform
			xform.basis = xform.basis.inverse()
			RenderingServer.instance_set_transform(light_instance, xform)
			instances.append(light_instance)
	
	await RenderingServer.frame_pre_draw
	RenderingServer.force_draw(true, 1.0 / iterations)
	await RenderingServer.frame_post_draw
	
	_render = RenderingServer.texture_2d_get(viewport_texture)
	
	for instance in instances:
		RenderingServer.free_rid(instance)
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
