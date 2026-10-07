class_name TypedAnswerInput
extends AnswerInput
## Type the answer: digits, "-", "/" and "." build the answer; Enter or Space
## fires at whichever enemy it solves.

signal buffer_changed(text: String)

const MAX_LENGTH := 8
const ALLOWED := "0123456789-/."

var buffer := ""


func hint() -> String:
	return "type the answer, then Enter"


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or (key.echo and key.keycode != KEY_BACKSPACE):
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if buffer != "":
				answer_submitted.emit(buffer, -1)
				_set_buffer("")
		KEY_BACKSPACE:
			_set_buffer(buffer.left(-1))
		KEY_ESCAPE:
			_set_buffer("")
		_:
			var ch := char(key.unicode) if key.unicode > 0 else ""
			if ch != "" and ch in ALLOWED and buffer.length() < MAX_LENGTH:
				_set_buffer(buffer + ch)
			else:
				return
	get_viewport().set_input_as_handled()


func _set_buffer(text: String) -> void:
	buffer = text
	buffer_changed.emit(buffer)
