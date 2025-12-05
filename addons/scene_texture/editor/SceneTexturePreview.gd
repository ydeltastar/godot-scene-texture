@tool
extends HBoxContainer
## [SceneTexture]'s preview in the inspector.

const SceneRender = preload("res://addons/scene_texture/SceneRender.gd")

const SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")

@onready var scene_texture_view = $VBoxContainer_2/SceneTextureView
@onready var loading: TextureRect = $VBoxContainer_2/HBoxContainer/Loading

var _scene_texture:SceneTexture:
	set(value):
		if _scene_texture:
			_scene_texture.changed.disconnect(_on_changed)
		
		_scene_texture = value
		
		if _scene_texture:
			_scene_texture.changed.connect(_on_changed)
			_setup.call_deferred()
		else:
			if _render:
				remove_child(_render)
				_render.queue_free()
				_render = null
				
var _render:SceneRender
var _timer:Timer
var _update_pending = false


func _ready() -> void:
	_timer = Timer.new()
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_update_now)
	
	# Fetch the progress icon animation from the editor.
	# Avoids saving the progress image data in the PackedScene.
	var root = EditorInterface.get_edited_scene_root()
	if root.scene_file_path != scene_file_path:
		var ani_texture = AnimatedTexture.new()
		ani_texture.frames = 8
		ani_texture.speed_scale = 8.0
		ani_texture.pause = true
		
		var editor_theme = EditorInterface.get_editor_theme()
		for i in range(ani_texture.frames):
			var texture = editor_theme.get_icon("Progress%d" % (i + 1), "EditorIcons")
			ani_texture.set_frame_texture(i, texture)
		
		loading.texture = ani_texture
	
	if Engine.is_editor_hint():
		return
	
	loading.texture.pause = _is_paused()
	
	_setup()


# Called when the node enters the scene tree for the first time.
func edit(texture:SceneTexture):
	_scene_texture = texture


func _process(delta: float) -> void:
	if loading.texture:
		loading.texture.pause = _is_paused()


func _setup() -> void:
	if not _render:
		_render = _create_render()
		add_child(_render)
	
	if _scene_texture:
		scene_texture_view.texture = _scene_texture
	
	_on_changed()


func _create_render() -> SceneRender:
	return SCENE_RENDER.instantiate()


func _exit_tree() -> void:
	if _scene_texture:
		_scene_texture.changed.disconnect(_on_changed)
	
	if is_instance_valid(_render):
		remove_child(_render)
		_render.queue_free()


func _is_paused():
	return not _scene_texture.is_baking() if _scene_texture != null else true
	

func _on_changed():
	_update_pending = true
	
	_timer.stop()
	var bake_delay:float = ProjectSettings.get_setting("scene_texture/auto_bake_delay", 0.25)
	if bake_delay > 0.0:
		_timer.start(bake_delay)
	else:
		_update_now.call_deferred()


func _update_now():
	if _update_pending:
		_update()


func _update():
	if not _timer.is_stopped():
		_timer.stop()
		
	_update_pending = false
	_scene_texture.bake()
