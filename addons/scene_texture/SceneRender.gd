@tool
class_name SceneRender extends SubViewport
## Scene setup for rendering a [SceneTexture].
## Should be an oneshot object which is freed after rendering is finished.

## Scene to render.
@export var scene:PackedScene:
	set(value):
		if scene == value:
			return

		scene = value
		_create_scene.call_deferred()
		_update()
## Process mode of the scene.
@export var scene_process_mode:ProcessMode = ProcessMode.PROCESS_MODE_DISABLED

@export_group("Scene Transform", "scene_")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var scene_position:Vector3:
	set(value):
		scene_position = value
		_update()
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees") var scene_rotation:Vector3:
	set(value):
		scene_rotation = value
		_update()
@export_custom(PROPERTY_HINT_LINK, "") var scene_scale = Vector3.ONE:
	set(value):
		scene_scale = value
		_update()

@export_group("Camera", "camera_")
@export var camera_distance:float = 3.0:
	set(value):
		camera_distance = value
		_update()
@export var camera_position = Vector3(0, 0.175, 0):
	set(value):
		camera_position = value
		_update()
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees") var camera_rotation = Vector3(deg_to_rad(-30), deg_to_rad(-25), 0):
	set(value):
		camera_rotation = value
		_update()

@onready var scene_parent: Node3D = $Node3D/Scene
@onready var camera_pivot: Node3D = $Node3D/CameraPivot
@onready var camera: Camera3D = $Node3D/CameraPivot/Camera3D


func _update():
	if not is_node_ready():
		await ready
	
	render_target_update_mode = UpdateMode.UPDATE_WHEN_VISIBLE
	
	camera_pivot.position = camera_position
	camera_pivot.global_rotation = camera_rotation
	camera.position.z = camera_distance
	scene_parent.position = scene_position
	scene_parent.rotation = scene_rotation
	scene_parent.scale = scene_scale


## Update render setting using the [SceneRenderTexture] settings.
func update_from_texture(texture:SceneTexture):
	scene = texture.scene
	if size != Vector2i(texture.width, texture.height):
		size = Vector2i(texture.width, texture.height)
		
	camera_position = texture.camera_position
	camera_rotation = texture.camera_rotation
	camera_distance = texture.camera_distance
	scene_position = texture.scene_position
	scene_rotation = texture.scene_rotation
	scene_scale = texture.scene_scale
	transparent_bg = texture.transparent_bg
	
	var world: World3D = texture.world_3d
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
	
	_update()


func _process(delta: float) -> void:
	#_scene_parent.basis = _scene_parent.basis.rotated(Vector3.UP, deg_to_rad(35 * delta))
	
	var canvas = get_parent() as CanvasItem
	if canvas:
		canvas.queue_redraw() # Required for the rendering to update during the delay


func _create_scene():
	var scene_node = _get_scene_node()
	if scene_node:
		scene_parent.remove_child(scene_node)
		scene_node.queue_free()
	
	if scene:
		var node = scene.instantiate()
		for child in node.get_children():
			child.set_script(null)
			if child is not Node3D:
				child.queue_free()
			
		node.process_mode = scene_process_mode
		scene_parent.add_child(node)


func _get_scene_node() -> Node3D:
	if scene_parent.get_child_count() > 0:
		return scene_parent.get_child(0)
	
	return null
