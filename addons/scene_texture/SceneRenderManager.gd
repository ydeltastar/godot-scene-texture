@tool
extends Node


const _SCENE_RENDER = preload("res://addons/scene_texture/scene_render.tscn")
const _SceneRender = preload("res://addons/scene_texture/SceneRender.gd")


class RenderTask extends  RefCounted:
	var texture: SceneTexture
	var callable: Callable
	
	
var _render_task: Array[RenderTask]
var _is_rendering := false


func _ready() -> void:
	if not Engine.has_singleton("SceneRenderManager"):
		Engine.register_singleton("SceneRenderManager", self)


func render(scene_texture: SceneTexture, callable: Callable) -> void:
	assert(is_instance_valid(scene_texture))
	
	var task := RenderTask.new()
	task.texture = scene_texture
	task.callable = callable
	
	_render_task.append(task)
	_render_next()


func _render_next() -> void:
	_is_rendering = true
	
	var task := _render_task.pop_front() as RenderTask
	
	var _render := _SCENE_RENDER.instantiate() as _SceneRender
	_render.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_render)
	_render.render_finished.connect(_on_render_finished.bind(_render, task))
		
	_render.render(task.texture)


func _on_render_finished(_render: _SceneRender, task: RenderTask) -> void:
	task.callable.call(_render.get_render())
	_render.queue_free()
	
	if _render_task.is_empty():
		_is_rendering = false
		return
	 
	_render_next()
