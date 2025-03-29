extends Node3D
# Scene to test that scripts are ignored and don't cause issues when SceneTexture render.


# @onready var not cause an error
@onready var tree_blocks_2: Node3D = $tree_blocks2


func _enter_tree() -> void:
	print("Should not print _enter_tree")


func _ready() -> void:
	print("Should not print _ready")


func _process(_delta: float) -> void:
	print("Should not print _process")
