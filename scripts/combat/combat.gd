extends Node2D
## Combat scene: draws an Encounter with placeholder pixel art and wires up
## the selected AnswerInput. All rules live in Encounter.

const LANE_COUNT := 3
const TOP_Y := 44.0
const SHIP_Y := 138.0
const SHIP_X := 160.0
const INPUT_Y := 154.0

const COLOR_TEXT := Color(0.95, 0.95, 1.0)
const COLOR_DIM := Color(0.5, 0.5, 0.7)
const COLOR_PROBLEM := Color(1.0, 0.82, 0.25)
const COLOR_TARGET := Color(0.3, 0.79, 0.94)
const COLOR_ENEMY := Color(0.97, 0.15, 0.52)
const COLOR_TOUGH := Color(1.0, 0.48, 0.0)
const COLOR_SHIP := Color(0.3, 0.79, 0.94)
const COLOR_DANGER := Color(1.0, 0.25, 0.25)
const COLOR_GOOD := Color(0.45, 1.0, 0.55)

var encounter: Encounter
var input: AnswerInput

var _problem_labels := {}  # enemy id -> Label
var _effects: Array[Dictionary] = []
var _flash := 0.0
var _flash_color := COLOR_DANGER
var _ship_shake := 0.0
var _stars: Array[Vector2i] = []

var _hud_score: Label
var _hud_combo: Label
var _input_label: Label
var _choice_buttons: Array[Button] = []
var _results: Control


func _ready() -> void:
	var config := Encounter.Config.new()
	config.tier = GameSession.tier
	config.lanes = LANE_COUNT
	encounter = Encounter.new(config, Weapon.adder_blaster(), GameSession.seed_value)
	encounter.enemy_spawned.connect(_on_enemy_spawned)
	encounter.enemy_hit.connect(_on_enemy_hit)
	encounter.answer_missed.connect(_on_answer_missed)
	encounter.enemy_breached.connect(_on_enemy_breached)
	encounter.finished.connect(_on_finished)

	var rng := RandomNumberGenerator.new()
	rng.seed = GameSession.seed_value
	for i in 50:
		_stars.append(Vector2i(rng.randi_range(0, 319), rng.randi_range(0, 179)))

	_hud_score = _label("0", 16, COLOR_TEXT, Vector2(110, 0), 100)
	_hud_combo = _label("", 16, COLOR_GOOD, Vector2(216, 0), 100, HORIZONTAL_ALIGNMENT_RIGHT)

	if GameSession.input_mode == GameSession.InputMode.SHOOT:
		_setup_choice_input()
	else:
		_setup_typed_input()
	input.attach(encounter)
	input.answer_submitted.connect(func(answer: String, target_id: int) -> void: encounter.submit(answer, target_id))
	_update_hud()


func _setup_typed_input() -> void:
	var typed := TypedAnswerInput.new()
	input = typed
	add_child(typed)
	_input_label = _label("", 16, COLOR_TARGET, Vector2(0, INPUT_Y), 320)
	typed.buffer_changed.connect(_on_buffer_changed)
	_on_buffer_changed("")


func _setup_choice_input() -> void:
	var choice := ChoiceAnswerInput.new()
	input = choice
	add_child(choice)
	for i in ChoiceAnswerInput.CHOICE_COUNT:
		var button := Button.new()
		button.position = Vector2(4 + i * 79, INPUT_Y)
		button.size = Vector2(75, 22)
		_style_pod(button)
		button.pressed.connect(choice.choose.bind(i))
		add_child(button)
		_choice_buttons.append(button)
	choice.choices_changed.connect(_on_choices_changed)


func _process(delta: float) -> void:
	encounter.step(delta)
	for effect in _effects:
		effect["t"] += delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return e["t"] < e["life"])
	_flash = maxf(0.0, _flash - delta * 3.0)
	_ship_shake = maxf(0.0, _ship_shake - delta)
	for enemy in encounter.enemies:
		var label: Label = _problem_labels.get(enemy.id)
		if label:
			var pos := _enemy_pos(enemy)
			label.position = Vector2(pos.x - label.size.x / 2.0, pos.y - 31)
			label.text = enemy.problem.text
			var targeted := enemy == encounter.lowest_enemy()
			label.add_theme_color_override("font_color", COLOR_TARGET if targeted else COLOR_PROBLEM)
	_update_hud()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not encounter.is_over:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_restart()
		elif key.keycode == KEY_ESCAPE:
			_to_title()


# --- Encounter events ---------------------------------------------------------

func _on_enemy_spawned(enemy: Encounter.Enemy) -> void:
	var label := _label(enemy.problem.text, 16, COLOR_PROBLEM, Vector2.ZERO, 104)
	_problem_labels[enemy.id] = label


