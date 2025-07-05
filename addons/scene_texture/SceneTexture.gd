@tool
class_name SceneTexture extends Texture2D
## A texture that renders and bakes a view of a 3D [PackedScene]. It can be used to generate icons and
## thumbnails directly from a scene and use it anywhere that accepts a [Texture2D].

# TODO: Use RenderingDevice.texture_get_data_async() to get the subviewport in 4.4
# https://github.com/godotengine/godot/pull/100110

## Emitted when the texture's bake process finished.
signal bake_finished

const _SceneRender = preload("res://addons/scene_texture/SceneRender.gd")

const _SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")

#region Export Variables
## The texture's size.
@export var size := Vector2i(64, 64):
	set(value):
		size = value.clampi(1, 16384)
		_queue_update()

## The scene to render.
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
@export_custom(PROPERTY_HINT_ENUM, "Perspective,Orthogonal,Frustum")
var camera_projection:Camera3D.ProjectionType:
	set(value):
		camera_projection = value
		notify_property_list_changed()
		_queue_update()

@export_custom(PROPERTY_HINT_RANGE, "1,179,0.1,degrees")
var camera_fov:float = 30:
	set(value):
		camera_fov = value
		_queue_update()
@export var camera_size:float = 1:
	set(value):
		camera_size = value
		_queue_update()
@export var camera_frustum_offset:Vector2:
	set(value):
		camera_frustum_offset = value
		_queue_update()
@export_custom(PROPERTY_HINT_RANGE, "0.001,10,0.001,or_greater,exp,suffix:m")
var camera_near:float = 0.05:
	set(value):
		camera_near = value
		_queue_update()
@export_custom(PROPERTY_HINT_RANGE, "0.01,4000,0.01,or_greater,exp,suffix:m")
var camera_far:float = 500.0:
	set(value):
		camera_far = value
		_queue_update()
@export var camera_distance:float = 3.0:
	set(value):
		camera_distance = value
		_queue_update()
@export var camera_position := Vector3(0, 0.175, 0):
	set(value):
		camera_position = value
		_queue_update()
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees")
var camera_rotation := Vector3(deg_to_rad(-40), deg_to_rad(-25), 0):
	set(value):
		camera_rotation = value
		_queue_update()

@export_group("Light", "light_")
@export var light_color := Color.WHITE:
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

@export var light_shadow: bool = false:
	set(value):
		light_shadow = value
		_queue_update()

@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,radians_as_degrees")
var light_rotation := Vector3(deg_to_rad(-60), deg_to_rad(60), 0):
	set(value):
		light_rotation = value
		_queue_update()

@export_group("Render", "render_")
## Define custom environment settings for the internal render. The render will use the [World3D] in
## project setting [code]scene_texture/default_world_3d[/code] if this is not provided.
## [br][br]
## [b]Note:[/b] The bake doesn't automatically updates when properties of the [Environment] or [CameraAttributes] change.
## You have to call [method bake] or click in the texture preview in the inspector to update.
@export var render_world_3d: World3D:
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
@export var render_transparent_bg: bool = true:
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
## For the editor, you can click on the texture preview in the inspector to manually request a bake.
## [br][br]
## [b]Note:[/b] See project setting [code]scene_texture/auto_bake_delay[/code] to configurate the bake timer.
@export var render_auto_bake: bool = true

## Stores the render in the resource file. The texture will use it instead of rendering at runtime when loaded.
@export var render_store_bake: bool = false:
	set(value):
		render_store_bake = value
		if render_store_bake:
			_data = RenderingServer.texture_2d_get(get_rid())
		else:
			_data = null
		notify_property_list_changed()

## Sets the multisample anti-aliasing mode.
@export_custom(PROPERTY_HINT_ENUM, "Disabled (Fastest),2× (Average),4× (Slow),8× (Slowest)") var render_msaa_3d := Viewport.MSAA_4X:
	set(value):
		render_msaa_3d = value
		_queue_update()
## Sets the screen-space antialiasing method.
@export_custom(PROPERTY_HINT_ENUM, "Disabled (Fastest),FXAA (Fast)") var render_screen_space_aa := Viewport.SCREEN_SPACE_AA_FXAA:
	set(value):
		render_screen_space_aa = value
		_queue_update()
#endregion

# Used to store image data when render_store_bake is true.
@export_storage var _data:Image

var _texture:RID
var _update_pending = false
var _is_baking = false
var _timer:Timer
var _render:_SceneRender


#region Engine Callbacks
func _init() -> void:
	_initialize.call_deferred()


func _get_rid() -> RID:
	if not _texture.is_valid():
		var image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
		_set_image(image)
	
	return _texture


func _get_width() -> int:
	return size.x


func _get_height() -> int:
	return size.y


func _validate_property(property: Dictionary):
	if property.name == "_data":
		if not render_store_bake:
			property.usage = PROPERTY_USAGE_NONE
	elif property.name == "camera_distance":
		if camera_projection != Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "camera_fov":
		if camera_projection != Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "camera_size":
		if camera_projection != Camera3D.ProjectionType.PROJECTION_ORTHOGONAL and camera_projection != Camera3D.ProjectionType.PROJECTION_FRUSTUM:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "camera_frustum_offset":
		if camera_projection != Camera3D.ProjectionType.PROJECTION_FRUSTUM:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	
	if property.name.begins_with("scene_") or property.name.begins_with("camera_") or property.name.begins_with("light_"):
		if scene == null:
			property.usage = PROPERTY_USAGE_NO_EDITOR
#endregion


#region Public Functions
## Render the scene and update the texture's image. Rendering and texture fetching can happen in
## another thread so this function returns before it finishes. Emits [signal bake_finished] when
## finished.
func bake():
	if not scene or _is_baking:
		return
	
	_is_baking = true
	
	_render = _SCENE_RENDER.instantiate() as SubViewport
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var scene_tree = Engine.get_main_loop() as SceneTree
	if not is_instance_valid(scene_tree):
		push_error("Can't setup render because MainLoop is not a SceneTree.")
		return
	
	scene_tree.root.add_child.call_deferred(_render, false, Node.INTERNAL_MODE_BACK)
	await _render.ready
		
	_render.update_from_texture(self)
	
	_render.render()
	await _render.render_finished
	_set_image(_render.get_render())
	_is_baking = false
	_render.queue_free()
	
	bake_finished.emit()


## Returns [code]true[/code] if a bake is in process.
func is_baking() -> bool:
	return _is_baking or _update_pending


# Can't use get_image() directly until https://github.com/godotengine/godot-proposals/issues/12097
# is solved.
## Use this instead of [member get_image] to get the correct image data from the
## texture.
func get_render_image() -> Image:
	return RenderingServer.texture_2d_get(_get_rid())
#endregion


#region Private Functions
var _initialized = false
func _initialize():
	if _data:
		_set_image(_data)
	
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
		
		if is_instance_valid(_render):
			_render.update_from_texture(self)
	else:
		if is_instance_valid(_timer):
			_timer.stop()
			_timer.queue_free()
			_timer = null
		
		_update_now.call_deferred()


func _update_now():
	if is_instance_valid(_timer):
		_timer.queue_free()
	
	if _update_pending:
		_update()


func _update():
	_update_pending = false
	bake()


func _set_image(image:Image):
	assert(image.get_width() == size.x)
	assert(image.get_height() == size.y)
	
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
#endregion
