class_name ChoiceAnswerInput
extends AnswerInput
## Shoot the answer: four answer pods for the enemy closest to the ship.
## Click or tap a pod, or press 1-4. Works without a keyboard.

signal choices_changed(target_id: int, choices: Array[String])

const CHOICE_COUNT := 4

var target_id := -1
var choices: Array[String] = []

var _rng := RandomNumberGenerator.new()
var _problem: Problem


func hint() -> String:
	return "click an answer or press 1-4"


func attach(p_encounter: Encounter) -> void:
	super(p_encounter)
	_rng.seed = p_encounter.seed_value ^ 0x5eed


func _process(_delta: float) -> void:
	if encounter == null:
		return
	var target := encounter.lowest_enemy()
	var new_id := target.id if target else -1
	var new_problem := target.problem if target else null
	if new_id != target_id or new_problem != _problem:
		target_id = new_id
		_problem = new_problem
		choices = []
		if target:
			choices = Distractors.generate(target.problem, CHOICE_COUNT - 1, _rng)
			choices.insert(_rng.randi_range(0, choices.size()), target.problem.answer_text())
		choices_changed.emit(target_id, choices)


## Fires the choice at index i (0-based) at the current target.
func choose(i: int) -> void:
	if target_id >= 0 and i >= 0 and i < choices.size():
		answer_submitted.emit(choices[i], target_id)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		choose(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()
