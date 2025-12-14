@tool
extends HBoxContainer
## [SceneTexture]'s preview in the inspector.

const SceneRender = preload("res://addons/scene_texture/SceneRender.gd")

const SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")

@onready var scene_texture_view = $VBoxContainer/SceneTextureView
@onready var loading: TextureRect = $VBoxContainer/HBoxContainer/Loading

var _scene_texture: SceneTexture
var _update_pending = false


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
	
	scene_texture_view.texture = _scene_texture
	
	if Engine.is_editor_hint():
		return
	
	loading.texture.pause = _is_paused()


# Called when the node enters the scene tree for the first time.
func edit(texture:SceneTexture):
	_scene_texture = texture


func _process(delta: float) -> void:
	if loading.texture:
		loading.texture.pause = _is_paused()


func _is_paused():
	return not _scene_texture.is_baking() if _scene_texture != null else true


func _update():
	_scene_texture.bake()
