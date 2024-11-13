@tool
extends HBoxContainer
## [SceneTexture]'s preview in the inspector.

const SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")
const SCENE_RENDER_CUSTOM = preload("res://addons/scene_texture/scene_render_custom.tscn")

@onready var subviewport_view = $VBoxContainer/TextureRect
@onready var scene_texture_view = $VBoxContainer_2/SceneTextureRect
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


func _ready() -> void:
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
	
	# FIXME: Remove the subview completly instead of just hiding
	$VBoxContainer.visible = false
	
	if Engine.is_editor_hint():
		return
	
	loading.texture.pause = _is_paused()
	
	_setup()


# Called when the node enters the scene tree for the first time.
func edit(texture:SceneTexture):
	_scene_texture = texture


func update():
	if _render and _scene_texture:
		_render.update_from_texture(_scene_texture)


func _process(delta: float) -> void:
	loading.texture.pause = _is_paused()


func _setup() -> void:
	if not _render:
		_render = _create_render()
		add_child(_render)
	
	if _render:
		subviewport_view.texture = _render.get_texture()
	if _scene_texture:
		scene_texture_view.texture = _scene_texture
	
	_on_changed()


func _create_render() -> SceneRender:
	var render
	match _scene_texture.render_method:
		SceneTexture.RenderMethod.Custom:
			render = SCENE_RENDER_CUSTOM.instantiate()
		
		SceneTexture.RenderMethod.Internal:
			render = SCENE_RENDER.instantiate()
	return render


func _exit_tree() -> void:
	if _scene_texture:
		_scene_texture.changed.disconnect(_on_changed)
	
	if is_instance_valid(_render):
		remove_child(_render)
		_render.queue_free()


func _is_paused():
	return not _scene_texture.is_baking() if _scene_texture != null else true
	

func _on_changed():
	update()
