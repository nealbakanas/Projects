extends Node2D
## Title screen: pick a content tier and an input mode, then launch combat.
## Keyboard: Left/Right tier, Up/Down mode, Enter start. Mouse/touch: the buttons.

const STAR_COUNT := 60
const STAR_SEED := 1986
const MODE_NAMES := {GameSession.InputMode.TYPE: "Type the answer", GameSession.InputMode.SHOOT: "Shoot the answer"}

var _stars: Array[Vector2i] = []

@onready var _tier_label: Label = $Tier
@onready var _mode_label: Label = $Mode


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var size := get_viewport_rect().size
	for i in STAR_COUNT:
		_stars.append(Vector2i(rng.randi_range(0, int(size.x) - 1), rng.randi_range(0, int(size.y) - 1)))
	$TierDown.pressed.connect(_change_tier.bind(-1))
	$TierUp.pressed.connect(_change_tier.bind(1))
	$ModePrev.pressed.connect(_toggle_mode)
	$ModeNext.pressed.connect(_toggle_mode)
	$Start.pressed.connect(_start)
	_refresh()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT:
			_change_tier(-1)
		KEY_RIGHT:
			_change_tier(1)
		KEY_UP, KEY_DOWN, KEY_TAB:
			_toggle_mode()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_start()


func _change_tier(delta: int) -> void:
	GameSession.tier = clampi(GameSession.tier + delta, ProblemGenerator.MIN_TIER, ProblemGenerator.MAX_TIER)
	_refresh()


func _toggle_mode() -> void:
	GameSession.input_mode = (GameSession.InputMode.SHOOT if GameSession.input_mode == GameSession.InputMode.TYPE
			else GameSession.InputMode.TYPE)
	_refresh()


func _refresh() -> void:
	_tier_label.text = "Tier %d" % GameSession.tier
	_mode_label.text = MODE_NAMES[GameSession.input_mode]


func _start() -> void:
	GameSession.new_seed()
	get_tree().change_scene_to_file("res://scenes/combat.tscn")


func _draw() -> void:
	for i in _stars.size():
		var color := Color.WHITE if i % 3 == 0 else Color(0.5, 0.5, 0.7)
		draw_rect(Rect2(_stars[i], Vector2.ONE), color)
