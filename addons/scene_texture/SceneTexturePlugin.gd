@tool
extends EditorPlugin


var scene_texture_inspector = preload("res://addons/scene_texture/editor/SceneTextureInspector.gd").new()


func _enter_tree() -> void:
	var prop = "scene_texture/auto_bake_delay"
	var default_value = 0.25
	if not ProjectSettings.has_setting(prop):
		ProjectSettings.set_setting(prop, default_value)
	ProjectSettings.set_initial_value(prop, default_value)
	
	add_inspector_plugin(scene_texture_inspector)


func _exit_tree() -> void:
	remove_inspector_plugin(scene_texture_inspector)
