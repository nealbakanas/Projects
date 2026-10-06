# Math Blaster (working title)

A real-time, retro pixel-art math shooter with roguelike runs. Built in Godot 4, browser-first.
See [docs/DESIGN.md](docs/DESIGN.md) for the design doc.

## Requirements

- [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET; GDScript only)
- Web export templates for 4.3 (Editor → Manage Export Templates → Download)

## Run

Open `project.godot` in Godot and press F5, or from the command line:

```sh
godot --path .
```

## Web build

The project uses the Compatibility renderer and a **single-threaded** web export
(`variant/thread_support=false`), so it runs on itch.io and GitHub Pages without
cross-origin isolation headers.

```sh
godot --headless --import
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8000   # then open http://localhost:8000
```

## Pixel-art settings

- Base resolution 320×180, window 1280×720
- Stretch mode `viewport` with `integer` scaling
- Nearest texture filtering, pixel snapping, and no font antialiasing

## CI

`.github/workflows/build.yml` runs on every push and PR. It imports the project, boots the
main scene headless and fails on any script error, exports the web build, and uploads it as
the `math-blaster-web` artifact.
