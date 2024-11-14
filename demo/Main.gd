extends Node3D


@export var scene_pivot:Node3D
@export_range(-180, 180, 0.001, "radians_as_degrees") var rotation_speed = deg_to_rad(5.0)

var _current_scene:PackedScene

@onready var _instance:Node3D = $ScenePivot/tree_blocks2
@onready var button_grid: GridContainer = $Control/CenterContainer/VBoxContainer/GridContainer
@onready var board: MeshInstance3D = $Node3D/CSGBox3D/MeshInstance3D


func _ready() -> void:
	for button:Button in button_grid.get_children():
		button.pressed.connect(_on_button_pressed.bind(button))
	
	_on_button_pressed($Control/CenterContainer/VBoxContainer/GridContainer/Button2)


func _process(delta: float) -> void:
	scene_pivot.rotate_y(rotation_speed * delta)


func _on_button_pressed(button:Button):
	var texture = button.icon as SceneTexture
	
	var material = board.mesh.material as StandardMaterial3D
	material.albedo_texture = texture
	
	if _current_scene == texture.scene:
		return
	
	if is_instance_valid(_instance):
		scene_pivot.remove_child(_instance)
	
	_current_scene = texture.scene
	_instance = _current_scene.instantiate()
	
	scene_pivot.add_child(_instance)


func _on_rebake_pressed() -> void:
	for button:Button in button_grid.get_children():
		var texture = button.icon as SceneTexture
		var rot = texture.scene_rotation
		texture.scene_rotation = Vector3(rot.x, randf_range(0, TAU), rot.z)
		texture.light_energy = randf_range(0.5, 3.0)
