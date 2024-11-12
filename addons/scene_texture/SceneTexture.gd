@tool
class_name SceneTexture extends Texture2D
## A texture that renders and bakes a view of a 3D [PackedScene]. It can be used to generate icons and
## thumbnails directly from a scene and use it anywhere that accepts a [Texture2D].
## TODO: Maybe implement a DrawableTexture like https://github.com/godotengine/godot-proposals/issues/7379
## with this method https://github.com/godotengine/godot-demo-projects/pull/938

## Emitted when the texture baking finished.
signal bake_finished

const SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")

## Texture bake width.
@export var width = 64:
	set(value):
		width = clamp(value, 1, 16384)
		_queue_update()
## Texture bake height.
@export var height = 64:
	set(value):
		height = clamp(value, 1, 16384)
		_queue_update()

## Process mode of the scene.
#@export var scene_process_mode:ProcessMode = ProcessMode.PROCESS_MODE_DISABLED

## Scene to render.
@export var scene:PackedScene:
	set(value):
		if scene == value:
			return
			
		scene = value
		_queue_update()

## Define custom environment settings. The render will use the default [World3D] if this is not provided.
## [b]Note:[/b] that the bake doesn't automatically updates when properties of the [Environment] or [CameraAttributes] change.
## You have to call [method bake].
@export var world_3d:World3D:
	set(value):
		if world_3d == value:
			return

		if world_3d:
			world_3d.changed.disconnect(_queue_update)
			# NOTE: These have no effect since the Environment and CameraAttributes doesn't emit changed..
			if world_3d.environment:
				world_3d.environment.changed.disconnect(_queue_update)
			if world_3d.camera_attributes:
				world_3d.camera_attributes.changed.disconnect(_queue_update)
		
		world_3d = value
		
		if world_3d:
			world_3d.changed.connect(_queue_update)
			# NOTE: These have no effect since the Environment and CameraAttributes doesn't emit changed..
			if world_3d.environment:
				world_3d.environment.changed.connect(_queue_update)
			if world_3d.camera_attributes:
				world_3d.camera_attributes.changed.connect(_queue_update)

		_queue_update()

## Render with transparent background.
@export var transparent_bg = true:
	set(value):
		if transparent_bg == value:
			return
		
		transparent_bg = value
		_queue_update()

@export_group("Scene", "scene_")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var scene_position:Vector3:
	set(value):
		scene_position = value
		_queue_update()
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees") var scene_rotation:Vector3:
	set(value):
		scene_rotation = value
		_queue_update()
@export_custom(PROPERTY_HINT_LINK, "") var scene_scale:Vector3 = Vector3.ONE:
	set(value):
		scene_scale = value
		_queue_update()

@export_group("Camera", "camera_")
@export var camera_distance:float = 3.0:
	set(value):
		camera_distance = value
		_queue_update()
@export var camera_position:Vector3 = Vector3(0, 0.175, 0):
	set(value):
		camera_position = value
		_queue_update()
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees")
var camera_rotation = Vector3(deg_to_rad(-40), deg_to_rad(-25), 0):
	set(value):
		camera_rotation = value
		_queue_update()

@export_group("Render", "render_")
## Automatically request bake when settings change.
@export var render_auto_bake = true
## Use [ProjectSetting]'s `rendering/global_illumination/sdfgi/frames_to_converge` to render multiple
## times so SDFGI stabilizes. Can slow down rendering significantly; use only when SDFGI is enabled.
@export var render_use_frames_to_converge = false

var _texture:RID
var _update_pending = false
var _is_baking = false
var _timer:Timer
var _render:SceneRender
var _texture_width:int = 0
var _texture_height:int = 0


#region Engine Callbacks
func _init() -> void:
	_texture_width = 0
	_texture_height = 0
	_queue_update.call_deferred()


func _get_rid() -> RID:
	if not _texture.is_valid():
		_texture = RenderingServer.texture_2d_placeholder_create()
	
	return _texture


func _get_width() -> int:
	return _texture_width


func _get_height() -> int:
	return _texture_height
#endregion


#region Public Functions
## Render scene and update the texture's image.
func bake():
	if not scene or _is_baking:
		return
	
	_is_baking = true
	
	_create_render()
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var root:Node = null
	if Engine.is_editor_hint():
		root = EditorInterface.get_base_control()
	else:
		root = Engine.get_main_loop().root
	
	var scene_tree = Engine.get_main_loop() as SceneTree
	assert(is_instance_valid(scene_tree), "MainLoop is not a SceneTree.")
	scene_tree.root.add_child(_render, false, Node.INTERNAL_MODE_BACK)

	var render_frames = 1
	if render_use_frames_to_converge:
		var converge = ProjectSettings.get_setting("rendering/global_illumination/sdfgi/frames_to_converge") as RenderingServer.EnvironmentSDFGIFramesToConverge
		var v = [5, 10, 15, 20, 25, 30]
		render_frames = v[converge]
	
	RenderingServer.call_on_render_thread(_render_subviewport.bind(_render, render_frames))


func is_baking():
	return _is_baking or _update_pending
#endregion


#region Private Functions
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
	var image = _render.get_texture().get_image()
	_render.queue_free()
	_render = null
	_is_baking = false
	_set_texture_image(image)
	bake_finished.emit()


func _queue_update():
	emit_changed()
	if render_auto_bake == false:
		return

	_update_pending = true
	
	# Duration of rendering before baking. Some rendering features are temporal-based and might need
	# time to settle for better visual quality.
	var bake_delay:float = ProjectSettings.get_setting("scene_texture/auto_bake_delay", 0.25)
	if bake_delay > 0.0:
		if is_instance_valid(_timer):
			_timer.wait_time = bake_delay
			_timer.start()
		else:
			var scene_tree = Engine.get_main_loop() as SceneTree
			assert(is_instance_valid(scene_tree), "MainLoop is not a SceneTree.")
			await scene_tree.process_frame
			_timer = Timer.new()
			_timer.one_shot = true
			_timer.wait_time = bake_delay
			_timer.timeout.connect(_update_now)
			scene_tree.root.add_child(_timer)
			_timer.start()
		
		if _render:
			_render.update_from_texture(self)
	else:
		if is_instance_valid(_timer):
			_timer.stop()
			_timer.queue_free()
			_timer = null
		
		_update_now.call_deferred()


func _update_now():
	if _update_pending:
		_update()


func _update():
	_update_pending = false
	bake()


func _set_texture_image(image:Image):
	_texture_width = image.get_width()
	_texture_height = image.get_height()
	if _texture.is_valid():
		var new_texture = RenderingServer.texture_2d_create(image)
		RenderingServer.texture_replace(_texture, new_texture)
	else:
		_texture = RenderingServer.texture_2d_create(image)
	RenderingServer.texture_set_path(_texture, resource_path)
	emit_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _texture.is_valid():
			RenderingServer.free_rid(_texture)
		

func _create_render():
	_render = SCENE_RENDER.instantiate()
	_render.update_from_texture(self)
#endregion
