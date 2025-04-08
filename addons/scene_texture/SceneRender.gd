@tool
extends SubViewport
## Renders a scene to an [Image].
## Should be an oneshot object which is freed after rendering is finished.

signal render_finished

## Scene to render.
@export var scene: PackedScene:
	set(value):
		if scene == value:
			return

		scene = value
		_create_scene.call_deferred()

@onready var scene_parent: Node3D = $Node3D/Scene
@onready var camera_pivot: Node3D = $Node3D/CameraPivot
@onready var camera: Camera3D = $Node3D/CameraPivot/Camera3D
@onready var main_light: DirectionalLight3D = $Node3D/DirectionalLight3D

var light_color: Color
var light_energy: float
var light_angular_distance: float
var scene_process_mode: ProcessMode = ProcessMode.PROCESS_MODE_DISABLED

var _render: Image


## Update render setting using the [SceneTexture] settings.
func update_from_texture(texture:SceneTexture):
	scene = texture.scene
	if size != texture.size:
		size = texture.size
		
	camera_pivot.position = texture.camera_position
	camera_pivot.global_rotation = texture.camera_rotation
	camera.position.z = texture.camera_distance

	camera.projection = texture.camera_projection
	camera.fov = texture.camera_fov
	camera.size = texture.camera_size
	camera.frustum_offset = texture.camera_frustum_offset
	camera.near = texture.camera_near
	camera.far = texture.camera_far
	
	scene_parent.position = texture.scene_position
	scene_parent.rotation = texture.scene_rotation
	scene_parent.scale = texture.scene_scale
	transparent_bg = texture.render_transparent_bg
	
	main_light.light_color = texture.light_color
	main_light.light_energy = texture.light_energy
	main_light.light_angular_distance = texture.light_angular_distance
	main_light.shadow_enabled = texture.light_shadow
	main_light.global_rotation = texture.light_rotation
	
	screen_space_aa = texture.render_screen_space_aa
	msaa_3d = texture.render_msaa_3d
	
	var world: World3D = texture.render_world_3d
	if not is_instance_valid(world):
		var default_env = ProjectSettings.get_setting("scene_texture/default_world_3d")
		if default_env:
			world = load(default_env)
	
	# HACK: Just setting world_3d gives an error in the editor. The SubViewport's own_world_3d must
	# start as false so the error doesn't happen.
	# https://github.com/godotengine/godot/issues/86456
	# https://github.com/godotengine/godot/issues/56518#issuecomment-2316687375
	world_3d = world
	own_world_3d = true
	
	render_target_update_mode = UpdateMode.UPDATE_WHEN_VISIBLE


func render():
	var render_frames = 1
	var world = find_world_3d()
	
	# Some rendering features like GI are temporal-based and might need time to settle for better visual quality.
	# Use settings to define how many frames to iterate the render for temporal features.
	var has_gi = world and world.environment and world.environment.sdfgi_enabled
	if has_gi:
		var converge = ProjectSettings.get_setting("rendering/global_illumination/sdfgi/frames_to_converge") as RenderingServer.EnvironmentSDFGIFramesToConverge
		var v = [5, 10, 15, 20, 25, 30]
		render_frames = v[converge]
	
	RenderingServer.call_on_render_thread(_render_subviewport.bind(self, render_frames))


func get_render() -> Image:
	return _render


# --- Private Functions --- #
func _create_scene():
	var scene_node = _get_scene_node()
	if scene_node:
		scene_parent.remove_child(scene_node)
		scene_node.queue_free()
	
	if scene:
		var node = scene.instantiate()
		node = _cleanup_node(node)
		scene_parent.add_child(node)


func _cleanup_node(node:Node):
	node.set_script(null)
	node.process_mode = scene_process_mode
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	
	if node is not Node3D:
		var replacement = Node3D.new()
		replacement.name = node.name
		node.replace_by(replacement)
		node.free()
		node = replacement
		
	elif node is not VisualInstance3D:
		var replacement = Node3D.new()
		replacement.name = node.name
		replacement.visible = node.visible
		replacement.transform = node.transform
		replacement.rotation_edit_mode = node.rotation_edit_mode
		replacement.rotation_order = node.rotation_order
		replacement.top_level = node.top_level
		node.replace_by(replacement)
		node.free()
		node = replacement
	
	for child in node.get_children():
		_cleanup_node(child)
	
	return node


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

	_render = get_texture().get_image()
	# Set final texture
	render_finished.emit()


static func _get_all_children(node:Node) -> Array[Node]:
	var children:Array[Node] = []

	for child in node.get_children():
		children.append(child)
		children.append_array(_get_all_children(child))

	return children


func _get_scene_node() -> Node3D:
	if scene_parent.get_child_count() > 0:
		return scene_parent.get_child(0)
	
	return null
