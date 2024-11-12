extends EditorInspectorPlugin


const SCENE_TEXTURE_PREVIEW = preload("res://addons/scene_texture/editor/scene_texture_preview.tscn")

var _previewer


func _can_handle(object: Object) -> bool:
	return object is SceneTexture


func _parse_begin(object: Object) -> void:
	var texture = object as SceneTexture
	
	_previewer = SCENE_TEXTURE_PREVIEW.instantiate()
	add_custom_control(_previewer)
	
	_previewer.edit(texture)


func _on_update_pressed(texture: SceneTexture):
	texture.bake()
	_previewer.update()
