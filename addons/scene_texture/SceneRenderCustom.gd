@tool
extends SceneRender
## Render a [SceneTexture] using the engine internal render.


# --- Engine Callbacks --- #


# --- Public Functions --- #
func render(iteration: int):	
	await get_tree().process_frame
	
	var mesh_instances = _get_children_of_type(self, MeshInstance3D)
	print(mesh_instances)
	var meshes: Array[Mesh]
	for instance: MeshInstance3D in mesh_instances:
		if instance.mesh:
			meshes.append(instance.mesh)
		instance.get_instance()
	
	if Engine.is_editor_hint() and meshes.size() > 0:
		var textures = EditorInterface.make_mesh_previews(meshes, size.x)
		_render = textures[0].get_image()
	else:
		var p = Image.create_empty(size.x, size.y, true, Image.FORMAT_RGB8)
		p.fill(Color.DEEP_PINK)
		_render = p
	
	render_finished.emit()


# --- Private Functions --- #
static func _get_children_of_type(node:Node, type, recursive = true) -> Array[Node]:
	var desired_children:Array[Node] = []
	for child in node.get_children():
		if is_instance_of(child, type):
			desired_children.append(child)

		if recursive:
			desired_children.append_array(_get_children_of_type(child, type, recursive))

	return desired_children
