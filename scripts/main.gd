extends Node2D
## Placeholder title screen for the scaffold milestone.
## Draws a seeded starfield and proves pixel-art settings and the web export work.

const STAR_COUNT := 60
const STAR_SEED := 1986

var _stars: Array[Vector2i] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var size := get_viewport_rect().size
	for i in STAR_COUNT:
		_stars.append(Vector2i(rng.randi_range(0, int(size.x) - 1), rng.randi_range(0, int(size.y) - 1)))
	queue_redraw()


func _draw() -> void:
	for i in _stars.size():
		var color := Color.WHITE if i % 3 == 0 else Color(0.5, 0.5, 0.7)
		draw_rect(Rect2(_stars[i], Vector2.ONE), color)
