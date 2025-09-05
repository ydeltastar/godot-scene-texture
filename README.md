# SceneTexture - Icon/Thumbnail Generation

A texture that uses a 3D scene to render itself. Generate icons and thumbnails directly from a scene and use them anywhere that accepts a regular texture resource.

![Use](docs/scene_texture_use.gif)

## Features

- Use anywhere that takes a regular texture like buttons and materials. It is just an extension of `Texture2D`.
- Real-time preview in the inspector and editor.
- Can bake at runtime so it doesn't need to store pixel data in the resource file (great for version control).
- Supports advanced rendering features like global illumination by defining a custom `Environment`.

## Installation and How to Use

- Automatic: Install it from the [Godot Asset Library](https://godotengine.org/asset-library/asset/3506) in the `AssetLib` tab in the Godot editor.
- Manual: Download the source code and copy the `addons` folder into your project folder.

Make sure the plugin is activated in `Project > Project Setting > Plugins`.  
Create a new `SceneTexture` resource anywhere that takes a `Texture2D`, like a button icon. Set the scene to render and configure.

## License

Created by ydeltastar - MIT License.  
Assets in the demo by Kenney ([Nature Kit](https://kenney.nl/assets/nature-kit)) - Creative Commons CC0.
