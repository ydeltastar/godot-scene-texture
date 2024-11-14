@tool
class_name SceneTexture extends Texture2D
## A texture that renders and bakes a view of a 3D [PackedScene]. It can be used to generate icons and
## thumbnails directly from a scene and use it anywhere that accepts a [Texture2D].
## TODO: Maybe implement a DrawableTexture like https://github.com/godotengine/godot-proposals/issues/7379
## with this method https://github.com/godotengine/godot-demo-projects/pull/938

## Emitted when the texture baking finished.
signal bake_finished

enum RenderMethod {
	Default,
	Internal
}

const SceneRender = preload("res://addons/scene_texture/SceneRender.gd")

const SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")

#region Export Variables
@export_group("Texture")
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
		notify_property_list_changed()
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

@export_group("Light", "light_")
@export var light_color = Color.WHITE:
	set(value):
		light_color = value
		_queue_update()

@export var light_energy: float = 2.5:
	set(value):
		light_energy = value
		_queue_update()

@export_custom(PROPERTY_HINT_RANGE, "0,90,0.1,radians_as_degrees")
var light_angular_distance: float = 0:
	set(value):
		light_angular_distance = value
		_queue_update()

@export var light_shadow = false:
	set(value):
		light_shadow = value
		_queue_update()

@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees")
var light_rotation = Vector3(deg_to_rad(-60), deg_to_rad(60), 0):
	set(value):
		light_rotation = value
		_queue_update()

@export_group("Render", "render_")
## Define custom environment settings for the internal render. The render will use the default [World3D] if this is not provided.
## [br][br]
## [b]Note:[/b] that the bake doesn't automatically updates when properties of the [Environment] or [CameraAttributes] change.
## You have to call [method bake].
@export var render_world_3d:World3D:
	set(value):
		if render_world_3d == value:
			return

		if render_world_3d:
			render_world_3d.changed.disconnect(_queue_update)
			# NOTE: These have no effect since the Environment and CameraAttributes doesn't emit changed..
			if render_world_3d.environment:
				render_world_3d.environment.changed.disconnect(_queue_update)
			if render_world_3d.camera_attributes:
				render_world_3d.camera_attributes.changed.disconnect(_queue_update)
		
		render_world_3d = value
		
		if render_world_3d:
			render_world_3d.changed.connect(_queue_update)
			# NOTE: These have no effect since the Environment and CameraAttributes doesn't emit changed..
			if render_world_3d.environment:
				render_world_3d.environment.changed.connect(_queue_update)
			if render_world_3d.camera_attributes:
				render_world_3d.camera_attributes.changed.connect(_queue_update)

		_queue_update()

## Render with transparent background.
@export var render_transparent_bg = true:
	set(value):
		if render_transparent_bg == value:
			return
		
		# FIXME: There is an outline around objects in transparent mode. Maybe feather postprocess the image to remove it.
		# Premultiplied alpha issue? https://github.com/godotengine/godot/issues/17574#issuecomment-1200328756
		# https://github.com/godotengine/godot/issues/78004
		# https://github.com/godotengine/godot/issues/17574
		render_transparent_bg = value
		_queue_update()

## Automatically request bake when settings change.
## [br][br]
## [b]Note:[/b] Changes to [Environment] and [CameraAttributes] can't be automatically catch so they require calling [method bake] manually.
@export var render_auto_bake = true
## Stores the render in the resource file. The texture will use it instead of rendering at runtime when loaded.
@export var render_store_bake = false:
	set(value):
		render_store_bake = value
		if render_store_bake:
			_data = RenderingServer.texture_2d_get(get_rid())
		else:
			_data = null
		notify_property_list_changed()
#endregion

# Used to store image data when render_store_bake is true.
@export_storage var _data:Image

var _texture:RID
var _update_pending = false
var _is_baking = false
var _timer:Timer
var _render:SceneRender


#region Engine Callbacks
func _init() -> void:
	_setup.call_deferred()


func _get_rid() -> RID:
	if not _texture.is_valid():
		# TODO: Use a transparent texture instead
		var image = Image.create_empty(width, height, true, Image.FORMAT_RGBA8)
		_set_texture_image(image)
	
	return _texture


func _get_width() -> int:
	return width


func _get_height() -> int:
	return height


func _validate_property(property: Dictionary):
	if property.name.begins_with("scene_") or property.name.begins_with("camera_") or property.name.begins_with("light_"):
		if scene == null:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "_data":
		if not render_store_bake:
			property.usage = PROPERTY_USAGE_NONE
#endregion


#region Public Functions
## Render scene and update the texture's image.
var _image
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
	_render.update_from_texture(self)

	_render.render_finished.connect(_on_render_finished)
	_image = await _render.render()


func _on_render_finished():
	_set_texture_image(_render.get_render())
	_is_baking = false


func is_baking():
	return _is_baking or _update_pending
#endregion


#region Private Functions
var _initialized = false
func _setup():
	if _data:
		_set_texture_image(_data)
	
	_initialized = true
	
	if not render_store_bake:
		_queue_update()


func _queue_update():
	if not _initialized:
		return
	
	if not render_store_bake:
		_data = null
	
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
	assert(image.get_width() == width)
	assert(image.get_height() == height)
	
	if _texture.is_valid():
		var new_texture = RenderingServer.texture_2d_create(image)
		RenderingServer.texture_replace(_texture, new_texture)
	else:
		_texture = RenderingServer.texture_2d_create(image)
	RenderingServer.texture_set_path(_texture, resource_path)
	
	if render_store_bake:
		_data = image
	else:
		_data = null
	emit_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _texture.is_valid():
			RenderingServer.free_rid(_texture)


func _create_render():
	_render = SCENE_RENDER.instantiate()
#endregion
