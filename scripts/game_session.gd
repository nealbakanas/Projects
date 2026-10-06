class_name GameSession
extends RefCounted
## Settings carried from the title screen into combat.

enum InputMode { TYPE, SHOOT }

static var tier := 1
static var input_mode := InputMode.TYPE
static var seed_value := 0


static func new_seed() -> void:
	seed_value = randi()
