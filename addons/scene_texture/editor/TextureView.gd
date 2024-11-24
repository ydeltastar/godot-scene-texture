@tool
extends Button
## Draws a texture with a checkboard background keeping the texture's size if less than the control's size.


@export var texture:Texture2D:
	set(value):
		if texture == value:
			return
		
		if is_instance_valid(texture):
			texture.changed.disconnect(queue_redraw)
		
		texture = value
		
		if is_instance_valid(texture):
			texture.changed.connect(queue_redraw)
		
		queue_redraw()

var _background_texture:Texture2D


func _ready() -> void:
	var editor_theme = EditorInterface.get_editor_theme()
	_background_texture = editor_theme.get_icon(&"Checkerboard", &"EditorIcons")


func _draw():
	var new_size = Vector2(size)
	if is_instance_valid(texture):
		new_size = texture.get_size()
		
		if texture.get_width() > size.x or texture.get_height() > size.y:
			var w = size.x / texture.get_width()
			var h = size.y / texture.get_height()

			new_size = texture.get_size() * min(w, h)

	var offset = (size - new_size) / 2
	
	draw_texture_rect(_background_texture, Rect2(offset, new_size), true)
	if is_instance_valid(texture):
		draw_texture_rect(texture, Rect2(offset, new_size), false)