func _on_enemy_hit(enemy: Encounter.Enemy, killed: bool, points: int) -> void:
	var pos := _enemy_pos(enemy)
	_effects.append({"kind": "laser", "to": pos, "t": 0.0, "life": 0.12})
	_effects.append({"kind": "points", "at": pos, "text": "+%d" % points, "t": 0.0, "life": 0.8})
	if killed:
		_effects.append({"kind": "boom", "at": pos, "t": 0.0, "life": 0.45, "color": _enemy_color(enemy)})
		_remove_label(enemy.id)


func _on_answer_missed(enemy: Encounter.Enemy) -> void:
	_ship_shake = 0.25
	if enemy:
		_effects.append({"kind": "fizzle", "to": _enemy_pos(enemy), "t": 0.0, "life": 0.15})


func _on_enemy_breached(enemy: Encounter.Enemy) -> void:
	_flash = 1.0
	_flash_color = COLOR_DANGER
	_ship_shake = 0.4
	_effects.append({"kind": "boom", "at": _enemy_pos(enemy), "t": 0.0, "life": 0.45, "color": COLOR_DANGER})
	_remove_label(enemy.id)


func _on_finished(won: bool) -> void:
	for id in _problem_labels.keys():
		_remove_label(id)
	for button in _choice_buttons:
		button.visible = false
	if _input_label:
		_input_label.visible = false
	input.set_process_unhandled_input(false)
	input.set_process(false)
	_show_results(won)


func _on_buffer_changed(text: String) -> void:
	if text == "":
		_input_label.text = input.hint()
		_input_label.add_theme_color_override("font_color", COLOR_DIM)
	else:
		_input_label.text = "> %s_" % text
		_input_label.add_theme_color_override("font_color", COLOR_TARGET)


func _on_choices_changed(_target_id: int, choices: Array[String]) -> void:
	for i in _choice_buttons.size():
		var button := _choice_buttons[i]
		button.visible = i < choices.size()
		if i < choices.size():
			button.text = "%d: %s" % [i + 1, choices[i]]


# --- Drawing ------------------------------------------------------------------

func _draw() -> void:
	for i in _stars.size():
		draw_rect(Rect2(_stars[i], Vector2.ONE), Color(1, 1, 1, 0.8) if i % 3 == 0 else Color(0.4, 0.4, 0.6))
	# Danger line the enemies must not cross.
	for x in range(0, 320, 6):
		draw_rect(Rect2(x, SHIP_Y - 6, 3, 1), Color(COLOR_DANGER, 0.35))
	for enemy in encounter.enemies:
		_draw_enemy(enemy, enemy == encounter.lowest_enemy())
	_draw_ship()
	_draw_hearts()
	for effect in _effects:
		_draw_effect(effect)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, 320, 180), Color(_flash_color, _flash * 0.35))


func _draw_enemy(enemy: Encounter.Enemy, targeted: bool) -> void:
	var p := _enemy_pos(enemy).round()
	var c := _enemy_color(enemy)
	var w := 10 if enemy.is_tough() else 7
	# Saucer: dome, body, lights.
	draw_rect(Rect2(p.x - 3, p.y - 5, 6, 2), Color(0.8, 0.9, 1.0))
	draw_rect(Rect2(p.x - w, p.y - 3, w * 2, 4), c)
	draw_rect(Rect2(p.x - w + 2, p.y + 1, w * 2 - 4, 2), c.darkened(0.4))
	for x in range(-w + 2, w - 1, 4):
		draw_rect(Rect2(p.x + x, p.y - 2, 1, 1), Color.WHITE)
	if enemy.is_tough():
		for i in enemy.max_hp:
			draw_rect(Rect2(p.x - 4 + i * 5, p.y + 5, 3, 2), COLOR_GOOD if i < enemy.hp else COLOR_DIM)
	if targeted:
		var r := Rect2(p.x - w - 4, p.y - 7, w * 2 + 8, 15)
		for corner in [r.position, Vector2(r.end.x - 3, r.position.y), Vector2(r.position.x, r.end.y - 1), Vector2(r.end.x - 3, r.end.y - 1)]:
			draw_rect(Rect2(corner, Vector2(3, 1)), COLOR_TARGET)


func _draw_ship() -> void:
	var shake := Vector2(roundf(sin(_ship_shake * 80.0) * 2.0 * signf(_ship_shake)), 0)
	var p := Vector2(SHIP_X, SHIP_Y) + shake
	draw_rect(Rect2(p.x - 1, p.y - 4, 2, 3), Color(1, 0.82, 0.25))
	draw_rect(Rect2(p.x - 3, p.y - 1, 6, 3), COLOR_SHIP)
	draw_rect(Rect2(p.x - 7, p.y + 2, 14, 3), COLOR_SHIP)
	draw_rect(Rect2(p.x - 9, p.y + 3, 3, 4), COLOR_ENEMY)
	draw_rect(Rect2(p.x + 6, p.y + 3, 3, 4), COLOR_ENEMY)
	draw_rect(Rect2(p.x - 1, p.y + 1, 2, 1), Color.WHITE)


