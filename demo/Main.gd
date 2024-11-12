extends Node3D


@export var scene_pivot:Node3D
@export_range(-180, 180, 0.001, "radians_as_degrees") var rotation_speed = deg_to_rad(5.0)

var _current_scene:PackedScene

@onready var _instance:Node3D = $ScenePivot/Tree1


func _ready() -> void:
	for button:Button in $Control/CenterContainer/GridContainer.get_children():
		button.pressed.connect(_on_button_pressed.bind(button))


func _process(delta: float) -> void:
	scene_pivot.rotate_y(rotation_speed * delta)


func _on_button_pressed(button:Button):
	var texture = button.icon as SceneTexture
	if _current_scene == texture.scene:
		return
	
	if is_instance_valid(_instance):
		scene_pivot.remove_child(_instance)
	
	_current_scene = texture.scene
	_instance = _current_scene.instantiate()
	
	scene_pivot.add_child(_instance)
