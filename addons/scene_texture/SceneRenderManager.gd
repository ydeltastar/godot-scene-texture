@tool
extends Node


const _SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")
const _SceneRender = preload("res://addons/scene_texture/SceneRender.gd")

var _render_task: Dictionary


func _ready() -> void:
	if not Engine.has_singleton("SceneRenderManager"):
		Engine.register_singleton("SceneRenderManager", self)
		
		
func render(scene_texture: SceneTexture, callable: Callable) -> void:
	assert(is_instance_valid(scene_texture))
	
	var _render = _SCENE_RENDER.instantiate() as _SceneRender
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_render)
	
	_render.update_from_texture(scene_texture)
	
	_render.render()
	await _render.render_finished
	callable.call(_render.get_render())
	_render.queue_free()