func _draw_hearts() -> void:
	const HEART := ["01100110", "11111111", "11111111", "01111110", "00111100", "00011000"]
	for i in encounter.config.player_hp:
		var color := COLOR_DANGER if i < encounter.player_hp else Color(COLOR_DIM, 0.5)
		for row in HEART.size():
			for col in HEART[row].length():
				if HEART[row][col] == "1":
					draw_rect(Rect2(4 + i * 10 + col, 5 + row, 1, 1), color)


func _draw_effect(effect: Dictionary) -> void:
	var k: float = effect["t"] / effect["life"]
	match effect["kind"]:
		"laser":
			draw_line(Vector2(SHIP_X, SHIP_Y - 4), effect["to"], Color(COLOR_TARGET, 1.0 - k), 2.0)
		"fizzle":
			var to: Vector2 = effect["to"]
			var mid := Vector2(SHIP_X, SHIP_Y - 4).lerp(to, 0.35)
			draw_line(Vector2(SHIP_X, SHIP_Y - 4), mid, Color(COLOR_DANGER, 1.0 - k), 1.0)
		"boom":
			var at: Vector2 = effect["at"]
			for i in 8:
				var dir := Vector2.RIGHT.rotated(TAU * i / 8.0)
				var pos := (at + dir * k * 14.0).round()
				draw_rect(Rect2(pos, Vector2(2, 2)), Color(effect["color"], 1.0 - k))
		"points":
			var at: Vector2 = effect["at"]
			draw_string(ThemeDB.fallback_font, (at + Vector2(-10, -26 - k * 10)).round(), effect["text"],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(COLOR_GOOD, 1.0 - k))


# --- Helpers ------------------------------------------------------------------

func _enemy_pos(enemy: Encounter.Enemy) -> Vector2:
	var lane_width := 320.0 / encounter.config.lanes
	var x := lane_width * (enemy.lane + 0.5)
	var y := lerpf(TOP_Y, SHIP_Y - 12, clampf(enemy.progress, 0.0, 1.0))
	return Vector2(x, y)


func _enemy_color(enemy: Encounter.Enemy) -> Color:
	return COLOR_TOUGH if enemy.is_tough() else COLOR_ENEMY


func _update_hud() -> void:
	_hud_score.text = str(encounter.score)
	_hud_combo.text = "x%.1f" % encounter.multiplier() if encounter.streak >= Encounter.STREAK_PER_STEP else ""


func _label(text: String, font_size: int, color: Color, pos: Vector2, width: float,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(width, font_size)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.12))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label


func _remove_label(id: int) -> void:
	if _problem_labels.has(id):
		_problem_labels[id].queue_free()
		_problem_labels.erase(id)


## Compact flat style: the default button padding doesn't fit a 180 px screen.
func _style_pod(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = {"normal": Color(0.12, 0.1, 0.25), "hover": Color(0.2, 0.17, 0.4), "pressed": Color(0.3, 0.79, 0.94, 0.5)}[state]
		box.border_color = COLOR_TARGET
		box.set_border_width_all(1)
		box.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)


func _show_results(won: bool) -> void:
	_results = Control.new()
	_results.size = Vector2(320, 180)
	add_child(_results)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.04, 0.12, 0.85)
	panel.size = Vector2(320, 180)
	_results.add_child(panel)
	var title := _label("SECTOR CLEAR!" if won else "SHIP DOWN", 16, COLOR_GOOD if won else COLOR_DANGER, Vector2(0, 20), 320)
	title.reparent(_results)
	var lines := [
		"Score  %d" % encounter.score,
		"Accuracy  %d%%" % roundi(encounter.accuracy() * 100.0),
		"Best combo  %d" % encounter.best_streak,
		"Avg answer  %.1f s" % encounter.average_answer_time(),
	]
	for i in lines.size():
		_label(lines[i], 16, COLOR_TEXT, Vector2(0, 50 + i * 18), 320).reparent(_results)
	var again := Button.new()
	again.text = "Again (Enter)"
	again.position = Vector2(40, 140)
	again.size = Vector2(116, 22)
	again.pressed.connect(_restart)
	_results.add_child(again)
	var back := Button.new()
	back.text = "Title (Esc)"
	back.position = Vector2(164, 140)
	back.size = Vector2(116, 22)
	back.pressed.connect(_to_title)
	_results.add_child(back)
	for b in [again, back]:
		_style_pod(b)


func _restart() -> void:
	GameSession.new_seed()
	get_tree().reload_current_scene()


func _to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
