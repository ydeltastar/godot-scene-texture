@tool
extends SceneRender
## Render a [SceneTexture] using the engine internal render.


# --- Engine Callbacks --- #


# --- Public Functions --- #
func render(iteration: int):
	#RenderingServer.call_on_render_thread(_render_subviewport.bind(self, iteration))
	#await render_finished
	#return _texture.get_image()
	
	const ICON = preload("res://icon.svg")
	var image = ICON.get_image()
	image.resize(size.x, size.y)
	
	_render = image
	#var new_texture = RenderingServer.texture_2d_create(image)
	#RenderingServer.texture_replace(get_texture(), new_texture)
	render_finished.emit()


# --- Private Functions --- #
